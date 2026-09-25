from unittest.mock import patch, MagicMock
from app.agent.models import IngestionResult


class TestIngestionAPI:
    @patch("app.api.ingestion.ingest")
    def test_ingest_dry_run(self, mock_ingest, client):
        mock_ingest.return_value = IngestionResult(
            dry_run=True,
            barcode="6281000000066",
            product_internal_code="FATEEN_MILK_TEST",
            changes=[],
            warnings=[],
            errors=[],
        )

        response = client.post(
            "/api/v1/agent/ingest",
            json={
                "barcode": "6281000000066",
                "dry_run": True,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["dry_run"] is True
        assert data["barcode"] == "6281000000066"
        assert data["product_internal_code"] == "FATEEN_MILK_TEST"

    @patch("app.api.ingestion.ingest")
    def test_ingest_with_data(self, mock_ingest, client):
        mock_ingest.return_value = IngestionResult(
            dry_run=True,
            barcode="6281000000066",
            product_internal_code="FATEEN_MILK_TEST",
            changes=[
                MagicMock(
                    action="no_change",
                    entity="ingredient",
                    entity_id=1,
                    details={"name": "MILK"},
                )
            ],
            warnings=[],
            errors=[],
        )

        response = client.post(
            "/api/v1/agent/ingest",
            json={
                "barcode": "6281000000066",
                "dry_run": True,
                "ingredients": [{"name": "MILK"}],
                "allergens": [{"name": "MILK"}],
                "nutrition": [
                    {
                        "nutrition_type": "energy",
                        "amount_value": 61.0,
                        "unit": "kcal",
                    }
                ],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["product_internal_code"] == "FATEEN_MILK_TEST"

    @patch("app.api.ingestion.ingest")
    def test_ingest_error_returns_500(self, mock_ingest, client):
        mock_ingest.side_effect = Exception("DB connection failed")

        response = client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": True},
        )

        assert response.status_code == 500

    @patch("app.api.ingestion.settings")
    def test_missing_api_key_returns_401(self, mock_settings, client):
        mock_settings.agent_ingest_api_key = "secret123"

        response = client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": True},
        )

        assert response.status_code == 401
        assert "Missing API key" in response.json()["detail"]

    @patch("app.api.ingestion.settings")
    def test_invalid_api_key_returns_401(self, mock_settings, client):
        mock_settings.agent_ingest_api_key = "secret123"

        response = client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": True},
            headers={"X-Agent-API-Key": "wrong_key"},
        )

        assert response.status_code == 401
        assert "Invalid API key" in response.json()["detail"]

    @patch("app.api.ingestion.settings")
    @patch("app.api.ingestion.ingest")
    def test_valid_api_key_passes(self, mock_ingest, mock_settings, client):
        mock_settings.agent_ingest_api_key = "secret123"
        mock_settings.agent_dry_run = True
        mock_ingest.return_value = IngestionResult(
            dry_run=True,
            barcode="6281000000066",
            product_internal_code="FATEEN_MILK_TEST",
        )

        response = client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": True},
            headers={"X-Agent-API-Key": "secret123"},
        )

        assert response.status_code == 200

    @patch("app.api.ingestion.settings")
    @patch("app.api.ingestion.ingest")
    def test_no_key_required_when_empty(
        self, mock_ingest, mock_settings, client
    ):
        mock_settings.agent_ingest_api_key = ""
        mock_settings.agent_dry_run = True
        mock_ingest.return_value = IngestionResult(
            dry_run=True,
            barcode="6281000000066",
            product_internal_code="FATEEN_MILK_TEST",
        )

        response = client.post(
            "/api/v1/agent/ingest",
            json={"barcode": "6281000000066", "dry_run": True},
        )

        assert response.status_code == 200

    def test_missing_barcode_returns_422(self, client):
        response = client.post(
            "/api/v1/agent/ingest",
            json={"dry_run": True},
        )
        assert response.status_code == 422

    def test_confidence_validation_rejects_over_one(self, client):
        response = client.post(
            "/api/v1/agent/ingest",
            json={
                "barcode": "6281000000066",
                "dry_run": True,
                "confidence_level": 1.5,
            },
        )
        assert response.status_code == 422
