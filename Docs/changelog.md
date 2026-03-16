# Changelog

All notable changes to the ESP32-C3 Multi-Sensor BLE Gateway.

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
