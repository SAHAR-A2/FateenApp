-- =============================================================================
-- Table: nutrition_type_translations
-- -----------------------------------------------------------------------------
-- Purpose:       Per-language translations of nutrition fact types. The base
--                registry (nutrition_types, mission 02) already exists as a
--                governed lookup table (ADR-008); this mission adds its
--                translation layer. Arabic and English supported from day one.
-- Work orders:   Mission 03: Canonical Core Entities (work orders #001-#008),
--                dedicated translation table per translatable entity.
-- Dependencies:  Enum translation_status (0002). Tables nutrition_types (0008),
--                languages (0003). Foreign keys applied in 0013.
-- Migration:     0012_core_entity_tables.sql
-- Rationale:     nutrition_types is unchanged from Mission 02 (no redesign);
--                localized display text arrives here. Keyed by
--                (nutrition_type_id, language_id). Quality is governed per row
--                by translation_status.
-- Columns:
--   nutrition_type_id  Owner entity (FK nutrition_types).
--   language_id        Language of this row (FK languages).
-- =============================================================================
CREATE TABLE nutrition_type_translations (
    id                 uuid                NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    nutrition_type_id  uuid                NOT NULL,
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

    CONSTRAINT nutrition_type_translations_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT nutrition_type_translations_nutrition_type_language_unique
        UNIQUE (nutrition_type_id, language_id)
);

COMMENT ON TABLE nutrition_type_translations IS
    'Per-language translations of nutrition fact types (unique per type and language).';
COMMENT ON COLUMN nutrition_type_translations.name IS
    'Translated canonical name of the nutrition fact type.';
COMMENT ON COLUMN nutrition_type_translations.display_name IS
    'User-facing label for the nutrition fact type in this language.';
COMMENT ON COLUMN nutrition_type_translations.search_name IS
    'Normalized search variant; NULL when not needed.';
COMMENT ON COLUMN nutrition_type_translations.translation_status IS
    'Governed quality lifecycle of this translation row.';
