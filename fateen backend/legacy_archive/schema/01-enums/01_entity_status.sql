-- =============================================================================
-- Enum: entity_status
-- -----------------------------------------------------------------------------
-- Purpose:       Lifecycle of a governed entity (product, ingredient, brand, ...)
--                once it exists in the knowledge base. This is the PUBLISHED
--                lifecycle. The review/approval workflow state is tracked
--                separately by approval_status.
-- Work orders:   Foundation Layer, work order #2 (enumerations).
-- Dependencies:  None.
-- Migration:     0002_foundation_enums.sql
-- Rule:          Internal immutable system state only; never governed business
--                knowledge (ADR-001 / ADR-007).
-- Rationale:     Governed entities are never hard-deleted; they progress through
--                a published lifecycle and may be deprecated or archived while
--                their version history remains intact.
-- Values:
--   draft       Being authored, not yet visible as published content.
--   active      Published and visible; governed by the review workflow.
--   inactive    Temporarily hidden from active views; history retained.
--   deprecated  Superseded; still resolvable and linked for integrity.
--   archived    Withdrawn from active use; retained only for history/audit.
-- =============================================================================
CREATE TYPE entity_status AS ENUM (
    'draft',
    'active',
    'inactive',
    'deprecated',
    'archived'
);
