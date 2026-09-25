-- =============================================================================
-- Constraints: relationship_types
-- -----------------------------------------------------------------------------
-- Purpose:       Cross-row integrity for the relationship_types registry: the
--                self-referential inverse link must point at a real, distinct
--                row, and symmetric types must not declare an inverse.
-- Work orders:   Foundation Layer, work orders #5 (constraints) and #3.
-- Dependencies:  Table relationship_types (0003). Runs after all tables exist.
-- Migration:     0004_foundation_lookup_constraints.sql
-- Rationale:     A self-referencing foreign key cannot be declared inside the
--                table's CREATE TABLE (the table does not exist yet); it is
--                applied here after the table is committed.
-- =============================================================================
ALTER TABLE relationship_types
    ADD CONSTRAINT relationship_types_inverse_type_id_fk
        FOREIGN KEY (inverse_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- A relationship type must not be its own inverse.
ALTER TABLE relationship_types
    ADD CONSTRAINT relationship_types_inverse_not_self_check
        CHECK (inverse_type_id IS NULL OR inverse_type_id <> id);

-- Symmetric types (is_directional = false) have no inverse by definition.
ALTER TABLE relationship_types
    ADD CONSTRAINT relationship_types_symmetric_no_inverse_check
        CHECK (is_directional OR inverse_type_id IS NULL);
