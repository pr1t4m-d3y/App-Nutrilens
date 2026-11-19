"""Turn the agents' outputs into the API response.

This is ordinary code and does not trust the agents. A finding reaches the app
only if the verifier marked it supported AND it cites at least one source that
a search actually returned. A finding the verifier did not mention counts as
unsupported.
"""

import json
from dataclasses import dataclass

from ..explain import ModelOutputError, enforce_citations, strip_fences
from ..rag.retriever import Retrieved


@dataclass(frozen=True)
class Assembled:
    body: dict
    dropped: int
    unsupported: int


def parse_list(text: str, key: str) -> list[dict]:
    """Read a JSON list from an agent's answer, either bare or under `key`."""
    try:
        data = json.loads(strip_fences(text or ""))
    except json.JSONDecodeError as exc:
        raise ModelOutputError("not JSON") from exc
    if isinstance(data, dict):
        data = data.get(key)
    if not isinstance(data, list):
        raise ModelOutputError(f"missing {key} list")
    return [item for item in data if isinstance(item, dict)]


def sources_from_state(registry: object) -> dict[str, Retrieved]:
    sources: dict[str, Retrieved] = {}
    if not isinstance(registry, dict):
        return sources
    for sid, entry in registry.items():
        if isinstance(sid, str) and isinstance(entry, dict):
            sources[sid] = Retrieved(
                chunk_id=str(entry.get("chunk_id", "")),
                doc_title=str(entry.get("title", "")),
                locator=str(entry.get("locator", "")),
                text=str(entry.get("text", "")),
                method=str(entry.get("method", "")),
                distance=None,
            )
    return sources


def _norm(value: object) -> str:
    return value.strip().lower() if isinstance(value, str) else ""


def assemble(review_text: str, verification_text: str, registry: object) -> Assembled:
    findings = parse_list(review_text, "findings")
    verdicts = {_norm(v.get("name")): v.get("supported") is True for v in parse_list(verification_text, "verdicts")}

    supported = [f for f in findings if verdicts.get(_norm(f.get("name")), False)]
    unsupported = len(findings) - len(supported)

    numbered = sources_from_state(registry)
    kept, dropped = enforce_citations(supported, numbered)
    if not kept:
        return Assembled({"status": "no_source_found", "ingredients": [], "sources": []}, dropped, unsupported)

    used = list(dict.fromkeys(cid for entry in kept for cid in entry["citations"]))
    sources = [{"id": sid, "title": numbered[sid].doc_title, "locator": numbered[sid].locator} for sid in used]
    return Assembled({"status": "ok", "ingredients": kept, "sources": sources}, dropped, unsupported)
