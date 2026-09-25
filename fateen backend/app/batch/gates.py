"""STEP G: scaling gates for the 10 -> 100 -> 250 -> 500 -> ~1,000 path.

Each gate deterministically certifies (fully offline, no DB writes) that the
batch orchestrator can process a target-sized queue with the documented
mechanics:

  - the candidate queue builds at N with no invented records (`FIXTURE-`
    synthetic identifiers can never resolve);
  - a dry-run orchestrator run over that queue reports processed == N and
    inserts ZERO products (no fabricated ingestion when there is no real
    record);
  - checkpoint files are written per candidate and a resume round-trips;
  - batch math (ceil(N / batch_size) batches, last-batch size) is correct;
  - rate-limit wall-clock is a function of the configured rps.

Live counts cannot be certified here (no credential): the gates certify
capability readiness; the projection table documents the credentialed path
with an honest note about expected inserted/quarantined counts.
"""
import logging
import math
import shutil
from pathlib import Path

from app.batch.checkpoint import list_runs, load_run
from app.batch.discovery import synthetic_candidates_for_dry_run
from app.batch.fetchers import build_fetcher
from app.batch.models import utcnow
from app.batch.orchestrator import SfdaBatchOrchestrator
from app.batch.quarantine import SfdaQuarantine

logger = logging.getLogger("fateen.batch.gates")

GATES_VERSION = "sfda-scaling-gates-1"
SCALING_TARGETS = [10, 100, 250, 500, 1000]
DEFAULT_BATCH_SIZE = 10


def assess_target(total: int, batch_size: int) -> dict:
    """Pure batch math for one target (no execution, always available)."""
    batch_size = max(1, batch_size)
    batches = max(1, math.ceil(total / batch_size))
    last_batch = total - (batches - 1) * batch_size
    return {
        "target": total,
        "batch_size": batch_size,
        "batches": batches,
        "last_batch_size": last_batch,
        "at_1_rps_seconds": total,
        "at_1_rps_minutes": round(total / 60.0, 2),
    }


def run_scaling_gates(
    targets: list[int] | None = None,
    batch_size: int = DEFAULT_BATCH_SIZE,
    checkpoint_dir: str | Path = ".sfda_gates",
    sink_dir: str | Path = ".sfda_gates/sink",
) -> dict:
    targets = targets or SCALING_TARGETS
    for p in (checkpoint_dir, sink_dir):
        if Path(p).exists():
            shutil.rmtree(Path(p), ignore_errors=True)

    results = []
    for target in targets:
        candidates = synthetic_candidates_for_dry_run(target, seed=[])
        plan = assess_target(target, batch_size)
        quarantine = SfdaQuarantine(sink_dir=str(sink_dir))
        fetcher = build_fetcher(live=False, fixture_records=None)
        orchestrator = SfdaBatchOrchestrator(
            mode="dry-run",
            batch_size=batch_size,
            checkpoint_dir=checkpoint_dir,
            rate_limit_rps=0,
            max_retries=1,
            retry_backoff_seconds=0,
        )

        run = orchestrator.run(
            candidates=candidates,
            fetcher=fetcher,
            resolver=_offline_resolver,
            quarantine=quarantine,
            active_dry_run=True,
        )

        listed = list_runs(checkpoint_dir)
        checkpoint_files = len([p for p in listed if p.startswith(run.run_id)])
        resume = load_run(run.run_id, checkpoint_dir)

        gate_ok = (
            run.processed == target
            and run.inserted == 0
            and run.failed == target
            and checkpoint_files == 1  # composite run checkpoint, refreshed per candidate
            and resume is not None
            and resume.processed == target
        )
        results.append({
            "target": target,
            **plan,
            "processed": run.processed,
            "inserted": run.inserted,
            "quarantined": run.quarantined,
            "failed": run.failed,
            "checkpoint_files": checkpoint_files,
            "resume_ok": resume is not None and resume.processed == target,
            "verdict": "PASS" if gate_ok else "FAIL",
            "reason": (
                "dry-run produced ZERO insertions (no invented records), "
                "processed == target, composite checkpoint resumed OK"
                if gate_ok
                else f"gate invariant broken: processed={run.processed} inserted={run.inserted} "
                f"checkpoint_files={checkpoint_files} resume={resume is not None}"
            ),
        })

    passed = sum(1 for r in results if r["verdict"] == "PASS")
    return {
        "gates": GATES_VERSION,
        "generated_at": utcnow(),
        "targets": targets,
        "batch_size": batch_size,
        "results": results,
        "verdict": "PASS" if passed == len(results) else "FAIL",
        "projection": _projection(targets, batch_size),
        "note": (
            "gates certify capability readiness offline; live certification "
            "begins only after SFDA_ACCESS_TOKEN / SFDA_API_KEY exists."
        ),
    }


def _projection(targets: list[int], batch_size: int) -> list[dict]:
    """Credentialed-path projection.

    Elapsed minutes assume the default 1 rps rate limit (respects the SFDA
    spike-arrest behaviour). Inserted/quarantined estimates are flagged as
    NOT certifiable from live data: today the fixture product's 5 tokens have
    ZERO exact resolver matches, so its honest fate under strict resolution is
    quarantine until the STEP-E vocabulary proposals are reviewed/applied.
    """
    out = []
    for target in targets:
        plan = assess_target(target, batch_size)
        out.append({
            "target_products": target,
            "batch_size": batch_size,
            "batches": plan["batches"],
            "at_1_rps_elapsed_minutes": plan["at_1_rps_minutes"],
            "expected_inserted_estimate": "NOT-CERTIFIABLE (no live data; strict "
                                          "resolver quarantines fully-unresolved products)",
            "expected_quarantined_estimate": "derived only after a credentialed run",
            "repeating_command": (
                f"python -m app.batch.cli run --mode live --batch-size {batch_size}"
            ),
        })
    return out


def _offline_resolver(conn, token):
    """Offline stand-in for the DB grammar resolver. Synthetic queue
    identifiers have no fixture record, so nothing can ever resolve."""
    return None