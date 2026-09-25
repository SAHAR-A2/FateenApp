-- =============================================================================
-- Indexes: relationship_types
-- -----------------------------------------------------------------------------
-- Purpose:       Index the self-referential inverse link.
-- Work orders:   Foundation Layer, work order #6 (indexes).
-- Dependencies:  Table relationship_types (0003) and its constraints (0004).
-- Migration:     0005_foundation_lookup_indexes.sql
-- Rationale:     PostgreSQL does not automatically index foreign-key columns.
--                inverse_type_id is queried to resolve inverse relationships, so
--                it is indexed here.
-- =============================================================================
CREATE INDEX relationship_types_inverse_type_id_idx
    ON relationship_types (inverse_type_id)
    WHERE inverse_type_id IS NOT NULL;
