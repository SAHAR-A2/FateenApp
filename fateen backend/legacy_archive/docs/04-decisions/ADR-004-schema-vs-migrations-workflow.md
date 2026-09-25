# ADR-004 — Canonical Schema vs. Generated Migrations

**Status:** Accepted (Foundation Layer, work order #7)
**Date:** Foundation Layer milestone

## Context

The repository has both `schema/` (decomposed DDL by object type) and
`migrations/` (versioned, deployable files). Two copies of DDL create a drift
risk unless a single source of truth is enforced.

## Decision

- **`schema/` is the canonical source of truth**, decomposed one-object-per-file
  for reviewability.
- **`migrations/` files are generated** from `schema/` by
  `scripts/build_migrations.ps1` using a fixed manifest (which is the migration
  order). They are committed for review and applied verbatim by
  `scripts/migrate.ps1`.
- Migrations are **immutable after ship**: `migrate.ps1` verifies the MD5
  checksum of every already-applied migration and aborts on mismatch.
- Workflow: edit `schema/` → run `build_migrations.ps1` → review the migration
  diff → commit. Never hand-edit a generated migration.

## Consequences

- One source of truth; drift is impossible while the workflow is followed.
- A migration's body is byte-identical to its schema sources, so a line-by-line
  review of either tree covers both.
- The manifest in `build_migrations.ps1` is the authoritative, reviewable
  migration order and must be kept in sync with `docs/02-erd/` and the
  `migrations/README.md` table.
