"""Request validation.

The explain endpoint is strict on purpose. It accepts label text and three
lists of coarse profile flags, and rejects any other field (a name, an age, a
medication list, free-text notes). That is how the "send only what the task
needs" rule is enforced on the server as well as in the app.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .errors import ValidationError

_ALLOWED_TOP = {"label_text", "profile"}
_ALLOWED_PROFILE = {"allergies", "conditions", "avoid"}
_MAX_ITEMS = 20
_MAX_ITEM_CHARS = 60
_MIN_LABEL_CHARS = 10
_CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")

_IMAGE_SIGNATURES: tuple[tuple[bytes, str], ...] = (
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n", "image/png"),
)


@dataclass(frozen=True)
class ExplainRequest:
    label_text: str
    allergies: tuple[str, ...]
    conditions: tuple[str, ...]
    avoid: tuple[str, ...]


def _clean(text: str) -> str:
    return _CONTROL.sub(" ", text).strip()


def _flag_list(value: object) -> tuple[str, ...]:
    if value is None:
        return ()
    if not isinstance(value, list):
        raise ValidationError("profile lists must be arrays of strings")
    if len(value) > _MAX_ITEMS:
        raise ValidationError("profile list is too long")
    cleaned: list[str] = []
    for item in value:
        if not isinstance(item, str):
            raise ValidationError("profile lists must contain only strings")
        text = _clean(item)
        if len(text) > _MAX_ITEM_CHARS:
            raise ValidationError("profile item is too long")
        if text:
            cleaned.append(text)
    return tuple(cleaned)


def parse_explain(payload: object, max_label_chars: int) -> ExplainRequest:
    if not isinstance(payload, dict):
        raise ValidationError("body must be a JSON object")
    if set(payload) - _ALLOWED_TOP:
        raise ValidationError("unexpected field in request")

    label = payload.get("label_text")
    if not isinstance(label, str):
        raise ValidationError("label_text is required")
    label = _clean(label)
    if len(label) < _MIN_LABEL_CHARS:
        raise ValidationError("label_text is too short")
    if len(label) > max_label_chars:
        raise ValidationError("label_text is too long")

    profile = payload.get("profile", {})
    if profile is None:
        profile = {}
    if not isinstance(profile, dict):
        raise ValidationError("profile must be an object")
    if set(profile) - _ALLOWED_PROFILE:
        raise ValidationError("unexpected field in profile")

    return ExplainRequest(
        label_text=label,
        allergies=_flag_list(profile.get("allergies")),
        conditions=_flag_list(profile.get("conditions")),
        avoid=_flag_list(profile.get("avoid")),
    )


def detect_image_mime(data: bytes) -> str | None:
    """Identify an image by its leading bytes, never by what the client claims."""
    for signature, mime in _IMAGE_SIGNATURES:
        if data.startswith(signature):
            return mime
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None
