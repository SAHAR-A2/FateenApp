-- =============================================================================
-- Function: capture_entity_history()
-- -----------------------------------------------------------------------------
-- Purpose:       Shared trigger function that AUTOMATICALLY records an immutable
--                snapshot into the {table}_history table whenever a tracked
--                entity row is inserted or materially changed. Application
--                developers never maintain history manually.
-- Work orders:   ECR-001 Blocker 3 (automatic history capture).
-- Dependencies:  Extension pgcrypto (0001, digest()/encode()). Lifecycle
--                lifecycle_statuses (0003/0007) for change-type mapping. A
--                matching {table}_history table per wired trigger (0033).
-- Migration:     0036_ecr_functions.sql
-- Rationale:     One generic function serves every tracked table. It reflects on
--                the trigger's own table via information_schema, copies every
--                entity column that exists (possibly renamed) in the history
--                table, and computes the history header itself:
--                  - id            -> original_entity_id
--                  - created_by    -> changed_by
--                  - approved_by   -> approved_by
--                  - updated_at    -> never captured (immutable rows carry none)
--                  - updated_by/reviewed_by -> never captured (not snapshot state)
--                Guarantees:
--                  - version chain: previous_version_id = latest existing history
--                    row for the entity; version_number adapts to the entity's
--                    counter (auto-increments only when the app does not manage
--                    version_number itself, so manual governance is respected).
--                  - immutability: history rows are INSERT-only; the existing
--                    prevent_history_mutation() triggers still reject UPDATE/
--                    DELETE. No trigger fires on the history INSERT (history
--                    tables carry no INSERT triggers), so there is NO recursion.
--                  - no duplicate snapshots: an UPDATE that changes nothing but
--                    updated_at is detected (jsonb comparison excluding
--                    updated_at) and skipped without a history row or a version
--                    bump.
--                  - tamper evidence: snapshot_hash = SHA-256 of the full
--                    snapshot jsonb; checksum = SHA-256 of
--                    snapshot_hash|id|version|change_type.
--                change_set_id stays NULL (no automatic change-set grouping yet);
--                change_reason stays NULL. version_status keeps its 'draft'
--                default (the existing version-status lifecycle semantics are
--                preserved unchanged).
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
    ins_vals        text[] := '{}';
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

    -- Build the snapshot column list from the entity columns that exist
    -- (possibly renamed) in the history table.
    FOR col IN
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = TG_TABLE_NAME
          AND column_name NOT IN ('id', 'updated_at', 'updated_by', 'reviewed_by')
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
            ins_cols := ins_cols || quote_ident(target_col);
            IF col.column_name = 'created_by' THEN
                IF has_updated_by THEN
                    ins_vals := ins_vals || format('COALESCE(NEW.%I, NEW.%I)', 'updated_by', 'created_by');
                ELSE
                    ins_vals := ins_vals || format('NEW.%I', 'created_by');
                END IF;
            ELSE
                ins_vals := ins_vals || format('NEW.%I', col.column_name);
            END IF;
        END IF;
    END LOOP;

    -- previous_version_id = the latest history row for this entity.
    EXECUTE format(
        'SELECT id FROM %I WHERE original_entity_id = %L ORDER BY version_number DESC LIMIT 1',
        hist_table, NEW.id
    ) INTO prev_id;

    snapshot     := to_jsonb(NEW) - 'updated_at';
    snap_hash    := encode(digest(snapshot::text, 'sha256'), 'hex');
    row_checksum := encode(
        digest(snap_hash || '|' || NEW.id::text || '|' || NEW.version_number::text || '|' || ct::text, 'sha256'),
        'hex'
    );

    EXECUTE format(
        'INSERT INTO %I (original_entity_id, version_number, previous_version_id, change_type, snapshot_hash, checksum, %s) VALUES (%L, %L, %L, %L, %L, %L, %s)',
        hist_table,
        array_to_string(ins_cols, ', '),
        NEW.id,
        NEW.version_number,
        prev_id,
        ct,
        snap_hash,
        row_checksum,
        array_to_string(ins_vals, ', ')
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION capture_entity_history() IS
    'Automatically records an immutable snapshot into {table}_history on INSERT/UPDATE of a tracked entity; preserves the version chain, prevents duplicate snapshots, and never recurses.';
