-- =============================================================================
-- Indexes: Nutrition Measurement Basis (ECR-001, Blocker 4)
-- -----------------------------------------------------------------------------
-- Purpose:       Correctness-critical indexes for the additive measurement basis
--                dimension: FK-supporting index for the new
--                product_nutrition_values.measurement_basis_id column and for
--                measurement_bases.status_id (PostgreSQL does not index FK
--                columns automatically).
-- Work orders:   ECR-001 Blocker 4 (nutrition measurement bases).
-- Dependencies:  measurement_bases (0032), constraints (0034).
-- Migration:     0035_ecr_indexes.sql
-- Rationale:     FK-supporting indexes are required for referential integrity
--                enforcement and integrity-performance. The extended natural-key
--                UNIQUE (product, nutrition_type, relationship_type,
--                measurement_basis_id) creates its own index.
-- =============================================================================
CREATE INDEX measurement_bases_status_id_idx
    ON measurement_bases (status_id);

CREATE INDEX product_nutrition_values_measurement_basis_id_idx
    ON product_nutrition_values (measurement_basis_id);
