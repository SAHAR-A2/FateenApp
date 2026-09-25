"""Extraction: RawProductData -> structured facts, each with an EvidenceItem.

This is where provenance is attached. A fact is only ever produced from data a
source actually returned — never invented. Ingredients are split verbatim; the
split is deterministic and the original text is preserved on the candidate.
"""

from __future__ import annotations

import logging

from ..constants import (
    FACT_ALLERGEN,
    FACT_BARCODE,
    FACT_BRAND,
    FACT_COMPANY,
    FACT_INGREDIENT,
    FACT_NAME,
    FACT_NUTRITION,
    FACT_PACKAGE,
    FACT_PRODUCT_URL,
)
from ..models import CandidateProduct, EvidenceItem, RawProductData
from ..normalization.ingredients import split_ingredients
from ..normalization.text import clean_ws

logger = logging.getLogger(__name__)


class ExtractedFacts:
    """Structured facts plus the evidence backing them."""

    def __init__(
        self,
        name: str | None = None,
        brand: str | None = None,
        company: str | None = None,
        barcode: str | None = None,
        package_size: str | None = None,
        ingredients: list[str] | None = None,
        ingredients_raw: str | None = None,
        allergens: list[str] | None = None,
        nutrition: dict[str, float] | None = None,
        evidence: list[EvidenceItem] | None = None,
    ):
        self.name = name
        self.brand = brand
        self.company = company
        self.barcode = barcode
        self.package_size = package_size
        self.ingredients = ingredients or []
        self.ingredients_raw = ingredients_raw
        self.allergens = allergens or []
        self.nutrition = nutrition or {}
        self.evidence = evidence or []


def extract_facts(raw: RawProductData) -> ExtractedFacts:
    """Extract evidence-backed facts from one raw source record."""
    ev: list[EvidenceItem] = []
    src = raw.source

    def add(fact: str, value: str | None) -> None:
        if value:
            ev.append(EvidenceItem(fact=fact, value=value, source=src))

    add(FACT_NAME, clean_ws(raw.name) or None)
    add(FACT_BRAND, clean_ws(raw.brand) or None)
    add(FACT_COMPANY, clean_ws(raw.company) or None)
    add(FACT_BARCODE, raw.barcode or None)
    add(FACT_PACKAGE, clean_ws(raw.package_size) or None)
    if raw.product_url:
        add(FACT_PRODUCT_URL, raw.product_url)

    ingredients_raw = clean_ws(raw.ingredients) or None
    ingredients: list[str] = []
    if raw.ingredients_parsed:
        ingredients = [i for i in raw.ingredients_parsed if i]
    elif ingredients_raw:
        ingredients = split_ingredients(ingredients_raw)

    for ing in ingredients:
        add(FACT_INGREDIENT, ing)

    for allergen in raw.allergens:
        if allergen:
            add(FACT_ALLERGEN, allergen)

    for fact_key, value in raw.nutrition.items():
        if value is not None:
            add(FACT_NUTRITION, f"{fact_key}={value}")

    return ExtractedFacts(
        name=clean_ws(raw.name) or None,
        brand=clean_ws(raw.brand) or None,
        company=clean_ws(raw.company) or None,
        barcode=raw.barcode,
        package_size=clean_ws(raw.package_size) or None,
        ingredients=ingredients,
        ingredients_raw=ingredients_raw,
        allergens=raw.allergens,
        nutrition=raw.nutrition,
        evidence=ev,
    )
