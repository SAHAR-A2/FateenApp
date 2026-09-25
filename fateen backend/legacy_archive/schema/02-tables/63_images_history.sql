-- =============================================================================
-- Table: images_history
-- -----------------------------------------------------------------------------
-- Purpose:       Immutable version-history for the canonical entity images. One
--                row per published version of an image, capturing the complete
--                governed snapshot plus versioning and audit metadata. Follows
--                the Mission 05 history architecture exactly.
-- Work orders:   Mission 07: Canonical Media & Barcode Domain.
-- Dependencies:  Extension citext (0001). Enums update_type / version_status
--                (0002). Lifecycle lifecycle_statuses (0003), data_sources
--                (0003), image_types (0003), languages (0003), change_sets
--                (0021). Canonical entity images (0025). Foreign keys are
--                applied in 0027 (03-constraints).
-- Migration:     0026_media_and_barcode_history_tables.sql
-- Rationale:     History is immutable by design: rows are INSERT-only (enforced
--                by triggers in 0029) and are never updated or deleted. The
--                snapshot excludes id (mapped to original_entity_id),
--                version_number (mapped to this table's version_number),
--                created_by/updated_by/reviewed_by/approved_by (mapped to
--                changed_by/approved_by in the header), source_id (carried by
--                the history header), and created_at/updated_at (the row's own
--                created_at plus the effective window cover temporal
--                provenance). This keeps the snapshot purely business/lifecycle
--                state with no field duplicated between snapshot and header.
-- Deviation:     The standard audit-trio layout (created_at/updated_at/deleted_at,
--                sql_conventions.md) is intentionally not followed: an immutable
--                row has no updated_at and is never soft-deleted. The entity's
--                deleted_at IS captured in the snapshot as business state.
-- Columns:
--   original_entity_id  Canonical image this version belongs to (FK images).
--   version_number      Monotonic version of the canonical image at this row.
--   previous_version_id Self-reference to the immediately prior version row.
--   change_type         Nature of the change (existing update_type ENUM).
--   snapshot_hash       SHA-256 of the snapshot columns (application-computed).
--   checksum            Checksum of the full history row for tamper evidence.
-- =============================================================================
CREATE TABLE images_history (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    original_entity_id  uuid          NOT NULL,
    version_number      integer       NOT NULL,
    previous_version_id uuid          NULL,
    change_set_id       uuid          NULL,
    change_type         update_type   NOT NULL,
    change_reason       text          NULL,
    changed_by          uuid          NULL,
    approved_by         uuid          NULL,
    source_id           uuid          NULL,
    confidence_level    numeric       NOT NULL DEFAULT 0.5,
    image_type_id       uuid          NOT NULL,
    language_id         uuid          NULL,
    storage_uri         text          NOT NULL,
    content_hash        text          NOT NULL,
    mime_type           text          NOT NULL,
    width               integer       NULL,
    height              integer       NULL,
    file_size           bigint        NOT NULL DEFAULT 0,
    metadata            jsonb         NOT NULL DEFAULT '{}'::jsonb,
    status_id           bigint        NOT NULL,
    deleted_at          timestamptz   NULL,
    created_at          timestamptz   NOT NULL DEFAULT now(),
    effective_from      timestamptz   NOT NULL DEFAULT now(),
    effective_to        timestamptz   NULL,
    superseded_at       timestamptz   NULL,
    snapshot_hash       text          NOT NULL,
    checksum            text          NOT NULL,
    version_status      version_status NOT NULL DEFAULT 'draft',

    CONSTRAINT images_history_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT images_history_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT images_history_effective_window_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT images_history_dimension_width_check
        CHECK (width IS NULL OR width > 0),
    CONSTRAINT images_history_dimension_height_check
        CHECK (height IS NULL OR height > 0),
    CONSTRAINT images_history_file_size_check
        CHECK (file_size >= 0),
    CONSTRAINT images_history_entity_version_unique
        UNIQUE (original_entity_id, version_number)
);

COMMENT ON TABLE images_history IS
    'Immutable version-history of images (INSERT-only; one row per version).';
COMMENT ON COLUMN images_history.original_entity_id IS
    'Canonical image this version belongs to (foreign key to images, applied in 0027).';
COMMENT ON COLUMN images_history.previous_version_id IS
    'Self-reference to the immediately prior version row; NULL for the first version.';
COMMENT ON COLUMN images_history.change_type IS
    'Nature of the change recorded by this version (existing update_type ENUM).';
COMMENT ON COLUMN images_history.content_hash IS
    'Content fingerprint of the image at this version (SHA-256).';
COMMENT ON COLUMN images_history.snapshot_hash IS
    'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';
COMMENT ON COLUMN images_history.checksum IS
    'Checksum of the full history row for tamper evidence.';
COMMENT ON COLUMN images_history.version_status IS
    'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';
