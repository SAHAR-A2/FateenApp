"""scripts/build_almarai_manifest.py: page parsing, nutrition, one-to-one barcode matching."""
import importlib.util
import sys
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
_SPEC = importlib.util.spec_from_file_location("build_almarai_manifest", SCRIPTS / "build_almarai_manifest.py")
alm = importlib.util.module_from_spec(_SPEC)
sys.modules["build_almarai_manifest"] = alm
_SPEC.loader.exec_module(alm)

EN_PAGE = """<html><head></head><body>
<div>Home</div><div>Brands</div><div>Almarai</div><div>Natural Juices</div><div>Mixed Apple</div>
<h1>Mixed Apple </h1><h2>Description</h2><p>100% natural apple juice.</p>
<div>HighLights</div><div>Brand</div><div>: </div><div>Almarai</div><div>Size</div><div>: </div><div>200.00 ML</div>
<div>Available In</div><span>200.00 </span><span>ML</span><span>1.40 </span><span>L</span>
<div>Nutrition Information</div><div>Serving Size</div><div>= </div><div>100ml</div><div>Calories</div><div>= </div><div>42</div>
<div>Total Fat 0g</div><div>Saturated Fat 0g</div><div>Trans Fat 0g</div><div>Sodium 5mg</div>
<div>Total Carbs 10.4g</div><div>Dietary Fiber 0g</div><div>Total Sugars 10.1g</div><div>Protein 0g</div>
<img src="https://almmedia.almarai.com/Gallery/mixed-apple.png"></body></html>"""


def test_parse_english_page():
    page = alm.parse_page("https://www.almarai.com/en/brands/almarai/juices/apple-juices/mixed-apple", EN_PAGE)
    assert page["name"] == "Mixed Apple"
    assert page["description"] == "100% natural apple juice."
    assert page["serving"] == (100.0, "ml")
    assert (200.0, "ml") in page["sizes"] and (1.4, "l") in page["sizes"]
    assert page["image"] == "https://almmedia.almarai.com/Gallery/mixed-apple.png"
    assert page["per_serving"]["SUGAR"] == 10.1


def test_listing_page_is_not_a_product():
    assert alm.parse_page("https://www.almarai.com/en/brands/lusine/bakery/puffs",
                          "<body><div>Puffs</div><div>View Details</div></body>") is None


def _page(serving, **values):
    base = {"ENERGY": None, "TOTAL_FAT": 3.1, "SATURATED_FAT": 1.6, "TRANS_FAT": 0, "SODIUM": 144,
            "CARBOHYDRATE": 22, "FIBER": 1.9, "SUGAR": 1.0, "PROTEIN": 3.2}
    return {"serving": serving, "per_serving": {**base, **values}}


def test_nutrition_is_scaled_to_100_g():
    values, why = alm.nutrition(_page((40.0, "g")))
    by_type = {v["type"]: v for v in values}
    assert why is None
    assert by_type["CARBOHYDRATE"]["amount"] == 55.0 and by_type["CARBOHYDRATE"]["basis"] == "PER_100G"
    assert by_type["SODIUM"] == {"type": "SODIUM", "amount": 360.0, "unit": "MG", "basis": "PER_100G"}


@pytest.mark.parametrize("page,reason", [
    (_page(None), "serving size not stated in g or ml"),
    (_page((40.0, "g"), SUGAR=None), "incomplete nutrition table"),
    (_page((40.0, "g"), SATURATED_FAT=5), "saturated fat or sugar above its total"),
    (_page((40.0, "g"), ENERGY=900), "energy inconsistent with macros"),
])
def test_unusable_nutrition_is_left_out(page, reason):
    assert alm.nutrition(page) == ([], reason)


def _product(path, name, sizes=((200.0, "ml"),)):
    return {"path": path, "brand_slug": path.split("/")[0], "en": {"name": name, "sizes": list(sizes)}}


def test_barcode_match_is_one_to_one():
    products = [_product("almarai/juices/mixed-apple", "Mixed Apple"),
                _product("almarai/milk/fresh-milk", "Fresh Milk", ((1000.0, "ml"),)),
                _product("almarai/milk/full-fat-milk", "Full Fat Milk", ((1000.0, "ml"),))]
    off = [{"code": "6281007000001", "brands": "Almarai", "product_name": "Almarai Mixed Apple", "quantity": "200 ml"},
           {"code": "6281007000002", "brands": "Almarai", "product_name": "Mixed Apple juice", "quantity": "1.4 L"},
           {"code": "6281007000003", "brands": "Almarai", "product_name": "Full Fat Milk", "quantity": "1 L"},
           {"code": "6281007000004", "brands": "Almarai", "product_name": "Full Fat Milk", "quantity": "1L"},
           {"code": "6281007000005", "brands": "Other", "product_name": "Fresh Milk", "quantity": "1 L"}]
    matched = alm.match_barcodes(products, off)
    # 000002 is 1.4 L, not a listed size; 000005 is another brand.
    assert matched == {"almarai/juices/mixed-apple": "6281007000001"}
    # Two records for one page: ambiguous, so no barcode at all.
    assert "almarai/milk/full-fat-milk" not in matched
