-- =============================================================================
-- Table: verification_statuses
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of barcode verification states. Verification
--                answers "can this barcode be trusted?" and is orthogonal to the
--                lifecycle status (ADR-008), which answers "should this barcode
--                participate in the published knowledge base?".
-- Work orders:   Mission 07: Canonical Media & Barcode Domain.
-- Dependencies:  Extension citext (0001). Enum set (0002). Lifecycle table
--                lifecycle_statuses (0003). Foreign keys applied in 0027
--                (03-constraints).
-- Migration:     0025_media_and_barcode_tables.sql
-- Rationale:     Verification is governed business vocabulary (ADR-001), modeled
--                as a lookup table so states are extensible by governance, never
--                by ALTER TYPE (ADR-007). It is deliberately NOT an ENUM and NOT
--                a lifecycle duplicate: a barcode carries both status_id
--                (lifecycle) and verification_status_id (verification).
-- Columns:
--   code           Stable machine reference (snake_case, e.g. unverified).
--   display_order  Governance display ordering for pickers.
-- =============================================================================
CREATE TABLE verification_statuses (
    id              uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code            citext       NOT NULL,
    name            text         NOT NULL,
    description     text         NULL,
    display_order   integer      NOT NULL DEFAULT 0,
    status_id       bigint       NOT NULL,
    version_number  integer      NOT NULL DEFAULT 1,
    created_at      timestamptz  NOT NULL DEFAULT now(),
    updated_at      timestamptz  NOT NULL DEFAULT now(),
    deleted_at      timestamptz  NULL,

    CONSTRAINT verification_statuses_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT verification_statuses_display_order_check
        CHECK (display_order >= 0),
    CONSTRAINT verification_statuses_code_unique
        UNIQUE (code)
);

COMMENT ON TABLE verification_statuses IS
    'Governed registry of barcode verification states (trust, not lifecycle).';
COMMENT ON COLUMN verification_statuses.code IS
    'Stable machine reference (snake_case; e.g. unverified, verified).';
COMMENT ON COLUMN verification_statuses.status_id IS
    'Lifecycle of the vocabulary row itself (foreign key to lifecycle_statuses).';
COMMENT ON COLUMN verification_statuses.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
