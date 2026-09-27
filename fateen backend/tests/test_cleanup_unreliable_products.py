"""scripts/cleanup_unreliable_products.py (real DB, every change rolled back)."""
import importlib.util
import sys
from pathlib import Path

import psycopg
import pytest
from psycopg.rows import dict_row

from app.core.config import settings

_SPEC = importlib.util.spec_from_file_location(
    "cleanup_unreliable_products",
    Path(__file__).resolve().parent.parent / "scripts" / "cleanup_unreliable_products.py",
)
cleanup = importlib.util.module_from_spec(_SPEC)
sys.modules["cleanup_unreliable_products"] = cleanup
_SPEC.loader.exec_module(cleanup)


@pytest.fixture
def tx():
    try:
        conn = psycopg.connect(settings.database_url, row_factory=dict_row)
    except psycopg.OperationalError as exc:  # pragma: no cover
        pytest.skip(f"database unavailable: {exc}")
    try:
        yield conn
    finally:
        conn.rollback()
        conn.close()


@pytest.mark.integration
def test_test_rows_are_selected_with_their_reasons(tx):
    selection = {p["internal_code"]: p for p in cleanup.collect(tx)}
    assert "test_row" in selection["TEST_MILK_001"]["reasons"]
    # The synthetic barcodes carry no GS1 check digit.
    assert "invalid_gtin" in selection["FATEEN_SNACK_TEST"]["reasons"]


@pytest.mark.integration
def test_all_zero_nutrition_is_selected(tx):
    pid = tx.execute("SELECT id FROM public.products WHERE internal_code = 'TEST_BREAD_001'").fetchone()["id"]
    tx.execute("UPDATE public.product_nutrition_values SET amount_value = 0 WHERE product_id = %s", (pid,))
    selection = {p["internal_code"]: p for p in cleanup.collect(tx)}
    if tx.execute(
        "SELECT COUNT(*) AS n FROM public.product_nutrition_values WHERE product_id = %s AND deleted_at IS NULL",
        (pid,),
    ).fetchone()["n"] >= 3:
        assert "all_zero_nutrition" in selection["TEST_BREAD_001"]["reasons"]


@pytest.mark.integration
def test_apply_soft_deletes_and_hides_from_the_selection(tx):
    selection = cleanup.collect(tx)
    products, _ = cleanup.apply(tx, selection)
    assert products == len([p for p in selection if p["reasons"] != ["invalid_barcode_link"]])
    row = tx.execute(
        "SELECT deleted_at FROM public.products WHERE internal_code = 'TEST_MILK_001'"
    ).fetchone()
    assert row["deleted_at"] is not None  # soft delete: the row is still there
    assert cleanup.collect(tx) == []


@pytest.mark.integration
def test_apply_refuses_when_the_count_changed(tmp_path):
    code = cleanup.main([
        "--database-url", settings.database_url, "--apply", "--expect", "999",
        "--backup", str(tmp_path / "b.json"),
    ])
    assert code == 1
    with psycopg.connect(settings.database_url, row_factory=dict_row) as conn:
        assert conn.execute(
            "SELECT deleted_at FROM public.products WHERE internal_code = 'TEST_MILK_001'"
        ).fetchone()["deleted_at"] is None
