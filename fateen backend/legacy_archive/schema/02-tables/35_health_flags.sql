-- =============================================================================
-- Table: health_flags
-- -----------------------------------------------------------------------------
-- Purpose:       Canonical registry of concrete health/risk flags and claims
--                (e.g. gluten_free_claim, recall_2024_001). Each flag may be
--                classified into one health_flag_types class (mission 02); a
--                NULL type means the class is not yet assigned.
-- Work orders:   Mission 03: Canonical Core Entities (work orders #001-#008),
--                primary business entity per the approved architecture.
-- Dependencies:  Extension citext (0001). Enum set (0002). Lifecycle table
--                lifecycle_statuses (0003), data_sources (0003), health_flag_types
--                (0003). Foreign keys are applied in 0013 (03-constraints).
-- Migration:     0012_core_entity_tables.sql
-- Rationale:     Health flags are governed, provenance-tracked business entities.
--                The class is a foreign key to the governed health_flag_types
--                registry (ADR-001). Product/ingredient flag assignments are
--                later-milestone relationships, not duplicated here.
-- Columns:
--   health_flag_type_id  Classification class (FK health_flag_types); NULL when
--                     not yet classified.
--   internal_code     Stable internal machine reference (unique, citext).
-- =============================================================================
CREATE TABLE health_flags (
    id                 uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    health_flag_type_id uuid         NULL,
    internal_code      citext        NOT NULL,
    name               text          NOT NULL,
    description        text          NULL,
    status_id          bigint        NOT NULL,
    source_id          uuid          NULL,
    confidence_level   numeric       NOT NULL DEFAULT 0.5,
    verified_at        timestamptz   NULL,
    approved_at        timestamptz   NULL,
    deprecated_at      timestamptz   NULL,
    version_number     integer       NOT NULL DEFAULT 1,
    created_by         uuid          NULL,
    approved_by        uuid          NULL,
    created_at         timestamptz   NOT NULL DEFAULT now(),
    updated_at         timestamptz   NOT NULL DEFAULT now(),
    deleted_at         timestamptz   NULL,

    CONSTRAINT health_flags_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT health_flags_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT health_flags_internal_code_unique
        UNIQUE (internal_code)
);

COMMENT ON TABLE health_flags IS
    'Canonical registry of concrete health/risk flags and claims.';
COMMENT ON COLUMN health_flags.health_flag_type_id IS
    'Health/risk flag class (foreign key to health_flag_types); NULL when not yet classified.';
COMMENT ON COLUMN health_flags.internal_code IS
    'Stable internal machine reference (unique, citext).';
COMMENT ON COLUMN health_flags.confidence_level IS
    'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';
COMMENT ON COLUMN health_flags.created_by IS
    'UUID of the actor that created the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN health_flags.approved_by IS
    'UUID of the actor that approved the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN health_flags.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
