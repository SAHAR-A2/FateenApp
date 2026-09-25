"""Tests for the ingredient / allergen / health-flag canonicalization layer.

Covers: loading the synthetic vocabulary seed, mapping raw ingredient tokens
to canonical ingredients (English + Arabic aliases), deriving normalized
allergens and health flags (sugar / salt / chronic-disease markers), keeping
unmatched tokens for human review, and proving an empty vocabulary is a
transparent no-op.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from fateen_agent.db.inmemory import InMemoryRepository, load_vocabulary
from fateen_agent.models import RawProductData, SourceInfo
from fateen_agent.pipeline.batch import BatchProcessor
from fateen_agent.pipeline.orchestrator import Orchestrator
from fateen_agent.sources.base import ProductQuery
from fateen_agent.sources.fixture import FixtureSource
from fateen_agent.validation import VerificationPolicy

FIXTURE = Path(__file__).parent / "fixtures" / "products_10.json"
VOCAB = Path(__file__).parent / "fixtures" / "vocabulary.json"

EXPECTED = {
    "5901234123457": "VERIFIED",
    "5901234123464": "NEEDS_REVIEW",
    "5901234123471": "CONFLICT",
    "5901234123488": "CONFLICT",
    "5901234123495": "UNRESOLVED",
    "5901234123501": "VERIFIED",
    "5901234123518": "VERIFIED",
    "5901234123525": "NEEDS_REVIEW",
    "5901234123549": "VERIFIED",
    "5901234123556": "VERIFIED",
}


class FakeSource:
    name = "fake"

    def __init__(self, ingredients: str, priority="PRIMARY", source_type="manufacturer"):
        self._ingredients = ingredients
        self._priority = priority
        self._source_type = source_type

    def search(self, query):
        return [
            RawProductData(
                source=SourceInfo(
                    name=self.name,
                    source_type=self._source_type,
                    priority=self._priority,
                ),
                name="Test Product",
                brand="Acme",
                barcode=query.barcode,
                ingredients=self._ingredients,
            )
        ]

    def get(self, product_key):
        return []


def _seeded_repo() -> InMemoryRepository:
    return InMemoryRepository(seed=load_vocabulary(VOCAB))


def _run(repo, barcode="5901234123457") -> tuple:
    orch = Orchestrator(repository=repo, sources=[FakeSource("Wheat flour, sugar, sea salt")], promote_verified=False)
    return orch.process(ProductQuery(barcode=barcode), barcode, "barcode")


class TestLoadVocabulary:
    def test_seed_parses_canonical_ingredients(self):
        seed = load_vocabulary(VOCAB)
        canonical = seed["canonical_ingredients"]
        assert canonical["sugar"]["name"] == "Sugar"
        assert canonical["salt"]["id"] == 5
        assert canonical["oats"]["id"] == 1
        assert len(canonical) == 16

    def test_seed_parses_alias_links(self):
        seed = load_vocabulary(VOCAB)
        aliases = {a["alias"]: a["ingredient_id"] for a in seed["aliases"]}
        assert aliases["Rolled oats"] == 1
        assert aliases["شوفان"] == 1
        assert aliases["سكر"] == 4
        assert aliases["ملح"] == 5
        assert aliases["sea salt"] == 5

    def test_seed_parses_allergen_links(self):
        seed = load_vocabulary(VOCAB)
        links = {(ia["ingredient_id"], ia["internal_code"]) for ia in seed["ingredient_allergens"]}
        assert (15, "gluten") in links  # wheat flour -> gluten
        assert (7, "soy") in links      # soy lecithin -> soy
        assert (14, "peanuts") in links  # peanuts -> peanuts

    def test_seed_parses_health_flag_links(self):
        seed = load_vocabulary(VOCAB)
        sugar_flags = {
            ih["internal_code"]
            for ih in seed["ingredient_health_flags"]
            if ih["ingredient_id"] == 4
        }
        assert sugar_flags == {"high_sugar", "chronic_diabetes_risk"}
        salt_flags = {
            ih["internal_code"]
            for ih in seed["ingredient_health_flags"]
            if ih["ingredient_id"] == 5
        }
        assert salt_flags == {"high_salt", "chronic_cardiovascular_risk"}

    def test_missing_vocabulary_returns_empty_seed(self, tmp_path):
        assert load_vocabulary(tmp_path / "nope.json") == {}


class TestCanonicalization:
    def test_maps_tokens_and_derives_allergens_and_flags(self):
        outcome = _run(_seeded_repo())
        cand = outcome.candidate
        assert cand.canonical_ingredients == ["Wheat flour", "Sugar", "Salt"]
        assert cand.unmatched_ingredients == []
        allergen_codes = {a["code"] for a in cand.derived_allergens}
        assert allergen_codes == {"gluten"}
        flag_codes = {f["code"] for f in cand.derived_health_flags}
        assert flag_codes == {
            "high_sugar",
            "high_salt",
            "chronic_diabetes_risk",
            "chronic_cardiovascular_risk",
        }

    def test_alias_exact_beats_fuzzy(self):
        outcome = _run(_seeded_repo())
        by_token = {m["token"]: m for m in outcome.candidate.ingredient_matches}
        assert by_token["sea salt"]["method"] == "alias_exact"
        assert by_token["sea salt"]["canonical_name"] == "Salt"
        assert by_token["Wheat flour"]["method"] == "exact"
        assert by_token["Wheat flour"]["score"] == 1.0

    def test_arabic_tokens_map_to_canonical(self):
        repo = _seeded_repo()
        orch = Orchestrator(
            repository=repo,
            sources=[FakeSource("شوفان، سكر، ملح، زيت نباتي")],
            promote_verified=False,
        )
        outcome = orch.process(ProductQuery(barcode="5901234123501"), "5901234123501", "barcode")
        cand = outcome.candidate
        assert cand.canonical_ingredients == ["Oats", "Sugar", "Salt", "Vegetable oil"]
        assert cand.unmatched_ingredients == []
        flag_codes = {f["code"] for f in cand.derived_health_flags}
        assert flag_codes == {
            "high_sugar",
            "high_salt",
            "chronic_diabetes_risk",
            "chronic_cardiovascular_risk",
        }

    def test_unknown_token_goes_to_unmatched(self):
        repo = _seeded_repo()
        orch = Orchestrator(
            repository=repo,
            sources=[FakeSource("Aqua-fanta, sugar")],
            promote_verified=False,
        )
        outcome = orch.process(ProductQuery(barcode="5901234123525"), "5901234123525", "barcode")
        cand = outcome.candidate
        assert cand.unmatched_ingredients == ["Aqua-fanta"]
        assert cand.canonical_ingredients == ["Aqua-fanta", "Sugar"]
        assert {f["code"] for f in cand.derived_health_flags} == {
            "high_sugar",
            "chronic_diabetes_risk",
        }

    def test_duplicate_derivation_is_deduplicated(self):
        repo = _seeded_repo()
        orch = Orchestrator(
            repository=repo,
            sources=[FakeSource("Sugar, sucrose syrup")],
            promote_verified=False,
        )
        outcome = orch.process(ProductQuery(barcode="5901234123457"), "5901234123457", "barcode")
        cand = outcome.candidate
        codes = [f["code"] for f in cand.derived_health_flags]
        assert codes.count("high_sugar") == 1

    def test_empty_vocabulary_is_transparent_noop(self):
        outcome = _run(InMemoryRepository())
        cand = outcome.candidate
        assert cand.canonical_ingredients == ["Wheat flour", "sugar", "sea salt"]
        assert cand.ingredient_matches == []
        assert cand.derived_allergens == []
        assert cand.derived_health_flags == []
        assert cand.unmatched_ingredients == ["Wheat flour", "sugar", "sea salt"]


class TestSeededOfflinePipeline:
    def test_statuses_unchanged_with_seeded_vocabulary(self):
        repo = _seeded_repo()
        batch_id = repo.start_batch("seeded_offline")
        orch = Orchestrator(repository=repo, sources=[FixtureSource(FIXTURE)], batch_id=batch_id, promote_verified=False)
        processor = BatchProcessor(
            process_one=orch.process,
            batch_label="seeded_offline",
            batch_id=batch_id,
            workers=1,
            retries=0,
            rate_limit_per_sec=1000.0,
            skip_processed=False,
            record_batch_item=repo.record_batch_item,
        )
        queries = [(ProductQuery(barcode=k), k, "barcode") for k in EXPECTED]
        result = processor.run(queries)

        by_key = {o.product_key: o for o in result.outcomes}
        for key, expected in EXPECTED.items():
            assert by_key[key].status == expected

    def test_seeded_pipeline_derives_allergens(self):
        repo = _seeded_repo()
        orch = Orchestrator(repository=repo, sources=[FixtureSource(FIXTURE)], promote_verified=False)
        # case-10: wheat flour -> gluten
        out = orch.process(ProductQuery(barcode="5901234123556"), "5901234123556", "barcode")
        assert {a["code"] for a in out.candidate.derived_allergens} == {"gluten"}
        # case-04: soy lecithin -> soy
        out = orch.process(ProductQuery(barcode="5901234123488"), "5901234123488", "barcode")
        assert {a["code"] for a in out.candidate.derived_allergens} == {"soy"}
        # case-09: roasted peanuts -> peanuts
        out = orch.process(ProductQuery(barcode="5901234123549"), "5901234123549", "barcode")
        assert {a["code"] for a in out.candidate.derived_allergens} == {"peanuts"}

    def test_seeded_pipeline_derives_health_flags(self):
        repo = _seeded_repo()
        orch = Orchestrator(repository=repo, sources=[FixtureSource(FIXTURE)], promote_verified=False)
        out = orch.process(ProductQuery(barcode="5901234123501"), "5901234123501", "barcode")
        cand = out.candidate
        assert cand.canonical_ingredients == ["Oats", "Sugar", "Salt", "Vegetable oil"]
        assert cand.unmatched_ingredients == []
        flag_codes = {f["code"] for f in cand.derived_health_flags}
        assert flag_codes == {
            "high_sugar",
            "high_salt",
            "chronic_diabetes_risk",
            "chronic_cardiovascular_risk",
        }

    def test_seeded_pipeline_leaves_no_unmatched_in_fixtures(self):
        repo = _seeded_repo()
        batch_id = repo.start_batch("no_unmatched")
        orch = Orchestrator(repository=repo, sources=[FixtureSource(FIXTURE)], batch_id=batch_id, promote_verified=False)
        processor = BatchProcessor(
            process_one=orch.process,
            batch_label="no_unmatched",
            batch_id=batch_id,
            workers=1,
            retries=0,
            rate_limit_per_sec=1000.0,
            skip_processed=False,
            record_batch_item=repo.record_batch_item,
        )
        result = processor.run([(ProductQuery(barcode=k), k, "barcode") for k in EXPECTED])
        for o in result.outcomes:
            cand = o.candidate
            if cand and cand.unmatched_ingredients:
                raise AssertionError(
                    f"{o.product_key}: unmatched tokens {cand.unmatched_ingredients}"
                )
