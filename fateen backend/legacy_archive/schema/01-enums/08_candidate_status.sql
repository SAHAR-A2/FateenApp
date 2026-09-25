-- =============================================================================
-- Enum: candidate_status
-- -----------------------------------------------------------------------------
-- Purpose:       Lifecycle of a candidate record inside the production population
--                pipeline, BEFORE it becomes a governed entity. Candidate rows are
--                discovered, enriched, normalized, deduplicated, then promoted
--                into governed entities (or discarded/merged).
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     Keeps ungoverned, raw pipeline state fully separate from the
--                governed knowledge base so low-quality data never leaks into
--                governed tables.
-- Values:
--   discovered      Raw record ingested; no processing yet.
--   enriched        Attribute/completeness enrichment applied.
--   normalized      Name/format normalization applied.
--   pending_review  Candidate ready for human or automated adjudication.
--   approved        Candidate accepted; promoted toward a governed entity.
--   merged          Candidate merged into an existing record; superseded.
--   discarded       Candidate rejected and retained only for audit.
-- =============================================================================
CREATE TYPE candidate_status AS ENUM (
    'discovered',
    'enriched',
    'normalized',
    'pending_review',
    'approved',
    'merged',
    'discarded'
);
