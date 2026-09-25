"""Source layer: pluggable, provenance-carrying data sources."""

from .base import DataSource, ProductQuery
from .fixture import FixtureSource
from .manufacturer import ManufacturerSource
from .openfoodfacts import OpenFoodFactsSource
from .registry import default_sources, enabled_sources

__all__ = [
    "DataSource",
    "ProductQuery",
    "FixtureSource",
    "ManufacturerSource",
    "OpenFoodFactsSource",
    "default_sources",
    "enabled_sources",
]
