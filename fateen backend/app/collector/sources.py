"""P05/P13: Source configuration and evidence management."""
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

logger = logging.getLogger("fateen.collector.sources")

VALID_SOURCE_TYPES = {"MANUFACTURER", "REGULATORY", "DATABASE", "USER_SUBMITTED", "IMPORT", "WEBSITE", "OCR"}
VALID_EVIDENCE_TYPES = {"LABEL", "MANUFACTURER", "OFFICIAL_SOURCE", "DATABASE", "USER_SUBMITTED", "OCR"}


def get_source_by_code(code: str) -> Optional[dict]:
    """Get a data source by its code."""
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id, code, source_type_id, priority_id FROM public.data_sources "
            "WHERE code = %s AND deleted_at IS NULL",
            (code,),
        ).fetchone()
        return dict(row) if row else None


def get_evidence_type_id(code: str) -> Optional[str]:
    """Get an evidence type ID by code."""
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id FROM public.evidence_types WHERE code = %s AND deleted_at IS NULL",
            (code,),
        ).fetchone()
        return str(row["id"]) if row else None


def get_relationship_type_id(code: str) -> Optional[str]:
    """Get a relationship type ID by code."""
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id FROM public.relationship_types WHERE code = %s AND deleted_at IS NULL",
            (code,),
        ).fetchone()
        return str(row["id"]) if row else None


def create_evidence_record(
    entity_type: str,
    entity_id: str,
    evidence_type_code: str = "LABEL",
    source_code: str = "FATEEN_TEST",
    raw_value: Optional[str] = None,
    normalized_value: Optional[str] = None,
    confidence: float = 0.5,
    metadata: Optional[dict] = None,
    conn=None,
) -> Optional[str]:
    """Create an evidence record. Returns the new evidence ID."""
    evidence_type_id = get_evidence_type_id(evidence_type_code)
    if evidence_type_id is None:
        logger.warning("Evidence type not found: %s", evidence_type_code)
        return None

    source = get_source_by_code(source_code)
    source_id = source["id"] if source else None

    evidence_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    def _execute(c):
        c.execute(
            """
            INSERT INTO public.evidence_records
                (id, entity_type, entity_id, evidence_type_code,
                 source_config_id, raw_value, normalized_value,
                 confidence, metadata, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                evidence_id, entity_type, entity_id, evidence_type_code,
                source_id, raw_value, normalized_value,
                confidence, metadata, now,
            ),
        )

    try:
        if conn:
            _execute(conn)
        else:
            with get_connection() as c:
                _execute(c)
    except Exception:
        logger.warning("Failed to create evidence record (table may not exist)")
        return None

    return evidence_id
