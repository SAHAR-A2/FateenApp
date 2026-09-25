"""Agent health check: database, web connectivity, sources, mode, config.

Used by `fateen-agent health` and by the offline MVP report. Probes use short
timeouts and never block a run: a failed probe is reported, not retried.
"""

from __future__ import annotations

import logging
import socket
from typing import Any

from .config import Settings
from .sources import default_sources, enabled_sources

logger = logging.getLogger(__name__)

_WEB_PROBE_HOST = "world.openfoodfacts.org"
_WEB_PROBE_PORT = 443


def _tcp_probe(host: str, port: int, timeout: float = 4.0) -> dict[str, Any]:
    """Try a TCP connect to host:port. Does NOT verify a full HTTPS exchange."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect((host, port))
        return {"ok": True, "detail": f"TCP connect to {host}:{port} succeeded"}
    except OSError as exc:
        return {"ok": False, "detail": f"TCP connect to {host}:{port} failed: {exc}"}
    finally:
        sock.close()


def check_database(settings: Settings) -> dict[str, Any]:
    from .db.repository import FateenRepository

    try:
        repo = FateenRepository(settings)
        ok = repo.ping()
        return {
            "ok": ok,
            "detail": (
                f"connected to {settings.db_host}:{settings.db_port}/{settings.db_name}"
                if ok
                else f"unreachable {settings.db_host}:{settings.db_port}/{settings.db_name}"
            ),
        }
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "detail": f"database error: {exc}"}


def check_web(settings: Settings) -> dict[str, Any]:
    if not settings.live_web:
        return {
            "ok": False,
            "detail": "disabled by config (FATEEN_LIVE_WEB=false / offline mode)",
            "enabled_by_config": False,
        }
    probe = _tcp_probe(_WEB_PROBE_HOST, _WEB_PROBE_PORT)
    probe["enabled_by_config"] = True
    probe["note"] = "TCP-level probe only; full HTTPS responses require working egress."
    return probe


def check_sources(settings: Settings) -> list[dict[str, Any]]:
    out = []
    for s in enabled_sources(default_sources(settings)):
        out.append({"name": s.name, "description": s.description, "available": s.health()})
    return out


def collect(settings: Settings) -> dict[str, Any]:
    """Full health snapshot used by the CLI and the offline report."""
    db = check_database(settings)
    web = check_web(settings)
    sources = check_sources(settings)
    mode = "offline" if not settings.live_web else "online"
    return {
        "mode": {
            "live_web": settings.live_web,
            "dry_run": settings.dry_run,
            "mode": mode,
            "label": "OFFLINE synthetic fixtures (no network, no production writes)"
            if mode == "offline"
            else "LIVE web sources (network required)",
        },
        "database": db,
        "web": web,
        "sources": sources,
        "configuration": {
            "web_search_provider": settings.web_search_provider or "(none)",
            "web_search_api_key": "set" if settings.web_search_api_key else "(missing)",
            "llm_provider": settings.llm_provider or "(none)",
            "llm_api_key": "set" if settings.llm_api_key else "(missing)",
            "fixture_path": settings.fixture_path or "(default)",
            "batch_size": settings.batch_size,
            "workers": settings.workers,
            "http_timeout_s": settings.http_timeout,
        },
    }
