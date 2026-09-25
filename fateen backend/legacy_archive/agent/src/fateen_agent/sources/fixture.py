"""Synthetic offline data source for testing the agent without live web.

Replays evidence fixtures from a local JSON file (see tests/fixtures/).
The fixtures simulate the structured payloads the agent would receive from
real sources (Open Food Facts, an official manufacturer page, a label photo,
a community forum, ...). Everything returned is clearly synthetic and is
NEVER presented as verified production data — it exists only to exercise the
pipeline logic deterministically (extraction -> normalization -> matching ->
dedup -> priority -> validation -> confidence -> verification -> review).

Production must keep using the real sources (LIVE_WEB=true); this source is
for offline MVP / CI / demos only.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any, Iterable, Optional

from ..constants import (
    PRIORITY_SECONDARY,
    SOURCE_TYPE_DATABASE,
)
from ..models import RawProductData, SourceInfo
from ..normalization.barcode import normalize_barcode
from ..normalization.text import normalize_text
from .base import DataSource, ProductQuery

logger = logging.getLogger(__name__)


def default_fixture_path() -> Path:
    """Path to the bundled 10-product offline fixture."""
    # <repo>/src/fateen_agent/sources/fixture.py -> <repo>
    repo_root = Path(__file__).resolve().parents[3]
    return repo_root / "tests" / "fixtures" / "products_10.json"


class FixtureSource(DataSource):
    """Offline source that replays synthetic evidence from a JSON file."""

    name = "fixture"
    description = "Synthetic offline test fixtures (NOT production data)"

    def __init__(self, path: Optional[str | Path] = None):
        self.path = Path(path) if path else default_fixture_path()
        self._entries: list[dict[str, Any]] = []
        self.meta: dict[str, Any] = {}
        self._load()

    def _load(self) -> None:
        if not self.path.exists():
            logger.warning("Fixture file not found: %s", self.path)
            return
        with open(self.path, encoding="utf-8") as fh:
            payload = json.load(fh)
        self.meta = payload.get("meta", {})
        self._entries = payload.get("queries", []) or []
        if self.meta.get("synthetic") is False:
            logger.warning("Fixture %s is not marked synthetic!", self.path)
        logger.info("Fixture source loaded %d product cases from %s", len(self._entries), self.path)

    # -- source interface ----------------------------------------------------

    def health(self) -> bool:
        return bool(self._entries)

    def search(self, query: ProductQuery) -> Iterable[RawProductData]:
        for entry in self._entries:
            if not self._matches(entry, query):
                continue
            for source in entry.get("sources", []) or []:
                raw = self._to_raw(source, entry)
                if raw is not None:
                    yield raw

    def get(self, product_key: str) -> Iterable[RawProductData]:
        norm = normalize_barcode(product_key)
        for entry in self._entries:
            q = entry.get("query") or {}
            if q.get("barcode") and normalize_barcode(q["barcode"]) == norm:
                for source in entry.get("sources", []) or []:
                    raw = self._to_raw(source, entry)
                    if raw is not None:
                        yield raw

    # -- helpers ---------------------------------------------------------------

    @staticmethod
    def _matches(entry: dict, query: ProductQuery) -> bool:
        q = entry.get("query") or {}
        if q.get("barcode"):
            return bool(
                query.barcode
                and normalize_barcode(q["barcode"]) == normalize_barcode(query.barcode)
            )
        if q.get("name"):
            return bool(
                query.name and normalize_text(q["name"]) == normalize_text(query.name)
            )
        return False

    @classmethod
    def _to_raw(cls, source: dict, entry: dict) -> Optional[RawProductData]:
        data = source.get("data") or {}
        source_type = source.get("source_type") or SOURCE_TYPE_DATABASE
        priority = (source.get("priority") or PRIORITY_SECONDARY).upper()
        language = source.get("language") or data.get("language")
        url = source.get("url") or data.get("product_url")

        allergens = data.get("allergens_tags") or data.get("allergens") or []
        allergens = [
            a.replace("en:", "") if isinstance(a, str) else a
            for a in allergens
            if a
        ]

        name = data.get("product_name") or data.get("name")
        brand = data.get("brands") or data.get("brand")
        package_size = data.get("quantity") or data.get("package_size")
        ingredients_text = data.get("ingredients_text") or data.get("ingredients")
        ingredients_parsed = data.get("ingredients_parsed") or []
        nutrition = data.get("nutriments") or data.get("nutrition") or {}
        image_url = data.get("image_front_url") or data.get("image_url")

        return RawProductData(
            source=SourceInfo(
                name=source.get("name") or "fixture",
                url=url,
                source_type=source_type,
                priority=priority,
                raw_excerpt=(data.get("raw_excerpt") if isinstance(data.get("raw_excerpt"), str) else None),
            ),
            name=name,
            brand=brand,
            company=data.get("company") or brand,
            package_size=package_size,
            barcode=data.get("barcode"),
            ingredients=ingredients_text,
            ingredients_parsed=ingredients_parsed,
            allergens=allergens,
            nutrition={k: float(v) for k, v in nutrition.items() if v is not None},
            product_url=url,
            image_url=image_url,
            raw=data,
            language=language,
        )
