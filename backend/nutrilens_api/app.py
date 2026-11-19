"""Flask application factory."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass

from flask import Flask, g, request
from werkzeug.exceptions import HTTPException
from werkzeug.middleware.proxy_fix import ProxyFix

from .auth import Verifier, install_auth
from .config import Settings
from .errors import error_response
from .explain import ExplainService, LlmLike, RetrieverLike
from .limits import limiter
from .llm import LlmClient
from .logging_utils import configure_logging, hash_uid
from .rag.retriever import Retriever
from .rag.store import Store
from .routes import bp

log = logging.getLogger(__name__)


@dataclass
class Services:
    settings: Settings
    llm: LlmClient
    explain: ExplainService


def create_app(
    settings: Settings | None = None,
    *,
    llm: LlmLike | None = None,
    retriever: RetrieverLike | None = None,
    verifier: Verifier | None = None,
) -> Flask:
    """Build the app. `llm`, `retriever` and `verifier` can be injected, which
    is how tests run without Google Cloud."""
    settings = settings or Settings.from_env()
    configure_logging()

    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = settings.max_image_bytes
    app.config["RATE_LIMIT"] = f"{settings.rate_limit_per_minute} per minute"
    # Cloud Run puts one proxy in front of the container.
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1)

    llm = llm or LlmClient(settings)
    if retriever is None:
        retriever = Retriever(Store(settings.db_conninfo(), settings.embedding_dim), llm, settings)
    app.extensions["nutrilens"] = Services(settings, llm, ExplainService(settings, llm, retriever))

    @app.before_request
    def _start_timer():
        g.started = time.perf_counter()

    # Registered before the limiter so the limiter can key on g.uid.
    install_auth(app, settings.firebase_project_id, verifier)
    limiter.init_app(app)
    app.register_blueprint(bp)

    @app.after_request
    def _log_request(response):
        if request.path != "/healthz":
            elapsed_ms = round((time.perf_counter() - g.get("started", time.perf_counter())) * 1000, 1)
            uid = g.get("uid")
            log.info(
                "request",
                extra={
                    "fields": {
                        "method": request.method,
                        "path": request.path,
                        "status": response.status_code,
                        "latency_ms": elapsed_ms,
                        "uid": hash_uid(uid) if uid else None,
                    }
                },
            )
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.errorhandler(404)
    def _not_found(_):
        return error_response("not_found", 404)

    @app.errorhandler(405)
    def _method_not_allowed(_):
        return error_response("method_not_allowed", 405)

    @app.errorhandler(413)
    def _too_large(_):
        return error_response("payload_too_large", 413)

    @app.errorhandler(429)
    def _rate_limited(_):
        return error_response("rate_limited", 429)

    @app.errorhandler(Exception)
    def _unexpected(exc):
        if isinstance(exc, HTTPException):
            return error_response("http_error", exc.code or 500)
        # Log the type only; exception text can contain request content.
        log.error("unhandled error", extra={"fields": {"error_type": type(exc).__name__}})
        return error_response("internal_error", 500)

    return app
