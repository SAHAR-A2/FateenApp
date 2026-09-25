"""Explicit, reviewable OFF-tag -> FateenDB allergen.internal_code mapping.

Firestore stores user allergies using Open Food Facts-style tags (see
lib/data/allergy_options.dart in the Flutter app), e.g. "en:peanuts".
FateenDB's `allergens` table uses its own internal_code vocabulary, e.g.
"PEANUT" (confirmed via the verified baseline:
GET /api/v1/products/details/barcode/6281000000073 returns an allergen with
internal_code "PEANUT").

IMPORTANT — verification status:
Only the "en:peanuts" -> "PEANUT" entry has been confirmed against the live
`allergens` table (via the documented baseline). Every other entry below is
an unverified best guess following the same naming convention seen in
"PEANUT" and MUST be checked against the real database before being trusted
for a safety-relevant decision.

Run scripts/verify_allergen_mapping.py against the real FateenDB and update
the `verified` flag for each entry only once its internal_code is confirmed
to exist and mean what this file assumes it means.

This mapping deliberately does NOT silently drop unknown or unverified
tags. app.services.compatibility_service treats both "unknown tag" and
"unverified mapping" as UNKNOWN for that specific allergy, never as a
silent non-match/SAFE, so a missing or wrong mapping entry cannot produce a
false "this product is safe" result.
"""
from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class AllergenMapping:
    internal_code: str
    verified: bool


# tag -> mapping. Lookup is case-insensitive on the tag.
_MAPPING: dict[str, AllergenMapping] = {
    "en:peanuts": AllergenMapping("PEANUT", verified=True),
    "en:milk": AllergenMapping("MILK", verified=False),
    "en:eggs": AllergenMapping("EGG", verified=False),
    "en:wheat": AllergenMapping("WHEAT", verified=False),
    "en:gluten": AllergenMapping("GLUTEN", verified=False),
    "en:fish": AllergenMapping("FISH", verified=False),
    "en:crustaceans": AllergenMapping("CRUSTACEANS", verified=False),
    "en:molluscs": AllergenMapping("MOLLUSCS", verified=False),
    "en:nuts": AllergenMapping("TREE_NUTS", verified=False),
    "en:soybeans": AllergenMapping("SOY", verified=False),
    "en:sesame-seeds": AllergenMapping("SESAME", verified=False),
    "en:celery": AllergenMapping("CELERY", verified=False),
    "en:mustard": AllergenMapping("MUSTARD", verified=False),
    "en:lupin": AllergenMapping("LUPIN", verified=False),
    "en:sulphur-dioxide-and-sulphites": AllergenMapping("SULPHITES", verified=False),
}


def resolve_allergen_code(tag: str) -> Optional[tuple[str, bool]]:
    """Resolve a client-supplied OFF-style allergy tag to a
    (internal_code, verified) pair, or None if the tag is not in the
    mapping table at all.

    Deliberately does not guess at unmapped tags.
    """
    if not tag:
        return None
    mapping = _MAPPING.get(tag.strip().lower())
    if mapping is None:
        return None
    return mapping.internal_code, mapping.verified


def all_mappings() -> dict[str, AllergenMapping]:
    """Exposed for the verification script and tests."""
    return dict(_MAPPING)
