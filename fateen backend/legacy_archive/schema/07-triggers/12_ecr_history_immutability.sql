-- =============================================================================
-- Triggers: ECR-001 History Table Immutability
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared prevent_history_mutation() function to the
--                history tables added by ECR-001 (product_images_history,
--                product_barcodes_history). History rows are INSERT-only: UPDATE
--                and DELETE are rejected at the storage layer.
-- Work orders:   ECR-001 Blocker 3 (automatic history capture).
-- Dependencies:  Function prevent_history_mutation() (06-functions, 0024).
--                History tables (0033).
-- Migration:     0037_ecr_triggers.sql
-- Rationale:     Same rule as every other history table: automatic capture
--                writes rows; nobody may change or remove them afterwards.
-- =============================================================================
CREATE TRIGGER product_images_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON product_images_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER product_barcodes_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON product_barcodes_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();
