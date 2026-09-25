-- =============================================================================
-- Indexes: data_sources
-- -----------------------------------------------------------------------------
-- Purpose:       Index all foreign-key columns of data_sources.
-- Work orders:   Foundation Layer, work order #6 (indexes).
-- Dependencies:  Table data_sources (0003) and its constraints (0004).
-- Migration:     0005_foundation_lookup_indexes.sql
-- Rationale:     PostgreSQL does not automatically index foreign-key columns.
--                Sources are filtered by category, priority, and jurisdiction in
--                governance queries, so each FK column is indexed. source_type_id
--                and priority_id are NOT NULL, so full indexes; country_id is
--                nullable, so a partial index that skips NULLs.
-- =============================================================================
CREATE INDEX data_sources_source_type_id_idx
    ON data_sources (source_type_id);

CREATE INDEX data_sources_priority_id_idx
    ON data_sources (priority_id);

CREATE INDEX data_sources_country_id_idx
    ON data_sources (country_id)
    WHERE country_id IS NOT NULL;
