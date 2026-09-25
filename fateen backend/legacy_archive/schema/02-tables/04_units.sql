-- =============================================================================
-- Table: units
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of units of measure (mass, volume, energy, ...)
--                referenced by future nutrition and quantity data.
-- Work orders:   Foundation Layer, work order #3 (lookup tables).
-- Dependencies:  Extension citext (0001). Enum unit_dimension (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     Units are grouped by dimension (unit_dimension) so the future
--                conversion layer is provably dimension-safe. Exactly one base
--                unit per dimension is enforced by a partial unique index
--                (04-indexes). A unit may carry a code distinct from its display
--                symbol (e.g. code 'ug', symbol 'µg').
-- Columns:
--   code          Stable machine reference, based on the international symbol
--                 where possible. Not an abbreviation: e.g. 'g' is the SI symbol
--                 for gram.
--   name          Canonical English name.
--   symbol        Display symbol.
--   dimension     Physical dimension (unit_dimension).
--   is_base_unit  True for the canonical base unit within its dimension, used
--                 as the conversion anchor (one per dimension).
-- =============================================================================
CREATE TABLE units (
    id            uuid             NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code          citext           NOT NULL,
    name          text             NOT NULL,
    symbol        text             NOT NULL,
    dimension     unit_dimension   NOT NULL,
    is_base_unit  boolean          NOT NULL DEFAULT false,
    status_id     bigint           NOT NULL,
    version_number  integer        NOT NULL DEFAULT 1,
    created_at    timestamptz      NOT NULL DEFAULT now(),
    updated_at    timestamptz      NOT NULL DEFAULT now(),
    deleted_at    timestamptz      NULL,

    CONSTRAINT units_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT units_code_unique
        UNIQUE (code),
    CONSTRAINT units_symbol_unique
        UNIQUE (symbol)
);

COMMENT ON TABLE units IS
    'Governed registry of units of measure, grouped by physical dimension.';
COMMENT ON COLUMN units.code IS
    'Stable machine reference based on the international symbol (e.g. g, kg, kcal).';
COMMENT ON COLUMN units.name IS
    'Canonical English name (e.g. gram).';
COMMENT ON COLUMN units.symbol IS
    'Display symbol (may differ from code, e.g. code ug / symbol µg).';
COMMENT ON COLUMN units.dimension IS
    'Physical dimension of the unit; conversions are only legal within one dimension.';
COMMENT ON COLUMN units.is_base_unit IS
    'Designates the canonical base unit for a dimension (exactly one per dimension).';
COMMENT ON COLUMN units.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
