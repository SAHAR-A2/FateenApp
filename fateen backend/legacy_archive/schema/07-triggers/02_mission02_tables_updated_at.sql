-- =============================================================================
-- Triggers: Foundation Reference Domain tables updated_at
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared set_updated_at() function to the 10 Mission 02
--                reference tables carrying the audit lifecycle columns.
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008).
-- Dependencies:  Function set_updated_at() (06-functions, 0006). Reference
--                tables (0008).
-- Migration:     0011_foundation_reference_triggers.sql
-- Rationale:     Every table with updated_at must stamp it on UPDATE. Declaring
--                one trigger per table here keeps the rule explicit and auditable.
-- =============================================================================
CREATE TRIGGER regions_set_updated_at
    BEFORE UPDATE ON regions
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER ingredient_categories_set_updated_at
    BEFORE UPDATE ON ingredient_categories
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER product_categories_set_updated_at
    BEFORE UPDATE ON product_categories
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER allergen_types_set_updated_at
    BEFORE UPDATE ON allergen_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER nutrition_types_set_updated_at
    BEFORE UPDATE ON nutrition_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER regulatory_authorities_set_updated_at
    BEFORE UPDATE ON regulatory_authorities
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER evidence_types_set_updated_at
    BEFORE UPDATE ON evidence_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER role_types_set_updated_at
    BEFORE UPDATE ON role_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER permission_types_set_updated_at
    BEFORE UPDATE ON permission_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER audit_event_types_set_updated_at
    BEFORE UPDATE ON audit_event_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
