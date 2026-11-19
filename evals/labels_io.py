"""Loading and validating ground-truth label files from evals/labels/.

A label is used only if a person reviewed its ground truth (`reviewed_by`).
Unreviewed files are reported and excluded, never silently used.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

# Must match LocalScanner.allergenGroups in lib/services/local_scanner.dart.
ALLERGEN_GROUPS = ("tree nuts", "peanuts", "lactose", "gluten", "soy", "shellfish", "eggs")
SOURCES = ("photographed", "open_food_facts")
IMAGE_SUFFIXES = (".jpg", ".jpeg", ".png", ".webp")


class LabelError(ValueError):
    """One or more label files are malformed. The message lists every problem."""


@dataclass(frozen=True)
class Label:
    id: str
    image: Path | None
    ingredients_text: str
    ingredients: tuple[str, ...]
    allergen_groups: tuple[str, ...]
    source: str
    reviewed_by: str


@dataclass(frozen=True)
class LoadResult:
    labels: list[Label]
    unreviewed: list[str]


def _find_image(json_path: Path) -> Path | None:
    for suffix in IMAGE_SUFFIXES:
        candidate = json_path.with_suffix(suffix)
        if candidate.is_file():
            return candidate
    return None


def load_labels(directory: Path) -> LoadResult:
    if not directory.is_dir():
        return LoadResult([], [])

    labels: list[Label] = []
    unreviewed: list[str] = []
    problems: list[str] = []

    for path in sorted(directory.glob("*.json")):
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            problems.append(f"{path.name}: not valid JSON")
            continue
        if not isinstance(raw, dict):
            problems.append(f"{path.name}: not a JSON object")
            continue

        before = len(problems)
        label_id = raw.get("id")
        text = raw.get("ingredients_text")
        ingredients = raw.get("ingredients")
        groups = raw.get("allergen_groups")
        source = raw.get("source")
        reviewer = raw.get("reviewed_by")

        if not isinstance(label_id, str) or not label_id:
            problems.append(f"{path.name}: id is required")
        if not isinstance(text, str) or not text.strip():
            problems.append(f"{path.name}: ingredients_text is required")
        if not isinstance(ingredients, list) or not all(isinstance(i, str) for i in ingredients):
            problems.append(f"{path.name}: ingredients must be a list of strings")
        if not isinstance(groups, list) or not set(groups) <= set(ALLERGEN_GROUPS):
            problems.append(f"{path.name}: allergen_groups must be a subset of {list(ALLERGEN_GROUPS)}")
        if source not in SOURCES:
            problems.append(f"{path.name}: source must be one of {list(SOURCES)}")
        if len(problems) > before:
            continue

        if not isinstance(reviewer, str) or not reviewer.strip():
            unreviewed.append(path.name)
            continue

        labels.append(
            Label(
                id=label_id,
                image=_find_image(path),
                ingredients_text=text,
                ingredients=tuple(ingredients),
                allergen_groups=tuple(groups),
                source=source,
                reviewed_by=reviewer.strip(),
            )
        )

    if problems:
        raise LabelError("; ".join(problems))
    return LoadResult(labels, unreviewed)
