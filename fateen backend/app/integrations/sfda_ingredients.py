"""Parsing of SFDA Arabic/English ingredient strings into ingredient tokens.

The SFDA FIRS/Registered-Food services deliver the full ingredient statement
as a single `ingredientsAr` string (Arabic), e.g.:

    'سكر، زبدة الكاكاو، مسحوق الحليب كامل الدسم، مسحوق مصل اللبن (حليب)، مستحلب ليسيثين الصويا'

This module splits that statement deterministically (no LLM, no inference)
into candidate ingredient tokens, preserving annotations. Each token then
enters the existing FATEEN ingredient resolver; tokens that do not resolve are
carried as unresolved (quarantine) by downstream processing — never mapped to
a canonical FATEEN term arbitrarily.
"""

import re
from dataclasses import dataclass, field
from typing import Optional

# Commas used in Arabic ingredient statements plus Latin comma/semicolon.
_SEPARATOR_RE = re.compile(r"[،;,،]")

# Parenthetical annotations such as (حليب) / (مشتقات الألبان) / (E322).
_ANNOTATION_RE = re.compile(r"[\(（(][^\(\)（）]*[\)）)]")


@dataclass
class IngredientToken:
    """One candidate ingredient with the exact source spelling preserved."""

    source_term: str          # exact text as it appeared in the SFDA string
    annotation: Optional[str] = None  # parenthetical qualifier, if any
    normalized: str = ""      # normalized form (lowercased/trimmed)


@dataclass
class IngredientStatement:
    """Result of splitting one SFDA ingredient statement."""

    tokens: list[IngredientToken] = field(default_factory=list)


def _normalize_term(term: str) -> str:
    return " ".join(term.strip().lower().split())


def split_ingredient_text(text: Optional[str]) -> IngredientStatement:
    """Split an SFDA ingredient statement into deterministic ingredients.

    Rules (deterministic only):
      - Split on Arabic/English comma/semicolon separators.
      - A parenthetical annotation is detached from its head term and kept as
        the token's `annotation` (it often names an allergen, e.g. (حليب)).
      - Empty segments are dropped; no token is invented.
    """
    statement = IngredientStatement()
    if not text:
        return statement

    for raw_segment in _SEPARATOR_RE.split(text):
        head = raw_segment.strip()
        if not head:
            continue
        annotation = None
        m = _ANNOTATION_RE.search(head)
        if m:
            annotation = m.group(0).strip("()（）[]")
            head = (head[: m.start()] + head[m.end():]).strip()
            if m.end() < len(raw_segment.strip()):
                tail = raw_segment.strip()[m.end():].strip()
                if tail:
                    head = (head + " " + tail).strip()
        if not head:
            continue
        statement.tokens.append(
            IngredientToken(
                source_term=head,
                annotation=annotation,
                normalized=_normalize_term(head),
            )
        )

    return statement


def normalize_ingredient_term(term: str) -> str:
    """Deterministic normalization used for resolver lookups (trim/lower)."""
    return _normalize_term(term)