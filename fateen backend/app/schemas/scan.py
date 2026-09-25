from pydantic import BaseModel, Field
from typing import Optional, Any
from datetime import datetime


class RawIngredient(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    amount_value: Optional[float] = Field(default=None, ge=0)
    unit: Optional[str] = Field(default=None, max_length=20)
    confidence_level: float = Field(default=0.5, ge=0, le=1)


class RawAllergen(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    confidence_level: float = Field(default=0.5, ge=0, le=1)
    evidence_type: str = Field(default="LABEL", max_length=50)
    is_declared: bool = True


class RawNutrition(BaseModel):
    nutrition_type: str = Field(..., min_length=1, max_length=50)
    amount_value: float = Field(..., ge=0)
    unit: str = Field(..., min_length=1, max_length=20)
    measurement_basis: Optional[str] = Field(default=None, max_length=50)
    confidence_level: float = Field(default=0.5, ge=0, le=1)


class DiscoveryRawData(BaseModel):
    """Structured payload for a discovery candidate's raw_data column.

    Mirrors exactly what app.collector.orchestrator._candidate_to_collected()
    reads back out of discovery_candidates.raw_data, so what you submit here
    is what the collector will actually see. Every field is validated by
    Pydantic (type + range) before it ever reaches the database — this is
    JSON stored in a jsonb column via a parameterized query, never
    interpolated SQL, so there is no separate "unsafe" path to guard against
    beyond making sure the shape is sane.
    """

    ingredients: list[RawIngredient] = Field(default_factory=list, max_length=200)
    allergens: list[RawAllergen] = Field(default_factory=list, max_length=100)
    nutrition: list[RawNutrition] = Field(default_factory=list, max_length=100)


class ScanJobCreate(BaseModel):
    company_id: str = Field(..., max_length=100)
    scan_type: str = Field("full", max_length=50)
    max_products: Optional[int] = Field(None, ge=1, le=10000)
    dry_run: bool = Field(
        default=False,
        description=(
            "Caller-requested dry run. IMPORTANT: this does not mean zero "
            "database writes. It guarantees no product/brand/barcode/"
            "ingredient/allergen/nutrition data is created or modified "
            "(see app.collector.orchestrator.DRY_RUN_FORBIDDEN_TABLES). "
            "Operational records needed to report on the scan -- scan_jobs, "
            "scan_job_items, discovery_candidates status, and data_conflicts "
            "-- are written the same way in both modes; that is by design, "
            "not a bug. Note also this is only ONE of two inputs to the "
            "effective dry-run decision -- the environment-level "
            "AGENT_DRY_RUN switch can still force a dry run even if this is "
            "false. See app.core.config.resolve_effective_dry_run."
        ),
    )


class ScanJobResponse(BaseModel):
    id: str
    company_id: str
    scan_type: str = "full"
    status: str = "pending"
    products_discovered: int = 0
    products_processed: int = 0
    products_accepted: int = 0
    products_rejected: int = 0
    products_needs_review: int = 0
    conflicts_detected: int = 0
    errors_count: int = 0
    coverage_pct: float = 0.0
    duration_seconds: Optional[float] = None
    started_at: Optional[datetime] = None
    finished_at: Optional[datetime] = None
    created_at: Optional[datetime] = None


class ScanReportResponse(BaseModel):
    company_name: str
    scan_type: str
    status: str
    summary: dict[str, Any] = {}
    coverage: dict[str, float] = {}
    items: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
