"""P03: Deterministic company prioritization.

Priority is reproducible and based on quantifiable factors.
No LLM is used to decide priority.
"""
import logging
import math
from typing import Optional

from app.db.connection import get_connection

logger = logging.getLogger("fateen.collector.prioritization")

# Weight factors for priority calculation (total = 1.0)
WEIGHT_MARKET_RELEVANCE = 0.25
WEIGHT_PRODUCT_COUNT = 0.20
WEIGHT_EXISTING_COVERAGE = 0.20
WEIGHT_SOURCE_QUALITY = 0.15
WEIGHT_BARCODE_COVERAGE = 0.10
WEIGHT_DATA_COMPLETENESS = 0.10


def calculate_priority_score(
    company_id: str,
    market_relevance: float = 0.5,
    estimated_products: int = 0,
    existing_coverage_pct: float = 0.0,
    source_quality: float = 0.5,
    barcode_coverage_pct: float = 0.0,
    data_completeness_pct: float = 0.0,
) -> float:
    """Calculate a deterministic priority score for a company.

    All inputs are normalized to [0, 1] before weighting.
    Returns a score in [0, 100].
    """
    product_score = min(estimated_products / 1000.0, 1.0) if estimated_products > 0 else 0.0
    coverage_penalty = existing_coverage_pct / 100.0

    raw = (
        WEIGHT_MARKET_RELEVANCE * min(market_relevance, 1.0)
        + WEIGHT_PRODUCT_COUNT * product_score
        + WEIGHT_EXISTING_COVERAGE * (1.0 - coverage_penalty)
        + WEIGHT_SOURCE_QUALITY * min(source_quality, 1.0)
        + WEIGHT_BARCODE_COVERAGE * (barcode_coverage_pct / 100.0)
        + WEIGHT_DATA_COMPLETENESS * (data_completeness_pct / 100.0)
    )

    score = round(raw * 100, 2)
    return max(0.0, min(100.0, score))


def calculate_all_company_priorities() -> dict[str, float]:
    """Calculate priority scores for all companies in the registry.

    Returns dict of company_id -> priority_score.
    """
    scores = {}
    try:
        with get_connection() as conn:
            companies = conn.execute("""
                SELECT id, name, expected_product_count, priority,
                       barcode_coverage_pct, ingredient_coverage_pct,
                       allergen_coverage_pct, nutrition_coverage_pct,
                       evidence_coverage_pct
                FROM public.companies
                WHERE deleted_at IS NULL
            """).fetchall()

            for company in companies:
                cid = str(company["id"])
                expected = company.get("expected_product_count") or 0

                barcode_cov = company.get("barcode_coverage_pct") or 0.0
                ingredient_cov = company.get("ingredient_coverage_pct") or 0.0
                allergen_cov = company.get("allergen_coverage_pct") or 0.0
                nutrition_cov = company.get("nutrition_coverage_pct") or 0.0
                evidence_cov = company.get("evidence_coverage_pct") or 0.0

                avg_coverage = (
                    (barcode_cov + ingredient_cov + allergen_cov +
                     nutrition_cov + evidence_cov) / 5.0
                    if any([barcode_cov, ingredient_cov, allergen_cov, nutrition_cov, evidence_cov])
                    else 0.0
                )

                score = calculate_priority_score(
                    company_id=cid,
                    estimated_products=expected,
                    existing_coverage_pct=avg_coverage,
                )
                scores[cid] = score

    except Exception:
        logger.exception("Failed to calculate company priorities")

    return scores


def update_company_priorities():
    """Update all company priority scores in the database."""
    scores = calculate_all_company_priorities()
    if not scores:
        return

    try:
        with get_connection() as conn:
            for company_id, score in scores.items():
                priority = max(1, min(100, int(score)))
                conn.execute(
                    "UPDATE public.companies SET priority_score = %s, priority = %s, updated_at = NOW() WHERE id = %s",
                    (score, priority, company_id),
                )
    except Exception:
        logger.exception("Failed to update company priorities")


def get_companies_by_priority(limit: int = 10) -> list[dict]:
    """Get companies ordered by priority score (highest first)."""
    try:
        with get_connection() as conn:
            rows = conn.execute("""
                SELECT id, internal_code, name, slug, priority, priority_score,
                       country, market, scan_status, expected_product_count,
                       discovered_product_count, verified_product_count,
                       last_scan_at, next_scan_at
                FROM public.companies
                WHERE deleted_at IS NULL
                ORDER BY priority DESC, name
                LIMIT %s
            """, (limit,)).fetchall()
            return [dict(r) for r in rows]
    except Exception:
        logger.exception("Failed to get companies by priority")
        return []
