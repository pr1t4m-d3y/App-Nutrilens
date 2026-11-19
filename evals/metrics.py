"""Pure metric functions used by the eval runners and the report generator.

No I/O and no network, so they can be unit tested on their own.
"""

from __future__ import annotations

import math
import re
from collections.abc import Sequence


def normalize(text: str) -> str:
    """Lower-case and collapse whitespace, so layout differences are not errors."""
    return re.sub(r"\s+", " ", text.lower()).strip()


def edit_distance(a: Sequence, b: Sequence) -> int:
    """Levenshtein distance between two sequences."""
    if len(a) < len(b):
        a, b = b, a
    previous = list(range(len(b) + 1))
    for i, item_a in enumerate(a, start=1):
        current = [i]
        for j, item_b in enumerate(b, start=1):
            cost = 0 if item_a == item_b else 1
            current.append(min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost))
        previous = current
    return previous[-1]


def _error_rate(reference: Sequence, hypothesis: Sequence) -> float:
    if not reference:
        return 0.0 if not hypothesis else 1.0
    return edit_distance(reference, hypothesis) / len(reference)


def cer(reference: str, hypothesis: str) -> float:
    """Character error rate on normalised text."""
    return _error_rate(normalize(reference), normalize(hypothesis))


def wer(reference: str, hypothesis: str) -> float:
    """Word error rate on normalised text."""
    return _error_rate(normalize(reference).split(), normalize(hypothesis).split())


def precision_recall(tp: int, fp: int, fn: int) -> tuple[float | None, float | None]:
    """(precision, recall); None where the denominator is zero."""
    precision = tp / (tp + fp) if (tp + fp) else None
    recall = tp / (tp + fn) if (tp + fn) else None
    return precision, recall


def percentile(values: Sequence[float], q: float) -> float:
    """Percentile with linear interpolation. q is 0 to 100."""
    if not values:
        raise ValueError("no values")
    ordered = sorted(values)
    position = (len(ordered) - 1) * q / 100
    low = math.floor(position)
    high = math.ceil(position)
    if low == high:
        return float(ordered[int(position)])
    return ordered[low] * (high - position) + ordered[high] * (position - low)


def latency_summary(values: Sequence[float]) -> dict:
    return {
        "n": len(values),
        "p50": percentile(values, 50),
        "p95": percentile(values, 95),
        "mean": sum(values) / len(values),
        "min": min(values),
        "max": max(values),
    }


def cost(input_tokens: int, output_tokens: int, price_in_per_mtok: float, price_out_per_mtok: float) -> float:
    return (input_tokens * price_in_per_mtok + output_tokens * price_out_per_mtok) / 1_000_000
