-- =============================================================================
-- Table: health_flag_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of health/risk flag classes (allergen,
--                intolerance, restricted_ingredient, recall, contamination,
--                not_suitable_for, other) attached to products and ingredients.
-- Work orders:   Foundation Layer, work order #3 (lookup tables). Refactor per
--                Architecture Authority decision: formerly the health_flag_type
--                ENUM; business knowledge must live in data, not in ENUM types
--                (ADR-001 / ADR-007).
-- Dependencies:  Extension citext (0001). Enum set (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     Health-flag classes are governed, evolving business vocabulary:
--                new classes of risk, translations (Arabic/English), deprecation
--                and governance all apply. Modeling them as a lookup table means
--                future additions are data inserts, never ALTER TYPE.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE health_flag_types (
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

    CONSTRAINT health_flag_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT health_flag_types_code_unique
        UNIQUE (code),
    CONSTRAINT health_flag_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE health_flag_types IS
    'Governed registry of health/risk flag classes (business knowledge, not ENUM).';
COMMENT ON COLUMN health_flag_types.code IS
    'Stable machine reference (snake_case), e.g. allergen, recall.';
COMMENT ON COLUMN health_flag_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
