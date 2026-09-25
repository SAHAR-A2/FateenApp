-- =============================================================================
-- Table: change_sets
-- -----------------------------------------------------------------------------
-- Purpose:       Groups the version records produced by one logical change.
--                Every history row written in a single governed change references
--                the same change_set, so a change that touches several entities
--                (merge, split, bulk import) stays atomic and traceable.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  audit_context (0021). Foreign keys are applied in 0022
--                (03-constraints).
-- Migration:     0021_audit_tables.sql
-- Rationale:     change_sets is the grouping anchor for history rows
--                (history_tables.change_set_id) and for audit_log feed entries.
--                The (correlation_id, transaction_id) pair references the owning
--                audit_context row; the composite foreign key is applied in 0022.
-- Columns:
--   correlation_id  Owner operation correlation (FK via audit_context pair).
--   transaction_id  Owner operation transaction (FK via audit_context pair).
--   applied_at      When the change was committed (server clock).
-- =============================================================================
CREATE TABLE change_sets (
    id               uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    correlation_id   uuid          NOT NULL,
    transaction_id   uuid          NOT NULL,
    description      text          NULL,
    applied_at       timestamptz   NOT NULL DEFAULT now(),
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now(),
    deleted_at       timestamptz   NULL
);

COMMENT ON TABLE change_sets IS
    'Logical grouping of version records produced by one governed change.';
COMMENT ON COLUMN change_sets.correlation_id IS
    'Owner operation correlation id (composite foreign key to audit_context, applied in 0022).';
COMMENT ON COLUMN change_sets.transaction_id IS
    'Owner operation transaction id (composite foreign key to audit_context, applied in 0022).';
COMMENT ON COLUMN change_sets.description IS
    'Human-readable description of the logical change (why the versions were written).';
COMMENT ON COLUMN change_sets.applied_at IS
    'When the change was committed (server clock).';
