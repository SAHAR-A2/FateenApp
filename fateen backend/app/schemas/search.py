from pydantic import BaseModel, Field
from typing import Optional


class ProductSearchResult(BaseModel):
    internal_code: str
    name: str
    description: Optional[str] = None
    confidence_level: float = Field(ge=0, le=1)
    lifecycle_status: str
    # A representative barcode for this product (preferring the
    # PRIMARY_BARCODE relationship where one exists). May be absent if the
    # product has no active barcode linked yet.
    barcode: Optional[str] = None
    image_url: Optional[str] = None
    name_ar: Optional[str] = None
    name_en: Optional[str] = None


class ProductSearchResponse(BaseModel):
    query: str
    count: int
    results: list[ProductSearchResult]
