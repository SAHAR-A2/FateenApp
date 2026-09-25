# Database — Entity Inventory

Approved inventory of every SQL object delivered by the Foundation Layer
(extensions, enums, lookup tables), the Mission 02 Foundation Reference Domain,
the Mission 03 canonical core entities, the Mission 04 relationship and junction
tables, the Mission 05 version-history and audit infrastructure, the Mission
07 canonical media & barcode domain, the Mission 08 search layer (derived
read models), and the ECR-001 additive closure of the remaining certification
blockers. All 73 tables are enumerated here.

> **Mission 09 (Database Foundation Finalization) + ECR-001:** this inventory is
> **certified** — every one of the 73 tables is classified in exactly one
> category below (24 lookup + 8 core canonical + 2 media/barcode canonical + 8
> translation + 10 relationship + 13 history + 6 audit + 4 search = 73), every
> derived table resolves to an existing base entity, and every canonical entity
> has immutable history. ECR-001 (migrations `0032`–`0037`) added the new
> category members additively — it removed, renamed, or redesigned nothing. See
> `docs/ecr001_report.md` and `docs/database_certification_report.md`.

## Enumerations (10)

Closed, immutable value sets modeled as PostgreSQL `ENUM` (see `ADR-001` and
`ADR-007` for why these and not more).

| Enum                | Purpose                                                        | Values |
| ------------------- | -------------------------------------------------------------- | ------ |
| `entity_status`     | Published lifecycle of a governed entity                       | draft, active, inactive, deprecated, archived |
| `approval_status`   | State of the governance review/approval workflow               | pending_review, in_review, changes_requested, approved, rejected, cancelled |
| `review_tier`       | Reviewer qualification tier for a change                       | automated, standard, elevated, expert, consensus |
| `review_decision`   | Outcome of one individual review action                        | approved, rejected, changes_requested, escalated |
| `version_status`    | Lifecycle of one version in version history                    | draft, pending_approval, approved, rejected, superseded |
| `confidence_band`   | Discretized confidence derived from `confidence_score`         | very_low, low, medium, high, very_high |
| `translation_status`| Lifecycle of a single translation row                          | draft, in_progress, pending_review, approved, rejected |
| `candidate_status`  | Lifecycle of a candidate record in the population pipeline     | discovered, enriched, normalized, pending_review, approved, merged, discarded |
| `update_type`       | Classification of a change recorded in version history         | created, modified, published, unpublished, deprecated, archived, merged, split |
| `unit_dimension`    | Physical dimension of a unit of measure                        | mass, volume, energy, temperature, count, ratio, amount, other |

## Lookup Tables (24)

Governed reference data (see `ADR-001`, `ADR-007`). Each table: UUID PK (except
`lifecycle_statuses`, the single BIGINT-identity exception, `ADR-008`), unique
`citext` `code`, `status_id` referencing `lifecycle_statuses`,
`version_number`, `created_at`/`updated_at`/`deleted_at`, `set_updated_at()`
trigger, and governed-change comments. Translations (Arabic/English) are
provided by the i18n milestone. The 10 tables after `health_flag_types` were
added by Mission 02 (Foundation Reference Domain, migrations `0008`–`0011`); the
`verification_statuses` row was added by Mission 07 (migrations `0025`–`0029`);
`measurement_bases` was added by ECR-001 (migrations `0032`–`0037`).

| Table                 | Purpose                                                        | FKs |
| --------------------- | -------------------------------------------------------------- | --- |
| `lifecycle_statuses`  | Shared non-destructive lifecycle (ACTIVE/DEPRECATED/ARCHIVED)   | —   |
| `languages`           | Supported platform languages (Arabic + English day one)        | lifecycle_statuses |
| `countries`           | ISO 3166-1 countries, GCC flag                                 | lifecycle_statuses |
| `units`               | Units of measure grouped by `unit_dimension`                   | lifecycle_statuses |
| `package_types`       | Packaging vocabulary (can, bottle, pouch, ...)                 | lifecycle_statuses |
| `barcode_types`       | Barcode symbologies (GTIN-8/12/13/14, GS1-128, QR, DataMatrix) | lifecycle_statuses |
| `image_types`         | Product image categories                                       | lifecycle_statuses |
| `relationship_types`  | Knowledge-graph edge types (directional + inverse pairing)     | lifecycle_statuses, self (inverse_type_id) |
| `source_types`        | Data-source categories                                         | lifecycle_statuses |
| `source_priorities`   | Trust priority scale (rank 1..99)                              | lifecycle_statuses |
| `data_sources`        | Concrete data sources, classified and jurisdiction-scoped      | lifecycle_statuses, source_types, source_priorities, countries |
| `health_flag_types`   | Governed health/risk flag classes (was an ENUM, `ADR-007`)     | lifecycle_statuses |
| `regions`             | Geopolitical regions for market scoping (flat registry)        | lifecycle_statuses |
| `ingredient_categories` | Hierarchical taxonomy of ingredient categories                | lifecycle_statuses, self (parent_id) |
| `product_categories`  | Hierarchical taxonomy of product categories                     | lifecycle_statuses, self (parent_id) |
| `allergen_types`      | Governed allergen classes (gluten, tree_nuts, ...)              | lifecycle_statuses |
| `nutrition_types`     | Governed nutrition fact types (energy, protein, ...)            | lifecycle_statuses |
| `regulatory_authorities` | Regulatory/standards bodies (sfda, efsa, codex, ...)          | lifecycle_statuses |
| `evidence_types`      | Evidence kinds backing governed facts                           | lifecycle_statuses |
| `role_types`          | Platform user roles for access control                          | lifecycle_statuses |
| `permission_types`    | Permission classes assigned to roles                            | lifecycle_statuses |
| `audit_event_types`   | Audit event classes for the future audit trail                  | lifecycle_statuses |
| `verification_statuses` | Barcode verification vocabulary (governed, ordered)           | lifecycle_statuses |
| `measurement_bases`     | Nutrition measurement bases (per_100g, per_serving, per_package, ...) | lifecycle_statuses |

## Core Entities (6)

Primary governed business entities added by Mission 03 (migrations `0012`–`0015`).
Each carries: UUID PK, unique `citext` `internal_code`, `status_id` →
`lifecycle_statuses` (`ADR-008`), `source_id` → `data_sources`,
`confidence_level` numeric `[0,1]` (band derived, `ADR-007`),
`verified_at`/`approved_at`/`deprecated_at`, `version_number`,
`created_by`/`approved_by` (UUID, future auth FK), full audit columns and soft
delete. No `SERIAL` identifiers.

| Table              | Purpose                                                        | FKs |
| ------------------ | -------------------------------------------------------------- | --- |
| `companies`        | Companies (manufacturers, distributors, retailers)             | lifecycle_statuses, data_sources |
| `brands`           | Brands owned by a company                                      | lifecycle_statuses, data_sources, companies |
| `products`         | Products (central catalog entity)                              | lifecycle_statuses, data_sources, brands, product_categories |
| `ingredients`      | Canonical ingredient registry                                  | lifecycle_statuses, data_sources |
| `allergens`        | Specific allergens, classified by allergen type                | lifecycle_statuses, data_sources, allergen_types |
| `health_flags`     | Concrete health/risk flags and claims                          | lifecycle_statuses, data_sources, health_flag_types |

## Canonical Media & Barcode Entities (2)

Canonical entities for the media and barcode domain, added by Mission 07
(migrations `0025`–`0029`). They carry the canonical-entity column set: UUID PK,
natural-key UNIQUE, `status_id` → `lifecycle_statuses` (`ADR-008`), optional
`source_id` → `data_sources`, `version_number`, actor UUIDs (no auth service,
`ADR-005`), full audit columns and soft delete. `barcodes` adds an independent
verification dimension (`verification_status_id` → `verification_statuses`,
Mission 07 lookup): lifecycle answers "should this participate?", verification
answers "can this be trusted?". No stored `is_active` boolean.

| Table | Natural key | Purpose | FKs |
| ----- | ----------- | ------- | --- |
| `images` | `storage_uri`, `content_hash` (both UNIQUE) | Canonical media asset registry | image_types, data_sources, languages, lifecycle_statuses |
| `barcodes` | `barcode` citext (UNIQUE) | Canonical barcode registry | barcode_types, verification_statuses, data_sources, lifecycle_statuses, countries |

`content_hash` is the content fingerprint; the Mission 05 history `checksum`
stays reserved for history-row tamper-evidence (distinct concepts, never
conflated).

## Translation Tables (8)

One per translatable entity (`Mission 03`). Each is keyed by
`UNIQUE ({entity}_id, language_id)`, carries the localized `name`,
`short_name`, `display_name`, `search_name`, `description`, and is governed per
row by `translation_status` (ENUM: draft / in_progress / pending_review /
approved / rejected) with `version_number` and full audit columns. Arabic and
English are supported via `languages`.

| Table | Base entity |
| ----- | ----------- |
| `company_translations` | `companies` |
| `brand_translations` | `brands` |
| `product_translations` | `products` |
| `ingredient_translations` | `ingredients` |
| `allergen_translations` | `allergens` |
| `health_flag_translations` | `health_flags` |
| `nutrition_type_translations` | `nutrition_types` (Mission 02) |
| `product_category_translations` | `product_categories` (Mission 02) |

## Relationship & Junction Tables (10)

Many-to-many and relationship tables added by Mission 04 (migrations
`0016`–`0019`) and, for product↔media, by ECR-001 (migrations `0032`–`0037`).
Every relationship carries the relationship column set:
`relationship_type_id` → `relationship_types` (governed edge vocabulary,
`ADR-007`), `source_id` → `data_sources`, `evidence_type_id` → `evidence_types`,
`confidence_level` numeric `[0,1]`, `effective_from`/`effective_to`,
`verified_at`/`approved_at`, `status_id` → `lifecycle_statuses` (`ADR-008`),
`version_number`, full audit columns and soft delete. No cascade anywhere
(`ADR-006`). `entity_relationships` is the polymorphic knowledge-graph edge table:
its `subject_id`/`object_id` endpoints are UUIDs typed by
`subject_entity_type`/`object_entity_type` (CHECK-constrained to the canonical core
entities) and carry no FK; since ECR-001 a `validate_entity_relationship_endpoints()`
trigger rejects any edge whose subject or object does not exist in its declared
entity table (database-level validation, no redesign).

| Table | Endpoints | Notes |
| ----- | --------- | ----- |
| `product_ingredients` | `products` × `ingredients` | optional `amount_value` + `unit_id` |
| `product_allergens` | `products` × `allergens` | `relationship_type` = declared vs. precautionary |
| `product_nutrition_values` | `products` × `nutrition_types` | `amount_value` + `unit_id` NOT NULL; optional `measurement_basis_id` → `measurement_bases` (ECR-001) |
| `product_health_flags` | `products` × `health_flags` | claims, warnings, risks |
| `ingredient_allergens` | `ingredients` × `allergens` | declared vs. precautionary |
| `ingredient_health_flags` | `ingredients` × `health_flags` | claims, warnings, risks |
| `ingredient_aliases` | `ingredients` (+ `languages`) | `alias` text, optional `language_id` |
| `entity_relationships` | any core entity × any core entity | polymorphic knowledge-graph edges (endpoints validated by trigger) |
| `product_images` | `products` × `images` | many images per product via relationship types (ECR-001) |
| `product_barcodes` | `products` × `barcodes` | many barcodes per product via relationship types (ECR-001) |

## History Tables (13)

Immutable version-history for every canonical entity, added by Mission 05
(migrations `0020`–`0024`) for the core entities, by Mission 07 (migrations
`0026`, `0028`, `0029`) for `images` and `barcodes`, and by ECR-001 (migration
`0033`) for `product_images` and `product_barcodes`. Each history row is
**INSERT-only** (enforced by a `prevent_history_mutation()` trigger, migrations
`0024`/`0029`/`0037`), keyed by `UNIQUE (original_entity_id, version_number)`, and
carries the full version column set: `previous_version_id` (self-FK),
`change_set_id` → `change_sets`, `change_type` (`update_type` ENUM),
`change_reason`, `changed_by`/`approved_by` (UUID, no auth service yet),
`source_id` → `data_sources`, `confidence_level`,
`created_at`, `effective_from`/`effective_to`/`superseded_at`,
`snapshot_hash`/`checksum`, and `version_status` (`version_status` ENUM), plus a
complete snapshot of the entity's business/lifecycle columns. As immutable rows
they deliberately carry no `updated_at`/`deleted_at` (deviation called out in
each file header per `sql_conventions.md`).

Since ECR-01 (migration `0037`) the `capture_entity_history()` trigger function
**automatically** records a snapshot on INSERT and on material UPDATE of every
history-owning table (13 triggers): history is always populated, version chains
are preserved, duplicate no-op snapshots are skipped, and the immutability
guards still reject UPDATE/DELETE of history rows.

| Table | Snapshot source | FKs |
| ----- | --------------- | --- |
| `companies_history` | `companies` | companies, data_sources, lifecycle_statuses, change_sets, self (previous_version_id) |
| `brands_history` | `brands` | brands, companies, data_sources, lifecycle_statuses, change_sets, self |
| `products_history` | `products` | products, brands, product_categories, data_sources, lifecycle_statuses, change_sets, self |
| `ingredients_history` | `ingredients` | ingredients, data_sources, lifecycle_statuses, change_sets, self |
| `allergens_history` | `allergens` | allergens, allergen_types, data_sources, lifecycle_statuses, change_sets, self |
| `health_flags_history` | `health_flags` | health_flags, health_flag_types, data_sources, lifecycle_statuses, change_sets, self |
| `nutrition_types_history` | `nutrition_types` | nutrition_types, data_sources, lifecycle_statuses, change_sets, self |
| `product_categories_history` | `product_categories` | product_categories, data_sources, lifecycle_statuses, change_sets, self |
| `ingredient_categories_history` | `ingredient_categories` | ingredient_categories, data_sources, lifecycle_statuses, change_sets, self |
| `images_history` | `images` | images, image_types, languages, data_sources, lifecycle_statuses, change_sets, self |
| `barcodes_history` | `barcodes` | barcodes, barcode_types, verification_statuses, countries, data_sources, lifecycle_statuses, change_sets, self |
| `product_images_history` | `product_images` | product_images, images, products, relationship_types, data_sources, evidence_types, lifecycle_statuses, change_sets, self |
| `product_barcodes_history` | `product_barcodes` | product_barcodes, barcodes, products, relationship_types, data_sources, evidence_types, lifecycle_statuses, change_sets, self |

## Audit & Version Infrastructure (6)

Generic audit/version layer added by Mission 05 (migration `0021`, constraints
`0022`). These are operational infrastructure, not governed entities: they carry
the standard audit trio and `set_updated_at()` triggers but no `status_id` or
`version_number` (except `entity_versions`, which registers version numbers).

| Table | Purpose | FKs |
| ----- | ------- | --- |
| `audit_context` | Per-operation context: actor, role, source, IP, user-agent, correlation/transaction pair | role_types |
| `change_sets` | Groups the versions written by one logical change | audit_context (composite) |
| `audit_log` | Append-only event feed with the full audit-event field set (actor, action, entity, versions, context) | change_sets, audit_event_types, role_types |
| `audit_events` | Normalized per-version event details under a feed entry | audit_log, audit_event_types |
| `entity_versions` | Generic registry of every version across all history tables (polymorphic pointer) | change_sets, self (previous_version_id) |
| `version_metadata` | Key/value extension attributes per version registry entry | entity_versions |

## Search Layer (4) — derived read models

Rebuildable search indexes added by Mission 08 (migrations `0030`–`0031`).
**Derived read models, not canonical data**: canonical entities remain the single
source of truth. Each carries the canonical entity identifier as a **logical
reference only — no foreign key** (`UNIQUE ({entity}_id)`, one row per entity,
idempotent rebuilds), normalized searchable text (`search_name`, `search_text`),
language-independent `search_tokens text[]`, `language_codes citext[]`, a
`search_rank numeric >= 0` helper, and `generated_at`. By design they carry **no**
`status_id`, `version_number`, audit trio, or `is_active` — no duplicated
governance/lifecycle state, no triggers, no synchronization. Search-only indexes
use `pg_trgm` GIN (approved in `ADR-003`).

| Table | Logical reference (no FK) | Derived from |
| ----- | ------------------------- | ------------ |
| `product_search_index` | `product_id` | `products`, `product_translations`, `product_categories`, `brands` |
| `ingredient_search_index` | `ingredient_id` | `ingredients`, `ingredient_translations`, `ingredient_aliases` |
| `brand_search_index` | `brand_id` | `brands`, `brand_translations`, `companies` |
| `company_search_index` | `company_id` | `companies`, `company_translations`, `countries` |

## Governance enablers

- `source_id` + `confidence_score` semantics: `data_sources` is the registry that
  future fact tables will FK to.
- Versioning vocabulary: `version_status` + `update_type` + `approval_status` +
  `review_tier` + `review_decision` are the shared types the version-history and
  review milestones will use without new enums. Mission 05 wired `version_status`
  and `update_type` into the history tables (`change_type`) and the
  `entity_versions` registry.
- Audit context: `audit_context` / `change_sets` / `audit_log` / `audit_events`
  provide the per-operation, per-change, and per-version audit trail; history
  rows link to their logical change via `change_set_id`.
- Non-destructive lifecycle: `deleted_at` soft delete, `status_id` lifecycle
  (`lifecycle_statuses`: ACTIVE/DEPRECATED/ARCHIVED, `ADR-008`),
  `ON DELETE RESTRICT` everywhere (`ADR-006`).
- Search: the four `*_search_index` derived read models (Mission 08) are
  rebuildable from canonical entities; they own performance while canonical data
  owns integrity (`pg_trgm`, `ADR-003`).
