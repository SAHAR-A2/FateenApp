-- =============================================================================
-- Table: package_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of packaging types (can, bottle, jar, pouch,
--                carton, ...) used by product packaging data.
-- Work orders:   Foundation Layer, work order #3 (lookup tables).
-- Dependencies:  Extension citext (0001). Enum set (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     Packaging vocabulary is reference data; new types are added by
--                governance, not schema migration (see ADR-001).
-- Columns:
--   code           Stable machine reference (snake_case).
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE package_types (
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

    CONSTRAINT package_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT package_types_code_unique
        UNIQUE (code),
    CONSTRAINT package_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE package_types IS
    'Governed registry of packaging types.';
COMMENT ON COLUMN package_types.display_order IS
    'Stable ordering for reference pickers; non-negative.';
COMMENT ON COLUMN package_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
