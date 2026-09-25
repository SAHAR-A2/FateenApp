-- =============================================================================
-- Triggers: lookup tables updated_at
-- -----------------------------------------------------------------------------
-- Purpose:       Wire the shared set_updated_at() function to every lookup table
--                carrying the audit lifecycle columns.
-- Work orders:   Foundation Layer, work order #4 (governance support).
-- Dependencies:  Function set_updated_at() (06-functions, same migration).
--                Lookup tables (0003).
-- Migration:     0006_foundation_functions_and_triggers.sql
-- Rationale:     Every table with updated_at must stamp it on UPDATE. Declaring
--                one trigger per table here keeps the rule explicit and auditable.
-- =============================================================================
CREATE TRIGGER languages_set_updated_at
    BEFORE UPDATE ON languages
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER countries_set_updated_at
    BEFORE UPDATE ON countries
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER units_set_updated_at
    BEFORE UPDATE ON units
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER package_types_set_updated_at
    BEFORE UPDATE ON package_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER barcode_types_set_updated_at
    BEFORE UPDATE ON barcode_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER image_types_set_updated_at
    BEFORE UPDATE ON image_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER relationship_types_set_updated_at
    BEFORE UPDATE ON relationship_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER source_types_set_updated_at
    BEFORE UPDATE ON source_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER source_priorities_set_updated_at
    BEFORE UPDATE ON source_priorities
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER data_sources_set_updated_at
    BEFORE UPDATE ON data_sources
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER health_flag_types_set_updated_at
    BEFORE UPDATE ON health_flag_types
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER lifecycle_statuses_set_updated_at
    BEFORE UPDATE ON lifecycle_statuses
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
