-- =============================================================================
-- Table: allergen_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of allergen classes (gluten, crustaceans,
--                eggs, fish, peanuts, soy, milk, tree_nuts, sesame, sulfites,
--                ...) attached to products and ingredients for compliance
--                display and filtering.
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Allergen classes are governed, evolving business vocabulary:
--                new regulated allergens, translations, deprecation and
--                governance all apply. Modeling them as a lookup table means
--                future additions are data inserts, never ALTER TYPE.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE allergen_types (
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

    CONSTRAINT allergen_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT allergen_types_code_unique
        UNIQUE (code),
    CONSTRAINT allergen_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE allergen_types IS
    'Governed registry of allergen classes (business knowledge, not ENUM).';
COMMENT ON COLUMN allergen_types.code IS
    'Stable machine reference (snake_case), e.g. gluten, tree_nuts, sesame.';
COMMENT ON COLUMN allergen_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
