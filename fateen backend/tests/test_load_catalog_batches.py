"""load_catalog.main: batches, and a dropped connection retried (real DB)."""
import importlib.util
import json
import sys
from pathlib import Path

import psycopg
import pytest

from app.core.config import settings

_SPEC = importlib.util.spec_from_file_location(
    "load_catalog_main", Path(__file__).resolve().parent.parent / "scripts" / "load_catalog.py")
loader = importlib.util.module_from_spec(_SPEC)
sys.modules["load_catalog_main"] = loader
_SPEC.loader.exec_module(loader)


def _entry(barcode):
    return {"barcode": barcode, "name_ar": "منتج", "name_ar_status": "approved", "source": "OPEN_FOOD_FACTS"}


@pytest.mark.integration
def test_preview_in_batches_survives_a_dropped_connection(tmp_path, monkeypatch):
    try:
        psycopg.connect(settings.database_url, connect_timeout=5).close()
    except psycopg.OperationalError as exc:  # pragma: no cover
        pytest.skip(f"database unavailable: {exc}")
    manifest = tmp_path / "m.json"
    manifest.write_text(json.dumps([_entry("6281007031585"), _entry("6281007053662"), _entry("123")]))
    real, calls = loader._run_batch, []

    def flaky(conn, refs, batch, corrections=None):
        calls.append(len(batch))
        if len(calls) == 1:
            raise psycopg.OperationalError("the connection is lost")
        return real(conn, refs, batch, corrections)

    monkeypatch.setattr(loader, "_run_batch", flaky)
    monkeypatch.setattr(loader.time, "sleep", lambda s: None)
    code = loader.main([str(manifest), "--database-url", settings.database_url, "--batch", "2",
                        "--report", str(tmp_path / "r.json")])
    report = json.loads((tmp_path / "r.json").read_text())
    assert code == 0
    assert calls == [2, 2, 1]  # first batch retried once
    assert [r["action"] for r in report] == ["created", "created", "rejected"]
    with psycopg.connect(settings.database_url) as conn:  # preview wrote nothing
        assert conn.execute("SELECT count(*) FROM public.barcodes WHERE barcode = '6281007031585'").fetchone()[0] == 0


def test_reconnect_waits_out_a_network_outage(monkeypatch):
    attempts = []

    def connect(url):
        attempts.append(url)
        if len(attempts) < 3:
            raise psycopg.OperationalError("failed to resolve host")
        return "conn"

    monkeypatch.setattr(loader, "_connect", connect)
    monkeypatch.setattr(loader.time, "sleep", lambda s: None)
    assert loader._reconnect("url") == "conn" and len(attempts) == 3


def test_reconnect_gives_up_with_a_clear_message(monkeypatch):
    monkeypatch.setattr(loader, "_connect", lambda url: (_ for _ in ()).throw(psycopg.OperationalError("down")))
    monkeypatch.setattr(loader.time, "sleep", lambda s: None)
    with pytest.raises(SystemExit, match="run the same command again"):
        loader._reconnect("url", tries=2)


@pytest.mark.integration
def test_a_stale_loader_session_is_ended_on_reconnect():
    try:
        stale = loader._connect(settings.database_url)
    except psycopg.OperationalError as exc:  # pragma: no cover
        pytest.skip(f"database unavailable: {exc}")
    stale.execute("SELECT 1")  # leaves it idle in transaction, as after a lost network
    stale_pid = stale.info.backend_pid
    fresh = loader._connect(settings.database_url)
    try:
        alive = fresh.execute("SELECT count(*) AS n FROM pg_stat_activity WHERE pid = %s",
                              (stale_pid,)).fetchone()["n"]
        assert alive == 0
        assert fresh.execute("SHOW lock_timeout").fetchone()["lock_timeout"] == "20s"
    finally:
        fresh.close()
