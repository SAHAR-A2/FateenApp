-- =============================================================================
-- Constraints: Version History & Audit Infrastructure
-- -----------------------------------------------------------------------------
-- Purpose:       Referential integrity for the Mission 05 history and audit
--                tables: canonical entity links (original_entity_id), version
--                chaining (previous_version_id self-references), provenance
--                (source_id, role_id), lifecycle (status_id), change grouping
--                (change_set_id), operation context (audit_context composite),
--                action classification (event_type_id), and version registry
--                links. No cascade anywhere.
-- Work orders:   Mission 05: Version History & Audit Infrastructure (work orders
--                #001-#008).
-- Dependencies:  Lookup tables (0003/0008), canonical entities (0012), history
--                tables (0020), audit tables (0021). Runs after all tables exist.
-- Migration:     0022_history_constraints.sql
-- Rationale:     Cross-table integrity is applied here, after every referenced
--                table is committed (see sql_conventions.md). A referenced
--                entity, lookup or version row cannot be removed while any
--                dependent history/audit row uses it (ON DELETE/UPDATE RESTRICT,
--                ADR-006). entity_versions.history_table / history_row_id and
--                the audit entity_type/entity_id discriminators carry no FK: the
--                target is polymorphic across several history tables (see
--                entity_relationships precedent).
-- =============================================================================
-- companies_history
ALTER TABLE companies_history
    ADD CONSTRAINT companies_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES companies (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE companies_history
    ADD CONSTRAINT companies_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES companies_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE companies_history
    ADD CONSTRAINT companies_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE companies_history
    ADD CONSTRAINT companies_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE companies_history
    ADD CONSTRAINT companies_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- brands_history
ALTER TABLE brands_history
    ADD CONSTRAINT brands_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES brands (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brands_history
    ADD CONSTRAINT brands_history_company_id_fk
        FOREIGN KEY (company_id)
        REFERENCES companies (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brands_history
    ADD CONSTRAINT brands_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES brands_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brands_history
    ADD CONSTRAINT brands_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brands_history
    ADD CONSTRAINT brands_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brands_history
    ADD CONSTRAINT brands_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- products_history
ALTER TABLE products_history
    ADD CONSTRAINT products_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products_history
    ADD CONSTRAINT products_history_brand_id_fk
        FOREIGN KEY (brand_id)
        REFERENCES brands (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products_history
    ADD CONSTRAINT products_history_product_category_id_fk
        FOREIGN KEY (product_category_id)
        REFERENCES product_categories (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products_history
    ADD CONSTRAINT products_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES products_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products_history
    ADD CONSTRAINT products_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products_history
    ADD CONSTRAINT products_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products_history
    ADD CONSTRAINT products_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- ingredients_history
ALTER TABLE ingredients_history
    ADD CONSTRAINT ingredients_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES ingredients (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredients_history
    ADD CONSTRAINT ingredients_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES ingredients_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredients_history
    ADD CONSTRAINT ingredients_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredients_history
    ADD CONSTRAINT ingredients_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredients_history
    ADD CONSTRAINT ingredients_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- allergens_history
ALTER TABLE allergens_history
    ADD CONSTRAINT allergens_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES allergens (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergens_history
    ADD CONSTRAINT allergens_history_allergen_type_id_fk
        FOREIGN KEY (allergen_type_id)
        REFERENCES allergen_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergens_history
    ADD CONSTRAINT allergens_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES allergens_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergens_history
    ADD CONSTRAINT allergens_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergens_history
    ADD CONSTRAINT allergens_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergens_history
    ADD CONSTRAINT allergens_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- health_flags_history
ALTER TABLE health_flags_history
    ADD CONSTRAINT health_flags_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES health_flags (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flags_history
    ADD CONSTRAINT health_flags_history_health_flag_type_id_fk
        FOREIGN KEY (health_flag_type_id)
        REFERENCES health_flag_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flags_history
    ADD CONSTRAINT health_flags_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES health_flags_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flags_history
    ADD CONSTRAINT health_flags_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flags_history
    ADD CONSTRAINT health_flags_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flags_history
    ADD CONSTRAINT health_flags_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- nutrition_types_history
ALTER TABLE nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES nutrition_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES nutrition_types_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE nutrition_types_history
    ADD CONSTRAINT nutrition_types_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- product_categories_history
ALTER TABLE product_categories_history
    ADD CONSTRAINT product_categories_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES product_categories (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_categories_history
    ADD CONSTRAINT product_categories_history_parent_id_fk
        FOREIGN KEY (parent_id)
        REFERENCES product_categories (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_categories_history
    ADD CONSTRAINT product_categories_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES product_categories_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_categories_history
    ADD CONSTRAINT product_categories_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_categories_history
    ADD CONSTRAINT product_categories_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_categories_history
    ADD CONSTRAINT product_categories_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- ingredient_categories_history
ALTER TABLE ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_original_entity_id_fk
        FOREIGN KEY (original_entity_id)
        REFERENCES ingredient_categories (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_parent_id_fk
        FOREIGN KEY (parent_id)
        REFERENCES ingredient_categories (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES ingredient_categories_history (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_categories_history
    ADD CONSTRAINT ingredient_categories_history_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- audit_context
ALTER TABLE audit_context
    ADD CONSTRAINT audit_context_role_id_fk
        FOREIGN KEY (role_id)
        REFERENCES role_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- change_sets
ALTER TABLE change_sets
    ADD CONSTRAINT change_sets_audit_context_fk
        FOREIGN KEY (correlation_id, transaction_id)
        REFERENCES audit_context (correlation_id, transaction_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- audit_log
ALTER TABLE audit_log
    ADD CONSTRAINT audit_log_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE audit_log
    ADD CONSTRAINT audit_log_event_type_id_fk
        FOREIGN KEY (event_type_id)
        REFERENCES audit_event_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE audit_log
    ADD CONSTRAINT audit_log_role_id_fk
        FOREIGN KEY (role_id)
        REFERENCES role_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- audit_events
ALTER TABLE audit_events
    ADD CONSTRAINT audit_events_audit_log_id_fk
        FOREIGN KEY (audit_log_id)
        REFERENCES audit_log (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE audit_events
    ADD CONSTRAINT audit_events_event_type_id_fk
        FOREIGN KEY (event_type_id)
        REFERENCES audit_event_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- entity_versions
ALTER TABLE entity_versions
    ADD CONSTRAINT entity_versions_change_set_id_fk
        FOREIGN KEY (change_set_id)
        REFERENCES change_sets (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE entity_versions
    ADD CONSTRAINT entity_versions_previous_version_id_fk
        FOREIGN KEY (previous_version_id)
        REFERENCES entity_versions (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- version_metadata
ALTER TABLE version_metadata
    ADD CONSTRAINT version_metadata_entity_version_id_fk
        FOREIGN KEY (entity_version_id)
        REFERENCES entity_versions (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;
