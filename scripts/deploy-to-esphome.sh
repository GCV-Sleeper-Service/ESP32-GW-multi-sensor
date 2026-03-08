#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION_REF="${1:-main}"

if [[ "$VERSION_REF" != "main" ]]; then
  git fetch --all --tags
  if git rev-parse "$VERSION_REF" >/dev/null 2>&1; then
    git checkout "$VERSION_REF"
  else
    echo "Git ref not found: $VERSION_REF" >&2
    exit 1
  fi
else
  git checkout main
  git pull --ff-only
fi

./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
