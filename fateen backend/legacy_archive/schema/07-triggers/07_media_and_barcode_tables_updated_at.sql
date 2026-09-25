-- =============================================================================
-- Triggers: Media & Barcode Tables updated_at
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared set_updated_at() function to every Mission 07
--                mutable media/barcode table carrying the audit lifecycle
--                columns. Reuses the existing trigger architecture.
-- Work orders:   Mission 07: Canonical Media & Barcode Domain.
-- Dependencies:  Function set_updated_at() (06-functions, 0006). Media/barcode
--                tables (0025).
-- Migration:     0029_media_and_barcode_triggers.sql
-- Rationale:     Every table with updated_at must stamp it on UPDATE. Declaring
--                one trigger per table here keeps the rule explicit and
--                auditable.
-- =============================================================================
CREATE TRIGGER verification_statuses_set_updated_at
    BEFORE UPDATE ON verification_statuses
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER images_set_updated_at
    BEFORE UPDATE ON images
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER barcodes_set_updated_at
    BEFORE UPDATE ON barcodes
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
