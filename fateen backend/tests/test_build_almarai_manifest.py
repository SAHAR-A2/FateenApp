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
<div>Available In</div><span>200.00&nbsp;</span><span>ML</span><span>1.40 </span><span>L</span>
<div>Nutrition Information</div><div>Serving Size</div><div>=&nbsp;</div><div>100ml</div><div>Calories</div><div>= </div><div>42</div>
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


PRODUCTS = [
    _product("almarai/juices/mixed-apple", "Mixed Apple Juice", ((200.0, "ml"), (1.4, "l"))),
    _product("almarai/butter/salted", "Salted Natural Butter", ((200.0, "g"), (400.0, "g"))),
    _product("almarai/butter/unsalted", "Unsalted Natural Butter", ((1.0, "kg"), (200.0, "g"), (400.0, "g"))),
]


def test_each_size_of_a_page_gets_its_own_barcode():
    off = [{"code": "6281007000001", "brands": "Almarai", "product_name": "Almarai Mixed Apple Juice", "quantity": "200 ml"},
           {"code": "6281007000002", "brands": "Almarai", "product_name": "Mixed Apple juice", "quantity": "1.4 L"}]
    assert alm.match_barcodes(PRODUCTS, off) == {
        "6281007000001": ("almarai/juices/mixed-apple", (200.0, "ml")),
        "6281007000002": ("almarai/juices/mixed-apple", (1400.0, "ml")),
    }


@pytest.mark.parametrize("record,expected", [
    # "Natural Butter" fits salted and unsalted at 400 g: ambiguous, no barcode.
    ({"brands": "Almarai", "product_name": "Natural Butter", "quantity": "400g"}, None),
    # Only the unsalted page lists 1 kg, but "unsalted" is not a word a
    # record may leave out: the size alone does not settle it.
    ({"brands": "Almarai", "product_name": "ALMARAI NATURAL BUTTER", "quantity": "1kg"}, None),
    # Size not listed on the page.
    ({"brands": "Almarai", "product_name": "Mixed Apple Juice", "quantity": "1 L"}, None),
    # No stated quantity, but the name fits one page only.
    ({"brands": "Almarai", "product_name": "Mixed Apple Juice"}, "almarai/juices/mixed-apple"),
    # No stated quantity and the name fits salted and unsalted.
    ({"brands": "Almarai", "product_name": "Natural Butter"}, None),
    # Arabic quantity.
    ({"brands": "Almarai", "product_name": "Unsalted Natural Butter", "quantity": "الوزن الصافي 400 جرام"},
     "almarai/butter/unsalted"),
    # Another brand.
    ({"brands": "Other", "product_name": "Mixed Apple Juice", "quantity": "200 ml"}, None),
    # Too generic a name.
    ({"brands": "Almarai", "product_name": "Butter", "quantity": "1kg"}, None),
])
def test_a_record_must_fit_exactly_one_page(record, expected):
    matched = alm.match_barcodes(PRODUCTS, [{"code": "6281007000009", **record}])
    assert (matched.get("6281007000009") or (None,))[0] == expected


def test_size_labels():
    assert alm._size_label((1400.0, "ml"), "en") == "1.4 l"
    assert alm._size_label((200.0, "g"), "ar") == "200 غ"


@pytest.mark.parametrize("record,page,ok", [
    ({"croissant", "mini"}, {"chocolate", "mini", "croissant"}, False),     # flavour added
    ({"milk", "powder"}, {"full", "cream", "milk", "powder"}, False),        # fat level added
    ({"gizzards", "chicken"}, {"fresh", "chicken", "gizzards"}, True),
    ({"mixed", "fruit", "mango"}, {"mango", "mixed", "fruit", "nectar"}, True),
    ({"vanilla", "dessert", "custard"}, {"custard", "vanilla"}, True),       # record adds one word
])
def test_name_rule(record, page, ok):
    assert alm._name_matches(record, page) is ok


def test_self_contradicting_record_is_left_out():
    product = _product("almarai/dairy/sweetened-condensed-milk", "Sweetened Condensed Milk", ((397.0, "g"),))
    product["ar"] = {"name": "حليب مكثف محلى"}
    record = {"code": "6281007000009", "brands": "Almarai", "product_name": "Nestle",
              "product_name_ar": "حليب مكثف محلى", "quantity": "397g"}
    assert alm.match_barcodes([product], [record]) == {}


def test_category_follows_the_site_section():
    assert alm.category("almarai/cheeses-and-foods/olive-oil/extra-virgin-olive-oil") == "SAUCES"
    assert alm.category("almarai/cheeses-and-foods/feta/feta-cheese-low-fat") == "DAIRY"
    assert alm.category("lusine/bakery/bread/sliced-bread-milk") == "BAKERY"  # not DAIRY
