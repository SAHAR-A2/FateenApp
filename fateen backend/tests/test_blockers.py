"""Tests for B1-B8 blocker fixes."""
import math
import os
import subprocess
import sys
from unittest.mock import patch, MagicMock

import pytest
from fastapi.testclient import TestClient


# ============================================================
# B1: LLM Confidence Bypass
# ============================================================
class TestB1LLMConfidence:
    @patch("app.llm.extractor.LLMClient")
    def test_valid_confidence_passes(self, MockClient):
        from app.llm.extractor import extract_product_data
        from app.llm.client import LLMResponse

        MockClient.return_value.chat.return_value = LLMResponse(
            content='{"confidence_level": 0.85, "ingredients": []}',
            model="test",
        )
        result = extract_product_data(barcode="6281000000066")
        assert result.confidence_level == 0.85

    @patch("app.llm.extractor.LLMClient")
    def test_confidence_zero_passes(self, MockClient):
        from app.llm.extractor import extract_product_data
        from app.llm.client import LLMResponse

        MockClient.return_value.chat.return_value = LLMResponse(
            content='{"confidence_level": 0.0, "ingredients": []}',
            model="test",
        )
        result = extract_product_data(barcode="6281000000066")
        assert result.confidence_level == 0.0

    @patch("app.llm.extractor.LLMClient")
    def test_confidence_one_passes(self, MockClient):
        from app.llm.extractor import extract_product_data
        from app.llm.client import LLMResponse

        MockClient.return_value.chat.return_value = LLMResponse(
            content='{"confidence_level": 1.0, "ingredients": []}',
            model="test",
        )
        result = extract_product_data(barcode="6281000000066")
        assert result.confidence_level == 1.0

    @patch("app.llm.extractor.LLMClient")
    def test_confidence_negative_resets_to_default(self, MockClient):
        from app.llm.extractor import extract_product_data
        from app.llm.client import LLMResponse

        MockClient.return_value.chat.return_value = LLMResponse(
            content='{"confidence_level": -1.0, "ingredients": []}',
            model="test",
        )
        result = extract_product_data(barcode="6281000000066")
        assert result.confidence_level == 0.5

    @patch("app.llm.extractor.LLMClient")
    def test_confidence_above_one_resets_to_default(self, MockClient):
        from app.llm.extractor import extract_product_data
        from app.llm.client import LLMResponse

        MockClient.return_value.chat.return_value = LLMResponse(
            content='{"confidence_level": 5.0, "ingredients": []}',
            model="test",
        )
        result = extract_product_data(barcode="6281000000066")
        assert result.confidence_level == 0.5

    @patch("app.llm.extractor.LLMClient")
    def test_confidence_nan_resets_to_default(self, MockClient):
        from app.llm.extractor import extract_product_data
        from app.llm.client import LLMResponse

        MockClient.return_value.chat.return_value = LLMResponse(
            content='{"confidence_level": "NaN", "ingredients": []}',
            model="test",
        )
        result = extract_product_data(barcode="6281000000066")
        assert result.confidence_level == 0.5

    @patch("app.llm.extractor.LLMClient")
    def test_confidence_infinity_resets_to_default(self, MockClient):
        from app.llm.extractor import extract_product_data
        from app.llm.client import LLMResponse

        MockClient.return_value.chat.return_value = LLMResponse(
            content='{"confidence_level": "Infinity", "ingredients": []}',
            model="test",
        )
        result = extract_product_data(barcode="6281000000066")
        assert result.confidence_level == 0.5

    @patch("app.llm.extractor.LLMClient")
    def test_confidence_none_resets_to_default(self, MockClient):
        from app.llm.extractor import extract_product_data
        from app.llm.client import LLMResponse

        MockClient.return_value.chat.return_value = LLMResponse(
            content='{"ingredients": []}',
            model="test",
        )
        result = extract_product_data(barcode="6281000000066")
        assert result.confidence_level == 0.5


# ============================================================
# B2: Error Information Leakage
# ============================================================
class TestB2ErrorLeakage:
    def test_ingestion_error_no_db_details(self, client):
        with patch("app.api.ingestion.ingest", side_effect=Exception("password=secret host=db.internal")):
            response = client.post(
                "/api/v1/agent/ingest",
                json={"barcode": "6281000000066", "dry_run": True},
            )
            assert response.status_code == 500
            detail = response.json()["detail"]
            assert "password" not in detail.lower()
            assert "secret" not in detail.lower()
            assert "db.internal" not in detail.lower()
            assert "Check server logs" in detail

    def test_enrichment_error_no_llm_details(self, client):
        with patch("app.api.enrichment.extract_product_data", side_effect=Exception("api_key=sk-xxx")):
            with patch("app.api.enrichment.settings") as mock_s:
                mock_s.agent_ingest_api_key = ""
                response = client.post(
                    "/api/v1/llm/extract",
                    json={"barcode": "6281000000066"},
                )
                assert response.status_code == 500
                detail = response.json()["detail"]
                assert "sk-xxx" not in detail
                assert "Check server logs" in detail

    def test_404_no_internals(self, client):
        response = client.get("/api/v1/products/barcode/9999999999999")
        assert response.status_code == 404
        assert "detail" in response.json()
        assert "SQL" not in str(response.json())


# ============================================================
# B3: CORS Production Security
# ============================================================
class TestB3CORS:
    def test_cors_uses_configured_origins(self):
        from app.core.config import Settings
        s = Settings(
            database_url="postgresql://x@localhost/db",
            cors_allowed_origins="https://example.com",
        )
        assert s.cors_origins_list == ["https://example.com"]

    def test_cors_multiple_origins(self):
        from app.core.config import Settings
        s = Settings(
            database_url="postgresql://x@localhost/db",
            cors_allowed_origins="https://a.com,https://b.com",
        )
        assert s.cors_origins_list == ["https://a.com", "https://b.com"]

    def test_cors_wildcard_rejected_in_production(self):
        from app.core.config import Settings
        with pytest.raises(Exception):
            Settings(
                database_url="postgresql://x@localhost/db",
                app_env="production",
                agent_ingest_api_key="strong_key_123",
                cors_allowed_origins="*",
            )

    def test_cors_allows_configured_origin(self, client):
        response = client.get(
            "/health",
            headers={"Origin": "http://localhost:3000"},
        )
        assert "access-control-allow-origin" in response.headers


# ============================================================
# B4: Production Startup Guard
# ============================================================
class TestB4ProductionGuard:
    def test_production_rejects_empty_api_key(self):
        from app.core.config import Settings
        with pytest.raises(Exception):
            Settings(
                database_url="postgresql://x@localhost/db",
                app_env="production",
                agent_ingest_api_key="",
                cors_allowed_origins="https://example.com",
            )

    def test_production_rejects_wildcard_cors(self):
        from app.core.config import Settings
        with pytest.raises(Exception):
            Settings(
                database_url="postgresql://x@localhost/db",
                app_env="production",
                agent_ingest_api_key="strong_key_123",
                cors_allowed_origins="*",
            )

    def test_production_accepts_valid_config(self):
        from app.core.config import Settings
        s = Settings(
            database_url="postgresql://x@localhost/db",
            app_env="production",
            agent_ingest_api_key="strong_key_123",
            cors_allowed_origins="https://example.com",
        )
        assert s.agent_ingest_api_key == "strong_key_123"

    def test_development_allows_empty_config(self):
        from app.core.config import Settings
        s = Settings(
            database_url="postgresql://x@localhost/db",
            app_env="development",
        )
        assert s.agent_ingest_api_key == ""


# ============================================================
# B6: LLM Timeout Configuration
# ============================================================
class TestB6LLMTimeout:
    def test_default_timeout(self):
        from app.core.config import Settings
        s = Settings(database_url="postgresql://x@localhost/db")
        assert s.llm_timeout == 30.0

    def test_custom_timeout(self):
        from app.core.config import Settings
        s = Settings(database_url="postgresql://x@localhost/db", llm_timeout=60.0)
        assert s.llm_timeout == 60.0

    def test_llm_client_uses_configured_timeout(self):
        from app.llm.client import LLMClient
        with patch("app.llm.client.settings") as mock_s:
            mock_s.llm_provider = "ollama"
            mock_s.llm_timeout = 45.0
            mock_s.ollama_model = "test"
            client = LLMClient()
            assert client.timeout == 45.0


# ============================================================
# B7: Effective Dates
# ============================================================
class TestB7EffectiveDates:
    def test_product_details_filters_expired_barcode(self, db_conn, client):
        from datetime import datetime, timedelta, timezone

        product = db_conn.execute("""
            SELECT p.id, b.barcode
            FROM public.product_barcodes pb
            JOIN public.products p ON p.id = pb.product_id
            JOIN public.barcodes b ON b.id = pb.barcode_id
            WHERE b.barcode = '6281000000066'
              AND pb.deleted_at IS NULL AND p.deleted_at IS NULL AND b.deleted_at IS NULL
            LIMIT 1
        """).fetchone()
        pid = product["id"]
        past = datetime.now(timezone.utc) - timedelta(days=365)

        db_conn.execute(
            "UPDATE public.product_barcodes SET effective_to = %s WHERE product_id = %s",
            (past, pid),
        )
        db_conn.commit()
        response = client.get("/api/v1/products/details/barcode/6281000000066")
        db_conn.execute(
            "UPDATE public.product_barcodes SET effective_to = NULL WHERE product_id = %s",
            (pid,),
        )
        db_conn.commit()
        assert response.status_code == 404

    def test_product_details_includes_active_barcode(self, client):
        response = client.get("/api/v1/products/details/barcode/6281000000066")
        assert response.status_code == 200

    def test_product_details_filters_future_barcode(self, db_conn, client):
        from datetime import datetime, timedelta, timezone

        product = db_conn.execute("""
            SELECT p.id
            FROM public.product_barcodes pb
            JOIN public.products p ON p.id = pb.product_id
            JOIN public.barcodes b ON b.id = pb.barcode_id
            WHERE b.barcode = '6281000000066'
              AND pb.deleted_at IS NULL AND p.deleted_at IS NULL AND b.deleted_at IS NULL
            LIMIT 1
        """).fetchone()
        pid = product["id"]
        future = datetime.now(timezone.utc) + timedelta(days=365)

        db_conn.execute(
            "UPDATE public.product_barcodes SET effective_from = %s WHERE product_id = %s",
            (future, pid),
        )
        db_conn.commit()
        response = client.get("/api/v1/products/details/barcode/6281000000066")
        db_conn.execute(
            "UPDATE public.product_barcodes SET effective_from = NULL WHERE product_id = %s",
            (pid,),
        )
        db_conn.commit()
        assert response.status_code == 404


# ============================================================
# B8: Dependency Reproducibility
# ============================================================
class TestB8Dependencies:
    def test_requirements_pinned(self):
        import re
        with open("requirements.txt") as f:
            lines = f.readlines()
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            assert "==" in line, f"Unpinned dependency: {line}"

    def test_all_versions_match_installed(self):
        with open("requirements.txt") as f:
            lines = f.readlines()
        from importlib.metadata import version as get_version
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            pkg_name = line.split("==")[0].replace("[binary]", "").replace("[standard]", "")
            installed_version = get_version(pkg_name)
            required_version = line.split("==")[1]
            assert installed_version == required_version, (
                f"{pkg_name}: required {required_version}, installed {installed_version}"
            )
