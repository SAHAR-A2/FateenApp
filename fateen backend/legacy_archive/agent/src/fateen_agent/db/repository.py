"""Fateen repository.

Reads canonical vocabulary from `public` (read-only) and writes agent results
to the `agent` schema ONLY. In DRY_RUN mode nothing is ever written to
`public`. Promotion of VERIFIED candidates into `public` is an explicit,
separate, human-gated step (see docs/scaling.md).

All agent writes are idempotent (ON CONFLICT ... DO UPDATE) so re-runs never
create duplicates.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Any, Optional

import psycopg
from psycopg import Connection

from ..config import Settings
from ..models import (
    BatchSummary,
    CandidateProduct,
    EvidenceItem,
    ProductOutcome,
    ReviewTask,
    SourceInfo,
)
from .connection import connect

logger = logging.getLogger(__name__)


class FateenRepository:
    """All DB access for the agent. Never touches public writes unless promote."""

    def __init__(self, settings: Settings, conn: Optional[Connection] = None):
        self.settings = settings
        self._conn = conn  # optional injected connection (tests)

    # ------------------------------------------------------------------ setup

    def _get_conn(self) -> Connection:
        if self._conn is not None:
            return self._conn
        return connect(self.settings)

    def ping(self) -> bool:
        conn = self._get_conn()
        try:
            conn.execute("SELECT 1")
            return True
        except psycopg.Error:
            return False

    # ------------------------------------------------------- read (public) ---

    def load_canonical_ingredients(self) -> dict[str, dict[str, Any]]:
        """Return {normalized_name: {id, name, code}} from public.ingredients."""
        conn = self._get_conn()
        rows = conn.execute(
            """
            SELECT i.id, i.name, i.internal_code
            FROM public.ingredients i
            WHERE i.deleted_at IS NULL
            """,
        ).fetchall()
        from ..normalization.text import normalize_text

        return {normalize_text(r["name"]): r for r in rows}

    def load_ingredient_aliases(self) -> list[dict[str, Any]]:
        conn = self._get_conn()
        return conn.execute(
            """
            SELECT ia.ingredient_id, ia.alias
            FROM public.ingredient_aliases ia
            WHERE ia.deleted_at IS NULL
            """,
        ).fetchall()

    def load_canonical_allergens(self) -> list[dict[str, Any]]:
        conn = self._get_conn()
        return conn.execute(
            """
            SELECT a.id, a.name, a.internal_code, at.code AS allergen_type_code
            FROM public.allergens a
            LEFT JOIN public.allergen_types at ON at.id = a.allergen_type_id
            WHERE a.deleted_at IS NULL
            """,
        ).fetchall()

    def load_ingredient_allergens(self) -> list[dict[str, Any]]:
        """ingredient_id -> canonical allergen(s) via public.ingredient_allergens."""
        conn = self._get_conn()
        return conn.execute(
            """
            SELECT ia.ingredient_id, a.id AS allergen_id,
                   a.internal_code, a.name
            FROM public.ingredient_allergens ia
            JOIN public.allergens a ON a.id = ia.allergen_id
            WHERE ia.deleted_at IS NULL AND a.deleted_at IS NULL
            """,
        ).fetchall()

    def load_ingredient_health_flags(self) -> list[dict[str, Any]]:
        """ingredient_id -> canonical health flags (sugar/salt/chronic disease markers)."""
        conn = self._get_conn()
        return conn.execute(
            """
            SELECT ihf.ingredient_id, hf.id AS health_flag_id,
                   hf.internal_code, hf.name
            FROM public.ingredient_health_flags ihf
            JOIN public.health_flags hf ON hf.id = ihf.health_flag_id
            WHERE ihf.deleted_at IS NULL AND hf.deleted_at IS NULL
            """,
        ).fetchall()

    def load_products_for_dedup(self) -> list[dict[str, Any]]:
        """Products with brand/company context for dedup matching."""
        conn = self._get_conn()
        return conn.execute(
            """
            SELECT p.id, p.name, p.internal_code,
                   b.name AS brand, c.name AS company
            FROM public.products p
            LEFT JOIN public.brands b ON b.id = p.brand_id
            LEFT JOIN public.companies c ON c.id = b.company_id
            WHERE p.deleted_at IS NULL
            """,
        ).fetchall()

    def load_barcode_index(self) -> dict[str, dict[str, Any]]:
        """{barcode: {product_id, barcode}} for exact-barcode dedup."""
        conn = self._get_conn()
        rows = conn.execute(
            """
            SELECT b.barcode, pb.product_id
            FROM public.product_barcodes pb
            JOIN public.barcodes b ON b.id = pb.barcode_id
            WHERE pb.deleted_at IS NULL
            """,
        ).fetchall()
        return {r["barcode"]: r for r in rows}

    def load_public_product_ids(self) -> set[str]:
        conn = self._get_conn()
        rows = conn.execute("SELECT id FROM public.products").fetchall()
        return {str(r["id"]) for r in rows}

    # ------------------------------------------------------ write (agent) ----

    def enqueue(self, product_key: str, key_type: str, context: Optional[dict] = None) -> None:
        conn = self._get_conn()
        with conn.transaction():
            conn.execute(
                """
                INSERT INTO agent.product_queue (product_key, key_type, context_json)
                VALUES (%s, %s, %s)
                ON CONFLICT (product_key, key_type) DO UPDATE
                SET status = 'queued',
                    started_at = NULL,
                    finished_at = NULL
                """,
                (product_key, key_type, json.dumps(context or {}, ensure_ascii=False)),
            )

    def is_processed(self, product_key: str, key_type: str) -> bool:
        conn = self._get_conn()
        row = conn.execute(
            "SELECT 1 FROM agent.processing_state WHERE product_key=%s AND key_type=%s",
            (product_key, key_type),
        ).fetchone()
        return row is not None

    def record_processing(self, outcome: ProductOutcome, error: Optional[str] = None) -> None:
        conn = self._get_conn()
        with conn.transaction():
            conn.execute(
                """
                INSERT INTO agent.processing_state (product_key, key_type, last_status, attempts, last_error)
                VALUES (%s, %s, %s, 1, %s)
                ON CONFLICT (product_key, key_type) DO UPDATE
                SET last_status = EXCLUDED.last_status,
                    attempts = agent.processing_state.attempts + 1,
                    last_error = EXCLUDED.last_error,
                    processed_at = now()
                """,
                (outcome.product_key, outcome.key_type, outcome.status, error),
            )

    def stage_finding(
        self,
        batch_id: Optional[str],
        product_key: str,
        key_type: str,
        source: SourceInfo,
        raw: dict[str, Any],
    ) -> None:
        conn = self._get_conn()
        with conn.transaction():
            conn.execute(
                """
                INSERT INTO agent.staged_findings
                    (batch_id, product_key, key_type, source_name, source_url, source_type,
                     source_priority, retrieved_at, raw_json)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (product_key, source_name, retrieved_at) DO UPDATE
                SET raw_json = EXCLUDED.raw_json
                """,
                (
                    batch_id,
                    product_key,
                    key_type,
                    source.name,
                    source.url,
                    source.source_type,
                    source.priority,
                    source.retrieved_at,
                    json.dumps(raw, ensure_ascii=False, default=str),
                ),
            )

    def save_candidate(self, candidate: CandidateProduct) -> str:
        """Upsert the normalized candidate; returns candidate id."""
        conn = self._get_conn()
        with conn.transaction():
            row = conn.execute(
                """
                INSERT INTO agent.candidates
                    (product_key, key_type, name, brand, company, package_size, barcode,
                     ingredients_raw, ingredients_json, allergens_json, nutrition_json,
                     status, confidence, conflicts_json, missing_data, source_summary)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (product_key, key_type) DO UPDATE
                SET name=EXCLUDED.name, brand=EXCLUDED.brand, company=EXCLUDED.company,
                    package_size=EXCLUDED.package_size, barcode=EXCLUDED.barcode,
                    ingredients_raw=EXCLUDED.ingredients_raw,
                    ingredients_json=EXCLUDED.ingredients_json,
                    allergens_json=EXCLUDED.allergens_json,
                    nutrition_json=EXCLUDED.nutrition_json,
                    status=EXCLUDED.status, confidence=EXCLUDED.confidence,
                    conflicts_json=EXCLUDED.conflicts_json,
                    missing_data=EXCLUDED.missing_data,
                    source_summary=EXCLUDED.source_summary,
                    updated_at=now()
                RETURNING id
                """,
                (
                    candidate.product_key,
                    candidate.key_type,
                    candidate.name,
                    candidate.brand,
                    candidate.company,
                    candidate.package_size,
                    candidate.barcode,
                    candidate.ingredients_raw,
                    json.dumps(candidate.ingredients, ensure_ascii=False),
                    json.dumps(candidate.allergens, ensure_ascii=False),
                    json.dumps(candidate.nutrition, ensure_ascii=False),
                    candidate.status,
                    candidate.confidence,
                    json.dumps([c.model_dump() for c in candidate.conflicts], ensure_ascii=False),
                    json.dumps(candidate.missing_data, ensure_ascii=False),
                    json.dumps(candidate.source_summary, ensure_ascii=False, default=str),
                ),
            ).fetchone()
            return str(row["id"])

    def save_evidence(self, candidate_id: str, product_key: str, key_type: str, item: EvidenceItem) -> None:
        conn = self._get_conn()
        with conn.transaction():
            conn.execute(
                """
                INSERT INTO agent.evidence
                    (candidate_id, product_key, key_type, fact, value, source_name, source_url,
                     source_type, source_priority, retrieved_at, confidence, raw_excerpt)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (product_key, fact, source_name) DO UPDATE
                SET value=EXCLUDED.value, confidence=EXCLUDED.confidence,
                    raw_excerpt=EXCLUDED.raw_excerpt
                """,
                (
                    candidate_id,
                    product_key,
                    key_type,
                    item.fact,
                    item.value,
                    item.source.name,
                    item.source.url,
                    item.source.source_type,
                    item.source.priority,
                    item.source.retrieved_at,
                    item.confidence,
                    item.source.raw_excerpt,
                ),
            )

    def save_review_task(self, task: ReviewTask) -> None:
        conn = self._get_conn()
        with conn.transaction():
            conn.execute(
                """
                INSERT INTO agent.review_tasks
                    (product_key, key_type, status, problem, reason, sources_checked,
                     conflicting_sources, missing_data, suggested_action)
                VALUES (%s,%s,'OPEN',%s,%s,%s,%s,%s,%s)
                ON CONFLICT (product_key, problem) DO UPDATE
                SET reason=EXCLUDED.reason, status='OPEN',
                    sources_checked=EXCLUDED.sources_checked,
                    conflicting_sources=EXCLUDED.conflicting_sources,
                    missing_data=EXCLUDED.missing_data,
                    suggested_action=EXCLUDED.suggested_action,
                    resolved_at=NULL
                """,
                (
                    task.product_key,
                    task.key_type,
                    task.problem,
                    task.reason,
                    json.dumps(task.sources_checked, ensure_ascii=False),
                    json.dumps(task.conflicting_sources, ensure_ascii=False),
                    json.dumps(task.missing_data, ensure_ascii=False),
                    task.suggested_action,
                ),
            )

    # ----------------------------------------------------------------- batch

    def start_batch(self, batch_label: str) -> str:
        conn = self._get_conn()
        with conn.transaction():
            row = conn.execute(
                "INSERT INTO agent.batch_runs (batch_label) VALUES (%s) RETURNING id",
                (batch_label,),
            ).fetchone()
            return str(row["id"])

    def record_batch_item(
        self, batch_id: Optional[str], outcome: ProductOutcome, detail: Optional[str] = None
    ) -> None:
        conn = self._get_conn()
        with conn.transaction():
            conn.execute(
                """
                INSERT INTO agent.batch_items (batch_id, product_key, key_type, status, confidence, detail)
                VALUES (%s,%s,%s,%s,%s,%s)
                ON CONFLICT (batch_id, product_key, key_type) DO UPDATE
                SET status=EXCLUDED.status, confidence=EXCLUDED.confidence, detail=EXCLUDED.detail
                """,
                (
                    batch_id,
                    outcome.product_key,
                    outcome.key_type,
                    outcome.status,
                    outcome.confidence,
                    detail,
                ),
            )

    def finish_batch(self, batch_id: str, summary: BatchSummary) -> None:
        conn = self._get_conn()
        with conn.transaction():
            conn.execute(
                """
                UPDATE agent.batch_runs
                SET total=%s, verified=%s, needs_review=%s, conflict=%s,
                    unresolved=%s, failed=%s, finished_at=now()
                WHERE id=%s
                """,
                (
                    summary.total,
                    summary.verified,
                    summary.needs_review,
                    summary.conflict,
                    summary.unresolved,
                    summary.failed,
                    batch_id,
                ),
            )

    # ------------------------------------------------------------- promotion

    def promote_candidate(self, candidate: CandidateProduct) -> str:
        """Explicitly write a VERIFIED candidate into public (opt-in, NOT dry-run).

        This is intentionally the ONLY method that touches `public` and it is
        never called by the pipeline in DRY_RUN mode.
        """
        conn = self._get_conn()
        lifecycle = conn.execute(
            "SELECT id FROM public.lifecycle_statuses WHERE code='ACTIVE'"
        ).fetchone()
        status_id = lifecycle["id"]
        with conn.transaction():
            row = conn.execute(
                """
                INSERT INTO public.products
                    (internal_code, name, description, status_id, source_id,
                     confidence_level, verified_at)
                VALUES (%s, %s, %s, %s, NULL, %s, now())
                RETURNING id
                """,
                (
                    f"AGENT_{candidate.product_key}",
                    candidate.name,
                    "Imported by Fateen Data Agent (see agent.evidence for provenance).",
                    status_id,
                    candidate.confidence,
                ),
            ).fetchone()
            return str(row["id"])
