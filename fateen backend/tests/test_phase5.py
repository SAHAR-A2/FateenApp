import uuid
from unittest.mock import patch, MagicMock

import pytest

from app.db.connection import get_connection
from app.collector.retrieval import (
    retrieve, RetrievalConfig, _is_safe_host, _validate_url_safety,
)


class TestSSRFProtection:
    def test_blocks_localhost(self):
        assert _is_safe_host("localhost") is False

    def test_blocks_loopback_ip(self):
        assert _is_safe_host("127.0.0.1") is False

    def test_blocks_loopback_ipv6(self):
        assert _is_safe_host("::1") is False

    def test_blocks_private_10(self):
        assert _is_safe_host("10.0.0.1") is False

    def test_blocks_private_172(self):
        assert _is_safe_host("172.16.0.1") is False

    def test_blocks_private_192(self):
        assert _is_safe_host("192.168.1.1") is False

    def test_blocks_link_local(self):
        assert _is_safe_host("169.254.1.1") is False

    def test_blocks_multicast(self):
        assert _is_safe_host("224.0.0.1") is False

    def test_blocks_reserved(self):
        assert _is_safe_host("240.0.0.1") is False

    def test_blocks_zero_network(self):
        assert _is_safe_host("0.0.0.1") is False

    def test_allows_public_hostname(self):
        assert _is_safe_host("httpbin.org") is True

    def test_validate_url_safety_ssrf(self):
        assert _validate_url_safety("http://127.0.0.1/admin") == "SSRF_BLOCKED"

    def test_validate_url_safety_invalid(self):
        assert _validate_url_safety("not-a-url") == "INVALID_URL"

    def test_validate_url_safety_ok(self):
        assert _validate_url_safety("https://httpbin.org/get") is None

    def test_retrieve_blocks_localhost(self):
        result = retrieve(
            "http://127.0.0.1:8080/admin",
            config=RetrievalConfig(timeout=5, max_retries=0),
        )
        assert result.success is False
        assert result.error == "SSRF_BLOCKED"

    def test_retrieve_blocks_private_10(self):
        result = retrieve(
            "http://10.0.0.1:8080/secret",
            config=RetrievalConfig(timeout=5, max_retries=0),
        )
        assert result.success is False
        assert result.error == "SSRF_BLOCKED"

    def test_retrieve_blocks_link_local(self):
        result = retrieve(
            "http://169.254.169.254/latest/meta-data/",
            config=RetrievalConfig(timeout=5, max_retries=0),
        )
        assert result.success is False
        assert result.error == "SSRF_BLOCKED"

    def test_retrieve_blocks_ipv6_loopback(self):
        result = retrieve(
            "http://[::1]:8080/",
            config=RetrievalConfig(timeout=5, max_retries=0),
        )
        assert result.success is False
        assert result.error == "SSRF_BLOCKED"

    def test_retrieve_blocks_cloud_metadata(self):
        result = retrieve(
            "http://169.254.169.254/latest/meta-data/iam/security-credentials/",
            config=RetrievalConfig(timeout=5, max_retries=0),
        )
        assert result.success is False
        assert result.error == "SSRF_BLOCKED"

    def test_retrieve_invalid_url_unchanged(self):
        result = retrieve(
            "not-a-url",
            config=RetrievalConfig(timeout=5, max_retries=0),
        )
        assert result.success is False
        assert result.error == "INVALID_URL"

    def test_retrieve_rejects_non_http(self):
        result = retrieve(
            "ftp://httpbin.org/file",
            config=RetrievalConfig(timeout=5, max_retries=0),
        )
        assert result.success is False
        assert result.error == "INVALID_URL"


class TestDatabaseSummaryAuth:
    def test_database_summary_requires_auth_when_key_configured(self):
        from app.main import app
        from fastapi.testclient import TestClient

        with patch("app.main.settings") as mock_settings:
            mock_settings.agent_ingest_api_key = "test-secret-key"
            mock_settings.cors_origins_list = ["http://localhost:3000"]
            client = TestClient(app, raise_server_exceptions=False)

            resp = client.get("/api/v1/database/summary")
            assert resp.status_code == 401
            assert resp.json()["detail"] == "Invalid or missing API key"

            resp = client.get(
                "/api/v1/database/summary",
                headers={"X-Agent-API-Key": "test-secret-key"},
            )
            assert resp.status_code == 200

    def test_database_summary_open_when_no_key_configured(self):
        from app.main import app
        from fastapi.testclient import TestClient

        with patch("app.main.settings") as mock_settings:
            mock_settings.agent_ingest_api_key = ""
            mock_settings.cors_origins_list = ["http://localhost:3000"]
            client = TestClient(app, raise_server_exceptions=False)

            resp = client.get("/api/v1/database/summary")
            assert resp.status_code == 200


class TestScanIdempotency:
    def test_find_active_scan_job_returns_none_when_no_active(self):
        from app.collector.orchestrator import _find_active_scan_job
        result = _find_active_scan_job(str(uuid.uuid4()))
        assert result is None

    def test_scan_company_rejects_nonexistent_company(self):
        from app.collector.orchestrator import scan_company
        result = scan_company(company_id=str(uuid.uuid4()), dry_run=True)
        assert result.status == "failed"
        assert "Company not found" in result.errors[0]

    def test_scan_company_idempotency_guard_exists(self):
        from app.collector.orchestrator import scan_company, _find_active_scan_job
        assert callable(_find_active_scan_job)
        with get_connection() as conn:
            row = conn.execute(
                "SELECT id FROM public.companies WHERE deleted_at IS NULL LIMIT 1"
            ).fetchone()
            if not row:
                pytest.skip("No companies in DB")
            result = _find_active_scan_job(row["id"])
            assert result is None or isinstance(result, dict)


class TestRetrievalSafety:
    def test_html_content_rejected(self):
        with patch("app.collector.retrieval._validate_url_safety", return_value=None):
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.headers = {"content-type": "text/html"}
            mock_response.text = "<html>test</html>"

            mock_client_instance = MagicMock()
            mock_client_instance.get.return_value = mock_response
            mock_client_instance.__enter__ = MagicMock(return_value=mock_client_instance)
            mock_client_instance.__exit__ = MagicMock(return_value=False)

            with patch("app.collector.retrieval.httpx") as mock_httpx:
                mock_httpx.Client.return_value = mock_client_instance
                mock_httpx.Timeout.return_value = MagicMock()
                mock_httpx.Limits.return_value = MagicMock()
                mock_httpx.TooManyRedirects = type("TooManyRedirects", (Exception,), {})
                result = retrieve(
                    "https://example.com",
                    config=RetrievalConfig(timeout=5, max_retries=0),
                )
                assert result.success is False
                assert result.error == "UNEXPECTED_HTML"

    def test_content_too_large_rejected(self):
        with patch("app.collector.retrieval._validate_url_safety", return_value=None):
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.headers = {"content-type": "text/plain"}
            mock_response.text = "x" * (11 * 1024 * 1024)

            mock_client_instance = MagicMock()
            mock_client_instance.get.return_value = mock_response
            mock_client_instance.__enter__ = MagicMock(return_value=mock_client_instance)
            mock_client_instance.__exit__ = MagicMock(return_value=False)

            with patch("app.collector.retrieval.httpx") as mock_httpx:
                mock_httpx.Client.return_value = mock_client_instance
                mock_httpx.Timeout.return_value = MagicMock()
                mock_httpx.Limits.return_value = MagicMock()
                mock_httpx.TooManyRedirects = type("TooManyRedirects", (Exception,), {})
                result = retrieve(
                    "https://example.com",
                    config=RetrievalConfig(timeout=5, max_retries=0),
                )
                assert result.success is False
                assert result.error == "CONTENT_TOO_LARGE"
