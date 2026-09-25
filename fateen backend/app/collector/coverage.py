"""P28: Coverage Metrics.

Calculates, stores, and updates data coverage metrics for companies.
Handles None denominators gracefully (returns None for pct fields).
"""
import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from app.db.connection import get_connection
from app.collector.models import CoverageReport

logger = logging.getLogger("fateen.collector.coverage")


def calculate_company_coverage(company_id: str) -> CoverageReport:
    """Query the database to compute coverage metrics for a company.

    Counts products that have barcodes, ingredients, allergens, nutrition,
    and evidence records. Returns a CoverageReport with absolute counts and
    percentages. None denominators produce None pct fields.
    """
    company_name = "UNKNOWN"
    try:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT id, name FROM public.companies WHERE id = %s AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            if row:
                company_name = row.get("name", "UNKNOWN")
    except Exception:
        logger.exception("Failed to load company %s for coverage", company_id)

    report = CoverageReport(
        company_id=company_id,
        company_name=company_name,
    )

    try:
        with get_connection() as conn:
            total_row = conn.execute(
                """
                SELECT COUNT(*) as cnt
                FROM public.products p
                JOIN public.brands b ON b.id = p.brand_id
                WHERE b.company_id = %s
                  AND p.deleted_at IS NULL
                  AND b.deleted_at IS NULL
                """,
                (company_id,),
            ).fetchone()
            report.total_products = total_row["cnt"] if total_row else 0

            barcode_row = conn.execute(
                """
                SELECT COUNT(DISTINCT p.id) as cnt
                FROM public.products p
                JOIN public.brands b ON b.id = p.brand_id
                JOIN public.product_barcodes pb ON pb.product_id = p.id
                JOIN public.barcodes br ON br.id = pb.barcode_id
                WHERE b.company_id = %s
                  AND p.deleted_at IS NULL
                  AND b.deleted_at IS NULL
                  AND pb.deleted_at IS NULL
                  AND br.deleted_at IS NULL
                """,
                (company_id,),
            ).fetchone()
            report.products_with_barcode = barcode_row["cnt"] if barcode_row else 0

            ingredient_row = conn.execute(
                """
                SELECT COUNT(DISTINCT p.id) as cnt
                FROM public.products p
                JOIN public.brands b ON b.id = p.brand_id
                JOIN public.product_ingredients pi ON pi.product_id = p.id
                WHERE b.company_id = %s
                  AND p.deleted_at IS NULL
                  AND b.deleted_at IS NULL
                  AND pi.deleted_at IS NULL
                """,
                (company_id,),
            ).fetchone()
            report.products_with_ingredients = ingredient_row["cnt"] if ingredient_row else 0

            allergen_row = conn.execute(
                """
                SELECT COUNT(DISTINCT p.id) as cnt
                FROM public.products p
                JOIN public.brands b ON b.id = p.brand_id
                JOIN public.product_allergens pa ON pa.product_id = p.id
                WHERE b.company_id = %s
                  AND p.deleted_at IS NULL
                  AND b.deleted_at IS NULL
                  AND pa.deleted_at IS NULL
                """,
                (company_id,),
            ).fetchone()
            report.products_with_allergens = allergen_row["cnt"] if allergen_row else 0

            nutrition_row = conn.execute(
                """
                SELECT COUNT(DISTINCT p.id) as cnt
                FROM public.products p
                JOIN public.brands b ON b.id = p.brand_id
                JOIN public.product_nutrition_values pnv ON pnv.product_id = p.id
                WHERE b.company_id = %s
                  AND p.deleted_at IS NULL
                  AND b.deleted_at IS NULL
                  AND pnv.deleted_at IS NULL
                """,
                (company_id,),
            ).fetchone()
            report.products_with_nutrition = nutrition_row["cnt"] if nutrition_row else 0

            evidence_row = conn.execute(
                """
                SELECT COUNT(DISTINCT p.id) as cnt
                FROM public.products p
                JOIN public.brands b ON b.id = p.brand_id
                JOIN public.evidence_records er
                  ON er.entity_type = 'product' AND er.entity_id = p.id::text
                WHERE b.company_id = %s
                  AND p.deleted_at IS NULL
                  AND b.deleted_at IS NULL
                """,
                (company_id,),
            ).fetchone()
            report.products_with_evidence = evidence_row["cnt"] if evidence_row else 0

    except Exception:
        logger.exception("Failed to calculate coverage for company %s", company_id)
        return report

    report.barcode_coverage_pct = _safe_pct(report.products_with_barcode, report.total_products)
    report.ingredient_coverage_pct = _safe_pct(report.products_with_ingredients, report.total_products)
    report.allergen_coverage_pct = _safe_pct(report.products_with_allergens, report.total_products)
    report.nutrition_coverage_pct = _safe_pct(report.products_with_nutrition, report.total_products)
    report.evidence_coverage_pct = _safe_pct(report.products_with_evidence, report.total_products)

    pct_values = [
        v for v in [
            report.barcode_coverage_pct,
            report.ingredient_coverage_pct,
            report.allergen_coverage_pct,
            report.nutrition_coverage_pct,
            report.evidence_coverage_pct,
        ] if v is not None
    ]
    report.overall_coverage_pct = round(sum(pct_values) / len(pct_values), 2) if pct_values else None

    return report


def save_coverage_snapshot(
    company_id: str,
    scan_job_id: Optional[str] = None,
) -> Optional[str]:
    """Save a coverage snapshot to the coverage_snapshots table.

    Returns the snapshot ID on success, None on failure.
    """
    report = calculate_company_coverage(company_id)
    snapshot_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    try:
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO public.coverage_snapshots
                    (id, company_id, scan_job_id,
                     total_products, products_with_barcode,
                     products_with_ingredients, products_with_allergens,
                     products_with_nutrition, products_with_evidence,
                     barcode_coverage_pct, ingredient_coverage_pct,
                     allergen_coverage_pct, nutrition_coverage_pct,
                     evidence_coverage_pct, overall_coverage_pct,
                     snapshot_at, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    snapshot_id,
                    company_id,
                    scan_job_id,
                    report.total_products,
                    report.products_with_barcode,
                    report.products_with_ingredients,
                    report.products_with_allergens,
                    report.products_with_nutrition,
                    report.products_with_evidence,
                    report.barcode_coverage_pct,
                    report.ingredient_coverage_pct,
                    report.allergen_coverage_pct,
                    report.nutrition_coverage_pct,
                    report.evidence_coverage_pct,
                    report.overall_coverage_pct,
                    now,
                    now,
                ),
            )
        logger.info(
            "Saved coverage snapshot %s for company %s",
            snapshot_id,
            company_id,
        )
        return snapshot_id
    except Exception:
        logger.exception(
            "Failed to save coverage snapshot for company %s", company_id
        )
        return None


def update_company_coverage_fields(company_id: str) -> bool:
    """Update the *_coverage_pct columns on the companies table.

    Returns True on success, False on failure.
    """
    report = calculate_company_coverage(company_id)
    now = datetime.now(timezone.utc)

    try:
        with get_connection() as conn:
            conn.execute(
                """
                UPDATE public.companies
                SET barcode_coverage_pct = %s,
                    ingredient_coverage_pct = %s,
                    allergen_coverage_pct = %s,
                    nutrition_coverage_pct = %s,
                    evidence_coverage_pct = %s,
                    last_scan_at = %s,
                    updated_at = %s
                WHERE id = %s
                """,
                (
                    report.barcode_coverage_pct,
                    report.ingredient_coverage_pct,
                    report.allergen_coverage_pct,
                    report.nutrition_coverage_pct,
                    report.evidence_coverage_pct,
                    now,
                    now,
                    company_id,
                ),
            )
        logger.info("Updated coverage fields for company %s", company_id)
        return True
    except Exception:
        logger.exception(
            "Failed to update coverage fields for company %s", company_id
        )
        return False


def _safe_pct(numerator: int, denominator: Optional[int]) -> Optional[float]:
    """Calculate percentage safely. Returns None when denominator is None or zero."""
    if denominator is None or denominator == 0:
        return None
    return round((numerator / denominator) * 100, 2)
