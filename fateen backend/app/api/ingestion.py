import hmac
import logging

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel, Field
from typing import Optional

from app.core.config import settings, resolve_effective_dry_run
from app.agent.ingestion import ingest
from app.agent.models import (
    IngestionInput,
    IngestionIngredient,
    IngestionAllergen,
    IngestionNutrition,
)

logger = logging.getLogger("fateen.ingestion")

router = APIRouter(prefix="/api/v1/agent", tags=["Agent"])


class IngestIngredient(BaseModel):
    name: str = Field(..., max_length=500)
    amount_value: Optional[float] = Field(None, ge=0)
    unit: Optional[str] = Field(None, max_length=20)
    order: Optional[int] = None


class IngestAllergen(BaseModel):
    name: str = Field(..., max_length=500)


class IngestNutrition(BaseModel):
    nutrition_type: str = Field(..., max_length=50)
    amount_value: float = Field(..., ge=0)
    unit: str = Field(..., max_length=20)
    measurement_basis: Optional[str] = Field(None, max_length=100)


class IngestionRequest(BaseModel):
    barcode: str = Field(..., description="Product barcode (EAN/UPC)", max_length=50)
    dry_run: bool = Field(default=True, description="Read-only mode (no DB writes)")
    product_name: Optional[str] = Field(None, description="Product name override", max_length=500)
    product_description: Optional[str] = Field(None, description="Product description override", max_length=5000)
    ingredients: list[IngestIngredient] = Field(default_factory=list, max_length=200)
    allergens: list[IngestAllergen] = Field(default_factory=list, max_length=100)
    nutrition: list[IngestNutrition] = Field(default_factory=list, max_length=50)
    source: str = Field(default="manual", description="Data source identifier", max_length=100)
    confidence_level: float = Field(default=0.5, ge=0, le=1, description="Overall confidence (0-1)")


@router.post(
    "/ingest",
    summary="Ingest product data for a barcode",
    description=(
        "Submits product data (ingredients, allergens, nutrition) for a given barcode. "
        "In dry_run mode (default), returns proposed changes without writing to DB. "
        "A real write happens ONLY when dry_run=false in the request AND "
        "AGENT_DRY_RUN=false in the environment; either one alone forces a dry run "
        "(env-level AGENT_DRY_RUN=true is a global override the caller cannot bypass)."
    ),
    responses={
        401: {"description": "Missing or invalid API key"},
        422: {"description": "Validation error in request body"},
    },
)
def ingest_barcode(
    request: IngestionRequest,
    x_agent_api_key: Optional[str] = Header(None),
):
    if settings.agent_ingest_api_key:
        if not x_agent_api_key:
            raise HTTPException(
                status_code=401, detail="Missing API key"
            )
        if not hmac.compare_digest(x_agent_api_key, settings.agent_ingest_api_key):
            raise HTTPException(
                status_code=401, detail="Invalid API key"
            )

    input_data = IngestionInput(
        barcode=request.barcode,
        product_name=request.product_name,
        product_description=request.product_description,
        ingredients=[
            IngestionIngredient(
                name=ing.name,
                amount_value=ing.amount_value,
                unit=ing.unit,
                order=ing.order,
            )
            for ing in request.ingredients
        ],
        allergens=[
            IngestionAllergen(name=al.name)
            for al in request.allergens
        ],
        nutrition=[
            IngestionNutrition(
                nutrition_type=nut.nutrition_type,
                amount_value=nut.amount_value,
                unit=nut.unit,
                measurement_basis=nut.measurement_basis,
            )
            for nut in request.nutrition
        ],
        source=request.source,
        confidence_level=request.confidence_level,
    )

    dry_run = resolve_effective_dry_run(request.dry_run)

    try:
        result = ingest(input_data, dry_run=dry_run)
    except Exception as e:
        logger.exception("Ingestion failed for barcode=%s", request.barcode)
        raise HTTPException(
            status_code=500,
            detail="Ingestion failed. Check server logs for details.",
        )

    return result.to_dict()
