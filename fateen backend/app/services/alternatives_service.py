"""Backend-owned safe-alternative retrieval.

Replaces the old Flutter result_screen flow (product name -> first three
words -> Open Food Facts search -> local HealthChecker filtering).

Candidate retrieval is deterministic: same product_category_id where the
original product has one recorded, otherwise a name-token fallback used
ONLY to decide which products are worth evaluating. Retrieval never decides
safety.

Every candidate is evaluated through the exact same compatibility_service
used by the barcode/search flow -- there is no second, alternatives-
specific safety engine. Only candidates whose compatibility result is
SAFE are returned. WARNING/DANGER/UNKNOWN/INSUFFICIENT_DATA candidates are
excluded outright, not shown as a lower-confidence "maybe" option -- an
uncertain candidate is not presented as a safe alternative.
"""
import logging
from typing import Optional

from app.services.product_details_service import get_product_details_by_barcode
from app.services.compatibility_service import evaluate_compatibility
from app.repositories.product_repository import (
    get_alternative_candidates_by_category,
    get_alternative_candidates_by_name_token,
)
from app.schemas.compatibility import CompatibilityRequest, ProductSummary, STATUS_SAFE
from app.schemas.alternatives import AlternativeCandidate, AlternativesResponse

logger = logging.getLogger("fateen.services.alternatives")

MAX_CANDIDATES = 15
MAX_RESULTS = 5


def get_safe_alternatives(
    barcode: str, request: CompatibilityRequest
) -> Optional[AlternativesResponse]:
    """Returns None if the original barcode is not found (mapped to 404 by
    the API layer), otherwise a list of at most MAX_RESULTS candidates
    that were positively confirmed SAFE for this specific user context.
    """
    details = get_product_details_by_barcode(barcode)
    if details is None:
        return None

    original = ProductSummary(
        internal_code=details["internal_code"],
        name=details["name"],
        barcode=barcode,
        lifecycle_status=details["lifecycle_status"],
        confidence_level=details["confidence_level"],
    )

    category_id = details.get("product_category_id")
    if category_id:
        candidates = get_alternative_candidates_by_category(
            category_id, details["internal_code"], limit=MAX_CANDIDATES
        )
    else:
        first_token = (details["name"].split() or [""])[0]
        candidates = (
            get_alternative_candidates_by_name_token(
                first_token, details["internal_code"], limit=MAX_CANDIDATES
            )
            if first_token
            else []
        )

    confirmed_safe: list[AlternativeCandidate] = []
    for candidate in candidates:
        candidate_barcode = candidate.get("barcode")
        if not candidate_barcode:
            # No active/purchasable barcode -- skip rather than recommend
            # something the user can't scan/verify themselves.
            continue

        result = evaluate_compatibility(candidate_barcode, request)
        if result is None or result.status != STATUS_SAFE:
            continue

        confirmed_safe.append(
            AlternativeCandidate(
                product=result.product,
                reason="متوافق وفق البيانات والقواعد المتوفرة حاليًا لدى فطين",
            )
        )
        if len(confirmed_safe) >= MAX_RESULTS:
            break

    return AlternativesResponse(
        original_product=original,
        alternatives=confirmed_safe,
        candidates_considered=len(candidates),
        candidates_confirmed_safe=len(confirmed_safe),
    )
