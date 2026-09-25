-- =============================================================================
-- Enum: review_tier
-- -----------------------------------------------------------------------------
-- Purpose:       Escalation tier that determines the reviewer qualifications and
--                consensus required before a change may be approved.
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     The governance milestone assigns a tier per change based on
--                risk (e.g. allergens, restricted ingredients, source conflicts).
--                Tiers are ordered from least to most stringent.
-- Values:
--   automated   Machine validation only; no human reviewer. Reserved for
--               low-risk, high-confidence, mechanically verifiable changes.
--   standard    One qualified reviewer.
--   elevated    Additional scrutiny (senior reviewer and/or multiple reviewers).
--   expert      Requires subject-matter expertise in the affected domain.
--   consensus   Multiple expert reviewers must agree; used for high-impact data.
-- =============================================================================
CREATE TYPE review_tier AS ENUM (
    'automated',
    'standard',
    'elevated',
    'expert',
    'consensus'
);
