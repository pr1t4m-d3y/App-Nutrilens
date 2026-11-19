"""Tools the agents call.

Both tools are read-only. They work on one request's session state and have no
network access of their own beyond the regulation retriever. The state keeps a
registry of every source a search returned, under ids S1, S2, ... The final
answer may cite only ids in that registry.

This module does not use postponed annotations: the agent framework reads the
function signatures to describe the tools to the model.
"""

import logging

from google.adk.tools.tool_context import ToolContext

from ..rag.retriever import Retriever
from .state import SEARCH_COUNT_KEY, SOURCES_KEY

log = logging.getLogger(__name__)

_MAX_QUERY_CHARS = 300
_MIN_QUERY_CHARS = 3
_SNIPPET_CHARS = 700


def make_tools(retriever: Retriever, max_searches: int):
    """Return (search_regulations, get_source) bound to one retriever."""

    def search_regulations(query: str, tool_context: ToolContext) -> dict:
        """Search the regulation corpus for passages about an ingredient,
        additive code or labelling rule.

        Args:
            query: A short, specific search such as an E-number with its name.

        Returns:
            A dict with a status and a list of sources. Each source has an id
            (S1, S2, ...), the document title, the locator inside it, and the
            passage text. Cite sources by id only.
        """
        used = int(tool_context.state.get(SEARCH_COUNT_KEY, 0))
        if used >= max_searches:
            return {"status": "search_budget_used", "sources": []}
        tool_context.state[SEARCH_COUNT_KEY] = used + 1

        cleaned = (query or "").strip()[:_MAX_QUERY_CHARS]
        if len(cleaned) < _MIN_QUERY_CHARS:
            return {"status": "query_too_short", "sources": []}

        try:
            hits = retriever.retrieve(cleaned)
        except Exception as exc:  # noqa: BLE001 - provider errors vary; log type only
            log.warning("agent search failed", extra={"fields": {"error_type": type(exc).__name__}})
            return {"status": "search_unavailable", "sources": []}

        registry = dict(tool_context.state.get(SOURCES_KEY, {}))
        known = {entry["chunk_id"]: sid for sid, entry in registry.items()}
        returned = []
        for hit in hits:
            sid = known.get(hit.chunk_id)
            if sid is None:
                sid = f"S{len(registry) + 1}"
                registry[sid] = {
                    "chunk_id": hit.chunk_id,
                    "title": hit.doc_title,
                    "locator": hit.locator,
                    "text": hit.text,
                    "method": hit.method,
                }
                known[hit.chunk_id] = sid
            returned.append(
                {
                    "id": sid,
                    "title": hit.doc_title,
                    "locator": hit.locator,
                    "text": hit.text[:_SNIPPET_CHARS],
                }
            )
        tool_context.state[SOURCES_KEY] = registry
        return {"status": "ok" if returned else "no_source_found", "sources": returned}

    def get_source(source_id: str, tool_context: ToolContext) -> dict:
        """Return the full text of a source found earlier.

        Args:
            source_id: A source id such as S1.

        Returns:
            A dict with the status and, if found, the title, locator and full
            passage text.
        """
        entry = tool_context.state.get(SOURCES_KEY, {}).get((source_id or "").strip())
        if not entry:
            return {"status": "not_found"}
        return {
            "status": "ok",
            "title": entry["title"],
            "locator": entry["locator"],
            "text": entry["text"],
        }

    return search_regulations, get_source
