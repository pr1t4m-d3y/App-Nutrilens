"""Runs the agent pipeline for one request."""

import asyncio
import logging
import time
import uuid
from dataclasses import dataclass, field

from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

from ..config import Settings, configure_vertex_environment
from ..errors import UpstreamError
from ..explain import ModelOutputError, RetrieverLike
from ..schemas import ExplainRequest
from .assemble import assemble
from .pipeline import build_pipeline
from .state import (
    APP_NAME,
    FLAGS_KEY,
    LABEL_KEY,
    REVIEW_KEY,
    SEARCH_COUNT_KEY,
    SOURCES_KEY,
    VERIFICATION_KEY,
)

log = logging.getLogger(__name__)


@dataclass
class StageStats:
    agent: str
    events: int = 0
    seconds: float = 0.0
    input_tokens: int = 0
    output_tokens: int = 0


@dataclass
class AgentOutcome:
    body: dict
    model: str
    dropped: int
    unsupported: int
    searches: int
    stages: list[StageStats] = field(default_factory=list)

    @property
    def input_tokens(self) -> int:
        return sum(stage.input_tokens for stage in self.stages)

    @property
    def output_tokens(self) -> int:
        return sum(stage.output_tokens for stage in self.stages)


def flags_text(req: ExplainRequest) -> str:
    return (
        f"allergies: {', '.join(req.allergies) or 'none'}\n"
        f"conditions: {', '.join(req.conditions) or 'none'}\n"
        f"avoid: {', '.join(req.avoid) or 'none'}"
    )


class AgentExplainService:
    def __init__(self, settings: Settings, retriever: RetrieverLike):
        self._settings = settings
        self._retriever = retriever

    def analyze(self, req: ExplainRequest, user_key: str) -> AgentOutcome:
        configure_vertex_environment(self._settings)
        try:
            return asyncio.run(self._run(req, user_key))
        except UpstreamError:
            raise
        except ModelOutputError as exc:
            log.warning("agent output rejected")
            raise UpstreamError("bad agent output") from exc
        except Exception as exc:  # noqa: BLE001 - framework and provider errors vary; log type only
            log.warning("agent run failed", extra={"fields": {"error_type": type(exc).__name__}})
            raise UpstreamError("agent run failed") from exc

    async def _run(self, req: ExplainRequest, user_key: str) -> AgentOutcome:
        pipeline = build_pipeline(self._settings, self._retriever)
        sessions = InMemorySessionService()
        runner = Runner(agent=pipeline, app_name=APP_NAME, session_service=sessions)
        session_id = uuid.uuid4().hex

        await sessions.create_session(
            app_name=APP_NAME,
            user_id=user_key,
            session_id=session_id,
            state={
                LABEL_KEY: req.label_text,
                FLAGS_KEY: flags_text(req),
                SOURCES_KEY: {},
                SEARCH_COUNT_KEY: 0,
            },
        )

        stages: dict[str, StageStats] = {}
        previous = time.perf_counter()
        message = types.Content(role="user", parts=[types.Part(text="Review this label.")])
        async for event in runner.run_async(user_id=user_key, session_id=session_id, new_message=message):
            now = time.perf_counter()
            stage = stages.setdefault(event.author, StageStats(event.author))
            stage.events += 1
            stage.seconds += now - previous
            previous = now
            usage = getattr(event, "usage_metadata", None)
            if usage is not None:
                stage.input_tokens += int(getattr(usage, "prompt_token_count", 0) or 0)
                stage.output_tokens += int(getattr(usage, "candidates_token_count", 0) or 0) + int(
                    getattr(usage, "thoughts_token_count", 0) or 0
                )

        session = await sessions.get_session(app_name=APP_NAME, user_id=user_key, session_id=session_id)
        await sessions.delete_session(app_name=APP_NAME, user_id=user_key, session_id=session_id)
        state = session.state if session is not None else {}

        review = state.get(REVIEW_KEY)
        verification = state.get(VERIFICATION_KEY)
        if not isinstance(review, str) or not isinstance(verification, str):
            raise UpstreamError("incomplete agent output")

        assembled = assemble(review, verification, state.get(SOURCES_KEY, {}))
        return AgentOutcome(
            body=assembled.body,
            model=self._settings.generation_model,
            dropped=assembled.dropped,
            unsupported=assembled.unsupported,
            searches=int(state.get(SEARCH_COUNT_KEY, 0)),
            stages=list(stages.values()),
        )
