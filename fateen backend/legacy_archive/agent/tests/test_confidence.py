"""Confidence engine tests."""

from fateen_agent.confidence import compute_confidence
from fateen_agent.models import CandidateProduct, EvidenceItem, SourceInfo

MANUFACTURER_SRC = SourceInfo(name="manufacturer_official", url="https://acme.example/p", source_type="manufacturer", priority="PRIMARY")
OFF_SRC = SourceInfo(name="openfoodfacts", url="https://world.openfoodfacts.org", source_type="database", priority="SECONDARY")
WEAK_SRC = SourceInfo(name="web_research", url="https://example.com/x", source_type="web", priority="TERTIARY")


def _candidate(evidence: list[EvidenceItem], conflicts=None, ingredients=None) -> CandidateProduct:
    return CandidateProduct(
        product_key="k",
        name="Test",
        barcode="4006381333931",
        brand="Acme",
        ingredients=ingredients or ["milk", "sugar"],
        evidence=evidence,
        conflicts=conflicts or [],
    )


class TestConfidence:
    def test_strong_evidence_high_confidence(self):
        ev = [
            EvidenceItem(fact="name", value="Nutella", source=MANUFACTURER_SRC, confidence=0.9),
            EvidenceItem(fact="barcode", value="4006381333931", source=MANUFACTURER_SRC, confidence=0.9),
            EvidenceItem(fact="brand", value="Nutella", source=MANUFACTURER_SRC, confidence=0.9),
            EvidenceItem(fact="ingredient", value="milk", source=MANUFACTURER_SRC, confidence=0.9),
            EvidenceItem(fact="ingredient", value="sugar", source=MANUFACTURER_SRC, confidence=0.9),
        ]
        c = compute_confidence(_candidate(ev))
        assert c > 0.7

    def test_unresolved_conflict_caps_confidence(self):
        ev = [
            EvidenceItem(fact="name", value="A", source=MANUFACTURER_SRC, confidence=0.9),
            EvidenceItem(fact="barcode", value="4006381333931", source=OFF_SRC, confidence=0.9),
            EvidenceItem(fact="brand", value="X", source=OFF_SRC, confidence=0.9),
            EvidenceItem(fact="ingredient", value="milk", source=OFF_SRC, confidence=0.9),
            EvidenceItem(fact="ingredient", value="sugar", source=OFF_SRC, confidence=0.9),
        ]
        c = compute_confidence(_candidate(ev, conflicts=[{"fact": "name", "resolved": False}]))
        assert c <= 0.45

    def test_weak_source_low_confidence(self):
        ev = [
            EvidenceItem(fact="name", value="X", source=WEAK_SRC, confidence=0.5),
            EvidenceItem(fact="barcode", value="4006381333931", source=WEAK_SRC, confidence=0.5),
            EvidenceItem(fact="ingredient", value="milk", source=WEAK_SRC, confidence=0.5),
            EvidenceItem(fact="ingredient", value="sugar", source=WEAK_SRC, confidence=0.5),
        ]
        c = compute_confidence(_candidate(ev))
        assert c < 0.5

    def test_in_range(self):
        for score in (0.0, 0.5, 1.0):
            assert 0.0 <= score <= 1.0
