--
-- PostgreSQL database dump
--

\restrict kDMzYjV0m1tQCrf18drraMx7P6fxbCIgEzTD0DkfDmeHkky1dPjtDq5CENd3W9H

-- Dumped from database version 17.6
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
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


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
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in',
    'like',
    'ilike',
    'is',
    'match',
    'imatch',
    'isdistinct'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text,
	negate boolean
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
begin
    if not exists (
        select 1
        from pg_event_trigger_ddl_commands() ev
        join pg_catalog.pg_extension e on ev.objid = e.oid
        where e.extname = 'pg_graphql'
    ) then
        return;
    end if;

    drop function if exists graphql_public.graphql;
    create or replace function graphql_public.graphql(
        "operationName" text default null,
        query text default null,
        variables jsonb default null,
        extensions jsonb default null
    )
        returns jsonb
        language sql
    as $$
        select graphql.resolve(
            query := query,
            variables := coalesce(variables, '{}'),
            "operationName" := "operationName",
            extensions := extensions
        );
    $$;

    -- Attach the wrapper to the extension so DROP EXTENSION cascades to it,
    -- which in turn triggers set_graphql_placeholder to reinstall the "not enabled" stub.
    alter extension pg_graphql add function graphql_public.graphql(text, text, jsonb, jsonb);

    grant usage on schema graphql to postgres, anon, authenticated, service_role;
    grant execute on function graphql.resolve to postgres, anon, authenticated, service_role;
    grant usage on schema graphql to postgres with grant option;
    grant usage on schema graphql_public to postgres with grant option;
end;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: graphql(text, text, jsonb, jsonb); Type: FUNCTION; Schema: graphql_public; Owner: -
--

CREATE FUNCTION graphql_public.graphql("operationName" text DEFAULT NULL::text, query text DEFAULT NULL::text, variables jsonb DEFAULT NULL::jsonb, extensions jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
  BEGIN
      RAISE DEBUG 'PgBouncer auth request: %', p_usename;

      RETURN QUERY
      SELECT
          rolname::text,
          CASE WHEN rolvaliduntil < now()
              THEN null
              ELSE rolpassword::text
          END
      FROM pg_authid
      WHERE rolname=$1 and rolcanlogin;
  END;
  $_$;


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
-- Name: FUNCTION capture_entity_history(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.capture_entity_history() IS 'Automatically records an immutable snapshot into {table}_history on INSERT/UPDATE of a tracked entity; preserves the version chain, prevents duplicate snapshots, and never recurses.';


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
-- Name: FUNCTION prevent_history_mutation(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.prevent_history_mutation() IS 'Raises an exception on UPDATE/DELETE of immutable history rows.';


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
-- Name: FUNCTION set_updated_at(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.set_updated_at() IS 'Sets updated_at = now() on UPDATE; wired to every audit-carrying table.';


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


--
-- Name: FUNCTION validate_entity_relationship_endpoints(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.validate_entity_relationship_endpoints() IS 'Rejects entity_relationships rows whose subject or object endpoint does not exist in its declared entity table (database-level polymorphic reference validation).';


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
    -- Regclass of the table e.g. public.notes
    entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

    -- I, U, D, T: insert, update ...
    action realtime.action = (
        case wal ->> 'action'
            when 'I' then 'INSERT'
            when 'U' then 'UPDATE'
            when 'D' then 'DELETE'
            else 'ERROR'
        end
    );

    -- Is row level security enabled for the table
    is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

    subscriptions realtime.subscription[] = array_agg(subs)
        from
            realtime.subscription subs
        where
            subs.entity = entity_
            -- Filter by action early - only get subscriptions interested in this action
            -- action_filter column can be: '*' (all), 'INSERT', 'UPDATE', or 'DELETE'
            and (subs.action_filter = '*' or subs.action_filter = action::text);

    -- Subscription vars
    working_role regrole;
    working_selected_columns text[];
    claimed_role regrole;
    claims jsonb;

    subscription_id uuid;
    subscription_has_access bool;
    visible_to_subscription_ids uuid[] = '{}';

    -- structured info for wal's columns
    columns realtime.wal_column[];
    -- previous identity values for update/delete
    old_columns realtime.wal_column[];

    error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

    -- Primary jsonb output for record
    output jsonb;

    -- Loop record for iterating unique roles (outer loop)
    role_record record;
    -- Loop record for iterating unique selected_columns within a role (inner loop)
    cols_record record;
    -- Subscription ids visible at the role level (before fanning out by selected_columns)
    visible_role_sub_ids uuid[] = '{}';

begin
    perform set_config('role', null, true);

    columns =
        array_agg(
            (
                x->>'name',
                x->>'type',
                x->>'typeoid',
                realtime.cast(
                    (x->'value') #>> '{}',
                    coalesce(
                        (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                        (x->>'type')::regtype
                    )
                ),
                (pks ->> 'name') is not null,
                true
            )::realtime.wal_column
        )
        from
            jsonb_array_elements(wal -> 'columns') x
            left join jsonb_array_elements(wal -> 'pk') pks
                on (x ->> 'name') = (pks ->> 'name');

    old_columns =
        array_agg(
            (
                x->>'name',
                x->>'type',
                x->>'typeoid',
                realtime.cast(
                    (x->'value') #>> '{}',
                    coalesce(
                        (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                        (x->>'type')::regtype
                    )
                ),
                (pks ->> 'name') is not null,
                true
            )::realtime.wal_column
        )
        from
            jsonb_array_elements(wal -> 'identity') x
            left join jsonb_array_elements(wal -> 'pk') pks
                on (x ->> 'name') = (pks ->> 'name');

    for role_record in
        select claims_role
        from (select distinct claims_role from unnest(subscriptions)) t
        order by claims_role::text
    loop
        working_role := role_record.claims_role;

        -- Update `is_selectable` for columns and old_columns (once per role)
        columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(columns) c;

        old_columns =
                array_agg(
                    (
                        c.name,
                        c.type_name,
                        c.type_oid,
                        c.value,
                        c.is_pkey,
                        pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                    )::realtime.wal_column
                )
                from
                    unnest(old_columns) c;

        if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
            -- Fan out 400 error per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;
                return next (
                    jsonb_build_object(
                        'schema', wal ->> 'schema',
                        'table', wal ->> 'table',
                        'type', action
                    ),
                    is_rls_enabled,
                    (select array_agg(s.subscription_id) from unnest(subscriptions) as s where s.claims_role = working_role and (s.selected_columns is not distinct from working_selected_columns)),
                    array['Error 400: Bad Request, no primary key']
                )::realtime.wal_rls;
            end loop;

        -- The claims role does not have SELECT permission to the primary key of entity
        elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
            -- Fan out 401 error per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;
                return next (
                    jsonb_build_object(
                        'schema', wal ->> 'schema',
                        'table', wal ->> 'table',
                        'type', action
                    ),
                    is_rls_enabled,
                    (select array_agg(s.subscription_id) from unnest(subscriptions) as s where s.claims_role = working_role and (s.selected_columns is not distinct from working_selected_columns)),
                    array['Error 401: Unauthorized']
                )::realtime.wal_rls;
            end loop;

        else
            -- Create the prepared statement (once per role)
            if is_rls_enabled and action <> 'DELETE' then
                if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                    deallocate walrus_rls_stmt;
                end if;
                execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
            end if;

            -- Collect all visible subscription IDs for this role (filter check + RLS check)
            visible_role_sub_ids = '{}';

            for subscription_id, claims in (
                    select
                        subs.subscription_id,
                        subs.claims
                    from
                        unnest(subscriptions) subs
                    where
                        subs.entity = entity_
                        and subs.claims_role = working_role
                        and (
                            realtime.is_visible_through_filters(columns, subs.filters)
                            or (
                              action = 'DELETE'
                              and realtime.is_visible_through_filters(old_columns, subs.filters)
                            )
                        )
            ) loop

                if not is_rls_enabled or action = 'DELETE' then
                    visible_role_sub_ids = visible_role_sub_ids || subscription_id;
                else
                    -- Check if RLS allows the role to see the record
                    perform
                        -- Trim leading and trailing quotes from working_role because set_config
                        -- doesn't recognize the role as valid if they are included
                        set_config('role', trim(both '"' from working_role::text), true),
                        set_config('request.jwt.claims', claims::text, true);

                    execute 'execute walrus_rls_stmt' into subscription_has_access;

                    -- Reset the role on every FOR..LOOP batch execution.
                    -- The first batch of 10 rows is pre-fetched using the current connection role (PG internal behaviour)
                    -- then we have to reset it again otherwise it would use the role defined in the `set_config` above
                    -- to fetch the remaining rows when rows>10, which could be a user-defined role that lacks execution grants.
                    -- The flow is:
                    --   1. run batch with conn role
                    --   2. set_config working_role
                    --   3. execute walrus
                    --   4. reset role (revert)
                    --   5. repeat
                    perform set_config('role', null, true);

                    if subscription_has_access then
                        visible_role_sub_ids = visible_role_sub_ids || subscription_id;
                    end if;
                end if;
            end loop;

            perform set_config('role', null, true);

            -- Inner loop: per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;

                output = jsonb_build_object(
                    'schema', wal ->> 'schema',
                    'table', wal ->> 'table',
                    'type', action,
                    'commit_timestamp', to_char(
                        ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
                    ),
                    'columns', (
                        select
                            jsonb_agg(
                                jsonb_build_object(
                                    'name', pa.attname,
                                    'type', pt.typname
                                )
                                order by pa.attnum asc
                            )
                        from
                            pg_attribute pa
                            join pg_type pt
                                on pa.atttypid = pt.oid
                            left join (
                                select unnest(conkey) as pkey_attnum
                                from pg_constraint
                                where conrelid = entity_ and contype = 'p'
                            ) pk on pk.pkey_attnum = pa.attnum
                        where
                            attrelid = entity_
                            and attnum > 0
                            and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
                            and (working_selected_columns is null or pa.attname = any(working_selected_columns) or pk.pkey_attnum is not null)
                    )
                )
                -- Add "record" key for insert and update
                || case
                    when action in ('INSERT', 'UPDATE') then
                        jsonb_build_object(
                            'record',
                            (
                                select
                                    jsonb_object_agg(
                                        -- if unchanged toast, get column name and value from old record
                                        coalesce((c).name, (oc).name),
                                        case
                                            when (c).name is null then (oc).value
                                            else (c).value
                                        end
                                    )
                                from
                                    unnest(columns) c
                                    full outer join unnest(old_columns) oc
                                        on (c).name = (oc).name
                                where
                                    coalesce((c).is_selectable, (oc).is_selectable)
                                    and (working_selected_columns is null or coalesce((c).name, (oc).name) = any(working_selected_columns) or coalesce((c).is_pkey, (oc).is_pkey))
                                    and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            )
                        )
                    else '{}'::jsonb
                end
                -- Add "old_record" key for update and delete
                || case
                    when action = 'UPDATE' then
                        jsonb_build_object(
                                'old_record',
                                (
                                    select jsonb_object_agg((c).name, (c).value)
                                    from unnest(old_columns) c
                                    where
                                        (c).is_selectable
                                        and (working_selected_columns is null or (c).name = any(working_selected_columns) or (c).is_pkey)
                                        and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                                )
                            )
                    when action = 'DELETE' then
                        jsonb_build_object(
                            'old_record',
                            (
                                select jsonb_object_agg((c).name, (c).value)
                                from unnest(old_columns) c
                                where
                                    (c).is_selectable
                                    and (working_selected_columns is null or (c).name = any(working_selected_columns) or (c).is_pkey)
                                    and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                                    and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                            )
                        )
                    else '{}'::jsonb
                end;

                -- Filter visible_role_sub_ids to those matching the current selected_columns group
                visible_to_subscription_ids = coalesce(
                    (
                        select array_agg(s.subscription_id)
                        from unnest(subscriptions) s
                        where s.claims_role = working_role
                          and (s.selected_columns is not distinct from working_selected_columns)
                          and s.subscription_id = any(visible_role_sub_ids)
                    ),
                    '{}'::uuid[]
                );

                return next (
                    output,
                    is_rls_enabled,
                    visible_to_subscription_ids,
                    case
                        when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                        else '{}'
                    end
                )::realtime.wal_rls;
            end loop;

        end if;
    end loop;

    perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
  res jsonb;
begin
  if type_::text = 'bytea' then
    return to_jsonb(val);
  end if;
  execute format('select to_jsonb(%L::'|| type_::text || ')', val) into res;
  return res;
end
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
/*
Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
*/
declare
    op_symbol text = (
        case
            when op = 'eq' then '='
            when op = 'neq' then '!='
            when op = 'lt' then '<'
            when op = 'lte' then '<='
            when op = 'gt' then '>'
            when op = 'gte' then '>='
            when op = 'in' then '= any'
            else 'UNKNOWN OP'
        end
    );
    res boolean;
begin
    execute format(
        'select %L::'|| type_::text || ' ' || op_symbol
        || ' ( %L::'
        || (
            case
                when op = 'in' then type_::text || '[]'
                else type_::text end
        )
        || ')', val_1, val_2) into res;
    return res;
end;
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
declare
    op_symbol text;
    res boolean;
begin
    -- IS DISTINCT FROM / IS NOT DISTINCT FROM: infix, both sides typed literals
    if op = 'isdistinct' then
        execute format(
            'select %L::%s %s %L::%s',
            val_1,
            type_::text,
            case when negate then 'IS NOT DISTINCT FROM' else 'IS DISTINCT FROM' end,
            val_2,
            type_::text
        ) into res;
        return res;
    end if;

    -- IS requires a keyword RHS (NULL, TRUE, FALSE, UNKNOWN), not a typed literal
    if op = 'is' then
        if val_2 not in ('null', 'true', 'false', 'unknown') then
            raise exception 'invalid value for is filter: must be null, true, false, or unknown';
        end if;
        execute format(
            'select %L::%s %s %s',
            val_1,
            type_::text,
            case when negate then 'IS NOT' else 'IS' end,
            upper(val_2)
        ) into res;
        return res;
    end if;

    op_symbol = case
        when op = 'eq'    then '='
        when op = 'neq'   then '!='
        when op = 'lt'    then '<'
        when op = 'lte'   then '<='
        when op = 'gt'    then '>'
        when op = 'gte'   then '>='
        when op = 'in'    then '= any'
        when op = 'like'   then 'LIKE'
        when op = 'ilike'  then 'ILIKE'
        when op = 'match'  then '~'
        when op = 'imatch' then '~*'
        else null
    end;

    if op_symbol is null then
        raise exception 'unsupported equality operator: %', op::text;
    end if;

    execute format(
        'select %L::%s %s (%L::%s)',
        val_1,
        type_::text,
        op_symbol,
        val_2,
        case when op = 'in' then type_::text || '[]' else type_::text end
    ) into res;

    return case when negate then not res else res end;
end;
$$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
    select
        filters is null
        or array_length(filters, 1) is null
        or coalesce(
            count(col.name) = count(1)
            and sum(
                realtime.check_equality_op(
                    op:=f.op,
                    type_:=coalesce(col.type_oid::regtype, col.type_name::regtype),
                    val_1:=col.value #>> '{}',
                    val_2:=f.value,
                    negate:=coalesce(f.negate, false)
                )::int
            ) filter (where col.name is not null) = count(col.name),
            false
        )
    from
        unnest(filters) f
        left join unnest(columns) col
            on f.column_name = col.name;
$$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS TABLE(wal jsonb, is_rls_enabled boolean, subscription_ids uuid[], errors text[], slot_changes_count bigint)
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
  WITH pub AS (
    SELECT
      concat_ws(
        ',',
        CASE WHEN bool_or(pubinsert) THEN 'insert' ELSE NULL END,
        CASE WHEN bool_or(pubupdate) THEN 'update' ELSE NULL END,
        CASE WHEN bool_or(pubdelete) THEN 'delete' ELSE NULL END
      ) AS w2j_actions,
      coalesce(
        string_agg(
          realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
          ','
        ) filter (WHERE ppt.tablename IS NOT NULL),
        ''
      ) AS w2j_add_tables
    FROM pg_publication pp
    LEFT JOIN pg_publication_tables ppt ON pp.pubname = ppt.pubname
    WHERE pp.pubname = publication
    GROUP BY pp.pubname
    LIMIT 1
  ),
  -- MATERIALIZED ensures pg_logical_slot_get_changes is called exactly once
  w2j AS MATERIALIZED (
    SELECT x.*, pub.w2j_add_tables
    FROM pub,
         pg_logical_slot_get_changes(
           slot_name, null, max_changes,
           'include-pk', 'true',
           'include-transaction', 'false',
           'include-timestamp', 'true',
           'include-type-oids', 'true',
           'format-version', '2',
           'actions', pub.w2j_actions,
           'add-tables', pub.w2j_add_tables
         ) x
  ),
  slot_count AS (
    SELECT count(*)::bigint AS cnt
    FROM w2j
    WHERE w2j.w2j_add_tables <> ''
  ),
  rls_filtered AS (
    SELECT xyz.wal, xyz.is_rls_enabled, xyz.subscription_ids, xyz.errors
    FROM w2j,
         realtime.apply_rls(
           wal := w2j.data::jsonb,
           max_record_bytes := max_record_bytes
         ) xyz(wal, is_rls_enabled, subscription_ids, errors)
    WHERE w2j.w2j_add_tables <> ''
      AND xyz.subscription_ids[1] IS NOT NULL
  )
  SELECT rf.wal, rf.is_rls_enabled, rf.subscription_ids, rf.errors, sc.cnt
  FROM rls_filtered rf, slot_count sc

  UNION ALL

  SELECT null, null, null, null, sc.cnt
  FROM slot_count sc
  WHERE NOT EXISTS (SELECT 1 FROM rls_filtered)
$$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
  SELECT
    realtime.wal2json_escape_identifier(nsp.nspname::text)
    || '.'
    || realtime.wal2json_escape_identifier(pc.relname::text)
  FROM pg_class pc
  JOIN pg_namespace nsp ON pc.relnamespace = nsp.oid
  WHERE pc.oid = entity
$$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'WarnSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: send_binary(bytea, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send_binary(payload bytea, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
BEGIN
  BEGIN
    generated_id := gen_random_uuid();

    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    INSERT INTO realtime.messages (id, binary_payload, event, topic, private, extension)
    VALUES (generated_id, payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'WarnSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    col_names text[] = coalesce(
            array_agg(a.attname order by a.attnum),
            '{}'::text[]
        )
        from
            pg_catalog.pg_attribute a
        where
            a.attrelid = new.entity
            and a.attnum > 0
            and not a.attisdropped
            and pg_catalog.has_column_privilege(
                (new.claims ->> 'role'),
                a.attrelid,
                a.attnum,
                'SELECT'
            );
    filter realtime.user_defined_filter;
    col_type regtype;
    in_val jsonb;
    selected_col text;
begin
    for filter in select * from unnest(new.filters) loop
        if not filter.column_name = any(col_names) then
            raise exception 'invalid column for filter %', filter.column_name;
        end if;

        col_type = (
            select atttypid::regtype
            from pg_catalog.pg_attribute
            where attrelid = new.entity
                  and attname = filter.column_name
        );
        if col_type is null then
            raise exception 'failed to lookup type for column %', filter.column_name;
        end if;

        if filter.op = 'in'::realtime.equality_op then
            in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
            if coalesce(jsonb_array_length(in_val), 0) > 100 then
                raise exception 'too many values for `in` filter. Maximum 100';
            end if;
        elsif filter.op = 'is'::realtime.equality_op then
            -- `is` requires a keyword RHS rather than a typed literal
            if filter.value not in ('null', 'true', 'false', 'unknown') then
                raise exception 'invalid value for is filter: must be null, true, false, or unknown';
            end if;
            -- IS NULL works for any type, but IS TRUE/FALSE/UNKNOWN require a boolean
            -- operand. Reject the non-null keywords on non-boolean columns here so they
            -- don't abort apply_rls at WAL time.
            if filter.value <> 'null' and col_type <> 'boolean'::regtype then
                raise exception 'is % filter requires a boolean column, got %', filter.value, col_type::text;
            end if;
        elsif filter.op in ('like'::realtime.equality_op, 'ilike'::realtime.equality_op) then
            -- like/ilike apply the text pattern operator (~~); reject column types that
            -- have no such operator instead of failing at WAL time
            if not exists (
                select 1 from pg_catalog.pg_operator
                where oprname = '~~' and oprleft = col_type
            ) then
                raise exception 'operator % requires a text-compatible column type, got %', filter.op::text, col_type::text;
            end if;
        elsif filter.op in ('match'::realtime.equality_op, 'imatch'::realtime.equality_op) then
            -- match/imatch apply the regex operators ~ / ~*; reject column types that have
            -- no such operator (e.g. integer) instead of failing at WAL time, mirroring the
            -- like/ilike guard above.
            if not exists (
                select 1 from pg_catalog.pg_operator
                where oprname = case when filter.op = 'imatch'::realtime.equality_op then '~*' else '~' end
                  and oprleft = col_type
                  and oprright = col_type
                  and oprresult = 'boolean'::regtype
            ) then
                raise exception 'operator % requires a text-compatible column type, got %', filter.op::text, col_type::text;
            end if;
            -- validate the regex eagerly so a bad pattern is rejected here, not inside
            -- apply_rls where it would abort the WAL stream for the entity
            begin
                perform '' ~ filter.value;
            exception when others then
                raise exception 'invalid regular expression for % filter: %', filter.op::text, sqlerrm;
            end;
        else
            -- eq/neq/lt/lte/gt/gte: value must be coercable to the type
            perform realtime.cast(filter.value, col_type);
        end if;
    end loop;

    if new.selected_columns is not null then
        for selected_col in select * from unnest(new.selected_columns) loop
            if not selected_col = any(col_names) then
                raise exception 'invalid column for select %', selected_col;
            end if;
        end loop;
    end if;

    -- Apply consistent order to filters so the unique constraint can't be tricked by a
    -- different filter order. negate is part of the sort key.
    new.filters = coalesce(
        array_agg(f order by f.column_name, f.op, f.value, f.negate),
        '{}'
    ) from unnest(new.filters) f;

    new.selected_columns = (
        select array_agg(c order by c)
        from unnest(new.selected_columns) c
    );

    return new;
end;
$$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: wal2json_escape_identifier(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.wal2json_escape_identifier(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
  -- Prefix `\`, `,`, `.`, and any whitespace with `\`
  SELECT regexp_replace(name, '([\\,.[:space:]])', '\\\1', 'g')
$$;


--
-- Name: allow_any_operation(text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_any_operation(expected_operations text[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT CASE
      WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
      ELSE raw_operation
    END AS current_operation
    FROM current_operation
  )
  SELECT EXISTS (
    SELECT 1
    FROM normalized n
    CROSS JOIN LATERAL unnest(expected_operations) AS expected_operation
    WHERE expected_operation IS NOT NULL
      AND expected_operation <> ''
      AND n.current_operation = CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END
  );
$$;


--
-- Name: allow_only_operation(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_only_operation(expected_operation text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
        ELSE raw_operation
      END AS current_operation,
      CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END AS requested_operation
    FROM current_operation
  )
  SELECT CASE
    WHEN requested_operation IS NULL OR requested_operation = '' THEN FALSE
    ELSE COALESCE(current_operation = requested_operation, FALSE)
  END
  FROM normalized;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Get the last path segment (the actual filename)
    SELECT _parts[array_length(_parts, 1)] INTO _filename;
    -- Extract extension: reverse, split on '.', then reverse again
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    RETURN _parts[array_length(_parts, 1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_common_prefix(text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint)::bigint as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: protect_delete(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.protect_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach (unchanged)
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT path_tokens[$1] AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $2 || '%%'
                  AND bucket_id = $3
                  AND array_length(objects.path_tokens, 1) <> $1
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT path_tokens[$1] AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $2 || '%%'
               AND bucket_id = $3
               AND array_length(objects.path_tokens, 1) = $1
             ORDER BY %I %s)
            LIMIT $4 OFFSET $5
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := split_part(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter), v_delimiter, levels);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := split_part(v_current.name, v_delimiter, levels);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: search_by_timestamp(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    IF p_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        p_sort_column,
        v_cursor_op,
        p_sort_column,
        p_sort_order,
        p_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: custom_oauth_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.custom_oauth_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_type text NOT NULL,
    identifier text NOT NULL,
    name text NOT NULL,
    client_id text NOT NULL,
    client_secret text NOT NULL,
    acceptable_client_ids text[] DEFAULT '{}'::text[] NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    pkce_enabled boolean DEFAULT true NOT NULL,
    attribute_mapping jsonb DEFAULT '{}'::jsonb NOT NULL,
    authorization_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    email_optional boolean DEFAULT false NOT NULL,
    issuer text,
    discovery_url text,
    skip_nonce_check boolean DEFAULT false NOT NULL,
    cached_discovery jsonb,
    discovery_cached_at timestamp with time zone,
    authorization_url text,
    token_url text,
    userinfo_url text,
    jwks_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom_claims_allowlist text[] DEFAULT '{}'::text[] NOT NULL,
    CONSTRAINT custom_oauth_providers_authorization_url_https CHECK (((authorization_url IS NULL) OR (authorization_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_authorization_url_length CHECK (((authorization_url IS NULL) OR (char_length(authorization_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_client_id_length CHECK (((char_length(client_id) >= 1) AND (char_length(client_id) <= 512))),
    CONSTRAINT custom_oauth_providers_discovery_url_length CHECK (((discovery_url IS NULL) OR (char_length(discovery_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_identifier_format CHECK ((identifier ~ '^[a-z0-9][a-z0-9:-]{0,48}[a-z0-9]$'::text)),
    CONSTRAINT custom_oauth_providers_issuer_length CHECK (((issuer IS NULL) OR ((char_length(issuer) >= 1) AND (char_length(issuer) <= 2048)))),
    CONSTRAINT custom_oauth_providers_jwks_uri_https CHECK (((jwks_uri IS NULL) OR (jwks_uri ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_jwks_uri_length CHECK (((jwks_uri IS NULL) OR (char_length(jwks_uri) <= 2048))),
    CONSTRAINT custom_oauth_providers_name_length CHECK (((char_length(name) >= 1) AND (char_length(name) <= 100))),
    CONSTRAINT custom_oauth_providers_oauth2_requires_endpoints CHECK (((provider_type <> 'oauth2'::text) OR ((authorization_url IS NOT NULL) AND (token_url IS NOT NULL) AND (userinfo_url IS NOT NULL)))),
    CONSTRAINT custom_oauth_providers_oidc_discovery_url_https CHECK (((provider_type <> 'oidc'::text) OR (discovery_url IS NULL) OR (discovery_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_issuer_https CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NULL) OR (issuer ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_requires_issuer CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NOT NULL))),
    CONSTRAINT custom_oauth_providers_provider_type_check CHECK ((provider_type = ANY (ARRAY['oauth2'::text, 'oidc'::text]))),
    CONSTRAINT custom_oauth_providers_token_url_https CHECK (((token_url IS NULL) OR (token_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_token_url_length CHECK (((token_url IS NULL) OR (char_length(token_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_userinfo_url_https CHECK (((userinfo_url IS NULL) OR (userinfo_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_userinfo_url_length CHECK (((userinfo_url IS NULL) OR (char_length(userinfo_url) <= 2048)))
);


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text,
    code_challenge_method auth.code_challenge_method,
    code_challenge text,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone,
    invite_token text,
    referrer text,
    oauth_client_state_id uuid,
    linking_target_id uuid,
    email_optional boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'Stores metadata for all OAuth/SSO login flows';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    token_endpoint_auth_method text NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048)),
    CONSTRAINT oauth_clients_token_endpoint_auth_method_check CHECK ((token_endpoint_auth_method = ANY (ARRAY['client_secret_basic'::text, 'client_secret_post'::text, 'none'::text])))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: webauthn_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    challenge_type text NOT NULL,
    session_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT webauthn_challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['signup'::text, 'registration'::text, 'authentication'::text])))
);


--
-- Name: webauthn_credentials; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    credential_id bytea NOT NULL,
    public_key bytea NOT NULL,
    attestation_type text DEFAULT ''::text NOT NULL,
    aaguid uuid,
    sign_count bigint DEFAULT 0 NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    backup_eligible boolean DEFAULT false NOT NULL,
    backed_up boolean DEFAULT false NOT NULL,
    friendly_name text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone
);


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
-- Name: TABLE allergen_translations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.allergen_translations IS 'Per-language translations of allergens (unique per allergen and language).';


--
-- Name: COLUMN allergen_translations.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergen_translations.name IS 'Translated canonical name of the allergen.';


--
-- Name: COLUMN allergen_translations.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergen_translations.display_name IS 'User-facing label for the allergen in this language.';


--
-- Name: COLUMN allergen_translations.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergen_translations.search_name IS 'Normalized search variant (e.g. transliteration); NULL when not needed.';


--
-- Name: COLUMN allergen_translations.translation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergen_translations.translation_status IS 'Governed quality lifecycle of this translation row.';


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
-- Name: TABLE allergen_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.allergen_types IS 'Governed registry of allergen classes (business knowledge, not ENUM).';


--
-- Name: COLUMN allergen_types.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergen_types.code IS 'Stable machine reference (snake_case), e.g. gluten, tree_nuts, sesame.';


--
-- Name: COLUMN allergen_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergen_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE allergens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.allergens IS 'Canonical registry of specific allergens (governed, provenance-tracked entity).';


--
-- Name: COLUMN allergens.allergen_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.allergen_type_id IS 'Allergen class (foreign key to allergen_types); NULL when not yet classified.';


--
-- Name: COLUMN allergens.internal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.internal_code IS 'Stable internal machine reference (unique, citext).';


--
-- Name: COLUMN allergens.confidence_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.confidence_level IS 'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';


--
-- Name: COLUMN allergens.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: COLUMN allergens.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.created_by IS 'UUID of the actor that created the row; FK to the future auth service (none yet).';


--
-- Name: COLUMN allergens.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.approved_by IS 'UUID of the actor that approved the row; FK to the future auth service (none yet).';


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
-- Name: TABLE allergens_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.allergens_history IS 'Immutable version-history of allergens (INSERT-only; one row per version).';


--
-- Name: COLUMN allergens_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens_history.original_entity_id IS 'Canonical allergen this version belongs to (foreign key to allergens, applied in 0022).';


--
-- Name: COLUMN allergens_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN allergens_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN allergens_history.allergen_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens_history.allergen_type_id IS 'Allergen class at this version (foreign key to allergen_types, applied in 0022).';


--
-- Name: COLUMN allergens_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN allergens_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN allergens_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE audit_context; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.audit_context IS 'Per-operation audit context (one row per correlation/transaction pair).';


--
-- Name: COLUMN audit_context.correlation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_context.correlation_id IS 'End-to-end request/correlation identifier (unique with transaction_id).';


--
-- Name: COLUMN audit_context.transaction_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_context.transaction_id IS 'Database transaction identifier within the operation (unique with correlation_id).';


--
-- Name: COLUMN audit_context.actor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_context.actor IS 'UUID of the acting principal; FK to the future auth service (none yet, ADR-005).';


--
-- Name: COLUMN audit_context.role_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_context.role_id IS 'Authorized role of the actor (foreign key to role_types, applied in 0022).';


--
-- Name: COLUMN audit_context.ip_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_context.ip_address IS 'Requesting host IP; nullable placeholder, never business data.';


--
-- Name: COLUMN audit_context.user_agent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_context.user_agent IS 'Requesting client user agent; nullable placeholder, never business data.';


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
-- Name: TABLE audit_event_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.audit_event_types IS 'Governed registry of audit event classes (created, updated, merged, ...).';


--
-- Name: COLUMN audit_event_types.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_event_types.code IS 'Stable machine reference (snake_case), e.g. created, status_changed, merged.';


--
-- Name: COLUMN audit_event_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_event_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE audit_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.audit_events IS 'Normalized per-version event details (one row per version record written).';


--
-- Name: COLUMN audit_events.audit_log_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_events.audit_log_id IS 'Owning feed entry (foreign key to audit_log, applied in 0022).';


--
-- Name: COLUMN audit_events.event_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_events.event_type_id IS 'Per-version action class (foreign key to audit_event_types, applied in 0022).';


--
-- Name: COLUMN audit_events.entity_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_events.entity_type IS 'Canonical entity/table the version belongs to (text discriminator, no FK).';


--
-- Name: COLUMN audit_events.entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_events.entity_id IS 'Canonical entity id the version belongs to.';


--
-- Name: COLUMN audit_events.previous_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_events.previous_version IS 'Version number before this version (NULL on create).';


--
-- Name: COLUMN audit_events.new_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_events.new_version IS 'Version number recorded by this event.';


--
-- Name: COLUMN audit_events.event_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_events.event_time IS 'When the version event was recorded (server clock).';


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
-- Name: TABLE audit_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.audit_log IS 'Append-only audit event feed (self-contained per-change narrative).';


--
-- Name: COLUMN audit_log.change_set_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.change_set_id IS 'Owning logical change (foreign key to change_sets, applied in 0022).';


--
-- Name: COLUMN audit_log.event_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.event_type_id IS 'Classified action, the mission "action" field (foreign key to audit_event_types, applied in 0022).';


--
-- Name: COLUMN audit_log.entity_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.entity_type IS 'Canonical entity/table the change acted on (the mission "entity" field; text discriminator, no FK).';


--
-- Name: COLUMN audit_log.entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.entity_id IS 'Entity id the change acted on (the mission "entity_id" field).';


--
-- Name: COLUMN audit_log.previous_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.previous_version IS 'Version number of the entity before the change (NULL on create).';


--
-- Name: COLUMN audit_log.new_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.new_version IS 'Version number of the entity after the change.';


--
-- Name: COLUMN audit_log.actor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.actor IS 'UUID of the acting principal; FK to the future auth service (none yet, ADR-005).';


--
-- Name: COLUMN audit_log.role_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.role_id IS 'Authorized role of the actor (foreign key to role_types, applied in 0022).';


--
-- Name: COLUMN audit_log.ip_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.ip_address IS 'Requesting host IP; nullable placeholder, never business data.';


--
-- Name: COLUMN audit_log.user_agent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.user_agent IS 'Requesting client user agent; nullable placeholder, never business data.';


--
-- Name: COLUMN audit_log.logged_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.logged_at IS 'When the feed entry was recorded (server clock).';


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
-- Name: TABLE barcode_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.barcode_types IS 'Governed registry of barcode symbologies.';


--
-- Name: COLUMN barcode_types.digit_length; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcode_types.digit_length IS 'Fixed numeric payload length for GTIN family; NULL for 2D/matrix types.';


--
-- Name: COLUMN barcode_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcode_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE barcodes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.barcodes IS 'Canonical registry of globally unique barcodes with lifecycle and verification statuses.';


--
-- Name: COLUMN barcodes.barcode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes.barcode IS 'Globally unique code value (unique, case-insensitive citext).';


--
-- Name: COLUMN barcodes.barcode_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes.barcode_type_id IS 'Symbology of the code (foreign key to barcode_types: gtin_13, qr, ...).';


--
-- Name: COLUMN barcodes.verification_status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes.verification_status_id IS 'Trust status of the code, orthogonal to lifecycle (foreign key to verification_statuses).';


--
-- Name: COLUMN barcodes.source_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes.source_id IS 'Provenance of the barcode record (foreign key to data_sources).';


--
-- Name: COLUMN barcodes.status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes.status_id IS 'Lifecycle of the barcode (foreign key to lifecycle_statuses; ADR-008). No active boolean is stored.';


--
-- Name: COLUMN barcodes.issued_country_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes.issued_country_id IS 'Issuing jurisdiction / GS1 prefix country, NULL when unknown (foreign key to countries).';


--
-- Name: COLUMN barcodes.confidence_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes.confidence_level IS 'Fact confidence of this barcode record in [0,1]; the confidence_band ENUM is derived, never stored.';


--
-- Name: COLUMN barcodes.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE barcodes_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.barcodes_history IS 'Immutable version-history of barcodes (INSERT-only; one row per version).';


--
-- Name: COLUMN barcodes_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes_history.original_entity_id IS 'Canonical barcode this version belongs to (foreign key to barcodes, applied in 0027).';


--
-- Name: COLUMN barcodes_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN barcodes_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN barcodes_history.verification_status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes_history.verification_status_id IS 'Verification state of the barcode at this version (foreign key to verification_statuses, applied in 0027).';


--
-- Name: COLUMN barcodes_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN barcodes_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN barcodes_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.barcodes_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE brand_search_index; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.brand_search_index IS 'Derived, rebuildable search index for brands (read model; no FK to brands).';


--
-- Name: COLUMN brand_search_index.brand_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_search_index.brand_id IS 'Logical reference to brands.id; NO foreign key - the search layer is disposable and rebuildable.';


--
-- Name: COLUMN brand_search_index.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_search_index.search_name IS 'Normalized primary searchable name (application-built from canonical name/translations).';


--
-- Name: COLUMN brand_search_index.search_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_search_index.search_text IS 'Normalized concatenated searchable text: description, owning company, internal code.';


--
-- Name: COLUMN brand_search_index.search_tokens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_search_index.search_tokens IS 'Language-independent normalized search tokens (folded, accent-stripped).';


--
-- Name: COLUMN brand_search_index.language_codes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_search_index.language_codes IS 'Languages covered by the searchable text (citext codes, e.g. {ar,en}).';


--
-- Name: COLUMN brand_search_index.search_rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_search_index.search_rank IS 'Ranking helper >= 0; higher means the result is promoted.';


--
-- Name: COLUMN brand_search_index.generated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_search_index.generated_at IS 'Timestamp when this search row was generated or refreshed (rebuild tracking).';


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
-- Name: TABLE brand_translations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.brand_translations IS 'Per-language translations of brands (unique per brand and language).';


--
-- Name: COLUMN brand_translations.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_translations.name IS 'Translated canonical name of the brand.';


--
-- Name: COLUMN brand_translations.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_translations.display_name IS 'User-facing label for the brand in this language.';


--
-- Name: COLUMN brand_translations.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_translations.search_name IS 'Normalized search variant (e.g. transliteration); NULL when not needed.';


--
-- Name: COLUMN brand_translations.translation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brand_translations.translation_status IS 'Governed quality lifecycle of this translation row.';


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
-- Name: TABLE brands; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.brands IS 'Canonical registry of brands, each owned by exactly one company.';


--
-- Name: COLUMN brands.company_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands.company_id IS 'Owning company (foreign key to companies).';


--
-- Name: COLUMN brands.internal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands.internal_code IS 'Stable internal machine reference (unique, citext).';


--
-- Name: COLUMN brands.confidence_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands.confidence_level IS 'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';


--
-- Name: COLUMN brands.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: COLUMN brands.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands.created_by IS 'UUID of the actor that created the row; FK to the future auth service (none yet).';


--
-- Name: COLUMN brands.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands.approved_by IS 'UUID of the actor that approved the row; FK to the future auth service (none yet).';


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
-- Name: TABLE brands_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.brands_history IS 'Immutable version-history of brands (INSERT-only; one row per version).';


--
-- Name: COLUMN brands_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands_history.original_entity_id IS 'Canonical brand this version belongs to (foreign key to brands, applied in 0022).';


--
-- Name: COLUMN brands_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN brands_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN brands_history.company_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands_history.company_id IS 'Owning company at this version (foreign key to companies, applied in 0022).';


--
-- Name: COLUMN brands_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN brands_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN brands_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.brands_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE change_sets; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.change_sets IS 'Logical grouping of version records produced by one governed change.';


--
-- Name: COLUMN change_sets.correlation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.change_sets.correlation_id IS 'Owner operation correlation id (composite foreign key to audit_context, applied in 0022).';


--
-- Name: COLUMN change_sets.transaction_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.change_sets.transaction_id IS 'Owner operation transaction id (composite foreign key to audit_context, applied in 0022).';


--
-- Name: COLUMN change_sets.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.change_sets.description IS 'Human-readable description of the logical change (why the versions were written).';


--
-- Name: COLUMN change_sets.applied_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.change_sets.applied_at IS 'When the change was committed (server clock).';


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
    CONSTRAINT companies_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT companies_version_number_check CHECK ((version_number > 0))
);


--
-- Name: TABLE companies; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.companies IS 'Canonical registry of companies (manufacturers, distributors, retailers).';


--
-- Name: COLUMN companies.internal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies.internal_code IS 'Stable internal machine reference (unique, citext).';


--
-- Name: COLUMN companies.confidence_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies.confidence_level IS 'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';


--
-- Name: COLUMN companies.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: COLUMN companies.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies.created_by IS 'UUID of the actor that created the row; FK to the future auth service (none yet).';


--
-- Name: COLUMN companies.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies.approved_by IS 'UUID of the actor that approved the row; FK to the future auth service (none yet).';


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
-- Name: TABLE companies_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.companies_history IS 'Immutable version-history of companies (INSERT-only; one row per version).';


--
-- Name: COLUMN companies_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies_history.original_entity_id IS 'Canonical company this version belongs to (foreign key to companies, applied in 0022).';


--
-- Name: COLUMN companies_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN companies_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN companies_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN companies_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN companies_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.companies_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE company_search_index; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.company_search_index IS 'Derived, rebuildable search index for companies (read model; no FK to companies).';


--
-- Name: COLUMN company_search_index.company_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_search_index.company_id IS 'Logical reference to companies.id; NO foreign key - the search layer is disposable and rebuildable.';


--
-- Name: COLUMN company_search_index.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_search_index.search_name IS 'Normalized primary searchable name (application-built from canonical name/translations).';


--
-- Name: COLUMN company_search_index.search_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_search_index.search_text IS 'Normalized concatenated searchable text: description, country, internal code.';


--
-- Name: COLUMN company_search_index.search_tokens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_search_index.search_tokens IS 'Language-independent normalized search tokens (folded, accent-stripped).';


--
-- Name: COLUMN company_search_index.language_codes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_search_index.language_codes IS 'Languages covered by the searchable text (citext codes, e.g. {ar,en}).';


--
-- Name: COLUMN company_search_index.search_rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_search_index.search_rank IS 'Ranking helper >= 0; higher means the result is promoted.';


--
-- Name: COLUMN company_search_index.generated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_search_index.generated_at IS 'Timestamp when this search row was generated or refreshed (rebuild tracking).';


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
-- Name: TABLE company_translations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.company_translations IS 'Per-language translations of companies (unique per company and language).';


--
-- Name: COLUMN company_translations.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_translations.name IS 'Translated canonical name of the company.';


--
-- Name: COLUMN company_translations.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_translations.display_name IS 'User-facing label for the company in this language.';


--
-- Name: COLUMN company_translations.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_translations.search_name IS 'Normalized search variant (e.g. transliteration); NULL when not needed.';


--
-- Name: COLUMN company_translations.translation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_translations.translation_status IS 'Governed quality lifecycle of this translation row.';


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
-- Name: TABLE countries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.countries IS 'Governed registry of countries (ISO 3166-1), Saudi-first with GCC/global scope.';


--
-- Name: COLUMN countries.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.countries.code IS 'ISO 3166-1 alpha-2 country code.';


--
-- Name: COLUMN countries.alpha_3; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.countries.alpha_3 IS 'ISO 3166-1 alpha-3 country code.';


--
-- Name: COLUMN countries.numeric_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.countries.numeric_code IS 'ISO 3166-1 numeric three-digit country code.';


--
-- Name: COLUMN countries.is_gcc_member; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.countries.is_gcc_member IS 'True for Gulf Cooperation Council member states; feeds the GCC expansion phase.';


--
-- Name: COLUMN countries.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.countries.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE data_sources; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.data_sources IS 'Governed registry of concrete data sources feeding the knowledge base.';


--
-- Name: COLUMN data_sources.source_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.data_sources.source_type_id IS 'Category of the source (foreign key to source_types).';


--
-- Name: COLUMN data_sources.priority_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.data_sources.priority_id IS 'Trust priority for conflict resolution (foreign key to source_priorities).';


--
-- Name: COLUMN data_sources.country_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.data_sources.country_id IS 'Jurisdictional scope; NULL means global/unspecified (foreign key to countries).';


--
-- Name: COLUMN data_sources.is_verified; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.data_sources.is_verified IS 'True for institutionally trusted sources that may bypass per-record human review.';


--
-- Name: COLUMN data_sources.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.data_sources.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE entity_relationships; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.entity_relationships IS 'Polymorphic knowledge-graph edges between canonical core entities.';


--
-- Name: COLUMN entity_relationships.subject_entity_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_relationships.subject_entity_type IS 'Entity kind of the edge subject; restricted to the canonical core entities.';


--
-- Name: COLUMN entity_relationships.subject_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_relationships.subject_id IS 'UUID of the subject entity; integrity enforced at the application/trigger layer (polymorphic endpoint).';


--
-- Name: COLUMN entity_relationships.object_entity_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_relationships.object_entity_type IS 'Entity kind of the edge object; restricted to the canonical core entities.';


--
-- Name: COLUMN entity_relationships.object_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_relationships.object_id IS 'UUID of the object entity; integrity enforced at the application/trigger layer (polymorphic endpoint).';


--
-- Name: COLUMN entity_relationships.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_relationships.relationship_type_id IS 'Edge type (foreign key to relationship_types); the governed edge vocabulary.';


--
-- Name: COLUMN entity_relationships.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_relationships.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE entity_versions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.entity_versions IS 'Generic registry of every published version across all history tables.';


--
-- Name: COLUMN entity_versions.entity_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_versions.entity_type IS 'Canonical entity/table the version belongs to (text discriminator, no FK).';


--
-- Name: COLUMN entity_versions.entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_versions.entity_id IS 'Canonical entity id the version belongs to.';


--
-- Name: COLUMN entity_versions.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_versions.version_number IS 'Version number within that entity (unique with entity_type and entity_id).';


--
-- Name: COLUMN entity_versions.history_table; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_versions.history_table IS 'Name of the history table holding the immutable snapshot (text discriminator, no FK).';


--
-- Name: COLUMN entity_versions.history_row_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_versions.history_row_id IS 'Id of the immutable history row (tamper-evidence pointer for hash verification).';


--
-- Name: COLUMN entity_versions.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_versions.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


--
-- Name: COLUMN entity_versions.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.entity_versions.previous_version_id IS 'Self-reference to the immediately prior version registry row (applied in 0022).';


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
-- Name: TABLE evidence_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.evidence_types IS 'Governed registry of evidence kinds that back governed facts.';


--
-- Name: COLUMN evidence_types.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.evidence_types.code IS 'Stable machine reference (snake_case), e.g. scientific_study, label_image.';


--
-- Name: COLUMN evidence_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.evidence_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE health_flag_translations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.health_flag_translations IS 'Per-language translations of health flags (unique per flag and language).';


--
-- Name: COLUMN health_flag_translations.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flag_translations.name IS 'Translated canonical name of the health flag.';


--
-- Name: COLUMN health_flag_translations.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flag_translations.display_name IS 'User-facing label for the health flag in this language.';


--
-- Name: COLUMN health_flag_translations.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flag_translations.search_name IS 'Normalized search variant (e.g. transliteration); NULL when not needed.';


--
-- Name: COLUMN health_flag_translations.translation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flag_translations.translation_status IS 'Governed quality lifecycle of this translation row.';


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
-- Name: TABLE health_flag_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.health_flag_types IS 'Governed registry of health/risk flag classes (business knowledge, not ENUM).';


--
-- Name: COLUMN health_flag_types.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flag_types.code IS 'Stable machine reference (snake_case), e.g. allergen, recall.';


--
-- Name: COLUMN health_flag_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flag_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE health_flags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.health_flags IS 'Canonical registry of concrete health/risk flags and claims.';


--
-- Name: COLUMN health_flags.health_flag_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags.health_flag_type_id IS 'Health/risk flag class (foreign key to health_flag_types); NULL when not yet classified.';


--
-- Name: COLUMN health_flags.internal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags.internal_code IS 'Stable internal machine reference (unique, citext).';


--
-- Name: COLUMN health_flags.confidence_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags.confidence_level IS 'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';


--
-- Name: COLUMN health_flags.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: COLUMN health_flags.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags.created_by IS 'UUID of the actor that created the row; FK to the future auth service (none yet).';


--
-- Name: COLUMN health_flags.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags.approved_by IS 'UUID of the actor that approved the row; FK to the future auth service (none yet).';


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
-- Name: TABLE health_flags_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.health_flags_history IS 'Immutable version-history of health_flags (INSERT-only; one row per version).';


--
-- Name: COLUMN health_flags_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags_history.original_entity_id IS 'Canonical health flag this version belongs to (foreign key to health_flags, applied in 0022).';


--
-- Name: COLUMN health_flags_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN health_flags_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN health_flags_history.health_flag_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags_history.health_flag_type_id IS 'Health/risk flag class at this version (foreign key to health_flag_types, applied in 0022).';


--
-- Name: COLUMN health_flags_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN health_flags_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN health_flags_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.health_flags_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE image_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.image_types IS 'Governed registry of product image categories.';


--
-- Name: COLUMN image_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.image_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE images; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.images IS 'Canonical registry of governed media records (references, not file storage).';


--
-- Name: COLUMN images.image_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.image_type_id IS 'Classification of the image (foreign key to image_types): primary, front, back, nutrition panel, ...';


--
-- Name: COLUMN images.source_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.source_id IS 'Provenance of the media record (foreign key to data_sources).';


--
-- Name: COLUMN images.language_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.language_id IS 'Language scope of the media (foreign key to languages); NULL = language-neutral.';


--
-- Name: COLUMN images.storage_uri; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.storage_uri IS 'Reference to the stored object in the object store (unique; never the bytes themselves).';


--
-- Name: COLUMN images.content_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.content_hash IS 'Content fingerprint (SHA-256) used for deduplication (unique); the history header column checksum is reserved for row tamper-evidence.';


--
-- Name: COLUMN images.mime_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.mime_type IS 'Media type of the stored object (e.g. image/jpeg).';


--
-- Name: COLUMN images.file_size; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.file_size IS 'Size of the stored object in bytes.';


--
-- Name: COLUMN images.status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.status_id IS 'Lifecycle of the media record (foreign key to lifecycle_statuses; ADR-008).';


--
-- Name: COLUMN images.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.metadata IS 'Optional JSONB metadata (EXIF/OCR/context); additive, never queried relationally.';


--
-- Name: COLUMN images.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE images_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.images_history IS 'Immutable version-history of images (INSERT-only; one row per version).';


--
-- Name: COLUMN images_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images_history.original_entity_id IS 'Canonical image this version belongs to (foreign key to images, applied in 0027).';


--
-- Name: COLUMN images_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN images_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN images_history.content_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images_history.content_hash IS 'Content fingerprint of the image at this version (SHA-256).';


--
-- Name: COLUMN images_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN images_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN images_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.images_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE ingredient_aliases; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredient_aliases IS 'Alternate accepted names for an ingredient, for matching and search.';


--
-- Name: COLUMN ingredient_aliases.alias; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_aliases.alias IS 'Alternate accepted name (e.g. E621, monosodium glutamate); never blank.';


--
-- Name: COLUMN ingredient_aliases.language_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_aliases.language_id IS 'Language of a transliteration alias; NULL means language-neutral.';


--
-- Name: COLUMN ingredient_aliases.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_aliases.relationship_type_id IS 'Alias kind: synonym, e_number, transliteration, ... (relationship_types).';


--
-- Name: COLUMN ingredient_aliases.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_aliases.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE ingredient_allergens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredient_allergens IS 'Ingredient-to-allergen relationship (declared and precautionary).';


--
-- Name: COLUMN ingredient_allergens.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_allergens.relationship_type_id IS 'Assertion kind: contains_allergen vs. may_contain_allergen (relationship_types).';


--
-- Name: COLUMN ingredient_allergens.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_allergens.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE ingredient_categories; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredient_categories IS 'Governed hierarchical taxonomy of ingredient categories (self-referencing parent_id).';


--
-- Name: COLUMN ingredient_categories.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories.code IS 'Stable machine reference (snake_case).';


--
-- Name: COLUMN ingredient_categories.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories.parent_id IS 'Optional parent category (self-reference); NULL for taxonomy roots.';


--
-- Name: COLUMN ingredient_categories.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE ingredient_categories_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredient_categories_history IS 'Immutable version-history of ingredient_categories (INSERT-only; one row per version).';


--
-- Name: COLUMN ingredient_categories_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories_history.original_entity_id IS 'Canonical ingredient category this version belongs to (foreign key to ingredient_categories, applied in 0022).';


--
-- Name: COLUMN ingredient_categories_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN ingredient_categories_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN ingredient_categories_history.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories_history.parent_id IS 'Taxonomy parent at this version (self-reference to ingredient_categories, applied in 0022); NULL for taxonomy roots.';


--
-- Name: COLUMN ingredient_categories_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN ingredient_categories_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN ingredient_categories_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_categories_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE ingredient_health_flags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredient_health_flags IS 'Ingredient-to-health-flag relationship (claims, warnings, risks).';


--
-- Name: COLUMN ingredient_health_flags.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_health_flags.relationship_type_id IS 'Kind of flag assertion (has_health_flag, warns_about, ...).';


--
-- Name: COLUMN ingredient_health_flags.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_health_flags.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE ingredient_search_index; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredient_search_index IS 'Derived, rebuildable search index for ingredients (read model; no FK to ingredients).';


--
-- Name: COLUMN ingredient_search_index.ingredient_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_search_index.ingredient_id IS 'Logical reference to ingredients.id; NO foreign key - the search layer is disposable and rebuildable.';


--
-- Name: COLUMN ingredient_search_index.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_search_index.search_name IS 'Normalized primary searchable name (application-built from canonical name/translations).';


--
-- Name: COLUMN ingredient_search_index.search_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_search_index.search_text IS 'Normalized concatenated searchable text: description, category, aliases.';


--
-- Name: COLUMN ingredient_search_index.search_tokens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_search_index.search_tokens IS 'Language-independent normalized search tokens (folded, accent-stripped).';


--
-- Name: COLUMN ingredient_search_index.language_codes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_search_index.language_codes IS 'Languages covered by the searchable text (citext codes, e.g. {ar,en}).';


--
-- Name: COLUMN ingredient_search_index.search_rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_search_index.search_rank IS 'Ranking helper >= 0; higher means the result is promoted.';


--
-- Name: COLUMN ingredient_search_index.generated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_search_index.generated_at IS 'Timestamp when this search row was generated or refreshed (rebuild tracking).';


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
-- Name: TABLE ingredient_translations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredient_translations IS 'Per-language translations of ingredients (unique per ingredient and language).';


--
-- Name: COLUMN ingredient_translations.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_translations.name IS 'Translated canonical name of the ingredient.';


--
-- Name: COLUMN ingredient_translations.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_translations.display_name IS 'User-facing label for the ingredient in this language.';


--
-- Name: COLUMN ingredient_translations.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_translations.search_name IS 'Normalized search variant (e.g. transliteration); NULL when not needed.';


--
-- Name: COLUMN ingredient_translations.translation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredient_translations.translation_status IS 'Governed quality lifecycle of this translation row.';


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
-- Name: TABLE ingredients; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredients IS 'Canonical registry of ingredients (governed, provenance-tracked core entity).';


--
-- Name: COLUMN ingredients.internal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients.internal_code IS 'Stable internal machine reference (unique, citext).';


--
-- Name: COLUMN ingredients.confidence_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients.confidence_level IS 'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';


--
-- Name: COLUMN ingredients.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: COLUMN ingredients.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients.created_by IS 'UUID of the actor that created the row; FK to the future auth service (none yet).';


--
-- Name: COLUMN ingredients.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients.approved_by IS 'UUID of the actor that approved the row; FK to the future auth service (none yet).';


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
-- Name: TABLE ingredients_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingredients_history IS 'Immutable version-history of ingredients (INSERT-only; one row per version).';


--
-- Name: COLUMN ingredients_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients_history.original_entity_id IS 'Canonical ingredient this version belongs to (foreign key to ingredients, applied in 0022).';


--
-- Name: COLUMN ingredients_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN ingredients_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN ingredients_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN ingredients_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN ingredients_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingredients_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE languages; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.languages IS 'Governed registry of supported platform languages (Arabic + English day one).';


--
-- Name: COLUMN languages.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.languages.code IS 'ISO 639-1 two-letter code where available; BCP-47 tag for variants.';


--
-- Name: COLUMN languages.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.languages.name IS 'Canonical English working name; display translations arrive with the i18n milestone.';


--
-- Name: COLUMN languages.native_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.languages.native_name IS 'Endonym of the language in its own script (e.g. العربية).';


--
-- Name: COLUMN languages.is_rtl; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.languages.is_rtl IS 'True for right-to-left scripts.';


--
-- Name: COLUMN languages.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.languages.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE lifecycle_statuses; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.lifecycle_statuses IS 'Shared non-destructive lifecycle vocabulary (ACTIVE, DEPRECATED, ARCHIVED); the status authority for every lookup table.';


--
-- Name: COLUMN lifecycle_statuses.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lifecycle_statuses.id IS 'BIGINT identity key (Architecture Authority directive; exception to the UUID convention, ADR-008).';


--
-- Name: COLUMN lifecycle_statuses.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lifecycle_statuses.code IS 'Stable machine reference: ACTIVE, DEPRECATED, ARCHIVED; future states are data inserts.';


--
-- Name: COLUMN lifecycle_statuses.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lifecycle_statuses.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE measurement_bases; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.measurement_bases IS 'Governed registry of nutrition measurement bases (per_100g, per_serving, per_package, ...).';


--
-- Name: COLUMN measurement_bases.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.measurement_bases.code IS 'Stable machine reference (snake_case, unique); seed vocabulary belongs to Phase 8.';


--
-- Name: COLUMN measurement_bases.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.measurement_bases.name IS 'Canonical English name of the measurement basis.';


--
-- Name: COLUMN measurement_bases.display_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.measurement_bases.display_order IS 'Stable ordering for reference pickers; non-negative.';


--
-- Name: COLUMN measurement_bases.status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.measurement_bases.status_id IS 'Lifecycle of the basis (foreign key to lifecycle_statuses; ADR-008).';


--
-- Name: COLUMN measurement_bases.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.measurement_bases.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE nutrition_type_translations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.nutrition_type_translations IS 'Per-language translations of nutrition fact types (unique per type and language).';


--
-- Name: COLUMN nutrition_type_translations.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_type_translations.name IS 'Translated canonical name of the nutrition fact type.';


--
-- Name: COLUMN nutrition_type_translations.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_type_translations.display_name IS 'User-facing label for the nutrition fact type in this language.';


--
-- Name: COLUMN nutrition_type_translations.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_type_translations.search_name IS 'Normalized search variant; NULL when not needed.';


--
-- Name: COLUMN nutrition_type_translations.translation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_type_translations.translation_status IS 'Governed quality lifecycle of this translation row.';


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
-- Name: TABLE nutrition_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.nutrition_types IS 'Governed registry of nutrition fact types (business knowledge, not ENUM).';


--
-- Name: COLUMN nutrition_types.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types.code IS 'Stable machine reference (snake_case), e.g. energy, protein, sodium.';


--
-- Name: COLUMN nutrition_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE nutrition_types_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.nutrition_types_history IS 'Immutable version-history of nutrition_types (INSERT-only; one row per version).';


--
-- Name: COLUMN nutrition_types_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types_history.original_entity_id IS 'Canonical nutrition type this version belongs to (foreign key to nutrition_types, applied in 0022).';


--
-- Name: COLUMN nutrition_types_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN nutrition_types_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN nutrition_types_history.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types_history.code IS 'Governed machine code at this version (snake_case); not unique in history because several versions share one entity code.';


--
-- Name: COLUMN nutrition_types_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN nutrition_types_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN nutrition_types_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nutrition_types_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE package_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.package_types IS 'Governed registry of packaging types.';


--
-- Name: COLUMN package_types.display_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.package_types.display_order IS 'Stable ordering for reference pickers; non-negative.';


--
-- Name: COLUMN package_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.package_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE permission_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.permission_types IS 'Governed registry of permission classes (read, write, approve, manage, ...).';


--
-- Name: COLUMN permission_types.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.permission_types.code IS 'Stable machine reference (snake_case), e.g. read, write, approve, audit.';


--
-- Name: COLUMN permission_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.permission_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE product_allergens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_allergens IS 'Product-to-allergen exposure relationship (declared and precautionary).';


--
-- Name: COLUMN product_allergens.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_allergens.relationship_type_id IS 'Assertion kind: contains_allergen vs. may_contain_allergen (relationship_types).';


--
-- Name: COLUMN product_allergens.effective_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_allergens.effective_from IS 'Start of validity for this assertion; NULL = from creation.';


--
-- Name: COLUMN product_allergens.effective_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_allergens.effective_to IS 'End of validity for this assertion; NULL = currently effective.';


--
-- Name: COLUMN product_allergens.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_allergens.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE product_barcodes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_barcodes IS 'Product-to-barcode association relationship (many barcodes per product).';


--
-- Name: COLUMN product_barcodes.product_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes.product_id IS 'Owning product (foreign key to products).';


--
-- Name: COLUMN product_barcodes.barcode_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes.barcode_id IS 'Connected canonical barcode (foreign key to barcodes); the barcode row is never duplicated.';


--
-- Name: COLUMN product_barcodes.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes.relationship_type_id IS 'Kind of association (foreign key to relationship_types: primary_barcode, pack_size_variant, ...).';


--
-- Name: COLUMN product_barcodes.effective_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes.effective_from IS 'Start of validity for this association; NULL = from creation.';


--
-- Name: COLUMN product_barcodes.effective_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes.effective_to IS 'End of validity for this association; NULL = currently effective.';


--
-- Name: COLUMN product_barcodes.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE product_barcodes_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_barcodes_history IS 'Immutable version-history of product_barcodes associations (INSERT-only; one row per version).';


--
-- Name: COLUMN product_barcodes_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes_history.original_entity_id IS 'Product-to-barcode association this version belongs to (foreign key to product_barcodes, applied in 0034).';


--
-- Name: COLUMN product_barcodes_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN product_barcodes_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN product_barcodes_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes_history.snapshot_hash IS 'SHA-256 of the snapshot columns, computed by capture_entity_history() at capture time.';


--
-- Name: COLUMN product_barcodes_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes_history.checksum IS 'Checksum of the full history row for tamper evidence, computed by capture_entity_history().';


--
-- Name: COLUMN product_barcodes_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_barcodes_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE product_categories; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_categories IS 'Governed hierarchical taxonomy of product categories (self-referencing parent_id).';


--
-- Name: COLUMN product_categories.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories.code IS 'Stable machine reference (snake_case).';


--
-- Name: COLUMN product_categories.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories.parent_id IS 'Optional parent category (self-reference); NULL for taxonomy roots.';


--
-- Name: COLUMN product_categories.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE product_categories_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_categories_history IS 'Immutable version-history of product_categories (INSERT-only; one row per version).';


--
-- Name: COLUMN product_categories_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories_history.original_entity_id IS 'Canonical product category this version belongs to (foreign key to product_categories, applied in 0022).';


--
-- Name: COLUMN product_categories_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN product_categories_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN product_categories_history.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories_history.parent_id IS 'Taxonomy parent at this version (self-reference to product_categories, applied in 0022); NULL for taxonomy roots.';


--
-- Name: COLUMN product_categories_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN product_categories_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN product_categories_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_categories_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE product_category_translations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_category_translations IS 'Per-language translations of product categories (unique per category and language).';


--
-- Name: COLUMN product_category_translations.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_category_translations.name IS 'Translated canonical name of the product category.';


--
-- Name: COLUMN product_category_translations.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_category_translations.display_name IS 'User-facing label for the product category in this language.';


--
-- Name: COLUMN product_category_translations.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_category_translations.search_name IS 'Normalized search variant; NULL when not needed.';


--
-- Name: COLUMN product_category_translations.translation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_category_translations.translation_status IS 'Governed quality lifecycle of this translation row.';


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
-- Name: TABLE product_health_flags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_health_flags IS 'Product-to-health-flag relationship (claims, warnings, risks).';


--
-- Name: COLUMN product_health_flags.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_health_flags.relationship_type_id IS 'Kind of flag assertion (has_health_flag, warns_about, ...).';


--
-- Name: COLUMN product_health_flags.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_health_flags.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE product_images; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_images IS 'Product-to-image attachment relationship (many images per product).';


--
-- Name: COLUMN product_images.product_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images.product_id IS 'Owning product (foreign key to products).';


--
-- Name: COLUMN product_images.image_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images.image_id IS 'Connected canonical image (foreign key to images); the image row is never duplicated.';


--
-- Name: COLUMN product_images.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images.relationship_type_id IS 'Kind of attachment (foreign key to relationship_types: primary_image, gallery, ...).';


--
-- Name: COLUMN product_images.effective_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images.effective_from IS 'Start of validity for this attachment; NULL = from creation.';


--
-- Name: COLUMN product_images.effective_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images.effective_to IS 'End of validity for this attachment; NULL = currently effective.';


--
-- Name: COLUMN product_images.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE product_images_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_images_history IS 'Immutable version-history of product_images attachments (INSERT-only; one row per version).';


--
-- Name: COLUMN product_images_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images_history.original_entity_id IS 'Product-to-image attachment this version belongs to (foreign key to product_images, applied in 0034).';


--
-- Name: COLUMN product_images_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN product_images_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN product_images_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images_history.snapshot_hash IS 'SHA-256 of the snapshot columns, computed by capture_entity_history() at capture time.';


--
-- Name: COLUMN product_images_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images_history.checksum IS 'Checksum of the full history row for tamper evidence, computed by capture_entity_history().';


--
-- Name: COLUMN product_images_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_images_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE product_ingredients; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_ingredients IS 'Product-to-ingredient membership relationship with optional declared amount.';


--
-- Name: COLUMN product_ingredients.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_ingredients.relationship_type_id IS 'Membership kind (contains_ingredient, may_contain_ingredient, ...).';


--
-- Name: COLUMN product_ingredients.amount_value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_ingredients.amount_value IS 'Optional declared amount of the ingredient; NULL when the label lists no quantity.';


--
-- Name: COLUMN product_ingredients.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_ingredients.unit_id IS 'Unit of amount_value (foreign key to units); NULL when amount is NULL.';


--
-- Name: COLUMN product_ingredients.effective_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_ingredients.effective_from IS 'Start of validity for this relationship; NULL = from creation.';


--
-- Name: COLUMN product_ingredients.effective_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_ingredients.effective_to IS 'End of validity for this relationship; NULL = currently effective.';


--
-- Name: COLUMN product_ingredients.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_ingredients.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE product_nutrition_values; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_nutrition_values IS 'Provenance-tracked nutrition fact values per product.';


--
-- Name: COLUMN product_nutrition_values.relationship_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_nutrition_values.relationship_type_id IS 'Fact kind (provides_nutrition, ...); reserved for future fact sub-kinds.';


--
-- Name: COLUMN product_nutrition_values.amount_value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_nutrition_values.amount_value IS 'Numeric amount of the nutrition fact (non-negative).';


--
-- Name: COLUMN product_nutrition_values.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_nutrition_values.unit_id IS 'Unit of amount_value (foreign key to units).';


--
-- Name: COLUMN product_nutrition_values.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_nutrition_values.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE product_search_index; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_search_index IS 'Derived, rebuildable search index for products (read model; no FK to products).';


--
-- Name: COLUMN product_search_index.product_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_search_index.product_id IS 'Logical reference to products.id; NO foreign key - the search layer is disposable and rebuildable.';


--
-- Name: COLUMN product_search_index.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_search_index.search_name IS 'Normalized primary searchable name (application-built from canonical name/translations).';


--
-- Name: COLUMN product_search_index.search_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_search_index.search_text IS 'Normalized concatenated searchable text: description, category, brand, internal code, aliases.';


--
-- Name: COLUMN product_search_index.search_tokens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_search_index.search_tokens IS 'Language-independent normalized search tokens (folded, accent-stripped).';


--
-- Name: COLUMN product_search_index.language_codes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_search_index.language_codes IS 'Languages covered by the searchable text (citext codes, e.g. {ar,en}).';


--
-- Name: COLUMN product_search_index.search_rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_search_index.search_rank IS 'Ranking helper >= 0; higher means the result is promoted.';


--
-- Name: COLUMN product_search_index.generated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_search_index.generated_at IS 'Timestamp when this search row was generated or refreshed (rebuild tracking).';


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
-- Name: TABLE product_translations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_translations IS 'Per-language translations of products (unique per product and language).';


--
-- Name: COLUMN product_translations.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_translations.name IS 'Translated canonical name of the product.';


--
-- Name: COLUMN product_translations.display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_translations.display_name IS 'User-facing label for the product in this language.';


--
-- Name: COLUMN product_translations.search_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_translations.search_name IS 'Normalized search variant (e.g. transliteration); NULL when not needed.';


--
-- Name: COLUMN product_translations.translation_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_translations.translation_status IS 'Governed quality lifecycle of this translation row.';


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
-- Name: TABLE products; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.products IS 'Canonical registry of products (governed, provenance-tracked core entity).';


--
-- Name: COLUMN products.brand_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products.brand_id IS 'Owning brand (foreign key to brands); NULL for generic/unbranded products.';


--
-- Name: COLUMN products.product_category_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products.product_category_id IS 'Classification node (foreign key to product_categories); NULL when unclassified.';


--
-- Name: COLUMN products.internal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products.internal_code IS 'Stable internal machine reference (unique, citext).';


--
-- Name: COLUMN products.confidence_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products.confidence_level IS 'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';


--
-- Name: COLUMN products.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: COLUMN products.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products.created_by IS 'UUID of the actor that created the row; FK to the future auth service (none yet).';


--
-- Name: COLUMN products.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products.approved_by IS 'UUID of the actor that approved the row; FK to the future auth service (none yet).';


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
-- Name: TABLE products_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.products_history IS 'Immutable version-history of products (INSERT-only; one row per version).';


--
-- Name: COLUMN products_history.original_entity_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products_history.original_entity_id IS 'Canonical product this version belongs to (foreign key to products, applied in 0022).';


--
-- Name: COLUMN products_history.previous_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products_history.previous_version_id IS 'Self-reference to the immediately prior version row; NULL for the first version.';


--
-- Name: COLUMN products_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products_history.change_type IS 'Nature of the change recorded by this version (existing update_type ENUM).';


--
-- Name: COLUMN products_history.brand_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products_history.brand_id IS 'Owning brand at this version (foreign key to brands, applied in 0022); NULL for unbranded products.';


--
-- Name: COLUMN products_history.product_category_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products_history.product_category_id IS 'Classification node at this version (foreign key to product_categories, applied in 0022).';


--
-- Name: COLUMN products_history.snapshot_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products_history.snapshot_hash IS 'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';


--
-- Name: COLUMN products_history.checksum; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products_history.checksum IS 'Checksum of the full history row for tamper evidence.';


--
-- Name: COLUMN products_history.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.products_history.version_status IS 'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';


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
-- Name: TABLE regions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.regions IS 'Governed registry of geopolitical regions (GCC, MENA, Europe, ...) for market scoping.';


--
-- Name: COLUMN regions.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regions.code IS 'Stable machine reference (snake_case), e.g. gcc, mena, europe.';


--
-- Name: COLUMN regions.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regions.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE regulatory_authorities; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.regulatory_authorities IS 'Governed registry of regulatory and standard authorities (sfda, efsa, codex, ...).';


--
-- Name: COLUMN regulatory_authorities.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulatory_authorities.code IS 'Stable machine reference (snake_case), e.g. sfda, gso, efsa, codex_alimentarius.';


--
-- Name: COLUMN regulatory_authorities.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.regulatory_authorities.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE relationship_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.relationship_types IS 'Governed registry of knowledge-graph relationship types between entities.';


--
-- Name: COLUMN relationship_types.is_directional; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.relationship_types.is_directional IS 'True when subject->object order is meaningful (paired with inverse_type_id).';


--
-- Name: COLUMN relationship_types.inverse_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.relationship_types.inverse_type_id IS 'Self-reference to the paired inverse relationship type; NULL when symmetric.';


--
-- Name: COLUMN relationship_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.relationship_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE role_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.role_types IS 'Governed registry of platform user roles (admin, editor, reviewer, expert, ...).';


--
-- Name: COLUMN role_types.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.role_types.code IS 'Stable machine reference (snake_case), e.g. admin, editor, reviewer, expert.';


--
-- Name: COLUMN role_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.role_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version text NOT NULL,
    checksum text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT schema_migrations_version_not_empty CHECK ((length(TRIM(BOTH FROM version)) > 0))
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
-- Name: TABLE source_priorities; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.source_priorities IS 'Governed trust/priority scale for data sources.';


--
-- Name: COLUMN source_priorities.rank; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.source_priorities.rank IS 'Ascending ordinal: higher rank wins conflicts; bounded to 1..99.';


--
-- Name: COLUMN source_priorities.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.source_priorities.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE source_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.source_types IS 'Governed registry of data-source categories.';


--
-- Name: COLUMN source_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.source_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE units; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.units IS 'Governed registry of units of measure, grouped by physical dimension.';


--
-- Name: COLUMN units.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.units.code IS 'Stable machine reference based on the international symbol (e.g. g, kg, kcal).';


--
-- Name: COLUMN units.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.units.name IS 'Canonical English name (e.g. gram).';


--
-- Name: COLUMN units.symbol; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.units.symbol IS 'Display symbol (may differ from code, e.g. code ug / symbol µg).';


--
-- Name: COLUMN units.dimension; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.units.dimension IS 'Physical dimension of the unit; conversions are only legal within one dimension.';


--
-- Name: COLUMN units.is_base_unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.units.is_base_unit IS 'Designates the canonical base unit for a dimension (exactly one per dimension).';


--
-- Name: COLUMN units.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.units.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE verification_statuses; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.verification_statuses IS 'Governed registry of barcode verification states (trust, not lifecycle).';


--
-- Name: COLUMN verification_statuses.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.verification_statuses.code IS 'Stable machine reference (snake_case; e.g. unverified, verified).';


--
-- Name: COLUMN verification_statuses.status_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.verification_statuses.status_id IS 'Lifecycle of the vocabulary row itself (foreign key to lifecycle_statuses).';


--
-- Name: COLUMN verification_statuses.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.verification_statuses.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


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
-- Name: TABLE version_metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.version_metadata IS 'Key/value extension attributes scoped to one entity_versions entry.';


--
-- Name: COLUMN version_metadata.entity_version_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.version_metadata.entity_version_id IS 'Owning version registry entry (foreign key to entity_versions, applied in 0022).';


--
-- Name: COLUMN version_metadata.key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.version_metadata.key IS 'Extension attribute key (snake_case, unique per version).';


--
-- Name: COLUMN version_metadata.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.version_metadata.value IS 'Extension attribute value (text).';


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea
)
PARTITION BY RANGE (inserted_at);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    action_filter text DEFAULT '*'::text,
    selected_columns text[],
    CONSTRAINT subscription_action_filter_check CHECK ((action_filter = ANY (ARRAY['*'::text, 'INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb,
    metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: custom_oauth_providers custom_oauth_providers_identifier_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_identifier_key UNIQUE (identifier);


--
-- Name: custom_oauth_providers custom_oauth_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webauthn_challenges webauthn_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_pkey PRIMARY KEY (id);


--
-- Name: webauthn_credentials webauthn_credentials_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_pkey PRIMARY KEY (id);


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
-- Name: messages messages_payload_exclusive; Type: CHECK CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages
    ADD CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL))) NOT VALID;


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: custom_oauth_providers_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_created_at_idx ON auth.custom_oauth_providers USING btree (created_at);


--
-- Name: custom_oauth_providers_enabled_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_enabled_idx ON auth.custom_oauth_providers USING btree (enabled);


--
-- Name: custom_oauth_providers_identifier_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_identifier_idx ON auth.custom_oauth_providers USING btree (identifier);


--
-- Name: custom_oauth_providers_provider_type_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_provider_type_idx ON auth.custom_oauth_providers USING btree (provider_type);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: idx_users_created_at_desc; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_created_at_desc ON auth.users USING btree (created_at DESC);


--
-- Name: idx_users_email; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_email ON auth.users USING btree (email);


--
-- Name: idx_users_last_sign_in_at_desc; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_last_sign_in_at_desc ON auth.users USING btree (last_sign_in_at DESC);


--
-- Name: idx_users_name; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_name ON auth.users USING btree (((raw_user_meta_data ->> 'name'::text))) WHERE ((raw_user_meta_data ->> 'name'::text) IS NOT NULL);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: webauthn_challenges_expires_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_expires_at_idx ON auth.webauthn_challenges USING btree (expires_at);


--
-- Name: webauthn_challenges_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_user_id_idx ON auth.webauthn_challenges USING btree (user_id);


--
-- Name: webauthn_credentials_credential_id_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX webauthn_credentials_credential_id_key ON auth.webauthn_credentials USING btree (credential_id);


--
-- Name: webauthn_credentials_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_credentials_user_id_idx ON auth.webauthn_credentials USING btree (user_id);


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
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_action_filter_selec; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_action_filter_selec ON realtime.subscription USING btree (subscription_id, entity, filters, action_filter, COALESCE(selected_columns, '{}'::text[]));


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_bucket_id_name_lower; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name_lower ON storage.objects USING btree (bucket_id, lower(name) COLLATE "C");


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


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
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: buckets protect_buckets_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects protect_objects_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: webauthn_challenges webauthn_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: webauthn_credentials webauthn_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


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
-- Name: countries countries_status_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_status_id_fk FOREIGN KEY (status_id) REFERENCES public.lifecycle_statuses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


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
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

\unrestrict kDMzYjV0m1tQCrf18drraMx7P6fxbCIgEzTD0DkfDmeHkky1dPjtDq5CENd3W9H

