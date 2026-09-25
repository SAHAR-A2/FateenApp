-- =============================================================================
-- Table: entity_versions
-- -----------------------------------------------------------------------------
-- Purpose:       Generic registry of every published version across all history
--                tables: a uniform index of (entity_type, entity_id,
--                version_number) pointing at the immutable history row and
--                tracking its version_status and predecessor. This is the single
--                place to ask "give me all versions of entity X".
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Extension citext (0001). Enums version_status (0002).
--                change_sets (0021). Foreign keys are applied in 0022
--                (03-constraints).
-- Migration:     0021_audit_tables.sql
-- Rationale:     entity_versions is polymorphic by design: the history row lives
--                in one of several history tables, so history_table /
--                history_row_id carry no foreign key (the same pattern as
--                entity_relationships.subject_id / object_id). The snapshot
--                itself stays in the history tables; this registry only indexes it
--                and adds no duplicated content.
-- Columns:
--   entity_type      Canonical entity/table the version belongs to (text).
--   entity_id        Canonical entity id the version belongs to.
--   version_number   Version number within that entity.
--   history_table    Name of the history table holding the snapshot.
--   history_row_id   Id of the immutable history row (tamper-evidence pointer).
-- =============================================================================
CREATE TABLE entity_versions (
    id                uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_type       text          NOT NULL,
    entity_id         uuid          NOT NULL,
    version_number    integer       NOT NULL,
    history_table     text          NOT NULL,
    history_row_id    uuid          NOT NULL,
    version_status    version_status NOT NULL DEFAULT 'draft',
    change_set_id     uuid          NULL,
    previous_version_id uuid        NULL,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now(),
    deleted_at        timestamptz   NULL,

    CONSTRAINT entity_versions_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT entity_versions_history_table_check
        CHECK (history_table <> ''),
    CONSTRAINT entity_versions_entity_version_unique
        UNIQUE (entity_type, entity_id, version_number)
);

COMMENT ON TABLE entity_versions IS
    'Generic registry of every published version across all history tables.';
COMMENT ON COLUMN entity_versions.entity_type IS
    'Canonical entity/table the version belongs to (text discriminator, no FK).';
COMMENT ON COLUMN entity_versions.entity_id IS
    'Canonical entity id the version belongs to.';
COMMENT ON COLUMN entity_versions.version_number IS
    'Version number within that entity (unique with entity_type and entity_id).';
COMMENT ON COLUMN entity_versions.history_table IS
    'Name of the history table holding the immutable snapshot (text discriminator, no FK).';
COMMENT ON COLUMN entity_versions.history_row_id IS
    'Id of the immutable history row (tamper-evidence pointer for hash verification).';
COMMENT ON COLUMN entity_versions.version_status IS
    'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';
COMMENT ON COLUMN entity_versions.previous_version_id IS
    'Self-reference to the immediately prior version registry row (applied in 0022).';
