from fastapi import APIRouter, HTTPException

from app.services.product_details_service import get_product_details_by_barcode
from app.schemas.product_details import ProductDetailsResponse

router = APIRouter(
    prefix="/api/v1/products",
    tags=["Products"],
)


@router.get(
    "/details/barcode/{barcode}",
    response_model=ProductDetailsResponse,
    summary="Get full product details by barcode",
    description=(
        "Returns complete product information including ingredients, allergens, "
        "health flags, and nutrition values for the given barcode."
    ),
    responses={
        404: {"description": "Product barcode not found"},
    },
)
def product_details_by_barcode(barcode: str):
    product = get_product_details_by_barcode(barcode)

    if product is None:
        raise HTTPException(
            status_code=404,
            detail="Product barcode not found",
        )

    return product
