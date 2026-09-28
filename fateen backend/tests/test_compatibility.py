from unittest.mock import patch

import pytest


# Mirrors the verified baseline:
# GET /api/v1/products/details/barcode/6281000000073 -> Fateen Test Snack,
# PEANUT / CONTAINS_INGREDIENT / LABEL, PEANUT / CONTAINS_ALLERGEN / DATABASE.
SAMPLE_DETAILS = {
    "id": "11111111-1111-1111-1111-111111111111",
    "internal_code": "FATEEN_SNACK_TEST",
    "name": "Fateen Test Snack",
    "description": None,
    "confidence_level": 1.0,
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

BARCODE = "6281000000073"
ENDPOINT = f"/api/v1/products/barcode/{BARCODE}/compatibility"


class TestCompatibilityAllergens:
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_peanut_allergy_severe_is_danger(self, mock_details, authenticated_client):
        mock_details.return_value = SAMPLE_DETAILS

        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "DANGER"
        assert len(data["matched_allergens"]) == 1
        assert data["matched_allergens"][0]["internal_code"] == "PEANUT"
        assert data["product"]["internal_code"] == "FATEEN_SNACK_TEST"

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_peanut_allergy_mild_is_warning(self, mock_details, authenticated_client):
        mock_details.return_value = SAMPLE_DETAILS

        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:peanuts", "severity": "خفيف"}], "diseases": []},
        )
        assert response.json()["status"] == "WARNING"

    @patch("app.services.allergen_mapping.live_allergen_codes", return_value=frozenset({"PEANUT", "MILK"}))
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_allergen_code_missing_from_database_is_unknown_not_safe(
            self, mock_details, mock_codes, authenticated_client
    ):
        # 'en:gluten' needs GLUTEN and WHEAT rows. On a database without
        # them (0055 not applied) the answer must be UNKNOWN, never SAFE.
        mock_details.return_value = SAMPLE_DETAILS

        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:gluten", "severity": "شديد"}], "diseases": []},
        )
        assert response.json()["status"] == "UNKNOWN"

    @pytest.mark.parametrize("user_tag,product_code", [
        ("en:wheat", "GLUTEN"),   # OFF records wheat under en:gluten
        ("en:gluten", "WHEAT"),
        ("en:crustaceans", "SHELLFISH"),
    ])
    @patch("app.services.allergen_mapping.live_allergen_codes",
           return_value=frozenset({"PEANUT", "WHEAT", "GLUTEN", "SHELLFISH"}))
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_related_allergen_codes_match(
            self, mock_details, mock_codes, user_tag, product_code, authenticated_client
    ):
        mock_details.return_value = {
            **SAMPLE_DETAILS,
            "allergens": [{**SAMPLE_DETAILS["allergens"][0], "internal_code": product_code, "name": product_code}],
        }
        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": user_tag, "severity": "شديد"}], "diseases": []},
        )
        data = response.json()
        assert data["status"] == "DANGER"
        assert data["matched_allergens"][0]["internal_code"] == product_code

    @patch("app.services.allergen_mapping.live_allergen_codes", return_value=frozenset({"PEANUT"}))
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_contains_outranks_may_contain_across_codes(
            self, mock_details, mock_codes, authenticated_client
    ):
        mock_details.return_value = {
            **SAMPLE_DETAILS,
            "allergens": [
                {**SAMPLE_DETAILS["allergens"][0], "relationship_type": "MAY_CONTAIN_ALLERGEN"},
            ],
        }
        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []},
        )
        assert "آثار" in response.json()["reason"]

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_unmapped_tag_is_unknown(self, mock_details, authenticated_client):
        mock_details.return_value = SAMPLE_DETAILS

        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:something-unheard-of"}], "diseases": []},
        )
        assert response.json()["status"] == "UNKNOWN"

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_no_allergy_or_disease_context_is_safe(self, mock_details, authenticated_client):
        mock_details.return_value = SAMPLE_DETAILS

        response = authenticated_client.post(ENDPOINT, json={"allergies": [], "diseases": []})
        assert response.json()["status"] == "SAFE"


class TestCompatibilityHealthConditions:
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    @patch("app.collector.health_conditions.get_health_conditions", return_value=[])
    def test_disease_with_no_backend_rule_is_unknown_not_safe(
            self, mock_conditions, mock_details, authenticated_client
    ):
        mock_details.return_value = SAMPLE_DETAILS

        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [], "diseases": [{"name": "سكري", "severity": "متوسط"}]},
        )
        data = response.json()
        assert data["status"] == "UNKNOWN"
        assert data["health_conditions"][0]["evaluation_result"] == "UNKNOWN"


    @pytest.mark.parametrize("app_label,code", [
        ("سكري", "DIABETES"),
        ("ارتفاع الضغط", "HYPERTENSION"),
        ("كوليسترول", "HIGH_CHOLESTEROL"),
    ])
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    @patch("app.collector.health_conditions.evaluate_single_condition")
    @patch("app.collector.health_conditions.get_health_conditions")
    def test_app_arabic_disease_labels_reach_their_condition(
            self, mock_conditions, mock_evaluate, mock_details, app_label, code, authenticated_client
    ):
        # lib/data/disease_options.dart sends these Arabic labels.
        mock_details.return_value = SAMPLE_DETAILS
        mock_conditions.return_value = [{"id": "c1", "name": code.title(), "code": code}]
        mock_evaluate.return_value = {
            "condition_code": code, "condition_name": code.title(),
            "evaluation_result": "WARNING", "evidence": [],
        }
        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [], "diseases": [{"name": app_label, "severity": "متوسط"}]},
        )
        data = response.json()
        mock_evaluate.assert_called_once_with(SAMPLE_DETAILS["id"], code)
        assert data["status"] == "WARNING"

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    @patch("app.collector.health_conditions.get_health_conditions",
           return_value=[{"id": "c1", "name": "Diabetes", "code": "DIABETES"}])
    def test_low_blood_pressure_has_no_rule_and_stays_unknown(
            self, mock_conditions, mock_details, authenticated_client
    ):
        mock_details.return_value = SAMPLE_DETAILS
        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [], "diseases": [{"name": "انخفاض الضغط", "severity": "متوسط"}]},
        )
        assert response.json()["status"] == "UNKNOWN"


class TestCompatibilityDataSufficiency:
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_product_with_no_enrichment_is_insufficient_data(
            self, mock_details, authenticated_client
    ):
        empty_details = {
            **SAMPLE_DETAILS,
            "ingredients": [],
            "allergens": [],
            "nutrition": [],
        }
        mock_details.return_value = empty_details

        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []},
        )
        assert response.json()["status"] == "INSUFFICIENT_DATA"


class TestCompatibilityAuthentication:
    def test_missing_token_is_401(self, client):
        # Plain `client` fixture has no auth override -- this proves the
        # endpoint fails closed by default (no configured Firebase
        # credential => reject, never silently allow through).
        response = client.post(
            ENDPOINT,
            json={"allergies": [], "diseases": []},
        )
        assert response.status_code == 401

    def test_malformed_bearer_token_is_401(self, client):
        response = client.post(
            ENDPOINT,
            json={"allergies": [], "diseases": []},
            headers={"Authorization": "NotBearer something"},
        )
        assert response.status_code == 401


class TestCompatibilityResilience:
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    @patch(
        "app.collector.health_conditions.get_health_conditions",
        side_effect=RuntimeError("db down"),
    )
    def test_condition_list_failure_degrades_to_unknown_not_500(
        self, mock_conditions, mock_details, authenticated_client
    ):
        mock_details.return_value = SAMPLE_DETAILS
        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [], "diseases": [{"name": "سكري"}]},
        )
        assert response.status_code == 200
        assert response.json()["status"] == "UNKNOWN"

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    @patch(
        "app.collector.health_conditions.get_health_conditions",
        return_value=[{"code": "DIABETES", "name": "سكري"}],
    )
    @patch(
        "app.collector.health_conditions.evaluate_single_condition",
        side_effect=RuntimeError("transient db error"),
    )
    def test_single_condition_failure_degrades_to_unknown_not_500(
        self, mock_evaluate, mock_conditions, mock_details, authenticated_client
    ):
        mock_details.return_value = SAMPLE_DETAILS
        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [], "diseases": [{"name": "سكري"}]},
        )
        assert response.status_code == 200
        assert response.json()["status"] == "UNKNOWN"


class TestCompatibilityNotFound:
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_unknown_barcode_is_404(self, mock_details, authenticated_client):
        mock_details.return_value = None

        response = authenticated_client.post(
            "/api/v1/products/barcode/0000000000000/compatibility",
            json={"allergies": [], "diseases": []},
        )
        assert response.status_code == 404
        assert response.json()["detail"] == "Product barcode not found"


class TestCompatibilityAllergenEvidence:
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_nutrition_only_product_is_not_safe_for_allergic_user(
            self, mock_details, authenticated_client
    ):
        """Nutrition values say nothing about allergens; never report SAFE."""
        mock_details.return_value = {
            **SAMPLE_DETAILS,
            "ingredients": [],
            "allergens": [],
            "nutrition": [{
                "nutrition_type": "ENERGY", "amount_value": 500.0, "unit": "KCAL",
                "relationship_type": "MEASURED_VALUE", "confidence_level": 0.5,
                "evidence_type": "DATABASE", "measurement_basis": "PER_100G",
            }],
        }
        response = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []},
        )
        assert response.json()["status"] == "INSUFFICIENT_DATA"

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_nutrition_only_product_without_allergies_is_safe(
            self, mock_details, authenticated_client
    ):
        mock_details.return_value = {
            **SAMPLE_DETAILS,
            "ingredients": [],
            "allergens": [],
            "nutrition": [{
                "nutrition_type": "ENERGY", "amount_value": 500.0, "unit": "KCAL",
                "relationship_type": "MEASURED_VALUE", "confidence_level": 0.5,
                "evidence_type": "DATABASE", "measurement_basis": "PER_100G",
            }],
        }
        response = authenticated_client.post(
            ENDPOINT, json={"allergies": [], "diseases": []},
        )
        assert response.json()["status"] == "SAFE"

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_may_contain_is_flagged_with_trace_wording(self, mock_details, authenticated_client):
        mock_details.return_value = {
            **SAMPLE_DETAILS,
            "allergens": [{
                "internal_code": "PEANUT", "name": "Peanut",
                "relationship_type": "MAY_CONTAIN_ALLERGEN",
                "confidence_level": 0.7, "evidence_type": "LABEL",
            }],
        }
        data = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []},
        ).json()
        assert data["status"] == "DANGER"
        assert "قد يحتوي" in data["reason"]

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_contains_outranks_may_contain_for_same_allergen(
            self, mock_details, authenticated_client
    ):
        contains = SAMPLE_DETAILS["allergens"][0]
        may_contain = {**contains, "relationship_type": "MAY_CONTAIN_ALLERGEN"}
        mock_details.return_value = {**SAMPLE_DETAILS, "allergens": [contains, may_contain]}
        data = authenticated_client.post(
            ENDPOINT,
            json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []},
        ).json()
        assert data["status"] == "DANGER"
        assert data["reason"].startswith("يحتوي")


class TestIngredientStatementEvidence:
    @patch("app.services.allergen_mapping.live_allergen_codes", return_value=frozenset({"PEANUT"}))
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_statement_without_the_allergen_is_evidence(self, mock_details, mock_codes, authenticated_client):
        # The loader stores the allergens found in a statement, so a statement
        # with no PEANUT row means peanut was not found in it.
        mock_details.return_value = {**SAMPLE_DETAILS, "ingredients": [], "allergens": [],
                                     "ingredient_statements": {"ar": "ماء، سكر"}}
        response = authenticated_client.post(
            ENDPOINT, json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []})
        assert response.json()["status"] == "SAFE"

    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_no_statement_and_no_allergens_is_still_insufficient(self, mock_details, authenticated_client):
        mock_details.return_value = {**SAMPLE_DETAILS, "ingredients": [], "allergens": [],
                                     "nutrition": [{"nutrition_type": "SUGAR", "amount_value": 1, "unit": "G",
                                                    "confidence_level": 0.5}]}
        response = authenticated_client.post(
            ENDPOINT, json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []})
        assert response.json()["status"] == "INSUFFICIENT_DATA"


class TestAllergenNamedByTheProduct:
    """A product's name is positive evidence of what it is made of, even when
    the source's ingredient list is missing or incomplete (seen: a whole milk
    whose only statement was "Vitamins, sodium fluoride added")."""

    MILK_DETAILS = {
        **SAMPLE_DETAILS,
        "name": "سعودية حليب كامل الدسم",
        "name_ar": "سعودية حليب كامل الدسم",
        "name_en": "Saudia whole milk",
        "ingredients": [],
        "allergens": [],
        "ingredient_statements": {"en": "Vitamins, sodium fluoride added"},
    }

    @patch("app.services.allergen_mapping.live_allergen_codes", return_value=frozenset({"MILK", "PEANUT"}))
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_milk_named_product_is_danger_for_milk_allergy(self, mock_details, _codes, authenticated_client):
        mock_details.return_value = self.MILK_DETAILS
        response = authenticated_client.post(
            ENDPOINT, json={"allergies": [{"tag": "en:milk", "severity": "شديد"}], "diseases": []})
        body = response.json()
        assert body["status"] == "DANGER"
        assert body["matched_allergens"][0]["evidence_type"] == "PRODUCT_NAME"

    @patch("app.services.allergen_mapping.live_allergen_codes", return_value=frozenset({"MILK", "PEANUT"}))
    @patch("app.services.compatibility_service.get_product_details_by_barcode")
    def test_name_without_data_is_not_evidence_of_absence(self, mock_details, _codes, authenticated_client):
        mock_details.return_value = {**self.MILK_DETAILS, "ingredient_statements": {}, "nutrition": []}
        response = authenticated_client.post(
            ENDPOINT, json={"allergies": [{"tag": "en:peanuts", "severity": "شديد"}], "diseases": []})
        assert response.json()["status"] == "INSUFFICIENT_DATA"
