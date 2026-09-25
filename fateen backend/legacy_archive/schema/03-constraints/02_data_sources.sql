-- =============================================================================
-- Constraints: data_sources
-- -----------------------------------------------------------------------------
-- Purpose:       Referential integrity from data_sources to its classification
--                and jurisdiction lookups. No cascade anywhere: a referenced
--                lookup cannot be removed while sources depend on it.
-- Work orders:   Foundation Layer, work orders #5 (constraints) and #3.
-- Dependencies:  Tables data_sources, source_types, source_priorities,
--                countries (all in 0003). Runs after all tables exist.
-- Migration:     0004_foundation_lookup_constraints.sql
-- Rationale:     Foreign keys are applied here, after every referenced table is
--                committed, keeping 03-constraints the single home for
--                cross-table integrity (see sql_conventions.md).
-- =============================================================================
ALTER TABLE data_sources
    ADD CONSTRAINT data_sources_source_type_id_fk
        FOREIGN KEY (source_type_id)
        REFERENCES source_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE data_sources
    ADD CONSTRAINT data_sources_priority_id_fk
        FOREIGN KEY (priority_id)
        REFERENCES source_priorities (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE data_sources
    ADD CONSTRAINT data_sources_country_id_fk
        FOREIGN KEY (country_id)
        REFERENCES countries (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;
