-- =============================================================================
-- Enum: translation_status
-- -----------------------------------------------------------------------------
-- Purpose:       Lifecycle of a single translation row in the i18n layer.
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     Translation quality is governed independently of the source
--                content: a translation may be reviewed and approved while the
--                source entity is unchanged.
-- Values:
--   draft           Translation created, not yet finished.
--   in_progress     Translation being worked on.
--   pending_review  Translation submitted for review.
--   approved        Translation reviewed and approved for display.
--   rejected        Translation rejected; requires rework.
-- =============================================================================
CREATE TYPE translation_status AS ENUM (
    'draft',
    'in_progress',
    'pending_review',
    'approved',
    'rejected'
);
