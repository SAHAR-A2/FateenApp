"""Barcode normalization/validation tests."""

from fateen_agent.normalization.barcode import gtin_type, is_valid_gtin, normalize_barcode


class TestNormalizeBarcode:
    def test_strips_non_digits(self):
        assert normalize_barcode("5 0010 1112 6172") == "5001011126172"

    def test_strips_separators(self):
        assert normalize_barcode("500-0111-2617-2") == "500011126172"


class TestValidGtin:
    def test_valid_ean13(self):
        # Nutella 400g — known valid EAN-13.
        assert is_valid_gtin("4006381333931") is True

    def test_invalid_check_digit(self):
        assert is_valid_gtin("4006381333932") is False

    def test_rejects_wrong_length(self):
        assert is_valid_gtin("123") is False
        assert is_valid_gtin("12345678901234567") is False

    def test_gtin_type(self):
        assert gtin_type("4006381333931") == "gtin_13"
        assert gtin_type("4012345678901") == "gtin_13"
        assert gtin_type("12345678") == "gtin_8"
        assert gtin_type("123456789012") == "gtin_12"
        assert gtin_type("12345678901234") == "gtin_14"
