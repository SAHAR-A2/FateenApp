"""Restrict the public Fateen API service to the app-facing API surface.

Run this module instead of ``app.main:app`` for the deployed public API.
Internal ingestion, scan,
company-management, vision, dashboard, and documentation routes return 404.
"""

import re

from fastapi.responses import JSONResponse
from starlette.requests import Request

from app.main import app


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


@app.middleware("http")
async def limit_public_routes(request: Request, call_next):
    method = request.method.upper()
    path = request.url.path
    allowed = any(
        route.fullmatch(path) and method in (methods if method != "OPTIONS" else ("GET", "POST"))
        for methods, route in _ROUTES
    )
    if not allowed:
        return JSONResponse({"detail": "Not found"}, status_code=404)

    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store"
    return response
