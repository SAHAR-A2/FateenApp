"""Manufacturer / official-site source.

Locates the official company website and official product page via web search,
fetches the page, and extracts structured product data (ingredients, nutrition)
with best-effort heuristics. Extracted facts are flagged with honest,
conservative confidence and are NEVER treated as verified without
corroboration — this is the "no guessing" rule.

Without a configured web-search API key this source is a no-op (returns
nothing) — the agent records missing evidence instead of inventing any.
"""

from __future__ import annotations

import logging
import re
from typing import Iterable, Optional

from ..config import Settings
from ..constants import PRIORITY_PRIMARY, SOURCE_TYPE_MANUFACTURER
from ..models import RawProductData, SourceInfo
from .base import DataSource, ProductQuery
from .websearch import PageFetcher, WebSearchProvider

logger = logging.getLogger(__name__)

# Domains we never treat as official manufacturer sources.
UNTRUSTED_DOMAINS = (
    "amazon.", "ebay.", "walmart", "alibaba", "aliexpress", "wikipedia",
    "yelp.", "facebook", "instagram", "twitter", "pinterest", "tiktok",
    "shopifypreview", "etsy.", "joinhoney", "pricegrabber", "camelcamel",
    "tmall", "taobao", "jd.com", "rakuten", "target.com", "tesco.com",
)

# Section markers for ingredients in several languages.
INGREDIENT_MARKERS = (
    "ingredients", "ingrédients", "ingredientes", "zutaten", "ingredienti",
    "bestanddelen", "المكونات", "المكوّنات", "składniki", "ингредиенты",
    "原材料", "원재료", "list of ingredients", "composição", "composición",
)

# Known "junk" lines that follow the ingredient marker but are not ingredients.
IGNORED_INGREDIENT_LINES = (
    "may contain", "may also contain", "contains", "nutrition facts",
    "nutrition information", "allergen", "allergy", "storage", "packaged",
    "manufactured", "produced", "keep in", "distributed by", "imported by",
    "made in", "country of", "suitable for", "net wt", "net weight",
)


class ManufacturerSource(DataSource):
    """Official manufacturer website / product page source."""

    name = "manufacturer_official"
    description = "Official manufacturer website product page"

    def __init__(self, settings: Settings):
        self.settings = settings
        self.web = WebSearchProvider(settings)
        self.fetcher = PageFetcher(settings)

    def health(self) -> bool:
        return self.web.enabled

    # -- source interface ----------------------------------------------------

    def search(self, query: ProductQuery) -> Iterable[RawProductData]:
        if not self.web.enabled:
            return []
        if query.barcode and query.name:
            queries = [
                f'"{query.name}" ingredients {query.brand or ""}'.strip(),
                f'"{query.name}" official product page {query.brand or ""}'.strip(),
            ]
        elif query.name:
            queries = [f'"{query.name}" ingredients official site {query.brand or ""}'.strip()]
        elif query.barcode:
            queries = [f'product barcode {query.barcode} official website ingredients']
        else:
            return []

        candidates: list[tuple[str, str]] = []  # (url, title)
        for q in queries:
            for res in self.web.search(q, max_results=5):
                if self._is_official_candidate(res.url):
                    candidates.append((res.url, res.title))
            if candidates:
                break

        for url, title in candidates[:3]:
            text = self.fetcher.fetch_text(url)
            if not text:
                continue
            ingredients = self._extract_ingredients(text)
            nutrition = self._extract_nutrition(text)
            name = self._extract_title(text, title)
            if not (ingredients or nutrition or name):
                continue
            source = SourceInfo(
                name=self.name,
                url=url,
                source_type=SOURCE_TYPE_MANUFACTURER,
                priority=PRIORITY_PRIMARY,
                raw_excerpt=self._excerpt(text, 2000),
            )
            yield RawProductData(
                source=source,
                name=name,
                brand=query.brand,
                company=query.brand,
                ingredients="; ".join(ingredients) if ingredients else None,
                ingredients_parsed=ingredients,
                nutrition=nutrition,
                product_url=url,
                raw={"page_title": title, "excerpt": text[:4000]},
                language=None,
            )

    def get(self, product_key: str) -> Iterable[RawProductData]:
        # Manufacturer source is reached via search, not a stable key.
        return []

    # -- helpers ---------------------------------------------------------------

    @staticmethod
    def _is_official_candidate(url: str) -> bool:
        return not any(d in url.lower() for d in UNTRUSTED_DOMAINS)

    def _extract_ingredients(self, text: str) -> list[str]:
        lines = [re.sub(r"\s+", " ", ln).strip() for ln in text.split("\n")]
        lines = [ln for ln in lines if ln]
        low = [ln.lower() for ln in lines]
        start = -1
        for i, line in enumerate(low):
            for marker in INGREDIENT_MARKERS:
                if marker in line and len(line) < 80:
                    start = i + 1
                    break
            if start >= 0:
                break
        if start < 0:
            return []
        ingredients: list[str] = []
        for line in lines[start : start + 60]:
            if self._is_ingredient_line(line, ingredients):
                ingredients.append(line)
            elif ingredients:
                break
            elif not ingredients and len(ingredients) == 0 and start and len(line) > 200:
                # First line may be a long paragraph; split on commas.
                for chunk in line.split(","):
                    chunk = chunk.strip().strip(".")
                    if chunk and self._is_ingredient_line(chunk, ingredients):
                        ingredients.append(chunk)
                if ingredients:
                    continue
        return ingredients[:40]

    @staticmethod
    def _is_ingredient_line(line: str, collected: list[str]) -> bool:
        low = line.lower()
        if len(line) < 2 or len(line) > 400:
            return False
        if any(ign in low for ign in IGNORED_INGREDIENT_LINES):
            return False
        if low.startswith(("e-", "e ") and line[1:2].isdigit()):
            return True  # E-number
        if re.match(r"^e\d{3,4}$", low):
            return True
        # must look ingredient-ish: contain letters, not pure punctuation
        if not re.search(r"[a-z\u0600-\u06FF]", low):
            return False
        # reject footer/contact junk
        if re.match(r"^(©|copyright|phone|fax|email|www|http|follow|share|privacy|terms)", low):
            return False
        if low in (s.lower() for s in collected):
            return False
        return True

    @staticmethod
    def _extract_title(text: str, fallback: str) -> Optional[str]:
        for line in text.split("\n"):
            line = line.strip()
            if 10 < len(line) < 120 and not re.match(r"^[^a-z\u0600-\u06FF]+$", line):
                return line
        return fallback or None

    @staticmethod
    def _excerpt(text: str, n: int) -> str:
        return text[:n]

    @staticmethod
    def _extract_nutrition(text: str) -> dict[str, float]:
        """Best-effort nutrition extraction. Values are raw; validation decides."""
        pattern = re.compile(
            r"(energy|protein|carbohydrates|fat|saturated|sugar|sodium|fiber)\s*[:.]?\s*(\d+(?:[.,]\d+)?)",
            re.IGNORECASE,
        )
        out: dict[str, float] = {}
        for m in pattern.finditer(text):
            key = m.group(1).lower()
            val = float(m.group(2).replace(",", "."))
            if key == "energy" and key not in out:
                out[key] = val
            elif key not in out:
                out[key] = val
        return out
