"""P21: Halal/Haram Evidence System.

Records and tracks halal evidence for products.
Statuses: HALAL, HARAM, DOUBTFUL, UNKNOWN, NEEDS_REVIEW.

CRITICAL: NEVER infer UNKNOWN -> HALAL or UNKNOWN -> HARAM.
Each status transition requires explicit evidence.
"""
# ---------------------------------------------------------------------------
# PRODUCTION-PATH STATUS (verified 2026-08-20, final release remediation):
# This module is NOT currently imported or called by any live API endpoint,
# CLI entry point, or orchestrator path in this codebase (app/api/*,
# app/main.py, app/collector/orchestrator.py, app/agent/*). It is fully
# implemented and tested in isolation but architecturally UNREACHABLE from
# production traffic as of commit 7b32932. Do not assume its protections
# are active for real requests until it is explicitly wired into a live
# call path AND that wiring is covered by an integration test proving the
# connection. See reports/FINAL_PRE_AGENT_RELEASE_AUDIT.md, section I, for
# the reachability audit and the decision not to wire it in during this
# remediation pass (wiring was judged out of scope: it requires an
# architecture decision about which entry point should invoke it and with
# what data, not just a mechanical import).
# ---------------------------------------------------------------------------

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from app.db.connection import get_connection
from app.collector.models import HalalStatus

logger = logging.getLogger("fateen.collector.halal")

VALID_STATUSES = {s.value for s in HalalStatus}

FORBIDDEN_TRANSITIONS = {
    (HalalStatus.UNKNOWN, HalalStatus.HALAL),
    (HalalStatus.UNKNOWN, HalalStatus.HARAM),
}


def record_halal_evidence(
    product_id: str,
    status: str,
    confidence: float,
    evidence_type: str,
    authority: str,
    reasoning: str,
    source_config_id: Optional[str] = None,
    raw_evidence: Optional[str] = None,
) -> Optional[str]:
    """Record a halal evidence entry for a product.

    Returns the halal_evidence_id on success, None on failure.
    If there is a current halal status, it is checked for forbidden transitions
    (UNKNOWN -> HALAL or UNKNOWN -> HARAM are never inferred).
    """
    if status not in VALID_STATUSES:
        logger.error("Invalid halal status: %s", status)
        return None

    if confidence < 0.0 or confidence > 1.0:
        logger.error("Invalid confidence value: %s", confidence)
        return None

    halal_evidence_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    try:
        with get_connection() as conn:
            current = conn.execute(
                """
                SELECT id, status FROM public.halal_evidence
                WHERE product_id = %s AND is_current = TRUE
                FOR UPDATE
                """,
                (product_id,),
            ).fetchone()

            if current:
                old_status_str = current["status"]
                try:
                    old_status = HalalStatus(old_status_str)
                    new_status = HalalStatus(status)
                except ValueError:
                    logger.error("Could not parse status for transition check: %s -> %s", old_status_str, status)
                    return None

                if (old_status, new_status) in FORBIDDEN_TRANSITIONS:
                    logger.warning(
                        "Forbidden transition %s -> %s for product %s. "
                        "UNKNOWN status cannot be inferred to HALAL or HARAM without explicit evidence.",
                        old_status_str, status, product_id,
                    )
                    return None

                conn.execute(
                    """
                    UPDATE public.halal_evidence
                    SET is_current = FALSE, updated_at = %s
                    WHERE product_id = %s AND is_current = TRUE
                    """,
                    (now, product_id),
                )

            conn.execute(
                """
                INSERT INTO public.halal_evidence
                    (id, product_id, status, confidence, source_config_id,
                     evidence_type, authority, reasoning, raw_evidence,
                     retrieved_at, is_current, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE, %s, %s)
                """,
                (
                    halal_evidence_id,
                    product_id,
                    status,
                    confidence,
                    source_config_id,
                    evidence_type,
                    authority,
                    reasoning,
                    raw_evidence,
                    now,
                    now,
                    now,
                ),
            )

            logger.info(
                "Recorded halal evidence %s for product %s: status=%s confidence=%.2f",
                halal_evidence_id, product_id, status, confidence,
            )

    except Exception:
        logger.exception("Failed to record halal evidence for product %s", product_id)
        return None

    return halal_evidence_id


def get_current_halal_status(product_id: str) -> Optional[dict]:
    """Get the current halal status for a product.

    Returns a dict with the current evidence record, or None if no record exists.
    """
    try:
        with get_connection() as conn:
            row = conn.execute(
                """
                SELECT id, product_id, status, confidence, source_config_id,
                       evidence_type, authority, reasoning, raw_evidence,
                       retrieved_at, is_current, created_at, updated_at
                FROM public.halal_evidence
                WHERE product_id = %s AND is_current = TRUE
                """,
                (product_id,),
            ).fetchone()
            return dict(row) if row else None
    except Exception:
        logger.exception("Failed to get current halal status for product %s", product_id)
        return None


def get_halal_history(product_id: str) -> list[dict]:
    """Get all halal evidence records for a product, ordered by creation time.

    Returns a list of dicts, newest first.
    """
    try:
        with get_connection() as conn:
            rows = conn.execute(
                """
                SELECT id, product_id, status, confidence, source_config_id,
                       evidence_type, authority, reasoning, raw_evidence,
                       retrieved_at, is_current, created_at, updated_at
                FROM public.halal_evidence
                WHERE product_id = %s
                ORDER BY created_at DESC
                """,
                (product_id,),
            ).fetchall()
            return [dict(r) for r in rows]
    except Exception:
        logger.exception("Failed to get halal history for product %s", product_id)
        return []
