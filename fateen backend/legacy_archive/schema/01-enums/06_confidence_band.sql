-- =============================================================================
-- Enum: confidence_band
-- -----------------------------------------------------------------------------
-- Purpose:       Discretized confidence on a governed fact or relationship,
--                derived from the numeric confidence_score.
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     Confidence is stored numerically (confidence_score, 0..1) for
--                computation and bucketed into bands for display, filtering, and
--                governance triage. Band boundaries are fixed by the architecture
--                and are half-open intervals [lower, upper).
-- Values (numeric range of confidence_score):
--   very_low   [0.00, 0.20)
--   low        [0.20, 0.40)
--   medium     [0.40, 0.60)
--   high       [0.60, 0.80)
--   very_high  [0.80, 1.00]
-- =============================================================================
CREATE TYPE confidence_band AS ENUM (
    'very_low',
    'low',
    'medium',
    'high',
    'very_high'
);
