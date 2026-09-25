"""Deterministic confidence engine.

Confidence is NOT an LLM guess. It is a weighted combination of explicit
signals, each defined below. Weights live in constants and can be overridden
in settings. The result is always in [0,1].
"""

from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Optional

from ..constants import (
    DEFAULT_CONFIDENCE_WEIGHTS,
    PRIORITY_PRIMARY,
    PRIORITY_RANK,
    RECENCY_HALF_LIFE_DAYS,
    SOURCE_TYPE_RELIABILITY,
)
from ..models import CandidateProduct


def _priority_factor(priority: str) -> float:
    """Map source priority rank (90..10) into a 0..1 factor."""
    return PRIORITY_RANK.get(priority, 10) / 90.0


def source_reliability_score(candidate: CandidateProduct) -> float:
    """Best reliability among sources that evidenced the product's core data."""
    best = 0.0
    for e in candidate.evidence:
        rel = SOURCE_TYPE_RELIABILITY.get(e.source.source_type, 0.2)
        best = max(best, rel * _priority_factor(e.source.priority))
    return best


def barcode_match_score(candidate: CandidateProduct) -> float:
    ev = candidate.evidence_for("barcode")
    if not ev:
        return 0.0
    # A confirmed barcode from a primary/secondary source.
    best = max(SOURCE_TYPE_RELIABILITY.get(e.source.source_type, 0.2) for e in ev)
    return best


def entity_match_score(candidate: CandidateProduct, fact: str) -> float:
    """Score for brand/company/name confirmation by source tier."""
    ev = candidate.evidence_for(fact)
    if not ev:
        return 0.0
    best = 0.0
    for e in ev:
        tier = 0.95 if e.source.priority == PRIORITY_PRIMARY else (
            0.80 if e.source.priority in ("SECONDARY",) else 0.40
        )
        best = max(best, tier)
    return best


def ingredient_evidence_score(candidate: CandidateProduct) -> float:
    """Fraction of declared ingredients backed by a >=SECONDARY source."""
    ev = candidate.evidence_for("ingredient")
    if not ev or not candidate.ingredients:
        return 0.0
    high_tier = [
        e
        for e in ev
        if e.source.priority in (PRIORITY_PRIMARY, "SECONDARY")
        and SOURCE_TYPE_RELIABILITY.get(e.source.source_type, 0.2) >= 0.75
    ]
    if not high_tier:
        return 0.0
    return min(1.0, len(high_tier) / max(1, len(candidate.ingredients)))


def recency_score(candidate: CandidateProduct, now: Optional[datetime] = None) -> float:
    now = now or datetime.now(timezone.utc)
    ages: list[float] = []
    for e in candidate.evidence:
        age_days = (now - e.source.retrieved_at).total_seconds() / 86400.0
        ages.append(max(0.0, age_days))
    if not ages:
        return 0.0
    age = min(ages)  # freshest evidence
    return 0.5 ** (age / RECENCY_HALF_LIFE_DAYS)


def compute_confidence(
    candidate: CandidateProduct,
    weights: Optional[dict[str, float]] = None,
    now: Optional[datetime] = None,
) -> float:
    """Weighted deterministic confidence in [0,1]."""
    w = dict(DEFAULT_CONFIDENCE_WEIGHTS)
    if weights:
        w.update({k: v for k, v in weights.items() if k in w})
    assert abs(sum(w.values()) - 1.0) < 1e-6, "weights must sum to 1"

    signals = {
        "source_reliability": source_reliability_score(candidate),
        "barcode_match": barcode_match_score(candidate),
        "brand_match": entity_match_score(candidate, "brand"),
        "company_match": entity_match_score(candidate, "company"),
        "name_match": entity_match_score(candidate, "name"),
        "ingredient_evidence": ingredient_evidence_score(candidate),
        "recency": recency_score(candidate, now),
    }
    raw = sum(w[k] * signals[k] for k in w)

    # Unresolved conflicts cap the score (a conflicted fact cannot be confident).
    unresolved = [c for c in candidate.conflicts if not c.resolved]
    if unresolved:
        raw = min(raw, 0.45)
    # If no barcode evidence at all, weight the barcode signal as zero benefit.
    if not candidate.evidence_for("barcode"):
        raw -= w["barcode_match"] * 0.5  # penalize missing barcode confirmation
    return round(min(1.0, max(0.0, raw)), 4)
