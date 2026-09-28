from pydantic import BaseModel, Field
from typing import Optional

# Top-level compatibility status values.
#
# SAFE / WARNING / DANGER are the three outcomes the existing Flutter
# HealthChecker already produces (green/orange/red), kept unchanged in
# meaning. UNKNOWN and INSUFFICIENT_DATA are distinct, deliberately never
# collapsed into SAFE:
#   - UNKNOWN: we have no backend rule/mapping to evaluate this specific
#     allergy or health condition against yet (e.g. an allergen tag with no
#     verified FateenDB mapping, or a disease with no matching
#     health_conditions row).
#   - INSUFFICIENT_DATA: the product itself has no ingredient/allergen/
#     nutrition data recorded at all, so no evaluation is possible.
STATUS_SAFE = "SAFE"
STATUS_WARNING = "WARNING"
STATUS_DANGER = "DANGER"
STATUS_UNKNOWN = "UNKNOWN"
STATUS_INSUFFICIENT_DATA = "INSUFFICIENT_DATA"


class UserAllergyContext(BaseModel):
    tag: str = Field(
        ...,
        max_length=100,
        description=(
            "Allergy identifier as stored today in Firestore "
            "(Open Food Facts-style tag, e.g. 'en:peanuts')."
        ),
    )
    severity: Optional[str] = Field(
        None,
        max_length=50,
        description=(
            "User-reported severity band, passed through as-is. The backend "
            "only reuses the existing mild-vs-severe distinction already "
            "applied in the legacy Flutter HealthChecker; it does not "
            "interpret any new medical meaning from this field."
        ),
    )


class UserDiseaseContext(BaseModel):
    name: str = Field(..., max_length=200)
    severity: Optional[str] = Field(None, max_length=50)


class CompatibilityRequest(BaseModel):
    allergies: list[UserAllergyContext] = Field(default_factory=list, max_length=50)
    diseases: list[UserDiseaseContext] = Field(default_factory=list, max_length=50)


class ProductSummary(BaseModel):
    internal_code: str
    name: str
    barcode: str
    lifecycle_status: str
    confidence_level: float = Field(ge=0, le=1)
    image_url: Optional[str] = None


class MatchedAllergen(BaseModel):
    internal_code: str
    name: str
    source_tag: str
    confidence_level: float = Field(ge=0, le=1)
    evidence_type: Optional[str] = None


class HealthConditionResult(BaseModel):
    condition_code: str
    condition_name: str
    evaluation_result: str
    evidence: list[dict] = Field(default_factory=list)


class RelevantNutrition(BaseModel):
    nutrition_type: str
    amount_value: float
    unit: str
    confidence_level: float = Field(ge=0, le=1)


class CompatibilityResponse(BaseModel):
    status: str
    reason: str
    confidence: float = Field(ge=0, le=1)
    product: ProductSummary
    matched_allergens: list[MatchedAllergen] = Field(default_factory=list)
    health_conditions: list[HealthConditionResult] = Field(default_factory=list)
    relevant_nutrition: list[RelevantNutrition] = Field(default_factory=list)
