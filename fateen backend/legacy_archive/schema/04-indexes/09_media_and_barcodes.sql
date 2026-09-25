-- =============================================================================
-- Indexes: Canonical Media & Barcode Domain
-- -----------------------------------------------------------------------------
-- Purpose:       Correctness-critical indexes only: every foreign-key column on
--                the Mission 07 media, barcode and history tables is indexed
--                (PostgreSQL does not index FK columns automatically). No
--                performance/search indexes yet.
-- Work orders:   Mission 07: Canonical Media & Barcode Domain.
-- Dependencies:  Media/barcode tables (0025), history tables (0026),
--                constraints (0027).
-- Migration:     0028_media_and_barcode_indexes.sql
-- Rationale:     FK-supporting indexes are required for referential integrity
--                enforcement and integrity-performance. UNIQUE constraints
--                (barcode, content_hash, storage_uri, code) create their own
--                indexes; their columns are not duplicated here.
-- =============================================================================
-- verification_statuses
CREATE INDEX verification_statuses_status_id_idx
    ON verification_statuses (status_id);

-- images
CREATE INDEX images_image_type_id_idx
    ON images (image_type_id);

CREATE INDEX images_source_id_idx
    ON images (source_id);

CREATE INDEX images_language_id_idx
    ON images (language_id);

CREATE INDEX images_status_id_idx
    ON images (status_id);

-- barcodes
CREATE INDEX barcodes_barcode_type_id_idx
    ON barcodes (barcode_type_id);

CREATE INDEX barcodes_verification_status_id_idx
    ON barcodes (verification_status_id);

CREATE INDEX barcodes_source_id_idx
    ON barcodes (source_id);

CREATE INDEX barcodes_status_id_idx
    ON barcodes (status_id);

CREATE INDEX barcodes_issued_country_id_idx
    ON barcodes (issued_country_id);

-- images_history
CREATE INDEX images_history_original_entity_id_idx
    ON images_history (original_entity_id);

CREATE INDEX images_history_previous_version_id_idx
    ON images_history (previous_version_id);

CREATE INDEX images_history_change_set_id_idx
    ON images_history (change_set_id);

CREATE INDEX images_history_source_id_idx
    ON images_history (source_id);

CREATE INDEX images_history_status_id_idx
    ON images_history (status_id);

CREATE INDEX images_history_image_type_id_idx
    ON images_history (image_type_id);

CREATE INDEX images_history_language_id_idx
    ON images_history (language_id);

-- barcodes_history
CREATE INDEX barcodes_history_original_entity_id_idx
    ON barcodes_history (original_entity_id);

CREATE INDEX barcodes_history_previous_version_id_idx
    ON barcodes_history (previous_version_id);

CREATE INDEX barcodes_history_change_set_id_idx
    ON barcodes_history (change_set_id);

CREATE INDEX barcodes_history_source_id_idx
    ON barcodes_history (source_id);

CREATE INDEX barcodes_history_status_id_idx
    ON barcodes_history (status_id);

CREATE INDEX barcodes_history_barcode_type_id_idx
    ON barcodes_history (barcode_type_id);

CREATE INDEX barcodes_history_verification_status_id_idx
    ON barcodes_history (verification_status_id);

CREATE INDEX barcodes_history_issued_country_id_idx
    ON barcodes_history (issued_country_id);
