# ECR-003 — History Capture Runtime Defect Fix (Live PostgreSQL Verification)

**Status:** **COMPLETE** — two runtime defects in `capture_entity_history()`
were confirmed on a live PostgreSQL instance, fixed additively via migrations
`0038` and `0039`, and proven end-to-end against all 13 history-owning tables.
Validator: **60/60 PASS**. Live ledger: `0001`–`0039` applied (39/39).

**Scope:** Runtime defect fix only. Migrations `0001`–`0037` were **not**
modified. No redesign of the history architecture, no new reference data, no
APIs, no business logic, no Phase 2 work.

**Method:** A portable PostgreSQL 17.4 server was provisioned locally
(`127.0.0.1:5433`, trust auth, user `postgres`), a test database `fateen` was
bootstrapped, migrations `0001`–`0039` were applied through the repository's
own `scripts/migrate.ps1`, and every claim below was verified with live
`psql`/SQL probes rather than static inspection.

---

## 1. Executive summary

ECR-002 certified the migration chain `0001`–`0037` statically but had **no
live PostgreSQL** available, so the ECR-001 capture function
`capture_entity_history()` had never actually run. This mission stood that
function up and executed it. Live execution immediately exposed two genuine
blocking defects, both fixed additively:

1. **Defect 1 — `NEW.<col>` tokens embedded in dynamic SQL.** The original
   function built its INSERT value list as literal strings such as
   `'NEW.brand_id'` and embedded them into the dynamically `EXECUTE`d SQL.
   Dynamic SQL runs in its own SPI context and has **no access to the PL/pgSQL
   `NEW`/`OLD` record bindings**, so every INSERT/UPDATE on a tracked entity
   failed at runtime. A secondary defect in the same body — `version_number`
   appearing both as the history header column and again through the generic
   column loop — produced the first observed failure
   (`column "version_number" specified more than once`).
2. **Defect 2 — actor-column mapping could NULL-out the whole snapshot.** The
   first fix mapped `created_by -> changed_by` with
   `jsonb_set(snapshot, '{changed_by}', to_jsonb(NEW.created_by))`. But
   `to_jsonb(NULL)` returns **SQL NULL**, and `jsonb_set` with a SQL-NULL
   `new_value` returns **NULL**, wiping the entire snapshot and turning every
   downstream value (hashes included) into NULL.
3. **Defect 3 — INSERT-time foreign-key conflict.** The capture triggers are
   `BEFORE INSERT` triggers: the history row is written *before* the entity
   row exists, so the `original_entity_id` FK (checked immediately) always
   failed for entity creation.

All three are eliminated by two additive migrations (`0038` function
replacement, `0039` FK deferral). Full details, evidence, and the complete
runtime test matrix follow.

---

## 2. Mission scope and constraints

- Fix the confirmed runtime defect so `capture_entity_history()` actually works.
- **Additive fixes only** (new migrations). Migrations `0001`–`0037` must be
  untouched and byte-identical to their canonical `schema/` sources.
- Prove the fix on **live PostgreSQL** — the first true runtime verification of
  the full chain.
- Do **not** redesign history, add reference data, APIs, business logic, or
  Phase 2 features.

---

## 3. Defect 1 — `NEW.<col>` tokens in dynamic SQL

### 3.1 Root cause

The ECR-001 body (migration `0036`, schema `03_capture_entity_history.sql`)
built the history INSERT as:

```sql
EXECUTE format(
    'INSERT INTO %I (...) SELECT ... %s ...',
    hist_table,
    array_to_string(ins_vals, ', ')   -- items like: 'NEW.brand_id', 'NEW.version_number'
) USING prev_id, ct;
```

The value list contained **text tokens** `NEW.brand_id`, `NEW.internal_code`,
etc. The `EXECUTE` statement is parsed and run in a fresh SPI context that has
no `NEW`/`OLD` bindings, so any such token is either a column reference that
does not exist there or, as observed, an outright duplicate/undefined column.
A secondary defect made the failure deterministic: `version_number` was emitted
both by the header (`version_number` column) and again by the generic column
loop.

### 3.2 Live evidence (pre-fix, migration `0037` state)

```text
psql: ERROR:  column "version_number" specified more than once
QUERY:  INSERT INTO products_history (original_entity_id, version_number,
previous_version_id, ... , NEW.brand_id, ..., NEW.version_number, ...)
```

This confirmed both the duplicated column and the `NEW.` token embedding.

---

## 4. Fix 1 — bound-parameter snapshot (migration `0038`)

New schema file `schema/06-functions/05_ecr_fix_capture_entity_history.sql`,
shipped as migration `0038_ecr_fix_capture_history.sql`
(`CREATE OR REPLACE FUNCTION capture_entity_history()` — same signature, so the
13 capture triggers wired in `0037` keep working unchanged).

Design of the corrected body:

- **Values are passed as a single bound parameter.** The snapshot is
  materialised with `to_jsonb(NEW)`, stripped of `updated_at`, and expanded
  into the INSERT via
  `jsonb_populate_record(NULL::<history_type>, $1) ... USING snapshot`.
  No value from `NEW` is ever textually embedded in the executed SQL.
- **Identifiers** remain safely quoted via `quote_ident`/`%I`; the history
  table name is never interpolated unquoted.
- **Column set** comes from `information_schema.columns` on the entity,
  excluding `id`, `version_number`, `updated_at`, `updated_by`, `reviewed_by`
  (so `version_number` appears exactly once — in the history header).
- **Actor mapping:** `created_by -> changed_by` (with
  `COALESCE(updated_by, created_by)` on the two tables that carry `updated_by`;
  `updated_by`/`reviewed_by` are never captured).
- **Preserved behavior:** INSERT/UPDATE capture, immutable history (unchanged),
  version chain (`previous_version_id` + `version_number`, `MAX+1` bump),
  no-op suppression (`(to_jsonb(NEW)-'updated_at') = (to_jsonb(OLD)-'updated_at')`
  → `RETURN NEW`), SHA-256 `snapshot_hash`/`checksum`, change-type mapping from
  `deleted_at` + `lifecycle_statuses` codes, no recursion (history tables carry
  no INSERT triggers).

---

## 5. Defect 2 — `jsonb_set` SQL-NULL snapshot wipe (found live)

### 5.1 Root cause

The first corrected body mapped the actor with:

```sql
snapshot := jsonb_set(snapshot, '{changed_by}', to_jsonb(NEW.created_by));
```

`to_jsonb(NULL)` returns SQL NULL (not JSON `null`), and
`jsonb_set(target, path, NULL::jsonb)` returns **SQL NULL**. With no
`created_by` supplied (the normal case), the entire snapshot became NULL:
`snapshot_hash`/`checksum` computed to NULL and every `(r).<col>` came out
NULL, tripping `NOT NULL` constraints on the history row.

### 5.2 Live evidence

```text
ERROR:  null value in column "confidence_level" of relation "products_history"
        violates not-null constraint
DETAIL: Failing row contains (... null, null, null, null, created, ...)
CONTEXT: SQL statement "INSERT INTO products_history (...) SELECT ..., NULL,
         NULL, (r).brand_id, ... FROM (SELECT jsonb_populate_record(...)) s"
```

The header values (`NEW.id`, `NEW.version_number`) were correct, while every
`(r).*` value and both hashes were NULL — the fingerprint of a NULL snapshot.

### 5.3 Fix

Both actor branches now guard the JSON-null mapping:

```sql
snapshot := jsonb_set(snapshot, '{changed_by}',
                      COALESCE(to_jsonb(COALESCE(NEW.updated_by, NEW.created_by)), 'null'::jsonb));
snapshot := jsonb_set(snapshot, '{changed_by}',
                      COALESCE(to_jsonb(NEW.created_by), 'null'::jsonb));
```

Verified semantics in live psql: `jsonb_set('{"x":1}', '{a}', COALESCE(to_jsonb(NULL::uuid),'null'::jsonb))`
→ `{"a": null, "x": 1}` — the snapshot survives, and a missing actor records a
clean SQL NULL in `changed_by`.

---

## 6. Defect 3 — INSERT-time FK conflict (migration `0039`)

### 6.1 Root cause

The 0037 capture triggers are `BEFORE INSERT OR UPDATE`. On entity creation the
trigger writes the history row before the entity row exists, so the
non-deferrable `original_entity_id` FK was checked immediately and failed.

### 6.2 Live evidence

```text
ERROR:  insert or update on table "products_history" violates foreign key
        constraint "products_history_original_entity_id_fk"
DETAIL: Key (original_entity_id)=(a0ac989d-...) is not present in table "products".
```

### 6.3 Fix

New schema file `schema/03-constraints/11_ecr_fix_history_original_entity_fk.sql`,
shipped as migration `0039_ecr_fix_history_original_entity_fk.sql`: all 13
history tables' `original_entity_id` FK is altered to
`DEFERRABLE INITIALLY DEFERRED` (checked at COMMIT, when the parent row exists).
Action clauses (`ON DELETE/UPDATE RESTRICT`) are untouched; referential
integrity is fully preserved — orphans are still rejected.

Verified: `ALTER TABLE ... ALTER CONSTRAINT ... DEFERRABLE INITIALLY DEFERRED`
executes cleanly and `pg_constraint` reports `condeferrable=t, condeferred=t`
for all 13 constraints.

---

## 7. Runtime verification environment

- Portable EDB PostgreSQL **17.4** (`postgresql-17.4-1-windows-x64-binaries.zip`)
  extracted to `%TEMP%\opencode\pgroot\pgsql\bin`, `initdb`'d at
  `%TEMP%\opencode\pgdata`, running on **127.0.0.1:5433** (trust, `postgres`).
- Test database **`fateen`** + role **`fateen_app`** bootstrapped manually (see
  finding F1 below).
- Migrations `0001`–`0039` applied via the repository's own
  `scripts/migrate.ps1` from an ASCII staging copy of `migrations/` (see
  finding F2 below). Ledger `schema_migrations` holds exactly 39 rows,
  contiguous `0001`–`0039`.
- Only `lifecycle_statuses` is seeded (from `0007`); all other lookup/reference
  tables were empty, so the runtime tests created minimal `t-*` test fixtures.

---

## 8. Runtime test matrix (all live)

### 8.1 Defect re-probe (the exact failing statement)

```sql
INSERT INTO products (internal_code, name, status_id)
VALUES ('probe-1', 'Probe Product', 1)
RETURNING id, internal_code, name, status_id, confidence_level, version_number;
```

| Assertion | Result |
| --------- | ------ |
| INSERT succeeds (pre-fix it failed) | **PASS** |
| Entity row: `confidence_level=0.5` (default), `version_number=1` | **PASS** |
| History row auto-created, `version_number=1`, `previous_version_id IS NULL` | **PASS** |
| `change_type='created'` | **PASS** |
| `internal_code/name/status_id/confidence_level` captured | **PASS** |
| `changed_by` SQL NULL (no actor supplied) | **PASS** |
| `created_at` matches entity `created_at` | **PASS** |
| `snapshot_hash`/`checksum` non-NULL, 64 hex chars | **PASS** |

### 8.2 Behavioral tests

| # | Test | Expected | Result |
| - | ---- | -------- | ------ |
| B | `UPDATE products SET name='Probe Product v2'` | entity `version_number→2`; new history row `version_number=2`, `change_type='modified'`, `previous_version_id` = row 1; row 1 unchanged | **PASS** |
| C | Re-run the *same* UPDATE (no-op, only `updated_at` changes) | **no** new history row; still 2 rows; entity stays version 2 | **PASS** |
| D1 | `UPDATE products_history ...` | rejected: `immutable history: UPDATE on products_history is not permitted` | **PASS** |
| D2 | `DELETE FROM products_history ...` | rejected: `immutable history: DELETE on products_history is not permitted` | **PASS** |

### 8.3 Full 13-owner sweep (companies, brands, products, ingredients,
allergens, health_flags, nutrition_types, product_categories,
ingredient_categories, images, barcodes, product_images, product_barcodes)

For each of the 13 tables (with minimal required parents seeded first):

| Assertion | Result |
| --------- | ------ |
| Authoritative owner set from `pg_trigger` = exactly these 13 | **PASS** |
| INSERT each → exactly **1** history row, `version_number=1` | **PASS (13/13)** |
| UPDATE each → exactly **2** history rows (`v1`,`v2`), **2 distinct** `snapshot_hash` | **PASS (13/13)** |
| Entity `version_number` mirrors history (`=2`) | **PASS (13/13)** |
| All 13 `original_entity_id` FKs `DEFERRABLE INITIALLY DEFERRED` | **PASS (13/13)** |

### 8.4 Endpoint validation (ECR-001 Blocker 2, live)

| Test | Expected | Result |
| ---- | -------- | ------ |
| `entity_relationships` with non-existent subject UUID | rejected: `entity_relationships: subject entity companies does not exist` | **PASS** |
| `entity_relationships` with real endpoints (`t-co` → `t-prod`) | accepted (`INSERT 0 1`) | **PASS** |
| Duplicate identical edge | rejected by `entity_relationships_edge_unique` | **PASS** |

### 8.5 Measurement basis natural key (live)

| Test | Expected | Result |
| ---- | -------- | ------ |
| INSERT `measurement_bases (code='t-mb', ...)` | accepted | **PASS** |
| INSERT duplicate `code='t-mb'` | rejected by `measurement_bases_code_unique` | **PASS** |

---

## 9. Validator results

`scripts/validate_foundation.ps1` was extended for ECR-003:

- `expectedPrefixes` now covers `0001`–`0039` (was `…0038`).
- New checks: fix migration `0038` present; corrected function binds values
  (`jsonb_populate_record` + `USING`, no `NEW.*` in dynamic SQL);
  changed_by mapping is NULL-safe (`COALESCE(to_jsonb(…), 'null'::jsonb)`);
  FK-deferral migration `0039` present; exactly 13 `original_entity_id` FKs
  made `DEFERRABLE INITIALLY DEFERRED`.

Result:

```text
Summary: 60 checks, 60 passed, 0 failed
```

---

## 10. Migration consistency

- `scripts/build_migrations.ps1` was re-run twice after the ECR-003 additions;
  regeneration is **byte-idempotent** — zero drift vs. the pre-regeneration
  staged copies for `0001`–`0037`, and stable `0038`/`0039`.
- Live ledger `schema_migrations` contains **39 rows**, contiguous
  `0001`–`0039`, applied through `scripts/migrate.ps1` (which verifies MD5
  content checksums and rejects tampering).
- No `0001`–`0037` file differs from its `schema/` source (validator + drift
  check both confirm).

---

## 11. Remaining limitations and findings

- **F1 — `scripts/create_database.sql` has a latent runtime defect.**
  psql does **not** interpolate `:'var'` inside `DO $$ … $$` dollar-quoted
  blocks, so the file fails at runtime
  (`ERROR: syntax error at or near ":"`). The live database was therefore
  bootstrapped manually (`CREATE ROLE fateen_app; CREATE DATABASE fateen
  OWNER fateen_app;`). Out of scope to fix here; recorded for a follow-up.
- **F2 — non-ASCII repository path vs. psql `\i`.** The repository lives under
  `…\OneDrive\المستندات\Default Project\`; `migrate.ps1` applies each
  migration by writing a `\i '<path>'` wrapper, and psql fails to read files
  whose path contains the Arabic characters (`No such file or directory`).
  Workaround: apply from an ASCII staging copy of `migrations/`
  (`-MigrationsDir %TEMP%\opencode\migs37`). Noted as an environment quirk.
- Runtime verification used minimal `t-*` fixtures (required by the empty
  lookup tables); no seed data was added to the schema.
- `snapshot_hash` is computed over the materialised `to_jsonb(NEW)` snapshot;
  its exact byte value depends on key ordering in `to_jsonb` output and is
  validated for *distinctness/immutability* here rather than cross-checked
  against a hand-rebuilt JSON document.

---

## 12. Certification trail

| Document | Reference |
| -------- | --------- |
| ECR-001 history capture (original, defective) | `schema/06-functions/03_capture_entity_history.sql`, migration `0036` |
| ECR-003 corrected function (fix 1) | `schema/06-functions/05_ecr_fix_capture_entity_history.sql`, migration `0038` |
| ECR-003 FK deferral (fix 3) | `schema/03-constraints/11_ecr_fix_history_original_entity_fk.sql`, migration `0039` |
| Capture triggers (unchanged) | `schema/07-triggers/09_ecr_capture_history.sql`, migration `0037` |
| Validator | `scripts/validate_foundation.ps1` — **60/60 PASS** |
| Build script (manifest) | `scripts/build_migrations.ps1` |
| Prior certification | `docs/ecr002_report.md`, `docs/ecr001_report.md` |

**Verdict: COMPLETE.** `capture_entity_history()` and the full history-capture
flow are verified working on live PostgreSQL across all 13 history-owning
tables; migrations `0001`–`0039` are applied, consistent, and regenerated
byte-idempotently; the validator is 60/60; the three live defects are fixed
additively without touching `0001`–`0037`.
