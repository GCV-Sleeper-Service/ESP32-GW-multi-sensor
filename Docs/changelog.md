# Changelog

All notable changes to the ESP32-C3 Multi-Sensor BLE Gateway.

## [v7.6.0.5] — 2026-04-04 (PR #129) — Phase D Closure: Playwright Tests + Stateful Mock Server

### New Features

- **Stateful satellite management mock server** (`tests/mock-server/server.js`)
  - Runtime `managedSatellites[]` array initialized from aggregator fixture (`aggregator-gateways.json`)
  - `POST /api/aggregator/add-satellite` — full validation branch coverage:
    - Non-empty body guard (mirrors firmware lines 2381-2384)
    - URL validation (must start with `http://`, max 127 chars)
    - Capacity check (max 8 satellites)
    - Duplicate URL detection (returns 409)
    - Probe simulation (URLs containing "unreachable" fail with 400)
    - Poll interval clamping (10-3600 seconds, default 30)
    - Monotonic ID generation (`nextSatelliteId++`)
    - Returns 405 for wrong HTTP method
  - `DELETE /api/aggregator/satellite/{id}` — auth-gated destructive endpoint:
    - Requires `?auth=mock` query parameter in mock (mirrors firmware authenticate_management_)
    - Empty ID guard (returns 400 instead of 404)
    - Returns 404 for unknown satellite ID
    - Returns 405 for wrong HTTP method
  - `POST /api/aggregator/test-satellite` — auth-gated probe endpoint:
    - Requires `?auth=mock` query parameter in mock
    - Non-empty body guard
    - URL validation (must start with `http://`, max 200 chars)
    - Probe simulation (returns mock gateway info on success)
    - Returns 405 for wrong HTTP method
  - `POST /api/system/reset-satellites` — auth-gated reset endpoint:
    - Requires `?auth=mock` query parameter in mock
    - Non-empty body guard
    - Resets `managedSatellites[]` to fixture defaults
    - Returns 405 for wrong HTTP method
  - `/api/aggregator/gateways` now returns live managed state when `FIXTURE_SET=aggregator`

- **Playwright Test Group 21: Satellite Management** (19 tests, `tests/browser/dashboard.spec.js`)
  - **12 API contract tests:**
    - `POST add-satellite: valid URL returns 200`
    - `POST add-satellite: duplicate URL returns 409`
    - `POST add-satellite: missing URL returns 400`
    - `POST add-satellite: full list returns 409`
    - `POST add-satellite: unreachable URL returns 400`
    - `DELETE satellite: valid ID returns 200`
    - `DELETE satellite: unknown ID returns 404`
    - `POST test-satellite: valid URL returns gateway info`
    - `POST test-satellite: missing URL returns 400`
    - `POST test-satellite: unreachable URL returns 400`
    - `POST test-satellite: URL without http:// returns 400`
    - `POST reset-satellites: resets to fixture defaults`
  - **2 UI rendering tests:**
    - `Settings panel renders add form`
    - `Settings panel renders remove buttons for each satellite`
  - **5 PR #128 regression guards (BUG-080 / BUG-081 / LESSON-OPS-111):**
    - `PR128-regression: URL input value preserved across poll-driven rerender`
    - `PR128-regression: test-satellite result appears in live panel after action`
    - `PR128-regression: settings panel not destroyed during in-flight add`
    - `PR128-regression: panel remains usable after completed add`
    - `PR128-regression: panel remains usable after completed delete`
  - **Stateful test isolation:** `beforeEach` hook resets satellites to fixture defaults before each test
  - **Deterministic waits:** Replaced flaky `waitForFunction` with reliable `waitForTimeout`, added auth token injection for authenticated flows

### Testing

- Full CI-exact validation suite: **402 tests passed, 0 failed** across all four fixture sets
  - 3sensor: 99 passed, 45 skipped
  - mixed: 96 passed, 48 skipped
  - system: 100 passed, 44 skipped
  - aggregator: 107 passed, 37 skipped

### Documentation

- Added `Docs/session-log-2026-04-04-v7.6.0.5.md` — comprehensive implementation log with PR review fixes
- Updated `Docs/phase-d-implementation-plan.md` — v7.6.0.5 marked complete, Phase D closure confirmed
- Updated `Docs/v7.5-v7.6-architecture-plan.md` — Phase D status table added
- Updated `Docs/aggregator-setup.md` — mock server test routes documented

### Important Notes

- **v7.6.0.4 final shipped state** = PR #126 + PR #128 (not PR #126 alone)
  - PR #126: Interactive settings panel with add/test/remove controls
  - PR #128: Stale-DOM fixes (BUG-080, BUG-081, LESSON-OPS-111)
- **Phase D complete:** All 6 steps (v7.6.0.0–v7.6.0.5) delivered
- Satellite configuration is now runtime-manageable via dashboard UI — no YAML editing, no reflashing required

---

## [v7.6.0.4] — 2026-04-03 — Dashboard Add/Remove/Test Satellite UI (Phase D Step 4)

**Note:** Final shipped v7.6.0.4 state includes PR #126 + PR #128 (stale-DOM fixes for BUG-080, BUG-081, LESSON-OPS-111).

### New Features

- **Interactive Settings Panel** — `renderSettingsPanel()` in `dashboard.js` (and mirrored in `dashboard.html`) replaces the read-only satellite list with full management controls:
  - **Add Satellite form** at the top of the settings panel:
    - URL text input (`http://192.168.x.x`) and optional friendly name input
    - `Test` button → `POST /api/aggregator/test-satellite?url=...` with management auth and form-encoded body
    - `Add` button → `POST /api/aggregator/add-satellite?url=...&name=...` (no auth required) with form-encoded body
    - Inline status area — no `alert()` calls
  - **Per-satellite Remove button** on each satellite card:
    - `confirm()` dialog: "Remove satellite {name}? This cannot be undone."
    - → `DELETE /api/aggregator/satellite/{id}` with management auth
    - On success: re-fetches gateway list and re-renders settings panel
  - **Enhanced per-satellite status**: last-seen timestamp (`gw.last_seen`), consecutive failure count when `> 0`, preserved online/unreachable indicator

- **New helper functions** (all programmatic event binding, no inline `onclick`):
  - `_handleTestSatellite(urlInput, statusEl)` — in-flight guarded, uses `requestManagementCredentials()`
  - `_handleAddSatellite(urlInput, nameInput, statusEl)` — in-flight guarded, no auth
  - `_handleRemoveSatellite(satId, satName, statusEl)` — in-flight guarded, uses `requestManagementCredentials()`
  - `_refreshSettingsPanel()` — re-fetches `/api/aggregator/gateways`, rebuilds selector, restores settings tab active state

### CSS

- Added new CSS classes to `dashboard.html` `<style>` section: `.settings-add-form`, `.settings-add-row`, `.settings-input`, `.settings-input-name`, `.settings-add-actions`, `.settings-btn`, `.settings-btn-test`, `.settings-btn-add`, `.settings-btn-remove`, `.settings-status`, `.settings-warning`, `.settings-empty`
- All new `<input>` and `<button>` elements include `color-scheme: light dark`

### Regenerated Artifacts

- `dashboard/dashboard.h` regenerated from minified `dashboard.html` (v7.6.0.4)
- All fixture variants and version strings updated

## [v7.6.0.3] — 2026-04-02 — POST /api/aggregator/test-satellite (Phase D Step 3)

### New Features

- **`POST /api/aggregator/test-satellite`** — replaces the 501 stub with a working probe endpoint.
  - Requires management authentication
  - Accepts `?url=http://...` query parameter
  - Inherits management POST guard — body must be non-empty (e.g. `Content-Type: application/x-www-form-urlencoded`, body `a=1`)
  - Validates URL format (must start with `http://`)
  - Calls `probe_satellite_manifest_()` to fetch `/api/manifest` from the candidate
  - Extracts `hardware` and `sensor_count` from the manifest buffer (`s_proxy_tmp`)
  - Returns `200 {"ok":true,"gateway":{"id":"...","name":"...","hardware":"...","sensor_count":N}}`
  - Returns `400` for missing URL, bad format, empty body, or unreachable/invalid manifest
  - Returns `405` for wrong HTTP method
  - **No side effects:** does not add to `satellite_caches[]`, does not write NVS

### Cleanup

- Removed `handle_aggregator_stub_501_()` — all three Phase D management endpoints now have
  working implementations (add in v7.6.0.1, delete in v7.6.0.2, test in v7.6.0.3).

## [v7.6.0.2] — 2026-04-02 — DELETE /api/aggregator/satellite/{id} (Phase D Step 2)

### New Features

- **`DELETE /api/aggregator/satellite/{id}`** — replaces the 501 stub with a working
  delete endpoint for runtime satellite management.
  - Requires management authentication
  - Parses the satellite ID from the URL path
  - Returns `400` for a missing ID and `404` for an unknown ID
  - Compacts `satellite_caches[]` under `AGG_LOCK()` so the runtime array stays dense
  - Clears the vacated last slot after compaction
  - Decrements `runtime_satellite_count`
  - Returns `200 {"ok":true}` on success

### Architecture

- **Deferred NVS rewrite for delete:** Added `save_satellites_nvs_task_()` and
  `schedule_save_satellites_nvs_()` so the destructive delete path follows Critical Rule 40:
  mutate runtime state under the mutex, send the HTTP response, then perform the bulk
  `save_satellites_to_nvs_()` rewrite on a dedicated 8192-byte task stack.
- **Dense array invariant preserved:** All remaining satellites shift down after delete, so
  every runtime loop that iterates `0..runtime_satellite_count-1` continues to work without
  any index-holding changes in the polling task, gateways endpoint, live endpoint, or proxy
  handler.

### Fixups (commits 1aabd93, 1751649, final)

- **BUG-079 fixup:** `canHandle()` now wires HTTP_DELETE for DELETE satellite route — plain-text 405 responses eliminated
- `canHandle()` wired for GET/POST on DELETE satellite route — wrong-method requests now return 405 (not 404)
- NVS snapshot-based deferred persistence — prevents torn reads during concurrent config mutations
- Config-generation counter in `aggregator_poll_task()` — prevents writing fetched data to wrong cache slot after array compaction
- NVS save-task serialization flag — prevents multiple concurrent deferred save tasks
- CORS `Access-Control-Allow-Methods` includes `DELETE`
- OPTIONS preflight handling for DELETE satellite route

### Documentation

- Added `Docs/session-log-2026-04-02-v7.6.0.2.md`
- Added BUG-079 (DELETE satellite returns plain-text 405 instead of reaching handler)
- Added LESSON-OPS-105 (snapshot-based deferred NVS persistence)
- Added LESSON-OPS-106 (config-generation counter for poll-task safety)
- Added LESSON-OPS-107 (NVS save failure after delete is a known limitation)
- Added LESSON-OPS-108 (handleRequest() GET fallthrough has no method guard)
- Added LESSON-OPS-109 (plain-text 405 = canHandle() returned false)

---
## [v7.6.0.1] — 2026-03-31 — POST /api/aggregator/add-satellite (Phase D Step 1)

### New Features

- **`POST /api/aggregator/add-satellite`** — replaces the 501 stub with a working
  implementation. Accepts `url` (required), `name` (optional), `poll` (optional,
  default 30 s, min 10, max 3600) as query string parameters.
  - Validates URL starts with `http://`
  - Rejects full satellite list (409) and duplicate URLs (409)
  - Probes the candidate via `GET /api/manifest` before adding
  - Extracts `gateway.id` and `gateway.name` from manifest JSON
  - Adds satellite under `AGG_LOCK()` mutex; persists via `save_single_satellite_to_nvs_()`
  - Returns `200 {"ok":true,"satellite":{"id":"...","name":"...","url":"...","poll":N}}`
- **`probe_satellite_manifest_()`** helper — factored out for reuse by v7.6.0.3
  (`test-satellite`). Uses `s_proxy_tmp` (web handler context only, never `s_fetch_tmp`).


### Bug Fixes

- **BUG-075/076: httpd task stack overflow — every POST with a body crashes S3
  aggregator.** Root cause: ESP-IDF's `HTTPD_DEFAULT_CONFIG()` hardcodes
  `.stack_size = 4096`. ESPHome never overrides it. `CONFIG_HTTPD_STACK_SIZE`
  in `sdkconfig_options` is dead config with zero runtime effect.
  - *Primary fix:* Local ESPHome component override via
    `firmware/local_components/web_server_idf/` — patches `config.stack_size = 16384`.
    Managed by `scripts/patch-esphome-httpd-stack.sh`.
  - *Secondary fix:* `handle_reset_satellites_()` and `handle_delete_data_()` now use
    deferred task pattern (`xTaskCreate`, 8192-byte stack) for NVS work.
  - *Content-type fix:* Dashboard POST calls changed from `application/json` to
    `application/x-www-form-urlencoded` with `body: 'a=1'`. ESPHome only consumes
    form-encoded POST bodies.
  - *Dead config removed:* `CONFIG_HTTPD_STACK_SIZE` removed from all board profiles.
  - Board profiles now include `external_components` pointing to the patched component.
  - `render_sensor_config.py` updated to emit `external_components` from board profiles.

### Post-Merge Fixups (v7.6.0.1 fixup — not a version bump)

- **BUG-077: `handle_add_satellite_()` build failure — Arduino `String` type in
  ESP-IDF code.** The coding agent generated `String url_param` (Arduino type)
  which passes CI but breaks `esphome compile`. Fixed to `std::string url_param`.
  Codified as Critical Rule 44.

- **BUG-078: HTTP error responses return status 500 instead of 400/401/405/etc.**
  `init_response_()` in the local `web_server_idf` component only mapped
  200/404/409 status codes; everything else defaulted to HTTP 500. This is a
  pre-existing ESPHome bug inherited by the local component override. Fixed with
  expanded switch covering all used status codes plus `snprintf` fallback.
  Codified as Critical Rule 43, LESSON-OPS-103.

- **canHandle() GET routing for POST-only endpoints.** Added `/api/aggregator/add-satellite`
  and `/api/aggregator/test-satellite` to `canHandle()`'s GET section so the handler
  can return 405 Method Not Allowed instead of ESPHome dropping the connection.


### New Files

- `scripts/patch-esphome-httpd-stack.sh` — copies and patches ESPHome's
  `web_server_idf` component. Re-run after ESPHome upgrades.
- `firmware/local_components/web_server_idf/` — patched component override.
- `Docs/postmortem-BUG-075-076-httpd-stack.md` — full investigation post-mortem.

### New Lessons & Critical Rules

- LESSON-OPS-097 through LESSON-OPS-102
- Critical Rules 38–42

### Architecture Notes

- Minor behaviour change: during an active auth lockout window, requests missing an `Authorization` header now return **401** (missing credentials) instead of **429**. This is more accurate for unauthenticated clients; authenticated failed-attempt lockout responses remain 429.
- The board was in a boot loop and could not be recovered via OTA. After this PR is compiled, the fix **must be flashed via USB serial** (`esphome run --device /dev/ttyUSB0`).
- Serial crash signature before fix: `***ERROR*** A stack overflow in task httpd` and `Guru Meditation Error: Core 1 panic'ed (LoadProhibited)` on POST to `/api/system/reset-satellites` without credentials.

---
## [v7.6.0.0] — 2026-03-29 — NVS Satellite Persistence Layer (Phase D Step 0)

### New Features

- **NVS satellite persistence:** Satellites now survive reboots without reflashing. On boot, the aggregator loads the satellite list from the `agg_sats` NVS namespace. If NVS is empty or corrupt, it falls back to the compile-time defaults from `aggregator_config.h`.
- **`runtime_satellite_count`:** New static variable replaces all `MAX_SATELLITES` loop bounds in `aggregator_poll_task()`, `handle_aggregator_gateways_()`, `handle_aggregator_live_()`, and the proxy handler. `MAX_SATELLITES` is retained only as the compile-time array sizing cap.
- **`SatelliteCache` owned string storage:** Added `id_buf[32]`, `name_buf[64]`, `url_buf[128]` fixed-length buffers to `SatelliteCache`. Added `set_identity()` helper that copies strings into buffers and points `id`/`name`/`base_url` at them. No heap allocation.
- **`load_satellites_from_nvs_()`:** Reads satellite list from NVS `agg_sats` namespace on boot.
- **`save_satellites_to_nvs_()`:** Writes all satellites to NVS (full rewrite — erases stale keys first).
- **`save_single_satellite_to_nvs_()`:** Writes a single satellite entry + updated count (optimisation for add operations in future steps).
- **`POST /api/system/reset-satellites`:** Factory reset endpoint — erases the NVS satellite namespace and reloads compile-time defaults. Returns `{"ok":true,"message":"Reset to compile-time defaults","satellite_count":N}`.

### Post-merge v7.6.0.0 stabilization fixups (2026-03-30)

- **BUG-075/076 root-cause fix:** Management POST handlers (`/api/system/reset-satellites`,
  `/api/delete-data`) now use the deferred task pattern — authenticate + respond immediately
  on the httpd task, then spawn an `xTaskCreate` task (8192-byte stack) for all NVS work.
  Root cause: ESPHome's `web_server_idf.cpp` hardcodes httpd task stack at 4 KB via
  `HTTPD_DEFAULT_CONFIG()` and never overrides it. `CONFIG_HTTPD_STACK_SIZE` in
  `sdkconfig_options` has no effect and has been removed from all board profiles.
- **BUG-076 content-type fix:** Dashboard POST calls changed from `application/json`
  to `application/x-www-form-urlencoded` with `body: 'a=1'`. ESPHome only consumes
  form-encoded POST bodies; JSON bodies are not read, corrupting socket state.

### Architecture

- Boot path remains unified (satellite boot + aggregator overlay, LESSON-OPS-074). `init_satellite_caches_()` is called inside `aggregator_poll_task()` as the first action after task start.
- Compile-time satellite arrays remain as the first-boot fallback source. The aggregator is still fully operational with a fresh flash (no prior NVS state required).
- All NVS write errors are logged but do not crash or corrupt runtime state.

---
## [v7.5.7.0] — 2026-03-28 — Aggregator Manifest Truncation Fix + PSRAM Scaling

### Bug Fixes

- **BUG-074:** Aggregator manifest buffer increased from 4096 to 8192 bytes (`AGG_MANIFEST_BUF_SIZE`). `s_fetch_tmp` increased to match. Truncation detection guard added to `handle_aggregator_gateways_()` — truncated manifests emit `"manifest":null` with a log warning instead of broken JSON.

### Architecture

- **PSRAM-aware aggregator gating:** Generator now enforces "no PSRAM = satellite only" — boards without PSRAM get `AGGREGATOR_ENABLED 0` even if `aggregator.json` is present (with build-time warning). PSRAM boards support up to 8 satellites.
- **`AGG_MANIFEST_BUF_SIZE` constant:** Buffer size no longer a magic number. Defined in generated `aggregator_config.h` and as a fallback `constexpr` in `sensor_history_multi.h`.

### Documentation

- `Docs/aggregator-setup.md` updated with buffer sizes and PSRAM scaling rules
- `Docs/v7.5-v7.6-architecture-plan.md` updated with v7.5.7.0 entry
- BUG-074 and LESSON-OPS-085 added to `Docs/bugs-and-lessons-learned.md`

---
## [v7.5.6.4] — 2026-03-26 — Test Fixtures, Playwright Tests, and Phase 6 Closure

### ✅ Phase 6 — Data Ingest and System Metrics — COMPLETE

All Phase 6 steps (v7.5.6.0–v7.5.6.4) are merged. External systems can push metrics
into the gateway via HTTP POST. System devices (CPU, RAM, disk) display alongside
environmental and network sensor cards.

### New `system` fixture variant

Added `tests/fixtures/variants/system/` with:
- 2 ThermoPro environmental sensors (`office`, `first_floor`)
- 1 network device (`wan_ping`)
- 1 system device (`nas01`, `external_push` adapter)
- 4 total sensors; all JSON files end with real `\n` newline
- `api-status.json` includes `free_heap`, `free_heap_internal`, `free_heap_total`

### LESSON-OPS-079 compliance: Updated `mixed` fixture variant

Added `nas01` system device to the `mixed` fixture variant in `generate-fixtures.js`.
Mixed variant now has 2 env + 1 network + 1 system = 4 sensors. Group 18 tests
updated to use `expectedSensorCount: 4`.

### Mock server extension

- Added `POST /api/ingest/:deviceId/:metricKey` route responding `{"ok":true}` for
  known devices, 404 for unknown devices
- `/api/v2/live` for system fixture now returns non-null values for `nas01`:
  `cpu_pct: 45.2`, `ram_pct: 72.8`, `disk_pct: 55.0`, `uptime_hrs: 168.5`

### Playwright Group 20: System Devices and Data Ingest (8 tests)

- System fixture renders correct total card count (4)
- System card renders with usage bar elements
- Environmental cards have full ThermoPro layout (count: 2)
- Network card present alongside system card (count: 1)
- `CARD_RENDERERS.system` is registered
- `/api/v2/live` returns system device data
- POST `/api/ingest` returns 200 for valid device/metric
- POST `/api/ingest` returns 404 for unknown device

### Skip guards: system fixture compatibility audit

7 existing tests received skip guards for `FIXTURE_SET=system` (BUG-051 prevention).
Documented in `Docs/bugs-and-lessons-learned.md` as LESSON-OPS-080.

### Bug fixes

- **BUG-072** (`updateNetworkCards()`): Changed truthy `last_seen` check to `!= null`
  so a `last_seen` value of `0` correctly updates the network card display.
- **BUG-073** (`buildNetworkCard()`): Added `escHtml()` to `target` string to prevent
  XSS via config-derived manifest data.
Both fixes mirrored in `dashboard.js` and `dashboard.html`.

### CI matrix update

Added `system` to the `fixture_set` matrix in `.github/workflows/browser-tests.yml`.
New step runs Group 20 with `FIXTURE_SET=system --grep "20\. System Devices"`.
System fixture excluded from sensor-count smoke step.

### Version bump and regeneration

- Bumped version to `7.5.6.4` via `bash scripts/bump-version.sh 7.5.6.4`
- Ran Critical Rule 28 regeneration sequence:
  - `python3 scripts/render_sensor_config.py --write`
  - `node tests/fixtures/generate-fixtures.js`
  - `bash scripts/generate-header.sh`
  - `python3 scripts/render_sensor_config.py --check`
  - `grep -q "free_heap" tests/fixtures/api-status.json`

---
## [v7.5.6.3] — 2026-03-26 — Example Exporter Scripts and Ingest Documentation (Phase 6 Step 3)

### Added exporter scripts for external system metrics push

Added new executable exporter scripts under `scripts/exporters/`:

- `system-metrics-exporter.sh` (Linux bash exporter)
- `system-metrics-exporter.py` (cross-platform Python exporter, stdlib-only)

Both scripts support configurable gateway URL and device ID and push:

- `cpu_pct`
- `ram_pct`
- `disk_pct`
- `uptime_hrs`

to:

- `POST /api/ingest/{device_id}/{metric_key}?val={float}`

### Added ingest workflow setup guide

Added `Docs/data-ingest-setup.md` with setup and operations guidance:

- endpoint overview and prerequisites
- adding a `system` / `external_push` device
- bash and Python exporter usage
- custom exporter API contract
- monitoring and troubleshooting
- security limitations for v7.5.6.x

The guide documents the exact ingest error response format returned by firmware:

- `{"ok":false,"message":"...","status":N}`

and success response:

- `{"ok":true}`

### Version bump and regeneration

- Bumped version to `7.5.6.3` via `bash scripts/bump-version.sh 7.5.6.3`
- Ran Critical Rule 28 regeneration sequence:
  - `python3 scripts/render_sensor_config.py --write`
  - `node tests/fixtures/generate-fixtures.js`
  - `bash scripts/generate-header.sh`
  - `python3 scripts/render_sensor_config.py --check`
  - `grep -q "free_heap" tests/fixtures/api-status.json`

---
## [v7.5.6.2] — 2026-03-26 — System Card Renderer (Phase 6 Step 2)

### Dashboard system card renderer added

Implemented `CARD_RENDERERS.system` for dashboard card dispatch and added a dedicated
system card layout that renders:

- CPU usage bar
- RAM usage bar
- Disk usage bar
- Uptime value
- Last-seen timestamp
- Optional `source.description` text from manifest

### Live data wiring for system devices

System card values are now updated from `/api/v2/live` polling (not SSE), matching
network device behavior:

- Added `updateSystemCards(liveData)` to process `cpu_pct`, `ram_pct`, `disk_pct`, `uptime_hrs`, `last_seen`
- Added `updateUsageBar(id, value, formatter)` helper with 0–100 clamp and class-based color bands
- Updated `pollV2Live()` to invoke both:
  - `updateNetworkCards(data)`
  - `updateSystemCards(data)`

### Metric formatter extensions

Added explicit formatter keys used by `updateSystemCards()`:

- `METRIC_FORMATTERS.cpu_usage`
- `METRIC_FORMATTERS.ram_usage`
- `METRIC_FORMATTERS.disk_usage`
- `METRIC_FORMATTERS.uptime_hours`

These are intentionally explicit formatter keys (not auto-mapped from manifest metric names).

### Aggregator per-gateway remote system card updates

Extended aggregator remote gateway live-path rendering so `renderGatewayDevices()`
cards with `category: "system"` are populated from `/api/aggregator/live` in
`_populateGatewayDeviceLive()`.

### Styling updates

Added system-card styles in dashboard HTML:

- `.system-card`
- `.system-usage-row`
- `.system-bar-bg`
- `.system-bar-fill`
- `.system-bar-fill.bar-ok/.bar-warning/.bar-danger`

### Mirror/regeneration and validation

- Mirrored all required dashboard logic updates in both:
  - `dashboard/dashboard.js`
  - `dashboard/dashboard.html`
- Regenerated compressed dashboard header (`dashboard/dashboard.h`)
- Executed required regeneration sequence (Critical Rule 28)
- Verified `free_heap` guard in fixtures
- Ran required Playwright/preflight/render checks before edits and again after changes

---
## [v7.5.6.1] — 2026-03-26 — System Device Category and Manifest Entries (Phase 6 Step 1)

### System device category support added

Implemented support for a new `system` device category using the `external_push`
adapter, with default manifest entry:

- `nas01` (`NAS Health`) in `config/sensors.json`
- `category: "system"`
- `adapter: "external_push"`
- `source.description` metadata for ingest provenance

### Manifest validation and generation updates

- Extended `canonicalize_sensors()` in `scripts/sensor_manifest_lib.py`:
  - Accepts `external_push` adapter
  - Does not require `mac` for `external_push`
  - Preserves optional `source.description`
  - Rejects unknown adapters explicitly
- Increased manifest sensor limit from 4 to 5 to support default set:
  - 3 environmental + 1 network + 1 system
- Extended manifest v2 generation to include system metrics and measurements:
  - `cpu_pct`, `ram_pct`, `disk_pct` (history-enabled)
  - `uptime_hrs` (metadata, no history)

### Generator/runtime entity updates

Updated `scripts/render_sensor_config.py` to generate system entities in
`dashboard/sensor_history_multi.h`:

- Added `metrics_system[]`
- Added history buffers for:
  - `entity_hbuf_nas01_cpu_pct`
  - `entity_hbuf_nas01_ram_pct`
  - `entity_hbuf_nas01_disk_pct`
- Added `SensorEntity` for `nas01` with:
  - `category_id = 1` (`system`)
  - `adapter = "external_push"`
  - `metric_count = 4`

### BUG-045 / BUG-052 / BUG-053 invariants preserved

Verified generated constants and endpoint behavior:

- `NUM_DEVICES = 5`
- `NUM_ENV_SENSORS = 3`
- `NUM_SENSORS = NUM_ENV_SENSORS` (unchanged alias; no persistence schema break)
- `/sensors.json` remains environmental-only (no `nas01`)
- `/api/status` includes `nas01` with `"category":"system"` and excludes
  `temp_valid`/`hum_valid`
- `/api/v2/live` includes `nas01` with null metric values before ingest
- Legacy `/history/nas01/temp` remains blocked (404)

### Fixture/mock/test alignment

- Updated `tests/fixtures/generate-fixtures.js` for `external_push` manifest output
  and system metric metadata.
- Updated `tests/mock-server/server.js` `/api/v2/live` stub to emit null-valued
  system metrics for system devices.
- Updated Playwright expectations for 5-device satellite manifests where needed.
- Updated preflight guard:
  - `fixture_manifest_sensor_count` now expects `5`.

### Validation

- Required precondition suite passed before edits.
- Critical Rule 28 regeneration sequence executed.
- Required Playwright + preflight + `render_sensor_config.py --check` validation
  completed after changes.

---
## [v7.5.6.0] — 2026-03-26 — POST /api/ingest Endpoint (Phase 6 Step 0)

### Ingest endpoint added

Added local ingest endpoint to `HistoryWebHandler`:

- `POST /api/ingest/{device_id}/{metric_key}?val={float}`

Behavior:
- Parses `device_id` and `metric_key` from URL path (prefix `/api/ingest/`, 12 chars)
- Validates device exists in `devices[]`
- Validates metric exists in `metric_defs[]` for that device
- Parses `val` query parameter as finite float
- Writes data with `devices[dev].add_sample(metric, value)`
- Updates freshness with `devices[dev].mark_seen(::time(nullptr))`
- Returns `200 {"ok":true}` on success

Error responses (reusing existing `send_json_error_()` helper):
- `405` — `Method not allowed` (non-POST)
- `404` — `Unknown device`
- `404` — `Unknown metric`
- `400` — `Missing val parameter`
- `400` — `Invalid value`

### Route registration and endpoint audit

Added `/api/ingest/` prefix handling to both:
- `canHandle()` (`strncmp(p, "/api/ingest/", 12)`)
- `handleRequest()` (dispatches to `handle_api_ingest_()`)

This does not collide with existing `/api/import/` or `/api/v2/` prefixes.

### Response/header compliance

- Success response uses `beginResponse()` (not `beginResponseStream()`)
- Success response uses `add_common_headers_()`
- Error responses use existing `send_json_error_()` helper (no duplicate helper added)

### Security note

`/api/ingest` currently has no authentication. Any client on the same network can push values.
This is acceptable for home/lab deployments in Phase 6 and must be hardened in a future security phase.

### Validation and tooling updates

- Added preflight guard: `history_handler_has_api_ingest_route`
- Version bumped to `7.5.6.0`
- Regeneration sequence executed (Critical Rule 28)
- Required Playwright + preflight validation completed

---
## [v7.5.5.5-docs] — 2026-03-25 — Documentation Overhaul and Phase D Planning

### Documentation cleanup

Consolidated and removed 23 obsolete files from root, Docs/, and prompts/:
- 8 individual Phase 5 session logs → consolidated into `session-log-archive-v7.5.x.md`
- 13 superseded Docs/ files (old architecture, version-specific docs, one-off fix prompts)
- 2 obsolete prompt handoff files (updates already applied)

### New documents

- **`Docs/phase-d-implementation-plan.md`** — detailed 6-step plan for Phase D (v7.6.0.0–v7.6.0.5): NVS satellite persistence, add/remove/test endpoints, dashboard management UI
- **`prompts/session-handoff-phase6.md`** — complete context handoff for Phase 6 start
- **`prompts/prompt-index-and-workflow.md`** — added Phase D section, version mapping table

### README rewrite

Updated from v7.5.3.9 to v7.5.5.5 state:
- Multi-board support, aggregator architecture, satellite/aggregator roles
- Updated API table (aggregator endpoints, ingest stub)
- Updated roadmap (Phases 1–5 complete, Phase 6 next, Phase D and 7 planned)
- Updated repo layout, test counts, preflight counts

### Version mapping established

| Phase | Version Range |
|-------|--------------|
| Phase 6 | v7.5.6.x |
| Phase D | v7.6.0.x |
| Phase 7 | v7.7.x |
| Phase E | v8.x |


---
## [v7.5.5.5-hotfix] — 2026-03-25 — Fixture Fragility Guard

### Problem

The `tests/fixtures/api-status.json` root fixture was missing `free_heap`,
`free_heap_internal`, and `free_heap_total` fields on main after the v7.5.5.5
merge. This caused `render_sensor_config.py --check` to fail. The same
regression occurred across PRs #68, #69, #70, #72, and #73 — making it the
single most expensive recurring issue in Phase 5.

### Root cause

Two independent fixture generators exist:
- `render_sensor_config.py` (root fixture) — already included `free_heap` in template
- `generate-fixtures.js` (variant fixtures) — did NOT include `free_heap`

Agents either manually edited the file (dropping fields) or ran `--write`
without also running the variant generator, leaving fixtures out of sync.

### Fixes

| Change | File |
|--------|------|
| Restored `free_heap` fields in root `api-status.json` | `tests/fixtures/api-status.json` |
| Added `free_heap` to variant fixture template | `tests/fixtures/generate-fixtures.js` |
| Regenerated all variant fixtures | `tests/fixtures/variants/*/api-status.json` |
| Added 3 preflight guards for `free_heap` fields | `scripts/preflight.sh` |
| Added LESSON-OPS-077 (systemic fixture fragility) | `Docs/bugs-and-lessons-learned.md` |
| Added Critical Rule 28 (both generators + verify) | `prompts/prompt-index-and-workflow.md` |
| Added CI/Development Pipeline section | `Docs/aggregator-setup.md` |

### Validation

- `render_sensor_config.py --check`: PASS
- `preflight.sh`: PASS (including new `free_heap` guards)
- All variant fixtures at v7.5.5.5 with `free_heap` fields
- Playwright: 3sensor 97 pass / 18 skip, mixed 7 pass, aggregator 11 pass / 1 skip

---
## [v7.5.5.5] — 2026-03-25 — Phase 5 Closure and Documentation

### Phase 5 Complete ✅

Phase 5 (Aggregator MVP) is closed with documentation, closure-gate verification, and full
validation rerun across all fixture variants.

| Step | Scope | Status |
|------|-------|--------|
| v7.5.5.0 | Aggregator configuration schema and loader | Complete |
| v7.5.5.1 | Aggregator polling task | Complete |
| v7.5.5.2 | Aggregator API endpoints | Complete |
| v7.5.5.3 | Aggregator dashboard UI (+ hotfix/hotfix-2) | Complete |
| v7.5.5.4 | Aggregator fixtures + Playwright coverage | Complete |
| v7.5.5.5 | Phase closure, docs, validation certification | Complete |

### Documentation delivered

- **New:** `Docs/aggregator-setup.md`
  - End-to-end aggregator deployment workflow
  - Multi-board guidance (C3/S3/WROOM profiles)
  - Naming convention guidance (`sat-*` / `agg-*`)
  - Config separation (`gateway.json`, `aggregator.json`, `sensors_file`)
  - Dashboard layout clarification (GATEWAYS vs SENSORS)
  - Zero-sensor aggregator guidance
  - Board correctness and troubleshooting guidance
- **Updated:** `Docs/v7.5-v7.6-architecture-plan.md`
  - Phase 5 marked COMPLETE with step table and completion date
  - Unified boot-path architecture note (BUG-064 / LESSON-OPS-074)
  - Multi-board validation note and Phase D next-milestone note
- **Updated:** `prompts/prompt-index-and-workflow.md`
  - v7.5.5.5 marked complete
  - Critical rule added for LESSON-OPS-068 (`lwip_*` socket usage)

### Closure-gate and validation evidence

- Fixture JSON validation: all fixture JSON files validated with `python3 -m json.tool`
- Generated-file consistency: `python3 scripts/render_sensor_config.py --check` passes (deployment configs absent)
- Playwright rerun (all six commands):
  - `FIXTURE_SET=3sensor --project=chromium`: **99 passed, 18 skipped**
  - `FIXTURE_SET=3sensor --project=firefox`: **99 passed, 18 skipped**
  - `FIXTURE_SET=mixed --project=chromium`: **95 passed, 22 skipped**
  - `FIXTURE_SET=mixed --project=firefox`: **95 passed, 22 skipped**
  - `FIXTURE_SET=aggregator --project=chromium`: **88 passed, 29 skipped**
  - `FIXTURE_SET=aggregator --project=firefox`: **88 passed, 29 skipped**
- `bash scripts/preflight.sh`: PASS

### Closure-gate checklist status

- [x] All fixture JSON files validated with `python3 -m json.tool`
- [x] `python3 scripts/render_sensor_config.py --check` passes with deployment configs absent
- [x] BUG-064 through BUG-069 documented in `Docs/bugs-and-lessons-learned.md`
- [x] LESSON-OPS-074 documented
- [x] Session logs exist for v7.5.5.3 hotfix and hotfix-2 sessions
- [x] Critical Rule 26 (LESSON-OPS-074) present in prompt index

---
## [v7.5.5.4] — 2026-03-25 — Aggregator Playwright Tests + Fixtures

### Phase 5 Step 4: Aggregator Test Infrastructure

Added complete Playwright test fixtures and test group for aggregator mode
verification. No functional or logic changes to firmware or dashboard sources in this step.

#### `tests/fixtures/variants/aggregator/`

New fixture variant simulating an aggregator with 2 satellites:
- `sensors.json` — empty array (pure aggregator, no local env sensors)
- `manifest.json` — v2 manifest with role=aggregator, hardware=ESP32-S3, 0 sensors
- `api-status.json` — includes required `free_heap`/`free_heap_internal`/`free_heap_total` fields (BUG-062 prevention)
- `aggregator-gateways.json` — 2 gateways: gw-main (reachable), gw-garage (unreachable), each with `manifest.sensors` array and `base_url`
- `aggregator-live.json` — live data from reachable satellite (office env + wan_ping network)
- `history-gw-main-office-temp.csv` / `history-gw-main-office-hum.csv` — CSV for proxy history route
- `storage-stats.json` — copied from root baseline

#### Mock server routes extended (`tests/mock-server/server.js`)

Extended existing `/api/aggregator/gateways`, `/api/aggregator/live`, and
`/api/aggregator/proxy/{gwId}/history/{device}/{metric}` routes to serve fixture
files when `FIXTURE_SET=aggregator`. Fallback to empty/default responses for all
other fixture sets (satellite mode). Routes extended, not duplicated.

#### `tests/browser/dashboard.spec.js`

- Added `waitForAggregatorReady(page)` helper — polls `window._aggregatorReady === true`
- Added Group 19 (Aggregator Mode) with 11 tests covering:
  - Mode detection (`DASHBOARD_MODE === 'aggregator'`)
  - Gateway selector visibility and tab count (4)
  - Offline satellite indicator
  - All Gateways summary (2 cards)
  - Per-gateway device cards
  - Environmental live values (temp=23.4 from fixture)
  - Network card live values (ping_ms=12.3 from fixture)
  - Settings panel satellite list (2 cards)
  - Gateways section separation (BUG-065 regression)
  - Unified boot — modeLabel present (LESSON-OPS-074)
- Added satellite fallback test to Group 1 (skip guard for aggregator)
- Added skip guards to 17 existing tests incompatible with aggregator fixture

#### Existing test skip guards (BUG-051 prevention)

Skip guards added (FIXTURE_SET=aggregator) to the following tests, referencing
the specific incompatibility:

| Test | Reason |
|------|--------|
| 1. version string in DOM | #modeLabel in #c3DescriptionBlock, hidden by updateBoardInfo() for ESP32-S3 |
| 2. four sensor cards | DEFAULT_SENSOR_META fallback yields 3 env-only (no wan_ping) |
| 9. manifest sensors array | manifest.sensors is [] (0 local sensors) |
| 9. manifest gateway block | gateway.role=aggregator (not satellite) |
| 9. manifest metrics array | metrics is [] (no env sensors) |
| 11. env renderer dispatches | card count 4 is satellite-specific |
| 14. scenario 1 source check | DEFAULT_SENSOR_META fallback yields source=auto-promoted |
| 14. scenario 4 env dispatcher | expectedSensorCount(4) is satellite-specific |
| 15. legacy /sensors.json | sensors.json is [] for aggregator; length > 0 fails |
| 15. dashboard renders identically | 4 cards + wan_ping are satellite-specific |
| 16. /api/manifest fetched once | aggregator calls it twice (loadManifestV2 + loadSensorManifest) |
| 17. network card renders | no wan_ping in DEFAULT_SENSOR_META |
| 17. net-ping-wan_ping element | element absent (no wan_ping in local sensors) |
| 17. net-success-wan_ping element | same |
| 17. net-target-wan_ping element | same |
| 17. SENSORS includes wan_ping | DEFAULT_SENSOR_META has no wan_ping |
| 17. updateNetworkCards ping values | #net-ping-wan_ping absent |
| manifest.spec.js: api manifest metadata | sensor_count=0, role=aggregator |
| manifest.spec.js: dashboard boots from manifest | DEFAULT_SENSOR_META fallback, not 4 sensors |
| sensor-count.spec.js: card count matches manifest | manifest.length=0, cards=3 mismatch |
| sensor-count.spec.js: export buttons match manifest | same |

#### CI matrix (`browser-tests.yml`)

Added `aggregator` to `fixture_set` matrix. New CI step runs
`--grep "19\. Aggregator Mode"`. Aggregator excluded from sensor-count smoke step.

---
## [v7.5.5.3-hotfix-2] — 2026-03-25 — Manifest Hardware String + Environmental Chart Hiding

### BUG-068: Board-aware manifest hardware string

`render_sensor_config.py` now builds `gateway_meta` from the board profile's
`chip_variant` field (e.g., `esp32s3` → `ESP32-S3`), the gateway config's
`friendly_name` and `esphome_name`, and the aggregator config's role. This
`gateway_meta` flows into both the compiled manifest (`gateway_manifest.h`) and
test fixtures. The S3 aggregator now correctly reports `"hardware": "ESP32-S3"`
in `/api/manifest`, enabling the BUG-067 About card fix to work.

### BUG-069: Hide environmental chart sections when no env sensors

After `initCharts()`, the boot path checks whether any local sensor has
`category === 'environmental'`. If none exist (e.g., aggregator with only WAN
ping), the Temperature/Humidity Real-Time and 15-Minute Average chart sections
are hidden. Added `id` attributes (`hdr-realtime`, `hdr-averages`,
`divider-charts`) to enable JS targeting.

---
## [v7.5.5.3-hotfix] — 2026-03-25 — Aggregator Boot Path Fix + Layout Correction

### BUG-064: Unified boot path (aggregator = satellite + overlay)

The aggregator boot path was rewritten from a forked if/else to a unified pipeline.
Both satellite and aggregator now run the full satellite pipeline (manifest → sensor
cards → charts → SSE/polling → status → storage stats → history). The aggregator
overlays `initAggregatorDashboard()` at the end. This fixes: red "connecting" dot,
"loading..." on storage stats, "waiting for telemetry", and missing local sensor cards
(WAN ping) on the aggregator.

### BUG-065: Gateways section separated from SENSORS

New collapsible "Gateways" section added above "SENSORS" in `dashboard.html`,
hidden by default. `initAggregatorDashboard()` unhides it. All aggregator render
functions (`renderGatewaySelector`, `renderAllGatewaysSummary`, `renderGatewayDevices`,
`renderSettingsPanel`) now target `#gwSelectorContainer` and `#gwGrid` instead of
`#sensorGrid`. Local sensors stay in SENSORS.

### BUG-066: Remote satellite history suppression

Per-gateway satellite device cards now show "—" for min/max history instead of
"calculating...". Range toggle buttons are hidden. Proxy history fetch is a
planned future feature.

### BUG-067: Board-aware About card

`updateBoardInfo()` extended to hide C3-specific content on non-C3 boards:
GPIO pinout card (`#gpioCard`), C3 description (`#c3DescriptionBlock`), C3 SVG
(`#pinoutDiagram`). About card title (`#aboutCardTitle`) updated from manifest.

---
## [v7.5.5.3] — 2026-03-24 — Aggregator Dashboard UI (Phase 5 Step 3)

### Aggregator dashboard mode detection

`detectAggregatorMode()` probes `GET /api/aggregator/gateways` at boot.
On satellites the endpoint returns an empty gateway list (fast fail, no
console error). On aggregators it returns the active gateway list.
`DASHBOARD_MODE` is set to `'aggregator'` or `'satellite'` accordingly.
The same `dashboard.html` is served by both firmware types.

### Aggregator boot path

`App.Boot.start()` now calls `detectAggregatorMode()` first and branches:

- **Aggregator path**: loads local manifest (the aggregator may have local
  devices like `wan_ping`), calls `updateBoardInfo()`, builds local device
  cards if any exist, then calls `initAggregatorDashboard()`.
- **Satellite path**: unchanged (existing boot flow preserved byte-for-byte,
  plus `updateBoardInfo()` added per Part D).

### Aggregator UI components

**`renderGatewaySelector(gateways)`** — inserts a `.gw-selector` tab bar
before `#sensorGrid`. Tabs: "All Gateways", one tab per satellite, "⚙ Settings"
(always last). Tab clicks dispatch to the appropriate view renderer. Uses
programmatic `addEventListener` (no inline `onclick`).

**`renderAllGatewaysSummary(gateways)`** — renders gateway health cards into
`#sensorGrid`. Each card shows: status dot (online/offline), name, id, last
seen timestamp, firmware version, device count. Stale (unreachable) gateways
get `.gw-stale` class and reduced opacity.

**`renderGatewayDevices(gwId)`** — renders per-gateway device cards. Parses
the `manifest` field from the `/api/aggregator/gateways` response. Builds
sensor configs with namespaced IDs (`{gw_id}.{device_id}`) to avoid
cross-gateway collisions. Dispatches to existing `CARD_RENDERERS`. Populates
live values from `/api/aggregator/live` via `_populateGatewayDeviceLive()`.
Falls back to a "manifest not yet cached" message if manifest is unavailable.

**`renderSettingsPanel(gateways)`** — read-only satellite configuration panel.
Shows each satellite's base URL, firmware version, device count, and status.
Displays a note that runtime management is planned for v7.6.

**`initAggregatorDashboard()`** — orchestrates the aggregator startup sequence:
build tab selector, render default "All Gateways" view, start 15s polling.
Sets `window._aggregatorReady = true` for Playwright test infrastructure.

**`pollAggregatorLive()`** — in-flight guarded (like `pollV2Live`). Fetches
`/api/aggregator/gateways` every 15s, updates `window._aggregatorGateways`,
refreshes gateway tab status indicators, and re-renders the active view if
it's "All Gateways" or "Settings".

### Board-aware About card (updateBoardInfo)

**`updateBoardInfo()`** — called after manifest loads in both satellite and
aggregator boot paths. Hides `#pinoutDiagram` (the C3 SuperMini SVG) if the
manifest's `gateway.hardware` field does not contain "C3". Enables the same
`dashboard.html` to serve non-C3 boards without showing C3-specific content.

**`id="pinoutDiagram"`** added to `<div class="device-photo-wrap">` in
`dashboard.html` to make the C3 board SVG selectable by `updateBoardInfo()`.

### Aggregator gateways API extended (sensor_history_multi.h)

`handle_aggregator_gateways_` now includes two additional fields per satellite:
- `base_url` — the satellite's HTTP URL (for settings panel display)
- `manifest` — the full cached `/api/manifest` JSON (for per-gateway device
  rendering in `renderGatewayDevices()`)

### Stub management endpoints (sensor_history_multi.h)

Three stubbed endpoints added under `#if AGGREGATOR_ENABLED`, reserved for
v7.6 runtime satellite management:
- `POST /api/aggregator/add-satellite` → 501 Not Implemented
- `POST /api/aggregator/test-satellite` → 501 Not Implemented
- `DELETE /api/aggregator/satellite/{id}` → 501 Not Implemented

All return `{"error":"not implemented","message":"...planned for v7.6"}`.

### Aggregator CSS added to dashboard.html

New CSS classes for aggregator UI elements:
`.gw-selector`, `.gw-tab`, `.gw-online`, `.gw-offline`, `.gw-settings-tab`,
`.gw-summary-card`, `.gw-stale`, `.gw-summary-header`, `.gw-summary-id`,
`.gw-summary-details`, `.gw-detail-label`, `.gw-status-online`,
`.gw-status-offline`, `.gw-stale-overlay`, `.settings-panel`,
`.settings-title`, `.settings-subtitle`, `.settings-satellite-card`,
`.settings-sat-header`, `.settings-sat-id`, `.settings-sat-details`.
Light-mode overrides added for tab and card elements.

### Mock server updated

`tests/mock-server/server.js`: `/api/aggregator/gateways` now returns
`{"gateways":[]}` (200 OK, empty list) for satellite fixture sets. This
correctly triggers satellite mode in `detectAggregatorMode()` (empty list
→ `data.gateways.length === 0` → returns false) without producing a 404
browser console error that would fail the console error guard tests.

### Test changes

- `tests/browser/dashboard.spec.js` (Group 16, BUG-043 regression):
  First-request check updated to filter `/api/aggregator/gateways` probe
  before verifying manifest comes before entity polling.

### Files modified

- `dashboard/dashboard.js` — `DASHBOARD_MODE` var, aggregator UI functions,
  `updateBoardInfo()`, modified `App.Boot.start()`; version bumped to v7.5.5.3
- `dashboard/dashboard.html` — aggregator CSS, `id="pinoutDiagram"`,
  mirrored JS changes, `dashboard.h` regenerated; version bumped to v7.5.5.3
- `dashboard/dashboard.h` — regenerated from updated `dashboard.html`
- `dashboard/sensor_history_multi.h` — `base_url`+`manifest` in gateways
  response, stub 501 endpoints, version bumped to v7.5.5.3
- `tests/mock-server/server.js` — aggregator route handlers (empty gateways)
- `tests/browser/dashboard.spec.js` — BUG-043 first-request check updated
- `scripts/render_sensor_config.py` — version bump to 7.5.5.3
- `tests/fixtures/generate-fixtures.js` — version bump to 7.5.5.3
- `firmware/esp32-c3-multi-sensor.yaml` — version bump to v7.5.5.3
- `src/gateway_manifest.h`, `tests/fixtures/manifest.json`,
  `tests/fixtures/api-status.json`, `tests/fixtures/variants/*/` —
  regenerated artifacts

---
## [v7.5.5.2] — 2026-03-24 — Aggregator API Endpoints (Phase 5 Step 2)

### Aggregator API endpoints (`#if AGGREGATOR_ENABLED`)

Three new aggregator-only endpoints added to `HistoryWebHandler`. All are
conditionally compiled and never present on satellite firmware
(`AGGREGATOR_ENABLED 0`).

**`GET /api/aggregator/gateways`** — returns the satellite list with
cached status. Includes `id`, `name`, `reachable`, `last_seen`,
`consecutive_failures`, `manifest_cached`, `live_cached`,
`firmware_version`, `sensor_count`, and `free_heap` extracted from the
cached `/api/status` response via `strstr()`.

**`GET /api/aggregator/live`** — returns unified live values from all
satellites. Each gateway entry contains `reachable` and the raw cached
`/api/v2/live` JSON embedded as-is (no parsing). Timestamp is the
current epoch from `::time(nullptr)`.

**`GET /api/aggregator/proxy/{gw_id}/history/{device}/{metric}`** — on-demand
history proxy. Fetches from the satellite using `fetch_to_buffer()` into
`s_proxy_tmp[32768]` (separate from `s_fetch_tmp` used by the polling
task) and relays the response with zero-copy `beginResponse`. Returns
404 for unknown gateway IDs, 502 if the satellite fetch fails.

**Thread safety:** All cache reads for gateways/live handlers take the
`s_cache_mutex` before reading and release before sending. The proxy
handler takes the mutex only briefly to read `base_url`, then releases
before the blocking network fetch.

**Fix: proxy truncation detection** — proxy endpoint now returns 502
with `{"error":"upstream_response_too_large","max_bytes":32768}` if the
upstream history response exceeds the 32KB buffer, instead of silently
serving truncated data as HTTP 200. See BUG-063.

**Fix: proxy upstream URL** — proxy now fetches from
`/api/v2/history/{device}/{metric}` (v2 endpoint, all device categories)
instead of the legacy `/history/{device}/{metric}` (env-only). This
enables proxying ping, RSSI, and other non-environmental metric history.

**LESSON-OPS-056 compliance:** All new aggregator endpoint responses use
pre-reserved `std::string` + `beginResponse()`. `beginResponseStream` is
not used by these handlers.

**LESSON-OPS-068 compliance:** All socket calls in `fetch_to_buffer()` use
`lwip_*()` prefixed names (no BSD socket aliases).

### Preflight checks added

`scripts/preflight.sh`: three new checks inside the
`config/aggregator.json` conditional block verify that the three
aggregator route patterns are present in `sensor_history_multi.h`.

### Files modified

- `dashboard/sensor_history_multi.h` — three new handler methods, proxy
  static buffers `s_proxy_tmp[32768]`/`s_proxy_len`, aggregator routes
  in `canHandle()` and `handleRequest()`; version bumped to v7.5.5.2
- `scripts/preflight.sh` — three aggregator route checks
- `scripts/render_sensor_config.py` — version bump to 7.5.5.2
- `tests/fixtures/generate-fixtures.js` — version bump to 7.5.5.2
- `dashboard/dashboard.html`, `dashboard/dashboard.js`,
  `dashboard/dashboard.h` — version bump to v7.5.5.2
- `firmware/esp32-c3-multi-sensor.yaml` — version bump to v7.5.5.2
- `src/gateway_manifest.h`, `tests/fixtures/manifest.json`,
  `tests/fixtures/api-status.json`, `tests/fixtures/variants/*/` —
  regenerated artifacts

---
## Infrastructure — Multi-Board Fixes and Repo Cleanup — 2026-03-24

### No version bump — build infrastructure only

**BUG-060 fixed: lazy yaml import.** Moved `import yaml` from top-level in
`sensor_manifest_lib.py` to inside `load_board_profile()`. The satellite workflow
(which never calls `load_board_profile()`) no longer requires PyYAML installed.

**BUG-061 fixed: S3 partition table corrected.** `partitions/esp32-s3-multi-partitions.csv`
now has `ota_0` at `0x10000` (was `0x20000`, which bricked the S3 on first flash).
Added documentation comments explaining the 0x10000 requirement.

**ThermoPro indentation fix in generator.** `generate_board_yaml()` in
`render_sensor_config.py` now correctly shifts ThermoPro blocks by 1 space for
non-C3 boards, producing valid ESPHome YAML.

**Corrupted Phase 6 prompt headers repaired.** `v7.5.6.0` and `v7.5.6.2` instruction
files had their first ~21 lines accidentally removed during addendum insertion. Headers
restored from git history.

**Per-deployment configs added to .gitignore.** `config/gateway.json` and
`config/aggregator.json` are per-device configs that should not be tracked. Only the
`.example.json` files are tracked.

**BUG-062 documented (not yet fixed).** `/api/status` reports PSRAM-inclusive heap on S3.
Fix planned for pre-v7.5.5.2 infrastructure commit.

**Files modified:**
- `scripts/sensor_manifest_lib.py` — lazy yaml import (BUG-060)
- `scripts/render_sensor_config.py` — ThermoPro indent fix
- `partitions/esp32-s3-multi-partitions.csv` — ota_0 at 0x10000 (BUG-061)
- `prompts/phase6/v7.5.6.0-*`, `v7.5.6.2-*` — header repair
- `.gitignore` — deployment config exclusions

---
## Infrastructure — Multi-Board Support — 2026-03-23

### No version bump — build infrastructure only (PR #66)

**Board profile system.** Three board profiles in `firmware/boards/`:
`esp32-c3-supermini.yaml`, `esp32-s3-devkitc1-n16r8.yaml`, `esp32-wroom-32d.yaml`.
Each defines chip variant, flash size, PSRAM, sdkconfig, and partition table path.

**Gateway config (`config/gateway.json`).** Optional per-device deployment config.
Specifies board selection, ESPHome name, WiFi address, friendly name. When absent,
the generator uses C3 defaults (full backward compatibility).

**`generate_board_yaml()` in `render_sensor_config.py`.** Generates complete ESPHome
YAML from scratch for non-C3 boards, incorporating board profile settings, aggregator
task, ping adapter, diagnostics, sorting groups, and text sensors.

**Zero-sensor support.** Empty `sensors` array produces valid YAML without BLE tracker
or ThermoPro blocks. `NUM_DEVICES=0` compiles correctly.

**New partition tables.** `esp32-s3-multi-partitions.csv` (4MB history, 3MB OTA slots)
and `esp32-wroom-multi-partitions.csv` (512KB history, same as C3).

**Preflight extended.** Board profile validation and gateway config validation when
optional files are present.

**Files added/modified:**
- `firmware/boards/*.yaml` — three board profiles
- `config/gateway.example.json` — example gateway config
- `partitions/esp32-s3-multi-partitions.csv`, `esp32-wroom-multi-partitions.csv`
- `scripts/sensor_manifest_lib.py` — `load_board_profile()`, `load_gateway_config()`, `validate_gateway_config()`
- `scripts/render_sensor_config.py` — `generate_board_yaml()`, gateway config loading
- `scripts/preflight.sh` — board/gateway validation
- `Docs/configuring-sensors.md` — multi-board deployment section

---
## v7.5.5.1 — Aggregator Polling Task — 2026-03-22

### Phase 5 Step 1 — Firmware only, no dashboard changes

**Aggregator polling task implemented.**
Added `SatelliteCache` struct (inside `#if AGGREGATOR_ENABLED`), one per configured satellite.
Each cache holds statically-allocated buffers for `/api/manifest` (4096 bytes),
`/api/v2/live` (2048 bytes), and `/api/status` (512 bytes) responses.

**Thread safety: FreeRTOS mutex protects shared cache.**
`s_cache_mutex` (created by `init_aggregator_mutex()`) guards all reads and writes to
`SatelliteCache` buffers. Torn-read prevention: network I/O writes into `s_fetch_tmp`
(a static 4 KB temp buffer) without holding the mutex; the completed result is copied
under the mutex in a brief critical section. This ensures web handlers (v7.5.5.2) can
never read a partially-written buffer.

**`aggregator_poll_task()` — background RTOS task.**
Polls each satellite sequentially:
- `/api/v2/live` every `poll_interval_seconds` (default 30 s)
- `/api/status` every `poll_interval_seconds`
- `/api/manifest` every 5 minutes (cached aggressively)

Satellites are staggered (2 s gap) to avoid simultaneous connections.
After 3 consecutive fetch failures a satellite is marked unreachable.
The task runs at `tskIDLE_PRIORITY + 2` with a 10 s initial delay for WiFi/boot settle.

**`start_aggregator_task()` — called from `on_boot` lambda.**
Creates the mutex, then spawns `aggregator_poll_task` with a 10 KB stack.

**ESPHome YAML updated.**
New `on_boot:` block at priority 600 conditionally calls `start_aggregator_task()`
under `#if AGGREGATOR_ENABLED`. Satellite builds (no `config/aggregator.json`) are
completely unaffected — `AGGREGATOR_ENABLED 0` compiles out the entire block.

**Files modified:**
- `dashboard/sensor_history_multi.h` — aggregator struct, mutex, task, start function
- `firmware/esp32-c3-multi-sensor.yaml` — on_boot lambda for aggregator task start
- `dashboard/dashboard.js`, `dashboard/dashboard.h` — version bump only
- `src/gateway_manifest.h`, test fixtures — version bump only
- `VERSION` → `7.5.5.1`

---
## v7.5.5.0 — Aggregator Configuration Schema and Loader — 2026-03-21

### Phase 5 Step 0 — No runtime changes

**Aggregator configuration schema defined.**
Added `config/aggregator.example.json` with the aggregator role schema: `schema_version`,
`role`, `gateway_id`, `gateway_name`, and `satellites[]` (each with `id`, `name`,
`base_url`, `poll_interval_seconds`).

**Live aggregator config added for development.**
`config/aggregator.json` created from the example with `base_url` pointing to actual
satellite IP (`http://192.168.120.189`). Required so v7.5.5.1 polling task can immediately
test against a real satellite without extra setup.

**`sensor_manifest_lib.py` extended.**
Added `validate_aggregator_config()` and `load_aggregator_config()`. Validation enforces:
- `schema_version` must be 1
- `role` must be `"aggregator"`
- At least 1 satellite, max 10
- Unique satellite IDs and `base_url` values
- `base_url` must start with `http://` or `https://`
- `poll_interval_seconds` must be 10–300

**`render_sensor_config.py` generates `src/aggregator_config.h`.**
Conditionally generates the header in two modes:
- Aggregator mode (config/aggregator.json present): `AGGREGATOR_ENABLED 1`, `MAX_SATELLITES N`,
  satellite ID/name/URL/poll arrays as C string literals.
- Satellite mode (no aggregator.json): `AGGREGATOR_ENABLED 0` only.
The file is always generated so `sensor_history_multi.h` can `#include` it unconditionally.

**`sensor_history_multi.h` includes `aggregator_config.h`.**
Added `#include "aggregator_config.h"` after `#include "gateway_manifest.h"`.
No runtime behavior changes — existing satellite firmware is completely unaffected.

**`scripts/preflight.sh` extended.**
New aggregator checks:
- `aggregator_config_h_included` — sensor_history_multi.h includes the header
- `aggregator_config_h_has_define` — AGGREGATOR_ENABLED define present
- If aggregator.json exists: validates schema, checks AGGREGATOR_ENABLED 1
- If absent: checks AGGREGATOR_ENABLED 0

### Files changed
- `config/aggregator.example.json` — new
- `config/aggregator.json` — new (live dev config)
- `scripts/sensor_manifest_lib.py` — added aggregator validation functions
- `scripts/render_sensor_config.py` — aggregator config header generation
- `src/aggregator_config.h` — generated header (aggregator mode enabled)
- `dashboard/sensor_history_multi.h` — added #include "aggregator_config.h"
- `scripts/preflight.sh` — aggregator validation checks
- `firmware/esp32-c3-multi-sensor.yaml` — added `../src/aggregator_config.h` to includes list
- `Docs/changelog.md` — this entry
- `prompts/prompt-index-and-workflow.md` — v7.5.5.0 marked complete

### Lessons learned
- **LESSON-OPS-067**: New generated headers must also be added to the ESPHome YAML `includes:` list.
  The `#include` directive alone is insufficient — ESPHome only copies listed files to its build directory.
  Discovered when CI failed after the first commit; fixed in the second commit.

---
## v7.5.4.5 — Post-Phase-4 Review Fixes — 2026-03-21

### Bug fixes

**BUG-052: `/sensors.json` v1 projection included non-environmental devices.**
The legacy endpoint returned all 4 devices including `wan_ping`. Architecture plan
Section 5.3 specifies environmental-only. Fixed: `handle_manifest_()` now filters
to `category_id == 0`.

**BUG-053: `/api/status` output ThermoPro-specific fields for all devices.**
`temp_valid` and `hum_valid` were emitted for `wan_ping` (always `false`,
meaningless). Fixed: added `category` field per sensor, `temp_valid`/`hum_valid`
only emitted for environmental devices.

**BUG-054: Calendar date picker dark/light mode styling.**
Dark mode: native browser date picker rendered white because `color-scheme:dark`
was missing from date inputs and selects. Light mode: date inputs and buttons
had hardcoded dark backgrounds. Fixed with `color-scheme` property and
`:root.light` CSS overrides for modal elements.

**BUG-056: WAN Latency ping data plotted on Temperature/Humidity charts.**
Multi-layer failure: `mkDS()` created chart datasets for all sensors including network,
`applyHistoryRange()` used SENSORS array index as dataset index, `fetchDeviceHistory()`
fallback fetched ping data via legacy `/history/wan_ping/temp` path, firmware's legacy
handler returned ping HistoryBuffer data as if it were temperature. Fixed with `chartIdx`
mapping (environmental-only), category skip in `loadHistory()`, and firmware 404 for
non-environmental devices on legacy history paths.

**BUG-055: `bump-version.sh` produces stale `dashboard.h` when `dashboard.min.html` exists.**
`generate-header.sh` auto-selects `.min.html` but `bump-version.sh` never re-minified it.
Fixed: bump script now re-runs `minify-dashboard.sh` if the tool is available, or removes
the stale `.min.html` so `generate-header.sh` falls back to the updated source.

### Files changed

- `dashboard/dashboard.html` — calendar CSS, chart category filtering (`chartIdx`, `mkDS`, `applyHistoryRange`, `handleState`, `loadHistory`)
- `dashboard/dashboard.js` — chart category filtering mirrored from dashboard.html
- `dashboard/sensor_history_multi.h` — `handle_manifest_()` environmental filter, `handle_status_()` category field, `handle_history_()` 404 for non-environmental legacy paths
- `scripts/bump-version.sh` — re-minify or remove stale `.min.html` before `generate-header.sh`
- `Docs/changelog.md` — this entry
- `Docs/bugs-and-lessons-learned.md` — BUG-052 through BUG-056, LESSON-OPS-064 through LESSON-OPS-066
- `Docs/session-log-2026-03-21-v7.5.4.5-post-phase4-fixes.md` — session log

---
## v7.5.4.4 — Phase 4 Closure — 2026-03-20

### Phase 4 Complete ✅

Phase 4 validates the generalized SensorEntity architecture by successfully adding a
non-climate sensor category (network/ping probe) to the gateway.

### Phase 4 summary

| Step | Scope |
|------|-------|
| v7.5.4.0 | Add ping device to manifest and generator (BUG-045 fix) |
| v7.5.4.1 | Implement ICMP ping adapter |
| v7.5.4.2 | Add network card renderer to dashboard |
| v7.5.4.3 | Mixed-category test fixtures and Playwright tests |
| v7.5.4.4 | Phase 4 closure (this step) |

### Architecture validation result

The Phase 1–3 abstraction held: adding a ping probe required one manifest entry, one
RTOS task, one card renderer, and zero changes to the core data model or persistence
engine. Environmental cards and ThermoPro history are completely unchanged.

### Test coverage

- Root baseline: 98 tests (Chromium: pass, Firefox: pass) + 7 skipped (Group 18 — mixed-only)
- Mixed-category: 94 tests (Chromium: pass, Firefox: pass) + 11 skipped (3sensor-specific tests)
- Preflight: all checks pass

### Files changed

- `Docs/v7.5-v7.6-architecture-plan.md` — Phase 4 COMPLETE status section added
- `Docs/changelog.md` — this entry
- `Docs/bugs-and-lessons-learned.md` — last-updated line reflects Phase 4 closure
- `prompts/prompt-index-and-workflow.md` — v7.5.4.4 marked complete
- Version bump: ALL locations to `7.5.4.4`

---
## v7.5.4.3 — Phase 4 Step 3: Mixed-Category Test Fixtures and Playwright Group 18 — 2026-03-20

### Mixed fixture variant (`tests/fixtures/variants/mixed/`)

Adds a `mixed` fixture variant representing the real-world mixed-category gateway configuration:
2 ThermoPro BLE environmental sensors + 1 `wan_ping` ICMP network device = 3 sensors total.

**New fixture files (10):**
- `manifest.json` — v2 manifest, `sensor_count: 3`, 2 environmental + 1 network device
- `sensors.json` — v1 legacy projection (environmental sensors only, for backward compat)
- `api-status.json` — gateway status, `mode: "mixed"`
- `storage-stats.json` — 512 KB partition, `mode: "mixed"`
- `history-office-temp.csv`, `history-office-hum.csv` — 96 data points (15-min intervals)
- `history-first_floor-temp.csv`, `history-first_floor-hum.csv` — 96 data points
- `history-wan_ping-ping_ms.csv` — 12 data points, latency 5–50 ms (realistic)
- `history-wan_ping-success_pct.csv` — 12 data points, success rate 95–100%

### Fixture generator update (`tests/fixtures/generate-fixtures.js`)

- Version bumped to `v7.5.4.3`
- Added `buildPingCsvLines(metricKey, pointCount)` — generates realistic ping history CSVs
- Added `generateMixedFixtures()` — produces the `mixed` variant (2 env + 1 network)
- `main()` now calls `generateMixedFixtures()` alongside the 1–4sensor variants

### Mock server update (`tests/mock-server/server.js`)

- `/api/v2/live`: `icmp_ping` devices now return realistic non-null values
  (`ping_ms: 12.5, success_pct: 100.0`) instead of `null` — required for live-value assertions

### Playwright tests — Group 18: Mixed-Category Rendering

Added `test.describe('18. Mixed-Category Rendering', ...)` in `tests/browser/dashboard.spec.js`
(7 new tests):

1. `mixed manifest renders correct total card count` — hardcoded 3 sensor cards
2. `environmental cards have full ThermoPro layout elements` — hardcoded 2 env cards and 2 Temperature labels
3. `network card renders with latency and success rate elements` — exactly 1 `.network-card`, `#net-ping-wan_ping` and `#net-success-wan_ping` visible
4. `CARD_RENDERERS dispatches correctly by category` — `CARD_RENDERERS.network` is a function
5. `chart canvases exist for environmental devices` — `#tempChart` visible
6. `/api/v2/live returns data for both device categories` — `devices.office` and `devices.wan_ping.ping_ms` defined
7. `manifest v2 contains both environmental and network devices` — `_manifest.sensors` categories contain both

All 7 tests use `{ expectedSensorCount: 3 }` (not `{ timeout: T }`), hardcoded integer counts
in `toHaveCount()`, and are guarded with `test.beforeEach` to skip when `FIXTURE_SET !== 'mixed'`.

### CI matrix update (`.github/workflows/browser-tests.yml`)

- Added `mixed` to the `fixture_set` matrix
- New step: `Run mixed-category suite (mixed — Group 18)` — runs only Group 18 with `FIXTURE_SET=mixed`
- Sensor-count smoke step updated: excludes `mixed` (only runs for `1sensor`, `2sensor`, `4sensor`)

### Bug fixed

- **BUG-050**: Group 18 CI failure (`expectedSensorCount: 3` vs `3sensor` fixture's 4 sensors).
  Root cause: fixture-specific tests must skip under non-matching fixture sets.
  See `Docs/bugs-and-lessons-learned.md` BUG-050 and LESSON-OPS-063.

### Test results

| Run | Result |
|-----|--------|
| `FIXTURE_SET=3sensor npx playwright test --project=chromium` | 98 passed, 7 skipped (Group 18) |
| `FIXTURE_SET=3sensor npx playwright test --project=firefox` | 98 passed, 7 skipped (Group 18) |
| `FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium` | 7 passed |
| `FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=firefox` | 7 passed |

---
## v7.5.4.2 — Phase 4 Step 2: Add Network Card Renderer to Dashboard — 2026-03-19

### Network card renderer

Adds `CARD_RENDERERS.network` to the dashboard to render the WAN ping probe as a network card.
The `wan_ping` device now appears alongside the three ThermoPro environmental cards in the sensor
grid. Environmental cards are pixel-identical to pre-Phase-4 — zero regression.

**SENSORS filtering expanded** (`normalizeManifestSensors()`):
- Removed `environmental`-only filter — all device categories are now included in SENSORS
- Enables category-aware routing in `applySensorMeta()` and `buildDeviceCards()`

**`makeNetworkSensorConfig(meta, idx)` (new)**:
- Category-aware sensor config factory for non-ThermoPro devices
- Produces `{ id, name, color, category: 'network', restPaths: [] }` — no ThermoPro entity IDs
- Reused for both `network` and `system` categories

**`applySensorMeta()` (updated)**:
- Now dispatches by category: `network`/`system` → `makeNetworkSensorConfig()`, else → `makeSensorConfig()` (ThermoPro path)

**`buildNetworkCard(s, manifest)` (new)**:
- Renders `<div class="sensor-card network-card" data-device-id="...">` with:
  - Color picker header (`#picker-{id}`)
  - Latency display (`#net-ping-{id}`, styled in sensor color)
  - Success rate display (`#net-success-{id}`)
  - Target host display (`#net-target-{id}`, read from `manifest.sensors[i].source.target`)
  - Last-seen timestamp (`#net-lastseen-{id}`)
- No chart canvas (chart support is a later step per architecture plan)

**`CARD_RENDERERS.network` (new)**: Registered in the card renderer registry

**`METRIC_FORMATTERS.ping_latency` and `success_rate` (new)**:
- `ping_latency(value, unit)` → `"N ms"` (or `"—"` for null/NaN)
- `success_rate(value)` → `"N%"` (or `"—"` for null/NaN)

**`updateNetworkCards(liveData)` (new)**:
- Reads from `/api/v2/live` response, updates `#net-ping-{id}`, `#net-success-{id}`, `#net-lastseen-{id}`
- Filters to `s.category === 'network'` sensors only

**`pollV2Live()` (new)**:
- Periodic `/api/v2/live` fetch (15 s interval) with in-flight guard (`_v2LiveInFlight`)
- Network devices do not appear in SSE state events — polling is the correct data path
- Started in boot flow after cards are built: `setInterval(pollV2Live, 15000); pollV2Live()`

**Network card CSS** (`dashboard.html`):
```css
.network-card { border-left: 3px solid var(--accent-network, #4FC3F7); }
.network-card .sensor-card-header { border-bottom-color: var(--accent-network, #4FC3F7); }
```

### Test updates

- **Group 2**: "three sensor cards are rendered" → "four sensor cards are rendered (3 environmental + 1 network)"; `each sensor card contains value display elements` scoped to `.sensor-card:not(.network-card)`
- **Group 11**: `environmental renderer dispatches correctly` count 3 → 4
- **Group 14**: scenario 1 count 3 → 4; scenario 4 updated for 4-sensor SENSORS (network included)
- **Group 15 test 6**: count 3 → 4
- **`manifest.spec.js`**: `waitForDashboardReady(page, 4)` + sensors array includes `wan_ping`
- **`sensor-count.spec.js`**: `getManifest()` updated to use `/api/manifest` v2 (includes all device categories)
- **Group 17 (new)**: 8 tests for Phase 4 network card renderer
  - Network card renders from manifest
  - `#net-ping-wan_ping` and `#net-success-wan_ping` elements present
  - `#net-target-wan_ping` shows target from manifest
  - Environmental cards structurally identical (`.sensor-card:not(.network-card)`)
  - `CARD_RENDERERS.network` is registered and callable
  - `METRIC_FORMATTERS.ping_latency` / `success_rate` registered and correct
  - `makeNetworkSensorConfig()` produces correct config (no ThermoPro entity IDs)
  - SENSORS includes `wan_ping` with length 4
  - `updateNetworkCards()` populates DOM values from live data

### Files changed

- `dashboard/dashboard.js` — `makeNetworkSensorConfig()`, `applySensorMeta()` dispatch, `normalizeManifestSensors()` filter removal, `METRIC_FORMATTERS.ping_latency/success_rate`, `CARD_RENDERERS.network`, `buildNetworkCard()`, `updateNetworkCards()`, `pollV2Live()`, `App.Render.buildNetworkCard` export, boot-flow `pollV2Live` start, version bump
- `dashboard/dashboard.html` — mirrored all JS changes (LESSON-OPS-043), network card CSS added, version bump
- `dashboard/dashboard.h` — regenerated (gzip)
- `tests/browser/dashboard.spec.js` — updated Groups 2, 11, 14, 15; added Group 17
- `tests/browser/manifest.spec.js` — updated `waitForDashboardReady` count 3→4, expected sensors include `wan_ping`
- `tests/browser/sensor-count.spec.js` — `getManifest()` uses `/api/manifest` v2 endpoint
- `tests/fixtures/manifest.json` — version bump (regenerated)
- `tests/fixtures/api-status.json` — version bump (regenerated)
- `src/gateway_manifest.h` — version bump (regenerated)
- `firmware/esp32-c3-multi-sensor.yaml` — version bump (regenerated)
- `dashboard/sensor_history_multi.h` — version bump (regenerated)
- `scripts/render_sensor_config.py` — version bump
- `VERSION` — `7.5.4.2`

### Test results

- 98 Playwright tests pass on Chromium (was 88 × 2 = 176 total; 10 new tests × 2 browsers = 196 total)
- 98 Playwright tests pass on Firefox
- `bash scripts/preflight.sh` — all checks pass

---
## v7.5.4.1 — Phase 4 Step 1: Implement ICMP Ping Adapter — 2026-03-19

### ICMP ping adapter (PingAdapter class)

Adds a periodic ICMP ping probe that feeds real latency data into the `wan_ping` SensorEntity
introduced in v7.5.4.0. The adapter runs as a low-priority FreeRTOS task and is safe for the
single-core ESP32-C3.

**PingAdapter class** (`dashboard/sensor_history_multi.h`, before `HistoryWebHandler`):
- FreeRTOS task at `tskIDLE_PRIORITY + 1`, stack 4096 bytes — lowest non-idle priority
- Pings the configured target every 60 seconds (3 probes, 200 ms spacing ≈ 600 ms/cycle)
- Uses ESP-IDF `ping/ping_sock.h` API (callback-based, async-safe with semaphore sync)
- Computes average RTT (ms) from successful pings and success rate (%) per cycle
- Calls `devices[PING_DEVICE_INDEX].add_sample(0, avg_rtt)` and `add_sample(1, success_pct)`
- Calls `devices[PING_DEVICE_INDEX].mark_seen(::time(nullptr))`
- WiFi-down: skips cycle, logs warning, delays 60 s, retries
- DNS failure: marks `metric_states[0/1].valid = false`, delays 60 s, retries
- All-pings-timeout: sets `ping_ms` invalid (NAN, valid=false), `success_pct = 0.0`
- Guarded by `#ifdef PING_DEVICE_INDEX` — compiled out if no ping device in manifest

**Generator changes** (`scripts/render_sensor_config.py`):
- `render_entity_block()` now emits `#define PING_DEVICE_INDEX N` and
  `#define PING_TARGET "..."` (from `source.target`) after `NUM_SENSORS`, for the first
  `icmp_ping` device in the manifest
- `render_yaml_averaging()` accepts new `all_sensors` parameter; adds
  `devices[N].compute_averages(epoch)` for each `icmp_ping` device in the 15-minute
  averaging interval lambda — **required** for history ring buffer to accumulate data

**YAML changes** (`firmware/esp32-c3-multi-sensor.yaml`):
- `on_boot:` converted from a single mapping to a YAML list with two entries at different priorities
- `priority: -100` entry: `register_history_handler` + `dashboard_link` (unchanged behaviour)
- `priority: 600` entry (new, after WiFi): a generator-managed lambda containing a
  `// <<< SENSOR_MANIFEST:PING_BOOT_BEGIN/END >>>` marker block that emits
  `static PingAdapter ping_adapter; ping_adapter.start(PING_DEVICE_INDEX, PING_TARGET);`
  inside `#ifdef PING_DEVICE_INDEX`

**New includes** (added to `sensor_history_multi.h`):
- `<freertos/semphr.h>` — FreeRTOS binary semaphore for ping callback sync
- `<esp_wifi.h>` — WiFi connection state check
- `<lwip/ip_addr.h>` — LWIP `ip_addr_t`
- `<lwip/netdb.h>` — `lwip_getaddrinfo()` / `lwip_freeaddrinfo()`
- `<ping/ping_sock.h>` — ESP-IDF ping API

### Files changed

- `dashboard/sensor_history_multi.h` — added includes, `PingAdapter` class, version bump
- `firmware/esp32-c3-multi-sensor.yaml` — version bump, `on_boot:` restructured as list with priority -100 (history handler) + priority 600 (PingAdapter, after WiFi), PING_BOOT marker block
- `scripts/render_sensor_config.py` — `render_entity_block()` + `render_yaml_averaging()` + `render_yaml_ping_boot()` added; `YAML_PING_BOOT_BEGIN/END` markers; version bump
- `dashboard/dashboard.js` — version bump (regenerated)
- `dashboard/dashboard.h` — regenerated (gzip)
- `tests/fixtures/manifest.json` — regenerated (version field)
- `tests/fixtures/api-status.json` — regenerated (version field)
- `src/gateway_manifest.h` — regenerated (version field)
- `Docs/changelog.md` — this entry
- `prompts/prompt-index-and-workflow.md` — v7.5.4.1 marked complete

---
## v7.5.4.0 — Phase 4 Step 0: Add Ping Probe Device to Manifest and Generator — 2026-03-18

### NVS snapshot recovery fix (BUG-048 — 2026-03-19)

After the BUG-046 meta migration fix (PR #53), the dashboard loaded history but only showed ~36
data points (approximately 9 hours of post-fix data). Full retained history was missing.

**Root cause:** `SegmentSnapshot` blobs written during the `NUM_SENSORS=4` period have a physically
different byte size than the corrected `NUM_SENSORS=3` struct. `nvs_get_blob()` returns
`ESP_ERR_NVS_INVALID_LENGTH` when the stored blob is larger than the buffer — the data is never
read. The restore loop silently skipped all incompatible segments but never recalibrated the meta
to reflect the reduced valid segment count.

**Fix:**
- `load_snapshot_from_handle_()`: diagnostic logging for `ESP_ERR_NVS_INVALID_LENGTH`
- `restore_from_nvs()`: after restore loop, recalibrate `meta.valid_segments` to match only
  successfully restored segments when size/schema mismatches are detected; persist recalibrated
  meta back to NVS

### Firefox Playwright test fix (BUG-049 — 2026-03-19)

Two Firefox-only failures in Group 13 (Manifest-driven history fetching) fixed.

**Root cause:** Firefox holds SSE EventSource TCP connections open during `browserContext.close()`
if callbacks aren't nulled before `.close()`. Group 13 used default 15s timeout insufficient for
Firefox's slower boot sequence.

**Fix:**
- `stopDashboardNetwork()`: null out `onopen/onerror/onmessage` before `evtSource.close()`
- `suspendDashboardNetworkActivity()` in `dashboard.js` + `dashboard.html`: same pattern
- Group 13: `test.setTimeout(90000)`, `loadDashboard({ timeout: 30000 })`

### Persistence compatibility fix (BUG-045)

The original v7.5.4.0 merge contained a regression: `NUM_SENSORS = NUM_DEVICES` caused the
persisted environmental history schema to change from 3 to 4 when `wan_ping` was added. This
violated the Phase 4 requirement that flash persistence remain unchanged for environmental devices.

**Root cause:** `render_entity_block()` aliased `NUM_SENSORS = NUM_DEVICES`. Because persistence
structs (`HistoryMeta`, `SegmentSnapshotHeader`, `SegmentSnapshot`) key off `NUM_SENSORS`, any
previously saved 3-sensor ThermoPro history would fail schema validation (`meta->num_sensors ==
NUM_SENSORS` evaluates `3 == 4`), causing the firmware to reset retained history on every boot.

**Fix:**
- `scripts/render_sensor_config.py` — `render_entity_block()` now generates a separate
  `NUM_ENV_SENSORS` constant (count of environmental/ThermoPro devices) and makes
  `NUM_SENSORS = NUM_ENV_SENSORS`. `render_header_block()` updated with clarifying comments.
- `dashboard/sensor_history_multi.h` — regenerated: `NUM_DEVICES = 4`, `NUM_ENV_SENSORS = 3`,
  `NUM_SENSORS = NUM_ENV_SENSORS`. `devices[]` still contains 4 entries including `wan_ping`.
  All persistence structs continue to key off `NUM_SENSORS` (unchanged). Static comment updated.
- `scripts/preflight.sh` — 3 new BUG-045 regression guards added: `num_env_sensors_constant_present`,
  `num_sensors_aliases_env_sensors`, `num_sensors_not_aliased_to_num_devices`.

**Result:** Runtime devices = 4 (unchanged). Persisted environmental schema = 3 (unchanged).
`wan_ping` remains RAM-only. Retained ThermoPro history is schema-compatible after flashing.

### Phase 4 begins: First non-climate sensor category (network / ping probe)

This step adds a `wan_ping` device to the data model and manifest. The ping device exists in the
C++ SensorEntity model and is included in the v2 manifest but produces no data at runtime — the
ICMP adapter is added in v7.5.4.1.

### Changes

- **`config/sensors.json` upgraded to v2 schema** — Added `schema_version: 2`, `category`, and
  `adapter` fields to all sensors. The three ThermoPro sensors are `category: environmental`,
  `adapter: thermopro_ble`. New `wan_ping` device: `category: network`, `adapter: icmp_ping`,
  `source: { target: "8.8.8.8" }`.

- **`scripts/sensor_manifest_lib.py` — v2 schema support** — `canonicalize_sensors()` now:
  - Validates `category` (environmental / network / system)
  - Requires `mac` only for `thermopro_ble` adapter
  - Requires `source.target` for `icmp_ping` adapter
  - Skips name→slug check for non-BLE adapters (e.g. `wan_ping` ≠ slug of "WAN Latency")
  - `fixture_manifest()` filters to environmental sensors only (legacy `/sensors.json`)
  - `manifest_v2()` generates per-adapter measurement entries (ping_ms / success_pct for network)

- **`scripts/render_sensor_config.py` — mixed-category generation** — `render_entity_block()`
  now produces a separate `metrics_ping[]` MetricDef array and a `SensorEntity` for the ping
  device (`category_id = 2`, `metric_count = 2`, RAM-only history buffers). YAML rendering
  functions receive only ThermoPro sensors (filtered internally). `render_js_block()` generates
  `DEFAULT_SENSOR_META` for environmental sensors only.

- **`dashboard/sensor_history_multi.h` — regenerated** — `NUM_DEVICES = 4` (3 ThermoPro + 1
  ping). `metrics_ping[]` added. `entity_hbuf_wan_ping_ping_ms` and
  `entity_hbuf_wan_ping_success_pct` HistoryBuffer instances added. `devices[3]` = wan_ping
  SensorEntity with RAM-only history, `category_id = 2`, `adapter = "icmp_ping"`.

- **`src/gateway_manifest.h` — regenerated** — v2 manifest JSON includes `wan_ping` with
  `category: network`, `adapter: icmp_ping`, `source: { target: "8.8.8.8" }`.

- **`dashboard/dashboard.js` + `dashboard.html` — SENSORS filter** — `normalizeManifestSensors()`
  now filters out non-environmental devices from the `SENSORS` array. Network/system devices are
  present in `window._manifest` but not rendered as cards until their respective phase card
  renderer is added (v7.5.4.2 for network).

- **`tests/fixtures/generate-fixtures.js` — mixed-category manifest** — `fixtureManifestV2()`
  generates category-appropriate sensor entries (ThermoPro: temp/hum; ping: ping_ms/success_pct).
  `fixtureManifestV1()` / `sensors.json` filtered to environmental only. Stub history CSV files
  created for `wan_ping` (empty, RAM-only).

- **`tests/mock-server/server.js` — category-aware `/api/v2/live`** — ThermoPro sensors get
  `{temp, hum, batt, rssi, last_seen}`. Ping device gets `{ping_ms: null, success_pct: null,
  last_seen: 0}`.

- **`scripts/preflight.sh`** — Added `manifest_has_network_device` check: when `sensors.json`
  is v2 schema, validates at least one `category: network` device is present. Updated
  `fixture_manifest_sensor_count` to 4.

- **Test updates** — 4 existing tests updated to support mixed-category manifest (sensor count,
  sensors array, Phase 3 metric-key check, Phase 2 environmental renderer check).

### Acceptance criteria met

- [x] `config/sensors.json` upgraded to v2 with 3 ThermoPro + 1 ping device
- [x] Generator produces `SensorEntity devices[4]` with correct metric arrays
- [x] Manifest fixture includes `wan_ping` device with `category: network`
- [x] All existing Playwright tests pass (88 / 88 on Chromium)
- [x] Version is `7.5.4.0` everywhere

**Device testing required:** compile + flash to verify ping device in `/api/manifest` and
`/api/v2/live` (null values expected).

---
## BUG-044: Implement BUG-043 Regression Guards + Multi-Browser Playwright Suite — 2026-03-18

Post-Phase-3 codebase audit discovered that two BUG-043 instruction documents specified concrete deliverables (5 preflight checks, 8 browser regression tests) but none of the specified code was ever written (BUG-044 — LESSON-OPS-057). This entry covers the full implementation, plus multi-browser expansion and prompt template improvements.

### Preflight enhancements (5 new checks)

| Check | Guards against | Lesson |
|-------|---------------|--------|
| `no_streaming_history_response` | `beginResponseStream` with `text/plain` in history handler | LESSON-OPS-056 |
| `nvs_yield_present` | NVS scan loops missing yield calls (3+ required) | LESSON-OPS-053 |
| `inflight_guard__statusInFlight` | Missing in-flight guard on status fetch | LESSON-OPS-050 |
| `inflight_guard__storageStatsInFlight` | Missing in-flight guard on storage stats fetch | LESSON-OPS-050 |
| `inflight_guard__historyInFlight` | Missing in-flight guard on history fetch | LESSON-OPS-050 |
| `generate_header_uses_gzip` | Build pipeline missing gzip compression | LESSON-OPS-055 |

### Browser regression tests (Group 16: BUG-043 Request Scheduling)

8 new Playwright tests catching JavaScript request-scheduling regressions:

1. Boot fetches `/api/manifest` exactly once (no duplicate)
2. History fetches are sequential (max 1 concurrent)
3. `loadHistory` in-flight guard prevents double invocation
4. History in-flight guard resets after failure (allows retry)
5. SSE ping/onopen handlers do not trigger `/api/status` fetches
6. No `/favicon.ico` request from dashboard (inline favicon)
7. Manifest is first HTTP request at boot (ordering)
8. `loadStorageStats` in-flight guard prevents concurrent calls

Mock server: 50ms delay added to history endpoints to make concurrency observable.

### Multi-browser Playwright suite

- **Playwright config expanded** to 3 browser engines: Chromium, Firefox, WebKit (Safari)
- **Parallel execution enabled** (`fullyParallel: true`) — workers default to half CPU cores
- Edge excluded (shares Chromium's Blink engine, zero additional coverage)
- Total test runs: 88 tests × 3 browsers = **264 test executions per suite run**
- Firefox catches Gecko-specific issues (prior BUG-014 `crossorigin` on CDN scripts)
- WebKit catches Safari rendering quirks and stricter JS API behavior

### Prompt and documentation improvements

- **Phase 4/5 prompt templates** (11 files) rewritten with full device testing workflows: pull → compile → flash → verify → report (LESSON-OPS-058)
- **Prompt index** (`phase3-prompt-templates-updated.md`) updated: Phase 3 marked complete, BUG-044 tracked, Phase 4 next
- **2 new bugs/lessons** — BUG-044, LESSON-OPS-057 (track specs to completion), LESSON-OPS-058 (device testing must include full workflow)

### Superseded documents (safe to delete)

The following instruction documents are now fully implemented and no longer needed:
- `Docs/BUG-043-preflight-enhancement-instructions.md` — all 5 checks implemented in `scripts/preflight.sh`
- `Docs/BUG-043-browser-test-implementation-instructions.md` — all 8 tests implemented in Group 16 of `tests/browser/dashboard.spec.js`

### Test count: 88 per browser (264 total across Chromium + Firefox + WebKit)

**Related:** BUG-043, BUG-044, LESSON-OPS-050–058

---
## v7.5.3.9 — Phase 3 Complete: Playwright Regression + Closure — 2026-03-18

### 🎉 Phase 3 Complete

Phase 3 (C++ SensorEntity Model) is now fully complete. The `SensorSlot` struct has been replaced by the generalized `SensorEntity` + `MetricDef` + `MetricState` model. All API endpoints, persistence, dashboard rendering, and history work identically to pre-Phase 3 behavior. The new internal model is extensible and ready for Phase 4 (first non-climate sensor category).

### Changes

- **New Playwright Group 15 tests** — 7 new tests validating Phase 3 v2 API endpoints:
  1. `/api/v2/live` returns valid JSON with all device IDs from manifest
  2. `/api/v2/live` returns metric keys matching manifest metric definitions
  3. `/api/v2/history/{device}/{metric}` returns CSV data
  4. Legacy `/history/{id}/temp` still works (backward compat)
  5. Legacy `/sensors.json` still works (backward compat)
  6. Dashboard renders identically with new endpoints
  7. `/api/v2/history` returns 404 for unknown device
- **Mock server updated** — Added `/api/v2/live` and `/api/v2/history/:device/:metric` routes to `tests/mock-server/server.js` for test coverage.
- **Architecture plan updated** — `Docs/v7.5-v7.6-architecture-plan.md` Phase 3 status marked COMPLETE.
- **Version bump** — All canonical locations updated to `7.5.3.9`.
- **Total test count: 80** (73 existing + 7 new Group 15 tests — all passing).

### Phase 3 Summary (v7.5.3.0–v7.5.3.9)

| Step | Description |
|------|------------|
| v7.5.3.0 | Pre-Phase 3 cleanup, schema decision, bump-version.sh fix |
| v7.5.3.1 | Define SensorEntity, MetricDef, MetricState C++ structs |
| v7.5.3.2 | Extend render_sensor_config.py with entity block generation |
| v7.5.3.3 | Wire YAML lambdas to dual-write (SensorSlot + SensorEntity) |
| v7.5.3.4 | Add /api/manifest endpoint |
| v7.5.3.5 | Dashboard stability fixes (BUG-043 continued) |
| v7.5.3.6 | Add /api/v2/live endpoint from SensorEntity |
| v7.5.3.7 | Add /api/v2/history/{device}/{metric} endpoint (RAM-only) |
| v7.5.3.8 | Remove SensorSlot, switch all paths to SensorEntity |
| v7.5.3.9 | Full Playwright regression + Phase 3 closure (this step) |

**Related:** Phase 3 implementation plan, v7.5-v7.6 architecture plan

---
## v7.5.3.8 — Remove SensorSlot, Switch All Paths to SensorEntity — 2026-03-18

**Phase 3 milestone — THE BIG SWITCHOVER:** `SensorSlot` struct and `sensors[]` array are removed. All runtime paths now use `SensorEntity devices[]`. Dual-write removed from YAML lambdas. Persistence shims bridge `SensorEntity` ↔ `SegmentSnapshot` for NVS write and boot restore.

### Changes

- **Removed `SensorSlot` struct** — The legacy per-sensor struct (`SensorSlot`) with `add_temp()`, `add_hum()`, `compute_and_format()`, `set_battery()` and inline `HistoryBuffer` fields is removed. All state now lives in `SensorEntity`.
- **Enhanced `SensorEntity`** — Added `compute_and_format()` method (computes averages, formats temp/hum strings, inserts gaps), `set_battery()`, and formatted output fields (`temp_avg_str`, `hum_avg_str`, `batt_str`, `temp_valid`, `hum_valid`, `batt_last`).
- **Removed dual-write from YAML lambdas** — BLE `on_value` callbacks now call only `devices[i].add_sample()` and `devices[i].mark_seen()`. No more `sensors[i].add_temp()` / `sensors[i].add_hum()`.
- **Updated 15-minute timer** — Now calls `devices[i].compute_and_format(epoch)` and publishes from `devices[i].temp_avg_str` / `devices[i].hum_avg_str` / `devices[i].batt_str`.
- **Persistence shims** — `build_segment_snapshot_()` reads from `devices[i].metric_states[0/1].history`; `append_snapshot_to_ram_()` writes to `devices[i].metric_states[0/1].history`. `SegmentSnapshot` format is UNCHANGED.
- **All API handlers updated** — `/sensors.json`, `/api/status`, `/history/{id}/{metric}`, import/export handlers all read from `devices[]`.
- **`NUM_SENSORS` aliased to `NUM_DEVICES`** — `static constexpr int NUM_SENSORS = NUM_DEVICES;` preserves backward compatibility for `SegmentSnapshot`, `HistoryMeta`, and NVS key naming.
- **`render_sensor_config.py` updated** — Generates only `SensorEntity devices[]` in ENTITY_BEGIN block. HEADER_BEGIN block now contains only a backward-compat comment. YAML lambda templates reference `devices[]` exclusively.
- **Version bump** — All canonical locations updated to `7.5.3.8`.

### Risk & testing notes

This is the highest-risk step in Phase 3. All persistence, restore, import, export, and API handler paths are affected. Comprehensive device testing is required per the v7.5.3.8 implementation instructions.

**Related:** Phase 3 implementation plan (v7.5.3.8 section)

---
## v7.5.3.7 — Add `/api/v2/history/{device}/{metric}` Endpoint (RAM-only) — 2026-03-18

**Phase 3 milestone:** New `/api/v2/history/{device_id}/{metric_key}` endpoint reads from `SensorEntity` history buffers (RAM ring buffer only — no NVS reads).

### Changes

- **New endpoint `GET /api/v2/history/{device_id}/{metric_key}`** — Returns CSV (`epoch,value\n`) from the SensorEntity's `metric_states[].history` HistoryBuffer. RAM-only: contains only post-boot data. Full NVS integration comes in v7.5.3.8.
- **URL parsing** — Extracts `device_id` and `metric_key` from path after `/api/v2/history/`. Returns 404 for unknown device, unknown metric, or metrics with `history_enabled == false`.
- **Pre-reserved string pattern (LESSON-OPS-056)** — Uses `std::string` with `reserve()` and zero-copy `beginResponse()` instead of `beginResponseStream`, establishing the correct pattern for NVS integration.
- **Route registration** — Added to `canHandle()` and `handleRequest()` in `HistoryWebHandler`.
- **Preflight check** — Added `history_handler_has_api_v2_history_route` to `scripts/preflight.sh`.
- **Version bump** — All canonical locations updated to `7.5.3.7`.

### Response format

Same `epoch,value\n` CSV format as legacy `/history/{id}/{metric}` endpoints:
```
1710260000,23.40
1710263600,23.20
```

**Key difference from legacy:** The legacy `/history/{id}/temp` reads NVS + RAM (up to 1080 blob reads). The v2 endpoint reads RAM ring buffer ONLY. During dual-write, both should produce identical data for the post-boot window.

**Related:** Phase 3 implementation plan (v7.5.3.7 section), LESSON-OPS-056

---
## v7.5.3.6 — Add `/api/v2/live` Endpoint from SensorEntity — 2026-03-18

**Phase 3 milestone:** New `/api/v2/live` endpoint reads current values from `SensorEntity devices[]` (populated via dual-write since v7.5.3.3).

### Changes

- **New endpoint `GET /api/v2/live`** — Returns JSON with current values for all devices and metrics from `SensorEntity.metric_states[]`. Invalid metrics return `null`. Includes per-device `last_seen` epoch.
- **Route registration** — Added to `canHandle()` and `handleRequest()` in `HistoryWebHandler`.
- **Preflight check** — Added `history_handler_has_api_v2_live_route` to `scripts/preflight.sh`.
- **Version bump** — All canonical locations updated to `7.5.3.6`.

### Response format

```json
{"timestamp":1710264000,"devices":{"office":{"temp":23.4,"hum":45.2,"batt":87.0,"rssi":-62.0,"last_seen":1710263985},...}}
```

**Related:** Phase 3 implementation plan (v7.5.3.6 section)

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
