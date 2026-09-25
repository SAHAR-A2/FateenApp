# Mission 07 — Canonical Media & Barcode Domain: Report

**Status:** DELIVERED (static-verified, 38/38 validation PASS; live apply pending a
PostgreSQL environment)

**Deliverable mapping:** The mission prompt requested canonical `images` and
`barcodes` entities, immutable version-history for the media/barcode domain, a
verification vocabulary, and migrations. Per `ADR-004` (migrations are generated
from `schema/`, never hand-written) and the established decomposition pattern,
Mission 07 ships as five generated, immutable migrations:

| Migration file | Contents |
| -------------- | -------- |
| `migrations/0025_media_and_barcode_tables.sql` | `verification_statuses`, `images`, `barcodes` |
| `migrations/0026_media_and_barcode_history_tables.sql` | `images_history`, `barcodes_history` |
| `migrations/0027_media_and_barcode_constraints.sql` | 25 foreign keys |
| `migrations/0028_media_and_barcode_indexes.sql` | 25 correctness-critical indexes |
| `migrations/0029_media_and_barcode_triggers.sql` | 3 `set_updated_at()` + 2 immutability triggers |

Repository state is authoritative over mission wording. Deliverables named in
Mission 06 (image/barcode relationships, search indexes, relationship history)
are **absent from the repository** and are therefore not part of this delivery;
they are captured as documented out-of-scope items in §8 and in
`docs/open_questions.md`.

## 1. Deliverable inventory

### 1.1 Verification vocabulary (1)

`verification_statuses` is a governed lookup table — not an ENUM — so the barcode
verification dimension is business vocabulary (`ADR-001`, `ADR-007`, `ADR-008`
style): UUID PK, unique `citext` `code`, `name`, `description`, `display_order`,
`status_id` → `lifecycle_statuses`, `version_number`, full audit trio, and a
`set_updated_at()` trigger. No stored `is_active` boolean; the lifecycle status is
authoritative.

### 1.2 Canonical entities (2)

| Table | Natural key | Purpose | Notes |
| ----- | ----------- | ------- | ----- |
| `images` | `storage_uri` UNIQUE, `content_hash` UNIQUE | Canonical media asset registry | `image_type_id` NOT NULL → `image_types`; optional `language_id` → `languages`; optional `source_id` → `data_sources`; `mime_type`; `width`/`height` (CHECK > 0 when set); `file_size` (CHECK >= 0); `metadata jsonb DEFAULT '{}'`; `status_id` → `lifecycle_statuses` |
| `barcodes` | `barcode` citext UNIQUE (CHECK <> '') | Canonical barcode registry | `barcode_type_id` NOT NULL → `barcode_types`; `verification_status_id` NOT NULL → `verification_statuses`; optional `issued_country_id` → `countries`; optional `source_id` → `data_sources`; `confidence_level` numeric [0,1] (CHECK); `status_id` → `lifecycle_statuses` |

Both carry the canonical-entity column set: `version_number` (CHECK > 0),
`created_by`/`updated_by`/`reviewed_by`/`approved_by` (UUID, no auth service,
`ADR-005`), full audit trio, and a `set_updated_at()` trigger.

### 1.3 History tables (2)

`images_history` and `barcodes_history` follow the Mission 05 history architecture
exactly (see `docs/mission05_report.md`): immutable INSERT-only rows, keyed by
`UNIQUE (original_entity_id, version_number)`, with the full version column set
(`previous_version_id` self-FK, `change_set_id` → `change_sets`, `change_type`
`update_type`, `change_reason`, `changed_by`/`approved_by`, `source_id` →
`data_sources`, `confidence_level`, `created_at`, `effective_from`/`effective_to`/
`superseded_at`, `snapshot_hash`, `checksum`, `version_status`) plus the complete
business/lifecycle snapshot (`status_id` → `lifecycle_statuses`, `deleted_at`
captured as business state). As immutable rows they carry **no**
`updated_at`/`deleted_at` (declared deviation, same as Mission 05).

Snapshot excludes the identity/audit columns that map to the header (`id`,
`version_number`, the four actor columns, `source_id`, `confidence_level`,
`created_at`/`updated_at`) so no field is duplicated between snapshot and header.

### 1.4 Naming: `content_hash` vs `checksum`

The `images`/`images_history` content fingerprint is named **`content_hash`**;
the Mission 05 history column `checksum` remains reserved for row tamper-evidence
on the history row itself. The two are distinct concepts and are never conflated.
Documented in file headers and `sql_conventions.md`.

## 2. Orthogonality of lifecycle and verification

`barcodes` carries two independent status dimensions:

| Column | Vocabulary | Question it answers |
| ------ | ---------- | ------------------- |
| `status_id` → `lifecycle_statuses` | ACTIVE / DEPRECATED / ARCHIVED | Should this barcode participate in the catalog? |
| `verification_status_id` → `verification_statuses` | e.g. unverified / verified / failed | Can this barcode be trusted? |

They are deliberately separate FKs: a deprecated-but-verified barcode and an
active-but-unverified barcode are both valid states. No `is_active` boolean is
stored (`ADR-008`).

## 3. Dependency diagram

```mermaid
graph LR
    subgraph Vocabulary (0003/0008/0025)
        BT[barcode_types]
        IT[image_types]
        LANG[languages]
        COUNTRY[countries]
        DS[data_sources]
        LS[lifecycle_statuses]
        VS[verification_statuses]
    end
    subgraph Canonical media & barcode (0025)
        IMG[images]
        BC[barcodes]
    end
    subgraph History (0026)
        IMGH[images_history]
        BCH[barcodes_history]
    end
    VS --> LS
    IMG --> IT
    IMG --> DS
    IMG --> LANG
    IMG --> LS
    BC --> BT
    BC --> VS
    BC --> DS
    BC --> LS
    BC --> COUNTRY
    IMGH --> IMG
    BCH --> BC
    IMGH --> DS; IMGH --> LS; IMGH --> CS[change_sets]
    BCH --> DS; BCH --> LS; BCH --> CS
    IMGH --> IMGH
    BCH --> BCH
    BCH --> VS
    IMGH --> IT; IMGH --> LANG
```

- History tables depend on their canonical entity, `data_sources`,
  `lifecycle_statuses`, `change_sets`, and their own self-reference
  (`previous_version_id`). No other table depends on a history table.
- `barcodes` is the only table referencing `verification_statuses`; the
  vocabulary is independently governed and shared with the history snapshot.

## 4. Foreign-key matrix (25 FKs, all `ON DELETE/UPDATE RESTRICT`)

| Referencing table | FK column(s) | References |
| ----------------- | ------------ | ---------- |
| `verification_statuses` | `status_id` | `lifecycle_statuses(id)` |
| `images` | `image_type_id` | `image_types(id)` |
| `images` | `source_id` | `data_sources(id)` |
| `images` | `language_id` | `languages(id)` |
| `images` | `status_id` | `lifecycle_statuses(id)` |
| `barcodes` | `barcode_type_id` | `barcode_types(id)` |
| `barcodes` | `verification_status_id` | `verification_statuses(id)` |
| `barcodes` | `source_id` | `data_sources(id)` |
| `barcodes` | `status_id` | `lifecycle_statuses(id)` |
| `barcodes` | `issued_country_id` | `countries(id)` |
| `images_history` | `original_entity_id` | `images(id)` |
| `images_history` | `previous_version_id` | `images_history(id)` (self) |
| `images_history` | `change_set_id` | `change_sets(id)` |
| `images_history` | `source_id` | `data_sources(id)` |
| `images_history` | `status_id` | `lifecycle_statuses(id)` |
| `images_history` | `image_type_id` | `image_types(id)` |
| `images_history` | `language_id` | `languages(id)` |
| `barcodes_history` | `original_entity_id` | `barcodes(id)` |
| `barcodes_history` | `previous_version_id` | `barcodes_history(id)` (self) |
| `barcodes_history` | `change_set_id` | `change_sets(id)` |
| `barcodes_history` | `source_id` | `data_sources(id)` |
| `barcodes_history` | `status_id` | `lifecycle_statuses(id)` |
| `barcodes_history` | `barcode_type_id` | `barcode_types(id)` |
| `barcodes_history` | `verification_status_id` | `verification_statuses(id)` |
| `barcodes_history` | `issued_country_id` | `countries(id)` |

All FKs use `ON DELETE RESTRICT` / `ON UPDATE RESTRICT` (`ADR-006`). No cascade
anywhere.

## 5. Constraint summary

- **UNIQUE (single-column):** `verification_statuses(code)` ·
  `images(storage_uri)` · `images(content_hash)` · `barcodes(barcode)`.
- **UNIQUE (composite):** `(original_entity_id, version_number)` on
  `images_history` and `barcodes_history` (one row per entity version).
- **CHECK:** `version_number > 0` (all 5 tables) ·
  `confidence_level BETWEEN 0 AND 1` (`barcodes`, both history tables) ·
  `effective_to >= effective_from` when both set (both history tables) ·
  `barcode <> ''` (`barcodes`, `barcodes_history`) ·
  `width/height > 0` when set and `file_size >= 0` (`images`,
  `images_history`).
- **FKs:** 25, all `ON DELETE/UPDATE RESTRICT` (`ADR-006`). No cascade.
- **Status:** `status_id` → `lifecycle_statuses` (`ADR-008`) on every table;
  `barcodes`/`barcodes_history` additionally carry `verification_status_id` →
  `verification_statuses` (independent verification dimension).

## 6. Immutable strategy

History rows are INSERT-only and enforced at the storage layer exactly as in
Mission 05:

- The shared `prevent_history_mutation()` guard function
  (`schema/06-functions/02`, migration 0024) raises on any `UPDATE` or `DELETE`.
- Two new `BEFORE UPDATE OR DELETE ... FOR EACH ROW` triggers, one per Mission 07
  history table (`schema/07-triggers/08`, migration 0029).
- `previous_version_id` chains (self-FK, RESTRICT), `version_status`
  (`draft → pending_approval → approved → superseded`), `superseded_at`,
  `snapshot_hash`/`checksum` — all reused from Mission 05; no new functions or
  enum types were created (`ADR-007`).

## 7. Indexes created (correctness-critical only)

25 indexes — one per FK column across `verification_statuses`, `images`,
`barcodes`, `images_history`, and `barcodes_history` (`status_id`,
`image_type_id`, `source_id`, `language_id`, `barcode_type_id`,
`verification_status_id`, `issued_country_id`, `original_entity_id`,
`previous_version_id`, `change_set_id`). PostgreSQL does not index FK columns
automatically, so these are required for referential-integrity enforcement. The
UNIQUE constraints on `code`, `storage_uri`, `content_hash`, and `barcode`
provide their own indexes (not duplicated). No performance/search indexes
created.

## 8. Assumptions

1. **Mission-literal history names map to existing Mission 05 tables.**
   `product_history`, `ingredient_history`, and `category_history` (and the other
   singular mission spellings) are **documentation-only aliases** for the existing
   Mission 05 plural history tables (`products_history`, `ingredients_history`,
   `product_categories_history` + `ingredient_categories_history`, ...). No
   duplicate history tables were created. Only the two genuinely new canonical
   entities (`images`, `barcodes`) received new history tables.
2. **Verification is a lookup table, not an ENUM.** `verification_statuses`
   follows `ADR-001`/`ADR-007` (governed, translatable, ordered business
   vocabulary → table) and `ADR-008` (lifecycle via `status_id`, no
   `is_active` boolean). Seed values are Phase 8 work, not invented here.
3. **`verification_status_id` is NOT NULL.** A barcode always carries a
   verification state (unverified being the default disposition for new rows);
   the same is true for the `status_id` lifecycle.
4. **`source_id` is nullable.** An image/barcode can enter the catalog without a
   documented provenance row yet; `data_sources` remains the registry that future
   fact tables FK to.
5. **Actor columns are NULL-able UUIDs with no FK** (`created_by`/`updated_by`/
   `reviewed_by`/`approved_by`). The auth/identity service does not exist yet
   (same ruling as `ADR-005` and Mission 05).
6. **`confidence_level` is carried on `barcodes` and both history tables**, not
   on `images` — provenance confidence is a property of the barcode claim
   (linkages resolve against the verified value), matching the Mission 04
   relationship column set.
7. **`content_hash` is the content fingerprint** on `images`/`images_history`;
   Mission 05 history `checksum` stays reserved for history-row tamper-evidence.
   The two names are intentional and non-overlapping.

## 9. Unresolved questions

1. **Mission 06 scope gap** — image/barcode relationship tables (e.g.
   `product_images`, `product_barcodes`), search indexes, and relationship history
   were named in Mission 06 but are **absent from the repository**. Repository
   state is authoritative; they are not re-invented here. **Decision needed:**
   fold them into a later milestone or approve a follow-up work order.
2. **Verification seed values** — the exact `verification_statuses` codes
   (e.g. unverified / verified / failed, with `display_order`) require the Phase 8
   approved vocabulary.
3. **`content_hash` vs `checksum`** — confirm the naming split (content
   fingerprint vs. row tamper-evidence) is acceptable; it deliberately diverges
   from a single shared column name to keep the two meanings distinct.
4. **Live apply** — no PostgreSQL is available in this environment; migrations
   `0025`–`0029` must be executed in CI/review to confirm execution (static
   validation is 38/38 PASS). Apply with:
   `powershell -ExecutionPolicy Bypass -File scripts/migrate.ps1 -Database fateen`.

## 10. Non-goals (explicitly not built, per mission scope)

No search/collection/OCR/governance/population/APIs. No product↔image or
product↔barcode junction tables (blocked by Mission 06 scope gap, §9). No
performance indexes. No new enums or functions. Media and barcode DDL only,
additive on top of Mission 05.
