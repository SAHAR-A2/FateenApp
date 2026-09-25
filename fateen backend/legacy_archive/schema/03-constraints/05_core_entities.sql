-- =============================================================================
-- Constraints: Canonical Core Entities
-- -----------------------------------------------------------------------------
-- Purpose:       Referential integrity for the Mission 03 core entities and
--                their translation tables: lifecycle status, provenance source,
--                entity hierarchy (companies -> brands -> products), type
--                classification (allergens, health_flags), and per-language
--                translations. No cascade anywhere.
-- Work orders:   Mission 03: Canonical Core Entities (work orders #001-#008).
-- Dependencies:  Tables lifecycle_statuses (0003), languages (0003),
--                data_sources (0003), allergen_types (0008), health_flag_types
--                (0003), product_categories (0008), and the Mission 03 core
--                entity tables (0012). Runs after all tables exist.
-- Migration:     0013_core_entity_constraints.sql
-- Rationale:     Cross-table integrity is applied here, after every referenced
--                table is committed (see sql_conventions.md). A referenced
--                entity or lookup cannot be removed while any dependent row
--                uses it (ON DELETE/UPDATE RESTRICT, ADR-006).
-- =============================================================================
-- Lifecycle status (ADR-008) on every canonical core entity.
ALTER TABLE companies
    ADD CONSTRAINT companies_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brands
    ADD CONSTRAINT brands_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products
    ADD CONSTRAINT products_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredients
    ADD CONSTRAINT ingredients_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergens
    ADD CONSTRAINT allergens_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flags
    ADD CONSTRAINT health_flags_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- Provenance: every canonical core entity cites its data source.
ALTER TABLE companies
    ADD CONSTRAINT companies_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brands
    ADD CONSTRAINT brands_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products
    ADD CONSTRAINT products_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredients
    ADD CONSTRAINT ingredients_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergens
    ADD CONSTRAINT allergens_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flags
    ADD CONSTRAINT health_flags_source_id_fk
        FOREIGN KEY (source_id)
        REFERENCES data_sources (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- Entity hierarchy and classification.
ALTER TABLE brands
    ADD CONSTRAINT brands_company_id_fk
        FOREIGN KEY (company_id)
        REFERENCES companies (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products
    ADD CONSTRAINT products_brand_id_fk
        FOREIGN KEY (brand_id)
        REFERENCES brands (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE products
    ADD CONSTRAINT products_product_category_id_fk
        FOREIGN KEY (product_category_id)
        REFERENCES product_categories (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergens
    ADD CONSTRAINT allergens_allergen_type_id_fk
        FOREIGN KEY (allergen_type_id)
        REFERENCES allergen_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flags
    ADD CONSTRAINT health_flags_health_flag_type_id_fk
        FOREIGN KEY (health_flag_type_id)
        REFERENCES health_flag_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

-- Translation tables: owner entity and language.
ALTER TABLE company_translations
    ADD CONSTRAINT company_translations_company_id_fk
        FOREIGN KEY (company_id)
        REFERENCES companies (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE company_translations
    ADD CONSTRAINT company_translations_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brand_translations
    ADD CONSTRAINT brand_translations_brand_id_fk
        FOREIGN KEY (brand_id)
        REFERENCES brands (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE brand_translations
    ADD CONSTRAINT brand_translations_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_translations
    ADD CONSTRAINT product_translations_product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_translations
    ADD CONSTRAINT product_translations_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_translations
    ADD CONSTRAINT ingredient_translations_ingredient_id_fk
        FOREIGN KEY (ingredient_id)
        REFERENCES ingredients (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE ingredient_translations
    ADD CONSTRAINT ingredient_translations_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergen_translations
    ADD CONSTRAINT allergen_translations_allergen_id_fk
        FOREIGN KEY (allergen_id)
        REFERENCES allergens (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE allergen_translations
    ADD CONSTRAINT allergen_translations_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE nutrition_type_translations
    ADD CONSTRAINT nutrition_type_translations_nutrition_type_id_fk
        FOREIGN KEY (nutrition_type_id)
        REFERENCES nutrition_types (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE nutrition_type_translations
    ADD CONSTRAINT nutrition_type_translations_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_category_translations
    ADD CONSTRAINT product_category_translations_product_category_id_fk
        FOREIGN KEY (product_category_id)
        REFERENCES product_categories (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE product_category_translations
    ADD CONSTRAINT product_category_translations_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flag_translations
    ADD CONSTRAINT health_flag_translations_health_flag_id_fk
        FOREIGN KEY (health_flag_id)
        REFERENCES health_flags (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE health_flag_translations
    ADD CONSTRAINT health_flag_translations_language_id_fk
        FOREIGN KEY (language_id)
        REFERENCES languages (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;
