# Mission 08 — Search Layer (Derived Read Models): Report

**Status:** DELIVERED (static-verified, 44/44 validation PASS; live apply pending a
PostgreSQL environment)

**Deliverable mapping:** The mission prompt requested exactly four search index
tables (`product_search_index`, `ingredient_search_index`, `brand_search_index`,
`company_search_index`) with no foreign keys, search-only indexes, and no
synchronization triggers. Per `ADR-004` (migrations are generated from `schema/`,
never hand-written) and the established decomposition pattern, Mission 08 ships
as two generated, immutable migrations:

| Migration file | Contents |
| -------------- | -------- |
| `migrations/0030_search_tables.sql` | 4 `CREATE TABLE` search-index statements |
| `migrations/0031_search_indexes.sql` | 16 search indexes (GIN trigram + GIN token + rank btree) |

No `03-constraints` and no `07-triggers` migrations were generated: the search
layer deliberately has no foreign keys and no triggers.

## 1. Search is a derived read model

Search tables are **derived read models**, not canonical data. Canonical
entities (`companies`, `brands`, `products`, `ingredients`) remain the single
source of truth and own integrity; the search layer owns performance. The layer
is **completely disposable and rebuildable**: dropping and regenerating
`0030`/`0031`, or truncating and reloading the four tables, loses nothing — every
searchable value is derived from canonical rows and their translations/aliases.

### 1.1 What search tables contain (required)

- **Canonical entity identifier** — `product_id` / `ingredient_id` /
  `brand_id` / `company_id`, a **logical reference only** with `UNIQUE` (one row
  per canonical entity, idempotent rebuilds) and **no foreign key**.
- **Normalized searchable text** — `search_name` (normalized primary name) and
  `search_text` (normalized concatenated searchable text: description, category,
  brand/company, internal code, aliases).
- **Language-independent search tokens** — `search_tokens text[]` (folded,
  accent-stripped tokens) and `language_codes citext[]` (the languages the
  searchable text covers).
- **Ranking/search helper field** — `search_rank numeric NOT NULL DEFAULT 0`
  with `CHECK (search_rank >= 0)`.
- **`generated_at`** — when the search row was generated/refreshed, for rebuild
  tracking.

### 1.2 What search tables do NOT contain (prohibited)

No `status_id`, no `version_number`, no `created_at`/`updated_at`/`deleted_at`,
no `is_active`, no `name`/`description`/`code` as business columns, no audit
columns. Nothing canonical is duplicated as a governed value — the searchable
text is a derived denormalization whose authoritative source remains the
canonical entity. This is a declared deviation from the standard column layout
(`sql_conventions.md`), documented in every file header: a derived read model is
not a governed entity.

## 2. Table inventory

| Table | Logical reference (no FK) | Derived from |
| ----- | ------------------------- | ------------ |
| `product_search_index` | `product_id` | `products`, `product_translations`, `product_categories`, `brands` |
| `ingredient_search_index` | `ingredient_id` | `ingredients`, `ingredient_translations`, `ingredient_aliases` |
| `brand_search_index` | `brand_id` | `brands`, `brand_translations`, `companies` |
| `company_search_index` | `company_id` | `companies`, `company_translations`, `countries` |

All four share an identical column set: `id uuid PK gen_random_uuid()` ·
`{entity}_id uuid NOT NULL UNIQUE` · `search_name text NOT NULL` ·
`search_text text NOT NULL` · `search_tokens text[] NOT NULL DEFAULT '{}'` ·
`language_codes citext[] NOT NULL DEFAULT '{}'` ·
`search_rank numeric NOT NULL DEFAULT 0` (CHECK ≥ 0) ·
`generated_at timestamptz NOT NULL DEFAULT now()`.

## 3. Foreign keys — deliberately none

The mission mandates logical references only. There is **no** `REFERENCES`
anywhere: neither inline in the table files, nor in any `03-constraints` file,
and no constraints file references a search table as a target. This is what keeps
the layer rebuildable — canonical data owns integrity, search owns performance.

## 4. Indexes (search-only, 16 total)

PostgreSQL search capability already approved in the repository (`ADR-003`):
**`pg_trgm`**. No new extensions, no `tsvector`/full-text configurations.

Per search table (×4):

| Index | Type | Purpose |
| ----- | ---- | ------- |
| `{table}_search_name_trgm_idx` | `GIN (search_name gin_trgm_ops)` | Fuzzy/prefix matching on the normalized name (language-independent) |
| `{table}_search_text_trgm_idx` | `GIN (search_text gin_trgm_ops)` | Trigram similarity over the full searchable text |
| `{table}_search_tokens_idx` | `GIN (search_tokens)` | Token containment / overlap queries |
| `{table}_search_rank_idx` | `btree (search_rank DESC)` | Ranked result ordering |

The `UNIQUE ({entity}_id)` constraints provide their own btree indexes (not
duplicated). No FK-supporting indexes exist (no FKs), and no canonical-query
indexes are placed on a read model.

## 5. Triggers — none

Per the mission rule ("do not invent synchronization triggers"), search tables
have **no triggers**. Population/synchronization is future-mission work; the
tables are filled by a rebuild job, not by database-side synchronization.
`set_updated_at()` is not applied because the tables carry no `updated_at` by
design (derived read model deviation).

## 6. Migration summary

| Migration | Schema sources | Contents |
| --------- | -------------- | -------- |
| `0030_search_tables` | `02-tables/65…68` | 4 search index tables |
| `0031_search_indexes` | `04-indexes/10` | 16 search indexes |

Both are atomic and checksum-verified by `scripts/migrate.ps1`. Apply with:
`powershell -ExecutionPolicy Bypass -File scripts/migrate.ps1 -Database fateen`.

## 7. Assumptions

1. **One row per canonical entity.** `UNIQUE ({entity}_id)` makes the index
   rebuild idempotent (`TRUNCATE` + reload, or `INSERT ... ON CONFLICT DO
   UPDATE`). A search index does not need version history; canonical `*_history`
   tables cover that.
2. **`search_rank` is a standard helper.** The mission permits ranking helper
   fields; a single `search_rank numeric >= 0` gives the search layer a uniform
   promotion/boost knob without inventing per-entity ranking tables.
3. **`pg_trgm` is the approved search primitive** (`ADR-003`). Trigram matching
   is language-independent, which matches the "language-independent search
   tokens" requirement without requiring per-language full-text configurations.
4. **No `updated_at`/audit trio on search tables.** A disposable read model is
   rebuilt, not governed; `generated_at` records the build/refresh time. This is
   the declared deviation required to keep the layer free of duplicated
   governance state.
5. **The search text is application-built.** The exact concatenation/normalization
   strategy (which aliases, transliterations, folds) is a population/API concern;
   the schema provides the storage shape.

## 8. Unresolved questions

1. **Population/synchronization** — the four tables are empty until the
   population milestone (or the search/API milestone) implements the rebuild job.
   No database-side synchronization was invented (mission rule).
2. **Search normalization rules** — Arabic normalization, accent folding,
   transliteration strategy, and the `search_tokens` tokenizer are not defined
   here; the schema stores the result.
3. **Live apply** — no PostgreSQL is available in this environment; migrations
   `0030`–`0031` must be executed in CI/review to confirm execution (static
   validation is 44/44 PASS).

## 9. Non-goals (explicitly not built, per mission scope)

No Collection, OCR, Governance, Population, Business Logic, API, or AI. No
synchronization triggers, no full-text configuration, no product↔image /
product↔barcode relationships (still open from Mission 06 scope gap), no search
history. Mission 08 stops after the search DDL and synchronized documentation.
