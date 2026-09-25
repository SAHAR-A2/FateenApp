-- =============================================================================
-- Constraints: Product Media Relationship & History (ECR-001, Blocker 1)
-- -----------------------------------------------------------------------------
-- Purpose:       Referential integrity for the product<->image and
--                product<->barcode relationship tables and their immutable
--                history tables: endpoint entities (products, images, barcodes),
--                relationship-type vocabulary, provenance (source, evidence),
--                lifecycle (status_id), canonical link (original_entity_id),
--                version chaining (previous_version_id self-references), and
--                change grouping (change_set_id). No cascade anywhere.
-- Work orders:   ECR-001 Blocker 1 (product<->image / product<->barcode).
-- Dependencies:  Lookup tables (0003/0008), products (0012), images/barcodes
--                (0025), change_sets (0021), relationship tables (0032),
--                history tables (0033). Runs after all tables exist.
-- Migration:     0034_ecr_constraints.sql
-- Rationale:     Cross-table integrity is applied here, after every referenced
--                table is committed (see sql_conventions.md). A referenced
--                entity, vocabulary or version row cannot be removed while any
--                dependent relationship/history row uses it (ON DELETE/UPDATE
--                RESTRICT, ADR-006). History original_entity_id resolves to the
--                owning relationship table; previous_version_id resolves to the
--                same history table. Snapshot FK columns mirror the owning
--                relationship's FKs so a historical version is self-describing.
-- =============================================================================
-- product_images
ALTER TABLE product_images
    ADD CONSTRAINT product_images_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images
    ADD CONSTRAINT product_images_image_id_fk
        FOREIGN KEY (image_id)
        REFERENCES images (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images
    ADD CONSTRAINT product_images_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images
    ADD CONSTRAINT product_images_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images
    ADD CONSTRAINT product_images_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images
    ADD CONSTRAINT product_images_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- product_barcodes
ALTER TABLE product_barcodes
    ADD CONSTRAINT product_barcodes_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes
    ADD CONSTRAINT product_barcodes_barcode_id_fk
        FOREIGN KEY (barcode_id)
        REFERENCES barcodes (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes
    ADD CONSTRAINT product_barcodes_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes
    ADD CONSTRAINT product_barcodes_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes
    ADD CONSTRAINT product_barcodes_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes
    ADD CONSTRAINT product_barcodes_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- product_images_history
ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES product_images (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES product_images_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_image_id_fk
        FOREIGN KEY (image_id)
        REFERENCES images (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_images_history
    ADD CONSTRAINT product_images_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- product_barcodes_history
ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES product_barcodes (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES product_barcodes_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_barcode_id_fk
        FOREIGN KEY (barcode_id)
        REFERENCES barcodes (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_barcodes_history
    ADD CONSTRAINT product_barcodes_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;
