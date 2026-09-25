"""Web search + page fetching. Used to locate official manufacturer sources.

Providers are pluggable (tavily | serper). Without a configured API key the
provider is a no-op: the agent never fabricates URLs, it simply records that
web research was unavailable (which lowers outcomes, never fabricates data).
"""

from __future__ import annotations

import logging
import re
from typing import Optional

import httpx
from bs4 import BeautifulSoup
from tenacity import retry, stop_after_attempt, wait_exponential

from ..config import Settings

logger = logging.getLogger(__name__)

LINK_RE = re.compile(r"https?://[^\s\"'<>]+", re.IGNORECASE)


class WebSearchResult:
    def __init__(self, title: str, url: str, snippet: str = ""):
        self.title = title
        self.url = url
        self.snippet = snippet

    def __repr__(self) -> str:  # pragma: no cover
        return f"WebSearchResult({self.title!r}, {self.url!r})"


class WebSearchProvider:
    """Unified facade over web-search APIs. No-op when unconfigured."""

    def __init__(self, settings: Settings, client: Optional[httpx.Client] = None):
        self.settings = settings
        self.provider = (settings.web_search_provider or "").lower()
        self.api_key = settings.web_search_api_key
        self._client = client or httpx.Client(timeout=settings.http_timeout)
        self.enabled = bool(self.provider and self.api_key)
        if not self.enabled:
            logger.info(
                "Web search provider not configured; web research sources disabled "
                "(missing FATEEN_WEB_SEARCH_PROVIDER / FATEEN_WEB_SEARCH_API_KEY)."
            )

    def search(self, query: str, max_results: int = 5) -> list[WebSearchResult]:
        if not self.enabled:
            return []
        if self.provider == "tavily":
            return self._search_tavily(query, max_results)
        if self.provider == "serper":
            return self._search_serper(query, max_results)
        logger.warning("Unknown web search provider: %s", self.provider)
        return []

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(multiplier=0.5, min=0.5, max=3), reraise=True)
    def _search_tavily(self, query: str, max_results: int) -> list[WebSearchResult]:
        resp = self._client.post(
            "https://api.tavily.com/search",
            json={"api_key": self.api_key, "query": query, "max_results": max_results},
        )
        resp.raise_for_status()
        data = resp.json()
        return [
            WebSearchResult(
                title=item.get("title", ""),
                url=item.get("url", ""),
                snippet=item.get("content", ""),
            )
            for item in data.get("results", [])
            if item.get("url")
        ]

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(multiplier=0.5, min=0.5, max=3), reraise=True)
    def _search_serper(self, query: str, max_results: int) -> list[WebSearchResult]:
        resp = self._client.post(
            "https://google.serper.dev/search",
            headers={"X-API-KEY": self.api_key},
            json={"q": query, "num": max_results},
        )
        resp.raise_for_status()
        data = resp.json()
        return [
            WebSearchResult(
                title=item.get("title", ""),
                url=item.get("link", ""),
                snippet=item.get("snippet", ""),
            )
            for item in data.get("organic", [])
            if item.get("link")
        ]


class PageFetcher:
    """Downloads a web page and extracts readable text."""

    def __init__(self, settings: Settings, client: Optional[httpx.Client] = None):
        self._client = client or httpx.Client(
            timeout=settings.http_timeout,
            follow_redirects=True,
            headers={"User-Agent": "Mozilla/5.0 (compatible; FateenDataAgent/0.1; +product data research)"},
        )

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(multiplier=0.5, min=0.5, max=3), reraise=True)
    def fetch_text(self, url: str, max_chars: int = 400_000) -> Optional[str]:
        """Return readable text from a page, or None on failure."""
        try:
            resp = self._client.get(url)
            resp.raise_for_status()
        except httpx.HTTPError as exc:
            logger.debug("Page fetch failed for %s: %s", url, exc)
            return None
        content_type = resp.headers.get("content-type", "")
        if "html" not in content_type and "text" not in content_type:
            return None
        soup = BeautifulSoup(resp.text, "lxml")
        for tag in soup(["script", "style", "noscript", "svg", "nav", "footer", "header"]):
            tag.decompose()
        text = soup.get_text("\n")
        text = re.sub(r"\n{3,}", "\n\n", text)
        text = re.sub(r"[ \t]{2,}", " ", text)
        return text[:max_chars]
