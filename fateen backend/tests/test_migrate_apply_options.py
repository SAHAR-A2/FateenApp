"""migrate.py apply --accept-not-in-repo / --skip on a Cloud-like ledger (scratch DB)."""
import importlib.util
import subprocess
import sys
import uuid
from pathlib import Path

import psycopg
import pytest
from psycopg.conninfo import make_conninfo

from app.core.config import settings

_SPEC = importlib.util.spec_from_file_location(
    "migrate", Path(__file__).resolve().parent.parent / "scripts" / "migrate.py"
)
migrate = importlib.util.module_from_spec(_SPEC)
sys.modules["migrate"] = migrate
_SPEC.loader.exec_module(migrate)

UNKNOWN = ["0040_security_hardening.sql", "0052_restore_fateen_app_write_path.sql"]


@pytest.fixture
def cloud_like_db():
    """Baseline, the archived pilot reference data, 0042/0043 (003 skipped),
    and two ledger rows with no file here."""
    admin = make_conninfo(settings.database_url, dbname="postgres")
    name = f"fateen_mig_{uuid.uuid4().hex[:8]}"
    try:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(f'CREATE DATABASE "{name}"')
    except psycopg.Error as exc:  # pragma: no cover - environment-dependent
        pytest.skip(f"cannot create a scratch database: {exc}")
    url = make_conninfo(settings.database_url, dbname=name)
    try:
        with psycopg.connect(url, autocommit=True) as conn:
            conn.execute(
                "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fateen_app') "
                "THEN CREATE ROLE fateen_app NOLOGIN; END IF; END $$;"
            )
        assert migrate.main(["apply", "--database-url", url, "--to", migrate.BASELINE]) == 0
        fixture = migrate.BACKEND_ROOT / "tests" / "fixtures" / "01_archive_pilot_data.sql"
        subprocess.run(["psql", url, "-v", "ON_ERROR_STOP=1", "-q", "-o", "/dev/null", "-f", str(fixture)],
                       check=True, capture_output=True)
        assert migrate.main(["apply", "--database-url", url, "--to", "0043_pilot_provider_failure_statuses.sql",
                             "--skip", "003_pilot_constraints.sql"]) == 0
        with psycopg.connect(url, autocommit=True) as conn:
            for v in UNKNOWN:
                conn.execute("INSERT INTO public.schema_migrations (version, checksum) VALUES (%s, 'x')", (v,))
        yield url
    finally:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')


def _ledger(url):
    with psycopg.connect(url) as conn:
        return {r[0] for r in conn.execute("SELECT version FROM public.schema_migrations")}


@pytest.mark.integration
def test_refuses_without_acknowledging_the_missing_files(cloud_like_db):
    assert migrate.main(["apply", "--database-url", cloud_like_db]) == 1


@pytest.mark.integration
def test_refuses_a_partial_acknowledgement(cloud_like_db):
    before = _ledger(cloud_like_db)
    assert migrate.main(["apply", "--database-url", cloud_like_db,
                         "--accept-not-in-repo", UNKNOWN[0]]) == 1
    assert _ledger(cloud_like_db) == before


@pytest.mark.integration
def test_applies_with_exact_acknowledgement_and_skip(cloud_like_db):
    assert migrate.main(["apply", "--database-url", cloud_like_db,
                         "--accept-not-in-repo", *UNKNOWN,
                         "--skip", "003_pilot_constraints.sql"]) == 0
    ledger = _ledger(cloud_like_db)
    assert "0055_allergens_and_health_rules.sql" in ledger
    assert "003_pilot_constraints.sql" not in ledger  # skipped, still pending


def test_skip_must_name_a_pending_migration(cloud_like_db):
    with pytest.raises(SystemExit, match="not a pending migration"):
        migrate.main(["apply", "--database-url", cloud_like_db, "--accept-not-in-repo", *UNKNOWN,
                      "--skip", "0000_recovered_baseline.sql"])
