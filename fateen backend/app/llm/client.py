import json
import logging
import time
from dataclasses import dataclass, field
from typing import Optional

from app.core.config import settings

logger = logging.getLogger("fateen.llm.client")


class LLMProviderError(ValueError):
    """Base class for typed LLM provider failures.

    Subclasses ValueError so legacy callers that caught ``ValueError`` keep
    working. The ``code`` attribute is a stable machine-readable outcome
    (e.g. ``PROVIDER_QUOTA_EXHAUSTED``). Instances NEVER embed the provider
    API key or the request URL -- the Gemini key travels in the request
    query string, so httpx error reprs (which include the URL) are
    deliberately suppressed via ``raise ... from None`` and replaced with
    sanitized messages. ``retryable`` drives the bounded retry loop in
    ``LLMClient.chat``.
    """

    code = "PROVIDER_ERROR"
    retryable = False

    def __init__(
        self,
        message: str = "",
        *,
        status_code: Optional[int] = None,
        retry_after: Optional[float] = None,
    ):
        self.status_code = status_code
        self.retry_after = retry_after
        super().__init__(message or self.code)


class LLMQuotaExhaustedError(LLMProviderError):
    """Provider capacity exhausted (HTTP 429 / RESOURCE_EXHAUSTED)."""

    code = "PROVIDER_QUOTA_EXHAUSTED"
    retryable = True


class LLMRateLimitError(LLMProviderError):
    """Provider rate limited (HTTP 429 without explicit quota semantics)."""

    code = "PROVIDER_RATE_LIMITED"
    retryable = True


class LLMTimeoutError(LLMProviderError):
    """Provider request timed out (transport-level)."""

    code = "PROVIDER_TIMEOUT"
    retryable = True


class LLMUnavailableError(LLMProviderError):
    """Provider unavailable (HTTP 5xx or connection-level failure)."""

    code = "PROVIDER_UNAVAILABLE"
    retryable = True


def _redact_secret(text: str, secret: str) -> str:
    """Replace a secret value inside a snippet, protecting API keys."""
    if not text:
        return ""
    if not secret:
        return text
    return text.replace(str(secret), "[REDACTED]")


def _parse_retry_after(value) -> Optional[float]:
    if value is None:
        return None
    try:
        parsed = float(value)
    except (ValueError, TypeError):
        return None
    return parsed if parsed > 0 else None


def _make_status_error(provider: str, resp, api_key: str) -> LLMProviderError:
    """Build a typed, sanitized error for a non-2xx provider response.

    The message never includes the request URL (the Gemini API key travels
    in the URL query string). The response body snippet is redacted against
    the API key as defense in depth.
    """
    status_code = getattr(resp, "status_code", None) or 0
    try:
        status_code = int(status_code)
    except (TypeError, ValueError):
        status_code = 0
    retry_after = _parse_retry_after(
        (resp.headers.get("retry-after") if getattr(resp, "headers", None) else None)
    )
    body = _redact_secret(
        (getattr(resp, "text", "") or "")[:300], api_key
    ).strip()
    detail = f"{provider} request failed with HTTP {status_code}"
    if body:
        detail += f": {body}"

    if status_code == 429:
        return LLMQuotaExhaustedError(
            detail, status_code=status_code, retry_after=retry_after
        )
    if status_code >= 500:
        return LLMUnavailableError(detail, status_code=status_code)
    return LLMProviderError(detail, status_code=status_code)


@dataclass
class LLMResponse:
    content: str
    model: str
    usage: dict = field(default_factory=dict)
    raw: Optional[dict] = None

    def parsed_json(self) -> dict:
        try:
            return json.loads(self.content)
        except json.JSONDecodeError:
            text = self.content
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0]
            elif "```" in text:
                text = text.split("```")[1].split("```")[0]
            return json.loads(text.strip())


class LLMClient:
    def __init__(self, provider: Optional[str] = None):
        self.provider = provider or settings.llm_provider
        self.api_key = self._get_api_key()
        self.model = self._get_model()
        self.timeout = settings.llm_timeout
        self.max_retries = self._coerce_max_retries(settings.llm_max_retries)
        self.retry_backoff_base = self._coerce_backoff(settings.llm_retry_backoff_base, 2.0)
        self.retry_backoff_max = self._coerce_backoff(settings.llm_retry_backoff_max, 30.0)

    @staticmethod
    def _coerce_max_retries(value) -> int:
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            parsed = 2
        return max(0, min(parsed, 10))

    @staticmethod
    def _coerce_backoff(value, default: float) -> float:
        try:
            parsed = float(value)
        except (TypeError, ValueError):
            return default
        if parsed != parsed:  # NaN
            return default
        return parsed if parsed > 0 else default

    def _get_api_key(self) -> str:
        if self.provider == "openai":
            return settings.openai_api_key
        elif self.provider == "anthropic":
            return settings.anthropic_api_key
        elif self.provider == "ollama":
            return ""
        elif self.provider == "gemini":
            return settings.gemini_api_key
        elif self.provider == "groq":
            return settings.groq_api_key
        else:
            raise ValueError(f"Unsupported LLM provider: {self.provider}")

    def _get_model(self) -> str:
        if self.provider == "openai":
            return settings.openai_model
        elif self.provider == "anthropic":
            return settings.anthropic_model
        elif self.provider == "ollama":
            return settings.ollama_model
        elif self.provider == "gemini":
            return settings.gemini_model
        elif self.provider == "groq":
            return settings.groq_model
        else:
            raise ValueError(f"Unsupported LLM provider: {self.provider}")

    def _provider_method(self):
        if self.provider == "openai":
            return self._chat_openai
        elif self.provider == "anthropic":
            return self._chat_anthropic
        elif self.provider == "ollama":
            return self._chat_ollama
        elif self.provider == "gemini":
            return self._chat_gemini
        elif self.provider == "groq":
            return self._chat_groq
        else:
            raise ValueError(f"Unsupported LLM provider: {self.provider}")

    def chat(self, system_prompt: str, user_prompt: str) -> LLMResponse:
        """Run the provider call with bounded client-level retry/backoff.

        Only retryable failures (429 / 5xx / timeout / connection) are
        retried, at most ``self.max_retries`` times. Permanent 4xx errors
        and any non-retryable typed error are raised immediately. The loop
        is strictly bounded (max_retries + 1 attempts total) so it can
        never spin indefinitely.
        """
        method = self._provider_method()
        for attempt in range(self.max_retries + 1):
            try:
                return method(system_prompt, user_prompt)
            except LLMProviderError as exc:
                if not exc.retryable or attempt >= self.max_retries:
                    raise
                wait = self._retry_delay(exc, attempt)
                logger.warning(
                    "LLM provider %s failed (%s), retrying in %.1fs "
                    "(attempt %d/%d)",
                    self.provider, exc.code, wait, attempt + 1, self.max_retries,
                )
                time.sleep(wait)
        raise LLMUnavailableError(
            f"LLM provider {self.provider} failed after "
            f"{self.max_retries + 1} attempts"
        )

    def _retry_delay(self, exc: LLMProviderError, attempt: int) -> float:
        if exc.retry_after is not None and exc.retry_after > 0:
            return min(max(exc.retry_after, self.retry_backoff_base), self.retry_backoff_max)
        return min(
            self.retry_backoff_base * (2 ** attempt), self.retry_backoff_max
        )

    def _chat_gemini(self, system_prompt: str, user_prompt: str) -> LLMResponse:
        """Gemini via the official REST generateContent endpoint.

        Uses GEMINI_API_KEY via the Gemini API header and noModel
        response_mime_type to ask for JSON output. This is the same
        official endpoint pattern already used by
        app/services/vision_service.py. No deprecated SDK is added.

        Failures raise typed LLMProviderError subclasses with sanitized
        messages; the request URL (which carries the API key) is never
        included and exception chaining is suppressed so the key cannot
        leak through an httpx traceback.
        """
        import httpx

        if not self.api_key:
            raise ValueError(
                f"Gemini provider requires GEMINI_API_KEY (provider='{self.provider}')"
            )

        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self.model}:generateContent"
        )
        timeout = max(settings.gemini_timeout, settings.llm_timeout)
        body = {
            "system_instruction": {"parts": [{"text": system_prompt}]},
            "contents": {"parts": [{"text": user_prompt}]},
            "generationConfig": {
                "temperature": 0.1,
                "response_mime_type": "application/json",
            },
        }

        try:
            resp = httpx.post(
                url,
                params={"key": self.api_key},
                json=body,
                timeout=timeout,
            )
        except httpx.TimeoutException:
            raise LLMTimeoutError(f"Gemini request timed out (provider={self.provider})") from None
        except httpx.ConnectError:
            raise LLMUnavailableError(
                f"Gemini connection failed (provider={self.provider})"
            ) from None
        except httpx.HTTPError:
            raise LLMUnavailableError(
                f"Gemini transport error (provider={self.provider})"
            ) from None

        try:
            resp.raise_for_status()
        except httpx.HTTPStatusError:
            raise _make_status_error(self.provider, resp, self.api_key) from None

        try:
            data = resp.json()
        except (json.JSONDecodeError, ValueError):
            raise LLMProviderError(
                f"Gemini returned a non-JSON response body "
                f"(provider={self.provider})"
            ) from None

        try:
            text = data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError):
            raise LLMProviderError(
                f"Unexpected Gemini response structure: "
                f"{_redact_secret(str(data)[:500], self.api_key)}"
            ) from None

        return LLMResponse(
            content=text,
            model=self.model,
            usage=data.get("usageMetadata", {}),
            raw=data,
        )

    def _chat_openai(self, system_prompt: str, user_prompt: str) -> LLMResponse:
        import httpx

        try:
            resp = httpx.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                    "temperature": 0.1,
                    "response_format": {"type": "json_object"},
                },
                timeout=self.timeout,
            )
        except httpx.TimeoutException:
            raise LLMTimeoutError(f"OpenAI request timed out (provider={self.provider})") from None
        except httpx.ConnectError:
            raise LLMUnavailableError(
                f"OpenAI connection failed (provider={self.provider})"
            ) from None
        except httpx.HTTPError:
            raise LLMUnavailableError(
                f"OpenAI transport error (provider={self.provider})"
            ) from None

        try:
            resp.raise_for_status()
        except httpx.HTTPStatusError:
            raise _make_status_error(self.provider, resp, self.api_key) from None

        data = resp.json()
        return LLMResponse(
            content=data["choices"][0]["message"]["content"],
            model=data.get("model", self.model),
            usage=data.get("usage", {}),
            raw=data,
        )

    def _chat_groq(self, system_prompt: str, user_prompt: str) -> LLMResponse:
        """Groq via its OpenAI-compatible chat completions endpoint.

        Groq exposes an OpenAI-compatible HTTP API, so the request shape,
        response parsing, and typed error handling mirror _chat_openai().
        The API key travels in the Authorization header only; the request
        URL never carries it, and exception chaining is suppressed so the
        key cannot leak through an httpx traceback.
        """
        import httpx

        if not self.api_key:
            raise ValueError(
                f"Groq provider requires GROQ_API_KEY (provider='{self.provider}')"
            )

        try:
            resp = httpx.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                    "temperature": 0.1,
                    "response_format": {"type": "json_object"},
                },
                timeout=self.timeout,
            )
        except httpx.TimeoutException:
            raise LLMTimeoutError(f"Groq request timed out (provider={self.provider})") from None
        except httpx.ConnectError:
            raise LLMUnavailableError(
                f"Groq connection failed (provider={self.provider})"
            ) from None
        except httpx.HTTPError:
            raise LLMUnavailableError(
                f"Groq transport error (provider={self.provider})"
            ) from None

        try:
            resp.raise_for_status()
        except httpx.HTTPStatusError:
            raise _make_status_error(self.provider, resp, self.api_key) from None

        data = resp.json()
        return LLMResponse(
            content=data["choices"][0]["message"]["content"],
            model=data.get("model", self.model),
            usage=data.get("usage", {}),
            raw=data,
        )

    def _chat_anthropic(self, system_prompt: str, user_prompt: str) -> LLMResponse:
        import httpx

        try:
            resp = httpx.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": self.api_key,
                    "anthropic-version": "2023-06-01",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "max_tokens": 2048,
                    "system": system_prompt,
                    "messages": [{"role": "user", "content": user_prompt}],
                    "temperature": 0.1,
                },
                timeout=self.timeout,
            )
        except httpx.TimeoutException:
            raise LLMTimeoutError(f"Anthropic request timed out (provider={self.provider})") from None
        except httpx.ConnectError:
            raise LLMUnavailableError(
                f"Anthropic connection failed (provider={self.provider})"
            ) from None
        except httpx.HTTPError:
            raise LLMUnavailableError(
                f"Anthropic transport error (provider={self.provider})"
            ) from None

        try:
            resp.raise_for_status()
        except httpx.HTTPStatusError:
            raise _make_status_error(self.provider, resp, self.api_key) from None

        data = resp.json()
        return LLMResponse(
            content=data["content"][0]["text"],
            model=data.get("model", self.model),
            usage=data.get("usage", {}),
            raw=data,
        )

    def _chat_ollama(self, system_prompt: str, user_prompt: str) -> LLMResponse:
        import httpx

        try:
            resp = httpx.post(
                "http://localhost:11434/api/chat",
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                    "stream": False,
                },
                timeout=self.timeout,
            )
        except httpx.TimeoutException:
            raise LLMTimeoutError(f"Ollama request timed out (provider={self.provider})") from None
        except httpx.ConnectError:
            raise LLMUnavailableError(
                f"Ollama connection failed (provider={self.provider})"
            ) from None
        except httpx.HTTPError:
            raise LLMUnavailableError(
                f"Ollama transport error (provider={self.provider})"
            ) from None

        try:
            resp.raise_for_status()
        except httpx.HTTPStatusError:
            raise _make_status_error(self.provider, resp, "") from None

        data = resp.json()
        return LLMResponse(
            content=data["message"]["content"],
            model=self.model,
            usage=data.get("eval_count", {}),
            raw=data,
        )