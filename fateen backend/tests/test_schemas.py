import pytest
from pydantic import ValidationError
from app.schemas.product import ProductBarcodeResponse
from app.schemas.product_details import (
    ProductDetailsResponse,
    IngredientDetails,
    AllergenDetails,
    HealthFlagDetails,
    NutritionDetails,
)


def _make_product_response(**overrides):
    defaults = {
        "internal_code": "TEST",
        "name": "Test",
        "barcode": "1234567890123",
        "relationship_type": "primary",
        "lifecycle_status": "active",
        "confidence_level": 0.5,
    }
    defaults.update(overrides)
    return ProductBarcodeResponse(**defaults)


class TestConfidenceLevelValidation:
    @pytest.mark.parametrize("level", [0.0, 0.5, 1.0])
    def test_valid_confidence_levels(self, level):
        resp = _make_product_response(confidence_level=level)
        assert resp.confidence_level == level

    def test_confidence_below_zero_rejected(self):
        with pytest.raises(ValidationError):
            _make_product_response(confidence_level=-0.01)

    def test_confidence_above_one_rejected(self):
        with pytest.raises(ValidationError):
            _make_product_response(confidence_level=1.01)

    def test_ingredient_confidence_valid(self):
        resp = IngredientDetails(
            internal_code="ING001",
            name="Test",
            relationship_type="contains",
            confidence_level=0.0,
        )
        assert resp.confidence_level == 0.0

    def test_ingredient_confidence_invalid(self):
        with pytest.raises(ValidationError):
            IngredientDetails(
                internal_code="ING001",
                name="Test",
                relationship_type="contains",
                confidence_level=2.0,
            )

    def test_allergen_confidence_invalid(self):
        with pytest.raises(ValidationError):
            AllergenDetails(
                internal_code="ALL001",
                name="Test",
                relationship_type="contains",
                confidence_level=-0.5,
            )

    def test_health_flag_confidence_invalid(self):
        with pytest.raises(ValidationError):
            HealthFlagDetails(
                internal_code="HF001",
                name="Test",
                relationship_type="contains",
                confidence_level=1.5,
            )

    def test_nutrition_confidence_invalid(self):
        with pytest.raises(ValidationError):
            NutritionDetails(
                nutrition_type="energy",
                amount_value=100.0,
                unit="kcal",
                relationship_type="contains",
                confidence_level=-1.0,
            )

    def test_product_details_confidence_invalid(self):
        with pytest.raises(ValidationError):
            ProductDetailsResponse(
                internal_code="TEST",
                name="Test",
                confidence_level=1.5,
                lifecycle_status="active",
                ingredients=[],
                allergens=[],
                health_flags=[],
                nutrition=[],
            )
