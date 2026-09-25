-- =============================================================================
-- Table: barcodes
-- -----------------------------------------------------------------------------
-- Purpose:       Canonical registry of barcodes. A barcode is a globally unique
--                code (GTIN family or other symbology) with its symbology
--                (barcode_type_id), issuer and jurisdiction, provenance, and two
--                orthogonal statuses: lifecycle (status_id, ADR-008) and
--                verification (verification_status_id).
-- Work orders:   Mission 07: Canonical Media & Barcode Domain.
-- Dependencies:  Extension citext (0001). Enum set (0002). Tables barcode_types,
--                verification_statuses (0025), data_sources, countries,
--                lifecycle_statuses (0003). Foreign keys applied in 0027
--                (03-constraints).
-- Migration:     0025_media_and_barcode_tables.sql
-- Rationale:     The barcode value is the natural, globally unique key (UNIQUE
--                barcode). Lifecycle follows ADR-008 exactly: status_id ->
--                lifecycle_statuses, with NO stored active/is_active boolean
--                (the mission's "active flag" is lifecycle state, not a column).
--                Verification is modeled independently via verification_status_id
--                -> verification_statuses: lifecycle answers "should this barcode
--                participate in the published knowledge base?", verification
--                answers "can this barcode be trusted?".
-- Columns:
--   barcode              Globally unique code value (citext, unique).
--   barcode_type_id      Symbology (FK barcode_types: gtin_13, qr, ...).
--   verification_status_id  Trust status of the code (FK verification_statuses).
--   issued_country_id    GS1 prefix / issuing jurisdiction, NULL = unknown.
--   confidence_level     Fact confidence of this barcode record in [0,1].
-- =============================================================================
CREATE TABLE barcodes (
    id                    uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    barcode               citext        NOT NULL,
    barcode_type_id       uuid          NOT NULL,
    verification_status_id uuid         NOT NULL,
    source_id             uuid          NULL,
    status_id             bigint        NOT NULL,
    issued_country_id     uuid          NULL,
    confidence_level      numeric       NOT NULL DEFAULT 0.5,
    version_number        integer       NOT NULL DEFAULT 1,
    created_by            uuid          NULL,
    updated_by            uuid          NULL,
    reviewed_by           uuid          NULL,
    approved_by           uuid          NULL,
    created_at            timestamptz   NOT NULL DEFAULT now(),
    updated_at            timestamptz   NOT NULL DEFAULT now(),
    deleted_at            timestamptz   NULL,

    CONSTRAINT barcodes_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT barcodes_confidence_level_check
        CHECK (confidence_level >= 0 AND confidence_level <= 1),
    CONSTRAINT barcodes_barcode_not_empty_check
        CHECK (barcode <> ''),
    CONSTRAINT barcodes_barcode_unique
        UNIQUE (barcode)
);

COMMENT ON TABLE barcodes IS
    'Canonical registry of globally unique barcodes with lifecycle and verification statuses.';
COMMENT ON COLUMN barcodes.barcode IS
    'Globally unique code value (unique, case-insensitive citext).';
COMMENT ON COLUMN barcodes.barcode_type_id IS
    'Symbology of the code (foreign key to barcode_types: gtin_13, qr, ...).';
COMMENT ON COLUMN barcodes.verification_status_id IS
    'Trust status of the code, orthogonal to lifecycle (foreign key to verification_statuses).';
COMMENT ON COLUMN barcodes.source_id IS
    'Provenance of the barcode record (foreign key to data_sources).';
COMMENT ON COLUMN barcodes.status_id IS
    'Lifecycle of the barcode (foreign key to lifecycle_statuses; ADR-008). No active boolean is stored.';
COMMENT ON COLUMN barcodes.issued_country_id IS
    'Issuing jurisdiction / GS1 prefix country, NULL when unknown (foreign key to countries).';
COMMENT ON COLUMN barcodes.confidence_level IS
    'Fact confidence of this barcode record in [0,1]; the confidence_band ENUM is derived, never stored.';
COMMENT ON COLUMN barcodes.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
