-- =============================================================================
-- Table: images
-- -----------------------------------------------------------------------------
-- Purpose:       Canonical registry of governed media records. An image is NOT a
--                stored file: storage_uri references the object store and the
--                record carries its classification (image_type_id), provenance
--                (source_id), optional language scope, content fingerprint
--                (content_hash), technical attributes and lifecycle state.
-- Work orders:   Mission 07: Canonical Media & Barcode Domain.
-- Dependencies:  Extension citext (0001). Enum set (0002). Tables image_types,
--                data_sources, languages, lifecycle_statuses (0003). Foreign
--                keys applied in 0027 (03-constraints).
-- Migration:     0025_media_and_barcode_tables.sql
-- Rationale:     Media are governed records, so they follow the canonical entity
--                layout: lifecycle via status_id (ADR-008), monotonic version
--                counter, actor columns (created_by/updated_by/reviewed_by/
--                approved_by; no auth service yet, ADR-005) and the audit trio.
--                content_hash is the content fingerprint used for deduplication;
--                it is named content_hash (not checksum) because the immutable
--                history header already reserves the name checksum for row
--                tamper-evidence (Mission 05 architecture). metadata carries
--                optional EXIF/OCR context as JSONB.
-- Columns:
--   image_type_id    Classification (FK image_types): primary, front, back, ...
--   source_id        Provenance of the media record (FK data_sources).
--   language_id      Language scope of the media, NULL = language-neutral.
--   storage_uri      Reference to the stored object (never the bytes).
--   content_hash     Content fingerprint (SHA-256) for deduplication (unique).
--   mime_type        Media type of the stored object (e.g. image/jpeg).
-- =============================================================================
CREATE TABLE images (
    id                 uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    image_type_id      uuid          NOT NULL,
    source_id          uuid          NULL,
    language_id        uuid          NULL,
    storage_uri        text          NOT NULL,
    content_hash       text          NOT NULL,
    mime_type          text          NOT NULL,
    width              integer       NULL,
    height             integer       NULL,
    file_size          bigint        NOT NULL DEFAULT 0,
    status_id          bigint        NOT NULL,
    metadata           jsonb         NOT NULL DEFAULT '{}'::jsonb,
    version_number     integer       NOT NULL DEFAULT 1,
    created_by         uuid          NULL,
    updated_by         uuid          NULL,
    reviewed_by        uuid          NULL,
    approved_by        uuid          NULL,
    created_at         timestamptz   NOT NULL DEFAULT now(),
    updated_at         timestamptz   NOT NULL DEFAULT now(),
    deleted_at         timestamptz   NULL,

    CONSTRAINT images_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT images_dimension_width_check
        CHECK (width IS NULL OR width > 0),
    CONSTRAINT images_dimension_height_check
        CHECK (height IS NULL OR height > 0),
    CONSTRAINT images_file_size_check
        CHECK (file_size >= 0),
    CONSTRAINT images_storage_uri_unique
        UNIQUE (storage_uri),
    CONSTRAINT images_content_hash_unique
        UNIQUE (content_hash)
);

COMMENT ON TABLE images IS
    'Canonical registry of governed media records (references, not file storage).';
COMMENT ON COLUMN images.image_type_id IS
    'Classification of the image (foreign key to image_types): primary, front, back, nutrition panel, ...';
COMMENT ON COLUMN images.source_id IS
    'Provenance of the media record (foreign key to data_sources).';
COMMENT ON COLUMN images.language_id IS
    'Language scope of the media (foreign key to languages); NULL = language-neutral.';
COMMENT ON COLUMN images.storage_uri IS
    'Reference to the stored object in the object store (unique; never the bytes themselves).';
COMMENT ON COLUMN images.content_hash IS
    'Content fingerprint (SHA-256) used for deduplication (unique); the history header column checksum is reserved for row tamper-evidence.';
COMMENT ON COLUMN images.mime_type IS
    'Media type of the stored object (e.g. image/jpeg).';
COMMENT ON COLUMN images.file_size IS
    'Size of the stored object in bytes.';
COMMENT ON COLUMN images.metadata IS
    'Optional JSONB metadata (EXIF/OCR/context); additive, never queried relationally.';
COMMENT ON COLUMN images.status_id IS
    'Lifecycle of the media record (foreign key to lifecycle_statuses; ADR-008).';
COMMENT ON COLUMN images.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
