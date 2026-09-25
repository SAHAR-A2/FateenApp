from typing import Optional
from app.db.connection import get_connection
import json
import logging
import uuid

logger = logging.getLogger(__name__)


def create_candidate(
    company_id: str,
    name: str,
    brand: Optional[str] = None,
    barcode: Optional[str] = None,
    category: Optional[str] = None,
    country: str = "SA",
    market: str = "packaged_food",
    source_url: Optional[str] = None,
    source_reference: Optional[str] = None,
    raw_data: Optional[dict] = None,
    scan_job_id: Optional[str] = None,
) -> str:
    try:
        candidate_id = str(uuid.uuid4())
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO discovery_candidates (
                    id, company_id, name, brand, barcode, category,
                    country, market, source_url, source_reference,
                    raw_data, scan_job_id, status,
                    created_at, updated_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, 'discovered',
                    NOW(), NOW()
                )
                """,
                (
                    candidate_id,
                    company_id,
                    name,
                    brand,
                    barcode,
                    category,
                    country,
                    market,
                    source_url,
                    source_reference,
                    json.dumps(raw_data) if raw_data is not None else None,
                    scan_job_id,
                ),
            )
            return candidate_id
    except Exception:
        logger.exception("Error creating candidate: %s", name)
        return ""


def get_candidate(candidate_id: str) -> Optional[dict]:
    try:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM discovery_candidates WHERE id = %s AND deleted_at IS NULL",
                (candidate_id,),
            ).fetchone()
            return dict(row) if row else None
    except Exception:
        logger.exception("Error fetching candidate: %s", candidate_id)
        return None


def list_candidates(
    company_id: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
) -> list[dict]:
    try:
        with get_connection() as conn:
            query = "SELECT * FROM discovery_candidates WHERE deleted_at IS NULL"
            params: list = []

            if company_id:
                query += " AND company_id = %s"
                params.append(company_id)
            if status:
                query += " AND status = %s"
                params.append(status)

            query += " ORDER BY created_at DESC LIMIT %s"
            params.append(limit)

            rows = conn.execute(query, tuple(params)).fetchall()
            return [dict(row) for row in rows]
    except Exception:
        logger.exception("Error listing candidates")
        return []


def update_candidate(candidate_id: str, **fields) -> bool:
    if not fields:
        return False
    try:
        allowed = {
            "name",
            "brand",
            "barcode",
            "category",
            "country",
            "market",
            "source_url",
            "source_reference",
            "raw_data",
            "status",
            "scan_job_id",
            "product_id",
        }
        filtered = {k: v for k, v in fields.items() if k in allowed}
        if not filtered:
            return False
        if "raw_data" in filtered and filtered["raw_data"] is not None:
            # jsonb column: psycopg3 does not auto-adapt a plain dict, it
            # must be serialized first (same convention already used for
            # jsonb-ish columns elsewhere in this module, e.g. scan_job_items
            # .error_message in app/collector/orchestrator.py).
            filtered["raw_data"] = json.dumps(filtered["raw_data"])

        set_parts = [f"{k} = %s" for k in filtered]
        values = list(filtered.values()) + [candidate_id]

        with get_connection() as conn:
            conn.execute(
                f"UPDATE discovery_candidates SET {', '.join(set_parts)}, updated_at = NOW() WHERE id = %s AND deleted_at IS NULL",
                tuple(values),
            )
            return True
    except Exception:
        logger.exception("Error updating candidate: %s", candidate_id)
        return False


def delete_candidate(candidate_id: str) -> bool:
    try:
        with get_connection() as conn:
            conn.execute(
                "UPDATE discovery_candidates SET deleted_at = NOW(), updated_at = NOW() WHERE id = %s AND deleted_at IS NULL",
                (candidate_id,),
            )
            return True
    except Exception:
        logger.exception("Error deleting candidate: %s", candidate_id)
        return False
