-- =============================================================================
-- Table: lifecycle_statuses
-- -----------------------------------------------------------------------------
-- Purpose:       Shared non-destructive lifecycle vocabulary for every governed
--                lookup/domain table: ACTIVE, DEPRECATED, ARCHIVED. Reference
--                rows are never hard-deleted; they progress through this status
--                instead (ADR-006 / ADR-008).
-- Work orders:   Foundation Layer, work order #3 (lookup tables). Architecture
--                Authority directive #007 (explicit lifecycle on lookup tables).
-- Dependencies:  Extension citext (0001).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     status_id on every lookup table is the authoritative lifecycle
--                field (business logic must never depend solely on a boolean).
--                This small, closed reference uses a BIGINT identity key per the
--                Architecture Authority directive - the single exception to the
--                UUID-key convention (ADR-008). Future states (PENDING,
--                DISABLED, SUPERSEDED) are data inserts, never schema changes.
-- Columns:
--   code           Stable machine reference: ACTIVE, DEPRECATED, ARCHIVED.
-- =============================================================================
CREATE TABLE lifecycle_statuses (
    id             bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code           citext       NOT NULL,
    name           text         NOT NULL,
    description    text         NULL,
    display_order  integer      NOT NULL DEFAULT 0,
    version_number  integer     NOT NULL DEFAULT 1,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    updated_at     timestamptz  NOT NULL DEFAULT now(),
    deleted_at     timestamptz  NULL,

    CONSTRAINT lifecycle_statuses_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT lifecycle_statuses_code_unique
        UNIQUE (code),
    CONSTRAINT lifecycle_statuses_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE lifecycle_statuses IS
    'Shared non-destructive lifecycle vocabulary (ACTIVE, DEPRECATED, ARCHIVED); the status authority for every lookup table.';
COMMENT ON COLUMN lifecycle_statuses.id IS
    'BIGINT identity key (Architecture Authority directive; exception to the UUID convention, ADR-008).';
COMMENT ON COLUMN lifecycle_statuses.code IS
    'Stable machine reference: ACTIVE, DEPRECATED, ARCHIVED; future states are data inserts.';
COMMENT ON COLUMN lifecycle_statuses.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
