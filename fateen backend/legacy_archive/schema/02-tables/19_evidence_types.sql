-- =============================================================================
-- Table: evidence_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of evidence kinds that back governed facts
--                (scientific_study, regulatory_document, label_image,
--                manufacturer_statement, user_report, ...).
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Evidence kinds are governed, evolving business vocabulary:
--                translated, reordered, deprecated and governed over time. New
--                kinds are data inserts, never schema changes. Future fact rows
--                cite evidence_type for provenance and confidence weighting.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE evidence_types (
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

    CONSTRAINT evidence_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT evidence_types_code_unique
        UNIQUE (code),
    CONSTRAINT evidence_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE evidence_types IS
    'Governed registry of evidence kinds that back governed facts.';
COMMENT ON COLUMN evidence_types.code IS
    'Stable machine reference (snake_case), e.g. scientific_study, label_image.';
COMMENT ON COLUMN evidence_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
