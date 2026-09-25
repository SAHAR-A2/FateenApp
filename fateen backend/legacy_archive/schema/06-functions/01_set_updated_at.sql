-- =============================================================================
-- Function: set_updated_at()
-- -----------------------------------------------------------------------------
-- Purpose:       Single shared trigger function that stamps updated_at = now()
--                on every UPDATE of tables that carry the audit lifecycle columns.
-- Work orders:   Foundation Layer, work order #4 (governance support).
-- Dependencies:  None (plpgsql is built in). Called by triggers in 07-triggers.
-- Migration:     0006_foundation_functions_and_triggers.sql
-- Rationale:     updated_at is maintained by the database so no application code
--                can forget it. One function serves every table, keeping the
--                behavior consistent and reviewable.
-- =============================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION set_updated_at() IS
    'Sets updated_at = now() on UPDATE; wired to every audit-carrying table.';
