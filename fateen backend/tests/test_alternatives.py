from unittest.mock import patch


ORIGINAL_DETAILS = {
    "id": "11111111-1111-1111-1111-111111111111",
    "internal_code": "FATEEN_SNACK_TEST",
    "name": "Fateen Test Snack",
    "description": None,
    "confidence_level": 1.0,
    "product_category_id": "cat-snacks",
    "lifecycle_status": "ACTIVE",
    "ingredients": [
        {
            "internal_code": "PEANUT",
            "name": "Peanut",
            "relationship_type": "CONTAINS_INGREDIENT",
            "amount_value": None,
            "unit": None,
            "confidence_level": 1.0,
            "evidence_type": "LABEL",
        }
    ],
    "allergens": [
        {
            "internal_code": "PEANUT",
            "name": "Peanut",
            "relationship_type": "CONTAINS_ALLERGEN",
            "confidence_level": 1.0,
            "evidence_type": "DATABASE",
        }
    ],
    "health_flags": [],
    "nutrition": [],
}

SAFE_CANDIDATE_DETAILS = {
    **ORIGINAL_DETAILS,
    "internal_code": "SNACK_PEANUT_FREE",
    "name": "Peanut-Free Snack",
    "ingredients": [
        {
            "internal_code": "OAT",
            "name": "Oat",
            "relationship_type": "CONTAINS_INGREDIENT",
            "amount_value": None,
            "unit": None,
            "confidence_level": 1.0,
            "evidence_type": "LABEL",
        }
    ],
    "allergens": [],
}

BARCODE = "6281000000073"
ENDPOINT = f"/api/v1/products/barcode/{BARCODE}/alternatives"

DETAILS_BY_BARCODE = {
    BARCODE: ORIGINAL_DETAILS,
    "6281000000090": SAFE_CANDIDATE_DETAILS,
    "6281000000091": ORIGINAL_DETAILS,  # still contains peanut
}


def _fake_details(barcode):
    return DETAILS_BY_BARCODE.get(barcode)


class TestAlternativesAuthentication:
    def test_missing_token_is_401(self, client):
        response = client.post(ENDPOINT, json={"allergies": [], "diseases": []})
        assert response.status_code == 401


class TestAlternatives:
    @patch(
        "app.services.alternatives_service.get_alternative_candidates_by_category",
        return_value=[
            {"internal_code": "SNACK_PEANUT_FREE", "name": "Peanut-Free Snack", "barcode": "6281000000090"},
            {"internal_code": "SNACK_WITH_PEANUT", "name": "Another Peanut Snack", "barcode": "6281000000091"},
            {"internal_code": "SNACK_NO_BARCODE", "name": "Barcode-less Snack", "barcode": None},
        ],
    )
    @patch(
        "app.services.compatibility_service.get_product_details_by_barcode",
        side_effect=_fake_details,
    )
    @patch(
        "app.services.alternatives_service.get_product_details_by_barcode",
        side_effect=_fake_details,
    )
    def test_only_confirmed_safe_candidates_returned(
        self, mock_alt_details, mock_compat_details, mock_candidates, authenticated_client
    ):
        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["candidates_considered"] == 3
        assert data["candidates_confirmed_safe"] == 1
        assert len(data["alternatives"]) == 1
        assert data["alternatives"][0]["product"]["internal_code"] == "SNACK_PEANUT_FREE"

    @patch(
        "app.services.alternatives_service.get_product_details_by_barcode",
        return_value=None,
    )
    def test_unknown_barcode_is_404(self, mock_details, authenticated_client):
        response = authenticated_client.post(
            "/api/v1/products/barcode/0000000000000/alternatives",
            json={"allergies": [], "diseases": []},
        )
        assert response.status_code == 404

    @patch(
        "app.services.alternatives_service.get_alternative_candidates_by_category",
        return_value=[],
    )
    @patch(
        "app.services.alternatives_service.get_product_details_by_barcode",
        side_effect=_fake_details,
    )
    def test_no_candidates_returns_empty_list_not_error(
        self, mock_details, mock_candidates, authenticated_client
    ):
        response = authenticated_client.post(ENDPOINT, json={"allergies": [], "diseases": []})
        assert response.status_code == 200
        data = response.json()
        assert data["alternatives"] == []
        assert data["candidates_considered"] == 0
