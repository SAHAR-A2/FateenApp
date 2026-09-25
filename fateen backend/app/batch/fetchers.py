"""Fetch stage for the SFDA batch pipeline.

Two fetchers share the same interface so the orchestrator is auth-independent:

  * FixtureFetcher  -> offline (no network); serves sanitized SFDA-shaped
                       records for dry-run/fixture tests.
  * SfdaFetcher     -> live; wraps the contract-faithful SfdaFoodAdapter. It
                       inherits the adapter's credential gate: with no
                       SFDA_ACCESS_TOKEN / SFDA_API_KEY it raises
                       SfdaAuthenticationRequired BEFORE any request, so the
                       live mode can never fire unauthenticated requests while
                       a credential is missing.

Every fetch returns a (record, error) tuple: `record` when the documented
response gave exactly one product, `error` otherwise. Ambiguity (multiple
records for an identifier) is surfaced as an error so the caller records it in
data_conflicts instead of silently picking.
"""
import logging
from typing import Optional

from app.batch.models import Candidate, CandidateMode
from app.integrations.sfda_food_adapter import (
    SfdaAuthenticationRequired,
    SfdaFoodAdapter,
)

logger = logging.getLogger("fateen.batch.fetchers")


class FixtureFetcher:
    """Offline fetcher serving sanitized SFDA-shaped records (no network)."""

    def __init__(self, records: Optional[dict] = None):
        # Maps identifier -> SfdaProductRecord (built from an SFDA fixture).
        self._records = records or {}

    def fetch(self, candidate: Candidate):
        if candidate.identifier not in self._records:
            return None, "no fixture record for identifier"
        return self._records[candidate.identifier], None


class SfdaFetcher:
    """Live fetcher wrapping the verified SFDA adapter (credential-gated)."""

    def __init__(self, adapter: Optional[SfdaFoodAdapter] = None):
        self.adapter = adapter if adapter is not None else SfdaFoodAdapter()

    def fetch(self, candidate: Candidate):
        mode = candidate.mode
        try:
            if mode == CandidateMode.BARCODE:
                return self.adapter.fetch_by_barcode(candidate.identifier), None
            if mode == CandidateMode.REFERENCE:
                return self.adapter.fetch_by_reference_number(candidate.identifier), None
            if mode == CandidateMode.SEARCH:
                records, _ = self.adapter.search_by_keyword(candidate.identifier)
                return self._select_one(records)
            if mode == CandidateMode.FIRS_LIST:
                records, _ = self.adapter.firs_food_list(page=_as_page(candidate.identifier))
                return self._select_one(records)
            if mode == CandidateMode.FIRS_SEARCH:
                records, _ = self.adapter.firs_food_search(keyword=candidate.identifier)
                return self._select_one(records)
            if mode == CandidateMode.LIST:
                records, _ = self.adapter.list_page(page=_as_page(candidate.identifier))
                return self._select_one(records)
            return None, f"unsupported fetch mode: {mode}"
        except SfdaAuthenticationRequired:
            # No credential configured -> no network call was attempted.
            raise
        except Exception as exc:  # transport / payload / validation errors
            return None, str(exc)

    @staticmethod
    def _select_one(records):
        if not records:
            return None, "no record found"
        if len(records) > 1:
            # Ambiguity is recorded by the caller (data_conflicts), never
            # silently resolved with an arbitrary pick.
            return None, f"ambiguous: {len(records)} records for one identifier"
        return records[0], None


def _as_page(value: str) -> int:
    try:
        page = int(value)
    except (TypeError, ValueError):
        page = 1
    return page if page >= 1 else 1


def build_fetcher(live: bool, fixture_records: Optional[dict] = None):
    """Fetcher for the requested mode.

    `live=False` may serve fixture records (offline dry-run). `live=True`
    ALWAYS returns the real credential-gated adapter.
    """
    if live:
        return SfdaFetcher()
    return FixtureFetcher(records=fixture_records)