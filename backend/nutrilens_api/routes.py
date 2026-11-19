"""HTTP routes."""

from __future__ import annotations

import logging

from flask import Blueprint, current_app, g, jsonify, request

from .errors import UpstreamError, ValidationError, error_response
from .limits import current_limit, limiter
from .llm import LlmError
from .logging_utils import hash_uid
from .schemas import detect_image_mime, parse_explain

log = logging.getLogger(__name__)
bp = Blueprint("api", __name__)

_MAX_EXPLAIN_BODY = 64 * 1024


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
                "cost": cost,
            }
        },
    )
    body = dict(outcome.body)
    body["model"] = outcome.model
    body["usage"] = {"input_tokens": outcome.input_tokens, "output_tokens": outcome.output_tokens}
    return jsonify(body)


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
