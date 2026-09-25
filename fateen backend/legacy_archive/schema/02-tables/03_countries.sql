-- =============================================================================
-- Table: countries
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of countries, keyed to ISO 3166-1. Supports
--                the Saudi-first deployment and the GCC/global expansion phases.
-- Work orders:   Foundation Layer, work order #3 (lookup tables).
-- Dependencies:  Extension citext (0001). Enum set (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     Countries scope data sources and future market content. The
--                ISO 3166-1 codes are stored in their canonical forms and are
--                unique and case-insensitive.
-- Columns:
--   code           ISO 3166-1 alpha-2 (SA, AE, US, ...).
--   alpha_3        ISO 3166-1 alpha-3 (SAU, ARE, USA, ...).
--   numeric_code   ISO 3166-1 numeric three-digit code (682, 784, 840, ...).
--   is_gcc_member  True for Gulf Cooperation Council member states; feeds the
--                  GCC expansion phase.
-- =============================================================================
CREATE TABLE countries (
    id             uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code           citext       NOT NULL,
    alpha_3        citext       NOT NULL,
    numeric_code   text         NOT NULL,
    name           text         NOT NULL,
    is_gcc_member  boolean      NOT NULL DEFAULT false,
    status_id      bigint        NOT NULL,
    version_number  integer     NOT NULL DEFAULT 1,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    updated_at     timestamptz  NOT NULL DEFAULT now(),
    deleted_at     timestamptz  NULL,

    CONSTRAINT countries_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT countries_code_check
        CHECK (code ~ '^[A-Za-z]{2}$'),
    CONSTRAINT countries_alpha_3_check
        CHECK (alpha_3 ~ '^[A-Za-z]{3}$'),
    CONSTRAINT countries_numeric_code_check
        CHECK (numeric_code ~ '^[0-9]{3}$'),
    CONSTRAINT countries_code_unique
        UNIQUE (code),
    CONSTRAINT countries_alpha_3_unique
        UNIQUE (alpha_3),
    CONSTRAINT countries_numeric_code_unique
        UNIQUE (numeric_code)
);

COMMENT ON TABLE countries IS
    'Governed registry of countries (ISO 3166-1), Saudi-first with GCC/global scope.';
COMMENT ON COLUMN countries.code IS
    'ISO 3166-1 alpha-2 country code.';
COMMENT ON COLUMN countries.alpha_3 IS
    'ISO 3166-1 alpha-3 country code.';
COMMENT ON COLUMN countries.numeric_code IS
    'ISO 3166-1 numeric three-digit country code.';
COMMENT ON COLUMN countries.is_gcc_member IS
    'True for Gulf Cooperation Council member states; feeds the GCC expansion phase.';
COMMENT ON COLUMN countries.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
