-- =============================================================================
-- Indexes: Product Media Relationship & History (ECR-001, Blocker 1)
-- -----------------------------------------------------------------------------
-- Purpose:       Correctness-critical indexes only: every foreign-key column on
--                the product<->image / product<->barcode relationship and
--                history tables is indexed (PostgreSQL does not index FK columns
--                automatically).
-- Work orders:   ECR-001 Blocker 1 (product<->image / product<->barcode).
-- Dependencies:  Relationship tables (0032), history tables (0033),
--                constraints (0034).
-- Migration:     0035_ecr_indexes.sql
-- Rationale:     FK-supporting indexes are required for referential integrity
--                enforcement and integrity-performance. UNIQUE constraints
--                (product+media+type) create their own indexes; their leading
--                columns are not duplicated here.
-- =============================================================================
-- product_images
CREATE INDEX product_images_product_id_idx
    ON product_images (product_id);

CREATE INDEX product_images_image_id_idx
    ON product_images (image_id);

CREATE INDEX product_images_relationship_type_id_idx
    ON product_images (relationship_type_id);

CREATE INDEX product_images_source_id_idx
    ON product_images (source_id);

CREATE INDEX product_images_evidence_type_id_idx
    ON product_images (evidence_type_id);

CREATE INDEX product_images_status_id_idx
    ON product_images (status_id);

-- product_barcodes
CREATE INDEX product_barcodes_product_id_idx
    ON product_barcodes (product_id);

CREATE INDEX product_barcodes_barcode_id_idx
    ON product_barcodes (barcode_id);

CREATE INDEX product_barcodes_relationship_type_id_idx
    ON product_barcodes (relationship_type_id);

CREATE INDEX product_barcodes_source_id_idx
    ON product_barcodes (source_id);

CREATE INDEX product_barcodes_evidence_type_id_idx
    ON product_barcodes (evidence_type_id);

CREATE INDEX product_barcodes_status_id_idx
    ON product_barcodes (status_id);

-- product_images_history
CREATE INDEX product_images_history_original_entity_id_idx
    ON product_images_history (original_entity_id);

CREATE INDEX product_images_history_previous_version_id_idx
    ON product_images_history (previous_version_id);

CREATE INDEX product_images_history_change_set_id_idx
    ON product_images_history (change_set_id);

CREATE INDEX product_images_history_product_id_idx
    ON product_images_history (product_id);

CREATE INDEX product_images_history_image_id_idx
    ON product_images_history (image_id);

CREATE INDEX product_images_history_relationship_type_id_idx
    ON product_images_history (relationship_type_id);

CREATE INDEX product_images_history_source_id_idx
    ON product_images_history (source_id);

CREATE INDEX product_images_history_evidence_type_id_idx
    ON product_images_history (evidence_type_id);

CREATE INDEX product_images_history_status_id_idx
    ON product_images_history (status_id);

-- product_barcodes_history
CREATE INDEX product_barcodes_history_original_entity_id_idx
    ON product_barcodes_history (original_entity_id);

CREATE INDEX product_barcodes_history_previous_version_id_idx
    ON product_barcodes_history (previous_version_id);

CREATE INDEX product_barcodes_history_change_set_id_idx
    ON product_barcodes_history (change_set_id);

CREATE INDEX product_barcodes_history_product_id_idx
    ON product_barcodes_history (product_id);

CREATE INDEX product_barcodes_history_barcode_id_idx
    ON product_barcodes_history (barcode_id);

CREATE INDEX product_barcodes_history_relationship_type_id_idx
    ON product_barcodes_history (relationship_type_id);

CREATE INDEX product_barcodes_history_source_id_idx
    ON product_barcodes_history (source_id);

CREATE INDEX product_barcodes_history_evidence_type_id_idx
    ON product_barcodes_history (evidence_type_id);

CREATE INDEX product_barcodes_history_status_id_idx
    ON product_barcodes_history (status_id);
