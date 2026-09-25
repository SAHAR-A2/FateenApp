"""P11: Centralized measurement unit conversion engine.

All conversions are deterministic, tested, and auditable.
No scattered conversion formulas throughout the Agent.
"""
# ---------------------------------------------------------------------------
# PRODUCTION-PATH STATUS (verified 2026-08-20, final release remediation):
# This module is NOT currently imported or called by any live API endpoint,
# CLI entry point, or orchestrator path in this codebase (app/api/*,
# app/main.py, app/collector/orchestrator.py, app/agent/*). It is fully
# implemented and tested in isolation but architecturally UNREACHABLE from
# production traffic as of commit 7b32932. Do not assume its protections
# are active for real requests until it is explicitly wired into a live
# call path AND that wiring is covered by an integration test proving the
# connection. See reports/FINAL_PRE_AGENT_RELEASE_AUDIT.md, section I, for
# the reachability audit and the decision not to wire it in during this
# remediation pass (wiring was judged out of scope: it requires an
# architecture decision about which entry point should invoke it and with
# what data, not just a mechanical import).
# ---------------------------------------------------------------------------

import logging
from typing import Optional
from app.db.connection import get_connection

logger = logging.getLogger("fateen.collector.units")

# Direct conversion cache loaded from DB
_conversion_cache: dict[tuple[str, str], float] = {}
_cache_loaded = False


def _load_conversions():
    """Load all unit conversions from database into memory cache."""
    global _conversion_cache, _cache_loaded
    if _cache_loaded:
        return
    try:
        with get_connection() as conn:
            rows = conn.execute("""
                SELECT u1.code AS from_code, u2.code AS to_code, 
                       uc.conversion_factor, uc.measurement_type
                FROM public.unit_conversions uc
                JOIN public.units u1 ON u1.id = uc.from_unit_id
                JOIN public.units u2 ON u2.id = uc.to_unit_id
            """).fetchall()
            for row in rows:
                _conversion_cache[(row["from_code"], row["to_code"])] = row["conversion_factor"]
            _cache_loaded = True
    except Exception:
        logger.exception("Failed to load unit conversions")


def can_convert(from_unit: str, to_unit: str) -> bool:
    """Check if a conversion exists between two units."""
    _load_conversions()
    from_u = from_unit.upper().strip()
    to_u = to_unit.upper().strip()
    if from_u == to_u:
        return True
    return (from_u, to_u) in _conversion_cache


def convert(value: float, from_unit: str, to_unit: str) -> Optional[float]:
    """Convert a value from one unit to another.

    Returns None if conversion is not possible.
    Returns the original value if units are the same.
    Raises ValueError for negative values where measurement type doesn't permit them.
    """
    if value < 0:
        raise ValueError(f"Negative value not permitted: {value}")

    from_u = from_unit.upper().strip()
    to_u = to_unit.upper().strip()

    if from_u == to_u:
        return value

    _load_conversions()
    key = (from_u, to_u)
    if key in _conversion_cache:
        factor = _conversion_cache[key]
        result = value * factor
        return round(result, 6)

    return None


def convert_to_base(value: float, unit: str) -> Optional[tuple[float, str]]:
    """Convert a value to the base unit for its measurement type.

    Returns (base_value, base_unit) or None if unknown.
    """
    base_units = {
        "mass": "G",
        "volume": "ML",
        "energy": "KCAL",
        "count": "PCS",
    }

    unit_u = unit.upper().strip()

    for mtype, base in base_units.items():
        result = convert(value, unit_u, base)
        if result is not None:
            return (result, base)

    return None


def get_all_conversions() -> dict[tuple[str, str], float]:
    """Get all loaded conversions. For testing/debugging."""
    _load_conversions()
    return dict(_conversion_cache)


def clear_cache():
    """Clear the conversion cache. For testing."""
    global _conversion_cache, _cache_loaded
    _conversion_cache = {}
    _cache_loaded = False
