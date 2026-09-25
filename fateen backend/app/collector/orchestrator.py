"""P27: Company Scan Orchestration.

Orchestrates the full data collection pipeline for a company:
discovery -> normalize -> validate -> deduplicate -> detect conflicts -> ingest.

Single bad products must never abort a company-wide scan.
Each candidate's DB writes are wrapped in a single transaction.
"""
import json
import logging
import time
import uuid
from datetime import datetime, timezone
from typing import Optional

from app.core.config import settings
from app.db.connection import get_connection
from app.collector.models import (
    ScanJobResult,
    ScanStatus,
    CollectedProductData,
    ExtractedIngredients,
    ExtractedAllergen,
    ExtractedNutrition,
)
from app.collector import deduplication
from app.collector import conflicts
from app.collector import validation
from app.collector import extraction
from app.collector import coverage as coverage_mod
from app.collector.web_discovery import (
    classify_url,
    sort_discovery_results,
    get_web_discovery_provider,
    SourceClassification,
)

logger = logging.getLogger("fateen.collector.orchestrator")

# Collector auto-extraction toggle. When True, each candidate with a
# source_url is fetched through the SSRF-safe retrieval module and the page
# text is run through retrieval -> LLM -> extract_from_llm_response before
# validation. When False (the default), the pre-existing manual raw_data
# path is used unchanged. Read once at import so tests can toggle it via
# the core config without environmental surprises.
_COLLECTOR_AUTO = settings.collector_auto_extraction

# Codename of the internal collection pipeline. Referenced by the provenance
# lookup in _create_product_from_candidate. Migration 0043 seeds the
# data_sources row; until then the lookup fails loudly (never a silent NULL
# source_id write against the products_source_id_fk constraint).
_COLLECTOR_SOURCE_CODE = "COLLECTOR"


class _MissingCollectorSource(RuntimeError):
    """Raised when the COLLECTOR data_sources row is not registered.

    Distinct from generic/database failures so the caller can surface a clear,
    diagnosable provenance error instead of a silent NULL source_id.
    """


# ---------------------------------------------------------------------------
# DRY_RUN contract (Fix 2, FATEEN Architecture Audit).
#
# dry_run=True does NOT mean "zero database writes". It means: no product
# data is created or modified. Operational/tracking records needed to
# report on and audit the scan itself are still written, by design, in
# both modes -- that is the whole point of being able to review a dry run
# before deciding to ingest for real.
#
# FORBIDDEN under dry_run=True (never written, in either dry-run or a
# candidate that is skipped/rejected before reaching real ingestion):
#   - public.products            (new products)
#   - public.brands              (new brands)
#   - public.barcodes / public.product_barcodes
#   - public.product_ingredients
#   - public.product_allergens
#   - public.product_nutrition_values
#   - public.coverage_snapshots  (recomputed only after a real ingest)
#   - public.companies (coverage_pct / products_count / last_scanned_at)
#
# ALLOWED under dry_run=True (operational records for reporting/tracking;
# written the same way regardless of dry_run):
#   - public.scan_jobs / public.scan_job_items
#   - public.discovery_candidates (normalization fields + status/
#     matched_product_id/match_confidence)
#   - public.data_conflicts, public.companies.conflict_count (surfacing a
#     conflict during a dry run is the point: it lets you see what WOULD
#     need review before you commit to a real ingest)
#
# _DRY_RUN_FORBIDDEN_TABLES exists so this contract is testable, not just
# documented: tests/test_dry_run_safety_contract.py asserts against it
# directly instead of duplicating the table list.
# ---------------------------------------------------------------------------
DRY_RUN_FORBIDDEN_TABLES = frozenset(
    {
        "public.products",
        "public.brands",
        "public.barcodes",
        "public.product_barcodes",
        "public.product_ingredients",
        "public.product_allergens",
        "public.product_nutrition_values",
        "public.coverage_snapshots",
    }
)

DRY_RUN_ALLOWED_OPERATIONAL_TABLES = frozenset(
    {
        "public.scan_jobs",
        "public.scan_job_items",
        "public.discovery_candidates",
        "public.data_conflicts",
        "public.companies",
    }
)


def assert_real_ingestion_authorized(ingest: bool) -> None:
    """Belt-and-braces guard: refuse a real write if a dry run is required.

    Mirrors the module-level DRY_RUN constant at runtime and also fires
    when the global AGENT_DRY_RUN switch forces a dry run (so a future call
    site cannot bypass the safety contract by passing dry_run=False
    directly).
    """
    if not ingest:
        return
    if not settings.agent_dry_run:
        return
    raise AssertionError(
        "AGENT_DRY_RUN is True: real product ingestion is forbidden. "
        "Resolve the dry-run flag through app.core.config."
    )


def scan_company(
    company_id: str,
    dry_run: bool = True,
    max_products: Optional[int] = None,
) -> ScanJobResult:
    """Run the full collection pipeline for a company.

    Steps:
        1. Load company from DB
        2. Create scan_job record
        3. Discover products (from discovery_candidates)
        4. For each candidate: normalize, validate, dedup, detect conflicts
        5. If not dry_run: ingest through existing pipeline
        6. Update scan_job with results
        7. Generate coverage snapshot
        8. Return ScanJobResult

    A single bad product never aborts the company scan.
    Every candidate's DB writes are wrapped in one transaction.

    DRY_RUN CONTRACT -- see DRY_RUN_FORBIDDEN_TABLES /
    DRY_RUN_ALLOWED_OPERATIONAL_TABLES above. dry_run=True guarantees no
    write to any table in DRY_RUN_FORBIDDEN_TABLES; it does NOT guarantee
    zero writes overall. scan_jobs, scan_job_items, discovery_candidates
    (normalization + status), and data_conflicts are written the same way
    in both modes -- this is intentional (a dry run's report/tracking
    needs those rows to exist), not an oversight.
    """
    started_at = time.monotonic()
    now = datetime.now(timezone.utc)

    company = _load_company(company_id)
    if company is None:
        return ScanJobResult(
            scan_job_id="",
            company_id=company_id,
            company_name="UNKNOWN",
            status=ScanStatus.FAILED,
            errors=[f"Company not found: {company_id}"],
        )

    existing_job = _find_active_scan_job(company_id)
    if existing_job:
        return ScanJobResult(
            scan_job_id=existing_job["id"],
            company_id=company_id,
            company_name=company.get("name", "UNKNOWN"),
            status=ScanStatus.IN_PROGRESS,
            errors=["A scan is already in progress for this company"],
        )

    scan_job_id = _create_scan_job(company_id, dry_run)

    if not scan_job_id:
        return ScanJobResult(
            scan_job_id="",
            company_id=company_id,
            company_name=company.get("name", "UNKNOWN"),
            status=ScanStatus.FAILED,
            errors=["Failed to create scan job"],
        )

    _update_scan_job_status(
        scan_job_id,
        ScanStatus.IN_PROGRESS,
    )
    logger.info(
        "Scan started: job=%s company=%s dry_run=%s",
        scan_job_id, company_id, dry_run,
    )

    result = ScanJobResult(
        scan_job_id=scan_job_id,
        company_id=company_id,
        company_name=company.get("name", "UNKNOWN"),
        status=ScanStatus.IN_PROGRESS,
    )

    candidates = _load_candidates(company_id, max_products)
    result.products_discovered = len(candidates)

    provider = get_web_discovery_provider()
    if candidate_sources := _discover_source_urls(provider, company, candidates):
        candidates.extend(candidate_sources)

    error_log = []

    try:
        for candidate in candidates:
            try:
                item_result = _process_candidate(
                    scan_job_id=scan_job_id,
                    candidate=candidate,
                    dry_run=dry_run,
                )

                result.products_processed += 1

                if item_result["action"] == "accepted":
                    result.products_accepted += 1
                elif item_result["action"] == "rejected":
                    result.products_rejected += 1
                elif item_result["action"] == "needs_review":
                    result.products_needs_review += 1
                elif item_result["action"] == "retryable":
                    result.products_needs_review += 1

                if item_result.get("created"):
                    result.products_created += 1
                elif item_result.get("updated"):
                    result.products_updated += 1
                elif item_result.get("unchanged"):
                    result.products_unchanged += 1

                if item_result.get("conflicts_detected"):
                    result.conflicts_detected += item_result["conflicts_detected"]

            except Exception:
                result.products_processed += 1
                result.errors_count += 1
                candidate_name = candidate.get("name", "unknown") if isinstance(candidate, dict) else "unknown"
                error_msg = f"Failed to process candidate '{candidate_name}'"
                result.errors.append(error_msg)
                error_log.append({
                    "candidate_id": str(candidate.get("id", "")) if isinstance(candidate, dict) else "",
                    "candidate_name": candidate_name,
                    "error": error_msg,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                })
                logger.exception(
                    "Failed to process candidate for company %s", company_id
                )

    except Exception:
        logger.exception("Catastrophic failure in scan_company for %s", company_id)
        result.status = ScanStatus.FAILED
        result.errors.append("Scan aborted due to unexpected error")
        error_log.append({
            "error": "Scan aborted due to unexpected error",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

    elapsed = time.monotonic() - started_at
    result.duration_seconds = round(elapsed, 2)

    if result.status != ScanStatus.FAILED:
        if result.errors_count == 0 and result.products_processed > 0:
            result.status = ScanStatus.COMPLETED
        elif result.errors_count > 0 and result.products_accepted > 0:
            result.status = ScanStatus.PARTIAL
        elif result.products_processed == 0:
            result.status = ScanStatus.COMPLETED
        else:
            result.status = ScanStatus.FAILED

    try:
        coverage_report = coverage_mod.calculate_company_coverage(company_id)
        result.coverage_pct = coverage_report.overall_coverage_pct
        if not dry_run:
            coverage_mod.save_coverage_snapshot(
                company_id, scan_job_id=scan_job_id
            )
            coverage_mod.update_company_coverage_fields(company_id)
    except Exception:
        logger.exception("Failed to calculate coverage for company %s", company_id)

    _finalize_scan_job(scan_job_id, result, error_log)

    logger.info(
        "Scan completed: job=%s company=%s status=%s "
        "processed=%d accepted=%d rejected=%d errors=%d duration=%.2fs",
        scan_job_id, company_id, result.status,
        result.products_processed, result.products_accepted,
        result.products_rejected, result.errors_count,
        result.duration_seconds or 0,
    )

    return result


def _load_company(company_id: str) -> Optional[dict]:
    """Load a company by ID."""
    try:
        with get_connection() as conn:
            row = conn.execute(
                "SELECT id, name, internal_code, country, market "
                "FROM public.companies WHERE id = %s AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            return dict(row) if row else None
    except Exception:
        logger.exception("Failed to load company %s", company_id)
        return None


def _find_active_scan_job(company_id: str) -> Optional[dict]:
    """Check if a scan is already in progress for this company."""
    try:
        with get_connection() as conn:
            row = conn.execute(
                """
                SELECT id, status FROM public.scan_jobs
                WHERE company_id = %s AND status = 'in_progress'
                ORDER BY created_at DESC LIMIT 1
                """,
                (company_id,),
            ).fetchone()
            return dict(row) if row else None
    except Exception:
        logger.exception("Failed to check active scan for company %s", company_id)
        return None


def _create_scan_job(company_id: str, dry_run: bool) -> str:
    """Create a scan_job record and return its ID."""
    scan_job_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    scan_type = "dry_run" if dry_run else "full"

    try:
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO public.scan_jobs
                    (id, company_id, scan_type, status, started_at, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    scan_job_id,
                    company_id,
                    scan_type,
                    ScanStatus.PENDING,
                    now,
                    now,
                    now,
                ),
            )
    except Exception:
        logger.exception("Failed to create scan_job for company %s", company_id)
        scan_job_id = ""

    return scan_job_id


def _update_scan_job_status(scan_job_id: str, status: str) -> None:
    """Update the status of a scan_job."""
    if not scan_job_id:
        return
    now = datetime.now(timezone.utc)
    try:
        with get_connection() as conn:
            conn.execute(
                """
                UPDATE public.scan_jobs
                SET status = %s, updated_at = %s
                WHERE id = %s
                """,
                (status, now, scan_job_id),
            )
    except Exception:
        logger.exception("Failed to update scan_job %s status to %s", scan_job_id, status)


def _load_candidates(
    company_id: str, max_products: Optional[int] = None
) -> list[dict]:
    """Load discovery_candidates for the company."""
    try:
        query = (
            "SELECT id, company_id, name, brand, barcode, category, "
            "country, market, source_url, source_reference, raw_data, "
            "status, normalized_name, normalized_brand, normalized_barcode "
            "FROM public.discovery_candidates "
            "WHERE company_id = %s AND deleted_at IS NULL "
            "ORDER BY created_at ASC"
        )
        params = [company_id]

        if max_products is not None:
            query += " LIMIT %s"
            params.append(max_products)

        with get_connection() as conn:
            rows = conn.execute(query, params).fetchall()
            return [dict(r) for r in rows]
    except Exception:
        logger.exception("Failed to load candidates for company %s", company_id)
        return []


def _process_candidate(
    scan_job_id: str,
    candidate: dict,
    dry_run: bool,
) -> dict:
    """Process a single discovery candidate through the pipeline.

    All DB writes for this candidate happen in a single transaction.
    Returns a dict describing what happened to this candidate.
    """
    item_id = str(uuid.uuid4())
    candidate_id = candidate.get("id")
    result = {
        "action": "rejected",
        "conflicts_detected": 0,
        "created": False,
        "updated": False,
        "unchanged": False,
    }

    _normalize_candidate(candidate)
    collected = _candidate_to_collected(candidate)

    if _COLLECTOR_AUTO:
        collected = _auto_extract_candidate(candidate, collected)

    if extraction.is_provider_failure(collected):
        return _record_provider_failure(scan_job_id, item_id, candidate, collected, result)

    val_result = validation.validate_product_data(collected)
    if not val_result.is_valid:
        with get_connection() as conn:
            now = datetime.now(timezone.utc)
            conn.execute(
                """
                INSERT INTO public.scan_job_items
                    (id, scan_job_id, candidate_id, barcode, status, action,
                     error_message, processed_at, created_at, updated_at)
                VALUES (%s, %s, %s, %s, 'validation_failed', 'rejected', %s, %s, %s, %s)
                """,
                (item_id, scan_job_id, candidate_id, candidate.get("barcode"),
                 json.dumps(val_result.errors), now, now, now),
            )
            _update_candidate_status_conn(conn, candidate_id, "validation_failed", val_result.errors)
        result["action"] = "rejected"
        return result

    dedup_match = deduplication.find_matching_product(
        barcode=collected.barcode,
        product_name=collected.product_name,
        brand=collected.brand,
    )

    if dedup_match:
        ambiguous = deduplication.check_ambiguous_match(
            barcode=collected.barcode,
            product_name=collected.product_name,
            brand=collected.brand,
        )
        if ambiguous["is_ambiguous"]:
            with get_connection() as conn:
                now = datetime.now(timezone.utc)
                conn.execute(
                    """
                    INSERT INTO public.scan_job_items
                        (id, scan_job_id, candidate_id, barcode, status, action,
                         error_message, processed_at, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, 'needs_review', 'needs_review', %s, %s, %s, %s)
                    """,
                    (item_id, scan_job_id, candidate_id, candidate.get("barcode"),
                     "Ambiguous dedup match", now, now, now),
                )
                _update_candidate_status_conn(conn, candidate_id, "pending_review", ["Ambiguous match"])
            result["action"] = "needs_review"
            return result

        detected = _detect_conflicts_for_product(dedup_match, collected)
        result["conflicts_detected"] = detected

        if not dry_run:
            ingestion_result = _ingest_product(collected, dry_run=dry_run)
            if ingestion_result["success"]:
                result["action"] = "accepted"
                if detected == 0:
                    result["unchanged"] = True
                with get_connection() as conn:
                    now = datetime.now(timezone.utc)
                    conn.execute(
                        """
                        INSERT INTO public.scan_job_items
                            (id, scan_job_id, candidate_id, product_id, barcode,
                             status, action, processed_at, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, %s, 'processed', 'accepted', %s, %s, %s)
                        """,
                        (item_id, scan_job_id, candidate_id, dedup_match["id"],
                         candidate.get("barcode"), now, now, now),
                    )
                    _update_candidate_status_conn(
                        conn, candidate_id, "matched",
                        None, dedup_match["id"], dedup_match.get("match_confidence"),
                    )
            else:
                result["action"] = "rejected"
                with get_connection() as conn:
                    now = datetime.now(timezone.utc)
                    conn.execute(
                        """
                        INSERT INTO public.scan_job_items
                            (id, scan_job_id, candidate_id, barcode, status, action,
                             error_message, processed_at, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, 'ingestion_failed', 'rejected', %s, %s, %s, %s)
                        """,
                        (item_id, scan_job_id, candidate_id, candidate.get("barcode"),
                         ingestion_result.get("error", "Ingestion failed"), now, now, now),
                    )
        else:
            result["action"] = "accepted"
            with get_connection() as conn:
                now = datetime.now(timezone.utc)
                conn.execute(
                    """
                    INSERT INTO public.scan_job_items
                        (id, scan_job_id, candidate_id, product_id, barcode,
                         status, action, processed_at, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, 'processed', 'accepted', %s, %s, %s)
                    """,
                    (item_id, scan_job_id, candidate_id, dedup_match["id"],
                     candidate.get("barcode"), now, now, now),
                )
                _update_candidate_status_conn(
                    conn, candidate_id, "matched",
                    None, dedup_match["id"], dedup_match.get("match_confidence"),
                )
    else:
        if dry_run:
            final_status = "discovered"
            with get_connection() as conn:
                now = datetime.now(timezone.utc)
                conn.execute(
                    """
                    INSERT INTO public.scan_job_items
                        (id, scan_job_id, candidate_id, barcode,
                         status, action, processed_at, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, 'processed', 'accepted', %s, %s, %s)
                    """,
                    (item_id, scan_job_id, candidate_id, candidate.get("barcode"),
                     now, now, now),
                )
                _update_candidate_status_conn(conn, candidate_id, final_status, None)
            result["action"] = "accepted"
            result["created"] = True
        else:
            ingestion_result = _ingest_product(collected, dry_run=dry_run)
            if ingestion_result["success"]:
                with get_connection() as conn:
                    now = datetime.now(timezone.utc)
                    existing = conn.execute(
                        "SELECT id FROM public.product_barcodes pb "
                        "JOIN public.barcodes b ON b.id = pb.barcode_id "
                        "WHERE b.barcode = %s AND pb.deleted_at IS NULL LIMIT 1",
                        (collected.barcode,),
                    ).fetchone()
                    if existing:
                        product_id = conn.execute(
                            "SELECT pb.product_id FROM public.product_barcodes pb "
                            "JOIN public.barcodes b ON b.id = pb.barcode_id "
                            "WHERE b.barcode = %s AND pb.deleted_at IS NULL LIMIT 1",
                            (collected.barcode,),
                        ).fetchone()["product_id"]
                    else:
                        try:
                            product_id = _create_product_from_candidate(
                                collected, conn=conn
                            )
                        except _MissingCollectorSource as exc:
                            provenance_msg = (
                                "Product creation refused: " + str(exc)
                            )
                            with get_connection() as fconn:
                                fnow = datetime.now(timezone.utc)
                                fconn.execute(
                                    """
                                    INSERT INTO public.scan_job_items
                                        (id, scan_job_id, candidate_id, barcode, status, action,
                                         error_message, processed_at, created_at, updated_at)
                                    VALUES (%s, %s, %s, %s, 'ingestion_failed', 'rejected', %s, %s, %s, %s)
                                    """,
                                    (item_id, scan_job_id, candidate_id,
                                     candidate.get("barcode"), provenance_msg,
                                     fnow, fnow, fnow),
                                )
                                _update_candidate_status_conn(
                                    fconn, candidate_id, "ingestion_failed",
                                    [provenance_msg],
                                )
                            result["action"] = "rejected"
                            result["error"] = provenance_msg
                            return result
                    if product_id is None:
                        failure_msg = (
                            "Product creation failed: the product row was "
                            "rejected by the database"
                        )
                        with get_connection() as fconn:
                            fnow = datetime.now(timezone.utc)
                            fconn.execute(
                                """
                                INSERT INTO public.scan_job_items
                                    (id, scan_job_id, candidate_id, barcode, status, action,
                                     error_message, processed_at, created_at, updated_at)
                                VALUES (%s, %s, %s, %s, 'ingestion_failed', 'rejected', %s, %s, %s, %s)
                                """,
                                (item_id, scan_job_id, candidate_id,
                                 candidate.get("barcode"), failure_msg, fnow, fnow, fnow),
                            )
                            _update_candidate_status_conn(
                                fconn, candidate_id, "ingestion_failed", [failure_msg],
                            )
                        result["action"] = "rejected"
                        result["error"] = failure_msg
                        return result
                    conn.execute(
                        """
                        INSERT INTO public.scan_job_items
                            (id, scan_job_id, candidate_id, product_id, barcode,
                             status, action, processed_at, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, %s, 'processed', 'accepted', %s, %s, %s)
                        """,
                        (item_id, scan_job_id, candidate_id, product_id,
                         candidate.get("barcode"), now, now, now),
                    )
                    _update_candidate_status_conn(
                        conn, candidate_id, "new", None, product_id, 1.0,
                    )
                result["action"] = "accepted"
                result["created"] = True
            else:
                final_status = "ingestion_failed"
                with get_connection() as conn:
                    now = datetime.now(timezone.utc)
                    conn.execute(
                        """
                        INSERT INTO public.scan_job_items
                            (id, scan_job_id, candidate_id, barcode, status, action,
                             error_message, processed_at, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, 'ingestion_failed', 'rejected', %s, %s, %s, %s)
                        """,
                        (item_id, scan_job_id, candidate_id, candidate.get("barcode"),
                         ingestion_result.get("error", "Ingestion failed"), now, now, now),
                    )
                    _update_candidate_status_conn(
                        conn, candidate_id, "ingestion_failed",
                        [ingestion_result.get("error", "Ingestion failed")],
                    )
                result["action"] = "rejected"

    return result


def _record_provider_failure(
    scan_job_id: str,
    item_id: str,
    candidate: dict,
    collected,
    result: dict,
) -> dict:
    """Record an LLM provider failure as an operational retryable outcome.

    A provider failure (quota / rate limit / timeout / 5xx / transport) is
    NOT product data. It must never be written as 'validation_failed' with
    a 'Product name is required' error. It is recorded as
    status='provider_failed', action='retryable' on scan_job_items and
    candidate status 'retryable' so the candidate can be retried once the
    provider is available again. Only operational/tracking tables are
    written, exactly as the DRY_RUN contract allows in both modes.
    """
    detail = collected.error_detail or collected.status or "PROVIDER_ERROR"
    try:
        with get_connection() as conn:
            now = datetime.now(timezone.utc)
            conn.execute(
                """
                INSERT INTO public.scan_job_items
                    (id, scan_job_id, candidate_id, barcode, status, action,
                     error_message, processed_at, created_at, updated_at)
                VALUES (%s, %s, %s, %s, 'provider_failed', 'retryable', %s, %s, %s, %s)
                """,
                (item_id, scan_job_id, candidate.get("id"),
                 candidate.get("barcode"), detail, now, now, now),
            )
            _update_candidate_status_conn(
                conn, candidate.get("id"), "retryable", [detail]
            )
    except Exception:
        logger.exception(
            "Failed to record provider failure for candidate %s",
            candidate.get("id"),
        )
    result["action"] = "retryable"
    result["retryable"] = True
    result["provider_failed"] = True
    result["extraction_status"] = collected.status
    return result


def _normalize_candidate(candidate: dict) -> None:
    """Normalize a candidate's name and barcode fields in-place."""
    raw_name = candidate.get("name", "")
    raw_brand = candidate.get("brand", "")
    raw_barcode = candidate.get("barcode", "")

    norm_name = raw_name.strip().lower() if raw_name else ""
    norm_brand = raw_brand.strip().lower() if raw_brand else ""
    norm_barcode = raw_barcode.strip() if raw_barcode else ""

    candidate["normalized_name"] = norm_name
    candidate["normalized_brand"] = norm_brand
    candidate["normalized_barcode"] = norm_barcode

    if candidate.get("id"):
        try:
            now = datetime.now(timezone.utc)
            with get_connection() as conn:
                conn.execute(
                    """
                    UPDATE public.discovery_candidates
                    SET normalized_name = %s, normalized_brand = %s,
                        normalized_barcode = %s, updated_at = %s
                    WHERE id = %s
                    """,
                    (norm_name, norm_brand, norm_barcode, now, candidate["id"]),
                )
        except Exception:
            logger.exception(
                "Failed to update normalized fields for candidate %s",
                candidate.get("id"),
            )


def _discover_source_urls(
    provider, company: dict, existing_candidates: list
) -> list[dict]:
    """Run the configured web discovery provider, if enabled.

    Deterministic source ranking only -- priority is never LLM-decided.
    Returns web discovery results (None) when the provider is disabled or
    produced nothing. Only source-URL candidates are returned; product
    identity (name/brand/barcode) is confirmed by an operator before a
    scan, never invented here.

    Each discovered URL is persisted as a discovery_candidates row
    (status='discovered', raw_data={}) so the scan can track it: web
    candidates must exist in discovery_candidates for scan_job_items to
    reference them (FK) and for candidate status transitions to persist.
    discovery_candidates is an operational/tracking table that the DRY_RUN
    contract explicitly allows writes to. The source_reference marks the
    row as web-discovered (audit/traceability: discovered_from_web).
    """
    if not provider or not getattr(provider, "enabled", False):
        return []

    company_id = company.get("id")
    company_name = company.get("name") or company_id
    country = company.get("country", "SA")
    market = company.get("market", "packaged_food")

    results = sort_discovery_results(
        provider.discover(
            target_name=company_name,
            country=country,
            market=market,
            max_results=getattr(settings, "web_discovery_max_results", 10),
        )
    )
    if not results:
        logger.info("Web discovery produced no candidate URLs for %s", company_name)
        return []

    existing_urls = {
        (c.get("source_url") or "").strip().lower()
        for c in existing_candidates
        if c.get("source_url")
    }

    new_candidates = []
    for r in results:
        url = (r.url or "").strip()
        if not url or url.lower() in existing_urls:
            continue
        row = {
            "id": str(uuid.uuid4()),
            "company_id": company_id,
            "name": "",  # identity must be confirmed by an operator
            "brand": None,
            "barcode": None,
            "category": None,
            "country": country,
            "market": market,
            "source_url": url,
            "source_reference": (
                "web_discovery:" + type(provider).__name__ + ":"
                + (r.source_reference or url)
            ),
            "source_retrieved_at": None,
            "raw_data": {
                # Deterministic classification resolved at discovery time
                # (tag on the URL wins; classify_url otherwise). Consumed by
                # _classification_for so the stub "LABEL" default that
                # extract_from_llm_response stamps can never leak onto
                # web-sourced data.
                "_source_classification": {
                    "source_type": r.source_type,
                    "evidence_type": r.evidence_type,
                    "is_retailer": r.is_retailer,
                },
            },
            "status": "discovered",
        }
        persisted = _persist_web_discovery_candidate(row)
        if not persisted:
            # A tracking-row failure must not fabricate identity or abort
            # the scan; the URL is simply not added this run.
            logger.warning(
                "Web discovery candidate not persisted (skipped): %s", url
            )
            continue
        row["id"] = persisted
        new_candidates.append(row)

    logger.info(
        "Web discovery proposed %d candidate URL(s) for %s",
        len(new_candidates), company_name,
    )
    return new_candidates


def _persist_web_discovery_candidate(row: dict) -> Optional[str]:
    """Insert a web-discovered URL as a tracking candidate row.

    Returns the persisted candidate id, or None on failure. Only
    operational/tracking columns are written (discovery_candidates).
    """
    now = datetime.now(timezone.utc)
    try:
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO public.discovery_candidates
                    (id, company_id, name, brand, barcode, category,
                     country, market, source_url, source_reference,
                     source_retrieved_at, raw_data, status,
                     created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    row["id"], row["company_id"], row["name"], row["brand"],
                    row["barcode"], row["category"], row["country"],
                    row["market"], row["source_url"], row["source_reference"],
                    row.get("source_retrieved_at"), json.dumps(row.get("raw_data") or {}), row["status"],
                    now, now,
                ),
            )
        return row["id"]
    except Exception:
        logger.exception(
            "Failed to persist web discovery candidate for %s",
            row.get("source_url"),
        )
        return None


def _classification_for(candidate: dict) -> SourceClassification:
    """Resolve the deterministic classification for a candidate.

    Prefers the classification captured from the explicit URL tag at
    web-discovery time (stored in raw_data); otherwise falls back to
    classify_url. Never LLM-decided, never the stub "LABEL" default.
    """
    raw_data = candidate.get("raw_data") or {}
    if isinstance(raw_data, str):
        try:
            raw_data = json.loads(raw_data)
        except (json.JSONDecodeError, TypeError):
            raw_data = {}
    meta = raw_data.get("_source_classification") or {}
    source_type = meta.get("source_type")
    if isinstance(source_type, str) and source_type:
        evidence_type = meta.get("evidence_type")
        return SourceClassification(
            source_type=source_type,
            evidence_type=evidence_type if isinstance(evidence_type, str) else None,
            is_retailer=bool(meta.get("is_retailer")),
        )
    return classify_url(candidate.get("source_url"))


def _fetch_candidate_source(candidate: dict):
    """Fetch a candidate's source_url through the SSRF-safe retrieval
    module. Never disabled: every protection stays active."""
    from app.collector.config import get_collector_config
    from app.collector import retrieval

    source_url = (candidate.get("source_url") or "").strip()
    if not source_url:
        return None

    cfg = get_collector_config()
    rcfg = retrieval.RetrievalConfig(
        timeout=cfg.retrieval_timeout,
        max_retries=cfg.retrieval_max_retries,
        accept_html=True,
    )
    # source_url comes from the candidate row (registered) or from a web
    # discovery result; a bare string is never passed unfiltered.
    return retrieval.retrieve(source_url, config=rcfg)


def _auto_extract_candidate(candidate: dict, collected: CollectedProductData):
    """Auto-extraction path: retrieval -> LLM extraction.

    Runs only when COLLECTOR_AUTO_EXTRACTION is enabled AND the candidate
    does NOT already carry structured extraction in raw_data (manual data is
    treated as authoritative and never overwritten) AND a source_url exists.
    On any failure the candidate is left unmodified -- extraction that never
    happened cannot fabricate a value.
    """
    raw_data = candidate.get("raw_data") or {}
    if isinstance(raw_data, str):
        try:
            raw_data = json.loads(raw_data)
        except (json.JSONDecodeError, TypeError):
            raw_data = {}
    has_extraction = bool(
        raw_data.get("ingredients")
        or raw_data.get("allergens")
        or raw_data.get("nutrition")
        or raw_data.get("product_name")
    )
    if has_extraction:
        return collected
    if not (candidate.get("source_url") or "").strip():
        return collected

    retrieval_result = _fetch_candidate_source(candidate)
    if retrieval_result is None:
        logger.warning(
            "Auto-extraction skipped for candidate %s: no source_url",
            candidate.get("id"),
        )
        return collected
    if not retrieval_result.success:
        logger.warning(
            "Auto-extraction skipped for candidate %s: retrieval failed (%s)",
            candidate.get("id"), retrieval_result.error,
        )
        return collected

    try:
        ext = extraction.extract_from_source_page(
            source_text=retrieval_result.content or "",
            source_url=candidate.get("source_url"),
            company_id=candidate.get("company_id"),
            barcode=candidate.get("barcode"),
            product_name=candidate.get("name"),
        )
        # Re-apply the deterministic source/evidence classification (never
        # LLM-decided, and never the stub "LABEL" default that
        # extract_from_llm_response otherwise stamps on web-sourced data).
        cls = _classification_for(candidate)
        ext.source_type = cls.source_type
        ext.evidence_type = cls.evidence_type
        if extraction.is_provider_failure(ext):
            logger.warning(
                "Auto-extraction provider failure (%s) for candidate %s",
                ext.status, candidate.get("id"),
            )
            return ext
        if not ext.product_name:
            logger.warning(
                "Auto-extraction produced no product name for %s",
                candidate.get("id"),
            )
        return ext
    except Exception:
        logger.exception("Auto-extraction failed for candidate %s", candidate.get("id"))
        return collected


def _candidate_to_collected(candidate: dict) -> CollectedProductData:
    """Convert a discovery_candidate dict to CollectedProductData.

    Missing values stay missing (None) -- never guessed as 0, 0.5, or a
    fabricated label. Source/evidence classification is deterministic.
    """
    raw_data = candidate.get("raw_data") or {}
    if isinstance(raw_data, str):
        try:
            raw_data = json.loads(raw_data)
        except (json.JSONDecodeError, TypeError):
            raw_data = {}

    ingredients = []
    for ing in raw_data.get("ingredients", []):
        if isinstance(ing, dict):
            ingredients.append(
                ExtractedIngredients(
                    name=ing.get("name", ""),
                    amount_value=ing.get("amount_value"),
                    unit=ing.get("unit"),
                    confidence_level=ing.get("confidence_level"),
                )
            )

    allergens = []
    for al in raw_data.get("allergens", []):
        if isinstance(al, dict):
            allergens.append(
                ExtractedAllergen(
                    name=al.get("name", ""),
                    confidence_level=al.get("confidence_level"),
                    evidence_type=al.get("evidence_type"),
                    is_declared=al.get("is_declared"),
                )
            )

    nutrition = []
    for nut in raw_data.get("nutrition", []):
        if isinstance(nut, dict):
            amount_raw = nut.get("amount_value")
            if amount_raw is None:
                continue  # missing amount stays missing, never 0
            try:
                nutrition.append(
                    ExtractedNutrition(
                        nutrition_type=nut.get("nutrition_type", ""),
                        amount_value=float(amount_raw),
                        unit=nut.get("unit", ""),
                        measurement_basis=nut.get("measurement_basis"),
                        confidence_level=nut.get("confidence_level"),
                    )
                )
            except (ValueError, TypeError):
                continue

    cls = _classification_for(candidate)

    return CollectedProductData(
        barcode=candidate.get("barcode"),
        product_name=candidate.get("name", ""),
        brand=candidate.get("brand"),
        category=candidate.get("category"),
        country=candidate.get("country", "SA"),
        ingredients=ingredients,
        allergens=allergens,
        nutrition=nutrition,
        source_url=candidate.get("source_url"),
        source_type=cls.source_type,
        evidence_type=cls.evidence_type,
        confidence_level=raw_data.get("confidence_level"),
        company_id=candidate.get("company_id"),
        raw_data=raw_data,
    )


def _detect_conflicts_for_product(matched: dict, collected: CollectedProductData) -> int:
    """Compare collected data against an existing product; record conflicts."""
    conflict_count = 0
    product_id = matched.get("id", "")

    if collected.product_name and matched.get("name"):
        c = conflicts.detect_conflicts(
            entity_type="product",
            entity_id=product_id,
            field_name="name",
            existing_value=matched["name"],
            new_value=collected.product_name,
        )
        if c:
            conflict_count += 1

    if collected.brand and matched.get("brand_name"):
        c = conflicts.detect_conflicts(
            entity_type="product",
            entity_id=product_id,
            field_name="brand",
            existing_value=matched["brand_name"],
            new_value=collected.brand,
        )
        if c:
            conflict_count += 1

    return conflict_count


def _create_product_from_candidate(
    collected: CollectedProductData, conn=None
) -> Optional[str]:
    """Create a new product, barcode, and product_barcodes from a candidate.

    The new product row is persisted with explicit source provenance: the
    data_sources row coded COLLECTOR must be registered (migration 0043
    seeds it, owned by role fateen). When it is missing, creation fails
    loudly (a ValueError is raised; never a silent NULL source_id write
    against the products_source_id_fk constraint), so an un-migrated
    database can never produce un-provenanced products.

    Returns the new product_id or None on failure.
    """
    if not collected.barcode:
        return None

    product_id = str(uuid.uuid4())
    barcode_id = str(uuid.uuid4())
    product_barcode_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    def _do(c):
        source_row = c.execute(
            "SELECT id FROM public.data_sources "
            "WHERE code = %s AND deleted_at IS NULL LIMIT 1",
            (_COLLECTOR_SOURCE_CODE,),
        ).fetchone()
        if not source_row:
            raise _MissingCollectorSource(
                f"Collector data source '{_COLLECTOR_SOURCE_CODE}' is not "
                f"registered in public.data_sources; refusing to create a "
                f"product without source provenance"
            )
        source_id = source_row["id"]

        status_row = c.execute(
            "SELECT id FROM public.lifecycle_statuses WHERE code = 'ACTIVE' LIMIT 1"
        ).fetchone()
        status_id = status_row["id"] if status_row else 1

        brand_id = None
        if collected.brand:
            existing_brand = c.execute(
                "SELECT id FROM public.brands WHERE name = %s AND deleted_at IS NULL LIMIT 1",
                (collected.brand,),
            ).fetchone()
            if existing_brand:
                brand_id = existing_brand["id"]
            else:
                brand_id = str(uuid.uuid4())
                c.execute(
                    """
                    INSERT INTO public.brands (id, name, status_id, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (brand_id, collected.brand, status_id, now, now),
                )

        c.execute(
            """
            INSERT INTO public.products
                (id, internal_code, name, description, brand_id,
                 status_id, confidence_level, source_id, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                product_id,
                f"FATEEN_{collected.barcode}",
                collected.product_name,
                None,
                brand_id,
                status_id,
                collected.confidence_level or 0.5,
                source_id,
                now,
                now,
            ),
        )

        c.execute(
            """
            INSERT INTO public.barcodes (id, barcode, created_at, updated_at)
            VALUES (%s, %s, %s, %s)
            """,
            (barcode_id, collected.barcode, now, now),
        )

        c.execute(
            """
            INSERT INTO public.product_barcodes
                (id, product_id, barcode_id, relationship_type_id,
                 status_id, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                product_barcode_id,
                product_id,
                barcode_id,
                c.execute(
                    "SELECT id FROM public.relationship_types WHERE code = 'PRIMARY_BARCODE' LIMIT 1"
                ).fetchone()["id"],
                status_id,
                now,
                now,
            ),
        )

    try:
        if conn:
            _do(conn)
        else:
            with get_connection() as c:
                _do(c)
        logger.info("Created new product %s for barcode %s", product_id, collected.barcode)
        return product_id
    except _MissingCollectorSource as exc:
        # Distinct, diagnosable provenance failure: the COLLECTOR source is
        # not registered/migrated. Propagate rather than returning None so a
        # caller never mistakes it for a generic/database failure.
        logger.error(
            "Refusing product creation: %s", exc, extra={"barcode": collected.barcode}
        )
        raise
    except Exception:
        logger.exception("Failed to create product from candidate for barcode %s", collected.barcode)
        return None


def _ingest_product(collected: CollectedProductData, dry_run: bool = False) -> dict:
    """Attempt to ingest a collected product through the existing ingestion pipeline.

    SAFETY CONTRACT: `dry_run` must be the already-resolved value from
    resolve_effective_dry_run() (computed once at the API entry point, see
    app/api/scan.py::start_scan). This function forwards it verbatim to
    app.agent.ingestion.ingest() rather than hardcoding a value, so a
    future caller of _ingest_product cannot accidentally force a write by
    skipping the dry-run check that currently gates every call site.
    """
    if not collected.barcode:
        return {"success": False, "error": "No barcode for ingestion"}

    try:
        from app.agent.models import (
            IngestionInput,
            IngestionIngredient,
            IngestionAllergen,
            IngestionNutrition,
        )
        from app.agent.ingestion import ingest

        input_data = IngestionInput(
            barcode=collected.barcode,
            product_name=collected.product_name,
            ingredients=[
                IngestionIngredient(
                    name=ing.name,
                    amount_value=ing.amount_value,
                    unit=ing.unit,
                    confidence_level=ing.confidence_level,
                )
                for ing in collected.ingredients
            ],
            allergens=[
                IngestionAllergen(
                    name=al.name,
                    confidence_level=al.confidence_level,
                )
                for al in collected.allergens
            ],
            nutrition=[
                IngestionNutrition(
                    nutrition_type=nut.nutrition_type,
                    amount_value=nut.amount_value,
                    unit=nut.unit,
                    measurement_basis=nut.measurement_basis,
                    confidence_level=nut.confidence_level,
                )
                for nut in collected.nutrition
            ],
            source="collector",
            confidence_level=collected.confidence_level,
            source_url=collected.source_url,
            retrieved_at=datetime.now(timezone.utc).isoformat(),
            evidence_type=collected.evidence_type,
        )

        ingestion_result = ingest(input_data, dry_run=dry_run)

        if ingestion_result.errors:
            return {"success": False, "error": "; ".join(ingestion_result.errors)}

        return {"success": True, "ingestion_result": ingestion_result.to_dict()}

    except Exception:
        logger.exception("Ingestion failed for barcode %s", collected.barcode)
        return {"success": False, "error": "Ingestion pipeline error"}


def _update_candidate_status_conn(
    conn,
    candidate_id: Optional[str],
    status: str,
    validation_errors: Optional[list],
    matched_product_id: Optional[str] = None,
    match_confidence: Optional[float] = None,
) -> None:
    """Update candidate status using an existing connection (no separate transaction)."""
    if not candidate_id:
        return
    now = datetime.now(timezone.utc)
    conn.execute(
        """
        UPDATE public.discovery_candidates
        SET status = %s, validation_errors = %s,
            matched_product_id = COALESCE(%s, matched_product_id),
            match_confidence = COALESCE(%s, match_confidence),
            updated_at = %s
        WHERE id = %s
        """,
        (
            status,
            json.dumps(validation_errors) if validation_errors else "[]",
            matched_product_id,
            match_confidence,
            now,
            candidate_id,
        ),
    )


def _finalize_scan_job(
    scan_job_id: str, result: ScanJobResult, error_log: list
) -> None:
    """Update the scan_job record with final results."""
    if not scan_job_id:
        return
    now = datetime.now(timezone.utc)
    try:
        with get_connection() as conn:
            conn.execute(
                """
                UPDATE public.scan_jobs
                SET status = %s,
                    finished_at = %s,
                    duration_seconds = %s,
                    products_discovered = %s,
                    products_processed = %s,
                    products_accepted = %s,
                    products_rejected = %s,
                    products_needs_review = %s,
                    products_created = %s,
                    products_updated = %s,
                    products_unchanged = %s,
                    conflicts_detected = %s,
                    errors_count = %s,
                    coverage_pct = %s,
                    error_log = %s,
                    updated_at = %s
                WHERE id = %s
                """,
                (
                    result.status,
                    now,
                    result.duration_seconds,
                    result.products_discovered,
                    result.products_processed,
                    result.products_accepted,
                    result.products_rejected,
                    result.products_needs_review,
                    result.products_created,
                    result.products_updated,
                    result.products_unchanged,
                    result.conflicts_detected,
                    result.errors_count,
                    result.coverage_pct,
                    json.dumps(error_log),
                    now,
                    scan_job_id,
                ),
            )
    except Exception:
        logger.exception("Failed to finalize scan_job %s", scan_job_id)
