from app.agent.normalizers import (
    normalize_barcode,
    normalize_name,
    normalize_code,
)


class TestNormalizeBarcode:
    def test_strips_whitespace(self):
        assert normalize_barcode(" 628 1000 0000 66 ") == "6281000000066"

    def test_removes_dashes(self):
        assert normalize_barcode("628-1000-0000-66") == "6281000000066"

    def test_no_change_when_clean(self):
        assert normalize_barcode("6281000000066") == "6281000000066"

    def test_removes_letters(self):
        assert normalize_barcode("628ABC100") == "628100"


class TestNormalizeName:
    def test_lowercases(self):
        assert normalize_name("MILK") == "milk"

    def test_strips_whitespace(self):
        assert normalize_name("  Milk  ") == "milk"

    def test_no_change_when_already_lower(self):
        assert normalize_name("milk") == "milk"


class TestNormalizeCode:
    def test_lowercases(self):
        assert normalize_code("KCAL") == "kcal"

    def test_strips(self):
        assert normalize_code("  kcal  ") == "kcal"
