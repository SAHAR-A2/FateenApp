"""Core data structures for the SFDA batch pipeline (auth-independent).

Follows the dataclass + Enum conventions of app/agent/models.py and
app/collector/models.py.
"""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional


def utcnow() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class CandidateStatus(str, Enum):
    PENDING = "pending"
    FETCHING = "fetching"
    NORMALIZED = "normalized"
    RESOLVED = "resolved"
    VALIDATED = "validated"
    INSERTED = "inserted"          # trusted path: written (or dry-run, no-op diff)
    QUARANTINED = "quarantined"    # failed validation / unresolved ingredients
    FAILED = "failed"              # transport/pipeline error (retry exhausted)
    SKIPPED = "skipped"            # already processed in a previous checkpoint


class CandidateMode(str, Enum):
    BARCODE = "barcode"
    REFERENCE = "referencenumber"
    SEARCH = "search"
    LIST = "list"
    FIRS_LIST = "firs_list"
    FIRS_SEARCH = "firs_search"


class QuarantineStatus(str, Enum):
    QUARANTINED = "quarantined"
    RETRIED = "retried"
    RESOLVED = "resolved"
    DISCARDED = "discarded"


class RejectionReason(str, Enum):
    """Deterministic rejection reasons (never fabricated data)."""

    INVALID_BARCODE = "invalid_barcode"
    NO_RECORD = "no_record"
    FETCH_FAILED = "fetch_failed"
    NORMALIZATION_FAILED = "normalization_failed"
    UNRESOLVED_INGREDIENTS = "unresolved_ingredients"
    VALIDATION_FAILED = "validation_failed"
    AMBIGUOUS_MULTIPLE_RECORDS = "ambiguous_multiple_records"
    EMPTY_RECORD = "empty_record"


@dataclass
class Candidate:
    """One unit of work: how a product is discovered and what happened to it."""

    candidate_id: str
    mode: CandidateMode
    identifier: str                      # barcode / reference / keyword / page
    source: str = "SFDA"
    status: CandidateStatus = CandidateStatus.PENDING
    barcode: Optional[str] = None
    reference_number: Optional[str] = None
    trade_name: Optional[str] = None
    brand: Optional[str] = None
    company: Optional[str] = None
    item_description: Optional[str] = None
    ingredients_ar: Optional[str] = None
    ingredients_en: Optional[str] = None
    warnings_ar: Optional[str] = None
    unresolved_ingredients: list = field(default_factory=list)
    resolved_names: list = field(default_factory=list)     # canonical names
    rejection_reasons: list = field(default_factory=list)
    validation_errors: list = field(default_factory=list)
    payload: Optional[dict] = None        # raw SFDA payload (evidence), never edited
    attempts: int = 0
    created_at: str = field(default_factory=utcnow)
    updated_at: str = field(default_factory=utcnow)
    processed_at: Optional[str] = None
    raw_payload: Optional[dict] = None


@dataclass
class QuarantineRecord:
    """Minimal quarantine row (per spec: identifier, reason, unresolved
    ingredients, source, timestamp, processing status)."""

    candidate_id: str
    identifier: str
    reasons: list
    unresolved_ingredients: list
    source: str = "SFDA"
    timestamp: str = field(default_factory=utcnow)
    processing_status: str = QuarantineStatus.QUARANTINED.value
    payload: Optional[dict] = None


@dataclass
class BatchRun:
    """Serializable checkpoint state for one scaled batch run."""

    run_id: str
    mode: str                              # dry-run | live
    batch_size: int
    total: int = 0
    position: int = 0
    processed: int = 0
    inserted: int = 0
    quarantined: int = 0
    failed: int = 0
    skipped: int = 0
    started_at: str = field(default_factory=utcnow)
    updated_at: str = field(default_factory=utcnow)
    source: str = "SFDA"
    candidates: dict = field(default_factory=dict)   # candidate_id -> dict
    quarantine: list = field(default_factory=list)   # list[QuarantineRecord]
    notes: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "run_id": self.run_id,
            "mode": self.mode,
            "batch_size": self.batch_size,
            "total": self.total,
            "position": self.position,
            "processed": self.processed,
            "inserted": self.inserted,
            "quarantined": self.quarantined,
            "failed": self.failed,
            "skipped": self.skipped,
            "started_at": self.started_at,
            "updated_at": self.updated_at,
            "source": self.source,
            "candidates": self.candidates,
            "quarantine": self.quarantine,
            "notes": self.notes,
        }

    @classmethod
    def from_dict(cls, payload: dict) -> "BatchRun":
        fields = {k: payload.get(k) for k in cls.__dataclass_fields__}
        fields["candidates"] = payload.get("candidates") or {}
        fields["quarantine"] = payload.get("quarantine") or []
        fields["notes"] = payload.get("notes") or []
        return cls(**fields)