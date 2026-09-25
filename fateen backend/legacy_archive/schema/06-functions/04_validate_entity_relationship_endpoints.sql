-- =============================================================================
-- Function: validate_entity_relationship_endpoints()
-- -----------------------------------------------------------------------------
-- Purpose:       Database-level validation for the polymorphic knowledge-graph
--                edge table entity_relationships. The subject_id/object_id
--                endpoints carry no foreign key (the endpoint type is dynamic),
--                so this trigger function verifies at the storage layer that
--                every referenced entity actually exists in its declared entity
--                table. The database REJECTS relationships that reference
--                non-existing entities.
-- Work orders:   ECR-001 Blocker 2 (entity reference validation).
-- Dependencies:  Core entities companies, brands, products, ingredients,
--                allergens, health_flags (0012). Table entity_relationships
--                (0016). Wired by trigger in 0037.
-- Migration:     0036_ecr_functions.sql
-- Rationale:     The endpoint entity-type column is CHECK-constrained to the six
--                canonical core entities, so the mapping below is a closed,
--                explicit CASE (no dynamic SQL, no injection surface). For each
--                endpoint an existence probe runs against the matching entity
--                table; a missing row raises an exception that aborts the whole
--                statement, so an edge can never point at a UUID that does not
--                exist. This complements (does not replace) the existing CHECK
--                constraints, the UNIQUE edge constraint, and the no-self-loop
--                guard. entity_relationships itself is unchanged (no redesign).
-- =============================================================================
CREATE OR REPLACE FUNCTION validate_entity_relationship_endpoints()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    subject_ok boolean;
    object_ok  boolean;
BEGIN
    subject_ok := CASE NEW.subject_entity_type
        WHEN 'companies'    THEN EXISTS (SELECT 1 FROM companies    WHERE id = NEW.subject_id)
        WHEN 'brands'       THEN EXISTS (SELECT 1 FROM brands       WHERE id = NEW.subject_id)
        WHEN 'products'     THEN EXISTS (SELECT 1 FROM products     WHERE id = NEW.subject_id)
        WHEN 'ingredients'  THEN EXISTS (SELECT 1 FROM ingredients  WHERE id = NEW.subject_id)
        WHEN 'allergens'    THEN EXISTS (SELECT 1 FROM allergens    WHERE id = NEW.subject_id)
        WHEN 'health_flags' THEN EXISTS (SELECT 1 FROM health_flags WHERE id = NEW.subject_id)
        ELSE NULL
    END;

    IF subject_ok IS NULL THEN
        RAISE EXCEPTION 'entity_relationships: unknown subject_entity_type %', NEW.subject_entity_type;
    END IF;
    IF NOT subject_ok THEN
        RAISE EXCEPTION 'entity_relationships: subject entity % does not exist (id %)',
            NEW.subject_entity_type, NEW.subject_id;
    END IF;

    object_ok := CASE NEW.object_entity_type
        WHEN 'companies'    THEN EXISTS (SELECT 1 FROM companies    WHERE id = NEW.object_id)
        WHEN 'brands'       THEN EXISTS (SELECT 1 FROM brands       WHERE id = NEW.object_id)
        WHEN 'products'     THEN EXISTS (SELECT 1 FROM products     WHERE id = NEW.object_id)
        WHEN 'ingredients'  THEN EXISTS (SELECT 1 FROM ingredients  WHERE id = NEW.object_id)
        WHEN 'allergens'    THEN EXISTS (SELECT 1 FROM allergens    WHERE id = NEW.object_id)
        WHEN 'health_flags' THEN EXISTS (SELECT 1 FROM health_flags WHERE id = NEW.object_id)
        ELSE NULL
    END;

    IF object_ok IS NULL THEN
        RAISE EXCEPTION 'entity_relationships: unknown object_entity_type %', NEW.object_entity_type;
    END IF;
    IF NOT object_ok THEN
        RAISE EXCEPTION 'entity_relationships: object entity % does not exist (id %)',
            NEW.object_entity_type, NEW.object_id;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION validate_entity_relationship_endpoints() IS
    'Rejects entity_relationships rows whose subject or object endpoint does not exist in its declared entity table (database-level polymorphic reference validation).';
