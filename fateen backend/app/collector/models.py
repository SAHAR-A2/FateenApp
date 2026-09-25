"""Core data models for the FATEEN Data Collection Agent.

Defines Pydantic models and dataclasses used throughout the collection pipeline.
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from enum import Enum


class ScanStatus(str, Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    PARTIAL = "partial"
    FAILED = "failed"
    BLOCKED = "blocked"


class DiscoveryStatus(str, Enum):
    DISCOVERED = "discovered"
    ENRICHED = "enriched"
    NORMALIZED = "normalized"
    PENDING_REVIEW = "pending_review"
    APPROVED = "approved"
    MERGED = "merged"
    DISCARDED = "discarded"
    VALIDATION_FAILED = "validation_failed"
    MATCHED = "matched"
    NEW = "new"


class ConflictResolution(str, Enum):
    RESOLVED = "resolved"
    UNRESOLVED = "unresolved"
    NEEDS_REVIEW = "needs_review"


class ConflictStatus(str, Enum):
    DETECTED = "detected"
    ACKNOWLEDGED = "acknowledged"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


class HalalStatus(str, Enum):
    HALAL = "HALAL"
    HARAM = "HARAM"
    DOUBTFUL = "DOUBTFUL"
    UNKNOWN = "UNKNOWN"
    NEEDS_REVIEW = "NEEDS_REVIEW"


class HealthEvaluation(str, Enum):
    SAFE = "SAFE"
    CAUTION = "CAUTION"
    WARNING = "WARNING"
    UNSAFE = "UNSAFE"
    UNKNOWN = "UNKNOWN"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"


class ExtractionStatus(str, Enum):
    """Typed outcome of an auto-extraction attempt.

    Distinct outcomes mean a provider failure is never confused with bad
    or missing product data. SUCCESS / EMPTY_EXTRACTION /
    MALFORMED_LLM_RESPONSE describe the extraction itself; the
    PROVIDER_* values describe a provider-side failure and must be routed
    to operational retry state, never to data validation failure.
    """

    SUCCESS = "SUCCESS"
    EMPTY_EXTRACTION = "EMPTY_EXTRACTION"
    MALFORMED_LLM_RESPONSE = "MALFORMED_LLM_RESPONSE"
    PROVIDER_QUOTA_EXHAUSTED = "PROVIDER_QUOTA_EXHAUSTED"
    PROVIDER_RATE_LIMITED = "PROVIDER_RATE_LIMITED"
    PROVIDER_TIMEOUT = "PROVIDER_TIMEOUT"
    PROVIDER_UNAVAILABLE = "PROVIDER_UNAVAILABLE"
    PROVIDER_ERROR = "PROVIDER_ERROR"


PROVIDER_FAILURE_STATUSES = frozenset(
    {
        ExtractionStatus.PROVIDER_QUOTA_EXHAUSTED,
        ExtractionStatus.PROVIDER_RATE_LIMITED,
        ExtractionStatus.PROVIDER_TIMEOUT,
        ExtractionStatus.PROVIDER_UNAVAILABLE,
        ExtractionStatus.PROVIDER_ERROR,
    }
)


@dataclass
class DiscoveredProduct:
    """A raw discovered product candidate before validation."""
    name: str
    brand: Optional[str] = None
    barcode: Optional[str] = None
    category: Optional[str] = None
    country: str = "SA"
    market: str = "packaged_food"
    source_url: Optional[str] = None
    source_reference: Optional[str] = None
    company_id: Optional[str] = None
    raw_data: dict = field(default_factory=dict)


@dataclass
class ExtractedIngredients:
    """Extracted ingredient data."""
    name: str
    amount_value: Optional[float] = None
    unit: Optional[str] = None
    confidence_level: float = 0.5
    aliases: list[str] = field(default_factory=list)


@dataclass
class ExtractedAllergen:
    """Extracted allergen data."""
    name: str
    confidence_level: float = 0.5
    evidence_type: str = "LABEL"
    is_declared: bool = True


@dataclass
class ExtractedNutrition:
    """Extracted nutrition data."""
    nutrition_type: str
    amount_value: float
    unit: str
    measurement_basis: Optional[str] = None
    confidence_level: float = 0.5


@dataclass
class CollectedProductData:
    """Fully collected and extracted product data ready for validation."""
    barcode: Optional[str] = None
    product_name: str = ""
    brand: Optional[str] = None
    category: Optional[str] = None
    manufacturer: Optional[str] = None
    country: str = "SA"
    ingredients: list[ExtractedIngredients] = field(default_factory=list)
    allergens: list[ExtractedAllergen] = field(default_factory=list)
    nutrition: list[ExtractedNutrition] = field(default_factory=list)
    source_url: Optional[str] = None
    source_type: Optional[str] = None
    evidence_type: str = "LABEL"
    confidence_level: float = 0.5
    raw_data: dict = field(default_factory=dict)
    company_id: Optional[str] = None
    brand_id: Optional[str] = None


@dataclass
class ExtractionResult(CollectedProductData):
    """CollectedProductData carrying a typed extraction outcome.

    Subclasses CollectedProductData so every existing consumer (validation,
    deduplication, ingestion, tests) keeps working unchanged: a result with
    status SUCCESS / EMPTY_EXTRACTION / MALFORMED_LLM_RESPONSE behaves
    exactly like the old return value. Provider failures additionally carry
    a status from PROVIDER_FAILURE_STATUSES, an error_code/error_detail and
    retryable=True so the orchestrator can route them to operational retry
    state instead of a data validation failure.
    """

    status: str = "SUCCESS"
    error_code: Optional[str] = None
    error_detail: Optional[str] = None
    retryable: bool = False


@dataclass
class ValidationResult:
    """Result of validating collected product data."""
    is_valid: bool = True
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    confidence_adjustments: dict = field(default_factory=dict)


@dataclass
class ConflictRecord:
    """A detected data conflict."""
    entity_type: str
    entity_id: str
    entity_name: str
    field_name: str
    value_a: str
    value_b: str
    source_a_id: Optional[str] = None
    source_b_id: Optional[str] = None
    confidence_a: Optional[float] = None
    confidence_b: Optional[float] = None


@dataclass
class EvidenceRecord:
    """A traceable evidence record."""
    entity_type: str
    entity_id: str
    entity_name: Optional[str] = None
    source_config_id: Optional[str] = None
    evidence_type_code: str = "LABEL"
    raw_value: Optional[str] = None
    normalized_value: Optional[str] = None
    confidence: float = 0.5
    metadata: dict = field(default_factory=dict)


@dataclass
class ScanJobResult:
    """Result of a company scan job."""
    scan_job_id: str
    company_id: str
    company_name: str
    status: str = "pending"
    products_discovered: int = 0
    products_processed: int = 0
    products_accepted: int = 0
    products_rejected: int = 0
    products_needs_review: int = 0
    products_created: int = 0
    products_updated: int = 0
    products_unchanged: int = 0
    conflicts_detected: int = 0
    errors_count: int = 0
    coverage_pct: Optional[float] = None
    duration_seconds: Optional[float] = None
    errors: list[str] = field(default_factory=list)


@dataclass
class CoverageReport:
    """Coverage metrics for a company."""
    company_id: str
    company_name: str
    total_products: int = 0
    products_with_barcode: int = 0
    products_with_ingredients: int = 0
    products_with_allergens: int = 0
    products_with_nutrition: int = 0
    products_with_evidence: int = 0
    barcode_coverage_pct: Optional[float] = None
    ingredient_coverage_pct: Optional[float] = None
    allergen_coverage_pct: Optional[float] = None
    nutrition_coverage_pct: Optional[float] = None
    evidence_coverage_pct: Optional[float] = None
    overall_coverage_pct: Optional[float] = None


@dataclass
class RetrievalResult:
    """Result of a retrieval attempt."""
    success: bool = False
    url: str = ""
    status_code: Optional[int] = None
    content_type: Optional[str] = None
    content: Optional[str] = None
    content_length: int = 0
    error: Optional[str] = None
    duration_seconds: float = 0.0
    retries: int = 0


@dataclass
class UnitConversion:
    """A unit conversion factor."""
    from_unit: str
    to_unit: str
    factor: float
    measurement_type: str
    is_exact: bool = True
