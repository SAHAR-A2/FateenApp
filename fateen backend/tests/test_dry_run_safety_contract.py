"""
Dry-run safety contract tests.

These tests exist because of two CRITICAL release-blocking defects found in
the final archive audit (commit 7b32932):

  C1: POST /api/v1/scan/start hardcoded dry_run=False, so the environment-
      level AGENT_DRY_RUN safety switch had no effect on the scan pipeline.

  C2: POST /api/v1/agent/ingest computed
      `dry_run = request.dry_run and settings.agent_dry_run`
      (should be `or`), so either the caller or the environment alone
      could force a real write even when the other explicitly requested
      a dry run.

Both are fixed by routing every write-capable entry point through the
single authoritative helper `app.core.config.resolve_effective_dry_run`,
whose contract is:

    effective_dry_run = env_dry_run OR request_dry_run

A real write is permitted ONLY when BOTH the environment and the request
agree writes are safe (both False).

This file tests that contract directly, and tests both HTTP entry points
against all 4 required combinations from the release remediation spec.
"""
from unittest.mock import patch, MagicMock

import pytest

from app.core.config import resolve_effective_dry_run
from app.agent.models import IngestionResult


# ---------------------------------------------------------------------------
# Part 1 — pure logic test of the authoritative helper (no DB, no HTTP)
# ---------------------------------------------------------------------------

class TestResolveEffectiveDryRun:
    """Direct truth-table test of the safety contract itself."""

    def test_case1_env_true_request_false_no_write(self):
        # environment dry_run = TRUE, request dry_run = FALSE -> NO WRITE
        assert resolve_effective_dry_run(request_dry_run=False, env_dry_run=True) is True

    def test_case2_env_true_request_true_no_write(self):
        # environment dry_run = TRUE, request dry_run = TRUE -> NO WRITE
        assert resolve_effective_dry_run(request_dry_run=True, env_dry_run=True) is True

    def test_case3_env_false_request_true_no_write(self):
        # environment dry_run = FALSE, request dry_run = TRUE -> NO WRITE
        # This is the case that exposed C2: the caller's dry_run=True
        # request MUST be respected even when the env allows writes.
        assert resolve_effective_dry_run(request_dry_run=True, env_dry_run=False) is True

    def test_case4_env_false_request_false_write_allowed(self):
        # environment dry_run = FALSE, request dry_run = FALSE -> WRITE ALLOWED
        assert resolve_effective_dry_run(request_dry_run=False, env_dry_run=False) is False

    def test_defaults_to_live_settings_when_env_dry_run_not_given(self):
        # settings.agent_dry_run defaults to True, so with no override and
        # a False request, the effective result must still be a dry run.
        assert resolve_effective_dry_run(request_dry_run=False) is True


# ---------------------------------------------------------------------------
# Part 2 — PATH A: POST /api/v1/agent/ingest, all 4 combinations
# ---------------------------------------------------------------------------

class TestAgentIngestDryRunMatrix:
    """
    Verifies the fix for C2. Mocks app.agent.ingestion.ingest and asserts
    the `dry_run` kwarg it actually receives matches the safety contract,
    for every (env, request) combination.

    IMPORTANT: `resolve_effective_dry_run` reads `settings.agent_dry_run`
    from the `app.core.config` module's own singleton, which
    `app.api.ingestion` imported a *reference* to at import time. Patching
    `app.api.ingestion.settings` would NOT affect that singleton. We must
    patch the attribute on the actual shared object instead, via
    `app.core.config.settings.agent_dry_run`, so every module that holds a
    reference to the same singleton observes the same patched value.
    """

    def _mock_result(self, dry_run: bool) -> IngestionResult:
        return IngestionResult(
            dry_run=dry_run,
            barcode="6281000000066",
            product_internal_code="FATEEN_MILK_TEST",
            changes=[],
            warnings=[],
            errors=[],
        )

    @patch("app.core.config.settings.agent_ingest_api_key", "")
    @patch("app.core.config.settings.agent_dry_run", True)
    @patch("app.api.ingestion.ingest")
    def test_case1_env_true_request_false(self, mock_ingest, client):
        mock_ingest.return_value = self._mock_result(dry_run=True)

        client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": False},
        )

        assert mock_ingest.call_args.kwargs["dry_run"] is True

    @patch("app.core.config.settings.agent_ingest_api_key", "")
    @patch("app.core.config.settings.agent_dry_run", True)
    @patch("app.api.ingestion.ingest")
    def test_case2_env_true_request_true(self, mock_ingest, client):
        mock_ingest.return_value = self._mock_result(dry_run=True)

        client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": True},
        )

        assert mock_ingest.call_args.kwargs["dry_run"] is True

    @patch("app.core.config.settings.agent_ingest_api_key", "")
    @patch("app.core.config.settings.agent_dry_run", False)
    @patch("app.api.ingestion.ingest")
    def test_case3_env_false_request_true(self, mock_ingest, client):
        # This is exactly the combination that exposed C2 originally:
        # `True and False` evaluated to False (write allowed) even though
        # the caller explicitly asked for a dry run.
        mock_ingest.return_value = self._mock_result(dry_run=True)

        client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": True},
        )

        assert mock_ingest.call_args.kwargs["dry_run"] is True

    @patch("app.core.config.settings.agent_ingest_api_key", "")
    @patch("app.core.config.settings.agent_dry_run", False)
    @patch("app.api.ingestion.ingest")
    def test_case4_env_false_request_false_write_allowed(self, mock_ingest, client):
        mock_ingest.return_value = self._mock_result(dry_run=False)

        client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": False},
        )

        assert mock_ingest.call_args.kwargs["dry_run"] is False


# ---------------------------------------------------------------------------
# Part 3 — PATH B: POST /api/v1/scan/start, all 4 combinations
# ---------------------------------------------------------------------------

class TestScanStartDryRunMatrix:
    """
    Verifies the fix for C1. Mocks app.api.scan.scan_company and asserts
    the `dry_run` kwarg it actually receives matches the safety contract,
    for every (env, request) combination. Before the fix, this endpoint
    hardcoded dry_run=False and never consulted settings.agent_dry_run at
    all, so ALL FOUR of these cases would have failed identically (every
    call would have received dry_run=False).
    """

    def _mock_scan_result(self):
        result = MagicMock()
        result.scan_job_id = "test-job-id"
        return result

    def _mock_job_response(self):
        return {
            "id": "test-job-id",
            "company_id": "test-company",
            "scan_type": "full",
            "status": "completed",
        }

    # Same reasoning as TestAgentIngestDryRunMatrix above: patch the
    # attribute on the actual shared `app.core.config.settings` singleton,
    # not the name imported into app.api.scan's local namespace.

    @patch("app.api.scan.get_scan_job")
    @patch("app.core.config.settings.agent_ingest_api_key", "")
    @patch("app.core.config.settings.agent_dry_run", True)
    @patch("app.api.scan.scan_company")
    def test_case1_env_true_request_false(self, mock_scan, mock_get_job, client):
        # Before the fix, this call always received dry_run=False
        # regardless of the environment (CRITICAL finding C1).
        mock_scan.return_value = self._mock_scan_result()
        mock_get_job.return_value = self._mock_job_response()

        client.post(
            "/api/v1/scan/start",
            json={"company_id": "test-company", "dry_run": False},
        )

        assert mock_scan.call_args.kwargs["dry_run"] is True

    @patch("app.api.scan.get_scan_job")
    @patch("app.core.config.settings.agent_ingest_api_key", "")
    @patch("app.core.config.settings.agent_dry_run", True)
    @patch("app.api.scan.scan_company")
    def test_case2_env_true_request_true(self, mock_scan, mock_get_job, client):
        mock_scan.return_value = self._mock_scan_result()
        mock_get_job.return_value = self._mock_job_response()

        client.post(
            "/api/v1/scan/start",
            json={"company_id": "test-company", "dry_run": True},
        )

        assert mock_scan.call_args.kwargs["dry_run"] is True

    @patch("app.api.scan.get_scan_job")
    @patch("app.core.config.settings.agent_ingest_api_key", "")
    @patch("app.core.config.settings.agent_dry_run", False)
    @patch("app.api.scan.scan_company")
    def test_case3_env_false_request_true(self, mock_scan, mock_get_job, client):
        mock_scan.return_value = self._mock_scan_result()
        mock_get_job.return_value = self._mock_job_response()

        client.post(
            "/api/v1/scan/start",
            json={"company_id": "test-company", "dry_run": True},
        )

        assert mock_scan.call_args.kwargs["dry_run"] is True

    @patch("app.api.scan.get_scan_job")
    @patch("app.core.config.settings.agent_ingest_api_key", "")
    @patch("app.core.config.settings.agent_dry_run", False)
    @patch("app.api.scan.scan_company")
    def test_case4_env_false_request_false_write_allowed(self, mock_scan, mock_get_job, client):
        mock_scan.return_value = self._mock_scan_result()
        mock_get_job.return_value = self._mock_job_response()

        client.post(
            "/api/v1/scan/start",
            json={"company_id": "test-company", "dry_run": False},
        )

        assert mock_scan.call_args.kwargs["dry_run"] is False


# ---------------------------------------------------------------------------
# Part 4 — DB-level proof, not just a boolean assertion.
#
# These require a real PostgreSQL connection (db_conn fixture) and were
# NOT executable in the audit sandbox (no Docker/network available there).
# They are provided for the maintainer to run locally against
# fateen-postgres, per the release remediation spec's explicit requirement
# that at least one test per path verify the database was actually
# unchanged under dry-run.
# ---------------------------------------------------------------------------

@pytest.mark.integration
class TestDryRunLeavesDatabaseUnchanged:
    TEST_BARCODE = "6281000000066"

    def _count_allergens(self, db_conn, barcode):
        row = db_conn.execute(
            """
            SELECT COUNT(*) AS cnt
            FROM public.product_allergens pa
            JOIN public.product_barcodes pb ON pb.product_id = pa.product_id
            JOIN public.barcodes b ON b.id = pb.barcode_id
            WHERE b.barcode = %s AND pa.deleted_at IS NULL
            """,
            (barcode,),
        ).fetchone()
        return row["cnt"]

    def test_agent_ingest_dry_run_true_writes_nothing(self, client, db_conn):
        """
        PATH A, Case 1 semantics proven against the real database: with
        AGENT_DRY_RUN left at its default (True) and request dry_run=True,
        submitting a *new* allergen must not change the row count.
        """
        before = self._count_allergens(db_conn, self.TEST_BARCODE)

        client.post(
            "/api/v1/agent/ingest",
            json={
                "barcode": self.TEST_BARCODE,
                "dry_run": True,
                "allergens": [{"name": "SOY"}],
            },
        )

        after = self._count_allergens(db_conn, self.TEST_BARCODE)
        assert after == before, (
            "Dry-run request must not mutate product_allergens, "
            f"but count changed from {before} to {after}"
        )

    def test_scan_start_dry_run_true_writes_nothing(self, client, db_conn):
        """
        PATH B: with request dry_run=True (regardless of the env default),
        starting a scan must not create/modify any product rows.
        Requires a company fixture row to exist; skips otherwise, matching
        the existing conditional-skip pattern used elsewhere in this suite.
        """
        company = db_conn.execute(
            "SELECT id FROM public.companies WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        if not company:
            pytest.skip("No company in DB for scan idempotency check")

        company_id_str = str(company["id"])

        before = db_conn.execute(
            "SELECT COUNT(*) AS cnt FROM public.products WHERE deleted_at IS NULL"
        ).fetchone()["cnt"]

        client.post(
            "/api/v1/scan/start",
            json={"company_id": company_id_str, "dry_run": True},
        )

        after = db_conn.execute(
            "SELECT COUNT(*) AS cnt FROM public.products WHERE deleted_at IS NULL"
        ).fetchone()["cnt"]
        assert after == before, (
            "Dry-run scan must not create/modify products, "
            f"but count changed from {before} to {after}"
        )


# ---------------------------------------------------------------------------
# Part 5 — Fix 2 (FATEEN Architecture Audit): explicit, testable contract.
#
# dry_run=True must never write to any DRY_RUN_FORBIDDEN_TABLES table, but
# IS allowed (by design) to write scan_jobs/scan_job_items/
# discovery_candidates. This is a fully mocked unit test (no real DB) so it
# runs everywhere, unlike the class above which needs a live company row.
# ---------------------------------------------------------------------------
class TestDryRunForbiddenTablesContract:
    def test_dry_run_scan_never_touches_forbidden_tables(self):
        from app.collector.orchestrator import (
            scan_company,
            DRY_RUN_FORBIDDEN_TABLES,
        )

        company_row = {
            "id": "company-1", "name": "Test Co",
            "internal_code": "CO1", "country": "SA", "market": "packaged_food",
        }
        candidate_row = {
            "id": "cand-1", "company_id": "company-1", "name": "New Product",
            "brand": None, "barcode": "6281000099999", "category": None,
            "country": "SA", "market": "packaged_food", "source_url": None,
            "source_reference": None, "raw_data": {}, "status": "discovered",
            "normalized_name": None, "normalized_brand": None,
            "normalized_barcode": None,
        }

        executed_queries = []

        def make_side_effect():
            def _execute(query, params=None):
                executed_queries.append(query)
                cursor = MagicMock()
                q = query.strip()
                if "FROM public.companies" in q:
                    cursor.fetchone.return_value = company_row
                elif "FROM public.scan_jobs" in q and "SELECT" in q:
                    cursor.fetchone.return_value = None  # no active job
                elif "FROM public.discovery_candidates" in q and "SELECT" in q:
                    cursor.fetchall.return_value = [candidate_row]
                    cursor.fetchone.return_value = None
                elif "FROM public.product_barcodes" in q or "FROM public.barcodes" in q:
                    cursor.fetchone.return_value = None  # dedup: no match
                else:
                    cursor.fetchone.return_value = None
                    cursor.fetchall.return_value = []
                return cursor
            return _execute

        conn = MagicMock()
        conn.__enter__ = MagicMock(return_value=conn)
        conn.__exit__ = MagicMock(return_value=False)
        conn.execute.side_effect = make_side_effect()

        with patch("app.collector.orchestrator.get_connection", return_value=conn), \
             patch("app.collector.deduplication.get_connection", return_value=conn), \
             patch("app.collector.coverage.get_connection", return_value=conn):
            result = scan_company(company_id="company-1", dry_run=True)

        assert result is not None
        touched_forbidden = []
        for q in executed_queries:
            q_norm = " ".join(q.split())  # collapse whitespace for matching
            for t in DRY_RUN_FORBIDDEN_TABLES:
                if f"INSERT INTO {t} " in q_norm or f"UPDATE {t} " in q_norm or f"INSERT INTO {t}(" in q_norm:
                    touched_forbidden.append((t, q_norm))
        assert touched_forbidden == [], (
            f"dry_run=True must never write to a forbidden table, but these "
            f"queries ran:\n" + "\n---\n".join(touched_forbidden)
        )
        wrote_scan_jobs = any(
            "INSERT INTO public.scan_jobs" in q for q in executed_queries
        )
        assert wrote_scan_jobs, (
            "scan_jobs is an allowed operational table and SHOULD be "
            "written even under dry_run=True -- this is the documented "
            "contract, not an accident."
        )

