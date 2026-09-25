-- =============================================================================
-- Triggers: Audit Tables updated_at
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared set_updated_at() function to every Mission 05
--                audit table carrying the audit lifecycle columns.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Function set_updated_at() (06-functions, 0006). Mission 05
--                audit tables (0021).
-- Migration:     0024_history_triggers.sql
-- Rationale:     Every table with updated_at must stamp it on UPDATE. Declaring
--                one trigger per table here keeps the rule explicit and auditable.
-- =============================================================================
CREATE TRIGGER audit_context_set_updated_at
    BEFORE UPDATE ON audit_context
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER change_sets_set_updated_at
    BEFORE UPDATE ON change_sets
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER audit_log_set_updated_at
    BEFORE UPDATE ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER audit_events_set_updated_at
    BEFORE UPDATE ON audit_events
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER entity_versions_set_updated_at
    BEFORE UPDATE ON entity_versions
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER version_metadata_set_updated_at
    BEFORE UPDATE ON version_metadata
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
