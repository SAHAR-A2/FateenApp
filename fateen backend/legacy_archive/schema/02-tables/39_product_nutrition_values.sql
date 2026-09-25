-- =============================================================================
-- Table: product_nutrition_values
-- -----------------------------------------------------------------------------
-- Purpose:       Nutrition fact value for a product: a numeric amount of a
--                nutrition_types fact in a unit of measure, provenance-tracked
--                like every other relationship. One row per (product, fact
--                type, relationship type).
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008), product nutrition-fact relationship.
-- Dependencies:  Tables products (0012), nutrition_types, units,
--                relationship_types, data_sources, evidence_types,
--                lifecycle_statuses (0003/0008). FKs applied in 0017.
-- Migration:     0016_relationship_tables.sql
-- Rationale:     Nutrition facts are governed, evidence-backed assertions: the
--                fact type and its unit are vocabulary rows, the value is
--                numeric, and provenance/confidence are recorded per fact. The
--                UNIQUE (product, nutrition_type, relationship type) prevents a
--                duplicate fact of the same kind. The basis of the value
--                (per-100g, per-serving, ...) is not modeled here; see Mission
--                04 report open questions.
-- Columns:
--   product_id          Product the fact belongs to (FK products).
--   nutrition_type_id   Fact type (energy, protein, sodium, ...) (FK nutrition_types).
--   amount_value        Numeric amount of the fact.
--   unit_id             Unit of amount_value (FK units).
--   relationship_type_id  Fact kind (provides_nutrition, ...) (FK relationship_types).
-- =============================================================================
CREATE TABLE product_nutrition_values (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id           uuid          NOT NULL,
    nutrition_type_id    uuid          NOT NULL,
    relationship_type_id uuid          NOT NULL,
    amount_value         numeric       NOT NULL,
    unit_id              uuid          NOT NULL,
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

    CONSTRAINT product_nutrition_values_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT product_nutrition_values_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT product_nutrition_values_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT product_nutrition_values_amount_nonnegative_check
        CHECK (amount_value >= 0),
    CONSTRAINT product_nutrition_values_fact_unique
        UNIQUE (product_id, nutrition_type_id, relationship_type_id)
);

COMMENT ON TABLE product_nutrition_values IS
    'Provenance-tracked nutrition fact values per product.';
COMMENT ON COLUMN product_nutrition_values.amount_value IS
    'Numeric amount of the nutrition fact (non-negative).';
COMMENT ON COLUMN product_nutrition_values.unit_id IS
    'Unit of amount_value (foreign key to units).';
COMMENT ON COLUMN product_nutrition_values.relationship_type_id IS
    'Fact kind (provides_nutrition, ...); reserved for future fact sub-kinds.';
COMMENT ON COLUMN product_nutrition_values.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
