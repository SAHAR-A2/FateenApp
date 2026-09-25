"""P14: Conflict detection for collected data.

Do NOT silently overwrite conflicting data.
Detect and record conflicts for human review.
"""
import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from app.db.connection import get_connection
from app.collector.models import ConflictRecord

logger = logging.getLogger("fateen.collector.conflicts")


def detect_conflicts(
    entity_type: str,
    entity_id: str,
    field_name: str,
    existing_value: str,
    new_value: str,
    source_a_id: Optional[str] = None,
    source_b_id: Optional[str] = None,
    confidence_a: Optional[float] = None,
    confidence_b: Optional[float] = None,
) -> Optional[ConflictRecord]:
    """Detect and record a data conflict.

    Returns the ConflictRecord if created, None if no conflict.
    """
    if existing_value == new_value:
        return None

    conflict = ConflictRecord(
        entity_type=entity_type,
        entity_id=entity_id,
        entity_name=f"{entity_type}:{entity_id}",
        field_name=field_name,
        value_a=existing_value,
        value_b=new_value,
        source_a_id=source_a_id,
        source_b_id=source_b_id,
        confidence_a=confidence_a,
        confidence_b=confidence_b,
    )

    conflict_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    try:
        with get_connection() as conn:
            existing = conn.execute(
                """
                SELECT id FROM public.data_conflicts
                WHERE entity_type = %s AND entity_id = %s AND field_name = %s
                    AND (resolution IS NULL OR resolution = 'unresolved')
                LIMIT 1
                """,
                (entity_type, entity_id, field_name),
            ).fetchone()
            if existing:
                logger.debug(
                    "Conflict already exists for %s.%s on entity %s (id=%s), skipping duplicate",
                    entity_type, field_name, entity_id, existing["id"],
                )
                return None
            conn.execute(
                """
                INSERT INTO public.data_conflicts
                    (id, entity_type, entity_id, entity_name, field_name,
                     value_a, value_b, source_a_id, source_b_id,
                     confidence_a, confidence_b, status, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    conflict_id, entity_type, entity_id, conflict.entity_name,
                    field_name, existing_value, new_value,
                    source_a_id, source_b_id,
                    confidence_a, confidence_b,
                    "detected", now, now,
                ),
            )
            _update_company_conflict_count(conn, entity_id)
    except Exception:
            logger.exception(
                "Failed to record conflict for %s.%s",
                entity_type,
                field_name,
            )
            raise

    return conflict


def get_unresolved_conflicts(entity_type: Optional[str] = None, entity_id: Optional[str] = None) -> list[dict]:
    """Get unresolved conflicts, optionally filtered.

    A conflict is unresolved when resolution IS NULL (newly detected)
    or resolution = 'unresolved' (explicitly marked).
    """
    query = "SELECT * FROM public.data_conflicts WHERE (resolution IS NULL OR resolution = 'unresolved')"
    params = []

    if entity_type:
        query += " AND entity_type = %s"
        params.append(entity_type)
    if entity_id:
        query += " AND entity_id = %s"
        params.append(entity_id)

    query += " ORDER BY created_at DESC"

    with get_connection() as conn:
        rows = conn.execute(query, params).fetchall()
        return [dict(r) for r in rows]


def resolve_conflict(conflict_id: str, resolution: str, note: str = "", resolved_by: str = "system") -> bool:
    """Resolve a conflict."""
    valid_resolutions = {"resolved", "unresolved", "needs_review", "dismissed"}
    if resolution not in valid_resolutions:
        return False

    now = datetime.now(timezone.utc)
    try:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT entity_id FROM public.data_conflicts WHERE id = %s",
                (conflict_id,),
            ).fetchone()
            if not row:
                return False
            product_id = row["entity_id"]
            conn.execute(
                """
                UPDATE public.data_conflicts
                SET resolution = %s, resolution_note = %s, resolved_by = %s,
                    resolved_at = %s, status = %s, updated_at = %s
                WHERE id = %s
                """,
                (resolution, note, resolved_by, now, "resolved" if resolution == "resolved" else "acknowledged", now, conflict_id),
            )
            _update_company_conflict_count(conn, product_id)
        return True
    except Exception:
        logger.exception("Failed to resolve conflict %s", conflict_id)
        return False


def count_unresolved_conflicts(company_id: Optional[str] = None) -> int:
    """Count unresolved conflicts, optionally for a specific company."""
    query = "SELECT COUNT(*) as cnt FROM public.data_conflicts WHERE (resolution IS NULL OR resolution = 'unresolved')"
    params = []

    if company_id:
        query += " AND entity_id IN (SELECT id FROM public.products WHERE brand_id IN (SELECT id FROM public.brands WHERE company_id = %s))"
        params.append(company_id)

    with get_connection() as conn:
        row = conn.execute(query, params).fetchone()
        return row["cnt"] if row else 0


def _update_company_conflict_count(conn, entity_id):
    """Update conflict count for the company owning a persisted product.

    Conflict records may refer to non-persisted or synthetic entities.
    Those entities must not cause the conflict operation to fail.
    """
    try:
        # Only persisted products can be mapped to a company.
        row = conn.execute(
            """
            SELECT b.company_id
            FROM public.products p
            JOIN public.brands b ON b.id = p.brand_id
            WHERE p.id = %s
              AND p.deleted_at IS NULL
              AND b.deleted_at IS NULL
            LIMIT 1
            """,
            (entity_id,),
        ).fetchone()

        # Synthetic / non-product entity: nothing to update.
        if not row or not row["company_id"]:
            return

        company_id = row["company_id"]

        conn.execute(
            """
            UPDATE public.companies
            SET conflict_count = (
                SELECT COUNT(*)
                FROM public.data_conflicts dc
                JOIN public.products p
                    ON p.id = dc.entity_id::uuid
                JOIN public.brands b
                    ON b.id = p.brand_id
                WHERE b.company_id = %s
                  AND p.deleted_at IS NULL
                  AND b.deleted_at IS NULL
                  AND (
                      dc.resolution IS NULL
                      OR dc.resolution = 'unresolved'
                  )
            ),
            updated_at = NOW()
            WHERE id = %s
            """,
            (company_id, company_id),
        )

    except Exception:
        # Conflict recording itself must remain reliable even when
        # the optional company counter cannot be updated.
        logger.exception(
            "Failed to update company conflict count for entity %s",
            entity_id,
        )
        