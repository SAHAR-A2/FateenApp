from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional

from app.core.auth import require_authenticated_user
from app.services.barcode_image_service import InvalidImage, read_barcode

router = APIRouter(prefix="/api/v1/products", tags=["Products"])


class BarcodeImageRequest(BaseModel):
    # About 7.5 MB of image; the app sends a phone photo or a screenshot.
    image_base64: str = Field(..., min_length=16, max_length=10_000_000)


class BarcodeImageResponse(BaseModel):
    barcode: Optional[str] = None


@router.post(
    "/barcode-from-image",
    response_model=BarcodeImageResponse,
    summary="Read a product barcode from a photo",
    description=(
        "Returns the first EAN-13/EAN-8/UPC-A/UPC-E barcode with a valid "
        "check digit, or null when none can be read. Used by the web app, "
        "which cannot decode a picked photo in the browser."
    ),
    responses={
        400: {"description": "The upload is not an image"},
        401: {"description": "Missing or invalid authentication token"},
    },
)
def barcode_from_image(
    request: BarcodeImageRequest,
    _user_id: str = Depends(require_authenticated_user),
):
    try:
        return BarcodeImageResponse(barcode=read_barcode(request.image_base64))
    except InvalidImage as exc:
        raise HTTPException(status_code=400, detail=str(exc))
