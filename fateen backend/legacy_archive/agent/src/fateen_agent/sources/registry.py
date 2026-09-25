"""Source registry: builds the active source list for a run.

Sources are cheap to construct and enabled/disabled by configuration. The
registry is the single place to add a new source class.
"""

from __future__ import annotations

from typing import Iterable

from ..config import Settings
from .base import DataSource
from .fixture import FixtureSource
from .manufacturer import ManufacturerSource
from .openfoodfacts import OpenFoodFactsSource


def default_sources(settings: Settings) -> list[DataSource]:
    """Order matters: higher-trust sources first for precedence in conflicts."""
    # Offline mode: replay synthetic fixtures only. No network sources.
    if not settings.live_web:
        return [FixtureSource(settings.fixture_path or None)]
    sources: list[DataSource] = []
    # Primary: official manufacturer site (requires web search key to function).
    sources.append(ManufacturerSource(settings))
    # Secondary: trusted open database, always available (no key required).
    sources.append(OpenFoodFactsSource())
    return sources


def enabled_sources(sources: Iterable[DataSource]) -> list[DataSource]:
    return [s for s in sources if s.health()]
