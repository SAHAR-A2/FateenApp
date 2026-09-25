"""
Groq LLM provider tests (offline, fully mocked).

Every test either patches httpx.post or only inspects provider/model
routing, so a real Groq API endpoint is never reached. Covers:

  1. provider="groq" selects settings.groq_api_key
  2. provider="groq" selects settings.groq_model
  3. provider="groq" selects _chat_groq
  4. successful OpenAI-compatible response parsing
  5. timeout -> LLMTimeoutError
  6. connection failure -> LLMUnavailableError
  7. HTTP status failure -> _make_status_error
  8. no secret appears in raised/logged error text
"""
from unittest.mock import patch

import httpx
import pytest

from app.llm.client import (
    LLMClient,
    LLMProviderError,
    LLMTimeoutError,
    LLMUnavailableError,
)


def _error_response(status_code, text="", headers=None, **kwargs):
    return httpx.Response(
        status_code,
        text=text,
        headers=headers or {},
        request=httpx.Request("POST", "https://api.groq.com/openai/v1/chat/completions"),
        **kwargs,
    )


def _ok_response():
    return httpx.Response(
        200,
        request=httpx.Request("POST", "https://api.groq.com/openai/v1/chat/completions"),
        json={
            "choices": [{"message": {"content": '{"product_name": "X"}'}}],
            "model": "llama-3.1-8b-instant",
            "usage": {"prompt_tokens": 5, "completion_tokens": 7, "total_tokens": 12},
        },
    )


def _groq_client():
    return LLMClient(provider="groq")


class TestGroqConfigRouting:
    def test_selects_groq_api_key(self, monkeypatch):
        monkeypatch.setattr(
            "app.core.config.settings.groq_api_key", "groq-test-key"
        )
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        assert _groq_client().api_key == "groq-test-key"

    def test_selects_groq_model(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.groq_api_key", "groq-test-key")
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        assert _groq_client().model == "groq-m"

    def test_selects_chat_groq_method(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.groq_api_key", "groq-test-key")
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        assert _groq_client()._provider_method().__name__ == "_chat_groq"


class TestGroqChat:
    def test_missing_api_key_raises_value_error(self, monkeypatch):
        monkeypatch.setattr("app.core.config.settings.groq_api_key", "")
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        with pytest.raises(ValueError) as exc_info:
            _groq_client()._chat_groq("s", "u")
        assert "GROQ_API_KEY" in str(exc_info.value)
        assert "groq-test-key" not in str(exc_info.value)

    def test_success_parses_openai_compatible_response(self, monkeypatch):
        monkeypatch.setattr(
            "app.core.config.settings.groq_api_key", "groq-test-key"
        )
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        client = _groq_client()

        captured = {}

        def fake_post(url, **kwargs):
            captured["url"] = url
            captured["kwargs"] = kwargs
            return _ok_response()

        with patch("httpx.post", side_effect=fake_post):
            result = client._chat_groq("sys", "usr")

        assert captured["url"] == "https://api.groq.com/openai/v1/chat/completions"
        assert captured["kwargs"]["headers"]["Authorization"] == "Bearer groq-test-key"
        assert captured["kwargs"]["headers"]["Content-Type"] == "application/json"
        assert captured["kwargs"]["json"]["model"] == "groq-m"
        assert captured["kwargs"]["json"]["messages"] == [
            {"role": "system", "content": "sys"},
            {"role": "user", "content": "usr"},
        ]
        assert captured["kwargs"]["json"]["temperature"] == 0.1
        assert captured["kwargs"]["json"]["response_format"] == {"type": "json_object"}

        assert result.content == '{"product_name": "X"}'
        assert result.model == "llama-3.1-8b-instant"
        assert result.usage == {
            "prompt_tokens": 5, "completion_tokens": 7, "total_tokens": 12,
        }
        assert result.raw["choices"][0]["message"]["content"] == '{"product_name": "X"}'

    def test_timeout_maps_to_typed_timeout(self, monkeypatch):
        monkeypatch.setattr(
            "app.core.config.settings.groq_api_key", "groq-test-key"
        )
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        with patch("httpx.post", side_effect=httpx.ReadTimeout("read timed out")):
            client = _groq_client()
            with pytest.raises(LLMTimeoutError) as exc_info:
                client._chat_groq("s", "u")
        assert exc_info.value.code == "PROVIDER_TIMEOUT"
        assert exc_info.value.retryable is True
        assert exc_info.value.__cause__ is None

    def test_connect_error_maps_to_unavailable(self, monkeypatch):
        monkeypatch.setattr(
            "app.core.config.settings.groq_api_key", "groq-test-key"
        )
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        with patch("httpx.post", side_effect=httpx.ConnectError("refused")):
            client = _groq_client()
            with pytest.raises(LLMUnavailableError) as exc_info:
                client._chat_groq("s", "u")
        assert exc_info.value.code == "PROVIDER_UNAVAILABLE"
        assert exc_info.value.retryable is True
        assert exc_info.value.__cause__ is None

    def test_http_status_failure_uses_make_status_error(self, monkeypatch):
        monkeypatch.setattr(
            "app.core.config.settings.groq_api_key", "groq-test-key"
        )
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        with patch("httpx.post", return_value=_error_response(429, text="{ }")):
            client = _groq_client()
            with pytest.raises(LLMProviderError) as exc_info:
                client._chat_groq("s", "u")
        assert exc_info.value.code == "PROVIDER_QUOTA_EXHAUSTED"
        assert exc_info.value.retryable is True
        assert exc_info.value.status_code == 429

    def test_secret_never_appears_in_error_text(self, monkeypatch):
        secret = "groq-supersecret-1234567890"
        monkeypatch.setattr("app.core.config.settings.groq_api_key", secret)
        monkeypatch.setattr("app.core.config.settings.groq_model", "groq-m")
        with patch(
            "httpx.post",
            return_value=_error_response(
                429, text=f'{{"error": {{"message": "{secret}"}}}}'
            ),
        ):
            client = _groq_client()
            with pytest.raises(LLMProviderError) as exc_info:
                client._chat_groq("s", "u")
        assert secret not in str(exc_info.value)
        assert exc_info.value.__cause__ is None