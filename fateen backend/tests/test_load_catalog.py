"""scripts/load_catalog.py against the test database; every change rolled back."""
import copy
import importlib.util
import sys
from pathlib import Path

import psycopg
import pytest
from psycopg.rows import dict_row

from app.core.config import settings

_SPEC = importlib.util.spec_from_file_location(
    "load_catalog", Path(__file__).resolve().parent.parent / "scripts" / "load_catalog.py"
)
loader = importlib.util.module_from_spec(_SPEC)
sys.modules["load_catalog"] = loader
_SPEC.loader.exec_module(loader)

ENTRY = {
    "barcode": "6281007031585",
    "name_ar": "بسكويت الشوفان", "name_ar_status": "pending_review",
    "name_en": "Oat Biscuits", "name_en_status": "approved",
    "brand": "Test Brand", "company": "Test Company",
    "category": "SNACKS",
    "image": {"url": "https://images.example/front.jpg", "sha256": "a" * 64, "mime": "image/jpeg", "bytes": 10},
    "nutrition": [{"type": "SUGAR", "amount": 30, "unit": "G", "basis": "PER_100G"}],
    "ingredients": {"ar": "دقيق الشوفان، سكر، زبدة. قد يحتوي على آثار من الفول السوداني"},
    "allergens": {},
    "source": "OPEN_FOOD_FACTS", "source_url": "https://world.openfoodfacts.org/product/6281007031585",
    "confidence": 0.6,
}


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


@pytest.fixture
def refs(tx):
    return loader.Refs(tx)


def _product(tx, barcode):
    return tx.execute(
        """SELECT p.* FROM public.products p JOIN public.product_barcodes pb ON pb.product_id = p.id
           JOIN public.barcodes b ON b.id = pb.barcode_id WHERE b.barcode = %s""", (barcode,)).fetchone()


@pytest.mark.integration
def test_new_product_gets_every_part_and_arabic_base_name(tx, refs):
    assert loader.validate(ENTRY, refs) == []
    result = loader.load_entry(tx, refs, ENTRY)
    assert result["action"] == "created"
    assert set(result["added"]) >= {"name_ar", "name_en", "image", "ingredients_ar", "allergens", "nutrition"}
    product = _product(tx, ENTRY["barcode"])
    assert product["name"] == "بسكويت الشوفان"
    allergens = {r["internal_code"]: r["rel"] for r in tx.execute(
        """SELECT a.internal_code, rt.code AS rel FROM public.product_allergens pa
           JOIN public.allergens a ON a.id = pa.allergen_id
           JOIN public.relationship_types rt ON rt.id = pa.relationship_type_id
           WHERE pa.product_id = %s""", (product["id"],))}
    # Found in the Arabic statement although the manifest listed none.
    assert allergens == {"GLUTEN": "CONTAINS_ALLERGEN", "MILK": "CONTAINS_ALLERGEN",
                         "PEANUT": "MAY_CONTAIN_ALLERGEN"}


@pytest.mark.integration
def test_second_load_changes_nothing(tx, refs):
    loader.load_entry(tx, refs, ENTRY)
    assert loader.load_entry(tx, refs, ENTRY) == {"action": "unchanged", "added": []}


@pytest.mark.integration
def test_existing_product_is_completed_not_overwritten(tx, refs):
    partial = {**copy.deepcopy(ENTRY), "name_en": "", "image": None, "nutrition": []}
    loader.load_entry(tx, refs, partial)
    richer = {**copy.deepcopy(ENTRY), "name_ar": "اسم آخر",
              "nutrition": [{"type": "SUGAR", "amount": 1, "unit": "G", "basis": "PER_100G"}]}
    result = loader.load_entry(tx, refs, richer)
    assert result["action"] == "completed"
    assert set(result["added"]) == {"name_en", "image", "nutrition"}
    assert _product(tx, ENTRY["barcode"])["name"] == "بسكويت الشوفان"  # not overwritten


@pytest.mark.parametrize("change,problem", [
    ({"barcode": "6281007031580"}, "barcode is not a valid GTIN"),
    ({"name_ar": " "}, "no Arabic name"),
    ({"name_ar_status": "draft"}, "name_ar_status must be approved or pending_review"),
    ({"category": "NOT_A_CATEGORY"}, "unknown category NOT_A_CATEGORY"),
    ({"allergens": {"MILK": "MAYBE"}}, "bad allergen relation MAYBE"),
    ({"image": {"url": "http://x", "sha256": "z"}}, "image needs an https url and a sha256"),
])
@pytest.mark.integration
def test_invalid_entries_are_rejected(tx, refs, change, problem):
    assert problem in loader.validate({**ENTRY, **change}, refs)


def test_apply_needs_an_explicit_url(monkeypatch, tmp_path):
    monkeypatch.setenv("CLOUD_DATABASE_URL", "postgresql://nobody@invalid.example/none")
    manifest = tmp_path / "m.json"
    manifest.write_text("[]")
    with pytest.raises(SystemExit, match="explicit --database-url"):
        loader.main([str(manifest), "--apply"])


@pytest.mark.integration
def test_products_sharing_a_photo_reuse_the_image(tx, refs):
    loader.load_entry(tx, refs, ENTRY)
    other = {**copy.deepcopy(ENTRY), "barcode": "6281007053662"}
    assert "image" in loader.load_entry(tx, refs, other)["added"]
    assert tx.execute("SELECT count(*) AS n FROM public.images WHERE content_hash = %s",
                      ("a" * 64,)).fetchone()["n"] == 1
