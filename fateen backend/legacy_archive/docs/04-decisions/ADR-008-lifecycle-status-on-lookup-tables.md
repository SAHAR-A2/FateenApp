# ADR-008 — Lifecycle Status on Lookup Tables

**Status:** Accepted (Architecture Authority directive #007)
**Date:** Foundation Layer milestone (refactor)

## Context

The approved architecture defines a non-destructive lifecycle for
lookup/reference domains: reference rows are never hard-deleted; they progress
through a lifecycle (`ACTIVE`, `DEPRECATED`, `ARCHIVED`, and later
`PENDING`, `DISABLED`, `SUPERSEDED`). A `BOOLEAN` can represent only two states
and cannot express this lifecycle, nor grow to a third/fourth state without a
schema change.

## Decision

1. **`lifecycle_statuses`** is a shared lookup table holding the lifecycle
   vocabulary. Initial seed values (`0007`): `ACTIVE`, `DEPRECATED`, `ARCHIVED`.
   Future states are **data inserts**, never schema changes.
2. **Every governed lookup table carries `status_id BIGINT NOT NULL REFERENCES
   lifecycle_statuses(id)`** (`languages`, `countries`, `units`, `package_types`,
   `barcode_types`, `image_types`, `relationship_types`, `source_types`,
   `source_priorities`, `data_sources`, `health_flag_types`). FKs use
   `ON DELETE RESTRICT` / `ON UPDATE RESTRICT` (`ADR-006`).
3. `status_id` is the **authoritative** lifecycle field. Business logic must
   never depend solely on a boolean.
4. **`is_active` is demoted.** It is not stored on lookup tables. Where a
   convenience flag is needed it is a computed/view-layer expression derived from
   `status_id` — never a second source of truth.
5. **BIGINT identity exception:** per the Architecture Authority directive,
   `lifecycle_statuses.id` is `BIGINT GENERATED ALWAYS AS IDENTITY`. This is the
   single exception to the repository's UUID-key convention; every other table
   keeps `uuid` keys (`ADR-001`, `sql_conventions.md`).
6. `lifecycle_statuses` itself has no `status_id`: it is the status authority,
   not a governed instance. It still carries `version_number` and audit columns.
7. A `DEPRECATED`/`ARCHIVED` transition is an `UPDATE` of `status_id`; history
   is preserved via the audit milestone (`ADR-005`).

## Consequences

- Lookup lifecycle is expressive, versioned, and extensible without redesign.
- `status_id` FKs are indexed on every lookup table (0005) and validated by
  `scripts/validate_foundation.ps1`.
- No schema change is required to add `PENDING`, `DISABLED`, or `SUPERSEDED`;
  only a governed insert into `lifecycle_statuses`.
- This ADR supersedes the `is_active`-based lifecycle language in `ADR-006` and
  the column-layout guidance in `sql_conventions.md`.
