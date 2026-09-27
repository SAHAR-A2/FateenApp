# Schema migration governance

This repository is the single source of truth for the FATEEN schema. A
database is correct when `scripts/migrate.py status` reports `consistent`
against it.

## Tooling

```bash
# Read-only: compare a database ledger with migrations/
MIGRATION_DATABASE_URL=... python scripts/migrate.py status

# Apply pending migrations in order (refuses while the ledger has drifted)
MIGRATION_DATABASE_URL=... python scripts/migrate.py apply [--to FILE] [--dry-run]

# Throwaway local database for tests and development
scripts/bootstrap_test_db.sh postgresql://user:pass@localhost:5432/fateen_test
```

`MIGRATION_DATABASE_URL` must be a schema-owner role, not the `fateen_app`
runtime role.

## Ledger rules

- Ledger table: `public.schema_migrations(version, checksum, applied_at)`.
- `version` is the file name. `checksum` is the lowercase MD5 of the file.
  This is the format the legacy `migrate.ps1` used for 0001-0039.
- A ledger row is written only by the request that ran the file, and only
  after every statement in it succeeded. Nothing records a migration without
  running it, so do not insert ledger rows by hand to make counts match.
- Migrations are immutable once applied. `status` reports `MODIFIED` when a
  file's bytes no longer match the ledger. Ship a new migration instead of
  editing an old one.
- `0042` and `0043` register themselves under their stem, with a label such as
  `fateen-pilot-0042-v1` instead of an MD5. The runner accepts those rows and
  reports that their checksum cannot be verified. New migrations must not
  write to the ledger themselves.
- `0000_recovered_baseline.sql` is a `pg_dump` of the schema that the legacy
  chain `0001`-`0039` plus `002_collector_tables` produced. If a ledger
  already holds that whole chain, as Cloud does, the baseline counts as
  applied there. It is never re-run and no row is invented for it.

## Known gap: migrations applied to Cloud but missing here

`docs/phase5c_phase6_cloud_introspection.json` holds a read-only snapshot of
the Cloud ledger (51 rows, taken as `fateen_app` on PostgreSQL 17.6).
`tests/test_migrate_runner.py` replays that snapshot through the runner,
which reports:

| Cloud ledger version | In this repository? |
|----------------------|---------------------|
| `0001_...` - `0039_...`, `002_collector_tables` | Yes: legacy chain, covered by `0000_recovered_baseline.sql` |
| `0040_security_hardening.sql` | **No** |
| `0041` | **No** (recorded without a name) |
| `0042_pilot_source_priorities_seed`, `0043_pilot_provider_failure_statuses` | Yes (self-registered) |
| `0044_open_food_facts_source` | **No** |
| `0045_open_food_facts_reference_ingredients` | **No** |
| `0046_off_nutrition_reference_salt` | **No** |
| `0048_off_pilot_reference_ingredients` ... `0050_...` | **No** |
| `0051_off_pilot_reference_ingredients.sql` | **No** |
| `0052` (fateen_app write grants, Phase 12; applied after the snapshot) | **No**. `0053` cites it |

Two points follow from the snapshot:

- `0047_sfda_quarantine_candidates` was never applied, which matches
  `app/batch/`, and it is not in the repository either.
- `003_pilot_constraints.sql` is **not** in the Cloud ledger. `status` shows
  it as `PENDING` there. `0043` rebuilds two of its constraints, so check
  with `\d scan_job_items` before applying it. If a constraint already
  exists, `apply` fails and rolls back that file; nothing is half-applied.

The missing files live in the `fateen_release_audit` working tree. Until
they are committed to `migrations/` byte for byte:

- `status` against Cloud reports them as `NOT IN REPO`, and `apply` refuses
  to run. This is intentional.
- A database built from this repository alone does not match Cloud. It lacks
  the OFF source, the salt/ingredient reference rows (0044-0051) and, without
  `0052`, the `fateen_app` write grants.

Migrations added in this repository after that snapshot:

- `0054_product_completeness_view.sql`: additive, read-only review-queue
  view. It is safe to apply once the gap below is closed.

To close the gap:

1. Copy each missing file from `fateen_release_audit/migrations/` without
   changing a byte.
2. Run `python scripts/migrate.py status` against Cloud with a read-only or
   owner URL (`scripts/cloud_readonly_report.py` runs it together with the
   audit and the seed export). Every repository file should show `APPLIED`, with no
   `NOT IN REPO` or `MODIFIED` rows.
3. Commit the files together with that status output.

The same applies to the Cloud reference data: units, nutrition types,
ingredient grammar and data sources. Export it read-only with
`scripts/export_reference_seed.py --database-url <cloud> --out
seed/reference_data.sql` and commit the result. A fresh environment is then
rebuilt as: baseline, seed, `migrate.py apply`
(`tests/test_reference_seed.py` proves this round trip). The test fixtures
in `tests/fixtures/` are not that seed.

## Local vs Cloud PostgreSQL versions

The baseline was dumped from PostgreSQL 17. On older servers the runner
drops the PG17-only `SET transaction_timeout`. On every server it drops the
psql `\restrict` meta-command lines. Both changes affect only the SQL sent
to the server; the checksum is still taken from the unmodified file.
