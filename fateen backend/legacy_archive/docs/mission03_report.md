# Mission 03 — Canonical Core Entities: Report

**Status:** DELIVERED (static-verified, 26/26 validation PASS; live apply pending a
PostgreSQL environment)

**Deliverable mapping:** The mission prompt requested `database/migrations/003_core_entities.sql`.
Per `ADR-004` (migrations are generated from `schema/`, never hand-written) and the
Foundation/Mission 02 decomposition pattern, Mission 03 ships as four generated,
immutable migrations:

| Migration file | Contents |
| -------------- | -------- |
| `migrations/0012_core_entity_tables.sql` | 14 `CREATE TABLE` statements |
| `migrations/0013_core_entity_constraints.sql` | 33 foreign keys |
| `migrations/0014_core_entity_indexes.sql` | 27 correctness-critical indexes |
| `migrations/0015_core_entity_triggers.sql` | 14 `set_updated_at()` triggers |

## 1. Tables created

New canonical core entities (6) and translation tables (8) = **14 tables** total.
`nutrition_types` and `product_categories` were already delivered by Mission 02 as
governed lookup tables (`ADR-008`) and are **not recreated**; Mission 03 adds their
translation tables only.

| Table | Type | Base entity | Notes |
| ----- | ---- | ----------- | ----- |
| `companies` | core entity | — | manufacturer/distributor/retailer registry |
| `company_translations` | translation | `companies` | |
| `brands` | core entity | `companies` (FK `company_id`) | a brand belongs to exactly one company |
| `brand_translations` | translation | `brands` | |
| `products` | core entity | `brands` (FK `brand_id`, nullable), `product_categories` (FK, nullable) | |
| `product_translations` | translation | `products` | |
| `ingredients` | core entity | — | canonical ingredient registry |
| `ingredient_translations` | translation | `ingredients` | |
| `allergens` | core entity | `allergen_types` (FK, nullable) | |
| `allergen_translations` | translation | `allergens` | |
| `health_flags` | core entity | `health_flag_types` (FK, nullable) | |
| `health_flag_translations` | translation | `health_flags` | |
| `nutrition_type_translations` | translation | `nutrition_types` (Mission 02) | base table not modified |
| `product_category_translations` | translation | `product_categories` (Mission 02) | base table not modified |

### Canonical core-entity column set (companies, brands, products, ingredients, allergens, health_flags)

`id uuid PK DEFAULT gen_random_uuid()` · `internal_code citext UNIQUE` · `name text`
· `description text NULL` · `status_id bigint NOT NULL` (→ `lifecycle_statuses`,
`ADR-008`) · `source_id uuid NULL` (→ `data_sources`) · `confidence_level numeric
NOT NULL DEFAULT 0.5` (CHECK 0..1) · `verified_at` · `approved_at` ·
`deprecated_at` · `version_number integer NOT NULL DEFAULT 1` (CHECK > 0) ·
`created_by uuid NULL` · `approved_by uuid NULL` · `created_at` · `updated_at` ·
`deleted_at`.

No `SERIAL` identifiers anywhere. `confidence_band` (ENUM) is derived from
`confidence_level` and never stored (`ADR-007`).

### Translation-table column set (all 8)

`id uuid PK` · `{entity}_id uuid NOT NULL` (→ base entity) · `language_id uuid NOT
NULL` (→ `languages`) · `name` · `short_name NULL` · `display_name` ·
`search_name NULL` · `description NULL` · `translation_status` (`translation_status`
ENUM, default `draft`) · `version_number` · `created_at` · `updated_at` ·
`deleted_at` · `UNIQUE ({entity}_id, language_id)`.

Arabic and English are supported from day one via the `languages` registry; no
language-specific columns exist in any canonical table.

## 2. Translation tables

Dedicated translation table per translatable entity (8 total), each enforcing one
translation per entity per language via `UNIQUE ({entity}_id, language_id)`.
Translation quality is governed per row by `translation_status`
(`draft / in_progress / pending_review / approved / rejected`).

## 3. Constraints

- `UNIQUE (internal_code)` on all 6 core entities.
- `UNIQUE ({entity}_id, language_id)` on all 8 translation tables.
- `CHECK (version_number > 0)` on all 14 tables.
- `CHECK (confidence_level >= 0 AND confidence_level <= 1)` on all 6 core entities.
- `translation_status` ENUM-typed column with default `'draft'` on all 8 translation tables.

## 4. Foreign keys (33 total, all `ON DELETE/UPDATE RESTRICT`)

| FK column | References | Nullable |
| --------- | ---------- | -------- |
| `companies.status_id` | `lifecycle_statuses(id)` | no |
| `companies.source_id` | `data_sources(id)` | yes |
| `brands.status_id` / `source_id` | `lifecycle_statuses` / `data_sources` | no / yes |
| `brands.company_id` | `companies(id)` | no |
| `products.status_id` / `source_id` | `lifecycle_statuses` / `data_sources` | no / yes |
| `products.brand_id` | `brands(id)` | yes |
| `products.product_category_id` | `product_categories(id)` | yes |
| `ingredients.status_id` / `source_id` | `lifecycle_statuses` / `data_sources` | no / yes |
| `allergens.status_id` / `source_id` | `lifecycle_statuses` / `data_sources` | no / yes |
| `allergens.allergen_type_id` | `allergen_types(id)` | yes |
| `health_flags.status_id` / `source_id` | `lifecycle_statuses` / `data_sources` | no / yes |
| `health_flags.health_flag_type_id` | `health_flag_types(id)` | yes |
| 8× `{table}.{entity}_id` | the owning base entity | no |
| 8× `{table}.language_id` | `languages(id)` | no |

No cascading deletes anywhere (`ADR-006`).

## 5. Indexes (correctness-critical only)

27 indexes, all FK-supporting (`status_id`/`source_id` per core entity, hierarchy
FKs, and every translation `{entity}_id`/`language_id`). UNIQUE constraints provide
their own indexes for `internal_code` and `(entity_id, language_id)`. No
performance/search indexes created.

## 6. Assumptions

1. **`internal_code`** is the canonical machine key for core entities (unique
   `citext`), matching the mission's naming; lookup tables keep `code` (Mission 02).
2. **`created_by` / `approved_by`** are nullable UUID columns with **no FK**: the
   `users`/auth table does not exist yet. This is consistent with `ADR-005` ("actor
   columns apply to governed entities" and arrive with the auth milestone).
3. **`confidence_level`** is the stored numeric in `[0,1]`; `confidence_band`
   (ENUM) is derived and never stored (`ADR-007`). The ERD doc uses
   "`confidence_score`" for this concept — see Open questions.
4. **Hierarchy FK nullability:** `brands.company_id` is NOT NULL (a brand is owned
   by a company); `products.brand_id` and `products.product_category_id` are NULL
   (unbranded / unclassified products are legitimate).
5. **Type classification FKs** (`allergens.allergen_type_id`,
   `health_flags.health_flag_type_id`) are nullable because a type is not always
   assigned at creation.
6. **`nutrition_types` / `product_categories`** are the Mission 02 lookup tables;
   Mission 03 adds translation tables and does not alter the base tables.
7. **Translation tables carry `translation_status`, not `status_id`** (they are not
   lookup tables; `ADR-008` governs lookup tables).

## 7. Open questions

1. **Column naming:** mission says `confidence_level`; the ERD doc
   (`docs/02-erd/foundation-dependency-graph.md`) says facts carry a numeric
   `confidence_score` with derived `confidence_band`. Recommend confirming whether
   the canonical fact column is `confidence_score` or `confidence_level` before the
   fact tables (nutrition/ingredient facts) are built.
2. **Product→company:** products reference companies only transitively via brands.
   If unbranded/private-label products must scope directly to a company, an
   explicit `products.company_id` FK would be needed (normalization currently
   rejects the redundancy).
3. **Translation `search_name`:** included as a nullable normalized-search variant
   per the mission's column list. Its exact population rule (transliteration,
   normalization) is a search-milestone decision.
4. **Live apply:** no PostgreSQL is available in this environment; migrations
   `0012`–`0015` must be executed in CI/review to confirm execution (static
   validation is 26/26 PASS). Apply with:
   `powershell -ExecutionPolicy Bypass -File scripts/migrate.ps1 -Database fateen`.

## 8. Non-goals (explicitly not built, per mission scope)

No collections, APIs, OCR, search, governance workflows, AI, or business logic.
No junction/relationship tables (product↔ingredient, product↔health flag,
ingredient↔allergen), no nutrition fact tables, no barcode tables, no version
history — these are later missions.
