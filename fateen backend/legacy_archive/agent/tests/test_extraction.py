"""Extraction tests: raw source data -> evidence-backed facts."""

from fateen_agent.extraction import extract_facts
from fateen_agent.models import RawProductData, SourceInfo

OFF_SRC = SourceInfo(name="openfoodfacts", url="https://world.openfoodfacts.org/product/x",
                     source_type="database", priority="SECONDARY")


def test_extracts_evidence_for_every_fact():
    raw = RawProductData(
        source=OFF_SRC,
        name="Test Milk",
        brand="Fateen",
        barcode="4006381333931",
        ingredients="milk, sugar",
        allergens=["en:milk", "en:soy"],
        nutrition={"protein": 3.2, "sodium": 0.5},
        product_url="https://example/p",
    )
    facts = extract_facts(raw)
    assert facts.name == "Test Milk"
    assert facts.ingredients == ["milk", "sugar"]
    assert facts.allergens == ["en:milk", "en:soy"]
    facts_facts = {e.fact for e in facts.evidence}
    assert "name" in facts_facts
    assert "ingredient" in facts_facts
    assert "allergen" in facts_facts
    assert "nutrition" in facts_facts


def test_never_invents_facts():
    raw = RawProductData(source=OFF_SRC, name=None, ingredients=None)
    facts = extract_facts(raw)
    assert facts.ingredients == []
    assert facts.evidence == []


def test_source_provenance_attached():
    raw = RawProductData(source=OFF_SRC, name="Milk", ingredients="milk")
    facts = extract_facts(raw)
    for e in facts.evidence:
        assert e.source is OFF_SRC
        assert e.source.priority == "SECONDARY"
