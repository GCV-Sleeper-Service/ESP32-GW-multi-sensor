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
  firmware/esp32-c3-multi-sensor.yaml
  scripts/apply_phase1_manifest_patch.py
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
  src/gateway_manifest.h
)

for f in "${REQUIRED_FILES[@]}"; do
  [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done

check_contains "version_file_present" VERSION "${VER_RAW}"
check_contains "dashboard_js_version_matches" dashboard/dashboard.js "App.version = '${VER_TAG}'"
check_contains "firmware_version_matches" firmware/esp32-c3-multi-sensor.yaml "${VER_TAG}"
check_contains "history_header_version_matches" dashboard/sensor_history_multi.h "sensor_history_multi-${VER_TAG}.h"
check_contains "history_handler_has_api_manifest_route" dashboard/sensor_history_multi.h "/api/manifest"
check_contains "dashboard_prefers_api_manifest" dashboard/dashboard.js "fetch(ESP_HOST + '/api/manifest'"
check_contains "dashboard_legacy_manifest_fallback" dashboard/dashboard.js "fetch(ESP_HOST + '/sensors.json'"
check_contains "mock_server_serves_api_manifest" tests/mock-server/server.js "pathname === '/api/manifest'"
check_contains "fixture_manifest_schema_v2" tests/fixtures/manifest.json '"schema_version": 2'
check_contains "fixture_manifest_sensor_count" tests/fixtures/manifest.json '"sensor_count": 3'
check_contains "browser_spec_present" tests/browser/manifest.spec.js "dashboard falls back to /sensors.json"
check_not_contains "no_old_dashboard_version" dashboard/dashboard.js "App.version = 'v7.4.5.1'"
check_not_contains "no_old_firmware_version" firmware/esp32-c3-multi-sensor.yaml "v7.4.5.1"

echo "→ Checking gateway_manifest.h exists and is included..."
if ! grep -q '#include "gateway_manifest.h"' dashboard/sensor_history_multi.h; then
  echo "✗ sensor_history_multi.h missing #include \"gateway_manifest.h\""
  fail "gateway_manifest_h_included"
else
  pass "gateway_manifest_h_included"
fi
check_contains "gateway_manifest_json_used" dashboard/sensor_history_multi.h "GATEWAY_MANIFEST_JSON"
check_contains "gateway_manifest_yaml_includes" firmware/esp32-c3-multi-sensor.yaml "../src/gateway_manifest.h"

FAIL_COUNT=0

echo "→ Validating manifest v2 schema structure..."

# Extract the JSON from gateway_manifest.h (skip C++ wrapper, get raw JSON)
MANIFEST_JSON=$(sed -n '/R"MANIFEST(/,/)MANIFEST"/p' src/gateway_manifest.h | sed '1d;$d')

# Check if extraction succeeded
if [[ -z "$MANIFEST_JSON" ]]; then
  echo "✗ Failed to extract JSON from gateway_manifest.h"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  # Validate required top-level fields
  for field in "schema_version" "gateway" "history" "sensor_count" "metrics" "sensors"; do
    if ! echo "$MANIFEST_JSON" | grep -q "\"$field\""; then
      echo "✗ Manifest missing required field: $field"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done

  # Validate gateway block required fields
  for field in "id" "name" "role" "hardware" "firmware_version" "api_version"; do
    if ! echo "$MANIFEST_JSON" | sed -n '/"gateway"/,/}/p' | grep -q "\"$field\""; then
      echo "✗ Manifest gateway block missing required field: $field"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done

  # Validate history block required fields
  for field in "backend" "retention_hours" "ram_window_hours" "sample_interval_seconds"; do
    if ! echo "$MANIFEST_JSON" | sed -n '/"history"/,/}/p' | grep -q "\"$field\""; then
      echo "✗ Manifest history block missing required field: $field"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  done

  # Validate metrics array has required fields (check first metric as representative)
  if ! echo "$MANIFEST_JSON" | grep -q '"metrics"'; then
    echo "✗ Manifest missing metrics array"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    # Check that metrics array contains expected fields
    METRICS_BLOCK=$(echo "$MANIFEST_JSON" | sed -n '/"metrics"/,/]/p')
    for field in "key" "name" "unit" "class" "data_type" "history"; do
      if ! echo "$METRICS_BLOCK" | grep -q "\"$field\""; then
        echo "✗ Manifest metrics missing required field: $field"
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
    done
  fi

  # Validate schema_version is 2
  SCHEMA_VERSION=$(echo "$MANIFEST_JSON" | grep -o '"schema_version"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
  if [[ "$SCHEMA_VERSION" != "2" ]]; then
    echo "✗ Manifest schema_version is $SCHEMA_VERSION, expected 2"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    echo "✓ Manifest v2 schema validation passed"
  fi
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "✗ Manifest v2 schema validation failed with $FAIL_COUNT error(s)"
  exit 1
fi

python3 scripts/render_sensor_config.py --check
node tests/fixtures/generate-fixtures.js --manifest config/sensors.json --overwrite-baseline >/dev/null
check_contains "fixture_baseline_manifest_regenerated" tests/fixtures/manifest.json '"schema_version": 2'

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
