-- =============================================================================
-- Enum: approval_status
-- -----------------------------------------------------------------------------
-- Purpose:       State of the governance review/approval workflow for a submitted
--                change or version. Distinct from entity_status (published
--                lifecycle) and from review_decision (the outcome of one review
--                action).
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     Every governed change flows through this state machine so the
--                review history is fully reconstructable without redesign.
-- Values:
--   pending_review    Submitted, awaiting assignment/review start.
--   in_review         Actively under review.
--   changes_requested Reviewer requested changes; work has been sent back.
--   approved          Approved; the change is applied to the governed record.
--   rejected          Rejected; the change is not applied.
--   cancelled         Withdrawn by the submitter before a final decision.
-- =============================================================================
CREATE TYPE approval_status AS ENUM (
    'pending_review',
    'in_review',
    'changes_requested',
    'approved',
    'rejected',
    'cancelled'
);
