"""scripts/merge_manifests.py: one entry per barcode, manufacturer first."""
import importlib.util
import sys
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "merge_manifests", Path(__file__).resolve().parent.parent / "scripts" / "merge_manifests.py")
mm = importlib.util.module_from_spec(_SPEC)
sys.modules["merge_manifests"] = mm
_SPEC.loader.exec_module(mm)


def test_first_manifest_wins_and_gaps_are_filled():
    almarai = [{"barcode": "6281007031585", "name_ar": "عصير تفاح", "nutrition": [], "ingredients": {},
                "allergens": {}, "category": "BEVERAGES", "source": "ALMARAI_WEBSITE"}]
    off = [{"barcode": "6281007031585", "name_ar": "تفاح", "nutrition": [{"type": "SUGAR"}],
            "ingredients": {"en": "Apple juice"}, "allergens": {"SULPHITES": "MAY_CONTAIN"},
            "category": "OTHER", "source": "OPEN_FOOD_FACTS"},
           {"barcode": "6281007000001", "name_ar": "حليب", "source": "OPEN_FOOD_FACTS"}]
    merged = mm.merge([almarai, off])
    assert [e["barcode"] for e in merged] == ["6281007031585", "6281007000001"]
    first = merged[0]
    assert first["name_ar"] == "عصير تفاح" and first["source"] == "ALMARAI_WEBSITE"
    assert first["nutrition"] == [{"type": "SUGAR"}]
    assert first["ingredients"] == {"en": "Apple juice"}
    assert first["allergens"] == {"SULPHITES": "MAY_CONTAIN"}
    assert first["category"] == "BEVERAGES"
