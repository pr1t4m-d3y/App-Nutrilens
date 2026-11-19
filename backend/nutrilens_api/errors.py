"""Error types and the single JSON error shape the API returns.

Error responses never echo request content or exception text.
"""

from __future__ import annotations

from flask import jsonify


class ValidationError(Exception):
    """A client mistake. `detail` is a fixed message that never contains user input."""

    def __init__(self, detail: str):
        super().__init__(detail)
        self.detail = detail


class UpstreamError(Exception):
    """A dependency (model or database) failed. Details go to logs by type only."""


def error_response(code: str, status: int, detail: str | None = None):
    body = {"error": code}
    if detail:
        body["detail"] = detail
    return jsonify(body), status
