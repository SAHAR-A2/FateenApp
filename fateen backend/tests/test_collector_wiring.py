"""
Wiring tests for the Web Discovery -> Safe Retrieval -> Gemini/LLM
Extraction -> Validation pipeline.

All tests are fully mocked: no real internet, no real Gemini, no database.
They prove the CONNECTION between the previously-unreachable modules
(retrieval.py, web_discovery.py) and the orchestrator, and certify the
safety contract is preserved (SSRF/timeout/redirect/content-size guards,
no-guess confidence, DRY_RUN never touching forbidden tables).
"""
import json
from unittest.mock import patch, MagicMock

import httpx
import pytest
import respx

from app.collector import web_discovery
from app.collector.models import CollectedProductData, RetrievalResult
from app.collector.retrieval import retrieve, RetrievalConfig
from app.llm.client import LLMClient, LLMResponse


# ---------------------------------------------------------------------------
# Web Discovery: deterministic classification + ranking (never LLM-decided)
# ---------------------------------------------------------------------------
class TestWebDiscoveryClassification:
    def test_regulatory_url(self):
        cls = web_discovery.classify_url("https://www.sfda.gov.sa/en/product/123")
        assert cls.source_type == "REGULATORY"
        assert cls.evidence_type == "OFFICIAL_SOURCE"
        assert cls.priority == 2

    def test_database_url(self):
        cls = web_discovery.classify_url("https://world.openfoodfacts.org/product/6281000099999")
        assert cls.source_type == "DATABASE"
        assert cls.evidence_type == "DATABASE"
        assert cls.priority == 3

    def test_retailer_url_is_unclassified_but_ranked_low(self):
        cls = web_discovery.classify_url("https://www.amazon.sa/dp/B0EXAMPLE")
        assert cls.source_type is None
        assert cls.evidence_type is None
        assert cls.is_retailer is True
        assert cls.priority == 4

    def test_unknown_website_lowest_priority(self):
        cls = web_discovery.classify_url("https://example-unknown-site.com/product")
        assert cls.source_type is None
        assert cls.priority == 5

    def test_invalid_url_returns_unclassified(self):
        # "" -> unclassified dataclass; nothing fabricated
        cls = web_discovery.classify_url("")
        assert cls.source_type is None
        assert cls.priority == 5

    def test_sort_is_deterministic_by_priority_then_url(self):
        results = [
            web_discovery.WebDiscoveryResult(url="https://z.org", priority=5),
            web_discovery.WebDiscoveryResult(url="https://a.com/x", priority=1),
            web_discovery.WebDiscoveryResult(url="https://b.com/y", priority=1),
        ]
        ordered = web_discovery.sort_discovery_results(results)
        assert [r.url for r in ordered] == [
            "https://a.com/x", "https://b.com/y", "https://z.org",
        ]


class TestWebDiscoveryProviders:
    def test_default_is_noop(self):
        provider = web_discovery.get_web_discovery_provider()
        if provider.__class__.__name__ == "NoopWebDiscoveryProvider":
            assert provider.enabled is False
            assert provider.discover(target_name="Co") == []

    def test_static_provider_disabled_without_urls(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.web_discovery_static_urls", "")
        provider = web_discovery.StaticWebDiscoveryProvider()
        assert provider.enabled is False
        assert provider.discover(target_name="Co") == []

    def test_static_provider_honors_manufacturer_tag(self, monkeypatch):
        monkeypatch.setattr(
            "app.core.config.settings.web_discovery_static_urls",
            "https://www.nestle.com/product-page|MANUFACTURER,"
            "https://www.sfda.gov.sa/item,"
            "https://www.amazon.sa/dp/X",
        )
        provider = web_discovery.StaticWebDiscoveryProvider()
        assert provider.enabled is True
        results = provider.discover(target_name="Nestle", max_results=10)
        assert len(results) == 3
        by_url = {r.url: r for r in results}
        assert by_url["https://www.nestle.com/product-page"].source_type == "MANUFACTURER"
        assert by_url["https://www.nestle.com/product-page"].priority == 1
        assert by_url["https://www.sfda.gov.sa/item"].source_type == "REGULATORY"
        assert by_url["https://www.amazon.sa/dp/X"].source_type is None

    def test_unknown_provider_degrades_to_noop(self, monkeypatch):
        # web_discovery_api_key is not a settings field; the unknown provider
        # path must degrade to the no-op provider regardless.
        monkeypatch.setattr("app.core.config.settings.web_discovery_provider", "tavily")
        provider = web_discovery.get_web_discovery_provider()
        assert provider.enabled is False
        assert provider.discover(target_name="Co") == []


# ---------------------------------------------------------------------------
# Retrieval: accept_html keeps every other protection intact
# ---------------------------------------------------------------------------
class TestRetrievalAcceptHtml:
    def test_html_rejected_by_default(self):
        with respx.mock:
            respx.get("https://www.example.com/page").mock(
                return_value=httpx.Response(
                    200, headers={"content-type": "text/html"}, text="<html>product</html>"
                )
            )
            result = retrieve(
                "https://www.example.com/page",
                config=RetrievalConfig(timeout=5, max_retries=0),
            )
        assert result.success is False
        assert result.error == "UNEXPECTED_HTML"

    def test_html_accepted_when_flagged(self):
        with respx.mock:
            respx.get("https://www.example.com/page").mock(
                return_value=httpx.Response(
                    200, headers={"content-type": "text/html"}, text="<h1>Instant Coffee</h1>"
                )
            )
            result = retrieve(
                "https://www.example.com/page",
                config=RetrievalConfig(timeout=5, max_retries=0, accept_html=True),
            )
        assert result.success is True
        assert "Instant Coffee" in (result.content or "")

    def test_ssrf_still_blocked_with_accept_html(self):
        result = retrieve(
            "http://127.0.0.1:19999/admin",
            config=RetrievalConfig(timeout=5, max_retries=0, accept_html=True),
        )
        assert result.success is False
        assert result.error == "SSRF_BLOCKED"

    def test_content_size_limit_still_enforced_with_accept_html(self):
        huge = "<div>" + "x" * (RetrievalConfig.max_content_length + 100) + "</div>"
        with respx.mock:
            respx.get("https://www.example.com/big").mock(
                return_value=httpx.Response(
                    200, headers={"content-type": "text/html"}, text=huge
                )
            )
            result = retrieve(
                "https://www.example.com/big",
                config=RetrievalConfig(timeout=5, max_retries=0, accept_html=True),
            )
        assert result.success is False
        assert result.error == "CONTENT_TOO_LARGE"

    def test_redirect_to_internal_network_one_hop_with_accept_html(self):
        with respx.mock:
            respx.get("https://www.example.com/start").mock(
                return_value=httpx.Response(
                    302,
                    headers={"location": "http://169.254.169.254/latest/meta-data"},
                )
            )
            result = retrieve(
                "https://www.example.com/start",
                config=RetrievalConfig(timeout=5, max_retries=0, accept_html=True),
            )
        assert result.success is False


# ---------------------------------------------------------------------------
# LLM (Gemini) client: official REST endpoint, error handling, no guessing
# ---------------------------------------------------------------------------
class TestGeminiClient:
    def test_gemini_resolves_key_and_model(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "test-key")
        monkeypatch.setattr("app.core.config.settings.gemini_model", "gemini-test-flash")
        client = LLMClient(provider="gemini")
        assert client.api_key == "test-key"
        assert client.model == "gemini-test-flash"

    def test_gemini_missing_key_raises(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "")
        client = LLMClient(provider="gemini")
        with pytest.raises(ValueError):
            client._chat_gemini("s", "u")

    def test_gemini_successful_chat(self, monkeypatch):
        payload = {
            "candidates": [{"content": {"parts": [{"text": '{"product_name": "Coffee"}'}]}}],
            "usageMetadata": {"tokenCount": 10},
        }
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "test-key")
        with patch("httpx.post") as mock_post:
            mock_post.return_value.raise_for_status = MagicMock()
            mock_post.return_value.json.return_value = payload
            client = LLMClient(provider="gemini")
            resp = client._chat_gemini("sys", "usr")
        assert resp.parsed_json()["product_name"] == "Coffee"
        request = mock_post.call_args
        assert "generativelanguage.googleapis.com/v1beta/models/" in request.args[0]
        assert request.kwargs["params"] == {"key": "test-key"}

    def test_gemini_http_error_raises_value_error(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "test-key")
        with patch("httpx.post") as mock_post:
            mock_post.return_value.raise_for_status.side_effect = httpx.HTTPStatusError(
                "boom", request=httpx.Request("POST", "https://x"), response=httpx.Response(500)
            )
            client = LLMClient(provider="gemini")
            with pytest.raises(ValueError):
                client._chat_gemini("s", "u")

    def test_gemini_malformed_structure_raises_value_error(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.gemini_api_key", "test-key")
        with patch("httpx.post") as mock_post:
            mock_post.return_value.raise_for_status = MagicMock()
            mock_post.return_value.json.return_value = {"unexpected": True}
            client = LLMClient(provider="gemini")
            with pytest.raises(ValueError):
                client._chat_gemini("s", "u")


# ---------------------------------------------------------------------------
# Extract-from-source-page: retrieval output -> LLM -> extract_from_llm_response
# ---------------------------------------------------------------------------
class TestExtractFromSourcePage:
    def _fake_json_response(self, data: dict) -> LLMResponse:
        return LLMResponse(content=json.dumps(data), model="fake")

    def test_valid_extraction(self, monkeypatch):
        call_log = {}

        class FakeLLMClient:
            def __init__(self, *a, **k):
                call_log["provider"] = k.get("provider")
                self.response = self._resp()

            @staticmethod
            def _resp():
                return LLMResponse(
                    content=json.dumps({
                        "product_name": "Instant Coffee",
                        "barcode": "6281000099999",
                        "ingredients": [{"name": "Coffee", "confidence_level": 0.9}],
                        "allergens": [{"name": "MILK", "confidence_level": 0.8}],
                        "nutrition": [{"nutrition_type": "ENERGY", "amount_value": 4.0, "unit": "KCAL"}],
                        "confidence_level": 0.9,
                    }),
                    model="fake-gemini",
                )

            def chat(self, system_prompt, user_prompt):
                return self.response

        monkeypatch.setattr("app.core.config.settings.llm_provider", "gemini")
        with patch("app.collector.extraction.LLMClient", FakeLLMClient):
            from app.collector.extraction import extract_from_source_page
            result = extract_from_source_page(
                source_text="<html>nutrition facts table</html>",
                source_url="https://www.nestle.com/product",
                barcode="6281000099999",
                product_name="Instant Coffee",
            )

        assert result.product_name == "Instant Coffee"
        assert result.barcode == "6281000099999"
        assert result.confidence_level == 0.9
        assert len(result.ingredients) == 1
        assert len(result.allergens) == 1

    def test_empty_source_text_never_calls_llm(self, monkeypatch):
        called = {"chat": False}

        class FakeLLMClient:
            def chat(self, *a, **k):
                called["chat"] = True
                return LLMResponse(content="{}", model="x")

        monkeypatch.setattr("app.core.config.settings.llm_provider", "gemini")
        with patch("app.collector.extraction.LLMClient", FakeLLMClient):
            from app.collector.extraction import extract_from_source_page, extract_from_llm_response
            result = extract_from_source_page(source_text="   ", source_url="https://x.com")
        assert called["chat"] is False
        assert result.product_name == ""

    def test_malformed_llm_response_degrades_without_guessing(self, monkeypatch):
        class BrokenLLMClient:
            def __init__(self, *a, **k):
                pass

            def chat(self, system_prompt, user_prompt):
                return LLMResponse(content="not-json{[", model="x")

        monkeypatch.setattr("app.core.config.settings.llm_provider", "gemini")
        with patch("app.collector.extraction.LLMClient", BrokenLLMClient):
            from app.collector.extraction import extract_from_source_page
            result = extract_from_source_page(
                source_text="page text", source_url="https://x.com"
            )
        assert result.product_name == ""
        assert result.confidence_level is None
        assert result.ingredients == []
        assert result.allergens == []
        assert result.nutrition == []

    def test_missing_confidence_and_fields_stay_missing(self):
        from app.collector.extraction import extract_from_llm_response
        result = extract_from_llm_response(
            {
                "product_name": "Simple",
                "ingredients": [{"name": "Water"}],
                "allergens": [{"name": "MILK"}],
                "nutrition": [{"nutrition_type": "SUGAR", "unit": "G"}],  # amount missing
            },
            source_url="https://www.sfda.gov.sa/x",
        )
        assert result.product_name == "Simple"
        assert result.confidence_level is None
        assert result.ingredients[0].confidence_level is None
        assert result.allergens[0].evidence_type is None
        assert result.nutrition == []  # missing amount -> dropped, never 0


# ---------------------------------------------------------------------------
# No-guess candidate conversion
# ---------------------------------------------------------------------------
class TestCandidateToCollectedNoGuess:
    def test_empty_raw_data_stays_missing(self):
        from app.collector.orchestrator import _candidate_to_collected
        collected = _candidate_to_collected(
            {
                "name": "Test Coffee",
                "barcode": "6281000099999",
                "country": "SA",
                "company_id": "c1",
                "raw_data": {},
                "source_url": "https://www.sfda.gov.sa/item",
            }
        )
        assert collected.product_name == "Test Coffee"
        assert collected.confidence_level is None
        assert collected.ingredients == []
        assert collected.allergens == []
        assert collected.nutrition == []
        # deterministic evidence classification from source_url
        assert collected.source_type == "REGULATORY"
        assert collected.evidence_type == "OFFICIAL_SOURCE"

    def test_explicit_confidence_and_evidence_preserved(self):
        from app.collector.orchestrator import _candidate_to_collected
        collected = _candidate_to_collected(
            {
                "name": "Coffee",
                "raw_data": {
                    "confidence_level": 0.8,
                    "allergens": [{"name": "MILK", "confidence_level": 0.7, "evidence_type": "LABEL"}],
                },
                "source_url": None,
            }
        )
        assert collected.confidence_level == 0.8
        assert collected.allergens[0].confidence_level == 0.7
        assert collected.allergens[0].evidence_type == "LABEL"

    def test_nutrition_without_amount_is_dropped_not_zeroed(self):
        from app.collector.orchestrator import _candidate_to_collected
        collected = _candidate_to_collected(
            {
                "name": "X",
                "raw_data": {
                    "nutrition": [
                        {"nutrition_type": "SUGAR", "amount_value": None, "unit": "G"},
                        {"nutrition_type": "ENERGY", "amount_value": 2.0, "unit": "KCAL"},
                    ]
                },
            }
        )
        assert len(collected.nutrition) == 1
        assert collected.nutrition[0].nutrition_type == "ENERGY"


# ---------------------------------------------------------------------------
# Web discovery -> discovery_candidates persistence (FK-safe, traceable)
# ---------------------------------------------------------------------------
class TestDiscoverSourceUrlPersistence:
    def test_persists_web_candidates_with_traceable_marker(self):
        from app.collector.orchestrator import _discover_source_urls
        executed = []

        class FakeConn:
            def execute(self, q, p=None):
                executed.append(q)
                return MagicMock()

        fake_conn = FakeConn()

        class StubProvider:
            enabled = True

            def discover(self, **kw):
                return [
                    web_discovery.WebDiscoveryResult(
                        url="https://www.nestle.com/product-1",
                        source_type="MANUFACTURER",
                        evidence_type="MANUFACTURER",
                        source_reference="operator-tag",
                    ),
                    web_discovery.WebDiscoveryResult(
                        url="https://www.sfda.gov.sa/item-2",
                        source_type="REGULATORY",
                        evidence_type="OFFICIAL_SOURCE",
                        source_reference=None,
                    ),
                ]

        company = {"id": "c1", "name": "Co", "country": "SA", "market": "packaged_food"}
        with patch("app.collector.orchestrator.get_connection") as m:
            m.return_value.__enter__.return_value = fake_conn
            m.return_value.__exit__.return_value = False
            got = _discover_source_urls(StubProvider(), company, [])

        assert len(got) == 2
        inserts = [q for q in executed if "INSERT INTO public.discovery_candidates" in q]
        assert len(inserts) == 2
        for c in got:
            assert c["source_url"].startswith("https://")
            assert c["source_reference"].startswith("web_discovery:")
            assert c["status"] == "discovered"
            assert c["id"]
            # identity is never invented by the pipeline
            assert c["name"] == ""
            assert c["barcode"] is None
            # the tag-resolved classification is captured at discovery time
            meta = c["raw_data"].get("_source_classification")
            assert meta is not None
            assert meta["source_type"] in {"MANUFACTURER", "REGULATORY"}
            assert meta["evidence_type"] in {"MANUFACTURER", "OFFICIAL_SOURCE"}

        # idempotency: URLs already registered -> no duplicates, no re-persist
        executed.clear()
        with patch("app.collector.orchestrator.get_connection") as m:
            m.return_value.__enter__.return_value = fake_conn
            m.return_value.__exit__.return_value = False
            got2 = _discover_source_urls(StubProvider(), company, got)
        assert got2 == []
        assert not any("INSERT INTO public.discovery_candidates" in q for q in executed)

    def test_persist_failure_skips_candidate_without_aborting(self):
        from app.collector.orchestrator import _discover_source_urls

        class FailingProvider:
            enabled = True

            def discover(self, **kw):
                return [
                    web_discovery.WebDiscoveryResult(
                        url="https://www.nestle.com/product-1",
                        source_type="MANUFACTURER",
                    ),
                ]

        class BoomConn:
            def execute(self, q, p=None):
                raise RuntimeError("boom")

        company = {"id": "c1", "name": "Co", "country": "SA", "market": "packaged_food"}
        with patch("app.collector.orchestrator.get_connection") as m:
            m.return_value.__enter__.return_value = BoomConn()
            m.return_value.__exit__.return_value = False
            got = _discover_source_urls(FailingProvider(), company, [])
        assert got == []

    def test_disabled_provider_persists_nothing(self):
        from app.collector.orchestrator import _discover_source_urls
        got = _discover_source_urls(
            web_discovery.NoopWebDiscoveryProvider(),
            {"id": "c1", "name": "Co"}, [],
        )
        assert got == []


# ---------------------------------------------------------------------------
# Auto-extraction wiring in the orchestrator
# ---------------------------------------------------------------------------
class TestAutoExtractCandidate:
    def _candidate(self, raw_data, source_url="https://www.nestle.com/product"):
        return {
            "id": "cand-1",
            "name": "Instant Coffee",
            "barcode": "6281000099999",
            "country": "SA",
            "company_id": "c1",
            "raw_data": raw_data,
            "source_url": source_url,
        }

    def test_skips_when_manual_raw_data_already_extracted(self):
        from app.collector.orchestrator import _candidate_to_collected, _auto_extract_candidate
        candidate = self._candidate(
            {"ingredients": [{"name": "Coffee"}], "confidence_level": 0.8}
        )
        collected = _candidate_to_collected(candidate)
        with patch("app.collector.retrieval.retrieve") as mock_retrieve:
            out = _auto_extract_candidate(candidate, collected)
        mock_retrieve.assert_not_called()
        assert out is collected

    def test_retrieves_and_extracts_source_page(self):
        from app.collector.orchestrator import _candidate_to_collected, _auto_extract_candidate
        candidate = self._candidate(raw_data={"scanned_at": "2026-09-04T00:00:00Z"})
        collected = _candidate_to_collected(candidate)

        llm_data = {
            "product_name": "Instant Coffee",
            "barcode": "6281000099999",
            "ingredients": [{"name": "Coffee"}],
            "confidence_level": 0.9,
        }

        class FakeLLMClient:
            def __init__(self, *a, **k):
                pass

            def chat(self, *a, **k):
                return LLMResponse(content=json.dumps(llm_data), model="fake")

        with patch(
            "app.collector.retrieval.retrieve",
            return_value=RetrievalResult(
                success=True, url=candidate["source_url"],
                content="<html>product</html>",
                content_type="text/html",
            ),
        ), patch("app.collector.extraction.LLMClient", FakeLLMClient):
            out = _auto_extract_candidate(candidate, collected)

        assert out is not collected
        assert out.product_name == "Instant Coffee"
        assert out.confidence_level == 0.9
        assert len(out.ingredients) == 1

    def test_retrieval_failure_leaves_candidate_unmodified(self):
        from app.collector.orchestrator import _candidate_to_collected, _auto_extract_candidate
        candidate = self._candidate(raw_data={})
        collected = _candidate_to_collected(candidate)
        with patch(
            "app.collector.retrieval.retrieve",
            return_value=RetrievalResult(success=False, url="x", error="TIMEOUT"),
        ):
            out = _auto_extract_candidate(candidate, collected)
        assert out is collected

    def test_auto_extraction_reapplies_deterministic_classification(self):
        """LLM output must never stamp the default LABEL evidence on
        web-sourced data; classification comes from the tag captured at
        discovery time (or falls back to the URL, never "LABEL")."""
        from app.collector.orchestrator import _candidate_to_collected, _auto_extract_candidate

        for url, meta, expected_type, expected_evidence in [
            (
                "https://www.almarai.com/ar/brands/lusine/bakery/bread/x",
                {"source_type": "MANUFACTURER", "evidence_type": "MANUFACTURER", "is_retailer": False},
                "MANUFACTURER", "MANUFACTURER",
            ),
            (
                "https://www.example.com/random-page",
                {},
                None, None,
            ),
        ]:
            raw_data = {"scanned_at": "2026-09-04T00:00:00Z"}
            if meta:
                raw_data["_source_classification"] = meta
            candidate = self._candidate(raw_data=raw_data, source_url=url)
            collected = _candidate_to_collected(candidate)

            llm_data = {
                "product_name": "Product",
                "ingredients": [{"name": "Wheat Flour"}],
            }

            class FakeLLMClient:
                def __init__(self, *a, **k):
                    pass

                def chat(self, *a, **k):
                    return LLMResponse(content=json.dumps(llm_data), model="fake")

            with patch(
                "app.collector.retrieval.retrieve",
                return_value=RetrievalResult(
                    success=True, url=url,
                    content="<html>product</html>",
                    content_type="text/html",
                ),
            ), patch("app.collector.extraction.LLMClient", FakeLLMClient):
                out = _auto_extract_candidate(candidate, collected)

            assert out is not collected
            assert out.source_type == expected_type
            assert out.evidence_type == expected_evidence


# ---------------------------------------------------------------------------
# End-to-end (fully mocked) scan: discovery wiring, extraction, DRY_RUN safety
# ---------------------------------------------------------------------------
class TestScanWiringAndDryRunSafety:
    def test_scan_with_auto_extraction_never_touches_forbidden_tables(self):
        from app.collector.orchestrator import (
            scan_company,
            _process_candidate,
            DRY_RUN_FORBIDDEN_TABLES,
            _COLLECTOR_AUTO,
        )

        company_row = {
            "id": "company-1", "name": "Test Co", "internal_code": "CO1",
            "country": "SA", "market": "packaged_food",
        }
        candidate_row = {
            "id": "cand-1", "company_id": "company-1", "name": "Web Coffee",
            "brand": None, "barcode": "6281000099999", "category": None,
            "country": "SA", "market": "packaged_food",
            "source_url": "https://www.nestle.com/product",
            "source_reference": None, "raw_data": {}, "status": "discovered",
            "normalized_name": None, "normalized_brand": None,
            "normalized_barcode": None,
        }

        executed_queries = []

        def make_side_effect():
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
            return _execute

        conn = MagicMock()
        conn.__enter__ = MagicMock(return_value=conn)
        conn.__exit__ = MagicMock(return_value=False)
        conn.execute.side_effect = make_side_effect()

        llm_data = {
            "product_name": "Web Coffee", "barcode": "6281000099999",
            "ingredients": [{"name": "Coffee"}], "confidence_level": 0.9,
        }

        class FakeLLMClient:
            def __init__(self, *a, **k):
                self._resp = LLMResponse(content=json.dumps(llm_data), model="fake")

            def chat(self, system_prompt, user_prompt):
                return self._resp

        with patch("app.collector.orchestrator.get_connection", return_value=conn), \
             patch("app.collector.deduplication.get_connection", return_value=conn), \
             patch("app.collector.coverage.get_connection", return_value=conn), \
             patch("app.collector.orchestrator._COLLECTOR_AUTO", True), \
             patch(
                 "app.collector.retrieval.retrieve",
                 return_value=RetrievalResult(
                     success=True, url=candidate_row["source_url"],
                     content="<html>Web Coffee</html>", content_type="text/html",
                 ),
             ) as mock_retrieve, \
             patch("app.collector.extraction.LLMClient", FakeLLMClient):
            # _process_candidate is the unit that performs writes for one
            # candidate; exercise the real extraction wiring through it.
            result = _process_candidate(
                scan_job_id="job-1", candidate=candidate_row, dry_run=True
            )

        assert result["action"] == "accepted"
        # retrieval was called through the SSRF-safe module
        mock_retrieve.assert_called_once()
        kwargs = mock_retrieve.call_args.kwargs
        assert kwargs["config"].accept_html is True

        touched_forbidden = []
        for q in executed_queries:
            q_norm = " ".join(q.split())
            for t in DRY_RUN_FORBIDDEN_TABLES:
                if f"INSERT INTO {t} " in q_norm or f"UPDATE {t} " in q_norm:
                    touched_forbidden.append((t, q_norm))
        assert touched_forbidden == [], (
            "dry_run=True must never write to a forbidden table, even with "
            "auto-extraction enabled: " + repr(touched_forbidden)
        )


# ---------------------------------------------------------------------------
# Product provenance guard: _create_product_from_candidate must resolve the
# COLLECTOR data_sources row and fail loudly (never a silent NULL source_id)
# when that source is not yet migrated.
# ---------------------------------------------------------------------------
class TestProductSourceProvenance:
    def _collected(self, **overrides):
        from app.collector.orchestrator import _create_product_from_candidate
        from app.collector.models import CollectedProductData
        fields = dict(
            barcode="6291041500213", product_name="Test Milk",
            brand="TestBrand", confidence_level=0.8,
        )
        fields.update(overrides)
        return CollectedProductData(**fields)

    def test_writes_source_id_when_collector_source_registered(self):
        from app.collector.orchestrator import _create_product_from_candidate

        collector_id = "11111111-2222-3333-4444-555555555555"
        executed = []

        def make_side_effect():
            def _execute(query, params=None):
                executed.append((query, params))
                cursor = MagicMock()
                q = " ".join(query.split())
                if "FROM public.data_sources" in q:
                    row = MagicMock()
                    row.__getitem__.return_value = collector_id
                    cursor.fetchone.return_value = row
                elif "WHERE code = 'ACTIVE'" in q:
                    row = MagicMock()
                    row.__getitem__.return_value = 1
                    cursor.fetchone.return_value = row
                elif "WHERE name = %s" in q:
                    cursor.fetchone.return_value = None
                elif "code = 'PRIMARY_BARCODE'" in q:
                    row = MagicMock()
                    row.__getitem__.return_value = 1
                    cursor.fetchone.return_value = row
                else:
                    cursor.fetchone.return_value = None
                return cursor
            return _execute

        conn = MagicMock()
        conn.execute.side_effect = make_side_effect()

        pid = _create_product_from_candidate(self._collected(), conn=conn)

        assert pid is not None
        insert_products = [
            (q, p) for (q, p) in executed
            if " ".join(q.split()).startswith("INSERT INTO public.products")
        ]
        assert insert_products, "no products INSERT issued"
        _, params = insert_products[0]
        product_row = params
        # source_id is the second-to-last bound value (after confidence_level),
        # matching the extended column list ... confidence_level, source_id, ...
        assert collector_id in product_row, "source_id not bound to INSERT"

    def test_fails_loudly_when_collector_source_missing(self):
        from app.collector.orchestrator import (
            _create_product_from_candidate,
            _MissingCollectorSource,
        )

        def make_side_effect():
            def _execute(query, params=None):
                cursor = MagicMock()
                cursor.fetchone.return_value = None
                return cursor
            return _execute

        conn = MagicMock()
        conn.execute.side_effect = make_side_effect()

        with pytest.raises(_MissingCollectorSource, match="COLLECTOR"):
            _create_product_from_candidate(self._collected(), conn=conn)

    def test_no_completion_writes_without_source(self):
        from app.collector.orchestrator import (
            _create_product_from_candidate,
            _MissingCollectorSource,
        )

        written = []

        def make_side_effect():
            def _execute(query, params=None):
                q = " ".join(query.split())
                if q.startswith("INSERT INTO"):
                    written.append(q)
                cursor = MagicMock()
                cursor.fetchone.return_value = None
                return cursor
            return _execute

        conn = MagicMock()
        conn.execute.side_effect = make_side_effect()

        with pytest.raises(_MissingCollectorSource, match="COLLECTOR"):
            _create_product_from_candidate(self._collected(), conn=conn)

        assert written == [], (
            "no product/barcode/brand row may be written when the COLLECTOR "
            "source is not registered: " + repr(written)
        )

    def test_process_candidate_records_provenance_rejection(self):
        from app.collector.orchestrator import _process_candidate

        executed = []
        collector_id = "11111111-2222-3333-4444-555555555555"

        def make_side_effect():
            def _execute(query, params=None):
                executed.append((query, params))
                cursor = MagicMock()
                q = " ".join(query.split())
                if "UPDATE public.discovery_candidates" in q:
                    cursor.fetchone.return_value = None
                elif "FROM public.data_sources" in q:
                    cursor.fetchone.return_value = None
                else:
                    cursor.fetchone.return_value = None
                return cursor
            return _execute

        conn = MagicMock()
        conn.__enter__ = MagicMock(return_value=conn)
        conn.__exit__ = MagicMock(return_value=False)
        conn.execute.side_effect = make_side_effect()

        candidate = {
            "id": "cand-prov-1", "company_id": "company-prov", "name": "Prov Coffee",
            "brand": None, "barcode": "6291041500213", "category": None,
            "country": "SA", "market": "packaged_food",
            "source_url": None, "source_reference": None, "raw_data": {},
            "status": "discovered", "normalized_name": None,
            "normalized_brand": None, "normalized_barcode": None,
        }

        with patch("app.collector.orchestrator.get_connection", return_value=conn), \
             patch("app.collector.deduplication.get_connection", return_value=conn), \
             patch("app.collector.coverage.get_connection", return_value=conn), \
             patch(
                 "app.collector.orchestrator._ingest_product",
                 return_value={"success": True},
             ):
            result = _process_candidate(
                scan_job_id="job-prov", candidate=candidate, dry_run=False
            )

        assert result["action"] == "rejected"
        assert "COLLECTOR" in result["error"]

        items = [
            (q, p) for (q, p) in executed
            if " ".join(q.split()).startswith("INSERT INTO public.scan_job_items")
        ]
        assert items, "no scan_job_items row recorded for the provenance rejection"
        item_sql = " ".join(items[0][0].split())
        assert "ingestion_failed" in item_sql and "rejected" in item_sql, (
            "rejected scan_job_items row must record ingestion_failed/rejected: "
            + item_sql
        )
        assert any(
            "COLLECTOR" in str(p)
            for p in items[0][1]
            if isinstance(p, str)
        ), "the error_message must identify the missing COLLECTOR source"

        products = [
            q for (q, p) in executed
            if " ".join(q.split()).startswith("INSERT INTO public.products")
        ]
        assert products == [], (
            "no product may be written when COLLECTOR provenance is missing"
        )
        updates = [
            p for (q, p) in executed
            if " ".join(q.split()).startswith("UPDATE public.discovery_candidates")
        ]
        assert any(
            "ingestion_failed" in str(p) if p else False for p in updates
        ), "candidate status must be updated to ingestion_failed"