"""app.catalog.allergen_detection: allergens in ar / en / fr ingredient text."""
import pytest

from app.catalog.allergen_detection import detect, from_off_tags, merge


@pytest.mark.parametrize("statement,expected", [
    # Arabic, with the Arabic comma and the "may contain" tail.
    ("دقيق القمح، سكر، زيت نباتي، حليب مجفف، قد يحتوي على آثار من المكسرات والسمسم",
     {"WHEAT": "CONTAINS", "GLUTEN": "CONTAINS", "MILK": "CONTAINS",
      "TREE_NUTS": "MAY_CONTAIN", "SESAME": "MAY_CONTAIN"}),
    ("ماء، طحينة، عصير ليمون، ثوم", {"SESAME": "CONTAINS"}),
    ("والجبنة والبيضة", {"MILK": "CONTAINS", "EGG": "CONTAINS"}),
    # English and French.
    ("Sugar, whole milk powder, hazelnuts, emulsifier (soy lecithin). May contain peanuts.",
     {"MILK": "CONTAINS", "TREE_NUTS": "CONTAINS", "SOY": "CONTAINS", "PEANUT": "MAY_CONTAIN"}),
    ("Farine de blé, beurre, œufs, sel. Peut contenir des traces de sésame.",
     {"WHEAT": "CONTAINS", "GLUTEN": "CONTAINS", "MILK": "CONTAINS", "EGG": "CONTAINS",
      "SESAME": "MAY_CONTAIN"}),
    ("Water, sugar, preservative (E223)", {"SULPHITES": "CONTAINS"}),
    ("Oats, honey", {"GLUTEN": "CONTAINS"}),
])
def test_detects_allergens(statement, expected):
    assert detect(statement) == expected


@pytest.mark.parametrize("statement", [
    "شوكولاتة بيضاء، سكر، جوز الهند، ملح",   # white (بيضاء) is not egg; coconut is not a tree nut
    "Coconut milk, water, guar gum",
    "Sugar, cocoa butter, vanilla",           # cocoa butter is not dairy
    "Water, maltodextrin, citric acid",       # maltodextrin is not "malt extract"
    "Butternut squash, salt",
    "",
])
def test_ignores_look_alikes(statement):
    assert detect(statement) == {}


def test_off_tags_and_merge_keep_contains_over_may_contain():
    off = from_off_tags(["en:milk"], ["en:nuts", "en:wheat"])
    assert off == {"MILK": "CONTAINS", "TREE_NUTS": "MAY_CONTAIN", "WHEAT": "MAY_CONTAIN", "GLUTEN": "MAY_CONTAIN"}
    assert merge(off, {"TREE_NUTS": "CONTAINS"})["TREE_NUTS"] == "CONTAINS"
    assert merge({"TREE_NUTS": "CONTAINS"}, off)["TREE_NUTS"] == "CONTAINS"


@pytest.mark.parametrize("text,ok", [
    ("price 3", False),                         # found in Open Food Facts as an "ingredient list"
    ("price 2.50", False),
    ("السعر 5 ريال", False),
    ("Sugar", False),
    ("Wheat flour, sugar, vegetable oil, salt", True),
    ("دقيق القمح، سكر، زيت نباتي، ملح", True),
    ("Water, sugar (10%), flavour, price 3 SR", False),
])
def test_statement_plausibility(text, ok):
    from app.catalog.allergen_detection import is_plausible_statement
    assert is_plausible_statement(text) is ok
