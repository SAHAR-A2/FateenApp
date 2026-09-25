-- =============================================================================
-- Indexes: Foundation Reference Domain tables
-- -----------------------------------------------------------------------------
-- Purpose:       Index status_id on every Mission 02 reference table and
--                parent_id on the two category taxonomies (PostgreSQL does not
--                index foreign-key columns automatically).
-- Work orders:   Mission 02: Foundation Reference Domain (work orders #001-#008).
--                Architecture Authority directive #007.
-- Dependencies:  Tables (0008) and constraints (0009).
-- Migration:     0010_foundation_reference_indexes.sql
-- Rationale:     Status is the primary filtering dimension for reference data
--                (active / deprecated / archived), so each status_id column is
--                indexed. Taxonomy parent lookups drive tree walks, so
--                parent_id is indexed too. All columns are nullable or NOT NULL
--                full indexes; no partial index needed here.
-- =============================================================================
CREATE INDEX regions_status_id_idx
    ON regions (status_id);

CREATE INDEX ingredient_categories_status_id_idx
    ON ingredient_categories (status_id);

CREATE INDEX ingredient_categories_parent_id_idx
    ON ingredient_categories (parent_id);

CREATE INDEX product_categories_status_id_idx
    ON product_categories (status_id);

CREATE INDEX product_categories_parent_id_idx
    ON product_categories (parent_id);

CREATE INDEX allergen_types_status_id_idx
    ON allergen_types (status_id);

CREATE INDEX nutrition_types_status_id_idx
    ON nutrition_types (status_id);

CREATE INDEX regulatory_authorities_status_id_idx
    ON regulatory_authorities (status_id);

CREATE INDEX evidence_types_status_id_idx
    ON evidence_types (status_id);

CREATE INDEX role_types_status_id_idx
    ON role_types (status_id);

CREATE INDEX permission_types_status_id_idx
    ON permission_types (status_id);

CREATE INDEX audit_event_types_status_id_idx
    ON audit_event_types (status_id);
