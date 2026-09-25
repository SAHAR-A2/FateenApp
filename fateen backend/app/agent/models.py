from dataclasses import dataclass, field
from typing import Optional


@dataclass
class IngestionIngredient:
    name: str
    amount_value: Optional[float] = None
    unit: Optional[str] = None
    order: Optional[int] = None
    confidence_level: Optional[float] = None


@dataclass
class IngestionAllergen:
    name: str
    confidence_level: Optional[float] = None


@dataclass
class IngestionNutrition:
    nutrition_type: str
    amount_value: float
    unit: str
    measurement_basis: Optional[str] = None
    confidence_level: Optional[float] = None


@dataclass
class IngestionInput:
    barcode: str
    product_name: Optional[str] = None
    product_description: Optional[str] = None
    internal_code: Optional[str] = None
    ingredients: list = field(default_factory=list)
    allergens: list = field(default_factory=list)
    nutrition: list = field(default_factory=list)
    source: str = "manual"
    evidence_type: str = "inferred"
    confidence_level: float = 0.5
    # Traceability, populated by callers that actually know where the data
    # came from (e.g. app.collector.orchestrator._ingest_product passes
    # CollectedProductData.source_url here). Both optional and unused by
    # older callers -- purely additive, no behavior changes for anyone who
    # doesn't set them.
    source_url: Optional[str] = None
    retrieved_at: Optional[str] = None


@dataclass
class ProposedChange:
    action: str
    entity: str
    entity_id: Optional[str] = None
    details: dict = field(default_factory=dict)


@dataclass
class IngestionResult:
    dry_run: bool
    barcode: str
    product_internal_code: Optional[str] = None
    product_id: Optional[str] = None
    changes: list = field(default_factory=list)
    warnings: list = field(default_factory=list)
    errors: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "dry_run": self.dry_run,
            "barcode": self.barcode,
            "product_internal_code": self.product_internal_code,
            "changes": [
                {
                    "action": c.action,
                    "entity": c.entity,
                    "entity_id": c.entity_id,
                    "details": c.details,
                }
                for c in self.changes
            ],
            "warnings": self.warnings,
            "errors": self.errors,
        }
