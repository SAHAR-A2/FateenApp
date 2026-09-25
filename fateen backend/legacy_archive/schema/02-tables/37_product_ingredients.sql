-- =============================================================================
-- Table: product_ingredients
-- -----------------------------------------------------------------------------
-- Purpose:       Relationship between a product and an ingredient it contains,
--                including an optional declared amount. The authoritative
--                ingredient list of a product is the set of ACTIVE rows here.
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008), product membership relationship.
-- Dependencies:  Tables products, ingredients (0012), relationship_types,
--                data_sources, evidence_types, units, lifecycle_statuses
--                (0003/0008). FKs applied in 0017 (03-constraints).
-- Migration:     0016_relationship_tables.sql
-- Rationale:     A product may contain an ingredient via multiple relationship
--                types (contains_ingredient, may_contain_ingredient, ...). The
--                composite UNIQUE (product, ingredient, relationship type)
--                prevents duplicate assertions while leaving room for distinct
--                types. amount_value/unit_id are optional: many labels list
--                ingredients without declared quantities. Provenance and
--                confidence are carried per relationship (source_id,
--                evidence_type_id, confidence_level).
-- Columns:
--   product_id          Owning product (FK products).
--   ingredient_id       Contained ingredient (FK ingredients).
--   relationship_type_id  Type of membership (FK relationship_types).
--   amount_value        Optional declared amount; NULL when not declared.
--   unit_id             Unit of amount_value (FK units); NULL when amount NULL.
-- =============================================================================
CREATE TABLE product_ingredients (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id           uuid          NOT NULL,
    ingredient_id        uuid          NOT NULL,
    relationship_type_id uuid          NOT NULL,
    amount_value         numeric       NULL,
    unit_id              uuid          NULL,
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

    CONSTRAINT product_ingredients_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT product_ingredients_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT product_ingredients_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT product_ingredients_amount_nonnegative_check
        CHECK (amount_value IS NULL OR amount_value >= 0),
    CONSTRAINT product_ingredients_amount_unit_pairing_check
        CHECK ((amount_value IS NULL AND unit_id IS NULL) OR (amount_value IS NOT NULL)),
    CONSTRAINT product_ingredients_subject_unique
        UNIQUE (product_id, ingredient_id, relationship_type_id)
);

COMMENT ON TABLE product_ingredients IS
    'Product-to-ingredient membership relationship with optional declared amount.';
COMMENT ON COLUMN product_ingredients.amount_value IS
    'Optional declared amount of the ingredient; NULL when the label lists no quantity.';
COMMENT ON COLUMN product_ingredients.unit_id IS
    'Unit of amount_value (foreign key to units); NULL when amount is NULL.';
COMMENT ON COLUMN product_ingredients.relationship_type_id IS
    'Membership kind (contains_ingredient, may_contain_ingredient, ...).';
COMMENT ON COLUMN product_ingredients.effective_from IS
    'Start of validity for this relationship; NULL = from creation.';
COMMENT ON COLUMN product_ingredients.effective_to IS
    'End of validity for this relationship; NULL = currently effective.';
COMMENT ON COLUMN product_ingredients.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
