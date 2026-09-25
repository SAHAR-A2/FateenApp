# FATEEN Cloud Migration — Phase 0 Verification Report

- **Phase**: PHASE_0 (pre-migration backup + restore verification only)
- **Executed (UTC)**: 2026-09-13 22:16:38Z → 22:33:06Z
- **Backup directory**: `C:\fateen2\fateen backend\backups\cloud_pre_migration_20260913T221638Z\`
- **Verdict**: **PHASE_0_PASS**

---

## 1. Scope & hard constraints honoured

| Constraint | Status |
|---|---|
| No writes to Supabase (zero DML/DDL/ALTER/migrations/ingestion) | ✓ (all cloud access read-only; commands were `pg_dump`, `pg_restore --list`, readonly SQL) |
| No `.env` / `.env.database.url` / `.env.runtime.url` edits | ✓ (files unchanged) |
| Credentials never echoed or stored in artifacts | ✓ (URLs read inside scripts only; manifest stores masked host/labels) |
| No Phase 1 / Phase 5 work started | ✓ (stopped at Phase 0 verdict) |
| Local DB not modified | ✓ (no grants/DDL issued against `fateen` DB) |

## 2. Source systems

| System | Location | Access method |
|---|---|---|
| Cloud Supabase (project host, db `postgres`) | via `.env.database.url` (postgres pooler role) | `postgres:17` image `pg_dump` with `PGSSLMODE=require` |
| Cloud runtime role | via `.env.runtime.url` | read-only schema/ACL queries in prior sessions |
| Local FATEEN DB (db `fateen`) | Docker container `fateen-postgres` (image `postgres:17`) | `docker exec fateen-postgres pg_dump -U fateen` (superuser role `fateen`) |

## 3. Pre-dump row counts (captured 2026-09-13 22:16:38Z)

| Table | Cloud (expected) | Cloud (got) | Local (expected) | Local (got) |
|---|---|---|---|---|
| products | 105 | 105 | 1331 | 1331 |
| product_barcodes | 105 | 105 | 1329 | 1329 |
| product_ingredients | 805 | 805 | 818 | 818 |
| product_nutrition_values | 883 | 883 | 2226 | 2226 |
| product_allergens | 55 | 55 | 56 | 56 |
| ingredients | 225 | 225 | 289 | 289 |
| allergens | 10 | 10 | 11 | 11 |

## 4. Artifacts produced

| File | Bytes | SHA-256 |
|---|---|---|
| `cloud_pre.dump` | 1,132,235 | `2e4af766ff575e73b369b011b63c8a159e6d296f075689f00930f7d7ac314355` |
| `cloud_schema.sql` | 415,026 | `b07290895b10be89c7d5340db5a345ccfb63bc787cd57acbcb186259175db92f` |
| `cloud_data.sql` | 834,163 | `08200431692ffcdec7db3351e1264ba7b293384513090fa7ff9b789298151021` |
| `cloud_acl.json` | 27,458 | `955c5fa6818a93ab731e13fac22e7f54a71374144e3ac55c316d130c30f7e384` |
| `local_pre_migration.dump` | 1,870,596 | `f74f81a3a40dd07cb4c8e110011e90160251812407f54c6a94a5ef8b743be44b` |
| `manifest.json` | 2,165 | (machine-readable metadata + pre-counts) |
| `sha256.txt` | 543 | (full checksum manifest) |

Retention: `local_pre_migration.dump` generated on 2026-09-13 22:25Z by `docker exec fateen-postgres pg_dump -U fateen -d fateen -Fc`. Cloud dumps generated 22:16Z. Hashes re-verified post-copy (recomputed `local_pre_migration.dump` matches, see Section 9).

## 5. Cloud source read-only sanity (prior scene-set checks, reconfirmed)

- Cloud `created_at` range: 2026-08-11 → 2026-09-11 (pre-Phase-5 era); zero products ≥ 2026-09-13.
- `product_barcodes` join on cloud = 105 (consistent).
- 100/105 internal codes are `FATEEN_%`; newest 8 names are legacy (Crostini, Nutella, Krisprolls Sans sucre, Water Crackers, Sarah 100% Real Orange Juice, …).
- Cloud `schema_migrations` = 0 rows (migrations were applied outside this DB's ledger).
- Cloud schema: **90 public tables** (local 86); the 4 extra are collector tables `conflicts`, `markets`, `market_scopes`, `source_configs`. Core tables identical column-for-column.
- RLS enabled on all 90 public tables; **17 SELECT policies** for `fateen_app_read_only`; `fateen_app` has SELECT-only grants on exactly those 17 tables.
- Extensions superset on cloud: `pg_stat_statements`, `supabase_vault`, `uuid-ossp` (+ local set).

## 6. Cloud scratch restore verification

Scratch: Docker container `fateen-cloud-scratch` (`postgres:17`), 31 cloud roles bootstrapped (NOLOGIN) before restore. `pg_restore --no-owner` into `postgres` DB.

| Table | Expected | Restored | Match |
|---|---|---|---|
| products | 105 | 105 | ✓ |
| product_barcodes | 105 | 105 | ✓ |
| product_ingredients | 805 | 805 | ✓ |
| product_nutrition_values | 883 | 883 | ✓ |
| product_allergens | 55 | 55 | ✓ |
| ingredients | 225 | 225 | ✓ |
| allergens | 10 | 10 | ✓ |

Structural checks on restored cloud scratch: public RLS policies **17**, RLS-enabled tables **90**, non-internal triggers **83**, public functions **83**, public constraints **579**, indexes (products 5 / ingredients 3 / allergens 4 / product_barcodes 8), orphan `product_barcodes` **0**, orphan `product_ingredients` **0** (by product and by ingredient).

## 7. Allowed-only restore failures (Supabase infrastructure)

8 errors, all confined to the `supabase_vault` extension surface (extension not bundled in stock `postgres:17`, plus `vault.secrets` / vault functions). All are Supabase-platform-provided infra objects; **no application-schema object failed to restore**. No errors for tables, data, constraints, indexes, triggers, policies, or functions in `public`.

## 8. Local scratch restore verification

Scratch: Docker container `fateen-local-scratch` (`postgres:17`), local roles (`fateen`, `fateen_admin`, `fateen_app`, `fateen_test_app`) bootstrapped before restore.

| Table | Expected | Restored | Match |
|---|---|---|---|
| products | 1331 | 1331 | ✓ |
| product_barcodes | 1329 | 1329 | ✓ |
| product_ingredients | 818 | 818 | ✓ |
| product_nutrition_values | 2226 | 2226 | ✓ |
| product_allergens | 56 | 56 | ✓ |
| ingredients | 289 | 289 | ✓ |
| allergens | 11 | 11 | ✓ |

Local scratch restore completed with **zero errors**. Structural checks: RLS policies 0, RLS tables 0, triggers 83, functions 120, constraints 581, indexes identical (5/3/4/8), orphans 0.

## 9. Round-trip integrity

- `pg_restore --list` object inventory generated for both dumps (`pg_restore_list_cloud_pre.dump.txt`, `pg_restore_list_local_pre_migration.dump.txt`).
- Cloud dump TOC: policy entries **17**, sequence **7**, plus full table/constraint/index/trigger/comment population. Local dump TOC: no policies, sequences 2 (both lifecycle).
- Re-hash of `local_pre_migration.dump` post-`docker cp` equals the value recorded in `sha256.txt` → byte-for-byte integrity of the archive copy.
- All counts in Section 8 restored from the archive, not from a live re-query → the dump contains the full local dataset at capture time.

## 10. Storage & retention

- Single canonical backup tree `backups\cloud_pre_migration_20260913T221638Z\` containing artifacts, per-step logs (`logs\`), TOC listings, and both scratch verification reports (`phase0_cloud_scratch_report.json`, `phase0_local_scratch_report.json`).
- Scratch containers `fateen-cloud-scratch` / `fateen-local-scratch` left running for Phase 1 dependency dry-runs; safe to `docker rm -f` once no longer needed. Data inside is throwaway.

## 11. Risks & recommendations

| Risk | Mitigation |
|---|---|
| Cloud restore depends on roles existing | Roles bootstrapped from live cloud read-only query before restore (31 roles) |
| `supabase_vault` cannot be reproduced in stock PG17 scratch | Only infra object failed; app objects complete. If vault coverage is required, use Supabase's own restore tooling later |
| 7-count check covers the critical dataset only | Counts + constraints + orphan checks + RLS/trigger/function counts all matched expectations |
| Backup dir is inside the project tree | Consider a second copy to removable/object storage before Phase 1 begins |

## 12. What Phase 1 can assume

- `cloud_pre.dump` is a trustworthy pre-migration snapshot (verified 105/105/805/883/55/225/10 and full public schema with RLS).
- `local_pre_migration.dump` is a trustworthy pre-migration snapshot (verified 1331/1329/818/2226/56/289/11, zero-error restore).
- Any Phase 1 destructive step against Supabase can pull back `cloud_pre.dump` (DROP/recreate of `public` is recoverable).
- Strategy B (canonical snapshot restore) remains the approved path; Phase 1 may now proceed.

## 13. Verdict

**PHASE_0_PASS** — All required conditions met:

1. Cloud backup artifacts complete and hash-consistent (Section 4).
2. Local backup artifact complete and hash-consistent (Section 4).
3. Cloud dump restores to scratch with exact expected counts and structural checks (Section 6).
4. Only allowed Supabase-infra (`supabase_vault`) failures (Section 7).
5. Local dump restores to scratch with exact expected counts, zero errors (Section 8).
6. No writes of any kind to Supabase; no source edits (Section 1).

Stop here. Phase 1 (destructive cloud rebuild / schema replacement) is **not** authorized by this report; it requires explicit user instruction.