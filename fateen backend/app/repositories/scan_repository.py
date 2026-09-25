from typing import Optional
from app.db.connection import get_connection
import logging
import uuid

logger = logging.getLogger(__name__)


def create_scan_job(company_id: str, scan_type: str = "full") -> str:
    try:
        job_id = str(uuid.uuid4())
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO scan_jobs (
                    id, company_id, scan_type, status,
                    products_discovered, products_processed,
                    products_accepted, products_rejected, products_needs_review,
                    conflicts_detected, errors_count,
                    coverage_pct, duration_seconds,
                    created_at
                ) VALUES (
                    %s, %s, %s, 'pending',
                    0, 0,
                    0, 0, 0,
                    0, 0,
                    0, 0,
                    NOW()
                )
                """,
                (job_id, company_id, scan_type),
            )
            return job_id
    except Exception:
        logger.exception("Error creating scan job for company: %s", company_id)
        return ""


def get_scan_job(job_id: str) -> Optional[dict]:
    try:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM scan_jobs WHERE id = %s",
                (job_id,),
            ).fetchone()
            if not row:
                return None
            job = dict(row)
            if isinstance(job.get("id"), uuid.UUID):
                job["id"] = str(job["id"])
            if isinstance(job.get("company_id"), uuid.UUID):
                job["company_id"] = str(job["company_id"])
            if job.get("coverage_pct") is None:
                job["coverage_pct"] = 0.0
            return job
    except Exception:
        logger.exception("Error fetching scan job: %s", job_id)
        return None


def list_scan_jobs(
    company_id: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 20,
) -> list[dict]:
    try:
        with get_connection() as conn:
            query = "SELECT * FROM scan_jobs WHERE 1=1"
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
        logger.exception("Error listing scan jobs")
        return []


def update_scan_job(job_id: str, **fields) -> bool:
    if not fields:
        return False
    try:
        allowed = {
            "status",
            "products_discovered",
            "products_processed",
            "products_accepted",
            "products_rejected",
            "products_needs_review",
            "conflicts_detected",
            "errors_count",
            "coverage_pct",
            "duration_seconds",
            "started_at",
            "finished_at",
        }
        filtered = {k: v for k, v in fields.items() if k in allowed}
        if not filtered:
            return False

        set_parts = [f"{k} = %s" for k in filtered]
        values = list(filtered.values()) + [job_id]

        with get_connection() as conn:
            conn.execute(
                f"UPDATE scan_jobs SET {', '.join(set_parts)} WHERE id = %s",
                tuple(values),
            )
            return True
    except Exception:
        logger.exception("Error updating scan job: %s", job_id)
        return False


def create_scan_job_item(
    scan_job_id: str,
    candidate_id: Optional[str] = None,
    product_id: Optional[str] = None,
    barcode: Optional[str] = None,
) -> str:
    try:
        item_id = str(uuid.uuid4())
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO scan_job_items (
                    id, scan_job_id, candidate_id, product_id, barcode,
                    status, created_at, updated_at
                ) VALUES (
                    %s, %s, %s, %s, %s,
                    'pending', NOW(), NOW()
                )
                """,
                (item_id, scan_job_id, candidate_id, product_id, barcode),
            )
            return item_id
    except Exception:
        logger.exception("Error creating scan job item for job: %s", scan_job_id)
        return ""


def update_scan_job_item(item_id: str, **fields) -> bool:
    if not fields:
        return False
    try:
        allowed = {
            "candidate_id",
            "product_id",
            "barcode",
            "status",
            "error_message",
            "processed_at",
        }
        filtered = {k: v for k, v in fields.items() if k in allowed}
        if not filtered:
            return False

        set_parts = [f"{k} = %s" for k in filtered]
        values = list(filtered.values()) + [item_id]

        with get_connection() as conn:
            conn.execute(
                f"UPDATE scan_job_items SET {', '.join(set_parts)}, updated_at = NOW() WHERE id = %s",
                tuple(values),
            )
            return True
    except Exception:
        logger.exception("Error updating scan job item: %s", item_id)
        return False


def get_scan_job_items(
    job_id: str, status: Optional[str] = None
) -> list[dict]:
    try:
        with get_connection() as conn:
            query = "SELECT * FROM scan_job_items WHERE scan_job_id = %s"
            params: list = [job_id]

            if status:
                query += " AND status = %s"
                params.append(status)

            query += " ORDER BY created_at ASC"

            rows = conn.execute(query, tuple(params)).fetchall()
            return [dict(row) for row in rows]
    except Exception:
        logger.exception("Error fetching scan job items for job: %s", job_id)
        return []
