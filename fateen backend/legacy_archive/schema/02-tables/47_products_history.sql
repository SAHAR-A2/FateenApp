-- =============================================================================
-- Table: products_history
-- -----------------------------------------------------------------------------
-- Purpose:       Immutable version-history for the canonical entity products.
--                One row per published version of a product, capturing the
--                complete governed snapshot plus versioning and audit metadata.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Extension citext (0001). Enums update_type / version_status
--                (0002). Lifecycle lifecycle_statuses (0003), data_sources
--                (0003), change_sets (0021). Canonical entity products (0012).
--                Foreign keys are applied in 0022 (03-constraints).
-- Migration:     0020_history_tables.sql
-- Rationale:     History is immutable by design: rows are INSERT-only (enforced
--                by triggers in 0024) and are never updated or deleted. The
--                snapshot excludes id (mapped to original_entity_id),
--                version_number (mapped to this table's version_number),
--                created_by/approved_by (mapped to changed_by/approved_by),
--                source_id and confidence_level (carried by the history header),
--                and created_at/updated_at (the row's own created_at plus the
--                effective window cover temporal provenance).
-- Deviation:     The standard audit-trio layout (created_at/updated_at/deleted_at,
--                sql_conventions.md) is intentionally not followed: an immutable
--                row has no updated_at and is never soft-deleted. The entity's
--                deleted_at IS captured in the snapshot as business state.
-- Columns:
--   original_entity_id  Canonical entity this version belongs to (FK products).
--   brand_id            Owning brand at this version (FK brands); NULL unbranded.
--   product_category_id Classification node at this version (FK product_categories).
-- =============================================================================
CREATE TABLE products_history (
    id                 uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    original_entity_id uuid          NOT NULL,
    version_number     integer       NOT NULL,
    previous_version_id uuid         NULL,
    change_set_id      uuid          NULL,
    change_type        update_type   NOT NULL,
    change_reason      text          NULL,
    changed_by         uuid          NULL,
    approved_by        uuid          NULL,
    source_id          uuid          NULL,
    confidence_level   numeric       NOT NULL DEFAULT 0.5,
    brand_id           uuid          NULL,
    product_category_id uuid         NULL,
    internal_code      citext        NOT NULL,
    name               text          NOT NULL,
    description        text          NULL,
    status_id          bigint        NOT NULL,
    verified_at        timestamptz   NULL,
    approved_at        timestamptz   NULL,
    deprecated_at      timestamptz   NULL,
    deleted_at         timestamptz   NULL,
    created_at         timestamptz   NOT NULL DEFAULT now(),
    effective_from     timestamptz   NOT NULL DEFAULT now(),
    effective_to       timestamptz   NULL,
    superseded_at      timestamptz   NULL,
    snapshot_hash      text          NOT NULL,
    checksum           text          NOT NULL,
    version_status     version_status NOT NULL DEFAULT 'draft',

    CONSTRAINT products_history_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT products_history_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT products_history_effective_window_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT products_history_entity_version_unique
        UNIQUE (original_entity_id, version_number)
);

COMMENT ON TABLE products_history IS
    'Immutable version-history of products (INSERT-only; one row per version).';
COMMENT ON COLUMN products_history.original_entity_id IS
    'Canonical product this version belongs to (foreign key to products, applied in 0022).';
COMMENT ON COLUMN products_history.brand_id IS
    'Owning brand at this version (foreign key to brands, applied in 0022); NULL for unbranded products.';
COMMENT ON COLUMN products_history.product_category_id IS
    'Classification node at this version (foreign key to product_categories, applied in 0022).';
COMMENT ON COLUMN products_history.previous_version_id IS
    'Self-reference to the immediately prior version row; NULL for the first version.';
COMMENT ON COLUMN products_history.change_type IS
    'Nature of the change recorded by this version (existing update_type ENUM).';
COMMENT ON COLUMN products_history.snapshot_hash IS
    'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';
COMMENT ON COLUMN products_history.checksum IS
    'Checksum of the full history row for tamper evidence.';
COMMENT ON COLUMN products_history.version_status IS
    'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';
