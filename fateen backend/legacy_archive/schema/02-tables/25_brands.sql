-- =============================================================================
-- Table: brands
-- -----------------------------------------------------------------------------
-- Purpose:       Canonical registry of brands. A brand belongs to exactly one
--                company; products attach to brands (generic/unbranded products
--                may attach to none).
-- Work orders:   Mission 03: Canonical Core Entities (work orders #001-#008),
--                primary business entity per the approved architecture.
-- Dependencies:  Extension citext (0001). Enum set (0002). Lifecycle table
--                lifecycle_statuses (0003), data_sources (0003), companies
--                (0012). Foreign keys are applied in 0013 (03-constraints).
-- Migration:     0012_core_entity_tables.sql
-- Rationale:     Brands are governed, provenance-tracked business entities with
--                the same canonical governance column set as companies. The
--                company relationship is applied as a foreign key in 0013.
--                Translations (Arabic/English) live in brand_translations.
-- Columns:
--   company_id      Owning company (FK companies, NOT NULL).
--   internal_code   Stable internal machine reference (unique, citext).
-- =============================================================================
CREATE TABLE brands (
    id               uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id       uuid          NOT NULL,
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

    CONSTRAINT brands_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT brands_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT brands_internal_code_unique
        UNIQUE (internal_code)
);

COMMENT ON TABLE brands IS
    'Canonical registry of brands, each owned by exactly one company.';
COMMENT ON COLUMN brands.company_id IS
    'Owning company (foreign key to companies).';
COMMENT ON COLUMN brands.internal_code IS
    'Stable internal machine reference (unique, citext).';
COMMENT ON COLUMN brands.confidence_level IS
    'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';
COMMENT ON COLUMN brands.created_by IS
    'UUID of the actor that created the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN brands.approved_by IS
    'UUID of the actor that approved the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN brands.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
