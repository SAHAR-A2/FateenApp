-- =============================================================================
-- Table: product_images
-- -----------------------------------------------------------------------------
-- Purpose:       Relationship between a product and one of its canonical images
--                (images). A product may own many images (primary, front, back,
--                nutrition panel, ...), each attached via a relationship type;
--                the image record itself stays canonical and is never duplicated
--                here. Future product-like attachments (e.g. to ingredients or
--                brands) extend this pattern, never the images model.
-- Work orders:   ECR-001 Blocker 1 (product<->image connection).
-- Dependencies:  Tables products (0012), images (0025), relationship_types,
--                data_sources, evidence_types, lifecycle_statuses (0003/0008).
--                FKs applied in 0034 (03-constraints).
-- Migration:     0032_ecr_product_media_tables.sql
-- Rationale:     Follows the Mission 04 relationship architecture exactly: the
--                full relationship column set, provenance per row (source_id,
--                evidence_type_id, confidence_level), lifecycle via status_id
--                (ADR-008), monotonic version counter, effective window, soft
--                delete, and a composite UNIQUE (product, image, relationship
--                type) that prevents duplicate assertions while allowing many
--                images per product. Image kind is governed by image_types on the
--                canonical images table (multiple image types supported without
--                schema change). No cascade anywhere (ADR-006).
-- Columns:
--   product_id          Owning product (FK products).
--   image_id            Connected canonical image (FK images).
--   relationship_type_id  Kind of attachment (FK relationship_types).
-- =============================================================================
CREATE TABLE product_images (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id           uuid          NOT NULL,
    image_id             uuid          NOT NULL,
    relationship_type_id uuid          NOT NULL,
    source_id            uuid          NULL,
    evidence_type_id     uuid          NULL,
    confidence_level     numeric       NOT NULL DEFAULT 0.5,
    effective_from       timestamptz   NULL,
    effective_to         timestamptz   NULL,
    verified_at          timestamptz   NULL,
    approved_at          timestamptz   NULL,
    status_id            bigint        NOT NULL,
    version_number       integer       NOT NULL DEFAULT 1,
    created_at           timestamptz   NOT NULL DEFAULT now(),
    updated_at           timestamptz   NOT NULL DEFAULT now(),
    deleted_at           timestamptz   NULL,

    CONSTRAINT product_images_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT product_images_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT product_images_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT product_images_attachment_unique
        UNIQUE (product_id, image_id, relationship_type_id)
);

COMMENT ON TABLE product_images IS
    'Product-to-image attachment relationship (many images per product).';
COMMENT ON COLUMN product_images.product_id IS
    'Owning product (foreign key to products).';
COMMENT ON COLUMN product_images.image_id IS
    'Connected canonical image (foreign key to images); the image row is never duplicated.';
COMMENT ON COLUMN product_images.relationship_type_id IS
    'Kind of attachment (foreign key to relationship_types: primary_image, gallery, ...).';
COMMENT ON COLUMN product_images.effective_from IS
    'Start of validity for this attachment; NULL = from creation.';
COMMENT ON COLUMN product_images.effective_to IS
    'End of validity for this attachment; NULL = currently effective.';
COMMENT ON COLUMN product_images.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
