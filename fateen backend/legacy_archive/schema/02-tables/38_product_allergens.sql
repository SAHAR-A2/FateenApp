-- =============================================================================
-- Table: product_allergens
-- -----------------------------------------------------------------------------
-- Purpose:       Relationship between a product and an allergen it contains or
--                may contain. The relationship_type distinguishes declared
--                "contains" from risk-based "may contain" assertions.
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008), product membership relationship.
-- Dependencies:  Tables products, allergens (0012), relationship_types,
--                data_sources, evidence_types, lifecycle_statuses (0003/0008).
--                FKs applied in 0017 (03-constraints).
-- Migration:     0016_relationship_tables.sql
-- Rationale:     Allergen exposure is a risk fact: the same product can carry a
--                confirmed allergen (contains_allergen) and a precautionary
--                allergen (may_contain_allergen). The composite UNIQUE
--                (product, allergen, relationship type) allows both while
--                rejecting duplicate assertions of the same type. Provenance
--                (source_id, evidence_type_id, confidence_level) is stored per
--                assertion so risk weighting can use it.
-- Columns:
--   product_id          Product carrying the allergen (FK products).
--   allergen_id         Allergen asserted for the product (FK allergens).
--   relationship_type_id  Contains vs. may-contain kind (FK relationship_types).
-- =============================================================================
CREATE TABLE product_allergens (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id           uuid          NOT NULL,
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

    CONSTRAINT product_allergens_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT product_allergens_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT product_allergens_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT product_allergens_subject_unique
        UNIQUE (product_id, allergen_id, relationship_type_id)
);

COMMENT ON TABLE product_allergens IS
    'Product-to-allergen exposure relationship (declared and precautionary).';
COMMENT ON COLUMN product_allergens.relationship_type_id IS
    'Assertion kind: contains_allergen vs. may_contain_allergen (relationship_types).';
COMMENT ON COLUMN product_allergens.effective_from IS
    'Start of validity for this assertion; NULL = from creation.';
COMMENT ON COLUMN product_allergens.effective_to IS
    'End of validity for this assertion; NULL = currently effective.';
COMMENT ON COLUMN product_allergens.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
