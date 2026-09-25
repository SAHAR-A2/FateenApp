-- =============================================================================
-- Seed: lifecycle_statuses
-- -----------------------------------------------------------------------------
-- Purpose:       Initial, non-destructive lifecycle vocabulary shared by every
--                lookup table (ACTIVE, DEPRECATED, ARCHIVED).
-- Work orders:   Foundation Layer. Architecture Authority directive #007.
-- Dependencies:  Table lifecycle_statuses (0003).
-- Migration:     0007_seed_lifecycle_statuses.sql
-- Rationale:     status_id is NOT NULL on every lookup table, so the status rows
--                must exist before any governed insert. codes are stable machine
--                references; ON CONFLICT (code) keeps the seed idempotent.
-- =============================================================================
INSERT INTO lifecycle_statuses (code, name, description, display_order)
VALUES
    ('ACTIVE',     'Active',
     'Reference row is in service and eligible for use.', 1),
    ('DEPRECATED', 'Deprecated',
     'No longer recommended; kept for history and referential integrity.', 2),
    ('ARCHIVED',   'Archived',
     'Retired from use; preserved for audit and history.', 3)
ON CONFLICT (code) DO NOTHING;
