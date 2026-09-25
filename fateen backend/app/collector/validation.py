"""P12: Data quality validation before ingestion.

Validates every aspect of collected data. Rejects invalid data.
Does NOT silently fix suspicious values.
"""
import logging
from typing import Optional

from app.collector.models import CollectedProductData, ValidationResult
from app.agent.validators import validate_barcode, validate_confidence
from app.agent.normalizers import normalize_barcode, normalize_name

logger = logging.getLogger("fateen.collector.validation")

VALID_NUTRITION_TYPES = {
    "CARBOHYDRATE", "ENERGY", "FIBER", "PROTEIN",
    "SATURATED_FAT", "SODIUM", "SUGAR", "TOTAL_FAT", "TRANS_FAT",
}
VALID_UNITS = {"MG", "G", "KG", "ML", "L", "KCAL", "KJ", "PCS"}

NUTRITION_RANGES = {
    "ENERGY": (0, 9000),
    "CARBOHYDRATE": (0, 1000),
    "SUGAR": (0, 1000),
    "FIBER": (0, 100),
    "PROTEIN": (0, 1000),
    "TOTAL_FAT": (0, 1000),
    "SATURATED_FAT": (0, 1000),
    "TRANS_FAT": (0, 100),
    "SODIUM": (0, 50000),
}


def validate_product_data(data: CollectedProductData) -> ValidationResult:
    """Comprehensive validation of collected product data.

    Returns ValidationResult with is_valid, errors, and warnings.
    Does NOT silently fix values. Invalid data is rejected.
    """
    result = ValidationResult()

    if data.barcode:
        barcode_errors = validate_barcode(data.barcode)
        if barcode_errors:
            result.errors.extend(barcode_errors)
            result.is_valid = False

    if not data.product_name or not data.product_name.strip():
        result.errors.append("Product name is required")
        result.is_valid = False

    # Confidence is optional under the "no fabrication" rule: a missing or
    # invalid confidence value stays None (never guessed as a number), and
    # an absent confidence does not fail validation by itself. When present
    # it must be a valid 0..1 value.
    if data.confidence_level is not None:
        conf_errors = validate_confidence(data.confidence_level)
        if conf_errors:
            result.errors.extend(conf_errors)
            result.is_valid = False

    for i, ing in enumerate(data.ingredients):
        if not ing.name or not ing.name.strip():
            result.warnings.append(f"Ingredient {i}: empty name, skipped")
            continue

        if ing.unit and ing.unit not in VALID_UNITS:
            result.errors.append(f"Ingredient '{ing.name}': invalid unit '{ing.unit}'")
            result.is_valid = False

        if ing.amount_value is not None and ing.amount_value < 0:
            result.errors.append(f"Ingredient '{ing.name}': negative amount")
            result.is_valid = False

        if ing.confidence_level is not None:
            conf_errors = validate_confidence(ing.confidence_level)
            if conf_errors:
                result.errors.append(f"Ingredient '{ing.name}': {conf_errors[0]}")
                result.is_valid = False

    seen_ingredients = set()
    for ing in data.ingredients:
        key = normalize_name(ing.name)
        if key in seen_ingredients:
            result.warnings.append(f"Duplicate ingredient: {ing.name}")
        seen_ingredients.add(key)

    for i, al in enumerate(data.allergens):
        if not al.name or not al.name.strip():
            result.warnings.append(f"Allergen {i}: empty name, skipped")
            continue

        if al.confidence_level is not None:
            conf_errors = validate_confidence(al.confidence_level)
            if conf_errors:
                result.errors.append(f"Allergen '{al.name}': {conf_errors[0]}")
                result.is_valid = False

    seen_allergens = set()
    for al in data.allergens:
        key = normalize_name(al.name)
        if key in seen_allergens:
            result.warnings.append(f"Duplicate allergen: {al.name}")
        seen_allergens.add(key)

    for i, nut in enumerate(data.nutrition):
        if nut.nutrition_type not in VALID_NUTRITION_TYPES:
            result.errors.append(f"Nutrition {i}: invalid type '{nut.nutrition_type}'")
            result.is_valid = False
            continue

        if nut.unit not in VALID_UNITS:
            result.errors.append(f"Nutrition '{nut.nutrition_type}': invalid unit '{nut.unit}'")
            result.is_valid = False

        if nut.amount_value < 0:
            result.errors.append(f"Nutrition '{nut.nutrition_type}': negative value")
            result.is_valid = False

        if nut.nutrition_type in NUTRITION_RANGES:
            lo, hi = NUTRITION_RANGES[nut.nutrition_type]
            if not (lo <= nut.amount_value <= hi):
                result.warnings.append(
                    f"Nutrition '{nut.nutrition_type}': value {nut.amount_value} "
                    f"outside expected range [{lo}, {hi}]"
                )

        if nut.confidence_level is not None:
            conf_errors = validate_confidence(nut.confidence_level)
            if conf_errors:
                result.errors.append(f"Nutrition '{nut.nutrition_type}': {conf_errors[0]}")
                result.is_valid = False

    seen_nutrition = set()
    for nut in data.nutrition:
        key = f"{nut.nutrition_type}_{nut.unit}"
        if key in seen_nutrition:
            result.warnings.append(f"Duplicate nutrition: {nut.nutrition_type} ({nut.unit})")
        seen_nutrition.add(key)

    return result
