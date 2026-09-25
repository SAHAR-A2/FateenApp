# Fateen Database Schema Documentation

**Database:** PostgreSQL 17.10  
**Schema:** `public`  
**Tables:** 85 | **Migrations:** 40 applied | **Custom Types:** 10 enums  
**Extensions:** `plpgsql`, `pgcrypto`, `citext`, `pg_trgm`

---

## Table of Contents

1. [Extensions & Custom Types](#1-extensions--custom-types)
2. [Lookup / Reference Tables](#2-lookup--reference-tables)
3. [Core Entity Tables](#3-core-entity-tables)
4. [Relationship / Junction Tables](#4-relationship--junction-tables)
5. [Translation Tables](#5-translation-tables)
6. [Barcodes & Data Sources](#6-barcodes--data-sources)
7. [Search Indexes](#7-search-indexes)
8. [History & Audit Tables](#8-history--audit-tables)
9. [Collector Tables](#9-collector-tables)
10. [Triggers & Functions](#10-triggers--functions)
11. [Entity Relationship Diagram](#11-entity-relationship-diagram)
12. [Seeded Data Reference](#12-seeded-data-reference)

---

## 1. Extensions & Custom Types

### PostgreSQL Extensions

| Extension  | Purpose |
|-----------|---------|
| `plpgsql` | Procedural language for triggers and functions |
| `pgcrypto` | Cryptographic functions (`gen_random_uuid()`) |
| `citext`  | Case-insensitive text type for codes and barcodes |
| `pg_trgm` | Trigram indexing for fuzzy search support |

### Custom Enum Types

| Enum Type | Values | Count |
|-----------|--------|-------|
| `approval_status` | PENDING, APPROVED, REJECTED, REVISION_REQUIRED, ESCALATED, WITHDRAWN | 6 |
| `candidate_status` | NEW, MATCHED, IMPORTED, DISMISSED, DUPLICATE, UNDER_REVIEW, RESOLVED | 7 |
| `confidence_band` | LOW, MEDIUM, HIGH, VERY_HIGH, UNCERTAIN | 5 |
| `entity_status` | ACTIVE, INACTIVE, DRAFT, ARCHIVED, DELETED | 5 |
| `review_decision` | APPROVE, REJECT, REQUEST_CHANGES, ESCALATE | 4 |
| `review_tier` | AUTO, BASIC, STANDARD, PREMIUM, EXPERT | 5 |
| `translation_status` | DRAFT, PENDING_REVIEW, APPROVED, PUBLISHED, DEPRECATED | 5 |
| `unit_dimension` | MASS, VOLUME, LENGTH, TEMPERATURE, ENERGY, COUNT, PERCENTAGE, DENSITY | 8 |
| `update_type` | CREATE, UPDATE, DELETE, RESTORE, MERGE, SPLIT, RECLASSIFY, RECONCILE | 8 |
| `version_status` | DRAFT, CURRENT, SUPERSEDED, ARCHIVED, DELETED | 5 |

---

## 2. Lookup / Reference Tables

Seeded reference data with no foreign keys to core entities.

### `lifecycle_statuses`

> **PK:** `id` (bigint, auto-increment) — *Only table using a sequence (`lifecycle_statuses_id_seq`).*

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | bigint | PK | Auto-increment identifier |
| `code` | text | UNIQUE, NOT NULL | Machine-readable code |
| `name` | text | NOT NULL | Display name |
| `description` | text | | Human-readable description |
| `display_order` | integer | NOT NULL, DEFAULT 0 | Sort order |
| `is_active` | boolean | NOT NULL, DEFAULT true | Whether status is in use |

### `source_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |

### `source_priorities`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `priority_level` | integer | NOT NULL |
| `description` | text | |

### `verification_statuses`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `description` | text | |
| `display_order` | integer | NOT NULL, DEFAULT 0 |

### `evidence_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `description` | text | |
| `display_order` | integer | NOT NULL, DEFAULT 0 |

### `relationship_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `description` | text | |
| `is_directional` | boolean | NOT NULL, DEFAULT false |
| `inverse_type_id` | uuid | FK → relationship_types(id) (self-referential) |
| `display_order` | integer | NOT NULL, DEFAULT 0 |

### `nutrition_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `description` | text | |
| `default_unit` | text | |
| `display_order` | integer | NOT NULL, DEFAULT 0 |

### `measurement_bases`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `description` | text | |
| `display_order` | integer | NOT NULL, DEFAULT 0 |

### `units`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `symbol` | text | |
| `dimension` | unit_dimension | NOT NULL (enum) |
| `display_order` | integer | NOT NULL, DEFAULT 0 |

### `health_conditions`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `description` | text | |
| `is_active` | boolean | NOT NULL, DEFAULT true |

---

## 3. Core Entity Tables

All core entities share common columns:

| Common Column | Type | Notes |
|---------------|------|-------|
| `id` | uuid | PK, DEFAULT gen_random_uuid() |
| `status_id` | bigint | FK → lifecycle_statuses(id) |
| `version_number` | integer | NOT NULL, DEFAULT 1 |
| `created_at` | timestamptz | NOT NULL, DEFAULT now() |
| `updated_at` | timestamptz | NOT NULL, auto-updated by trigger |
| `deleted_at` | timestamptz | Nullable, soft-delete marker |

### `companies`

> 10 seeded companies. Central entity for product discovery and scanning.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `internal_code` | citext | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `description` | text | |
| `slug` | text | |
| `priority` | text | |
| `priority_score` | numeric | |
| `expected_product_count` | integer | |
| `discovered_count` | integer | |
| `verified_count` | integer | |
| `failed_count` | integer | |
| `conflict_count` | integer | |
| `missing_data_count` | integer | |
| `barcode_coverage_pct` | numeric | |
| `ingredient_coverage_pct` | numeric | |
| `allergen_coverage_pct` | numeric | |
| `nutrition_coverage_pct` | numeric | |
| `evidence_coverage_pct` | numeric | |
| `scan_status` | text | |
| `country` | text | |
| `market` | text | |
| `last_scan_at` | timestamptz | |
| `next_scan_at` | timestamptz | |
| `metadata` | jsonb | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `brands`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `company_id` | uuid | FK → companies(id) |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `product_categories`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `parent_id` | uuid | FK → product_categories(id) (self-referential) |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `products`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `brand_id` | uuid | FK → brands(id) |
| `product_category_id` | uuid | FK → product_categories(id) |
| `internal_code` | citext | |
| `name` | text | NOT NULL |
| `description` | text | |
| `serving_size` | text | |
| `serving_size_unit` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `ingredients`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `allergens`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `allergen_type_id` | uuid | FK → allergen_types(id) |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `health_flag_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `health_flags`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `health_flag_type_id` | uuid | FK → health_flag_types(id) |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `ingredient_categories`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `parent_id` | uuid | FK → ingredient_categories(id) (self-referential) |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `barcode_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `image_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `countries`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `code` | text | |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `regions`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `languages`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `code` | text | UNIQUE, NOT NULL |
| `name` | text | NOT NULL |
| `native_name` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `role_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `package_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `permission_types`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `regulatory_authorities`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `description` | text | |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

---

## 4. Relationship / Junction Tables

Connect core entities with typed, sourced, confidence-scored relationships.

### `product_barcodes`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `product_id` | uuid | FK → products(id) |
| `barcode_id` | uuid | FK → barcodes(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `source_id` | uuid | FK → data_sources(id) |
| `confidence_level` | numeric | 0–1 range |
| `effective_from` | timestamptz | |
| `effective_to` | timestamptz | |
| `verified_at` | timestamptz | |
| `approved_at` | timestamptz | |

### `product_ingredients`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `product_id` | uuid | FK → products(id) |
| `ingredient_id` | uuid | FK → ingredients(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `amount_value` | numeric | |
| `unit_id` | uuid | FK → units(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `source_id` | uuid | FK → data_sources(id) |
| `confidence_level` | numeric | 0–1 range |

### `product_allergens`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `product_id` | uuid | FK → products(id) |
| `allergen_id` | uuid | FK → allergens(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `source_id` | uuid | FK → data_sources(id) |
| `confidence_level` | numeric | 0–1 range |

### `product_nutrition_values`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `product_id` | uuid | FK → products(id) |
| `nutrition_type_id` | uuid | FK → nutrition_types(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `amount_value` | numeric | |
| `unit_id` | uuid | FK → units(id) |
| `measurement_basis_id` | uuid | FK → measurement_bases(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `source_id` | uuid | FK → data_sources(id) |
| `confidence_level` | numeric | 0–1 range |

### `product_health_flags`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `product_id` | uuid | FK → products(id) |
| `health_flag_id` | uuid | FK → health_flags(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `source_id` | uuid | FK → data_sources(id) |

### `product_health_evaluations`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `product_id` | uuid | FK → products(id) |
| `condition_id` | uuid | FK → health_conditions(id) |
| `is_safe` | boolean | NOT NULL |
| `risk_level` | text | |
| `recommendations` | jsonb | |
| `evaluated_at` | timestamptz | |

### `product_images`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `product_id` | uuid | FK → products(id) |
| `image_id` | uuid | FK → images(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `source_id` | uuid | FK → data_sources(id) |

### `ingredient_aliases`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `ingredient_id` | uuid | FK → ingredients(id) |
| `alias_name` | citext | NOT NULL |
| `language_id` | uuid | FK → languages(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `source_id` | uuid | FK → data_sources(id) |

### `ingredient_allergens`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `ingredient_id` | uuid | FK → ingredients(id) |
| `allergen_id` | uuid | FK → allergens(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `source_id` | uuid | FK → data_sources(id) |

### `ingredient_health_flags`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `ingredient_id` | uuid | FK → ingredients(id) |
| `health_flag_id` | uuid | FK → health_flags(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `source_id` | uuid | FK → data_sources(id) |

### `entity_relationships`

> Polymorphic junction table for arbitrary entity-to-entity relationships.

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `source_entity_id` | uuid | NOT NULL |
| `source_entity_type` | text | NOT NULL |
| `target_entity_id` | uuid | NOT NULL |
| `target_entity_type` | text | NOT NULL |
| `relationship_type_id` | uuid | FK → relationship_types(id) |
| `evidence_type_id` | uuid | FK → evidence_types(id) |
| `source_id` | uuid | FK → data_sources(id) |
| `confidence_level` | numeric | 0–1 range |

### `condition_nutrition_rules`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `condition_id` | uuid | FK → health_conditions(id) |
| `nutrition_type_id` | uuid | FK → nutrition_types(id) |
| `threshold_value` | numeric | NOT NULL |
| `threshold_unit` | text | NOT NULL |
| `comparison_operator` | text | NOT NULL (e.g., `>`, `<`, `>=`) |
| `severity` | text | NOT NULL |
| `description` | text | |
| `is_active` | boolean | NOT NULL, DEFAULT true |

---

## 5. Translation Tables

Each translation table links a language to an entity with localized text fields.

| Table | Entity FK Target | Localized Columns |
|-------|-----------------|-------------------|
| `company_translations` | `companies(id)` | name, description |
| `brand_translations` | `brands(id)` | name, description |
| `product_translations` | `products(id)` | name, description |
| `ingredient_translations` | `ingredients(id)` | name, description |
| `allergen_translations` | `allergens(id)` | name, description |
| `health_flag_translations` | `health_flags(id)` | name, description |
| `nutrition_type_translations` | `nutrition_types(id)` | name, description |
| `product_category_translations` | `product_categories(id)` | name, description |

**Common columns on all translation tables:**

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `language_id` | uuid | FK → languages(id) |
| `status` | translation_status | enum, DEFAULT 'DRAFT' |
| `created_at` | timestamptz | DEFAULT now() |
| `updated_at` | timestamptz | |

---

## 6. Barcodes & Data Sources

### `barcodes`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `barcode` | citext | UNIQUE, NOT NULL |
| `barcode_type_id` | uuid | FK → barcode_types(id) |
| `verification_status_id` | uuid | FK → verification_statuses(id) |
| `source_id` | uuid | FK → data_sources(id) |
| `issued_country_id` | uuid | FK → countries(id) |
| `confidence_level` | numeric | 0–1 range |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

### `data_sources`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `name` | text | NOT NULL |
| `url` | text | |
| `source_type_id` | uuid | FK → source_types(id) |
| `country_id` | uuid | FK → countries(id) |
| `priority_id` | uuid | FK → source_priorities(id) |
| `description` | text | |
| `is_active` | boolean | NOT NULL, DEFAULT true |
| `status_id` | bigint | FK → lifecycle_statuses |
| `version_number` | integer | DEFAULT 1 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `deleted_at` | timestamptz | |

---

## 7. Search Indexes

Trigram-based (`pg_trgm`) search indexes for fuzzy matching across entity names.

| Index Table | Entity |
|-------------|--------|
| `company_search_index` | companies |
| `brand_search_index` | brands |
| `product_search_index` | products |
| `ingredient_search_index` | ingredients |

Each table provides a search-optimized view over its corresponding core entity, leveraging `pg_trgm` GIN/GiST indexes for `LIKE`/`ILIKE` and similarity queries.

---

## 8. History & Audit Tables

### History Tables

Every core entity has a corresponding `*_history` table that stores a full copy of each entity version.

**Common history table structure:**

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `original_entity_id` | uuid | FK → original entity table(id) |
| `previous_version_id` | uuid | FK → same history table(id) (self-referential) |
| `change_set_id` | uuid | FK → change_sets(id) |
| *(all entity columns)* | *(copied)* | Full snapshot of the entity at that version |

> **Mutation prevention:** A `BEFORE UPDATE OR DELETE` trigger (`prevent_history_mutation()`) fires on every `*_history` table and raises an exception, ensuring history rows are immutable once written.

### Audit Tables

#### `change_sets`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `correlation_id` | uuid | NOT NULL |
| `transaction_id` | uuid | NOT NULL |
| `description` | text | |
| `metadata` | jsonb | |

#### `audit_context`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `correlation_id` | uuid | NOT NULL |
| `transaction_id` | uuid | NOT NULL |
| `session_id` | text | |
| `role_id` | uuid | FK → role_types(id) |
| `ip_address` | inet | |
| `user_agent` | text | |

#### `audit_log`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `change_set_id` | uuid | FK → change_sets(id) |
| `event_type_id` | uuid | FK → audit_event_types(id) |
| `role_id` | uuid | FK → role_types(id) |
| `context_id` | uuid | FK → audit_context(id) |

#### `audit_events`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `audit_log_id` | uuid | FK → audit_log(id) |
| `event_type_id` | uuid | FK → audit_event_types(id) |
| `old_value` | jsonb | |
| `new_value` | jsonb | |
| `field_name` | text | |
| `entity_id` | uuid | |
| `entity_type` | text | |

---

## 9. Collector Tables

Introduced by migration `002`. Support the data collection and discovery pipeline.

### `discovery_candidates`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `company_id` | uuid | FK → companies(id) |
| `barcode` | text | |
| `product_name` | text | |
| `brand_name` | text | |
| `status` | candidate_status | enum |
| `confidence_band` | confidence_band | enum |
| `source_url` | text | |
| `raw_data` | jsonb | |
| `normalized_data` | jsonb | |
| `matched_product_id` | uuid | FK → products(id) (nullable) |

### `data_conflicts`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `entity_id` | uuid | NOT NULL |
| `entity_type` | text | NOT NULL |
| `conflict_type` | text | NOT NULL |
| `field_name` | text | NOT NULL |
| `existing_value` | jsonb | |
| `new_value` | jsonb | |
| `source_id` | uuid | FK → data_sources(id) |
| `resolution` | text | |
| `resolved_at` | timestamptz | |
| `resolved_by` | text | |

### `halal_evidence`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `product_id` | uuid | FK → products(id) |
| `status` | text | (halal / haram / doubtful / unknown / needs_review) |
| `confidence` | numeric | |
| `evidence_text` | text | |
| `source_url` | text | |
| `ingredient_analysis` | jsonb | |
| `reviewed_at` | timestamptz | |
| `reviewed_by` | text | |

### `unit_conversions`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `from_unit_id` | uuid | FK → units(id) |
| `to_unit_id` | uuid | FK → units(id) |
| `conversion_factor` | numeric | NOT NULL |
| `formula` | text | |
| `is_active` | boolean | NOT NULL, DEFAULT true |

> **6 seeded conversion rows.**

### `scan_jobs`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `company_id` | uuid | FK → companies(id) |
| `status` | text | NOT NULL |
| `started_at` | timestamptz | |
| `completed_at` | timestamptz | |
| `total_items` | integer | |
| `completed_items` | integer | |
| `failed_items` | integer | |
| `metadata` | jsonb | |

### `scan_job_items`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `scan_job_id` | uuid | FK → scan_jobs(id) |
| `candidate_id` | uuid | FK → discovery_candidates(id) |
| `product_id` | uuid | FK → products(id) (nullable) |
| `status` | text | NOT NULL |
| `error_message` | text | |
| `processed_at` | timestamptz | |

### `coverage_snapshots`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `company_id` | uuid | FK → companies(id) |
| `scan_job_id` | uuid | FK → scan_jobs(id) |
| `barcode_coverage_pct` | numeric | |
| `ingredient_coverage_pct` | numeric | |
| `allergen_coverage_pct` | numeric | |
| `nutrition_coverage_pct` | numeric | |
| `evidence_coverage_pct` | numeric | |
| `captured_at` | timestamptz | DEFAULT now() |

### `data_versions`

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | uuid | PK |
| `entity_id` | uuid | NOT NULL |
| `entity_type` | text | NOT NULL |
| `version_number` | integer | NOT NULL |
| `data` | jsonb | NOT NULL |
| `created_at` | timestamptz | DEFAULT now() |

---

## 10. Triggers & Functions

### Trigger Functions

| Function | Event | Target Tables | Behavior |
|----------|-------|---------------|----------|
| `capture_entity_history()` | BEFORE INSERT, UPDATE | All core entity tables | Captures a full row snapshot to the corresponding `*_history` table |
| `set_updated_at()` | BEFORE UPDATE | All tables with `updated_at` | Sets `updated_at = now()` |
| `prevent_history_mutation()` | BEFORE UPDATE, DELETE | All `*_history` tables | Raises exception — history is immutable |
| `validate_entity_relationship_endpoints()` | BEFORE INSERT, UPDATE | `entity_relationships` | Validates that both source and target entity types/IDs resolve correctly |

### Custom Functions

#### `check_product_allergies(p_barcode text, p_allergen_codes text[])`

Returns allergen conflict results for a given barcode against a list of allergen codes. Used for real-time allergy safety checks.

#### `check_product_allergy(p_barcode text, p_allergen_code citext)`

Single-allergen convenience wrapper. Returns safety status for one barcode and one allergen code.

---

## 11. Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        LIFECYCLE & TYPES (Lookup)                           │
│                                                                             │
│  lifecycle_statuses ──────────┬──────────────────────────────────────┐      │
│  source_types                 │                                      │      │
│  source_priorities            │                                      │      │
│  verification_statuses        │  (status_id FK on all               │      │
│  evidence_types               │   core entity tables)               │      │
│  relationship_types ──┐       │                                      │      │
│  nutrition_types      │       │                                      │      │
│  measurement_bases    │       │                                      │      │
│  units                │       │                                      │      │
│  health_conditions    │       │                                      │      │
└───────────────────────┼───────┼──────────────────────────────────────┼──────┘
                        │       │                                      │
                        ▼       ▼                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CORE ENTITIES                                      │
│                                                                             │
│  companies ◄────────────────────────────────────────────────────────┐      │
│      │  (10 seeded)                                                 │      │
│      ├────► brands                                                  │      │
│      │       │   ├────► products ◄────────────────────────────┐    │      │
│      │       │   │       │                                    │    │      │
│      │       │   │       ├──► product_barcodes ◄──┐          │    │      │
│      │       │   │       ├──► product_ingredients ◄──┐       │    │      │
│      │       │   │       ├──► product_allergens ◄────┐│       │    │      │
│      │       │   │       ├──► product_nutrition_values ││       │    │      │
│      │       │   │       ├──► product_health_flags    ││       │    │      │
│      │       │   │       ├──► product_health_evaluations      │    │      │
│      │       │   │       ├──► product_images          ││       │    │      │
│      │       │   │       └──► product_translations    ││       │    │      │
│      │       │   │                                    ││       │    │      │
│      │       │   └──► product_categories              ││       │    │      │
│      │       │          (self-referential parent_id)  ││       │    │      │
│      │       │                                        ││       │    │      │
│      │       └──► brand_translations                  ││       │    │      │
│      │                                                ││       │    │      │
│      ├────► scan_jobs ──► scan_job_items ─────────────┘│       │    │      │
│      ├────► coverage_snapshots                         │       │    │      │
│      ├────► discovery_candidates ──────────────────────┘       │    │      │
│      └────► company_translations                               │    │      │
│                                                               │    │      │
│  ingredients ◄─────────────────────────────────────────────────┘    │      │
│      ├──► ingredient_aliases (language FK)                          │      │
│      ├──► ingredient_allergens ──► allergens                        │      │
│      ├──► ingredient_health_flags ──► health_flags                  │      │
│      ├──► ingredient_translations                                   │      │
│      └──► ingredient_categories (self-referential)                  │      │
│                                                                     │      │
│  allergens ──► allergen_types                                       │      │
│  health_flags ──► health_flag_types                                 │      │
│  barcodes ──► barcode_types, verification_statuses, countries      │      │
│  countries, regions, languages                                      │      │
│  role_types, package_types, permission_types                       │      │
│  regulatory_authorities, image_types                               │      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        JUNCTION / RELATIONSHIPS                             │
│                                                                             │
│  product_barcodes ──── products, barcodes, relationship_types,             │
│                        evidence_types, data_sources                        │
│                                                                             │
│  product_ingredients ── products, ingredients, relationship_types,         │
│                         units, evidence_types, data_sources                │
│                                                                             │
│  product_allergens ──── products, allergens, relationship_types,           │
│                         evidence_types, data_sources                       │
│                                                                             │
│  product_nutrition_values ── products, nutrition_types, units,             │
│                               measurement_bases, evidence_types, sources   │
│                                                                             │
│  product_health_flags ── products, health_flags, relationship_types,      │
│                           evidence_types, data_sources                     │
│                                                                             │
│  product_health_evaluations ── products, health_conditions                 │
│                                                                             │
│  product_images ──── products, images, relationship_types,                │
│                      evidence_types, data_sources                          │
│                                                                             │
│  entity_relationships ── (polymorphic) source → target via                 │
│                           relationship_types, evidence_types, sources      │
│                                                                             │
│  condition_nutrition_rules ── health_conditions, nutrition_types           │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         TRANSLATIONS                                        │
│                                                                             │
│  company_translations ──── languages, companies                            │
│  brand_translations ────── languages, brands                               │
│  product_translations ──── languages, products                             │
│  ingredient_translations ─ languages, ingredients                          │
│  allergen_translations ─── languages, allergens                            │
│  health_flag_translations  languages, health_flags                         │
│  nutrition_type_translations languages, nutrition_types                     │
│  product_category_translations languages, product_categories              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                     HISTORY & AUDIT                                         │
│                                                                             │
│  change_sets ──► audit_log ──► audit_events                                │
│       │              │                                                      │
│       │              └──► audit_context                                     │
│       │                                                                    │
│       └──► *_history (immutable, prevent_history_mutation trigger)         │
│                                                                             │
│  Original Entity ──(capture_entity_history)──► *_history                  │
│  History rows: original_entity_id → original table                        │
│                previous_version_id → self-FK (version chain)              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                      COLLECTOR PIPELINE                                     │
│                                                                             │
│  companies ──► scan_jobs ──► scan_job_items ──► discovery_candidates       │
│                                         │              │                    │
│                                         │              └──► products       │
│                                         │                    (matched)     │
│                                         └──► coverage_snapshots            │
│                                                                             │
│  discovery_candidates ──► data_conflicts                                   │
│  products ──► halal_evidence                                                │
│  units ──► unit_conversions (from_unit, to_unit)                           │
│  entities ──► data_versions (entity_id + type + version)                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Seeded Data Reference

### lifecycle_statuses (3)

| code | name |
|------|------|
| ACTIVE | Active |
| DEPRECATED | Deprecated |
| ARCHIVED | Archived |

### source_types (5)

| code | name |
|------|------|
| LABEL | Label |
| WEBSITE | Website |
| API | API |
| DATABASE | Database |
| USER_INPUT | User Input |

### evidence_types (4)

| code | name |
|------|------|
| LABEL | Label |
| MANUFACTURER | Manufacturer |
| OFFICIAL_SOURCE | Official Source |
| DATABASE | Database |

### verification_statuses (4)

| code | name |
|------|------|
| UNVERIFIED | Unverified |
| VERIFIED | Verified |
| CONFLICTED | Conflicted |
| RETRACTED | Retracted |

### relationship_types (7)

| code | name | directional | inverse |
|------|------|-------------|---------|
| CONTAINS_INGREDIENT | Contains Ingredient | true | — |
| MAY_CONTAIN_INGREDIENT | May Contain Ingredient | true | — |
| CONTAINS_ALLERGEN | Contains Allergen | true | — |
| MAY_CONTAIN_ALLERGEN | May Contain Allergen | true | — |
| PRIMARY_BARCODE | Primary Barcode | true | — |
| PACK_SIZE_VARIANT | Pack Size Variant | false | self |
| MEASURED_VALUE | Measured Value | false | — |

### measurement_bases (4 seeded)

### units (2 seeded)

| code | name | symbol | dimension |
|------|------|--------|-----------|
| g | Gram | g | MASS |
| ml | Milliliter | ml | VOLUME |

### health_conditions (7)

| code | name |
|------|------|
| DIABETES | Diabetes |
| HYPERTENSION | Hypertension |
| CELIAC | Celiac Disease |
| NUT_ALLERGY | Nut Allergy |
| LACTOSE | Lactose Intolerance |
| HEART_DISEASE | Heart Disease |
| OBESITY | Obesity |

### unit_conversions (6 seeded)

### companies (10 seeded)

### Sequences

| Sequence | Table | Column |
|----------|-------|--------|
| `lifecycle_statuses_id_seq` | lifecycle_statuses | id (bigint) |

> All other primary keys use `gen_random_uuid()` — no additional sequences exist.

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Total tables | 85 |
| Core entity tables | 19 |
| Lookup/reference tables | 10 |
| Junction/relationship tables | 12 |
| Translation tables | 8 |
| History tables | 19 (one per core entity) |
| Audit tables | 4 |
| Collector tables | 8 |
| Search index tables | 4 |
| Custom enum types | 10 |
| Trigger functions | 4 |
| Custom functions | 2 |
| Seeded data rows | ~50+ |
| Migrations applied | 40 |
| Sequences | 1 |
