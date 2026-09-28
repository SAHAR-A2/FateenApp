"""Review queue over public.product_completeness (migration 0054)."""
from unittest.mock import patch

import psycopg
import pytest

from app.public_gateway import is_public


@pytest.mark.integration
class TestReviewQueueAgainstFixtureDb:
    def test_summary_counts_every_live_product(self, client, db_conn):
        live = db_conn.execute(
            "SELECT COUNT(*) AS n FROM public.products WHERE deleted_at IS NULL"
        ).fetchone()["n"]
        data = client.get("/api/v1/review/summary").json()
        assert data["products"] == live
        assert set(data["missing_by_field"]) == {
            "barcode", "name_ar", "name_en", "ingredients",
            "allergen_evidence", "nutrition", "image",
        }

    def test_nutrition_filter_matches_the_data(self, client, db_conn):
        expected = db_conn.execute(
            """
            SELECT COUNT(*) AS n FROM public.products p
            WHERE p.deleted_at IS NULL AND NOT EXISTS (
                SELECT 1 FROM public.product_nutrition_values v
                WHERE v.product_id = p.id AND v.deleted_at IS NULL)
            """
        ).fetchone()["n"]
        data = client.get("/api/v1/review/products", params={"missing": "nutrition"}).json()
        assert data["total"] == expected
        assert all("nutrition" in item["missing_fields"] for item in data["items"])

    def test_product_with_nutrition_is_not_listed_as_missing_it(self, client):
        data = client.get(
            "/api/v1/review/products", params={"missing": "nutrition", "limit": 200}
        ).json()
        assert "FATEEN_MILK_TEST" not in {i["internal_code"] for i in data["items"]}

    def test_allergen_evidence_rule_matches_compatibility(self, db_conn):
        """allergen_evidence is missing exactly when there are no ingredients
        and no allergen rows -- the INSUFFICIENT_DATA rule."""
        rows = db_conn.execute(
            "SELECT has_ingredients, has_allergens, missing_fields FROM public.product_completeness"
        ).fetchall()
        for r in rows:
            assert ("allergen_evidence" in r["missing_fields"]) == (
                not (r["has_ingredients"] or r["has_allergens"])
            )


def test_unknown_missing_field_is_rejected(client):
    assert client.get("/api/v1/review/products", params={"missing": "colour"}).status_code == 422


@patch("app.api.review.completeness_summary", side_effect=psycopg.errors.UndefinedTable())
def test_missing_view_is_explained(_summary, client):
    response = client.get("/api/v1/review/summary")
    assert response.status_code == 503
    assert "0054" in response.json()["detail"]


def test_review_queue_is_not_public():
    assert not is_public("GET", "/api/v1/review/summary")
    assert not is_public("GET", "/api/v1/review/products")


def test_review_requires_api_key_when_configured(client, monkeypatch):
    from app.core.config import settings

    monkeypatch.setattr(settings, "agent_ingest_api_key", "secret")
    assert client.get("/api/v1/review/summary").status_code == 401
