"""The agent orchestrator: search -> extract -> merge -> validate -> record.

This is the "one product" execution path. It is called by the batch processor
for every queued product. All writes go through FateenRepository (agent schema
only in dry-run mode). Never guesses.
"""

from __future__ import annotations

import logging
from typing import Any, Optional

from ..confidence import compute_confidence
from ..constants import (
    CONFLICT_RESOLUTION_AGREEMENT,
    KEY_BARCODE,
    PRIORITY_RANK,
    PROBLEM_TECHNICAL,
    SOURCE_TYPE_RELIABILITY,
    VERIFIED,
)
from ..db.repository import FateenRepository
from ..extraction.parser import ExtractedFacts, extract_facts
from ..matching.matcher import best_ingredient_match, find_existing_product
from ..models import CandidateProduct, Conflict, EvidenceItem, ProductOutcome, SourceInfo
from ..normalization.barcode import normalize_barcode
from ..normalization.text import normalize_text
from ..review import build_review_task
from ..sources import DataSource
from ..sources.base import ProductQuery
from ..validation import VerificationPolicy
from ..validation.engine import VerificationResult
from .staging import stage_all

logger = logging.getLogger(__name__)


class Orchestrator:
    def __init__(
        self,
        repository: FateenRepository,
        sources: list[DataSource],
        policy: Optional[VerificationPolicy] = None,
        batch_id: Optional[str] = None,
        promote_verified: bool = False,
    ):
        self.repo = repository
        self.sources = sources
        self.policy = policy or VerificationPolicy()
        self.batch_id = batch_id
        self.promote_verified = promote_verified

    # ------------------------------------------------------------------ main

    def process(self, query: ProductQuery, product_key: str, key_type: str) -> ProductOutcome:
        try:
            return self._process_inner(query, product_key, key_type)
        except Exception as exc:  # noqa: BLE001 — per-product isolation
            logger.exception("Product %s failed: %s", product_key, exc)
            outcome = ProductOutcome(
                product_key=product_key,
                key_type=key_type,
                status="FAILED",
                error=str(exc),
            )
            self._persist_failure(outcome)
            return outcome

    # ------------------------------------------------------------------ inner

    def _process_inner(self, query: ProductQuery, product_key: str, key_type: str) -> ProductOutcome:
        # 1. Search every enabled source.
        raw_records = self._collect(query)
        if not raw_records:
            outcome = ProductOutcome(
                product_key=product_key,
                key_type=key_type,
                status="UNRESOLVED",
                error=None,
            )
            self._persist_failure(outcome, problem="unresolved")
            return outcome

        # 2. Stage raw payloads (full audit trail of what each source returned).
        stage_all(self.repo, self.batch_id, product_key, key_type, raw_records)

        # 3. Extract evidence-backed facts per source.
        extracted = [extract_facts(r) for r in raw_records]

        # 4. Merge into one normalized candidate.
        candidate = self._merge(product_key, key_type, extracted)

        # 4b. Matching + deduplication against canonical vocabularies (if any).
        self._canonicalize(candidate)

        # 5. Detect + try to resolve conflicts.
        candidate.conflicts = self._detect_conflicts(extracted)
        self._resolve_conflicts(candidate)

        # 6. Confidence (deterministic, weighted).
        candidate.confidence = compute_confidence(candidate)

        # 7. Verification policy decides the status.
        result = self.policy.verify(candidate)

        # Barcode mismatch: sources pointed at a different product — never verify.
        if (
            key_type == KEY_BARCODE
            and candidate.barcode
            and self._barcode_mismatch(candidate.barcode, product_key)
        ):
            candidate.notes.append(
                f"Barcode mismatch: sources report barcode {candidate.barcode}, "
                f"but the query was for {product_key}."
            )
            if result.status == VERIFIED:
                result = VerificationResult(
                    status="NEEDS_REVIEW",
                    confidence=candidate.confidence,
                    missing_data=candidate.missing_data,
                    reason="; ".join(candidate.notes),
                )
        candidate.status = result.status
        candidate.missing_data = result.missing_data

        # 8. Persist candidate + evidence.
        candidate_id = self.repo.save_candidate(candidate)
        for item in candidate.evidence:
            self.repo.save_evidence(candidate_id, product_key, key_type, item)

        # 9. Review task if not verified.
        review_task = None
        if result.status != VERIFIED:
            review_task = build_review_task(candidate)
            self.repo.save_review_task(review_task)

        # 10. Optional explicit promotion (never in dry-run; opt-in only).
        if self.promote_verified and result.status == VERIFIED:
            self.repo.promote_candidate(candidate)

        outcome = ProductOutcome(
            product_key=product_key,
            key_type=key_type,
            status=result.status,
            confidence=candidate.confidence,
            candidate=candidate,
            review_task=review_task,
        )
        self.repo.record_processing(outcome)
        return outcome

    # ------------------------------------------------------------- internals

    def _canonicalize(self, candidate: CandidateProduct) -> None:
        """Matching + deduplication against canonical vocabularies.

        1. Maps each raw ingredient token to its canonical ingredient (exact
           alias -> exact name -> high-similarity). Unmatched tokens are kept
           for human review — never silently dropped.
        2. Derives canonical allergens and health flags (sugar / salt /
           chronic-disease markers) from the matched canonical ingredients.
        3. Flags candidates that already exist canonically (barcode/name).

        Offline (empty vocabularies) this is a transparent no-op that never
        invents data: tokens simply stay unmatched and nothing is derived.
        """
        try:
            canonical = self.repo.load_canonical_ingredients() or {}
            rows = [c for c in canonical.values() if c.get("name")]
            names = [c["name"] for c in rows]
            index_by_id = {str(c["id"]): i for i, c in enumerate(rows) if c.get("id")}

            alias_map: dict[str, list[int]] = {}
            for alias in self.repo.load_ingredient_aliases() or []:
                idx = index_by_id.get(str(alias.get("ingredient_id")))
                if idx is not None:
                    alias_map.setdefault(alias.get("alias") or "", []).append(idx)

            allergen_by_ingredient: dict[Any, list[dict]] = {}
            for ia in self.repo.load_ingredient_allergens() or []:
                allergen_by_ingredient.setdefault(ia.get("ingredient_id"), []).append(
                    {"code": ia.get("internal_code"), "name": ia.get("name")}
                )
            flag_by_ingredient: dict[Any, list[dict]] = {}
            for ih in self.repo.load_ingredient_health_flags() or []:
                flag_by_ingredient.setdefault(ih.get("ingredient_id"), []).append(
                    {"code": ih.get("internal_code"), "name": ih.get("name")}
                )

            matches: list[dict] = []
            unmatched: list[str] = []
            canonical_ingredients: list[str] = []
            derived_allergens: list[dict] = []
            derived_flags: list[dict] = []
            seen_allergen: set[str] = set()
            seen_flag: set[str] = set()

            for tok in candidate.ingredients:
                m = best_ingredient_match(tok, names, alias_map)
                if not m:
                    unmatched.append(tok)
                    canonical_ingredients.append(tok)
                    continue
                row = rows[m.index]
                canonical_ingredients.append(m.value)
                matches.append(
                    {
                        "token": tok,
                        "canonical_id": row.get("id"),
                        "canonical_name": m.value,
                        "method": m.method,
                        "score": round(m.score, 3),
                    }
                )
                for al in allergen_by_ingredient.get(row.get("id"), []):
                    if al.get("code") and al["code"] not in seen_allergen:
                        seen_allergen.add(al["code"])
                        derived_allergens.append(al)
                for flag in flag_by_ingredient.get(row.get("id"), []):
                    if flag.get("code") and flag["code"] not in seen_flag:
                        seen_flag.add(flag["code"])
                        derived_flags.append(flag)

            candidate.canonical_ingredients = canonical_ingredients
            candidate.ingredient_matches = matches
            candidate.unmatched_ingredients = unmatched
            candidate.derived_allergens = derived_allergens
            candidate.derived_health_flags = derived_flags

            existing = find_existing_product(
                barcode=candidate.barcode,
                name=candidate.name,
                brand=candidate.brand,
                known_products=self.repo.load_products_for_dedup() or [],
                barcode_index=self.repo.load_barcode_index() or {},
            )
            if existing:
                candidate.dedup_match = {
                    "product_id": str(existing.get("product_id") or existing.get("id")),
                    "name": existing.get("name"),
                    "brand": existing.get("brand"),
                }
        except Exception:  # noqa: BLE001 — matching must never block verification
            logger.warning("Canonicalization skipped for %s", candidate.product_key, exc_info=True)

    @staticmethod
    def _barcode_mismatch(candidate_barcode: str, product_key: str) -> bool:
        return normalize_barcode(candidate_barcode) != normalize_barcode(product_key)

    def _collect(self, query: ProductQuery) -> list:
        records = []
        for source in self.sources:
            try:
                records.extend(source.search(query))
            except Exception as exc:  # noqa: BLE001 — one source must not kill the run
                logger.warning("Source %s failed for %s: %s", source.name, query.describe(), exc)
        return records

    def _merge(self, product_key: str, key_type: str, extracted: list[ExtractedFacts]) -> CandidateProduct:
        candidate = CandidateProduct(product_key=product_key, key_type=key_type)

        # Union of evidence.
        for ef in extracted:
            candidate.evidence.extend(ef.evidence)

        # Value selection: highest-priority evidence wins for scalar facts.
        candidate.name = _best_value(extracted, "name")
        candidate.brand = _best_value(extracted, "brand")
        candidate.company = _best_value(extracted, "company")
        candidate.barcode = _best_value(extracted, "barcode")
        candidate.package_size = _best_value(extracted, "package_size")

        # Ingredients: best verbatim list + union of parsed tokens.
        best_ingredients = _best_facts_with(extracted, "ingredient")
        if best_ingredients and best_ingredients.ingredients_raw:
            candidate.ingredients_raw = best_ingredients.ingredients_raw
        elif best_ingredients and best_ingredients.ingredients:
            candidate.ingredients_raw = "; ".join(best_ingredients.ingredients)
        for ef in extracted:
            for tok in ef.ingredients:
                if tok not in candidate.ingredients:
                    candidate.ingredients.append(tok)

        # Allergens + nutrition union.
        for ef in extracted:
            for a in ef.allergens:
                if a not in candidate.allergens:
                    candidate.allergens.append(a)
            for k, v in ef.nutrition.items():
                candidate.nutrition.setdefault(k, v)

        candidate.source_summary = {
            "sources": sorted({e.source.name for e in candidate.evidence}),
            "ingredient_sources": sorted(
                {e.source.name for e in candidate.evidence if e.fact == "ingredient"}
            ),
        }
        return candidate

    def _detect_conflicts(self, extracted: list[ExtractedFacts]) -> list[Conflict]:
        conflicts: list[Conflict] = []

        # Scalar facts: disagreeing values from meaningful sources.
        for fact in ("name", "barcode", "brand", "company", "package_size"):
            grouped: dict[str, list] = {}
            for ef in extracted:
                value = getattr(ef, fact, None)
                if not value:
                    continue
                key = _norm_key(fact, value)
                if key not in grouped:
                    grouped[key] = {"value": value, "sources": []}
                grouped[key]["sources"].append(ef.evidence[0].source if ef.evidence else None)

            candidates = [(k, g) for k, g in grouped.items() if self._meaningful(g["sources"])]
            if len(candidates) > 1:
                for k, g in candidates:
                    pass  # keep first meaningful value as reference
                first = candidates[0]
                for k, g in candidates[1:]:
                    conflicts.append(
                        Conflict(
                            fact=fact,
                            source_a=first[1]["sources"][0].name if first[1]["sources"] else "?",
                            value_a=first[1]["value"],
                            source_b=g["sources"][0].name if g["sources"] else "?",
                            value_b=g["value"],
                        )
                    )

        # Ingredient sets: material disagreement between meaningful sources.
        sets: dict[str, list] = {}
        for ef in extracted:
            if not ef.ingredients:
                continue
            key = ",".join(sorted(ef.ingredients))
            sets.setdefault(key, []).append(ef)
        if len(sets) > 1:
            keys = list(sets.keys())
            conflicts.append(
                Conflict(
                    fact="ingredients",
                    source_a=sets[keys[0]][0].evidence[0].source.name,
                    value_a=f"{len(sets[keys[0]][0].ingredients)} ingredients",
                    source_b=sets[keys[1]][0].evidence[0].source.name,
                    value_b=f"{len(sets[keys[1]][0].ingredients)} ingredients",
                )
            )

        # Allergen sets: disagreement between meaningful sources. Never
        # auto-resolved — an allergen disagreement stays CONFLICT for review.
        allergen_sets: dict[str, list] = {}
        for ef in extracted:
            if not ef.allergens:
                continue
            key = ",".join(sorted(ef.allergens))
            allergen_sets.setdefault(key, []).append(ef)
        if len(allergen_sets) > 1:
            keys = list(allergen_sets.keys())
            conflicts.append(
                Conflict(
                    fact="allergens",
                    source_a=allergen_sets[keys[0]][0].evidence[0].source.name,
                    value_a=", ".join(sorted(allergen_sets[keys[0]][0].allergens)),
                    source_b=allergen_sets[keys[1]][0].evidence[0].source.name,
                    value_b=", ".join(sorted(allergen_sets[keys[1]][0].allergens)),
                )
            )
        return conflicts

    def _resolve_conflicts(self, candidate: CandidateProduct) -> None:
        for conflict in candidate.conflicts:
            ev = [e for e in candidate.evidence if e.fact == conflict.fact]
            if not ev:
                continue
            # Group evidence by value, tracking weight + distinct sources.
            by_value: dict[str, dict] = {}
            for e in ev:
                v = e.value or ""
                g = by_value.setdefault(v, {"weight": 0.0, "sources": set(), "priority": 0})
                g["weight"] += (
                    PRIORITY_RANK.get(e.source.priority, 10)
                    * SOURCE_TYPE_RELIABILITY.get(e.source.source_type, 0.2)
                )
                g["sources"].add(e.source.name)
                g["priority"] = max(g["priority"], PRIORITY_RANK.get(e.source.priority, 10))
            total = sum(g["weight"] for g in by_value.values()) or 1.0
            best_value, best = max(by_value.items(), key=lambda kv: kv[1]["weight"])
            best_fraction = best["weight"] / total
            low_trust_rivals = all(
                g["priority"] < 50 for v, g in by_value.items() if v != best_value
            )
            # Resolve only on genuine agreement:
            #  - a value backed by >=2 distinct sources AND holding >=50% weight, or
            #  - the winner is PRIMARY/high-trust while all rivals are below SECONDARY.
            resolved = (
                len(best["sources"]) >= 2 and best_fraction >= CONFLICT_RESOLUTION_AGREEMENT
            ) or (best_fraction >= 0.6 and low_trust_rivals)
            if resolved:
                conflict.resolved = True
                conflict.resolution = f"Agreement by weighted source majority: {best_value!r}"

    @staticmethod
    def _meaningful(sources: list) -> bool:
        meaningful = [s for s in sources if s and PRIORITY_RANK.get(s.priority, 0) >= 50]
        return len(meaningful) >= 1

    # ------------------------------------------------------------- failure

    def _persist_failure(self, outcome: ProductOutcome, problem: Optional[str] = None) -> None:
        try:
            self.repo.record_processing(outcome, error=outcome.error)
            if problem == "unresolved":
                task = build_review_task(None)
                task.product_key = outcome.product_key
                task.key_type = outcome.key_type
                self.repo.save_review_task(task)
            elif outcome.status == "FAILED":
                task = build_review_task(None, error=outcome.error)
                task.product_key = outcome.product_key
                task.key_type = outcome.key_type
                task.problem = PROBLEM_TECHNICAL
                self.repo.save_review_task(task)
        except Exception:  # noqa: BLE001
            logger.exception("Could not persist failure for %s", outcome.product_key)


# ---------------------------------------------------------------------------
# value-selection helpers
# ---------------------------------------------------------------------------


def _best_evidence(extracted: list[ExtractedFacts], fact: str) -> Optional[EvidenceItem]:
    best: Optional[EvidenceItem] = None
    for ef in extracted:
        for item in ef.evidence:
            if item.fact != fact:
                continue
            if best is None or _evidence_key(item) > _evidence_key(best):
                best = item
    return best


def _best_facts_with(extracted: list[ExtractedFacts], fact: str) -> Optional[ExtractedFacts]:
    """Return the ExtractedFacts block whose evidence for `fact` is strongest."""
    best_ef: Optional[ExtractedFacts] = None
    best_item: Optional[EvidenceItem] = None
    for ef in extracted:
        for item in ef.evidence:
            if item.fact != fact:
                continue
            if best_item is None or _evidence_key(item) > _evidence_key(best_item):
                best_item = item
                best_ef = ef
    return best_ef


def _evidence_key(item: EvidenceItem) -> tuple[float, float]:
    return (
        PRIORITY_RANK.get(item.source.priority, 10),
        SOURCE_TYPE_RELIABILITY.get(item.source.source_type, 0.2),
    )


def _best_value(extracted: list[ExtractedFacts], fact: str) -> Optional[str]:
    item = _best_evidence(extracted, fact)
    return item.value if item else None


def _norm_key(fact: str, value: str) -> str:
    from ..normalization.text import normalize_text

    return normalize_text(value) if value else ""
