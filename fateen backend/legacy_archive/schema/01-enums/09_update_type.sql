-- =============================================================================
-- Enum: update_type
-- -----------------------------------------------------------------------------
-- Purpose:       Classifies the nature of a change recorded in version history.
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     History entries must explain WHAT happened (update_type) in
--                addition to WHEN and BY WHOM, so the audit trail reads as a
--                narrative and supports reversion analysis.
-- Values:
--   created      A new entity or version was created.
--   modified     Existing content was changed.
--   published    An approved version was published to active state.
--   unpublished  An active record was taken out of active state.
--   deprecated   A record was marked deprecated.
--   archived     A record was archived.
--   merged       Records were merged; the losing record is referenced.
--   split        A record was split; the resulting records are referenced.
-- =============================================================================
CREATE TYPE update_type AS ENUM (
    'created',
    'modified',
    'published',
    'unpublished',
    'deprecated',
    'archived',
    'merged',
    'split'
);
