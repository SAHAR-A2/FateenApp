"""Ingredient-name handling: splitting, cleaning, canonical matching.

Matching against Fateen's canonical `ingredients` vocabulary is delegated to
the database repository (ingredients + ingredient_aliases). This module owns
deterministic splitting/cleaning of verbatim ingredient lists, plus pure
helpers for the matcher.
"""

from __future__ import annotations

import re

# Ingredient-list separators (incl. Arabic comma). Percentages/quantities stripped.
_SPLITTERS = re.compile(r"\s*,\s*|\s*;\s*|\s*•\s*|\s*·\s*|\s*،\s*|\n+")

# Leading/trailing quantity junk to strip from a single ingredient token.
_QUANTITY_LEAD = re.compile(
    r"^\s*(\d+(?:[.,]\d+)?\s*%?\s*(?:g|kg|mg|ml|l|oz|gr)?\s*[:\-]?\s*)",
    re.IGNORECASE,
)
_QUANTITY_TRAIL = re.compile(r"\s*\d+(?:[.,]\d+)?\s*%?\s*$")

# Trailing parenthetical like "(26%)" to strip.
_TRAILING_PAREN = re.compile(r"\s*\(\s*[^)]*\)\s*$")

# E-number tokens are kept as-is.
_ENUMBER = re.compile(r"^e\d{3,4}$", re.IGNORECASE)


def split_ingredients(raw: str) -> list[str]:
    """Split a verbatim ingredient list into candidate tokens (not canonical)."""
    if not raw:
        return []
    parts = [_SPLITTERS.sub(",", raw)]
    tokens_list: list[str] = []
    for part in parts:
        for chunk in part.split(","):
            token = _clean_token(chunk)
            if token and token not in tokens_list:
                tokens_list.append(token)
    return tokens_list


def _clean_token(chunk: str) -> str:
    t = chunk.strip()
    if is_enumber(t):
        return t.lower()
    t = _TRAILING_PAREN.sub("", t).strip()
    t = _QUANTITY_LEAD.sub("", t).strip()
    t = _QUANTITY_TRAIL.sub("", t).strip()
    t = t.strip(".:;,•،\u2013\u2014-()\"' ")
    t = re.sub(r"\s+", " ", t)
    return t


def is_enumber(token: str) -> bool:
    return bool(_ENUMBER.match(token.strip()))
