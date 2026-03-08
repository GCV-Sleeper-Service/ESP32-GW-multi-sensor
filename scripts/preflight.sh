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
check_not_contains "yaml_no_old_versioned_header_name" firmware/esp32-c3-multi-sensor.yaml "dashboard-v7.3.4.2.h"
check_not_contains "yaml_no_old_versioned_history_name" firmware/esp32-c3-multi-sensor.yaml "sensor_history_multi-v7.3.4.2.h"
check_not_contains "yaml_no_old_versioned_partition_name" firmware/esp32-c3-multi-sensor.yaml "esp32-c3-multi-v7.3.4.2-partitions.csv"

node --check dashboard/dashboard.js
echo "node_check: PASS"

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

echo "preflight: PASS"
