"""Internal review queue: products kept in FateenDB that still miss fields.

Not part of app.public_gateway; protected by the agent API key like the
other internal routes.
"""
import hmac
import logging
from typing import Optional

import psycopg
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel

from app.core.config import settings
from app.repositories.review_repository import (
    MISSING_FIELDS,
    completeness_summary,
    list_incomplete,
)

logger = logging.getLogger("fateen.api.review")

router = APIRouter(prefix="/api/v1/review", tags=["Review"])


class ReviewSummary(BaseModel):
    products: int
    complete: int
    missing_by_field: dict[str, int]


class ReviewItem(BaseModel):
    internal_code: str
    name: str
    confidence_level: float
    missing_fields: list[str]


class ReviewList(BaseModel):
    total: int
    limit: int
    offset: int
    items: list[ReviewItem]


def _check_api_key(request: Request):
    api_key = request.headers.get("X-Agent-API-Key", "")
    if settings.agent_ingest_api_key and not hmac.compare_digest(api_key, settings.agent_ingest_api_key):
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


def _view_missing() -> HTTPException:
    return HTTPException(
        status_code=503,
        detail="product_completeness view not found: apply migration 0054",
    )


@router.get("/summary", response_model=ReviewSummary, summary="Completeness counts")
def review_summary(request: Request):
    _check_api_key(request)
    try:
        return completeness_summary()
    except psycopg.errors.UndefinedTable:
        raise _view_missing()


@router.get("/products", response_model=ReviewList, summary="Products that still miss fields")
def review_products(
    request: Request,
    missing: Optional[str] = Query(default=None, description=f"one of: {', '.join(MISSING_FIELDS)}"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    _check_api_key(request)
    if missing is not None and missing not in MISSING_FIELDS:
        raise HTTPException(status_code=422, detail=f"missing must be one of {list(MISSING_FIELDS)}")
    try:
        total, items = list_incomplete(missing, limit, offset)
    except psycopg.errors.UndefinedTable:
        raise _view_missing()
    return {"total": total, "limit": limit, "offset": offset, "items": items}
