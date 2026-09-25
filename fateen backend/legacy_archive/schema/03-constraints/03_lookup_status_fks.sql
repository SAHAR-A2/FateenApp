-- =============================================================================
-- Constraints: lookup table lifecycle statuses
-- -----------------------------------------------------------------------------
-- Purpose:       Every governed lookup table's status_id references the shared
--                lifecycle_statuses registry (ADR-008). No cascade anywhere: a
--                lifecycle status cannot be removed while any lookup row uses it.
-- Work orders:   Foundation Layer, work orders #5 (constraints) and #3.
--                Architecture Authority directive #007.
-- Dependencies:  Tables lifecycle_statuses and all 11 lookup tables (0003).
--                Runs after all tables exist.
-- Migration:     0004_foundation_lookup_constraints.sql
-- Rationale:     Cross-table integrity is applied here, after every referenced
--                table is committed (see sql_conventions.md).
-- =============================================================================
ALTER TABLE languages
    ADD CONSTRAINT languages_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE countries
    ADD CONSTRAINT countries_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE units
    ADD CONSTRAINT units_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE package_types
    ADD CONSTRAINT package_types_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE barcode_types
    ADD CONSTRAINT barcode_types_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE image_types
    ADD CONSTRAINT image_types_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE relationship_types
    ADD CONSTRAINT relationship_types_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE source_types
    ADD CONSTRAINT source_types_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE source_priorities
    ADD CONSTRAINT source_priorities_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE data_sources
    ADD CONSTRAINT data_sources_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flag_types
    ADD CONSTRAINT health_flag_types_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;
