-- =============================================================================
-- Table: audit_log
-- -----------------------------------------------------------------------------
-- Purpose:       Append-only audit event feed. One entry per audited change,
--                carrying the complete mission audit-event field set so a single
--                row reads as a self-contained narrative (who did what, to which
--                entity/version, when, from where, in which operation).
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Extension citext (0001). audit_event_types (0008), role_types
--                (0008), change_sets (0021). Foreign keys are applied in 0022
--                (03-constraints).
-- Migration:     0021_audit_tables.sql
-- Rationale:     Field mapping to the mission list: action -> event_type_id,
--                entity -> entity_type, timestamp -> logged_at, role -> role_id,
--                IP/user-agent -> ip_address/user_agent. The actor/role/source/IP/
--                user-agent fields are stored here (denormalized from
--                audit_context) so the feed is readable without joins; audit_events
--                then records one normalized detail row per version actually
--                written, so one feed entry may have several event details
--                (e.g. a merge writes multiple versions).
-- Columns:
--   event_type_id   Classified action (FK audit_event_types).
--   entity_type     Canonical entity/table the change acted on (text, no FK).
--   previous_version  Version number of the entity before the change (NULL create).
--   new_version       Version number of the entity after the change.
-- =============================================================================
CREATE TABLE audit_log (
    id                uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    change_set_id     uuid          NULL,
    event_type_id     uuid          NOT NULL,
    entity_type       text          NOT NULL,
    entity_id         uuid          NULL,
    previous_version  integer       NULL,
    new_version       integer       NOT NULL,
    actor             uuid          NULL,
    role_id           uuid          NULL,
    source            text          NULL,
    ip_address        inet          NULL,
    user_agent        text          NULL,
    correlation_id    uuid          NULL,
    transaction_id    uuid          NULL,
    logged_at         timestamptz   NOT NULL DEFAULT now(),
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now(),
    deleted_at        timestamptz   NULL
);

COMMENT ON TABLE audit_log IS
    'Append-only audit event feed (self-contained per-change narrative).';
COMMENT ON COLUMN audit_log.change_set_id IS
    'Owning logical change (foreign key to change_sets, applied in 0022).';
COMMENT ON COLUMN audit_log.event_type_id IS
    'Classified action, the mission "action" field (foreign key to audit_event_types, applied in 0022).';
COMMENT ON COLUMN audit_log.entity_type IS
    'Canonical entity/table the change acted on (the mission "entity" field; text discriminator, no FK).';
COMMENT ON COLUMN audit_log.entity_id IS
    'Entity id the change acted on (the mission "entity_id" field).';
COMMENT ON COLUMN audit_log.previous_version IS
    'Version number of the entity before the change (NULL on create).';
COMMENT ON COLUMN audit_log.new_version IS
    'Version number of the entity after the change.';
COMMENT ON COLUMN audit_log.actor IS
    'UUID of the acting principal; FK to the future auth service (none yet, ADR-005).';
COMMENT ON COLUMN audit_log.role_id IS
    'Authorized role of the actor (foreign key to role_types, applied in 0022).';
COMMENT ON COLUMN audit_log.ip_address IS
    'Requesting host IP; nullable placeholder, never business data.';
COMMENT ON COLUMN audit_log.user_agent IS
    'Requesting client user agent; nullable placeholder, never business data.';
COMMENT ON COLUMN audit_log.logged_at IS
    'When the feed entry was recorded (server clock).';
