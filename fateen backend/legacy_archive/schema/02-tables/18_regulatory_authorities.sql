-- =============================================================================
-- Table: regulatory_authorities
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of regulatory and standard authorities
--                (sfda, gso, efsa, fda, codex_alimentarius, ...) whose rules and
--                publications are cited as evidence by governed facts.
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Authorities are governed, evolving business vocabulary: new
--                bodies, translations, deprecation and governance are data
--                inserts, never schema changes. Authorities anchor the
--                provenance of regulatory evidence in the evidence milestone.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE regulatory_authorities (
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

    CONSTRAINT regulatory_authorities_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT regulatory_authorities_code_unique
        UNIQUE (code),
    CONSTRAINT regulatory_authorities_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE regulatory_authorities IS
    'Governed registry of regulatory and standard authorities (sfda, efsa, codex, ...).';
COMMENT ON COLUMN regulatory_authorities.code IS
    'Stable machine reference (snake_case), e.g. sfda, gso, efsa, codex_alimentarius.';
COMMENT ON COLUMN regulatory_authorities.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
