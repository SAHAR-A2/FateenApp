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
