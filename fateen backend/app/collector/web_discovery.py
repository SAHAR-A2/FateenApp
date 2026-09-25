"""Web Discovery: find candidate product source URLs for a company.

Deterministic source classification and ranking only. Source priority is
NEVER decided by an LLM -- it is a fixed, code-defined ordering:

    official manufacturer/product page  (1)
    official / regulatory / trusted     (2)
    trusted database                    (3)
    retailer                            (4)
    unknown website                     (5)

Providers are pluggable behind WebDiscoveryProvider. Without configured
credentials the provider is a no-op that returns [] -- URLs are never
fabricated. Discovery only proposes source URLs; product identity (name,
brand, barcode) is confirmed by an operator before a candidate is
registered for a scan. This module never writes to the database.
"""
from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Optional
from urllib.parse import urlparse

from app.core.config import settings

logger = logging.getLogger("fateen.collector.web_discovery")

# Source types (public.source_types has these codes; an unclassifiable
# website is left as None = "missing", never replaced with an invented code).
SOURCE_MANUFACTURER = "MANUFACTURER"
SOURCE_REGULATORY = "REGULATORY"
SOURCE_DATABASE = "DATABASE"

# Evidence types that exist in public.evidence_types.
EVIDENCE_MANUFACTURER = "MANUFACTURER"
EVIDENCE_OFFICIAL_SOURCE = "OFFICIAL_SOURCE"
EVIDENCE_DATABASE = "DATABASE"

_RETAILER_HOST_HINTS = frozenset(
    {
        "amazon",
        "carrefour",
        "luluhypermarket",
        "lulu",
        "tamimimarkets",
        "tamimi",
        "danube",
        "noon",
        "souq",
        "binwahed",
        "nana",
        "sachef",
        "aldawood",
        "walmart",
        "target",
        "tesco",
        "ocado",
    }
)

_REGULATORY_HOST_HINTS = frozenset(
    {
        "sfda",
        "fda",
        "efsa",
        "europa.eu",
        "who.int",
        "fsai",
        "codexalimentarius",
    }
)

_DATABASE_HOST_HINTS = frozenset(
    {
        "openfoodfacts",
        "makatapedia",
        "nutritionix",
        "fatsecret",
        "upcitemdb",
        "usda",
        "ndb.nal",
    }
)


@dataclass
class SourceClassification:
    """Deterministic classification of a source URL.

    source_type / evidence_type are codes that exist in the reference data
    (public.source_types / public.evidence_types). None means "unclassified"
    -- a missing value, never a guess.
    """
    source_type: Optional[str] = None
    evidence_type: Optional[str] = None
    is_retailer: bool = False
    priority: int = 5


@dataclass
class WebDiscoveryResult:
    """A source URL proposed by web discovery, with deterministic priority."""
    url: str
    title: str = ""
    source_type: Optional[str] = None
    evidence_type: Optional[str] = None
    priority: int = 5
    is_retailer: bool = False
    source_reference: Optional[str] = None
    metadata: dict = field(default_factory=dict)


def _priority_for(source_type: Optional[str], is_retailer: bool) -> int:
    if source_type == SOURCE_MANUFACTURER:
        return 1
    if source_type == SOURCE_REGULATORY:
        return 2
    if source_type == SOURCE_DATABASE:
        return 3
    if is_retailer:
        return 4
    return 5


def _evidence_for(source_type: Optional[str]) -> Optional[str]:
    if source_type == SOURCE_MANUFACTURER:
        return EVIDENCE_MANUFACTURER
    if source_type == SOURCE_REGULATORY:
        return EVIDENCE_OFFICIAL_SOURCE
    if source_type == SOURCE_DATABASE:
        return EVIDENCE_DATABASE
    return None


def classify_url(url: Optional[str]) -> SourceClassification:
    """Classify a source URL deterministically (no LLM involved)."""
    if not url:
        return SourceClassification()

    parsed = urlparse(url)
    host = (parsed.hostname or "").lower()

    if not host:
        return SourceClassification()

    if any(hint in host for hint in _REGULATORY_HOST_HINTS):
        return SourceClassification(
            source_type=SOURCE_REGULATORY,
            evidence_type=_evidence_for(SOURCE_REGULATORY),
            priority=_priority_for(SOURCE_REGULATORY, False),
        )

    if any(hint in host for hint in _DATABASE_HOST_HINTS):
        return SourceClassification(
            source_type=SOURCE_DATABASE,
            evidence_type=_evidence_for(SOURCE_DATABASE),
            priority=_priority_for(SOURCE_DATABASE, False),
        )

    if any(hint in host for hint in _RETAILER_HOST_HINTS):
        return SourceClassification(
            source_type=None,
            evidence_type=None,
            is_retailer=True,
            priority=_priority_for(None, True),
        )

    return SourceClassification()


class WebDiscoveryProvider(ABC):
    """Pluggable web discovery. Must never fabricate URLs."""

    enabled: bool = False

    @abstractmethod
    def discover(
        self,
        target_name: str,
        brand: Optional[str] = None,
        barcode: Optional[str] = None,
        country: str = "SA",
        market: str = "packaged_food",
        max_results: int = 10,
    ) -> list[WebDiscoveryResult]:
        """Return ranked candidate source URLs.

        Returns [] when the provider is disabled or cannot find anything.
        """
        raise NotImplementedError


class NoopWebDiscoveryProvider(WebDiscoveryProvider):
    """No-op provider. Used when no web discovery is configured."""

    enabled = False

    def discover(self, *args, **kwargs) -> list[WebDiscoveryResult]:
        logger.info("Web discovery disabled; returning no sources")
        return []


class StaticWebDiscoveryProvider(WebDiscoveryProvider):
    """Reads explicit source URLs from WEB_DISCOVERY_STATIC_URLS.

    Format: comma-separated URLs. Optionally tagged per URL:
        https://host/product-page|MANUFACTURER
    A tag is honored only when it matches a DB source_type code
    (MANUFACTURER, REGULATORY, DATABASE); anything else is ignored and the
    URL is classified deterministically.
    """

    def __init__(self) -> None:
        raw = (settings.web_discovery_static_urls or "").strip()
        self._url_tokens = [t.strip() for t in raw.split(",") if t.strip()]
        self.enabled = bool(self._url_tokens)
        if not self.enabled:
            logger.info(
                "Static web discovery configured but no URLs supplied; "
                "WEB_DISCOVERY_STATIC_URLS is empty"
            )

    def discover(
        self,
        target_name: str,
        brand: Optional[str] = None,
        barcode: Optional[str] = None,
        country: str = "SA",
        market: str = "packaged_food",
        max_results: int = 10,
    ) -> list[WebDiscoveryResult]:
        if not self.enabled:
            return []

        results: list[WebDiscoveryResult] = []
        for token in self._url_tokens:
            url, _, tag = token.partition("|")
            url = url.strip()
            if not url or not url.startswith(("http://", "https://")):
                continue

            cls = classify_url(url)
            explicit_tag = tag.strip().upper()
            if explicit_tag in {
                SOURCE_MANUFACTURER,
                SOURCE_REGULATORY,
                SOURCE_DATABASE,
            }:
                cls = SourceClassification(
                    source_type=explicit_tag,
                    evidence_type=_evidence_for(explicit_tag),
                    is_retailer=cls.is_retailer,
                    priority=_priority_for(explicit_tag, cls.is_retailer),
                )

            results.append(
                WebDiscoveryResult(
                    url=url,
                    source_type=cls.source_type,
                    evidence_type=cls.evidence_type,
                    priority=cls.priority,
                    is_retailer=cls.is_retailer,
                    source_reference=f"static discovery targeting: {target_name}",
                )
            )

        return sort_discovery_results(results)[:max_results]


def sort_discovery_results(results: list[WebDiscoveryResult]) -> list[WebDiscoveryResult]:
    """Stable deterministic sort: priority, then URL. Never LLM-decided."""
    return sorted(results, key=lambda r: (r.priority, r.url or ""))


def get_web_discovery_provider() -> WebDiscoveryProvider:
    """Factory for the configured web discovery provider.

    Unknown or unimplemented providers degrade to the no-op provider.
    """
    provider = (settings.web_discovery_provider or "none").strip().lower()

    if provider in ("", "none"):
        return NoopWebDiscoveryProvider()

    if provider == "static":
        return StaticWebDiscoveryProvider()

    logger.warning(
        "Web discovery provider '%s' is not implemented; using no-op "
        "provider (no URLs will be discovered)",
        provider,
    )
    return NoopWebDiscoveryProvider()