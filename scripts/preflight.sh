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
check_contains_regex() {
  local label="$1" file="$2" pattern="$3"
  grep -Eq -- "$pattern" "$file" && pass "$label" || fail "$label"
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
  scripts/bump-version.sh
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
# dashboard.h is now gzip-compressed binary data; version appears in the header comment
# as "Dashboard version: App.version = 'vX.Y.Z.W'"
check_contains_regex "dashboard_h_version_matches" dashboard/dashboard.h "Dashboard version:.*${VER_TAG}"
# BUG-043: verify dashboard.h uses gzip format (not raw string literal)
check_contains "dashboard_h_gzip_format" dashboard/dashboard.h "DASHBOARD_HTML_GZ"
check_not_contains "dashboard_h_no_raw_literal" dashboard/dashboard.h "R\"DASH64("
check_contains "firmware_version_matches" firmware/esp32-c3-multi-sensor.yaml "${VER_TAG}"
check_contains "history_header_version_matches" dashboard/sensor_history_multi.h "sensor_history_multi-${VER_TAG}.h"
check_contains "history_handler_has_api_manifest_route" dashboard/sensor_history_multi.h "/api/manifest"
check_contains "history_handler_has_api_v2_live_route" dashboard/sensor_history_multi.h "/api/v2/live"
check_contains "history_handler_has_api_v2_history_route" dashboard/sensor_history_multi.h "/api/v2/history/"
check_contains "dashboard_prefers_api_manifest" dashboard/dashboard.js "fetch(ESP_HOST + '/api/manifest'"
check_contains "dashboard_legacy_manifest_fallback" dashboard/dashboard.js "fetch(ESP_HOST + '/sensors.json'"
check_contains "mock_server_serves_api_manifest" tests/mock-server/server.js "pathname === '/api/manifest'"
check_contains "fixture_manifest_schema_v2" tests/fixtures/manifest.json '"schema_version": 2'
check_contains "fixture_manifest_sensor_count" tests/fixtures/manifest.json '"sensor_count": 4'
check_contains "browser_spec_present" tests/browser/manifest.spec.js "dashboard falls back to /sensors.json"
check_not_contains "no_old_dashboard_version" dashboard/dashboard.js "App.version = 'v7.4.5.1'"
check_not_contains "no_old_firmware_version" firmware/esp32-c3-multi-sensor.yaml "v7.4.5.1"

echo "→ Checking render_sensor_config.py version sync..."
RENDER_PY_VERSION=$(grep -oP '^VERSION = "\K[^"]+' scripts/render_sensor_config.py || true)
if [[ "$VER_RAW" != "$RENDER_PY_VERSION" ]]; then
  echo "✗ scripts/render_sensor_config.py VERSION (${RENDER_PY_VERSION}) does not match canonical VERSION (${VER_RAW})"
  fail "render_sensor_config_py_version_sync"
else
  pass "render_sensor_config_py_version_sync"
fi

echo "→ Checking fixture generator version sync..."
FIXTURE_VERSION=$(grep -oP "const VERSION = 'v\K[^']+" tests/fixtures/generate-fixtures.js || true)
if [[ "$VER_RAW" != "$FIXTURE_VERSION" ]]; then
  echo "✗ Fixture generator VERSION (v${FIXTURE_VERSION}) does not match canonical VERSION (${VER_RAW})"
  fail "fixture_generator_version_sync"
else
  pass "fixture_generator_version_sync"
fi

echo "→ Checking gateway_manifest.h exists and is included..."
if ! grep -q '#include "gateway_manifest.h"' dashboard/sensor_history_multi.h; then
  echo "✗ sensor_history_multi.h missing #include \"gateway_manifest.h\""
  fail "gateway_manifest_h_included"
else
  pass "gateway_manifest_h_included"
fi
check_contains "gateway_manifest_json_used" dashboard/sensor_history_multi.h "GATEWAY_MANIFEST_JSON"
check_contains "gateway_manifest_yaml_includes" firmware/esp32-c3-multi-sensor.yaml "../src/gateway_manifest.h"

# BUG-043: verify dashboard.html has inline favicon to prevent browser /favicon.ico request
check_contains "dashboard_inline_favicon" dashboard/dashboard.html 'rel="icon" href="data:,'
# BUG-043: verify firmware serves gzip with Content-Encoding header
check_contains "firmware_gzip_content_encoding" dashboard/sensor_history_multi.h 'Content-Encoding", "gzip'

FAIL_COUNT=0

# BUG-043: dashboard.h size guard — gzip format should produce <300KB C source
# (which embeds ~45KB of gzip data). If this exceeds 400KB, someone likely
# reverted to the raw string literal format.
DASH_H_SIZE=$(wc -c < dashboard/dashboard.h)
if [[ "$DASH_H_SIZE" -gt 400000 ]]; then
  echo "✗ dashboard_h_size_guard: FAIL — dashboard.h is ${DASH_H_SIZE} bytes (max 400000)"
  echo "  This likely means generate-header.sh reverted to uncompressed format."
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "dashboard_h_size_guard: OK (${DASH_H_SIZE} bytes)"
fi

# ── BUG-043 Preflight Enhancements ──────────────────────────────────────────

# BUG-043 / LESSON-OPS-056: history handler must use pre-reserved string, not beginResponseStream
if grep -n 'beginResponseStream.*text/plain' dashboard/sensor_history_multi.h | grep -v '^\s*//' | grep -q .; then
  echo "✗ no_streaming_history_response: FAIL — handle_history_ must use pre-reserved string, not beginResponseStream"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "no_streaming_history_response: OK"
fi

# BUG-043 / LESSON-OPS-053: NVS scan loops must have yield calls
NVS_YIELD_COUNT=$(grep -c 'maybe_yield_nvs_scan_' dashboard/sensor_history_multi.h || true)
if [[ "$NVS_YIELD_COUNT" -ge 3 ]]; then
  echo "nvs_yield_present: OK (${NVS_YIELD_COUNT} yield calls)"
else
  echo "✗ nvs_yield_present: FAIL — expected 3+ calls to maybe_yield_nvs_scan_ in sensor_history_multi.h (found ${NVS_YIELD_COUNT})"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# BUG-043 / LESSON-OPS-050: all interval-driven fetch functions must have in-flight guards
for guard in "_statusInFlight" "_storageStatsInFlight" "_historyInFlight"; do
  if grep -q "var ${guard}" dashboard/dashboard.js; then
    echo "inflight_guard_${guard}: OK"
  else
    echo "✗ inflight_guard_${guard}: FAIL — missing in-flight guard in dashboard.js"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

# BUG-043 / LESSON-OPS-055: generate-header.sh must use gzip compression
if grep -q 'gzip' scripts/generate-header.sh; then
  echo "generate_header_uses_gzip: OK"
else
  echo "✗ generate_header_uses_gzip: FAIL — generate-header.sh must gzip-compress the dashboard"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

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

# BUG-043-cont Fix 8: prevent regression — fetchDeviceHistory must fetch sequentially,
# never via Promise.all (concurrent NVS scans block the HTTP server task for 1-4 seconds)
if grep -Eq 'Promise\.all\(.*historyMeasurements' dashboard/dashboard.js dashboard/dashboard.html; then
  echo "✗ no_concurrent_history_fetch: FAIL — fetchDeviceHistory must NOT use Promise.all"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "no_concurrent_history_fetch: OK"
fi

# BUG-043-cont (PR2): prevent regression — initial poll in startPolling() must use batchSize=1
# for fully sequential startup. Promise.all with batchSize>1 creates concurrent connections
# that can destabilize the ESP32-C3 during the critical startup window.
if grep -Eq 'pollAll\(POLL_DEVICE\.concat\(livePaths\),\s*1' dashboard/dashboard.js dashboard/dashboard.html; then
  echo "startup_poll_sequential: OK"
else
  echo "✗ startup_poll_sequential: FAIL — initial pollAll in startPolling() must use batchSize=1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo "→ Validating ESPHome YAML configuration..."

# Check if esphome is available
if ! command -v esphome &> /dev/null; then
  echo "⚠ esphome not found — skipping YAML parse check"
  echo "  (Install via: pip install esphome)"
else
  # Run esphome config to validate YAML structure
  # This parses the YAML and validates the configuration without compiling
  if esphome config firmware/esp32-c3-multi-sensor.yaml > /dev/null 2>&1; then
    echo "✓ ESPHome YAML configuration is valid"
  else
    echo "✗ ESPHome YAML configuration is invalid"
    echo "  Run 'esphome config firmware/esp32-c3-multi-sensor.yaml' to see errors"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "✗ Preflight failed with $FAIL_COUNT error(s)"
  exit 1
fi

python3 scripts/render_sensor_config.py --check
node tests/fixtures/generate-fixtures.js --manifest config/sensors.json --overwrite-baseline >/dev/null
check_contains "fixture_baseline_manifest_regenerated" tests/fixtures/manifest.json '"schema_version": 2'

# Phase 4 check: v2 manifest with sensors.json must contain at least one network-category device
SENSORS_V2="$(python3 -c "import json,sys; d=json.load(open('config/sensors.json')); sys.exit(0 if d.get('schema_version',1)==2 else 1)" 2>/dev/null && echo "yes" || echo "no")"
if [[ "$SENSORS_V2" == "yes" ]]; then
  NETWORK_DEVICE_COUNT="$(python3 -c "import json; d=json.load(open('config/sensors.json')); print(sum(1 for s in d.get('sensors',[]) if s.get('category')=='network'))")"
  if [[ "$NETWORK_DEVICE_COUNT" -ge 1 ]]; then
    echo "manifest_has_network_device: OK (${NETWORK_DEVICE_COUNT} network device(s))"
  else
    echo "✗ manifest_has_network_device: FAIL — v2 manifest has no network-category devices"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "✗ Preflight failed with $FAIL_COUNT error(s)"
  exit 1
fi

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
