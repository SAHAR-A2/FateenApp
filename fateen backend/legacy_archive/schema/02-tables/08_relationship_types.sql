-- =============================================================================
-- Table: relationship_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of knowledge-graph edge types between governed
--                entities (contains_ingredient, similar_to, substitutable_for,
--                ...). Seeded by governance; extensible without schema changes.
-- Work orders:   Foundation Layer, work order #3 (lookup tables).
-- Dependencies:  Extension citext (0001). Enum set (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     The knowledge graph milestone references this table for all
--                edges. is_directional expresses whether subject->object order is
--                meaningful; inverse_type_id links a type to its paired inverse
--                (e.g. contains_ingredient <-> is_ingredient_of). The
--                self-referential foreign key is applied in 03-constraints.
-- Columns:
--   code             Stable machine reference (snake_case).
--   is_directional   True when subject->object order matters.
--   inverse_type_id  Self-reference to the paired inverse relationship type.
-- =============================================================================
CREATE TABLE relationship_types (
    id                uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code              citext       NOT NULL,
    name              text         NOT NULL,
    description       text         NULL,
    is_directional    boolean      NOT NULL DEFAULT true,
    inverse_type_id   uuid         NULL,
    display_order     integer      NOT NULL DEFAULT 0,
    status_id         bigint        NOT NULL,
    version_number    integer      NOT NULL DEFAULT 1,
    created_at        timestamptz  NOT NULL DEFAULT now(),
    updated_at        timestamptz  NOT NULL DEFAULT now(),
    deleted_at        timestamptz  NULL,

    CONSTRAINT relationship_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT relationship_types_code_unique
        UNIQUE (code),
    CONSTRAINT relationship_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE relationship_types IS
    'Governed registry of knowledge-graph relationship types between entities.';
COMMENT ON COLUMN relationship_types.is_directional IS
    'True when subject->object order is meaningful (paired with inverse_type_id).';
COMMENT ON COLUMN relationship_types.inverse_type_id IS
    'Self-reference to the paired inverse relationship type; NULL when symmetric.';
COMMENT ON COLUMN relationship_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
