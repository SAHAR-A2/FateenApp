"""Integration tests against the dev database (fateen_agent_dev).

Skipped automatically when the dev database is unreachable.
"""

import os

import pytest

from fateen_agent.config import Settings
from fateen_agent.db.repository import FateenRepository
from fateen_agent.models import CandidateProduct, EvidenceItem, ReviewTask, SourceInfo

pytestmark = pytest.mark.skipif(
    os.environ.get("FATEEN_TEST_DB") == "0",
    reason="DB integration tests disabled via FATEEN_TEST_DB=0",
)


@pytest.fixture(scope="module")
def repo():
    settings = Settings()
    r = FateenRepository(settings)
    if not r.ping():
        pytest.skip("dev database unreachable")
    return r


class TestRepository:
    def test_ping(self, repo):
        assert repo.ping() is True

    def test_canonical_vocab(self, repo):
        ingredients = repo.load_canonical_ingredients()
        assert "milk" in ingredients
        assert "soy" in ingredients
        allergens = repo.load_canonical_allergens()
        assert any(a["name"] == "Milk" for a in allergens)

    def test_enqueue_and_process_state_idempotent(self, repo):
        key = "TEST_12345"
        repo.enqueue(key, "barcode")
        repo.record_processing(
            type("O", (), {"product_key": key, "key_type": "barcode", "status": "UNRESOLVED", "confidence": 0.0})()
        )
        assert repo.is_processed(key, "barcode") is True

    def test_save_candidate_and_evidence(self, repo):
        cand = CandidateProduct(
            product_key="SAVE_TEST",
            name="Test",
            barcode="4006381333931",
            ingredients=["milk"],
            evidence=[EvidenceItem(fact="ingredient", value="milk",
                                   source=SourceInfo(name="openfoodfacts", source_type="database", priority="SECONDARY"))],
        )
        cid = repo.save_candidate(cand)
        assert cid
        for item in cand.evidence:
            repo.save_evidence(cid, cand.product_key, cand.key_type, item)

    def test_save_review_task(self, repo):
        task = ReviewTask(product_key="REV_TEST", problem="NEEDS_REVIEW", reason="test")
        repo.save_review_task(task)
