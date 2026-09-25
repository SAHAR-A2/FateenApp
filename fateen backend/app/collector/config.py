"""P34: Collector Configuration.

Provides CollectorConfig dataclass with defaults.
Values are read from environment variables when available,
falling back to sensible defaults.
"""
# ---------------------------------------------------------------------------
# PRODUCTION-PATH STATUS (updated 2026-09-04):
# This module is now wired into the live collector path: the orchestrator
# (app/collector/orchestrator.py, auto-extraction for web-discovered
# candidates) reads retrieval timeout / retry limits from
# get_collector_config(). The connection is covered by an integration test
# (tests/test_collector_wiring.py). CollectorConfig remains a pure config
# shim -- it never writes to the database.
# ---------------------------------------------------------------------------

import os
from dataclasses import dataclass, field
import logging

logger = logging.getLogger("fateen.collector.config")


@dataclass
class CollectorConfig:
    """Configuration for the FATEEN Data Collection Agent."""
    market_country: str = "SA"
    market_category: str = "packaged_food"
    max_products_per_company: int = 100
    retrieval_timeout: int = 30
    retrieval_max_retries: int = 3
    llm_timeout: float = 30.0
    pilot_mode: bool = True
    dry_run_default: bool = True
    rate_limit_per_minute: int = 60


def get_collector_config() -> CollectorConfig:
    """Read collector configuration from environment variables.

    Falls back to defaults for any unset or invalid values.
    """
    try:
        return CollectorConfig(
            market_country=os.environ.get("COLLECTOR_MARKET_COUNTRY", "SA"),
            market_category=os.environ.get("COLLECTOR_MARKET_CATEGORY", "packaged_food"),
            max_products_per_company=_int_env("COLLECTOR_MAX_PRODUCTS_PER_COMPANY", 100),
            retrieval_timeout=_int_env("COLLECTOR_RETRIEVAL_TIMEOUT", 30),
            retrieval_max_retries=_int_env("COLLECTOR_RETRIEVAL_MAX_RETRIES", 3),
            llm_timeout=_float_env("COLLECTOR_LLM_TIMEOUT", 30.0),
            pilot_mode=_bool_env("COLLECTOR_PILOT_MODE", True),
            dry_run_default=_bool_env("COLLECTOR_DRY_RUN_DEFAULT", True),
            rate_limit_per_minute=_int_env("COLLECTOR_RATE_LIMIT_PER_MINUTE", 60),
        )
    except Exception:
        logger.exception("Failed to load collector config from environment, using defaults")
        return CollectorConfig()


def _int_env(key: str, default: int) -> int:
    """Read an integer from environment, returning default on failure."""
    raw = os.environ.get(key)
    if raw is None:
        return default
    try:
        return int(raw)
    except (ValueError, TypeError):
        logger.warning("Invalid integer for %s: %s, using default %s", key, raw, default)
        return default


def _float_env(key: str, default: float) -> float:
    """Read a float from environment, returning default on failure."""
    raw = os.environ.get(key)
    if raw is None:
        return default
    try:
        return float(raw)
    except (ValueError, TypeError):
        logger.warning("Invalid float for %s: %s, using default %s", key, raw, default)
        return default


def _bool_env(key: str, default: bool) -> bool:
    """Read a boolean from environment, returning default on failure.

    Recognizes: true, 1, yes (case-insensitive) as True.
    """
    raw = os.environ.get(key)
    if raw is None:
        return default
    return raw.strip().lower() in ("true", "1", "yes")
