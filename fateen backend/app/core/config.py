import logging
from urllib.parse import urlparse

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger("fateen.core.config")

# DB roles that a live backend process must NEVER authenticate as.
# `fateen` is the emergency/superuser role per the FATEEN role model
# (fateen = superuser, fateen_admin = DDL/migrations, fateen_app = runtime).
_FORBIDDEN_RUNTIME_DB_USERS = {"fateen", "postgres"}


class Settings(BaseSettings):
    database_url: str
    app_env: str = "development"
    app_name: str = "Fateen Backend"
    agent_dry_run: bool = True
    agent_ingest_api_key: str = ""

    cors_allowed_origins: str = "http://localhost:3000,http://localhost:8000"

    llm_provider: str = "openai"
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-3-haiku-20240307"
    ollama_model: str = "llama3.2"
    llm_timeout: float = 30.0

    # Client-level retry/backoff for the LLM provider (hardened bounded
    # behavior: 429 / 5xx / timeout / connection errors are retried a
    # bounded number of times with exponential backoff that honors a
    # Retry-After header when present; permanent 4xx errors never retry).
    # max_retries is the number of RETRIES *after* the first attempt, so
    # total attempts == llm_max_retries + 1; the loop can never spin
    # unboundedly and total worst-case wait is bounded by backoff_max.
    llm_max_retries: int = 2
    llm_retry_backoff_base: float = 2.0
    llm_retry_backoff_max: float = 30.0

    # Gemini: used for structured data EXTRACTION ONLY. Blocked by design
    # from every health/safety decision (see FATEEN extraction boundary).
    gemini_api_key: str = ""
    gemini_model: str = "gemini-3.6-flash"
    gemini_timeout: float = 30.0

    # Groq: OpenAI-compatible endpoint. Set LLM_PROVIDER=groq to use it.
    groq_api_key: str = ""
    groq_model: str = "llama-3.1-8b-instant"

    # Web Discovery: pluggable source-URL discovery. Default "none" is a
    # no-op that fabricates nothing. "static" reads WEB_DISCOVERY_STATIC_URLS.
    web_discovery_provider: str = "none"
    web_discovery_static_urls: str = ""
    web_discovery_max_results: int = 10

    # Collector auto-extraction: when True, the orchestrator fetches a
    # candidate's source_url through the SSRF-safe retrieval module and runs
    # retrieval -> LLM -> extract_from_llm_response before validation.
    # Default False keeps the previous (manual raw_data) behavior.
    collector_auto_extraction: bool = False

    db_pool_min_size: int = 2
    db_pool_max_size: int = 20
    db_pool_acquire_timeout: float = 30.0
    db_pool_check: float = 60.0

    # SFDA Registered Food Products API (official regulatory source).
    # Three official mechanisms exist:
    #   - Registered Food Service (developer portal, OAuth2 client credentials
    #     -> 24h bearer token): set SFDA_CONSUMER_KEY + SFDA_CONSUMER_SECRET
    #     and the portal's exact token URL in SFDA_OAUTH_TOKEN_URL.
    #   - Pre-minted bearer token (already-obtained 24h token): set
    #     SFDA_ACCESS_TOKEN (used as-is when present).
    #   - FIRS open-data web services (documented `/v2/FIRS/food/list` and
    #     `/v2/FIRS/food/search`), API-key based: set SFDA_API_KEY.
    # Never commit a real credential; configure via env / .env only. An empty
    # SFDA_* value means the related client raises before any network call.
    # The OAuth token URL is deliberately NOT guessed/hardcoded: it must come
    # from the developer portal's Authentication/Tokens documentation
    # (SFDA_OAUTH_TOKEN_URL); without it the adapter refuses to send anything.
    sfda_consumer_key: str = ""
    sfda_consumer_secret: str = ""
    sfda_oauth_token_url: str = ""
    sfda_oauth_scope: str = ""
    sfda_access_token: str = ""
    sfda_api_key: str = ""
    sfda_api_key_header: str = "X-API-Key"
    sfda_base_url: str = "https://apis.sfda.gov.sa:9002"
    sfda_products_path: str = "/v2/Food"
    sfda_firs_path: str = "/v2/FIRS/food"
    sfda_timeout: float = 30.0

    @model_validator(mode="after")
    def validate_production_config(self):
        if self.app_env == "production":
            errors = []
            if not self.agent_ingest_api_key:
                errors.append(
                    "AGENT_INGEST_API_KEY must be set in production"
                )
            if self.cors_allowed_origins in ("*", ""):
                errors.append(
                    "CORS_ALLOWED_ORIGINS must be set to explicit origins in production"
                )
            db_user = (urlparse(self.database_url).username or "").lower()
            if db_user in _FORBIDDEN_RUNTIME_DB_USERS:
                errors.append(
                    f"DATABASE_URL must not authenticate as the superuser "
                    f"role '{db_user}' in production; use the least-privilege "
                    f"'fateen_app' runtime role instead"
                )
            if errors:
                for e in errors:
                    logger.error("PRODUCTION CONFIG ERROR: %s", e)
                raise ValueError(
                    "Invalid production configuration: "
                    + "; ".join(errors)
                )
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        return [
            o.strip()
            for o in self.cors_allowed_origins.split(",")
            if o.strip()
        ]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()


def resolve_effective_dry_run(request_dry_run: bool, env_dry_run: bool | None = None) -> bool:
    """
    Single authoritative dry-run safety contract for FATEEN.

    SAFETY RULE (non-negotiable — see release remediation spec):
        effective_dry_run = env_dry_run OR request_dry_run

    Either the environment-level AGENT_DRY_RUN switch or the per-request
    `dry_run` flag is sufficient to force a dry run (no DB mutation).
    A real write is permitted ONLY when BOTH agree that writes are safe
    (both are False). Neither the caller nor the environment can
    unilaterally force a write against the other's wishes.

    This is intentionally the ONLY place this decision is computed.
    Every write-capable entry point (POST /api/v1/agent/ingest,
    POST /api/v1/scan/start, and any future one) MUST call this
    function instead of re-implementing the boolean logic inline —
    that duplication is exactly what caused the previous release's
    two CRITICAL dry-run bypass defects (C1, C2).

    Args:
        request_dry_run: the `dry_run` flag supplied by the caller in
            the HTTP request body (or equivalent).
        env_dry_run: override for testing; defaults to the live
            `settings.agent_dry_run` value.

    Returns:
        True  -> caller MUST NOT perform any database mutation.
        False -> a real write is permitted (both env and request agreed).
    """
    if env_dry_run is None:
        env_dry_run = settings.agent_dry_run
    return bool(env_dry_run) or bool(request_dry_run)
