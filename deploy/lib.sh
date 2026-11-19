#!/usr/bin/env bash
# Shared helpers, sourced by the other scripts.
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$DEPLOY_DIR/config.env}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing $CONFIG_FILE. Copy deploy/config.example.env to deploy/config.env and fill it in." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG_FILE"

require() {
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      echo "Set $name in $CONFIG_FILE" >&2
      exit 1
    fi
  done
}

SERVICE_ACCOUNT="${SERVICE_ACCOUNT_NAME:-nutrilens-api}@${PROJECT_ID:-}.iam.gserviceaccount.com"
IMAGE="${REGION:-}-docker.pkg.dev/${PROJECT_ID:-}/${REPO:-nutrilens}/${SERVICE:-nutrilens-api}"
