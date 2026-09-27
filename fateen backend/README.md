# FATEEN backend

FastAPI service over the FateenDB PostgreSQL schema. It serves product
search, barcode details, compatibility checks (allergies and conditions) and
safe alternatives to the Flutter app (`../fateen1`).

## Run the tests locally

You need Python 3.11+ and a local PostgreSQL 16 or 17 with `psql`.

```bash
pip install -r requirements.txt
createdb fateen_test
scripts/bootstrap_test_db.sh postgresql://USER:PASS@localhost:5432/fateen_test
DATABASE_URL=postgresql://USER:PASS@localhost:5432/fateen_test python -m pytest -q
```

`bootstrap_test_db.sh` builds the schema from `migrations/` and loads
`tests/fixtures/`. The fixtures are test data only (see their README). CI
(`.github/workflows/ci.yml` at the repository root) runs the same steps on
PostgreSQL 17.

## Run the API

```bash
DATABASE_URL=... uvicorn app.main:app --reload          # full internal surface, /docs
DATABASE_URL=... uvicorn app.public_gateway:app         # what production exposes
```

`app.public_gateway` exposes only `/health`, search, barcode lookup,
product details, and the authenticated compatibility and alternatives
routes. Everything else returns 404: ingestion, scan, companies, review,
dashboards and docs. The Docker image runs the public gateway. Deployment
steps are in `../TEAM_DEPLOYMENT.md`.

Configuration is read from the environment or a local `.env`. See
`.env.example` for the variables. Never commit `.env` files. In production
the process refuses to start without `AGENT_INGEST_API_KEY` and explicit
`CORS_ALLOWED_ORIGINS`, and refuses the `postgres`/`fateen` superuser roles.

## Database migrations

```bash
MIGRATION_DATABASE_URL=... python scripts/migrate.py status
MIGRATION_DATABASE_URL=... python scripts/migrate.py apply
```

Read `docs/MIGRATIONS_GOVERNANCE.md` before running `apply` against Cloud.
Some migrations applied to Cloud are not in this repository yet, and the
runner refuses to apply until they are.

## Data-quality tools (read-only)

```bash
python scripts/db_audit.py --database-url URL        # invalid barcodes, impossible or all-zero nutrition, ...
python scripts/export_reference_seed.py --database-url URL --out seed/reference_data.sql
```

To run every read-only Cloud check at once (status, audit, seed export) and
save the results in one folder:

```bash
CLOUD_DATABASE_URL=... python scripts/cloud_readonly_report.py
```

It switches every connection to `default_transaction_read_only`, so
PostgreSQL rejects any write. Cloud sessions of Claude Code cannot open a
PostgreSQL connection (their network allows HTTPS only), so run it from a
machine that can reach the database.

Both scripts run in a `READ ONLY` transaction, so they are safe against
Cloud. The exported seed holds lookup and vocabulary tables only and can
rebuild a fresh environment: baseline, then the seed, then `migrate.py apply`.

## Safety rules the code enforces

- Compatibility never reports SAFE without evidence. An unmapped or
  unverified allergy tag gives UNKNOWN. A product with no ingredient list and
  no allergen data gives INSUFFICIENT_DATA for an allergic user.
- Alternatives are only products that the same compatibility check confirms
  SAFE.
- Missing nutrition is absent, never `0`.
- Products with missing fields are kept. `GET /api/v1/review/summary` and
  `GET /api/v1/review/products?missing=barcode` (internal, API key) list
  what each product still needs, from the `product_completeness` view
  (migration 0054).
