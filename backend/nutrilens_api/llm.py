"""Thin wrapper around the Google Gen AI SDK on Vertex AI.

Authentication is the Cloud Run service account (application default
credentials). There is no API key anywhere in this service.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from google import genai
from google.genai import types

from .config import Settings

log = logging.getLogger(__name__)

OCR_PROMPT = (
    "This is a photo of a packaged food or medicine label. Return only the "
    "text of the ingredients list, exactly as printed, with no commentary. "
    "If there is no ingredients list, return an empty string."
)


class LlmError(Exception):
    """A model call failed. Carries no provider text."""


@dataclass(frozen=True)
class LlmResult:
    text: str
    model: str
    input_tokens: int
    output_tokens: int


def _usage(response) -> tuple[int, int]:
    usage = getattr(response, "usage_metadata", None)
    if usage is None:
        return 0, 0
    prompt = getattr(usage, "prompt_token_count", 0) or 0
    output = getattr(usage, "candidates_token_count", 0) or 0
    thoughts = getattr(usage, "thoughts_token_count", 0) or 0
    return int(prompt), int(output) + int(thoughts)


class LlmClient:
    def __init__(self, settings: Settings, client: genai.Client | None = None):
        self._settings = settings
        self._client = client or genai.Client(
            enterprise=True,
            project=settings.gcp_project,
            location=settings.gcp_location,
        )

    def generate_json(self, system: str, prompt: str) -> LlmResult:
        """JSON generation with one retry on the lighter fallback model."""
        models = [self._settings.generation_model]
        if self._settings.fallback_model != self._settings.generation_model:
            models.append(self._settings.fallback_model)
        for model in models:
            try:
                response = self._client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=system,
                        temperature=0.1,
                        response_mime_type="application/json",
                        max_output_tokens=4096,
                    ),
                )
                text = response.text or ""
                if not text.strip():
                    raise LlmError("empty model response")
                tokens_in, tokens_out = _usage(response)
                return LlmResult(text, model, tokens_in, tokens_out)
            except Exception as exc:  # noqa: BLE001 - provider errors vary; log type only
                log.warning("generation failed", extra={"fields": {"model": model, "error_type": type(exc).__name__}})
        raise LlmError("generation failed on all models")

    def ocr_text(self, image: bytes, mime: str) -> LlmResult:
        model = self._settings.generation_model
        try:
            response = self._client.models.generate_content(
                model=model,
                contents=[types.Part.from_bytes(data=image, mime_type=mime), OCR_PROMPT],
                config=types.GenerateContentConfig(temperature=0.0, max_output_tokens=2048),
            )
        except Exception as exc:  # noqa: BLE001
            log.warning("ocr failed", extra={"fields": {"model": model, "error_type": type(exc).__name__}})
            raise LlmError("ocr failed") from exc
        tokens_in, tokens_out = _usage(response)
        return LlmResult((response.text or "").strip(), model, tokens_in, tokens_out)

    def embed(self, texts: list[str], task_type: str) -> list[list[float]]:
        """One request per text. task_type is RETRIEVAL_DOCUMENT or RETRIEVAL_QUERY."""
        vectors: list[list[float]] = []
        for text in texts:
            try:
                response = self._client.models.embed_content(
                    model=self._settings.embedding_model,
                    contents=text,
                    config=types.EmbedContentConfig(
                        output_dimensionality=self._settings.embedding_dim,
                        task_type=task_type,
                    ),
                )
                values = list(response.embeddings[0].values)
            except Exception as exc:  # noqa: BLE001
                log.warning("embedding failed", extra={"fields": {"error_type": type(exc).__name__}})
                raise LlmError("embedding failed") from exc
            if len(values) != self._settings.embedding_dim:
                raise LlmError("embedding has unexpected dimension")
            vectors.append(values)
        return vectors
