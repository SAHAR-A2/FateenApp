from fastapi import APIRouter, Depends, HTTPException, Query
from app.services.barcode_service import get_product_by_barcode
from app.services.search_service import search_products_by_name
from app.services.compatibility_service import evaluate_compatibility
from app.services.alternatives_service import get_safe_alternatives
from app.schemas.product import ProductBarcodeResponse
from app.schemas.search import ProductSearchResponse
from app.schemas.compatibility import CompatibilityRequest, CompatibilityResponse
from app.schemas.alternatives import AlternativesResponse
from app.core.auth import require_authenticated_user

router = APIRouter(prefix="/api/v1/products", tags=["Products"])


@router.get(
    "/barcode/{barcode}",
    response_model=ProductBarcodeResponse,
    summary="Look up product by barcode",
    description=(
        "Returns product information for the given EAN/UPC barcode. "
        "Returns 404 if no active, non-deleted product is linked to this barcode."
    ),
    responses={
        404: {"description": "Product barcode not found"},
    },
)
def product_by_barcode(barcode: str):
    product = get_product_by_barcode(barcode)

    if product is None:
        raise HTTPException(
            status_code=404,
            detail="Product barcode not found",
        )

    return product


@router.get(
    "/search",
    response_model=ProductSearchResponse,
    summary="Search products by name",
    description=(
        "FateenDB-backed product search by name (case-insensitive substring "
        "match). Returns an empty result set for queries shorter than 2 "
        "characters, rather than an error."
    ),
)
def search_products_endpoint(
    q: str = Query(..., min_length=1, max_length=200, description="Search text"),
    language: str = Query("ar", pattern="^(ar|en)$"),
):
    return search_products_by_name(q, language)


@router.post(
    "/barcode/{barcode}/compatibility",
    response_model=CompatibilityResponse,
    summary="Evaluate product compatibility for a user's allergy/health context",
    description=(
        "Evaluates whether the product identified by this barcode is "
        "compatible with the allergy/health context supplied in the request "
        "body. The backend is the sole authority for this decision -- the "
        "client must not recompute it. User allergy/disease profile data "
        "is not stored in FateenDB; it is supplied per-request from the "
        "client's own profile store (Firestore)."
    ),
    responses={
        401: {"description": "Missing or invalid authentication token"},
        404: {"description": "Product barcode not found"},
    },
)
def product_compatibility(
    barcode: str,
    request: CompatibilityRequest,
    _user_id: str = Depends(require_authenticated_user),
):
    result = evaluate_compatibility(barcode, request)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Product barcode not found",
        )

    return result


@router.post(
    "/barcode/{barcode}/alternatives",
    response_model=AlternativesResponse,
    summary="Find backend-verified safe alternatives for a product",
    description=(
        "Retrieves candidate products from FateenDB (same category where "
        "known) and evaluates every candidate through the same "
        "Compatibility Service used elsewhere. Only candidates confirmed "
        "SAFE for the supplied allergy/health context are returned -- "
        "WARNING/DANGER/UNKNOWN/INSUFFICIENT_DATA candidates are excluded, "
        "never presented as a lower-confidence alternative."
    ),
    responses={
        401: {"description": "Missing or invalid authentication token"},
        404: {"description": "Product barcode not found"},
    },
)
def product_alternatives(
    barcode: str,
    request: CompatibilityRequest,
    _user_id: str = Depends(require_authenticated_user),
):
    result = get_safe_alternatives(barcode, request)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Product barcode not found",
        )

    return result
