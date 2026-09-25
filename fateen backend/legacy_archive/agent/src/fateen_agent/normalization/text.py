"""Text normalization: unicode folding, Arabic handling, tokenization."""

from __future__ import annotations

import re
import unicodedata

# Arabic normalization maps (used for matching, NOT for display).
_ARABIC_DIACRITICS = re.compile(r"[\u064B-\u0652\u0670\u0653-\u0655]")
_ARABIC_KASHIDA = re.compile(r"\u0640")

# Folding map for Arabic letter variants to a canonical letter.
_AR_FOLD = str.maketrans(
    {
        "\u0622": "\u0627",  # آ -> ا
        "\u0623": "\u0627",  # أ -> ا
        "\u0625": "\u0627",  # إ -> ا
        "\u0621": "\u0627",  # ء -> ا
        "\u0624": "\u0648",  # ؤ -> و
        "\u0626": "\u064A",  # ئ -> ي
        "\u0649": "\u064A",  # ى -> ي
        "\u0671": "\u0627",  # ٱ -> ا
        "\u0629": "\u0647",  # ة -> ه
    }
)


def normalize_text(text: str) -> str:
    """Canonical form for matching: folded, diacritic-stripped, lowercased."""
    if not text:
        return ""
    s = unicodedata.normalize("NFKD", text)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = _ARABIC_DIACRITICS.sub("", s)
    s = _ARABIC_KASHIDA.sub("", s)
    s = s.translate(_AR_FOLD)
    return s.strip().lower()


def tokens(text: str) -> list[str]:
    """Language-independent normalized tokens (letters/numbers/unicode words)."""
    s = normalize_text(text)
    return [t for t in re.split(r"[^\w\u0600-\u06FF]+", s) if t]


def is_arabic(text: str) -> bool:
    return bool(re.search(r"[\u0600-\u06FF]", text))


def similarity(a: str, b: str) -> float:
    """Character-level normalized similarity in [0,1] (SequenceMatcher ratio)."""
    from difflib import SequenceMatcher

    return SequenceMatcher(None, normalize_text(a), normalize_text(b)).ratio()


def token_overlap(a: str, b: str) -> float:
    """Jaccard-like token overlap in [0,1]."""
    ta, tb = set(tokens(a)), set(tokens(b))
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


def clean_ws(text: str) -> str:
    """Collapse whitespace and strip punctuation noise."""
    return re.sub(r"\s+", " ", (text or "")).strip()
