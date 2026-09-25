-- =============================================================================
-- Table: product_barcodes
-- -----------------------------------------------------------------------------
-- Purpose:       Relationship between a product and one of its canonical
--                barcodes (barcodes). A product may carry many barcodes (GTIN-13
--                and GS1 DataMatrix on the same package, one barcode per pack
--                size, regional variants, ...), each attached via a relationship
--                type; the barcode record itself stays canonical and is never
--                duplicated here. Multiple barcode standards are governed by
--                barcode_types on the canonical barcodes table.
-- Work orders:   ECR-001 Blocker 1 (product<->barcode connection).
-- Dependencies:  Tables products (0012), barcodes (0025), relationship_types,
--                data_sources, evidence_types, lifecycle_statuses (0003/0008).
--                FKs applied in 0034 (03-constraints).
-- Migration:     0032_ecr_product_media_tables.sql
-- Rationale:     Follows the Mission 04 relationship architecture exactly: the
--                full relationship column set, provenance per row, lifecycle via
--                status_id (ADR-008), monotonic version counter, effective
--                window, soft delete, and a composite UNIQUE (product, barcode,
--                relationship type) that prevents duplicate assertions while
--                allowing many barcodes per product. No cascade anywhere
--                (ADR-006).
-- Columns:
--   product_id          Owning product (FK products).
--   barcode_id          Connected canonical barcode (FK barcodes).
--   relationship_type_id  Kind of association (FK relationship_types).
-- =============================================================================
CREATE TABLE product_barcodes (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id           uuid          NOT NULL,
    barcode_id           uuid          NOT NULL,
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

    CONSTRAINT product_barcodes_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT product_barcodes_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT product_barcodes_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT product_barcodes_association_unique
        UNIQUE (product_id, barcode_id, relationship_type_id)
);

COMMENT ON TABLE product_barcodes IS
    'Product-to-barcode association relationship (many barcodes per product).';
COMMENT ON COLUMN product_barcodes.product_id IS
    'Owning product (foreign key to products).';
COMMENT ON COLUMN product_barcodes.barcode_id IS
    'Connected canonical barcode (foreign key to barcodes); the barcode row is never duplicated.';
COMMENT ON COLUMN product_barcodes.relationship_type_id IS
    'Kind of association (foreign key to relationship_types: primary_barcode, pack_size_variant, ...).';
COMMENT ON COLUMN product_barcodes.effective_from IS
    'Start of validity for this association; NULL = from creation.';
COMMENT ON COLUMN product_barcodes.effective_to IS
    'End of validity for this association; NULL = currently effective.';
COMMENT ON COLUMN product_barcodes.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
