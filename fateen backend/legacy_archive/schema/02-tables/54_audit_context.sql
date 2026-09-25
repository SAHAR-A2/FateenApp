-- =============================================================================
-- Table: audit_context
-- -----------------------------------------------------------------------------
-- Purpose:       Per-operation audit context: one row per audited operation,
--                identified by its correlation_id / transaction_id pair, carrying
--                the shared actor, role and request-context fields once.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Extension citext (0001). role_types (0008). Foreign keys are
--                applied in 0022 (03-constraints).
-- Migration:     0021_audit_tables.sql
-- Rationale:     The mission audit-event field list includes actor, role, source,
--                IP and user-agent. Those fields are identical for every event of
--                one operation, so they are stored once here and referenced by
--                change_sets / audit_log instead of being repeated per event
--                (repository no-duplication rule).
-- Columns:
--   correlation_id  End-to-end request/correlation identifier.
--   transaction_id  Database transaction identifier within the operation.
--   actor           UUID of the acting principal (no auth service yet, ADR-005).
--   role_id         Authorized role of the actor (FK role_types).
--   ip_address      Requesting host (inet placeholder, nullable by design).
--   user_agent      Requesting client (placeholder, nullable by design).
-- =============================================================================
CREATE TABLE audit_context (
    id               uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    correlation_id   uuid          NOT NULL,
    transaction_id   uuid          NOT NULL,
    actor            uuid          NULL,
    role_id          uuid          NULL,
    source           text          NULL,
    ip_address       inet          NULL,
    user_agent       text          NULL,
    started_at       timestamptz   NOT NULL DEFAULT now(),
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now(),
    deleted_at       timestamptz   NULL,

    CONSTRAINT audit_context_operation_unique
        UNIQUE (correlation_id, transaction_id)
);

COMMENT ON TABLE audit_context IS
    'Per-operation audit context (one row per correlation/transaction pair).';
COMMENT ON COLUMN audit_context.correlation_id IS
    'End-to-end request/correlation identifier (unique with transaction_id).';
COMMENT ON COLUMN audit_context.transaction_id IS
    'Database transaction identifier within the operation (unique with correlation_id).';
COMMENT ON COLUMN audit_context.actor IS
    'UUID of the acting principal; FK to the future auth service (none yet, ADR-005).';
COMMENT ON COLUMN audit_context.role_id IS
    'Authorized role of the actor (foreign key to role_types, applied in 0022).';
COMMENT ON COLUMN audit_context.ip_address IS
    'Requesting host IP; nullable placeholder, never business data.';
COMMENT ON COLUMN audit_context.user_agent IS
    'Requesting client user agent; nullable placeholder, never business data.';
