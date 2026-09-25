-- =============================================================================
-- Table: ingredients_history
-- -----------------------------------------------------------------------------
-- Purpose:       Immutable version-history for the canonical entity ingredients.
--                One row per published version of an ingredient, capturing the
--                complete governed snapshot plus versioning and audit metadata.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Extension citext (0001). Enums update_type / version_status
--                (0002). Lifecycle lifecycle_statuses (0003), data_sources
--                (0003), change_sets (0021). Canonical entity ingredients
--                (0012). Foreign keys are applied in 0022 (03-constraints).
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
-- =============================================================================
CREATE TABLE ingredients_history (
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

    CONSTRAINT ingredients_history_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT ingredients_history_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT ingredients_history_effective_window_check
        CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ingredients_history_entity_version_unique
        UNIQUE (original_entity_id, version_number)
);

COMMENT ON TABLE ingredients_history IS
    'Immutable version-history of ingredients (INSERT-only; one row per version).';
COMMENT ON COLUMN ingredients_history.original_entity_id IS
    'Canonical ingredient this version belongs to (foreign key to ingredients, applied in 0022).';
COMMENT ON COLUMN ingredients_history.previous_version_id IS
    'Self-reference to the immediately prior version row; NULL for the first version.';
COMMENT ON COLUMN ingredients_history.change_type IS
    'Nature of the change recorded by this version (existing update_type ENUM).';
COMMENT ON COLUMN ingredients_history.snapshot_hash IS
    'SHA-256 of the snapshot columns (application-computed) to verify a stored version matches the original state.';
COMMENT ON COLUMN ingredients_history.checksum IS
    'Checksum of the full history row for tamper evidence.';
COMMENT ON COLUMN ingredients_history.version_status IS
    'Version lifecycle: draft -> pending_approval -> approved -> superseded (existing version_status ENUM).';
