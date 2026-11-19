import pytest

from nutrilens_api.agents.runner import AgentOutcome, StageStats
from nutrilens_api.app import create_app
from nutrilens_api.config import Settings
from nutrilens_api.limits import limiter
from nutrilens_api.errors import UpstreamError
from nutrilens_api.llm import LlmError, LlmResult
from nutrilens_api.rag.retriever import Retrieved

GOOD_TOKEN = "good-token"


class FakeLlm:
    """Stands in for LlmClient. Records prompts so tests can inspect them."""

    def __init__(self, json_text: str = "", error: bool = False):
        self.json_text = json_text
        self.error = error
        self.prompts: list[str] = []

    def generate_json(self, system: str, prompt: str) -> LlmResult:
        self.prompts.append(prompt)
        if self.error:
            raise LlmError("boom")
        return LlmResult(self.json_text, "fake-model", 100, 50)

    def ocr_text(self, image: bytes, mime: str) -> LlmResult:
        return LlmResult("Sugar, salt", "fake-model", 10, 5)

    def embed(self, texts, task_type):
        return [[0.0] * 4 for _ in texts]


class FakeRetriever:
    def __init__(self, items: list[Retrieved] | None = None, error: Exception | None = None):
        self.items = items or []
        self.error = error

    def retrieve(self, label_text: str) -> list[Retrieved]:
        if self.error:
            raise self.error
        return self.items


class FakeAgents:
    """Stands in for the agent service."""

    def __init__(self, body: dict | None = None, error: bool = False):
        self.body = body or {
            "status": "ok",
            "ingredients": [
                {"name": "Sodium benzoate", "impact": "bad", "details": ["A reason."], "citations": ["S1"]}
            ],
            "sources": [{"id": "S1", "title": "Test Regulation", "locator": "Annex II"}],
        }
        self.error = error
        self.calls: list[tuple] = []

    def analyze(self, req, user_key: str) -> AgentOutcome:
        self.calls.append((req, user_key))
        if self.error:
            raise UpstreamError("agents failed")
        return AgentOutcome(
            body=self.body,
            model="fake-model",
            dropped=1,
            unsupported=2,
            searches=3,
            stages=[StageStats("ingredient_analyst", events=1, seconds=0.5, input_tokens=10, output_tokens=5)],
        )


def fake_verifier(token: str, project_id: str) -> dict:
    if token == GOOD_TOKEN:
        return {
            "sub": "user-1",
            "iss": "https://securetoken.google.com/test-project",
            "aud": "test-project",
        }
    raise ValueError("bad token")


def source(chunk_id="doc:0001", title="Test Regulation", locator="Annex II") -> Retrieved:
    return Retrieved(chunk_id, title, locator, "test passage", "exact", None)


@pytest.fixture
def settings() -> Settings:
    return Settings(firebase_project_id="test-project", gcp_project="test-project")


@pytest.fixture
def make_client(settings):
    def _make(llm=None, retriever=None, agents=None, **settings_overrides):
        from dataclasses import replace

        app = create_app(
            replace(settings, **settings_overrides),
            llm=llm or FakeLlm(),
            retriever=retriever or FakeRetriever([source()]),
            verifier=fake_verifier,
            agent_service=agents or FakeAgents(),
        )
        limiter.reset()
        return app.test_client()

    return _make


AUTH = {"Authorization": f"Bearer {GOOD_TOKEN}"}
