-- =============================================================================
-- Table: product_categories
-- -----------------------------------------------------------------------------
-- Purpose:       Governed, hierarchical taxonomy of product categories
--                (beverages, dairy, snacks, baby_food, ...). A row may nest under
--                one parent (parent_id) to form a tree; taxonomy roots have NULL
--                parent. The self-foreign key is applied in 03-constraints (the
--                table must exist before it references itself).
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008),
--                canonical governed lookup table (ADR-001 / ADR-007 / ADR-008).
-- Dependencies:  Extension citext (0001).
-- Migration:     0008_foundation_reference_tables.sql
-- Rationale:     Product categories are governed, evolving business vocabulary:
--                translated, reordered, deprecated and governed over time. A
--                bounded parent_id hierarchy gives a clean taxonomy without a
--                separate graph table; future additions are data inserts, never
--                schema changes.
-- Columns:
--   code           Stable machine reference (snake_case).
--   parent_id      Optional parent category (self-reference); NULL for roots.
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE product_categories (
    id             uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code           citext       NOT NULL,
    name           text         NOT NULL,
    description    text         NULL,
    parent_id      uuid         NULL,
    display_order  integer      NOT NULL DEFAULT 0,
    status_id      bigint        NOT NULL,
    version_number  integer     NOT NULL DEFAULT 1,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    updated_at     timestamptz  NOT NULL DEFAULT now(),
    deleted_at     timestamptz  NULL,

    CONSTRAINT product_categories_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT product_categories_code_unique
        UNIQUE (code),
    CONSTRAINT product_categories_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE product_categories IS
    'Governed hierarchical taxonomy of product categories (self-referencing parent_id).';
COMMENT ON COLUMN product_categories.code IS
    'Stable machine reference (snake_case).';
COMMENT ON COLUMN product_categories.parent_id IS
    'Optional parent category (self-reference); NULL for taxonomy roots.';
COMMENT ON COLUMN product_categories.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
