from pydantic import BaseModel, Field
from typing import Optional


class ProductBarcodeResponse(BaseModel):
    internal_code: str
    name: str
    barcode: str
    relationship_type: str
    source: Optional[str] = None
    evidence_type: Optional[str] = None
    lifecycle_status: str
    confidence_level: float = Field(ge=0, le=1)
