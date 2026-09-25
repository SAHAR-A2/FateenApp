from app.agent.confidence import (
    calculate_ingredient_confidence,
    calculate_allergen_confidence,
    calculate_nutrition_confidence,
    calculate_product_confidence,
)


class TestIngredientConfidence:
    def test_name_only(self):
        assert calculate_ingredient_confidence(has_name=True) == 0.4

    def test_name_amount_unit(self):
        result = calculate_ingredient_confidence(
            has_name=True, has_amount=True, has_unit=True
        )
        assert result == 0.7

    def test_all_fields(self):
        result = calculate_ingredient_confidence(
            has_name=True,
            has_amount=True,
            has_unit=True,
            source_verified=True,
        )
        assert result == 1.0

    def test_no_name(self):
        assert calculate_ingredient_confidence(has_name=False) == 0.0

    def test_never_exceeds_one(self):
        result = calculate_ingredient_confidence(
            has_name=True,
            has_amount=True,
            has_unit=True,
            source_verified=True,
        )
        assert result <= 1.0


class TestAllergenConfidence:
    def test_name_only(self):
        assert calculate_allergen_confidence(has_name=True) == 0.5

    def test_name_and_verified(self):
        result = calculate_allergen_confidence(
            has_name=True, source_verified=True
        )
        assert result == 1.0

    def test_no_name(self):
        assert calculate_allergen_confidence(has_name=False) == 0.0


class TestNutritionConfidence:
    def test_all_fields(self):
        result = calculate_nutrition_confidence(
            has_type=True, has_amount=True, has_unit=True
        )
        assert result == 0.7

    def test_all_with_source(self):
        result = calculate_nutrition_confidence(
            has_type=True,
            has_amount=True,
            has_unit=True,
            source_verified=True,
        )
        assert result == 1.0

    def test_nothing(self):
        result = calculate_nutrition_confidence(
            has_type=False, has_amount=False, has_unit=False
        )
        assert result == 0.0


class TestProductConfidence:
    def test_average(self):
        result = calculate_product_confidence(
            [0.8, 0.6], [1.0], [0.5, 0.7]
        )
        expected = round((0.8 + 0.6 + 1.0 + 0.5 + 0.7) / 5, 2)
        assert result == expected

    def test_empty(self):
        assert calculate_product_confidence([], [], []) == 0.0
