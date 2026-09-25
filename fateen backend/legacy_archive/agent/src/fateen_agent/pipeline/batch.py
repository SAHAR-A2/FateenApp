"""Batch processor: runs the orchestrator over many products with retry,
rate limiting, checkpointing and reporting. One product failure never stops
the batch.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Callable, Iterable, Optional

from ..constants import AGENT_STATUSES
from ..models import BatchSummary, ProductOutcome
from ..reporting import summarize
from ..sources.base import ProductQuery

logger = logging.getLogger(__name__)


@dataclass
class BatchResult:
    summary: BatchSummary
    outcomes: list[ProductOutcome]
    batch_id: Optional[str] = None


class BatchProcessor:
    """Processes a list of product queries with bounded concurrency."""

    def __init__(
        self,
        process_one: Callable[[ProductQuery, str, str], ProductOutcome],
        batch_label: str = "batch",
        batch_id: Optional[str] = None,
        workers: int = 1,
        retries: int = 1,
        rate_limit_per_sec: float = 2.0,
        skip_processed: bool = True,
        processed_check: Optional[Callable[[str, str], bool]] = None,
        record_batch_item: Optional[Callable[[Optional[str], ProductOutcome], None]] = None,
    ):
        self.process_one = process_one
        self.batch_label = batch_label
        self.batch_id = batch_id
        self.workers = max(1, workers)
        self.retries = retries
        self.rate_limit = 1.0 / max(rate_limit_per_sec, 0.1)
        self.skip_processed = skip_processed
        self.processed_check = processed_check
        self.record_batch_item = record_batch_item

    def run(self, queries: list[tuple[ProductQuery, str, str]]) -> BatchResult:
        outcomes: list[ProductOutcome] = []
        started = time.monotonic()

        for query, product_key, key_type in queries:
            if self.skip_processed and self.processed_check and self.processed_check(product_key, key_type):
                logger.info("Skipping already-processed product: %s", product_key)
                continue
            outcome = self._process_with_retry(query, product_key, key_type)
            outcomes.append(outcome)
            if self.record_batch_item:
                try:
                    self.record_batch_item(self.batch_id, outcome)
                except Exception:  # noqa: BLE001
                    logger.exception("Could not record batch item for %s", product_key)
            time.sleep(self.rate_limit)  # polite rate limiting across sources

        summary = summarize(self.batch_label, outcomes)
        summary.finished_at = None
        logger.info(
            "Batch %s finished in %.1fs: %s",
            self.batch_label,
            time.monotonic() - started,
            {s: sum(1 for o in outcomes if o.status == s) for s in AGENT_STATUSES},
        )
        return BatchResult(summary=summary, outcomes=outcomes, batch_id=self.batch_id)

    def _process_with_retry(self, query: ProductQuery, product_key: str, key_type: str) -> ProductOutcome:
        last: Optional[ProductOutcome] = None
        for attempt in range(max(1, self.retries + 1)):
            outcome = self.process_one(query, product_key, key_type)
            if outcome.status != "FAILED":
                return outcome
            last = outcome
            if attempt < self.retries:
                backoff = (attempt + 1) * 2.0
                logger.info("Retry %d for %s in %.1fs", attempt + 1, product_key, backoff)
                time.sleep(backoff)
        return last  # type: ignore[return-value]
