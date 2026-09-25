from unittest.mock import patch


SAMPLE_PRODUCT = {
    "internal_code": "MILK001",
    "name": "Fateen Milk",
    "barcode": "6281000000066",
    "relationship_type": "primary",
    "source": "manual",
    "evidence_type": "verified",
    "lifecycle_status": "active",
    "confidence_level": 0.95,
}


class TestProductByBarcode:
    @patch("app.services.barcode_service.get_connection")
    def test_barcode_found(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.return_value.fetchone.return_value = SAMPLE_PRODUCT

        response = client.get("/api/v1/products/barcode/6281000000066")
        assert response.status_code == 200
        data = response.json()
        assert data["barcode"] == "6281000000066"
        assert data["name"] == "Fateen Milk"
        assert data["internal_code"] == "MILK001"
        assert data["confidence_level"] == 0.95
        assert data["lifecycle_status"] == "active"

    @patch("app.services.barcode_service.get_connection")
    def test_barcode_not_found(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.return_value.fetchone.return_value = None

        response = client.get("/api/v1/products/barcode/0000000000000")
        assert response.status_code == 404
        assert response.json()["detail"] == "Product barcode not found"

    @patch("app.services.barcode_service.get_connection")
    def test_barcode_response_has_all_fields(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.return_value.fetchone.return_value = SAMPLE_PRODUCT

        response = client.get("/api/v1/products/barcode/6281000000066")
        data = response.json()
        expected_keys = {
            "internal_code", "name", "barcode", "relationship_type",
            "source", "evidence_type", "lifecycle_status", "confidence_level",
        }
        assert set(data.keys()) == expected_keys

    @patch("app.services.barcode_service.get_connection")
    def test_barcode_with_null_source(self, mock_get_conn, mock_db_connection, client):
        product_no_source = {**SAMPLE_PRODUCT, "source": None}
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.return_value.fetchone.return_value = product_no_source

        response = client.get("/api/v1/products/barcode/6281000000066")
        assert response.status_code == 200
        assert response.json()["source"] is None
