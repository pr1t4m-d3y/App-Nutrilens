"""Loader for the structured additive table (`data/additives.csv`).

The CSV is authored by a person from the regulation documents in
`data/regulations/`. Every row must name the document and the locator that
supports it. Rows without a citation are rejected, so no additive entry can
exist without a source.

Columns: e_number, name, synonyms, category, allergen_tags, limits_note,
source_doc_id, source_locator. `synonyms` and `allergen_tags` use "|" as the
separator.
"""

from __future__ import annotations

import csv
import re
from collections.abc import Iterable
from pathlib import Path

from .chunker import Chunk
from .enumbers import extract_e_numbers
from .store import AdditiveRecord

REQUIRED_COLUMNS = (
    "e_number",
    "name",
    "synonyms",
    "category",
    "allergen_tags",
    "limits_note",
    "source_doc_id",
    "source_locator",
)
_E_NUMBER = re.compile(r"^E\d{3,4}[a-i]?$")


class AdditiveFileError(ValueError):
    """The additive CSV is malformed. The message lists every problem found."""


def _split(value: str) -> tuple[str, ...]:
    return tuple(part.strip() for part in value.split("|") if part.strip())


def load_additives(path: Path, known_doc_ids: set[str], chunks: Iterable[Chunk]) -> list[AdditiveRecord]:
    chunk_index: dict[tuple[str, str], list[str]] = {}
    for chunk in chunks:
        for code in chunk.e_numbers:
            chunk_index.setdefault((chunk.doc_id, code), []).append(chunk.chunk_id)

    problems: list[str] = []
    records: list[AdditiveRecord] = []
    seen: set[str] = set()

    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = [c for c in REQUIRED_COLUMNS if c not in (reader.fieldnames or [])]
        if missing:
            raise AdditiveFileError(f"missing columns: {', '.join(missing)}")
        for line_no, raw_row in enumerate(reader, start=2):
            row = {key: (value or "") for key, value in raw_row.items() if isinstance(key, str)}
            codes = extract_e_numbers(row["e_number"])
            code = codes[0] if len(codes) == 1 else ""
            if not _E_NUMBER.match(code):
                problems.append(f"line {line_no}: e_number is not a single E-number")
                continue
            if code in seen:
                problems.append(f"line {line_no}: duplicate {code}")
                continue
            seen.add(code)
            for column in ("name", "category", "limits_note", "source_doc_id", "source_locator"):
                if not row[column].strip():
                    problems.append(f"line {line_no}: {column} is empty")
            if row["source_doc_id"].strip() not in known_doc_ids:
                problems.append(f"line {line_no}: source_doc_id is not in the manifest")
                continue
            records.append(
                AdditiveRecord(
                    e_number=code,
                    name=row["name"].strip(),
                    synonyms=_split(row["synonyms"]),
                    category=row["category"].strip(),
                    allergen_tags=_split(row["allergen_tags"]),
                    limits_note=row["limits_note"].strip(),
                    source_doc_id=row["source_doc_id"].strip(),
                    source_locator=row["source_locator"].strip(),
                    chunk_ids=tuple(chunk_index.get((row["source_doc_id"].strip(), code), [])),
                )
            )
    if problems:
        raise AdditiveFileError("; ".join(problems))
    return records
