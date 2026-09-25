# Mission 04 — Relationship & Junction Tables: Report

**Status:** DELIVERED (static-verified, 29/29 validation PASS; live apply pending a
PostgreSQL environment)

**Deliverable mapping:** The mission prompt requested
`database/migrations/0016_relationship_tables.sql` … `0019_relationship_triggers.sql`.
Per `ADR-004` (migrations are generated from `schema/`, never hand-written) and the
established decomposition pattern, Mission 04 ships as four generated, immutable
migrations:

| Migration file | Contents |
| -------------- | -------- |
| `migrations/0016_relationship_tables.sql` | 8 `CREATE TABLE` statements |
| `migrations/0017_relationship_constraints.sql` | 48 foreign keys |
| `migrations/0018_relationship_indexes.sql` | 48 correctness-critical indexes |
| `migrations/0019_relationship_triggers.sql` | 8 `set_updated_at()` triggers |

## 1. Relationship inventory

### 1.1 Tables created (8)

| Table | Kind | Endpoints | Cardinality |
| ----- | ---- | --------- | ----------- |
| `product_ingredients` | product membership | `products` × `ingredients` (+ optional `units`) | M:N |
| `product_allergens` | product membership | `products` × `allergens` | M:N |
| `product_nutrition_values` | product fact | `products` × `nutrition_types` (+ `units`) | M:N |
| `product_health_flags` | product membership | `products` × `health_flags` | M:N |
| `ingredient_allergens` | ingredient membership | `ingredients` × `allergens` | M:N |
| `ingredient_health_flags` | ingredient membership | `ingredients` × `health_flags` | M:N |
| `ingredient_aliases` | ingredient naming | `ingredients` (+ optional `languages`) | 1:M (alias to one ingredient) |
| `entity_relationships` | knowledge-graph edge | any canonical core entity → any canonical core entity | M:N (polymorphic) |

### 1.2 Relationship column set (every table)

`id uuid PK` · endpoint column(s) · `relationship_type_id uuid NOT NULL` (→
`relationship_types`) · `source_id uuid NULL` (→ `data_sources`) ·
`evidence_type_id uuid NULL` (→ `evidence_types`) · `confidence_level numeric NOT
NULL DEFAULT 0.5` (CHECK 0..1) · `effective_from` · `effective_to` ·
`verified_at` · `approved_at` · `status_id bigint NOT NULL` (→ `lifecycle_statuses`,
`ADR-008`) · `version_number integer NOT NULL DEFAULT 1` (CHECK > 0) ·
`created_at` · `updated_at` · `deleted_at`.

Column-name mapping for the mission's requirement list: `relationship_type` →
`relationship_type_id`, `evidence_type` → `evidence_type_id`, `lifecycle_status` →
`status_id` (the repository-wide `ADR-008` naming). `deleted_at` is added per the
non-destructive delete policy (`ADR-006`) — every table in this repository carries
it.

### 1.3 Relationship types

Every relationship carries `relationship_type_id` → `relationship_types`. The edge
vocabulary (`contains_ingredient`, `may_contain_ingredient`, `contains_allergen`,
`may_contain_allergen`, `provides_nutrition`, `has_health_flag`, `similar_to`,
`substitutable_for`, alias kinds, ...) is **governed data** in that lookup table —
seeded by governance, extensible by insert. The relationship model therefore
supports all approved relationship types without redesign; no ENUM was added and no
`ALTER TYPE` will ever be needed for edge kinds (`ADR-007`).

## 2. Dependency diagram

```mermaid
graph LR
    subgraph Canonical entities (0012)
        PR[products] --- PI[product_ingredients] --- IN[ingredients]
        PR --- PA[product_allergens] --- AL[allergens]
        PR --- PN[product_nutrition_values] --- NT[nutrition_types]
        PR --- PH[product_health_flags] --- HF[health_flags]
        IN --- IAL[ingredient_allergens] --- AL
        IN --- IHF[ingredient_health_flags] --- HF
        IN --- IALI[ingredient_aliases] --- LANG[languages]
    end
    subgraph Vocabulary (0003/0008)
        RT[relationship_types]
        DS[data_sources]
        ET[evidence_types]
        UN[units]
        LS[lifecycle_statuses]
    end
    ER[entity_relationships] --- RT
    ER --> SUB[products / ingredients / brands / companies / allergens / health_flags]
    PI --- RT; PI --- DS; PI --- ET; PI --- UN; PI --- LS
    PA --- RT; PA --- DS; PA --- ET; PA --- LS
    PN --- RT; PN --- DS; PN --- ET; PN --- UN; PN --- LS
    PH --- RT; PH --- DS; PH --- ET; PH --- LS
    IAL --- RT; IAL --- DS; IAL --- ET; IAL --- LS
    IHF --- RT; IHF --- DS; IHF --- ET; IHF --- LS
    IALI --- RT; IALI --- DS; IALI --- ET; IALI --- LANG; IALI --- LS
    ER --- DS; ER --- ET; ER --- LS
```

- All junction edges point **from** relationship tables **to** canonical entities
  and vocabulary. `entity_relationships` is the only polymorphic edge: its
  `subject_id`/`object_id` endpoints carry no FK (see Assumptions 5).
- No cycles: relationship tables never reference each other, and no entity
  references a relationship table. The only self-references in the schema remain
  `relationship_types`, `ingredient_categories`, `product_categories` (prior missions).

## 3. Foreign-key matrix (48 FKs, all `ON DELETE/UPDATE RESTRICT`)

| Referencing table | FK column | References | Nullable |
| ----------------- | --------- | ---------- | -------- |
| `product_ingredients` | `product_id` | `products(id)` | no |
| `product_ingredients` | `ingredient_id` | `ingredients(id)` | no |
| `product_ingredients` | `relationship_type_id` | `relationship_types(id)` | no |
| `product_ingredients` | `source_id` | `data_sources(id)` | yes |
| `product_ingredients` | `evidence_type_id` | `evidence_types(id)` | yes |
| `product_ingredients` | `unit_id` | `units(id)` | yes |
| `product_ingredients` | `status_id` | `lifecycle_statuses(id)` | no |
| `product_allergens` | `product_id` | `products(id)` | no |
| `product_allergens` | `allergen_id` | `allergens(id)` | no |
| `product_allergens` | `relationship_type_id` | `relationship_types(id)` | no |
| `product_allergens` | `source_id` | `data_sources(id)` | yes |
| `product_allergens` | `evidence_type_id` | `evidence_types(id)` | yes |
| `product_allergens` | `status_id` | `lifecycle_statuses(id)` | no |
| `product_nutrition_values` | `product_id` | `products(id)` | no |
| `product_nutrition_values` | `nutrition_type_id` | `nutrition_types(id)` | no |
| `product_nutrition_values` | `unit_id` | `units(id)` | no |
| `product_nutrition_values` | `relationship_type_id` | `relationship_types(id)` | no |
| `product_nutrition_values` | `source_id` | `data_sources(id)` | yes |
| `product_nutrition_values` | `evidence_type_id` | `evidence_types(id)` | yes |
| `product_nutrition_values` | `status_id` | `lifecycle_statuses(id)` | no |
| `product_health_flags` | `product_id` | `products(id)` | no |
| `product_health_flags` | `health_flag_id` | `health_flags(id)` | no |
| `product_health_flags` | `relationship_type_id` | `relationship_types(id)` | no |
| `product_health_flags` | `source_id` | `data_sources(id)` | yes |
| `product_health_flags` | `evidence_type_id` | `evidence_types(id)` | yes |
| `product_health_flags` | `status_id` | `lifecycle_statuses(id)` | no |
| `ingredient_allergens` | `ingredient_id` | `ingredients(id)` | no |
| `ingredient_allergens` | `allergen_id` | `allergens(id)` | no |
| `ingredient_allergens` | `relationship_type_id` | `relationship_types(id)` | no |
| `ingredient_allergens` | `source_id` | `data_sources(id)` | yes |
| `ingredient_allergens` | `evidence_type_id` | `evidence_types(id)` | yes |
| `ingredient_allergens` | `status_id` | `lifecycle_statuses(id)` | no |
| `ingredient_health_flags` | `ingredient_id` | `ingredients(id)` | no |
| `ingredient_health_flags` | `health_flag_id` | `health_flags(id)` | no |
| `ingredient_health_flags` | `relationship_type_id` | `relationship_types(id)` | no |
| `ingredient_health_flags` | `source_id` | `data_sources(id)` | yes |
| `ingredient_health_flags` | `evidence_type_id` | `evidence_types(id)` | yes |
| `ingredient_health_flags` | `status_id` | `lifecycle_statuses(id)` | no |
| `ingredient_aliases` | `ingredient_id` | `ingredients(id)` | no |
| `ingredient_aliases` | `language_id` | `languages(id)` | yes |
| `ingredient_aliases` | `relationship_type_id` | `relationship_types(id)` | no |
| `ingredient_aliases` | `source_id` | `data_sources(id)` | yes |
| `ingredient_aliases` | `evidence_type_id` | `evidence_types(id)` | yes |
| `ingredient_aliases` | `status_id` | `lifecycle_statuses(id)` | no |
| `entity_relationships` | `relationship_type_id` | `relationship_types(id)` | no |
| `entity_relationships` | `source_id` | `data_sources(id)` | yes |
| `entity_relationships` | `evidence_type_id` | `evidence_types(id)` | yes |
| `entity_relationships` | `status_id` | `lifecycle_statuses(id)` | no |

`entity_relationships.subject_id` / `object_id` carry **no** FK — the endpoint is
polymorphic across six entity tables (Assumption 5).

## 4. Constraint summary

- **UNIQUE (composite):** `(product, ingredient, relationship_type)` ·
  `(product, allergen, relationship_type)` · `(product, nutrition_type,
  relationship_type)` · `(product, health_flag, relationship_type)` ·
  `(ingredient, allergen, relationship_type)` · `(ingredient, health_flag,
  relationship_type)` · `(ingredient, alias)` ·
  `(subject_entity_type, subject_id, relationship_type, object_entity_type, object_id)`.
- **CHECK:** `version_number > 0` (all 8) · `confidence_level BETWEEN 0 AND 1`
  (all 8) · `effective_to >= effective_from` when both set (all 8) ·
  `amount_value >= 0` (product_ingredients, product_nutrition_values) ·
  amount/unit pairing (product_ingredients) · `alias <> ''` (ingredient_aliases) ·
  `subject_entity_type IN (6 canonical entities)` and `object_entity_type IN (...)`
  (entity_relationships) · no-self-loop `subject <> object` (entity_relationships).
- **FKs:** 48, all `ON DELETE RESTRICT` / `ON UPDATE RESTRICT` (`ADR-006`). No
  cascade anywhere.
- **Status:** `status_id bigint NOT NULL` → `lifecycle_statuses` (`ADR-008`)
  authoritative lifecycle; soft delete via `deleted_at`.

## 5. Indexes created (correctness-critical only)

48 indexes — one per FK column on each relationship table (`source_id`,
`evidence_type_id`, `relationship_type_id`, `status_id` on all 8; endpoint and
unit/language columns where present). UNIQUE constraints provide their own indexes
and are not duplicated. `entity_relationships.subject_id` / `object_id` are not
indexed (no FK, correctness scope only). No performance/search indexes created.

## 6. Assumptions

1. **Every relationship table carries the full relationship column set**, including
   `relationship_type_id` and `evidence_type_id`, even where today's data would use
   a single kind (e.g. nutrition facts): this satisfies the mission's column list
   and keeps the model extensible without redesign.
2. **`relationship_type_id`, `source_id`, `evidence_type_id`, `status_id`,
   `confidence_level` are named per repository conventions** (`relationship_type`
   → `relationship_type_id`, `evidence_type` → `evidence_type_id`,
   `lifecycle_status` → `status_id`). `confidence_band` remains a derived ENUM,
   never stored (`ADR-007`).
3. **`source_id` and `evidence_type_id` are NULLABLE** (consistent with core
   entities): an assertion may be entered before a source/evidence is attached.
   `relationship_type_id` and `status_id` are NOT NULL.
4. **Amount/unit semantics:** `product_ingredients.amount_value`/`unit_id` are
   nullable and paired (amount implies unit; no unit without amount).
   `product_nutrition_values.amount_value`/`unit_id` are NOT NULL.
5. **Polymorphic `entity_relationships`:** `subject_id`/`object_id` are UUIDs with
   `subject_entity_type`/`object_entity_type` CHECK-constrained to the six canonical
   core entities. Endpoint existence is enforced by the application layer and by a
   future trigger (a trigger-based endpoint validator is deliberately deferred; see
   Open questions 4). This is the standard knowledge-graph pattern: a single FK
   cannot reference multiple tables.
6. **`effective_from`/`effective_to`** express optional validity windows; NULL means
   unbounded. The composite UNIQUE excludes the effective window, so a new window
   for the same pair+type requires closing the previous one (set `effective_to`);
   this is the chosen temporal model (see Open questions 3).
7. **`deleted_at`** is added to the mission's column set for consistency with the
   repository-wide non-destructive delete policy (`ADR-006`).

## 7. Unresolved questions

1. **`company_brands` / `brand_products` (mission list) — not created.** The
   approved Mission 03 schema already encodes these relationships as direct FKs:
   `brands.company_id` (NOT NULL) and `products.brand_id` (nullable). Junction
   tables would duplicate canonical information and contradict the "a brand belongs
   to exactly one company" NOT NULL rule, and the mission forbids duplication and
   redesign. **Decision needed:** confirm the direct-FK representation is final, or
   request an ADR to convert to junction tables.
2. **`product_categories` / `ingredient_categories` (mission list) — not created.**
   Both names are already governed taxonomy lookup tables (Mission 02) referenced
   by `products.product_category_id`; `ingredient_categories` is currently unused by
   any canonical entity. If a many-to-many product↔category model is required
   (products in multiple categories), that is a redesign of the approved single-FK
   classification and needs an ADR. **Decision needed.**
3. **`product_images` / `product_barcodes` (mission list) — not created.** No
   `images` or `barcodes` canonical entity exists yet (only `image_types` and
   `barcode_types` vocabulary). Creating the junction tables would require inventing
   canonical entities, which is out of Mission 04 scope (relationship modeling only)
   and would violate "every FK resolves". **Decision needed:** confirm these arrive
   with their canonical entity milestone.
4. **`entity_relationships` endpoint integrity** is not enforced by a database
   trigger yet. Options: (a) keep application-layer enforcement (current),
   (b) add a trigger that validates `subject_id` exists in the table named by
   `subject_entity_type` (deferred to the population milestone to avoid premature
   business logic).
5. **Nutrition fact basis** (`per_100g` vs `per_serving` vs `per_package`) is not
   modeled on `product_nutrition_values`. The mission prohibits inventing business
   rules; the basis vocabulary needs a product decision.
6. **Unit-dimension consistency:** nothing yet prevents a mass fact (`g`) being
   paired with a volume unit (`ml`). Cross-table dimension validation is a
   population-milestone/trigger concern.
7. **`ingredient_aliases` language model:** `language_id` is nullable
   (NULL = language-neutral). Confirm whether every alias should be language-scoped.
8. **Live apply:** no PostgreSQL is available in this environment; migrations
   `0016`–`0019` must be executed in CI/review to confirm execution (static
   validation is 29/29 PASS). Apply with:
   `powershell -ExecutionPolicy Bypass -File scripts/migrate.ps1 -Database fateen`.

## 8. Non-goals (explicitly not built, per mission scope)

No business logic, APIs, search, governance workflows, or population. No
performance indexes, no version-history tables, no images/barcodes canonical
entities, no fact-basis vocabulary. Relationship types are governed data, not ENUMs
(`ADR-007`).
