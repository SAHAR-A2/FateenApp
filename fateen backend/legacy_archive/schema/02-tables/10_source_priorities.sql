-- =============================================================================
-- Table: source_priorities
-- -----------------------------------------------------------------------------
-- Purpose:       Governed trust/priority scale for data sources, used in conflict
--                resolution and confidence derivation across the pipeline.
-- Work orders:   Foundation Layer, work order #3 (lookup tables).
-- Dependencies:  Extension citext (0001). Enum set (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     Priority is a stable ordinal scale; rank makes the ordering
--                explicit and query-safe instead of relying on insertion order.
-- Columns:
--   rank  Ascending severity: 1 = lowest priority, higher value wins conflicts.
-- =============================================================================
CREATE TABLE source_priorities (
    id             uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code           citext       NOT NULL,
    name           text         NOT NULL,
    rank           smallint     NOT NULL,
    description    text         NULL,
    status_id      bigint        NOT NULL,
    version_number  integer     NOT NULL DEFAULT 1,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    updated_at     timestamptz  NOT NULL DEFAULT now(),
    deleted_at     timestamptz  NULL,

    CONSTRAINT source_priorities_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT source_priorities_code_unique
        UNIQUE (code),
    CONSTRAINT source_priorities_rank_unique
        UNIQUE (rank),
    CONSTRAINT source_priorities_rank_check
        CHECK (rank BETWEEN 1 AND 99)
);

COMMENT ON TABLE source_priorities IS
    'Governed trust/priority scale for data sources.';
COMMENT ON COLUMN source_priorities.rank IS
    'Ascending ordinal: higher rank wins conflicts; bounded to 1..99.';
COMMENT ON COLUMN source_priorities.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
