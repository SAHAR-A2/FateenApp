-- =============================================================================
-- Triggers: Automatic History Capture (ECR-001, Blocker 3)
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared capture_entity_history() function to every
--                table that owns an immutable {table}_history table, so history
--                is recorded automatically on INSERT and on material UPDATE.
--                Application developers never maintain history manually.
-- Work orders:   ECR-001 Blocker 3 (automatic history capture).
-- Dependencies:  Function capture_entity_history() (06-functions, 0036).
--                Tracked tables: 9 Mission 05 canonical entities, images and
--                barcodes (0025), product_images and product_barcodes (0032).
-- Migration:     0037_ecr_triggers.sql
-- Rationale:     One trigger per tracked table keeps the rule explicit and
--                auditable, matching the repository's per-table trigger style.
--                BEFORE INSERT OR UPDATE allows the trigger to maintain
--                NEW.version_number for the chain. No recursion: history tables
--                carry no INSERT triggers (their only triggers are the
--                INSERT-only prevent_history_mutation guards).
-- =============================================================================
CREATE TRIGGER companies_capture_history
    BEFORE INSERT OR UPDATE ON companies
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER brands_capture_history
    BEFORE INSERT OR UPDATE ON brands
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER products_capture_history
    BEFORE INSERT OR UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER ingredients_capture_history
    BEFORE INSERT OR UPDATE ON ingredients
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER allergens_capture_history
    BEFORE INSERT OR UPDATE ON allergens
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER health_flags_capture_history
    BEFORE INSERT OR UPDATE ON health_flags
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER nutrition_types_capture_history
    BEFORE INSERT OR UPDATE ON nutrition_types
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER product_categories_capture_history
    BEFORE INSERT OR UPDATE ON product_categories
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER ingredient_categories_capture_history
    BEFORE INSERT OR UPDATE ON ingredient_categories
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER images_capture_history
    BEFORE INSERT OR UPDATE ON images
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER barcodes_capture_history
    BEFORE INSERT OR UPDATE ON barcodes
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER product_images_capture_history
    BEFORE INSERT OR UPDATE ON product_images
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();

CREATE TRIGGER product_barcodes_capture_history
    BEFORE INSERT OR UPDATE ON product_barcodes
    FOR EACH ROW
    EXECUTE FUNCTION capture_entity_history();
