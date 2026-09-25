-- =============================================================================
-- Triggers: History Table Immutability
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared prevent_history_mutation() function to every
--                Mission 05 history table. History rows are INSERT-only: UPDATE
--                and DELETE are rejected at the storage layer.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Function prevent_history_mutation() (06-functions, 0024).
--                Mission 05 history tables (0020).
-- Migration:     0024_history_triggers.sql
-- Rationale:     One trigger per history table keeps the rule explicit and
--                auditable, matching the repository's per-table trigger style.
-- =============================================================================
CREATE TRIGGER companies_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON companies_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER brands_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON brands_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER products_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON products_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER ingredients_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON ingredients_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER allergens_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON allergens_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER health_flags_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON health_flags_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER nutrition_types_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON nutrition_types_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER product_categories_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON product_categories_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();

CREATE TRIGGER ingredient_categories_history_prevent_mutation
    BEFORE UPDATE OR DELETE ON ingredient_categories_history
    FOR EACH ROW
    EXECUTE FUNCTION prevent_history_mutation();
