"""P07: Data extraction pipeline - extracts structured product information.

Wraps LLM extraction with validation, normalization, and evidence attachment.
LLM output is treated as UNTRUSTED INPUT.
"""
import json
import logging
from typing import Optional

from app.core.config import settings
from app.llm.client import LLMClient, LLMProviderError
from app.llm.prompts import (
    PRODUCT_EXTRACTION_SYSTEM,
    PRODUCT_EXTRACTION_USER,
)
from app.collector.models import (
    CollectedProductData,
    ExtractedIngredients,
    ExtractedAllergen,
    ExtractedNutrition,
    ExtractionResult,
    ExtractionStatus,
    PROVIDER_FAILURE_STATUSES,
)
from app.agent.normalizers import normalize_barcode, normalize_name, normalize_code
from app.agent.validators import validate_barcode, validate_confidence

logger = logging.getLogger("fateen.collector.extraction")

# Upper bound on the source-page text handed to the LLM, to keep prompt
# sizes bounded. The page is truncated, never summarized or extrapolated.
MAX_EXTRACTION_CONTEXT_CHARS = 40_000

VALID_NUTRITION_TYPES = {
    "CARBOHYDRATE", "ENERGY", "FIBER", "PROTEIN",
    "SATURATED_FAT", "SODIUM", "SUGAR", "TOTAL_FAT", "TRANS_FAT",
}
VALID_UNITS = {"MG", "G", "KG", "ML", "L", "KCAL", "KJ", "PCS"}
VALID_ALLERGEN_NAMES = {
    "MILK", "EGGS", "FISH", "SHELLFISH", "TREE_NUTS", "PEANUTS",
    "WHEAT", "SOY", "SESAME", "CELERY", "MUSTARD", "LUPIN",
    "MOLLUSKS", "SULFUR_DIOXIDE", "GLUTEN",
}


def extract_from_llm_response(
    llm_data: dict,
    source_url: Optional[str] = None,
    company_id: Optional[str] = None,
    brand_id: Optional[str] = None,
) -> CollectedProductData:
    """Extract and normalize structured product data from LLM output.

    LLM output is treated as UNTRUSTED INPUT.
    Every field passes validation.
    Missing fields remain None/empty. Never invent facts.
    """
    barcode_raw = llm_data.get("barcode")
    barcode = None
    if barcode_raw:
        normalized = normalize_barcode(str(barcode_raw))
        errors = validate_barcode(normalized)
        if not errors:
            barcode = normalized

    product_name = str(llm_data.get("product_name", "") or llm_data.get("name", "")).strip()
    if not product_name:
        logger.warning("Extraction: no product name in LLM output")

    brand = str(llm_data.get("brand", "")).strip() or None
    category = str(llm_data.get("category", "")).strip() or None
    manufacturer = str(llm_data.get("manufacturer", "")).strip() or None
    country_raw = llm_data.get("country")

    if country_raw is None:
        country = None
    else:
        country = str(country_raw).strip() or None

    ingredients = _extract_ingredients(llm_data.get("ingredients", []))
    allergens = _extract_allergens(llm_data.get("allergens", []))
    nutrition = _extract_nutrition(llm_data.get("nutrition", []))

    # Confidence reflects the LLM's stated certainty; it is NOT truth and
    # never substitutes for evidence. Missing/invalid confidence stays None.
    confidence_level = _validate_confidence_value(llm_data.get("confidence_level"))

    return CollectedProductData(
        barcode=barcode,
        product_name=product_name,
        brand=brand,
        category=category,
        manufacturer=manufacturer,
        country=country,
        ingredients=ingredients,
        allergens=allergens,
        nutrition=nutrition,
        source_url=source_url,
        confidence_level=confidence_level,
        company_id=company_id,
        brand_id=brand_id,
        raw_data=llm_data,
    )


def extract_from_source_page(
    source_text: str,
    source_url: Optional[str] = None,
    company_id: Optional[str] = None,
    barcode: Optional[str] = None,
    product_name: Optional[str] = None,
    provider: Optional[str] = None,
    max_context_chars: int = MAX_EXTRACTION_CONTEXT_CHARS,
) -> ExtractionResult:
    """Run retrieval output -> LLM -> extract_from_llm_response.

    Returns a typed ExtractionResult (a CollectedProductData subclass) so
    every existing consumer keeps working unchanged. The typed status
    distinguishes the possible outcomes:

      * EMPTY_EXTRACTION        - no source text to extract from
      * MALFORMED_LLM_RESPONSE  - LLM returned unparsable output
      * PROVIDER_*              - the LLM provider failed (retryable);
                                  never confused with bad product data
      * SUCCESS                 - extraction completed (missing fields may
                                  still stay missing: no fabrication)

    LLM output is UNTRUSTED INPUT passed through the same validation as any
    other extraction. No LLM call is made when there is nothing to extract.
    """
    if not source_text or not source_text.strip():
        logger.warning("No source text to extract from for %s", source_url)
        return _empty_result(ExtractionStatus.EMPTY_EXTRACTION, source_url, company_id)

    client = LLMClient(provider=provider or settings.llm_provider)

    user_prompt = PRODUCT_EXTRACTION_USER.format(
        barcode=barcode or "not provided",
        name=product_name or "not provided",
        description="",
        context=source_text[:max_context_chars],
    )

    try:
        raw_response = client.chat(PRODUCT_EXTRACTION_SYSTEM, user_prompt)
    except LLMProviderError as exc:
        return _provider_failure_result(exc, source_url, company_id)
    except Exception:
        logger.exception("LLM extraction failed for source %s", source_url)
        return _empty_result(
            ExtractionStatus.MALFORMED_LLM_RESPONSE, source_url, company_id
        )

    try:
        llm_data = raw_response.parsed_json()
    except (json.JSONDecodeError, ValueError, TypeError):
        logger.warning("Malformed LLM response for source %s", source_url)
        return _empty_result(
            ExtractionStatus.MALFORMED_LLM_RESPONSE, source_url, company_id
        )

    base = extract_from_llm_response(
        llm_data, source_url=source_url, company_id=company_id
    )
    return _to_extraction_result(base, ExtractionStatus.SUCCESS)


def is_provider_failure(result: CollectedProductData) -> bool:
    """True when an extraction outcome is a provider-side failure.

    Provider failure means the LLM provider could not service the request
    (quota / rate limit / timeout / 5xx / transport error) -- it says
    NOTHING about the product data and must never be reported as a data
    validation failure.
    """
    return bool(
        isinstance(result, ExtractionResult)
        and result.status in PROVIDER_FAILURE_STATUSES
    )


def _empty_result(status: ExtractionStatus, source_url, company_id) -> ExtractionResult:
    """Typed result for an extraction that produced no LLM data.

    Fields stay missing (product_name stays "", confidence stays None) --
    never a fabricated value.
    """
    base = extract_from_llm_response({}, source_url=source_url, company_id=company_id)
    return _to_extraction_result(base, status)


def _provider_failure_result(
    exc: LLMProviderError, source_url, company_id
) -> ExtractionResult:
    """Typed result carrying the provider failure (never an empty dict)."""
    base = extract_from_llm_response({}, source_url=source_url, company_id=company_id)
    return _to_extraction_result(
        base,
        status=exc.code,
        error_code=exc.code,
        error_detail=str(exc) or exc.code,
        retryable=bool(exc.retryable),
    )


def _status_value(status: ExtractionStatus) -> str:
    return status.value if isinstance(status, ExtractionStatus) else str(status)


def _to_extraction_result(
    base: CollectedProductData,
    status,
    error_code: Optional[str] = None,
    error_detail: Optional[str] = None,
    retryable: bool = False,
) -> ExtractionResult:
    return ExtractionResult(
        barcode=base.barcode,
        product_name=base.product_name,
        brand=base.brand,
        category=base.category,
        manufacturer=base.manufacturer,
        country=base.country,
        ingredients=base.ingredients,
        allergens=base.allergens,
        nutrition=base.nutrition,
        source_url=base.source_url,
        source_type=base.source_type,
        evidence_type=base.evidence_type,
        confidence_level=base.confidence_level,
        raw_data=base.raw_data,
        company_id=base.company_id,
        brand_id=base.brand_id,
        status=_status_value(status),
        error_code=error_code,
        error_detail=error_detail,
        retryable=retryable,
    )


def _extract_ingredients(raw_list: list) -> list[ExtractedIngredients]:
    """Extract and validate ingredients from LLM output."""
    results = []
    if not isinstance(raw_list, list):
        return results

    for item in raw_list:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip()
        if not name:
            continue

        amount = item.get("amount_value") or item.get("amount")
        if amount is not None:
            try:
                amount = float(amount)
                if amount < 0:
                    amount = None
            except (ValueError, TypeError):
                amount = None

        unit = str(item.get("unit", "")).strip().upper() or None
        if unit and unit not in VALID_UNITS:
            logger.warning("Invalid ingredient unit: %s", unit)
            unit = None

        conf = _validate_confidence_value(item.get("confidence_level"))

        results.append(ExtractedIngredients(
            name=name,
            amount_value=amount,
            unit=unit,
            confidence_level=conf,
        ))

    return results


def _extract_allergens(raw_list: list) -> list[ExtractedAllergen]:
    """Extract and validate allergens from LLM output."""
    results = []

    if not isinstance(raw_list, list):
        return results

    for item in raw_list:
        if not isinstance(item, dict):
            continue

        name = str(item.get("name", "")).strip().upper()

        if not name:
            continue

        if name not in VALID_ALLERGEN_NAMES:
            logger.warning(
                "Invalid allergen name from extraction: %s",
                name,
            )
            continue

        conf = _validate_confidence_value(item.get("confidence_level"))

        evidence = (
            str(item.get("evidence_type", ""))
            .strip()
            .upper()
            or None
        )

        raw_declared = item.get("is_declared")

        if isinstance(raw_declared, bool):
            is_declared = raw_declared
        else:
            is_declared = None

        results.append(
            ExtractedAllergen(
                name=name,
                confidence_level=conf,
                evidence_type=evidence,
                is_declared=is_declared,
            )
        )

    return results
NUTRITION_ALLOWED_UNITS = {
    "CARBOHYDRATE": {"G", "KG"},
    "ENERGY": {"KCAL", "KJ"},
    "FIBER": {"G", "KG"},
    "PROTEIN": {"G", "KG"},
    "SATURATED_FAT": {"G", "KG"},
    "SODIUM": {"MG", "G", "KG"},
    "SUGAR": {"G", "KG"},
    "TOTAL_FAT": {"G", "KG"},
    "TRANS_FAT": {"G", "KG"},
}

def _extract_nutrition(raw_list: list) -> list[ExtractedNutrition]:
    """Extract and validate nutrition from LLM output."""
    results = []
    if not isinstance(raw_list, list):
        return results

    for item in raw_list:
        if not isinstance(item, dict):
            continue

        ntype = str(item.get("nutrition_type", "")).strip().upper()
        if ntype not in VALID_NUTRITION_TYPES:
            logger.warning("Invalid nutrition type: %s", ntype)
            continue

        amount_raw = item.get("amount_value")
        if amount_raw is None:
            amount_raw = item.get("value")
        if amount_raw is None:
            logger.warning(
                "Nutrition %s has no amount; entry dropped (never 0)",
                ntype,
            )
            continue

        try:
            amount = float(amount_raw)
        except (ValueError, TypeError):
            logger.warning("Invalid nutrition amount: %s", amount_raw)
            continue

        if amount < 0:
            logger.warning("Negative nutrition value rejected: %s=%s", ntype, amount)
            continue

        unit = str(item.get("unit", "")).strip().upper()

        allowed_units = NUTRITION_ALLOWED_UNITS.get(ntype, set())

        if unit not in allowed_units:
            logger.warning(
                "Invalid unit %s for nutrition type %s",
                unit,
                ntype,
            )
            continue

        conf = _validate_confidence_value(item.get("confidence_level"))

        results.append(ExtractedNutrition(
            nutrition_type=ntype,
            amount_value=amount,
            unit=unit,
            measurement_basis=item.get("measurement_basis"),
            confidence_level=conf,
        ))

    return results


def _validate_confidence_value(value) -> Optional[float]:
    """Validate confidence without inventing a default value."""

    if value is None:
        return None

    try:
        f = float(value)
    except (ValueError, TypeError):
        return None

    if f != f:  # NaN
        return None

    return max(0.0, min(1.0, f))
