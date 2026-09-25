# ECR-001 — Closing Five Certification Blockers

Status: **IMPLEMENTED (additive-only), static-validated**

Work order scope: eliminate the five audit blockers that remained after Mission
09 certified the Fateen Database Foundation. Every change is **additive**: no
redesign, no renames, no removed columns, no modification of any previous
migration. Every existing ADR and the Mission 09 certification of migrations
`0001`–`0031` remain valid.

## 1. What was blocking

| # | Blocker | Why it existed | Verdict |
| - | ------- | -------------- | ------- |
| 1 | No product↔image / product↔barcode connection | Mission 04 built the relationship architecture but had no canonical `images`/`barcodes` yet; Mission 07 built those entities without the relationship tables. The long-documented Mission 06 scope gap. | **CLOSED** (additive) |
| 2 | `entity_relationships` accepts nonexistent endpoint UUIDs | The polymorphic edge table has no FK on `subject_id`/`object_id` by design (dynamic endpoint type). Existence was only application-enforced. | **CLOSED** (additive) |
| 3 | History tables immutable but never auto-populated | Mission 05 built the history tables and INSERT-only guards but no capture mechanism; history was developer-maintained. | **CLOSED** (additive) |
| 4 | Nutrition facts cannot express measurement basis | `product_nutrition_values` modeled only (product, nutrition_type, relationship_type); `per_100g` vs `per_serving` vs `per_package` could not coexist. | **CLOSED** (additive) |
| 5 | Validator could not detect these classes of defect | `scripts/validate_foundation.ps1` (47 checks) lacked checks for missing links, missing history capture, and unresolved references. | **CLOSED** (additive) |

## 2. Design (additive-only)

Golden rules applied throughout:

- No redesign, no renames, no removed columns, no modification of prior
  migrations (`0001`–`0031` untouched and byte-identical).
- Every new object follows an existing, certified pattern (lookup / Mission 04
  relationship / Mission 05 history / governed trigger wiring).
- No `ON DELETE/UPDATE CASCADE` anywhere (`ADR-006`); `status_id` governs
  lifecycle (`ADR-008`); governed business vocabulary is a lookup table, never
  an ENUM (`ADR-001`/`ADR-007`).
- History tables stay immutable: their only triggers are the INSERT-only
  `prevent_history_mutation()` guards, so automatic capture never recurses.

## 3. What was delivered

### Blocker 1 — product↔media relationships (migrations `0032`, `0033`, `0034`, `0035`)

- `product_images` — relationship table (many images per product, image kinds
  governed by `image_types`), full Mission 04 relationship column set, composite
  UNIQUE `(product_id, image_id, relationship_type_id)`.
- `product_barcodes` — same pattern (many barcodes per product, barcode
  standards governed by `barcode_types`), composite UNIQUE
  `(product_id, barcode_id, relationship_type_id)`.
- `product_images_history` / `product_barcodes_history` — Mission 05 history
  tables (INSERT-only, `UNIQUE (original_entity_id, version_number)`, full
  version/audit header + snapshot + `snapshot_hash`/`checksum`).
- Constraints (`0034`): 6 FKs per relationship table + 9 FKs per history table,
  all `RESTRICT`, all FK columns indexed (`0035`).

New schema files: `02-tables/70`–`73`, `03-constraints/10`,
`04-indexes/12`.

### Blocker 2 — entity_relationships endpoint validation (migrations `0036`, `0037`)

- `validate_entity_relationship_endpoints()` — BEFORE INSERT OR UPDATE trigger
  function. For each endpoint it resolves `{entity_type, entity_id}` against the
  canonical entity table named by the entity-type CHECK constraint (the six
  canonical core entities) and raises an exception if the row does not exist.
  `entity_relationships` itself is unchanged.
- Wired by `entity_relationships_validate_endpoints` trigger (`0037`).

New schema files: `06-functions/04`, `07-triggers/10`.

### Blocker 3 — automatic history capture (migrations `0036`, `0037`)

- `capture_entity_history()` — one generic BEFORE INSERT/UPDATE function wired to
  every history-owning table (13 triggers: 6 core entities + `nutrition_types` +
  `product_categories` + `ingredient_categories` + `images` + `barcodes` +
  `product_images` + `product_barcodes`). It:
  - maps the change to the existing `update_type` ENUM (`created` /
    `modified` / `archived` / `deprecated`),
  - skips no-op updates (jsonb comparison excluding `updated_at`), so touching
    only `updated_at` does not mint a new version,
  - preserves the version chain: `previous_version_id` = latest history row for
    the entity; `version_number` auto-increments only when the application does
    not manage it,
  - reflects the entity columns onto the history snapshot (renames
    `created_by`→`changed_by`, keeps `approved_by`; never copies `updated_at`),
  - computes `snapshot_hash` (SHA-256 of the snapshot jsonb) and `checksum`
    (SHA-256 of `snapshot_hash|id|version|change_type`),
  - leaves `change_set_id`/`change_reason` NULL and keeps `version_status`
    `'draft'` (session/application context supplies them server-side).
- No recursion: history tables carry no INSERT triggers; their only triggers are
  the immutability guards, which still reject UPDATE/DELETE of history rows
  (`0037` adds them for the two new history tables).

New schema files: `06-functions/03`, `07-triggers/09`, `07-triggers/12`.

### Blocker 4 — nutrition measurement bases (migrations `0032`, `0034`, `0035`, `0037`)

- `measurement_bases` — governed lookup table (NOT an ENUM; ADR-001/007) with
  `code citext UNIQUE`, `status_id` → `lifecycle_statuses`, `version_number`,
  audit trio. Canonical codes documented: `per_100g`, `per_serving`,
  `per_package` (seed rows deferred to Phase 8 — the repository never invents
  seed data).
- `product_nutrition_values` gains a **NULLable** `measurement_basis_id` column
  + FK RESTRICT to `measurement_bases`.
- Natural key: `product_nutrition_values_fact_unique` is dropped and re-added
  **with the same name** over
  `(product_id, nutrition_type_id, relationship_type_id, measurement_basis_id)`.
  NULLs are distinct in PostgreSQL, so all pre-existing rows remain valid;
  existing inserts without a basis keep working.

New schema files: `02-tables/69`, `03-constraints/09`, `04-indexes/11`,
`07-triggers/11`.

### Blocker 5 — stronger validator (`scripts/validate_foundation.ps1`)

Extended from 47 → **55 checks**. New ECR-001 block validates:

- all Blocker 1/4 tables present;
- a `{table}_capture_history` trigger exists for **every** history-owning table
  (a table whose history is never populated is a FAIL);
- `capture_entity_history()` and `validate_entity_relationship_endpoints()`
  functions exist and the endpoint-validation trigger is wired;
- `set_updated_at()` wired for the three new audit-trio tables;
- the `measurement_basis_id` extension is additive (nullable column + FK +
  same-named 4-column UNIQUE);
- migrations `0032`–`0037` exist and are byte-identical to `schema/`.

The generic checks now also cover the new objects (FK targets exist, no
CASCADE, every FK column indexed, category membership, base-entity resolution,
history column set, immutability triggers).

## 4. Migration plan

All migrations are new (generated from `schema/` via `scripts/build_migrations.ps1`,
`ADR-004`); `0001`–`0031` were regenerated byte-identical.

| Migration | Schema sources | Contents |
| --------- | -------------- | -------- |
| `0032_ecr_product_media_tables.sql` | `02-tables/69–71` | `measurement_bases`, `product_images`, `product_barcodes` |
| `0033_ecr_product_media_history_tables.sql` | `02-tables/72–73` | `product_images_history`, `product_barcodes_history` |
| `0034_ecr_constraints.sql` | `03-constraints/09–10` | measurement-basis FK + natural-key extension; 30 product-media FKs |
| `0035_ecr_indexes.sql` | `04-indexes/11–12` | 38 FK-supporting indexes |
| `0036_ecr_functions.sql` | `06-functions/03–04` | `capture_entity_history()`, `validate_entity_relationship_endpoints()` |
| `0037_ecr_triggers.sql` | `07-triggers/09–12` | 13 capture triggers, 1 validation trigger, 3 `set_updated_at`, 2 immutability |

## 5. Verification report

Static validation (`powershell -NoProfile -ExecutionPolicy Bypass -File
scripts\validate_foundation.ps1`):

- **55/55 checks PASS** (47 pre-existing + 8 ECR-001).
- Schema/migration sync: regeneration is byte-identical for `0001`–`0031` and
  produces `0032`–`0037`.
- Repository totals (counted from `schema/`):
  - 73 tables (24 lookup, 8 canonical, 8 translation, 10 relationship,
    13 history, 6 audit, 4 search);
  - 227 FKs, all `ON DELETE RESTRICT`, no CASCADE anywhere;
  - 238 index statements; 83 triggers (56 `set_updated_at` + 13
    `prevent_history_mutation` + 13 `capture_entity_history` + 1
    `validate_entity_relationship_endpoints`);
  - 4 functions, 10 enums, 3 extensions.

## 6. Execution prep

No live PostgreSQL exists in this environment (no `psql`, no Docker, no
PostgreSQL service), so live apply is a documented remaining risk. To execute
in CI/review:

```powershell
psql -v db_name=fateen -v db_owner=fateen_app -f scripts/create_database.sql postgres
powershell -File scripts/migrate.ps1 -Database fateen   # applies 0001..0037
```

Post-execution sanity probes recommended:

```sql
-- history auto-capture: an insert must mint history version 1
INSERT INTO companies (id, internal_code, status_id, ...) VALUES (...);
SELECT change_type, version_number, snapshot_hash IS NOT NULL
FROM companies_history WHERE original_entity_id = <id>;

-- endpoint validation: an edge to a nonexistent entity must be rejected
INSERT INTO entity_relationships (subject_entity_type, subject_id, ...)
VALUES ('companies', '00000000-0000-0000-0000-000000000000', ...); -- must fail

-- measurement basis natural key
INSERT INTO measurement_bases (id, code, status_id) VALUES (..., 'per_100g', <active>);
INSERT INTO product_nutrition_values (product_id, nutrition_type_id,
    relationship_type_id, measurement_basis_id, ...) VALUES (..., <per_100g>, ...);
INSERT INTO product_nutrition_values (product_id, nutrition_type_id,
    relationship_type_id, measurement_basis_id, ...) VALUES (..., <per_serving>, ...); -- both allowed
```

## 7. Remaining risks / carried forward

1. **Live apply** — migrations `0001`–`0037` static-certified but never executed;
   CI apply job recommended (pre-existing, now includes `0032`–`0037`).
2. **`change_set_id`/`change_reason`** — NULL by default; the application layer
   supplies session context (`set_config`) and change-set grouping.
3. **Actors** — `changed_by`/`approved_by` NULL until an auth service exists
   (ADR-005 precedent); the capture function maps `created_by`/`updated_by`/
   `approved_by` when present.
4. **`measurement_bases` seeds** — canonical codes documented, unseeded (Phase 8).
5. **Endpoint-type coverage** — the validation function handles exactly the six
   CHECK-constrained endpoint types; a future CHECK extension must extend the
   function in the same change.
6. **Snapshot/entity parity** — the capture function copies entity columns that
   exist (possibly renamed) in the history table; history-only columns (none
   today) would not be snapshot-filled automatically.

## 8. ADR and certification impact

- No ADR was changed or invalidated; the new lookup table, relationship tables,
  and functions all follow existing ADRs (`ADR-001`, `ADR-003`, `ADR-004`,
  `ADR-006`, `ADR-007`, `ADR-008`).
- Mission 09 certification of `0001`–`0031` remains intact: no prior migration
  was modified (regeneration is byte-identical).
- Documentation updated: `README.md`, `docs/README.md`,
  `docs/01-entity-list/foundation-entities.md` (68→73 tables),
  `docs/02-erd/foundation-dependency-graph.md` (ECR-001 nodes, migration
  graph `0032`–`0037`, FK summary), `migrations/README.md`,
  `docs/open_questions.md` (Mission 06 gap closed; ECR-001 section).
