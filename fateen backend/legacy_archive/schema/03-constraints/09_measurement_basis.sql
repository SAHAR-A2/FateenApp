-- =============================================================================
-- Constraints: Nutrition Measurement Basis (ECR-001, Blocker 4)
-- -----------------------------------------------------------------------------
-- Purpose:       Add the measurement basis dimension to product_nutrition_values
--                so a nutrition fact can be expressed per 100 g, per serving,
--                per package, and future bases. The change is additive: a new
--                NULLable column (backward compatible - existing inserts without
--                a basis keep working), a foreign key to the governed
--                measurement_bases vocabulary, and an extended natural key.
-- Work orders:   ECR-001 Blocker 4 (nutrition measurement bases).
-- Dependencies:  measurement_bases (0032), product_nutrition_values (0016),
--                lifecycle_statuses (0003). Runs after all tables exist.
-- Migration:     0034_ecr_constraints.sql
-- Rationale:     The original natural key UNIQUE (product, nutrition_type,
--                relationship_type) prevented the same fact from existing in
--                more than one basis. Extending it with measurement_basis_id
--                keeps the constraint name and semantics while allowing
--                per_100g AND per_serving AND per_package to coexist. NULL
--                measurement_basis_id is allowed (PostgreSQL UNIQUE treats NULLs
--                as distinct) so pre-existing fact rows remain valid and
--                backward compatible; the population milestone is expected to
--                require a basis for new facts. ON DELETE/UPDATE RESTRICT
--                (ADR-006): a measurement basis cannot be removed while facts
--                reference it.
-- =============================================================================
ALTER TABLE product_nutrition_values
    ADD COLUMN measurement_basis_id uuid NULL;

ALTER TABLE product_nutrition_values
    DROP CONSTRAINT product_nutrition_values_fact_unique;

ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_fact_unique
        UNIQUE (product_id, nutrition_type_id, relationship_type_id, measurement_basis_id);

ALTER TABLE product_nutrition_values
    ADD CONSTRAINT product_nutrition_values_measurement_basis_id_fk
        FOREIGN KEY (measurement_basis_id)
        REFERENCES measurement_bases (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;

ALTER TABLE measurement_bases
    ADD CONSTRAINT measurement_bases_status_id_fk
        FOREIGN KEY (status_id)
        REFERENCES lifecycle_statuses (id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT;
