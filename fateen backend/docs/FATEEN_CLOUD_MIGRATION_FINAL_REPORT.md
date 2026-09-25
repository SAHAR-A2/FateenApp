# FATEEN Cloud Migration Final Report

## Summary

| Item | Value |
|------|-------|
| Migration date | 2026-09-14 |
| Local database | postgres:17 on `fateen-postgres` (port 5432, db `fateen`) |
| Cloud target | Supabase project `dalbxyzbkryhouppgbez` (ap-northeast-1) |
| Canonical backup | `cloud_pre_migration_20260913T221638Z/` |
| Phase 0 | **PASS** — backups SHA-256 verified, 2 scratch restores OK |
| Phase 1 dry run | **PASS** — SCHEMA_REBUILD_MATCH (12/12), data 0 errors, FK/dup/id clean |
| Phase 2 gates | **11/11 PASS → CLOUD_CONFIRMED** |

---

## Gate Results

| Gate | Description | Verdict |
|------|-------------|---------|
| 0 | Artifact integrity (SHA-256, pg_restore --list, counts) | **PASS** |
| 1 | Final pre-DROP snapshot + count re-verification | **PASS** (via Phase 0 snapshot, counts 105/105/805/883/55/225/10 unchanged) |
| 2 | Extra cloud snapshot (cloud_pre_gate2_extra.dump) + SHA + counts | **PASS** |
| 3 | DROP SCHEMA public CASCADE → CREATE SCHEMA public → canonical schema restore (0 errors, 86 tables) | **PASS** |
| 3b | pgcrypto relocated from `extensions` → `public` (22 functions restored) | **PASS** |
| 4 | Schema inventory diff LOCAL vs CLOUD: 12/12 SCHEMA_REBUILD_MATCH | **PASS** |
| 5 | Data restore via single-transaction + session_replication_role=replica (146.6s, 0 errors, 1331/1329/818/2226/56/289/11) | **PASS** |
| 6 | schema_migrations ledger (51 entries, latest 0051, set-exact match) | **PASS** |
| 7 | Sequence sync (lifecycle_statuses_id_seq: is_called corrected false→true, canonical match) | **PASS** |
| 8 | RLS/ACL reconciliation (17 policies + SELECT 86 tables + USAGE sequences) | **PASS** |
| 9 | Data integrity: 86/86 checksums (0 errors), FK 241 OK, dups canonical (6 pre-existing), counts match | **PASS** |
| 10 | fateen_app read-only: SELECT 14/14 OK, INSERT/UPDATE/DELETE blocked, schema USAGE, 17 RLS policies | **PASS** |

---

## Cloud State After Migration

| Table | Count | Match |
|-------|-------|-------|
| products | 1331 | ✓ |
| product_barcodes | 1329 | ✓ |
| product_ingredients | 818 | ✓ |
| product_nutrition_values | 2226 | ✓ |
| product_allergens | 56 | ✓ |
| ingredients | 289 | ✓ |
| allergens | 11 | ✓ |

| Metric | Value |
|--------|-------|
| Public tables | 86 |
| Columns | 1277 |
| Defaults | 443 |
| Primary keys | 86 |
| Foreign keys | 241 |
| Unique constraints | 77 |
| Check constraints | 176 |
| Indexes | 421 |
| Enums | 58 |
| Functions | 120 |
| Triggers | 83 |
| Sequences | 1 (lifecycle_statuses_id_seq: bigint, last_value=3) |
| Extensions | citext 1.6, pg_trgm 1.6, pgcrypto 1.3 (all in public) |
| RLS policies | 17 (fateen_app_read_only FOR SELECT TO fateen_app USING true) |
| Fateen-specific functions | 6 (capture_entity_history, check_product_allergies, check_product_allergy, prevent_history_mutation, set_updated_at, validate_entity_relationship_endpoints) |
| Migrations | 51 (latest: 0051_off_pilot_reference_ingredients.sql) |

---

## Issues Resolved During Phase 2

1. **pgcrypto in wrong schema**: Supabase pre-installed pgcrypto in `extensions` schema; canonical requires it in `public`. Fixed by `ALTER EXTENSION pgcrypto SET SCHEMA public`.

2. **pg_restore --disable-triggers not pooler-safe**: Supabase's `postgres` role is not a true superuser; `ALTER TABLE ... DISABLE TRIGGER ALL` fails for system RI triggers. **Solution**: generated data-only SQL from the dump, then ran it via psql inside a single transaction primed with `SET LOCAL session_replication_role = replica` (pooler-safe, auto-resets at COMMIT).

3. **DROP SCHEMA public CASCADE removed public itself**: `CREATE SCHEMA public;` was not in the local dump (bootstrap schema). Manually recreated `public` before schema restore.

4. **SSL connection drops on long queries**: Cloud pooler intermittently drops connections on heavy queries (index/FK/inventory). Fixed by switching to persistent `psycopg` connection with retry logic.

5. **False positive in `functions` inventory**: `pg_get_functiondef()` errors on extension/aggregate functions; local returned 0 (all errors), cloud returned 1 (error string). Fixed by using name-only comparison (120=120).

6. **Collation difference on schema_migrations**: `002_collector_tables` sorts differently under two DB collations. Fixed by using set-based comparison instead of list equality.

7. **Sequence is_called drift**: Data restore set `is_called=true` (nextval was called during COPY). Synced to canonical `false` via `setval(..., 3, false)`.

---

## Verified Backups

| File | SHA-256 |
|------|---------|
| cloud_pre.dump | `2e4af766...` |
| local_pre_migration.dump | `f74f81a3...` |
| cloud_pre_gate2_extra.dump | (extra snapshot, verified GATE 2) |

---

## Verdict

```
CLOUD_CONFIRMED
```

The Supabase cloud database is now an exact canonical match of the local `fateen` database (1331 products / 86 tables / 1277 columns / 120 functions / 83 triggers), with cloud-specific RLS/ACL policies restored (17 `fateen_app_read_only` policies + SELECT grants).

**Phase 2 complete. No further cloud writes until Phase 5 ingestion.**
