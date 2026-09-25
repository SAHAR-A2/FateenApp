"""Matching & deduplication helpers.

Pure functions over canonical vocabularies (loaded from the repository).
Fuzzy similarity is used ONLY to suggest candidates — never alone to enter
sensitive data into production. Exact barcode/alias matches take priority.
"""

from __future__ import annotations

from dataclasses import dataclass

from ..normalization.barcode import normalize_barcode
from ..normalization.text import normalize_text, similarity, token_overlap


@dataclass
class MatchScore:
    index: int
    value: str
    score: float
    method: str


def best_ingredient_match(
    token: str,
    canonical_names: list[str],
    alias_map: dict[str, list[int]],
    threshold: float = 0.86,
) -> MatchScore | None:
    """Return the best canonical ingredient index for a token.

    Priority: exact alias -> exact canonical -> high-similarity canonical.
    """
    norm = normalize_text(token)
    if not norm:
        return None

    # Exact alias match (aliases mapped to canonical index).
    for alias, idxs in alias_map.items():
        if normalize_text(alias) == norm:
            return MatchScore(idxs[0], canonical_names[idxs[0]], 1.0, "alias_exact")

    # Exact canonical match.
    for i, name in enumerate(canonical_names):
        if normalize_text(name) == norm:
            return MatchScore(i, name, 1.0, "exact")

    # Fuzzy suggestion (similarity or token overlap).
    best: MatchScore | None = None
    for i, name in enumerate(canonical_names):
        s = similarity(name, norm)
        if s >= threshold and (best is None or s > best.score):
            best = MatchScore(i, name, s, "similarity")
        else:
            to = token_overlap(name, norm)
            if to >= threshold and (best is None or to > best.score):
                best = MatchScore(i, name, to, "token_overlap")
    return best


def find_existing_product(
    barcode: str | None,
    name: str | None,
    brand: str | None,
    known_products: list[dict],
    barcode_index: dict[str, dict],
) -> dict | None:
    """Return the canonical product a candidate is likely the same as.

    Priority: exact barcode -> normalized-name match. Never a blind fuzzy
    match alone: barcode match must be exact, name match requires strong
    normalized equality (exact normalized name).
    """
    if barcode:
        key = normalize_barcode(barcode)
        if key in barcode_index:
            return barcode_index[key]

    if name:
        norm = normalize_text(name)
        for p in known_products:
            p_name = normalize_text((p.get("name") or ""))
            if p_name and p_name == norm:
                return p

        # Branded name similarity: require same brand AND very high similarity.
        if brand:
            norm_brand = normalize_text(brand)
            for p in known_products:
                p_brand = normalize_text((p.get("brand") or ""))
                if p_brand and p_brand == norm_brand:
                    p_name = normalize_text((p.get("name") or ""))
                    if p_name and similarity(p_name, norm) >= 0.92:
                        return p
    return None
