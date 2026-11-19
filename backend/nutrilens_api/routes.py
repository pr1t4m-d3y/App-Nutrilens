"""HTTP routes."""

from __future__ import annotations

import logging
import time

from flask import Blueprint, current_app, g, jsonify, request

from .errors import UpstreamError, ValidationError, error_response
from .limits import current_limit, limiter
from .llm import LlmError
from .logging_utils import hash_uid
from .schemas import detect_image_mime, parse_explain, parse_search

log = logging.getLogger(__name__)
bp = Blueprint("api", __name__)

_MAX_EXPLAIN_BODY = 64 * 1024
_SNIPPET_CHARS = 600


def _services():
    return current_app.extensions["nutrilens"]


@bp.get("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@bp.post("/v1/explain")
@limiter.limit(current_limit)
def explain():
    services = _services()
    if request.content_length is not None and request.content_length > _MAX_EXPLAIN_BODY:
        return error_response("payload_too_large", 413)
    try:
        req = parse_explain(request.get_json(silent=True), services.settings.max_label_chars)
    except ValidationError as exc:
        return error_response("invalid_request", 400, exc.detail)

    try:
        outcome = services.explain.explain(req)
    except UpstreamError:
        return error_response("upstream_unavailable", 502)

    cost = services.settings.estimate_cost(outcome.input_tokens, outcome.output_tokens)
    log.info(
        "explain",
        extra={
            "fields": {
                "uid": hash_uid(g.uid),
                "status": outcome.body["status"],
                "model": outcome.model,
                "input_tokens": outcome.input_tokens,
                "output_tokens": outcome.output_tokens,
                "dropped_uncited": outcome.dropped,
                "retrieval_ms": round(outcome.retrieval_ms, 1),
                "generation_ms": round(outcome.generation_ms, 1),
                "cost": cost,
            }
        },
    )
    body = dict(outcome.body)
    body["model"] = outcome.model
    body["usage"] = {"input_tokens": outcome.input_tokens, "output_tokens": outcome.output_tokens}
    body["timings_ms"] = {
        "retrieval": round(outcome.retrieval_ms, 1),
        "generation": round(outcome.generation_ms, 1),
    }
    return jsonify(body)


@bp.post("/v1/search")
@limiter.limit(current_limit)
def search():
    """Retrieval only: returns the matching regulation text verbatim, with its
    document title and locator. No model is involved, so nothing is generated."""
    services = _services()
    if request.content_length is not None and request.content_length > _MAX_EXPLAIN_BODY:
        return error_response("payload_too_large", 413)
    try:
        query = parse_search(request.get_json(silent=True))
    except ValidationError as exc:
        return error_response("invalid_request", 400, exc.detail)

    started = time.perf_counter()
    try:
        hits = services.retriever.retrieve(query)
    except Exception as exc:  # noqa: BLE001 - database errors vary; log type only
        log.warning("search retrieval failed", extra={"fields": {"error_type": type(exc).__name__}})
        return error_response("upstream_unavailable", 502)
    elapsed_ms = round((time.perf_counter() - started) * 1000, 1)

    log.info(
        "search",
        extra={"fields": {"uid": hash_uid(g.uid), "results": len(hits), "retrieval_ms": elapsed_ms}},
    )
    return jsonify(
        {
            "status": "ok" if hits else "no_source_found",
            "results": [
                {
                    "id": hit.chunk_id,
                    "title": hit.doc_title,
                    "locator": hit.locator,
                    "snippet": hit.text[:_SNIPPET_CHARS],
                    "method": hit.method,
                }
                for hit in hits
            ],
        }
    )


@bp.post("/v1/ocr-fallback")
@limiter.limit(current_limit)
def ocr_fallback():
    services = _services()
    data = request.get_data(cache=False)
    if not data:
        return error_response("invalid_request", 400, "image body is required")
    mime = detect_image_mime(data)
    if mime is None:
        return error_response("unsupported_media_type", 415)
    try:
        result = services.llm.ocr_text(data, mime)
    except LlmError:
        return error_response("upstream_unavailable", 502)

    cost = services.settings.estimate_cost(result.input_tokens, result.output_tokens)
    log.info(
        "ocr_fallback",
        extra={
            "fields": {
                "uid": hash_uid(g.uid),
                "model": result.model,
                "input_tokens": result.input_tokens,
                "output_tokens": result.output_tokens,
                "cost": cost,
            }
        },
    )
    return jsonify(
        {
            "text": result.text[: services.settings.max_label_chars],
            "model": result.model,
            "usage": {"input_tokens": result.input_tokens, "output_tokens": result.output_tokens},
        }
    )


@bp.delete("/v1/me")
@limiter.limit(current_limit)
def delete_me():
    """Acknowledge a deletion request.

    This service keeps no per-user data: requests are processed in memory, and
    logs hold only a short hash of the user id plus counts. The app deletes its
    own Firebase identity and local data. The endpoint exists so that guarantee
    has a testable contract.
    """
    log.info("delete_requested", extra={"fields": {"uid": hash_uid(g.uid)}})
    return jsonify({"status": "ok", "server_side_records": 0})
