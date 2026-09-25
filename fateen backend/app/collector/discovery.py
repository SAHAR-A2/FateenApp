"""P04: Product Discovery.

Manages discovery candidates for a company.
Currently seed-based (no external API); manages candidate registration,
status updates, normalization, and retrieval of pending items.
"""
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from app.db.connection import get_connection
from app.collector.models import DiscoveryStatus
from app.agent.normalizers import normalize_barcode, normalize_name

logger = logging.getLogger("fateen.collector.discovery")


def discover_products_for_company(
    company_id: str,
    max_products: int = 100,
) -> list[dict]:
    """Get discovery candidates for a company, ordered by creation time.

    Returns up to max_products candidate dicts.
    """
    try:
        with get_connection() as conn:
            company = conn.execute(
                "SELECT id FROM public.companies WHERE id = %s AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            if not company:
                logger.warning("Company not found: %s", company_id)
                return []

            rows = conn.execute(
                """
                SELECT id, company_id, scan_job_id, name, brand, barcode,
                       category, country, market, source_url,
                       source_reference, source_retrieved_at, raw_data, status,
                       normalized_name, normalized_brand, normalized_barcode,
                       matched_product_id, match_confidence, validation_errors,
                       created_at, updated_at
                FROM public.discovery_candidates
                WHERE company_id = %s AND deleted_at IS NULL
                ORDER BY created_at ASC
                LIMIT %s
                """,
                (company_id, max_products),
            ).fetchall()
            return [dict(r) for r in rows]
    except Exception:
        logger.exception("Failed to discover products for company %s", company_id)
        return []


def register_candidate(
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
) -> Optional[str]:
    """Register a new discovery candidate.

    Returns the candidate_id on success, None on failure.
    """
    if not name or not name.strip():
        logger.error("Cannot register candidate: name is required")
        return None

    candidate_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    try:
        with get_connection() as conn:
            company = conn.execute(
                "SELECT id FROM public.companies WHERE id = %s AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            if not company:
                logger.error("Company not found: %s", company_id)
                return None

            conn.execute(
                """
                INSERT INTO public.discovery_candidates
                    (id, company_id, name, brand, barcode, category,
                     country, market, source_url, source_reference,
                     raw_data, status, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    candidate_id,
                    company_id,
                    name.strip(),
                    brand.strip() if brand else None,
                    barcode.strip() if barcode else None,
                    category.strip() if category else None,
                    country,
                    market,
                    source_url,
                    source_reference,
                    json.dumps(raw_data) if raw_data else "{}",
                    DiscoveryStatus.DISCOVERED.value,
                    now,
                    now,
                ),
            )

            logger.info("Registered candidate %s for company %s: %s", candidate_id, company_id, name)
            return candidate_id

    except Exception:
        logger.exception("Failed to register candidate for company %s", company_id)
        return None


def get_pending_candidates(
    company_id: Optional[str] = None,
    limit: int = 100,
) -> list[dict]:
    """Get candidates with status='discovered' (pending processing).

    Optionally filtered by company_id.
    """
    try:
        with get_connection() as conn:
            if company_id:
                rows = conn.execute(
                    """
                    SELECT id, company_id, scan_job_id, name, brand, barcode,
                           category, country, market, source_url,
                           source_reference, source_retrieved_at, raw_data, status,
                           normalized_name, normalized_brand, normalized_barcode,
                           matched_product_id, match_confidence, validation_errors,
                           created_at, updated_at
                    FROM public.discovery_candidates
                    WHERE status = %s
                      AND company_id = %s
                      AND deleted_at IS NULL
                    ORDER BY created_at ASC
                    LIMIT %s
                    """,
                    (DiscoveryStatus.DISCOVERED.value, company_id, limit),
                ).fetchall()
            else:
                rows = conn.execute(
                    """
                    SELECT id, company_id, scan_job_id, name, brand, barcode,
                           category, country, market, source_url,
                           source_reference, source_retrieved_at, raw_data, status,
                           normalized_name, normalized_brand, normalized_barcode,
                           matched_product_id, match_confidence, validation_errors,
                           created_at, updated_at
                    FROM public.discovery_candidates
                    WHERE status = %s
                      AND deleted_at IS NULL
                    ORDER BY created_at ASC
                    LIMIT %s
                    """,
                    (DiscoveryStatus.DISCOVERED.value, limit),
                ).fetchall()
            return [dict(r) for r in rows]
    except Exception:
        logger.exception("Failed to get pending candidates")
        return []


def update_candidate_status(candidate_id: str, status: str) -> bool:
    """Update the status of a discovery candidate.

    Returns True on success, False on failure.
    """
    valid_statuses = {s.value for s in DiscoveryStatus}
    if status not in valid_statuses:
        logger.error("Invalid candidate status: %s", status)
        return False

    now = datetime.now(timezone.utc)
    try:
        with get_connection() as conn:
            result = conn.execute(
                """
                UPDATE public.discovery_candidates
                SET status = %s, updated_at = %s
                WHERE id = %s AND deleted_at IS NULL
                """,
                (status, now, candidate_id),
            )
            updated = result.rowcount > 0
            if updated:
                logger.info("Updated candidate %s status to %s", candidate_id, status)
            else:
                logger.warning("Candidate not found for status update: %s", candidate_id)
            return updated
    except Exception:
        logger.exception("Failed to update candidate %s status to %s", candidate_id, status)
        return False


def normalize_candidate(candidate_id: str) -> bool:
    """Normalize a candidate's name, brand, and barcode.

    Computes normalized_name, normalized_brand, and normalized_barcode.
    Returns True on success, False on failure.
    """
    try:
        with get_connection() as conn:
            row = conn.execute(
                """
                SELECT id, name, brand, barcode
                FROM public.discovery_candidates
                WHERE id = %s AND deleted_at IS NULL
                """,
                (candidate_id,),
            ).fetchone()

            if not row:
                logger.warning("Candidate not found for normalization: %s", candidate_id)
                return False

            normalized_name = normalize_name(row["name"])
            normalized_brand = normalize_name(row["brand"]) if row["brand"] else None
            normalized_barcode = normalize_barcode(row["barcode"]) if row["barcode"] else None

            now = datetime.now(timezone.utc)
            conn.execute(
                """
                UPDATE public.discovery_candidates
                SET normalized_name = %s,
                    normalized_brand = %s,
                    normalized_barcode = %s,
                    updated_at = %s
                WHERE id = %s
                """,
                (normalized_name, normalized_brand, normalized_barcode, now, candidate_id),
            )

            logger.info("Normalized candidate %s", candidate_id)
            return True

    except Exception:
        logger.exception("Failed to normalize candidate %s", candidate_id)
        return False



