#!/usr/bin/env bash
# Report release APK / AAB sizes so a size claim can be reproduced.
#
#   bash scripts/app_size.sh --label "baseline"          # build, then report
#   bash scripts/app_size.sh --label "after-abi-split" --no-build   # report existing outputs
#
# Every run appends rows to docs/size_log.csv with the date, git commit and
# label, so before/after comparisons come from recorded builds only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/docs/size_log.csv"
LABEL=""
BUILD=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) LABEL="${2:?--label needs a value}"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$LABEL" ]] || { echo "Pass --label <name> so the run can be identified later." >&2; exit 2; }

cd "$ROOT"

DEFINES=()
if [[ -f app_config.json ]]; then
  DEFINES=(--dart-define-from-file=app_config.json)
fi

if [[ "$BUILD" -eq 1 ]]; then
  flutter build apk --release --split-per-abi ${DEFINES[@]+"${DEFINES[@]}"}
  flutter build apk --release ${DEFINES[@]+"${DEFINES[@]}"}
  flutter build appbundle --release ${DEFINES[@]+"${DEFINES[@]}"}
fi

COMMIT="$(git rev-parse --short HEAD)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
[[ -f "$LOG" ]] || echo "date,commit,label,artifact,bytes" > "$LOG"

found=0
printf '%-60s %12s %10s\n' "artifact" "bytes" "MiB"
for file in build/app/outputs/flutter-apk/*.apk build/app/outputs/bundle/release/*.aab; do
  [[ -f "$file" ]] || continue
  bytes="$(wc -c < "$file" | tr -d ' ')"
  mib="$(awk -v b="$bytes" 'BEGIN { printf "%.2f", b / 1048576 }')"
  printf '%-60s %12s %10s\n' "$file" "$bytes" "$mib"
  echo "$DATE,$COMMIT,$LABEL,$file,$bytes" >> "$LOG"
  found=1
done

if [[ "$found" -eq 0 ]]; then
  echo "No APK or AAB found under build/app/outputs. Build first (omit --no-build)." >&2
  exit 1
fi
