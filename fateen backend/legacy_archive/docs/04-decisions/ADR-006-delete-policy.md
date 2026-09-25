# ADR-006 — Non-Destructive Delete Policy

**Status:** Accepted (Foundation Layer, work orders #5/#6), amended for
lifecycle (`ADR-008`)
**Date:** Foundation Layer milestone

## Context

The approved architecture states the database follows a non-destructive lifecycle:
deletion is almost never physical. The Foundation Layer must establish the
constraint policy that makes this enforceable.

## Decision

- **`ON DELETE RESTRICT` on every foreign key.** Physical deletion of a row that
  is referenced by any child row is rejected by the database. `ON DELETE CASCADE`
  is forbidden unless a work order explicitly requires it — none do.
- **Soft delete via `deleted_at`** on every table: a row is retired by setting
  `deleted_at`, never removed.
- **Lifecycle via `status_id`** (amended by `ADR-008`): lookup tables progress
  through `lifecycle_statuses` (`ACTIVE` → `DEPRECATED` → `ARCHIVED`); deprecation
  replaces deletion.
- Physical deletes are reserved for data-repair operations executed by a DBA in
  a maintenance window.

## Consequences

- Referential integrity is never silently broken by cascades.
- Historical and audit data survive entity retirement.
- Migrating a lookup value out of service is a `status_id = DEPRECATED` update,
  not a delete; future business tables may safely FK to this registry.
