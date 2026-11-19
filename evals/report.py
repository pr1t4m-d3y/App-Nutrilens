"""Generate evals/results/RESULTS.md from raw results. Never edit RESULTS.md by hand.

Every number in the report is computed here from files in evals/results/raw/.
A section whose raw input is missing says so. The report records the git
commit, the date and what produced each input.

    python evals/report.py [--price-in 0.0 --price-out 0.0 --price-date YYYY-MM-DD]

Prices are per million tokens, copied by the operator from the current Google
Cloud price list for the models named in run_meta.json. Without them no cost is
reported.
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from labels_io import load_labels  # noqa: E402
from metrics import cer, cost, latency_summary, precision_recall, wer  # noqa: E402

HERE = Path(__file__).resolve().parent
RAW = HERE / "results" / "raw"
OUT = HERE / "results" / "RESULTS.md"


def _load(name: str):
    path = RAW / name
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else None


def _pct(value: float | None) -> str:
    return "n/a" if value is None else f"{value * 100:.1f}%"


def _mean(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def _git_commit() -> str:
    try:
        return subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True, cwd=HERE
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def section_dataset() -> list[str]:
    loaded = load_labels(HERE / "labels")
    by_source: dict[str, int] = {}
    for label in loaded.labels:
        by_source[label.source] = by_source.get(label.source, 0) + 1
    reviewers = sorted({label.reviewed_by for label in loaded.labels})
    lines = ["## Dataset", ""]
    lines.append(f"- Reviewed labels used: **{len(loaded.labels)}**")
    lines.append(f"- Excluded as unreviewed: {len(loaded.unreviewed)}")
    for source, count in sorted(by_source.items()):
        lines.append(f"- Source `{source}`: {count}")
    lines.append(f"- Ground truth reviewed by: {', '.join(reviewers) if reviewers else 'n/a'}")
    return lines + [""]


def section_ocr() -> list[str]:
    lines = ["## OCR accuracy", ""]
    gemini = _load("cloud_ocr.json")
    mlkit = _load("mlkit_ocr.json")
    lines += ["| Engine | Labels | Mean CER | Mean WER |", "|---|---|---|---|"]
    if gemini:
        ok = [r for r in gemini if r.get("ok")]
        failed = len(gemini) - len(ok)
        lines.append(
            f"| Gemini vision (cloud) | {len(ok)} ok, {failed} failed | "
            f"{_pct(_mean([r['cer'] for r in ok]))} | {_pct(_mean([r['wer'] for r in ok]))} |"
        )
    else:
        lines.append("| Gemini vision (cloud) | no data | n/a | n/a |")
    truth = {label.id: label.ingredients_text for label in load_labels(HERE / "labels").labels}
    scored = [r for r in (mlkit or []) if r.get("id") in truth]
    if scored:
        lines.append(
            f"| ML Kit (on device, after the app's sanitiser) | {len(scored)} | "
            f"{_pct(_mean([cer(truth[r['id']], r['text']) for r in scored]))} | "
            f"{_pct(_mean([wer(truth[r['id']], r['text']) for r in scored]))} |"
        )
    elif mlkit:
        lines.append("| ML Kit (on device) | export found, but no ids match reviewed labels | n/a | n/a |")
    else:
        lines.append(
            "| ML Kit (on device) | no data (`integration_test/ocr_export_test.dart` produces it) | n/a | n/a |"
        )
    return lines + ["", "CER/WER are edit distance over normalised text; lower is better.", ""]


def section_local() -> list[str]:
    data = _load("local_engine.json")
    lines = ["## On-device engine", ""]
    if not data:
        return lines + ["No data (`flutter test test/eval` writes `local_engine.json`).", ""]

    p = data["parser"]
    precision, recall = precision_recall(p["tp"], p["fp"], p["fn"])
    lines += [
        "### Ingredient parsing (ground-truth text in, ingredient list out)",
        "",
        f"- Labels: {data['n_labels']}; exact list matches: {p['labels_exact_match']}",
        f"- Precision {_pct(precision)}, recall {_pct(recall)} (TP {p['tp']}, FP {p['fp']}, FN {p['fn']})",
        "",
        "### Allergen detection by group",
        "",
        "| Group | TP | FP | FN | TN | Precision | Recall |",
        "|---|---|---|---|---|---|---|",
    ]
    totals = {"tp": 0, "fp": 0, "fn": 0}
    for group, c in data["groups"].items():
        pr, rc = precision_recall(c["tp"], c["fp"], c["fn"])
        lines.append(f"| {group} | {c['tp']} | {c['fp']} | {c['fn']} | {c['tn']} | {_pct(pr)} | {_pct(rc)} |")
        for key in totals:
            totals[key] += c[key]
    pr, rc = precision_recall(totals["tp"], totals["fp"], totals["fn"])
    lines.append(
        f"| **all** | {totals['tp']} | {totals['fp']} | {totals['fn']} | | **{_pct(pr)}** | **{_pct(rc)}** |"
    )

    lines += ["", "### Missed allergens (false negatives)", ""]
    if data["false_negatives"]:
        lines += [f"- `{r['id']}`: {r['group']}" for r in data["false_negatives"]]
    else:
        lines.append("None in this label set.")
    lines += ["", "### False alarms (false positives)", ""]
    if data["false_positives"]:
        lines += [f"- `{r['id']}`: {r['group']} (matched: {r['matched']})" for r in data["false_positives"]]
    else:
        lines.append("None in this label set.")
    return lines + [""]


def _citation_block(label: str, path: Path) -> list[str]:
    if not path.is_file():
        return [f"**{label}:** no data.", ""]
    with path.open(encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    supported = sum(1 for r in rows if r["verdict"].strip() == "supported")
    unsupported = sum(1 for r in rows if r["verdict"].strip() == "not_supported")
    pending = len(rows) - supported - unsupported
    judged = supported + unsupported
    return [
        f"**{label}**",
        "",
        f"- Cited statements: {len(rows)}",
        f"- Reviewed by a person: {judged} (supported {supported}, not supported {unsupported})",
        f"- Still to review: {pending}",
        f"- Citation correctness over reviewed rows: {_pct(supported / judged if judged else None)}",
        "",
    ]


def section_citations() -> list[str]:
    lines = ["## Citation correctness", ""]
    lines += _citation_block("Single-pass (/v1/explain)", RAW / "citation_review.csv")
    lines += _citation_block("Multi-agent (/v1/analyze)", RAW / "citation_review_analyze.csv")
    return lines


def section_cloud(price_in: float | None, price_out: float | None, price_date: str | None) -> list[str]:
    lines = ["## Cloud latency and cost", ""]
    paths = {
        "/v1/ocr-fallback": _load("cloud_ocr.json"),
        "/v1/explain": _load("cloud_explain.json"),
        "/v1/analyze": _load("cloud_analyze.json"),
    }
    meta = _load("run_meta.json")
    if not any(paths.values()):
        return lines + ["No data (`python evals/run_cloud.py` writes it).", ""]
    if meta:
        lines += [
            f"- Last run: {meta['date_utc']}, `{meta['base_url']}`, {meta['labels']} labels x "
            f"{meta['repeats']} repeats, endpoint `{meta.get('endpoint', 'explain')}`",
            f"- Instance state note: {meta['note'] or '(none recorded)'}",
            f"- Models seen: {', '.join(meta['models']) or 'n/a'}",
            "",
        ]
    lines += ["| Endpoint | n | p50 (s) | p95 (s) | Mean tokens in | Mean tokens out |", "|---|---|---|---|---|---|"]
    tokens: dict[str, tuple[float, float]] = {}
    for name, rows in paths.items():
        if rows is None:
            lines.append(f"| {name} | no data | n/a | n/a | n/a | n/a |")
            continue
        ok = [r for r in rows if r.get("ok")]
        if not ok:
            lines.append(f"| {name} | 0 | n/a | n/a | n/a | n/a |")
            continue
        summary = latency_summary([r["latency_s"] for r in ok])
        mean_in = _mean([r["input_tokens"] for r in ok]) or 0.0
        mean_out = _mean([r["output_tokens"] for r in ok]) or 0.0
        tokens[name] = (mean_in, mean_out)
        lines.append(
            f"| {name} | {summary['n']} | {summary['p50']:.2f} | {summary['p95']:.2f} | "
            f"{mean_in:.0f} | {mean_out:.0f} |"
        )
    lines.append("")

    stages = [r["timings_ms"] for r in (paths["/v1/explain"] or []) if r.get("ok") and r.get("timings_ms")]
    if stages:
        lines += [
            f"Mean /v1/explain stage time: retrieval {_mean([s['retrieval'] for s in stages]):.0f} ms, "
            f"generation {_mean([s['generation'] for s in stages]):.0f} ms (n={len(stages)}).",
            "",
        ]

    agent_rows = [r["agents"] for r in (paths["/v1/analyze"] or []) if r.get("ok") and r.get("agents")]
    if agent_rows:
        per_agent: dict[str, list[dict]] = {}
        for entry in agent_rows:
            for stage in entry["stages"]:
                per_agent.setdefault(stage["agent"], []).append(stage)
        lines += [
            "Multi-agent breakdown (means over the multi-agent runs):",
            "",
            "| Agent | Mean seconds | Mean tokens in | Mean tokens out |",
            "|---|---|---|---|",
        ]
        for agent, items in per_agent.items():
            lines.append(
                f"| {agent} | {_mean([i['seconds'] for i in items]):.2f} | "
                f"{_mean([i['input_tokens'] for i in items]):.0f} | {_mean([i['output_tokens'] for i in items]):.0f} |"
            )
        lines += [
            "",
            f"Mean regulation searches per run: {_mean([e['searches'] for e in agent_rows]):.1f}; "
            f"findings rejected by the verifier: {_mean([e['unsupported_dropped'] for e in agent_rows]):.1f}; "
            f"dropped for missing citations: {_mean([e['uncited_dropped'] for e in agent_rows]):.1f}.",
            "",
        ]

    if price_in is None or price_out is None:
        return lines + ["Cost per scan: not computed (no prices supplied).", ""]
    when = price_date or "unspecified date"
    for label, needed in (
        ("Single-pass scan (cloud OCR + explain)", ("/v1/ocr-fallback", "/v1/explain")),
        ("Multi-agent scan (cloud OCR + analyze)", ("/v1/ocr-fallback", "/v1/analyze")),
    ):
        if all(name in tokens for name in needed):
            total = sum(cost(round(tokens[n][0]), round(tokens[n][1]), price_in, price_out) for n in needed)
            lines.append(
                f"- {label}: **{total:.6f}** in the currency of the supplied prices (input {price_in}, output "
                f"{price_out} per million tokens, as of {when}). One price pair is applied to every model, so a "
                "cheaper light model makes the multi-agent figure an upper bound."
            )
    return lines + [""]


def section_safety() -> list[str]:
    lines = ["## Safety and API contract", ""]
    cases = _load("safety.json")
    if not cases:
        return lines + ["No data (`python evals/run_safety.py` writes it).", ""]
    passed = sum(1 for c in cases if c["passed"])
    lines += [
        f"{passed} of {len(cases)} cases behaved as designed.",
        "",
        "| Case | Expected | Observed | Result |",
        "|---|---|---|---|",
    ]
    for case in cases:
        note = f" ({case['note']})" if case.get("note") else ""
        result = "pass" if case["passed"] else "**FAIL**"
        lines.append(f"| {case['case']} | {case['expected']} | {case['observed']}{note} | {result} |")
    return lines + [""]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--price-in", type=float)
    parser.add_argument("--price-out", type=float)
    parser.add_argument("--price-date")
    args = parser.parse_args(argv)

    lines = [
        "# Eval results",
        "",
        "> Generated by `evals/report.py` from `evals/results/raw/`. Do not edit by hand.",
        "",
        f"- Generated: {datetime.now(UTC).isoformat(timespec='seconds')}",
        f"- Git commit: `{_git_commit()}`",
        "",
    ]
    lines += section_dataset()
    lines += section_ocr()
    lines += section_local()
    lines += section_citations()
    lines += section_cloud(args.price_in, args.price_out, args.price_date)
    lines += section_safety()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
