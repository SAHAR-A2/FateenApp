-- =============================================================================
-- Table: role_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of platform user roles (admin, editor,
--                reviewer, expert, analyst, ...) used by future access control
--                and review-workflow authorization.
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Roles are governed, evolving business vocabulary: translated,
--                reordered, deprecated and governed over time. New roles are
--                data inserts, never schema changes. The authorization layer
--                assigns permissions to roles in a later milestone.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE role_types (
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

    CONSTRAINT role_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT role_types_code_unique
        UNIQUE (code),
    CONSTRAINT role_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE role_types IS
    'Governed registry of platform user roles (admin, editor, reviewer, expert, ...).';
COMMENT ON COLUMN role_types.code IS
    'Stable machine reference (snake_case), e.g. admin, editor, reviewer, expert.';
COMMENT ON COLUMN role_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
