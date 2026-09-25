-- =============================================================================
-- Function: capture_entity_history() — ECR-003 corrected implementation
-- -----------------------------------------------------------------------------
-- Purpose:       ECR-003 REPLACEMENT for the ECR-001 snapshot trigger function.
--                CREATE OR REPLACE (same signature) so the 13 capture triggers
--                wired in migration 0037 keep working unchanged.
-- Defect fixed:   The ECR-001 body built its INSERT value list as strings such
--                as 'NEW.brand_id' and embedded them inside the dynamically
--                EXECUTEd SQL. Dynamic SQL runs in its own SPI context and has
--                NO access to the PL/pgSQL NEW/OLD record bindings, so every
--                INSERT/UPDATE on a tracked entity failed at runtime. A second
--                latent defect (version_number appearing both as the header
--                column and again via the generic column loop) is also removed.
-- Fix:           Values are now passed with a single bound parameter ($1):
--                the snapshot is materialised with to_jsonb(NEW), mapped to the
--                history column names (created_by -> changed_by, updated_by ->
--                never captured), and expanded into the INSERT via
--                jsonb_populate_record(NULL::<history_type>, $1). No value ever
--                appears as a literal token in the executed SQL; identifiers
--                remain quoted via quote_ident/%I. Behavior preserved:
--                  - INSERT/UPDATE capture on all 13 history-owning tables
--                  - immutable history (INSERT-only, unchanged by 0037 triggers)
--                  - version chain (previous_version_id + version_number)
--                  - no-op snapshot suppression (jsonb compare excluding
--                    updated_at)
--                  - tamper evidence (snapshot_hash / checksum unchanged)
--                  - no recursion (history tables carry no INSERT triggers)
-- Work orders:   ECR-003 (runtime defect fix).
-- Dependencies:  Extension pgcrypto (0001). Lifecycle lifecycle_statuses
--                (0003/0007) for change-type mapping. Matching {table}_history
--                tables (0020/0026/0033) and the 0037 capture triggers.
-- Migration:     0038_ecr_fix_capture_history.sql
-- =============================================================================
CREATE OR REPLACE FUNCTION capture_entity_history()
RETURNS trigger
LANGUAGE plpgsql
AS $$
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
$$;

COMMENT ON FUNCTION capture_entity_history() IS
    'Automatically records an immutable snapshot into {table}_history on INSERT/UPDATE of a tracked entity; preserves the version chain, prevents duplicate snapshots, and never recurses.';
