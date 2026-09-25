-- =============================================================================
-- Table: health_flag_translations
-- -----------------------------------------------------------------------------
-- Purpose:       Per-language translations of health flags. Arabic and English
--                are supported from day one; additional languages are data
--                inserts.
-- Work orders:   Mission 03: Canonical Core Entities (work orders #001-#008),
--                dedicated translation table per translatable entity.
-- Dependencies:  Enum translation_status (0002). Tables health_flags (0012),
--                languages (0003). Foreign keys applied in 0013.
-- Migration:     0012_core_entity_tables.sql
-- Rationale:     No language-specific columns exist in health_flags; all
--                localized text lives here, keyed by (health_flag_id,
--                language_id). Quality is governed per row by
--                translation_status; display_name is the user-facing label and
--                search_name a normalized search variant.
-- Columns:
--   health_flag_id  Owner entity (FK health_flags).
--   language_id     Language of this row (FK languages).
-- =============================================================================
CREATE TABLE health_flag_translations (
    id                 uuid                NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    health_flag_id     uuid                NOT NULL,
    language_id        uuid                NOT NULL,
    name               text                NOT NULL,
    short_name         text                NULL,
    display_name       text                NOT NULL,
    search_name        text                NULL,
    description        text                NULL,
    translation_status translation_status  NOT NULL DEFAULT 'draft',
    version_number     integer             NOT NULL DEFAULT 1,
    created_at         timestamptz         NOT NULL DEFAULT now(),
    updated_at         timestamptz         NOT NULL DEFAULT now(),
    deleted_at         timestamptz         NULL,

    CONSTRAINT health_flag_translations_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT health_flag_translations_health_flag_language_unique
        UNIQUE (health_flag_id, language_id)
);

COMMENT ON TABLE health_flag_translations IS
    'Per-language translations of health flags (unique per flag and language).';
COMMENT ON COLUMN health_flag_translations.name IS
    'Translated canonical name of the health flag.';
COMMENT ON COLUMN health_flag_translations.display_name IS
    'User-facing label for the health flag in this language.';
COMMENT ON COLUMN health_flag_translations.search_name IS
    'Normalized search variant (e.g. transliteration); NULL when not needed.';
COMMENT ON COLUMN health_flag_translations.translation_status IS
    'Governed quality lifecycle of this translation row.';
