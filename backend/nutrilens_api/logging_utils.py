"""Structured JSON logs with masking.

Rules:
- Request and response bodies are never logged.
- Exceptions are logged by type only, because exception text can echo content.
- Anything that looks like a token, an email or a long number is masked in
  message text as a second line of defence.
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
import sys

_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"Bearer\s+[A-Za-z0-9._~+/=-]+", re.IGNORECASE), "Bearer [redacted]"),
    (re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]*"), "[jwt]"),
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "[email]"),
    (re.compile(r"(?<!\d)\+?\d[\d\s().-]{8,}\d"), "[number]"),
]


def mask(text: str) -> str:
    for pattern, replacement in _PATTERNS:
        text = pattern.sub(replacement, text)
    return text


def hash_uid(uid: str) -> str:
    """Short, non-reversible handle so log lines can be grouped per user."""
    return hashlib.sha256(uid.encode("utf-8")).hexdigest()[:12]


class MaskingFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = mask(record.getMessage())
        record.args = ()
        return True


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict = {
            "severity": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        fields = getattr(record, "fields", None)
        if isinstance(fields, dict):
            payload.update(fields)
        if record.exc_info and record.exc_info[0] is not None:
            payload["exception_type"] = record.exc_info[0].__name__
        return json.dumps(payload, default=str)


def configure_logging(level: int = logging.INFO) -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    handler.addFilter(MaskingFilter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)
