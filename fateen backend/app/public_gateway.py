"""Restrict the public Fateen API service to the app-facing API surface.

Run this module instead of ``app.main:app`` for the deployed public API.
Internal ingestion, scan,
company-management, vision, dashboard, and documentation routes return 404.

This wraps ``app.main.app`` instead of registering middleware on it, so
importing this module never changes the behaviour of ``app.main.app``
itself (tests and internal tooling keep the full surface).
"""

import re

from fastapi.responses import JSONResponse
from starlette.datastructures import MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.main import app as _full_app


_ROUTES = (
    ("GET", re.compile(r"^/health$")),
    ("GET", re.compile(r"^/api/v1/products/search$")),
    ("GET", re.compile(r"^/api/v1/products/barcode/[^/]+$")),
    ("GET", re.compile(r"^/api/v1/products/details/barcode/[^/]+$")),
    (
        "POST",
        re.compile(r"^/api/v1/products/barcode/[^/]+/compatibility$"),
    ),
    (
        "POST",
        re.compile(r"^/api/v1/products/barcode/[^/]+/alternatives$"),
    ),
)


def is_public(method: str, path: str) -> bool:
    # OPTIONS is the CORS preflight for any public route; everything else
    # must match the route's own method exactly.
    method = method.upper()
    return any(
        route.fullmatch(path) and method in (route_method, "OPTIONS")
        for route_method, route in _ROUTES
    )


class PublicSurface:
    def __init__(self, inner: ASGIApp):
        self.inner = inner

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.inner(scope, receive, send)
            return

        if not is_public(scope["method"], scope["path"]):
            await JSONResponse({"detail": "Not found"}, status_code=404)(scope, receive, send)
            return

        async def send_no_store(message: Message) -> None:
            if message["type"] == "http.response.start":
                MutableHeaders(scope=message)["Cache-Control"] = "no-store"
            await send(message)

        await self.inner(scope, receive, send_no_store)


app = PublicSurface(_full_app)
