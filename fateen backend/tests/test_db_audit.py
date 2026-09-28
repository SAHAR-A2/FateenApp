"""scripts/db_audit.py finds each defect it claims to (real DB, rolled back)."""
import importlib.util
import sys
from pathlib import Path

import psycopg
import pytest
from psycopg.rows import dict_row

from app.core.config import settings
from app.core.gtin import has_valid_check_digit

_SPEC = importlib.util.spec_from_file_location(
    "db_audit", Path(__file__).resolve().parent.parent / "scripts" / "db_audit.py"
)
db_audit = importlib.util.module_from_spec(_SPEC)
sys.modules["db_audit"] = db_audit
_SPEC.loader.exec_module(db_audit)


@pytest.mark.parametrize("code,ok", [
    ("4006381333931", True), ("036000291452", True), ("96385074", True),
    ("6281007031585", True), ("6281007031580", False), ("12345678901", False),
    ("abc", False), ("", False),
])
def test_gtin_check_digit(code, ok):
    assert has_valid_check_digit(code) is ok


@pytest.fixture
def tx():
    """A connection whose every change is rolled back after the test."""
    try:
        conn = psycopg.connect(settings.database_url, row_factory=dict_row)
    except psycopg.OperationalError as exc:  # pragma: no cover
        pytest.skip(f"database unavailable: {exc}")
    try:
        yield conn
    finally:
        conn.rollback()
        conn.close()


def _ref(conn, table, code):
    return conn.execute(f"SELECT id FROM public.{table} WHERE code = %s", (code,)).fetchone()["id"]


def _product(conn, code):
    return conn.execute(
        "SELECT id FROM public.products WHERE internal_code = %s", (code,)
    ).fetchone()["id"]


def _add_nutrition(conn, product_id, nutrient, amount, unit, basis="PER_100G"):
    conn.execute(
        """
        INSERT INTO public.product_nutrition_values
            (product_id, nutrition_type_id, relationship_type_id, amount_value,
             unit_id, status_id, measurement_basis_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (product_id, _ref(conn, "nutrition_types", nutrient),
         _ref(conn, "relationship_types", "MEASURED_VALUE"), amount,
         _ref(conn, "units", unit), _ref(conn, "lifecycle_statuses", "ACTIVE"),
         _ref(conn, "measurement_bases", basis)),
    )


@pytest.mark.integration
class TestAuditFindsDefects:
    def test_invalid_check_digits_are_reported(self, tx):
        found = {r["barcode"] for r in db_audit.check_invalid_gtin(tx)}
        # The synthetic pilot barcodes do not carry GS1 check digits.
        assert "6281000000066" in found

    def test_impossible_nutrition(self, tx):
        pid = _product(tx, "TEST_BREAD_001")
        _add_nutrition(tx, pid, "PROTEIN", 150, "G")
        _add_nutrition(tx, pid, "ENERGY", 2000, "KCAL")
        _add_nutrition(tx, pid, "SUGAR", 150, "G", basis="PER_SERVING")  # not bounded
        rows = db_audit.check_impossible_nutrition(tx)
        found = {(r["internal_code"], r["nutrition_type"]) for r in rows}
        assert found == {("TEST_BREAD_001", "PROTEIN"), ("TEST_BREAD_001", "ENERGY")}

    def test_all_zero_nutrition(self, tx):
        pid = _product(tx, "TEST_CHIPS_001")
        for nutrient in ("PROTEIN", "SUGAR", "TOTAL_FAT"):
            _add_nutrition(tx, pid, nutrient, 0, "G")
        codes = {r["internal_code"] for r in db_audit.check_all_zero_nutrition(tx)}
        assert codes == {"TEST_CHIPS_001"}  # milk has real values

    def test_shared_barcode_and_missing_barcode(self, tx):
        milk = _product(tx, "FATEEN_MILK_TEST")
        bread = _product(tx, "TEST_BREAD_001")
        tx.execute(
            """
            UPDATE public.product_barcodes SET product_id = %s
            WHERE product_id = %s
            """,
            (milk, bread),
        )
        without = {r["internal_code"] for r in db_audit.check_product_without_barcode(tx)}
        assert without == {"TEST_BREAD_001"}

    def test_barcode_linked_to_two_products(self, tx):
        milk = _product(tx, "FATEEN_MILK_TEST")
        tx.execute(
            """
            INSERT INTO public.product_barcodes
                (product_id, barcode_id, relationship_type_id, status_id)
            SELECT %s, pb.barcode_id, pb.relationship_type_id, pb.status_id
            FROM public.product_barcodes pb
            JOIN public.products p ON p.id = pb.product_id
            WHERE p.internal_code = 'TEST_BREAD_001'
            """,
            (milk,),
        )
        shared = db_audit.check_barcode_on_many_products(tx)
        assert [r["products"] for r in shared] == [["FATEEN_MILK_TEST", "TEST_BREAD_001"]]

    def test_clean_fixture_has_no_physical_nutrition_errors(self, tx):
        results = db_audit.run_audit(tx)
        assert results["impossible_nutrition"] == []
        assert results["all_zero_nutrition"] == []
        assert results["barcode_on_many_products"] == []
