"""The deployed surface (app.public_gateway) exposes only app-facing routes."""
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.public_gateway import app


@pytest.fixture(scope="module")
def gateway():
    return TestClient(app)


@pytest.mark.parametrize("method,path", [
    ("GET", "/docs"),
    ("GET", "/openapi.json"),
    ("GET", "/api/v1/dashboard/summary"),
    ("GET", "/api/v1/database/summary"),
    ("POST", "/api/v1/agent/ingest"),
    ("POST", "/api/v1/scan/discover/company-1"),
    ("GET", "/api/v1/companies"),
    # Right path, wrong method.
    ("POST", "/api/v1/products/search"),
    ("GET", "/api/v1/products/barcode/6281000000066/compatibility"),
    ("HEAD", "/api/v1/products/search"),
])
def test_internal_or_wrong_method_is_404(gateway, method, path):
    assert gateway.request(method, path).status_code == 404


@patch("app.api.products.search_products_by_name")
def test_public_search_is_served_and_not_cached(mock_search, gateway):
    from app.schemas.search import ProductSearchResponse

    mock_search.return_value = ProductSearchResponse(query="حليب", count=0, results=[])
    response = gateway.get("/api/v1/products/search", params={"q": "حليب"})
    assert response.status_code == 200
    assert response.headers["Cache-Control"] == "no-store"


def test_cors_preflight_reaches_public_route(gateway):
    response = gateway.options(
        "/api/v1/products/barcode/6281000000066/compatibility",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert response.status_code == 200
