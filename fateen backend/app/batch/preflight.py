"""STEP I: credential handoff readiness / preflight (never prints secrets).

Reports ONLY presence flags:
    credential configured = YES/NO

Never logs, prints, or returns the credential value.
"""
import logging

from app.batch.models import utcnow
from app.integrations.sfda_food_adapter import SfdaFoodAdapter

logger = logging.getLogger("fateen.batch.preflight")


def check_credentials() -> dict:
    """Read-only credential presence report (values are never exposed)."""
    adapter = SfdaFoodAdapter()
    mechanisms = adapter.access_configured()  # bearer_token / firs_api_key / oauth
    complete = (
        mechanisms["bearer_token"]
        or mechanisms["firs_api_key"]
        or mechanisms["oauth_complete"]
    )
    if mechanisms["bearer_token"]:
        mechanism = "SFDA_ACCESS_TOKEN (pre-minted bearer)"
    elif mechanisms["firs_api_key"]:
        mechanism = "SFDA_API_KEY (FIRS)"
    elif mechanisms["oauth_complete"]:
        mechanism = "SFDA_CONSUMER_KEY + SFDA_CONSUMER_SECRET (OAuth2 client credentials)"
    else:
        mechanism = None
    return {
        "credential_configured": "YES" if complete else "NO",
        "bearer_token_configured": mechanisms["bearer_token"],
        "firs_api_key_configured": mechanisms["firs_api_key"],
        "consumer_key_configured": mechanisms["consumer_key"],
        "consumer_secret_configured": mechanisms["consumer_secret"],
        "oauth_token_url_configured": mechanisms["oauth_token_url"],
        "oauth_complete": mechanisms["oauth_complete"],
        "mechanism": mechanism,
        "note": (
            "configure credentials ONLY via environment / .env (pre-minted "
            "SFDA_ACCESS_TOKEN, FIRS SFDA_API_KEY, or OAuth2 "
            "SFDA_CONSUMER_KEY + SFDA_CONSUMER_SECRET + SFDA_OAUTH_TOKEN_URL); "
            "values are never printed."
        ),
        "checked_at": utcnow(),
    }


def assert_credential_for_live() -> dict:
    """Raises before ANY network call when a live run has no credential."""
    report = check_credentials()
    if report["credential_configured"] != "YES":
        from app.integrations.sfda_food_adapter import SfdaAuthenticationRequired

        raise SfdaAuthenticationRequired(
            "live SFDA run requires a completed credential path "
            "(SFDA_ACCESS_TOKEN bearer, SFDA_API_KEY FIRS key, or "
            "SFDA_CONSUMER_KEY + SFDA_CONSUMER_SECRET + SFDA_OAUTH_TOKEN_URL). "
            "No network call was attempted and noting was ingested. "
            "Configure via env/.env only.",
            code="NO_CREDENTIAL",
        )
    return report