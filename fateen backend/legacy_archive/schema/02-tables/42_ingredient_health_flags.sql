-- =============================================================================
-- Table: ingredient_health_flags
-- -----------------------------------------------------------------------------
-- Purpose:       Relationship between an ingredient and a health_flag (claim,
--                warning, risk) that applies to the ingredient itself, e.g. an
--                additive with a regulatory caution.
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008), ingredient membership relationship.
-- Dependencies:  Tables ingredients, health_flags (0012), relationship_types,
--                data_sources, evidence_types, lifecycle_statuses (0003/0008).
--                FKs applied in 0017 (03-constraints).
-- Migration:     0016_relationship_tables.sql
-- Rationale:     Mirrors product_health_flags for the ingredient registry: a
--                flag applies to many ingredients and an ingredient can carry
--                several flags. The composite UNIQUE (ingredient, flag,
--                relationship type) rejects duplicate assertions. No flag text
--                is duplicated here (ADR-007).
-- Columns:
--   ingredient_id       Ingredient the flag applies to (FK ingredients).
--   health_flag_id      Applied flag (FK health_flags).
--   relationship_type_id  Kind of assertion (FK relationship_types).
-- =============================================================================
CREATE TABLE ingredient_health_flags (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    ingredient_id        uuid          NOT NULL,
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

    CONSTRAINT ingredient_health_flags_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT ingredient_health_flags_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT ingredient_health_flags_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT ingredient_health_flags_subject_unique
        UNIQUE (ingredient_id, health_flag_id, relationship_type_id)
);

COMMENT ON TABLE ingredient_health_flags IS
    'Ingredient-to-health-flag relationship (claims, warnings, risks).';
COMMENT ON COLUMN ingredient_health_flags.relationship_type_id IS
    'Kind of flag assertion (has_health_flag, warns_about, ...).';
COMMENT ON COLUMN ingredient_health_flags.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
