-- =============================================================================
-- Table: audit_event_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of audit event classes (created, updated,
--                status_changed, merged, deprecated, restored, exported, ...)
--                recorded by the future audit trail.
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Audit event classes are governed, evolving business vocabulary:
--                translated, reordered, deprecated and governed over time. New
--                classes are data inserts, never schema changes. The audit
--                milestone records every event against one of these classes.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE audit_event_types (
    id             uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code           citext       NOT NULL,
    name           text         NOT NULL,
    description    text         NULL,
    display_order  integer      NOT NULL DEFAULT 0,
    status_id      bigint        NOT NULL,
    version_number  integer     NOT NULL DEFAULT 1,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    updated_at     timestamptz  NOT NULL DEFAULT now(),
    deleted_at     timestamptz  NULL,

    CONSTRAINT audit_event_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT audit_event_types_code_unique
        UNIQUE (code),
    CONSTRAINT audit_event_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE audit_event_types IS
    'Governed registry of audit event classes (created, updated, merged, ...).';
COMMENT ON COLUMN audit_event_types.code IS
    'Stable machine reference (snake_case), e.g. created, status_changed, merged.';
COMMENT ON COLUMN audit_event_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
