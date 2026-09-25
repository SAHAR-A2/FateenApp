"""STEP A: batch orchestrator with checkpointing, retries and rate limiting.

File-backed (checkpoint per run, JSON in `.sfda_batch/`), dry-run/live mode
through the single `resolve_effective_dry_run` safety contract, resumable via
`--resume <run_id>`. No database migration is required for the orchestrator.
"""
import logging
import time
from pathlib import Path
from typing import Callable, Optional

from app.batch.checkpoint import create_run, load_run, save_run
from app.batch.models import BatchRun, Candidate, CandidateStatus
from app.batch.quarantine import SfdaQuarantine
from app.batch.pipeline import process_candidate
from app.core.config import resolve_effective_dry_run

logger = logging.getLogger("fateen.batch.orchestrator")


def _default_inserter(candidate: Candidate, dry_run: bool):
    """Default trusted-path inserter -> ingest(dry_run=...).

    Reused by tests and the CLI as the production insert/quarantine boundary.
    Imported lazily so offline module import never forces DB wiring.
    """
    from app.agent.ingestion import ingest
    from app.batch.pipeline import build_ingestion_input

    return ingest(build_ingestion_input(candidate), dry_run=dry_run)


class SfdaBatchOrchestrator:
    def __init__(
        self,
        mode: str = "dry-run",
        batch_size: int = 10,
        checkpoint_dir: str | Path = ".sfda_batch",
        max_retries: int = 3,
        rate_limit_rps: float = 1.0,
        retry_backoff_seconds: float = 1.0,
        conn=None,
    ):
        self.mode = mode
        self.live = mode == "live"
        self.batch_size = max(1, int(batch_size))
        self.checkpoint_dir = Path(checkpoint_dir)
        self.max_retries = max(0, int(max_retries))
        self.rate_limit_rps = max(0.0, float(rate_limit_rps))
        self.retry_backoff_seconds = max(0.0, float(retry_backoff_seconds))
        self.conn = conn
        self._min_interval = (1.0 / self.rate_limit_rps) if self.rate_limit_rps else 0.0
        self._last_call = 0.0

    # -- publishing ---------------------------------------------------------

    def publish(self, run: BatchRun, candidates: list[Candidate], quarantine: SfdaQuarantine) -> BatchRun:
        """Store the working state of every candidate plus quarantine records."""
        run.total = len(candidates)
        run.candidates = {
            c.candidate_id: {
                "identifier": c.identifier,
                "mode": c.mode.value,
                "status": c.status.value,
                "barcode": c.barcode,
                "trade_name": c.trade_name,
                "unresolved_ingredients": c.unresolved_ingredients,
                "rejection_reasons": c.rejection_reasons,
                "validation_errors": c.validation_errors,
                "processed_at": c.processed_at,
            }
            for c in candidates
        }
        run.quarantine = quarantine.records()
        run.updated_at = run.updated_at
        return run

    # -- rate limit ---------------------------------------------------------

    def _throttle(self) -> None:
        if self._min_interval <= 0:
            return
        elapsed = time.monotonic() - self._last_call
        delay = self._min_interval - elapsed
        if delay > 0:
            time.sleep(delay)
        self._last_call = time.monotonic()

    # -- run -----------------------------------------------------------------

    def run(
        self,
        candidates: list[Candidate],
        fetcher,
        resolver: Callable,
        quarantine: SfdaQuarantine,
        inserter: Optional[Callable] = None,
        active_dry_run: Optional[bool] = None,
    ) -> BatchRun:
        """Process candidates; saves a checkpoint after each one.

        Semantics of `dry_run`: the batch mode and the environment agree via
        `resolve_effective_dry_run`. Live writes REQUIRE both the sender to
        choose `live` AND the environment AGENT_DRY_RUN=false.
        """
        dry_run = resolve_effective_dry_run(
            active_dry_run if active_dry_run is not None else (not self.live)
        )
        run = create_run(self.mode, self.batch_size, self.checkpoint_dir)
        run.mode = self.mode
        run.total = len(candidates)
        run.notes.append(
            f"effective dry_run={dry_run} (mode={self.mode}, AGENT_DRY_RUN gate applied)"
        )

        processed_ids = set()
        for idx, candidate in enumerate(candidates):
            if candidate.candidate_id in processed_ids:
                continue
            if candidate.status in (CandidateStatus.INSERTED, CandidateStatus.QUARANTINED):
                candidate.status = CandidateStatus.SKIPPED  # resume: already handled
            self._throttle()

            record, error = self._fetch_with_retry(fetcher, candidate)
            if error is not None:
                candidate.unresolved_ingredients = []
                candidate.rejection_reasons.append("fetch_failed")
                candidate.validation_errors.append(error)
                candidate.status = CandidateStatus.FAILED
            else:
                # The DB-backed inserter only runs on the real write path;
                # dry-run resolves+validates and proves INSERTED/QUARANTINED
                # decisions fully offline (no fabricated data, no DB contact).
                active_inserter = (inserter or _default_inserter) if not dry_run else None
                candidate = process_candidate(
                    candidate,
                    record,
                    resolver,
                    quarantine,
                    inserter=active_inserter,
                    conn=self.conn,
                    dry_run=dry_run,
                )

            processed_ids.add(candidate.candidate_id)
            self._tally(run, candidate)
            self.publish(run, candidates, quarantine)
            save_run(run, self.checkpoint_dir)
        return run

    def resume(self, run_id: str) -> BatchRun:
        """Not yet resumed runs rebuild candidates from the checkpoint."""
        run = load_run(run_id, self.checkpoint_dir)
        if run is None:
            raise FileNotFoundError(f"no checkpoint for run {run_id}")
        logger.info("resume target loaded: %s (processed=%d)", run_id, run.processed)
        return run

    def _fetch_with_retry(self, fetcher, candidate: Candidate):
        last_error = None
        for attempt in range(self.max_retries + 1):
            candidate.attempts += 1
            try:
                record, error = fetcher.fetch(candidate)
                if error is None:
                    return record, None
                last_error = error
            except Exception as exc:
                last_error = str(exc)
            if attempt < self.max_retries:
                time.sleep(self.retry_backoff_seconds * (attempt + 1))
        return None, last_error

    @staticmethod
    def _tally(run: BatchRun, candidate: Candidate) -> None:
        run.processed += 1
        status = candidate.status
        if status == CandidateStatus.INSERTED:
            run.inserted += 1
        elif status == CandidateStatus.QUARANTINED:
            run.quarantined += 1
        elif status == CandidateStatus.FAILED:
            run.failed += 1
        elif status == CandidateStatus.SKIPPED:
            run.skipped += 1