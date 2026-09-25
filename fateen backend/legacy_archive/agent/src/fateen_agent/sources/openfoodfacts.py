"""Open Food Facts source — bulk-capable, community-maintained food database."""

from __future__ import annotations

import logging
from typing import Iterable, Optional

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from ..constants import PRIORITY_SECONDARY, SOURCE_TYPE_DATABASE
from ..models import RawProductData, SourceInfo
from .base import DataSource, ProductQuery

logger = logging.getLogger(__name__)

OFF_API = "https://world.openfoodfacts.org/api/v2"
OFF_PRODUCT_URL = "https://world.openfoodfacts.org/product/{code}"


class OpenFoodFactsSource(DataSource):
    """Fetches products from Open Food Facts by barcode.

    OFF is a SECONDARY source: good for bulk discovery and cross-checking,
    but never treated as absolute truth (community-maintained).
    """

    name = "openfoodfacts"
    description = "Open Food Facts API (v2)"

    def __init__(self, client: Optional[httpx.Client] = None, user_agent: str = "fateen-agent/0.1"):
        self._client = client or httpx.Client(
            timeout=20.0,
            headers={"User-Agent": user_agent, "Accept": "application/json"},
        )

    # -- source interface ----------------------------------------------------

    def search(self, query: ProductQuery) -> Iterable[RawProductData]:
        if query.barcode:
            return list(self.get(query.barcode))
        if query.name:
            return list(self._search_by_name(query.name, brand=query.brand))
        return []

    def get(self, product_key: str) -> Iterable[RawProductData]:
        data = self._fetch(f"{OFF_API}/product/{product_key}.json")
        status = data.get("status")
        if status != 1:
            logger.info("OFF: product %s not found", product_key)
            return []
        product = data.get("product", {}) or {}
        return [self._to_raw(product, source_url=OFF_PRODUCT_URL.format(code=product_key))]

    def health(self) -> bool:
        # Capability check only — avoids blocking on a real network probe.
        # Actual availability is detected per-request and reported via `health` cmd.
        return True

    # -- helpers ---------------------------------------------------------------

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=0.5, min=0.5, max=4), reraise=True)
    def _fetch(self, url: str) -> dict:
        resp = self._client.get(url)
        resp.raise_for_status()
        return resp.json()

    def _search_by_name(self, name: str, brand: Optional[str] = None) -> Iterable[RawProductData]:
        params = {"search_terms": name, "page_size": 5, "fields": "code,product_name,brands,quantity,image_front_url"}
        if brand:
            params["brand"] = brand
        data = self._fetch(f"{OFF_API}/search")
        # Re-issue with query params (the base URL has no query string).
        resp = self._client.get(f"{OFF_API}/search", params=params)
        resp.raise_for_status()
        data = resp.json()
        for hit in data.get("products", []) or []:
            code = hit.get("code")
            yield RawProductData(
                source=SourceInfo(
                    name=self.name,
                    url=OFF_PRODUCT_URL.format(code=code) if code else None,
                    source_type=SOURCE_TYPE_DATABASE,
                    priority=PRIORITY_SECONDARY,
                ),
                name=hit.get("product_name"),
                brand=hit.get("brands"),
                package_size=hit.get("quantity"),
                barcode=code,
                image_url=hit.get("image_front_url"),
                raw=hit,
            )

    def _to_raw(self, product: dict, source_url: str) -> RawProductData:
        barcode = product.get("code")
        brands_tags = product.get("brands_tags") or []
        return RawProductData(
            source=SourceInfo(
                name=self.name,
                url=source_url,
                source_type=SOURCE_TYPE_DATABASE,
                priority=PRIORITY_SECONDARY,
            ),
            name=product.get("product_name"),
            brand=product.get("brands"),
            company=product.get("brands"),
            package_size=product.get("quantity"),
            barcode=barcode,
            ingredients=product.get("ingredients_text"),
            allergens=[a.replace("en:", "") for a in (product.get("allergens_tags") or []) if a],
            nutrition=self._nutrition(product),
            product_url=source_url,
            image_url=product.get("image_front_url"),
            raw=product,
            language="en",
        )

    @staticmethod
    def _nutrition(product: dict) -> dict[str, float]:
        nf = product.get("nutriments") or {}
        mapping = {
            "energy": "energy",
            "energy-kcal": "energy_kcal",
            "proteins": "protein",
            "carbohydrates": "carbohydrate",
            "fat": "total_fat",
            "saturated-fat": "saturated_fat",
            "trans-fat": "trans_fat",
            "sodium": "sodium",
            "sugars": "sugar",
            "fiber": "fiber",
        }
        out: dict[str, float] = {}
        for off_key, fateen_key in mapping.items():
            val = nf.get(off_key)
            if val is not None:
                try:
                    out[fateen_key] = float(val)
                except (TypeError, ValueError):
                    continue
        return out
