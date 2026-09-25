class TestCORS:
    def test_cors_allows_origin(self, client):
        response = client.get(
            "/health",
            headers={"Origin": "http://localhost:3000"},
        )
        assert "access-control-allow-origin" in response.headers

    def test_cors_preflight(self, client):
        response = client.options(
            "/api/v1/products/barcode/1234567890123",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )
        assert "access-control-allow-origin" in response.headers
        allow_methods = response.headers.get("access-control-allow-methods", "")
        assert "GET" in allow_methods

    def test_cors_allow_credentials(self, client):
        response = client.get(
            "/health",
            headers={"Origin": "http://localhost:3000"},
        )
        assert response.headers.get("access-control-allow-credentials") == "true"
