-- =============================================================================
-- Table: barcode_types
-- -----------------------------------------------------------------------------
-- Purpose:       Governed registry of barcode symbologies (GTIN-8/12/13/14,
--                GS1-128, QR, DataMatrix, ...) for product barcode data.
-- Work orders:   Foundation Layer, work order #3 (lookup tables).
-- Dependencies:  Extension citext (0001). Enum set (0002).
-- Migration:     0003_foundation_lookup_tables.sql
-- Rationale:     Barcode symbologies are reference data (see ADR-001). The
--                digit_length column records the fixed numeric payload length
--                where one exists, enabling payload validation in the population
--                pipeline.
-- Columns:
--   code           Stable machine reference (gs1 naming, e.g. gtin_13).
--   digit_length   Fixed numeric payload length; NULL for 2D/matrix symbologies.
-- =============================================================================
CREATE TABLE barcode_types (
    id             uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    code           citext       NOT NULL,
    name           text         NOT NULL,
    digit_length   smallint     NULL,
    description    text         NULL,
    display_order  integer      NOT NULL DEFAULT 0,
    status_id      bigint        NOT NULL,
    version_number  integer     NOT NULL DEFAULT 1,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    updated_at     timestamptz  NOT NULL DEFAULT now(),
    deleted_at     timestamptz  NULL,

    CONSTRAINT barcode_types_version_number_check
        CHECK (version_number > 0),
    CONSTRAINT barcode_types_code_unique
        UNIQUE (code),
    CONSTRAINT barcode_types_digit_length_check
        CHECK (digit_length IS NULL OR digit_length > 0),
    CONSTRAINT barcode_types_display_order_check
        CHECK (display_order >= 0)
);

COMMENT ON TABLE barcode_types IS
    'Governed registry of barcode symbologies.';
COMMENT ON COLUMN barcode_types.digit_length IS
    'Fixed numeric payload length for GTIN family; NULL for 2D/matrix types.';
COMMENT ON COLUMN barcode_types.version_number IS
    'Monotonic governance/version counter; starts at 1, increments on governed change.';
