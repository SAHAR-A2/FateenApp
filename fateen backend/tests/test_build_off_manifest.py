"""scripts/build_off_manifest.py: the quality gates (pure, no network)."""
import importlib.util
import json
import sys
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
_SPEC = importlib.util.spec_from_file_location("build_off_manifest", SCRIPTS / "build_off_manifest.py")
off = importlib.util.module_from_spec(_SPEC)
sys.modules["build_off_manifest"] = off
_SPEC.loader.exec_module(off)

GOOD = {"energy-kcal_100g": 42, "proteins_100g": 0.5, "carbohydrates_100g": 10.4, "sugars_100g": 10.1,
        "fat_100g": 0, "saturated-fat_100g": 0, "salt_100g": 0.01}


def test_consistent_nutrition_passes():
    assert off.nutrition_problems(GOOD) == []


@pytest.mark.parametrize("change,problem", [
    ({"salt_100g": None}, "missing salt_100g"),
    ({"sugars_100g": 20}, "sugars above carbohydrate"),
    ({"saturated-fat_100g": 3}, "saturated fat above total fat"),
    ({"energy-kcal_100g": 400}, "energy 400.0 kcal inconsistent with macros (44)"),
    ({k: 0 for k in GOOD}, "all values 0"),
])
def test_bad_nutrition_is_reported(change, problem):
    assert problem in off.nutrition_problems({**GOOD, **change})


def test_energy_from_kilojoules():
    n = {**GOOD, "energy-kcal_100g": None, "energy-kj_100g": 176}
    assert off.energy_kcal(n) == 42.1


@pytest.mark.parametrize("product,expected", [
    ({"quantity": "200 ml"}, True),
    ({"quantity": "1.4 L"}, True),
    ({"quantity": "400 g"}, False),
    ({"categories_tags": ["en:beverages", "en:juices"]}, True),
    ({"categories_tags": ["en:beverages", "en:instant-beverages"]}, False),  # powder
])
def test_drinks_are_measured_per_100_ml(product, expected):
    assert off.is_drink(product) is expected


@pytest.mark.parametrize("product,expected", [
    ({"categories_hierarchy": ["en:dairies", "en:milks"]}, "DAIRY"),
    ({"categories_tags": ["en:beverages", "en:juices"]}, "BEVERAGES"),
    ({"categories_tags": ["en:snacks", "en:salty-snacks"]}, "SNACKS"),
    ({"product_name": "Lay's chips salt"}, "SNACKS"),
    ({"product_name_ar": "خبز أسمر"}, "BAKERY"),
    ({"product_name": "Something"}, "OTHER"),
])
def test_category(product, expected):
    assert off.category(product) == expected


def test_brand_is_prefixed_when_missing_from_the_name():
    assert off.names({"product_name": "Shells", "brands": "La moderna"}) == (None, "La moderna Shells")
    assert off.names({"product_name": "Almarai Milk", "brands": "Almarai"}) == (None, "Almarai Milk")
    assert off.names({"product_name_ar": "حليب", "product_name": "Milk"})[0] == "حليب"


def _record(tmp_path, code, **p):
    product = {"code": code, "countries_tags": ["en:saudi-arabia"], "product_name": "Apple Juice",
               "nutriments": GOOD, "image_front_url": "https://images.example/x.jpg", **p}
    (tmp_path / f"{code}.json").write_text(json.dumps({"status": 1, "product": product}))


def test_build_gates(tmp_path, monkeypatch):
    monkeypatch.setattr(off, "fetch_image", lambda url, cache: {"url": url, "sha256": "a" * 64,
                                                                "mime": "image/jpeg", "bytes": 1000})
    _record(tmp_path, "6281007031585")                               # passes with a translation
    _record(tmp_path, "0628110219091")                               # UPC 0628: North American
    _record(tmp_path, "6281007031580")                               # bad check digit
    _record(tmp_path, "6281007063234", countries_tags=["en:canada"])
    _record(tmp_path, "6281007058117")                               # translation reviewed as unclear
    entries, rejected = off.build(tmp_path, {"6281007031585": "عصير تفاح", "6281007058117": None,
                                             "0628110219091": "x"}, tmp_path)
    assert [e["barcode"] for e in entries] == ["6281007031585"]
    entry = entries[0]
    assert (entry["name_ar"], entry["name_ar_status"]) == ("عصير تفاح", "pending_review")
    assert entry["name_en_status"] == "approved"
    problems = {r["barcode"]: r["problems"] for r in rejected}
    assert "UPC 0628/0629 is North American, not a Saudi EAN" in problems["0628110219091"]
    assert "barcode is not a valid GTIN" in problems["6281007031580"]
    assert "not tagged as sold in Saudi Arabia" in problems["6281007063234"]
    assert "name reviewed as unclear" in problems["6281007058117"]


@pytest.mark.parametrize("name,expected", [
    ("Light Meat Tuna", "SEAFOOD"),          # "meat" must not win over "tuna"
    ("Yaourt nature", "DAIRY"),
    ("Lay's Kettle cooked original", "SNACKS"),
    ("Extra virgin olive oil", "SAUCES"),
])
def test_name_keywords(name, expected):
    assert off.category({"product_name": name}) == expected


def test_reviewed_category_wins(tmp_path, monkeypatch):
    monkeypatch.setattr(off, "fetch_image", lambda url, cache: {"url": url, "sha256": "a" * 64,
                                                                "mime": "image/jpeg", "bytes": 1000})
    _record(tmp_path, "6281007031585")
    entries, _ = off.build(tmp_path, {"6281007031585": "عصير تفاح"}, tmp_path, {"6281007031585": "DAIRY"})
    assert entries[0]["category"] == "DAIRY"


def test_reviewed_names(tmp_path, monkeypatch):
    monkeypatch.setattr(off, "fetch_image", lambda url, cache: {"url": url, "sha256": "a" * 64,
                                                                "mime": "image/jpeg", "bytes": 1000})
    _record(tmp_path, "6281007031585", product_name="لبن المراعي 360مل")      # Arabic only
    _record(tmp_path, "6281007063234", product_name="Triple Cheese Puff", product_name_ar="منقوشة زعتر")
    entries, rejected = off.build(tmp_path, {}, tmp_path, None, {
        "6281007031585": {"en": "Almarai Laban 360 ml"},
        "6281007063234": None,
    })
    assert [(e["name_ar"], e["name_ar_status"], e["name_en"], e["name_en_status"]) for e in entries] == [
        ("لبن المراعي 360مل", "approved", "Almarai Laban 360 ml", "pending_review")]
    assert "name reviewed as unclear" in {r["barcode"]: r for r in rejected}["6281007063234"]["problems"]


@pytest.mark.parametrize("raw,clean", [
    ("Almarai 8 Triangles 16days", "Almarai 8 Triangles"),
    ("Almarai extra virgin olive oil 2yrs prod", "Almarai extra virgin olive oil"),
    ("السعر 5 ريال Avemari lisce pasta", "Avemari lisce pasta"),
])
def test_clean_name(raw, clean):
    assert off.clean_name(raw) == clean


@pytest.mark.parametrize("name,category_code,kcal,rejected", [
    ("Black cumin seed oil", "SAUCES", 10, True),          # an oil is ~900 kcal/100 g
    ("Olive oil", "SAUCES", 884, False),
    ("Sucre de canne", "SAUCES", 15, True),
    ("arcor flics", "CONFECTIONERY", 10, True),            # candy values given per piece
    ("ice pops", "CONFECTIONERY", 40, False),
    ("Oat Biscuits", "BAKERY", 45, True),
    ("Forsana Sandwiches cheese", "DAIRY", 59, True),
    ("Almarai milk fat free", "DAIRY", 34, False),
    ("Maggi Chicken broth", "SAUCES", 0.2, False),
    ("Freshly Yellow mustard", "SAUCES", 0, True),
])
def test_energy_density_floors(name, category_code, kcal, rejected):
    assert bool(off.density_problems(name, category_code, kcal, "PER_100G")) is rejected


def test_density_is_not_judged_for_drinks():
    assert off.density_problems("Sugar syrup", "BEVERAGES", 1, "PER_100ML") == []


@pytest.mark.parametrize("name,category_code,liquid", [
    ("Fitch & Leedes Ginger Beer", "BEVERAGES", True),
    ("nada Protein Strawberry milk", "DAIRY", True),
    ("ندى زبادي يوناني للشرب", "DAIRY", True),
    ("Almarai Milk Powder", "DAIRY", False),
    ("Matcha green tea", "BEVERAGES", False),            # leaves or powder, not the drink
    ("Almarai Halloumi Cheese", "DAIRY", False),
    ("McVitie's Digestive Milk Chocolate", "BAKERY", False),
])
def test_liquids_without_a_stated_volume(name, category_code, liquid):
    assert off.looks_liquid(name, category_code) is liquid
