-- =============================================================================
-- Table: regions
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of geopolitical regions (GCC, MENA, Europe,
--                North America, ...) that scope market and expansion content.
--                Flat today with no nested hierarchy; future country-to-region
--                links arrive with the market-scoping milestone.
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Regions are governed, evolving business vocabulary: they are
--                translated, reordered, deprecated and governed over time. A
--                lookup table means future additions are data inserts, never
--                schema changes. The Saudi-first and GCC/global expansion phases
--                use these regions to scope market content.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE regions (
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

    CONSTRAINT regions_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT regions_code_unique
        UNIQUE (code),
    CONSTRAINT regions_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE regions IS
    'Governed registry of geopolitical regions (GCC, MENA, Europe, ...) for market scoping.';
COMMENT ON COLUMN regions.code IS
    'Stable machine reference (snake_case), e.g. gcc, mena, europe.';
COMMENT ON COLUMN regions.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
