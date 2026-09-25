import hmac
import logging

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel, Field
from typing import Optional

from app.core.config import settings
from app.llm.extractor import extract_product_data, enrich_product

logger = logging.getLogger("fateen.enrichment")

router = APIRouter(prefix="/api/v1/llm", tags=["LLM"])


class ExtractRequest(BaseModel):
    barcode: str = Field(..., description="Product barcode", max_length=50)
    name: Optional[str] = Field(None, description="Product name hint", max_length=500)
    description: Optional[str] = Field(None, description="Product description hint", max_length=5000)
    context: Optional[str] = Field(None, description="Additional context (label text, etc.)", max_length=10000)
    provider: Optional[str] = Field(None, description="LLM provider override (openai/anthropic/ollama)", max_length=50)


class EnrichRequest(BaseModel):
    barcode: str = Field(..., description="Product barcode", max_length=50)
    product_json: str = Field(..., description="Existing product data as JSON string", max_length=50000)
    provider: Optional[str] = Field(None, description="LLM provider override", max_length=50)


class ExtractResponse(BaseModel):
    barcode: str
    product_name: Optional[str] = None
    product_description: Optional[str] = None
    ingredients: list[dict]
    allergens: list[dict]
    nutrition: list[dict]
    confidence_level: float = Field(ge=0, le=1)
    source: str


class EnrichResponse(BaseModel):
    suggestions: list[dict]
    confidence: float = Field(ge=0, le=1)
    notes: Optional[str] = None


def _check_api_key(x_api_key: Optional[str] = Header(None)):
    if settings.agent_ingest_api_key:
        if not x_api_key:
            raise HTTPException(status_code=401, detail="Missing API key")
        if not hmac.compare_digest(x_api_key, settings.agent_ingest_api_key):
            raise HTTPException(status_code=401, detail="Invalid API key")


@router.post(
    "/extract",
    response_model=ExtractResponse,
    summary="Extract product data using LLM",
    description=(
        "Uses an LLM to extract structured product data from a barcode, "
        "name, description, and/or context text. Returns ingredients, "
        "allergens, and nutrition data ready for ingestion."
    ),
    responses={
        401: {"description": "Missing or invalid API key"},
        500: {"description": "LLM provider error"},
    },
)
def extract(request: ExtractRequest, x_api_key: Optional[str] = Header(None)):
    _check_api_key(x_api_key)

    try:
        result = extract_product_data(
            barcode=request.barcode,
            name=request.name,
            description=request.description,
            context=request.context,
            provider=request.provider,
        )
    except Exception as e:
        logger.exception("LLM extraction failed for barcode=%s", request.barcode)
        raise HTTPException(
            status_code=500,
            detail="LLM extraction failed. Check server logs for details.",
        )

    return ExtractResponse(
        barcode=result.barcode,
        product_name=result.product_name,
        product_description=result.product_description,
        ingredients=result.ingredients,
        allergens=result.allergens,
        nutrition=result.nutrition,
        confidence_level=result.confidence_level,
        source=result.source,
    )


@router.post(
    "/enrich",
    response_model=EnrichResponse,
    summary="Enrich existing product data using LLM",
    description=(
        "Takes existing product data and uses an LLM to suggest improvements, "
        "corrections, or missing information."
    ),
    responses={
        401: {"description": "Missing or invalid API key"},
        500: {"description": "LLM provider error"},
    },
)
def enrich(request: EnrichRequest, x_api_key: Optional[str] = Header(None)):
    _check_api_key(x_api_key)

    try:
        result = enrich_product(
            barcode=request.barcode,
            product_json=request.product_json,
            provider=request.provider,
        )
    except Exception as e:
        logger.exception("LLM enrichment failed for barcode=%s", request.barcode)
        raise HTTPException(
            status_code=500,
            detail="LLM enrichment failed. Check server logs for details.",
        )

    return EnrichResponse(
        suggestions=result.get("suggestions", []),
        confidence=float(result.get("confidence", 0.0)),
        notes=result.get("notes"),
    )
