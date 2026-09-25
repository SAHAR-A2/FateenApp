"""Tests for LLM extraction and enrichment."""
import json
import pytest
from unittest.mock import patch, MagicMock

from app.llm.client import LLMClient, LLMResponse
from app.llm.extractor import (
    extract_product_data,
    enrich_product,
    _validate_ingredients,
    _validate_allergens,
    _validate_nutrition,
    VALID_NUTRITION_TYPES,
    VALID_UNITS,
)


class TestLLMResponseParsing:
    def test_parse_valid_json(self):
        resp = LLMResponse(content='{"key": "value"}', model="test")
        assert resp.parsed_json() == {"key": "value"}

    def test_parse_markdown_json(self):
        resp = LLMResponse(
            content='```json\n{"key": "value"}\n```',
            model="test",
        )
        assert resp.parsed_json() == {"key": "value"}

    def test_parse_bare_code_block(self):
        resp = LLMResponse(
            content='```\n{"key": "value"}\n```',
            model="test",
        )
        assert resp.parsed_json() == {"key": "value"}

    def test_parse_invalid_json_raises(self):
        resp = LLMResponse(content="not json", model="test")
        with pytest.raises(Exception):
            resp.parsed_json()


class TestValidation:
    def test_validate_ingredients_valid(self):
        items = [
            {"name": "MILK", "amount_value": 100, "unit": "ML"},
            {"name": "SUGAR"},
        ]
        result = _validate_ingredients(items)
        assert len(result) == 2
        assert result[0]["name"] == "milk"
        assert result[0]["amount_value"] == 100.0
        assert result[0]["unit"] == "ML"

    def test_validate_ingredients_skips_invalid(self):
        items = [{"name": ""}, {}, {"name": "X", "unit": "INVALID"}]
        result = _validate_ingredients(items)
        assert len(result) == 1
        assert result[0]["name"] == "x"

    def test_validate_allergens_valid(self):
        items = [{"name": "MILK"}, {"name": "NUTS"}]
        result = _validate_allergens(items)
        assert len(result) == 2

    def test_validate_allergens_skips_empty(self):
        items = [{"name": ""}, {}, {"name": "X"}]
        result = _validate_allergens(items)
        assert len(result) == 1

    def test_validate_nutrition_valid(self):
        items = [
            {"nutrition_type": "ENERGY", "amount_value": 61, "unit": "KCAL"},
            {"nutrition_type": "PROTEIN", "amount_value": 3.2, "unit": "G"},
        ]
        result = _validate_nutrition(items)
        assert len(result) == 2

    def test_validate_nutrition_skips_invalid_type(self):
        items = [{"nutrition_type": "INVALID", "amount_value": 10, "unit": "G"}]
        result = _validate_nutrition(items)
        assert len(result) == 0

    def test_validate_nutrition_skips_invalid_unit(self):
        items = [{"nutrition_type": "ENERGY", "amount_value": 10, "unit": "INVALID"}]
        result = _validate_nutrition(items)
        assert len(result) == 0

    def test_validate_nutrition_skips_negative(self):
        items = [{"nutrition_type": "ENERGY", "amount_value": -5, "unit": "KCAL"}]
        result = _validate_nutrition(items)
        assert len(result) == 0

    def test_all_nutrition_types_valid(self):
        assert VALID_NUTRITION_TYPES == {
            "CARBOHYDRATE", "ENERGY", "FIBER", "PROTEIN",
            "SATURATED_FAT", "SODIUM", "SUGAR", "TOTAL_FAT", "TRANS_FAT",
        }

    def test_all_units_valid(self):
        assert VALID_UNITS == {"MG", "G", "KG", "ML", "L", "KCAL", "KJ", "PCS"}


class TestExtractProductData:
    @patch("app.llm.extractor.LLMClient")
    def test_extract_returns_structured_data(self, MockClient):
        mock_resp = LLMResponse(
            content=json.dumps({
                "product_name": "Test Milk",
                "ingredients": [{"name": "MILK"}],
                "allergens": [{"name": "MILK"}],
                "nutrition": [{"nutrition_type": "ENERGY", "amount_value": 61, "unit": "KCAL"}],
                "confidence_level": 0.85,
            }),
            model="gpt-4o-mini",
        )
        MockClient.return_value.chat.return_value = mock_resp

        result = extract_product_data(barcode="6281000000066")
        assert result.barcode == "6281000000066"
        assert result.product_name == "Test Milk"
        assert len(result.ingredients) == 1
        assert len(result.nutrition) == 1
        assert result.confidence_level == 0.85

    @patch("app.llm.extractor.LLMClient")
    def test_extract_handles_minimal_response(self, MockClient):
        mock_resp = LLMResponse(
            content=json.dumps({"confidence_level": 0.3}),
            model="gpt-4o-mini",
        )
        MockClient.return_value.chat.return_value = mock_resp

        result = extract_product_data(barcode="6281000000066")
        assert result.ingredients == []
        assert result.allergens == []
        assert result.nutrition == []


class TestEnrichProduct:
    @patch("app.llm.extractor.LLMClient")
    def test_enrich_returns_suggestions(self, MockClient):
        mock_resp = LLMResponse(
            content=json.dumps({
                "suggestions": [
                    {"field": "name", "current": "Milk", "suggested": "Whole Milk", "reason": "More specific"}
                ],
                "confidence": 0.9,
                "notes": "Looks good overall",
            }),
            model="gpt-4o-mini",
        )
        MockClient.return_value.chat.return_value = mock_resp

        result = enrich_product(
            barcode="6281000000066",
            product_json='{"name": "Milk"}',
        )
        assert len(result["suggestions"]) == 1
        assert result["confidence"] == 0.9
