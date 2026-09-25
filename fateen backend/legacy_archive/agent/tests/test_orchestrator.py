"""Orchestrator tests using fake sources (no network, no DB writes)."""

from fateen_agent.models import RawProductData, SourceInfo
from fateen_agent.pipeline.orchestrator import Orchestrator
from fateen_agent.sources.base import DataSource, ProductQuery
from fateen_agent.validation import VerificationPolicy


class FakeSource(DataSource):
    def __init__(self, name, records, priority="SECONDARY", source_type="database"):
        self.name = name
        self._records = records
        self._priority = priority
        self._source_type = source_type

    def _wrap(self, rec: dict) -> RawProductData:
        return RawProductData(
            source=SourceInfo(name=self.name, source_type=self._source_type, priority=self._priority),
            **rec,
        )

    def search(self, query):
        return [self._wrap(r) for r in self._records]

    def get(self, product_key):
        return []


class FakeRepo:
    """In-memory repository capturing writes for assertions."""

    def __init__(self):
        self.staged = []
        self.candidates = []
        self.evidence = []
        self.review = []
        self.processed = []
        self.promoted = []

    def stage_finding(self, *a, **k):
        self.staged.append(a)

    def save_candidate(self, cand):
        self.candidates.append(cand)
        return "cand-id"

    def save_evidence(self, *a, **k):
        self.evidence.append(a)

    def save_review_task(self, task):
        self.review.append(task)

    def record_processing(self, outcome, error=None):
        self.processed.append((outcome, error))

    def promote_candidate(self, cand):
        self.promoted.append(cand)

    def load_canonical_ingredients(self):
        return {}

    def load_ingredient_aliases(self):
        return []

    def load_ingredient_allergens(self):
        return []

    def load_ingredient_health_flags(self):
        return []

    def load_products_for_dedup(self):
        return []

    def load_barcode_index(self):
        return {}


def _policy_allowing_verified():
    return VerificationPolicy(verified_min_confidence=0.0)


class TestOrchestrator:
    def test_verified_with_two_agreeing_sources(self):
        srcs = [
            FakeSource("openfoodfacts", [dict(name="Test Milk", brand="Fateen", barcode="4006381333931", ingredients="milk, sugar")]),
            FakeSource("manufacturer_official", [dict(name="Test Milk", brand="Fateen", barcode="4006381333931", ingredients="milk, sugar")], priority="PRIMARY", source_type="manufacturer"),
        ]
        repo = FakeRepo()
        orch = Orchestrator(repo, srcs, policy=_policy_allowing_verified())
        outcome = orch.process(
            ProductQuery(barcode="4006381333931"), "4006381333931", "barcode"
        )
        assert outcome.status == "VERIFIED"
        assert repo.candidates and repo.candidates[0].name == "Test Milk"
        assert not repo.review  # verified -> no review task
        assert repo.promoted == []  # dry-run: never promoted

    def test_no_source_unresolved(self):
        repo = FakeRepo()
        orch = Orchestrator(repo, [], policy=_policy_allowing_verified())
        outcome = orch.process(ProductQuery(barcode="9999999999999"), "9999999999999", "barcode")
        assert outcome.status == "UNRESOLVED"
        assert repo.review  # unresolved -> review task

    def test_conflicting_sources_flag_conflict(self):
        srcs = [
            FakeSource("openfoodfacts", [dict(name="Milk Product", brand="A", barcode="4006381333931", ingredients="milk")]),
            FakeSource("manufacturer_official", [dict(name="Totally Different", brand="B", barcode="4006381333931", ingredients="milk")], priority="PRIMARY", source_type="manufacturer"),
        ]
        repo = FakeRepo()
        orch = Orchestrator(repo, srcs)
        outcome = orch.process(ProductQuery(barcode="4006381333931"), "4006381333931", "barcode")
        assert outcome.status == "CONFLICT"

    def test_source_error_does_not_kill_others(self):
        class BoomSource(DataSource):
            name = "boom"

            def search(self, query):
                raise RuntimeError("down")

            def get(self, product_key):
                return []

        srcs = [
            BoomSource(),
            FakeSource("openfoodfacts", [dict(name="X", brand="B", barcode="4006381333931", ingredients="milk")]),
        ]
        repo = FakeRepo()
        orch = Orchestrator(repo, srcs, policy=_policy_allowing_verified())
        outcome = orch.process(ProductQuery(barcode="4006381333931"), "4006381333931", "barcode")
        assert outcome.status == "VERIFIED"
