-- =============================================================================
-- Table: entity_relationships
-- -----------------------------------------------------------------------------
-- Purpose:       Knowledge-graph edges between any two canonical core entities
--                (companies, brands, products, ingredients, allergens,
--                health_flags). The relationship_types registry defines the
--                edge vocabulary (contains_ingredient, similar_to,
--                substitutable_for, ...), with inverse pairing, so new edge
--                kinds are governed data inserts, never schema changes.
-- Work orders:   Mission 04: Relationship & Junction Tables (work orders
--                #001-#008), knowledge-graph edge table.
-- Dependencies:  Tables relationship_types, data_sources, evidence_types,
--                lifecycle_statuses (0003/0008); core entities (0012). The
--                subject/object endpoint tables must exist. FKs applied in 0017.
-- Migration:     0016_relationship_tables.sql
-- Rationale:     A polymorphic edge table cannot carry a single foreign key to
--                several entity tables. Each endpoint is therefore a UUID plus
--                an entity-type discriminator; the endpoint TYPE is validated by
--                CHECK against the set of canonical core entities, and the
--                endpoint ID is validated at the application layer and by future
--                triggers (see Mission 04 report, assumptions). No information
--                is duplicated from the endpoint entities; only the edge and its
--                provenance are stored. A directed self-relationship between two
--                distinct rows of the same entity (e.g. ingredient A similar to
--                ingredient B) is allowed; a self-loop (A similar to A) is
--                rejected by CHECK. The UNIQUE constraint over
--                (subject, object, type) prevents duplicate edges.
-- Columns:
--   subject_entity_type  Entity kind of the edge subject (CHECK list).
--   subject_id           UUID of the subject entity (no FK: polymorphic).
--   object_entity_type   Entity kind of the edge object (CHECK list).
--   object_id            UUID of the object entity (no FK: polymorphic).
--   relationship_type_id  Edge type (FK relationship_types), governs semantics.
-- =============================================================================
CREATE TABLE entity_relationships (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    subject_entity_type  text          NOT NULL,
    subject_id           uuid          NOT NULL,
    object_entity_type   text          NOT NULL,
    object_id            uuid          NOT NULL,
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

    CONSTRAINT entity_relationships_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT entity_relationships_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT entity_relationships_effective_period_check
        CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CONSTRAINT entity_relationships_subject_entity_type_check
        CHECK (subject_entity_type IN ('companies', 'brands', 'products', 'ingredients', 'allergens', 'health_flags')),
    CONSTRAINT entity_relationships_object_entity_type_check
        CHECK (object_entity_type IN ('companies', 'brands', 'products', 'ingredients', 'allergens', 'health_flags')),
    CONSTRAINT entity_relationships_no_self_loop_check
        CHECK (subject_entity_type <> object_entity_type OR subject_id <> object_id),
    CONSTRAINT entity_relationships_edge_unique
        UNIQUE (subject_entity_type, subject_id, relationship_type_id, object_entity_type, object_id)
);

COMMENT ON TABLE entity_relationships IS
    'Polymorphic knowledge-graph edges between canonical core entities.';
COMMENT ON COLUMN entity_relationships.subject_entity_type IS
    'Entity kind of the edge subject; restricted to the canonical core entities.';
COMMENT ON COLUMN entity_relationships.subject_id IS
    'UUID of the subject entity; integrity enforced at the application/trigger layer (polymorphic endpoint).';
COMMENT ON COLUMN entity_relationships.object_entity_type IS
    'Entity kind of the edge object; restricted to the canonical core entities.';
COMMENT ON COLUMN entity_relationships.object_id IS
    'UUID of the object entity; integrity enforced at the application/trigger layer (polymorphic endpoint).';
COMMENT ON COLUMN entity_relationships.relationship_type_id IS
    'Edge type (foreign key to relationship_types); the governed edge vocabulary.';
COMMENT ON COLUMN entity_relationships.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
