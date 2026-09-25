# SQL Engineering Conventions — Fateen Database

These conventions govern **every** SQL object in this repository. They exist so that any
senior PostgreSQL engineer can review any file without explanation. Deviations require an
ADR and must be called out in the file header.

## Identifier naming

| Rule                                                          | Example                                  |
| ------------------------------------------------------------- | ---------------------------------------- |
| `snake_case`, lowercase, ASCII only                            | `barcode_types`, `source_priority_id`    |
| Table names are **plural** nouns                               | `languages`, `data_sources`              |
| Column names are **singular**                                  | `code`, `name`, `description`            |
| Foreign-key columns are the **singular target table name + `_id`** | `country_id`, `source_type_id`       |
| Natural keys / codes are named `code`                          | `languages.code`                         |
| No abbreviations (`desc` → `description`, `idx` → `index`)     | `created_at`, `updated_at`, `deleted_at` |
| Enum type names: `snake_case`, singular noun phrase             | `approval_status`, `confidence_band`     |
| Constraint names: `{table}_{column/cols}_{kind}`                | `languages_code_unique`, `units_dimension_check` |

Documented category-suffix exceptions to plural table names (each is a distinct
structural role, not a plural noun): history mirrors `{entity}_history`,
derived read models `{entity}_search_index`, and the audit trio
(`audit_context`, `audit_log`, `version_metadata`).

## Column layout (stable order across every table)

1. `id uuid PRIMARY KEY DEFAULT gen_random_uuid()` — surrogate key, never exposed as a
   business identifier. (`lifecycle_statuses` is the single BIGINT-identity exception,
   `ADR-008`.)
2. Natural keys and codes (with `UNIQUE` constraints).
3. Business / descriptive columns.
4. Ordering columns (`display_order`, `rank`).
5. Lifecycle column (`status_id bigint NOT NULL`, FK to `lifecycle_statuses(id)`).
6. Governance/versioning column (`version_number integer NOT NULL DEFAULT 1`,
   with `CHECK (version_number > 0)`).
7. Audit columns (`created_at`, `updated_at`, `deleted_at`).

## Enumerations vs. lookup tables (rule)

- PostgreSQL `ENUM` is allowed **only** for internal immutable system state
  (statuses, decisions, tiers, dimensions) that will never be translated,
  governed, or extended. See `docs/04-decisions/ADR-001` and `ADR-007`.
- All governed, translatable, evolving business knowledge is a lookup table
  carrying the governance capability set (UUID PK, unique `citext` `code`,
  `status_id` → `lifecycle_statuses`, `version_number`,
  `created_at`/`updated_at`/`deleted_at`).
- Never duplicate a concept in both forms, and never `ALTER TYPE` to add
  business vocabulary.

## Types

- Identifiers: `uuid` (`gen_random_uuid()`, core since PostgreSQL 13).
- Timestamps: `timestamptz` (never `timestamp` without zone).
- Natural codes: `citext` where case-insensitive matching is correct and desired.
- Multilingual display text: **never** stored on the entity — deferred to the i18n
  translation layer. Lookup tables carry a canonical working `name` in English; display
  translations arrive with the translation milestone.
- Text lengths: no arbitrary `VARCHAR(n)` — use `text` with `CHECK` constraints where a
  bound is meaningful.

## Constraints

- Primary keys are declared inline in `CREATE TABLE` (`schema/02-tables/`).
- Single-table `UNIQUE` and `CHECK` constraints are declared inline in `CREATE TABLE`.
- Cross-table `FOREIGN KEY` constraints are applied in `schema/03-constraints/` via
  `ALTER TABLE`, after all tables exist.
- `ON DELETE RESTRICT` is the default **everywhere**. `ON DELETE CASCADE` is forbidden
  unless an architecture work order explicitly requires it (see `docs/04-decisions/ADR-006`).
- Every `CHECK` expression is documented in a preceding comment. No "magic values".

## Indexes

- Indexes are declared in `schema/04-indexes/`, one statement per index, after tables
  and constraints.
- Every foreign-key column is indexed (PostgreSQL does not index FKs automatically).
- Partial indexes are preferred over full-column indexes when the predicate is stable
  (e.g. `WHERE is_active`).
- `CREATE INDEX CONCURRENTLY` is **not** used inside migrations; migrations run inside
  a transaction. Online index builds are applied out-of-band by the DBA.

## Soft delete and lifecycle

- `deleted_at timestamptz NULL` is the soft-delete marker; physical `DELETE` is rare.
- `status_id bigint NOT NULL REFERENCES lifecycle_statuses(id)` is the authoritative
  lifecycle field on every lookup table: `ACTIVE`, `DEPRECATED`, `ARCHIVED` (`ADR-008`).
  Deprecation replaces deletion; future states are data inserts, never schema changes.
- `status` ENUM columns (e.g. `entity_status`) are reserved for governed entities;
  reference tables use `status_id`.
- `is_active` is never stored on reference tables; a convenience flag, if needed, is a
  computed/view-layer expression derived from `status_id`. Business logic must never
  depend solely on a boolean.

## Formatting

- Two-space indentation, one column or predicate per line in complex statements.
- `CREATE` keywords uppercase; identifiers lowercase.
- Trailing commas never; leading commas never.
- Every file begins with a documentation header (see `docs/03-conventions/` file header
  template below).
- Statement-level comments explain **why**, not **what**.

## File header template

```sql
-- =============================================================================
-- <object/scope> — <short title>
-- -----------------------------------------------------------------------------
-- Purpose:       <why this file exists, one paragraph>
-- Work orders:   <approved architecture work order references>
-- Dependencies:  <objects/folders this file requires to exist first>
-- Migration:     <NNNN_...> (build order)
-- Rationale:     <design decisions a reviewer must know>
-- =============================================================================
```

## Versioning of this document

Changes to these conventions are architecture changes and require an ADR.
