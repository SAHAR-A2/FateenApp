"""P06: Safe HTTP retrieval with timeout, retry, backoff, and bounded failures.

NO operation may hang indefinitely. Every external call has a bounded timeout.
SSRF protection: rejects requests to private/reserved/internal IP ranges.
"""
# ---------------------------------------------------------------------------
# PRODUCTION-PATH STATUS (updated 2026-09-04):
# This module is now wired into the live collector path. When
# COLLECTOR_AUTO_EXTRACTION=true, app/collector/orchestrator.py fetches each
# candidate's source_url through retrieve() (accept_html=True) before LLM
# extraction. The wiring is covered by tests proving the connection
# (tests/test_collector_wiring.py). All safety protections below remain
# active for every request: SSRF / private-IP blocking, bounded timeout,
# bounded retries/backoff, redirect protection, content-size limit, and
# credential leakage rejection. They are never disabled for the pilot.
# ---------------------------------------------------------------------------

import ipaddress
import logging
import socket
import time
from dataclasses import dataclass
from typing import Optional

import httpx

from app.collector.models import RetrievalResult

logger = logging.getLogger("fateen.collector.retrieval")

DEFAULT_TIMEOUT = 30
DEFAULT_MAX_RETRIES = 3
DEFAULT_BACKOFF_BASE = 1.0
DEFAULT_BACKOFF_MAX = 60.0
DEFAULT_MAX_CONTENT_LENGTH = 10 * 1024 * 1024  # 10 MB

_BLOCKED_NETWORKS = [
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),
    ipaddress.ip_network("fe80::/10"),
    ipaddress.ip_network("0.0.0.0/8"),
    ipaddress.ip_network("224.0.0.0/4"),
    ipaddress.ip_network("240.0.0.0/4"),
]


def _is_safe_host(hostname: str) -> bool:
    """Resolve hostname and reject any private, loopback, link-local,
    multicast, reserved, or unspecified IP address.
    """

    try:
        addr_infos = socket.getaddrinfo(
            hostname,
            None,
            socket.AF_UNSPEC,
            socket.SOCK_STREAM,
        )
    except (socket.gaierror, OSError):
        return False

    if not addr_infos:
        return False

    for _, _, _, _, sockaddr in addr_infos:
        ip_str = sockaddr[0]

        try:
            ip = ipaddress.ip_address(ip_str)
        except ValueError:
            logger.warning(
                "SSRF blocked: invalid resolved IP %s for hostname %s",
                ip_str,
                hostname,
            )
            return False

        # Reject all non-public addresses.
        if (
            not ip.is_global
            or ip.is_private
            or ip.is_loopback
            or ip.is_link_local
            or ip.is_reserved
            or ip.is_multicast
            or ip.is_unspecified
        ):
            logger.warning(
                "SSRF blocked: hostname %s resolved to %s",
                hostname,
                ip_str,
            )
            return False

    return True

def _validate_url_safety(url: str) -> Optional[str]:
    """Validate URL before fetching it.

    Returns an error code or None when the URL is safe.
    """

    from urllib.parse import urlparse

    if not isinstance(url, str) or not url.strip():
        return "INVALID_URL"

    parsed = urlparse(url)

    if parsed.scheme.lower() not in {"http", "https"}:
        return "INVALID_URL"

    if not parsed.hostname:
        return "INVALID_URL"

    # Explicitly reject credentials in URLs.
    if parsed.username is not None or parsed.password is not None:
        return "INVALID_URL"

    if not _is_safe_host(parsed.hostname):
        return "SSRF_BLOCKED"

    return None

@dataclass
class RetrievalConfig:
    timeout: int = DEFAULT_TIMEOUT
    max_retries: int = DEFAULT_MAX_RETRIES
    backoff_base: float = DEFAULT_BACKOFF_BASE
    backoff_max: float = DEFAULT_BACKOFF_MAX
    max_content_length: int = DEFAULT_MAX_CONTENT_LENGTH
    user_agent: str = "FateenBot/1.0 (+https://fateen.app)"
    # When True, text/html responses are returned as content instead of
    # UNEXPECTED_HTML. Used by the collector's page-extraction path (product
    # pages are HTML). All other protections are unchanged.
    accept_html: bool = False


def _make_redirect_hook():
    """Create a redirect hook that blocks unsafe redirect targets."""

    def _on_redirect(request: httpx.Request, response: httpx.Response):
        redirect_url = response.headers.get("location", "")

        if not redirect_url:
            return

        from urllib.parse import urljoin, urlparse

        # Resolve relative redirects against the current URL.
        target_url = urljoin(str(request.url), redirect_url)
        parsed = urlparse(target_url)

        if parsed.scheme.lower() not in {"http", "https"}:
            raise httpx.TooManyRedirects(
                "Redirect to unsupported scheme blocked"
            )

        if not parsed.hostname:
            raise httpx.TooManyRedirects(
                "Redirect without hostname blocked"
            )

        if parsed.username is not None or parsed.password is not None:
            raise httpx.TooManyRedirects(
                "Redirect containing credentials blocked"
            )

        if not _is_safe_host(parsed.hostname):
            logger.warning(
                "SSRF redirect blocked: %s -> %s",
                request.url,
                target_url,
            )
            raise httpx.TooManyRedirects(
                "Redirect to internal or non-public address blocked (SSRF)"
            )

    return _on_redirect

def retrieve(
    url: str,
    config: Optional[RetrievalConfig] = None,
) -> RetrievalResult:
    """Retrieve content from a URL with retry, backoff, and bounded timeout.

    Returns a RetrievalResult. NEVER raises exceptions for expected failures.
    Every failure path returns a result with success=False.
    """
    if config is None:
        config = RetrievalConfig()

    if not url or not url.startswith(("http://", "https://")):
        return RetrievalResult(
            success=False, url=url,
            error="INVALID_URL",
            duration_seconds=0.0,
        )

    ssrf_error = _validate_url_safety(url)
    if ssrf_error:
        return RetrievalResult(
            success=False, url=url,
            error=ssrf_error,
            duration_seconds=0.0,
        )

    last_error = None
    retries = 0
    start_time = time.time()

    for attempt in range(config.max_retries + 1):
        try:
            with httpx.Client(
                timeout=httpx.Timeout(config.timeout),
                follow_redirects=True,
                max_redirects=5,
                limits=httpx.Limits(),
                event_hooks={"redirect": [_make_redirect_hook()]},
            ) as client:
                response = client.get(
                    url,
                    headers={"User-Agent": config.user_agent},
                )

                elapsed = time.time() - start_time

                if response.status_code == 429:
                    retry_after = response.headers.get("retry-after")
                    try:
                        wait = float(retry_after) if retry_after else 0
                    except (ValueError, TypeError):
                        wait = 0
                    wait = min(max(wait, config.backoff_base), config.backoff_max)
                    logger.warning(
                        "Rate limited at %s, waiting %.1fs", url, wait,
                    )
                    time.sleep(wait)
                    retries += 1
                    continue

                if response.status_code >= 500:
                    if attempt < config.max_retries:
                        wait = min(config.backoff_base * (2 ** attempt), config.backoff_max)
                        logger.warning(
                            "Server error %d at %s, retrying in %.1fs",
                            response.status_code, url, wait,
                        )
                        time.sleep(wait)
                        retries += 1
                        continue
                    return RetrievalResult(
                        success=False, url=url,
                        status_code=response.status_code,
                        error=f"HTTP_{response.status_code}",
                        duration_seconds=elapsed, retries=retries,
                    )

                if response.status_code == 403:
                    return RetrievalResult(
                        success=False, url=url,
                        status_code=403,
                        error="HTTP_403_FORBIDDEN",
                        duration_seconds=elapsed, retries=retries,
                    )

                if response.status_code == 404:
                    return RetrievalResult(
                        success=False, url=url,
                        status_code=404,
                        error="HTTP_404_NOT_FOUND",
                        duration_seconds=elapsed, retries=retries,
                    )

                if response.status_code >= 400:
                    return RetrievalResult(
                        success=False, url=url,
                        status_code=response.status_code,
                        error=f"HTTP_{response.status_code}",
                        duration_seconds=elapsed, retries=retries,
                    )

                content_type = response.headers.get("content-type", "")

                if "text/html" in content_type and not config.accept_html:
                    return RetrievalResult(
                        success=False, url=url,
                        status_code=response.status_code,
                        content_type=content_type,
                        error="UNEXPECTED_HTML",
                        duration_seconds=elapsed, retries=retries,
                    )

                content = response.text
                content_length = len(content.encode("utf-8"))

                if content_length > config.max_content_length:
                    return RetrievalResult(
                        success=False, url=url,
                        status_code=response.status_code,
                        content_type=content_type,
                        content_length=content_length,
                        error="CONTENT_TOO_LARGE",
                        duration_seconds=elapsed, retries=retries,
                    )

                return RetrievalResult(
                    success=True, url=url,
                    status_code=response.status_code,
                    content_type=content_type,
                    content=content,
                    content_length=content_length,
                    duration_seconds=elapsed, retries=retries,
                )

        except httpx.TimeoutException:
            last_error = "TIMEOUT"
            retries += 1
            if attempt < config.max_retries:
                wait = min(config.backoff_base * (2 ** attempt), config.backoff_max)
                logger.warning("Timeout at %s, retrying in %.1fs", url, wait)
                time.sleep(wait)
                continue

        except httpx.ConnectError:
            last_error = "CONNECTION_REFUSED"
            retries += 1
            if attempt < config.max_retries:
                wait = min(config.backoff_base * (2 ** attempt), config.backoff_max)
                logger.warning("Connection refused at %s, retrying in %.1fs", url, wait)
                time.sleep(wait)
                continue

        except httpx.TooManyRedirects:
            last_error = "TOO_MANY_REDIRECTS"
            break

        except Exception as e:
            last_error = f"UNEXPECTED_ERROR: {type(e).__name__}"
            logger.exception("Unexpected retrieval error for %s", url)
            break

    elapsed = time.time() - start_time
    return RetrievalResult(
        success=False, url=url,
        error=last_error or "MAX_RETRIES_EXCEEDED",
        duration_seconds=elapsed, retries=retries,
    )
