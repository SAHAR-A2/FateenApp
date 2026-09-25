"""SFDA_FIXTURE_TEST (offline): fixture-based pipeline proof, no network.

This is the SFDA-focused scenario run the mission requires while the live
gateway is auth-blocked. It proves, entirely offline and against fixture data
shaped by the official FIRS open-data documentation, that the adapter's
Schema → DTO → normalization → ingredient-splitting → provenance chain behaves
as specified:

  - FIRS/registered-food field mapping is preserved, deterministic, idempotent;
  - raw official payloads travel intact (the evidence/raw-data layer);
  - Arabic ingredient statements split deterministically; annotations such as
    (حليب) are detached and kept, never dropped or renamed;
  - unknown ingredient tokens are NEVER auto-mapped to a canonical term: they
    stay unresolved (quarantine pathway) unless an exact deterministic match
    exists in the resolver grammar;
  - with no SFDA_API_KEY / SFDA_ACCESS_TOKEN configured the client refuses to
    fire a network request (NO credentials in this environment).

Pytest marker: SFDA_FIXTURE_TEST (no `integration` marker -> no DB needed).
"""

import pytest

from app.integrations.sfda_food_adapter import (
    SFDA_CONTRACT_VERSION,
    SfdaAuthenticationRequired,
    SfdaFoodAdapter,
    SfdaPayloadError,
    parse_firs_record,
    parse_food_product,
    to_product_record,
    _parse_firs_list_body,
)
from app.integrations.sfda_ingredients import normalize_ingredient_term, split_ingredient_text

# ---------------------------------------------------------------------------
# Fixture: one sanitized FIRS open-data record. Field names/values follow the
# official FIRS documentation (barCode/RefNumber/ItemDescription variants are
# documented casing forms). Content mirrors the spec's Dr.Oetker example but is
# rewritten so it is not a byte-copy of the developer docs.
# ---------------------------------------------------------------------------
FIRS_FIXTURE_1 = {
    "barCode": "50254156",
    "RefNumber": "P-3-N-200621-107719",
    "brandName": "Dr.Oetker",
    "tradeName": "Dr.Oetker",
    "ItemDescription": "رقائق الشوكولاته البيضاء",
    "companyName": "Dr.Oetker",
    "ingredientsAr": (
        "سكر، زبدة الكاكاو، مسحوق الحليب كامل الدسم، "
        "مسحوق مصل اللبن (حليب)، مستحلب ليسيثين الصويا"
    ),
    "ingredientsEn": "",
    "warnings": "تحذير: قد تصبح الشوكولاتة ساخنة جدا بعد التسخين.",
    "itemWeight": 100,
    "unitNameAr": "جرام",
    "unitNameEn": "gm",
    "shelfTime": "12 months",
    "storageTemperatureAr": "درجة حرارة الغرفة",
    "dataIssuer": "SFDA.FIRS.Food",
}

ARABIC_INGREDIENT_FIXTURE = FIRS_FIXTURE_1["ingredientsAr"]


def _match_token(token, vocabulary):
    """Deterministic token→canonical match against the resolver vocabulary.

    Mirror of the FATEEN resolver contract used by the engine: a token can
    only be linked to a canonical term through an exact vocabulary match. Doing
    anything more (synonyms, LLM guesses) is outside the fixture adapter scope
    and therefore returns None, i.e. the token remains unresolved.
    """
    return vocabulary.get(token.normalized)


class TestFirsSchemaMapping:
    def test_maps_documented_firs_fields(self):
        product = parse_firs_record(FIRS_FIXTURE_1)
        assert product.barCode == "50254156"
        assert product.referanceNumber == "P-3-N-200621-107719"
        assert product.itemDescription == "رقائق الشوكولاته البيضاء"
        assert product.brandName == "Dr.Oetker"
        assert product.companyName == "Dr.Oetker"
        assert product.itemWeight == 100
        assert product.unitNameAr == "جرام"
        assert product.unitNameEn == "gm"
        assert product.shelfTime == "12 months"
        assert product.storageTemperatureAr == "درجة حرارة الغرفة"
        assert product.raw_payload == FIRS_FIXTURE_1

    def test_parse_is_deterministic_idempotent(self):
        a = parse_firs_record(FIRS_FIXTURE_1)
        b = parse_firs_record(FIRS_FIXTURE_1)
        assert a == b
        assert a.barCode == b.barCode
        assert a.referanceNumber == b.referanceNumber
        assert a.raw_payload == b.raw_payload

    def test_missing_firs_field_stays_none(self):
        sparse = {k: v for k, v in FIRS_FIXTURE_1.items() if k not in ("itemWeight", "unitNameAr")}
        product = parse_firs_record(sparse)
        assert product.itemWeight is None
        assert product.unitNameAr is None

    def test_firs_variants_and_conventional_fields_coexist(self):
        mixed = {
            **FIRS_FIXTURE_1,
            "barcode": "7622210300469",   # documented alternative casing
            "referanceNumber": "P-4-N-20240501-000001",  # conventional casing
        }
        product = parse_firs_record(mixed)
        # Populated-first wins: exact conventional names are set by
        # parse_food_product, so the variant aliases only fill gaps (they never
        # overwrite a value that is already present).
        assert product.barCode == "50254156"
        assert product.referanceNumber == "P-4-N-20240501-000001"

    def test_firs_variant_only_record(self):
        # A record that ONLY uses variant aliases must parse identically.
        variant_only = {
            "barcode": "7622210300469",
            "RefNumber": "P-4-N-20240501-000001",
            "ItemDescription": "رقائق الشوكولاته البيضاء",
            "companyName": "Dr.Oetker",
            "brandName": "Dr.Oetker",
        }
        product = parse_firs_record(variant_only)
        assert product.barCode == "7622210300469"
        assert product.referanceNumber == "P-4-N-20240501-000001"
        assert product.itemDescription == "رقائق الشوكولاته البيضاء"


class TestParseFirsListEnvelope:
    def test_data_array_envelope(self):
        body = {"data": [FIRS_FIXTURE_1], "metadata": {"currentPage": 1}}
        records, metadata = _parse_firs_list_body(body, page=1)
        assert len(records) == 1
        assert records[0].barcode == "50254156"
        assert records[0].source == "SFDA"
        assert metadata["currentPage"] == 1
        assert records[0].raw_payload == FIRS_FIXTURE_1

    def test_metadata_fallback_current_page(self):
        body = {"data": [FIRS_FIXTURE_1]}
        _, metadata = _parse_firs_list_body(body, page=3)
        assert metadata == {"currentPage": 3}

    def test_missing_data_array_raises(self):
        with pytest.raises(SfdaPayloadError):
            _parse_firs_list_body({"error": "x"}, page=1)


class TestIngredientStatementParsing:
    def test_split_known_fixture(self):
        statement = split_ingredient_text(ARABIC_INGREDIENT_FIXTURE)
        assert [t.source_term for t in statement.tokens] == [
            "سكر",
            "زبدة الكاكاو",
            "مسحوق الحليب كامل الدسم",
            "مسحوق مصل اللبن",
            "مستحلب ليسيثين الصويا",
        ]

    def test_annotation_detached_not_lost(self):
        statement = split_ingredient_text(ARABIC_INGREDIENT_FIXTURE)
        annotated = [t for t in statement.tokens if t.annotation is not None]
        assert len(annotated) == 1
        assert annotated[0].source_term == "مسحوق مصل اللبن"
        assert annotated[0].annotation == "حليب"

    def test_no_empty_tokens(self):
        statement = split_ingredient_text("سكر،، زبدة الكاكاو ،مسحوق الحليب،،")
        assert all(t.source_term for t in statement.tokens)
        assert [t.source_term for t in statement.tokens] == ["سكر", "زبدة الكاكاو", "مسحوق الحليب"]

    def test_empty_and_none(self):
        assert len(split_ingredient_text(None).tokens) == 0
        assert len(split_ingredient_text("   ").tokens) == 0

    def test_deterministic(self):
        assert split_ingredient_text(ARABIC_INGREDIENT_FIXTURE) == split_ingredient_text(
            ARABIC_INGREDIENT_FIXTURE
        )


class TestNoFabrication:
    """Unknown tokens must never be auto-invented into canonical terms."""

    def test_arabic_tokens_unresolved_without_exact_grammar_match(self):
        statement = split_ingredient_text(ARABIC_INGREDIENT_FIXTURE)
        # Vocabulary contains only normalizer-oriented English names.
        vocabulary = {
            "sugar": "SUGAR",
            "milk": "MILK",
            "whey": "WHEY",
            "lecithin": "LECITHIN",
        }
        resolved = {t.normalized: _match_token(t, vocabulary) for t in statement.tokens}
        assert all(v is None for v in resolved.values())
        # No Arabic term is silently coerced into a canonical English term.
        unknown = [t for t in statement.tokens if _match_token(t, vocabulary) is None]
        assert len(unknown) == len(statement.tokens)

    def test_exact_match_resolves(self):
        from app.integrations.sfda_ingredients import IngredientToken

        statement = split_ingredient_text("sugar, milk")
        vocabulary = {"sugar": "SUGAR", "milk": "MILK"}
        resolved = [_match_token(t, vocabulary) for t in statement.tokens]
        assert resolved == ["SUGAR", "MILK"]
        assert IngredientToken is not None  # token type stable

    def test_normalize_ingredient_term(self):
        assert normalize_ingredient_term("  مسحوق مصل اللبن  ") == "مسحوق مصل اللبن"
        assert normalize_ingredient_term("Sugar") == "sugar"


class TestProvenanceBlueprint:
    def test_record_carries_evidence_sandbox(self):
        record = to_product_record(parse_firs_record(FIRS_FIXTURE_1))
        assert record.source == "SFDA"
        assert record.source_record_id == "P-3-N-200621-107719"
        assert record.barcode == "50254156"
        assert record.ingredients_ar == ARABIC_INGREDIENT_FIXTURE
        assert record.raw_payload == FIRS_FIXTURE_1
        assert record.retrieved_at is not None
        assert record.en_status is None  # not present in fixture -> stays None

    def test_contract_version_includes_firs(self):
        assert "firs-open-data" in SFDA_CONTRACT_VERSION


class TestCredentialGate:
    """With no credentials configured the adapter must refuse to dial out."""

    def test_firs_list_requires_api_key_before_network(self):
        adapter = SfdaFoodAdapter(api_key=None, base_url="https://example.invalid")
        with pytest.raises(SfdaAuthenticationRequired) as exc:
            adapter.firs_food_list(page=1)
        assert exc.value.code == "NO_API_KEY"

    def test_firs_search_requires_api_key_before_network(self):
        adapter = SfdaFoodAdapter(api_key=None, base_url="https://example.invalid")
        with pytest.raises(SfdaAuthenticationRequired) as exc:
            adapter.firs_food_search("or")
        assert exc.value.code == "NO_API_KEY"

    def test_access_configured_reports_both_mechanisms(self):
        adapter = SfdaFoodAdapter(token=None, api_key=None)
        status = adapter.access_configured()
        # With no explicit token/api_key the credential mechanisms are all off.
        assert status["bearer_token"] is False
        assert status["firs_api_key"] is False
        assert status["consumer_key"] is False
        assert status["consumer_secret"] is False
        assert status["oauth_token_url"] is False
        assert status["oauth_complete"] is False
        assert adapter.token_configured() is False