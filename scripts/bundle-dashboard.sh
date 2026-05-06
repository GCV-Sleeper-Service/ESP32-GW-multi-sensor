#!/usr/bin/env bash
# Concatenates dashboard/core/*.js + dashboard/components/*/index.js in dependency order → dashboard/dashboard.js
# Usage: bundle-dashboard.sh [--write|--check]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FILES=(
  dashboard/core/app-shell.js            # was 00-app-shell
  dashboard/core/config.js               # was 01-config-state
  dashboard/core/auth.js                 # auth state + authenticated fetch wrapper
  dashboard/core/sensor-defs.js          # was 02-sensor-defs
  dashboard/core/history.js              # was 03-history-fetch
  dashboard/core/manifest.js             # was 04-manifest
  dashboard/core/status-snapshot.js      # was 05-status-snapshot
  dashboard/core/ui-helpers.js           # was 06-ui-helpers
  dashboard/core/staleness-derived.js    # was 07-staleness-derived
  dashboard/components/custom-range/index.js    # was 08-custom-range
  dashboard/components/settings-panel/index.js  # was 09+10 (export+storage)
  dashboard/core/suspend-resume.js       # was 11-suspend-resume
  dashboard/components/auth-modal/index.js      # was 12-management
  dashboard/components/import-panel/index.js    # was 13-import
  dashboard/components/sensor-cards/index.js    # was 14+15 (cards+minmax)
  dashboard/components/charts/index.js          # was 16-charts
  dashboard/components/live-view/index.js       # was 17+18 (live-updates+transport)
  dashboard/components/gateway-panel/index.js   # was 19-aggregator
  dashboard/core/boot.js                        # was 20-boot
)

OUT="dashboard/dashboard.js"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

for src in "${FILES[@]}"; do
  [[ -f "$src" ]] || { echo "MISSING: $src"; exit 1; }
  cat "$src" >> "$TMP"
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

# Strip all SENSOR_MANIFEST marker blocks (begin..end inclusive) from a file.
# render_sensor_config.py legitimately post-modifies these blocks after bundling,
# so the --check diff must ignore them to avoid false failures.
strip_manifest_blocks() {
  python3 - "$1" <<'PYEOF'
import re, sys
text = open(sys.argv[1]).read()
text = re.sub(
    r'// <<< SENSOR_MANIFEST:[A-Z_]+_BEGIN >>>.*?// <<< SENSOR_MANIFEST:[A-Z_]+_END >>>',
    '',
    text,
    flags=re.S
)
print(text, end='')
PYEOF
}

if [[ "$MODE" == "--check" ]]; then
  TMP_STRIPPED=$(mktemp)
  OUT_STRIPPED=$(mktemp)
  trap 'rm -f "$TMP" "$TMP_STRIPPED" "$OUT_STRIPPED"' EXIT
  strip_manifest_blocks "$TMP" > "$TMP_STRIPPED"
  strip_manifest_blocks "$OUT" > "$OUT_STRIPPED"
  if diff -q "$TMP_STRIPPED" "$OUT_STRIPPED" >/dev/null 2>&1; then
    echo "OK: dashboard.js matches source modules"
  else
    echo "FAIL: dashboard.js is out of sync with source modules"
    diff "$TMP_STRIPPED" "$OUT_STRIPPED" | head -20
    exit 1
  fi
else
  cp "$TMP" "$OUT"
  echo "Bundled ${#FILES[@]} modules → $OUT ($(wc -c < "$OUT") bytes)"
fi
