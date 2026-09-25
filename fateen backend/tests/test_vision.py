import os
from unittest.mock import AsyncMock, patch

import httpx


ENDPOINT = "/api/v1/vision/estimate-dish"


class TestVisionEstimation:
    def test_missing_token_is_401(self, client):
        response = client.post(ENDPOINT, json={"image_base64": "aGVsbG8="})
        assert response.status_code == 401

    def test_unconfigured_key_is_503_not_500(self, authenticated_client, monkeypatch):
        monkeypatch.delenv("GEMINI_API_KEY", raising=False)
        response = authenticated_client.post(
            ENDPOINT, json={"image_base64": "aGVsbG8="}
        )
        assert response.status_code == 503

    def test_invalid_base64_is_503_not_500(self, authenticated_client, monkeypatch):
        monkeypatch.setenv("GEMINI_API_KEY", "test-key-not-real")
        response = authenticated_client.post(
            ENDPOINT, json={"image_base64": "not valid base64 at all"}
        )
        assert response.status_code == 503

    def test_successful_estimation_is_parsed(self, authenticated_client, monkeypatch):
        monkeypatch.setenv("GEMINI_API_KEY", "test-key-not-real")
        fake_response = httpx.Response(
            status_code=200,
            json={
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": '{"name": "سلطة", "estimatedIngredients": ["خس", "طماطم"]}'
                                }
                            ]
                        }
                    }
                ]
            },
            request=httpx.Request("POST", "https://generativelanguage.googleapis.com/"),
        )
        with patch.object(
            httpx.AsyncClient, "post", new=AsyncMock(return_value=fake_response)
        ):
            response = authenticated_client.post(
                ENDPOINT, json={"image_base64": "aGVsbG8="}
            )
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "سلطة"
        assert data["estimated_ingredients"] == ["خس", "طماطم"]

    def test_missing_body_is_422(self, authenticated_client):
        response = authenticated_client.post(ENDPOINT, json={})
        assert response.status_code == 422
