from unittest.mock import patch


SAMPLE_ROWS = [
    {
        "internal_code": "MILK001",
        "name": "Fateen Milk",
        "description": "Fresh whole milk",
        "confidence_level": 0.95,
        "lifecycle_status": "active",
        "barcode": "6281000000066",
    },
]


class TestProductSearch:
    @patch("app.repositories.product_repository.get_connection")
    def test_search_returns_matches(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.return_value.fetchall.return_value = SAMPLE_ROWS

        response = client.get("/api/v1/products/search?q=milk")
        assert response.status_code == 200
        data = response.json()
        assert data["query"] == "milk"
        assert data["count"] == 1
        assert data["results"][0]["internal_code"] == "MILK001"
        assert data["results"][0]["barcode"] == "6281000000066"

    @patch("app.repositories.product_repository.get_connection")
    def test_search_no_matches(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.return_value.fetchall.return_value = []

        response = client.get("/api/v1/products/search?q=doesnotexist")
        assert response.status_code == 200
        data = response.json()
        assert data["count"] == 0
        assert data["results"] == []

    def test_search_query_too_short_returns_empty_without_hitting_db(self, client):
        # Single-character queries short-circuit in search_service before
        # any DB call is made.
        response = client.get("/api/v1/products/search?q=m")
        assert response.status_code == 200
        data = response.json()
        assert data["count"] == 0
        assert data["results"] == []

    def test_search_missing_query_param_is_422(self, client):
        response = client.get("/api/v1/products/search")
        assert response.status_code == 422

    @patch("app.repositories.product_repository.get_connection")
    def test_search_result_without_barcode_is_allowed(
        self, mock_get_conn, mock_db_connection, client
    ):
        row_without_barcode = {**SAMPLE_ROWS[0], "barcode": None}
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.return_value.fetchall.return_value = [
            row_without_barcode
        ]

        response = client.get("/api/v1/products/search?q=milk")
        assert response.status_code == 200
        assert response.json()["results"][0]["barcode"] is None
