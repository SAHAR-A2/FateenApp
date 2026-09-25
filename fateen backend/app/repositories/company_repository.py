from typing import Optional
from app.db.connection import get_connection
import logging
import uuid

logger = logging.getLogger(__name__)


def get_company_by_id(company_id: str) -> Optional[dict]:
    try:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM companies WHERE id = %s AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            return dict(row) if row else None
    except Exception:
        logger.exception("Error fetching company by id: %s", company_id)
        return None


def get_company_by_slug(slug: str) -> Optional[dict]:
    try:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM companies WHERE slug = %s AND deleted_at IS NULL",
                (slug,),
            ).fetchone()
            return dict(row) if row else None
    except Exception:
        logger.exception("Error fetching company by slug: %s", slug)
        return None


def get_company_by_code(code: str) -> Optional[dict]:
    try:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM companies WHERE internal_code = %s AND deleted_at IS NULL",
                (code,),
            ).fetchone()
            return dict(row) if row else None
    except Exception:
        logger.exception("Error fetching company by code: %s", code)
        return None


def list_companies(
    country: Optional[str] = None,
    market: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
) -> list[dict]:
    try:
        with get_connection() as conn:
            query = "SELECT * FROM companies WHERE deleted_at IS NULL"
            params: list = []

            if country:
                query += " AND country = %s"
                params.append(country)
            if market:
                query += " AND market = %s"
                params.append(market)
            if status:
                query += " AND scan_status = %s"
                params.append(status)

            query += " ORDER BY priority_score DESC, name ASC LIMIT %s OFFSET %s"
            params.extend([limit, offset])

            rows = conn.execute(query, tuple(params)).fetchall()
            return [dict(row) for row in rows]
    except Exception:
        logger.exception("Error listing companies")
        return []


def create_company(
    name: str,
    code: str,
    slug: Optional[str] = None,
    country: str = "SA",
    market: str = "packaged_food",
    priority: int = 50,
    expected_product_count: Optional[int] = None,
    description: Optional[str] = None,
) -> str:
    try:
        company_id = str(uuid.uuid4())
        if not slug:
            slug = name.lower().replace(" ", "-").replace(".", "").replace(",", "")

        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO companies (
                    id, internal_code, name, slug, country, market,
                    priority, expected_product_count, description,
                    scan_status, discovered_product_count, verified_product_count,
                    barcode_coverage_pct, ingredient_coverage_pct,
                    allergen_coverage_pct, nutrition_coverage_pct, evidence_coverage_pct,
                    created_at, updated_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s,
                    'idle', 0, 0,
                    0, 0,
                    0, 0, 0,
                    NOW(), NOW()
                )
                """,
                (
                    company_id,
                    code,
                    name,
                    slug,
                    country,
                    market,
                    priority,
                    expected_product_count,
                    description,
                ),
            )
            return company_id
    except Exception:
        logger.exception("Error creating company: %s", name)
        return ""


def update_company(company_id: str, **fields) -> bool:
    if not fields:
        return False
    try:
        allowed = {
            "name",
            "slug",
            "internal_code",
            "country",
            "market",
            "priority",
            "expected_product_count",
            "description",
            "scan_status",
            "last_scan_at",
            "next_scan_at",
        }
        filtered = {k: v for k, v in fields.items() if k in allowed}
        if not filtered:
            return False

        set_parts = [f"{k} = %s" for k in filtered]
        values = list(filtered.values()) + [company_id]

        with get_connection() as conn:
            conn.execute(
                f"UPDATE companies SET {', '.join(set_parts)}, updated_at = NOW() WHERE id = %s AND deleted_at IS NULL",
                tuple(values),
            )
            return True
    except Exception:
        logger.exception("Error updating company: %s", company_id)
        return False


def delete_company(company_id: str) -> bool:
    try:
        with get_connection() as conn:
            conn.execute(
                "UPDATE companies SET deleted_at = NOW(), updated_at = NOW() WHERE id = %s AND deleted_at IS NULL",
                (company_id,),
            )
            return True
    except Exception:
        logger.exception("Error deleting company: %s", company_id)
        return False


def get_company_stats(company_id: str) -> dict:
    try:
        with get_connection() as conn:
            row = conn.execute(
                """
                SELECT
                    c.id,
                    c.name,
                    c.internal_code,
                    COALESCE(c.discovered_product_count, 0) AS discovered_product_count,
                    COALESCE(c.verified_product_count, 0) AS verified_product_count,
                    COALESCE(c.barcode_coverage_pct, 0) AS barcode_coverage_pct,
                    COALESCE(c.ingredient_coverage_pct, 0) AS ingredient_coverage_pct,
                    COALESCE(c.allergen_coverage_pct, 0) AS allergen_coverage_pct,
                    COALESCE(c.nutrition_coverage_pct, 0) AS nutrition_coverage_pct,
                    COALESCE(c.evidence_coverage_pct, 0) AS evidence_coverage_pct,
                    c.last_scan_at,
                    c.next_scan_at
                FROM companies c
                WHERE c.id = %s AND c.deleted_at IS NULL
                """,
                (company_id,),
            ).fetchone()
            if not row:
                return {}

            stats = dict(row)

            prod_row = conn.execute(
                """
                SELECT
                    COUNT(*) AS total_products,
                    COUNT(CASE WHEN p.internal_code IS NOT NULL AND p.internal_code != '' THEN 1 END) AS products_with_internal_code,
                    COUNT(CASE WHEN p.status_id = 1 THEN 1 END) AS active_products,
                    COUNT(CASE WHEN p.confidence_level IS NOT NULL THEN 1 END) AS products_with_confidence
                FROM products p
                JOIN brands b ON b.id = p.brand_id
                WHERE b.company_id = %s AND p.deleted_at IS NULL AND b.deleted_at IS NULL
                """,
                (company_id,),
            ).fetchone()
            if prod_row:
                stats["product_stats"] = dict(prod_row)

            job_row = conn.execute(
                """
                SELECT COUNT(*) AS total_jobs,
                       COUNT(CASE WHEN status = 'completed' THEN 1 END) AS completed_jobs
                FROM scan_jobs
                WHERE company_id = %s
                """,
                (company_id,),
            ).fetchone()
            if job_row:
                stats["scan_job_stats"] = dict(job_row)

            return stats
    except Exception:
        logger.exception("Error fetching company stats: %s", company_id)
        return {}
