"""Measure the cloud path against reviewed labels.

For every reviewed label with an image it records:
- OCR through POST /v1/ocr-fallback: latency, character and word error rate
  against the ground-truth text, token counts;
- explanation through POST /v1/explain, fed the ground-truth text so OCR errors
  do not hide explanation errors: latency, status, number of cited ingredients,
  token counts.

It also writes evals/results/raw/citation_review.csv, one row per cited
ingredient, for a person to mark `supported` or `not_supported`.

The Firebase ID token is read from the environment (NUTRILENS_ID_TOKEN) so it
never appears in shell history or process lists.

    NUTRILENS_ID_TOKEN=... python evals/run_cloud.py --base-url https://... --repeats 3 --note "warm"
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))

from labels_io import load_labels  # noqa: E402
from metrics import cer, wer  # noqa: E402

RAW = Path(__file__).resolve().parent / "results" / "raw"
TIMEOUT_S = 90


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--labels", type=Path, default=Path(__file__).resolve().parent / "labels")
    parser.add_argument("--repeats", type=int, default=1, help="requests per label per endpoint")
    parser.add_argument("--note", default="", help="free text, e.g. 'warm instance' or 'cold start'")
    args = parser.parse_args(argv)

    token = os.environ.get("NUTRILENS_ID_TOKEN", "").strip()
    if not token:
        print("Set NUTRILENS_ID_TOKEN to a current Firebase ID token.", file=sys.stderr)
        return 2

    loaded = load_labels(args.labels)
    if loaded.unreviewed:
        print(f"Skipping {len(loaded.unreviewed)} unreviewed label file(s).", file=sys.stderr)
    labels = [label for label in loaded.labels if label.image is not None]
    if not labels:
        print("No reviewed labels with images. See evals/LABEL_CHECKLIST.md.", file=sys.stderr)
        return 2

    base = args.base_url.rstrip("/")
    headers = {"Authorization": f"Bearer {token}"}
    ocr_rows: list[dict] = []
    explain_rows: list[dict] = []
    review_rows: list[dict] = []
    models: set[str] = set()

    for label in labels:
        image_bytes = label.image.read_bytes()
        for _ in range(args.repeats):
            ocr_rows.append(_ocr_once(base, headers, label.id, image_bytes, label.ingredients_text, models))
            row, citations = _explain_once(base, headers, label.id, label.ingredients_text, models)
            explain_rows.append(row)
        review_rows.extend({"id": label.id, **c, "verdict": ""} for c in citations)

    RAW.mkdir(parents=True, exist_ok=True)
    (RAW / "cloud_ocr.json").write_text(json.dumps(ocr_rows, indent=2), encoding="utf-8")
    (RAW / "cloud_explain.json").write_text(json.dumps(explain_rows, indent=2), encoding="utf-8")
    (RAW / "run_meta.json").write_text(
        json.dumps(
            {
                "date_utc": datetime.now(UTC).isoformat(timespec="seconds"),
                "base_url": base,
                "labels": len(labels),
                "repeats": args.repeats,
                "note": args.note,
                "models": sorted(models),
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    _write_review_sheet(RAW / "citation_review.csv", review_rows)
    print(f"Wrote raw results to {RAW}")
    return 0


def _post(url: str, **kwargs) -> tuple[requests.Response | None, float]:
    start = time.perf_counter()
    try:
        response = requests.post(url, timeout=TIMEOUT_S, **kwargs)
    except requests.RequestException:
        return None, time.perf_counter() - start
    return response, time.perf_counter() - start


def _ocr_once(base, headers, label_id, image_bytes, truth, models) -> dict:
    response, elapsed = _post(
        f"{base}/v1/ocr-fallback",
        headers={**headers, "Content-Type": "application/octet-stream"},
        data=image_bytes,
    )
    row = {"id": label_id, "latency_s": elapsed, "ok": False}
    if response is not None and response.status_code == 200:
        body = response.json()
        usage = body.get("usage", {})
        models.add(str(body.get("model")))
        row.update(
            ok=True,
            cer=cer(truth, body.get("text", "")),
            wer=wer(truth, body.get("text", "")),
            input_tokens=usage.get("input_tokens", 0),
            output_tokens=usage.get("output_tokens", 0),
        )
    else:
        row["status"] = response.status_code if response is not None else "network_error"
    return row


def _explain_once(base, headers, label_id, truth, models) -> tuple[dict, list[dict]]:
    response, elapsed = _post(f"{base}/v1/explain", headers=headers, json={"label_text": truth})
    row = {"id": label_id, "latency_s": elapsed, "ok": False}
    citations: list[dict] = []
    if response is not None and response.status_code == 200:
        body = response.json()
        usage = body.get("usage", {})
        models.add(str(body.get("model")))
        ingredients = body.get("ingredients", [])
        row.update(
            ok=True,
            status=body.get("status"),
            n_ingredients=len(ingredients),
            timings_ms=body.get("timings_ms"),
            input_tokens=usage.get("input_tokens", 0),
            output_tokens=usage.get("output_tokens", 0),
        )
        for item in ingredients:
            details = item.get("details", [])
            citations.append(
                {
                    "ingredient": item.get("name", ""),
                    "claim": details[0] if details else "",
                    "cited": "; ".join(d for d in details if d.startswith("Source: ")),
                }
            )
    else:
        row["status"] = response.status_code if response is not None else "network_error"
    return row, citations


def _write_review_sheet(path: Path, rows: list[dict]) -> None:
    """Never overwrite a sheet a person has already started filling in."""
    started = False
    if path.exists():
        with path.open(encoding="utf-8") as handle:
            started = any(row.get("verdict") for row in csv.DictReader(handle))
    if started:
        print(f"{path.name} already has verdicts; not overwritten. New rows saved as {path.stem}.new.csv")
        path = path.with_name(f"{path.stem}.new.csv")
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["id", "ingredient", "claim", "cited", "verdict"])
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    raise SystemExit(main())
