"""Export the structured additive table to the app's on-device asset.

    python -m nutrilens_api.rag.export_additives \\
        --csv ../data/additives.csv \\
        --manifest ../data/regulations/manifest.json \\
        --out ../assets/additives/additives.json

The phone and the cloud therefore read the same source file, so the offline
and online answers cannot drift apart. Each entry carries a ready-to-show
citation built from the manifest's document title and the row's locator.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .additive_rows import AdditiveRow, parse_rows
from .ingest import load_manifest


def build_entries(rows: list[AdditiveRow], titles: dict[str, str]) -> list[dict]:
    return [
        {
            "e_number": row.e_number,
            "name": row.name,
            "synonyms": list(row.synonyms),
            "category": row.category,
            "allergen_tags": list(row.allergen_tags),
            "limits_note": row.limits_note,
            "citation": f"{titles[row.source_doc_id]}, {row.source_locator}",
        }
        for row in rows
    ]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Export additives for the app")
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)

    manifest = load_manifest(args.manifest)
    titles = {entry["id"]: entry["title"] for entry in manifest}
    rows = parse_rows(args.csv, set(titles))
    entries = build_entries(rows, titles)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(entries, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {len(entries)} additives to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
