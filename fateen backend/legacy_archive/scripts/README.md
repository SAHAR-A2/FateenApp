# Scripts

Operational helpers executed via `psql` / PowerShell.

| Script                        | Purpose |
| ----------------------------- | ------- |
| `build_migrations.ps1`        | Regenerate `migrations/NNNN_*.sql` from the canonical `schema/` tree (`ADR-004`). |
| `create_database.sql`         | Idempotently create the Fateen database and owner role (bootstrap, not numbered). |
| `migrate.ps1`                 | Apply migrations in numeric order, atomically, with a checksum-verified ledger. |
| `drop_database.sql`           | Idempotent teardown of the database and role — **development only**. |
| `seed.*` (planned)            | Seed runner — ships with the Phase 8 seed milestone. |

## Typical workflow

```powershell
# 1. Bootstrap (as a superuser against the maintenance DB)
psql -v db_name=fateen -v db_owner=fateen_app -f scripts/create_database.sql postgres

# 2. Migrate (as the owner / a privileged user)
powershell -ExecutionPolicy Bypass -File scripts/migrate.ps1 -Database fateen

# 3. After editing schema/ (never after a migration has shipped)
powershell -ExecutionPolicy Bypass -File scripts/build_migrations.ps1
```

## Connection

`migrate.ps1` and the `psql` invocations use standard libpq environment:
`PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` (or `~/.pgpass`). Passwords are never
stored in this repository.

## Migration safety

- Each migration applies inside one transaction (`--single-transaction`); a
  failure rolls the whole migration back and records nothing.
- The `schema_migrations` ledger stores an MD5 of each applied migration's bytes.
  An edited applied migration fails the checksum and stops the run
  (immutability enforcement, `ADR-004`).
