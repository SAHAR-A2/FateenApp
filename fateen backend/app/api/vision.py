from fastapi import APIRouter, Depends, HTTPException

from app.schemas.vision import DishEstimationRequest, DishEstimationResponse
from app.services.vision_service import (
    estimate_dish_from_image,
    VisionServiceUnavailable,
)
from app.core.auth import require_authenticated_user

router = APIRouter(prefix="/api/v1/vision", tags=["Vision"])


@router.post(
    "/estimate-dish",
    response_model=DishEstimationResponse,
    summary="Estimate a dish's name and likely ingredients from a photo",
    description=(
        "Server-side Gemini call -- the API key never leaves the backend. "
        "This is an ESTIMATION/extraction step only: it does not decide "
        "product compatibility, and is unrelated to "
        "app.services.compatibility_service. The client is responsible "
        "for what it does with the estimated ingredients."
    ),
    responses={
        401: {"description": "Missing or invalid authentication token"},
        503: {"description": "Dish estimation temporarily unavailable"},
    },
)
async def estimate_dish(
    request: DishEstimationRequest,
    _user_id: str = Depends(require_authenticated_user),
):
    try:
        return await estimate_dish_from_image(request.image_base64)
    except VisionServiceUnavailable as e:
        raise HTTPException(status_code=503, detail=str(e))
