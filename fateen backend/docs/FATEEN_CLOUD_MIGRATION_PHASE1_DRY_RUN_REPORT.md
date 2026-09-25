# FATEEN Cloud Migration — Phase 1 Dry Run Report

- **Phase**: PHASE_1 DRY RUN (schema rebuild + data restore on scratch only)
- **Executed (UTC)**: 2026-09-14 00:16 → 01:12 (approximately)
- **Scratch containers**: `fateen-cloud-rebuild-scratch` (primary), `fateen-cloud-rebuild-scratch-2` (re-runability)
- **Backup dir reference**: `C:\fateen2\fateen backend\backups\cloud_pre_migration_20260913T221638Z\`
- **Verdict**: **PHASE_1_DRY_RUN_PASS**

---

## 1. Schema rebuild result: SCHEMA_REBUILD_MATCH

Fresh PostgreSQL 17 container (`fateen-cloud-rebuild-scratch`) with local application roles (`fateen`, `fateen_admin`, `fateen_app`, `fateen_test_app`) bootstrapped. Canonical schema restored via `pg_restore --schema-only --no-owner` from `local_pre_migration.dump` — **0 restore errors**.

Full inventory comparison local canonical vs scratch (12 categories):

| Category | Local | Scratch | Match |
|---|---|---|---|
| tables (public) | 86 | 86 | ✓ |
| columns + types | 1277 | 1277 | ✓ |
| column defaults | 443 | 443 | ✓ |
| primary keys | 86 | 86 | ✓ |
| foreign keys | 241 | 241 | ✓ |
| unique constraints | 77 | 77 | ✓ |
| check constraints | 176 | 176 | ✓ |
| indexes | 421 | 421 | ✓ |
| sequences | 1 (lifecycle_statuses_id_seq) | 1 | ✓ |
| enums | 58 | 58 | ✓ |
| functions (118 defs + 2 aggregates) | 120 | 120 | ✓ |
| triggers | 83 | 83 | ✓ |

**Result**: `SCHEMA_REBUILD_MATCH` — zero structural differences between local canonical and scratch.

## 2. Data restore result

`pg_restore --data-only --disable-triggers` (superuser) into schema-verified scratch. The `--disable-triggers` option was required because the schema-first + data-second two-phase approach loads data with FK constraints already active; without trigger disable, table-load order differences (pg_dump does not guarantee parent-before-child for data COPYs) would cause FK violations on history tables. This is expected for the two-phase dry-run methodology and does not apply to the real one-pass migration (`pg_restore` full dump into empty public schema).

- **Restore errors**: **0** (clean single load)
- **session_replication_role**: not explicitly set (pg_restore log did not surface the statement; `--disable-triggers` handled trigger suspension internally)
- **Evidence**: `fateen-cloud-rebuild-scratch-2` confirmed zero errors independently

## 3. Count comparison

| Table | Local canonical | Scratch | Match |
|---|---|---|---|
| products | 1331 | 1331 | ✓ |
| product_barcodes | 1329 | 1329 | ✓ |
| product_ingredients | 818 | 818 | ✓ |
| product_nutrition_values | 2226 | 2226 | ✓ |
| product_allergens | 56 | 56 | ✓ |
| ingredients | 289 | 289 | ✓ |
| allergens | 11 | 11 | ✓ |

## 4. ID comparison

### EXCEPT set comparison (id column, sorted by text)

| Table | Local IDs | Scratch IDs | Only-local | Only-scratch | Match |
|---|---|---|---|---|---|
| products | 1331 | 1331 | — | — | ✓ |
| product_barcodes | 1329 | 1329 | — | — | ✓ |
| ingredients | 289 | 289 | — | — | ✓ |
| allergens | 11 | 11 | — | — | ✓ |
| barcodes | (all) | (all) | — | — | ✓ |
| brands | (all) | (all) | — | — | ✓ |
| companies | (all) | (all) | — | — | ✓ |
| lifecycle_statuses | 3 | 3 | — | — | ✓ |
| nutrition_types | (all) | (all) | — | — | ✓ |
| units | (all) | (all) | — | — | ✓ |

### Min / max / count (core tables)

All 10 tables identical between local and scratch (min, max, count values match exactly).

## 5. Checksum comparison

**All 86 public tables** checked via `md5(string_agg(row_to_json(t)::text, '\n' ORDER BY row_to_json(t)::text))`.

**Result: 86/86 tables match. Zero mismatches.**

Content equality confirmed, not merely row counts.

## 6. FK integrity

Generic orphan scan across all 241 foreign key constraints in scratch.

**Result: 0 orphan rows across all constraints.** All relationships valid post-restore.

Specific checks also confirmed clean:
- `product_barcodes` orphan by `product_id`: 0
- `product_ingredients` orphan by `product_id`: 0
- `product_ingredients` orphan by `ingredient_id`: 0

## 7. Constraint integrity

163 unique/PK constraints scanned (all `convalidated=true` in canonical source).

| Check | Result |
|---|---|
| PK duplicates | 0 |
| UNIQUE duplicates (IS NOT NULL groups only — matches PG unique null semantics) | 0 |
| `product_barcodes` PK duplicate | 0 |
| `product_barcodes` duplicate links (product_id, barcode_id, relationship_type_id) | 0 |
| `barcodes.barcode` duplicate values | 0 |
| `product_ingredients` duplicate (product_id, ingredient_id) | 0 |
| `product_allergens` duplicate (product_id, allergen_id) | 0 |

Note: `product_nutrition_values` `fact_unique` constraint allows NULL values in the 4-column unique definition; `GROUP BY` comparison with `IS NOT NULL` guards shows 0 real constraint-violating duplicates. Local canonical data is clean and constraint-respecting.

## 8. Sequence / identity check

`lifecycle_statuses_id_seq` (the only sequence in the canonical public schema):

| Metric | Local | Scratch | Match |
|---|---|---|---|
| last_value | 3 | 3 | ✓ |
| is_called | t | t | ✓ |
| max(id) | 3 | 3 | ✓ |
| next_generated (last+1) | 4 | 4 | ✓ |
| next > max(id) | true | true | ✓ (no collision) |

Post-test note: the identity INSERT test consumed one nextval (3→4); sequence value was restored to 3 via `setval` (scratch only). The real migration will not need this adjustment.

## 9. Trigger check

- **Enabled state**: 0 disabled triggers in both local and scratch (all 83 triggers `tgenabled = 'O'`)
- **History-table checksums**: 13 history tables checked; **0 mismatches** between local and scratch → no history generated during data restore (confirms `--disable-triggers` was effective)
- **INSERT+ROLLBACK live test** (scratch only):
  - Inserted test allergen into `allergens` → `allergens_history` count went 11→12 (trigger `allergens_capture_history` fired)
  - Identity INSERT into `lifecycle_statuses` → returned fresh `id=4`, `max(id)` became 4 (no collision with existing max 3)
  - ROLLBACK completed; post-test counts identical to pre-test counts
  - **Zero test data persisted**

## 10. RLS / ACL findings

### Local canonical state
- RLS enabled tables: **0**
- RLS policies: **0**
- This is the canonical baseline (RLS not configured locally)

### Current cloud state
- RLS enabled tables: **90** (all public tables)
- RLS policies: **17** — all `fateen_app_read_only`, command `r` (SELECT), quality `true`, role `fateen_app`
- `fateen_app` SELECT-only grants on the same 17 tables

The 17 protected tables:
`allergens`, `barcodes`, `data_sources`, `evidence_types`, `health_flags`, `ingredients`, `lifecycle_statuses`, `measurement_bases`, `nutrition_types`, `product_allergens`, `product_barcodes`, `product_health_flags`, `product_ingredients`, `product_nutrition_values`, `products`, `relationship_types`, `units`

### Scratch rebuilt state
- RLS enabled tables: **0**
- RLS policies: **0**
- Confirmed clean (matches local canonical)

### Post-rebuild RLS recreation plan (requires separate approval)
After `DROP SCHEMA public CASCADE` + canonical restore, RLS and grants must be recreated in this order:
1. `ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;` — for all 90 public tables
2. `ALTER TABLE public.<table> FORCE ROW LEVEL SECURITY;` — optional, based on current cloud setting
3. `CREATE POLICY fateen_app_read_only ON public.<table> FOR SELECT TO fateen_app USING (true);` — for the 17 protected tables only
4. `GRANT SELECT ON public.<table> TO fateen_app;` — for the same 17 tables

**Do not decide to remove RLS from cloud without separate approval.**

## 11. Supabase-specific objects (not present in local canonical)

Classification from infrastructure-pattern scanning:

| Class | Objects / Schemas | Source |
|---|---|---|
| A: Fateen application schema | All 86 tables, 120 functions, 83 triggers, enums, sequences in `public` | `local_pre_migration.dump` (canonical) |
| B: Supabase cloud-only schemas | `auth`, `extensions`, `graphql`, `graphql_public`, `pgbouncer`, `realtime`, `storage`, `vault` | `cloud_acl.json` |
| B: Cloud-only extensions | `pg_stat_statements`, `supabase_vault`, `uuid-ossp` | `cloud_schema.sql` |
| B: Cloud-only roles | `supabase_admin`, `supabase_auth_admin`, `supabase_functions_admin`, `supabase_replication_admin`, `supabase_storage_admin`, `supabase_vault_admin`, `anon`, `authenticated`, `service_role`, `authenticator`, `pgbouncer`, `pgsodium_*`, `supabase_prisma_admin`, `supabase_realtime_admin`, `supabase_read_only_user` | live cloud query |
| A: Local canonical infra hits | **ZERO** — local contains no Supabase-specific objects | phase1_classification.json |

Cloud-only objects must be restored by Supabase's own tooling or manually after the canonical application schema is rebuilt; they are outside scope of this migration plan.

## 12. Risks discovered

| Risk | Severity | Mitigation |
|---|---|---|
| `--disable-triggers` required for two-phase (schema-first) restore | Medium | Real migration uses one-pass full restore (schema+data together) where this issue does not arise; `--disable-triggers` logged and all post-restore triggers verified functional |
| `supabase_vault` extension unavailable on stock PostgreSQL 17 | Low | Supabase-infra; must be restored via Supabase platform tooling |
| RLS disabled in local canonical vs enabled on cloud | Medium | Requires explicit recreation script post-rebuild (Section 10 plan); do not drop RLS from cloud without separate approval |
| Sequence nextval non-transactional | Low | Live test consumed one seq value; restored via `setval` on scratch; not relevant to real migration data |

## 13. Exact differences requiring attention

| Item | Local Canonical | Cloud Current | Action Required |
|---|---|---|---|
| RLS policies | 0 | 17 (`fateen_app_read_only` SELECT) | Recreate after rebuild (Section 10) |
| RLS enabled tables | 0 | 90 | Recreate after rebuild |
| `fateen_app` SELECT grants | none documented | 17 tables | Re-apply after rebuild |
| Supabase infra schemas | not present | 8 schemas | Restore via Supabase platform |
| Cloud-only extensions | not present | `supabase_vault`, `pg_stat_statements`, `uuid-ossp` | Restore via Supabase platform |
| Schema migration ledger | local has 50 entries (`0000`→`0051`) | cloud `schema_migrations` = 0 rows | Cloud ledger will be populated during canonical rebuild or via Supabase migration tooling |
| Collector tables (4) | not in local (local has 86 tables) | cloud has 90 tables (`conflicts`, `markets`, `market_scopes`, `source_configs`) | Local canonical does not include these; they are cloud-originated. Retained separately if needed. |

## 14. Supabase received ZERO writes

| Step | Target | Operation | Result |
|---|---|---|---|
| All scratch operations | `fateen-cloud-rebuild-scratch`, `fateen-cloud-rebuild-scratch-2` | `pg_restore` / SQL | Local Docker only |
| Cloud read-only queries (prior sessions) | Supabase | `SELECT` only | No mutations |
| `local_pre_migration.dump` | local via `docker exec` | `pg_dump` | Local container only |
| No operations performed on real Supabase throughout Phase 1 | — | — | **Confirmed zero writes** |

---

## Final verdict

**PHASE_1_DRY_RUN_PASS**

All conditions met:
1. ✅ Canonical schema rebuild succeeded — `SCHEMA_REBUILD_MATCH` (12/12 categories)
2. ✅ Local data restore succeeded — 0 errors, IDs preserved
3. ✅ All counts match (7/7 core tables)
4. ✅ ID sets match (10/10 core tables EXCEPT = empty)
5. ✅ Checksums match (86/86 tables)
6. ✅ FK integrity — 0 orphans across 241 constraints
7. ✅ Constraint integrity — 0 duplicates (163 constraints scanned)
8. ✅ Identity (`lifecycle_statuses_id_seq`) — match, no collision
9. ✅ Triggers — all 83 enabled, 0 history generated during restore, INSERT+ROLLBACK test passed
10. ✅ RLS/ACL — local baseline documented, cloud recreation plan defined, no removal without approval
11. ✅ Re-runability — fresh scratch#2 reproduced schema+data+counts independently
12. ✅ Zero test data persisted after rollback
13. ✅ Supabase cloud received **zero writes**

**Stop here. Phase 2 (destructive cloud rebuild / real execution) requires explicit user approval.**