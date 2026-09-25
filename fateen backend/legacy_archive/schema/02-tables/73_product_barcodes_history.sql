-- =============================================================================
-- Table: product_barcodes_history
-- -----------------------------------------------------------------------------
-- Purpose:       Immutable version-history for the relationship table
--                product_barcodes. One row per version of a product-to-barcode
--                association, capturing the complete relationship snapshot plus
--                versioning and audit metadata. Follows the Mission 05 history
--                architecture exactly (INSERT-only, one row per version).
-- Work orders:   ECR-001 Blocker 1 (relationship history for product<->barcode).
-- Dependencies:  Extension citext (0001). Enums update_type / version_status
--                (0002). Lifecycle lifecycle_statuses (0003), data_sources
--                (0003), change_sets (0021), barcodes (0025). Relationship table
--                product_barcodes (0032). Foreign keys applied in 0034
--                (03-constraints).
-- Migration:     0033_ecr_product_media_history_tables.sql
-- Rationale:     Relationship rows are version-governed like every governed
--                relationship (version_number), and ECR-001 makes history
--                capture automatic via the shared capture_entity_history()
--                function (0036) wired to product_barcodes (0037). The snapshot
--                excludes id (mapped to original_entity_id), version_number
--                (mapped to this table's version_number), and updated_at
--                (immutable rows carry no updated_at). changed_by/approved_by
--                are header columns (relationship rows carry no actor columns,
--                so they stay NULL until the auth milestone provides actors).
-- Deviation:     The standard audit-trio layout (created_at/updated_at/deleted_at)
--                is intentionally not followed: an immutable row has no
--                updated_at and is never soft-deleted. The relationship's
--                deleted_at IS captured in the snapshot as business state.
-- =============================================================================
CREATE TABLE product_barcodes_history (
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
    product_id         uuid          NOT NULL,
    barcode_id         uuid          NOT NULL,
    relationship_type_id uuid        NOT NULL,
    evidence_type_id   uuid          NULL,
    effective_from     timestamptz   NULL,
    effective_to       timestamptz   NULL,
    verified_at        timestamptz   NULL,
    approved_at        timestamptz   NULL,
    status_id          bigint        NOT NULL,
    deleted_at         timestamptz   NULL,
    created_at         timestamptz   NOT NULL DEFAULT now(),
    superseded_at      timestamptz   NULL,
    snapshot_hash      text          NOT NULL,
    checksum           text          NOT NULL,
    version_status     version_status NOT NULL DEFAULT 'draft',

    CONSTRAINT product_barcodes_history_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT product_barcodes_history_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT product_barcodes_history_effective_window_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT product_barcodes_history_entity_version_unique
        UNIQUE (original_entity_id, version_number)
);

COMMENT ON TABLE product_barcodes_history IS
    'Immutable version-history of product_barcodes associations (INSERT-only; one row per version).';
COMMENT ON COLUMN product_barcodes_history.original_entity_id IS
    'Product-to-barcode association this version belongs to (foreign key to product_barcodes, applied in 0034).';
COMMENT ON COLUMN product_barcodes_history.previous_version_id IS
    'Self-reference to the immediately prior version row; NULL for the first version.';
COMMENT ON COLUMN product_barcodes_history.change_type IS
    'Nature of the change recorded by this version (existing update_type ENUM).';
COMMENT ON COLUMN product_barcodes_history.snapshot_hash IS
    'SHA-256 of the snapshot columns, computed by capture_entity_history() at capture time.';
COMMENT ON COLUMN product_barcodes_history.checksum IS
    'Checksum of the full history row for tamper evidence, computed by capture_entity_history().';
COMMENT ON COLUMN product_barcodes_history.version_status IS
    'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';
