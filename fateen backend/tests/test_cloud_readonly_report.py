"""scripts/cloud_readonly_report.py runs all read-only checks and cannot write."""
import importlib.util
import json
import sys
from pathlib import Path

import psycopg
import pytest

from app.core.config import settings

_SPEC = importlib.util.spec_from_file_location(
    "cloud_readonly_report",
    Path(__file__).resolve().parent.parent / "scripts" / "cloud_readonly_report.py",
)
report = importlib.util.module_from_spec(_SPEC)
sys.modules["cloud_readonly_report"] = report
_SPEC.loader.exec_module(report)


@pytest.fixture
def url():
    try:
        psycopg.connect(settings.database_url, connect_timeout=5).close()
    except psycopg.OperationalError as exc:  # pragma: no cover
        pytest.skip(f"database unavailable: {exc}")
    return settings.database_url


@pytest.mark.integration
def test_connections_reject_writes(url):
    with report._read_only_connect(url) as conn:
        with pytest.raises(psycopg.errors.ReadOnlySqlTransaction):
            conn.execute("CREATE TABLE public.cloud_report_must_not_exist (x int)")


@pytest.mark.integration
def test_report_writes_every_result(url, tmp_path, monkeypatch):
    monkeypatch.setattr(psycopg, "connect", report._real_connect)
    try:
        assert report.main(["--database-url", url, "--out", str(tmp_path)]) == 0
    finally:
        psycopg.connect = report._real_connect
    for name in ("meta.txt", "status.txt", "audit.txt", "audit.json", "reference_data.sql"):
        assert (tmp_path / name).stat().st_size > 0, name
    assert "Result:" in (tmp_path / "status.txt").read_text()
    assert "invalid_gtin_check_digit" in json.loads((tmp_path / "audit.json").read_text())
    assert "COMMIT;" in (tmp_path / "reference_data.sql").read_text()
    assert "(verified)" in (tmp_path / "meta.txt").read_text()
