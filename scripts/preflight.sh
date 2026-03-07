#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
VER="v7.3.4.2"
FILES=(
  "dashboard-$VER.html"
  "dashboard-$VER.js"
  "dashboard-$VER.h"
  "sensor_history_multi-$VER.h"
  "esp32-c3-multi-sensor-$VER.yaml"
  "generate-header-$VER.sh"
  "esp32-c3-multi-$VER-partitions.csv"
  "secrets-example-$VER.yaml"
)
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done

python - <<'PY'
from pathlib import Path
import sys
base = Path('.')
ver = 'v7.3.4.2'
html = (base/f'dashboard-{ver}.html').read_text(encoding='utf-8')
js = (base/f'dashboard-{ver}.js').read_text(encoding='utf-8').strip()
hdr = (base/f'dashboard-{ver}.h').read_text(encoding='utf-8')
hist = (base/f'sensor_history_multi-{ver}.h').read_text(encoding='utf-8')
yaml = (base/f'esp32-c3-multi-sensor-{ver}.yaml').read_text(encoding='utf-8')
gen = (base/f'generate-header-{ver}.sh').read_text(encoding='utf-8')
start = html.index('<script>') + len('<script>')
end = html.index('</script>', start)
html_js = html[start:end].strip()
app_state_marker = '// ── App.State implementation (Phase 1 write chokepoints) ───────'
sensors_decl = 'var SENSORS = [];'
checks = []
checks.append(('html_js_sync', html_js == js))
checks.append(('yaml_includes_dashboard', f'- dashboard-{ver}.h' in yaml))
checks.append(('yaml_includes_history', f'- sensor_history_multi-{ver}.h' in yaml))
checks.append(('yaml_uses_versioned_partitions', f'partitions: esp32-c3-multi-{ver}-partitions.csv' in yaml))
checks.append(('generator_targets_current_version', f'dashboard-{ver}.html' in gen and f'dashboard-{ver}.h' in gen))
checks.append(('header_generated_from_version', f'Auto-generated from dashboard-{ver}.html' in hdr))
checks.append(('js_version', f"App.version = '{ver}';" in js))
checks.append(('same_origin_https_polling', "window.location.protocol === 'https:'" in js and "TRANSPORT = 'polling'" in js))
checks.append(('storage_retry_present', 'Retrying storage statistics' in js and 'loadStorageStats(tryNum + 1)' in js))
checks.append(('history_axis_helper_present', 'function getHistoryTimeFormat(hours)' in js and 'applyHistoryAxisFormatting(tempAvgChart, HISTORY_RANGE_HOURS);' in js))
checks.append(('no_explicit_acao_addheader_in_history_header', 'addHeader("Access-Control-Allow-Origin"' not in hist))
checks.append(('no_inline_handlers_remaining', 'onclick=' not in html and 'oninput=' not in html and 'onchange=' not in html))
checks.append(('bind_events_present', 'function bindEvents()' in js and 'bindEvents();' in js and 'App.Render.bindEvents = bindEvents;' in js))
checks.append(('state_write_chokepoints_present', 'App.State.setSensors(' in js and 'App.State.setHistoryRangeHours(' in js and 'App.State.resetAvgHistoryStore(' in js and 'App.State.setChartsReady(' in js))
checks.append(('single_dashboard_family', 'v7.3.4.1' not in yaml and 'v7.3.4.1' not in hist and 'v7.3.4.1' not in gen))
checks.append(('sensors_decl_present', sensors_decl in js))
checks.append(('sensors_decl_before_app_state', js.index(sensors_decl) < js.index(app_state_marker) if sensors_decl in js and app_state_marker in js else False))
checks.append(('export_all_is_sequential', 'function fetchAllSensorHistoryRowsSequentially(' in js and 'fetchAllSensorHistoryRowsSequentially(SENSORS' in js and 'Promise.all(SENSORS.map(fetchSensorHistoryRows))' not in js))
checks.append(('point_marker_colors_present', 'pointBackgroundColor:s.color' in js and 'pointBorderColor:s.color' in js and 'pointHoverBackgroundColor:s.color' in js and 'pointHoverBorderColor:s.color' in js))
checks.append(('recolor_updates_point_markers', "ds.pointBackgroundColor = color;" in js and "ds.pointBorderColor = color;" in js and "ds.pointHoverBackgroundColor = color;" in js and "ds.pointHoverBorderColor = color;" in js))
checks.append(('avg_marker_size_aligned', 'pointRadius:1.5, pointHoverRadius:4,' in js))
checks.append(('theme_runtime_redraw_present', 'function refreshChartsAfterVisualChange(reason)' in js and "refreshChartsAfterVisualChange('theme-toggle')" in js))
failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f'{name}: {"PASS" if ok else "FAIL"}')
if failed:
    print('FAILED:', ', '.join(failed))
    sys.exit(1)
PY

node --check "dashboard-$VER.js"
echo "node_check: PASS"

node <<'NODE'
const fs = require('fs');
const vm = require('vm');
const code = fs.readFileSync('dashboard-v7.3.4.2.js', 'utf8');
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
  vm.runInContext(code, context, { filename: 'dashboard-v7.3.4.2.js' });
  console.log('runtime_smoke: PASS');
} catch (err) {
  console.error('runtime_smoke: FAIL');
  console.error(err && err.stack ? err.stack : err);
  process.exit(1);
}
NODE

echo "preflight: PASS"
