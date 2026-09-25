"""Text normalization tests (incl. Arabic)."""

from fateen_agent.normalization.text import is_arabic, normalize_text, similarity, token_overlap, tokens


class TestNormalizeText:
    def test_basic_lower(self):
        assert normalize_text("Milk") == "milk"

    def test_unicode_fold(self):
        assert normalize_text("ﬁsh") == "fish"
        assert normalize_text("Café") == "cafe"

    def test_arabic_hamza_fold(self):
        assert normalize_text("ألبان") == "البان"
        assert normalize_text("آلآء") == "الاا"

    def test_arabic_teh_marbuta(self):
        assert normalize_text("جبنة") == "جبنه"

    def test_arabic_diacritics_stripped(self):
        assert normalize_text("حَلِيبٌ") == "حليب"

    def test_kashida_stripped(self):
        assert normalize_text("مكــونات") == "مكونات"


class TestIsArabic:
    def test_detect_arabic(self):
        assert is_arabic("حليب") is True
        assert is_arabic("milk") is False


class TestSimilarity:
    def test_identical(self):
        assert similarity("Milk", "milk") == 1.0

    def test_similar_partial(self):
        assert similarity("wheat flour", "wheat") > 0.3

    def test_arabic_similar(self):
        assert similarity("قمح", "قمح") == 1.0


class TestTokens:
    def test_tokenization(self):
        assert set(tokens("Milk, soy lecithin")) == {"milk", "soy", "lecithin"}

    def test_token_overlap(self):
        assert token_overlap("milk chocolate", "milk chocolate bar") > 0.5
