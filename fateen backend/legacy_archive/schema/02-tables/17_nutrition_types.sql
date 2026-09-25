-- =============================================================================
-- Table: nutrition_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of nutrition fact types (energy, protein,
--                total_fat, saturated_fat, carbohydrate, sugars, fiber, sodium,
--                ...) referenced by future per-100g / per-serving fact rows.
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Nutrition fact types are governed business vocabulary: labels
--                and regulations evolve, translations apply, and facts must not
--                be coupled to a frozen ENUM (ADR-007). New fact types are data
--                inserts, never schema changes. Values are recorded in `units`
--                by the future nutrition milestone.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE nutrition_types (
    id             uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code           citext       NOT NULL,
    name           text         NOT NULL,
    description    text         NULL,
    display_order  integer      NOT NULL DEFAULT 0,
    status_id      bigint        NOT NULL,
    version_number  integer     NOT NULL DEFAULT 1,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    updated_at     timestamptz  NOT NULL DEFAULT now(),
    deleted_at     timestamptz  NULL,

    CONSTRAINT nutrition_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT nutrition_types_code_unique
        UNIQUE (code),
    CONSTRAINT nutrition_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE nutrition_types IS
    'Governed registry of nutrition fact types (business knowledge, not ENUM).';
COMMENT ON COLUMN nutrition_types.code IS
    'Stable machine reference (snake_case), e.g. energy, protein, sodium.';
COMMENT ON COLUMN nutrition_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
