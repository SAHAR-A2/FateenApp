"""Explicit, reviewable OFF-tag -> FateenDB allergen.internal_code mapping.

Firestore stores user allergies as Open Food Facts-style tags (see
lib/data/allergy_options.dart in the Flutter app), e.g. "en:peanuts".
FateenDB's `allergens` table uses its own internal_code vocabulary, e.g.
"PEANUT".

Each tag maps to the set of codes that must count as a match. Wheat and
gluten map to both WHEAT and GLUTEN: Open Food Facts records wheat under
en:gluten, so a wheat-allergic user must be warned about a product whose
only evidence is GLUTEN, and a gluten-allergic user about one recorded as
WHEAT.

Two conditions guard a mapping before it is trusted:
  * `verified`: a human checked that the codes mean what the tag means.
    The codes were checked against the allergens rows archived from the
    pilot database (tests/fixtures/01_archive_pilot_data.sql) and against
    migration 0055, which defines GLUTEN, MOLLUSCS, CELERY, LUPIN and
    SULPHITES. SHELLFISH is described there as "Crustaceans and
    shellfish".
  * every code exists as a live row in public.allergens (checked at
    runtime, see live_allergen_codes). On a database without 0055 a gluten
    allergy therefore stays UNKNOWN instead of silently passing.

app.services.compatibility_service treats an unknown tag, an unverified
mapping and a missing code as UNKNOWN for that allergy, never as a silent
non-match/SAFE.
"""
import logging
import time
from dataclasses import dataclass
from typing import Optional

logger = logging.getLogger("fateen.services.allergen_mapping")


@dataclass(frozen=True)
class AllergenMapping:
    internal_codes: tuple[str, ...]
    verified: bool

    @property
    def internal_code(self) -> str:
        return self.internal_codes[0]


# tag -> mapping. Lookup is case-insensitive on the tag.
_MAPPING: dict[str, AllergenMapping] = {
    "en:peanuts": AllergenMapping(("PEANUT",), verified=True),
    "en:milk": AllergenMapping(("MILK",), verified=True),
    "en:eggs": AllergenMapping(("EGG",), verified=True),
    "en:wheat": AllergenMapping(("WHEAT", "GLUTEN"), verified=True),
    "en:gluten": AllergenMapping(("GLUTEN", "WHEAT"), verified=True),
    "en:fish": AllergenMapping(("FISH",), verified=True),
    "en:crustaceans": AllergenMapping(("SHELLFISH",), verified=True),
    "en:molluscs": AllergenMapping(("MOLLUSCS",), verified=True),
    "en:nuts": AllergenMapping(("TREE_NUTS",), verified=True),
    "en:soybeans": AllergenMapping(("SOY",), verified=True),
    "en:sesame-seeds": AllergenMapping(("SESAME",), verified=True),
    "en:celery": AllergenMapping(("CELERY",), verified=True),
    "en:mustard": AllergenMapping(("MUSTARD",), verified=True),
    "en:lupin": AllergenMapping(("LUPIN",), verified=True),
    "en:sulphur-dioxide-and-sulphites": AllergenMapping(("SULPHITES",), verified=True),
}

_CACHE_SECONDS = 600
_live_cache: tuple[float, frozenset[str]] = (0.0, frozenset())


def live_allergen_codes() -> frozenset[str]:
    """internal_codes of live allergens rows, cached for ten minutes.

    Fails closed: on a database error it returns an empty set, so every
    allergy resolves as not verified (UNKNOWN), never as SAFE.
    """
    global _live_cache
    fetched_at, codes = _live_cache
    if codes and time.monotonic() - fetched_at < _CACHE_SECONDS:
        return codes
    try:
        from app.db.connection import get_connection

        with get_connection() as conn:
            rows = conn.execute(
                "SELECT internal_code FROM public.allergens WHERE deleted_at IS NULL"
            ).fetchall()
        codes = frozenset(str(r["internal_code"]).upper() for r in rows)
    except Exception:
        logger.exception("Could not load allergens; treating every mapping as unverified")
        return frozenset()
    _live_cache = (time.monotonic(), codes)
    return codes


def resolve_allergen_codes(tag: str) -> Optional[tuple[tuple[str, ...], bool]]:
    """Resolve a client-supplied OFF-style allergy tag to
    (internal_codes, verified), or None if the tag is not mapped at all.

    `verified` is False when the mapping was not reviewed or when any of its
    codes is missing from public.allergens. Deliberately does not guess at
    unmapped tags.
    """
    if not tag:
        return None
    mapping = _MAPPING.get(tag.strip().lower())
    if mapping is None:
        return None
    verified = mapping.verified and set(mapping.internal_codes) <= live_allergen_codes()
    return mapping.internal_codes, verified


def all_mappings() -> dict[str, AllergenMapping]:
    """Exposed for the verification script and tests."""
    return dict(_MAPPING)
