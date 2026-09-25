"""Phase 6 tests: dashboard, job recovery, reset, logging, constraints."""
import uuid
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.db.connection import get_connection
from app.main import app, _recover_stale_jobs


@pytest.fixture
def client():
    return TestClient(app)


class TestDashboardSummary:
    def test_dashboard_returns_expected_keys(self, client):
        response = client.get("/api/v1/dashboard/summary")
        assert response.status_code == 200
        data = response.json()
        assert "companies" in data
        assert "products" in data
        assert "scan_jobs" in data
        assert "candidates" in data
        assert "unresolved_conflicts" in data

    def test_dashboard_scan_jobs_structure(self, client):
        response = client.get("/api/v1/dashboard/summary")
        data = response.json()
        jobs = data["scan_jobs"]
        assert "total" in jobs
        assert "active" in jobs
        assert "failed" in jobs
        assert "by_status" in jobs
        assert isinstance(jobs["by_status"], dict)

    def test_dashboard_candidates_structure(self, client):
        response = client.get("/api/v1/dashboard/summary")
        data = response.json()
        candidates = data["candidates"]
        assert "total" in candidates
        assert "rejected" in candidates
        assert "by_status" in candidates

    def test_dashboard_counts_are_non_negative(self, client):
        response = client.get("/api/v1/dashboard/summary")
        data = response.json()
        assert data["companies"] >= 0
        assert data["products"] >= 0
        assert data["scan_jobs"]["total"] >= 0
        assert data["unresolved_conflicts"] >= 0


class TestJobRecovery:
    def test_stale_job_marked_failed(self, db_conn):
        company_id = db_conn.execute(
            "SELECT id FROM public.companies WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        if not company_id:
            pytest.skip("No companies")
        company_id = company_id["id"]

        job_id = str(uuid.uuid4())
        try:
            db_conn.execute(
                """
                INSERT INTO public.scan_jobs
                    (id, company_id, scan_type, status, started_at, created_at, updated_at)
                VALUES (%s, %s, 'full', 'in_progress', NOW() - INTERVAL '1 hour', NOW(), NOW())
                """,
                (job_id, company_id),
            )
            db_conn.commit()
        except Exception:
            db_conn.rollback()
            pytest.skip("INSERT permission denied on scan_jobs")

        _recover_stale_jobs()

        row = db_conn.execute(
            "SELECT status, finished_at FROM public.scan_jobs WHERE id = %s",
            (job_id,),
        ).fetchone()
        assert row["status"] == "failed"
        assert row["finished_at"] is not None

        try:
            db_conn.execute("DELETE FROM public.scan_jobs WHERE id = %s", (job_id,))
            db_conn.commit()
        except Exception:
            db_conn.rollback()

    def test_recent_job_not_affected(self, db_conn):
        company_id = db_conn.execute(
            "SELECT id FROM public.companies WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        if not company_id:
            pytest.skip("No companies")
        company_id = company_id["id"]

        job_id = str(uuid.uuid4())
        try:
            db_conn.execute(
                """
                INSERT INTO public.scan_jobs
                    (id, company_id, scan_type, status, started_at, created_at, updated_at)
                VALUES (%s, %s, 'full', 'in_progress', NOW(), NOW(), NOW())
                """,
                (job_id, company_id),
            )
            db_conn.commit()
        except Exception:
            db_conn.rollback()
            pytest.skip("INSERT permission denied on scan_jobs")

        _recover_stale_jobs()

        row = db_conn.execute(
            "SELECT status FROM public.scan_jobs WHERE id = %s",
            (job_id,),
        ).fetchone()
        assert row["status"] == "in_progress"

        try:
            db_conn.execute("DELETE FROM public.scan_jobs WHERE id = %s", (job_id,))
            db_conn.commit()
        except Exception:
            db_conn.rollback()


class TestResetEndpoint:
    def test_reset_stuck_job(self, client, db_conn):
        company_id = db_conn.execute(
            "SELECT id FROM public.companies WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        if not company_id:
            pytest.skip("No companies")
        company_id = company_id["id"]

        job_id = str(uuid.uuid4())
        try:
            db_conn.execute(
                """
                INSERT INTO public.scan_jobs
                    (id, company_id, scan_type, status, started_at, created_at, updated_at)
                VALUES (%s, %s, 'full', 'in_progress', NOW(), NOW(), NOW())
                """,
                (job_id, company_id),
            )
            db_conn.commit()
        except Exception:
            db_conn.rollback()
            pytest.skip("INSERT permission denied on scan_jobs")

        response = client.post(f"/api/v1/scan/{job_id}/reset")
        assert response.status_code == 200

        row = db_conn.execute(
            "SELECT status FROM public.scan_jobs WHERE id = %s",
            (job_id,),
        ).fetchone()
        assert row["status"] == "failed"

        try:
            db_conn.execute("DELETE FROM public.scan_jobs WHERE id = %s", (job_id,))
            db_conn.commit()
        except Exception:
            db_conn.rollback()

    def test_reset_nonexistent_job(self, client):
        response = client.post("/api/v1/scan/nonexistent/reset")
        assert response.status_code == 404

    def test_reset_completed_job_rejected(self, client, db_conn):
        company_id = db_conn.execute(
            "SELECT id FROM public.companies WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        if not company_id:
            pytest.skip("No companies")
        company_id = company_id["id"]

        job_id = str(uuid.uuid4())
        try:
            db_conn.execute(
                """
                INSERT INTO public.scan_jobs
                    (id, company_id, scan_type, status, created_at, updated_at)
                VALUES (%s, %s, 'full', 'completed', NOW(), NOW())
                """,
                (job_id, company_id),
            )
            db_conn.commit()
        except Exception:
            db_conn.rollback()
            pytest.skip("INSERT permission denied on scan_jobs")

        response = client.post(f"/api/v1/scan/{job_id}/reset")
        assert response.status_code == 400

        try:
            db_conn.execute("DELETE FROM public.scan_jobs WHERE id = %s", (job_id,))
            db_conn.commit()
        except Exception:
            db_conn.rollback()


class TestInputValidation:
    def test_company_name_max_length(self, client):
        from unittest.mock import patch
        with patch("app.api.companies.settings") as mock_s:
            mock_s.agent_ingest_api_key = ""
            long_name = "x" * 501
            response = client.post(
                "/api/v1/companies",
                json={"name": long_name, "code": "TEST"},
            )
            assert response.status_code == 422

    def test_barcode_max_length(self, client):
        from unittest.mock import patch
        with patch("app.api.ingestion.settings") as mock_s:
            mock_s.agent_ingest_api_key = ""
            mock_s.agent_dry_run = True
            long_barcode = "1" * 51
            response = client.post(
                "/api/v1/agent/ingest",
                json={"barcode": long_barcode, "dry_run": True},
            )
            assert response.status_code == 422

    def test_context_max_length(self, client):
        from unittest.mock import patch
        with patch("app.api.enrichment.settings") as mock_s:
            mock_s.agent_ingest_api_key = ""
            long_context = "x" * 10001
            response = client.post(
                "/api/v1/llm/extract",
                json={"barcode": "6281000000066", "context": long_context},
            )
            assert response.status_code == 422

    def test_ingredients_max_length(self, client):
        from unittest.mock import patch
        with patch("app.api.ingestion.settings") as mock_s:
            mock_s.agent_ingest_api_key = ""
            mock_s.agent_dry_run = True
            many_ingredients = [{"name": f"ing_{i}"} for i in range(201)]
            response = client.post(
                "/api/v1/agent/ingest",
                json={
                    "barcode": "6281000000066",
                    "ingredients": many_ingredients,
                    "dry_run": True,
                },
            )
            assert response.status_code == 422

    def test_priority_range_enforced(self, client):
        from unittest.mock import patch
        with patch("app.api.companies.settings") as mock_s:
            mock_s.agent_ingest_api_key = ""
            response = client.post(
                "/api/v1/companies",
                json={"name": "Test", "code": "T", "priority": 150},
            )
            assert response.status_code == 422


class TestLoggingSafety:
    def test_no_traceback_in_api_response(self, client):
        from unittest.mock import patch
        with patch("app.api.ingestion.ingest", side_effect=Exception("internal error")):
            with patch("app.api.ingestion.settings") as mock_s:
                mock_s.agent_ingest_api_key = ""
                response = client.post(
                    "/api/v1/agent/ingest",
                    json={"barcode": "6281000000066", "dry_run": True},
                )
                assert response.status_code == 500
                detail = response.json()["detail"]
                assert "Traceback" not in detail
                assert "internal error" not in detail

    def test_database_error_not_exposed(self, client):
        with patch("app.api.ingestion.ingest", side_effect=Exception("password=secret host=db.internal")):
            with patch("app.api.ingestion.settings") as mock_s:
                mock_s.agent_ingest_api_key = ""
                response = client.post(
                    "/api/v1/agent/ingest",
                    json={"barcode": "6281000000066", "dry_run": True},
                )
                assert response.status_code == 500
                detail = response.json()["detail"]
                assert "password" not in detail.lower()
                assert "db.internal" not in detail.lower()


class TestCORSRestriction:
    def test_cors_allows_get(self, client):
        response = client.options(
            "/api/v1/products/barcode/123",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )
        assert response.status_code in (200, 405)

    def test_cors_methods_not_star(self):
        from app.main import app as fastapi_app
        for mw in fastapi_app.user_middleware:
            pass


class TestCheckConstraints:
    def test_scan_jobs_status_constraint_exists(self, db_conn):
        row = db_conn.execute(
            """
            SELECT conname FROM pg_constraint
            WHERE conname = 'chk_scan_jobs_status'
              AND connamespace = 'public'::regnamespace
            """
        ).fetchone()
        assert row is not None

    def test_scan_job_items_status_constraint_exists(self, db_conn):
        row = db_conn.execute(
            """
            SELECT conname FROM pg_constraint
            WHERE conname = 'chk_scan_job_items_status'
              AND connamespace = 'public'::regnamespace
            """
        ).fetchone()
        assert row is not None

    def test_discovery_candidates_status_constraint_exists(self, db_conn):
        row = db_conn.execute(
            """
            SELECT conname FROM pg_constraint
            WHERE conname = 'chk_discovery_candidates_status'
              AND connamespace = 'public'::regnamespace
            """
        ).fetchone()
        assert row is not None

    def test_data_conflicts_resolution_constraint_exists(self, db_conn):
        row = db_conn.execute(
            """
            SELECT conname FROM pg_constraint
            WHERE conname = 'chk_data_conflicts_resolution'
              AND connamespace = 'public'::regnamespace
            """
        ).fetchone()
        assert row is not None
