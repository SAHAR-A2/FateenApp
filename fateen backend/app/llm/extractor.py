from typing import Optional
from dataclasses import dataclass, field

from app.llm.client import LLMClient
from app.llm.prompts import (
    PRODUCT_EXTRACTION_SYSTEM,
    PRODUCT_EXTRACTION_USER,
    PRODUCT_ENRICHMENT_SYSTEM,
    PRODUCT_ENRICHMENT_USER,
)
from app.agent.normalizers import normalize_barcode, normalize_name
from app.agent.validators import validate_confidence


VALID_NUTRITION_TYPES = {
    "CARBOHYDRATE", "ENERGY", "FIBER", "PROTEIN",
    "SATURATED_FAT", "SODIUM", "SUGAR", "TOTAL_FAT", "TRANS_FAT",
}

VALID_UNITS = {"MG", "G", "KG", "ML", "L", "KCAL", "KJ", "PCS"}


@dataclass
class ExtractedProduct:
    barcode: str
    product_name: Optional[str] = None
    product_description: Optional[str] = None
    ingredients: list = field(default_factory=list)
    allergens: list = field(default_factory=list)
    nutrition: list = field(default_factory=list)
    confidence_level: float = 0.0
    source: str = "llm_extraction"


def extract_product_data(
    barcode: str,
    name: Optional[str] = None,
    description: Optional[str] = None,
    context: Optional[str] = None,
    provider: Optional[str] = None,
) -> ExtractedProduct:
    barcode = normalize_barcode(barcode)

    client = LLMClient(provider=provider)

    user_prompt = PRODUCT_EXTRACTION_USER.format(
        barcode=barcode,
        name=name or "unknown",
        description=description or "none",
        context=context or "none",
    )

    response = client.chat(PRODUCT_EXTRACTION_SYSTEM, user_prompt)
    data = response.parsed_json()

    ingredients = _validate_ingredients(data.get("ingredients", []))
    allergens = _validate_allergens(data.get("allergens", []))
    nutrition = _validate_nutrition(data.get("nutrition", []))

    confidence_raw = data.get("confidence_level", 0.5)
    conf_errors = validate_confidence(confidence_raw)
    if conf_errors:
        confidence_raw = 0.5
    confidence_level = max(0.0, min(1.0, float(confidence_raw)))

    return ExtractedProduct(
        barcode=barcode,
        product_name=data.get("product_name", name),
        product_description=data.get("product_description", description),
        ingredients=ingredients,
        allergens=allergens,
        nutrition=nutrition,
        confidence_level=confidence_level,
    )


def enrich_product(
    barcode: str,
    product_json: str,
    provider: Optional[str] = None,
) -> dict:
    client = LLMClient(provider=provider)

    user_prompt = PRODUCT_ENRICHMENT_USER.format(
        barcode=barcode,
        product_json=product_json,
    )

    response = client.chat(PRODUCT_ENRICHMENT_SYSTEM, user_prompt)
    return response.parsed_json()


def _validate_ingredients(items: list) -> list:
    result = []
    for item in items:
        if not isinstance(item, dict) or "name" not in item:
            continue
        name = str(item["name"]).strip()
        if not name:
            continue
        entry = {"name": normalize_name(name)}
        if item.get("amount_value") is not None:
            try:
                entry["amount_value"] = float(item["amount_value"])
            except (ValueError, TypeError):
                pass
        if item.get("unit") and str(item["unit"]).upper() in VALID_UNITS:
            entry["unit"] = str(item["unit"]).upper()
        result.append(entry)
    return result


def _validate_allergens(items: list) -> list:
    result = []
    for item in items:
        if not isinstance(item, dict) or "name" not in item:
            continue
        name = str(item["name"]).strip()
        if name:
            result.append({"name": normalize_name(name)})
    return result


def _validate_nutrition(items: list) -> list:
    result = []
    for item in items:
        if not isinstance(item, dict):
            continue
        nt = str(item.get("nutrition_type", "")).upper()
        unit = str(item.get("unit", "")).upper()
        if nt not in VALID_NUTRITION_TYPES or unit not in VALID_UNITS:
            continue
        try:
            amount = float(item["amount_value"])
        except (KeyError, ValueError, TypeError):
            continue
        if amount < 0:
            continue
        result.append({
            "nutrition_type": nt,
            "amount_value": amount,
            "unit": unit,
        })
    return result
