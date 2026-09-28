"""export_reference_seed.py round trip: export -> fresh database -> same rows."""
import importlib.util
import subprocess
import sys
import uuid
from pathlib import Path

import psycopg
import pytest
from psycopg.conninfo import conninfo_to_dict, make_conninfo

from app.core.config import settings

BACKEND = Path(__file__).resolve().parent.parent


def _load(name):
    spec = importlib.util.spec_from_file_location(name, BACKEND / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


export_reference_seed = _load("export_reference_seed")
migrate = _load("migrate")


def _counts(url, tables):
    with psycopg.connect(url) as conn:
        return {
            t: conn.execute(f"SELECT count(*) FROM public.{t}").fetchone()[0] for t in tables
        }


@pytest.fixture
def scratch_db():
    admin = make_conninfo(settings.database_url, dbname="postgres")
    name = f"fateen_seed_{uuid.uuid4().hex[:8]}"
    try:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(f'CREATE DATABASE "{name}"')
    except psycopg.Error as exc:  # pragma: no cover - environment-dependent
        pytest.skip(f"cannot create a scratch database: {exc}")
    try:
        yield make_conninfo(settings.database_url, dbname=name)
    finally:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')


@pytest.mark.integration
def test_seed_rebuilds_reference_data(tmp_path, scratch_db):
    seed = tmp_path / "reference_data.sql"
    seed.write_text(export_reference_seed.export(settings.database_url), encoding="utf-8")
    text = seed.read_text(encoding="utf-8")
    assert "INSERT INTO public.products " not in text
    assert "ON CONFLICT DO NOTHING" in text

    assert migrate.main(["apply", "--database-url", scratch_db, "--to", migrate.BASELINE]) == 0
    load = ["psql", scratch_db, "-v", "ON_ERROR_STOP=1", "-q", "-f", str(seed)]
    subprocess.run(load, check=True, capture_output=True)
    assert migrate.main(["apply", "--database-url", scratch_db]) == 0

    tables = [t for t in export_reference_seed.REFERENCE_TABLES
              if f"-- {t} (" in text]
    assert _counts(scratch_db, tables) == _counts(settings.database_url, tables)

    # Idempotent: a second load changes nothing.
    subprocess.run(load, check=True, capture_output=True)
    assert _counts(scratch_db, tables) == _counts(settings.database_url, tables)

    # The source user's host/port are reused; only the database differs.
    assert conninfo_to_dict(scratch_db)["dbname"].startswith("fateen_seed_")
