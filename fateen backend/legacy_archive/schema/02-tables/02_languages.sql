-- =============================================================================
-- Table: languages
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of the languages the platform supports for
--                content and translation. Arabic and English ship from day one;
--                GCC and global languages are added by governance, not by schema
--                migration (see ADR-001).
-- Work orders:   Foundation Layer, work order #3 (lookup tables).
-- Dependencies:  Extension citext (0001). Enum set (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     Languages are governed data. The code column is the stable,
--                case-insensitive reference that future translation and content
--                tables will foreign-key.
-- Columns:
--   code          ISO 639-1 two-letter code where available; BCP-47 tag for
--                 variants and regional scripts.
--   name          Canonical English working name (display translations arrive
--                 with the i18n milestone).
--   native_name   Endonym: the language's name in itself (e.g. العربية).
--   is_rtl        True for right-to-left scripts (Arabic).
-- =============================================================================
CREATE TABLE languages (
    id           uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code         citext       NOT NULL,
    name         text         NOT NULL,
    native_name  text         NOT NULL,
    is_rtl       boolean      NOT NULL DEFAULT false,
    status_id    bigint        NOT NULL,
    version_number  integer   NOT NULL DEFAULT 1,
    created_at   timestamptz  NOT NULL DEFAULT now(),
    updated_at   timestamptz  NOT NULL DEFAULT now(),
    deleted_at   timestamptz  NULL,

    CONSTRAINT languages_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT languages_code_check
        CHECK (char_length(code) BETWEEN 2 AND 10),
    CONSTRAINT languages_code_unique
        UNIQUE (code)
);

COMMENT ON TABLE languages IS
    'Governed registry of supported platform languages (Arabic + English day one).';
COMMENT ON COLUMN languages.code IS
    'ISO 639-1 two-letter code where available; BCP-47 tag for variants.';
COMMENT ON COLUMN languages.name IS
    'Canonical English working name; display translations arrive with the i18n milestone.';
COMMENT ON COLUMN languages.native_name IS
    'Endonym of the language in its own script (e.g. العربية).';
COMMENT ON COLUMN languages.is_rtl IS
    'True for right-to-left scripts.';
COMMENT ON COLUMN languages.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
