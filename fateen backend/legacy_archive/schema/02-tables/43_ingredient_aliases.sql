-- =============================================================================
-- Table: ingredient_aliases
-- -----------------------------------------------------------------------------
-- Purpose:       Alternate names for an ingredient (E-number, trade synonym,
--                regional spelling) used for matching and search. One
--                ingredient has many aliases; an alias belongs to one ingredient.
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008), ingredient naming relationship.
-- Dependencies:  Tables ingredients (0012), languages (0003), relationship_types,
--                data_sources, evidence_types, lifecycle_statuses (0003/0008).
--                FKs applied in 0017 (03-constraints).
-- Migration:     0016_relationship_tables.sql
-- Rationale:     The canonical ingredient name lives in ingredients.name and its
--                localized forms in ingredient_translations; aliases are
--                additional accepted strings (e.g. "E621", "monosodium
--                glutamate", regional transliterations) that must not pollute
--                the canonical name. language_id scopes an alias to a language
--                when it is a transliteration; NULL means language-neutral.
--                UNIQUE (ingredient_id, alias) prevents duplicate aliases.
-- Columns:
--   ingredient_id       Owning ingredient (FK ingredients).
--   alias               Alternate accepted name for the ingredient.
--   language_id         Language of the alias; NULL = language-neutral (FK languages).
--   relationship_type_id  Alias kind (synonym, e_number, transliteration, ...).
-- =============================================================================
CREATE TABLE ingredient_aliases (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    ingredient_id        uuid          NOT NULL,
    alias                text          NOT NULL,
    language_id          uuid          NULL,
    relationship_type_id uuid          NOT NULL,
    source_id            uuid          NULL,
    evidence_type_id     uuid          NULL,
    confidence_level     numeric       NOT NULL DEFAULT 0.5,
    effective_from       timestamptz   NULL,
    effective_to         timestamptz   NULL,
    verified_at          timestamptz   NULL,
    approved_at          timestamptz   NULL,
    status_id            bigint        NOT NULL,
    version_number       integer       NOT NULL DEFAULT 1,
    created_at           timestamptz   NOT NULL DEFAULT now(),
    updated_at           timestamptz   NOT NULL DEFAULT now(),
    deleted_at           timestamptz   NULL,

    CONSTRAINT ingredient_aliases_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT ingredient_aliases_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT ingredient_aliases_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT ingredient_aliases_alias_not_blank_check
        CHECK (alias <> ''),
    CONSTRAINT ingredient_aliases_ingredient_alias_unique
        UNIQUE (ingredient_id, alias)
);

COMMENT ON TABLE ingredient_aliases IS
    'Alternate accepted names for an ingredient, for matching and search.';
COMMENT ON COLUMN ingredient_aliases.alias IS
    'Alternate accepted name (e.g. E621, monosodium glutamate); never blank.';
COMMENT ON COLUMN ingredient_aliases.language_id IS
    'Language of a transliteration alias; NULL means language-neutral.';
COMMENT ON COLUMN ingredient_aliases.relationship_type_id IS
    'Alias kind: synonym, e_number, transliteration, ... (relationship_types).';
COMMENT ON COLUMN ingredient_aliases.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
