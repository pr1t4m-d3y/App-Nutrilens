"""Rate limiting.

Requests are keyed by the verified user id when there is one, otherwise by the
client address. Counters live in each instance's memory, so the effective
limit scales with the number of Cloud Run instances. `--max-instances` in the
deploy script bounds that.
"""

from __future__ import annotations

from flask import current_app, g
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address


def rate_key() -> str:
    uid = g.get("uid")
    return f"uid:{uid}" if uid else f"ip:{get_remote_address()}"


def current_limit() -> str:
    return current_app.config["RATE_LIMIT"]


limiter = Limiter(rate_key, storage_uri="memory://")
