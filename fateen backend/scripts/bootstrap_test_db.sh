#!/usr/bin/env bash
# Build a throwaway FATEEN database for tests and local development:
#   baseline -> archived pilot fixture -> remaining migrations -> synthetic fixture
#
# Usage: scripts/bootstrap_test_db.sh postgresql://user:pass@localhost:5432/fateen_test
# The target database must exist and be empty. Refuses anything but a local host.
set -euo pipefail

URL="${1:-${DATABASE_URL:-}}"
if [[ -z "$URL" ]]; then
  echo "usage: $0 DATABASE_URL" >&2
  exit 2
fi
case "$URL" in
  *@localhost[:/]*|*@127.0.0.1[:/]*|*@postgres[:/]*) ;;
  *) echo "Refusing: $0 only targets a local test database (localhost/127.0.0.1/postgres)." >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PY="${PYTHON:-python}"
cd "$HERE"

# 0053 grants to the runtime role; create it (without login) if absent.
psql "$URL" -v ON_ERROR_STOP=1 -q -c \
  "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fateen_app') THEN CREATE ROLE fateen_app NOLOGIN; END IF; END \$\$;"

"$PY" scripts/migrate.py apply --database-url "$URL" --to 0000_recovered_baseline.sql
psql "$URL" -v ON_ERROR_STOP=1 -q -o /dev/null -f tests/fixtures/01_archive_pilot_data.sql
"$PY" scripts/migrate.py apply --database-url "$URL"
psql "$URL" -v ON_ERROR_STOP=1 -q -f tests/fixtures/02_synthetic_test_data.sql
"$PY" scripts/migrate.py status --database-url "$URL"
