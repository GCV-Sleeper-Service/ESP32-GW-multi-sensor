#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/config/esp32-gateway"
VERSION="${1:-main}"

cd "$REPO_DIR"

git fetch --all --tags

if git rev-parse "$VERSION" >/dev/null 2>&1; then
  git checkout "$VERSION"
else
  git checkout main
  git pull --ff-only
fi

./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml