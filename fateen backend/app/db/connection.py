import atexit
import logging
import threading
from contextlib import contextmanager
from typing import Optional

from psycopg import Connection
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from app.core.config import settings

logger = logging.getLogger("fateen.db.connection")

_pool: Optional[ConnectionPool] = None
_pool_lock = threading.Lock()


def _get_pool() -> ConnectionPool:
    global _pool
    if _pool is not None:
        return _pool
    with _pool_lock:
        if _pool is not None:
            return _pool
        _pool = ConnectionPool(
            conninfo=settings.database_url,
            min_size=settings.db_pool_min_size,
            max_size=settings.db_pool_max_size,
            kwargs={
                "row_factory": dict_row,
                "connect_timeout": 10,
                "options": "-c statement_timeout=30000",
            },
            timeout=settings.db_pool_acquire_timeout,
            open=True,
        )
        logger.info(
            "DB pool created: min=%d max=%d acquire_timeout=%.1f",
            settings.db_pool_min_size,
            settings.db_pool_max_size,
            settings.db_pool_acquire_timeout,
        )
        return _pool


@contextmanager
def get_connection():
    """Borrow a connection from the pool and guarantee it is returned.

    Usage::

        with get_connection() as conn:
            conn.execute("SELECT 1")

    On success the transaction is committed.
    On exception the transaction is rolled back.
    The connection is ALWAYS returned to the pool.
    """
    pool = _get_pool()
    conn = pool.getconn()
    try:
        yield conn
        conn.commit()
    except Exception:
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    finally:
        try:
            conn.reset()
        except Exception:
            pass
        pool.putconn(conn)


def release_connection(conn: Connection) -> None:
    """Explicitly return a connection to the pool."""
    pool = _get_pool()
    pool.putconn(conn)


def close_pool() -> None:
    """Shut down the connection pool cleanly and idempotently."""
    global _pool

    with _pool_lock:
        pool = _pool
        _pool = None

    if pool is None:
        return

    try:
        # psycopg_pool's default close() timeout (5.0s) is shorter than the
        # per-connection connect_timeout (10s) configured above. On a
        # short-lived process (the CLI in particular), close() can be
        # called while a background worker thread is still mid-connect
        # to warm up `min_size` connections, and the default 5s isn't
        # always enough for that thread to notice the shutdown and stop
        # cleanly -> "couldn't stop thread 'pool-N-worker-*' within 5.0
        # seconds". Give close() at least as long as a connection attempt
        # is allowed to take, so workers always get a clean chance to exit.
        pool.close(timeout=10.0)
        logger.info("DB pool closed successfully")
    except Exception:
        logger.exception("Failed to close DB pool")


def _close_pool_at_exit() -> None:
    # Interpreter is shutting down: logging streams may already be closed
    # (e.g. under pytest capture), and a failed emit would print a noisy
    # "Logging error" block. Suppress it for this final operation.
    logging.raiseExceptions = False
    close_pool()


atexit.register(_close_pool_at_exit)
