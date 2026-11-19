"""Structure-aware chunking for regulation text.

Splits on legal structure (Article, Annex, Schedule, numbered clauses) rather
than on a fixed window, so each chunk keeps its regulation locator, for
example "Annex II" or "Article 9". Over-long sections are split on paragraph
boundaries with a small overlap, and every piece keeps the same locator.
Each chunk also records the E-numbers it mentions so exact lookups work.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .enumbers import extract_e_numbers

MAX_CHARS = 1800
OVERLAP_CHARS = 150

_ARTICLE = re.compile(r"^(Article|Section|Regulation|Rule)\s+(\d+[A-Za-z]?(?:\.\d+)*)\b", re.IGNORECASE)
_ANNEX = re.compile(r"^(ANNEX|Annex|SCHEDULE|Schedule|APPENDIX|Appendix)\s+([IVXLC]+|\d+|[A-Z])\b")
_CLAUSE = re.compile(r"^(\d+(?:\.\d+){1,4})\.?\s+(?=[A-Z])")


@dataclass(frozen=True)
class Chunk:
    doc_id: str
    index: int
    locator: str
    text: str
    e_numbers: tuple[str, ...]

    @property
    def chunk_id(self) -> str:
        return f"{self.doc_id}:{self.index:04d}"


def _heading_locator(line: str) -> str | None:
    stripped = line.strip()
    match = _ANNEX.match(stripped)
    if match:
        return f"{match.group(1).title()} {match.group(2)}"
    match = _ARTICLE.match(stripped)
    if match:
        return f"{match.group(1).title()} {match.group(2)}"
    match = _CLAUSE.match(stripped)
    if match:
        return f"Clause {match.group(1)}"
    return None


def _split_long(text: str) -> list[str]:
    """Split on blank lines first, then on length, keeping a small overlap."""
    if len(text) <= MAX_CHARS:
        return [text]
    pieces: list[str] = []
    current = ""
    for paragraph in re.split(r"\n\s*\n", text):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        if current and len(current) + len(paragraph) + 2 > MAX_CHARS:
            pieces.append(current)
            current = current[-OVERLAP_CHARS:] + "\n\n" + paragraph
        else:
            current = f"{current}\n\n{paragraph}" if current else paragraph
        while len(current) > MAX_CHARS:
            pieces.append(current[:MAX_CHARS])
            current = current[MAX_CHARS - OVERLAP_CHARS:]
    if current.strip():
        pieces.append(current)
    return pieces


def chunk_document(doc_id: str, text: str) -> list[Chunk]:
    """Chunk one document's full text. Text before the first heading is
    labelled "Preamble"."""
    sections: list[tuple[str, list[str]]] = [("Preamble", [])]
    for line in text.splitlines():
        locator = _heading_locator(line)
        if locator is not None:
            sections.append((locator, [line]))
        else:
            sections[-1][1].append(line)

    chunks: list[Chunk] = []
    for locator, lines in sections:
        body = "\n".join(lines).strip()
        if not body:
            continue
        for piece in _split_long(body):
            piece = piece.strip()
            if not piece:
                continue
            chunks.append(
                Chunk(
                    doc_id=doc_id,
                    index=len(chunks),
                    locator=locator,
                    text=piece,
                    e_numbers=tuple(extract_e_numbers(piece)),
                )
            )
    return chunks
