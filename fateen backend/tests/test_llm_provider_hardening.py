"""
P5: LLM provider-failure hardening tests (offline, fully mocked).

No real Gemini/OpenAI calls, no network, no database. Every test either
patches httpx.post or replaces the LLM client with a fake, so a real
provider endpoint is never reached. Covers the hardening deliverables:

  1. Typed LLMProviderError subclasses from the LLM client (quota
     exhaustion / rate limit / timeout / unavailable / generic), with
     sanitized messages that can never leak the API key.
  2. Bounded client-level retry/backoff in LLMClient.chat: retryable
     failures (429/5xx/timeout/connection) retried at most
     llm_max_retries times with exponential backoff honoring Retry-After;
     permanent 4xx never retries; the loop is strictly bounded.
  3. Typed extraction outcomes (ExtractionResult/ExtractionStatus):
     EMPTY_EXTRACTION, MALFORMED_LLM_RESPONSE and PROVIDER_* are distinct;
     a provider failure is a typed result, never just an empty dict.
  4. Pipeline routing: a provider failure in the collector auto-extraction
     path records status='provider_failed', action='retryable' on
     scan_job_items and candidate status 'retryable' -- never
     'validation_failed' / 'Product name is required' -- and never touches
     a DRY_RUN-forbidden table.
"""
import json
from unittest.mock import patch, MagicMock

import httpx
import pytest

from app.collector import extraction
from app.collector.models import (
    ExtractionResult,
    ExtractionStatus,
    PROVIDER_FAILURE_STATUSES,
)
from app.llm.client import (
    LLMClient,
    LLMProviderError,
    LLMQuotaExhaustedError,
    LLMTimeoutError,
    LLMUnavailableError,
    LLMResponse,
)


def _error_response(status_code, text="", headers=None, **kwargs):
    return httpx.Response(
        status_code,
        text=text,
        headers=headers or {},
        request=httpx.Request("POST", "https://provider.invalid/chat"),
        **kwargs,
    )


def _ok_response():
    return httpx.Response(
        200,
        request=httpx.Request("POST", "https://provider.invalid/chat"),
        json={
            "candidates": [
                {"content": {"parts": [{"text": '{"product_name": "X"}'}]}}
            ]
        },
    )


def _gemini_client():
    return LLMClient(provider="gemini")


class TestTypedClientErrors:
    """Every provider failure is a typed LLMProviderError, not a bare ValueError."""

    def test_429_raises_quota_exhausted(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-test-429")
        with patch("httpx.post", return_value=_error_response(429, text="{ }")):
            client = _gemini_client()
            with pytest.raises(LLMQuotaExhaustedError) as exc_info:
                client._chat_gemini("s", "u")
        assert exc_info.value.code == "PROVIDER_QUOTA_EXHAUSTED"
        assert exc_info.value.retryable is True
        assert exc_info.value.status_code == 429

    def test_5xx_raises_unavailable(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-test-500")
        with patch("httpx.post", return_value=_error_response(503, text="busy")):
            client = _gemini_client()
            with pytest.raises(LLMUnavailableError) as exc_info:
                client._chat_gemini("s", "u")
        assert exc_info.value.code == "PROVIDER_UNAVAILABLE"
        assert exc_info.value.retryable is True
        assert exc_info.value.status_code == 503

    def test_permanent_4xx_is_not_retryable(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-test-400")
        with patch("httpx.post", return_value=_error_response(400, text="bad request")):
            client = _gemini_client()
            with pytest.raises(LLMProviderError) as exc_info:
                client._chat_gemini("s", "u")
        assert exc_info.value.code == "PROVIDER_ERROR"
        assert exc_info.value.retryable is False
        assert exc_info.value.status_code == 400

    def test_timeout_raises_typed_timeout(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-test-timeout")
        with patch("httpx.post", side_effect=httpx.ReadTimeout("read timed out")):
            client = _gemini_client()
            with pytest.raises(LLMTimeoutError) as exc_info:
                client._chat_gemini("s", "u")
        assert exc_info.value.code == "PROVIDER_TIMEOUT"
        assert exc_info.value.retryable is True

    def test_connect_error_raises_unavailable(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-test-connect")
        with patch("httpx.post", side_effect=httpx.ConnectError("connection refused")):
            client = _gemini_client()
            with pytest.raises(LLMUnavailableError) as exc_info:
                client._chat_gemini("s", "u")
        assert exc_info.value.code == "PROVIDER_UNAVAILABLE"
        assert exc_info.value.retryable is True

    def test_api_key_never_appears_in_error_message(self, monkeypatch):
        # Even when the provider echoes the key back in the body, the
        # raised error must not contain it (defense in depth on top of
        # exception chaining suppression).
        secret = "AIzaFAKE-SUPERSECRET-1234567890"
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", secret)
        with patch(
            "httpx.post",
            return_value=_error_response(429, text=f'{{"message": "{secret}"}}'),
        ):
            client = _gemini_client()
            with pytest.raises(LLMProviderError) as exc_info:
                client._chat_gemini("s", "u")
        assert secret not in str(exc_info.value)
        assert exc_info.value.__cause__ is None  # httpx chain suppressed


class TestBoundedRetryBackoff:
    """chat() retries retryable failures a bounded number of times."""

    def _client(self, max_retries=2, base=0.01, cap=0.05):
        client = _gemini_client()
        client.max_retries = max_retries
        client.retry_backoff_base = base
        client.retry_backoff_max = cap
        return client

    def test_429_twice_then_success(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-retry")
        client = self._client()
        calls = {"n": 0}

        def fake_post(*a, **k):
            calls["n"] += 1
            if calls["n"] <= 2:
                return _error_response(429, headers={"retry-after": "0.01"})
            return _ok_response()

        sleeps = []
        with patch("httpx.post", side_effect=fake_post), patch(
            "app.llm.client.time.sleep", side_effect=lambda s: sleeps.append(s)
        ):
            out = client.chat("s", "u")
        assert out.parsed_json()["product_name"] == "X"
        assert calls["n"] == 3
        assert len(sleeps) == 2
        assert all(s > 0 for s in sleeps)

    def test_retry_after_honored_within_bounds(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-ra")
        client = self._client(base=0.01, cap=1.0)
        calls = {"n": 0}

        def fake_post(*a, **k):
            calls["n"] += 1
            if calls["n"] == 1:
                return _error_response(429, headers={"retry-after": "0.5"})
            return _ok_response()

        sleeps = []
        with patch("httpx.post", side_effect=fake_post), patch(
            "app.llm.client.time.sleep", side_effect=lambda s: sleeps.append(s)
        ):
            client.chat("s", "u")
        assert sleeps[0] == 0.5

    def test_always_429_stops_after_bounded_attempts(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-bounded")
        client = self._client(max_retries=2)
        calls = {"n": 0}

        def always429(*a, **k):
            calls["n"] += 1
            return _error_response(429, headers={"retry-after": "0.01"})

        with patch("httpx.post", side_effect=always429), patch(
            "app.llm.client.time.sleep"
        ):
            with pytest.raises(LLMQuotaExhaustedError):
                client.chat("s", "u")
        assert calls["n"] == 3  # max_retries + 1, never unbounded

    def test_exponential_backoff_capped_by_max(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-exp")
        client = self._client(max_retries=4, base=10.0, cap=25.0)
        calls = {"n": 0}

        def always429(*a, **k):
            calls["n"] += 1
            return _error_response(429)

        sleeps = []
        with patch("httpx.post", side_effect=always429), patch(
            "app.llm.client.time.sleep", side_effect=lambda s: sleeps.append(s)
        ):
            with pytest.raises(LLMQuotaExhaustedError):
                client.chat("s", "u")
        assert sleeps == [10.0, 20.0, 25.0, 25.0]

    def test_permanent_4xx_never_retries(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-400")
        client = self._client(max_retries=3)
        calls = {"n": 0}

        def always400(*a, **k):
            calls["n"] += 1
            return _error_response(400, text="bad")

        sleeps = []
        with patch("httpx.post", side_effect=always400), patch(
            "app.llm.client.time.sleep", side_effect=lambda s: sleeps.append(s)
        ):
            with pytest.raises(LLMProviderError) as exc_info:
                client.chat("s", "u")
        assert calls["n"] == 1
        assert sleeps == []
        assert exc_info.value.retryable is False

    def test_max_retries_zero_means_single_attempt(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-zero")
        client = self._client(max_retries=0)
        calls = {"n": 0}

        def always429(*a, **k):
            calls["n"] += 1
            return _error_response(429)

        with patch("httpx.post", side_effect=always429), patch(
            "app.llm.client.time.sleep"
        ):
            with pytest.raises(LLMQuotaExhaustedError):
                client.chat("s", "u")
        assert calls["n"] == 1

    def test_non_retryable_error_raised_without_any_sleep(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "k-nr")
        client = self._client(max_retries=3)
        calls = {"n": 0}

        def always400(*a, **k):
            calls["n"] += 1
            return _error_response(400, text="bad")

        with patch("httpx.post", side_effect=always400), patch(
            "app.llm.client.time.sleep"
        ) as mock_sleep:
            with pytest.raises(LLMProviderError):
                client.chat("s", "u")
        mock_sleep.assert_not_called()
        assert calls["n"] == 1


class TestExtractionTypedOutcomes:
    """extract_from_source_page returns typed, distinct outcomes."""

    def test_empty_source_is_empty_extraction_and_no_llm_call(self, monkeypatch):
        called = {"chat": False}

        class FakeLLMClient:
            def __init__(self, *a, **k):
                pass

            def chat(self, *a, **k):
                called["chat"] = True
                return LLMResponse(content="{}", model="x")

        with patch("app.collector.extraction.LLMClient", FakeLLMClient):
            result = extraction.extract_from_source_page(
                source_text="   ", source_url="https://x.com"
            )
        assert called["chat"] is False
        assert isinstance(result, ExtractionResult)
        assert result.status == ExtractionStatus.EMPTY_EXTRACTION.value
        assert result.product_name == ""
        assert result.confidence_level is None

    def test_malformed_response_is_distinct_status(self, monkeypatch):
        class Broken:
            def __init__(self, *a, **k):
                pass

            def chat(self, s, u):
                return LLMResponse(content="not-json{[", model="x")

        with patch("app.collector.extraction.LLMClient", Broken):
            result = extraction.extract_from_source_page(
                source_text="page text", source_url="https://x.com"
            )
        assert isinstance(result, ExtractionResult)
        assert result.status == ExtractionStatus.MALFORMED_LLM_RESPONSE.value
        assert result.product_name == ""
        assert result.ingredients == []
        assert result.retryable is False

    def test_valid_extraction_is_success(self, monkeypatch):
        class Good:
            def __init__(self, *a, **k):
                pass

            def chat(self, s, u):
                return LLMResponse(
                    content=json.dumps({
                        "product_name": "Coffee",
                        "ingredients": [{"name": "Water"}],
                        "confidence_level": 0.9,
                    }),
                    model="fake",
                )

        with patch("app.collector.extraction.LLMClient", Good):
            result = extraction.extract_from_source_page(
                source_text="<html>coffee</html>", source_url="https://x.com"
            )
        assert result.status == ExtractionStatus.SUCCESS.value
        assert result.product_name == "Coffee"
        assert len(result.ingredients) == 1

    def test_provider_failure_is_typed_result_not_empty_dict(self, monkeypatch):
        secret = "AIzaFAKE-PROVIDER-SECRET"
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", secret)

        class Boom:
            def __init__(self, *a, **k):
                pass

            def chat(self, s, u):
                raise LLMQuotaExhaustedError(
                    "quota exhausted", status_code=429, retry_after=3.0
                )

        with patch("app.collector.extraction.LLMClient", Boom):
            result = extraction.extract_from_source_page(
                source_text="page text", source_url="https://x.com"
            )
        assert isinstance(result, ExtractionResult)
        assert result.status == ExtractionStatus.PROVIDER_QUOTA_EXHAUSTED.value
        assert result.retryable is True
        assert result.error_code == "PROVIDER_QUOTA_EXHAUSTED"
        assert secret not in (result.error_detail or "")
        # The payload fields are empty (fields stay missing) but the typed
        # status is the signal -- an empty dict alone must never be the
        # only way to tell a provider failure apart from a bad extraction.
        assert result.raw_data == {}

    def test_provider_statuses_are_all_known(self):
        codes = {
            "PROVIDER_QUOTA_EXHAUSTED",
            "PROVIDER_RATE_LIMITED",
            "PROVIDER_TIMEOUT",
            "PROVIDER_UNAVAILABLE",
            "PROVIDER_ERROR",
        }
        assert {s.value for s in PROVIDER_FAILURE_STATUSES} == codes

    def test_is_provider_failure_boundaries(self):
        good = ExtractionResult(status=ExtractionStatus.SUCCESS.value)
        empty = ExtractionResult(status=ExtractionStatus.EMPTY_EXTRACTION.value)
        malformed = ExtractionResult(
            status=ExtractionStatus.MALFORMED_LLM_RESPONSE.value
        )
        failed = ExtractionResult(
            status=ExtractionStatus.PROVIDER_QUOTA_EXHAUSTED.value,
            retryable=True,
        )
        assert extraction.is_provider_failure(failed) is True
        assert extraction.is_provider_failure(good) is False
        assert extraction.is_provider_failure(empty) is False
        assert extraction.is_provider_failure(malformed) is False
        assert extraction.is_provider_failure(None) is False


class TestPipelineProviderFailureRouting:
    """A provider failure in the collector must land on provider_failed /
    retryable operational state, never on validation_failed."""

    def _candidate(self, source_url="https://www.nestle.com/product"):
        return {
            "id": "cand-provider-1",
            "company_id": "company-1",
            "name": "Coffee",
            "brand": None,
            "barcode": "6281000099999",
            "category": None,
            "country": "SA",
            "market": "packaged_food",
            "source_url": source_url,
            "source_reference": None,
            "raw_data": {"scanned_at": "2026-09-04T00:00:00Z"},
            "status": "discovered",
            "normalized_name": None,
            "normalized_brand": None,
            "normalized_barcode": None,
        }

    def _boom_client(self):
        class _Boom:
            def __init__(self, *a, **k):
                pass

            def chat(self, s, u):
                raise LLMQuotaExhaustedError("quota", status_code=429)

        return _Boom

    def _mock_conn(self, executed_queries):
        conn = MagicMock()
        conn.__enter__ = MagicMock(return_value=conn)
        conn.__exit__ = MagicMock(return_value=False)

        def _execute(query, params=None):
            executed_queries.append(query)
            cursor = MagicMock()
            q = query.strip() if isinstance(query, str) else ""
            if "SELECT" in q:
                cursor.fetchone.return_value = None
                cursor.fetchall.return_value = []
            return cursor

        conn.execute.side_effect = _execute
        return conn

    def test_provider_failure_routed_to_retryable_never_validation_failed(self):
        from app.collector.orchestrator import _process_candidate
        from app.collector.orchestrator import DRY_RUN_FORBIDDEN_TABLES
        from app.collector.models import RetrievalResult

        executed_queries = []
        conn = self._mock_conn(executed_queries)
        candidate = self._candidate()

        with patch("app.collector.orchestrator.get_connection", return_value=conn), \
             patch("app.collector.orchestrator._COLLECTOR_AUTO", True), \
             patch(
                 "app.collector.retrieval.retrieve",
                 return_value=RetrievalResult(
                     success=True, url=candidate["source_url"],
                     content="<html>coffee</html>", content_type="text/html",
                 ),
             ), \
             patch("app.collector.extraction.LLMClient", self._boom_client()):
            result = _process_candidate(
                scan_job_id="job-1", candidate=candidate, dry_run=True
            )

        assert result["action"] == "retryable"
        assert result["provider_failed"] is True
        assert result["retryable"] is True
        assert result["extraction_status"] == "PROVIDER_QUOTA_EXHAUSTED"

        all_q = " ;; ".join(executed_queries)
        assert "'provider_failed'" in all_q
        assert "'retryable'" in all_q
        assert "validation_failed" not in all_q
        assert "Product name is required" not in all_q

        touched_forbidden = []
        for q in executed_queries:
            q_norm = " ".join(q.split())
            for t in DRY_RUN_FORBIDDEN_TABLES:
                if f"INSERT INTO {t} " in q_norm or f"UPDATE {t} " in q_norm:
                    touched_forbidden.append((t, q_norm))
        assert touched_forbidden == [], (
            "provider failure under dry_run must never touch a forbidden "
            "table: " + repr(touched_forbidden)
        )

    def test_scan_company_survives_provider_failure(self):
        from app.collector.orchestrator import scan_company
        from app.collector.models import RetrievalResult

        company_row = {
            "id": "company-1", "name": "Test Co", "internal_code": "CO1",
            "country": "SA", "market": "packaged_food",
        }
        candidate_row = self._candidate()

        executed_queries = []
        conn = MagicMock()
        conn.__enter__ = MagicMock(return_value=conn)
        conn.__exit__ = MagicMock(return_value=False)

        def _execute(query, params=None):
            executed_queries.append(query)
            cursor = MagicMock()
            q = query.strip() if isinstance(query, str) else ""
            if "FROM public.companies" in q:
                cursor.fetchone.return_value = company_row
            elif "FROM public.scan_jobs" in q and "SELECT" in q:
                cursor.fetchone.return_value = None
            elif "FROM public.discovery_candidates" in q and "SELECT" in q:
                cursor.fetchall.return_value = [candidate_row]
                cursor.fetchone.return_value = None
            else:
                cursor.fetchone.return_value = None
                cursor.fetchall.return_value = []
            return cursor

        conn.execute.side_effect = _execute

        fake_coverage = MagicMock()
        fake_coverage.overall_coverage_pct = None

        with patch("app.collector.orchestrator.get_connection", return_value=conn), \
             patch("app.collector.deduplication.get_connection", return_value=conn), \
             patch("app.collector.coverage.get_connection", return_value=conn), \
             patch("app.collector.coverage.calculate_company_coverage", return_value=fake_coverage), \
             patch("app.collector.orchestrator._COLLECTOR_AUTO", True), \
             patch(
                 "app.collector.retrieval.retrieve",
                 return_value=RetrievalResult(
                     success=True, url=candidate_row["source_url"],
                     content="<html>coffee</html>", content_type="text/html",
                 ),
             ), \
             patch("app.collector.extraction.LLMClient", self._boom_client()):
            result = scan_company(company_id="company-1", dry_run=True)

        assert result is not None
        assert result.products_processed == 1
        assert result.products_needs_review == 1
        assert result.status.value in ("completed", "partial", "failed")
        # the provider failure was recorded operationally
        assert any("'provider_failed'" in q for q in executed_queries)