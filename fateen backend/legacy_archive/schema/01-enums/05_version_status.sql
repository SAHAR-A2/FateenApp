-- =============================================================================
-- Enum: version_status
-- -----------------------------------------------------------------------------
-- Purpose:       Lifecycle of a single version of a governed entity within the
--                version-history system.
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     Version history is immutable: a version's status only ever moves
--                forward (draft -> pending_approval -> approved/rejected, then
--                approved -> superseded when a newer version takes over).
-- Values:
--   draft             Version is being composed, not submitted.
--   pending_approval  Submitted to the review workflow.
--   approved          Approved and applied as the current governed version.
--   rejected          Rejected; never becomes current.
--   superseded        Was approved but a newer version is now current.
-- =============================================================================
CREATE TYPE version_status AS ENUM (
    'draft',
    'pending_approval',
    'approved',
    'rejected',
    'superseded'
);
