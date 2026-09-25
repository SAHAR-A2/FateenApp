-- =============================================================================
-- Indexes: units
-- -----------------------------------------------------------------------------
-- Purpose:       Enforce exactly one base unit per dimension.
-- Work orders:   Foundation Layer, work order #6 (indexes).
-- Dependencies:  Table units (0003). Runs after tables and constraints.
-- Migration:     0005_foundation_lookup_indexes.sql
-- Rationale:     The future unit-conversion layer anchors conversions on the base
--                unit of a dimension. A partial unique index on (dimension)
--                restricted to base units is the invariant that guarantees a
--                single, unambiguous anchor.
-- =============================================================================
CREATE UNIQUE INDEX units_one_base_unit_per_dimension_idx
    ON units (dimension)
    WHERE is_base_unit;
