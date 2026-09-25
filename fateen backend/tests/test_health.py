from unittest.mock import patch


class TestHealthEndpoint:
    @patch("app.main.check_database")
    def test_health_success(self, mock_check, client):
        mock_check.return_value = {
            "database": "fateen",
            "version": "PostgreSQL 15.0",
        }
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert data["database"] == "fateen"

    @patch("app.main.check_database")
    def test_health_db_failure_returns_503(self, mock_check, client):
        mock_check.side_effect = Exception("Connection refused")
        response = client.get("/health")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "error"
        assert data["database"] == "unavailable"

    @patch("app.main.check_database")
    def test_health_db_timeout_returns_503(self, mock_check, client):
        mock_check.side_effect = TimeoutError("Connection timed out")
        response = client.get("/health")
        assert response.status_code == 503
