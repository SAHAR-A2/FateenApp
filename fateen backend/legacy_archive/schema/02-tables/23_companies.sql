-- =============================================================================
-- Table: companies
-- -----------------------------------------------------------------------------
-- Purpose:       Canonical registry of companies (manufacturers, distributors,
--                retailers) that own brands and produce or supply products.
-- Work orders:   Mission 03: Canonical Core Entities (work orders #001-#008),
--                primary business entity per the approved architecture.
-- Dependencies:  Extension citext (0001). Enum set (0002). Lifecycle table
--                lifecycle_statuses (0003), data_sources (0003). Foreign keys
--                are applied in 0013 (03-constraints).
-- Migration:     0012_core_entity_tables.sql
-- Rationale:     Companies are governed, provenance-tracked business entities,
--                not lookup vocabulary: they carry source attribution
--                (source_id), confidence, verification/approval/deprecation
--                state, actor columns and a version counter (ADR-005 note: actor
--                columns apply to governed entities, not lookup tables).
--                Translations (Arabic/English) live in company_translations.
-- Columns:
--   internal_code   Stable internal machine reference (unique, citext).
--   confidence_level  Numeric fact confidence in [0,1]; confidence_band is
--                     derived from this and never stored (ADR-007).
--   created_by/approved_by  Actor UUIDs; reference the future auth/identity
--                     service (no users table in this mission).
-- =============================================================================
CREATE TABLE companies (
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

    CONSTRAINT companies_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT companies_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT companies_internal_code_unique
        UNIQUE (internal_code)
);

COMMENT ON TABLE companies IS
    'Canonical registry of companies (manufacturers, distributors, retailers).';
COMMENT ON COLUMN companies.internal_code IS
    'Stable internal machine reference (unique, citext).';
COMMENT ON COLUMN companies.confidence_level IS
    'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';
COMMENT ON COLUMN companies.created_by IS
    'UUID of the actor that created the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN companies.approved_by IS
    'UUID of the actor that approved the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN companies.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
