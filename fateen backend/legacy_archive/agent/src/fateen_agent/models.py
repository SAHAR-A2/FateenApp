"""Pydantic data models flowing through the agent pipeline."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

from .constants import KEY_BARCODE, KEY_NAME


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class SourceInfo(BaseModel):
    """Provenance of a piece of data. Never optional for recorded facts."""

    name: str
    url: Optional[str] = None
    source_type: str
    priority: str = "UNVERIFIED"
    retrieved_at: datetime = Field(default_factory=utcnow)
    raw_excerpt: Optional[str] = None


class EvidenceItem(BaseModel):
    """One fact + the source that backs it. The auditability primitive."""

    fact: str
    value: Optional[str] = None
    source: SourceInfo
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)


class RawProductData(BaseModel):
    """Structured, source-extracted product data. NOT yet normalized/verified."""

    source: SourceInfo
    name: Optional[str] = None
    brand: Optional[str] = None
    company: Optional[str] = None
    package_size: Optional[str] = None
    barcode: Optional[str] = None
    ingredients: Optional[str] = None  # verbatim ingredient list (or raw text)
    ingredients_parsed: list[str] = Field(default_factory=list)
    allergens: list[str] = Field(default_factory=list)
    nutrition: dict[str, float] = Field(default_factory=dict)
    product_url: Optional[str] = None
    image_url: Optional[str] = None
    raw: dict[str, Any] = Field(default_factory=dict)  # full payload for staging
    language: Optional[str] = None


class Conflict(BaseModel):
    """A disagreement between two sources about one fact."""

    fact: str
    source_a: str = ""
    value_a: Optional[str] = None
    source_b: str = ""
    value_b: Optional[str] = None
    resolved: bool = False
    resolution: Optional[str] = None


class CandidateProduct(BaseModel):
    """The agent's normalized, evidence-backed view of one product."""

    product_key: str
    key_type: str = KEY_BARCODE
    name: Optional[str] = None
    brand: Optional[str] = None
    company: Optional[str] = None
    package_size: Optional[str] = None
    barcode: Optional[str] = None
    ingredients_raw: Optional[str] = None
    ingredients: list[str] = Field(default_factory=list)
    canonical_ingredients: list[str] = Field(default_factory=list)
    ingredient_matches: list[dict[str, Any]] = Field(default_factory=list)
    unmatched_ingredients: list[str] = Field(default_factory=list)
    derived_allergens: list[dict[str, Any]] = Field(default_factory=list)
    derived_health_flags: list[dict[str, Any]] = Field(default_factory=list)
    allergens: list[str] = Field(default_factory=list)
    nutrition: dict[str, float] = Field(default_factory=dict)
    evidence: list[EvidenceItem] = Field(default_factory=list)
    conflicts: list[Conflict] = Field(default_factory=list)
    missing_data: list[str] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)
    dedup_match: Optional[dict[str, Any]] = None
    status: str = "UNRESOLVED"
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    source_summary: dict[str, Any] = Field(default_factory=dict)

    def evidence_for(self, fact: str) -> list[EvidenceItem]:
        return [e for e in self.evidence if e.fact == fact]

    def facts(self) -> set[str]:
        return {e.fact for e in self.evidence}


class ReviewTask(BaseModel):
    """A human-review task produced when the agent cannot prove data."""

    product_key: str
    key_type: str = KEY_BARCODE
    problem: str  # NEEDS_REVIEW | CONFLICT | UNRESOLVED | FAILED
    reason: Optional[str] = None
    sources_checked: list[str] = Field(default_factory=list)
    conflicting_sources: list[str] = Field(default_factory=list)
    missing_data: list[str] = Field(default_factory=list)
    suggested_action: Optional[str] = None


class ProductOutcome(BaseModel):
    """Result of processing one product through the pipeline."""

    product_key: str
    key_type: str = KEY_BARCODE
    status: str = "UNRESOLVED"
    confidence: float = 0.0
    candidate: Optional[CandidateProduct] = None
    review_task: Optional[ReviewTask] = None
    error: Optional[str] = None
    processed_at: datetime = Field(default_factory=utcnow)


class BatchSummary(BaseModel):
    """Aggregated outcome of a batch run."""

    batch_label: str
    total: int = 0
    verified: int = 0
    needs_review: int = 0
    conflict: int = 0
    unresolved: int = 0
    failed: int = 0
    started_at: datetime = Field(default_factory=utcnow)
    finished_at: Optional[datetime] = None
    details: list[dict[str, Any]] = Field(default_factory=list)
