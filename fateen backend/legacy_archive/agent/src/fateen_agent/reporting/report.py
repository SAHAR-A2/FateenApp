"""Batch reporting."""

from __future__ import annotations

import logging
from typing import Iterable

from ..constants import AGENT_STATUSES
from ..models import BatchSummary, ProductOutcome
from rich.console import Console
from rich.table import Table

logger = logging.getLogger(__name__)


def summarize(batch_label: str, outcomes: Iterable[ProductOutcome]) -> BatchSummary:
    outcomes = list(outcomes)
    counts = {s: 0 for s in AGENT_STATUSES}
    for o in outcomes:
        counts[o.status] = counts.get(o.status, 0) + 1
    return BatchSummary(
        batch_label=batch_label,
        total=len(outcomes),
        verified=counts["VERIFIED"],
        needs_review=counts["NEEDS_REVIEW"],
        conflict=counts["CONFLICT"],
        unresolved=counts["UNRESOLVED"],
        failed=counts["FAILED"],
        details=[_outcome_detail(o) for o in outcomes],
    )


def _outcome_detail(o: ProductOutcome) -> dict:
    """One product's outcome row with the exact validation reason."""
    cand = o.candidate
    unresolved = [c for c in (cand.conflicts if cand else []) if not c.resolved]
    return {
        "product_key": o.product_key,
        "key_type": o.key_type,
        "status": o.status,
        "confidence": o.confidence,
        "detail": o.error or (o.review_task.reason if o.review_task else None),
        "reason": o.error or (o.review_task.reason if o.review_task else None),
        "missing_data": list(cand.missing_data) if cand else [],
        "notes": list(cand.notes) if cand else [],
        "conflicts": [
            {
                "fact": c.fact,
                "sources": f"{c.source_a} vs {c.source_b}",
                "value_a": c.value_a,
                "value_b": c.value_b,
            }
            for c in unresolved
        ],
        "sources": sorted(cand.source_summary.get("sources") or []) if cand else [],
        "dedup_match": cand.dedup_match if cand else None,
        "ingredient_matches": list(cand.ingredient_matches) if cand else [],
        "unmatched_ingredients": list(cand.unmatched_ingredients) if cand else [],
        "derived_allergens": list(cand.derived_allergens) if cand else [],
        "derived_health_flags": list(cand.derived_health_flags) if cand else [],
    }


def render_summary(summary: BatchSummary) -> str:
    lines = [
        f"Processed:       {summary.total}",
        f"Verified:        {summary.verified}",
        f"Needs Review:    {summary.needs_review}",
        f"Conflicts:       {summary.conflict}",
        f"Unresolved:      {summary.unresolved}",
        f"Failed:          {summary.failed}",
    ]
    return "\n".join(lines)


def render_detail_table(outcomes: list[ProductOutcome]) -> None:
    console = Console()
    table = Table(title="Batch outcomes")
    for col in ("product_key", "status", "confidence", "reason"):
        table.add_column(col)
    for o in outcomes:
        detail = _outcome_detail(o)
        reason = detail["reason"] or ""
        if detail["missing_data"]:
            reason += f" | missing: {', '.join(detail['missing_data'])}"
        if detail["conflicts"]:
            reason += " | conflicts: " + "; ".join(c["sources"] for c in detail["conflicts"])
        table.add_row(
            o.product_key,
            o.status,
            f"{o.confidence:.2f}",
            reason[:120],
        )
    console.print(table)
