from unittest.mock import patch, MagicMock


SAMPLE_PRODUCT = {
    "id": 1,
    "internal_code": "MILK001",
    "name": "Fateen Milk",
    "description": "Fresh whole milk",
    "confidence_level": 0.95,
    "product_category_id": 1,
    "lifecycle_status": "ACTIVE",
    "image_url": None,
}

SAMPLE_INGREDIENTS = [
    {
        "internal_code": "ING001",
        "name": "Milk",
        "relationship_type": "contains",
        "amount_value": 100.0,
        "unit": "ml",
        "confidence_level": 0.9,
        "evidence_type": "verified",
    }
]

SAMPLE_ALLERGENS = [
    {
        "internal_code": "ALL001",
        "name": "Milk Protein",
        "relationship_type": "contains",
        "confidence_level": 0.95,
        "evidence_type": "verified",
    }
]

SAMPLE_HEALTH_FLAGS = [
    {
        "internal_code": "HF001",
        "name": "Halal",
        "relationship_type": "certified",
        "confidence_level": 1.0,
        "evidence_type": "verified",
    }
]

SAMPLE_NUTRITION = [
    {
        "nutrition_type": "energy",
        "amount_value": 61.0,
        "unit": "kcal",
        "relationship_type": "contains",
        "confidence_level": 0.85,
        "evidence_type": "verified",
        "measurement_basis": "per_100ml",
    }
]


class TestProductDetails:
    @patch("app.services.product_details_service.get_connection")
    def test_product_details_found(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.side_effect = [
            MagicMock(fetchone=lambda: SAMPLE_PRODUCT),
            MagicMock(fetchall=lambda: SAMPLE_INGREDIENTS),
            MagicMock(fetchall=lambda: SAMPLE_ALLERGENS),
            MagicMock(fetchall=lambda: SAMPLE_HEALTH_FLAGS),
            MagicMock(fetchall=lambda: SAMPLE_NUTRITION),
            MagicMock(fetchone=lambda: {"present": False}),  # no 0056 statements table
        ]

        response = client.get("/api/v1/products/details/barcode/6281000000066")
        assert response.status_code == 200
        data = response.json()
        assert data["internal_code"] == "MILK001"
        assert data["name"] == "Fateen Milk"
        assert data["description"] == "Fresh whole milk"
        assert data["confidence_level"] == 0.95
        assert len(data["ingredients"]) == 1
        assert len(data["allergens"]) == 1
        assert len(data["health_flags"]) == 1
        assert len(data["nutrition"]) == 1

    @patch("app.services.product_details_service.get_connection")
    def test_product_details_not_found(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.side_effect = [
            MagicMock(fetchone=lambda: None),
        ]

        response = client.get("/api/v1/products/details/barcode/0000000000000")
        assert response.status_code == 404
        assert response.json()["detail"] == "Product barcode not found"

    @patch("app.services.product_details_service.get_connection")
    def test_product_details_empty_subtables(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.side_effect = [
            MagicMock(fetchone=lambda: SAMPLE_PRODUCT),
            MagicMock(fetchall=lambda: []),
            MagicMock(fetchall=lambda: []),
            MagicMock(fetchall=lambda: []),
            MagicMock(fetchall=lambda: []),
            MagicMock(fetchone=lambda: {"present": False}),
        ]

        response = client.get("/api/v1/products/details/barcode/6281000000066")
        assert response.status_code == 200
        data = response.json()
        assert data["ingredients"] == []
        assert data["allergens"] == []
        assert data["health_flags"] == []
        assert data["nutrition"] == []

    @patch("app.services.product_details_service.get_connection")
    def test_product_details_response_structure(self, mock_get_conn, mock_db_connection, client):
        mock_get_conn.return_value = mock_db_connection
        mock_db_connection.execute.side_effect = [
            MagicMock(fetchone=lambda: SAMPLE_PRODUCT),
            MagicMock(fetchall=lambda: SAMPLE_INGREDIENTS),
            MagicMock(fetchall=lambda: SAMPLE_ALLERGENS),
            MagicMock(fetchall=lambda: SAMPLE_HEALTH_FLAGS),
            MagicMock(fetchall=lambda: SAMPLE_NUTRITION),
            MagicMock(fetchone=lambda: {"present": False}),  # no 0056 statements table
        ]

        response = client.get("/api/v1/products/details/barcode/6281000000066")
        data = response.json()
        expected_top_keys = {
            "internal_code", "name", "description", "confidence_level",
            "lifecycle_status", "image_url", "ingredients", "allergens", "health_flags", "nutrition", "ingredient_statements", "name_ar", "name_en",
        }
        assert set(data.keys()) == expected_top_keys
