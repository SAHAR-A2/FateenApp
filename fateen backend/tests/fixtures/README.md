# Test database fixtures

Test data only. Nothing here may be loaded into Cloud.

`scripts/bootstrap_test_db.sh <local-url>` builds a test database in this order:

1. `migrations/0000_recovered_baseline.sql`: schema only
2. `01_archive_pilot_data.sql`: reference lookups and the August 2026 pilot
   products (7 synthetic `6281000000xxx` barcodes)
3. the remaining `migrations/`: 0042 needs the lifecycle statuses from step 2
4. `02_synthetic_test_data.sql`: rows the code relies on that the archive
   predates

## How `01_archive_pilot_data.sql` was built

1. Apply the baseline to an empty database.
2. Load the `public.*` data blocks from these `legacy_archive/backup/` files,
   with `session_replication_role = replica`:
   - `supabase_before_fateen_import.sql`
   - `fateen_data_full.sql`
   - `missing_data.sql`
   - `barcodes_product_barcodes.sql` (UTF-16, converted to UTF-8)
3. Run `legacy_archive/migrations/archive/002_collector_tables.sql` for its
   seed rows: health conditions, nutrition rules and unit conversions. The
   baseline dump has the schema but not these rows.
4. `pg_dump --data-only --column-inserts --exclude-table=public.schema_migrations`.
   Strip the psql 17 `\restrict` lines. Set `lifecycle_statuses_id_seq` from
   `max(id)` instead of the dump's stale value.

## Why not use the Cloud reference data?

Cloud holds the current reference data (units, nutrition types, ingredient
grammar, OFF sources, and so on). That data is not in this repository yet,
and this fixture does not reproduce it. See `docs/MIGRATIONS_GOVERNANCE.md`.
