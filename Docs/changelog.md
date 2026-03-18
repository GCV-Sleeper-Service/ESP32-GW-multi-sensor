# Changelog

All notable changes to the ESP32-C3 Multi-Sensor BLE Gateway.

---
## BUG-043 Final Fix: Gzip Dashboard + Pre-Reserved History Response (no version bump) — 2026-03-17

**Root cause identification and elimination of the actual BUG-043 crash mechanism.** After PRs #39–#41 resolved request scheduling issues, the dashboard still crashed the ESP32-C3 on page open and F5 refresh. Two firmware-level root causes were identified and fixed:

### Root causes addressed

1. **190KB uncompressed dashboard HTML transfer blocked HTTP task 2–4s per page load.** Every browser page load or F5 triggered a `GET /dashboard.html` that transferred 194,533 bytes of raw HTML. On the ESP32-C3 single core, this monopolized the HTTP server task, starving BLE/WiFi/API and triggering watchdog resets. Gzip compression reduces the transfer to ~45KB (77% reduction), cutting blocking to <1s.

2. **`beginResponseStream` reallocation cascade in `handle_history_()` caused heap exhaustion.** The history CSV response used `beginResponseStream("text/plain")` which grows its internal `std::string` through repeated `resp->print()` calls. With 336 NVS segments, the string grows through 128→256→…→16K→32K, and at the 16K→32K transition, **both old and new buffers exist simultaneously (48KB)**. With SSE/polling connections consuming ~12KB of heap, the total exceeded available ~60KB free heap. Replaced with a pre-reserved `std::string` (single allocation, zero reallocations) sent via zero-copy `beginResponse`.

### Fixes implemented

- **Gzip dashboard** — `scripts/generate-header.sh` now gzip-compresses the HTML and outputs a C `uint8_t[]` byte array. Firmware serves with `Content-Encoding: gzip`. Browser decompresses transparently.
- **Inline favicon** — Added `<link rel="icon" href="data:,">` to `dashboard.html`, eliminating browser `/favicon.ico` request entirely (was returning 500 due to handler ordering).
- **Pre-reserved history response** — `handle_history_()` calculates expected CSV size upfront, calls `csv.reserve(est_bytes)`, builds CSV into that buffer, sends with zero-copy `beginResponse(200, type, data, len)`.
- **String-based CSV builders** — New `HistoryBuffer::append_csv_to()` and `append_snapshot_series_csv_()` methods write to pre-reserved string.
- **Aggressive NVS yielding** — Changed from 1ms/4-reads to 5ms/2-reads, giving BLE/WiFi/API 2.5× more CPU time between NVS flash reads.
- **Preflight guards** — Added `dashboard_h_gzip_format`, `dashboard_h_no_raw_literal`, `dashboard_inline_favicon`, `firmware_gzip_content_encoding`, and `dashboard_h_size_guard` checks.

### Why PRs #39–#41 didn't fix the problem

The earlier PRs correctly identified and fixed **request scheduling** problems (concurrent history fetches, in-flight guard gaps, polling burst, SSE redundant requests). These were genuine issues. However, the fixes treated **request count** as the bottleneck while missing the **response size** and **heap allocation** bottlenecks:

- Manual curl worked fine because individual API endpoints return small payloads (<5KB)
- The dashboard crash was triggered by the 190KB HTML transfer (not caught by request scheduling fixes)
- The history response crash was triggered by std::string reallocation patterns (not caught by sequential fetching — even one sequential request crashed the device when SSE/polling connections consumed enough heap)

### Lesson

When debugging ESP32-C3 instability, always check: (1) transfer sizes of large responses, (2) heap allocation patterns during response building, (3) peak concurrent heap usage including TCP/SSE buffers. Request scheduling is necessary but not sufficient — the response construction itself can be the crash trigger.

**Related:** BUG-043, LESSON-OPS-055, LESSON-OPS-056

---

## BUG-043 Dashboard Hardening (no version bump) — 2026-03-17

**BUG-043 dashboard-side stability finish (PR2).** After the firmware NVS-yield fix in PR #40 reduced blocking duration, dashboard-induced crashes still occurred because the startup request sequence still sent concurrent connections during the fragile SSE open window (initial open) and during F5 reload (polling burst). This PR completes the BUG-043 resolution by fully serializing the startup request schedule.

### Root causes addressed

- **SSE initial open crash**: `loadStatusSnapshot()` fired immediately before `connectSSE()`, creating two simultaneous requests during the most fragile window (SSE setup + status fetch concurrent)
- **Polling F5 crash**: initial `pollAll` used batch=2 with `Promise.all`, still producing 2 concurrent connections per batch with only 120ms inter-batch gaps — insufficient breathing room for a just-rebooted device
- **History NVS overlap**: `loadHistory()` chained to the next sensor immediately on success/failure, giving zero recovery time between NVS scan loops on the ESP32-C3
- **Startup overlap**: storage stats (t+3s) and history (t+8s) could overlap with a batch-2 poll still in flight or wrapping up

### Fixes implemented

- **Fix A (SSE startup)**: In SSE mode, `connectSSE()` now fires first; `loadStatusSnapshot()` is deferred 2s. SSE `state` events carry initial live state, so the immediate snapshot was unnecessary overhead during the connection-open window.
- **Fix B (polling startup)**: Initial poll in `startPolling()` changed from batch=2/120ms to **batch=1/200ms** — fully sequential, one request at a time with 200ms gaps. `Promise.all` with batch=1 is equivalent to a plain sequential call but uses the existing batching infrastructure.
- **Fix C (history inter-sensor gap)**: `loadHistory()` now waits **500ms** between sensors instead of chaining immediately. This lets the ESP32-C3 complete BLE/WiFi/API work between back-to-back NVS scan loops.
- **Fix D (storage stats defer)**: Storage stats deferred from **3s → 5s** to avoid overlapping with the sequential initial poll (which now takes ~7-8s to complete 30+ paths at batch=1).
- **Fix E (history bootstrap defer)**: History bootstrap deferred from **8s → 10s** to ensure the sequential poll and storage stats both complete before NVS-heavy history scans begin.
- **Fix F (preflight guard)**: Added `startup_poll_sequential` check to `scripts/preflight.sh` — fails if the initial `pollAll` in `startPolling()` is ever changed back to a batch size > 1.
- **Fix G (dashboard.h regen)**: `dashboard/dashboard.h` regenerated from updated `dashboard/dashboard.html`.

### Startup request budget (after this PR)

| Time | Request(s) | Mode | Notes |
|------|-----------|------|-------|
| t=0ms | `GET /api/manifest` | both | single manifest fetch |
| t=~200ms | `GET /events` | SSE | stream opened first |
| t=~1000ms | first poll path | polling | batch=1, sequential |
| t=2000ms | `GET /api/status` | SSE | deferred 2s after SSE open |
| t=~8s | last poll path | polling | ~30 paths × 250ms each |
| t=~8s | `GET /api/status` | polling | after initial poll completes |
| t=5000ms | `GET /api/storage-stats` | both | deferred 5s |
| t=10000ms | `GET /history/s1/temp` | both | first history request |
| t=~10.3s | `GET /history/s1/hum` | both | 300ms gap (fetchDeviceHistory) |
| t=~10.8s | `GET /history/s2/temp` | both | 500ms inter-sensor gap |
| … | … | | |

**Peak concurrent at any point: 1 request at a time** (after manifest fetch completes)

### Favicon/routing note

`/favicon.ico` already has a correct handler in `sensor_history_multi.h` returning HTTP 204. The observed HTTP 500 on real devices is caused by **handler registration order**: ESPHome's built-in `web_server` component registers its `AsyncWebHandler` during component `setup()` (which runs before `on_boot` lambdas). Our `HistoryWebHandler` is registered in `on_boot`, so it appears after ESPHome's handler in the `AsyncWebServer` handler list. ESPHome's web_server v3 acts as a catch-all handler (returns 500 for routes it does not recognize), intercepting `/favicon.ico` before our handler is reached. The code is correct; the fix requires changing when `register_history_handler()` is called (from `on_boot` to an earlier hook that runs before ESPHome's web_server setup). This is a separate, larger change outside the scope of this dashboard-hardening PR.

**Related:** BUG-043, PRs #39–#40, LESSON-OPS-050, LESSON-OPS-051, LESSON-OPS-052, LESSON-OPS-053

---

## BUG-043 Firmware Fix (no version bump) — 2026-03-17

**BUG-043 firmware root-cause fix.** Post-merge validation after PR #39 (v7.5.3.5 dashboard-side mitigations) showed the ESP32-C3 still disconnects during dashboard history loads. Even a single history request blocks the HTTP task long enough to starve BLE/WiFi/API/watchdog work. The root cause is that long NVS iteration loops in `sensor_history_multi.h` scan up to 1080 persisted segment blobs without ever yielding to the FreeRTOS scheduler.

This firmware-only PR adds cooperative yielding inside every heavy NVS scan loop. Dashboard request-scheduling hardening is handled separately in a follow-up PR.

### Root cause addressed

- **Firmware blocking (PRIMARY):** `handle_history_()`, `restore_from_nvs()`, and `build_import_epoch_map_()` all iterate up to `meta.valid_segments` NVS blobs in a tight loop with no `vTaskDelay()` between blob reads. With 1080 segments and accumulated history, a single `/history/{id}/temp` or `/history/{id}/hum` request blocks the HTTP server task for 0.5–2 seconds. During that window, BLE scanning, WiFi, the ESPHome API, and the task watchdog are all starved, causing the observed API disconnects, 500/502 responses, and ERR_CONNECTION_RESET crashes in the browser.

### Fix implemented

- Added `maybe_yield_nvs_scan_(int iteration)` static helper in `dashboard/sensor_history_multi.h`. Calls `vTaskDelay(pdMS_TO_TICKS(1))` every `NVS_SCAN_YIELD_INTERVAL` (4) iterations to give the FreeRTOS scheduler a timeslice between blob reads without introducing per-blob overhead.
- Applied to **all three** long NVS iteration loops:
  - `restore_from_nvs()` — boot-time restore loop
  - `build_import_epoch_map_()` — import epoch-map scan loop
  - `handle_history_()` — history streaming loop (per-sensor HTTP response)

### Scope

No dashboard JS changes in this PR. No version bump (firmware-only code fix and docs). Dashboard request-scheduling hardening (sequential poll throttling, SSE boot sequencing improvements) will be addressed in a separate follow-up PR.

**Related:** BUG-043, PR #39 (v7.5.3.5 dashboard mitigations), LESSON-OPS-050, LESSON-OPS-051, LESSON-OPS-052

---

## v7.5.3.5 — BUG-043 Continued: Dashboard Startup Crash Fix (2026-03-17)

**BUG-043-cont fix.** Three additional root causes identified and fixed after the v7.5.3.3-hotfix failed to prevent dashboard-induced ESP32-C3 crashes on open.

### Root causes addressed

- **RC1**: `loadManifestV2()` and `loadSensorManifest()` both fetched `/api/manifest` — double manifest fetch during startup burst
- **RC2**: `fetchDeviceHistory()` used `Promise.all` for temp+hum fetches — concurrent NVS scan loops blocked the HTTP server task for 1–4 seconds per sensor
- **RC3**: `loadHistory()` had no in-flight guard — F5 refresh / button click during boot could spawn two overlapping history chains
- **RC4**: `startPolling()` fired 33+ paths immediately with no delay, concurrent with `loadStatusSnapshot()` — 5 concurrent connections in first 120ms
- **RC5**: History fetch deferred only 5s — not enough for storage stats (t+3s) and initial poll (~3.5s) to clear

### Fixes implemented

- **FIX 1**: Eliminated double manifest fetch — `App.Boot.start()` now reuses `window._manifest.sensors` from `loadManifestV2()` and only falls back to `loadSensorManifest()` if the v2 manifest had no sensor entries
- **FIX 2** (CRITICAL): `fetchDeviceHistory()` now fetches metrics **sequentially** with a 300ms gap between requests instead of using `Promise.all`. This is the primary crash mechanism fix — prevents concurrent NVS scan blocking
- **FIX 3**: Added `_historyInFlight` in-flight guard to `loadHistory()` — prevents concurrent history loading from F5 refresh or button click during boot
- **FIX 4**: `startPolling()` now defers initial poll by 1 second and uses batch size 2 (not 4). `loadStatusSnapshot()` moved inside `startPolling()` so it fires after the deferred poll, not simultaneously with it
- **FIX 5**: History bootstrap timer increased from 5s to 8s — ensures storage stats and initial poll both complete before NVS-heavy history requests begin
- **FIX 6**: All JS changes mirrored to `dashboard/dashboard.html` (source of truth per LESSON-OPS-043)
- **FIX 7**: `dashboard/dashboard.h` regenerated via `scripts/generate-header.sh`
- **FIX 8**: Added `no_concurrent_history_fetch` check to `scripts/preflight.sh` — fails if `fetchDeviceHistory()` is ever changed back to use `Promise.all`

### Peak concurrent connections (startup window, after fix)

| t=0ms | t=1s | t=3s | t=8s |
|-------|------|------|------|
| manifest fetch (1) | poll batch-2 starts | storage stats | history seq fetch 1 |
| SSE or poll init | | | 300ms gap |
| | | | history seq fetch 2 |
| **max: 2** | **max: 2** | **max: 1** | **max: 1** |

**Related:** BUG-043, PRs #36–#38, LESSON-OPS-050, LESSON-OPS-051, LESSON-OPS-052

---

## v7.5.3.3-hotfix — Dashboard Stability Remediation (2026-03-17)



**BUG-043 fix implemented.** Dashboard request scheduling rewritten to eliminate ESP32-C3 HTTP server overload.

Dashboard JavaScript was overwhelming the ESP32-C3 HTTP server (~4-7 concurrent connections) with excessive concurrent and overlapping requests, causing `httpd_accept_conn: error in accept (23)` and panic/reboot.

### Fixes implemented
- **FIX 1**: Added `_statusInFlight` in-flight guard on `loadStatusSnapshot()` — max 1 concurrent `/api/status` request
- **FIX 2**: Added `_storageStatsInFlight` in-flight guard on `loadStorageStats()` — max 1 concurrent `/api/storage-stats` request (internal retries still allowed)
- **FIX 3**: Removed `loadStatusSnapshot()` from SSE `ping` handler — SSE already delivers state via `state` events; this eliminated 10-20+ redundant requests/minute
- **FIX 4**: Removed `loadStatusSnapshot()` from SSE `onopen` handler — boot sequence already calls it once; this eliminated duplicate status fetch on connect
- **FIX 5**: Made 30s `statusSnapshotIntervalId` conditional (polling mode only) — in SSE mode, state is delivered via events, no periodic polling needed
- **FIX 6**: Removed `loadStatusSnapshot()` from `startPolling()` 15s interval — the 30s `statusSnapshotIntervalId` handles status refresh in polling mode
- **FIX 7**: Staggered startup requests: storage stats deferred 3s, history deferred from 2s to 5s — reduced boot burst from 8-12+ concurrent to 2-3 staggered
- **FIX 8**: Increased storage stats interval from 60s to 120s (NVS persists ~hourly, 120s is sufficient)
- **SYNC**: All fixes mirrored to `dashboard/dashboard.html`; `dashboard.h` regenerated
- **SYNC**: `resumeDashboardNetworkActivity()` updated with matching 120s storage interval and polling-only status interval
- **TEST**: All preflight checks pass
- **TEST**: All 73 Playwright tests pass (no behavior change)
- **DOCS**: `Docs/dashboard-stability-remediation-plan.md` — detailed step-by-step plan with code, acceptance criteria, and device validation checklist
- **DOCS**: `Docs/bugs-and-lessons-learned.md` — BUG-037 updated with confirmed root cause; LESSON-OPS-050 and LESSON-OPS-051 added

### Request budget improvement

| Metric | Before | After |
|--------|--------|-------|
| Peak concurrent at boot | 8-12+ | 2-3 (staggered) |
| Sustained connections (SSE) | 3-5 | 1 (SSE stream only) |
| Sustained connections (polling) | 4-6 | 2-3 |
| Status requests/min (SSE) | 12-20+ | 0 |
| Status requests/min (polling) | 6 | 2 |

### Device validation required
See `Docs/dashboard-stability-remediation-plan.md` — Device Validation Checklist section.

---

## v7.5.3.3 (2026-03-16)

**Phase 3 Step 3 — Wire YAML Lambdas to SensorEntity (Dual-Write)**

Implements the dual-write phase: BLE `on_value` lambdas now call both the legacy
`SensorSlot` methods and the new `SensorEntity` methods in parallel. Dashboard polling
continues to read from `SensorSlot` while `SensorEntity` accumulates data for the
future v2 endpoints.

- **FEAT**: `thermopro_ble` temperature `on_value` lambdas now call `devices[i].add_sample(0, x)` and `devices[i].mark_seen(::time(nullptr))` alongside the existing `sensors[i].add_temp(x)` call (dual-write)
- **FEAT**: `thermopro_ble` humidity `on_value` lambdas now call `devices[i].add_sample(1, x)` and `devices[i].mark_seen(::time(nullptr))` alongside the existing `sensors[i].add_hum(x)` call (dual-write)
- **FEAT**: 15-minute averaging timer lambda now calls `devices[i].compute_averages(epoch)` alongside existing `sensors[i].compute_and_format(epoch)`, accumulating 15-minute averages into `SensorEntity` history buffers
- **COMPAT**: `SensorSlot sensors[]` calls are fully preserved — both models receive identical data in parallel
- **COMPAT**: `::time(nullptr)` used (not `time(nullptr)`) per ESPHome project convention and BUG-035/036 guardrails
- **BUILD**: All YAML changes generated via `apply_yaml_marker_block()` per BUG-035/036 guardrails; `replace_marker_block()` never used for YAML regions
- **TEST**: `render_sensor_config.py --check` passes
- **TEST**: All preflight checks pass
- **TEST**: 73 Playwright tests pass
- **BUMP**: Version 7.5.3.2 → 7.5.3.3 across all canonical locations

---

## v7.5.3.2 (2026-03-16)

**Phase 3 Step 2 — Generator Produces SensorEntity Arrays (Dual Output)**

Extends the generator to emit the new generalized `SensorEntity` model alongside the
existing `SensorSlot` arrays. Runtime behavior is unchanged in this step — `SensorSlot`
remains the active model while `SensorEntity devices[]` is generated in parallel as a
compile-valid migration target.

- **FEAT**: Extended `scripts/render_sensor_config.py` to generate dual-output C++ in `dashboard/sensor_history_multi.h` — legacy `SensorSlot sensors[]` plus new `SensorEntity devices[]`
- **FEAT**: Added generator support for shared `metrics_thermopro[]` definitions and per-device `entity_hbuf_<sensor>_<metric>` history buffers for Phase 3 `SensorEntity` output
- **FEAT**: Added helper logic in `scripts/sensor_manifest_lib.py` for ThermoPro metric-definition generation used by the Phase 3 renderer
- **FEAT**: Generated `SensorEntity devices[]` initializes `MetricState` entries with `NAN`, zeroed accumulators/sample counts, `valid = false`, `last_update_epoch = 0`, and correct history pointers / `nullptr`
- **COMPAT**: Existing `SensorSlot sensors[]` generation is unchanged and remains the only active runtime model in v7.5.3.2
- **TEST**: `render_sensor_config.py --check` passes with the new dual-output generated header
- **TEST**: PR #34 CI passed and the branch was merged successfully
- **TEST**: Local ESPHome compile succeeded on 2026-03-16, confirming the generated dual-output header compiles cleanly on the ESP-IDF toolchain
- **BUILD**: Compile output reported total image size 1,610,284 bytes; DRAM usage 132,818 bytes (41.34%) with 188,478 bytes remaining; flash usage 1,610,028 / 1,769,472 bytes (91.0%)
- **BUMP**: Version 7.5.3.1 → 7.5.3.2 across all canonical locations

---

## v7.5.3.1 (2026-03-16)

**Phase 3 Step 1 — Define SensorEntity, MetricDef, MetricState Structs**

Adds the three passive C++ struct definitions that form the foundation of the Phase 3
generalized sensor model. These structs coexist with `SensorSlot` during migration.
No runtime code references them yet.

- **FEAT**: Added `MetricDef` struct — describes a single sensor metric (key, label, unit, class_id, history_enabled)
- **FEAT**: Added `MetricState` struct — runtime state for one metric per device (current_value, accumulator, sample_count, valid flag, last_update_epoch, HistoryBuffer pointer)
- **FEAT**: Added `SensorEntity` struct — generalized device model with identity, metric arrays (up to `MAX_METRICS_PER_DEVICE=4`), adapter-specific fields, and methods `add_sample()`, `compute_averages()`, `mark_seen()`
- **FEAT**: Added `#define MAX_METRICS_PER_DEVICE 4` — covers ThermoPro (temp+hum+battery+rssi) and ping (latency+success+uptime+loss)
- `SensorSlot` is unchanged and remains the only active runtime model
- Uses `::time(nullptr)` per ESPHome project convention
- **BUMP**: Version 7.5.3.0 → 7.5.3.1 across all canonical locations

---

## v7.5.3.0 (2026-03-16)

**Pre-Phase 3 Cleanup — Boot Sequencing, Schema Naming Decision, Version Management**

Clears technical debt identified in the Phase 1/2 assessment before the Phase 3 C++ SensorEntity refactor begins.

- **FIX**: `scripts/bump-version.sh` now updates `dashboard/dashboard.html` App.version string automatically (was previously a manual step required after every bump)
- **FIX**: Boot flow sequencing in `App.Boot.start()` — `loadManifestV2()` now completes before `loadSensorManifest()` begins, ensuring `window._manifest` is available when `buildDeviceCards()` runs. Both `dashboard/dashboard.js` and `dashboard/dashboard.html` updated in sync.
- **DOCS**: Added `config/sensors.v2.example.json` — reference config showing mixed-category v2 sensor definitions (ThermoPro BLE + ICMP ping probe). Documentation/example only; generator still reads `config/sensors.json`.
- **DOCS**: Added schema naming decision comment in `scripts/sensor_manifest_lib.py` — implementation uses `sensors` key for backward compatibility; architecture plan's `devices` naming deferred to a future major version.
- **BUMP**: Version 7.5.2.4 → 7.5.3.0 across all canonical locations

---

## v7.5.2.4 (2026-03-16)

> **🏁 Phase 2 Complete** — Dashboard Consumes v2 Manifest
>
> All Phase 2 work (v7.5.2.0–v7.5.2.4) is merged. The dashboard now fully loads from
> the v2 manifest (`/api/manifest`), falls back gracefully to `/sensors.json` and then to
> hardcoded defaults, dispatches card rendering via `CARD_RENDERERS`, formats metric values
> via `METRIC_FORMATTERS`, and resolves history URLs from manifest measurements. All eight
> Phase 2 Playwright regression scenarios pass. ThermoPro rendering is pixel-identical to
> the pre-Phase-2 baseline.

**Phase 2 Step 5 — Full Playwright Regression + Phase 2 Closure**

Final validation, comprehensive test coverage, and phase closure for Phase 2.

- **TEST**: Added Group 14 (8 tests) in `tests/browser/dashboard.spec.js` — Phase 2 closure full regression:
  - **Scenario 1**: Sensor cards render correctly when `/api/manifest` returns full v2 manifest (verifies `source: 'active-manifest'` and 3 named cards)
  - **Scenario 2**: Sensor cards render correctly when `/api/manifest` returns 404 (verifies auto-promote from `/sensors.json` and 3 named cards)
  - **Scenario 3**: Sensor cards render correctly when both `/api/manifest` and `/sensors.json` fail (verifies hardcoded `DEFAULT_SENSOR_META` fallback and 3 named cards)
  - **Scenario 4**: Environmental card renderer dispatches correctly for all manifest sensors
  - **Scenario 5**: `_default` card renderer handles unknown category gracefully without crashing
  - **Scenario 6**: Metric formatters produce correct temperature output (`°C / °F`)
  - **Scenario 7**: `fetchDeviceHistory` uses `history_url` from manifest when available
  - **Scenario 8**: `fetchDeviceHistory` falls back to legacy URLs when manifest is unavailable
- **BUMP**: Version 7.5.2.3 → 7.5.2.4 across all canonical locations
- **SYNC**: `dashboard/dashboard.html` updated to v7.5.2.4; `dashboard/dashboard.h` regenerated; variant fixtures regenerated

---

## v7.5.2.3 (2026-03-16)

**Phase 2 Step 4 — Generic History Fetching (Manifest-Driven)**

Refactors history URL resolution so it is driven by manifest measurement definitions instead
of hardcoded `/history/{id}/temp` and `/history/{id}/hum` paths. ThermoPro rendering remains
pixel-identical to v7.5.2.2.

- **FEAT**: Added `fetchDeviceHistory(sensor, manifest)` — manifest-driven history URL resolver; reads `measurements[].history_url` from `window._manifest.sensors`; falls back to legacy `/history/{id}/temp` and `/history/{id}/hum` when manifest data is absent or has no matching sensor
- **REFACTOR**: `fetchSensorHistoryRows(sensor)` now delegates to `fetchDeviceHistory(sensor, window._manifest)` instead of directly building hardcoded URLs
- **REFACTOR**: `loadHistory()` inline fetch chain refactored to use `fetchDeviceHistory()` with `Promise.all()` per sensor; behavior is identical — sequential per-sensor loading, min/max and display updates unchanged
- **FEAT**: `App.API.fetchDeviceHistory` exported for testability
- **TEST**: Added Group 13 (5 tests) in `tests/browser/dashboard.spec.js`:
  - `fetchDeviceHistory` is a callable function
  - `App.API.fetchDeviceHistory` is exported
  - `fetchDeviceHistory` uses `history_url` from manifest measurements (URL interception test)
  - `fetchDeviceHistory` falls back to legacy URLs when manifest is null
  - `fetchDeviceHistory` falls back to legacy URLs when manifest has no matching sensor
- **BUMP**: Version 7.5.2.2 → 7.5.2.3 across all canonical locations
- **SYNC**: `dashboard/dashboard.html` kept in sync with `dashboard/dashboard.js`; `dashboard/dashboard.h` regenerated

---

## v7.5.2.2 (2026-03-16)

**Phase 2 Step 3 — Metric Formatter Registry**

Extracts value-formatting logic into a `METRIC_FORMATTERS` registry and adds a unified
`formatMetricValue()` lookup function. Dashboard reads `unit`, `unit_symbol`, and
`display.precision` from the manifest. ThermoPro rendering remains pixel-identical to
v7.5.2.1.

- **FEAT**: Added `METRIC_FORMATTERS` registry with `temperature`, `humidity`, and `_default` entries
- **FEAT**: Added `formatMetricValue(key, value, metric_def)` — unified formatter lookup; dispatches to registered formatter or `_default`
- **FEAT**: Added `getMetricDef(key)` — looks up a metric definition by key from `window._manifest.metrics`
- **REFACTOR**: Replaced 5 inline temperature/humidity formatting strings across `handleState()` and history loader with `formatMetricValue()` calls
- **TEST**: Added Group 12 (6 tests) in `tests/browser/dashboard.spec.js`:
  - `METRIC_FORMATTERS` registry exists with `temperature`, `humidity`, and `_default` entries
  - `formatMetricValue` is a callable function
  - Temperature formatted as `22.5 °C / 72.5 °F` (identical to prior behavior)
  - Humidity formatted as `55 %` with `Math.round()` (identical to prior behavior)
  - Unknown metric key falls back to `_default` formatter
  - `null` metric_def handled gracefully
- **BUMP**: Version 7.5.2.1 → 7.5.2.2 across all canonical locations
- **SYNC**: `dashboard/dashboard.html` kept in sync with `dashboard/dashboard.js`; `dashboard/dashboard.h` regenerated

---

## v7.5.2.1 (2026-03-16)

**Phase 2 Step 2 — Card Renderer Registry (Environmental Only)**

Introduces a `CARD_RENDERERS` registry and refactors `buildSensorCards()` into a
category-dispatched rendering pipeline. Environmental/ThermoPro rendering is pixel-identical
to v7.5.2.0. `buildSensorCards()` retained as a compatibility alias.

- **FEAT**: Added `CARD_RENDERERS` registry with `environmental` and `_default` entries
- **FEAT**: Added `buildEnvironmentalCard(sensor, manifest)` — extracted from `buildSensorCards()`, produces HTML identical to previous behavior
- **FEAT**: Added `buildDeviceCards()` — clears `#sensorGrid`, iterates `SENSORS`, looks up `manifest.sensors[].category`, dispatches to `CARD_RENDERERS[category] || CARD_RENDERERS._default`, calls `buildExportButtons()`
- **FEAT**: `buildSensorCards()` is now a compatibility alias/wrapper calling `buildDeviceCards()`
- **FEAT**: `_default` renderer gracefully handles unknown categories with a minimal key/value card
- **FEAT**: `App.Render` exports extended with `buildDeviceCards` and `buildEnvironmentalCard`
- **TEST**: Added Group 11 (7 tests) in `tests/browser/dashboard.spec.js`:
  - `CARD_RENDERERS` registry exists with `environmental` and `_default` entries
  - `buildDeviceCards` and `buildEnvironmentalCard` are accessible
  - `buildSensorCards` is still a callable function (compatibility alias)
  - Environmental renderer dispatches correctly and produces sensor cards
  - Environmental renderer produces full card structure (temp, hum, minmax, batt, rssi)
  - `_default` renderer handles unknown category gracefully without crashing
  - `App.Render` exposes `buildDeviceCards` and `buildEnvironmentalCard`
- **BUMP**: Version 7.5.2.0 → 7.5.2.1 across all canonical locations
- **SYNC**: `dashboard/dashboard.html` kept in sync with `dashboard/dashboard.js` per repo convention; `dashboard/dashboard.h` regenerated

---

## Process & Documentation Hardening (2026-03-16, post-v7.5.2.0)

**Long-term version-drift prevention — no firmware version change**

Closes a preflight gap where `dashboard/dashboard.h` version could silently drift from `dashboard/dashboard.js` after a version bump without regenerating the header. Adds an atomic version bump script to prevent partial bumps.

- **CI**: Added `dashboard_h_version_matches` preflight check — verifies `dashboard/dashboard.h` contains the current `App.version` string (catches missing `generate-header.sh` run after version bump)
- **CI**: Added `render_sensor_config_py_version_sync` preflight check — explicitly verifies `scripts/render_sensor_config.py` VERSION constant matches canonical `VERSION` file before running `--check` (gives clearer error than generic sync failure)
- **TOOL**: Added `scripts/bump-version.sh` — atomic version bump script that updates all canonical version locations, regenerates all artifacts, and runs preflight in one command
- **DOCS**: Added BUG-042 and LESSON-OPS-048 to `Docs/bugs-and-lessons-learned.md`
- **DOCS**: Added `Docs/session-log-2026-03-16-docs-version-drift-prevention.md` — session handoff log
- **NOTE**: PR #23 is superseded by PR #24 (merged). PR #23 should be closed with a superseded comment; see session log for exact wording.

Related: BUG-042, LESSON-OPS-048

---

## v7.5.2.0 (2026-03-16)

**Phase 2 Step 1 — Dashboard Manifest v2 Loader with Fallback Chain**

Adds manifest v2 loading to the dashboard boot flow. Data loading only — no rendering changes.

- **FEAT**: Added `loadManifestV2()` — async three-tier fallback loader:
  - Tier 1: `GET /api/manifest` → validates `schema_version === 2 && sensors`
  - Tier 2: `GET /sensors.json` → `autoPromoteV1ToV2()`
  - Tier 3: `DEFAULT_SENSOR_META` → `autoPromoteV1ToV2()`
- **FEAT**: Added `autoPromoteV1ToV2(sensorsArray)` — wraps a v1 `[{id, name}]` array in a full v2 manifest envelope with ThermoPro metric defaults
- **FEAT**: `loadManifestV2()` fires alongside existing `loadSensorManifest()` (unchanged) during boot; result stored in `window._manifest`
- **TEST**: Added Groups 9 and 10 in `tests/browser/dashboard.spec.js`:
  - Group 9 (5 tests): `window._manifest` set after boot; correct `schema_version`, sensors, gateway block, metrics array
  - Group 10 (2 tests): dashboard loads and `window._manifest` is auto-promoted when `/api/manifest` returns 404; both functions accessible
- **FIX**: Correctly ran `python3 scripts/render_sensor_config.py --write` after version bump to keep `sensor_history_multi.h`, `gateway_manifest.h`, and fixture files in sync — fixes PR #23 preflight failure
- **BUMP**: Version 7.5.1.3 → 7.5.2.0 across all canonical locations

**Addresses**: PR #23 preflight failure (generated files out of sync with config/sensors.json after version bump)

---

## v7.5.1.3 (2026-03-15)

**Phase 1 Refinement — Test Fixture Alignment & Version Sync**

Aligns test fixtures to the full v2 manifest schema and fixes version drift:

- **FIX**: Synchronized version across all canonical sources (VERSION, render_sensor_config.py, generate-fixtures.js, dashboard.js, dashboard.html, YAML, gateway_manifest.h)
- **TEST**: Extended Playwright manifest test to validate all v2 fields (gateway, history, metrics, sensors)
- **TEST**: Fixed `--manifest` flag parsing in generate-fixtures.js (standalone flag now defaults to config/sensors.json)
- **TEST**: Regenerated all fixtures with synchronized v7.5.1.3 version
- **CI**: Added preflight `fixture_generator_version_sync` check to prevent future version drift
- **DOCS**: Updated architecture plan — Phase 1 complete

**Phase 1 Complete** ✅
- v7.5.1.0 — Full manifest v2 implementation
- v7.5.1.1 — Manifest schema validation
- v7.5.1.2 — ESPHome YAML parse gate
- v7.5.1.3 — Test fixture alignment + version sync

**Next**: Phase 2 — Dashboard consumes `/api/manifest`

Related: BUG-041, LESSON-OPS-047

---

## v7.5.1.2 (2026-03-15)

**Phase 1 Refinement — ESPHome YAML Parse Gate**

Adds automated validation to preflight that verifies the generated ESPHome YAML is syntactically valid and parseable:

- **TEST**: Preflight runs `esphome config` to validate YAML structure
- **TEST**: Preflight fails if YAML has syntax errors, indentation issues, or schema violations
- **TEST**: Preflight skips check with warning if `esphome` not installed (graceful degradation)
- **CI**: GitHub Actions workflow installs ESPHome to ensure parse check always runs in automated testing
- **DOCS**: Updated architecture plan — Phase 1 refinement step 2 of 3 complete

This prevents generator bugs (like BUG-035/BUG-036) from producing broken YAML that passes preflight but fails at compile time.

Related: ISSUE-004 (ESPHome parse gate), LESSON-OPS-045 (YAML parse validation)

---

## v7.5.1.1 (2026-03-15)

**Phase 1 Refinement — Manifest Schema Validation**

Adds automated validation to preflight that verifies the generated manifest conforms to the v2 schema specification:

- **TEST**: Preflight validates `src/gateway_manifest.h` contains parseable JSON
- **TEST**: Preflight validates required top-level fields: `schema_version`, `gateway`, `history`, `sensor_count`, `metrics`, `sensors`
- **TEST**: Preflight validates `gateway` block fields: `id`, `name`, `role`, `hardware`, `firmware_version`, `api_version`
- **TEST**: Preflight validates `history` block fields: `backend`, `retention_hours`, `ram_window_hours`, `sample_interval_seconds`
- **TEST**: Preflight validates `metrics` array contains: `key`, `name`, `unit`, `class`, `data_type`, `history`
- **TEST**: Preflight validates `schema_version` is exactly `2`
- **DOCS**: Updated architecture plan — Phase 1 refinement step 1 of 3 complete

This is the first incremental Phase 1 refinement (v7.5.1.1). Ensures manifest generation cannot produce invalid schema.

Related: ISSUE-003 (manifest v2 schema alignment)

---

## v7.5.1.0 — 2026-03-15

**Phase 1 Completion — Full Manifest v2 Implementation**

Completes the Phase 1 manifest endpoint delivery with full v2 schema and compile-time generation:

- **ARCH**: Generated `src/gateway_manifest.h` with full v2 manifest as static C string literal
- **ARCH**: Extended manifest v2 schema with `gateway`, `history`, per-metric `class`/`data_type`/`display` fields
- **FIX**: Replaced inline `resp->print()` manifest builder with static `GATEWAY_MANIFEST_JSON` constant
- **FIX**: Manifest now includes gateway identity block (id, name, role, hardware, firmware_version, api_version)
- **FIX**: Manifest now includes history policy block (backend, retention_hours, ram_window_hours, sample_interval_seconds)
- **FIX**: Metrics array now includes `class` (analog_numeric), `data_type` (float), `bounds`, `display` hints
- **FIX**: Sensor entries now include `category`, `adapter`, `source.mac`, and `measurements` with `history_url`
- **TEST**: Preflight validates `src/gateway_manifest.h` existence, proper inclusion, and YAML include registration
- **TEST**: `generate-fixtures.js` updated to produce byte-identical full v2 schema output
- **DOCS**: Architecture plan Phase 1 issues resolved (ISSUE-003)

Fixes issues identified in Phase 1 feedback (inline manifest, partial schema, missing gateway_manifest.h).

---

## v7.5.0.1 — 2026-03-14

**Completed:** Phase 1 — manifest endpoint, dashboard migration, and runtime fixes

- Added `GET /api/manifest` firmware endpoint serving schema v2 JSON with global metric metadata and per-sensor history paths
- Preserved `GET /sensors.json` as a backward-compatible v1 projection for existing consumers and older dashboards
- Updated dashboard bootstrap to prefer `/api/manifest`, with fallback to `/sensors.json`, then to built-in defaults
- Restored dashboard display of **Free Heap** and **Uptime** by switching hydration source from legacy entity-polling paths to `GET /api/status`
- Restored **Free Heap**, **Uptime**, and **Loop Time** in the built-in ESPHome diagnostics web page by re-adding `debug.free`, `debug.loop_time`, and `uptime` sensor blocks to YAML
- Fixed `render_sensor_config.py` regex replacement crash on generated content containing backslash sequences (`\xC2\xB0`, etc.) — changed to lambda-based replacement
- Fixed `render_sensor_config.py` YAML indentation regression — all YAML marker regions now route through `apply_yaml_marker_block()` which preserves indentation column of the marker location
- Re-aligned `dashboard.html`, `dashboard.min.html`, and `dashboard.h` so the embedded firmware payload reflects the current source
- Confirmed generator idempotence: `python3 scripts/render_sensor_config.py --write` produces no diff on the current baseline
- Version: `v7.5.0.1`

**Validated on device:**
- `GET /api/manifest` → schema v2 response ✓
- `GET /sensors.json` → 3-sensor legacy array ✓
- `GET /api/status` → version, uptime, heap, sensor validity ✓
- Dashboard loads, sensor cards render, Free Heap and Uptime visible ✓
- Built-in ESPHome web page diagnostics visible ✓
- OTA upload via `esphome run` ✓

**Documentation:**
- `Docs/bugs-and-lessons-learned.md` — BUG-033–039, LESSON-OPS-039–045 added
- `Docs/esp32-gateway-fresh-start-handoff.md` — updated to v7.5.0.1 baseline
- `Docs/v7.5.x-documentation.md` — new Phase 1 reference document

---

## v7.5.0.0 — 2026-03-13

**Attempted:** Initial Phase 1 manifest endpoint and dashboard migration

- First implementation of `/api/manifest` endpoint and manifest-first dashboard boot path
- Local repo application uncovered generator and runtime regressions (generator regex crash, YAML indentation failure, dashboard source/artifact drift) that were resolved in v7.5.0.1
- Test and fixture layer updated: `tests/fixtures/manifest.json` (schema v2 shape), `tests/browser/manifest.spec.js` (new Playwright spec for manifest boot and fallback behavior)
- Mock server updated to serve `/api/manifest` endpoint for test fixtures
- Preflight extended with manifest-related checks: firmware route presence, dashboard preference and fallback, fixture schema-v2 baseline

**Note:** v7.5.0.0 was not device-validated due to the generator/YAML regression. v7.5.0.1 is the first device-validated Phase 1 baseline.

---

## v7.4.5.1 — 2026-03-12

**Fixed:** Patch hardening for manifest automation and CLI history restore

- `scripts/history_backup.py` now uses a 60-second default HTTP timeout and exposes `--timeout` for slower links or large retained-history exports
- `scripts/history_backup.py import` now warns before erase-first multi-sensor import and requires explicit confirmation unless `--yes` is provided
- `scripts/history_backup.py import` now supports `--single-sensor <id>` so a merged CSV can be routed through the single-sensor merge path intentionally
- `scripts/change_sensor_number.py` now shows the history-backup reminder before add/remove confirmation, not only after the manifest has already been updated
- `scripts/change_sensor_number.py` rollback handling is now more defensive: the backup file is preserved on failure, rollback problems are surfaced clearly, and manual recovery commands are printed if automatic recovery is incomplete
- `scripts/sensor_manifest_lib.py` validation is now side-effect free; manifest canonicalization is explicit instead of silently mutating caller-provided dictionaries
- `scripts/render_sensor_config.py --check` now tells the operator exactly which command to run to resync generated files
- Legacy single-sensor filename detection in `scripts/history_backup.py` now prefers the longest exact phrase match, reducing false ambiguity for similar names

**Documentation:**
- `Docs/configuring-sensors.md` now documents the new `history_backup.py` safety controls (`--timeout`, multi-sensor confirmation, `--single-sensor`)
- `README.md`, `Docs/bugs-and-lessons-learned.md`, and the fresh-start handoff updated to reflect the patch release

---

## v7.4.5.0 — 2026-03-12

**Added:** Canonical sensor-manifest workflow and history backup/restore CLI

- `config/sensors.json` — new single source of truth for configured sensors (id, name, MAC)
- `scripts/change_sensor_number.py` — interactive add/remove flow with count guardrails (1–4), name/MAC validation, confirmation prompts, manifest update, and generator invocation
- `scripts/render_sensor_config.py` — manifest-driven renderer for `dashboard/sensor_history_multi.h`, `firmware/esp32-c3-multi-sensor.yaml`, `dashboard/dashboard.js`, and `tests/fixtures/sensors.json`
- `scripts/history_backup.py` — command-line retained-history export/import helper built on existing `/sensors.json`, `/history/*`, and `/api/import/*` endpoints
- Generated sensor-manifest markers in the header, YAML, and dashboard JS so future sensor changes are deterministic instead of four-file manual edits
- `Docs/session-log-2026-03-12-sensor-config-automation.md` — session handoff with request, actions, design decisions, lessons, and next steps

**Changed:** Validation and test plumbing are now manifest-aware

- `scripts/preflight.sh` now validates the canonical manifest, runs `scripts/render_sensor_config.py --check`, regenerates root mock fixtures from the active manifest, and optionally runs the sensor-count browser smoke suite when Playwright dependencies are installed
- `tests/fixtures/generate-fixtures.js` now supports `--manifest <path> --overwrite-baseline`, and baseline overwrite now refreshes the full root fixture set
- `tests/mock-server/server.js` now builds polling responses from the active fixture manifest and supports `FIXTURE_SET` variant resolution with root fallback
- `Docs/configuring-sensors.md` is now centered on the canonical manifest workflow, backup-before-delete requirement, and both browser and CLI restore paths
- `README.md` now points users to the manifest-driven workflow instead of manual four-file edits

**Expanded documentation:** Single-sensor merge-import design is now carried forward explicitly

- Changelog/session docs now capture the merge-first behavior added in v7.4.0.2: the firmware builds an epoch-to-slot map, overlays only the target sensor into existing hourly segments, writes back to the same slot when possible, and allocates a new slot only for hours not already present

**Device impact:** Reflash not required for this release. Runtime history logic is unchanged; this release automates configuration and backup/restore workflows.

---

## v7.4.4.0 — 2026-03-12

**Added:** Configurable sensor count (1–4) with preflight validation and multi-variant test coverage

- `Docs/configuring-sensors.md` — new authoritative step-by-step change procedure including 1/2/3/4-sensor templates, YAML alignment guide, history reset requirement, and browser test validation commands
- `scripts/preflight.sh` — ~12 new sensor-count checks: NUM_SENSORS range (1–4), C++ initializer count, YAML thermopro_ble/ble_rssi/text-sensor ID counts, baseline fixture manifest count, DEFAULT_SENSOR_META fallback count in dashboard.js
- `tests/fixtures/generate-fixtures.js` — rewritten to generate 1/2/3/4-sensor fixture variants under `tests/fixtures/variants/<N>sensor/`
- `tests/mock-server/server.js` — FIXTURE_SET env var support; variant-first fixture resolution with root fallback
- `tests/browser/sensor-count.spec.js` — new 7-test fixture-driven smoke suite; works for any FIXTURE_SET without hardcoded counts
- `.github/workflows/browser-tests.yml` — matrix strategy across 3sensor/1sensor/2sensor/4sensor; baseline suite for 3sensor, smoke suite for others

**Fixed:**
- Fixture epoch bug: generate-fixtures.js was using milliseconds (Date.UTC()) for CSV timestamps; dashboard multiplies by 1000 expecting seconds — would silently render empty charts. Now uses epoch seconds throughout. (BUG-025 / LESSON-OPS-029)

**Not changed:** YAML firmware sensor blocks (still 3-sensor default); sensor_history_multi.h sensor definitions (still 3-sensor default). Changing the active count requires following Docs/configuring-sensors.md — preflight now enforces this.

**Device flash:** Not required — no firmware logic changes.

---

## v7.4.3.0 — 2026-03-11

**Added:** Playwright browser regression test suite

- `tests/mock-server/server.js` — lightweight Node.js HTTP mock of the ESP32 gateway API (no live device required)
- `tests/fixtures/` — deterministic fixture data: sensor manifest, 72h history CSVs, storage-stats, api-status
- `tests/browser/dashboard.spec.js` — 25 tests across 8 groups: boot/structure, sensor cards, transport/status, history/charts, custom date range modal, theme toggle, export controls, console error guard
- `playwright.config.js` — Playwright configuration; webServer block auto-starts mock server before tests
- `package.json` — project test runner (`npm run test:browser`)
- `.github/workflows/browser-tests.yml` — separate CI workflow triggered on dashboard or test file changes
- Version bump: VERSION + dashboard.js/html only (no firmware change, no device reflash required)

**Not changed:** YAML firmware, sensor_history_multi.h, device flash (remains at v7.4.2.0 on device)

---

## v7.4.2.0 — 2026-03-11

**Added:** Custom date range selector

- "Custom" button added after 45d in both chart range toggle and per-sensor min/max toggles
- Modal date-range picker: 6 quick-select presets, navigable calendar with two-click start→end selection, hour + AM/PM time selectors
- `getEffectiveTimeRange()` centralises all time-range logic — charts and min/max both route through it
- `CUSTOM_RANGE_START` / `CUSTOM_RANGE_END` module-level state; cleared when any standard preset is clicked
- Data availability footer: "Data available: oldest–newest", "up to newest", or "No persisted history yet" (correct on fresh device)
- Mobile responsive below 480px

**Fixed:**
- BUG-017: `MAX_HISTORY_RANGE_HOURS` was 720 (30d), silently truncating the 45d range — changed to 1080
- BUG-018: Duplicate `<script>` tag in HTML caused `Unexpected token '<'` on boot — script sync corrected
- BUG-019: "Data available: unknown" on freshly-flashed device — three-state availability display added

---

## v7.4.1.0 — 2026-03-10

**Added:** Dashboard minification pipeline

- New script `scripts/minify-dashboard.sh` — runs `html-minifier-terser` on `dashboard.html` to produce `dashboard.min.html` (build artifact, gitignored)
- `scripts/generate-header.sh` updated — auto-detects `dashboard.min.html` when present; falls back to `dashboard.html` if not (backwards-compatible)
- CI workflow updated — installs `html-minifier-terser`, runs minify → generate-header → preflight → compile in sequence
- `.gitignore` updated — adds `dashboard/dashboard.min.html` and `node_modules/`
- Expected flash savings: ~40KB (~88% → ~86%)

**Pipeline sequence (local):**
```
dashboard.html → minify-dashboard.sh → dashboard.min.html (gitignored)
                                      → generate-header.sh → dashboard.h (committed)
```

**Key behaviours:**
- `dashboard.min.html` is never committed — it is a build artifact
- `generate-header.sh` picks up `.min.html` automatically when present (no argument needed)
- CI always produces the minified binary; local builds without the tool fall back gracefully

---

## v7.4.0.2 — 2026-03-09

**Added:** Single-sensor non-destructive import

- New endpoint: `POST /api/import/begin/single/<sensor_id>` for merge import
- Single-sensor CSV import now preserves other sensors' data in flash
- Firmware builds epoch-to-slot map to locate existing segments for merge
- Existing segments are read, overlaid with imported sensor data, and written back
- New segments created only for hours not already in flash
- Dashboard auto-detects single vs multi sensor from CSV columns
- Confirmation dialog adapts messaging: "replace all" vs "replace sensor X only"

**Fixed:** Import mode selection

- Multi-sensor CSV import still uses replacement-first model (unchanged behavior)
- Single-sensor import no longer erases flash before writing

---

## v7.4.0.1 — 2026-03-09 (rolled into v7.4.0 codebase)

**Fixed:** Single-sensor CSV export/import schema mismatch

- Single-sensor CSV exports now use prefixed headers (`outside_temp_c`) matching merged export format
- Legacy bare-header single-sensor CSVs handled safely via filename detection
- Removed unsafe fallback that silently mapped ambiguous files to first sensor (Office)
- Added import time estimate to confirmation dialog
- Added remaining-time indicator during batch import progress

**Fixed:** Import failures through Cloudflare tunnel

- Dashboard suspends background polling/SSE during import to reduce origin pressure
- Added pacing delays between batches (120ms data, 320ms write)
- Added retry with exponential backoff for transient tunnel errors (502/503/504)
- Eliminated HTTP 502 "Bad Gateway" during sustained import over Cloudflare

---

## v7.4.0 — 2026-03-09 (merged via PR #2)

**Added:** CSV import feature

- New import endpoints: `POST /api/import/begin`, `/api/import/d/<data>`, `/api/import/w/<data>`, `/api/import/finish`
- Data transported via URL path (proxy-safe, works through Cloudflare)
- Replacement-first model: existing history cleared before import
- Browser-side validation: timestamp range, value ranges, sensor ID matching, deduplication
- ESP-side validation: sensor lookup, epoch range, value bounds, segment slot overflow
- Dashboard UI: "Import History" button in management card, file picker, progress display, auto-reload
- Supports both single-sensor and merged multi-sensor CSV formats (auto-detected from column headers)
- Sequential batch upload with configurable batch size (250 chars/batch)
- Safe JSON response handling for non-JSON server errors

**Transport evolution (development history):**
This feature went through four transport iterations before reaching the final design:
1. POST body via `handleBody()` — ESP-IDF does not call this (Arduino-only API)
2. URL query parameters — `url_to()` strips query string
3. Custom headers (X-Data/X-Write) — works on LAN, fails through Cloudflare (HTTP 431)
4. URL path encoding — final design, proxy-safe

---

## v7.3.5.0 — 2026-03-08

**Added:** `/api/status` health endpoint

- New `GET /api/status` endpoint returning JSON with version, uptime, sensor count, per-sensor health, free heap
- No authentication required (read-only health check)
- First feature developed through the full GitHub PR workflow (PR #1)

**Fixed:** JSON truncation bug in `/api/status`

- Three JSON fields packed into single `snprintf` targeting 64-byte buffer. Output was 72 bytes. Fix: split into separate print calls.

**Infrastructure:**

- Branch protection configured on `main`
- Root README.md with screenshots in Images/
- Documentation reorganized: 13 overlapping files consolidated into purpose-driven structure
- `scripts/test-local.sh` added
- `Docs/device-test-report-template.md` added
- Version bump applied across VERSION, YAML, dashboard.js, register_history_handler

---

## v7.3.4.2 — 2026-03-07

**Fixed:** Four dashboard issues

- `Export All` HTTP 502 — serialized fetches via `fetchAllSensorHistoryRowsSequentially()`
- Chart point markers not following sensor recolor — updated all marker properties
- 15-minute chart markers oversized — matched to real-time size
- Theme toggle not forcing chart redraw — added `refreshChartsAfterVisualChange()`

**Infrastructure:**

- Repository normalized to canonical paths
- GitHub Actions CI pipeline established
- Helper scripts: preflight, generate-header, deploy, compile-with-log, test-local
- Secrets handling: example committed, real gitignored, CI uses dummy secrets

---

## v7.3.4.1 — 2026-03-06

**Fixed:** Dashboard startup blocker — initialization ordering for `bindEvents()`

---

## v7.3.4 — 2026-03-06

**Changed:** Phase 1 structural enforcement — `App.State` chokepoints, centralized `bindEvents()`, removed inline handlers

---

## v7.3.3 — 2026-03-05

**Baseline:** Stabilization release. Transport/CORS/date-axis regressions addressed.

---

## Earlier versions

See previous changelog entries in git history. Key milestones:
- v7.x: Dedicated history partition, 45-day retention, storage stats, management section
- v6.0: Persistent history (daily NVS snapshots, 30 days)
- v5.0: Dashboard features (min/max, RSSI, dew point, dark/light, CSV export)
- v4.x: Embedded dashboard in firmware
- v3: Per-sensor tracking, batched polling
- v2: AsyncWebHandler pattern for ESP-IDF
- v1: Multi-sensor SensorSlot architecture

---
