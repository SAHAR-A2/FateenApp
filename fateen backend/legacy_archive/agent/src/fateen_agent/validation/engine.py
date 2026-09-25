"""Verification engine: the gate that decides what can enter the knowledge base.

Rules are explicit and deterministic (see docs/verification_rules.md). The
engine NEVER invents data: if evidence is missing, the outcome is
NEEDS_REVIEW/UNRESOLVED, never a guessed value.

Outcome ladder (first match wins):
  FAILED        -> a technical error occurred during processing
  CONFLICT      -> two+ sources disagree on a fact and it cannot be resolved
  UNRESOLVED    -> no source returned usable evidence at all
  VERIFIED      -> all required facts evidenced, no conflicts, confidence high
  NEEDS_REVIEW  -> everything else (data present but insufficient proof)
"""

from __future__ import annotations

from dataclasses import dataclass, field

from ..constants import (
    NEEDS_REVIEW_MIN_CONFIDENCE,
    VERIFIED_MIN_CONFIDENCE,
)
from ..models import CandidateProduct


@dataclass
class VerificationResult:
    status: str
    confidence: float = 0.0
    missing_data: list[str] = field(default_factory=list)
    reason: str = ""


class VerificationPolicy:
    """Configurable verification policy for the agent."""

    def __init__(
        self,
        verified_min_confidence: float = VERIFIED_MIN_CONFIDENCE,
        needs_review_min_confidence: float = NEEDS_REVIEW_MIN_CONFIDENCE,
        required_facts: tuple[str, ...] = ("name", "barcode", "ingredients", "brand_or_company"),
    ):
        self.verified_min = verified_min_confidence
        self.needs_review_min = needs_review_min_confidence
        self.required_facts = required_facts

    def verify(self, candidate: CandidateProduct) -> VerificationResult:
        missing = self._missing_facts(candidate)
        unresolved_conflicts = [c for c in candidate.conflicts if not c.resolved]
        confidence = candidate.confidence

        # CONFLICT: unresolved disagreement between sources.
        if unresolved_conflicts:
            facts = ", ".join(c.fact for c in unresolved_conflicts)
            return VerificationResult(
                status="CONFLICT",
                confidence=confidence,
                missing_data=missing,
                reason=f"Unresolved source conflict on: {facts}.",
            )

        # NEEDS_REVIEW: data exists but core proof is missing.
        if missing:
            return VerificationResult(
                status="NEEDS_REVIEW",
                confidence=confidence,
                missing_data=missing,
                reason=f"Missing required evidence: {', '.join(missing)}.",
            )

        # VERIFIED: full evidence + high confidence.
        if confidence >= self.verified_min:
            return VerificationResult(
                status="VERIFIED",
                confidence=confidence,
                reason=f"All required facts evidenced; confidence {confidence:.2f} >= {self.verified_min}.",
            )

        # NEEDS_REVIEW: present but below the verified threshold.
        return VerificationResult(
            status="NEEDS_REVIEW",
            confidence=confidence,
            missing_data=missing,
            reason=f"Confidence {confidence:.2f} below verified threshold {self.verified_min}.",
        )

    @staticmethod
    def _missing_facts(candidate: CandidateProduct) -> list[str]:
        missing: list[str] = []
        has_any_identity = bool(candidate.brand or candidate.company)
        required_identity = bool(candidate.name and (candidate.brand or candidate.company))
        if not candidate.name:
            missing.append("name")
        if not candidate.barcode:
            missing.append("barcode")
        if not candidate.ingredients:
            missing.append("ingredients")
        if not required_identity:
            if has_any_identity:
                missing.append("brand_or_company_confirmation")
            else:
                missing.append("brand_or_company")
        return missing
