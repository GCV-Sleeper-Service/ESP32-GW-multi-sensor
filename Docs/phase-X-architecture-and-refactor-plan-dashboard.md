# Phase X — Dashboard Architecture and Refactor Plan

_Unified implementation plan — reconciles Draft A (GP) and Draft B (PR) with codebase-verified corrections._
_Date: 2026-04-04 (revised 2026-04-05)_
_Phase: Phase X — Post-Phase D dashboard architecture refactor_
_Version range: `v7.6.4.0`–`v7.6.5.8` (v7.6.4.0 is a documentation pre-step)_
_Status: Planning — not yet implemented_
_Prerequisite: Phase D Complete (v7.6.0.5 on `main`, 402/0 tests green)_
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_

---

## 1. Goal

Refactor the dashboard source architecture in three progressive levels so that:

1. Future coding-agent tasks fit within a 30K–40K token context window — no task requires loading the full dashboard monolith.
2. `dashboard.html` stops being a hand-maintained mirror of `dashboard.js` — the LESSON-OPS-043 / BUG-039 class of failures is permanently eliminated.
3. The dashboard can scale to Phase 7 (per-device persistence UI), Phase E (captive portal, v8.0.x), and beyond through component-level ownership instead of whole-file editing.
4. Documentation is restructured so coding agents read domain-scoped reference material, not monolithic 3,000-line files.
5. The test suite structure mirrors the module/component structure, so tests for a feature can be loaded without loading tests for every other feature.
6. Security, efficiency, and performance are preserved — no runtime behavior change at any step.

**This phase is structural only. It is not a feature phase.**

---

## 2. Architecture Decisions (Resolved)

These decisions were identified as open tensions between Draft A and Draft B. They are resolved here and apply to all steps.

### 2.1 `dashboard.html` — committed or gitignored?

**Decision: Committed, but clearly marked as generated.**

Rationale: The "open from disk" device-testing workflow (loading `dashboard.html` directly in a browser against a live ESP32) is a real operational need documented in LESSON-OPS-051. If the file is gitignored, operators must remember to build it before testing. Keeping it committed also makes PR diffs reviewable — the reviewer can see exactly what the firmware will serve.

Implementation: `dashboard.html` header gets a comment: `<!-- GENERATED — Do not edit. Source: dashboard/src/*.js + dashboard.tmpl.html -->`. Preflight enforces that the committed file matches the build output.

### 2.2 `dashboard.js` — committed or gitignored?

**Decision: Committed, marked as generated.**

Rationale: Same as above — `dashboard.js` is used for development-time browser debugging (loading the HTML from disk with the JS as a separate file). It also serves as a human-readable assembled view of the full runtime.

### 2.3 Aggregator overlay constraint

**Decision: LESSON-OPS-074 is a non-negotiable constraint for all component boundaries.**

The aggregator boot path is a superset overlay of the satellite path, not a forked pipeline. In Level 3, the gateway panel and settings panel are separate components, but they augment the base dashboard — they never replace core components or fork the boot sequence. `App.Boot.start()` remains a single orchestrator that conditionally enables aggregator components.

### 2.4 POST/body semantics through refactor

**Decision: LESSON-OPS-099 (x-www-form-urlencoded, `body: 'a=1'`) applies to every refactor step.**

All POST fetch calls must be moved intact. No refactoring of request construction during Phase X. POST semantics are verified by the existing Playwright satellite management tests (Group 21).

### 2.5 Generator coupling

**Decision: `render_sensor_config.py` continues to write into the assembled `dashboard.js`, not into individual modules.**

The generator's `DEFAULT_SENSOR_META` block (lines 196–202 in current `dashboard.js`) is only 6 lines. Moving the marker into a source module would require updating the generator's `JS_PATH` and adding a rebuild-after-generate step. Instead: the generator writes into `dashboard.js` (the assembled output) as it does today, and preflight verifies sync. This means the canonical pipeline is: modules → bundle → generator → minify → header. The generator operates on the bundle, not the sources.

**Note:** The markers physically live in `02-sensor-defs.js` during editing (not `04-manifest.js` — the function names suggest manifest but the markers sit at lines 196–202 which fall in the sensor definitions section). After bundling, they land in `dashboard.js` where the generator can find them.

After Level 2, the pipeline becomes: modules → bundle (writes `dashboard.js`) → generator (updates `dashboard.js` markers) → template injection (produces `dashboard.html`) → minify → header.

---

## 3. Current State Analysis

### 3.1 Dashboard asset metrics (verified at HEAD `24f68ab`)

| Artifact | Lines | Role | Problem |
|---|---|---|---|
| `dashboard/dashboard.js` | **3,955** | Hand-maintained JS monolith | Exceeds any agent's comfortable context window |
| `dashboard/dashboard.html` | **4,900** | Hand-maintained HTML + CSS + inline JS mirror | Second manual source of truth; LESSON-OPS-043 |
| `dashboard/dashboard.h` | 3,423 | Committed gzip C header | Depends on correct regeneration order |
| `dashboard/dashboard.min.html` | (build artifact) | Minified intermediate | Can go stale; `generate-header.sh` silently prefers it |
| `tests/browser/dashboard.spec.js` | **1,853** | Single test file, 21 groups, 402 tests | Also a monolith; context overhead for any test-touching task |
| `tests/mock-server/server.js` | 498 | Mock endpoints for Playwright | Approaching split threshold |
| `scripts/render_sensor_config.py` | 1,414 | Config generator — writes into `dashboard.js` and `sensor_history_multi.h` | Generator coupling to assembled output |

**Note:** Both Draft A (~2,400 lines) and Draft B (~2,600 lines) undercount `dashboard.js`. The actual file is **3,955 lines** at HEAD after Phase D added ~640 lines of aggregator satellite management UI. All module boundaries in this plan use the correct line counts.

### 3.2 Functional groups in `dashboard.js` (verified)

#### Shared runtime logic (used by both satellite and aggregator modes)

| Area | Representative functions | Approx lines |
|---|---|---|
| App namespace + plugin shell + error logger | `App.*`, `App.Features`, `logNonFatal()` | ~70 |
| Connection/config bootstrap | `FILE_FALLBACK_HOST`, `IS_FILE_MODE`, `ESP_HOST`, `TRANSPORT`, config wiring | ~60 |
| State management | `App.State` IIFE, sensor/history/chart getters/setters | ~50 |
| Common helpers + formatters | `sensorSlug()`, `esc*()`, `cToF()`, `formatBytes()`, `formatMetricValue()`, `METRIC_FORMATTERS` | ~190 |
| Manifest + sensor config | `makeSensorConfig()`, `applySensorMeta()`, `loadSensorManifest()`, `loadManifestV2()`, `autoPromoteV1ToV2()` | ~160 |
| Theme/UI utilities | `toggle()`, `toggleTheme()`, `bindEvents()`, debug log helpers | ~105 |
| History range + custom range | `CustomRange` IIFE (calendar modal), `setHistoryRange()`, `applyHistoryRange()`, `getEffectiveTimeRange()` | ~445 |
| Card rendering | `CARD_RENDERERS`, `buildEnvironmentalCard()`, `buildNetworkCard()`, `buildSystemCard()`, `buildDeviceCards()` | ~330 |
| Charts | `FREEZING_LINE_PLUGIN`, `tempChartOpts()`, `humChartOpts()`, `telemetryChartOpts()`, `initCharts()`, `updateChartsTheme()` | ~340 |
| Boot orchestration | `App.Boot.start()`, `updateBoardInfo()`, `DOMContentLoaded` | ~75 |

#### Satellite-primary logic (meaningful only for local gateway)

| Area | Representative functions | Approx lines |
|---|---|---|
| Local status + telemetry | `applyStatusSnapshot()`, `loadStatusSnapshot()`, `updateTelemetry()`, `pushTelemetry()` | ~100 |
| Live entity handling | `handleState()`, `updateBattery()`, `updateRSSI()`, `updateDewPoint()`, `updateComfortLevel()` | ~130 |
| SSE + polling transport | `connectSSE()`, `pollEntity()`, `pollAll()`, `startPolling()` | ~200 |
| Storage stats | `applyStorageStats()`, `loadStorageStats()` | ~110 |
| History loading | `parseCompactHistory()`, `loadHistory()`, `fetchSensorHistoryRows()` | ~160 |
| CSV export | `buildSingleSensorCsv()`, `buildMergedSensorCsv()`, `exportSensorCSV()`, `exportAllCSV()` | ~160 |
| Management/auth | `requestManagementCredentials()`, `postManagementAction()`, `rebootESP()`, `deleteHistoryData()` | ~155 |
| Import engine | `importHistoryData()`, `processImportFile()`, `parseImportCsv()`, `buildImportSegments()`, `executeImport()` | ~510 |
| Min/max + derived values | `updateMinMax()`, `setMinMaxPeriod()`, `calcDewPoint()`, `calcComfortEstimate()`, `checkStaleness()` | ~230 |
| Suspend/resume | `suspendDashboardNetworkActivity()`, `resumeDashboardNetworkActivity()`, import state guards | ~75 |

#### Aggregator-only logic

| Area | Representative functions | Approx lines |
|---|---|---|
| Aggregator mode detection | `detectAggregatorMode()` | ~15 |
| Gateway tab/summary rendering | `renderGatewaySelector()`, `renderAllGatewaysSummary()` | ~65 |
| Remote gateway device rendering | `renderGatewayDevices()`, `_populateGatewayDeviceLive()` | ~155 |
| Settings panel + satellite management | `renderSettingsPanel()`, `_handleTestSatellite()`, `_handleAddSatellite()`, `_handleRemoveSatellite()`, `_refreshSettingsPanel()` | ~220 |
| Aggregator poll loop | `pollAggregatorLive()`, `initAggregatorDashboard()` | ~75 |
| Aggregator live device updates | `updateNetworkCards()`, `updateSystemCards()`, `pollV2Live()` | ~115 |

#### Cross-cutting functions (shared name, aggregator-specific branches inside)

These functions are technically shared but contain conditional branches for aggregator mode. They must stay in shared modules — not split by mode:

- `fetchDeviceHistory()` — local and proxy-history branches
- `buildDeviceCards()` — shared registry used in both local and remote contexts
- `App.Boot.start()` — shared boot with aggregator overlay
- `pollV2Live()` — shared local network/system flow plus aggregator equivalents

### 3.3 CSS partition inside `dashboard.html` (verified)

The `<style>` block spans lines 23–515 (~493 lines). The CSS already has feature groupings that map to component boundaries:

| CSS selector family | Feature ownership | Component target |
|---|---|---|
| `:root`, `body`, `.header`, `*` resets, scrollbar | Global shell / app chrome | `core/base.css` |
| `.status-*`, `.about-bar`, `.error-banner` | Status bar + description | `core/base.css` |
| `.collapse-*` | Shared collapsible-section system | `core/base.css` |
| `.top-grid`, `.gateway-*`, `.device-info-*`, `.compact-*` | Gateway top area, management cards | `components/device-info/` |
| `.storage-*` | History storage panel | `components/storage-panel/` |
| `.credits-*` | Credits block | `core/base.css` (small) |
| `.gpio-*` | GPIO / board-info panel | `components/device-info/` |
| `.telemetry-*` | Telemetry panel | `components/telemetry-panel/` |
| `.sensor-*`, `.reading-*`, `.sensor-minmax`, `.sensor-batt-*` | Environmental sensor cards | `components/sensor-cards/` |
| `.sensor-rssi-*`, `.dewpoint-*`, `.comfort-*`, `.sensor-env-*`, `.sensor-color-picker` | Sensor-card subfeatures | `components/sensor-cards/` |
| `.network-card`, `.system-card`, `.system-*` | Non-environmental device cards | `components/sensor-cards/` |
| `.charts-row`, `.chart-*`, `.history-*`, `.refresh-btn` | Charts panels | `components/charts/` |
| `.export-*` | Export history panel | `components/export-panel/` |
| `.footer`, `.debug-*` | Footer and debug log | `core/base.css` |
| `.auth-*` | Management auth modal | `components/auth-modal/` |
| `.cr-*` | Custom date range modal | `components/custom-range/` |
| `:root.light ...`, `.theme-toggle` | Theme system (light mode overrides) | `core/base.css` |
| `@media (...)` | Responsive layout rules | Split across components; global breakpoints in `core/base.css` |
| `.gw-*`, `.settings-*` | Aggregator gateway selector, summary, settings | `components/gateway-panel/` |

### 3.4 Current build pipeline

```
dashboard/dashboard.js          ← developer edits (JS logic, source of truth for JS)
dashboard/dashboard.html        ← developer edits (manually mirrored HTML+CSS+JS)
        │
        ▼  [scripts/minify-dashboard.sh → npm: html-minifier-terser]
dashboard/dashboard.min.html    ← build artifact (gitignored)
        │
        ▼  [scripts/generate-header.sh → gzip + python3 hex dump]
dashboard/dashboard.h           ← committed C header, embedded in firmware
        │
        ▼  [esphome compile]
firmware binary served at GET /
```

**Weakness 1:** Two manual edit surfaces for one runtime — LESSON-OPS-043.
**Weakness 2:** `generate-header.sh` silently prefers stale `.min.html` if present.
**Weakness 3:** No JS assembly layer — no way to split JS into modules.
**Weakness 4:** `bump-version.sh` (line 66) uses `sed` on `dashboard.html` directly.

### 3.5 Generator coupling (verified)

`render_sensor_config.py` writes a 6-line `DEFAULT_SENSOR_META` block into `dashboard.js` between marker comments at lines 196–202:

```javascript
// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_BEGIN >>>
var DEFAULT_SENSOR_META = [
  { id: 'office', name: 'Office' },
  { id: 'first_floor', name: 'First Floor' },
  { id: 'outside', name: 'Outside' },
];
// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_END >>>
```

The generator also writes into `sensor_history_multi.h` (header block and entity block). The JS injection is small and self-contained; it operates on the assembled `dashboard.js` bundle. See §2.5 for the resolution.

### 3.6 Test structure (verified)

`tests/browser/dashboard.spec.js` — 1,853 lines, 21 test groups:

| Groups | Coverage domain |
|---|---|
| 1–3 | Boot, structure, sensor cards, transport |
| 4–5 | History, charts, custom date range |
| 6–8 | Theme, export, console error guard |
| 9–11 | Manifest v2, fallback, card renderer registry |
| 12–13 | Metric formatters, manifest-driven history |
| 14–15 | Phase 2/3 closure regressions |
| 16 | BUG-043 request scheduling regression |
| 17–18 | Network card renderer, mixed-category rendering |
| 19 | Aggregator mode |
| 20 | System devices and data ingest |
| 21 | Satellite management |

### 3.7 Fixture sets (correct names)

| Fixture Set | Test Count | Notes |
|---|---|---|
| `3sensor` | 99 | Default 3-sensor satellite |
| `mixed` | 96 | Mixed environmental + network |
| `system` | 100 | System metrics device |
| `aggregator` | 107 | Aggregator with satellites |

**Note:** Draft B incorrectly listed "1sensor, 2sensor, 3sensor, 4sensor, mixed, system." The actual fixture sets are the four listed above. All Phase X acceptance criteria use these correct names.

---

## 4. Proposed File Structure

### 4.1 After Level 1 — Module Split (`v7.6.5.0`–`v7.6.5.1`)

```
dashboard/
  src/
    00-app-shell.js           ~71  lines — App namespace, App.Features IIFE, logNonFatal
    01-config-state.js        ~119 lines — FILE_FALLBACK_HOST, IS_FILE_MODE, ESP_HOST, TRANSPORT, App.Config, MAX_POINTS, HISTORY vars, SENSORS, DASHBOARD_MODE, App.State IIFE
    02-sensor-defs.js         ~178 lines — SENSOR_COLORS, DEFAULT_SENSOR_META (generator markers), export column helpers, sensorSlug, csvEscape, METRIC_FORMATTERS, formatMetricValue, triggerCsvDownload
    03-history-fetch.js       ~216 lines — parseHistoryMetricLines, buildNormalizedSensorRows, fetchDeviceHistory, fetchSensorHistoryRows, fetchAllSensorHistoryRowsSequentially, buildSingleSensorCsv, buildMergedSensorCsv, currentExportDateTag
    04-manifest.js            ~151 lines — makeSensorConfig, makeNetworkSensorConfig, applySensorMeta, normalizeManifestSensors, loadSensorManifest, loadManifestV2, autoPromoteV1ToV2
    05-status-snapshot.js     ~65  lines — TELEMETRY_IDS, POLL_SHARED, POLL_DEVICE, formatUptimeSeconds, applyStatusSnapshot, loadStatusSnapshot
    06-ui-helpers.js          ~248 lines — esc*, cToF, pad2, formatUtcForExport, formatBytes, formatEpochLocal, getEffectiveTimeRange, filterPointsForRange, ensureHistoryStore, setHistoryRange, applyHistoryRange, isNoDataState, parseVal, dlog, toggle, toggleTheme, bindEvents
    07-staleness-derived.js   ~121 lines — calcDewPoint, checkStaleness, updateRSSI, updateDewPoint, calcComfortEstimate, updateComfortLevel, setMinMaxPeriod
    08-custom-range.js        ~329 lines — CustomRange IIFE (calendar modal)
    09-export.js              ~64  lines — exportSensorCSV, exportAllCSV, resetHistoryVisuals
    10-storage-stats.js       ~100 lines — applyStorageStats, loadStorageStats, importState vars, polling interval vars
    11-suspend-resume.js      ~86  lines — isImportActive, stopPolling, stopStorageRefresh, stopStatusRefresh, suspendDashboardNetworkActivity, resumeDashboardNetworkActivity, isTransientImportError
    12-management.js          ~168 lines — importFetchJsonWithRetry, requestManagementCredentials, postManagementAction, rebootESP, deleteHistoryData
    13-import.js              ~426 lines — importHistoryData, processImportFile, parseImportCsv, estimateImportDuration, detectSensorIdFromImportFileName, detectImportColumns, buildImportSegments, safeJsonResponse, executeImport
    14-cards.js               ~270 lines — updateBadge, onSensorColorPicked, CARD_RENDERERS, buildEnvironmentalCard, buildNetworkCard, buildSystemCard, buildDeviceCards, buildSensorCards (compat alias), buildExportButtons
    15-minmax.js              ~52  lines — updateMinMax
    16-charts.js              ~200 lines — FREEZING_LINE_PLUGIN, chart axis vars, recolorChartForTheme, refreshChartsAfterVisualChange, updateChartsTheme, tempChartOpts, humChartOpts, telemetryChartOpts, initCharts
    17-live-updates.js        ~156 lines — updateBattery, updateDeviceInfo, updateTelemetry, pushTelemetry, parseCompactHistory, loadHistory
    18-transport.js            ~276 lines — handleState, connectSSE, pollEntity, pollAll, startPolling, updateNetworkCards, _updateSystemCardDOM, updateSystemCards, updateUsageBar, pollV2Live, App module exports block
    19-aggregator.js           ~508 lines — detectAggregatorMode, renderGatewaySelector, renderAllGatewaysSummary, renderGatewayDevices, _populateGatewayDeviceLive, renderSettingsPanel, _handleTestSatellite, _handleAddSatellite, _handleRemoveSatellite, _refreshSettingsPanel, initAggregatorDashboard, pollAggregatorLive
    20-boot.js                ~134 lines — updateBoardInfo, App.Boot.start, DOMContentLoaded
  dashboard.js              ← GENERATED by bundle-dashboard.sh; committed; generator markers live here
  dashboard.html            ← still manually maintained at Level 1
  dashboard.h               ← committed gzip C header (unchanged)
scripts/
  bundle-dashboard.sh       ← NEW: concatenates src/*.js in order → dashboard.js
  minify-dashboard.sh       ← unchanged
  generate-header.sh        ← unchanged
```

**Module count:** 21 source files. Largest: `19-aggregator.js` (~508 lines), `13-import.js` (~426 lines). Smallest: `15-minmax.js` (~52 lines), `09-export.js` (~64 lines). Most modules ≤250 lines.

**Critical: module order = file order.** Each module is a contiguous slice of the original `dashboard.js`. The concatenation order (00→20) exactly reproduces the original file. Modules cannot be reordered or have functions moved between them without breaking the identity gate. The function list for each module reflects where those functions actually sit in the current 3,955-line monolith — not where they would logically belong in an ideal architecture.

**Why some groupings may seem unexpected:**
- `buildSingleSensorCsv` and `buildMergedSensorCsv` are in `03-history-fetch.js` (not `09-export.js`) because they physically sit at lines 529–587, between `fetchSensorHistoryRows` and `currentExportDateTag`.
- `triggerCsvDownload` is in `02-sensor-defs.js` (not `09-export.js`) because it sits at line 363, in the helpers section.
- `requestManagementCredentials` is in `12-management.js` (after `11-suspend-resume.js`) because it physically follows the suspend/resume block in the file.
- `updateMinMax` is a standalone module (`15-minmax.js`) because it physically sits between `buildExportButtons` (end of cards) and `FREEZING_LINE_PLUGIN` (start of charts) — it cannot be merged in either direction without breaking the identity gate at Level 1. At Level 3, it will be absorbed into the sensor-cards component.

**Generator interaction:** `render_sensor_config.py` still writes into the assembled `dashboard.js` at the `SENSOR_MANIFEST:DEFAULT_SENSOR_META` markers. The markers live in `02-sensor-defs.js` during editing but land in `dashboard.js` after bundling.

**Pipeline at Level 1:**
```
src/*.js → bundle-dashboard.sh → dashboard.js → render_sensor_config.py (updates markers) → minify-dashboard.sh (operates on dashboard.html, still manual) → generate-header.sh → dashboard.h
```

### 4.2 After Level 2 — Generated HTML (`v7.6.5.2`–`v7.6.5.3`)

```
dashboard/
  src/
    ... (same module files as Level 1)
  dashboard.tmpl.html       ← NEW: canonical HTML/CSS template with {{JS_PLACEHOLDER}}
  dashboard.js              ← GENERATED (bundle + generator); committed
  dashboard.html            ← GENERATED from template + JS; committed, marked as generated
  dashboard.h               ← committed gzip C header (unchanged role)
scripts/
  bundle-dashboard.sh       ← concatenates src/*.js → dashboard.js
  build-dashboard.sh        ← NEW: injects dashboard.js into template → dashboard.html
  minify-dashboard.sh       ← now operates on generated dashboard.html
  generate-header.sh        ← unchanged
```

**Pipeline at Level 2:**
```
src/*.js → bundle-dashboard.sh → dashboard.js → render_sensor_config.py (updates markers) → build-dashboard.sh (template + JS → dashboard.html) → minify-dashboard.sh → generate-header.sh → dashboard.h
```

**LESSON-OPS-043 is eliminated at this level.** There is no manual mirror. `dashboard.html` is a build output.

### 4.3 After Level 3 — Component Model (`v7.6.5.4`–`v7.6.5.7`)

```
dashboard/
  components/
    sensor-cards/
      index.js              ~330 lines — card renderers
      styles.css            — sensor, network, system card CSS
      template.html         — sensor grid HTML fragment
    charts/
      index.js              ~340 lines — chart init, opts, theme
      styles.css            — chart panel CSS
      template.html         — chart canvas sections
    custom-range/
      index.js              ~300 lines — CustomRange IIFE
      styles.css            — calendar modal CSS
      template.html         — modal HTML
    auth-modal/
      index.js              ~180 lines — requestManagementCredentials, auth dialog logic
      styles.css            — auth modal CSS
      template.html         — auth dialog HTML
    settings-panel/
      index.js              ~400 lines — management actions, import engine, export, storage stats
      styles.css            — storage/management CSS
      template.html         — management/storage/export HTML
    gateway-panel/
      index.js              ~500 lines — aggregator detection, selector, summary, settings, satellite mgmt
      styles.css            — gateway/settings CSS
      template.html         — gateway panel HTML
    live-view/
      index.js              ~360 lines — SSE, polling, handleState, telemetry, live device updates
      styles.css            — telemetry CSS
      template.html         — telemetry/live section HTML
    device-info/
      index.js              ~130 lines — device info, GPIO, board info
      styles.css            — top-grid, device-info, gpio CSS
      template.html         — top-grid HTML (includes existing C3 board SVG)
  core/
    app-shell.js            — App namespace, plugin shell, error logger
    config.js               — transport detection, config wiring, App.State
    sensor-defs.js          — sensor definitions, generator markers, helpers, METRIC_FORMATTERS
    history.js              — history fetch, parse, CSV builders
    manifest.js             — manifest loading, sensor config
    status-snapshot.js      — status/telemetry snapshot loading
    ui-helpers.js           — esc*, format*, toggle, bindEvents, history range
    staleness-derived.js    — derived values, staleness checks, min/max period
    suspend-resume.js       — network suspend/resume
    boot.js                 — App.Boot.start orchestrator
    base.css                — :root, theme tokens, global resets, responsive breakpoints
  dashboard.tmpl.html       ← shell template with {{CSS:*}} + {{COMPONENT:*}} + {{JS_PLACEHOLDER}} slots
  dashboard.js              ← GENERATED assembled runtime; committed
  dashboard.html            ← GENERATED assembled HTML; committed
  dashboard.h               ← committed gzip C header
scripts/
  bundle-dashboard.sh       ← assembles core/*.js + components/*/index.js → dashboard.js
  build-dashboard.sh        ← three-pass: CSS → component templates → JS injection → dashboard.html
  minify-dashboard.sh       ← unchanged
  generate-header.sh        ← unchanged
```

**Future enhancement (not a Phase X deliverable):** Board-specific SVG images can be added under `components/device-info/boards/` as they are created (e.g., `esp32-c3-supermini.svg`, `esp32-s3-devkitc1.svg`, `esp32-wroom-32d.svg`). The component's `index.js` selects the correct SVG at runtime based on the board identifier from `/api/status`. During `v7.6.5.5` (HTML template extraction), the existing C3 SVG is extracted from `dashboard.tmpl.html` into `components/device-info/template.html` as part of the normal template extraction — no new SVG creation required.

**Pipeline at Level 3:**
```
core/*.js + components/*/index.js → bundle-dashboard.sh → dashboard.js
  → render_sensor_config.py (updates markers)
  → build-dashboard.sh:
      pass 0: {{CSS:name}} → inline core/base.css + components/*/styles.css
      pass 1: {{COMPONENT:name}} → inline components/*/template.html
      pass 2: {{JS_PLACEHOLDER}} → inline dashboard.js
      → dashboard.html
  → minify-dashboard.sh → dashboard.min.html
  → generate-header.sh → dashboard.h
```

---

## 5. Migration Safety Rules

These rules apply to **every** Phase X step without exception.

1. **No behavior changes.** Structural reorganization only. Same endpoints, same DOM, same chart behavior, same transport, same management actions. If a step reveals a pre-existing bug, the fix is a separate PR before the refactor step.

2. **All existing Playwright tests must pass after each step.** All four fixture sets (`3sensor`, `mixed`, `system`, `aggregator`) must be green. No test may be deleted or disabled to make a refactor step pass.

3. **`dashboard.h` bit-for-bit identity gate.** Before and after each step, the generated `dashboard.h` must produce an identical SHA-256 hash. This is enforced by `preflight.sh`.

4. **Each step must be independently revertable.** Each step is a separate PR. Reverting step N must not break step N-1.

5. **No heavy bundler toolchain.** No Webpack, Vite, Rollup, or similar. Build scripts use bash + Python exact text substitution. The operator must be able to run the full pipeline with no `npm install` beyond what already exists (html-minifier-terser).

6. **Generated artifacts stay committed and reviewable.** `dashboard.js`, `dashboard.html`, and `dashboard.h` remain in version control, clearly marked as generated. Preflight enforces sync.

7. **Module dependency order must be acyclic.** The concatenation order in `bundle-dashboard.sh` is the canonical load order. No module may call a function defined in a later module.

8. **POST semantics unchanged.** All `fetch()` POST calls must retain `Content-Type: application/x-www-form-urlencoded` and `body: 'a=1'` per LESSON-OPS-099. Move POST-related code intact; do not refactor request construction.

9. **Aggregator is overlay, not fork.** Per LESSON-OPS-074, aggregator components augment the base dashboard — they never replace core components or fork the boot sequence.

10. **CSS cascade order preserved.** CSS assembly order must match the current order in `dashboard.html`. Do not alphabetize or auto-sort components. CSS ordering is explicit in the build script.

11. **Device testing at Level 2 transition.** Before and after `v7.6.5.3` (generated HTML becomes canonical), load the dashboard on a real device and verify: page loads, SSE/polling connects, charts render, management actions work. This is per LESSON-OPS-051.

---

## 6. Versioned Implementation Steps

### `v7.6.4.0` — Documentation restructuring (pre-step)

**Level:** Pre-step — Documentation only
**Goal:** Split the 3,069-line `Docs/bugs-and-lessons-learned.md` and the 1,593-line `Docs/writing-prompts-for-coding-agents-guide.md` into domain-scoped files so that Phase X coding agent prompts reference only the relevant domain file (~3K–4K tokens instead of ~15K–23K tokens).

#### Scope

- Split `Docs/bugs-and-lessons-learned.md` into domain-scoped files under `Docs/lessons/`.
- Split `Docs/writing-prompts-for-coding-agents-guide.md` into `Docs/writing-guide/` files.
- Original files become redirect stubs.
- Update `prompts/prompt-index-and-workflow.md` to reference new file paths.
- **No code changes, no test changes, no build pipeline changes.**

#### Documentation split targets

**Bugs and lessons (`Docs/bugs-and-lessons-learned.md` → `Docs/lessons/`):**

| File | Content scope | Est. lines |
|---|---|---|
| `Docs/lessons/index.md` | Cross-reference: which file covers which domain; how to find a lesson by number | ~100 |
| `Docs/lessons/dashboard.md` | Dashboard-specific: LESSON-OPS-043, -050, -052, -055, -065, -099, -111; BUG-039, -054, -056, -080, -081 | ~600 |
| `Docs/lessons/firmware.md` | Firmware/ESP-IDF/NVS: LESSON-OPS-056, -068, -069, -070, -072, -074, -100, -101, -102, -103, -104, -105, -106, -107, -108, -109; BUG-057, -061, -062, -064, -075, -076, -077, -078, -079 | ~800 |
| `Docs/lessons/build-pipeline.md` | Build, generators, regeneration: LESSON-OPS-066, -067, -071, -077, -090, -091, -097, -098 | ~400 |
| `Docs/lessons/testing.md` | Playwright, CI, fixtures, mocks: LESSON-OPS-057, -063, -080, -083, -112, -113, -114; BUG-051 | ~500 |
| `Docs/lessons/operations.md` | Device testing, flashing, USB, deployment: LESSON-OPS-051, -058, -069, -073 | ~300 |

**Writing guide (`Docs/writing-prompts-for-coding-agents-guide.md` → `Docs/writing-guide/`):**

| File | Content | Est. lines |
|---|---|---|
| `Docs/writing-guide/methodology.md` | §1–3: Core prompt anatomy, required sections, how to structure a prompt | ~600 |
| `Docs/writing-guide/gap-catalog.md` | §4: All 17 gap categories with examples — reference material | ~900 |
| `Docs/writing-guide/checklists/dashboard.md` | Dashboard-specific prompt patterns: async safety, module-scoped prompts, POST body requirements | ~100+ |
| `Docs/writing-guide/checklists/firmware.md` | Firmware-specific prompt patterns: deferred task pattern, NVS namespace isolation, Arduino-ism detection, `canHandle()` registration | ~100+ |

#### Acceptance criteria

- [ ] `Docs/lessons/` directory exists with all domain files
- [ ] Every LESSON-OPS and BUG entry from the original file appears in exactly one domain file
- [ ] `Docs/lessons/index.md` cross-references all entries with file locations
- [ ] Original `Docs/bugs-and-lessons-learned.md` contains redirect notice
- [ ] `Docs/writing-guide/` directory exists with methodology + gap catalog + checklists
- [ ] `prompts/prompt-index-and-workflow.md` updated to reference new file paths
- [ ] No code changes, no test changes

#### Risk: **Very Low** — pure documentation; no code, no tests, no pipeline
#### Estimated effort: 1 session
#### Context window: ~20K tokens (read both large docs once to split)

---

### `v7.6.5.0` — Module split: extract src/ modules from monolith

**Level:** Level 1 — Module Split
**Goal:** Split the 3,955-line `dashboard.js` monolith into 21 ordered source modules under `dashboard/src/`. Introduce `bundle-dashboard.sh`. The assembled `dashboard.js` must be content-identical to the pre-split monolith.

#### Scope

- Create `dashboard/src/` directory with 21 module files.
- Create `scripts/bundle-dashboard.sh` with `--write` and `--check` modes.
- `dashboard.js` becomes a generated artifact (content-identical to current).
- `dashboard.html` is **unchanged** — still manually maintained.
- `dashboard.h` is **unchanged**.
- No behavior change.

#### Files modified

| Action | File |
|---|---|
| CREATE dir | `dashboard/src/` |
| CREATE × 21 | All `dashboard/src/*.js` files listed in §4.1 |
| CREATE | `scripts/bundle-dashboard.sh` |
| REGENERATE | `dashboard/dashboard.js` (content-identical to pre-split) |
| NO CHANGE | `dashboard/dashboard.html` |
| NO CHANGE | `dashboard/dashboard.h` |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.5.0` |

#### `bundle-dashboard.sh` contract

```bash
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
  echo "" >> "$TMP"
done

MODE="${1:---write}"
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
```

**Note:** The bundle does NOT add header comments like "Auto-generated." The output must be byte-for-byte identical to the current `dashboard.js` so that the generator markers remain in place and `dashboard.h` is unchanged.

#### Identity gate

```bash
SHA_BEFORE=$(sha256sum dashboard/dashboard.js | cut -d' ' -f1)
bash scripts/bundle-dashboard.sh --write
SHA_AFTER=$(sha256sum dashboard/dashboard.js | cut -d' ' -f1)
[[ "$SHA_BEFORE" == "$SHA_AFTER" ]] || { echo "IDENTITY GATE FAILED"; exit 1; }
```

#### Acceptance criteria

- [ ] All 21 module files exist in `dashboard/src/`
- [ ] `bash scripts/bundle-dashboard.sh --write` runs without error
- [ ] SHA-256 of bundled `dashboard.js` matches pre-split `dashboard.js`
- [ ] `bash scripts/generate-header.sh` produces byte-identical `dashboard.h`
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes
- [ ] No behavior change — dashboard functionality identical on device

#### Risk: **Medium**
The split itself is mechanical, but incorrect splitting at a closure boundary or IIFE scope could change behavior. The identity gate catches this.

#### Estimated effort: 1.5–2 sessions
#### Context window for this task: ~35K tokens (must read full monolith once to split)

---

### `v7.6.5.1` — Wire bundle into CI and preflight

**Level:** Level 1 — Module Split
**Goal:** Integrate `bundle-dashboard.sh --check` into CI and `preflight.sh` so that any module edit without rebundling is caught before merge.

#### Scope

- Add `dashboard_js_bundle_sync` check to `preflight.sh`.
- Add bundle step to CI workflow before Playwright run.
- Update developer documentation with new pipeline step.
- Update LESSON-OPS-091 (regeneration pipeline) in `Docs/bugs-and-lessons-learned.md`.

#### Files modified

| Action | File |
|---|---|
| MODIFY | `scripts/preflight.sh` — add `dashboard_js_bundle_sync` check |
| MODIFY | `.github/workflows/browser-tests.yml` — add `bundle-dashboard.sh --check` step |
| MODIFY | `Docs/bugs-and-lessons-learned.md` — update LESSON-OPS-091 pipeline |
| MODIFY | `Docs/aggregator-setup.md` — update regeneration pipeline |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.5.1` |

#### Updated canonical regeneration pipeline (extends LESSON-OPS-091 / Critical Rule 37)

```
1. python3 scripts/render_sensor_config.py --write
2. node tests/fixtures/generate-fixtures.js
3. bash scripts/bundle-dashboard.sh --write          ← NEW
4. python3 scripts/render_sensor_config.py --write   ← re-run to update generator markers in bundle
5. bash scripts/minify-dashboard.sh
6. bash scripts/generate-header.sh
7. python3 scripts/render_sensor_config.py --check
```

**Note:** Step 4 re-runs the generator after bundling because `bundle-dashboard.sh` overwrites `dashboard.js`, which erases the generator's marker content. The generator must re-inject after every bundle. Preflight's `--check` mode in step 7 verifies the final state.

#### Acceptance criteria

- [ ] CI workflow includes bundle check before Playwright
- [ ] `dashboard_js_bundle_sync` preflight check passes on clean tree
- [ ] Editing a module without rebundling → preflight FAIL (verified)
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes

#### Risk: **Very Low** — pure CI/tooling change
#### Estimated effort: 0.5 sessions
#### Context window: ~5K tokens

---

### `v7.6.5.2` — Create dashboard.tmpl.html and build-dashboard.sh

**Level:** Level 2 — Generated HTML
**Goal:** Extract the static HTML structure from `dashboard.html` into `dashboard.tmpl.html`. Create `build-dashboard.sh` that injects `dashboard.js` into the template. Prove bit-for-bit equivalence. `dashboard.html` is NOT yet retired — this step only proves the pipeline works.

#### Scope

- Create `dashboard/dashboard.tmpl.html` from `dashboard.html`:
  - Keep all HTML structure (lines 1–935).
  - Keep all CSS (lines 23–515).
  - Replace the entire `<script>...</script>` block (lines 936–4898) with `<script>\n{{JS_PLACEHOLDER}}\n</script>`.
- Create `scripts/build-dashboard.sh`.
- Prove generated `dashboard.html` is byte-for-byte identical to the hand-maintained version.
- Add `dashboard_tmpl_has_placeholder` preflight check.

#### Files modified

| Action | File |
|---|---|
| CREATE | `dashboard/dashboard.tmpl.html` |
| CREATE | `scripts/build-dashboard.sh` |
| MODIFY | `scripts/preflight.sh` — add `dashboard_tmpl_has_placeholder` check |
| NO CHANGE | `.gitignore` (dashboard.html still committed) |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.5.2` |

#### `build-dashboard.sh` contract

```bash
#!/usr/bin/env bash
# Injects dashboard.js into dashboard.tmpl.html → dashboard.html
# Usage: build-dashboard.sh [--write|--check]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - "$ROOT/dashboard/dashboard.tmpl.html" "$ROOT/dashboard/dashboard.js" << 'PYEOF'
import sys, os
tmpl = open(sys.argv[1]).read()
js = open(sys.argv[2]).read()
if '{{JS_PLACEHOLDER}}' not in tmpl:
    print("ERROR: {{JS_PLACEHOLDER}} not found in template", file=sys.stderr)
    sys.exit(1)
out = tmpl.replace('{{JS_PLACEHOLDER}}', js, 1)
out_path = os.path.join(os.path.dirname(sys.argv[1]), 'dashboard.html')
mode = sys.argv[3] if len(sys.argv) > 3 else '--write'
if mode == '--check':
    existing = open(out_path).read()
    if existing == out:
        print("OK: dashboard.html matches template + JS")
    else:
        print("FAIL: dashboard.html out of sync with template + JS")
        sys.exit(1)
else:
    open(out_path, 'w').write(out)
    print(f"Built {out_path}")
PYEOF
```

#### Level 2 bit-for-bit gate

```bash
# Save the current hand-maintained file
cp dashboard/dashboard.html dashboard/dashboard.html.orig
# Run the full pipeline
bash scripts/bundle-dashboard.sh --write
python3 scripts/render_sensor_config.py --write
bash scripts/build-dashboard.sh
# Gate: must produce empty diff
diff dashboard/dashboard.html dashboard/dashboard.html.orig
# If diff exits non-zero, template extraction has a whitespace or encoding difference — fix before proceeding
```

This diff must exit 0 before proceeding to v7.6.5.3.

#### Acceptance criteria

- [ ] `dashboard.tmpl.html` exists with exactly one `{{JS_PLACEHOLDER}}`
- [ ] `bash scripts/build-dashboard.sh` produces byte-for-byte identical `dashboard.html` vs. hand-maintained version
- [ ] `diff` of generated vs. original exits 0
- [ ] `bash scripts/generate-header.sh` produces identical `dashboard.h`
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes

#### Risk: **Medium** — whitespace differences between template injection and original can cause non-zero diff. Use Python exact substitution, never prettify/beautify.
#### Estimated effort: 1–2 sessions
#### Context window: ~20K tokens (read HTML shell, no JS logic needed)

---

### `v7.6.5.3` — Make generated HTML canonical; retire manual mirror

**Level:** Level 2 — Generated HTML
**Goal:** Wire `build-dashboard.sh` into CI. Mark `dashboard.html` as generated. Update `bump-version.sh`. LESSON-OPS-043 is now permanently resolved.

#### Scope

- Add `build-dashboard.sh` step to CI workflow.
- Add `<!-- GENERATED — Do not edit -->` header to `dashboard.html` output.
- Update `bump-version.sh` to use pipeline instead of `sed` on `dashboard.html`.
- Add `dashboard_html_matches_build` preflight check.
- Update `Docs/bugs-and-lessons-learned.md` — mark LESSON-OPS-043 as structurally resolved.
- **Device testing required** — load dashboard on real device before and after this step.

#### Files modified

| Action | File |
|---|---|
| MODIFY | `.github/workflows/browser-tests.yml` — add `build-dashboard.sh` step |
| MODIFY | `scripts/build-dashboard.sh` — add `<!-- GENERATED -->` header to output |
| MODIFY | `scripts/bump-version.sh` — replace `sed` on `dashboard.html` with pipeline re-run |
| MODIFY | `scripts/preflight.sh` — add `dashboard_html_matches_build` check |
| MODIFY | `Docs/bugs-and-lessons-learned.md` — LESSON-OPS-043 structurally resolved note |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.5.3` |

#### What this permanently eliminates

| Before (every dashboard PR) | After v7.6.5.3 |
|---|---|
| Edit `dashboard.js` | Edit `dashboard/src/<module>.js` |
| Manually copy change to `dashboard.html` | (eliminated — build-dashboard.sh does this) |
| Risk: forgot the mirror → fixup commit | Risk: impossible — `dashboard.html` is not a source file |

#### Updated canonical pipeline (final Level 2 form)

```
1. python3 scripts/render_sensor_config.py --write
2. node tests/fixtures/generate-fixtures.js
3. bash scripts/bundle-dashboard.sh --write
4. python3 scripts/render_sensor_config.py --write   ← re-inject markers into bundle
5. bash scripts/build-dashboard.sh                    ← template + JS → dashboard.html
6. bash scripts/minify-dashboard.sh
7. bash scripts/generate-header.sh
8. python3 scripts/render_sensor_config.py --check
```

#### Acceptance criteria

- [ ] CI pipeline includes `build-dashboard.sh` before minification
- [ ] `dashboard.html` header contains `<!-- GENERATED -->` comment
- [ ] `bump-version.sh` no longer uses `sed` on `dashboard.html`
- [ ] `dashboard_html_matches_build` preflight check passes
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes
- [ ] **Device test:** Dashboard loaded on real ESP32, page loads, SSE/polling connects, charts render, management actions work
- [ ] LESSON-OPS-043 cross-referenced as structurally resolved

#### Risk: **Low** (if v7.6.5.2 bit-for-bit gate passed)
#### Estimated effort: 0.5–1 sessions
#### Context window: ~5K tokens

---

### `v7.6.5.4` — Component directory scaffolding (file moves only)

**Level:** Level 3 — Component Model
**Goal:** Create `dashboard/components/` and `dashboard/core/` directories. Move module files from `dashboard/src/` into component/core directories. Update `bundle-dashboard.sh` paths. No behavior change.

#### Scope

- Create component and core directory structure per §4.3.
- Move source modules into appropriate locations.
- Update `bundle-dashboard.sh` to use new paths.
- Remove `dashboard/src/` directory.

#### File moves

| Source | Destination |
|---|---|
| `src/00-app-shell.js` | `core/app-shell.js` |
| `src/01-config-state.js` | `core/config.js` |
| `src/02-sensor-defs.js` | `core/sensor-defs.js` |
| `src/03-history-fetch.js` | `core/history.js` |
| `src/04-manifest.js` | `core/manifest.js` |
| `src/05-status-snapshot.js` | `core/status-snapshot.js` |
| `src/06-ui-helpers.js` | `core/ui-helpers.js` |
| `src/07-staleness-derived.js` | `core/staleness-derived.js` |
| `src/08-custom-range.js` | `components/custom-range/index.js` |
| `src/09-export.js` + `src/10-storage-stats.js` | `components/settings-panel/index.js` (concatenated with 13-import) |
| `src/11-suspend-resume.js` | `core/suspend-resume.js` |
| `src/12-management.js` | `components/auth-modal/index.js` |
| `src/13-import.js` | concatenated into `components/settings-panel/index.js` |
| `src/14-cards.js` + `src/15-minmax.js` | `components/sensor-cards/index.js` (concatenated) |
| `src/16-charts.js` | `components/charts/index.js` |
| `src/17-live-updates.js` + `src/18-transport.js` | `components/live-view/index.js` (concatenated) |
| `src/19-aggregator.js` | `components/gateway-panel/index.js` |
| `src/20-boot.js` | `core/boot.js` |

**Note:** Some modules are concatenated during the move (transport + live-devices → live-view, import + export → settings-panel). This is because the Level 3 component boundaries group related functionality more coarsely than the Level 1 modules. The concatenation is mechanical — no code changes.

#### Acceptance criteria

- [ ] All files moved to component/core directories
- [ ] `dashboard/src/` directory removed
- [ ] `bash scripts/bundle-dashboard.sh` succeeds with new paths
- [ ] Bundled `dashboard.js` is content-identical to v7.6.5.3 output
- [ ] `bash scripts/generate-header.sh` produces identical `dashboard.h`
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes

#### Risk: **Low** — pure file moves + path updates
#### Estimated effort: 1 session
#### Context window: ~5K tokens

---

### `v7.6.5.5` — Component HTML template extraction

**Level:** Level 3 — Component Model
**Goal:** Extract HTML markup for each dashboard section from `dashboard.tmpl.html` into per-component `template.html` files. Replace section markup with `{{COMPONENT:name}}` markers. Update `build-dashboard.sh` to resolve component templates in a first pass before JS injection.

#### Scope

- Create `template.html` for each component containing its HTML section.
- Replace HTML sections in `dashboard.tmpl.html` with `{{COMPONENT:name}}` markers.
- Update `build-dashboard.sh` for two-pass assembly.

#### Component template targets

| Component | HTML section | DOM identifiers |
|---|---|---|
| `device-info` | Top grid, GPIO, management cards | `#c3DescriptionBlock`, `.top-grid` |
| `sensor-cards` | Sensor grid | `#sensorGrid` |
| `charts` | Chart canvases, history controls | `.charts-row`, `#chartSection` |
| `settings-panel` | Storage, export, import, management | `#storageCard`, `#exportSection` |
| `custom-range` | Calendar modal | `#customRangeModal` |
| `auth-modal` | Auth dialog | `#authModal` |
| `live-view` | Telemetry panel | `#telemetrySection` |
| `gateway-panel` | Aggregator selector, summary, settings | `#hdr-gateways`, `#gwSelector` |

#### `build-dashboard.sh` two-pass contract

```
Pass 1: For each {{COMPONENT:name}} in dashboard.tmpl.html,
        substitute contents of dashboard/components/<name>/template.html.
        → Produces fully-assembled HTML shell (all panels inlined).

Pass 2: Inject dashboard.js at {{JS_PLACEHOLDER}}.
        → Produces final dashboard/dashboard.html.
```

#### Acceptance criteria

- [ ] All component `template.html` files exist
- [ ] Two-pass assembly produces byte-identical `dashboard.html` vs. v7.6.5.4 output
- [ ] `bash scripts/generate-header.sh` produces identical `dashboard.h`
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes

#### Risk: **Medium** — HTML extraction must preserve whitespace exactly. Use Python exact substitution, never beautify.
#### Estimated effort: 1–2 sessions
#### Context window: ~15K tokens

---

### `v7.6.5.6` — Component CSS extraction

**Level:** Level 3 — Component Model
**Goal:** Extract CSS blocks from `dashboard.tmpl.html` into per-component `styles.css` files and `core/base.css`. Update `build-dashboard.sh` for three-pass assembly.

#### Scope

- Create `styles.css` for each component using the CSS mapping from §3.3.
- Create `core/base.css` for global CSS (`:root`, theme tokens, resets, responsive breakpoints).
- Replace `<style>` content in `dashboard.tmpl.html` with `{{CSS_PLACEHOLDER}}`.
- Update `build-dashboard.sh` for three-pass assembly (CSS → templates → JS).

#### `build-dashboard.sh` three-pass contract

```
Pass 0: Concatenate core/base.css + components/*/styles.css in order.
        Replace {{CSS_PLACEHOLDER}} in dashboard.tmpl.html.
        → Produces CSS-complete template.

Pass 1: Resolve {{COMPONENT:name}} template markers.
        → Produces fully-assembled HTML shell.

Pass 2: Inject dashboard.js at {{JS_PLACEHOLDER}}.
        → Produces final dashboard/dashboard.html.
```

#### Acceptance criteria

- [ ] All component `styles.css` files exist
- [ ] `core/base.css` contains only global CSS
- [ ] Three-pass assembly produces byte-identical `dashboard.html` vs. v7.6.5.5 output
- [ ] `bash scripts/generate-header.sh` produces identical `dashboard.h`
- [ ] All Playwright tests pass across all four fixture sets
- [ ] Visual regression: screenshot before and after must show no rendered difference
- [ ] `bash scripts/preflight.sh` passes

#### Risk: **Medium** — CSS boundary identification requires careful audit. If a CSS rule targets elements across component boundaries, it stays in `core/base.css`.
#### Estimated effort: 1–2 sessions
#### Context window: ~10K tokens

---

### `v7.6.5.7` — Test spec split

**Level:** Level 3 — Component Model (test infrastructure)
**Goal:** Split the 1,853-line `dashboard.spec.js` monolith into domain-scoped test files that mirror the component structure.

#### Scope

- Split `dashboard.spec.js` into focused test files.
- Each test file covers groups that map to one component or one domain.
- Shared test helpers and fixture setup extracted into a common helper.
- All test counts remain unchanged (402 pass / 0 fail).

#### Proposed test file structure

| Test file | Groups | Lines (approx) |
|---|---|---|
| `tests/browser/boot-structure.spec.js` | 1–3 | ~80 |
| `tests/browser/sensor-cards.spec.js` | 2, 11, 17, 18 | ~200 |
| `tests/browser/history-charts.spec.js` | 4, 5, 13, 16 | ~300 |
| `tests/browser/theme-export.spec.js` | 6, 7, 8 | ~80 |
| `tests/browser/manifest.spec.js` | 9, 10 (already separate file) | existing |
| `tests/browser/metric-formatters.spec.js` | 12 | ~60 |
| `tests/browser/regression.spec.js` | 14, 15 | ~200 |
| `tests/browser/aggregator.spec.js` | 19 | ~130 |
| `tests/browser/system-devices.spec.js` | 20 | ~60 |
| `tests/browser/satellite-management.spec.js` | 21 | ~210 |
| `tests/browser/test-helpers.js` | Shared setup, fixture detection, skip guards | ~100 |

**Note:** `dashboard.spec.js` is retained as an empty file that imports all sub-specs (or removed entirely if Playwright auto-discovers `*.spec.js` in the directory).

#### Acceptance criteria

- [ ] All test groups exist in domain-scoped files
- [ ] Total test count unchanged: 402 pass / 0 fail across all four fixture sets
- [ ] Shared test helpers extracted into `test-helpers.js`
- [ ] Each test file is loadable independently for targeted debugging
- [ ] `bash scripts/preflight.sh` passes

#### Risk: **Low** — test file splitting is mechanical
#### Estimated effort: 1 session
#### Context window: ~15K tokens (read full spec once to split)

---

### `v7.6.5.8` — Phase X closure: critical rules, preflight guards, results

**Level:** Closure
**Goal:** Update all documentation to reflect the new architecture. Add Phase-X-specific preflight guards. Retire superseded critical rules. Phase X complete.

#### Scope

- Add component/core file existence checks to `preflight.sh`.
- Update `Docs/writing-guide/checklists/dashboard.md` with Phase X patterns (module-scoped prompts, bundle pipeline).
- Update `prompts/prompt-index-and-workflow.md`:
  - Phase X steps marked complete.
  - Critical Rule 6 marked as structurally resolved (by Level 2).
  - Critical Rule 37 updated with new pipeline steps.
  - New critical rule: "Edit source modules in `dashboard/src/` or `dashboard/components/` — never edit `dashboard.js` or `dashboard.html` directly."
- Update `README.md` with dashboard architecture overview.
- Produce Phase X results document.

**Note:** Documentation restructuring (the `Docs/lessons/` and `Docs/writing-guide/` splits) was completed in `v7.6.4.0`. This step only adds Phase-X-specific lessons to the already-split domain files.

#### Critical rules impact

| Rule | Action |
|---|---|
| Rule 6 (mirror dashboard.js → dashboard.html) | Mark as "structurally resolved by Phase X v7.6.5.3" |
| Rule 37 (regeneration pipeline) | Update with new pipeline steps (bundle → generator → build-html → minify → header) |
| NEW rule | "Source modules live in `dashboard/core/` and `dashboard/components/*/`. `dashboard.js` and `dashboard.html` are generated — never edit directly." |
| NEW rule | "After any module edit, run the full pipeline: `bundle-dashboard.sh --write && render_sensor_config.py --write && build-dashboard.sh && minify-dashboard.sh && generate-header.sh`" |

#### Acceptance criteria

- [ ] All preflight component existence checks pass
- [ ] Documentation reflects new architecture
- [ ] Critical rules table updated in `prompts/prompt-index-and-workflow.md`
- [ ] All Playwright tests pass across all four fixture sets
- [ ] Phase X results document produced

#### Risk: **Low** — documentation and tooling only
#### Estimated effort: 1 session
#### Context window: ~12K tokens

---

## 7. Build Pipeline Changes Summary

### Current pipeline

```
dashboard.html → minify-dashboard.sh → dashboard.min.html → generate-header.sh → dashboard.h
```

### After Level 1

```
dashboard/src/*.js
  → bundle-dashboard.sh → dashboard.js
  → render_sensor_config.py (updates markers in dashboard.js)

dashboard.html (still manual)
  → minify-dashboard.sh → dashboard.min.html → generate-header.sh → dashboard.h
```

### After Level 2

```
dashboard/src/*.js
  → bundle-dashboard.sh → dashboard.js
  → render_sensor_config.py (updates markers)

dashboard.tmpl.html + dashboard.js
  → build-dashboard.sh → dashboard.html
  → minify-dashboard.sh → dashboard.min.html → generate-header.sh → dashboard.h
```

### After Level 3

```
dashboard/core/*.js + dashboard/components/*/index.js
  → bundle-dashboard.sh → dashboard.js
  → render_sensor_config.py (updates markers)

dashboard/core/base.css + dashboard/components/*/styles.css
  + dashboard/components/*/template.html
  + dashboard.tmpl.html + dashboard.js
  → build-dashboard.sh (3-pass: CSS → templates → JS) → dashboard.html
  → minify-dashboard.sh → dashboard.min.html → generate-header.sh → dashboard.h
```

---

## 8. Documentation Refactoring

**This work is performed in `v7.6.4.0` (pre-step), not at Phase X closure.**

### Problem

`Docs/bugs-and-lessons-learned.md` is 3,069 lines covering dashboard bugs, firmware bugs, build pipeline issues, testing lessons, and operational procedures. A coding agent working on a dashboard module doesn't need to read firmware lessons. A coding agent working on firmware doesn't need dashboard CSS lessons.

`Docs/writing-prompts-for-coding-agents-guide.md` is 1,593 lines. The gap catalog (§4, ~900 lines) is reference material rarely needed in full during prompt authoring.

### Solution

Split into domain-scoped files under `Docs/lessons/` and `Docs/writing-guide/` as part of `v7.6.4.0`. See §6 `v7.6.4.0` for the full file list and acceptance criteria.

### Prompt impact

After `v7.6.4.0`, every Phase X implementation prompt references only the relevant domain file:
- Dashboard feature prompt → `Docs/lessons/dashboard.md`
- Firmware handler prompt → `Docs/lessons/firmware.md`
- Test infrastructure prompt → `Docs/lessons/testing.md`

This immediately reduces the documentation token burden from ~15K–23K to ~3K–6K per prompt.

---

## 9. Coding Agent Task Size Analysis

### Baseline — Today (pre-refactor)

| Task type | Files needed | Est. tokens |
|---|---|---|
| Any dashboard feature | `dashboard.js` (3,955 lines) + `dashboard.html` (4,900 lines, mirror) | ~55K–70K |
| Dashboard bug fix | Full monolith × 2 | ~55K–70K |
| Test for new feature | Full monolith + full test spec (1,853 lines) | ~45K |
| Build pipeline change | Both scripts + both dashboard files | ~50K |

### After Level 1 (Module Split)

| Task type | Files needed | Est. tokens |
|---|---|---|
| Fix export bug | `src/09-export.js` (~64 ln) + `src/02-sensor-defs.js` | ~4K |
| New sensor card type | `src/14-cards.js` (~270 ln) | ~5K |
| Transport change | `src/18-transport.js` + `src/01-config-state.js` | ~6K |
| Custom range bug | `src/08-custom-range.js` (~329 ln) | ~5K |
| Charts theme fix | `src/16-charts.js` (~200 ln) | ~4K |
| Settings panel feature | `src/19-aggregator.js` (~508 ln) | ~8K |

Mirror requirement still exists at Level 1 but is mitigated — edit module, rebundle, CI catches sync.

### After Level 2 (Generated HTML)

Same per-module sizes as Level 1. **No `dashboard.html` to read or mirror.** JS changes never touch HTML. HTML structural changes go into `dashboard.tmpl.html` (no JS).

### After Level 3 (Component Model) + test split + documentation split

| Task type | Files needed | Est. tokens |
|---|---|---|
| New Phase 7 dashboard feature | One component dir (~3 files, ~500 lines) + `core/state.js` + domain test file + `Docs/lessons/dashboard.md` | ~12K–15K |
| Charts feature | `components/charts/` (~3 files) + test file | ~8K |
| Settings panel feature | `components/settings-panel/` + test file | ~10K |
| Gateway panel feature | `components/gateway-panel/` + test file | ~10K |
| Build pipeline change | `build-dashboard.sh` (~80 ln) | ~2K |

**Target achieved: all typical tasks fit within 15K tokens, well within the 30K–40K budget.**

### Per-step context estimate

| Version | Est. tokens | Notes |
|---|---|---|
| `v7.6.5.0` | ~35K | Only step requiring full monolith read |
| `v7.6.5.1` | ~5K | CI/preflight only |
| `v7.6.5.2` | ~20K | HTML template extraction (no JS) |
| `v7.6.5.3` | ~5K | Pipeline wiring |
| `v7.6.5.4` | ~5K | File moves + path updates |
| `v7.6.5.5` | ~15K | HTML section extraction |
| `v7.6.5.6` | ~10K | CSS extraction |
| `v7.6.5.7` | ~15K | Test spec split (read once) |
| `v7.6.5.8` | ~12K | Documentation + closure |

---

## 10. Rollout Order and Gate Conditions

### Sequence

0. **Documentation pre-step** (`v7.6.4.0`): Immediate token reduction for all subsequent prompts. Zero risk.
1. **Level 1 first** (`v7.6.5.0`–`v7.6.5.1`): Immediate context reduction. Lowest risk.
2. **Level 2 second** (`v7.6.5.2`–`v7.6.5.3`): Eliminates LESSON-OPS-043 permanently. Highest-value single change.
3. **Level 3 third** (`v7.6.5.4`–`v7.6.5.6`): Scales to Phase 7/E. Highest effort.
4. **Test + docs last** (`v7.6.5.7`–`v7.6.5.8`): Clean closure.

### Gate conditions

| Gate | Condition |
|---|---|
| Pre-step → Level 1 | v7.6.4.0 merged, no code changes, doc files verified |
| Level 1 → Level 2 | v7.6.5.1 merged, CI green, preflight passes, bundle identity confirmed |
| Level 2 → Level 3 | v7.6.5.3 merged, bit-for-bit gate passed, device testing confirmed, LESSON-OPS-043 marked resolved |
| Level 3 → Test/docs | v7.6.5.6 merged, three-pass assembly stable, visual regression clean |
| Phase X complete | v7.6.5.8 merged, all tests green, documentation updated, Phase X results produced |

### Optional early stop

If the project needs to start Phase 7 urgently:

- **Minimum viable refactor:** Level 1 + Level 2 (`v7.6.5.0`–`v7.6.5.3`). This eliminates the mirror problem and reduces module sizes. Level 3 can be deferred.
- **Full refactor:** All 9 steps. This is the recommended path for maximum Phase 7/E benefit.

---

## 11. Risks and Mitigations

| Risk | Level | Mitigation |
|---|---|---|
| Module split breaks a subtle global variable dependency (out-of-order reference) | 1 | SHA-256 identity gate on bundled output vs. original; browser smoke test with bundled file |
| Bundle order creates reference-before-definition error at runtime | 1 | Explicit ordered manifest in `bundle-dashboard.sh`; no auto-discovery |
| Template injection produces different whitespace than hand-maintained HTML | 2 | Bit-for-bit diff gate; Python exact substitution only — never prettify |
| Stale `dashboard.min.html` embedded by `generate-header.sh` | 2 | CI always rebuilds from clean state; preflight catches staleness |
| CSS extraction changes rendered appearance | 3 | Visual regression screenshot diff before/after; CSS order frozen in build script |
| Component boundary creates circular dependency | 3 | Dependency order explicit in `bundle-dashboard.sh`; enforce with ESLint if available |
| Generator markers in `dashboard.js` lost during bundle overwrite | 1+ | Pipeline re-runs generator after bundle; preflight `--check` catches desync |
| `bump-version.sh` still calls `sed` on generated files | 2 | v7.6.5.3 explicitly updates `bump-version.sh` to use pipeline |
| Aggregator logic accidentally forked from shared runtime | 3 | LESSON-OPS-074 in migration rules; aggregator component augments, never replaces |
| POST semantics (LESSON-OPS-099) changed during code move | 1+ | Migration rule 8; POST code moved intact; Group 21 tests verify |
| `render_sensor_config.py` writes into wrong file after restructure | 1 | Generator continues targeting assembled `dashboard.js`; path unchanged |
| Phase 7 starts before Level 3 is stable | 3 | Gate conditions enforce stability before proceeding; optional early-stop at Level 2 |

---

## 12. Version Number Mapping

| Phase | Version Range | Description |
|---|---|---|
| Phase D | v7.6.0.0–v7.6.0.5 | Runtime Satellite Management |
| **Phase X** | **v7.6.4.0** | **Documentation Restructuring (pre-step)** |
| **Phase X** | **v7.6.5.0–v7.6.5.8** | **Dashboard Architecture Refactor** |
| Phase Y | v7.6.6.0–v7.6.6.x | Firmware Architecture Refactor (planned after Phase X) |
| Phase 7 | v7.7.0.0–v7.7.2.x | Per-Device Persistence Engine |
| Phase E | v8.0.x | Captive Portal + WiFi Config |

---

## 13. What This Changes for Future Implementation Prompts

### Before Phase X (current state)

A typical dashboard feature prompt requires:

```
Required Reading:
1. dashboard/dashboard.js (3,955 lines)
2. dashboard/dashboard.html (4,900 lines)
3. Docs/bugs-and-lessons-learned.md (3,069 lines)
4. tests/browser/dashboard.spec.js (1,853 lines)
5. scripts/minify-dashboard.sh
6. scripts/generate-header.sh
Total: ~14,000 lines ≈ 55K–70K tokens
```

### After Phase X (target state)

```
Required Reading:
1. dashboard/components/sensor-cards/index.js (~330 lines)
2. dashboard/components/sensor-cards/template.html (~50 lines)
3. dashboard/components/sensor-cards/styles.css (~80 lines)
4. dashboard/core/state.js (~100 lines)
5. Docs/lessons/dashboard.md (~600 lines)
6. tests/browser/sensor-cards.spec.js (~200 lines)
Total: ~1,360 lines ≈ 8K–12K tokens
```

That is a **6x–8x reduction** in required context per task.

---

## 14. Relationship to Phase Y (Firmware Refactor)

Phase Y (`v7.6.6.x`) will apply similar principles to `sensor_history_multi.h` (4,325 lines):

- Split into domain modules (data model, NVS persistence, ping adapter, aggregator, web handlers).
- Update `render_sensor_config.py` to inject into the correct module files.
- Split the HistoryWebHandler class into domain-specific handler files.
- Update YAML `includes:` lists.

Phase Y planning will be done after Phase X completion, using Phase X patterns and lessons as the template. The two phases are independent — Phase Y does not depend on Phase X, and vice versa — but Phase X establishes the methodology and the documentation structure that Phase Y will follow.

---

## 15. Implementation Prompts

Implementation prompts for each Phase X step are stored in `prompts/phaseX/`:

```
prompts/phaseX/v7.6.4.0-implementation-instructions-for-coding-agent.md
prompts/phaseX/v7.6.5.0-implementation-instructions-for-coding-agent.md
prompts/phaseX/v7.6.5.1-implementation-instructions-for-coding-agent.md
...
prompts/phaseX/v7.6.5.8-implementation-instructions-for-coding-agent.md
```

Each prompt follows the established anatomy from `Docs/writing-guide/methodology.md`:

1. Header with version and prerequisite
2. Required Reading with specific callouts (referencing domain-scoped docs from `v7.6.4.0`)
3. Current status
4. Pre-condition checks (CI-exact fixture set commands)
5. Exact scope with file lists
6. Do-NOT list
7. Critical rules table
8. Documentation updates
9. Validation and regeneration pipeline
10. Mandatory deliverables (session log, compliance table, validation evidence)

---

## 16. Reconciliation Notes

This plan reconciles Draft A (GP) and Draft B (PR) as follows:

| Decision | Draft A position | Draft B position | This plan |
|---|---|---|---|
| Step count | 6 steps (v7.6.5.0–5) | 8 steps (v7.6.5.0–7) | **10 steps** (v7.6.4.0 + v7.6.5.0–8): doc pre-step + 9 code/closure steps |
| `dashboard.html` committed? | Yes (reviewable) | No (gitignored) | **Yes** — committed, marked as generated, preflight-enforced |
| CSS mapping detail | Detailed selector-family table | Minimal | **Detailed** — from Draft A, mapped to component targets |
| Module names | `src/00-app-shell.js` etc. | `modules/util.js` etc. | **Numbered names** (`src/00-app-shell.js`) for explicit ordering; renamed at Level 3 |
| Generator coupling | Not addressed | Not addressed | **Resolved** — generator writes into assembled bundle; pipeline re-runs generator after bundle |
| Test spec splitting | Not addressed | Group 19 only | **Full test spec split** into domain files (v7.6.5.7) |
| Documentation split | Not addressed | Not addressed | **Domain-scoped lessons** under `Docs/lessons/` (v7.6.5.8) |
| Aggregator overlay constraint | Mentioned implicitly | Mentioned implicitly | **Explicit migration rule** (Rule 9) |
| Device testing | Implicit | Implicit | **Explicit** at Level 2 transition (Rule 11) |
| Fixture set names | Correct | Incorrect (1/2/3/4sensor) | **Corrected** to 3sensor/mixed/system/aggregator |
| Line count for dashboard.js | ~2,400 (stale) | ~2,600 (stale) | **3,955** (verified at HEAD) |

---

_End of Phase X Architecture and Refactor Plan._
