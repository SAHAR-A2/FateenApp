-- =============================================================================
-- Table: ingredients
-- -----------------------------------------------------------------------------
-- Purpose:       Canonical registry of ingredients (single canonical record per
--                ingredient). Ingredient hierarchies and aliases are separate
--                later-milestone structures; this mission builds the core.
-- Work orders:   Mission 03: Canonical Core Entities (work orders #001-#008),
--                primary business entity per the approved architecture.
-- Dependencies:  Extension citext (0001). Enum set (0002). Lifecycle table
--                lifecycle_statuses (0003), data_sources (0003). Foreign keys
--                are applied in 0013 (03-constraints).
-- Migration:     0012_core_entity_tables.sql
-- Rationale:     Ingredients are governed, provenance-tracked business entities
--                with the canonical governance column set. Translations
--                (Arabic/English) live in ingredient_translations. Category
--                membership (ingredient_categories) is a relationship applied in
--                a later milestone, not duplicated here.
-- Columns:
--   internal_code   Stable internal machine reference (unique, citext).
-- =============================================================================
CREATE TABLE ingredients (
    id               uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    internal_code    citext        NOT NULL,
    name             text          NOT NULL,
    description      text          NULL,
    status_id        bigint        NOT NULL,
    source_id        uuid          NULL,
    confidence_level numeric       NOT NULL DEFAULT 0.5,
    verified_at      timestamptz   NULL,
    approved_at      timestamptz   NULL,
    deprecated_at    timestamptz   NULL,
    version_number   integer       NOT NULL DEFAULT 1,
    created_by       uuid          NULL,
    approved_by      uuid          NULL,
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now(),
    deleted_at       timestamptz   NULL,

    CONSTRAINT ingredients_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT ingredients_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT ingredients_internal_code_unique
        UNIQUE (internal_code)
);

COMMENT ON TABLE ingredients IS
    'Canonical registry of ingredients (governed, provenance-tracked core entity).';
COMMENT ON COLUMN ingredients.internal_code IS
    'Stable internal machine reference (unique, citext).';
COMMENT ON COLUMN ingredients.confidence_level IS
    'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';
COMMENT ON COLUMN ingredients.created_by IS
    'UUID of the actor that created the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN ingredients.approved_by IS
    'UUID of the actor that approved the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN ingredients.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
