import hmac
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Body, HTTPException, Query, Request
from typing import Optional

from app.core.config import settings, resolve_effective_dry_run
from app.db.connection import get_connection
from app.repositories.scan_repository import (
    get_scan_job,
    list_scan_jobs,
)
from app.repositories.discovery_repository import (
    create_candidate,
    list_candidates,
    update_candidate,
)
from app.schemas.scan import ScanJobCreate, ScanJobResponse, DiscoveryRawData
from app.collector.orchestrator import scan_company
from app.collector.discovery import normalize_candidate
from app.collector.coverage import calculate_company_coverage
from app.collector.reporting import generate_scan_report, format_report_text

logger = logging.getLogger("fateen.api.scan")

router = APIRouter(prefix="/api/v1/scan", tags=["Scan"])


def _check_api_key(request: Request):
    api_key = request.headers.get("X-Agent-API-Key", "")
    if settings.agent_ingest_api_key and not hmac.compare_digest(api_key, settings.agent_ingest_api_key):
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


@router.post(
    "/start",
    summary="Start a company scan",
    response_model=ScanJobResponse,
    responses={
        401: {"description": "Invalid or missing API key"},
        422: {"description": "Validation error"},
    },
)
def start_scan(body: ScanJobCreate, request: Request):
    _check_api_key(request)

    # SAFETY CONTRACT: the global AGENT_DRY_RUN switch must be able to
    # force a dry run regardless of what the caller requests. This MUST
    # go through the single authoritative helper — do not hardcode
    # dry_run=False here again (that was CRITICAL finding C1).
    effective_dry_run = resolve_effective_dry_run(body.dry_run)

    try:
        result = scan_company(
            company_id=body.company_id,
            dry_run=effective_dry_run,
            max_products=body.max_products,
        )
    except Exception:
        logger.exception("Scan failed for company %s", body.company_id)
        raise HTTPException(
            status_code=500, detail="Scan execution failed"
        )

    job = get_scan_job(result.scan_job_id)
    if not job:
        raise HTTPException(
            status_code=500, detail="Scan job created but could not be retrieved"
        )
    return job


@router.get(
    "/jobs",
    summary="List scan jobs",
    responses={401: {"description": "Invalid or missing API key"}},
)
def list_jobs(
    request: Request,
    company_id: Optional[str] = Query(default=None),
    status: Optional[str] = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
):
    _check_api_key(request)
    jobs = list_scan_jobs(
        company_id=company_id,
        status=status,
        limit=limit,
    )
    return {"jobs": jobs, "total": len(jobs)}


@router.get(
    "/{job_id}",
    summary="Get scan job status",
    response_model=ScanJobResponse,
    responses={
        401: {"description": "Invalid or missing API key"},
        404: {"description": "Scan job not found"},
    },
)
def get_job(job_id: str, request: Request):
    _check_api_key(request)
    job = get_scan_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Scan job not found")
    return job


@router.get(
    "/{job_id}/report",
    summary="Get scan report in text format",
    responses={
        401: {"description": "Invalid or missing API key"},
        404: {"description": "Scan job not found"},
    },
)
def get_job_report(job_id: str, request: Request):
    _check_api_key(request)
    job = get_scan_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Scan job not found")

    try:
        report_dict = generate_scan_report(job_id)
        report_text = format_report_text(report_dict)
    except Exception:
        logger.exception("Failed to generate report for job %s", job_id)
        raise HTTPException(
            status_code=500, detail="Failed to generate report"
        )

    return {"report": report_text}


@router.post(
    "/discover/{company_id}",
    summary="Register a discovery candidate for a company",
    status_code=201,
    responses={
        401: {"description": "Invalid or missing API key"},
        404: {"description": "Company not found"},
        422: {"description": "Validation error"},
    },
)
def discover_candidate(
    company_id: str,
    request: Request,
    name: str = Query(..., description="Product name"),
    brand: Optional[str] = Query(default=None),
    barcode: Optional[str] = Query(default=None),
    category: Optional[str] = Query(default=None),
    country: str = Query(default="SA"),
    market: str = Query(default="packaged_food"),
    source_url: Optional[str] = Query(default=None),
    source_reference: Optional[str] = Query(default=None),
    raw_data: Optional[DiscoveryRawData] = Body(
        default=None,
        embed=True,
        description=(
            "Optional structured ingredients/allergens/nutrition payload "
            "for the collector to read back during scan_company(). Fully "
            "validated (types + ranges) before storage. Omit entirely to "
            "keep the previous behaviour (a bare candidate with no "
            "raw_data, exactly as before this field existed)."
        ),
    ),
):
    _check_api_key(request)
    candidate_id = create_candidate(
        company_id=company_id,
        name=name,
        brand=brand,
        barcode=barcode,
        category=category,
        country=country,
        market=market,
        source_url=source_url,
        source_reference=source_reference,
        raw_data=raw_data.model_dump() if raw_data is not None else None,
    )
    if not candidate_id:
        raise HTTPException(
            status_code=404, detail="Company not found or failed to create candidate"
        )
    return {"candidate_id": candidate_id, "raw_data_attached": raw_data is not None}


@router.get(
    "/candidates",
    summary="List pending discovery candidates",
    responses={401: {"description": "Invalid or missing API key"}},
)
def list_pending_candidates(
    request: Request,
    company_id: Optional[str] = Query(default=None),
    status: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
):
    _check_api_key(request)
    candidates = list_candidates(
        company_id=company_id,
        status=status,
        limit=limit,
    )
    return {"candidates": candidates, "total": len(candidates)}


@router.get(
    "/coverage/{company_id}",
    summary="Get coverage metrics for a company",
    responses={
        401: {"description": "Invalid or missing API key"},
        404: {"description": "Company not found"},
    },
)
def get_coverage(company_id: str, request: Request):
    _check_api_key(request)
    try:
        report = calculate_company_coverage(company_id)
    except Exception:
        logger.exception("Failed to calculate coverage for company %s", company_id)
        raise HTTPException(
            status_code=500, detail="Failed to calculate coverage"
        )
    return {
        "company_id": report.company_id,
        "company_name": report.company_name,
        "total_products": report.total_products,
        "products_with_barcode": report.products_with_barcode,
        "products_with_ingredients": report.products_with_ingredients,
        "products_with_allergens": report.products_with_allergens,
        "products_with_nutrition": report.products_with_nutrition,
        "products_with_evidence": report.products_with_evidence,
        "barcode_coverage_pct": report.barcode_coverage_pct,
        "ingredient_coverage_pct": report.ingredient_coverage_pct,
        "allergen_coverage_pct": report.allergen_coverage_pct,
        "nutrition_coverage_pct": report.nutrition_coverage_pct,
        "evidence_coverage_pct": report.evidence_coverage_pct,
        "overall_coverage_pct": report.overall_coverage_pct,
    }


@router.post(
    "/{job_id}/reset",
    summary="Reset a stuck scan job to failed status",
    responses={
        401: {"description": "Invalid or missing API key"},
        404: {"description": "Scan job not found"},
    },
)
def reset_stuck_job(job_id: str, request: Request):
    _check_api_key(request)
    job = get_scan_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Scan job not found")
    if job.get("status") != "in_progress":
        raise HTTPException(
            status_code=400, detail="Only in_progress jobs can be reset"
        )
    now = datetime.now(timezone.utc)
    try:
        with get_connection() as conn:
            conn.execute(
                """
                UPDATE public.scan_jobs
                SET status = 'failed',
                    finished_at = %s,
                    error_log = COALESCE(error_log, '[]'::jsonb)
                        || '[{"error": "Manually reset via API"}]'::jsonb,
                    updated_at = %s
                WHERE id = %s AND status = 'in_progress'
                """,
                (now, now, job_id),
            )
    except Exception:
        logger.exception("Failed to reset scan job %s", job_id)
        raise HTTPException(
            status_code=500, detail="Failed to reset scan job"
        )
    return {"detail": "Scan job reset to failed", "job_id": job_id}
