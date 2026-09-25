-- =============================================================================
-- Table: measurement_bases
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of nutrition measurement bases: the reference
--                that the amount_value of a product_nutrition_values fact is
--                expressed against (per 100 g, per serving, per package, ...).
-- Work orders:   ECR-001 Blocker 4 (nutrition measurement bases).
-- Dependencies:  Extension citext (0001). Enum set (0002). Lifecycle table
--                lifecycle_statuses (0003). FK applied in 0034.
-- Migration:     0032_ecr_product_media_tables.sql
-- Rationale:     Following ADR-001/ADR-007 the basis is reference/business
--                knowledge, so it is a governed lookup table, NOT an ENUM: new
--                bases are data inserts, never schema changes (future
--                extensibility). The approved canonical codes are per_100g,
--                per_serving and per_package; their seed rows belong to the
--                Phase 8 governed vocabulary (this repository never invents seed
--                data), while the table structure and the UNIQUE code constraint
--                are provided now so product_nutrition_values can reference the
--                basis. The basis is a new additive dimension on the nutrition
--                fact: the natural key of a fact becomes
--                (product, nutrition_type, relationship_type, measurement_basis),
--                so the same fact may legitimately exist per 100 g AND per
--                serving AND per package.
-- Columns:
--   code           Stable machine reference (snake_case, unique).
--   name           Canonical English name of the basis.
--   display_order  Stable ordering for reference pickers and displays.
-- =============================================================================
CREATE TABLE measurement_bases (
    id             uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code           citext       NOT NULL,
    name           text         NOT NULL,
    description    text         NULL,
    display_order  integer      NOT NULL DEFAULT 0,
    status_id      bigint       NOT NULL,
    version_number integer      NOT NULL DEFAULT 1,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    updated_at     timestamptz  NOT NULL DEFAULT now(),
    deleted_at     timestamptz  NULL,

    CONSTRAINT measurement_bases_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT measurement_bases_code_unique
        UNIQUE (code),
    CONSTRAINT measurement_bases_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE measurement_bases IS
    'Governed registry of nutrition measurement bases (per_100g, per_serving, per_package, ...).';
COMMENT ON COLUMN measurement_bases.code IS
    'Stable machine reference (snake_case, unique); seed vocabulary belongs to Phase 8.';
COMMENT ON COLUMN measurement_bases.name IS
    'Canonical English name of the measurement basis.';
COMMENT ON COLUMN measurement_bases.display_order IS
    'Stable ordering for reference pickers; non-negative.';
COMMENT ON COLUMN measurement_bases.status_id IS
    'Lifecycle of the basis (foreign key to lifecycle_statuses; ADR-008).';
COMMENT ON COLUMN measurement_bases.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
