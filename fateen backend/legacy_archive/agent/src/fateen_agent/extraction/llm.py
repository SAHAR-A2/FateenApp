"""Optional, model-agnostic LLM extraction.

The LLM is strictly an extractor/normalizer assistant. It is NEVER a source of
truth: any fact it produces must be traceable to a fetched page (raw_excerpt)
and is subject to the same validation rules. Without a configured key the
NullExtractor is used (deterministic parsing only).
"""

from __future__ import annotations

import abc
import json
import logging
from typing import Optional

from ..config import Settings

logger = logging.getLogger(__name__)


class LLMExtractor(abc.ABC):
    """Interface for LLM-backed extraction assistants."""

    name = "base"

    @abc.abstractmethod
    def extract_ingredients(self, page_text: str) -> list[str]:
        """Extract the verbatim ingredient list from free page text."""
        raise NotImplementedError


class NullExtractor(LLMExtractor):
    """Deterministic no-op; used when no LLM is configured."""

    name = "none"

    def extract_ingredients(self, page_text: str) -> list[str]:
        return []


class OpenAICompatibleExtractor(LLMExtractor):
    """OpenAI-compatible chat-completions extractor (OpenAI, Gemini, etc.)."""

    name = "openai_compatible"

    def __init__(self, settings: Settings):
        try:
            from openai import OpenAI  # type: ignore
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError(
                "LLM provider requires the 'openai' package (pip install 'fateen-agent[llm]')."
            ) from exc
        self._client = OpenAI(api_key=settings.llm_api_key, base_url=settings.llm_base_url or None)
        self._model = settings.llm_model or "gpt-4o-mini"
        self._max_tokens = settings.llm_max_tokens

    def extract_ingredients(self, page_text: str) -> list[str]:
        prompt = (
            "You are an ingredient-list extractor. From the following product page text, "
            "return ONLY the verbatim ingredient list as a JSON array of strings. "
            "If no ingredient list is present, return []. Never invent ingredients."
            "\n\nPAGE TEXT:\n"
            f"{page_text[:12000]}"
        )
        try:
            resp = self._client.chat.completions.create(
                model=self._model,
                max_tokens=self._max_tokens,
                temperature=0.0,
                messages=[
                    {"role": "system", "content": "Output strict JSON only."},
                    {"role": "user", "content": prompt},
                ],
            )
            content = resp.choices[0].message.content
            items = json.loads(content)
            if isinstance(items, list):
                return [str(i).strip() for i in items if str(i).strip()]
        except Exception as exc:  # noqa: BLE001
            logger.warning("LLM extraction failed: %s", exc)
        return []


def build_extractor(settings: Settings) -> LLMExtractor:
    if settings.llm_provider:
        provider = settings.llm_provider.lower()
        if provider in ("openai_compatible", "openai", "gemini"):
            try:
                return OpenAICompatibleExtractor(settings)
            except RuntimeError as exc:  # pragma: no cover
                logger.warning("%s", exc)
    return NullExtractor()
