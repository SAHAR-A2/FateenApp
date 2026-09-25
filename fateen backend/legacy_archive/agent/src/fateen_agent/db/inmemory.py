"""In-memory repository for offline / dry-run executions.

Implements the same interface as FateenRepository but persists to plain
dicts in memory and performs NO database writes of any kind. Used by the
offline MVP (fixture runs) so production data is never touched and the run
works even with no database available. Results can be inspected from the
report / review queue after the run.

Can be seeded with a synthetic canonical vocabulary (see
``load_vocabulary``) so the matching/allergen/health-flag derivation can be
exercised offline — the seed data is synthetic and never treated as truth.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any, Optional

from ..models import (
    BatchSummary,
    CandidateProduct,
    EvidenceItem,
    ProductOutcome,
    ReviewTask,
    SourceInfo,
)
from ..normalization.text import normalize_text

logger = logging.getLogger(__name__)


def default_vocabulary_path() -> Path:
    """Path to the bundled synthetic vocabulary fixture."""
    # <repo>/src/fateen_agent/db/inmemory.py -> <repo>
    return Path(__file__).resolve().parents[3] / "tests" / "fixtures" / "vocabulary.json"


def load_vocabulary(path: str | Path) -> dict[str, Any]:
    """Load a synthetic vocabulary fixture into repository-ready structures.

    Returns the seed dict understood by ``InMemoryRepository(seed=...)``.
    The JSON mirrors the public schema: ingredients, aliases, allergens,
    ingredient_allergens, health_flags, ingredient_health_flags. allergen /
    health-flag rows are joined to ingredient ids at load time.
    """
    path = Path(path)
    if not path.exists():
        return {}
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)

    allergens = {a["id"]: a for a in data.get("allergens", []) or []}
    flags = {f["id"]: f for f in data.get("health_flags", []) or []}

    ingredient_allergens = []
    for ia in data.get("ingredient_allergens", []) or []:
        a = allergens.get(ia.get("allergen_id"))
        if not a:
            continue
        ingredient_allergens.append(
            {
                "ingredient_id": ia.get("ingredient_id"),
                "allergen_id": a["id"],
                "internal_code": a.get("internal_code"),
                "name": a.get("name"),
            }
        )

    ingredient_health_flags = []
    for ih in data.get("ingredient_health_flags", []) or []:
        f = flags.get(ih.get("health_flag_id"))
        if not f:
            continue
        ingredient_health_flags.append(
            {
                "ingredient_id": ih.get("ingredient_id"),
                "health_flag_id": f["id"],
                "internal_code": f.get("internal_code"),
                "name": f.get("name"),
            }
        )

    canonical: dict[str, dict[str, Any]] = {}
    for ing in data.get("ingredients", []) or []:
        canonical[normalize_text(ing.get("name") or "")] = {
            "id": ing.get("id"),
            "name": ing.get("name"),
            "internal_code": ing.get("internal_code"),
        }

    return {
        "canonical_ingredients": canonical,
        "aliases": data.get("aliases", []) or [],
        "allergens": list(allergens.values()),
        "ingredient_allergens": ingredient_allergens,
        "health_flags": list(flags.values()),
        "ingredient_health_flags": ingredient_health_flags,
    }


class InMemoryRepository:
    """Zero-persistence repository. Never writes to the database."""

    def __init__(self, seed: Optional[dict[str, Any]] = None) -> None:
        self.promoted: list[CandidateProduct] = []
        self.candidates: dict[tuple[str, str], CandidateProduct] = {}
        self.evidence: list[EvidenceItem] = []
        self.review_tasks: list[ReviewTask] = []
        self.processing: dict[tuple[str, str], dict[str, Any]] = {}
        self.staged: list[dict[str, Any]] = []
        self.batch_items: list[dict[str, Any]] = []
        self.batch_count = 0
        self._candidate_counter = 0
        seed = seed or {}
        self._seed = seed

    # ------------------------------------------------------------------ setup

    def ping(self) -> bool:
        return True

    # -------------------------------------------------------- read (offline) -

    def load_canonical_ingredients(self) -> dict[str, dict[str, Any]]:
        return self._seed.get("canonical_ingredients", {})

    def load_ingredient_aliases(self) -> list[dict[str, Any]]:
        return self._seed.get("aliases", [])

    def load_canonical_allergens(self) -> list[dict[str, Any]]:
        return self._seed.get("allergens", [])

    def load_ingredient_allergens(self) -> list[dict[str, Any]]:
        return self._seed.get("ingredient_allergens", [])

    def load_ingredient_health_flags(self) -> list[dict[str, Any]]:
        return self._seed.get("ingredient_health_flags", [])

    def load_products_for_dedup(self) -> list[dict[str, Any]]:
        return []

    def load_barcode_index(self) -> dict[str, dict[str, Any]]:
        return {}

    def load_public_product_ids(self) -> set[str]:
        return set()

    # -------------------------------------------------------- write (memory) -

    def enqueue(self, product_key: str, key_type: str, context: Optional[dict] = None) -> None:
        pass

    def is_processed(self, product_key: str, key_type: str) -> bool:
        return False

    def record_processing(self, outcome: ProductOutcome, error: Optional[str] = None) -> None:
        self.processing[(outcome.product_key, outcome.key_type)] = {
            "last_status": outcome.status,
            "last_error": error,
        }

    def stage_finding(
        self,
        batch_id: Optional[str],
        product_key: str,
        key_type: str,
        source: SourceInfo,
        raw: dict[str, Any],
    ) -> None:
        self.staged.append(
            {
                "batch_id": batch_id,
                "product_key": product_key,
                "key_type": key_type,
                "source_name": source.name,
                "source_type": source.source_type,
                "source_priority": source.priority,
            }
        )

    def save_candidate(self, candidate: CandidateProduct) -> str:
        self._candidate_counter += 1
        candidate_id = f"cand-{self._candidate_counter}"
        self.candidates[(candidate.product_key, candidate.key_type)] = candidate
        return candidate_id

    def save_evidence(
        self, candidate_id: str, product_key: str, key_type: str, item: EvidenceItem
    ) -> None:
        self.evidence.append(item)

    def save_review_task(self, task: ReviewTask) -> None:
        self.review_tasks.append(task)

    # ------------------------------------------------------------------ batch

    def start_batch(self, batch_label: str) -> str:
        self.batch_count += 1
        return f"batch-{self.batch_count}"

    def record_batch_item(
        self, batch_id: Optional[str], outcome: ProductOutcome, detail: Optional[str] = None
    ) -> None:
        self.batch_items.append(
            {
                "batch_id": batch_id,
                "product_key": outcome.product_key,
                "status": outcome.status,
                "confidence": outcome.confidence,
                "detail": detail,
            }
        )

    def finish_batch(self, batch_id: str, summary: BatchSummary) -> None:
        pass

    # ------------------------------------------------------------- promotion

    def promote_candidate(self, candidate: CandidateProduct) -> str:
        raise RuntimeError(
            "promote_candidate is forbidden in offline/dry-run mode (no production writes)."
        )
