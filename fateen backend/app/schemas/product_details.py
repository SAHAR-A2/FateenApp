from pydantic import BaseModel, Field
from typing import Optional


class IngredientDetails(BaseModel):
    internal_code: str
    name: str
    relationship_type: str
    amount_value: Optional[float] = None
    unit: Optional[str] = None
    confidence_level: float = Field(ge=0, le=1)
    evidence_type: Optional[str] = None


class AllergenDetails(BaseModel):
    internal_code: str
    name: str
    relationship_type: str
    confidence_level: float = Field(ge=0, le=1)
    evidence_type: Optional[str] = None


class HealthFlagDetails(BaseModel):
    internal_code: str
    name: str
    relationship_type: str
    confidence_level: float = Field(ge=0, le=1)
    evidence_type: Optional[str] = None


class NutritionDetails(BaseModel):
    nutrition_type: str
    amount_value: float
    unit: str
    relationship_type: str
    confidence_level: float = Field(ge=0, le=1)
    evidence_type: Optional[str] = None
    # Basis the amount refers to (e.g. PER_100G, PER_SERVING). Without it
    # two values for the same nutrient are not comparable.
    measurement_basis: Optional[str] = None


class ProductDetailsResponse(BaseModel):
    internal_code: str
    name: str
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    description: Optional[str] = None
    confidence_level: float = Field(ge=0, le=1)
    lifecycle_status: str
    image_url: Optional[str] = None
    ingredients: list[IngredientDetails]
    allergens: list[AllergenDetails]
    health_flags: list[HealthFlagDetails]
    nutrition: list[NutritionDetails]
    # Ingredient list as printed on the pack, keyed by language ("ar", "en").
    ingredient_statements: dict[str, str] = {}
