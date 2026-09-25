"""Verification policy tests."""

from fateen_agent.models import CandidateProduct
from fateen_agent.validation import VerificationPolicy

POLICY = VerificationPolicy()


def _candidate(**kw) -> CandidateProduct:
    base = dict(
        product_key="k",
        name="Test",
        barcode="4006381333931",
        brand="Acme",
        ingredients=["milk"],
        status="UNRESOLVED",
        confidence=0.8,
    )
    base.update(kw)
    return CandidateProduct(**base)


class TestVerify:
    def test_verified_when_full_evidence_high_confidence(self):
        r = POLICY.verify(_candidate())
        assert r.status == "VERIFIED"

    def test_conflict_when_unresolved(self):
        c = _candidate(conflicts=[{"fact": "name", "source_a": "a", "source_b": "b", "resolved": False}])
        r = POLICY.verify(c)
        assert r.status == "CONFLICT"

    def test_needs_review_when_ingredients_missing(self):
        c = _candidate(ingredients=[])
        r = POLICY.verify(c)
        assert r.status == "NEEDS_REVIEW"
        assert "ingredients" in r.missing_data

    def test_needs_review_when_barcode_missing(self):
        c = _candidate(barcode=None)
        r = POLICY.verify(c)
        assert r.status == "NEEDS_REVIEW"
        assert "barcode" in r.missing_data

    def test_needs_review_when_low_confidence(self):
        c = _candidate(confidence=0.3)
        r = POLICY.verify(c)
        assert r.status == "NEEDS_REVIEW"

    def test_never_verified_without_identity(self):
        c = _candidate(brand=None, company=None)
        r = POLICY.verify(c)
        assert r.status != "VERIFIED"
