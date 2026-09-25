# ADR-002 — Single `public` Schema

**Status:** Accepted (Foundation Layer)
**Date:** Foundation Layer milestone

## Context

The Foundation Layer must decide whether DDL targets `public` or named schemas
(`core`, `i18n`, `gov`, ...). Multi-schema layouts add privilege boundaries and
namespace discipline but also add cross-schema FK and search_path complexity.

## Decision

All Foundation Layer objects live in the default **`public`** schema. No
fully-qualified object names are used; object names are globally unique.

## Consequences

- Simpler migrations, FKs, and tooling (no `search_path` management).
- PostgreSQL's default `public` privileges are restricted on new clusters; the
  owner role is explicitly granted `ALL ON SCHEMA public` in
  `scripts/create_database.sql`.
- If a future milestone needs privilege separation (e.g. a read-only reporting
  role), this can be layered on without object relocation. If object-level
  schema decomposition is ever required, a migration can move objects; this is
  not anticipated and is not part of the approved architecture.
