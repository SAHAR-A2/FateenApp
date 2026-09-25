-- =============================================================================
-- Function: prevent_history_mutation()
-- -----------------------------------------------------------------------------
-- Purpose:       Shared trigger function that rejects UPDATE and DELETE on
--                immutable history tables. History is INSERT-only by design
--                (Mission 05), so any attempt to change or remove a recorded
--                version raises an exception.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  None (plpgsql is built in). Called by triggers in 07-triggers.
-- Migration:     0024_history_triggers.sql
-- Rationale:     Immutability is enforced by the database, not by application
--                discipline: a history row is a factual record of a governed
--                change and must never be altered. The mission's PASS criterion
--                "immutable strategy" is satisfied at the storage layer.
-- =============================================================================
CREATE OR REPLACE FUNCTION prevent_history_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'immutable history: % on % is not permitted (history rows are INSERT-only)',
        TG_OP,
        TG_TABLE_NAME;
END;
$$;

COMMENT ON FUNCTION prevent_history_mutation() IS
    'Raises an exception on UPDATE/DELETE of immutable history rows.';
