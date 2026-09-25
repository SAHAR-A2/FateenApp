-- =============================================================================
-- Table: version_metadata
-- -----------------------------------------------------------------------------
-- Purpose:       Free-form key/value extension attributes for a version registry
--                entry (entity_versions), e.g. exporter, batch id, or review
--                comment references that do not fit the uniform version column
--                set.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Extension citext (0001). entity_versions (0021). Foreign keys
--                are applied in 0022 (03-constraints).
-- Migration:     0021_audit_tables.sql
-- Rationale:     version_metadata deliberately holds only per-version extension
--                attributes; the uniform version fields (version_status, effective
--                window, hashes, change type) live in the history tables and
--                entity_versions. Keys are snake_case and scoped per version
--                (UNIQUE entity_version_id + key).
-- Columns:
--   key    Extension attribute key (snake_case).
--   value  Attribute value (text).
-- =============================================================================
CREATE TABLE version_metadata (
    id                uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_version_id uuid          NOT NULL,
    key               citext        NOT NULL,
    value             text          NOT NULL,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now(),
    deleted_at        timestamptz   NULL,

    CONSTRAINT version_metadata_key_not_empty_check
        CHECK (key <> ''),
    CONSTRAINT version_metadata_key_unique
        UNIQUE (entity_version_id, key)
);

COMMENT ON TABLE version_metadata IS
    'Key/value extension attributes scoped to one entity_versions entry.';
COMMENT ON COLUMN version_metadata.entity_version_id IS
    'Owning version registry entry (foreign key to entity_versions, applied in 0022).';
COMMENT ON COLUMN version_metadata.key IS
    'Extension attribute key (snake_case, unique per version).';
COMMENT ON COLUMN version_metadata.value IS
    'Extension attribute value (text).';
