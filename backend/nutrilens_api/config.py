"""Runtime settings, read once from environment variables.

Nothing here is a secret except DB_PASSWORD, which Cloud Run injects from
Secret Manager. No model API keys exist: Vertex AI is reached through the
service account's credentials.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

from psycopg.conninfo import make_conninfo


class ConfigError(RuntimeError):
    """Raised when a required environment variable is missing or malformed."""


def _required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ConfigError(f"missing required environment variable {name}")
    return value


def _int(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError as exc:
        raise ConfigError(f"{name} must be an integer") from exc


def _float(name: str, default: float) -> float:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        return float(raw)
    except ValueError as exc:
        raise ConfigError(f"{name} must be a number") from exc


def _optional_float(name: str) -> float | None:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError as exc:
        raise ConfigError(f"{name} must be a number") from exc


@dataclass(frozen=True)
class Settings:
    firebase_project_id: str
    gcp_project: str
    gcp_location: str = "global"
    # Model IDs taken from the Vertex AI "model versions" page on 2026-11-19.
    # Each has a published retirement date; re-check before relying on them.
    generation_model: str = "gemini-3.8-flash"
    fallback_model: str = "gemini-3.5-flash-lite"
    embedding_model: str = "gemini-embedding-001"
    embedding_dim: int = 768
    db_host: str = ""
    db_name: str = "nutrilens"
    db_user: str = "nutrilens_app"
    db_password: str = ""
    max_label_chars: int = 6000
    max_image_bytes: int = 8 * 1024 * 1024
    rate_limit_per_minute: int = 20
    retrieval_top_k: int = 8
    retrieval_max_context: int = 10
    # Untuned cut-off on cosine distance. It must be tuned on the eval set.
    retrieval_max_distance: float = 0.5
    # Prices are supplied by the operator from the current published price
    # list. They are never hard-coded, so cost is reported only when set.
    price_input_per_mtok: float | None = None
    price_output_per_mtok: float | None = None

    @classmethod
    def from_env(cls) -> Settings:
        defaults = cls(firebase_project_id="x", gcp_project="x")
        return cls(
            firebase_project_id=_required("FIREBASE_PROJECT_ID"),
            gcp_project=_required("GOOGLE_CLOUD_PROJECT"),
            gcp_location=os.environ.get("GOOGLE_CLOUD_LOCATION", defaults.gcp_location),
            generation_model=os.environ.get("GENERATION_MODEL", defaults.generation_model),
            fallback_model=os.environ.get("FALLBACK_MODEL", defaults.fallback_model),
            embedding_model=os.environ.get("EMBEDDING_MODEL", defaults.embedding_model),
            embedding_dim=_int("EMBEDDING_DIM", defaults.embedding_dim),
            db_host=os.environ.get("DB_HOST", ""),
            db_name=os.environ.get("DB_NAME", defaults.db_name),
            db_user=os.environ.get("DB_USER", defaults.db_user),
            db_password=os.environ.get("DB_PASSWORD", ""),
            max_label_chars=_int("MAX_LABEL_CHARS", defaults.max_label_chars),
            max_image_bytes=_int("MAX_IMAGE_BYTES", defaults.max_image_bytes),
            rate_limit_per_minute=_int("RATE_LIMIT_PER_MINUTE", defaults.rate_limit_per_minute),
            retrieval_top_k=_int("RETRIEVAL_TOP_K", defaults.retrieval_top_k),
            retrieval_max_context=_int("RETRIEVAL_MAX_CONTEXT", defaults.retrieval_max_context),
            retrieval_max_distance=_float(
                "RETRIEVAL_MAX_DISTANCE", defaults.retrieval_max_distance
            ),
            price_input_per_mtok=_optional_float("PRICE_INPUT_PER_MTOK"),
            price_output_per_mtok=_optional_float("PRICE_OUTPUT_PER_MTOK"),
        )

    def db_conninfo(self) -> str:
        """Connection string. A host starting with '/' is a Unix socket
        directory, which is how Cloud Run reaches Cloud SQL."""
        if not self.db_host:
            raise ConfigError("DB_HOST is not set")
        return make_conninfo(
            host=self.db_host,
            dbname=self.db_name,
            user=self.db_user,
            password=self.db_password,
        )

    def estimate_cost(self, input_tokens: int, output_tokens: int) -> float | None:
        """Cost in the currency of the supplied prices, or None if unset."""
        if self.price_input_per_mtok is None or self.price_output_per_mtok is None:
            return None
        return (
            input_tokens * self.price_input_per_mtok
            + output_tokens * self.price_output_per_mtok
        ) / 1_000_000
