"""Pluggable data-source interface.

A DataSource receives a product query (barcode, name, brand, company) and
returns zero or more RawProductData records, each carrying full provenance.
Sources are interchangeable: adding a new source is a new class in this
package, registered in registry.py — no pipeline rewrite.
"""

from __future__ import annotations

import abc
from typing import Iterable, Optional

from pydantic import BaseModel

from ..models import RawProductData


class ProductQuery(BaseModel):
    """Search criteria for a product. All fields optional; at least one given."""

    barcode: Optional[str] = None
    name: Optional[str] = None
    brand: Optional[str] = None
    company: Optional[str] = None

    def is_empty(self) -> bool:
        return not (self.barcode or self.name or self.brand or self.company)

    def describe(self) -> str:
        parts = [f"barcode={self.barcode}", f"name={self.name!r}"]
        if self.brand:
            parts.append(f"brand={self.brand!r}")
        if self.company:
            parts.append(f"company={self.company!r}")
        return ", ".join(parts)


class DataSource(abc.ABC):
    """Interface every data source must implement."""

    name: str = "base"
    description: str = ""

    @abc.abstractmethod
    def search(self, query: ProductQuery) -> Iterable[RawProductData]:
        """Search for the product and return raw structured data with provenance."""
        raise NotImplementedError

    @abc.abstractmethod
    def get(self, product_key: str) -> Iterable[RawProductData]:
        """Fetch a product directly by its source-specific key (e.g. OFF barcode)."""
        raise NotImplementedError

    def health(self) -> bool:
        """Optional cheap availability probe."""
        return True
