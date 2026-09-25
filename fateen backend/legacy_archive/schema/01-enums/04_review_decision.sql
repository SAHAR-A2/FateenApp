-- =============================================================================
-- Enum: review_decision
-- -----------------------------------------------------------------------------
-- Purpose:       Outcome recorded for ONE individual review action within the
--                approval workflow. The aggregate workflow state is tracked by
--                approval_status.
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     Recording per-action decisions (not just the final state) makes
--                the review trail auditable and reconstructable.
-- Values:
--   approved           Reviewer approved the change.
--   rejected           Reviewer rejected the change.
--   changes_requested  Reviewer returned the change for modification.
--   escalated          Reviewer escalated to a higher tier for decision.
-- =============================================================================
CREATE TYPE review_decision AS ENUM (
    'approved',
    'rejected',
    'changes_requested',
    'escalated'
);
