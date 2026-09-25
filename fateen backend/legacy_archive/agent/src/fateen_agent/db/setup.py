"""Agent schema bootstrap. Applies migrations/agent_schema.sql if not applied."""

from __future__ import annotations

import logging
import os

import psycopg

from ..config import Settings
from .connection import connect

logger = logging.getLogger(__name__)

_SCHEMA_SQL = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))),
    "migrations",
    "agent_schema.sql",
)


def ensure_agent_schema(settings: Settings) -> bool:
    """Create the agent schema and tables. Safe to re-run."""
    conn = connect(settings)
    try:
        if not os.path.exists(_SCHEMA_SQL):
            raise FileNotFoundError(f"agent schema SQL not found: {_SCHEMA_SQL}")
        with open(_SCHEMA_SQL, encoding="utf-8") as fh:
            sql = fh.read()
        with conn.transaction():
            conn.execute(sql)
        logger.info("agent schema ensured")
        return True
    except psycopg.Error as exc:
        logger.error("agent schema apply failed: %s", exc)
        return False
    finally:
        conn.close()
