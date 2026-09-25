"""Review queue construction: turn unproven outcomes into actionable tasks."""

from __future__ import annotations

from ..constants import PROBLEM_SOURCE_CONFLICT, PROBLEM_TECHNICAL, PROBLEM_UNRESOLVED
from ..models import CandidateProduct, ReviewTask


def build_review_task(candidate: CandidateProduct | None, error: str | None = None) -> ReviewTask:
    """Build a review task for a candidate that could not be verified."""
    if error:
        return ReviewTask(
            product_key=candidate.product_key if candidate else "",
            key_type=candidate.key_type if candidate else "barcode",
            problem="FAILED",
            reason=f"Technical failure: {error}",
            sources_checked=_sources_checked(candidate),
            suggested_action="Retry after addressing the technical failure; check logs.",
        )

    if not candidate:
        return ReviewTask(
            product_key="",
            key_type="barcode",
            problem=PROBLEM_UNRESOLVED,
            reason="No source returned usable data for this product.",
            suggested_action="Verify the barcode/name; try an alternative barcode or the official manufacturer page.",
        )

    unresolved_conflicts = [c for c in candidate.conflicts if not c.resolved]
    problem = candidate.status
    if unresolved_conflicts:
        problem = PROBLEM_SOURCE_CONFLICT
    elif candidate.status in ("NEEDS_REVIEW",):
        problem = "NEEDS_REVIEW"

    conflict_sources = [
        f"{c.source_a} vs {c.source_b} on '{c.fact}'" for c in unresolved_conflicts
    ]
    reason = _reason_text(candidate, unresolved_conflicts)

    action = "Review the conflicting sources and pick the correct value, or find a third source."
    if candidate.status == "NEEDS_REVIEW" and candidate.missing_data:
        action = f"Supply the missing data: {', '.join(candidate.missing_data)}."
    if problem == PROBLEM_UNRESOLVED:
        action = "Manually verify product identity (barcode/name) against official sources."

    return ReviewTask(
        product_key=candidate.product_key,
        key_type=candidate.key_type,
        problem=problem,
        reason=reason,
        sources_checked=_sources_checked(candidate),
        conflicting_sources=conflict_sources,
        missing_data=candidate.missing_data,
        suggested_action=action,
    )


def _sources_checked(candidate: CandidateProduct | None) -> list[str]:
    if not candidate:
        return []
    return sorted({e.source.name for e in candidate.evidence})


def _reason_text(candidate: CandidateProduct, conflicts: list) -> str:
    if conflicts:
        return f"{len(conflicts)} unresolved source conflict(s)."
    if candidate.status == "UNRESOLVED":
        return "No source returned usable data."
    if candidate.missing_data:
        return f"Missing required evidence: {', '.join(candidate.missing_data)}."
    if candidate.notes:
        return "; ".join(candidate.notes)
    return f"Confidence {candidate.confidence:.2f} below verified threshold."
