--
-- PostgreSQL database dump
--

\restrict ubqmmaewkkIhQijpbku8px5cRW64WMQc2OVyHo19R3ycgzAA1B3VNxThgGQLXoJ

-- Dumped from database version 17.10 (Debian 17.10-1.pgdg13+1)
-- Dumped by pg_dump version 17.10 (Debian 17.10-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: approval_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approval_status AS ENUM (
    'pending_review',
    'in_review',
    'changes_requested',
    'approved',
    'rejected',
    'cancelled'
);


--
-- Name: candidate_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.candidate_status AS ENUM (
    'discovered',
    'enriched',
    'normalized',
    'pending_review',
    'approved',
    'merged',
    'discarded'
);


--
-- Name: confidence_band; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.confidence_band AS ENUM (
    'very_low',
    'low',
    'medium',
    'high',
    'very_high'
);


--
-- Name: entity_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entity_status AS ENUM (
    'draft',
    'active',
    'inactive',
    'deprecated',
    'archived'
);


--
-- Name: review_decision; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.review_decision AS ENUM (
    'approved',
    'rejected',
    'changes_requested',
    'escalated'
);


--
-- Name: review_tier; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.review_tier AS ENUM (
    'automated',
    'standard',
    'elevated',
    'expert',
    'consensus'
);


--
-- Name: translation_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.translation_status AS ENUM (
    'draft',
    'in_progress',
    'pending_review',
    'approved',
    'rejected'
);


--
-- Name: unit_dimension; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.unit_dimension AS ENUM (
    'mass',
    'volume',
    'energy',
    'temperature',
    'count',
    'ratio',
    'amount',
    'other'
);


--
-- Name: update_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.update_type AS ENUM (
    'created',
    'modified',
    'published',
    'unpublished',
    'deprecated',
    'archived',
    'merged',
    'split'
);


--
-- Name: version_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.version_status AS ENUM (
    'draft',
    'pending_approval',
    'approved',
    'rejected',
    'superseded'
);


--
-- Name: capture_entity_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.capture_entity_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    hist_table      text;
    prev_id         uuid;
    ct              update_type;
    snapshot        jsonb;
    snap_hash       text;
    row_checksum    text;
    col             record;
    target_col      text;
    ins_cols        text[] := '{}';
    sel_fields      text[] := '{}';
    has_updated_by  boolean := false;
    status_code     citext;
BEGIN
    IF TG_TABLE_SCHEMA IS DISTINCT FROM current_schema() THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    hist_table := TG_TABLE_NAME || '_history';

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = TG_TABLE_NAME
          AND column_name = 'updated_by'
    ) INTO has_updated_by;

    -- Classify the change.
    IF TG_OP = 'INSERT' THEN
        ct := 'created';
    ELSIF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
        ct := 'archived';
    ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
        ct := 'modified';
    ELSE
        SELECT code INTO status_code FROM lifecycle_statuses WHERE id = NEW.status_id;
        IF status_code = 'ARCHIVED' THEN
            ct := 'archived';
        ELSIF status_code = 'DEPRECATED' THEN
            ct := 'deprecated';
        ELSE
            ct := 'modified';
        END IF;
    END IF;

    -- Avoid duplicate snapshots: an UPDATE that changed nothing except the
    -- trigger-maintained updated_at stamp must not mint a new version.
    IF TG_OP = 'UPDATE' AND (to_jsonb(NEW) - 'updated_at') = (to_jsonb(OLD) - 'updated_at') THEN
        RETURN NEW;
    END IF;

    -- Preserve the version chain: bump the entity counter only when the
    -- application does not manage version_number itself.
    IF TG_OP = 'UPDATE' AND NEW.version_number = OLD.version_number THEN
        NEW.version_number := OLD.version_number + 1;
    END IF;

    -- Materialise the snapshot and map actor columns to their history names.
    -- created_by -> changed_by (COALESCE(updated_by, created_by) when the
    -- entity carries updated_by); updated_by/reviewed_by are never captured.
    -- NOTE: jsonb_set's new_value must never be SQL NULL (that would make the
    -- whole snapshot NULL); to_jsonb(expr) returns SQL NULL for a NULL input,
    -- so a missing actor is mapped to JSON null via COALESCE.
    snapshot := to_jsonb(NEW) - 'updated_at';
    IF snapshot ? 'created_by' THEN
        IF has_updated_by THEN
            snapshot := snapshot - 'created_by' - 'updated_by';
            snapshot := jsonb_set(snapshot, '{changed_by}', COALESCE(to_jsonb(COALESCE(NEW.updated_by, NEW.created_by)), 'null'::jsonb));
        ELSE
            snapshot := snapshot - 'created_by';
            snapshot := jsonb_set(snapshot, '{changed_by}', COALESCE(to_jsonb(NEW.created_by), 'null'::jsonb));
        END IF;
    END IF;

    -- Build the snapshot column list from the entity columns that exist
    -- (possibly renamed) in the history table. version_number is excluded:
    -- it is inserted via the history header (original_entity_id /
    -- version_number / previous_version_id / change_type / hashes), not as a
    -- snapshot column, so it must not appear twice in the INSERT.
    FOR col IN
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = TG_TABLE_NAME
          AND column_name NOT IN ('id', 'version_number', 'updated_at', 'updated_by', 'reviewed_by')
        ORDER BY ordinal_position
    LOOP
        target_col := CASE col.column_name
            WHEN 'created_by' THEN 'changed_by'
            WHEN 'approved_by' THEN 'approved_by'
            ELSE col.column_name
        END;

        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = current_schema()
              AND table_name = hist_table
              AND column_name = target_col
        ) THEN
            ins_cols   := ins_cols || quote_ident(target_col);
            sel_fields := sel_fields || format('(r).%I', target_col);
        END IF;
    END LOOP;

    -- previous_version_id = the latest history row for this entity.
    EXECUTE format(
        'SELECT id FROM %I WHERE original_entity_id = %L ORDER BY version_number DESC LIMIT 1',
        hist_table, NEW.id
    ) INTO prev_id;

    snap_hash    := encode(digest(snapshot::text, 'sha256'), 'hex');
    row_checksum := encode(
        digest(snap_hash || '|' || NEW.id::text || '|' || NEW.version_number::text || '|' || ct::text, 'sha256'),
        'hex'
    );

    -- Values are passed as a single bound parameter; nothing from NEW is ever
    -- textually embedded in the executed statement.
    EXECUTE format(
        'INSERT INTO %I (original_entity_id, version_number, previous_version_id, change_type, snapshot_hash, checksum, %s) '
        'SELECT %L, %L, %L, %L, %L, %L, %s '
        'FROM (SELECT jsonb_populate_record(NULL::%I, $1) AS r) s',
        hist_table,
        array_to_string(ins_cols, ', '),
        NEW.id,
        NEW.version_number,
        prev_id,
        ct,
        snap_hash,
        row_checksum,
        array_to_string(sel_fields, ', '),
        hist_table
    ) USING snapshot;

    RETURN NEW;
END;
$_$;


--
-- Name: check_product_allergies(text, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_product_allergies(p_barcode text, p_allergen_codes text[]) RETURNS TABLE(scanned_barcode text, product_code public.citext, product_name text, matched_allergens text[], decision text)
    LANGUAGE sql STABLE
    AS $$SELECT b.barcode::text, p.internal_code, p.name, ARRAY_AGG(DISTINCT a.internal_code::text ORDER BY a.internal_code::text) FILTER (WHERE a.internal_code::text = ANY(p_allergen_codes)) AS matched_allergens, CASE WHEN COUNT(DISTINCT a.id) FILTER (WHERE a.internal_code::text = ANY(p_allergen_codes)) > 0 THEN 'UNSAFE' ELSE 'SAFE' END FROM public.barcodes b JOIN public.product_barcodes pb ON pb.barcode_id = b.id JOIN public.products p ON p.id = pb.product_id LEFT JOIN public.product_ingredients pi ON pi.product_id = p.id AND pi.status_id = 1 AND pi.deleted_at IS NULL LEFT JOIN public.ingredient_allergens ia ON ia.ingredient_id = pi.ingredient_id AND ia.status_id = 1 AND ia.deleted_at IS NULL LEFT JOIN public.allergens a ON a.id = ia.allergen_id WHERE b.barcode::text = p_barcode AND b.deleted_at IS NULL AND pb.status_id = 1 AND pb.deleted_at IS NULL AND p.status_id = 1 AND p.deleted_at IS NULL GROUP BY b.barcode, p.internal_code, p.name$$;


--
-- Name: check_product_allergy(text, public.citext); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_product_allergy(p_barcode text, p_allergen_code public.citext) RETURNS TABLE(scanned_barcode text, product_code public.citext, product_name text, allergen_code public.citext, allergen_name text, decision text)
    LANGUAGE sql STABLE
    AS $$SELECT b.barcode::text, p.internal_code, p.name, a.internal_code, a.name, CASE WHEN EXISTS (SELECT 1 FROM public.product_allergens pa JOIN public.relationship_types rt ON rt.id = pa.relationship_type_id WHERE pa.product_id = p.id AND pa.allergen_id = a.id AND rt.code = 'CONTAINS_ALLERGEN' AND pa.status_id = 1 AND pa.deleted_at IS NULL) THEN 'UNSAFE' WHEN EXISTS (SELECT 1 FROM public.product_allergens pa JOIN public.relationship_types rt ON rt.id = pa.relationship_type_id WHERE pa.product_id = p.id AND pa.allergen_id = a.id AND rt.code = 'MAY_CONTAIN_ALLERGEN' AND pa.status_id = 1 AND pa.deleted_at IS NULL) THEN 'CAUTION' WHEN EXISTS (SELECT 1 FROM public.product_ingredients pi JOIN public.ingredient_allergens ia ON ia.ingredient_id = pi.ingredient_id JOIN public.relationship_types rt ON rt.id = pi.relationship_type_id WHERE pi.product_id = p.id AND ia.allergen_id = a.id AND rt.code IN ('CONTAINS_INGREDIENT', 'MAY_CONTAIN_INGREDIENT') AND pi.status_id = 1 AND ia.status_id = 1 AND pi.deleted_at IS NULL AND ia.deleted_at IS NULL) THEN 'UNSAFE' ELSE 'SAFE' END FROM public.barcodes b JOIN public.product_barcodes pb ON pb.barcode_id = b.id JOIN public.products p ON p.id = pb.product_id JOIN public.allergens a ON a.internal_code = p_allergen_code WHERE b.barcode::text = p_barcode AND b.deleted_at IS NULL AND pb.status_id = 1 AND pb.deleted_at IS NULL AND p.status_id = 1 AND p.deleted_at IS NULL$$;


--
-- Name: prevent_history_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_history_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
        'immutable history: % on % is not permitted (history rows are INSERT-only)',
        TG_OP,
        TG_TABLE_NAME;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


--
-- Name: validate_entity_relationship_endpoints(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_entity_relationship_endpoints() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    subject_ok boolean;
    object_ok  boolean;
BEGIN
    subject_ok := CASE NEW.subject_entity_type
        WHEN 'companies'    THEN EXISTS (SELECT 1 FROM companies    WHERE id = NEW.subject_id)
        WHEN 'brands'       THEN EXISTS (SELECT 1 FROM brands       WHERE id = NEW.subject_id)
        WHEN 'products'     THEN EXISTS (SELECT 1 FROM products     WHERE id = NEW.subject_id)
        WHEN 'ingredients'  THEN EXISTS (SELECT 1 FROM ingredients  WHERE id = NEW.subject_id)
        WHEN 'allergens'    THEN EXISTS (SELECT 1 FROM allergens    WHERE id = NEW.subject_id)
        WHEN 'health_flags' THEN EXISTS (SELECT 1 FROM health_flags WHERE id = NEW.subject_id)
        ELSE NULL
    END;

    IF subject_ok IS NULL THEN
        RAISE EXCEPTION 'entity_relationships: unknown subject_entity_type %', NEW.subject_entity_type;
    END IF;
    IF NOT subject_ok THEN
        RAISE EXCEPTION 'entity_relationships: subject entity % does not exist (id %)',
            NEW.subject_entity_type, NEW.subject_id;
    END IF;

    object_ok := CASE NEW.object_entity_type
        WHEN 'companies'    THEN EXISTS (SELECT 1 FROM companies    WHERE id = NEW.object_id)
        WHEN 'brands'       THEN EXISTS (SELECT 1 FROM brands       WHERE id = NEW.object_id)
        WHEN 'products'     THEN EXISTS (SELECT 1 FROM products     WHERE id = NEW.object_id)
        WHEN 'ingredients'  THEN EXISTS (SELECT 1 FROM ingredients  WHERE id = NEW.object_id)
        WHEN 'allergens'    THEN EXISTS (SELECT 1 FROM allergens    WHERE id = NEW.object_id)
        WHEN 'health_flags' THEN EXISTS (SELECT 1 FROM health_flags WHERE id = NEW.object_id)
        ELSE NULL
    END;

    IF object_ok IS NULL THEN
        RAISE EXCEPTION 'entity_relationships: unknown object_entity_type %', NEW.object_entity_type;
    END IF;
    IF NOT object_ok THEN
        RAISE EXCEPTION 'entity_relationships: object entity % does not exist (id %)',
            NEW.object_entity_type, NEW.object_id;
    END IF;

    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: allergen_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allergen_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    allergen_id uuid NOT NULL,
    language_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    display_name text NOT NULL,
    search_name text,
    description text,
    translation_status public.translation_status DEFAULT 'draft'::public.translation_status NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT allergen_translations_version_number_check CHECK ((version_number > 0))
);


--
-- Name: allergen_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allergen_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT allergen_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT allergen_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: allergens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allergens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    allergen_type_id uuid,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT allergens_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT allergens_version_number_check CHECK ((version_number > 0))
);


--
-- Name: allergens_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allergens_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    allergen_type_id uuid,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT allergens_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT allergens_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT allergens_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: audit_context; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_context (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    correlation_id uuid NOT NULL,
    transaction_id uuid NOT NULL,
    actor uuid,
    role_id uuid,
    source text,
    ip_address inet,
    user_agent text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: audit_event_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_event_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT audit_event_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT audit_event_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    audit_log_id uuid NOT NULL,
    event_type_id uuid NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    previous_version integer,
    new_version integer NOT NULL,
    event_time timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    change_set_id uuid,
    event_type_id uuid NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    previous_version integer,
    new_version integer NOT NULL,
    actor uuid,
    role_id uuid,
    source text,
    ip_address inet,
    user_agent text,
    correlation_id uuid,
    transaction_id uuid,
    logged_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: barcode_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.barcode_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    digit_length smallint,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT barcode_types_digit_length_check CHECK (((digit_length IS NULL) OR (digit_length > 0))),
    CONSTRAINT barcode_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT barcode_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: barcodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.barcodes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    barcode public.citext NOT NULL,
    barcode_type_id uuid NOT NULL,
    verification_status_id uuid NOT NULL,
    source_id uuid,
    status_id bigint NOT NULL,
    issued_country_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    updated_by uuid,
    reviewed_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT barcodes_barcode_not_empty_check CHECK ((barcode OPERATOR(public.<>) ''::public.citext)),
    CONSTRAINT barcodes_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT barcodes_version_number_check CHECK ((version_number > 0))
);


--
-- Name: barcodes_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.barcodes_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    barcode public.citext NOT NULL,
    barcode_type_id uuid NOT NULL,
    verification_status_id uuid NOT NULL,
    issued_country_id uuid,
    status_id bigint NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT barcodes_history_barcode_not_empty_check CHECK ((barcode OPERATOR(public.<>) ''::public.citext)),
    CONSTRAINT barcodes_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT barcodes_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT barcodes_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: brand_search_index; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brand_search_index (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    brand_id uuid NOT NULL,
    search_name text NOT NULL,
    search_text text NOT NULL,
    search_tokens text[] DEFAULT '{}'::text[] NOT NULL,
    language_codes public.citext[] DEFAULT '{}'::public.citext[] NOT NULL,
    search_rank numeric DEFAULT 0 NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT brand_search_index_search_rank_check CHECK ((search_rank >= (0)::numeric))
);


--
-- Name: brand_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brand_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    brand_id uuid NOT NULL,
    language_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    display_name text NOT NULL,
    search_name text,
    description text,
    translation_status public.translation_status DEFAULT 'draft'::public.translation_status NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT brand_translations_version_number_check CHECK ((version_number > 0))
);


--
-- Name: brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brands (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT brands_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT brands_version_number_check CHECK ((version_number > 0))
);


--
-- Name: brands_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brands_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    company_id uuid NOT NULL,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT brands_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT brands_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT brands_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: change_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.change_sets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    correlation_id uuid NOT NULL,
    transaction_id uuid NOT NULL,
    description text,
    applied_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    slug text,
    priority integer DEFAULT 50 NOT NULL,
    priority_score double precision,
    expected_product_count integer,
    discovered_product_count integer DEFAULT 0 NOT NULL,
    verified_product_count integer DEFAULT 0 NOT NULL,
    failed_product_count integer DEFAULT 0 NOT NULL,
    conflict_count integer DEFAULT 0 NOT NULL,
    missing_data_count integer DEFAULT 0 NOT NULL,
    barcode_coverage_pct double precision,
    ingredient_coverage_pct double precision,
    allergen_coverage_pct double precision,
    nutrition_coverage_pct double precision,
    evidence_coverage_pct double precision,
    last_scan_at timestamp with time zone,
    next_scan_at timestamp with time zone,
    country text DEFAULT 'SA'::text NOT NULL,
    market text DEFAULT 'packaged_food'::text NOT NULL,
    scan_status text DEFAULT 'pending'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT companies_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT companies_version_number_check CHECK ((version_number > 0))
);


--
-- Name: companies_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT companies_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT companies_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT companies_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: company_search_index; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_search_index (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    search_name text NOT NULL,
    search_text text NOT NULL,
    search_tokens text[] DEFAULT '{}'::text[] NOT NULL,
    language_codes public.citext[] DEFAULT '{}'::public.citext[] NOT NULL,
    search_rank numeric DEFAULT 0 NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT company_search_index_search_rank_check CHECK ((search_rank >= (0)::numeric))
);


--
-- Name: company_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    language_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    display_name text NOT NULL,
    search_name text,
    description text,
    translation_status public.translation_status DEFAULT 'draft'::public.translation_status NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT company_translations_version_number_check CHECK ((version_number > 0))
);


--
-- Name: condition_nutrition_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.condition_nutrition_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condition_id uuid NOT NULL,
    nutrition_type_code text NOT NULL,
    operator text NOT NULL,
    threshold_value double precision NOT NULL,
    unit_code text NOT NULL,
    severity text DEFAULT 'warning'::text NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.countries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    alpha_3 public.citext NOT NULL,
    numeric_code text NOT NULL,
    name text NOT NULL,
    is_gcc_member boolean DEFAULT false NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT countries_alpha_3_check CHECK ((alpha_3 OPERATOR(public.~) '^[A-Za-z]{3}$'::public.citext)),
    CONSTRAINT countries_code_check CHECK ((code OPERATOR(public.~) '^[A-Za-z]{2}$'::public.citext)),
    CONSTRAINT countries_numeric_code_check CHECK ((numeric_code ~ '^[0-9]{3}$'::text)),
    CONSTRAINT countries_version_number_check CHECK ((version_number > 0))
);


--
-- Name: coverage_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coverage_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    scan_job_id uuid,
    total_products integer DEFAULT 0 NOT NULL,
    products_with_barcode integer DEFAULT 0 NOT NULL,
    products_with_ingredients integer DEFAULT 0 NOT NULL,
    products_with_allergens integer DEFAULT 0 NOT NULL,
    products_with_nutrition integer DEFAULT 0 NOT NULL,
    products_with_evidence integer DEFAULT 0 NOT NULL,
    products_with_halal integer DEFAULT 0 NOT NULL,
    barcode_coverage_pct double precision,
    ingredient_coverage_pct double precision,
    allergen_coverage_pct double precision,
    nutrition_coverage_pct double precision,
    evidence_coverage_pct double precision,
    halal_coverage_pct double precision,
    overall_coverage_pct double precision,
    snapshot_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: data_conflicts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_conflicts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    entity_name text,
    field_name text NOT NULL,
    value_a text NOT NULL,
    value_b text NOT NULL,
    source_a_id uuid,
    source_b_id uuid,
    confidence_a double precision,
    confidence_b double precision,
    resolution text DEFAULT 'unresolved'::text,
    resolution_note text,
    resolved_by text,
    resolved_at timestamp with time zone,
    status text DEFAULT 'detected'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: data_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_sources (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    source_type_id uuid NOT NULL,
    priority_id uuid NOT NULL,
    country_id uuid,
    is_verified boolean DEFAULT false NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT data_sources_version_number_check CHECK ((version_number > 0))
);


--
-- Name: data_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    data_snapshot jsonb NOT NULL,
    source_config_id uuid,
    change_summary text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: discovery_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discovery_candidates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    scan_job_id uuid,
    name text NOT NULL,
    brand text,
    barcode text,
    category text,
    country text DEFAULT 'SA'::text NOT NULL,
    market text DEFAULT 'packaged_food'::text NOT NULL,
    source_url text,
    source_reference text,
    source_retrieved_at timestamp with time zone,
    raw_data jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'discovered'::text NOT NULL,
    normalized_name text,
    normalized_brand text,
    normalized_barcode text,
    matched_product_id uuid,
    match_confidence double precision,
    validation_errors jsonb DEFAULT '[]'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: entity_relationships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_relationships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    subject_entity_type text NOT NULL,
    subject_id uuid NOT NULL,
    object_entity_type text NOT NULL,
    object_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT entity_relationships_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT entity_relationships_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT entity_relationships_no_self_loop_check CHECK (((subject_entity_type <> object_entity_type) OR (subject_id <> object_id))),
    CONSTRAINT entity_relationships_object_entity_type_check CHECK ((object_entity_type = ANY (ARRAY['companies'::text, 'brands'::text, 'products'::text, 'ingredients'::text, 'allergens'::text, 'health_flags'::text]))),
    CONSTRAINT entity_relationships_subject_entity_type_check CHECK ((subject_entity_type = ANY (ARRAY['companies'::text, 'brands'::text, 'products'::text, 'ingredients'::text, 'allergens'::text, 'health_flags'::text]))),
    CONSTRAINT entity_relationships_version_number_check CHECK ((version_number > 0))
);


--
-- Name: entity_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    history_table text NOT NULL,
    history_row_id uuid NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    change_set_id uuid,
    previous_version_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT entity_versions_history_table_check CHECK ((history_table <> ''::text)),
    CONSTRAINT entity_versions_version_number_check CHECK ((version_number > 0))
);


--
-- Name: evidence_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evidence_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT evidence_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT evidence_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: halal_evidence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.halal_evidence (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    status text DEFAULT 'UNKNOWN'::text NOT NULL,
    confidence double precision DEFAULT 0.0 NOT NULL,
    source_config_id uuid,
    evidence_type text,
    authority text,
    reasoning text,
    raw_evidence text,
    retrieved_at timestamp with time zone DEFAULT now() NOT NULL,
    is_current boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: health_conditions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: health_flag_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_flag_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    health_flag_id uuid NOT NULL,
    language_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    display_name text NOT NULL,
    search_name text,
    description text,
    translation_status public.translation_status DEFAULT 'draft'::public.translation_status NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT health_flag_translations_version_number_check CHECK ((version_number > 0))
);


--
-- Name: health_flag_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_flag_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT health_flag_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT health_flag_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: health_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_flags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    health_flag_type_id uuid,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT health_flags_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT health_flags_version_number_check CHECK ((version_number > 0))
);


--
-- Name: health_flags_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.health_flags_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    health_flag_type_id uuid,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT health_flags_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT health_flags_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT health_flags_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: image_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT image_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT image_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.images (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    image_type_id uuid NOT NULL,
    source_id uuid,
    language_id uuid,
    storage_uri text NOT NULL,
    content_hash text NOT NULL,
    mime_type text NOT NULL,
    width integer,
    height integer,
    file_size bigint DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    updated_by uuid,
    reviewed_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT images_dimension_height_check CHECK (((height IS NULL) OR (height > 0))),
    CONSTRAINT images_dimension_width_check CHECK (((width IS NULL) OR (width > 0))),
    CONSTRAINT images_file_size_check CHECK ((file_size >= 0)),
    CONSTRAINT images_version_number_check CHECK ((version_number > 0))
);


--
-- Name: images_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.images_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    image_type_id uuid NOT NULL,
    language_id uuid,
    storage_uri text NOT NULL,
    content_hash text NOT NULL,
    mime_type text NOT NULL,
    width integer,
    height integer,
    file_size bigint DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    status_id bigint NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT images_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT images_history_dimension_height_check CHECK (((height IS NULL) OR (height > 0))),
    CONSTRAINT images_history_dimension_width_check CHECK (((width IS NULL) OR (width > 0))),
    CONSTRAINT images_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT images_history_file_size_check CHECK ((file_size >= 0)),
    CONSTRAINT images_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: ingredient_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredient_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingredient_id uuid NOT NULL,
    alias text NOT NULL,
    language_id uuid,
    relationship_type_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ingredient_aliases_alias_not_blank_check CHECK ((alias <> ''::text)),
    CONSTRAINT ingredient_aliases_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT ingredient_aliases_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT ingredient_aliases_version_number_check CHECK ((version_number > 0))
);


--
-- Name: ingredient_allergens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredient_allergens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingredient_id uuid NOT NULL,
    allergen_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ingredient_allergens_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT ingredient_allergens_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT ingredient_allergens_version_number_check CHECK ((version_number > 0))
);


--
-- Name: ingredient_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredient_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    parent_id uuid,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ingredient_categories_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT ingredient_categories_parent_not_self_check CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT ingredient_categories_version_number_check CHECK ((version_number > 0))
);


--
-- Name: ingredient_categories_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredient_categories_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    parent_id uuid,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT ingredient_categories_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT ingredient_categories_history_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT ingredient_categories_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT ingredient_categories_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: ingredient_health_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredient_health_flags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingredient_id uuid NOT NULL,
    health_flag_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ingredient_health_flags_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT ingredient_health_flags_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT ingredient_health_flags_version_number_check CHECK ((version_number > 0))
);


--
-- Name: ingredient_search_index; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredient_search_index (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingredient_id uuid NOT NULL,
    search_name text NOT NULL,
    search_text text NOT NULL,
    search_tokens text[] DEFAULT '{}'::text[] NOT NULL,
    language_codes public.citext[] DEFAULT '{}'::public.citext[] NOT NULL,
    search_rank numeric DEFAULT 0 NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ingredient_search_index_search_rank_check CHECK ((search_rank >= (0)::numeric))
);


--
-- Name: ingredient_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredient_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingredient_id uuid NOT NULL,
    language_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    display_name text NOT NULL,
    search_name text,
    description text,
    translation_status public.translation_status DEFAULT 'draft'::public.translation_status NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ingredient_translations_version_number_check CHECK ((version_number > 0))
);


--
-- Name: ingredients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ingredients_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT ingredients_version_number_check CHECK ((version_number > 0))
);


--
-- Name: ingredients_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingredients_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT ingredients_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT ingredients_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT ingredients_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.languages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    native_name text NOT NULL,
    is_rtl boolean DEFAULT false NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT languages_code_check CHECK (((char_length((code)::text) >= 2) AND (char_length((code)::text) <= 10))),
    CONSTRAINT languages_version_number_check CHECK ((version_number > 0))
);


--
-- Name: lifecycle_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lifecycle_statuses (
    id bigint NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT lifecycle_statuses_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT lifecycle_statuses_version_number_check CHECK ((version_number > 0))
);


--
-- Name: lifecycle_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.lifecycle_statuses ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.lifecycle_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: measurement_bases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.measurement_bases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT measurement_bases_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT measurement_bases_version_number_check CHECK ((version_number > 0))
);


--
-- Name: nutrition_type_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nutrition_type_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nutrition_type_id uuid NOT NULL,
    language_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    display_name text NOT NULL,
    search_name text,
    description text,
    translation_status public.translation_status DEFAULT 'draft'::public.translation_status NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT nutrition_type_translations_version_number_check CHECK ((version_number > 0))
);


--
-- Name: nutrition_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nutrition_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT nutrition_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT nutrition_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: nutrition_types_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nutrition_types_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT nutrition_types_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT nutrition_types_history_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT nutrition_types_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT nutrition_types_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: package_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.package_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT package_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT package_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: permission_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permission_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT permission_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT permission_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_allergens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_allergens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    allergen_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT product_allergens_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_allergens_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_allergens_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_barcodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_barcodes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    barcode_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT product_barcodes_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_barcodes_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_barcodes_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_barcodes_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_barcodes_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    product_id uuid NOT NULL,
    barcode_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    evidence_type_id uuid,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT product_barcodes_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_barcodes_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_barcodes_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    parent_id uuid,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT product_categories_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT product_categories_parent_not_self_check CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT product_categories_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_categories_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_categories_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    parent_id uuid,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT product_categories_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_categories_history_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT product_categories_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_categories_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_category_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_category_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_category_id uuid NOT NULL,
    language_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    display_name text NOT NULL,
    search_name text,
    description text,
    translation_status public.translation_status DEFAULT 'draft'::public.translation_status NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT product_category_translations_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_health_evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_health_evaluations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    condition_id uuid NOT NULL,
    evaluation_result text NOT NULL,
    evidence jsonb DEFAULT '[]'::jsonb,
    evaluated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: product_health_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_health_flags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    health_flag_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT product_health_flags_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_health_flags_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_health_flags_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_images (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    image_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT product_images_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_images_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_images_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_images_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_images_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    product_id uuid NOT NULL,
    image_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    evidence_type_id uuid,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT product_images_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_images_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_images_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_ingredients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_ingredients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    ingredient_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    amount_value numeric,
    unit_id uuid,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT product_ingredients_amount_nonnegative_check CHECK (((amount_value IS NULL) OR (amount_value >= (0)::numeric))),
    CONSTRAINT product_ingredients_amount_unit_pairing_check CHECK ((((amount_value IS NULL) AND (unit_id IS NULL)) OR (amount_value IS NOT NULL))),
    CONSTRAINT product_ingredients_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_ingredients_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_ingredients_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_nutrition_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_nutrition_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    nutrition_type_id uuid NOT NULL,
    relationship_type_id uuid NOT NULL,
    amount_value numeric NOT NULL,
    unit_id uuid NOT NULL,
    source_id uuid,
    evidence_type_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    measurement_basis_id uuid,
    CONSTRAINT product_nutrition_values_amount_nonnegative_check CHECK ((amount_value >= (0)::numeric)),
    CONSTRAINT product_nutrition_values_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT product_nutrition_values_effective_period_check CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT product_nutrition_values_version_number_check CHECK ((version_number > 0))
);


--
-- Name: product_search_index; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_search_index (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    search_name text NOT NULL,
    search_text text NOT NULL,
    search_tokens text[] DEFAULT '{}'::text[] NOT NULL,
    language_codes public.citext[] DEFAULT '{}'::public.citext[] NOT NULL,
    search_rank numeric DEFAULT 0 NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT product_search_index_search_rank_check CHECK ((search_rank >= (0)::numeric))
);


--
-- Name: product_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_translations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    language_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    display_name text NOT NULL,
    search_name text,
    description text,
    translation_status public.translation_status DEFAULT 'draft'::public.translation_status NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT product_translations_version_number_check CHECK ((version_number > 0))
);


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    brand_id uuid,
    product_category_id uuid,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT products_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT products_version_number_check CHECK ((version_number > 0))
);


--
-- Name: products_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    original_entity_id uuid NOT NULL,
    version_number integer NOT NULL,
    previous_version_id uuid,
    change_set_id uuid,
    change_type public.update_type NOT NULL,
    change_reason text,
    changed_by uuid,
    approved_by uuid,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    brand_id uuid,
    product_category_id uuid,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    effective_from timestamp with time zone DEFAULT now() NOT NULL,
    effective_to timestamp with time zone,
    superseded_at timestamp with time zone,
    snapshot_hash text NOT NULL,
    checksum text NOT NULL,
    version_status public.version_status DEFAULT 'draft'::public.version_status NOT NULL,
    CONSTRAINT products_history_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT products_history_effective_window_check CHECK (((effective_to IS NULL) OR (effective_to >= effective_from))),
    CONSTRAINT products_history_version_number_check CHECK ((version_number > 0))
);


--
-- Name: regions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.regions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT regions_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT regions_version_number_check CHECK ((version_number > 0))
);


--
-- Name: regulatory_authorities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.regulatory_authorities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT regulatory_authorities_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT regulatory_authorities_version_number_check CHECK ((version_number > 0))
);


--
-- Name: relationship_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.relationship_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    is_directional boolean DEFAULT true NOT NULL,
    inverse_type_id uuid,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT relationship_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT relationship_types_inverse_not_self_check CHECK (((inverse_type_id IS NULL) OR (inverse_type_id <> id))),
    CONSTRAINT relationship_types_symmetric_no_inverse_check CHECK ((is_directional OR (inverse_type_id IS NULL))),
    CONSTRAINT relationship_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: role_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT role_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT role_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: scan_job_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scan_job_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scan_job_id uuid NOT NULL,
    candidate_id uuid,
    product_id uuid,
    barcode text,
    status text DEFAULT 'pending'::text NOT NULL,
    action text,
    error_message text,
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: scan_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scan_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    scan_type text DEFAULT 'full'::text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    duration_seconds double precision,
    products_discovered integer DEFAULT 0 NOT NULL,
    products_processed integer DEFAULT 0 NOT NULL,
    products_accepted integer DEFAULT 0 NOT NULL,
    products_rejected integer DEFAULT 0 NOT NULL,
    products_needs_review integer DEFAULT 0 NOT NULL,
    products_created integer DEFAULT 0 NOT NULL,
    products_updated integer DEFAULT 0 NOT NULL,
    products_unchanged integer DEFAULT 0 NOT NULL,
    conflicts_detected integer DEFAULT 0 NOT NULL,
    errors_count integer DEFAULT 0 NOT NULL,
    coverage_pct double precision,
    error_log jsonb DEFAULT '[]'::jsonb,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version text NOT NULL,
    checksum text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: source_priorities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_priorities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    rank smallint NOT NULL,
    description text,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT source_priorities_rank_check CHECK (((rank >= 1) AND (rank <= 99))),
    CONSTRAINT source_priorities_version_number_check CHECK ((version_number > 0))
);


--
-- Name: source_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT source_types_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT source_types_version_number_check CHECK ((version_number > 0))
);


--
-- Name: unit_conversions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unit_conversions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    from_unit_id uuid NOT NULL,
    to_unit_id uuid NOT NULL,
    conversion_factor double precision NOT NULL,
    measurement_type text NOT NULL,
    is_exact boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    symbol text NOT NULL,
    dimension public.unit_dimension NOT NULL,
    is_base_unit boolean DEFAULT false NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT units_version_number_check CHECK ((version_number > 0))
);


--
-- Name: verification_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.verification_statuses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    display_order integer DEFAULT 0 NOT NULL,
    status_id bigint NOT NULL,
    version_number integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT verification_statuses_display_order_check CHECK ((display_order >= 0)),
    CONSTRAINT verification_statuses_version_number_check CHECK ((version_number > 0))
);


--
-- Name: version_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.version_metadata (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_version_id uuid NOT NULL,
    key public.citext NOT NULL,
    value text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT version_metadata_key_not_empty_check CHECK ((key OPERATOR(public.<>) ''::public.citext))
);


--
-- Name: allergen_translations allergen_translations_allergen_language_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergen_translations
    ADD CONSTRAINT allergen_translations_allergen_language_unique UNIQUE (allergen_id, language_id);


--
-- Name: allergen_translations allergen_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergen_translations
    ADD CONSTRAINT allergen_translations_pkey PRIMARY KEY (id);


--
-- Name: allergen_types allergen_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergen_types
    ADD CONSTRAINT allergen_types_code_unique UNIQUE (code);


--
-- Name: allergen_types allergen_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergen_types
    ADD CONSTRAINT allergen_types_pkey PRIMARY KEY (id);


--
-- Name: allergens_history allergens_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens_history
    ADD CONSTRAINT allergens_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: allergens_history allergens_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens_history
    ADD CONSTRAINT allergens_history_pkey PRIMARY KEY (id);


--
-- Name: allergens allergens_internal_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens
    ADD CONSTRAINT allergens_internal_code_unique UNIQUE (internal_code);


--
-- Name: allergens allergens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens
    ADD CONSTRAINT allergens_pkey PRIMARY KEY (id);


--
-- Name: audit_context audit_context_operation_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_context
    ADD CONSTRAINT audit_context_operation_unique UNIQUE (correlation_id, transaction_id);


--
-- Name: audit_context audit_context_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_context
    ADD CONSTRAINT audit_context_pkey PRIMARY KEY (id);


--
-- Name: audit_event_types audit_event_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_event_types
    ADD CONSTRAINT audit_event_types_code_unique UNIQUE (code);


--
-- Name: audit_event_types audit_event_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_event_types
    ADD CONSTRAINT audit_event_types_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: barcode_types barcode_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcode_types
    ADD CONSTRAINT barcode_types_code_unique UNIQUE (code);


--
-- Name: barcode_types barcode_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcode_types
    ADD CONSTRAINT barcode_types_pkey PRIMARY KEY (id);


--
-- Name: barcodes barcodes_barcode_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes
    ADD CONSTRAINT barcodes_barcode_unique UNIQUE (barcode);


--
-- Name: barcodes_history barcodes_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: barcodes_history barcodes_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_pkey PRIMARY KEY (id);


--
-- Name: barcodes barcodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes
    ADD CONSTRAINT barcodes_pkey PRIMARY KEY (id);


--
-- Name: brand_search_index brand_search_index_brand_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_search_index
    ADD CONSTRAINT brand_search_index_brand_id_unique UNIQUE (brand_id);


--
-- Name: brand_search_index brand_search_index_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_search_index
    ADD CONSTRAINT brand_search_index_pkey PRIMARY KEY (id);


--
-- Name: brand_translations brand_translations_brand_language_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_translations
    ADD CONSTRAINT brand_translations_brand_language_unique UNIQUE (brand_id, language_id);


--
-- Name: brand_translations brand_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_translations
    ADD CONSTRAINT brand_translations_pkey PRIMARY KEY (id);


--
-- Name: brands_history brands_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands_history
    ADD CONSTRAINT brands_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: brands_history brands_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands_history
    ADD CONSTRAINT brands_history_pkey PRIMARY KEY (id);


--
-- Name: brands brands_internal_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_internal_code_unique UNIQUE (internal_code);


--
-- Name: brands brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_pkey PRIMARY KEY (id);


--
-- Name: change_sets change_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_sets
    ADD CONSTRAINT change_sets_pkey PRIMARY KEY (id);


--
-- Name: companies_history companies_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies_history
    ADD CONSTRAINT companies_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: companies_history companies_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies_history
    ADD CONSTRAINT companies_history_pkey PRIMARY KEY (id);


--
-- Name: companies companies_internal_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_internal_code_unique UNIQUE (internal_code);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_search_index company_search_index_company_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_search_index
    ADD CONSTRAINT company_search_index_company_id_unique UNIQUE (company_id);


--
-- Name: company_search_index company_search_index_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_search_index
    ADD CONSTRAINT company_search_index_pkey PRIMARY KEY (id);


--
-- Name: company_translations company_translations_company_language_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_translations
    ADD CONSTRAINT company_translations_company_language_unique UNIQUE (company_id, language_id);


--
-- Name: company_translations company_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_translations
    ADD CONSTRAINT company_translations_pkey PRIMARY KEY (id);


--
-- Name: condition_nutrition_rules condition_nutrition_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.condition_nutrition_rules
    ADD CONSTRAINT condition_nutrition_rules_pkey PRIMARY KEY (id);


--
-- Name: countries countries_alpha_3_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_alpha_3_unique UNIQUE (alpha_3);


--
-- Name: countries countries_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_code_unique UNIQUE (code);


--
-- Name: countries countries_numeric_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_numeric_code_unique UNIQUE (numeric_code);


--
-- Name: countries countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (id);


--
-- Name: coverage_snapshots coverage_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_snapshots
    ADD CONSTRAINT coverage_snapshots_pkey PRIMARY KEY (id);


--
-- Name: data_conflicts data_conflicts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_conflicts
    ADD CONSTRAINT data_conflicts_pkey PRIMARY KEY (id);


--
-- Name: data_sources data_sources_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_code_unique UNIQUE (code);


--
-- Name: data_sources data_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_pkey PRIMARY KEY (id);


--
-- Name: data_versions data_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_versions
    ADD CONSTRAINT data_versions_pkey PRIMARY KEY (id);


--
-- Name: discovery_candidates discovery_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discovery_candidates
    ADD CONSTRAINT discovery_candidates_pkey PRIMARY KEY (id);


--
-- Name: entity_relationships entity_relationships_edge_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relationships
    ADD CONSTRAINT entity_relationships_edge_unique UNIQUE (subject_entity_type, subject_id, relationship_type_id, object_entity_type, object_id);


--
-- Name: entity_relationships entity_relationships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relationships
    ADD CONSTRAINT entity_relationships_pkey PRIMARY KEY (id);


--
-- Name: entity_versions entity_versions_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_versions
    ADD CONSTRAINT entity_versions_entity_version_unique UNIQUE (entity_type, entity_id, version_number);


--
-- Name: entity_versions entity_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_versions
    ADD CONSTRAINT entity_versions_pkey PRIMARY KEY (id);


--
-- Name: evidence_types evidence_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_types
    ADD CONSTRAINT evidence_types_code_unique UNIQUE (code);


--
-- Name: evidence_types evidence_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_types
    ADD CONSTRAINT evidence_types_pkey PRIMARY KEY (id);


--
-- Name: halal_evidence halal_evidence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.halal_evidence
    ADD CONSTRAINT halal_evidence_pkey PRIMARY KEY (id);


--
-- Name: health_conditions health_conditions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_conditions
    ADD CONSTRAINT health_conditions_code_key UNIQUE (code);


--
-- Name: health_conditions health_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_conditions
    ADD CONSTRAINT health_conditions_pkey PRIMARY KEY (id);


--
-- Name: health_flag_translations health_flag_translations_health_flag_language_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flag_translations
    ADD CONSTRAINT health_flag_translations_health_flag_language_unique UNIQUE (health_flag_id, language_id);


--
-- Name: health_flag_translations health_flag_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flag_translations
    ADD CONSTRAINT health_flag_translations_pkey PRIMARY KEY (id);


--
-- Name: health_flag_types health_flag_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flag_types
    ADD CONSTRAINT health_flag_types_code_unique UNIQUE (code);


--
-- Name: health_flag_types health_flag_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flag_types
    ADD CONSTRAINT health_flag_types_pkey PRIMARY KEY (id);


--
-- Name: health_flags_history health_flags_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags_history
    ADD CONSTRAINT health_flags_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: health_flags_history health_flags_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags_history
    ADD CONSTRAINT health_flags_history_pkey PRIMARY KEY (id);


--
-- Name: health_flags health_flags_internal_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags
    ADD CONSTRAINT health_flags_internal_code_unique UNIQUE (internal_code);


--
-- Name: health_flags health_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags
    ADD CONSTRAINT health_flags_pkey PRIMARY KEY (id);


--
-- Name: image_types image_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_types
    ADD CONSTRAINT image_types_code_unique UNIQUE (code);


--
-- Name: image_types image_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_types
    ADD CONSTRAINT image_types_pkey PRIMARY KEY (id);


--
-- Name: images images_content_hash_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_content_hash_unique UNIQUE (content_hash);


--
-- Name: images_history images_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: images_history images_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: images images_storage_uri_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_storage_uri_unique UNIQUE (storage_uri);


--
-- Name: ingredient_aliases ingredient_aliases_ingredient_alias_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_ingredient_alias_unique UNIQUE (ingredient_id, alias);


--
-- Name: ingredient_aliases ingredient_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_pkey PRIMARY KEY (id);


--
-- Name: ingredient_allergens ingredient_allergens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_pkey PRIMARY KEY (id);


--
-- Name: ingredient_allergens ingredient_allergens_subject_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_subject_unique UNIQUE (ingredient_id, allergen_id, relationship_type_id);


--
-- Name: ingredient_categories ingredient_categories_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories
    ADD CONSTRAINT ingredient_categories_code_unique UNIQUE (code);


--
-- Name: ingredient_categories_history ingredient_categories_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: ingredient_categories_history ingredient_categories_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_pkey PRIMARY KEY (id);


--
-- Name: ingredient_categories ingredient_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories
    ADD CONSTRAINT ingredient_categories_pkey PRIMARY KEY (id);


--
-- Name: ingredient_health_flags ingredient_health_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_pkey PRIMARY KEY (id);


--
-- Name: ingredient_health_flags ingredient_health_flags_subject_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_subject_unique UNIQUE (ingredient_id, health_flag_id, relationship_type_id);


--
-- Name: ingredient_search_index ingredient_search_index_ingredient_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_search_index
    ADD CONSTRAINT ingredient_search_index_ingredient_id_unique UNIQUE (ingredient_id);


--
-- Name: ingredient_search_index ingredient_search_index_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_search_index
    ADD CONSTRAINT ingredient_search_index_pkey PRIMARY KEY (id);


--
-- Name: ingredient_translations ingredient_translations_ingredient_language_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_translations
    ADD CONSTRAINT ingredient_translations_ingredient_language_unique UNIQUE (ingredient_id, language_id);


--
-- Name: ingredient_translations ingredient_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_translations
    ADD CONSTRAINT ingredient_translations_pkey PRIMARY KEY (id);


--
-- Name: ingredients_history ingredients_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients_history
    ADD CONSTRAINT ingredients_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: ingredients_history ingredients_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients_history
    ADD CONSTRAINT ingredients_history_pkey PRIMARY KEY (id);


--
-- Name: ingredients ingredients_internal_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients
    ADD CONSTRAINT ingredients_internal_code_unique UNIQUE (internal_code);


--
-- Name: ingredients ingredients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients
    ADD CONSTRAINT ingredients_pkey PRIMARY KEY (id);


--
-- Name: languages languages_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT languages_code_unique UNIQUE (code);


--
-- Name: languages languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT languages_pkey PRIMARY KEY (id);


--
-- Name: lifecycle_statuses lifecycle_statuses_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_statuses
    ADD CONSTRAINT lifecycle_statuses_code_unique UNIQUE (code);


--
-- Name: lifecycle_statuses lifecycle_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lifecycle_statuses
    ADD CONSTRAINT lifecycle_statuses_pkey PRIMARY KEY (id);


--
-- Name: measurement_bases measurement_bases_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.measurement_bases
    ADD CONSTRAINT measurement_bases_code_unique UNIQUE (code);


--
-- Name: measurement_bases measurement_bases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.measurement_bases
    ADD CONSTRAINT measurement_bases_pkey PRIMARY KEY (id);


--
-- Name: nutrition_type_translations nutrition_type_translations_nutrition_type_language_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_type_translations
    ADD CONSTRAINT nutrition_type_translations_nutrition_type_language_unique UNIQUE (nutrition_type_id, language_id);


--
-- Name: nutrition_type_translations nutrition_type_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_type_translations
    ADD CONSTRAINT nutrition_type_translations_pkey PRIMARY KEY (id);


--
-- Name: nutrition_types nutrition_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types
    ADD CONSTRAINT nutrition_types_code_unique UNIQUE (code);


--
-- Name: nutrition_types_history nutrition_types_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: nutrition_types_history nutrition_types_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_pkey PRIMARY KEY (id);


--
-- Name: nutrition_types nutrition_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types
    ADD CONSTRAINT nutrition_types_pkey PRIMARY KEY (id);


--
-- Name: package_types package_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_types
    ADD CONSTRAINT package_types_code_unique UNIQUE (code);


--
-- Name: package_types package_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_types
    ADD CONSTRAINT package_types_pkey PRIMARY KEY (id);


--
-- Name: permission_types permission_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_types
    ADD CONSTRAINT permission_types_code_unique UNIQUE (code);


--
-- Name: permission_types permission_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_types
    ADD CONSTRAINT permission_types_pkey PRIMARY KEY (id);


--
-- Name: product_allergens product_allergens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_allergens
    ADD CONSTRAINT product_allergens_pkey PRIMARY KEY (id);


--
-- Name: product_allergens product_allergens_subject_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_allergens
    ADD CONSTRAINT product_allergens_subject_unique UNIQUE (product_id, allergen_id, relationship_type_id);


--
-- Name: product_barcodes product_barcodes_association_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes
    ADD CONSTRAINT product_barcodes_association_unique UNIQUE (product_id, barcode_id, relationship_type_id);


--
-- Name: product_barcodes_history product_barcodes_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: product_barcodes_history product_barcodes_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_pkey PRIMARY KEY (id);


--
-- Name: product_barcodes product_barcodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes
    ADD CONSTRAINT product_barcodes_pkey PRIMARY KEY (id);


--
-- Name: product_categories product_categories_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_code_unique UNIQUE (code);


--
-- Name: product_categories_history product_categories_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories_history
    ADD CONSTRAINT product_categories_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: product_categories_history product_categories_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories_history
    ADD CONSTRAINT product_categories_history_pkey PRIMARY KEY (id);


--
-- Name: product_categories product_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);


--
-- Name: product_category_translations product_category_translations_category_language_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_category_translations
    ADD CONSTRAINT product_category_translations_category_language_unique UNIQUE (product_category_id, language_id);


--
-- Name: product_category_translations product_category_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_category_translations
    ADD CONSTRAINT product_category_translations_pkey PRIMARY KEY (id);


--
-- Name: product_health_evaluations product_health_evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_evaluations
    ADD CONSTRAINT product_health_evaluations_pkey PRIMARY KEY (id);


--
-- Name: product_health_flags product_health_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_flags
    ADD CONSTRAINT product_health_flags_pkey PRIMARY KEY (id);


--
-- Name: product_health_flags product_health_flags_subject_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_flags
    ADD CONSTRAINT product_health_flags_subject_unique UNIQUE (product_id, health_flag_id, relationship_type_id);


--
-- Name: product_images product_images_attachment_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_attachment_unique UNIQUE (product_id, image_id, relationship_type_id);


--
-- Name: product_images_history product_images_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: product_images_history product_images_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_pkey PRIMARY KEY (id);


--
-- Name: product_images product_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_pkey PRIMARY KEY (id);


--
-- Name: product_ingredients product_ingredients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_pkey PRIMARY KEY (id);


--
-- Name: product_ingredients product_ingredients_subject_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_subject_unique UNIQUE (product_id, ingredient_id, relationship_type_id);


--
-- Name: product_nutrition_values product_nutrition_values_fact_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_fact_unique UNIQUE (product_id, nutrition_type_id, relationship_type_id, measurement_basis_id);


--
-- Name: product_nutrition_values product_nutrition_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_pkey PRIMARY KEY (id);


--
-- Name: product_search_index product_search_index_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_search_index
    ADD CONSTRAINT product_search_index_pkey PRIMARY KEY (id);


--
-- Name: product_search_index product_search_index_product_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_search_index
    ADD CONSTRAINT product_search_index_product_id_unique UNIQUE (product_id);


--
-- Name: product_translations product_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_translations
    ADD CONSTRAINT product_translations_pkey PRIMARY KEY (id);


--
-- Name: product_translations product_translations_product_language_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_translations
    ADD CONSTRAINT product_translations_product_language_unique UNIQUE (product_id, language_id);


--
-- Name: products_history products_history_entity_version_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_entity_version_unique UNIQUE (original_entity_id, version_number);


--
-- Name: products_history products_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_pkey PRIMARY KEY (id);


--
-- Name: products products_internal_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_internal_code_unique UNIQUE (internal_code);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: regions regions_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT regions_code_unique UNIQUE (code);


--
-- Name: regions regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT regions_pkey PRIMARY KEY (id);


--
-- Name: regulatory_authorities regulatory_authorities_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulatory_authorities
    ADD CONSTRAINT regulatory_authorities_code_unique UNIQUE (code);


--
-- Name: regulatory_authorities regulatory_authorities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulatory_authorities
    ADD CONSTRAINT regulatory_authorities_pkey PRIMARY KEY (id);


--
-- Name: relationship_types relationship_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_types
    ADD CONSTRAINT relationship_types_code_unique UNIQUE (code);


--
-- Name: relationship_types relationship_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_types
    ADD CONSTRAINT relationship_types_pkey PRIMARY KEY (id);


--
-- Name: role_types role_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_types
    ADD CONSTRAINT role_types_code_unique UNIQUE (code);


--
-- Name: role_types role_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_types
    ADD CONSTRAINT role_types_pkey PRIMARY KEY (id);


--
-- Name: scan_job_items scan_job_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_job_items
    ADD CONSTRAINT scan_job_items_pkey PRIMARY KEY (id);


--
-- Name: scan_jobs scan_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_jobs
    ADD CONSTRAINT scan_jobs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: source_priorities source_priorities_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_priorities
    ADD CONSTRAINT source_priorities_code_unique UNIQUE (code);


--
-- Name: source_priorities source_priorities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_priorities
    ADD CONSTRAINT source_priorities_pkey PRIMARY KEY (id);


--
-- Name: source_priorities source_priorities_rank_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_priorities
    ADD CONSTRAINT source_priorities_rank_unique UNIQUE (rank);


--
-- Name: source_types source_types_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_types
    ADD CONSTRAINT source_types_code_unique UNIQUE (code);


--
-- Name: source_types source_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_types
    ADD CONSTRAINT source_types_pkey PRIMARY KEY (id);


--
-- Name: unit_conversions unit_conversions_from_unit_id_to_unit_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_conversions
    ADD CONSTRAINT unit_conversions_from_unit_id_to_unit_id_key UNIQUE (from_unit_id, to_unit_id);


--
-- Name: unit_conversions unit_conversions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_conversions
    ADD CONSTRAINT unit_conversions_pkey PRIMARY KEY (id);


--
-- Name: units units_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_code_unique UNIQUE (code);


--
-- Name: units units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);


--
-- Name: units units_symbol_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_symbol_unique UNIQUE (symbol);


--
-- Name: verification_statuses verification_statuses_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_statuses
    ADD CONSTRAINT verification_statuses_code_unique UNIQUE (code);


--
-- Name: verification_statuses verification_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_statuses
    ADD CONSTRAINT verification_statuses_pkey PRIMARY KEY (id);


--
-- Name: version_metadata version_metadata_key_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_metadata
    ADD CONSTRAINT version_metadata_key_unique UNIQUE (entity_version_id, key);


--
-- Name: version_metadata version_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_metadata
    ADD CONSTRAINT version_metadata_pkey PRIMARY KEY (id);


--
-- Name: allergen_translations_allergen_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergen_translations_allergen_id_idx ON public.allergen_translations USING btree (allergen_id);


--
-- Name: allergen_translations_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergen_translations_language_id_idx ON public.allergen_translations USING btree (language_id);


--
-- Name: allergen_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergen_types_status_id_idx ON public.allergen_types USING btree (status_id);


--
-- Name: allergens_allergen_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergens_allergen_type_id_idx ON public.allergens USING btree (allergen_type_id);


--
-- Name: allergens_history_allergen_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergens_history_allergen_type_id_idx ON public.allergens_history USING btree (allergen_type_id);


--
-- Name: allergens_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergens_history_change_set_id_idx ON public.allergens_history USING btree (change_set_id);


--
-- Name: allergens_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergens_history_original_entity_id_idx ON public.allergens_history USING btree (original_entity_id);


--
-- Name: allergens_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergens_history_previous_version_id_idx ON public.allergens_history USING btree (previous_version_id);


--
-- Name: allergens_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergens_history_source_id_idx ON public.allergens_history USING btree (source_id);


--
-- Name: allergens_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergens_history_status_id_idx ON public.allergens_history USING btree (status_id);


--
-- Name: allergens_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allergens_source_id_idx ON public.allergens USING btree (source_id);


--
-- Name: audit_context_role_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_context_role_id_idx ON public.audit_context USING btree (role_id);


--
-- Name: audit_event_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_event_types_status_id_idx ON public.audit_event_types USING btree (status_id);


--
-- Name: audit_events_audit_log_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_audit_log_id_idx ON public.audit_events USING btree (audit_log_id);


--
-- Name: audit_events_event_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_event_type_id_idx ON public.audit_events USING btree (event_type_id);


--
-- Name: audit_log_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_change_set_id_idx ON public.audit_log USING btree (change_set_id);


--
-- Name: audit_log_event_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_event_type_id_idx ON public.audit_log USING btree (event_type_id);


--
-- Name: audit_log_role_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_role_id_idx ON public.audit_log USING btree (role_id);


--
-- Name: barcode_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcode_types_status_id_idx ON public.barcode_types USING btree (status_id);


--
-- Name: barcodes_barcode_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_barcode_type_id_idx ON public.barcodes USING btree (barcode_type_id);


--
-- Name: barcodes_history_barcode_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_history_barcode_type_id_idx ON public.barcodes_history USING btree (barcode_type_id);


--
-- Name: barcodes_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_history_change_set_id_idx ON public.barcodes_history USING btree (change_set_id);


--
-- Name: barcodes_history_issued_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_history_issued_country_id_idx ON public.barcodes_history USING btree (issued_country_id);


--
-- Name: barcodes_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_history_original_entity_id_idx ON public.barcodes_history USING btree (original_entity_id);


--
-- Name: barcodes_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_history_previous_version_id_idx ON public.barcodes_history USING btree (previous_version_id);


--
-- Name: barcodes_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_history_source_id_idx ON public.barcodes_history USING btree (source_id);


--
-- Name: barcodes_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_history_status_id_idx ON public.barcodes_history USING btree (status_id);


--
-- Name: barcodes_history_verification_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_history_verification_status_id_idx ON public.barcodes_history USING btree (verification_status_id);


--
-- Name: barcodes_issued_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_issued_country_id_idx ON public.barcodes USING btree (issued_country_id);


--
-- Name: barcodes_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_source_id_idx ON public.barcodes USING btree (source_id);


--
-- Name: barcodes_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_status_id_idx ON public.barcodes USING btree (status_id);


--
-- Name: barcodes_verification_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX barcodes_verification_status_id_idx ON public.barcodes USING btree (verification_status_id);


--
-- Name: brand_search_index_search_name_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brand_search_index_search_name_trgm_idx ON public.brand_search_index USING gin (search_name public.gin_trgm_ops);


--
-- Name: brand_search_index_search_rank_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brand_search_index_search_rank_idx ON public.brand_search_index USING btree (search_rank DESC);


--
-- Name: brand_search_index_search_text_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brand_search_index_search_text_trgm_idx ON public.brand_search_index USING gin (search_text public.gin_trgm_ops);


--
-- Name: brand_search_index_search_tokens_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brand_search_index_search_tokens_idx ON public.brand_search_index USING gin (search_tokens);


--
-- Name: brand_translations_brand_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brand_translations_brand_id_idx ON public.brand_translations USING btree (brand_id);


--
-- Name: brand_translations_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brand_translations_language_id_idx ON public.brand_translations USING btree (language_id);


--
-- Name: brands_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brands_company_id_idx ON public.brands USING btree (company_id);


--
-- Name: brands_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brands_history_change_set_id_idx ON public.brands_history USING btree (change_set_id);


--
-- Name: brands_history_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brands_history_company_id_idx ON public.brands_history USING btree (company_id);


--
-- Name: brands_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brands_history_original_entity_id_idx ON public.brands_history USING btree (original_entity_id);


--
-- Name: brands_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brands_history_previous_version_id_idx ON public.brands_history USING btree (previous_version_id);


--
-- Name: brands_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brands_history_source_id_idx ON public.brands_history USING btree (source_id);


--
-- Name: brands_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brands_history_status_id_idx ON public.brands_history USING btree (status_id);


--
-- Name: brands_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brands_source_id_idx ON public.brands USING btree (source_id);


--
-- Name: change_sets_correlation_id_transaction_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX change_sets_correlation_id_transaction_id_idx ON public.change_sets USING btree (correlation_id, transaction_id);


--
-- Name: companies_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_history_change_set_id_idx ON public.companies_history USING btree (change_set_id);


--
-- Name: companies_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_history_original_entity_id_idx ON public.companies_history USING btree (original_entity_id);


--
-- Name: companies_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_history_previous_version_id_idx ON public.companies_history USING btree (previous_version_id);


--
-- Name: companies_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_history_source_id_idx ON public.companies_history USING btree (source_id);


--
-- Name: companies_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_history_status_id_idx ON public.companies_history USING btree (status_id);


--
-- Name: companies_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX companies_source_id_idx ON public.companies USING btree (source_id);


--
-- Name: company_search_index_search_name_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_search_index_search_name_trgm_idx ON public.company_search_index USING gin (search_name public.gin_trgm_ops);


--
-- Name: company_search_index_search_rank_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_search_index_search_rank_idx ON public.company_search_index USING btree (search_rank DESC);


--
-- Name: company_search_index_search_text_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_search_index_search_text_trgm_idx ON public.company_search_index USING gin (search_text public.gin_trgm_ops);


--
-- Name: company_search_index_search_tokens_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_search_index_search_tokens_idx ON public.company_search_index USING gin (search_tokens);


--
-- Name: company_translations_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_translations_company_id_idx ON public.company_translations USING btree (company_id);


--
-- Name: company_translations_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_translations_language_id_idx ON public.company_translations USING btree (language_id);


--
-- Name: countries_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX countries_status_id_idx ON public.countries USING btree (status_id);


--
-- Name: data_sources_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX data_sources_country_id_idx ON public.data_sources USING btree (country_id) WHERE (country_id IS NOT NULL);


--
-- Name: data_sources_priority_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX data_sources_priority_id_idx ON public.data_sources USING btree (priority_id);


--
-- Name: data_sources_source_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX data_sources_source_type_id_idx ON public.data_sources USING btree (source_type_id);


--
-- Name: data_sources_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX data_sources_status_id_idx ON public.data_sources USING btree (status_id);


--
-- Name: entity_relationships_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_relationships_evidence_type_id_idx ON public.entity_relationships USING btree (evidence_type_id);


--
-- Name: entity_relationships_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_relationships_relationship_type_id_idx ON public.entity_relationships USING btree (relationship_type_id);


--
-- Name: entity_relationships_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_relationships_source_id_idx ON public.entity_relationships USING btree (source_id);


--
-- Name: entity_relationships_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_relationships_status_id_idx ON public.entity_relationships USING btree (status_id);


--
-- Name: entity_versions_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_versions_change_set_id_idx ON public.entity_versions USING btree (change_set_id);


--
-- Name: entity_versions_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_versions_previous_version_id_idx ON public.entity_versions USING btree (previous_version_id);


--
-- Name: evidence_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX evidence_types_status_id_idx ON public.evidence_types USING btree (status_id);


--
-- Name: health_flag_translations_health_flag_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flag_translations_health_flag_id_idx ON public.health_flag_translations USING btree (health_flag_id);


--
-- Name: health_flag_translations_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flag_translations_language_id_idx ON public.health_flag_translations USING btree (language_id);


--
-- Name: health_flag_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flag_types_status_id_idx ON public.health_flag_types USING btree (status_id);


--
-- Name: health_flags_health_flag_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flags_health_flag_type_id_idx ON public.health_flags USING btree (health_flag_type_id);


--
-- Name: health_flags_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flags_history_change_set_id_idx ON public.health_flags_history USING btree (change_set_id);


--
-- Name: health_flags_history_health_flag_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flags_history_health_flag_type_id_idx ON public.health_flags_history USING btree (health_flag_type_id);


--
-- Name: health_flags_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flags_history_original_entity_id_idx ON public.health_flags_history USING btree (original_entity_id);


--
-- Name: health_flags_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flags_history_previous_version_id_idx ON public.health_flags_history USING btree (previous_version_id);


--
-- Name: health_flags_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flags_history_source_id_idx ON public.health_flags_history USING btree (source_id);


--
-- Name: health_flags_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flags_history_status_id_idx ON public.health_flags_history USING btree (status_id);


--
-- Name: health_flags_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX health_flags_source_id_idx ON public.health_flags USING btree (source_id);


--
-- Name: idx_conflicts_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conflicts_entity ON public.data_conflicts USING btree (entity_type, entity_id);


--
-- Name: idx_conflicts_resolution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conflicts_resolution ON public.data_conflicts USING btree (resolution);


--
-- Name: idx_conflicts_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_conflicts_status ON public.data_conflicts USING btree (status);


--
-- Name: idx_coverage_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coverage_company ON public.coverage_snapshots USING btree (company_id);


--
-- Name: idx_data_versions_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_data_versions_entity ON public.data_versions USING btree (entity_type, entity_id);


--
-- Name: idx_discovery_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_discovery_barcode ON public.discovery_candidates USING btree (barcode);


--
-- Name: idx_discovery_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_discovery_company ON public.discovery_candidates USING btree (company_id);


--
-- Name: idx_discovery_scan_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_discovery_scan_job ON public.discovery_candidates USING btree (scan_job_id);


--
-- Name: idx_discovery_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_discovery_status ON public.discovery_candidates USING btree (status);


--
-- Name: idx_halal_current; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_halal_current ON public.halal_evidence USING btree (product_id, is_current);


--
-- Name: idx_halal_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_halal_product ON public.halal_evidence USING btree (product_id);


--
-- Name: idx_health_eval_condition; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_health_eval_condition ON public.product_health_evaluations USING btree (condition_id);


--
-- Name: idx_health_eval_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_health_eval_product ON public.product_health_evaluations USING btree (product_id);


--
-- Name: idx_scan_job_items_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scan_job_items_job ON public.scan_job_items USING btree (scan_job_id);


--
-- Name: idx_scan_job_items_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scan_job_items_status ON public.scan_job_items USING btree (status);


--
-- Name: idx_scan_jobs_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scan_jobs_company ON public.scan_jobs USING btree (company_id);


--
-- Name: idx_scan_jobs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scan_jobs_status ON public.scan_jobs USING btree (status);


--
-- Name: idx_unit_conv_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_unit_conv_from ON public.unit_conversions USING btree (from_unit_id);


--
-- Name: image_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX image_types_status_id_idx ON public.image_types USING btree (status_id);


--
-- Name: images_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_history_change_set_id_idx ON public.images_history USING btree (change_set_id);


--
-- Name: images_history_image_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_history_image_type_id_idx ON public.images_history USING btree (image_type_id);


--
-- Name: images_history_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_history_language_id_idx ON public.images_history USING btree (language_id);


--
-- Name: images_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_history_original_entity_id_idx ON public.images_history USING btree (original_entity_id);


--
-- Name: images_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_history_previous_version_id_idx ON public.images_history USING btree (previous_version_id);


--
-- Name: images_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_history_source_id_idx ON public.images_history USING btree (source_id);


--
-- Name: images_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_history_status_id_idx ON public.images_history USING btree (status_id);


--
-- Name: images_image_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_image_type_id_idx ON public.images USING btree (image_type_id);


--
-- Name: images_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_language_id_idx ON public.images USING btree (language_id);


--
-- Name: images_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_source_id_idx ON public.images USING btree (source_id);


--
-- Name: images_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX images_status_id_idx ON public.images USING btree (status_id);


--
-- Name: ingredient_aliases_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_aliases_evidence_type_id_idx ON public.ingredient_aliases USING btree (evidence_type_id);


--
-- Name: ingredient_aliases_ingredient_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_aliases_ingredient_id_idx ON public.ingredient_aliases USING btree (ingredient_id);


--
-- Name: ingredient_aliases_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_aliases_language_id_idx ON public.ingredient_aliases USING btree (language_id);


--
-- Name: ingredient_aliases_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_aliases_relationship_type_id_idx ON public.ingredient_aliases USING btree (relationship_type_id);


--
-- Name: ingredient_aliases_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_aliases_source_id_idx ON public.ingredient_aliases USING btree (source_id);


--
-- Name: ingredient_aliases_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_aliases_status_id_idx ON public.ingredient_aliases USING btree (status_id);


--
-- Name: ingredient_allergens_allergen_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_allergens_allergen_id_idx ON public.ingredient_allergens USING btree (allergen_id);


--
-- Name: ingredient_allergens_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_allergens_evidence_type_id_idx ON public.ingredient_allergens USING btree (evidence_type_id);


--
-- Name: ingredient_allergens_ingredient_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_allergens_ingredient_id_idx ON public.ingredient_allergens USING btree (ingredient_id);


--
-- Name: ingredient_allergens_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_allergens_relationship_type_id_idx ON public.ingredient_allergens USING btree (relationship_type_id);


--
-- Name: ingredient_allergens_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_allergens_source_id_idx ON public.ingredient_allergens USING btree (source_id);


--
-- Name: ingredient_allergens_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_allergens_status_id_idx ON public.ingredient_allergens USING btree (status_id);


--
-- Name: ingredient_categories_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_categories_history_change_set_id_idx ON public.ingredient_categories_history USING btree (change_set_id);


--
-- Name: ingredient_categories_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_categories_history_original_entity_id_idx ON public.ingredient_categories_history USING btree (original_entity_id);


--
-- Name: ingredient_categories_history_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_categories_history_parent_id_idx ON public.ingredient_categories_history USING btree (parent_id);


--
-- Name: ingredient_categories_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_categories_history_previous_version_id_idx ON public.ingredient_categories_history USING btree (previous_version_id);


--
-- Name: ingredient_categories_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_categories_history_source_id_idx ON public.ingredient_categories_history USING btree (source_id);


--
-- Name: ingredient_categories_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_categories_history_status_id_idx ON public.ingredient_categories_history USING btree (status_id);


--
-- Name: ingredient_categories_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_categories_parent_id_idx ON public.ingredient_categories USING btree (parent_id);


--
-- Name: ingredient_categories_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_categories_status_id_idx ON public.ingredient_categories USING btree (status_id);


--
-- Name: ingredient_health_flags_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_health_flags_evidence_type_id_idx ON public.ingredient_health_flags USING btree (evidence_type_id);


--
-- Name: ingredient_health_flags_health_flag_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_health_flags_health_flag_id_idx ON public.ingredient_health_flags USING btree (health_flag_id);


--
-- Name: ingredient_health_flags_ingredient_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_health_flags_ingredient_id_idx ON public.ingredient_health_flags USING btree (ingredient_id);


--
-- Name: ingredient_health_flags_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_health_flags_relationship_type_id_idx ON public.ingredient_health_flags USING btree (relationship_type_id);


--
-- Name: ingredient_health_flags_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_health_flags_source_id_idx ON public.ingredient_health_flags USING btree (source_id);


--
-- Name: ingredient_health_flags_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_health_flags_status_id_idx ON public.ingredient_health_flags USING btree (status_id);


--
-- Name: ingredient_search_index_search_name_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_search_index_search_name_trgm_idx ON public.ingredient_search_index USING gin (search_name public.gin_trgm_ops);


--
-- Name: ingredient_search_index_search_rank_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_search_index_search_rank_idx ON public.ingredient_search_index USING btree (search_rank DESC);


--
-- Name: ingredient_search_index_search_text_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_search_index_search_text_trgm_idx ON public.ingredient_search_index USING gin (search_text public.gin_trgm_ops);


--
-- Name: ingredient_search_index_search_tokens_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_search_index_search_tokens_idx ON public.ingredient_search_index USING gin (search_tokens);


--
-- Name: ingredient_translations_ingredient_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_translations_ingredient_id_idx ON public.ingredient_translations USING btree (ingredient_id);


--
-- Name: ingredient_translations_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredient_translations_language_id_idx ON public.ingredient_translations USING btree (language_id);


--
-- Name: ingredients_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredients_history_change_set_id_idx ON public.ingredients_history USING btree (change_set_id);


--
-- Name: ingredients_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredients_history_original_entity_id_idx ON public.ingredients_history USING btree (original_entity_id);


--
-- Name: ingredients_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredients_history_previous_version_id_idx ON public.ingredients_history USING btree (previous_version_id);


--
-- Name: ingredients_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredients_history_source_id_idx ON public.ingredients_history USING btree (source_id);


--
-- Name: ingredients_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredients_history_status_id_idx ON public.ingredients_history USING btree (status_id);


--
-- Name: ingredients_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingredients_source_id_idx ON public.ingredients USING btree (source_id);


--
-- Name: languages_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX languages_status_id_idx ON public.languages USING btree (status_id);


--
-- Name: measurement_bases_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX measurement_bases_status_id_idx ON public.measurement_bases USING btree (status_id);


--
-- Name: nutrition_type_translations_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nutrition_type_translations_language_id_idx ON public.nutrition_type_translations USING btree (language_id);


--
-- Name: nutrition_type_translations_nutrition_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nutrition_type_translations_nutrition_type_id_idx ON public.nutrition_type_translations USING btree (nutrition_type_id);


--
-- Name: nutrition_types_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nutrition_types_history_change_set_id_idx ON public.nutrition_types_history USING btree (change_set_id);


--
-- Name: nutrition_types_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nutrition_types_history_original_entity_id_idx ON public.nutrition_types_history USING btree (original_entity_id);


--
-- Name: nutrition_types_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nutrition_types_history_previous_version_id_idx ON public.nutrition_types_history USING btree (previous_version_id);


--
-- Name: nutrition_types_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nutrition_types_history_source_id_idx ON public.nutrition_types_history USING btree (source_id);


--
-- Name: nutrition_types_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nutrition_types_history_status_id_idx ON public.nutrition_types_history USING btree (status_id);


--
-- Name: nutrition_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nutrition_types_status_id_idx ON public.nutrition_types USING btree (status_id);


--
-- Name: package_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX package_types_status_id_idx ON public.package_types USING btree (status_id);


--
-- Name: permission_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX permission_types_status_id_idx ON public.permission_types USING btree (status_id);


--
-- Name: product_allergens_allergen_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_allergens_allergen_id_idx ON public.product_allergens USING btree (allergen_id);


--
-- Name: product_allergens_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_allergens_evidence_type_id_idx ON public.product_allergens USING btree (evidence_type_id);


--
-- Name: product_allergens_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_allergens_product_id_idx ON public.product_allergens USING btree (product_id);


--
-- Name: product_allergens_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_allergens_relationship_type_id_idx ON public.product_allergens USING btree (relationship_type_id);


--
-- Name: product_allergens_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_allergens_source_id_idx ON public.product_allergens USING btree (source_id);


--
-- Name: product_allergens_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_allergens_status_id_idx ON public.product_allergens USING btree (status_id);


--
-- Name: product_barcodes_barcode_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_barcode_id_idx ON public.product_barcodes USING btree (barcode_id);


--
-- Name: product_barcodes_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_evidence_type_id_idx ON public.product_barcodes USING btree (evidence_type_id);


--
-- Name: product_barcodes_history_barcode_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_barcode_id_idx ON public.product_barcodes_history USING btree (barcode_id);


--
-- Name: product_barcodes_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_change_set_id_idx ON public.product_barcodes_history USING btree (change_set_id);


--
-- Name: product_barcodes_history_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_evidence_type_id_idx ON public.product_barcodes_history USING btree (evidence_type_id);


--
-- Name: product_barcodes_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_original_entity_id_idx ON public.product_barcodes_history USING btree (original_entity_id);


--
-- Name: product_barcodes_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_previous_version_id_idx ON public.product_barcodes_history USING btree (previous_version_id);


--
-- Name: product_barcodes_history_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_product_id_idx ON public.product_barcodes_history USING btree (product_id);


--
-- Name: product_barcodes_history_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_relationship_type_id_idx ON public.product_barcodes_history USING btree (relationship_type_id);


--
-- Name: product_barcodes_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_source_id_idx ON public.product_barcodes_history USING btree (source_id);


--
-- Name: product_barcodes_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_history_status_id_idx ON public.product_barcodes_history USING btree (status_id);


--
-- Name: product_barcodes_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_product_id_idx ON public.product_barcodes USING btree (product_id);


--
-- Name: product_barcodes_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_relationship_type_id_idx ON public.product_barcodes USING btree (relationship_type_id);


--
-- Name: product_barcodes_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_source_id_idx ON public.product_barcodes USING btree (source_id);


--
-- Name: product_barcodes_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_barcodes_status_id_idx ON public.product_barcodes USING btree (status_id);


--
-- Name: product_categories_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_history_change_set_id_idx ON public.product_categories_history USING btree (change_set_id);


--
-- Name: product_categories_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_history_original_entity_id_idx ON public.product_categories_history USING btree (original_entity_id);


--
-- Name: product_categories_history_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_history_parent_id_idx ON public.product_categories_history USING btree (parent_id);


--
-- Name: product_categories_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_history_previous_version_id_idx ON public.product_categories_history USING btree (previous_version_id);


--
-- Name: product_categories_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_history_source_id_idx ON public.product_categories_history USING btree (source_id);


--
-- Name: product_categories_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_history_status_id_idx ON public.product_categories_history USING btree (status_id);


--
-- Name: product_categories_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_parent_id_idx ON public.product_categories USING btree (parent_id);


--
-- Name: product_categories_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_status_id_idx ON public.product_categories USING btree (status_id);


--
-- Name: product_category_translations_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_category_translations_language_id_idx ON public.product_category_translations USING btree (language_id);


--
-- Name: product_category_translations_product_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_category_translations_product_category_id_idx ON public.product_category_translations USING btree (product_category_id);


--
-- Name: product_health_flags_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_health_flags_evidence_type_id_idx ON public.product_health_flags USING btree (evidence_type_id);


--
-- Name: product_health_flags_health_flag_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_health_flags_health_flag_id_idx ON public.product_health_flags USING btree (health_flag_id);


--
-- Name: product_health_flags_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_health_flags_product_id_idx ON public.product_health_flags USING btree (product_id);


--
-- Name: product_health_flags_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_health_flags_relationship_type_id_idx ON public.product_health_flags USING btree (relationship_type_id);


--
-- Name: product_health_flags_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_health_flags_source_id_idx ON public.product_health_flags USING btree (source_id);


--
-- Name: product_health_flags_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_health_flags_status_id_idx ON public.product_health_flags USING btree (status_id);


--
-- Name: product_images_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_evidence_type_id_idx ON public.product_images USING btree (evidence_type_id);


--
-- Name: product_images_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_change_set_id_idx ON public.product_images_history USING btree (change_set_id);


--
-- Name: product_images_history_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_evidence_type_id_idx ON public.product_images_history USING btree (evidence_type_id);


--
-- Name: product_images_history_image_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_image_id_idx ON public.product_images_history USING btree (image_id);


--
-- Name: product_images_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_original_entity_id_idx ON public.product_images_history USING btree (original_entity_id);


--
-- Name: product_images_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_previous_version_id_idx ON public.product_images_history USING btree (previous_version_id);


--
-- Name: product_images_history_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_product_id_idx ON public.product_images_history USING btree (product_id);


--
-- Name: product_images_history_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_relationship_type_id_idx ON public.product_images_history USING btree (relationship_type_id);


--
-- Name: product_images_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_source_id_idx ON public.product_images_history USING btree (source_id);


--
-- Name: product_images_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_history_status_id_idx ON public.product_images_history USING btree (status_id);


--
-- Name: product_images_image_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_image_id_idx ON public.product_images USING btree (image_id);


--
-- Name: product_images_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_product_id_idx ON public.product_images USING btree (product_id);


--
-- Name: product_images_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_relationship_type_id_idx ON public.product_images USING btree (relationship_type_id);


--
-- Name: product_images_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_source_id_idx ON public.product_images USING btree (source_id);


--
-- Name: product_images_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_images_status_id_idx ON public.product_images USING btree (status_id);


--
-- Name: product_ingredients_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_ingredients_evidence_type_id_idx ON public.product_ingredients USING btree (evidence_type_id);


--
-- Name: product_ingredients_ingredient_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_ingredients_ingredient_id_idx ON public.product_ingredients USING btree (ingredient_id);


--
-- Name: product_ingredients_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_ingredients_product_id_idx ON public.product_ingredients USING btree (product_id);


--
-- Name: product_ingredients_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_ingredients_relationship_type_id_idx ON public.product_ingredients USING btree (relationship_type_id);


--
-- Name: product_ingredients_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_ingredients_source_id_idx ON public.product_ingredients USING btree (source_id);


--
-- Name: product_ingredients_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_ingredients_status_id_idx ON public.product_ingredients USING btree (status_id);


--
-- Name: product_ingredients_unit_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_ingredients_unit_id_idx ON public.product_ingredients USING btree (unit_id);


--
-- Name: product_nutrition_values_evidence_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_nutrition_values_evidence_type_id_idx ON public.product_nutrition_values USING btree (evidence_type_id);


--
-- Name: product_nutrition_values_measurement_basis_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_nutrition_values_measurement_basis_id_idx ON public.product_nutrition_values USING btree (measurement_basis_id);


--
-- Name: product_nutrition_values_nutrition_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_nutrition_values_nutrition_type_id_idx ON public.product_nutrition_values USING btree (nutrition_type_id);


--
-- Name: product_nutrition_values_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_nutrition_values_product_id_idx ON public.product_nutrition_values USING btree (product_id);


--
-- Name: product_nutrition_values_relationship_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_nutrition_values_relationship_type_id_idx ON public.product_nutrition_values USING btree (relationship_type_id);


--
-- Name: product_nutrition_values_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_nutrition_values_source_id_idx ON public.product_nutrition_values USING btree (source_id);


--
-- Name: product_nutrition_values_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_nutrition_values_status_id_idx ON public.product_nutrition_values USING btree (status_id);


--
-- Name: product_nutrition_values_unit_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_nutrition_values_unit_id_idx ON public.product_nutrition_values USING btree (unit_id);


--
-- Name: product_search_index_search_name_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_search_index_search_name_trgm_idx ON public.product_search_index USING gin (search_name public.gin_trgm_ops);


--
-- Name: product_search_index_search_rank_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_search_index_search_rank_idx ON public.product_search_index USING btree (search_rank DESC);


--
-- Name: product_search_index_search_text_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_search_index_search_text_trgm_idx ON public.product_search_index USING gin (search_text public.gin_trgm_ops);


--
-- Name: product_search_index_search_tokens_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_search_index_search_tokens_idx ON public.product_search_index USING gin (search_tokens);


--
-- Name: product_translations_language_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_translations_language_id_idx ON public.product_translations USING btree (language_id);


--
-- Name: product_translations_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_translations_product_id_idx ON public.product_translations USING btree (product_id);


--
-- Name: products_brand_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_brand_id_idx ON public.products USING btree (brand_id);


--
-- Name: products_history_brand_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_history_brand_id_idx ON public.products_history USING btree (brand_id);


--
-- Name: products_history_change_set_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_history_change_set_id_idx ON public.products_history USING btree (change_set_id);


--
-- Name: products_history_original_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_history_original_entity_id_idx ON public.products_history USING btree (original_entity_id);


--
-- Name: products_history_previous_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_history_previous_version_id_idx ON public.products_history USING btree (previous_version_id);


--
-- Name: products_history_product_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_history_product_category_id_idx ON public.products_history USING btree (product_category_id);


--
-- Name: products_history_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_history_source_id_idx ON public.products_history USING btree (source_id);


--
-- Name: products_history_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_history_status_id_idx ON public.products_history USING btree (status_id);


--
-- Name: products_product_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_product_category_id_idx ON public.products USING btree (product_category_id);


--
-- Name: products_source_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_source_id_idx ON public.products USING btree (source_id);


--
-- Name: regions_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX regions_status_id_idx ON public.regions USING btree (status_id);


--
-- Name: regulatory_authorities_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX regulatory_authorities_status_id_idx ON public.regulatory_authorities USING btree (status_id);


--
-- Name: relationship_types_inverse_type_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX relationship_types_inverse_type_id_idx ON public.relationship_types USING btree (inverse_type_id) WHERE (inverse_type_id IS NOT NULL);


--
-- Name: relationship_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX relationship_types_status_id_idx ON public.relationship_types USING btree (status_id);


--
-- Name: role_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX role_types_status_id_idx ON public.role_types USING btree (status_id);


--
-- Name: source_priorities_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX source_priorities_status_id_idx ON public.source_priorities USING btree (status_id);


--
-- Name: source_types_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX source_types_status_id_idx ON public.source_types USING btree (status_id);


--
-- Name: units_one_base_unit_per_dimension_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX units_one_base_unit_per_dimension_idx ON public.units USING btree (dimension) WHERE is_base_unit;


--
-- Name: units_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX units_status_id_idx ON public.units USING btree (status_id);


--
-- Name: verification_statuses_status_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX verification_statuses_status_id_idx ON public.verification_statuses USING btree (status_id);


--
-- Name: version_metadata_entity_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX version_metadata_entity_version_id_idx ON public.version_metadata USING btree (entity_version_id);


--
-- Name: allergen_translations allergen_translations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER allergen_translations_set_updated_at BEFORE UPDATE ON public.allergen_translations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: allergen_types allergen_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER allergen_types_set_updated_at BEFORE UPDATE ON public.allergen_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: allergens allergens_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER allergens_capture_history BEFORE INSERT OR UPDATE ON public.allergens FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: allergens_history allergens_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER allergens_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.allergens_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: allergens allergens_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER allergens_set_updated_at BEFORE UPDATE ON public.allergens FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: audit_context audit_context_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_context_set_updated_at BEFORE UPDATE ON public.audit_context FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: audit_event_types audit_event_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_event_types_set_updated_at BEFORE UPDATE ON public.audit_event_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: audit_events audit_events_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_set_updated_at BEFORE UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: audit_log audit_log_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_log_set_updated_at BEFORE UPDATE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: barcode_types barcode_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER barcode_types_set_updated_at BEFORE UPDATE ON public.barcode_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: barcodes barcodes_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER barcodes_capture_history BEFORE INSERT OR UPDATE ON public.barcodes FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: barcodes_history barcodes_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER barcodes_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.barcodes_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: barcodes barcodes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER barcodes_set_updated_at BEFORE UPDATE ON public.barcodes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: brand_translations brand_translations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER brand_translations_set_updated_at BEFORE UPDATE ON public.brand_translations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: brands brands_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER brands_capture_history AFTER INSERT OR UPDATE ON public.brands DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: brands_history brands_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER brands_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.brands_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: brands brands_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER brands_set_updated_at BEFORE UPDATE ON public.brands FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: change_sets change_sets_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER change_sets_set_updated_at BEFORE UPDATE ON public.change_sets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: companies companies_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER companies_capture_history BEFORE INSERT OR UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: companies_history companies_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER companies_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.companies_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: companies companies_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER companies_set_updated_at BEFORE UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: company_translations company_translations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER company_translations_set_updated_at BEFORE UPDATE ON public.company_translations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: countries countries_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER countries_set_updated_at BEFORE UPDATE ON public.countries FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: data_sources data_sources_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER data_sources_set_updated_at BEFORE UPDATE ON public.data_sources FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entity_relationships entity_relationships_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entity_relationships_set_updated_at BEFORE UPDATE ON public.entity_relationships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: entity_relationships entity_relationships_validate_endpoints; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entity_relationships_validate_endpoints BEFORE INSERT OR UPDATE ON public.entity_relationships FOR EACH ROW EXECUTE FUNCTION public.validate_entity_relationship_endpoints();


--
-- Name: entity_versions entity_versions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entity_versions_set_updated_at BEFORE UPDATE ON public.entity_versions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: evidence_types evidence_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER evidence_types_set_updated_at BEFORE UPDATE ON public.evidence_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: health_flag_translations health_flag_translations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER health_flag_translations_set_updated_at BEFORE UPDATE ON public.health_flag_translations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: health_flag_types health_flag_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER health_flag_types_set_updated_at BEFORE UPDATE ON public.health_flag_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: health_flags health_flags_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER health_flags_capture_history BEFORE INSERT OR UPDATE ON public.health_flags FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: health_flags_history health_flags_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER health_flags_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.health_flags_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: health_flags health_flags_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER health_flags_set_updated_at BEFORE UPDATE ON public.health_flags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: image_types image_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER image_types_set_updated_at BEFORE UPDATE ON public.image_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: images images_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER images_capture_history BEFORE INSERT OR UPDATE ON public.images FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: images_history images_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER images_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.images_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: images images_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER images_set_updated_at BEFORE UPDATE ON public.images FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ingredient_aliases ingredient_aliases_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredient_aliases_set_updated_at BEFORE UPDATE ON public.ingredient_aliases FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ingredient_allergens ingredient_allergens_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredient_allergens_set_updated_at BEFORE UPDATE ON public.ingredient_allergens FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ingredient_categories ingredient_categories_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredient_categories_capture_history BEFORE INSERT OR UPDATE ON public.ingredient_categories FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: ingredient_categories_history ingredient_categories_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredient_categories_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.ingredient_categories_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: ingredient_categories ingredient_categories_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredient_categories_set_updated_at BEFORE UPDATE ON public.ingredient_categories FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ingredient_health_flags ingredient_health_flags_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredient_health_flags_set_updated_at BEFORE UPDATE ON public.ingredient_health_flags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ingredient_translations ingredient_translations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredient_translations_set_updated_at BEFORE UPDATE ON public.ingredient_translations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ingredients ingredients_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredients_capture_history BEFORE INSERT OR UPDATE ON public.ingredients FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: ingredients_history ingredients_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredients_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.ingredients_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: ingredients ingredients_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ingredients_set_updated_at BEFORE UPDATE ON public.ingredients FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: languages languages_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER languages_set_updated_at BEFORE UPDATE ON public.languages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: lifecycle_statuses lifecycle_statuses_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lifecycle_statuses_set_updated_at BEFORE UPDATE ON public.lifecycle_statuses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: measurement_bases measurement_bases_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER measurement_bases_set_updated_at BEFORE UPDATE ON public.measurement_bases FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: nutrition_type_translations nutrition_type_translations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nutrition_type_translations_set_updated_at BEFORE UPDATE ON public.nutrition_type_translations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: nutrition_types nutrition_types_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nutrition_types_capture_history BEFORE INSERT OR UPDATE ON public.nutrition_types FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: nutrition_types_history nutrition_types_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nutrition_types_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.nutrition_types_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: nutrition_types nutrition_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nutrition_types_set_updated_at BEFORE UPDATE ON public.nutrition_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: package_types package_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER package_types_set_updated_at BEFORE UPDATE ON public.package_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: permission_types permission_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER permission_types_set_updated_at BEFORE UPDATE ON public.permission_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_allergens product_allergens_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_allergens_set_updated_at BEFORE UPDATE ON public.product_allergens FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_barcodes product_barcodes_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_barcodes_capture_history BEFORE INSERT OR UPDATE ON public.product_barcodes FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: product_barcodes_history product_barcodes_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_barcodes_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.product_barcodes_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: product_barcodes product_barcodes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_barcodes_set_updated_at BEFORE UPDATE ON public.product_barcodes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_categories product_categories_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_categories_capture_history BEFORE INSERT OR UPDATE ON public.product_categories FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: product_categories_history product_categories_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_categories_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.product_categories_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: product_categories product_categories_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_categories_set_updated_at BEFORE UPDATE ON public.product_categories FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_category_translations product_category_translations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_category_translations_set_updated_at BEFORE UPDATE ON public.product_category_translations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_health_flags product_health_flags_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_health_flags_set_updated_at BEFORE UPDATE ON public.product_health_flags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_images product_images_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_images_capture_history BEFORE INSERT OR UPDATE ON public.product_images FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: product_images_history product_images_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_images_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.product_images_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: product_images product_images_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_images_set_updated_at BEFORE UPDATE ON public.product_images FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_ingredients product_ingredients_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_ingredients_set_updated_at BEFORE UPDATE ON public.product_ingredients FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_nutrition_values product_nutrition_values_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_nutrition_values_set_updated_at BEFORE UPDATE ON public.product_nutrition_values FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_translations product_translations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_translations_set_updated_at BEFORE UPDATE ON public.product_translations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: products products_capture_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER products_capture_history BEFORE INSERT OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.capture_entity_history();


--
-- Name: products_history products_history_prevent_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER products_history_prevent_mutation BEFORE DELETE OR UPDATE ON public.products_history FOR EACH ROW EXECUTE FUNCTION public.prevent_history_mutation();


--
-- Name: products products_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER products_set_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: regions regions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER regions_set_updated_at BEFORE UPDATE ON public.regions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: regulatory_authorities regulatory_authorities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER regulatory_authorities_set_updated_at BEFORE UPDATE ON public.regulatory_authorities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: relationship_types relationship_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER relationship_types_set_updated_at BEFORE UPDATE ON public.relationship_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: role_types role_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER role_types_set_updated_at BEFORE UPDATE ON public.role_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: source_priorities source_priorities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER source_priorities_set_updated_at BEFORE UPDATE ON public.source_priorities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: source_types source_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER source_types_set_updated_at BEFORE UPDATE ON public.source_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: units units_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER units_set_updated_at BEFORE UPDATE ON public.units FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: verification_statuses verification_statuses_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER verification_statuses_set_updated_at BEFORE UPDATE ON public.verification_statuses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: version_metadata version_metadata_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER version_metadata_set_updated_at BEFORE UPDATE ON public.version_metadata FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: allergen_translations allergen_translations_allergen_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergen_translations
    ADD CONSTRAINT allergen_translations_allergen_id_fk FOREIGN KEY (allergen_id) REFERENCES public.allergens(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergen_translations allergen_translations_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergen_translations
    ADD CONSTRAINT allergen_translations_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergen_types allergen_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergen_types
    ADD CONSTRAINT allergen_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergens allergens_allergen_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens
    ADD CONSTRAINT allergens_allergen_type_id_fk FOREIGN KEY (allergen_type_id) REFERENCES public.allergen_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergens_history allergens_history_allergen_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens_history
    ADD CONSTRAINT allergens_history_allergen_type_id_fk FOREIGN KEY (allergen_type_id) REFERENCES public.allergen_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergens_history allergens_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens_history
    ADD CONSTRAINT allergens_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergens_history allergens_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens_history
    ADD CONSTRAINT allergens_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.allergens(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: allergens_history allergens_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens_history
    ADD CONSTRAINT allergens_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.allergens_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergens_history allergens_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens_history
    ADD CONSTRAINT allergens_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergens_history allergens_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens_history
    ADD CONSTRAINT allergens_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergens allergens_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens
    ADD CONSTRAINT allergens_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: allergens allergens_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergens
    ADD CONSTRAINT allergens_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: audit_context audit_context_role_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_context
    ADD CONSTRAINT audit_context_role_id_fk FOREIGN KEY (role_id) REFERENCES public.role_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: audit_event_types audit_event_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_event_types
    ADD CONSTRAINT audit_event_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: audit_events audit_events_audit_log_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_audit_log_id_fk FOREIGN KEY (audit_log_id) REFERENCES public.audit_log(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: audit_events audit_events_event_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_event_type_id_fk FOREIGN KEY (event_type_id) REFERENCES public.audit_event_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: audit_log audit_log_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: audit_log audit_log_event_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_event_type_id_fk FOREIGN KEY (event_type_id) REFERENCES public.audit_event_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: audit_log audit_log_role_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_role_id_fk FOREIGN KEY (role_id) REFERENCES public.role_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcode_types barcode_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcode_types
    ADD CONSTRAINT barcode_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes barcodes_barcode_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes
    ADD CONSTRAINT barcodes_barcode_type_id_fk FOREIGN KEY (barcode_type_id) REFERENCES public.barcode_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes_history barcodes_history_barcode_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_barcode_type_id_fk FOREIGN KEY (barcode_type_id) REFERENCES public.barcode_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes_history barcodes_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes_history barcodes_history_issued_country_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_issued_country_id_fk FOREIGN KEY (issued_country_id) REFERENCES public.countries(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes_history barcodes_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.barcodes(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: barcodes_history barcodes_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.barcodes_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes_history barcodes_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes_history barcodes_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes_history barcodes_history_verification_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes_history
    ADD CONSTRAINT barcodes_history_verification_status_id_fk FOREIGN KEY (verification_status_id) REFERENCES public.verification_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes barcodes_issued_country_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes
    ADD CONSTRAINT barcodes_issued_country_id_fk FOREIGN KEY (issued_country_id) REFERENCES public.countries(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes barcodes_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes
    ADD CONSTRAINT barcodes_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes barcodes_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes
    ADD CONSTRAINT barcodes_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: barcodes barcodes_verification_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.barcodes
    ADD CONSTRAINT barcodes_verification_status_id_fk FOREIGN KEY (verification_status_id) REFERENCES public.verification_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brand_translations brand_translations_brand_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_translations
    ADD CONSTRAINT brand_translations_brand_id_fk FOREIGN KEY (brand_id) REFERENCES public.brands(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brand_translations brand_translations_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brand_translations
    ADD CONSTRAINT brand_translations_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brands brands_company_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_company_id_fk FOREIGN KEY (company_id) REFERENCES public.companies(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brands_history brands_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands_history
    ADD CONSTRAINT brands_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brands_history brands_history_company_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands_history
    ADD CONSTRAINT brands_history_company_id_fk FOREIGN KEY (company_id) REFERENCES public.companies(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brands_history brands_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands_history
    ADD CONSTRAINT brands_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.brands(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: brands_history brands_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands_history
    ADD CONSTRAINT brands_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.brands_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brands_history brands_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands_history
    ADD CONSTRAINT brands_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brands_history brands_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands_history
    ADD CONSTRAINT brands_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brands brands_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: brands brands_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: change_sets change_sets_audit_context_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_sets
    ADD CONSTRAINT change_sets_audit_context_fk FOREIGN KEY (correlation_id, transaction_id) REFERENCES public.audit_context(correlation_id, transaction_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: companies_history companies_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies_history
    ADD CONSTRAINT companies_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: companies_history companies_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies_history
    ADD CONSTRAINT companies_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.companies(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: companies_history companies_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies_history
    ADD CONSTRAINT companies_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.companies_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: companies_history companies_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies_history
    ADD CONSTRAINT companies_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: companies_history companies_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies_history
    ADD CONSTRAINT companies_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: companies companies_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: companies companies_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: company_translations company_translations_company_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_translations
    ADD CONSTRAINT company_translations_company_id_fk FOREIGN KEY (company_id) REFERENCES public.companies(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: company_translations company_translations_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_translations
    ADD CONSTRAINT company_translations_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: condition_nutrition_rules condition_nutrition_rules_condition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.condition_nutrition_rules
    ADD CONSTRAINT condition_nutrition_rules_condition_id_fkey FOREIGN KEY (condition_id) REFERENCES public.health_conditions(id);


--
-- Name: countries countries_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: coverage_snapshots coverage_snapshots_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_snapshots
    ADD CONSTRAINT coverage_snapshots_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: coverage_snapshots coverage_snapshots_scan_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_snapshots
    ADD CONSTRAINT coverage_snapshots_scan_job_id_fkey FOREIGN KEY (scan_job_id) REFERENCES public.scan_jobs(id);


--
-- Name: data_sources data_sources_country_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_country_id_fk FOREIGN KEY (country_id) REFERENCES public.countries(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: data_sources data_sources_priority_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_priority_id_fk FOREIGN KEY (priority_id) REFERENCES public.source_priorities(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: data_sources data_sources_source_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_source_type_id_fk FOREIGN KEY (source_type_id) REFERENCES public.source_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: data_sources data_sources_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: discovery_candidates discovery_candidates_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discovery_candidates
    ADD CONSTRAINT discovery_candidates_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: discovery_candidates discovery_candidates_matched_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discovery_candidates
    ADD CONSTRAINT discovery_candidates_matched_product_id_fkey FOREIGN KEY (matched_product_id) REFERENCES public.products(id);


--
-- Name: entity_relationships entity_relationships_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relationships
    ADD CONSTRAINT entity_relationships_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: entity_relationships entity_relationships_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relationships
    ADD CONSTRAINT entity_relationships_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: entity_relationships entity_relationships_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relationships
    ADD CONSTRAINT entity_relationships_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: entity_relationships entity_relationships_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relationships
    ADD CONSTRAINT entity_relationships_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: entity_versions entity_versions_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_versions
    ADD CONSTRAINT entity_versions_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: entity_versions entity_versions_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_versions
    ADD CONSTRAINT entity_versions_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.entity_versions(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: evidence_types evidence_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidence_types
    ADD CONSTRAINT evidence_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: halal_evidence halal_evidence_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.halal_evidence
    ADD CONSTRAINT halal_evidence_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: health_flag_translations health_flag_translations_health_flag_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flag_translations
    ADD CONSTRAINT health_flag_translations_health_flag_id_fk FOREIGN KEY (health_flag_id) REFERENCES public.health_flags(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flag_translations health_flag_translations_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flag_translations
    ADD CONSTRAINT health_flag_translations_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flag_types health_flag_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flag_types
    ADD CONSTRAINT health_flag_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flags health_flags_health_flag_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags
    ADD CONSTRAINT health_flags_health_flag_type_id_fk FOREIGN KEY (health_flag_type_id) REFERENCES public.health_flag_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flags_history health_flags_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags_history
    ADD CONSTRAINT health_flags_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flags_history health_flags_history_health_flag_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags_history
    ADD CONSTRAINT health_flags_history_health_flag_type_id_fk FOREIGN KEY (health_flag_type_id) REFERENCES public.health_flag_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flags_history health_flags_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags_history
    ADD CONSTRAINT health_flags_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.health_flags(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: health_flags_history health_flags_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags_history
    ADD CONSTRAINT health_flags_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.health_flags_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flags_history health_flags_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags_history
    ADD CONSTRAINT health_flags_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flags_history health_flags_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags_history
    ADD CONSTRAINT health_flags_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flags health_flags_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags
    ADD CONSTRAINT health_flags_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: health_flags health_flags_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.health_flags
    ADD CONSTRAINT health_flags_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: image_types image_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_types
    ADD CONSTRAINT image_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images_history images_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images_history images_history_image_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_image_type_id_fk FOREIGN KEY (image_type_id) REFERENCES public.image_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images_history images_history_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images_history images_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.images(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: images_history images_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.images_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images_history images_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images_history images_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images_history
    ADD CONSTRAINT images_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images images_image_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_image_type_id_fk FOREIGN KEY (image_type_id) REFERENCES public.image_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images images_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images images_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: images images_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_aliases ingredient_aliases_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_aliases ingredient_aliases_ingredient_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_ingredient_id_fk FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_aliases ingredient_aliases_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_aliases ingredient_aliases_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_aliases ingredient_aliases_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_aliases ingredient_aliases_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_allergens ingredient_allergens_allergen_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_allergen_id_fk FOREIGN KEY (allergen_id) REFERENCES public.allergens(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_allergens ingredient_allergens_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_allergens ingredient_allergens_ingredient_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_ingredient_id_fk FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_allergens ingredient_allergens_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_allergens ingredient_allergens_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_allergens ingredient_allergens_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_categories_history ingredient_categories_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_categories_history ingredient_categories_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.ingredient_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ingredient_categories_history ingredient_categories_history_parent_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_parent_id_fk FOREIGN KEY (parent_id) REFERENCES public.ingredient_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_categories_history ingredient_categories_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.ingredient_categories_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_categories_history ingredient_categories_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_categories_history ingredient_categories_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_categories ingredient_categories_parent_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories
    ADD CONSTRAINT ingredient_categories_parent_id_fk FOREIGN KEY (parent_id) REFERENCES public.ingredient_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_categories ingredient_categories_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_categories
    ADD CONSTRAINT ingredient_categories_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_health_flags ingredient_health_flags_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_health_flags ingredient_health_flags_health_flag_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_health_flag_id_fk FOREIGN KEY (health_flag_id) REFERENCES public.health_flags(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_health_flags ingredient_health_flags_ingredient_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_ingredient_id_fk FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_health_flags ingredient_health_flags_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_health_flags ingredient_health_flags_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_health_flags ingredient_health_flags_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_translations ingredient_translations_ingredient_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_translations
    ADD CONSTRAINT ingredient_translations_ingredient_id_fk FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredient_translations ingredient_translations_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredient_translations
    ADD CONSTRAINT ingredient_translations_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredients_history ingredients_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients_history
    ADD CONSTRAINT ingredients_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredients_history ingredients_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients_history
    ADD CONSTRAINT ingredients_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.ingredients(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ingredients_history ingredients_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients_history
    ADD CONSTRAINT ingredients_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.ingredients_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredients_history ingredients_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients_history
    ADD CONSTRAINT ingredients_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredients_history ingredients_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients_history
    ADD CONSTRAINT ingredients_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredients ingredients_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients
    ADD CONSTRAINT ingredients_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ingredients ingredients_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingredients
    ADD CONSTRAINT ingredients_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: languages languages_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT languages_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: measurement_bases measurement_bases_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.measurement_bases
    ADD CONSTRAINT measurement_bases_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nutrition_type_translations nutrition_type_translations_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_type_translations
    ADD CONSTRAINT nutrition_type_translations_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nutrition_type_translations nutrition_type_translations_nutrition_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_type_translations
    ADD CONSTRAINT nutrition_type_translations_nutrition_type_id_fk FOREIGN KEY (nutrition_type_id) REFERENCES public.nutrition_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nutrition_types_history nutrition_types_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nutrition_types_history nutrition_types_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.nutrition_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nutrition_types_history nutrition_types_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.nutrition_types_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nutrition_types_history nutrition_types_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nutrition_types_history nutrition_types_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nutrition_types nutrition_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrition_types
    ADD CONSTRAINT nutrition_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: package_types package_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.package_types
    ADD CONSTRAINT package_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: permission_types permission_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_types
    ADD CONSTRAINT permission_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_allergens product_allergens_allergen_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_allergens
    ADD CONSTRAINT product_allergens_allergen_id_fk FOREIGN KEY (allergen_id) REFERENCES public.allergens(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_allergens product_allergens_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_allergens
    ADD CONSTRAINT product_allergens_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_allergens product_allergens_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_allergens
    ADD CONSTRAINT product_allergens_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_allergens product_allergens_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_allergens
    ADD CONSTRAINT product_allergens_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_allergens product_allergens_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_allergens
    ADD CONSTRAINT product_allergens_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_allergens product_allergens_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_allergens
    ADD CONSTRAINT product_allergens_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes product_barcodes_barcode_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes
    ADD CONSTRAINT product_barcodes_barcode_id_fk FOREIGN KEY (barcode_id) REFERENCES public.barcodes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes product_barcodes_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes
    ADD CONSTRAINT product_barcodes_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes_history product_barcodes_history_barcode_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_barcode_id_fk FOREIGN KEY (barcode_id) REFERENCES public.barcodes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes_history product_barcodes_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes_history product_barcodes_history_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes_history product_barcodes_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.product_barcodes(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: product_barcodes_history product_barcodes_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.product_barcodes_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes_history product_barcodes_history_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes_history product_barcodes_history_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes_history product_barcodes_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes_history product_barcodes_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes product_barcodes_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes
    ADD CONSTRAINT product_barcodes_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes product_barcodes_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes
    ADD CONSTRAINT product_barcodes_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes product_barcodes_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes
    ADD CONSTRAINT product_barcodes_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_barcodes product_barcodes_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_barcodes
    ADD CONSTRAINT product_barcodes_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_categories_history product_categories_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories_history
    ADD CONSTRAINT product_categories_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_categories_history product_categories_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories_history
    ADD CONSTRAINT product_categories_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.product_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: product_categories_history product_categories_history_parent_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories_history
    ADD CONSTRAINT product_categories_history_parent_id_fk FOREIGN KEY (parent_id) REFERENCES public.product_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_categories_history product_categories_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories_history
    ADD CONSTRAINT product_categories_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.product_categories_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_categories_history product_categories_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories_history
    ADD CONSTRAINT product_categories_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_categories_history product_categories_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories_history
    ADD CONSTRAINT product_categories_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_categories product_categories_parent_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_parent_id_fk FOREIGN KEY (parent_id) REFERENCES public.product_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_categories product_categories_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_category_translations product_category_translations_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_category_translations
    ADD CONSTRAINT product_category_translations_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_category_translations product_category_translations_product_category_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_category_translations
    ADD CONSTRAINT product_category_translations_product_category_id_fk FOREIGN KEY (product_category_id) REFERENCES public.product_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_health_evaluations product_health_evaluations_condition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_evaluations
    ADD CONSTRAINT product_health_evaluations_condition_id_fkey FOREIGN KEY (condition_id) REFERENCES public.health_conditions(id);


--
-- Name: product_health_evaluations product_health_evaluations_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_evaluations
    ADD CONSTRAINT product_health_evaluations_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: product_health_flags product_health_flags_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_flags
    ADD CONSTRAINT product_health_flags_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_health_flags product_health_flags_health_flag_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_flags
    ADD CONSTRAINT product_health_flags_health_flag_id_fk FOREIGN KEY (health_flag_id) REFERENCES public.health_flags(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_health_flags product_health_flags_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_flags
    ADD CONSTRAINT product_health_flags_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_health_flags product_health_flags_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_flags
    ADD CONSTRAINT product_health_flags_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_health_flags product_health_flags_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_flags
    ADD CONSTRAINT product_health_flags_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_health_flags product_health_flags_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_health_flags
    ADD CONSTRAINT product_health_flags_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images product_images_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images_history product_images_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images_history product_images_history_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images_history product_images_history_image_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_image_id_fk FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images_history product_images_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.product_images(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: product_images_history product_images_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.product_images_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images_history product_images_history_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images_history product_images_history_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images_history product_images_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images_history product_images_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images_history
    ADD CONSTRAINT product_images_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images product_images_image_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_image_id_fk FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images product_images_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images product_images_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images product_images_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_images product_images_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_images
    ADD CONSTRAINT product_images_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_ingredients product_ingredients_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_ingredients product_ingredients_ingredient_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_ingredient_id_fk FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_ingredients product_ingredients_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_ingredients product_ingredients_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_ingredients product_ingredients_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_ingredients product_ingredients_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_ingredients product_ingredients_unit_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_ingredients
    ADD CONSTRAINT product_ingredients_unit_id_fk FOREIGN KEY (unit_id) REFERENCES public.units(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_nutrition_values product_nutrition_values_evidence_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_evidence_type_id_fk FOREIGN KEY (evidence_type_id) REFERENCES public.evidence_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_nutrition_values product_nutrition_values_measurement_basis_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_measurement_basis_id_fk FOREIGN KEY (measurement_basis_id) REFERENCES public.measurement_bases(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_nutrition_values product_nutrition_values_nutrition_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_nutrition_type_id_fk FOREIGN KEY (nutrition_type_id) REFERENCES public.nutrition_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_nutrition_values product_nutrition_values_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_nutrition_values product_nutrition_values_relationship_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_relationship_type_id_fk FOREIGN KEY (relationship_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_nutrition_values product_nutrition_values_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_nutrition_values product_nutrition_values_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_nutrition_values product_nutrition_values_unit_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_unit_id_fk FOREIGN KEY (unit_id) REFERENCES public.units(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_translations product_translations_language_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_translations
    ADD CONSTRAINT product_translations_language_id_fk FOREIGN KEY (language_id) REFERENCES public.languages(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: product_translations product_translations_product_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_translations
    ADD CONSTRAINT product_translations_product_id_fk FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products products_brand_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_brand_id_fk FOREIGN KEY (brand_id) REFERENCES public.brands(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products_history products_history_brand_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_brand_id_fk FOREIGN KEY (brand_id) REFERENCES public.brands(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products_history products_history_change_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_change_set_id_fk FOREIGN KEY (change_set_id) REFERENCES public.change_sets(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products_history products_history_original_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_original_entity_id_fk FOREIGN KEY (original_entity_id) REFERENCES public.products(id) ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: products_history products_history_previous_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_previous_version_id_fk FOREIGN KEY (previous_version_id) REFERENCES public.products_history(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products_history products_history_product_category_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_product_category_id_fk FOREIGN KEY (product_category_id) REFERENCES public.product_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products_history products_history_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products_history products_history_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_history
    ADD CONSTRAINT products_history_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products products_product_category_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_product_category_id_fk FOREIGN KEY (product_category_id) REFERENCES public.product_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products products_source_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_source_id_fk FOREIGN KEY (source_id) REFERENCES public.data_sources(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: products products_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regions regions_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT regions_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regulatory_authorities regulatory_authorities_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regulatory_authorities
    ADD CONSTRAINT regulatory_authorities_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: relationship_types relationship_types_inverse_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_types
    ADD CONSTRAINT relationship_types_inverse_type_id_fk FOREIGN KEY (inverse_type_id) REFERENCES public.relationship_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: relationship_types relationship_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationship_types
    ADD CONSTRAINT relationship_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: role_types role_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_types
    ADD CONSTRAINT role_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: scan_job_items scan_job_items_candidate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_job_items
    ADD CONSTRAINT scan_job_items_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES public.discovery_candidates(id);


--
-- Name: scan_job_items scan_job_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_job_items
    ADD CONSTRAINT scan_job_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: scan_job_items scan_job_items_scan_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_job_items
    ADD CONSTRAINT scan_job_items_scan_job_id_fkey FOREIGN KEY (scan_job_id) REFERENCES public.scan_jobs(id);


--
-- Name: scan_jobs scan_jobs_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_jobs
    ADD CONSTRAINT scan_jobs_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: source_priorities source_priorities_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_priorities
    ADD CONSTRAINT source_priorities_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: source_types source_types_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_types
    ADD CONSTRAINT source_types_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: unit_conversions unit_conversions_from_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_conversions
    ADD CONSTRAINT unit_conversions_from_unit_id_fkey FOREIGN KEY (from_unit_id) REFERENCES public.units(id);


--
-- Name: unit_conversions unit_conversions_to_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unit_conversions
    ADD CONSTRAINT unit_conversions_to_unit_id_fkey FOREIGN KEY (to_unit_id) REFERENCES public.units(id);


--
-- Name: units units_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: verification_statuses verification_statuses_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_statuses
    ADD CONSTRAINT verification_statuses_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: version_metadata version_metadata_entity_version_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_metadata
    ADD CONSTRAINT version_metadata_entity_version_id_fk FOREIGN KEY (entity_version_id) REFERENCES public.entity_versions(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict ubqmmaewkkIhQijpbku8px5cRW64WMQc2OVyHo19R3ycgzAA1B3VNxThgGQLXoJ

