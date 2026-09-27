import hmac
import logging
import time
import uuid
from collections import defaultdict
from contextlib import asynccontextmanager
from datetime import datetime, timezone, timedelta

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.db.health import check_database
from app.db.connection import get_connection
from app.services.database_service import get_database_summary
from app.api.products import router as products_router
from app.api.product_details import router as product_details_router
from app.api.vision import router as vision_router
from app.api.ingestion import router as ingestion_router
from app.api.enrichment import router as enrichment_router
from app.api.companies import router as companies_router
from app.api.scan import router as scan_router
from app.api.review import router as review_router


def _setup_logging():
    env = settings.app_env
    level = logging.DEBUG if env == "development" else logging.INFO
    log_format = "%(asctime)s %(levelname)s %(name)s %(message)s"
    logging.basicConfig(level=level, format=log_format)
    if env == "production":
        logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
        logging.getLogger("psycopg_pool").setLevel(logging.WARNING)


_setup_logging()
logger = logging.getLogger("fateen")

STALE_JOB_THRESHOLD = timedelta(minutes=30)


def _recover_stale_jobs():
    """Mark stale in_progress jobs as failed on startup."""
    cutoff = datetime.now(timezone.utc) - STALE_JOB_THRESHOLD
    try:
        with get_connection() as conn:
            can_update = conn.execute(
                "SELECT has_table_privilege(current_user, 'public.scan_jobs', 'UPDATE')"
            ).fetchone()["has_table_privilege"]
            if not can_update:
                logger.info(
                    "Skipping stale-scan-job recovery on startup "
                    "(current role lacks UPDATE on public.scan_jobs)"
                )
                return
            has_company_id = conn.execute(
                """
                SELECT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name = 'scan_jobs'
                      AND column_name = 'company_id'
                )
                """
            ).fetchone()["exists"]
            if not has_company_id:
                logger.info(
                    "Skipping stale-scan-job recovery on startup "
                    "(public.scan_jobs has no company_id column)"
                )
                return
            result = conn.execute(
                """
                UPDATE public.scan_jobs
                SET status = 'failed',
                    finished_at = NOW(),
                    error_log = COALESCE(error_log, '[]'::jsonb)
                        || '[{"error": "Stale job recovered on startup", "timestamp": "now"}]'::jsonb,
                    updated_at = NOW()
                WHERE status = 'in_progress'
                  AND started_at < %s
                RETURNING id, company_id
                """,
                (cutoff,),
            )
            recovered = result.fetchall()
            if recovered:
                for row in recovered:
                    logger.warning(
                        "Recovered stale scan job %s for company %s",
                        row["id"], row["company_id"],
                    )
                logger.info("Recovered %d stale scan jobs on startup", len(recovered))
    except Exception:
        logger.exception("Failed to recover stale jobs on startup")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Fateen Backend starting (env=%s)", settings.app_env)
    _recover_stale_jobs()
    yield
    logger.info("Fateen Backend shutting down")


app = FastAPI(
    title="Fateen Backend API",
    description=(
        "Food product data management API for the Fateen platform.\n\n"
        "Provides barcode lookup, product details, and agent-based "
        "data ingestion with dry-run support."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    openapi_tags=[
        {"name": "Health", "description": "Service health checks"},
        {"name": "Products", "description": "Barcode lookup and product data"},
        {"name": "Agent", "description": "Agent-based data ingestion"},
        {"name": "LLM", "description": "LLM-assisted product data extraction and enrichment"},
        {"name": "Database", "description": "Database summary and diagnostics"},
        {"name": "Companies", "description": "Company registry management"},
        {"name": "Scan", "description": "Product discovery and scan orchestration"},
        {"name": "Review", "description": "Products kept with missing fields, for review"},
    ],
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)


_rate_limit_store: dict[str, list[float]] = defaultdict(list)
RATE_LIMIT_WINDOW = 60
RATE_LIMIT_MAX = 100
_rate_limit_cleanup_counter = 0
_RATE_LIMIT_CLEANUP_EVERY = 200


def _cleanup_rate_limit_store() -> int:
    """Remove IPs with no recent timestamps. Returns number of keys removed."""
    now = time.time()
    stale_keys = [
        ip for ip, timestamps in _rate_limit_store.items()
        if not timestamps or all(now - t >= RATE_LIMIT_WINDOW for t in timestamps)
    ]
    for ip in stale_keys:
        del _rate_limit_store[ip]
    return len(stale_keys)


@app.middleware("http")
async def rate_limit_and_tracking(request: Request, call_next):
    global _rate_limit_cleanup_counter
    request_id = str(uuid.uuid4())[:8]
    start = time.time()

    client_ip = request.client.host if request.client else "unknown"
    now = time.time()
    _rate_limit_store[client_ip] = [
        t for t in _rate_limit_store[client_ip] if now - t < RATE_LIMIT_WINDOW
    ]

    _rate_limit_cleanup_counter += 1
    if _rate_limit_cleanup_counter >= _RATE_LIMIT_CLEANUP_EVERY:
        _rate_limit_cleanup_counter = 0
        removed = _cleanup_rate_limit_store()
        if removed:
            logger.debug("Rate limit cleanup: removed %d stale IPs", removed)

    if len(_rate_limit_store[client_ip]) >= RATE_LIMIT_MAX:
        logger.warning("Rate limit exceeded for ip=%s", client_ip)
        return JSONResponse(
            status_code=429,
            content={"detail": "Rate limit exceeded. Try again later."},
        )
    _rate_limit_store[client_ip].append(now)

    response = await call_next(request)
    elapsed = round(time.time() - start, 3)

    response.headers["X-Request-ID"] = request_id
    response.headers["X-Response-Time"] = f"{elapsed}s"

    logger.info(
        "request_id=%s method=%s path=%s status=%d duration=%.3fs",
        request_id,
        request.method,
        request.url.path,
        response.status_code,
        elapsed,
    )

    return response


app.include_router(products_router)
app.include_router(product_details_router)
app.include_router(vision_router)
app.include_router(ingestion_router)
app.include_router(enrichment_router)
app.include_router(companies_router)
app.include_router(scan_router)
app.include_router(review_router)


@app.get(
    "/health",
    tags=["Health"],
    summary="Service health check",
    response_description="Health status with database connectivity",
)
def health():
    try:
        db = check_database()
        return {
            "status": "ok",
            "database": db["database"],
        }
    except Exception:
        logger.error("Health check failed: database unavailable")
        return JSONResponse(
            status_code=503,
            content={
                "status": "error",
                "database": "unavailable",
            },
        )


@app.get(
    "/api/v1/database/summary",
    tags=["Database"],
    summary="Database summary statistics",
)
def database_summary(request: Request):
    api_key = request.headers.get("X-Agent-API-Key", "")
    if settings.agent_ingest_api_key and not hmac.compare_digest(api_key, settings.agent_ingest_api_key):
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    return get_database_summary()


@app.get(
    "/api/v1/dashboard/summary",
    tags=["Dashboard"],
    summary="Aggregate pilot dashboard metrics",
    responses={401: {"description": "Invalid or missing API key"}},
)
def dashboard_summary(request: Request):
    # Was unauthenticated (MEDIUM finding M1 in the final archive audit).
    # Protected for consistency with /api/v1/database/summary, which
    # already required this same check. No documented reason existed for
    # this endpoint to be publicly exposed, so the pilot-safe default
    # (authenticated) is applied.
    api_key = request.headers.get("X-Agent-API-Key", "")
    if settings.agent_ingest_api_key and not hmac.compare_digest(api_key, settings.agent_ingest_api_key):
        raise HTTPException(status_code=401, detail="Invalid or missing API key")
    try:
        with get_connection() as conn:
            companies = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.companies WHERE deleted_at IS NULL"
            ).fetchone()["cnt"]
            products = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.products WHERE deleted_at IS NULL"
            ).fetchone()["cnt"]
            jobs = conn.execute(
                "SELECT status, COUNT(*) as cnt FROM public.scan_jobs GROUP BY status"
            ).fetchall()
            job_counts = {r["status"]: r["cnt"] for r in jobs}
            active_jobs = job_counts.get("in_progress", 0)
            total_jobs = sum(job_counts.values())
            failed_jobs = job_counts.get("failed", 0)
            unresolved_conflicts = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.data_conflicts WHERE resolution = 'unresolved'"
            ).fetchone()["cnt"]
            candidates = conn.execute(
                "SELECT status, COUNT(*) as cnt FROM public.discovery_candidates WHERE deleted_at IS NULL GROUP BY status"
            ).fetchall()
            candidate_counts = {r["status"]: r["cnt"] for r in candidates}
            total_candidates = sum(candidate_counts.values())
            rejected_candidates = (
                candidate_counts.get("validation_failed", 0)
                + candidate_counts.get("ingestion_failed", 0)
            )
            return {
                "companies": companies,
                "products": products,
                "scan_jobs": {
                    "total": total_jobs,
                    "active": active_jobs,
                    "failed": failed_jobs,
                    "by_status": job_counts,
                },
                "candidates": {
                    "total": total_candidates,
                    "rejected": rejected_candidates,
                    "by_status": candidate_counts,
                },
                "unresolved_conflicts": unresolved_conflicts,
            }
    except Exception:
        logger.exception("Failed to generate dashboard summary")
        raise HTTPException(
            status_code=500, detail="Failed to generate dashboard summary"
        )
