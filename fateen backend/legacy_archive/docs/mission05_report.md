# Mission 05 — Version History & Audit Infrastructure: Report

**Status:** DELIVERED (static-verified, 34/34 validation PASS; live apply pending a
PostgreSQL environment)

**Deliverable mapping:** The mission prompt requested version-history tables for
every canonical entity plus generic audit/version tables, an immutable strategy,
and migrations. Per `ADR-004` (migrations are generated from `schema/`, never
hand-written) and the established decomposition pattern, Mission 05 ships as five
generated, immutable migrations:

| Migration file | Contents |
| -------------- | -------- |
| `migrations/0020_history_tables.sql` | 9 `CREATE TABLE` history statements |
| `migrations/0021_audit_tables.sql` | 6 `CREATE TABLE` audit/version statements |
| `migrations/0022_history_constraints.sql` | 62 foreign keys |
| `migrations/0023_history_indexes.sql` | 62 correctness-critical indexes |
| `migrations/0024_history_triggers.sql` | guard function + 9 immutability triggers + 6 `set_updated_at()` triggers |

## 1. Deliverable inventory

### 1.1 History tables (9)

Immutable version-history for every canonical entity. One row per published
version, INSERT-only (enforced by `prevent_history_mutation()` triggers in 0024),
keyed by `UNIQUE (original_entity_id, version_number)`.

| Table | Snapshot source |
| ----- | --------------- |
| `companies_history` | `companies` |
| `brands_history` | `brands` |
| `products_history` | `products` |
| `ingredients_history` | `ingredients` |
| `allergens_history` | `allergens` |
| `health_flags_history` | `health_flags` |
| `nutrition_types_history` | `nutrition_types` |
| `product_categories_history` | `product_categories` |
| `ingredient_categories_history` | `ingredient_categories` |

### 1.2 History column set (every table)

`id uuid PK` · `original_entity_id uuid NOT NULL` (→ the owning canonical entity) ·
`version_number integer NOT NULL` (CHECK > 0) · `previous_version_id uuid NULL`
(self-FK) · `change_set_id uuid NULL` (→ `change_sets`) ·
`change_type update_type NOT NULL` · `change_reason text NULL` ·
`changed_by uuid NULL` / `approved_by uuid NULL` (auth service not yet built) ·
`source_id uuid NULL` (→ `data_sources`) · `confidence_level numeric NOT NULL
DEFAULT 0.5` (CHECK 0..1) · the full business/lifecycle snapshot (all canonical
columns) · `status_id bigint NOT NULL` (→ `lifecycle_statuses`, `ADR-008`) ·
`created_at` · `effective_from` · `effective_to` · `superseded_at` ·
`snapshot_hash text NOT NULL` · `checksum text NOT NULL` ·
`version_status version_status NOT NULL DEFAULT 'draft'`.

The snapshot deliberately **excludes** `id` (mapped to `original_entity_id`),
`version_number` (this table's version_number), `created_by`/`approved_by`
(mapped to `changed_by`/`approved_by`), `source_id` and `confidence_level`
(carried by the history header), and `created_at`/`updated_at` (the row's own
`created_at` plus the effective window cover temporal provenance). No field is
duplicated between snapshot and header (no-duplication rule). As immutable rows
they carry **no** `updated_at`/`deleted_at` — the standard audit trio is
intentionally not followed (declared deviation in every history file header;
`sql_conventions.md`).

### 1.3 Audit & version tables (6)

| Table | Purpose | Key constraints |
| ----- | ------- | --------------- |
| `audit_context` | Per-operation context: actor, role, source, IP, user-agent, correlation/transaction pair | `UNIQUE (correlation_id, transaction_id)`; `role_id` → `role_types` |
| `change_sets` | Groups the version records written by one logical change | composite FK `(correlation_id, transaction_id)` → `audit_context` |
| `audit_log` | Append-only, self-contained event feed (full mission field set) | `change_set_id` → `change_sets`, `event_type_id` → `audit_event_types`, `role_id` → `role_types` |
| `audit_events` | Normalized per-version event details (one row per version actually written) | `audit_log_id` → `audit_log`, `event_type_id` → `audit_event_types` |
| `entity_versions` | Generic registry of every published version across all history tables | `UNIQUE (entity_type, entity_id, version_number)`; `change_set_id` → `change_sets`; self-FK `previous_version_id` |
| `version_metadata` | Key/value extension attributes per registry entry | `UNIQUE (entity_version_id, key)`; FK → `entity_versions` |

### 1.4 Mission field mapping

`action` → `event_type_id` (→ `audit_event_types`), `entity` → `entity_type`
(text discriminator), `entity_id` → `entity_id`, `timestamp` → `logged_at` /
`event_time`, `role` → `role_id`, IP / user-agent → `ip_address inet` /
`user_agent text` (nullable placeholders), `previous_version` / `new_version` →
version-number transition columns, `correlation_id` / `transaction_id` shared
across `audit_context`, `change_sets` and `audit_log`. `actor` / `changed_by` /
`approved_by` are NULL-able UUIDs with no FK until an auth service exists
(`ADR-005` precedent).

## 2. Dependency diagram

```mermaid
graph LR
    subgraph Audit chain (0021)
        AC[audit_context] --- CS[change_sets]
        CS --- ALOG[audit_log]
        ALOG --- AEV[audit_events]
    end
    subgraph Version registry (0021)
        EV[entity_versions] --- VM[version_metadata]
    end
    subgraph Vocabulary (0003/0008)
        RT[role_types]
        AET[audit_event_types]
        DS[data_sources]
        LS[lifecycle_statuses]
    end
    subgraph History (0020)
        COH[companies_history]
        BRH[brands_history]
        PRH[products_history]
        INH[ingredients_history]
        ALH[allergens_history]
        HFH[health_flags_history]
        NTH[nutrition_types_history]
        PCH[product_categories_history]
        ICH[ingredient_categories_history]
    end
    AC --- RT
    ALOG --- AET
    ALOG --- RT
    EV --- CS
    CS --- AC
    COH --- DS; COH --- LS; COH --- CS
    BRH --- DS; BRH --- LS; BRH --- CS
    PRH --- DS; PRH --- LS; PRH --- CS
    INH --- DS; INH --- LS; INH --- CS
    ALH --- DS; ALH --- LS; ALH --- CS
    HFH --- DS; HFH --- LS; HFH --- CS
    NTH --- DS; NTH --- LS; NTH --- CS
    PCH --- DS; PCH --- LS; PCH --- CS
    ICH --- DS; ICH --- LS; ICH --- CS
    EV --- CS
```

- History tables depend on their canonical entity, `data_sources`,
  `lifecycle_statuses`, and `change_sets`, plus their own self-reference
  (`previous_version_id`). No other table depends on a history table.
- The audit tables form a strict chain `audit_context → change_sets → audit_log →
  audit_events` and the parallel registry `entity_versions → version_metadata`; no
  cycles exist.

## 3. Foreign-key matrix (62 FKs, all `ON DELETE/UPDATE RESTRICT`)

History (52): every history table carries
`original_entity_id` (→ owning entity), `previous_version_id` (self),
`source_id` (→ `data_sources`), `status_id` (→ `lifecycle_statuses`), and
`change_set_id` (→ `change_sets`); plus the snapshot FKs mirrored from the
canonical entity:

| Referencing table | Extra snapshot FK columns | References |
| ----------------- | ------------------------- | ---------- |
| `brands_history` | `company_id` | `companies(id)` |
| `products_history` | `brand_id`, `product_category_id` | `brands(id)`, `product_categories(id)` |
| `allergens_history` | `allergen_type_id` | `allergen_types(id)` |
| `health_flags_history` | `health_flag_type_id` | `health_flag_types(id)` |
| `product_categories_history` | `parent_id` | `product_categories(id)` |
| `ingredient_categories_history` | `parent_id` | `ingredient_categories(id)` |

Audit (10):

| Referencing table | FK column(s) | References |
| ----------------- | ------------ | ---------- |
| `audit_context` | `role_id` | `role_types(id)` |
| `change_sets` | `(correlation_id, transaction_id)` | `audit_context(correlation_id, transaction_id)` — composite |
| `audit_log` | `change_set_id`, `event_type_id`, `role_id` | `change_sets`, `audit_event_types`, `role_types` |
| `audit_events` | `audit_log_id`, `event_type_id` | `audit_log`, `audit_event_types` |
| `entity_versions` | `change_set_id`, `previous_version_id` | `change_sets(id)`, `entity_versions(id)` (self) |
| `version_metadata` | `entity_version_id` | `entity_versions(id)` |

All FKs use `ON DELETE RESTRICT` / `ON UPDATE RESTRICT` (`ADR-006`). No cascade
anywhere. `entity_versions.{history_table, history_row_id}` and the audit
`entity_type`/`entity_id` discriminators carry **no** FK — the target is
polymorphic across several history tables (see Assumptions 5).

## 4. Constraint summary

- **UNIQUE (composite):** `(original_entity_id, version_number)` on all 9 history
  tables (one row per entity version) · `(correlation_id, transaction_id)` on
  `audit_context` · `(entity_type, entity_id, version_number)` on
  `entity_versions` · `(entity_version_id, key)` on `version_metadata`.
- **CHECK:** `version_number > 0` (9 history + `entity_versions`) ·
  `confidence_level BETWEEN 0 AND 1` (9 history) ·
  `effective_to >= effective_from` when both set (9 history) ·
  `history_table <> ''` (`entity_versions`).
- **FKs:** 62, all `ON DELETE/UPDATE RESTRICT` (`ADR-006`). No cascade.
- **Status:** `status_id bigint NOT NULL` → `lifecycle_statuses` (`ADR-008`)
  authoritative lifecycle on every history table; snapshot `deleted_at` captured
  as business state.

## 5. Immutable strategy

History rows are INSERT-only by design and enforced at the storage layer:

- `prevent_history_mutation()` (`schema/06-functions/02`, migration 0024) raises
  an exception on any `UPDATE` or `DELETE`.
- One `BEFORE UPDATE OR DELETE ... FOR EACH ROW` trigger per history table
  (`schema/07-triggers/05`, 9 triggers).
- `previous_version_id` chains (self-FK, RESTRICT) and `version_status`
  (`draft → pending_approval → approved → superseded`) model version lifecycle;
  `superseded_at` marks replacement; `snapshot_hash`/`checksum` support tamper
  evidence.
- The 6 audit tables carry `set_updated_at()` triggers
  (`schema/07-triggers/06`) for their mutable operational columns.

## 6. Indexes created (correctness-critical only)

62 indexes — one per FK column on every history and audit table
(`original_entity_id`, `previous_version_id`, `source_id`, `status_id`,
`change_set_id` on all 9 history tables; snapshot FK columns where present;
`role_id`, `event_type_id`, `change_set_id`, `audit_log_id`, `entity_version_id`,
and the composite `(correlation_id, transaction_id)` on the audit tables).
PostgreSQL does not index FK columns automatically, so these are required for
referential-integrity enforcement. UNIQUE constraints provide their own indexes
(not duplicated). Polymorphic discriminators (`history_table`/`history_row_id`,
audit `entity_type`/`entity_id`) have no FK and are not indexed. No
performance/search indexes created.

## 7. Assumptions

1. **`categories_history` was delivered as two tables.** The work order asked for
   one history table for "categories"; the canonical schema (Mission 02) has two
   distinct category tables (`product_categories`, `ingredient_categories`) with
   different columns. A single polymorphic table would have violated the
   mandated per-entity history column set, so Mission 05 ships
   `product_categories_history` and `ingredient_categories_history`, each
   mirroring its own source. (Open question 1.)
2. **`audit_log` is the self-contained narrative feed and `audit_events` the
   normalized details.** The mission listed the audit field set per event; the
   design stores the full field set in `audit_log` (readable without joins,
   repeating actor/role/source/IP/UA per change — a deliberate, documented
   denormalization) and one normalized row per version actually written in
   `audit_events`, so a merge/split/bulk change expands into several events under
   one feed entry. (Open question 2.)
3. **Actor columns are NULL-able UUIDs with no FK** (`changed_by`, `approved_by`,
   `audit_log.actor`, `audit_context.actor`). The auth/identity service does not
   exist yet; adding an FK would require inventing a principals table or service
   (same ruling as `ADR-005`).
4. **IP / user-agent are nullable placeholders.** `ip_address inet` and
   `user_agent text` are stored but optional; filling them is the application
   layer's responsibility.
5. **Polymorphic references carry no FK.** `entity_versions.history_table` /
   `history_row_id` and the audit `entity_type`/`entity_id` discriminators point
   at one of several history tables. A single FK cannot reference multiple
   tables; this is the same pattern already approved for
   `entity_relationships.subject_id`/`object_id`. Existence is enforced by the
   application layer (a trigger-based validator is deferred).
6. **`change_type` reuses the existing `update_type` ENUM** (0002) and
   `version_status` reuses the existing `version_status` ENUM (0002) — no new
   enum types were created (`ADR-007`).
7. **History snapshots omit `created_at`/`updated_at`** of the canonical row
   (covered by the history row's own `created_at` and the effective window) and
   the identity/audit columns mapped to the header — no field duplicated between
   snapshot and header.

## 8. Unresolved questions

1. **`categories_history` split** — confirm `product_categories_history` +
   `ingredient_categories_history` is acceptable instead of a single
   "categories" history table. **Decision needed.**
2. **`audit_log` / `audit_events` split** — confirm the denormalized-feed +
   normalized-details design satisfies the mission's "audit event fields" list.
   **Decision needed.**
3. **Authz on history/audit writes** — only UPDATE/DELETE is blocked on history
   tables; nothing prevents an unauthorized INSERT of a history/audit row. Access
   control is deferred to the application/service layer (and future
   `auth_principals`).
4. **`entity_versions` endpoint integrity** — `history_table`/`history_row_id`
   existence is not enforced by a database trigger yet (same open question as
   `entity_relationships` in Mission 04). Options: keep application-layer
   enforcement, or add a trigger in the population milestone.
5. **Live apply** — no PostgreSQL is available in this environment; migrations
   `0020`–`0024` must be executed in CI/review to confirm execution (static
   validation is 34/34 PASS). Apply with:
   `powershell -ExecutionPolicy Bypass -File scripts/migrate.ps1 -Database fateen`.

## 9. Non-goals (explicitly not built, per mission scope)

No business logic, APIs, governance workflows, or population. No performance
indexes, no per-entity audit trigger generation, no `auth_principals`/identity
service, no fact-basis vocabulary. Version-history and audit DDL only.
