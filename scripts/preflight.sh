#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VER_RAW="$(tr -d '[:space:]' < VERSION)"
VER_TAG="v${VER_RAW#v}"

pass() { echo "$1: PASS"; }
fail() { echo "$1: FAIL"; exit 1; }
check_contains() {
  local label="$1" file="$2" needle="$3"
  grep -Fq -- "$needle" "$file" && pass "$label" || fail "$label"
}
check_not_contains() {
  local label="$1" file="$2" needle="$3"
  grep -Fq -- "$needle" "$file" && fail "$label" || pass "$label"
}

REQUIRED_FILES=(
  VERSION
  config/sensors.json
  dashboard/dashboard.html
  dashboard/dashboard.js
  dashboard/dashboard.h
  dashboard/sensor_history_multi.h
  dashboard/gateway_manifest.h
  firmware/esp32-c3-multi-sensor.yaml
  scripts/render_sensor_config.py
  scripts/sensor_manifest_lib.py
  scripts/generate-header.sh
  tests/mock-server/server.js
  tests/fixtures/generate-fixtures.js
  tests/fixtures/sensors.json
  tests/fixtures/manifest.json
  tests/browser/manifest.spec.js
  Docs/changelog.md
  Docs/bugs-and-lessons-learned.md
)

for f in "${REQUIRED_FILES[@]}"; do
  [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done

check_contains "version_file_present" VERSION "${VER_RAW}"
check_contains "dashboard_js_version_matches" dashboard/dashboard.js "App.version = '${VER_TAG}'"
check_contains "firmware_version_matches" firmware/esp32-c3-multi-sensor.yaml "${VER_TAG}"
check_contains "history_header_version_matches" dashboard/sensor_history_multi.h "sensor_history_multi-${VER_TAG}.h"
check_contains "history_handler_has_api_manifest_route" dashboard/sensor_history_multi.h "/api/manifest"
check_contains "gateway_manifest_h_exists" dashboard/gateway_manifest.h "GATEWAY_MANIFEST_JSON"
check_contains "dashboard_prefers_api_manifest" dashboard/dashboard.js "fetch(ESP_HOST + '/api/manifest'"
check_contains "dashboard_legacy_manifest_fallback" dashboard/dashboard.js "fetch(ESP_HOST + '/sensors.json'"
check_contains "mock_server_serves_api_manifest" tests/mock-server/server.js "pathname === '/api/manifest'"
check_contains "fixture_manifest_schema_v2" tests/fixtures/manifest.json '"schema_version": 2'
check_contains "fixture_manifest_sensor_count" tests/fixtures/manifest.json '"sensor_count": 3'
check_contains "fixture_manifest_has_gateway_block" tests/fixtures/manifest.json '"gateway"'
check_contains "fixture_manifest_has_history_block" tests/fixtures/manifest.json '"history"'
check_contains "fixture_manifest_has_measurements" tests/fixtures/manifest.json '"measurements"'
check_contains "browser_spec_present" tests/browser/manifest.spec.js "dashboard falls back to /sensors.json"
check_not_contains "no_old_dashboard_version" dashboard/dashboard.js "App.version = 'v7.4.5.1'"
check_not_contains "no_old_firmware_version" firmware/esp32-c3-multi-sensor.yaml "v7.4.5.1"

# Regenerate baseline fixtures from config — must happen BEFORE render_sensor_config --check
# so that --check validates Python and JS generators produce byte-identical output.
if command -v node >/dev/null 2>&1; then
  node tests/fixtures/generate-fixtures.js --manifest config/sensors.json --overwrite-baseline >/dev/null
  pass "fixture_baseline_regenerated"
else
  echo "fixture_baseline_regenerated: SKIP (node unavailable)"
fi

# Idempotence check: --write followed by --check must pass
python3 scripts/render_sensor_config.py --write >/dev/null
python3 scripts/render_sensor_config.py --check

if command -v node >/dev/null 2>&1; then
  if [[ -d node_modules/@playwright/test ]]; then
    npx playwright test tests/browser/manifest.spec.js --project=chromium >/dev/null
    pass "playwright_manifest_spec"
  else
    echo "playwright_manifest_spec: SKIP (node_modules missing)"
  fi
else
  echo "playwright_manifest_spec: SKIP (node unavailable)"
fi
