#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VER_RAW="$(tr -d '[:space:]' < VERSION)"
VER_TAG="${VER_RAW#v}"
VER_TAG="v${VER_TAG}"

FILES=(
  "VERSION"
  "dashboard/dashboard.html"
  "dashboard/dashboard.js"
  "dashboard/dashboard.h"
  "dashboard/sensor_history_multi.h"
  "firmware/esp32-c3-multi-sensor.yaml"
  "partitions/esp32-c3-multi-partitions.csv"
  "scripts/generate-header.sh"
  "scripts/deploy-to-esphome.sh"
  "tests/mock-server/server.js"
  "tests/browser/sensor-count.spec.js"
  "Docs/configuring-sensors.md"
)

for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done

check_contains() {
  local label="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    echo "$label: PASS"
  else
    echo "$label: FAIL"
    exit 1
  fi
}

check_not_contains() {
  local label="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    echo "$label: FAIL"
    exit 1
  else
    echo "$label: PASS"
  fi
}

check_contains "yaml_includes_dashboard" firmware/esp32-c3-multi-sensor.yaml "- ../dashboard/dashboard.h"
check_contains "yaml_includes_history" firmware/esp32-c3-multi-sensor.yaml "- ../dashboard/sensor_history_multi.h"
check_contains "yaml_uses_canonical_partitions" firmware/esp32-c3-multi-sensor.yaml "partitions: ../partitions/esp32-c3-multi-partitions.csv"
check_contains "generator_targets_dashboard_html" scripts/generate-header.sh "dashboard/dashboard.html"
check_contains "generator_targets_dashboard_h" scripts/generate-header.sh "dashboard/dashboard.h"
check_contains "header_generated_from_canonical_html" dashboard/dashboard.h "Auto-generated from dashboard/dashboard.html"
check_contains "deploy_targets_canonical_yaml" scripts/deploy-to-esphome.sh "firmware/esp32-c3-multi-sensor.yaml"
check_contains "js_version_matches_VERSION" dashboard/dashboard.js "App.version = '${VER_TAG}'"
check_contains "export_all_is_sequential" dashboard/dashboard.js "fetchAllSensorHistoryRowsSequentially"
check_contains "theme_redraw_present" dashboard/dashboard.js "refreshChartsAfterVisualChange"
check_contains "bind_events_present" dashboard/dashboard.js "function bindEvents()"
check_contains "state_write_chokepoints_present" dashboard/dashboard.js "App.State.setSensors("
check_contains "recolor_updates_point_markers" dashboard/dashboard.js "pointBackgroundColor"
check_contains "import_js_present" dashboard/dashboard.js "executeImport"
check_contains "status_endpoint_present" dashboard/sensor_history_multi.h "handle_status_("
check_contains "import_begin_present" dashboard/sensor_history_multi.h "handle_import_begin_("
check_contains "import_segment_present" dashboard/sensor_history_multi.h "handle_import_data_("
check_contains "import_finish_present" dashboard/sensor_history_multi.h "handle_import_finish_("
check_not_contains "yaml_no_old_versioned_header_name" firmware/esp32-c3-multi-sensor.yaml "dashboard-v7.3.4.2.h"
check_not_contains "yaml_no_old_versioned_history_name" firmware/esp32-c3-multi-sensor.yaml "sensor_history_multi-v7.3.4.2.h"
check_not_contains "yaml_no_old_versioned_partition_name" firmware/esp32-c3-multi-sensor.yaml "esp32-c3-multi-v7.3.4.2-partitions.csv"

# ── BUG-018 prevention: exactly one <script> tag in dashboard.html ──
SCRIPT_TAG_COUNT=$(grep -c '^<script>$' dashboard/dashboard.html || true)
if [[ "$SCRIPT_TAG_COUNT" -eq 1 ]]; then
  echo "single_script_tag: PASS"
else
  echo "single_script_tag: FAIL (found ${SCRIPT_TAG_COUNT}, expected 1 — script block was doubled during sync)"
  exit 1
fi

# ── BUG-017 prevention: MAX_HISTORY_RANGE_HOURS must match highest data-history-range button ──
MAX_RANGE_HOURS=$(grep -oP 'data-history-range="\K[0-9]+' dashboard/dashboard.html | sort -n | tail -1)
MAX_CONST=$(grep -oP 'MAX_HISTORY_RANGE_HOURS\s*=\s*\K[0-9]+' dashboard/dashboard.js | head -1)
if [[ "$MAX_RANGE_HOURS" == "$MAX_CONST" ]]; then
  echo "max_history_range_consistent: PASS"
else
  echo "max_history_range_consistent: FAIL (highest button=${MAX_RANGE_HOURS}h, MAX_HISTORY_RANGE_HOURS=${MAX_CONST} — mismatch silently truncates history)"
  exit 1
fi

# ── Test infrastructure existence ──
TEST_FILES=(
  "tests/browser/dashboard.spec.js"
  "tests/browser/sensor-count.spec.js"
  "tests/mock-server/server.js"
  "tests/fixtures/generate-fixtures.js"
  "playwright.config.js"
  "package.json"
  "package-lock.json"
)
for tf in "${TEST_FILES[@]}"; do
  [[ -f "$tf" ]] || { echo "test_infrastructure: FAIL (missing $tf)"; exit 1; }
done
echo "test_infrastructure: PASS"

# ── Playwright browser binary and dependencies check ──
# BUG-026/BUG-027 prevention:
#   BUG-026: Binary missing → need: npx playwright install --with-deps chromium
#   BUG-027: Binary present but shared libs missing (libnspr4.so etc) → same fix
# This check is skipped when node_modules is absent (e.g. build-only CI that
# does not run npm ci). It only runs — and only matters — in environments where
# npm ci has already been executed before preflight.
if [[ ! -d "node_modules/@playwright" ]]; then
  echo "playwright_browser_installed: SKIP (node_modules not present — run npm ci first to enable this check)"
else
node << 'NODE'
const { execFileSync } = require('child_process');
let exec;
try {
  const { chromium } = require('@playwright/test');
  exec = chromium.executablePath();
} catch (e) {
  console.error('playwright_browser_installed: FAIL — @playwright/test not found: ' + e.message);
  console.error('Fix: npm ci && npx playwright install --with-deps chromium');
  process.exit(1);
}
const fs = require('fs');
if (!fs.existsSync(exec)) {
  console.error('playwright_browser_installed: FAIL — binary not found at: ' + exec);
  console.error('Fix: npx playwright install --with-deps chromium');
  process.exit(1);
}
// Actually execute the binary to catch missing shared libraries (libnspr4.so etc)
try {
  execFileSync(exec, ['--version'], { timeout: 5000, stdio: ['ignore', 'pipe', 'pipe'] });
  console.log('playwright_browser_installed: PASS');
} catch (e) {
  const stderr = e.stderr ? e.stderr.toString() : '';
  if (stderr.includes('shared libraries') || stderr.includes('cannot open shared object')) {
    console.error('playwright_browser_installed: FAIL — binary exists but system libs missing: ' + stderr.trim());
    console.error('Fix: npx playwright install --with-deps chromium');
    process.exit(1);
  } else {
    // Some headless-shell builds exit non-zero for --version but still work fine
    console.log('playwright_browser_installed: PASS (binary present)');
  }
}
NODE
fi

node --check dashboard/dashboard.js
echo "node_check: PASS"

# ── Runtime smoke ──
node <<'NODE'
const fs = require('fs');
const vm = require('vm');
const code = fs.readFileSync('dashboard/dashboard.js', 'utf8');
function dummyEl() {
  return {
    classList: { add(){}, remove(){}, toggle(){}, contains(){ return false; } },
    textContent: '', innerHTML: '', value: '', style: {}, dataset: {},
    appendChild(){}, removeChild(){}, setAttribute(){}, removeAttribute(){},
    addEventListener(){}, removeEventListener(){}, focus(){}, select(){}, click(){},
    getContext(){ return {}; }
  };
}
const document = {
  documentElement: { classList: { add(){}, remove(){}, contains(){ return false; }, toggle(){} } },
  body: dummyEl(),
  getElementById(){ return dummyEl(); },
  createElement(){ return dummyEl(); },
  addEventListener(){},
  removeEventListener(){}
};
const context = {
  console,
  window: {
    App: {},
    location: { protocol: 'http:', hostname: 'localhost', href: 'http://localhost/', origin: 'http://localhost' },
    setTimeout: () => 0,
    clearTimeout: () => {},
    setInterval: () => 0,
    clearInterval: () => {}
  },
  document,
  localStorage: { getItem(){ return null; }, setItem(){} },
  setTimeout: () => 0,
  clearTimeout: () => {},
  setInterval: () => 0,
  clearInterval: () => {},
  URL,
  fetch: () => Promise.reject(new Error('fetch not available in runtime smoke')),
  EventSource: function(){},
  Chart: function(){}
};
context.window.document = document;
context.window.localStorage = context.localStorage;
context.window.fetch = context.fetch;
context.window.EventSource = context.EventSource;
context.window.Chart = context.Chart;
vm.createContext(context);
try {
  vm.runInContext(code, context, { filename: 'dashboard.js' });
  console.log('runtime_smoke: PASS');
} catch (err) {
  console.error('runtime_smoke: FAIL');
  console.error(err && err.stack ? err.stack : err);
  process.exit(1);
}
NODE

# ── v7.4.4.x: Sensor-count consistency checks ──
node <<'NODE'
const fs = require('fs');

function fail(msg) {
  console.error(msg);
  process.exit(1);
}

const header      = fs.readFileSync('dashboard/sensor_history_multi.h', 'utf8');
const yaml        = fs.readFileSync('firmware/esp32-c3-multi-sensor.yaml', 'utf8');
const dashboardJs = fs.readFileSync('dashboard/dashboard.js', 'utf8');

let baselineManifest = [];
try {
  baselineManifest = JSON.parse(fs.readFileSync('tests/fixtures/sensors.json', 'utf8'));
} catch (e) {
  fail('sensor_count_checks: FAIL — cannot read tests/fixtures/sensors.json: ' + e.message);
}

// NUM_SENSORS value
const numMatch = header.match(/static\s+constexpr\s+int\s+NUM_SENSORS\s*=\s*(\d+)/);
if (!numMatch) fail('sensor_count_checks: FAIL — NUM_SENSORS not found in sensor_history_multi.h');
const expected = parseInt(numMatch[1], 10);
if (expected < 1 || expected > 4) {
  fail('sensor_count_range_valid: FAIL (NUM_SENSORS=' + expected + ', supported range 1–4). See Docs/configuring-sensors.md');
}
console.log('sensor_count_range_valid: PASS (NUM_SENSORS=' + expected + ')');

// C++ initializer count — count .id = occurrences on non-comment lines (one per sensor slot)
const initializerMatches = header.split('\n')
  .filter(function(line) { return !/^\s*\/\//.test(line); })
  .join('\n')
  .match(/\.id\s*=/g) || [];
if (initializerMatches.length !== expected) {
  fail('sensor_initializer_count_matches_NUM_SENSORS: FAIL (header has ' + initializerMatches.length + ' .id initializers (excluding comment lines), NUM_SENSORS=' + expected + '). See Docs/configuring-sensors.md');
}
console.log('sensor_initializer_count_matches_NUM_SENSORS: PASS (' + initializerMatches.length + ')');

// YAML: thermopro_ble blocks
const bleCount = (yaml.match(/platform:\s*thermopro_ble/g) || []).length;
if (bleCount !== expected) {
  fail('yaml_thermopro_count_matches_NUM_SENSORS: FAIL (yaml=' + bleCount + ', expected=' + expected + '). See Docs/configuring-sensors.md');
}
console.log('yaml_thermopro_count_matches_NUM_SENSORS: PASS (' + bleCount + ')');

// YAML: ble_rssi blocks
const rssiCount = (yaml.match(/platform:\s*ble_rssi/g) || []).length;
if (rssiCount !== expected) {
  fail('yaml_rssi_count_matches_NUM_SENSORS: FAIL (yaml=' + rssiCount + ', expected=' + expected + '). See Docs/configuring-sensors.md');
}
console.log('yaml_rssi_count_matches_NUM_SENSORS: PASS (' + rssiCount + ')');

// YAML: per-sensor text-sensor ID prefix counts
const yamlPrefixChecks = [
  ['cur_temp_',  /id:\s*cur_temp_/g],
  ['cur_hum_',   /id:\s*cur_hum_/g],
  ['avg_temp_',  /id:\s*avg_temp_/g],
  ['avg_hum_',   /id:\s*avg_hum_/g],
  ['battery_',   /id:\s*battery_/g],
  ['last_seen_', /id:\s*last_seen_/g],
];
for (const [label, rx] of yamlPrefixChecks) {
  const count = (yaml.match(rx) || []).length;
  if (count !== expected) {
    fail('yaml_' + label + 'count_matches_NUM_SENSORS: FAIL (yaml=' + count + ', expected=' + expected + '). See Docs/configuring-sensors.md');
  }
  console.log('yaml_' + label + 'count_matches_NUM_SENSORS: PASS (' + count + ')');
}

// Baseline fixture manifest
if (baselineManifest.length !== expected) {
  fail('fixture_manifest_count_matches_NUM_SENSORS: FAIL (tests/fixtures/sensors.json has ' + baselineManifest.length + ' entries, expected=' + expected + '). See Docs/configuring-sensors.md');
}
console.log('fixture_manifest_count_matches_NUM_SENSORS: PASS (' + baselineManifest.length + ')');

// dashboard.js DEFAULT_SENSOR_META fallback (fail if present but wrong count)
const fallbackMatch = dashboardJs.match(/DEFAULT_SENSOR_META\s*=\s*\[([\s\S]*?)\]/);
if (fallbackMatch) {
  const fallbackIds = (fallbackMatch[1].match(/id\s*:/g) || []).length;
  if (fallbackIds !== expected) {
    fail('dashboard_default_sensor_meta_count: FAIL (dashboard.js DEFAULT_SENSOR_META has ' + fallbackIds + ' entries, expected=' + expected + '). Update DEFAULT_SENSOR_META to match NUM_SENSORS. See Docs/configuring-sensors.md');
  }
  console.log('dashboard_default_sensor_meta_count: PASS (' + fallbackIds + ')');
} else {
  console.log('dashboard_default_sensor_meta_count: SKIP (DEFAULT_SENSOR_META not found)');
}

NODE

echo "preflight: PASS"
