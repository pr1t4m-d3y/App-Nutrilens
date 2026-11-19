"""Firebase ID-token (JWT) verification.

Each app install signs in with Firebase anonymous auth and sends the ID token
as `Authorization: Bearer <token>`. The token is verified against Google's
public keys, with the Firebase project ID as the expected audience.
"""

from __future__ import annotations

from collections.abc import Callable

from flask import Flask, g, request
from google.auth.transport import requests as ga_requests
from google.oauth2 import id_token

from .errors import error_response

_REQUEST = ga_requests.Request()

Verifier = Callable[[str, str], dict]


class AuthError(Exception):
    """The request carried no valid token."""


def _default_verifier(token: str, project_id: str) -> dict:
    return id_token.verify_firebase_token(token, _REQUEST, audience=project_id)


def verify_bearer(header: str | None, project_id: str, verifier: Verifier | None = None) -> dict:
    """Return the verified claims, or raise AuthError."""
    if not header or not header.startswith("Bearer "):
        raise AuthError("missing bearer token")
    token = header[len("Bearer "):].strip()
    if not token:
        raise AuthError("empty bearer token")
    try:
        claims = (verifier or _default_verifier)(token, project_id)
    except ValueError as exc:
        raise AuthError("invalid token") from exc
    if not claims or not claims.get("sub"):
        raise AuthError("token has no subject")
    # Checked explicitly rather than trusted to the library: the token must have
    # been issued by this project's Firebase Auth and be addressed to it.
    if claims.get("iss") != f"https://securetoken.google.com/{project_id}":
        raise AuthError("wrong issuer")
    if claims.get("aud") != project_id:
        raise AuthError("wrong audience")
    return claims


def install_auth(app: Flask, project_id: str, verifier: Verifier | None = None) -> None:
    """Require a valid token on every /v1/ route and expose `g.uid`.

    This must be registered before the rate limiter so the limiter can key on
    the user.
    """

    @app.before_request
    def _authenticate():
        if not request.path.startswith("/v1/"):
            return None
        try:
            claims = verify_bearer(request.headers.get("Authorization"), project_id, verifier)
        except AuthError:
            return error_response("unauthorized", 401)
        g.uid = claims["sub"]
        return None
