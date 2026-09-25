"""Candidate processing pipeline (STEP B core).

One candidate flows through:

    normalize (from the fetched SfdaProductRecord) ->
    resolve (ingredientsAr tokens against the deterministic grammar) ->
    validate (barcode, record completeness, resolution completeness) ->
    insert (IngestionInput -> ingest on the trusted path)
    or quarantine (with verbatim unresolved terms + reasons)

Rules honored here (mission-critical):
  - No fabricated products: a candidate is only inserted when the SFDA record
    fully resolves against the FATEEN grammar (strict mode, default).
  - No unknown->known: unresolved ingredient tokens are surfaced verbatim in
    the quarantine record; they are never auto-mapped to a canonical term.
  - Unresolved ingredients are a rejection reason (STEP C); with any
    unresolved token the product is quarantined, never partially inserted with
    fabricated completions.
  - The raw SFDA payload travels untouched (evidence) on the candidate and in
    the quarantine record.
"""
import logging
from typing import Callable, Optional

from app.agent.models import IngestionInput, IngestionIngredient
from app.agent.normalizers import normalize_barcode
from app.batch.models import (
    Candidate,
    CandidateStatus,
    QuarantineRecord,
    QuarantineStatus,
    RejectionReason,
    utcnow,
)
from app.batch.quarantine import SfdaQuarantine
from app.core.config import resolve_effective_dry_run
from app.integrations.sfda_ingredients import split_ingredient_text

logger = logging.getLogger("fateen.batch.pipeline")

# Resolver signature: (conn, token) -> Optional[dict with 'name' + 'internal_code'].
Resolver = Callable

# Inserter signature: (candidate, resolved_names, dry_run) -> IngestionResult.
Inserter = Callable


def normalizer(record) -> dict:
    """Deterministic normalization of one SfdaProductRecord for the pipeline."""
    return {
        "barcode": normalize_barcode(record.barcode) if record.barcode else None,
        "reference_number": record.registration_number or record.source_record_id,
        "trade_name": record.trade_name,
        "brand": record.brand,
        "company": record.company,
        "item_description": record.item_description,
        "ingredients_ar": record.ingredients_ar,
        "ingredients_en": record.ingredients_en,
        "warnings_ar": record.warnings_ar,
    }


def _apply_normalized(candidate: Candidate, normalized: dict) -> Candidate:
    for key, value in normalized.items():
        setattr(candidate, key, value)
    return candidate


def resolve_candidate(candidate: Candidate, resolver: Resolver, conn=None) -> Candidate:
    """Split ingredientsAr deterministically and resolve each token.

    Stores `resolved_names` (canonical names of resolved tokens) and
    `unresolved_ingredients` (verbatim unsolved terms + annotations).
    """
    candidate.resolved_names = []
    candidate.unresolved_ingredients = []
    if not candidate.ingredients_ar:
        candidate.status = CandidateStatus.RESOLVED
        return candidate

    for token in split_ingredient_text(candidate.ingredients_ar).tokens:
        matched = resolver(conn, token)
        if matched is None:
            candidate.unresolved_ingredients.append(
                {
                    "term": token.source_term,
                    "normalized": token.normalized,
                    "annotation": token.annotation,
                }
            )
        else:
            candidate.resolved_names.append(matched.get("name"))
    candidate.status = CandidateStatus.RESOLVED
    return candidate


def validate_candidate(candidate: Candidate) -> Candidate:
    reasons: list[str] = []
    errors: list[str] = []

    if candidate.raw_payload is None:
        reasons.append(RejectionReason.NO_RECORD.value)
        errors.append("no record returned")

    if not candidate.barcode:
        reasons.append(RejectionReason.INVALID_BARCODE.value)
        errors.append("record has no barcode")
    else:
        from app.integrations.sfda_food_adapter import validate_barcode

        try:
            candidate.barcode = validate_barcode(candidate.barcode)
        except Exception as exc:
            reasons.append(RejectionReason.INVALID_BARCODE.value)
            errors.append(f"invalid barcode: {exc}")

    if not candidate.ingredients_ar and not candidate.ingredients_en:
        errors.append("record has no ingredientsAr/ingredientsEn")

    if candidate.unresolved_ingredients:
        reasons.append(RejectionReason.UNRESOLVED_INGREDIENTS.value)
        errors.append(
            "unresolved ingredients: "
            + ", ".join(u["term"] for u in candidate.unresolved_ingredients)
        )

    candidate.validation_errors = list(dict.fromkeys(errors))
    candidate.rejection_reasons = list(dict.fromkeys(reasons))
    candidate.status = (
        CandidateStatus.VALIDATED if not reasons else CandidateStatus.QUARANTINED
    )
    return candidate


def build_ingestion_input(candidate: Candidate) -> Optional[IngestionInput]:
    """IngestionInput carrying ONLY the resolved canonical ingredient names."""
    return IngestionInput(
        barcode=candidate.barcode,
        product_name=candidate.trade_name,
        product_description=candidate.item_description,
        ingredients=[
            IngestionIngredient(name=name, confidence_level=0.5)
            for name in candidate.resolved_names
        ],
        allergens=[],
        source="SFDA",
        confidence_level=0.5,
    )


def process_candidate(
    candidate: Candidate,
    record,
    resolver: Resolver,
    quarantine: SfdaQuarantine,
    inserter: Optional[Inserter] = None,
    conn=None,
    dry_run: bool = True,
) -> Candidate:
    """normalize -> resolve -> validate -> insert/quarantine for one candidate.

    `dry_run` flows through `resolve_effective_dry_run` (the single safety
    contract that the AGENT_DRY_RUN env switch can never be bypassed).
    """
    candidate.attempts += 1
    try:
        if record is None:
            candidate.rejection_reasons.append(RejectionReason.NO_RECORD.value)
            candidate.validation_errors.append("no record to process")
            candidate.status = CandidateStatus.QUARANTINED
            return _finalize(candidate, quarantine)

        candidate.raw_payload = record.raw_payload if record.raw_payload else None
        _apply_normalized(candidate, normalizer(record))
        candidate = resolve_candidate(candidate, resolver, conn=conn)
        candidate = validate_candidate(candidate)

        if candidate.status == CandidateStatus.QUARANTINED:
            return _finalize(candidate, quarantine)

        effective_dry_run = resolve_effective_dry_run(dry_run)
        if inserter is not None:
            result = inserter(candidate, effective_dry_run)
            if result and result.errors:
                candidate.validation_errors = candidate.validation_errors + result.errors
                candidate.rejection_reasons.append(RejectionReason.VALIDATION_FAILED.value)
                candidate.status = CandidateStatus.QUARANTINED
                return _finalize(candidate, quarantine)

        candidate.status = CandidateStatus.INSERTED
        return _finalize(candidate, quarantine)
    except Exception:
        logger.exception("pipeline error for candidate %s", candidate.candidate_id)
        candidate.status = CandidateStatus.FAILED
        return _finalize(candidate, quarantine)


def _finalize(candidate: Candidate, quarantine: SfdaQuarantine) -> Candidate:
    candidate.processed_at = utcnow()
    if candidate.status == CandidateStatus.QUARANTINED:
        quarantine.record(
            QuarantineRecord(
                candidate_id=candidate.candidate_id,
                identifier=candidate.identifier,
                reasons=candidate.rejection_reasons,
                unresolved_ingredients=candidate.unresolved_ingredients,
                source=candidate.source,
                processing_status=QuarantineStatus.QUARANTINED.value,
                payload=candidate.raw_payload,
            )
        )
    return candidate