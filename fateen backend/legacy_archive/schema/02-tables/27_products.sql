-- =============================================================================
-- Table: products
-- -----------------------------------------------------------------------------
-- Purpose:       Canonical registry of products. A product may belong to one
--                brand (NULL = generic/unbranded) and may be classified into one
--                product_categories taxonomy node.
-- Work orders:   Mission 03: Canonical Core Entities (work orders #001-#008),
--                primary business entity per the approved architecture.
-- Dependencies:  Extension citext (0001). Enum set (0002). Lifecycle table
--                lifecycle_statuses (0003), data_sources (0003), brands (0012),
--                product_categories (0008). FKs applied in 0013 (03-constraints).
-- Migration:     0012_core_entity_tables.sql
-- Rationale:     Products are the central governed, provenance-tracked entity.
--                Nutrition facts, ingredient membership, images, and health
--                flags are separate later-milestone tables; this mission builds
--                only the canonical product core. Brand and category links are
--                applied as foreign keys in 0013.
-- Columns:
--   brand_id           Owning brand (FK brands); NULL for unbranded products.
--   product_category_id  Classification node (FK product_categories); NULL when
--                     not yet classified.
--   internal_code      Stable internal machine reference (unique, citext).
-- =============================================================================
CREATE TABLE products (
    id                 uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_id           uuid          NULL,
    product_category_id uuid         NULL,
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

    CONSTRAINT products_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT products_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT products_internal_code_unique
        UNIQUE (internal_code)
);

COMMENT ON TABLE products IS
    'Canonical registry of products (governed, provenance-tracked core entity).';
COMMENT ON COLUMN products.brand_id IS
    'Owning brand (foreign key to brands); NULL for generic/unbranded products.';
COMMENT ON COLUMN products.product_category_id IS
    'Classification node (foreign key to product_categories); NULL when unclassified.';
COMMENT ON COLUMN products.internal_code IS
    'Stable internal machine reference (unique, citext).';
COMMENT ON COLUMN products.confidence_level IS
    'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';
COMMENT ON COLUMN products.created_by IS
    'UUID of the actor that created the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN products.approved_by IS
    'UUID of the actor that approved the row; FK to the future auth service (none yet).';
COMMENT ON COLUMN products.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
