import math
from app.agent.validators import validate_barcode, validate_confidence


class TestValidateBarcode:
    def test_valid_barcode(self):
        assert validate_barcode("6281000000066") == []

    def test_empty_barcode(self):
        errors = validate_barcode("")
        assert len(errors) == 1
        assert "empty" in errors[0]

    def test_none_like_empty(self):
        errors = validate_barcode("")
        assert len(errors) == 1

    def test_letters_rejected(self):
        errors = validate_barcode("628ABC100DEF")
        assert len(errors) == 1
        assert "non-digit" in errors[0]

    def test_too_short(self):
        errors = validate_barcode("123")
        assert len(errors) == 1
        assert "outside" in errors[0]

    def test_too_long(self):
        errors = validate_barcode("1" * 20)
        assert len(errors) == 1
        assert "outside" in errors[0]

    def test_valid_length_8(self):
        assert validate_barcode("12345678") == []

    def test_valid_length_14(self):
        assert validate_barcode("12345678901234") == []


class TestValidateConfidence:
    def test_valid_zero(self):
        assert validate_confidence(0) == []

    def test_valid_one(self):
        assert validate_confidence(1) == []

    def test_valid_half(self):
        assert validate_confidence(0.5) == []

    def test_below_zero(self):
        errors = validate_confidence(-0.1)
        assert len(errors) == 1
        assert "outside" in errors[0]

    def test_above_one(self):
        errors = validate_confidence(1.1)
        assert len(errors) == 1
        assert "outside" in errors[0]

    def test_none(self):
        errors = validate_confidence(None)
        assert len(errors) == 1
        assert "None" in errors[0]

    def test_nan(self):
        errors = validate_confidence(float("nan"))
        assert len(errors) == 1
        assert "NaN" in errors[0]

    def test_string(self):
        errors = validate_confidence("high")
        assert len(errors) == 1
        assert "not numeric" in errors[0]
