"""Hybrid retrieval: exact E-number match first, then vector search.

If the embedding service is down, exact matches are still returned. If
nothing at all is retrieved the caller must answer "no source found".
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Protocol

from ..config import Settings
from ..llm import LlmError
from .enumbers import extract_e_numbers
from .store import StoredChunk

log = logging.getLogger(__name__)

_QUERY_CHARS = 2000


@dataclass(frozen=True)
class Retrieved:
    chunk_id: str
    doc_title: str
    locator: str
    text: str
    method: str  # "exact" or "vector"
    distance: float | None


class StoreLike(Protocol):
    def chunks_for_e_numbers(self, codes: list[str], limit: int) -> list[StoredChunk]: ...
    def search_vector(self, embedding: list[float], limit: int) -> list[StoredChunk]: ...


class EmbedderLike(Protocol):
    def embed(self, texts: list[str], task_type: str) -> list[list[float]]: ...


class Retriever:
    def __init__(self, store: StoreLike, embedder: EmbedderLike, settings: Settings):
        self._store = store
        self._embedder = embedder
        self._settings = settings

    def retrieve(self, label_text: str) -> list[Retrieved]:
        results: dict[str, Retrieved] = {}

        codes = extract_e_numbers(label_text)
        for chunk in self._store.chunks_for_e_numbers(codes, self._settings.retrieval_max_context):
            results.setdefault(
                chunk.chunk_id,
                Retrieved(chunk.chunk_id, chunk.doc_title, chunk.locator, chunk.text, "exact", None),
            )

        try:
            query_vector = self._embedder.embed([label_text[:_QUERY_CHARS]], "RETRIEVAL_QUERY")[0]
        except LlmError:
            log.warning("vector search skipped: embedding unavailable")
            query_vector = None

        if query_vector is not None:
            for chunk in self._store.search_vector(query_vector, self._settings.retrieval_top_k):
                if chunk.distance is None or chunk.distance > self._settings.retrieval_max_distance:
                    continue
                results.setdefault(
                    chunk.chunk_id,
                    Retrieved(
                        chunk.chunk_id, chunk.doc_title, chunk.locator, chunk.text, "vector", chunk.distance
                    ),
                )

        return list(results.values())[: self._settings.retrieval_max_context]
