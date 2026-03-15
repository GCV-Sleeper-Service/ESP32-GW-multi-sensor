# Phase 2 — Dashboard Consumes v2 Manifest

_Implementation Plan for v7.5.2.x_  
_Date: 2026-03-15_  
_Prerequisite: Phase 1 Complete (v7.5.1.3 on `main`)_  
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Goal

Teach the dashboard to render from manifest v2 metadata instead of hardcoded ThermoPro assumptions. When Phase 2 is complete, the dashboard will:

- Fetch and parse `/api/manifest` (v2) on boot
- Fall back gracefully to `/sensors.json` (v1) and then to hardcoded defaults
- Render sensor cards via a category-dispatched `CARD_RENDERERS` registry
- Format metric values via a `METRIC_FORMATTERS` registry
- Fetch history data based on manifest measurement definitions (not hardcoded temp/hum)
- Pass all existing Playwright regression tests with zero user-visible changes

**Key principle:** ThermoPro rendering must be pixel-identical to current behavior. The refactor changes the dashboard's internal wiring, not its output.

---

## Architecture Reference

See `Docs/v7.5-v7.6-architecture-plan.md`:
- Section 7 — Dashboard Renderer Registry and Dynamic Cards
- Section 7.2 — Card renderer registry
- Section 7.3 — Measurement formatters
- Section 7.4 — Generic history fetching
- Section 7.5 — Boot flow change

---

## Phased Steps

### v7.5.2.0 — Dashboard manifest v2 loader with fallback chain

**Scope:** Add `/api/manifest` fetch to dashboard boot flow with graceful fallback. No rendering changes.

**Files modified:**
- `dashboard/dashboard.js` — add `loadManifestV2()` function with three-tier fallback
- `tests/mock-server/server.js` — serve `/api/manifest` from `tests/fixtures/manifest.json`
- `tests/browser/dashboard.spec.js` — add test: dashboard loads with manifest v2 endpoint
- `tests/browser/dashboard.spec.js` — add test: dashboard loads when `/api/manifest` returns 404 (fallback to `/sensors.json`)
- `Docs/changelog.md` — v7.5.2.0 entry
- Version bump: ALL locations to `7.5.2.0`

**Implementation details:**

```javascript
// New function in dashboard.js
async function loadManifestV2() {
  try {
    // Tier 1: Try v2 manifest endpoint
    var resp = await fetch(ESP_HOST + '/api/manifest', {cache: 'no-store'});
    if (resp.ok) {
      var manifest = await resp.json();
      if (manifest.schema_version === 2 && manifest.sensors) {
        console.log('[manifest] Loaded v2 manifest from /api/manifest');
        return manifest;
      }
    }
  } catch (e) {
    console.warn('[manifest] /api/manifest failed:', e.message);
  }
  
  try {
    // Tier 2: Fall back to legacy /sensors.json, auto-promote to v2
    var resp = await fetch(ESP_HOST + '/sensors.json', {cache: 'no-store'});
    if (resp.ok) {
      var sensors = await resp.json();
      console.log('[manifest] Falling back to /sensors.json → auto-promote to v2');
      return autoPromoteV1ToV2(sensors);
    }
  } catch (e) {
    console.warn('[manifest] /sensors.json failed:', e.message);
  }
  
  // Tier 3: Use hardcoded DEFAULT_SENSOR_META
  console.warn('[manifest] Using hardcoded DEFAULT_SENSOR_META fallback');
  return autoPromoteV1ToV2(DEFAULT_SENSOR_META);
}

function autoPromoteV1ToV2(sensorsArray) {
  // Convert v1 [{id, name}] to v2 manifest structure with ThermoPro defaults
  return {
    ok: true,
    schema_version: 2,
    source: 'auto-promoted',
    version: App.version,
    gateway: { id: 'gw-main', name: 'Main Gateway', role: 'satellite', hardware: 'ESP32-C3', firmware_version: App.version, api_version: 'v2' },
    history: { backend: 'nvs', retention_hours: 1080, ram_window_hours: 24, sample_interval_seconds: 900 },
    sensor_count: sensorsArray.length,
    metrics: [
      { key: 'temp', name: 'Temperature', unit: 'celsius', unit_symbol: '°C', class: 'analog_numeric', data_type: 'float', bounds: {min: -50, max: 80}, history: true, history_suffix: 'temp', display: {precision: 1, chart: true} },
      { key: 'hum', name: 'Humidity', unit: 'percent', unit_symbol: '%', class: 'analog_numeric', data_type: 'float', bounds: {min: 0, max: 100}, history: true, history_suffix: 'hum', display: {precision: 1, chart: true} }
    ],
    sensors: sensorsArray.map(function(s) {
      return { id: s.id, name: s.name, category: 'environmental', adapter: 'thermopro_ble', source: { mac: s.mac || '' }, measurements: [{ key: 'temp', history_url: '/history/' + s.id + '/temp' }, { key: 'hum', history_url: '/history/' + s.id + '/hum' }] };
    })
  };
}
```

**Acceptance criteria:**
- [ ] Dashboard boot calls `loadManifestV2()` and stores result
- [ ] When `/api/manifest` is available: v2 manifest is used
- [ ] When `/api/manifest` returns 404: falls back to `/sensors.json` + auto-promote
- [ ] When both fail: uses `DEFAULT_SENSOR_META` + auto-promote
- [ ] All existing Playwright tests pass (no rendering changes yet)
- [ ] Version is `7.5.2.0` everywhere

**Risk:** Low. Data loading only, no rendering changes.  
**Estimated effort:** 1 session.

---

### v7.5.2.1 — Card renderer registry (environmental only)

**Scope:** Introduce `CARD_RENDERERS` registry. Refactor `buildSensorCards()` → `buildDeviceCards()` that dispatches to category-specific renderers.

**Files modified:**
- `dashboard/dashboard.js` — add `CARD_RENDERERS` object, `buildDeviceCards()`, `buildEnvironmentalCard()`
- `dashboard/dashboard.html` — no structural changes needed (cards are dynamically built)
- `dashboard/dashboard.min.html` — regenerated
- `dashboard/dashboard.h` — regenerated
- `tests/browser/dashboard.spec.js` — add test: verify card renderer dispatches by category
- `Docs/changelog.md` — v7.5.2.1 entry
- Version bump: ALL locations to `7.5.2.1`

**Implementation details:**

```javascript
// Card renderer registry
var CARD_RENDERERS = {
  environmental: function(device, manifest) {
    // This is the existing buildSensorCards() logic, scoped to one device
    return buildEnvironmentalCard(device, manifest);
  },
  _default: function(device, manifest) {
    // Simple key-value fallback renderer for unknown categories
    var html = '';
    return html;
  }
};

function buildDeviceCards() {
  var grid = document.getElementById('sensorGrid');
  grid.innerHTML = '';
  SENSORS.forEach(function(sensor, index) {
    // Look up device in manifest to get category
    var manifestDevice = null;
    if (window._manifest && window._manifest.sensors) {
      manifestDevice = window._manifest.sensors.find(function(s) { return s.id === sensor.id; });
    }
    var category = (manifestDevice && manifestDevice.category) || 'environmental';
    var renderer = CARD_RENDERERS[category] || CARD_RENDERERS._default;
    grid.innerHTML += renderer(sensor, window._manifest);
  });
  // Re-attach event listeners after innerHTML rebuild
  attachCardEventListeners();
}
```

**Critical regression requirement:**
The `buildEnvironmentalCard()` function must produce HTML **identical** to what `buildSensorCards()` produces today. The refactor is structural — moving existing logic into a named function — not behavioral. Every DOM element, class name, data attribute, and text node must be preserved.

**Approach:**
1. Extract the per-sensor card body from `buildSensorCards()` into `buildEnvironmentalCard(sensor, manifest)`
2. Replace the `buildSensorCards()` body with a call to `buildDeviceCards()`
3. Keep `buildSensorCards()` as an alias (for any external callers) initially
4. Run Playwright tests — must be pixel-identical

**Acceptance criteria:**
- [ ] `CARD_RENDERERS` registry exists with `environmental` and `_default` entries
- [ ] `buildDeviceCards()` dispatches by category
- [ ] `buildEnvironmentalCard()` produces identical HTML to old `buildSensorCards()` per-sensor logic
- [ ] All existing Playwright tests pass without changes to test assertions
- [ ] `_default` renderer gracefully handles unknown categories
- [ ] Version is `7.5.2.1` everywhere

**Risk:** Medium. Card rendering refactor touches core UI code. Playwright regression tests are the safety net.  
**Estimated effort:** 2 sessions.

---

### v7.5.2.2 — Metric formatters registry

**Scope:** Extract value formatting logic into a `METRIC_FORMATTERS` registry. Dashboard reads `unit`, `unit_symbol`, `display.precision` from manifest.

**Files modified:**
- `dashboard/dashboard.js` — add `METRIC_FORMATTERS` object, integrate into card rendering
- `dashboard/dashboard.min.html` — regenerated
- `dashboard/dashboard.h` — regenerated
- `tests/browser/dashboard.spec.js` — add test: verify metric formatting matches expected output
- `Docs/changelog.md` — v7.5.2.2 entry
- Version bump: ALL locations to `7.5.2.2`

**Implementation details:**

```javascript
var METRIC_FORMATTERS = {
  temperature: function(value, unit) {
    if (unit === 'celsius' || unit === '°C') {
      var f = value * 9/5 + 32;
      return value.toFixed(1) + ' °C / ' + f.toFixed(1) + ' °F';
    }
    return value.toFixed(1) + ' ' + (unit || '');
  },
  humidity: function(value) {
    return value.toFixed(1) + ' %';
  },
  _default: function(value, unit) {
    return value.toFixed(1) + ' ' + (unit || '');
  }
};

// Formatter lookup by metric key
function formatMetricValue(key, value, metric_def) {
  var formatter = METRIC_FORMATTERS[key] || METRIC_FORMATTERS._default;
  var unit = metric_def ? (metric_def.unit_symbol || metric_def.unit || '') : '';
  return formatter(value, unit);
}
```

**Approach:**
1. Create `METRIC_FORMATTERS` with `temperature` and `humidity` entries matching current formatting behavior
2. Replace inline formatting calls in `buildEnvironmentalCard()` with `formatMetricValue()` calls
3. Verify output is identical to pre-refactor behavior

**Acceptance criteria:**
- [ ] `METRIC_FORMATTERS` registry exists with `temperature`, `humidity`, and `_default` entries
- [ ] `formatMetricValue()` function provides unified formatting interface
- [ ] Temperature formatting produces identical `°C / °F` string to current code
- [ ] Humidity formatting produces identical `%` string to current code
- [ ] All existing Playwright tests pass without assertion changes
- [ ] Version is `7.5.2.2` everywhere

**Risk:** Low-Medium. Formatting extraction is straightforward. Must match existing output exactly.  
**Estimated effort:** 1 session.

---

### v7.5.2.3 — Generic history fetching

**Scope:** Refactor `fetchSensorHistoryRows()` to be driven by manifest measurement definitions instead of hardcoded temp/hum paths.

**Files modified:**
- `dashboard/dashboard.js` — refactor `fetchSensorHistoryRows()` or equivalent history fetch function
- `dashboard/dashboard.min.html` — regenerated
- `dashboard/dashboard.h` — regenerated
- `tests/browser/dashboard.spec.js` — add test: verify history URLs are derived from manifest
- `Docs/changelog.md` — v7.5.2.3 entry
- Version bump: ALL locations to `7.5.2.3`

**Implementation details:**

```javascript
function fetchDeviceHistory(sensor, manifest) {
  // Find this sensor's measurements in the manifest
  var manifestDevice = null;
  if (manifest && manifest.sensors) {
    manifestDevice = manifest.sensors.find(function(s) { return s.id === sensor.id; });
  }

  // Determine which measurements have history + chart enabled
  var historyMeasurements = [];
  if (manifestDevice && manifestDevice.measurements) {
    manifestDevice.measurements.forEach(function(m) {
      // Find the metric definition to check if chart is enabled
      var metricDef = manifest.metrics.find(function(md) { return md.key === m.key; });
      if (metricDef && metricDef.history && metricDef.display && metricDef.display.chart) {
        historyMeasurements.push({
          key: m.key,
          url: m.history_url || ('/history/' + sensor.id + '/' + (metricDef.history_suffix || m.key))
        });
      }
    });
  }

  // Fallback: if no manifest data, use legacy temp/hum paths
  if (historyMeasurements.length === 0) {
    historyMeasurements = [
      { key: 'temp', url: '/history/' + sensor.id + '/temp' },
      { key: 'hum', url: '/history/' + sensor.id + '/hum' }
    ];
  }

  // Fetch all history series
  var fetches = historyMeasurements.map(function(m) {
    return fetch(ESP_HOST + m.url, {cache: 'no-store'})
      .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
      .then(function(text) { return { key: m.key, data: parseHistoryCsv(text) }; })
      .catch(function(err) { console.warn('[history] Failed to fetch ' + m.url + ':', err.message); return { key: m.key, data: [] }; });
  });

  return Promise.all(fetches);
}
```

**Approach:**
1. Create `fetchDeviceHistory(sensor, manifest)` that reads measurement URLs from manifest
2. Include fallback to legacy `/history/{id}/temp` and `/history/{id}/hum` when manifest data unavailable
3. Replace existing hardcoded history fetch calls with the generic version
4. Chart rendering continues to work because the data format (CSV) is unchanged

**Acceptance criteria:**
- [ ] History URLs are derived from manifest `measurements[].history_url`
- [ ] Fallback to legacy URLs when manifest unavailable
- [ ] Chart rendering produces identical output
- [ ] All existing Playwright tests pass
- [ ] Version is `7.5.2.3` everywhere

**Risk:** Medium. History fetching is critical path for charts. Fallback logic must be robust.  
**Estimated effort:** 1–2 sessions.

---

### v7.5.2.4 — Full Playwright regression + Phase 2 closure

**Scope:** Final validation, documentation, and phase closure.

**Files modified:**
- `tests/browser/dashboard.spec.js` — add comprehensive manifest-driven rendering tests
- `tests/browser/dashboard.spec.js` — add fallback chain test (no `/api/manifest` → works via `/sensors.json`)
- `Docs/changelog.md` — v7.5.2.4 entry with Phase 2 Complete callout
- `Docs/v7.5-v7.6-architecture-plan.md` — Phase 2 Status: COMPLETE
- `Docs/session-log-2026-03-15-phase2.md` — full session log (created during implementation)
- `Docs/bugs-and-lessons-learned.md` — any new bugs/lessons from Phase 2
- Version bump: ALL locations to `7.5.2.4`

**New Playwright tests to add:**
1. Dashboard renders correctly when `/api/manifest` returns full v2 manifest
2. Dashboard renders correctly when `/api/manifest` returns 404 (fallback to `/sensors.json`)
3. Dashboard renders correctly when both `/api/manifest` and `/sensors.json` fail (fallback to hardcoded defaults)
4. Card renderer dispatches `environmental` category correctly
5. `_default` card renderer handles unknown category gracefully
6. Metric formatters produce correct temperature format (`°C / °F`)
7. History fetch uses `history_url` from manifest when available
8. History fetch falls back to legacy URLs when manifest unavailable

**Acceptance criteria:**
- [ ] All existing Playwright tests pass (regression gate)
- [ ] All new manifest-driven tests pass
- [ ] All fallback chain tests pass
- [ ] Architecture plan updated with Phase 2 COMPLETE
- [ ] Changelog updated
- [ ] Session log created/updated
- [ ] Version is `7.5.2.4` everywhere

**Risk:** Low. This step is validation and documentation, not new functionality.  
**Estimated effort:** 1 session.

---

## Phase 1 Lessons Applied to Phase 2

| # | Lesson | How Applied in Phase 2 |
|---|---|---|
| 1 | BUG-041: Version strings drifted between fixture generator and canonical VERSION | Every version bump is atomic across ALL files. Preflight version-sync check prevents drift. |
| 2 | LESSON-OPS-046: Generated artifacts need schema validation, not just existence checks | New Playwright tests validate manifest-driven rendering end-to-end, not just file existence. |
| 3 | LESSON-OPS-045: YAML parse gate | `esphome config` preflight check runs on every PR. |
| 4 | BUG-035/036: YAML marker block replacement | Never use `replace_marker_block()` for YAML. Use `apply_yaml_marker_block()`. Not directly relevant to Phase 2 (dashboard-only), but guardrail remains. |
| 5 | PR #15 lesson: generated file paths | ESPHome includes resolve from `src/`. Not directly relevant to Phase 2 (JS-only), but guardrail remains. |
| 6 | BUG-039: Dashboard artifact regeneration | After editing `dashboard.html` or `dashboard.js`, always regenerate `dashboard.min.html` and `dashboard.h`. |
| 7 | PR #20 lesson: fixture sync | Run `python3 scripts/render_sensor_config.py --check` locally before every push. |

---

## Version Bump Checklist (apply to every v7.5.2.x step)

When bumping version, update ALL of these files atomically:

- [ ] `VERSION` file
- [ ] `scripts/render_sensor_config.py` — VERSION constant
- [ ] `tests/fixtures/generate-fixtures.js` — VERSION constant
- [ ] `dashboard/dashboard.js` — App.version
- [ ] `dashboard/sensor_history_multi.h` — header comment
- [ ] `firmware/esp32-c3-multi-sensor.yaml` — version references
- [ ] `dashboard/dashboard.html` — version comment (if present)
- [ ] Run `python3 scripts/render_sensor_config.py --write` to regenerate:
  - `src/gateway_manifest.h`
  - `tests/fixtures/manifest.json`
  - `tests/fixtures/api-status.json`
  - All other generated files
- [ ] Run `bash scripts/generate-header.sh` to regenerate:
  - `dashboard/dashboard.min.html`
  - `dashboard/dashboard.h`

---

## File Inventory

| File | Change type | Step |
|---|---|---|
| `dashboard/dashboard.js` | Major refactor: manifest loader, card registry, formatters, generic history | 7.5.2.0–7.5.2.3 |
| `dashboard/dashboard.html` | Minor: possible structural changes for generic cards | 7.5.2.1 |
| `dashboard/dashboard.min.html` | Regenerated after each dashboard.js/html change | 7.5.2.1–7.5.2.3 |
| `dashboard/dashboard.h` | Regenerated after each dashboard.js/html change | 7.5.2.1–7.5.2.3 |
| `tests/mock-server/server.js` | Extend: serve `/api/manifest` endpoint | 7.5.2.0 |
| `tests/browser/dashboard.spec.js` | Extend: manifest-driven rendering tests, fallback tests | 7.5.2.0–7.5.2.4 |
| `Docs/changelog.md` | Update per step | All |
| `Docs/v7.5-v7.6-architecture-plan.md` | Phase 2 status update | 7.5.2.4 |
| `Docs/bugs-and-lessons-learned.md` | New entries if bugs found | As needed |

---

_End of Phase 2 Implementation Plan._
