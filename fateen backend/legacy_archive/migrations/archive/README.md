# Archive

Immutable record of previously shipped migrations. Files here are never
re-executed and never modified. New migrations always go in the parent `migrations/`
folder with a higher prefix.

## Collector migrations moved out of `migrations/`

- `001_collector_tables.sql` was never applied to any database (see
  `docs/PHASE8_CODE_INVENTORY.md`). It conflicts with the baseline and fails on
  it (`companies.status` does not exist).
- `002_collector_tables.sql` was applied on 2026-08-18 and is recorded in the
  ledger as `002_collector_tables`. Its schema is already part of
  `migrations/0000_recovered_baseline.sql`, so it must not run again after the
  baseline. `scripts/migrate.py` counts it as part of the legacy chain.
