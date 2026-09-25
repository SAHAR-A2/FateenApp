-- =============================================================================
-- Triggers: entity_relationships Endpoint Validation (ECR-001, Blocker 2)
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared validate_entity_relationship_endpoints()
--                function to entity_relationships so every INSERT and UPDATE is
--                checked at the storage layer: the database rejects edges whose
--                subject or object endpoint does not exist.
-- Work orders:   ECR-001 Blocker 2 (entity reference validation).
-- Dependencies:  Function validate_entity_relationship_endpoints()
--                (06-functions, 0036). Table entity_relationships (0016).
-- Migration:     0037_ecr_triggers.sql
-- Rationale:     BEFORE INSERT OR UPDATE validates both polymorphic endpoints
--                before the row is stored. entity_relationships itself is
--                unchanged; the validation layer is purely additive.
-- =============================================================================
CREATE TRIGGER entity_relationships_validate_endpoints
    BEFORE INSERT OR UPDATE ON entity_relationships
    FOR EACH ROW
    EXECUTE FUNCTION validate_entity_relationship_endpoints();
