#!/usr/bin/env bash
# Concatenates dashboard/src/*.js in dependency order → dashboard/dashboard.js
# Usage: bundle-dashboard.sh [--write|--check]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODULES=(
  00-app-shell
  01-config-state
  02-sensor-defs
  03-history-fetch
  04-manifest
  05-status-snapshot
  06-ui-helpers
  07-staleness-derived
  08-custom-range
  09-export
  10-storage-stats
  11-suspend-resume
  12-management
  13-import
  14-cards
  15-minmax
  16-charts
  17-live-updates
  18-transport
  19-aggregator
  20-boot
)

OUT="dashboard/dashboard.js"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

for mod in "${MODULES[@]}"; do
  SRC="dashboard/src/${mod}.js"
  [[ -f "$SRC" ]] || { echo "MISSING: $SRC"; exit 1; }
  cat "$SRC" >> "$TMP"
done

usage() {
  echo "Usage: $(basename "$0") [--write|--check]"
  exit 1
}

if [[ "$#" -gt 1 ]]; then
  usage
fi

MODE="${1:---write}"
case "$MODE" in
  --write|--check) ;;
  -h|--help) usage ;;
  *) usage ;;
esac

if [[ "$MODE" == "--check" ]]; then
  if diff -q "$TMP" "$OUT" >/dev/null 2>&1; then
    echo "OK: dashboard.js matches source modules"
  else
    echo "FAIL: dashboard.js is out of sync with source modules"
    diff "$TMP" "$OUT" | head -20
    exit 1
  fi
else
  cp "$TMP" "$OUT"
  echo "Bundled ${#MODULES[@]} modules → $OUT ($(wc -c < "$OUT") bytes)"
fi
