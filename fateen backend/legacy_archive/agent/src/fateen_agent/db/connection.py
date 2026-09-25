"""PostgreSQL connection helpers."""

from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator, Optional

import psycopg
from psycopg import Connection

from ..config import Settings


def connect(settings: Settings) -> Connection:
    """Open a psycopg3 connection to the (dev) database."""
    return psycopg.connect(
        settings.dsn,
        connect_timeout=15,
        autocommit=False,
        row_factory=psycopg.rows.dict_row,
    )


@contextmanager
def connection_scope(settings: Settings) -> Iterator[Connection]:
    """Yield a connection and ensure it is closed."""
    conn = connect(settings)
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def transaction(conn: Connection) -> Iterator[Connection]:
    """Yield the connection inside a transaction (commit on success)."""
    with conn.transaction():
        yield conn
