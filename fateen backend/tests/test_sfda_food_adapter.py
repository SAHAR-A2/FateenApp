"""Offline contract tests for the SFDA Registered Food Products adapter.

These tests exercise `parse_food_product` / `parse_product_response` /
`to_product_record` and barcode validation against payloads that mirror the
official OpenAPI spec (dr.oetker white-chocolate-chips example). They require
NO network access and NO token, so the adapter's contract handling is proven
even while the live gateway is auth-blocked in this environment.

The `integration` marker is NOT applied: these are pure unit/contract tests.
"""

import pytest

from app.integrations.sfda_food_adapter import (
    SFDA_ERR_NO_API_PRODUCT,
    SfdaAuthenticationRequired,
    SfdaFoodAdapter,
    SfdaHttpError,
    SfdaValidationError,
    parse_food_product,
    parse_product_list_response,
    parse_product_response,
    to_product_record,
    validate_barcode,
)

# Documented FoodProduct example from the official OpenAPI spec
# (white chocolate chips, brand/trade/company Dr.Oetker).
SPEC_FOOD_PRODUCT_EXAMPLE = {
    "id": 1449070,
    "bayaN_ID": 1427992,
    "requestType": "SFDA.FIRS.Food.Domain.Item.RegisterItemRequest",
    "referanceNumber": "P-3-N-200621-107719",
    "submittedDate": "2021-06-20T12:56:14",
    "lastActionDate": "2021-06-23T02:41:41",
    "closeDate": "2021-06-23T02:41:41",
    "arStatus": "مسجل",
    "enStatus": "Registered",
    "isClosed": True,
    "barCode": "50254156",
    "brandName": "Dr.Oetker",
    "tradeName": "Dr.Oetker",
    "hsCode": "18040000",
    "itemWeight": 100,
    "unitNameAr": "جرام",
    "unitNameEn": "gm",
    "arCOO": "المملكة المتحدة",
    "enCOO": "United Kingdom",
    "arFoodGroup": "الكاكاو ومنتجاته & السكاكر",
    "enFoodGroup": "Cocoa & sweet confectionary",
    "itemDescription": "رقائق الشوكولاته البيضاء",
    "ingredientsAr": (
        "سكر، زبدة الكاكاو، مسحوق الحليب كامل الدسم، "
        "مسحوق مصل اللبن (حليب)، مستحلب ليسيثين الصويا"
    ),
    "ingredientsEn": "",
    "warnings": "فد تصبح الشوكولاتة ساخنة جدا، توخ الحذر عند التعمل مع الشوكولاتة بعد التسخين.",
    "companyName": "Dr.Oetker",
}


class TestParseFoodProduct:
    def test_preserves_all_fields_and_raw_payload(self):
        product = parse_food_product(SPEC_FOOD_PRODUCT_EXAMPLE)
        assert product.referanceNumber == "P-3-N-200621-107719"
        assert product.barCode == "50254156"
        assert product.brandName == "Dr.Oetker"
        assert product.itemWeight == 100
        assert product.unitNameAr == "جرام"
        assert product.unitNameEn == "gm"
        assert product.enStatus == "Registered"
        assert product.ingredientsEn == ""
        assert product.raw_payload == SPEC_FOOD_PRODUCT_EXAMPLE
        assert "ingredientsAr" in product.raw_payload

    def test_single_response_envelope(self):
        body = {"code": 200, "name": "OK", "data": {"result": SPEC_FOOD_PRODUCT_EXAMPLE}}
        product = parse_product_response(body)
        assert product.barCode == "50254156"

    def test_list_response_envelope(self):
        body = {
            "code": 200,
            "name": "OK",
            "data": [SPEC_FOOD_PRODUCT_EXAMPLE],
            "metadata": {
                "currentPage": 1,
                "pageCount": 121723,
                "pageSize": 10,
                "rowCount": 1217226,
                "firstRowOnPage": 1,
                "lastRowOnPage": 10,
            },
        }
        products, metadata = parse_product_list_response(body)
        assert len(products) == 1
        assert products[0].referanceNumber == "P-3-N-200621-107719"
        assert metadata["rowCount"] == 1217226


class TestToProductRecord:
    def test_maps_mission_dto(self):
        product = parse_food_product(SPEC_FOOD_PRODUCT_EXAMPLE)
        record = to_product_record(product, retrieved_at="2026-09-07T00:00:00Z")
        assert record.source == "SFDA"
        assert record.source_record_id == "P-3-N-200621-107719"
        assert record.registration_number == "P-3-N-200621-107719"
        assert record.barcode == "50254156"
        assert record.trade_name == "Dr.Oetker"
        assert record.brand == "Dr.Oetker"
        assert record.company == "Dr.Oetker"
        assert record.item_description == "رقائق الشوكولاته البيضاء"
        assert record.ingredients_ar == SPEC_FOOD_PRODUCT_EXAMPLE["ingredientsAr"]
        assert record.warnings_ar == SPEC_FOOD_PRODUCT_EXAMPLE["warnings"]
        assert record.weight == 100
        assert record.unit == "gm"
        assert record.raw_payload == SPEC_FOOD_PRODUCT_EXAMPLE

    def test_never_invents_english_ingredients(self):
        product = parse_food_product({**SPEC_FOOD_PRODUCT_EXAMPLE, "ingredientsEn": None, "ingredientsAr": None})
        record = to_product_record(product)
        assert record.ingredients_en is None
        assert record.ingredients_ar is None


class TestValidateBarcode:
    def test_normalizes_and_accepts_ean(self):
        assert validate_barcode("50254156") == "50254156"
        assert validate_barcode(" 5020-8000-1200 ") == "502080001200"

    def test_rejects_empty(self):
        with pytest.raises(SfdaValidationError):
            validate_barcode("   ")

    def test_rejects_implausible_length(self):
        with pytest.raises(SfdaValidationError):
            validate_barcode("123")

    def test_inherits_normalizer_strip_behavior(self):
        # FATEEN's normalize_barcode strips non-digits by convention, so
        # "ABC50254156" normalizes to the valid EAN "50254156" (consistent
        # with tests/test_agent_normalizers.py). Only empty/overshort inputs
        # are rejected.
        assert validate_barcode("ABC50254156") == "50254156"

    def test_rejects_letters_only(self):
        with pytest.raises(SfdaValidationError):
            validate_barcode("ABCDEF")


class TestErrorTaxonomy:
    def test_auth_failed_code(self):
        err = SfdaHttpError("x", status_code=401, code=SFDA_ERR_NO_API_PRODUCT)
        assert err.status_code == 401
        assert err.code == SFDA_ERR_NO_API_PRODUCT

    def test_validation_error_has_code(self):
        err = SfdaValidationError("bad barcode", code="BAD_BARCODE")
        assert err.code == "BAD_BARCODE"

    def test_missing_token_raises_before_network(self):
        adapter = SfdaFoodAdapter(token=None, base_url="https://example.invalid")
        adapter._token = ""  # force the no-token state
        assert adapter.token_configured() is False
        with pytest.raises(SfdaAuthenticationRequired):
            adapter.fetch_by_barcode("50254156")


class TestAccessReport:
    def test_access_report_shape(self):
        from app.integrations.sfda_food_adapter import access_report

        report = access_report()
        assert report["contract_version"].startswith("registered-food-service")
        assert report["base_url"].startswith("https://")
        assert "by_barcode" in report["endpoints"]
        assert "firs_list" in report["endpoints"]
        mechanisms = report["access_mechanisms"]
        assert isinstance(mechanisms["bearer_token"], bool)
        assert isinstance(mechanisms["firs_api_key"], bool)
        assert "note" in report