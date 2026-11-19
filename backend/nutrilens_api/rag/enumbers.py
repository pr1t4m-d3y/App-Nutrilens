"""E-number / INS code extraction and normalisation.

Both "E211" and "INS 211" are normalised to "E211". Sub-letters are kept
("E160a"). The pattern can also match unrelated text such as "vitamin E 100",
so callers treat a match as a lookup key, not as proof that an additive is
present.
"""

from __future__ import annotations

import re

_PATTERN = re.compile(r"\b(?:E|INS)[\s-]?(\d{3,4})([a-i]?)\b", re.IGNORECASE)


def normalise(digits: str, letter: str = "") -> str:
    return f"E{digits}{letter.lower()}"


def extract_e_numbers(text: str) -> list[str]:
    """Unique normalised codes in order of first appearance."""
    seen: dict[str, None] = {}
    for match in _PATTERN.finditer(text):
        seen.setdefault(normalise(match.group(1), match.group(2)), None)
    return list(seen)
