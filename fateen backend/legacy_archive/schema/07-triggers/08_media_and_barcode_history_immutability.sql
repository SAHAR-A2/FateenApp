-- =============================================================================
-- Triggers: Media & Barcode History Immutability
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared prevent_history_mutation() function to every
--                Mission 07 history table. History rows are INSERT-only: UPDATE
--                and DELETE are rejected at the storage layer.
-- Work orders:   Mission 07: Canonical Media & Barcode Domain.
-- Dependencies:  Function prevent_history_mutation() (06-functions, 0024).
--                Mission 07 history tables (0026).
-- Migration:     0029_media_and_barcode_triggers.sql
-- Rationale:     One trigger per history table keeps the rule explicit and
--                auditable, matching the repository's per-table trigger style.
-- =============================================================================
CREATE TRIGGER images_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON images_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER barcodes_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON barcodes_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();
