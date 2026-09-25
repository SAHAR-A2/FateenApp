"""OAuth2 client-credentials authentication for the SFDA developer portal.

The SFDA "Food Enabled" subscription issues Consumer Key + Consumer Secret
(client credentials). The Registered Food Products API requires a 24h bearer
token obtained by exchanging those credentials:

    POST <SFDA_OAUTH_TOKEN_URL>          (grant_type=client_credentials)
    Authorization: Basic base64(key:secret)
    -> { access_token, expires_in, ... }
    Authorization: Bearer <access_token> on every /v2/Food call

The exact token endpoint is NOT hardcoded here and is NOT guessed: it must be
provided via SFDA_OAUTH_TOKEN_URL from the developer portal's
Authentication/Tokens documentation. Until that value is configured this
module refuses to send any request (SfdaAuthenticationRequired code
NO_TOKEN_URL), which is the documented-missing-endpoint guard.

Credentials are never logged, printed or embedded in exception messages.
"""
import base64
import logging
import time
from typing import Optional

import httpx

from app.integrations.sfda_food_adapter import (
    SfdaAdapterError,
    SfdaAuthenticationRequired,
    SfdaHttpError,
    SfdaUnreachable,
)

logger = logging.getLogger("fateen.integrations.sfda_auth")


class SfdaOAuth2ClientCredentials:
    """Client-credentials grant producing a cached bearer token.

    Guarantees (all enforced offline where possible):
      - no request is ever sent without BOTH consumer credentials AND an
        explicitly configured token URL;
      - the key/secret/token never appear in logs or exception messages;
      - the token is cached for min(expires_in, 24h) per the documented
        lifetime, so one exchange is reused across a run.
    """

    GRANT_TYPE = "client_credentials"
    MAX_TOKEN_TTL_SECONDS = 24 * 3600

    def __init__(
        self,
        consumer_key: str = "",
        consumer_secret: str = "",
        token_url: str = "",
        scope: str = "",
        timeout: Optional[float] = None,
        transport: Optional[httpx.BaseTransport] = None,
    ) -> None:
        self._consumer_key = consumer_key or ""
        self._consumer_secret = consumer_secret or ""
        self._token_url = (token_url or "").strip()
        self._scope = (scope or "").strip()
        self.timeout = timeout if timeout is not None else 30.0
        self._transport = transport
        self._token: Optional[str] = None
        self._expires_at: float = 0.0

    # -- presence ONLY (values never exposed) -------------------------------

    def consumer_credentials_configured(self) -> bool:
        return bool(self._consumer_key.strip()) and bool(self._consumer_secret.strip())

    def token_url_configured(self) -> bool:
        return bool(self._token_url)

    # -- guards -------------------------------------------------------------

    def require_token_url(self) -> str:
        if not self._token_url:
            raise SfdaAuthenticationRequired(
                "SFDA OAuth token URL is not configured (SFDA_OAUTH_TOKEN_URL). "
                "The Registered Food Products / Food Enabled subscription "
                "authenticates via OAuth2 client_credentials, but the exact "
                "token endpoint must be taken from the developer portal's "
                "Authentication/Tokens documentation - it is NOT guessed here. "
                "No network call was attempted.",
                code="NO_TOKEN_URL",
            )
        return self._token_url

    def require_credentials(self) -> tuple[str, str]:
        if not self.consumer_credentials_configured():
            raise SfdaAuthenticationRequired(
                "SFDA consumer credentials are not configured "
                "(SFDA_CONSUMER_KEY + SFDA_CONSUMER_SECRET). No network call "
                "was attempted.",
                code="NO_CREDENTIAL",
            )
        return self._consumer_key, self._consumer_secret

    # -- exchange -----------------------------------------------------------

    def token(self) -> str:
        """Return a usable bearer token, acquiring/caching one as needed."""
        if self._token and time.monotonic() < self._expires_at:
            return self._token
        token, ttl = self._exchange()
        self._token = token
        self._expires_at = time.monotonic() + ttl
        return token

    def _exchange(self) -> tuple[str, int]:
        key, secret = self.require_credentials()  # raises NO_CREDENTIAL first
        self.require_token_url()  # raises NO_TOKEN_URL before any request
        auth_value = base64.b64encode(f"{key}:{secret}".encode("utf-8")).decode("ascii")
        form = {"grant_type": self.GRANT_TYPE}
        if self._scope:
            form["scope"] = self._scope
        headers = {
            "Authorization": f"Basic {auth_value}",
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "Fateen-SFDA-Adapter/0.1",
        }
        try:
            transport = self._transport
            if transport is not None:
                with httpx.Client(transport=transport, timeout=self.timeout) as client:
                    response = client.post(self._token_url, headers=headers, data=form)
            else:
                with httpx.Client(timeout=self.timeout) as client:
                    response = client.post(self._token_url, headers=headers, data=form)
        except httpx.TimeoutException as exc:
            raise SfdaUnreachable(
                f"SFDA OAuth token exchange timed out: {exc}", code="TIMEOUT"
            ) from exc
        except httpx.TransportError as exc:
            raise SfdaUnreachable(
                f"SFDA OAuth token endpoint unreachable: {exc}", code="TRANSPORT"
            ) from exc

        if response.status_code >= 400:
            raise SfdaHttpError(
                f"SFDA OAuth token exchange failed with HTTP {response.status_code}",
                status_code=response.status_code,
                code=f"TOKEN_HTTP_{response.status_code}",
            )

        try:
            body = response.json()
        except ValueError as exc:
            raise SfdaAdapterError(
                "SFDA OAuth token response is not JSON", code="TOKEN_MALFORMED"
            ) from exc
        if not isinstance(body, dict):
            raise SfdaAdapterError(
                "SFDA OAuth token response is not a JSON object", code="TOKEN_MALFORMED"
            )
        access_token = body.get("access_token")
        if not isinstance(access_token, str) or not access_token:
            raise SfdaAdapterError(
                "SFDA OAuth token response has no access_token", code="TOKEN_MALFORMED"
            )
        expires_in = int(body.get("expires_in") or self.MAX_TOKEN_TTL_SECONDS)
        ttl = max(60, min(int(expires_in), self.MAX_TOKEN_TTL_SECONDS))
        logger.info(
            "SFDA OAuth token acquired (cached %ss; the value itself is never logged)",
            ttl,
        )
        return access_token, ttl