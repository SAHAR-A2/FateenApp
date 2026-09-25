-- =============================================================================
-- Table: data_sources
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of concrete data sources (e.g. a national
--                authority, a partner feed, a scientific dataset, manual entry)
--                from which facts enter the knowledge base. Every governed fact
--                in later milestones will carry source_id and confidence_score
--                referencing this registry.
-- Work orders:   Foundation Layer, work order #3 (lookup tables). The
--                governance/confidence milestone (future) depends on this table.
-- Dependencies:  Extension citext (0001). Enum set (0002). Tables source_types,
--                source_priorities, countries (all in 0003). Foreign keys are
--                applied in 0004 (03-constraints).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     A source is classified by type and priority and may be scoped
--                to a country jurisdiction (NULL = global/unspecified).
--                is_verified marks institutional sources the pipeline may trust
--                without individual human review of every record.
-- Columns:
--   source_type_id   Category of the source (FK source_types).
--   priority_id      Trust priority for conflict resolution (FK source_priorities).
--   country_id       Jurisdictional scope; NULL = global (FK countries).
--   is_verified      True for institutionally trusted sources.
-- =============================================================================
CREATE TABLE data_sources (
    id              uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code            citext       NOT NULL,
    name            text         NOT NULL,
    description     text         NULL,
    source_type_id  uuid         NOT NULL,
    priority_id     uuid         NOT NULL,
    country_id      uuid         NULL,
    is_verified     boolean      NOT NULL DEFAULT false,
    status_id       bigint        NOT NULL,
    version_number  integer      NOT NULL DEFAULT 1,
    created_at      timestamptz  NOT NULL DEFAULT now(),
    updated_at      timestamptz  NOT NULL DEFAULT now(),
    deleted_at      timestamptz  NULL,

    CONSTRAINT data_sources_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT data_sources_code_unique
        UNIQUE (code)
);

COMMENT ON TABLE data_sources IS
    'Governed registry of concrete data sources feeding the knowledge base.';
COMMENT ON COLUMN data_sources.source_type_id IS
    'Category of the source (foreign key to source_types).';
COMMENT ON COLUMN data_sources.priority_id IS
    'Trust priority for conflict resolution (foreign key to source_priorities).';
COMMENT ON COLUMN data_sources.country_id IS
    'Jurisdictional scope; NULL means global/unspecified (foreign key to countries).';
COMMENT ON COLUMN data_sources.is_verified IS
    'True for institutionally trusted sources that may bypass per-record human review.';
COMMENT ON COLUMN data_sources.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
