"""
Fix 3 (FATEEN Architecture Audit): POST /api/v1/scan/discover/{company_id}
must accept an optional, validated raw_data payload without breaking
existing callers that never send one, and without ever passing an
un-serialized dict into a jsonb column.

All DB access is mocked -- these tests never touch a real database.
"""
import json
import os
from unittest.mock import patch, MagicMock

os.environ.setdefault("AGENT_INGEST_API_KEY", "test-key")

from fastapi.testclient import TestClient
from app.main import app
from app.repositories.discovery_repository import create_candidate, update_candidate

client = TestClient(app)
HEADERS = {"X-Agent-API-Key": os.environ["AGENT_INGEST_API_KEY"]}
URL = "/api/v1/scan/discover/company-1?name=TestProduct&barcode=6281000000099"


class TestDiscoverEndpointBackwardCompatibility:
    @patch("app.api.scan.create_candidate", return_value="cand-1")
    def test_no_body_still_works_exactly_as_before(self, mock_create):
        resp = client.post(URL, headers=HEADERS)
        assert resp.status_code == 201
        assert resp.json()["raw_data_attached"] is False
        assert mock_create.call_args.kwargs.get("raw_data") is None


class TestDiscoverEndpointAcceptsRawData:
    @patch("app.api.scan.create_candidate", return_value="cand-2")
    def test_valid_raw_data_is_parsed_and_forwarded(self, mock_create):
        payload = {
            "raw_data": {
                "ingredients": [
                    {"name": "SUGAR", "amount_value": 10.0, "unit": "g", "confidence_level": 0.9}
                ],
                "allergens": [{"name": "MILK", "confidence_level": 0.8}],
                "nutrition": [
                    {"nutrition_type": "energy", "amount_value": 250.0, "unit": "kcal"}
                ],
            }
        }
        resp = client.post(URL, json=payload, headers=HEADERS)
        assert resp.status_code == 201
        assert resp.json()["raw_data_attached"] is True
        forwarded = mock_create.call_args.kwargs.get("raw_data")
        assert forwarded["ingredients"][0]["name"] == "SUGAR"
        assert forwarded["allergens"][0]["name"] == "MILK"
        assert forwarded["nutrition"][0]["nutrition_type"] == "energy"

    @patch("app.api.scan.create_candidate", return_value="cand-3")
    def test_confidence_out_of_range_is_rejected(self, mock_create):
        payload = {"raw_data": {"ingredients": [{"name": "X", "confidence_level": 5.0}]}}
        resp = client.post(URL, json=payload, headers=HEADERS)
        assert resp.status_code == 422
        assert not mock_create.called

    @patch("app.api.scan.create_candidate", return_value="cand-4")
    def test_negative_amount_is_rejected(self, mock_create):
        payload = {
            "raw_data": {
                "nutrition": [{"nutrition_type": "energy", "amount_value": -5, "unit": "kcal"}]
            }
        }
        resp = client.post(URL, json=payload, headers=HEADERS)
        assert resp.status_code == 422
        assert not mock_create.called


class TestRawDataJsonSerialization:
    """The pre-existing bug this fix depends on: psycopg3 does not
    auto-adapt a plain dict to jsonb, so raw_data must be json.dumps()'d
    before it reaches conn.execute(). Without this, every real call would
    raise at the database layer the first time raw_data was non-None."""

    def _mock_conn(self):
        conn = MagicMock()
        conn.__enter__ = MagicMock(return_value=conn)
        conn.__exit__ = MagicMock(return_value=False)
        return conn

    def test_create_candidate_serializes_raw_data_to_json_string(self):
        conn = self._mock_conn()
        with patch("app.repositories.discovery_repository.get_connection", return_value=conn):
            create_candidate(
                company_id="c1", name="P", raw_data={"ingredients": [{"name": "SUGAR"}]}
            )
        params = conn.execute.call_args.args[1]
        raw_data_param = params[-2]
        assert isinstance(raw_data_param, str)
        assert json.loads(raw_data_param) == {"ingredients": [{"name": "SUGAR"}]}

    def test_update_candidate_serializes_raw_data_to_json_string(self):
        conn = self._mock_conn()
        with patch("app.repositories.discovery_repository.get_connection", return_value=conn):
            update_candidate("cand-1", raw_data={"allergens": [{"name": "MILK"}]})
        params = conn.execute.call_args.args[1]
        assert isinstance(params[0], str)
        assert json.loads(params[0]) == {"allergens": [{"name": "MILK"}]}

    def test_create_candidate_handles_none_raw_data(self):
        conn = self._mock_conn()
        with patch("app.repositories.discovery_repository.get_connection", return_value=conn):
            create_candidate(company_id="c1", name="P")
        params = conn.execute.call_args.args[1]
        assert params[-2] is None
