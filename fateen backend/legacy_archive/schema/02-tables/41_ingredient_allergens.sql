-- =============================================================================
-- Table: ingredient_allergens
-- -----------------------------------------------------------------------------
-- Purpose:       Relationship between an ingredient and an allergen class it
--                contains or may contain. The canonical allergen registry
--                (allergens) classifies specific allergens by allergen_type;
--                this table links concrete ingredients to concrete allergens.
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008), ingredient membership relationship.
-- Dependencies:  Tables ingredients, allergens (0012), relationship_types,
--                data_sources, evidence_types, lifecycle_statuses (0003/0008).
--                FKs applied in 0017 (03-constraints).
-- Migration:     0016_relationship_tables.sql
-- Rationale:     An ingredient may carry an allergen (wheat contains gluten) and
--                the same pair may be asserted with distinct relationship types
--                (contains vs. may-contain). UNIQUE (ingredient, allergen,
--                relationship type) rejects duplicate assertions. Ingredient
--                names and allergen data are never duplicated here — only the
--                link and its provenance.
-- Columns:
--   ingredient_id       Ingredient carrying the allergen (FK ingredients).
--   allergen_id         Allergen asserted for the ingredient (FK allergens).
--   relationship_type_id  Contains vs. may-contain kind (FK relationship_types).
-- =============================================================================
CREATE TABLE ingredient_allergens (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    ingredient_id        uuid          NOT NULL,
    allergen_id          uuid          NOT NULL,
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

    CONSTRAINT ingredient_allergens_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT ingredient_allergens_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT ingredient_allergens_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT ingredient_allergens_subject_unique
        UNIQUE (ingredient_id, allergen_id, relationship_type_id)
);

COMMENT ON TABLE ingredient_allergens IS
    'Ingredient-to-allergen relationship (declared and precautionary).';
COMMENT ON COLUMN ingredient_allergens.relationship_type_id IS
    'Assertion kind: contains_allergen vs. may_contain_allergen (relationship_types).';
COMMENT ON COLUMN ingredient_allergens.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
