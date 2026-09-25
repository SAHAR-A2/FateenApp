-- =============================================================================
-- Table: image_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of product image categories (primary, front,
--                back, nutrition facts panel, ingredients list, packaging,
--                logo, barcode, ...).
-- Work orders:   Foundation Layer, work order #3 (lookup tables).
-- Dependencies:  Extension citext (0001). Enum set (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     Image categories are reference data (see ADR-001). They exist
--                now so the images milestone can reference them without redesign.
-- =============================================================================
CREATE TABLE image_types (
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

    CONSTRAINT image_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT image_types_code_unique
        UNIQUE (code),
    CONSTRAINT image_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE image_types IS
    'Governed registry of product image categories.';
COMMENT ON COLUMN image_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
