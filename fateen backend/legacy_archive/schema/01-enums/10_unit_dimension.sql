-- =============================================================================
-- Enum: unit_dimension
-- -----------------------------------------------------------------------------
-- Purpose:       Physical/measurement dimension that a unit of measure belongs to.
--                Used by the units lookup table to group units and by the future
--                unit-conversion layer to scope conversions.
-- Work orders:   Foundation Layer, work order #2 (enumerations). Required by the
--                units lookup table (work order #3).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     Classifying units by dimension makes conversion logic safe: a
--                conversion is only legal within a single dimension, and one base
--                unit per dimension is enforced by a partial unique index.
-- Values:
--   mass       Mass/weight (g, kg, mg, ...).
--   volume     Volume (ml, l, ...).
--   energy     Energy (kcal, kJ, ...).
--   temperature  Temperature (deg_c, deg_f).
--   count      Discrete countable items (piece, pack).
--   ratio      Dimensionless proportions (percent, ppm).
--   amount     Substance amount (mol, international units IU).
--   other      Any measure not covered above.
-- =============================================================================
CREATE TYPE unit_dimension AS ENUM (
    'mass',
    'volume',
    'energy',
    'temperature',
    'count',
    'ratio',
    'amount',
    'other'
);
