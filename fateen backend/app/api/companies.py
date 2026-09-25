import hmac
import logging

from fastapi import APIRouter, HTTPException, Query, Request
from typing import Optional

from app.core.config import settings
from app.repositories.company_repository import (
    get_company_by_id,
    list_companies,
    create_company,
    update_company,
    delete_company,
)
from app.schemas.company import (
    CompanyCreate,
    CompanyUpdate,
    CompanyResponse,
    CompanyListResponse,
)
from app.collector.prioritization import (
    update_company_priorities,
    get_companies_by_priority,
)

logger = logging.getLogger("fateen.api.companies")

router = APIRouter(prefix="/api/v1/companies", tags=["Companies"])


def _check_api_key(request: Request):
    api_key = request.headers.get("X-Agent-API-Key", "")
    if settings.agent_ingest_api_key and not hmac.compare_digest(api_key, settings.agent_ingest_api_key):
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


@router.get(
    "/priority/list",
    summary="List companies by priority score",
    response_model=list[CompanyResponse],
    responses={401: {"description": "Invalid or missing API key"}},
)
def list_companies_by_priority(
    request: Request,
    limit: int = Query(default=10, ge=1, le=100),
):
    _check_api_key(request)
    companies = get_companies_by_priority(limit=limit)
    return companies


@router.post(
    "/priority/recalculate",
    summary="Recalculate all company priority scores",
    responses={401: {"description": "Invalid or missing API key"}},
)
def recalculate_priorities(request: Request):
    _check_api_key(request)
    try:
        update_company_priorities()
    except Exception:
        logger.exception("Failed to recalculate priorities")
        raise HTTPException(
            status_code=500, detail="Failed to recalculate priorities"
        )
    return {"detail": "Priority recalculation completed"}


@router.get(
    "",
    summary="List companies with optional filters",
    response_model=CompanyListResponse,
    responses={401: {"description": "Invalid or missing API key"}},
)
def list_companies_route(
    request: Request,
    country: Optional[str] = Query(default=None),
    market: Optional[str] = Query(default=None),
    status: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
):
    _check_api_key(request)
    companies = list_companies(
        country=country,
        market=market,
        status=status,
        limit=limit,
        offset=offset,
    )
    return CompanyListResponse(
        companies=companies,
        total=len(companies),
    )


@router.get(
    "/{company_id}",
    summary="Get company by ID",
    response_model=CompanyResponse,
    responses={
        401: {"description": "Invalid or missing API key"},
        404: {"description": "Company not found"},
    },
)
def get_company(company_id: str, request: Request):
    _check_api_key(request)
    company = get_company_by_id(company_id)
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    return company


@router.post(
    "",
    summary="Create a new company",
    status_code=201,
    response_model=CompanyResponse,
    responses={
        401: {"description": "Invalid or missing API key"},
        422: {"description": "Validation error"},
    },
)
def create_company_route(body: CompanyCreate, request: Request):
    _check_api_key(request)
    company_id = create_company(
        name=body.name,
        code=body.code,
        slug=body.slug,
        country=body.country,
        market=body.market,
        priority=body.priority,
        expected_product_count=body.expected_product_count,
        description=body.description,
    )
    if not company_id:
        raise HTTPException(
            status_code=500, detail="Failed to create company"
        )
    company = get_company_by_id(company_id)
    if not company:
        raise HTTPException(
            status_code=500, detail="Company created but could not be retrieved"
        )
    return company


@router.put(
    "/{company_id}",
    summary="Update an existing company",
    response_model=CompanyResponse,
    responses={
        401: {"description": "Invalid or missing API key"},
        404: {"description": "Company not found"},
        422: {"description": "Validation error"},
    },
)
def update_company_route(company_id: str, body: CompanyUpdate, request: Request):
    _check_api_key(request)
    existing = get_company_by_id(company_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Company not found")

    update_fields = body.model_dump(exclude_unset=True)
    if update_fields:
        updated = update_company(company_id, **update_fields)
        if not updated:
            raise HTTPException(
                status_code=500, detail="Failed to update company"
            )

    company = get_company_by_id(company_id)
    return company


@router.delete(
    "/{company_id}",
    summary="Soft delete a company",
    responses={
        401: {"description": "Invalid or missing API key"},
        404: {"description": "Company not found"},
    },
)
def delete_company_route(company_id: str, request: Request):
    _check_api_key(request)
    existing = get_company_by_id(company_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Company not found")

    deleted = delete_company(company_id)
    if not deleted:
        raise HTTPException(
            status_code=500, detail="Failed to delete company"
        )
    return {"detail": "Company deleted"}
