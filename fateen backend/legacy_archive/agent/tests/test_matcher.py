"""Matcher tests: ingredient matching + product dedup."""

from fateen_agent.matching import best_ingredient_match, find_existing_product

CANONICAL = ["Milk", "Soy", "Soy Lecithin", "Wheat Flour", "Sugar", "Cocoa Butter"]


class TestIngredientMatch:
    def test_exact_match(self):
        m = best_ingredient_match("sugar", CANONICAL, {})
        assert m is not None
        assert m.method == "exact"
        assert m.score == 1.0

    def test_alias_match_wins(self):
        aliases = {"e471": [5]}  # points to "Cocoa Butter"
        m = best_ingredient_match("E471", CANONICAL, aliases)
        assert m is not None
        assert m.method == "alias_exact"
        assert m.index == 5

    def test_fuzzy_suggestion(self):
        m = best_ingredient_match("wheet flour", CANONICAL, {})
        assert m is not None
        assert m.method in ("similarity", "token_overlap")

    def test_no_match(self):
        m = best_ingredient_match("zzzzzz", CANONICAL, {})
        assert m is None


class TestFindExistingProduct:
    PRODUCTS = [
        {"id": "p1", "name": "Test Milk", "brand": "Fateen", "company": "Fateen Co"},
        {"id": "p2", "name": "Test Bread", "brand": "Fateen", "company": "Fateen Co"},
    ]
    BARCODE_INDEX = {"5901234123457": {"product_id": "p1", "barcode": "5901234123457"}}

    def test_exact_barcode(self):
        found = find_existing_product("5901234123457", None, None, self.PRODUCTS, self.BARCODE_INDEX)
        assert found is not None
        assert found["product_id"] == "p1"

    def test_barcode_normalized(self):
        found = find_existing_product("5901 2341 2345 7", None, None, self.PRODUCTS, self.BARCODE_INDEX)
        assert found is not None

    def test_name_exact(self):
        found = find_existing_product(None, "test milk", None, self.PRODUCTS, {})
        assert found is not None

    def test_same_brand_high_similarity(self):
        found = find_existing_product(None, "Test Milk!", "Fateen", self.PRODUCTS, {})
        assert found is not None

    def test_no_match(self):
        found = find_existing_product(None, "Totally Different", "Other", self.PRODUCTS, {})
        assert found is None
