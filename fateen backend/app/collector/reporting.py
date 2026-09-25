"""P33: Reporting.

Generates human-readable and machine-readable scan reports.
Never logs secrets or sensitive data.
"""
import json
import logging
from datetime import datetime, timezone
from typing import Optional

from app.db.connection import get_connection
from app.collector.models import ScanJobResult, ScanStatus

logger = logging.getLogger("fateen.collector.reporting")

STATUS_LABELS = {
    ScanStatus.PENDING: "Pending",
    ScanStatus.IN_PROGRESS: "In Progress",
    ScanStatus.COMPLETED: "Completed",
    ScanStatus.PARTIAL: "Partially Completed",
    ScanStatus.FAILED: "Failed",
    ScanStatus.BLOCKED: "Blocked",
}


def generate_scan_report(scan_job_id: str) -> dict:
    """Generate a report dict for a scan job.

    Returns a machine-readable dict with nested sections. All fields use
    safe error handling and never log secrets.
    """
    report: dict = {
        "scan_job_id": scan_job_id,
        "status": "error",
        "summary": {},
        "products": {},
        "quality": {},
        "coverage": {},
        "errors": [],
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        with get_connection() as conn:
            job = conn.execute(
                """
                SELECT id, company_id, scan_type, status,
                       started_at, finished_at, duration_seconds,
                       products_discovered, products_processed,
                       products_accepted, products_rejected,
                       products_needs_review, products_created,
                       products_updated, products_unchanged,
                       conflicts_detected, errors_count,
                       coverage_pct, error_log, metadata,
                       created_at, updated_at
                FROM public.scan_jobs
                WHERE id = %s
                """,
                (scan_job_id,),
            ).fetchone()

            if job is None:
                report["status"] = "not_found"
                report["errors"].append("Scan job not found")
                return report

            job = dict(job)

            company = conn.execute(
                "SELECT id, name, internal_code FROM public.companies WHERE id = %s",
                (job["company_id"],),
            ).fetchone()
            company = dict(company) if company else {"name": "UNKNOWN"}

            items = conn.execute(
                """
                SELECT id, candidate_id, product_id, barcode,
                       status, action, error_message, processed_at
                FROM public.scan_job_items
                WHERE scan_job_id = %s
                ORDER BY created_at ASC
                """,
                (scan_job_id,),
            ).fetchall()
            items = [dict(r) for r in items]

    except Exception:
        logger.exception("Failed to load scan_job %s for report", scan_job_id)
        report["status"] = "error"
        report["errors"].append("Failed to load scan job data")
        return report

    status_raw = job.get("status", "unknown")
    status_label = STATUS_LABELS.get(status_raw, status_raw.replace("_", " ").title())

    report["status"] = "ok"
    report["summary"] = {
        "scan_job_id": scan_job_id,
        "company_id": job["company_id"],
        "company_name": company.get("name", "UNKNOWN"),
        "scan_type": job.get("scan_type", "unknown"),
        "status": status_raw,
        "status_label": status_label,
        "started_at": _iso(job.get("started_at")),
        "finished_at": _iso(job.get("finished_at")),
        "duration_seconds": job.get("duration_seconds"),
    }

    report["products"] = {
        "discovered": job.get("products_discovered", 0),
        "processed": job.get("products_processed", 0),
        "accepted": job.get("products_accepted", 0),
        "rejected": job.get("products_rejected", 0),
        "needs_review": job.get("products_needs_review", 0),
        "created": job.get("products_created", 0),
        "updated": job.get("products_updated", 0),
        "unchanged": job.get("products_unchanged", 0),
    }

    report["quality"] = {
        "conflicts_detected": job.get("conflicts_detected", 0),
        "errors_count": job.get("errors_count", 0),
    }

    report["coverage"] = {
        "coverage_pct": job.get("coverage_pct"),
    }

    raw_error_log = job.get("error_log")
    if isinstance(raw_error_log, str):
        try:
            raw_error_log = json.loads(raw_error_log)
        except (json.JSONDecodeError, TypeError):
            raw_error_log = []
    if not isinstance(raw_error_log, list):
        raw_error_log = []

    report["errors"] = raw_error_log

    item_summary = {
        "total": len(items),
        "accepted": sum(1 for i in items if i.get("action") == "accepted"),
        "rejected": sum(1 for i in items if i.get("action") == "rejected"),
        "needs_review": sum(1 for i in items if i.get("action") == "needs_review"),
        "validation_failed": sum(
            1 for i in items if i.get("status") == "validation_failed"
        ),
    }
    report["items"] = item_summary

    return report


def format_report_text(report_dict: dict) -> str:
    """Format a report dict into a human-readable string.

    All fields use safe access. No secrets are logged.
    """
    if report_dict.get("status") == "not_found":
        return "Scan Job Not Found"
    if report_dict.get("status") == "error":
        errs = "; ".join(report_dict.get("errors", ["Unknown error"]))
        return f"Report Error: {errs}"

    lines = []

    summary = report_dict.get("summary", {})
    lines.append("=" * 60)
    lines.append("FATEEN Scan Report")
    lines.append("=" * 60)
    lines.append(f"  Scan Job ID  : {summary.get('scan_job_id', 'N/A')}")
    lines.append(f"  Company      : {summary.get('company_name', 'N/A')}")
    lines.append(f"  Scan Type    : {summary.get('scan_type', 'N/A')}")
    lines.append(f"  Status       : {summary.get('status_label', 'N/A')}")
    lines.append(f"  Started At   : {summary.get('started_at', 'N/A')}")
    lines.append(f"  Finished At  : {summary.get('finished_at', 'N/A')}")
    lines.append(f"  Duration     : {_fmt_duration(summary.get('duration_seconds'))}")
    lines.append("")

    products = report_dict.get("products", {})
    lines.append("-" * 60)
    lines.append("Product Metrics")
    lines.append("-" * 60)
    lines.append(f"  Discovered    : {products.get('discovered', 0)}")
    lines.append(f"  Processed     : {products.get('processed', 0)}")
    lines.append(f"  Accepted      : {products.get('accepted', 0)}")
    lines.append(f"  Rejected      : {products.get('rejected', 0)}")
    lines.append(f"  Needs Review  : {products.get('needs_review', 0)}")
    lines.append(f"  Created       : {products.get('created', 0)}")
    lines.append(f"  Updated       : {products.get('updated', 0)}")
    lines.append(f"  Unchanged     : {products.get('unchanged', 0)}")
    lines.append("")

    quality = report_dict.get("quality", {})
    lines.append("-" * 60)
    lines.append("Data Quality")
    lines.append("-" * 60)
    lines.append(f"  Conflicts Detected : {quality.get('conflicts_detected', 0)}")
    lines.append(f"  Errors             : {quality.get('errors_count', 0)}")
    lines.append("")

    coverage = report_dict.get("coverage", {})
    lines.append("-" * 60)
    lines.append("Coverage")
    lines.append("-" * 60)
    cov_pct = coverage.get("coverage_pct")
    lines.append(f"  Overall Coverage : {_fmt_pct(cov_pct)}")
    lines.append("")

    items = report_dict.get("items", {})
    if items:
        lines.append("-" * 60)
        lines.append("Item Breakdown")
        lines.append("-" * 60)
        lines.append(f"  Total Items         : {items.get('total', 0)}")
        lines.append(f"  Accepted            : {items.get('accepted', 0)}")
        lines.append(f"  Rejected            : {items.get('rejected', 0)}")
        lines.append(f"  Needs Review        : {items.get('needs_review', 0)}")
        lines.append(f"  Validation Failed   : {items.get('validation_failed', 0)}")
        lines.append("")

    errors = report_dict.get("errors", [])
    if errors:
        lines.append("-" * 60)
        lines.append("Error Log")
        lines.append("-" * 60)
        for i, err in enumerate(errors, 1):
            if isinstance(err, dict):
                ts = err.get("timestamp", "")
                msg = err.get("error", str(err))
                name = err.get("candidate_name", "")
                lines.append(f"  {i}. [{ts}] {name}: {msg}")
            else:
                lines.append(f"  {i}. {err}")
        lines.append("")

    lines.append("=" * 60)
    lines.append(f"Report generated at: {report_dict.get('generated_at', 'N/A')}")
    lines.append("=" * 60)

    return "\n".join(lines)


def _iso(dt) -> Optional[str]:
    """Safely convert a datetime to ISO string."""
    if dt is None:
        return None
    if isinstance(dt, datetime):
        return dt.isoformat()
    return str(dt)


def _fmt_duration(seconds: Optional[float]) -> str:
    """Format duration in seconds to a human-readable string."""
    if seconds is None:
        return "N/A"
    if seconds < 60:
        return f"{seconds:.1f}s"
    minutes = int(seconds // 60)
    secs = seconds % 60
    return f"{minutes}m {secs:.1f}s"


def _fmt_pct(pct: Optional[float]) -> str:
    """Format a percentage value."""
    if pct is None:
        return "UNKNOWN"
    return f"{pct:.1f}%"
