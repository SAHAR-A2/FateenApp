-- =============================================================================
-- Table: permission_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of permission classes (read, write, approve,
--                manage, audit, ...) that the future authorization layer assigns
--                to role_types.
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Permissions are governed, evolving business vocabulary:
--                translated, reordered, deprecated and governed over time. New
--                permissions are data inserts, never schema changes. The
--                role-permission matrix is built in the authorization milestone.
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE permission_types (
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

    CONSTRAINT permission_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT permission_types_code_unique
        UNIQUE (code),
    CONSTRAINT permission_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE permission_types IS
    'Governed registry of permission classes (read, write, approve, manage, ...).';
COMMENT ON COLUMN permission_types.code IS
    'Stable machine reference (snake_case), e.g. read, write, approve, audit.';
COMMENT ON COLUMN permission_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
