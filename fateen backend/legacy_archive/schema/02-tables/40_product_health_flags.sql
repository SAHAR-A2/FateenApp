-- =============================================================================
-- Table: product_health_flags
-- -----------------------------------------------------------------------------
-- Purpose:       Relationship between a product and a health_flag it carries
--                (claim, warning, risk). The relationship_type distinguishes
--                asserted claims from machine-derived warnings when needed.
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008), product membership relationship.
-- Dependencies:  Tables products, health_flags (0012), relationship_types,
--                data_sources, evidence_types, lifecycle_statuses (0003/0008).
--                FKs applied in 0017 (03-constraints).
-- Migration:     0016_relationship_tables.sql
-- Rationale:     A product can carry several flags; a flag can apply to many
--                products. The composite UNIQUE (product, flag, relationship
--                type) prevents duplicate assertions. Flags are governed rows in
--                health_flags; this table stores only the link and its
--                provenance, never flag text (no duplication, ADR-007).
-- Columns:
--   product_id          Product the flag applies to (FK products).
--   health_flag_id      Applied flag (FK health_flags).
--   relationship_type_id  Kind of assertion (FK relationship_types).
-- =============================================================================
CREATE TABLE product_health_flags (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id           uuid          NOT NULL,
    health_flag_id       uuid          NOT NULL,
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

    CONSTRAINT product_health_flags_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT product_health_flags_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT product_health_flags_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT product_health_flags_subject_unique
        UNIQUE (product_id, health_flag_id, relationship_type_id)
);

COMMENT ON TABLE product_health_flags IS
    'Product-to-health-flag relationship (claims, warnings, risks).';
COMMENT ON COLUMN product_health_flags.relationship_type_id IS
    'Kind of flag assertion (has_health_flag, warns_about, ...).';
COMMENT ON COLUMN product_health_flags.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
