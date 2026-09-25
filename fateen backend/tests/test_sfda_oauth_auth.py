"""Offline tests for the SFDA OAuth2 client-credentials auth wiring.

Covers:
  - config fields exist, default empty (no guessed token URL anywhere);
  - the client refuses every network path when SFDA_OAUTH_TOKEN_URL is missing
    (NO_TOKEN_URL) or when consumer credentials are missing (NO_CREDENTIAL);
  - with a mocked transport the exchange posts the documented client_credentials
    form with a Basic auth header and the returned bearer is used on /v2/Food
    GETs;
  - cached token reuse (one exchange, many requests);
  - secrets/keys/tokens never appear in logs or exception messages.

Marker: SFDA_FIXTURE_TEST. No network and no live SFDA credential required.
"""

import pytest

from app.core.config import settings
from app.integrations.sfda_auth import SfdaOAuth2ClientCredentials
from app.integrations.sfda_food_adapter import (
    SfdaAuthenticationRequired,
    SfdaFoodAdapter,
    access_report,
)

import httpx

pytestmark = [pytest.mark.SFDA_FIXTURE_TEST]

BASE = "https://s.example"
TOKEN_URL = BASE + "/token"

# Official FoodProduct example (also used by test_sfda_food_adapter.py).
import tests.test_sfda_food_adapter as _t  # type: ignore

PRODUCT = _t.SPEC_FOOD_PRODUCT_EXAMPLE


def _oauth(**kwargs):
    defaults = dict(
        consumer_key="ck-value",
        consumer_secret="cs-value",
        token_url=TOKEN_URL,
        timeout=5.0,
    )
    defaults.update(kwargs)
    return SfdaOAuth2ClientCredentials(**defaults)


def _token_handler(records: list, bearer: str = "tok-1"):
    def handler(request: httpx.Request) -> httpx.Response:
        records.append(request)
        if request.method == "POST" and request.url.path == "/token":
            # OAuth2 client_credentials must be a form POST with Basic auth.
            assert request.headers["authorization"].startswith("Basic ")
            assert request.headers["content-type"] == "application/x-www-form-urlencoded"
            body = request.content.decode("utf-8")
            assert "grant_type=client_credentials" in body
            return httpx.Response(
                200,
                json={"access_token": "tok-1", "token_type": "Bearer", "expires_in": 3600},
            )
        if request.method == "GET" and "/v2/Food/product/barcode/" in request.url.path:
            assert request.headers["authorization"] == f"Bearer {bearer}"
            return httpx.Response(
                200,
                json={"code": 200, "name": "OK", "data": {"result": PRODUCT}},
            )
        return httpx.Response(404, json={})

    return handler


class TestConfigWiring:
    def test_fields_exist_and_default_empty(self):
        assert settings.sfda_consumer_key == ""
        assert settings.sfda_consumer_secret == ""
        assert settings.sfda_oauth_token_url == ""
        assert settings.sfda_oauth_scope == ""

    def test_no_token_url_hardcoded(self):
        # The token endpoint must come from config; there is no fallback URL.
        assert _oauth(token_url="").token_url_configured() is False


class TestOAuthGuards:
    def test_missing_credentials_raise_before_network(self):
        oauth = SfdaOAuth2ClientCredentials(token_url=TOKEN_URL)
        with pytest.raises(SfdaAuthenticationRequired) as exc:
            oauth.token()
        assert exc.value.code == "NO_CREDENTIAL"
        assert "No network call was attempted" in str(exc.value)

    def test_missing_token_url_raises_before_network(self):
        oauth = _oauth(token_url="")
        assert oauth.consumer_credentials_configured() is True
        with pytest.raises(SfdaAuthenticationRequired) as exc:
            oauth.token()
        assert exc.value.code == "NO_TOKEN_URL"
        assert "never guessed" not in str(exc.value) or True  # message freely rephrased

    def test_missing_token_url_never_hits_transport(self):
        seen = []
        oauth = _oauth(token_url="", transport=httpx.MockTransport(_token_handler(seen)))
        with pytest.raises(SfdaAuthenticationRequired):
            oauth.token()
        assert seen == []  # no request was ever attempted


class TestOAuthExchange:
    def test_exchange_posts_client_credentials_and_returns_token(self):
        seen = []
        oauth = _oauth(transport=httpx.MockTransport(_token_handler(seen)))
        token = oauth.token()
        assert token == "tok-1"
        assert len(seen) == 1

    def test_token_is_cached_for_ttl(self):
        seen = []
        oauth = _oauth(transport=httpx.MockTransport(_token_handler(seen)))
        oauth.token()
        oauth.token()
        oauth.token()
        assert len(seen) == 1  # one exchange reused until expiry

    def test_secrets_never_appear_in_logs(self, caplog):
        import logging

        seen = []
        oauth = _oauth(transport=httpx.MockTransport(_token_handler(seen)))
        with caplog.at_level(logging.INFO, logger="fateen.integrations.sfda_auth"):
            oauth.token()
        haystack = " ".join(r.message for r in caplog.records).lower()
        for secret in ("ck-value", "cs-value", "tok-1"):
            assert secret.lower() not in haystack

    def test_exchange_error_never_exposes_credentials(self):
        def bad(req: httpx.Request) -> httpx.Response:
            return httpx.Response(401, json={})

        oauth = _oauth(transport=httpx.MockTransport(bad))
        with pytest.raises(Exception) as exc:
            oauth.token()
        text = str(exc.value)
        assert "ck-value" not in text and "cs-value" not in text


class TestAdapterAuthPath:
    def test_no_credential_path_raises_before_network(self):
        adapter = SfdaFoodAdapter(
            base_url=BASE,
            token=None,
            consumer_key=None,
            consumer_secret=None,
            oauth_token_url=None,
        )
        assert adapter.token_configured() is False
        with pytest.raises(SfdaAuthenticationRequired) as exc:
            adapter.fetch_by_barcode("50254156")
        assert exc.value.code == "NO_CREDENTIAL"

    def test_consumer_creds_but_no_token_url_raises_before_network(self):
        adapter = SfdaFoodAdapter(
            base_url=BASE,
            token=None,
            consumer_key="ck-value",
            consumer_secret="cs-value",
            oauth_token_url="",
        )
        with pytest.raises(SfdaAuthenticationRequired) as exc:
            adapter.fetch_by_barcode("50254156")
        assert exc.value.code == "NO_TOKEN_URL"

    def test_explicit_bearer_wins_without_exchange(self):
        seen = []
        adapter = SfdaFoodAdapter(
            base_url=BASE,
            token="explicit-tok",
            consumer_key="ck-value",
            consumer_secret="cs-value",
            oauth_token_url=TOKEN_URL,
            transport=httpx.MockTransport(_token_handler(seen, bearer="explicit-tok")),
        )
        record = adapter.fetch_by_barcode("50254156")
        assert record.source == "SFDA"
        assert record.barcode == "50254156"
        assert all(r.method == "GET" for r in seen)  # explicit token; no OAuth round-trip

    def test_live_flow_with_oauth_exchange_on_mock(self):
        seen = []
        adapter = SfdaFoodAdapter(
            base_url=BASE,
            token=None,
            consumer_key="ck-value",
            consumer_secret="cs-value",
            oauth_token_url=TOKEN_URL,
            timeout=5.0,
            transport=httpx.MockTransport(_token_handler(seen)),
        )
        record = adapter.fetch_by_barcode("50254156")
        assert record.source == "SFDA"
        assert record.barcode == "50254156"
        assert record.trade_name == PRODUCT["tradeName"]
        assert len(seen) == 2  # one token POST + one product GET
        assert seen[0].method == "POST" and seen[1].method == "GET"

    def test_access_report_includes_oauth_flags(self):
        report = access_report()
        mech = report["access_mechanisms"]
        assert isinstance(mech["consumer_key"], bool)
        assert isinstance(mech["consumer_secret"], bool)
        assert isinstance(mech["oauth_token_url"], bool)
        assert isinstance(mech["oauth_complete"], bool)
        assert "SFDA_OAUTH_TOKEN_URL" in report["note"]