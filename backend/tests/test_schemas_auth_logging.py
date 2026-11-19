import json
import logging
import sys

import pytest

from nutrilens_api.auth import AuthError, verify_bearer
from nutrilens_api.errors import ValidationError
from nutrilens_api.logging_utils import JsonFormatter, hash_uid, mask
from nutrilens_api.schemas import detect_image_mime, parse_explain

LABEL = "Ingredients: sugar, palm oil, E211"


def test_parse_explain_accepts_minimal_profile():
    req = parse_explain(
        {"label_text": LABEL, "profile": {"allergies": ["Peanuts"], "conditions": [], "avoid": ["palm oil"]}},
        6000,
    )
    assert req.allergies == ("Peanuts",)
    assert req.avoid == ("palm oil",)
    assert req.conditions == ()


@pytest.mark.parametrize(
    "payload",
    [
        [],
        {"label_text": LABEL, "name": "A"},
        {"label_text": LABEL, "profile": {"medications": ["x"]}},
        {"label_text": "short"},
        {"label_text": 5},
        {"label_text": LABEL, "profile": {"allergies": "peanuts"}},
        {"label_text": LABEL, "profile": {"allergies": [1]}},
        {"label_text": LABEL, "profile": {"allergies": ["x" * 61]}},
        {"label_text": LABEL, "profile": {"allergies": ["a"] * 21}},
    ],
)
def test_parse_explain_rejects(payload):
    with pytest.raises(ValidationError):
        parse_explain(payload, 6000)


def test_parse_explain_rejects_oversize_label():
    with pytest.raises(ValidationError):
        parse_explain({"label_text": "a" * 50}, 40)


def test_detect_image_mime():
    assert detect_image_mime(b"\xff\xd8\xff\xe0" + b"0" * 8) == "image/jpeg"
    assert detect_image_mime(b"\x89PNG\r\n\x1a\n" + b"0" * 8) == "image/png"
    assert detect_image_mime(b"RIFF\x00\x00\x00\x00WEBPVP8 ") == "image/webp"
    assert detect_image_mime(b"hello world, not an image") is None


def claims(**overrides):
    base = {"sub": "u1", "iss": "https://securetoken.google.com/p", "aud": "p"}
    base.update(overrides)
    return base


def good(token, project):
    return claims()


def test_verify_bearer_success():
    assert verify_bearer("Bearer abc", "p", good) == claims()


def test_verify_bearer_rejects_wrong_issuer_and_audience():
    with pytest.raises(AuthError):
        verify_bearer("Bearer abc", "p", lambda t, p: claims(iss="https://securetoken.google.com/other"))
    with pytest.raises(AuthError):
        verify_bearer("Bearer abc", "p", lambda t, p: claims(iss="https://accounts.google.com"))
    with pytest.raises(AuthError):
        verify_bearer("Bearer abc", "p", lambda t, p: claims(aud="other"))


@pytest.mark.parametrize("header", [None, "", "Basic abc", "Bearer ", "Bearer    "])
def test_verify_bearer_rejects_bad_headers(header):
    with pytest.raises(AuthError):
        verify_bearer(header, "p", good)


def test_verify_bearer_rejects_invalid_token_and_missing_subject():
    def bad(token, project):
        raise ValueError("invalid")

    with pytest.raises(AuthError):
        verify_bearer("Bearer abc", "p", bad)
    with pytest.raises(AuthError):
        verify_bearer("Bearer abc", "p", lambda t, p: {})


def test_mask_removes_tokens_emails_and_numbers():
    assert mask("auth Bearer abc.def.ghi ok") == "auth Bearer [redacted] ok"
    assert mask("mail a.b@example.com now") == "mail [email] now"
    assert mask("call +91 98765 43210 now") == "call [number] now"


def test_hash_uid_is_stable_and_short():
    assert hash_uid("user-1") == hash_uid("user-1")
    assert len(hash_uid("user-1")) == 12
    assert hash_uid("user-1") != hash_uid("user-2")


def test_json_formatter_logs_exception_type_not_text():
    try:
        raise ValueError("secret detail")
    except ValueError:
        record = logging.LogRecord("t", logging.ERROR, __file__, 1, "failed", (), sys.exc_info())
    record.fields = {"status": 500}
    out = json.loads(JsonFormatter().format(record))
    assert out["exception_type"] == "ValueError"
    assert out["status"] == 500
    assert "secret detail" not in json.dumps(out)


def test_trace_resource_parses_the_cloud_trace_header():
    from nutrilens_api.logging_utils import trace_resource

    header = "105445aa7843bc8bf206b12000100000/1;o=1"
    assert trace_resource(header, "proj") == "projects/proj/traces/105445aa7843bc8bf206b12000100000"
    assert trace_resource("not-a-trace/1", "proj") is None
    assert trace_resource(None, "proj") is None
