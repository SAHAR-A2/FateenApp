"""Ingredient splitting tests."""

from fateen_agent.normalization.ingredients import is_enumber, split_ingredients


class TestSplitIngredients:
    def test_simple_comma_list(self):
        assert split_ingredients("milk, sugar, cocoa butter") == ["milk", "sugar", "cocoa butter"]

    def test_quantity_stripped(self):
        toks = split_ingredients("wheat flour 60%, sugar 20%, water")
        assert toks == ["wheat flour", "sugar", "water"]

    def test_parentheticals_stripped(self):
        assert split_ingredients("hazelnuts (26%), skim milk powder") == [
            "hazelnuts",
            "skim milk powder",
        ]

    def test_enumber_kept(self):
        assert "e471" in split_ingredients("water, sugar, e471, lecithin")

    def test_arabic_list(self):
        toks = split_ingredients("حليب كامل الدسم، سكر، ماء")
        assert len(toks) == 3

    def test_empty(self):
        assert split_ingredients("") == []
        assert split_ingredients(None) == []


class TestIsEnumber:
    def test_enumber(self):
        assert is_enumber("E471") is True
        assert is_enumber("e100") is True

    def test_not_enumber(self):
        assert is_enumber("milk") is False
        assert is_enumber("E47") is False
