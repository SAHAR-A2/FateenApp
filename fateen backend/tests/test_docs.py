"""Tests for OpenAPI docs, rate limiting, and request tracking."""
import pytest


def test_openapi_json(client):
    response = client.get("/openapi.json")
    assert response.status_code == 200
    schema = response.json()
    assert schema["info"]["title"] == "Fateen Backend API"
    assert schema["info"]["version"] == "1.0.0"
    assert len(schema["paths"]) >= 7


def test_docs_endpoint(client):
    response = client.get("/docs")
    assert response.status_code == 200


def test_redoc_endpoint(client):
    response = client.get("/redoc")
    assert response.status_code == 200


def test_request_id_header(client):
    response = client.get("/health")
    assert "X-Request-ID" in response.headers
    assert len(response.headers["X-Request-ID"]) == 8


def test_response_time_header(client):
    response = client.get("/health")
    assert "X-Response-Time" in response.headers
    assert response.headers["X-Response-Time"].endswith("s")


def test_rate_limit_not_exceeded(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert "429" not in str(response.status_code)
