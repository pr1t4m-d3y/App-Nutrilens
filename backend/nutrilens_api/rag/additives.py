"""Loader that links the structured additive table to regulation chunks and
prepares rows for the database. Parsing and validation live in
`additive_rows.py` so the app exporter shares them.
"""

from __future__ import annotations

from collections.abc import Iterable
from pathlib import Path

from .additive_rows import AdditiveFileError, parse_rows
from .chunker import Chunk
from .store import AdditiveRecord

__all__ = ["AdditiveFileError", "load_additives"]


def load_additives(path: Path, known_doc_ids: set[str], chunks: Iterable[Chunk]) -> list[AdditiveRecord]:
    chunk_index: dict[tuple[str, str], list[str]] = {}
    for chunk in chunks:
        for code in chunk.e_numbers:
            chunk_index.setdefault((chunk.doc_id, code), []).append(chunk.chunk_id)

    return [
        AdditiveRecord(
            e_number=row.e_number,
            name=row.name,
            synonyms=row.synonyms,
            category=row.category,
            allergen_tags=row.allergen_tags,
            limits_note=row.limits_note,
            source_doc_id=row.source_doc_id,
            source_locator=row.source_locator,
            chunk_ids=tuple(chunk_index.get((row.source_doc_id, row.e_number), [])),
        )
        for row in parse_rows(path, known_doc_ids)
    ]
