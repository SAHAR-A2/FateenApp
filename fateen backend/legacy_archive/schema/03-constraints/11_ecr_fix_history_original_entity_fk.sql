-- =============================================================================
-- Constraints: history original_entity_id FKs — ECR-003 deferral fix
-- -----------------------------------------------------------------------------
-- Purpose:       ECR-003 follow-up discovered during live verification: the
--                0037 capture triggers are BEFORE INSERT triggers, so when a
--                tracked entity row is created the trigger runs before the
--                parent row exists. The {table}_history.original_entity_id
--                foreign keys were NOT DEFERRABLE and checked immediately, so
--                every INSERT of a tracked entity failed with
--                '..._original_entity_id_fk: key is not present in table'.
--                Making these FKs DEFERRABLE INITIALLY DEFERRED postpones the
--                check to COMMIT time, by which the parent row exists.
--                Referential integrity is preserved (orphans are still
--                rejected, only the check point moves to the end of the
--                transaction).
-- Defect fixed:   All 13 history tables shared this INSERT-time FK conflict:
--                companies, brands, products, ingredients, allergens,
--                health_flags, nutrition_types, product_categories,
--                ingredient_categories, images, barcodes, product_images,
--                product_barcodes. The original_entity_id FK of each is
--                flipped to DEFERRABLE INITIALLY DEFERRED (its action clause
--                is untouched).
-- Work orders:   ECR-003 (runtime defect fix, second defect).
-- Dependencies:  History tables and their original_entity_id FKs from
--                0022/0027/0034; capture triggers from 0037.
-- Migration:     0039_ecr_fix_history_original_entity_fk.sql
-- =============================================================================

ALTER TABLE companies_history
    ALTER CONSTRAINT companies_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE brands_history
    ALTER CONSTRAINT brands_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE products_history
    ALTER CONSTRAINT products_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ingredients_history
    ALTER CONSTRAINT ingredients_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE allergens_history
    ALTER CONSTRAINT allergens_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE health_flags_history
    ALTER CONSTRAINT health_flags_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE nutrition_types_history
    ALTER CONSTRAINT nutrition_types_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE product_categories_history
    ALTER CONSTRAINT product_categories_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ingredient_categories_history
    ALTER CONSTRAINT ingredient_categories_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE images_history
    ALTER CONSTRAINT images_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE barcodes_history
    ALTER CONSTRAINT barcodes_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE product_images_history
    ALTER CONSTRAINT product_images_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE product_barcodes_history
    ALTER CONSTRAINT product_barcodes_history_original_entity_id_fk
    DEFERRABLE INITIALLY DEFERRED;
