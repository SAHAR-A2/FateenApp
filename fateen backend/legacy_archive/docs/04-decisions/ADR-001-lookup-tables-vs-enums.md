# ADR-001 — Lookup Tables vs. PostgreSQL ENUMs

**Status:** Accepted (Foundation Layer, work order #2/#3)
**Date:** Foundation Layer milestone

## Context

The Foundation Layer mission listed six concepts under BOTH the enum requirement
and the lookup-table requirement:

| Concept              | Enum list          | Lookup table list |
| -------------------- | ------------------ | ----------------- |
| Languages            | Language Code      | `languages`       |
| Barcodes             | Barcode Type       | `barcode_types`   |
| Images               | Image Type         | `image_types`     |
| Relationships        | Relationship Type  | `relationship_types` |
| Source categories    | Source Type        | `source_types`    |
| Source priority      | Source Priority    | `source_priorities` |

The approved architecture mandates **no duplicated information** and requires
future **GCC expansion** and **global expansion** without redesign. These two
requirements conflict with creating both an enum and a table for the same value
set.

## Decision

For these six concepts, the **lookup table is authoritative**. The corresponding
PostgreSQL `ENUM` is **not created**. Each lookup table exposes a unique, stable,
case-insensitive `code` column that future tables foreign-key.

Only genuinely closed, stable value sets are modeled as `ENUM`:
`entity_status`, `approval_status`, `review_tier`, `review_decision`,
`version_status`, `confidence_band`, `translation_status`, `candidate_status`,
`update_type`, `unit_dimension`.

`health_flag_type` was originally listed as an enum alongside these; under
`ADR-007` it is governed business vocabulary and now ships as the
`health_flag_types` lookup table.

## Consequences

- Adding a language, relationship type, source type, health-flag class, etc. is a
  **data insert** governed by the review workflow — never a schema migration.
  This directly serves the GCC/global expansion mandate.
- ENUMs are used only where a value set is part of the schema's own vocabulary
  (statuses, decisions, tiers) and is expected to change only via architecture.
- The Foundation Layer's enum inventory (10) is smaller than the mission's
  illustrative list (17). The seven omissions — including `health_flag_type`,
  reclassified under `ADR-007` — are intentional and this ADR (with `ADR-007`)
  is their authority. Every look-up pair ships as a governed table instead.
- `unit_dimension` is an additional enum not on the mission's illustrative list;
  it is required by the `units` table and is justified in `schema/01-enums/10_unit_dimension.sql`.
