-- =============================================================================
-- Table: audit_events
-- -----------------------------------------------------------------------------
-- Purpose:       Normalized per-version event details. One row per version record
--                actually written to a history table, so a single audit_log feed
--                entry (one logical change) can expand into several events
--                (merge/split/bulk operations touching multiple entities).
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Extension citext (0001). audit_event_types (0008), audit_log
--                (0021). Foreign keys are applied in 0022 (03-constraints).
-- Migration:     0021_audit_tables.sql
-- Rationale:     audit_events is the relational, queryable layer: every row links
--                to its feed entry (audit_log) and carries the exact entity and
--                version transition. Unlike audit_log it never repeats actor or
--                request-context fields, keeping the no-duplication rule.
-- Columns:
--   audit_log_id    Owning feed entry (FK audit_log).
--   event_type_id   Per-version action class (FK audit_event_types).
--   entity_type     Canonical entity/table the version belongs to.
--   entity_id       Canonical entity id the version belongs to.
-- =============================================================================
CREATE TABLE audit_events (
    id                uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    audit_log_id      uuid          NOT NULL,
    event_type_id     uuid          NOT NULL,
    entity_type       text          NOT NULL,
    entity_id         uuid          NULL,
    previous_version  integer       NULL,
    new_version       integer       NOT NULL,
    event_time        timestamptz   NOT NULL DEFAULT now(),
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now(),
    deleted_at        timestamptz   NULL
);

COMMENT ON TABLE audit_events IS
    'Normalized per-version event details (one row per version record written).';
COMMENT ON COLUMN audit_events.audit_log_id IS
    'Owning feed entry (foreign key to audit_log, applied in 0022).';
COMMENT ON COLUMN audit_events.event_type_id IS
    'Per-version action class (foreign key to audit_event_types, applied in 0022).';
COMMENT ON COLUMN audit_events.entity_type IS
    'Canonical entity/table the version belongs to (text discriminator, no FK).';
COMMENT ON COLUMN audit_events.entity_id IS
    'Canonical entity id the version belongs to.';
COMMENT ON COLUMN audit_events.previous_version IS
    'Version number before this version (NULL on create).';
COMMENT ON COLUMN audit_events.new_version IS
    'Version number recorded by this event.';
COMMENT ON COLUMN audit_events.event_time IS
    'When the version event was recorded (server clock).';
