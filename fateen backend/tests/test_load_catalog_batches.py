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

    def flaky(conn, refs, batch):
        calls.append(len(batch))
        if len(calls) == 1:
            raise psycopg.OperationalError("the connection is lost")
        return real(conn, refs, batch)

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
