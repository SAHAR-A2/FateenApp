-- =============================================================================
-- Triggers: ECR-001 New Tables updated_at
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared set_updated_at() function to the tables added
--                by ECR-001 that carry the audit lifecycle columns
--                (measurement_bases, product_images, product_barcodes).
-- Work orders:   ECR-001 (Blocker 1 / Blocker 4 new tables).
-- Dependencies:  Function set_updated_at() (06-functions, 0006). New tables
--                (0032).
-- Migration:     0037_ecr_triggers.sql
-- Rationale:     Every table with updated_at must stamp it on UPDATE. Declaring
--                one trigger per table here keeps the rule explicit and auditable.
-- =============================================================================
CREATE TRIGGER measurement_bases_set_updated_at
    BEFORE UPDATE ON measurement_bases
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER product_images_set_updated_at
    BEFORE UPDATE ON product_images
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER product_barcodes_set_updated_at
    BEFORE UPDATE ON product_barcodes
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
