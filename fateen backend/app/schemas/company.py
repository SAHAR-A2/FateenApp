from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


class CompanyCreate(BaseModel):
    name: str = Field(..., max_length=500)
    slug: Optional[str] = Field(None, max_length=200)
    code: str = Field(..., max_length=100)
    country: str = Field("SA", max_length=10)
    market: str = Field("packaged_food", max_length=100)
    priority: int = Field(50, ge=0, le=100)
    expected_product_count: Optional[int] = Field(None, ge=0)
    description: Optional[str] = Field(None, max_length=5000)


class CompanyUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=500)
    slug: Optional[str] = Field(None, max_length=200)
    country: Optional[str] = Field(None, max_length=10)
    market: Optional[str] = Field(None, max_length=100)
    priority: Optional[int] = Field(None, ge=0, le=100)
    expected_product_count: Optional[int] = Field(None, ge=0)
    description: Optional[str] = Field(None, max_length=5000)
    scan_status: Optional[str] = Field(None, max_length=50)


class CompanyResponse(BaseModel):
    id: str
    internal_code: Optional[str] = None
    name: str
    slug: Optional[str] = None
    country: str = "SA"
    market: str = "packaged_food"
    priority: int = 50
    priority_score: Optional[float] = None
    scan_status: str = "idle"
    expected_product_count: Optional[int] = None
    discovered_product_count: int = 0
    verified_product_count: int = 0
    barcode_coverage_pct: Optional[float] = None
    ingredient_coverage_pct: Optional[float] = None
    allergen_coverage_pct: Optional[float] = None
    nutrition_coverage_pct: Optional[float] = None
    evidence_coverage_pct: Optional[float] = None
    last_scan_at: Optional[datetime] = None
    next_scan_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    @field_validator("id", mode="before")
    @classmethod
    def coerce_id_to_str(cls, v):
        return str(v) if v is not None else v


class CompanyListResponse(BaseModel):
    companies: list[CompanyResponse] = []
    total: int = 0
