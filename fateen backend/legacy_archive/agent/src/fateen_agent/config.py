"""Application configuration loaded from environment / .env."""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Fateen Data Agent settings. Secrets come from environment / .env only."""

    model_config = SettingsConfigDict(
        env_prefix="FATEEN_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    # --- run mode --------------------------------------------------------
    dry_run: bool = Field(default=True, alias="FATEEN_AGENT_DRY_RUN")
    live_web: bool = Field(default=True, alias="FATEEN_LIVE_WEB")
    batch_size: int = Field(default=10, alias="FATEEN_AGENT_BATCH_SIZE")
    workers: int = Field(default=1, alias="FATEEN_AGENT_WORKERS")
    skip_processed: bool = Field(default=True, alias="FATEEN_AGENT_SKIP_PROCESSED")
    fixture_path: str = Field(default="", alias="FATEEN_FIXTURE_PATH")

    # --- database ---------------------------------------------------------
    db_host: str = Field(default="localhost", alias="FATEEN_DB_HOST")
    db_port: int = Field(default=5432, alias="FATEEN_DB_PORT")
    db_name: str = Field(default="fateen_agent_dev", alias="FATEEN_DB_NAME")
    db_user: str = Field(default="fateen", alias="FATEEN_DB_USER")
    db_password: str = Field(default="", alias="FATEEN_DB_PASSWORD")
    db_sslmode: str = Field(default="prefer", alias="FATEEN_DB_SSLMODE")

    # --- http / web --------------------------------------------------------
    http_timeout: float = Field(default=20.0, alias="FATEEN_HTTP_TIMEOUT")
    http_retries: int = Field(default=3, alias="FATEEN_HTTP_RETRIES")
    web_search_provider: str = Field(default="", alias="FATEEN_WEB_SEARCH_PROVIDER")
    web_search_api_key: str = Field(default="", alias="FATEEN_WEB_SEARCH_API_KEY")

    # --- llm (optional) -----------------------------------------------------
    llm_provider: str = Field(default="", alias="FATEEN_LLM_PROVIDER")
    llm_api_key: str = Field(default="", alias="FATEEN_LLM_API_KEY")
    llm_base_url: str = Field(default="", alias="FATEEN_LLM_BASE_URL")
    llm_model: str = Field(default="", alias="FATEEN_LLM_MODEL")
    llm_max_tokens: int = Field(default=4000, alias="FATEEN_LLM_MAX_TOKENS")

    @property
    def dsn(self) -> str:
        """PostgreSQL connection string."""
        return (
            f"postgresql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
            f"?sslmode={self.db_sslmode}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
