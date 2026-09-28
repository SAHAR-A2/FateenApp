"""The single authoritative product-compatibility decision point for FATEEN.

Combines:
  - product data, reused from product_details_service (not re-queried)
  - allergen matching, via app.services.allergen_mapping
  - health-condition / nutrition evaluation, via the existing
    app.collector.health_conditions engine (reused as-is; this file does
    not duplicate or reimplement that logic)

Nothing here invents or reinterprets a medical threshold. Where the
required data, mapping, or backend rule does not exist, the result is
UNKNOWN or INSUFFICIENT_DATA -- never a silent SAFE. See:
  - app.services.allergen_mapping (mapping verification status)
  - app.collector.health_conditions (currently unpopulated
    health_conditions / condition_nutrition_rules tables -- disease
    evaluation will legitimately be UNKNOWN until FATEEN's team reviews
    and populates those tables; this file does not port the Flutter
    disease_rules.dart thresholds in, by design).
"""
import logging
from typing import Optional

from app.services.product_details_service import get_product_details_by_barcode
from app.services.allergen_mapping import resolve_allergen_codes
from app.catalog.allergen_detection import detect_in_name
from app.collector import health_conditions as health_conditions_engine
from app.schemas.compatibility import (
    CompatibilityRequest,
    CompatibilityResponse,
    ProductSummary,
    MatchedAllergen,
    HealthConditionResult,
    RelevantNutrition,
    STATUS_SAFE,
    STATUS_WARNING,
    STATUS_DANGER,
    STATUS_UNKNOWN,
    STATUS_INSUFFICIENT_DATA,
)

logger = logging.getLogger("fateen.services.compatibility")

_SEVERITY_RANK = {
    STATUS_SAFE: 0,
    STATUS_UNKNOWN: 1,
    STATUS_INSUFFICIENT_DATA: 1,
    STATUS_WARNING: 2,
    STATUS_DANGER: 3,
}

# Mirrors, unchanged, the mild-vs-severe distinction already applied to a
# confirmed allergen match in lib/logic/health_checker.dart
# (`allergy.severity == 'خفيف'` -> orange/WARNING, otherwise -> red/DANGER).
# Relocated here, not reinterpreted.
_MILD_SEVERITY_LABELS = {"خفيف", "mild", "light"}

# Maps the health_conditions engine's own 6-state HealthEvaluation enum
# (app.collector.models.HealthEvaluation) onto this service's 5-state
# top-level status. CAUTION and WARNING both fold into WARNING at the
# top level; the original, more granular value is preserved unchanged in
# HealthConditionResult.evaluation_result for anyone who needs the detail.
_CONDITION_STATUS_MAP = {
    "SAFE": STATUS_SAFE,
    "CAUTION": STATUS_WARNING,
    "WARNING": STATUS_WARNING,
    "UNSAFE": STATUS_DANGER,
    "UNKNOWN": STATUS_UNKNOWN,
    "INSUFFICIENT_DATA": STATUS_INSUFFICIENT_DATA,
}


class _Verdict:
    """Accumulates the worst-status-wins outcome, tracking the reason and
    confidence that go with whichever fact currently drives the status --
    the same 'worst result wins' philosophy as the existing Flutter
    HealthChecker._pickWorseResult, extended to five states instead of
    four.
    """

    def __init__(self, default_confidence: float):
        self.status = STATUS_SAFE
        self.reason = "هذا المنتج آمن وفق البيانات والقواعد المتوفرة حاليًا"
        self.confidence = default_confidence

    def consider(self, status: str, reason: str, confidence: Optional[float] = None):
        if _SEVERITY_RANK[status] > _SEVERITY_RANK[self.status]:
            self.status = status
            self.reason = reason
            if confidence is not None:
                self.confidence = confidence


# The Flutter app stores and sends the Arabic labels of
# lib/data/disease_options.dart. Each maps to a health_conditions.code. A
# label with no condition row (low blood pressure has no nutrition rule)
# stays UNKNOWN rather than being guessed.
_DISEASE_NAME_TO_CODE = {
    "سكري": "DIABETES",
    "السكري": "DIABETES",
    "ارتفاع الضغط": "HYPERTENSION",
    "ارتفاع ضغط الدم": "HYPERTENSION",
    "انخفاض الضغط": "LOW_BLOOD_PRESSURE",
    "كوليسترول": "HIGH_CHOLESTEROL",
    "الكوليسترول": "HIGH_CHOLESTEROL",
    "ارتفاع الكوليسترول": "HIGH_CHOLESTEROL",
    "high cholesterol": "HIGH_CHOLESTEROL",
    "cholesterol": "HIGH_CHOLESTEROL",
}


def _matches_condition_name(condition: dict, disease_name: str) -> bool:
    target = (disease_name or "").strip().lower()
    code = (condition.get("code") or "").strip().lower()
    if not code:
        return False
    return (
        (condition.get("name") or "").strip().lower() == target
        or code == target
        or _DISEASE_NAME_TO_CODE.get(target, "").lower() == code
    )


_ALLERGEN_NAMES = {
    "CELERY": "Celery", "EGG": "Egg", "FISH": "Fish", "GLUTEN": "Gluten", "LUPIN": "Lupin",
    "MILK": "Milk", "MOLLUSCS": "Molluscs", "MUSTARD": "Mustard", "PEANUT": "Peanut",
    "SESAME": "Sesame", "SHELLFISH": "Shellfish", "SOY": "Soy", "SULPHITES": "Sulphites",
    "TREE_NUTS": "Tree Nuts", "WHEAT": "Wheat",
}


def evaluate_compatibility(
    barcode: str, request: CompatibilityRequest
) -> Optional[CompatibilityResponse]:
    """Evaluate a product's compatibility for the given user context.

    Returns None if the barcode is not found, so the API layer can map
    that to 404 -- consistent with the existing barcode/details endpoints.
    """
    details = get_product_details_by_barcode(barcode)
    if details is None:
        return None

    product = ProductSummary(
        internal_code=details["internal_code"],
        name=details["name"],
        barcode=barcode,
        lifecycle_status=details["lifecycle_status"],
        confidence_level=details["confidence_level"],
    )

    verdict = _Verdict(default_confidence=details["confidence_level"])
    matched_allergens: list[MatchedAllergen] = []
    health_condition_results: list[HealthConditionResult] = []

    # An ingredient statement counts as evidence: the catalog loader derives
    # the product's allergen rows from it (app.catalog.allergen_detection),
    # so a statement with no allergen rows means none of the 14 was found.
    has_allergen_basis = bool(
        details["ingredients"] or details["allergens"] or details.get("ingredient_statements")
    )
    has_any_enrichment = has_allergen_basis or bool(details["nutrition"])

    if not has_any_enrichment:
        verdict.consider(
            STATUS_INSUFFICIENT_DATA,
            "لا تتوفر بيانات كافية عن مكونات هذا المنتج بعد",
        )
    elif request.allergies and not has_allergen_basis:
        # Nutrition alone says nothing about allergens: without an
        # ingredient list or allergen evidence, "no match" is not "safe".
        verdict.consider(
            STATUS_INSUFFICIENT_DATA,
            "لا تتوفر قائمة مكونات أو بيانات مسببات حساسية لهذا المنتج للتحقق من حساسيتك",
        )
    product_allergens_by_code = {}
    for a in details["allergens"]:
        # A CONTAINS row outranks a MAY_CONTAIN row for the same allergen.
        current = product_allergens_by_code.get(a["internal_code"])
        if current is None or current.get("relationship_type") == "MAY_CONTAIN_ALLERGEN":
            product_allergens_by_code[a["internal_code"]] = a
    # What the product is called is evidence of what it is made of: "Fresh
    # Milk" contains milk even when the source's ingredient list is missing
    # or incomplete. Positive evidence only -- a name never proves absence,
    # so it does not count as an allergen basis above.
    for code in detect_in_name(details.get("name"), details.get("name_ar"), details.get("name_en")):
        current = product_allergens_by_code.get(code)
        if current is None or current.get("relationship_type") == "MAY_CONTAIN_ALLERGEN":
            product_allergens_by_code[code] = {
                "internal_code": code,
                "name": _ALLERGEN_NAMES.get(code, code),
                "relationship_type": "CONTAINS_ALLERGEN",
                "confidence_level": details["confidence_level"],
                "evidence_type": "PRODUCT_NAME",
            }

    if product_allergens_by_code or has_allergen_basis:

        for allergy in request.allergies:
            resolution = resolve_allergen_codes(allergy.tag)

            if resolution is None:
                verdict.consider(
                    STATUS_UNKNOWN,
                    f"لا يوجد ربط معروف للحساسية ({allergy.tag}) في قاعدة بيانات فطين بعد",
                )
                continue

            codes, verified = resolution
            if not verified:
                verdict.consider(
                    STATUS_UNKNOWN,
                    f"ربط الحساسية ({allergy.tag}) لم يُتحقق بعد من قاعدة البيانات",
                )
                continue

            # A CONTAINS row for any of the codes outranks a MAY_CONTAIN row.
            hits = [product_allergens_by_code[c] for c in codes if c in product_allergens_by_code]
            hit = next(
                (h for h in hits if h.get("relationship_type") != "MAY_CONTAIN_ALLERGEN"),
                hits[0] if hits else None,
            )
            if hit is None:
                # No evidence linking this specific allergen to this
                # product. Not treated as proof of absence, but does not
                # by itself downgrade the result either -- see the audit
                # report's discussion of "no evidence" vs "evidence of
                # absence" vs "insufficient evidence".
                continue
            code = hit["internal_code"]

            severity_label = (allergy.severity or "").strip()
            allergen_status = (
                STATUS_WARNING if severity_label in _MILD_SEVERITY_LABELS else STATUS_DANGER
            )
            matched_allergens.append(
                MatchedAllergen(
                    internal_code=code,
                    name=hit["name"],
                    source_tag=allergy.tag,
                    confidence_level=hit["confidence_level"],
                    evidence_type=hit.get("evidence_type"),
                )
            )
            if hit.get("relationship_type") == "MAY_CONTAIN_ALLERGEN":
                allergen_reason = f"قد يحتوي هذا المنتج على آثار من مسبب حساسية ({hit['name']})"
            else:
                allergen_reason = f"يحتوي هذا المنتج على مسبب حساسية ({hit['name']})"
            verdict.consider(
                allergen_status,
                allergen_reason,
                confidence=hit["confidence_level"],
            )

    if request.diseases:
        try:
            known_conditions = health_conditions_engine.get_health_conditions()
        except Exception:
            logger.exception(
                "health_conditions_engine.get_health_conditions failed -- "
                "degrading every requested disease to UNKNOWN"
            )
            known_conditions = []
            for disease in request.diseases:
                health_condition_results.append(
                    HealthConditionResult(
                        condition_code=disease.name,
                        condition_name=disease.name,
                        evaluation_result=STATUS_UNKNOWN,
                        evidence=[],
                    )
                )
                verdict.consider(
                    STATUS_UNKNOWN,
                    f"تعذّر تقييم حالة ({disease.name}) حاليًا",
                )
            request_diseases = []  # already handled above, skip the loop below
        else:
            request_diseases = request.diseases

        for disease in request_diseases:
            matching = next(
                (c for c in known_conditions if _matches_condition_name(c, disease.name)),
                None,
            )

            if matching is None:
                health_condition_results.append(
                    HealthConditionResult(
                        condition_code=disease.name,
                        condition_name=disease.name,
                        evaluation_result=STATUS_UNKNOWN,
                        evidence=[],
                    )
                )
                verdict.consider(
                    STATUS_UNKNOWN,
                    f"لا توجد قاعدة معتمدة في فطين لتقييم حالة ({disease.name}) بعد",
                )
                continue

            try:
                evaluation = health_conditions_engine.evaluate_single_condition(
                    str(details["id"]), matching["code"]
                )
            except Exception:
                logger.exception(
                    "health_conditions_engine.evaluate_single_condition failed "
                    "for condition_code=%s -- degrading to UNKNOWN rather than "
                    "failing the whole compatibility request",
                    matching.get("code"),
                )
                health_condition_results.append(
                    HealthConditionResult(
                        condition_code=matching.get("code", disease.name),
                        condition_name=disease.name,
                        evaluation_result=STATUS_UNKNOWN,
                        evidence=[],
                    )
                )
                verdict.consider(
                    STATUS_UNKNOWN,
                    f"تعذّر تقييم حالة ({disease.name}) حاليًا",
                )
                continue

            if evaluation is None:
                health_condition_results.append(
                    HealthConditionResult(
                        condition_code=matching.get("code", disease.name),
                        condition_name=disease.name,
                        evaluation_result=STATUS_UNKNOWN,
                        evidence=[],
                    )
                )
                verdict.consider(
                    STATUS_UNKNOWN,
                    f"تعذّر تقييم حالة ({disease.name}) بالقواعد المتوفرة حاليًا",
                )
                continue

            raw_result = evaluation["evaluation_result"]
            mapped_status = _CONDITION_STATUS_MAP.get(raw_result, STATUS_UNKNOWN)
            health_condition_results.append(
                HealthConditionResult(
                    condition_code=evaluation["condition_code"],
                    condition_name=evaluation["condition_name"],
                    evaluation_result=raw_result,
                    evidence=evaluation["evidence"],
                )
            )
            if mapped_status != STATUS_SAFE:
                verdict.consider(
                    mapped_status,
                    f"هذا المنتج قد لا يتناسب مع حالة ({evaluation['condition_name']}) وفق القواعد المسجلة",
                )

    relevant_nutrition = [
        RelevantNutrition(
            nutrition_type=n["nutrition_type"],
            amount_value=n["amount_value"],
            unit=n["unit"],
            confidence_level=n["confidence_level"],
        )
        for n in details["nutrition"]
    ]

    return CompatibilityResponse(
        status=verdict.status,
        reason=verdict.reason,
        confidence=verdict.confidence,
        product=product,
        matched_allergens=matched_allergens,
        health_conditions=health_condition_results,
        relevant_nutrition=relevant_nutrition,
    )
