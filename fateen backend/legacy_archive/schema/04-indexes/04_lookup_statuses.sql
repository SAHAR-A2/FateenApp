-- =============================================================================
-- Indexes: lookup table lifecycle statuses
-- -----------------------------------------------------------------------------
-- Purpose:       Index status_id on every lookup table (PostgreSQL does not
--                index foreign-key columns automatically).
-- Work orders:   Foundation Layer, work order #6 (indexes). Architecture
--                Authority directive #007.
-- Dependencies:  Tables and constraints from 0003/0004.
-- Migration:     0005_foundation_lookup_indexes.sql
-- Rationale:     Status is the primary filtering dimension for reference data
--                (active / deprecated / archived), so each status_id column is
--                indexed. status_id is NOT NULL everywhere, so full indexes.
-- =============================================================================
CREATE INDEX languages_status_id_idx
    ON languages (status_id);

CREATE INDEX countries_status_id_idx
    ON countries (status_id);

CREATE INDEX units_status_id_idx
    ON units (status_id);

CREATE INDEX package_types_status_id_idx
    ON package_types (status_id);

CREATE INDEX barcode_types_status_id_idx
    ON barcode_types (status_id);

CREATE INDEX image_types_status_id_idx
    ON image_types (status_id);

CREATE INDEX relationship_types_status_id_idx
    ON relationship_types (status_id);

CREATE INDEX source_types_status_id_idx
    ON source_types (status_id);

CREATE INDEX source_priorities_status_id_idx
    ON source_priorities (status_id);

CREATE INDEX data_sources_status_id_idx
    ON data_sources (status_id);

CREATE INDEX health_flag_types_status_id_idx
    ON health_flag_types (status_id);
