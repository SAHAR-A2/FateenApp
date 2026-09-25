-- =============================================================================
-- Constraints: Relationship & Junction Tables
-- -----------------------------------------------------------------------------
-- Purpose:       Referential integrity for the Mission 04 relationship tables:
--                endpoint entities, relationship-type vocabulary, provenance
--                (source, evidence), measurement units, language scoping, and
--                the lifecycle status field. No cascade anywhere.
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008).
-- Dependencies:  Lookup tables (0003/0008), core entities (0012), and the
--                Mission 04 relationship tables (0016). Runs after all tables
--                exist.
-- Migration:     0017_relationship_constraints.sql
-- Rationale:     Cross-table integrity is applied here, after every referenced
--                table is committed (see sql_conventions.md). A referenced
--                entity or vocabulary row cannot be removed while any dependent
--                relationship uses it (ON DELETE/UPDATE RESTRICT, ADR-006).
--                entity_relationships.subject_id / object_id carry no FK: the
--                endpoint is polymorphic across several entity tables, so
--                integrity is enforced by the entity-type CHECK constraints and
--                the application/trigger layer instead (see 44_entity_relationships.sql).
-- =============================================================================
-- product_ingredients
ALTER TABLE product_ingredients
    ADD CONSTRAINT product_ingredients_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_ingredients
    ADD CONSTRAINT product_ingredients_ingredient_id_fk
        FOREIGN KEY (ingredient_id)
        REFERENCES ingredients (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_ingredients
    ADD CONSTRAINT product_ingredients_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_ingredients
    ADD CONSTRAINT product_ingredients_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_ingredients
    ADD CONSTRAINT product_ingredients_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_ingredients
    ADD CONSTRAINT product_ingredients_unit_id_fk
        FOREIGN KEY (unit_id)
        REFERENCES units (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_ingredients
    ADD CONSTRAINT product_ingredients_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- product_allergens
ALTER TABLE product_allergens
    ADD CONSTRAINT product_allergens_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_allergens
    ADD CONSTRAINT product_allergens_allergen_id_fk
        FOREIGN KEY (allergen_id)
        REFERENCES allergens (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_allergens
    ADD CONSTRAINT product_allergens_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_allergens
    ADD CONSTRAINT product_allergens_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_allergens
    ADD CONSTRAINT product_allergens_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_allergens
    ADD CONSTRAINT product_allergens_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- product_nutrition_values
ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_nutrition_type_id_fk
        FOREIGN KEY (nutrition_type_id)
        REFERENCES nutrition_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_unit_id_fk
        FOREIGN KEY (unit_id)
        REFERENCES units (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- product_health_flags
ALTER TABLE product_health_flags
    ADD CONSTRAINT product_health_flags_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_health_flags
    ADD CONSTRAINT product_health_flags_health_flag_id_fk
        FOREIGN KEY (health_flag_id)
        REFERENCES health_flags (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_health_flags
    ADD CONSTRAINT product_health_flags_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_health_flags
    ADD CONSTRAINT product_health_flags_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_health_flags
    ADD CONSTRAINT product_health_flags_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_health_flags
    ADD CONSTRAINT product_health_flags_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- ingredient_allergens
ALTER TABLE ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_ingredient_id_fk
        FOREIGN KEY (ingredient_id)
        REFERENCES ingredients (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_allergen_id_fk
        FOREIGN KEY (allergen_id)
        REFERENCES allergens (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_allergens
    ADD CONSTRAINT ingredient_allergens_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- ingredient_health_flags
ALTER TABLE ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_ingredient_id_fk
        FOREIGN KEY (ingredient_id)
        REFERENCES ingredients (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_health_flag_id_fk
        FOREIGN KEY (health_flag_id)
        REFERENCES health_flags (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_health_flags
    ADD CONSTRAINT ingredient_health_flags_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- ingredient_aliases
ALTER TABLE ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_ingredient_id_fk
        FOREIGN KEY (ingredient_id)
        REFERENCES ingredients (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_aliases
    ADD CONSTRAINT ingredient_aliases_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- entity_relationships
ALTER TABLE entity_relationships
    ADD CONSTRAINT entity_relationships_relationship_type_id_fk
        FOREIGN KEY (relationship_type_id)
        REFERENCES relationship_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE entity_relationships
    ADD CONSTRAINT entity_relationships_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE entity_relationships
    ADD CONSTRAINT entity_relationships_evidence_type_id_fk
        FOREIGN KEY (evidence_type_id)
        REFERENCES evidence_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE entity_relationships
    ADD CONSTRAINT entity_relationships_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;
