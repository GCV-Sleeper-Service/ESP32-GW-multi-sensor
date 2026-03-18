# Bugs Fixed & Lessons Learned

_Last updated: 2026-03-18 — BUG-045 mixed-category persistence regression, LESSON-OPS-059 added_

This file tracks significant bugs, root causes, fixes, and operational lessons.
It is also the place where project guardrails are recorded so they are not re-learned in later sessions.

Both sections are in **reverse chronological order** — most recent entry first.

## Bug Fixes

### BUG-045 — Mixed-category device count accidentally changed persisted history schema (2026-03-18)

**Date:** 2026-03-18 (discovered post-flash via ESPHome logs)
**Version observed:** v7.5.4.0
**Status:** FIXED

**Symptom:** After flashing v7.5.4.0 firmware, ESPHome output repeatedly logged:

```
[W][history:672][httpd]: history meta invalid or schema mismatch — resetting
```

All history cards on the dashboard showed no data. Previously retained ThermoPro temperature and
humidity history was silently discarded on every boot.

**Root cause:** `scripts/render_sensor_config.py` `render_entity_block()` aliased
`NUM_SENSORS = NUM_DEVICES`. Adding the RAM-only `wan_ping` network device increased
`NUM_DEVICES` from 3 to 4, which propagated to `NUM_SENSORS`. The persistence validation code
in `sensor_history_multi.h` checks `meta->num_sensors == NUM_SENSORS` (and likewise for
`SegmentSnapshotHeader`). A retained 3-sensor schema would fail `3 == 4`, triggering a full
history reset on every boot.

**Fix:**
- In `render_entity_block()`, generate a separate `NUM_ENV_SENSORS` constant equal to the count
  of environmental (ThermoPro/BLE) devices, and alias `NUM_SENSORS = NUM_ENV_SENSORS` instead
  of `NUM_DEVICES`. This keeps persisted schema 3-wide regardless of how many RAM-only devices
  are added.
- Update `render_header_block()` comments to clearly distinguish `NUM_DEVICES` (all runtime
  devices) from `NUM_SENSORS` (persisted environmental count).
- Update the static comment in `sensor_history_multi.h` to reflect the corrected aliasing.
- Add 3 preflight regression guards to `scripts/preflight.sh`:
  - `num_env_sensors_constant_present` — generated header must contain `NUM_ENV_SENSORS =`
  - `num_sensors_aliases_env_sensors` — `NUM_SENSORS` must alias `NUM_ENV_SENSORS`
  - `num_sensors_not_aliased_to_num_devices` — `NUM_SENSORS = NUM_DEVICES` must not appear

**Prevention:** LESSON-OPS-059 (see below). Preflight guards prevent this class of regression.

Related: LESSON-OPS-059

---

### BUG-044 — BUG-043 preflight enhancements and browser regression tests specified but never implemented (2026-03-18)

**Date:** 2026-03-18 (discovered during post-Phase-3 codebase audit)
**Version observed:** v7.5.3.9
**Status:** FIXED

**Symptom:** Two instruction documents existed — `Docs/BUG-043-preflight-enhancement-instructions.md` (5 preflight checks) and `Docs/BUG-043-browser-test-implementation-instructions.md` (8 browser regression tests) — but neither was implemented. The codebase had zero of the specified checks or tests.

**Root cause:** The documents were created as part of BUG-043 resolution planning but the implementation work was never scheduled as a tracked step. The Phase 3 implementation plan (v7.5.3.4/v7.5.3.5) addressed the BUG-043 firmware and dashboard fixes but did not include these supplementary test/check deliverables as gated steps.

**Fix:**
- Added 5 preflight checks to `scripts/preflight.sh`: `no_streaming_history_response`, `nvs_yield_present`, `inflight_guard_{_statusInFlight,_storageStatsInFlight,_historyInFlight}`, `generate_header_uses_gzip`
- Added 8 browser regression tests as Group 16 in `tests/browser/dashboard.spec.js`: manifest dedup, history sequential fetch, loadHistory in-flight guard, guard reset after failure, SSE ping/onopen no-status-fetch, no favicon.ico, manifest-first boot order, loadStorageStats guard
- Added 50ms delay to mock server history endpoints to make concurrency observable in Playwright

**Prevention:**
- Specified implementations must be tracked in a step index with explicit "Status: Pending/Complete" tracking (LESSON-OPS-057)
- Post-phase audits should verify that all referenced instruction documents have corresponding implementations

Related: BUG-043, LESSON-OPS-057

---

### Fix (final — gzip dashboard + pre-reserved history response)

Post-PR#41 device validation showed the ESP32-C3 still crashed on dashboard open and F5 despite all request scheduling fixes. Two firmware-level root causes:

**RC-GZIP: 190KB uncompressed dashboard HTML blocked HTTP task 2–4s per page load.**
Every `GET /dashboard.html` transferred 194,533 bytes of raw HTML. On the single-core ESP32-C3, this monopolized the HTTP server task, starving BLE/WiFi/API and causing watchdog resets.

**Fix:** Gzip-compress dashboard in build pipeline (194KB → 45KB, 77% reduction). Serve with `Content-Encoding: gzip`. Added inline favicon (`<link rel="icon" href="data:,">`) to eliminate browser `/favicon.ico` request.

**RC-HEAPALLOC: `beginResponseStream` reallocation cascade in `handle_history_()` caused heap exhaustion.**
With 336 NVS segments, the response string grew through 128→256→…→16K→32K via `resp->print()`. At the 16K→32K transition, both old (16K) and new (32K) buffers exist simultaneously = 48KB. With SSE/polling holding ~12KB of buffers, total exceeded available ~60KB free heap.

**Fix:** Pre-reserved `std::string` with `csv.reserve(estimated_bytes)` — single allocation, zero reallocations. Sent via zero-copy `beginResponse(200, type, data, len)` instead of `beginResponseStream`. Added string-based CSV builders `append_csv_to()` and `append_snapshot_series_csv_()`. Increased NVS yield from 1ms/4-reads to 5ms/2-reads.

### Updated Prevention rules

Add to the existing Prevention section:
- **Gzip-compress all large embedded responses** — the ESP32-C3 HTTP task blocks proportionally to response size. Any response >50KB should be gzip-compressed at build time (LESSON-OPS-055)
- **Never use `beginResponseStream` for responses that grow beyond ~10KB** — the std::string reallocation doubles peak heap temporarily. Use pre-reserved `std::string` + zero-copy `beginResponse(200, type, data, len)` instead (LESSON-OPS-056)
- **Preflight must guard dashboard.h size** — a size threshold check catches accidental regression to uncompressed format (LESSON-OPS-055)

Related: LESSON-OPS-055, LESSON-OPS-056

---

## BUG-043 — Dashboard request fanout / polling destabilizes ESP32-C3 (CONFIRMED)

**Date:** 2026-03-16 / continued 2026-03-17 / firmware fix 2026-03-17 / dashboard hardening 2026-03-17
**Version observed:** `v7.5.3.3` post-merge validation; crash persists through `v7.5.3.4`, partial mitigation in `v7.5.3.5`
**Status:** FIXED — firmware NVS yield (PR #40) + dashboard hardening (PR2, this PR). Post-merge device validation still required.
**Remediation:** `Docs/dashboard-stability-remediation-plan.md`, `Docs/BUG-043-continued-fix-plan.md`
**Fix PRs:** PRs #36–#38 (v7.5.3.3-hotfix); v7.5.3.5 (PR #39); firmware NVS yield (PR #40); dashboard hardening (this PR)

### Symptom (continued, post-hotfix)
Despite the v7.5.3.3-hotfix implementing all 8 remediation steps, the ESP32-C3 still crashed when the dashboard was opened in SSE or polling mode:

- **SSE mode**: Dashboard loads ~1 minute then crashes during history loading. Device logs show a 2-second component blocking warning followed by API disconnect.
- **Polling mode**: Initial crash on open, then stabilization with oscillating heap (53K–73K).
- **F5 refresh** after 3 min uptime crashes again.
- **Untouched**: Device runs stable at 72.1 KB free heap — confirms crash is dashboard-triggered.
- **No `httpd_accept_conn: error in accept (23)`** — socket exhaustion (the original root cause) is fixed; new root causes identified below.

### Continued root causes (v7.5.3.5)

#### RC1: Concurrent temp+hum history fetches block the HTTP server task (PRIMARY)
`fetchDeviceHistory()` used `Promise.all` for all history measurements. Each `/history/{id}/temp` or `/history/{id}/hum` request triggers a **synchronous NVS scan loop** in `sensor_history_multi.h` that reads up to 1080 NVS blobs without yielding. With `Promise.all`, both requests fire simultaneously, doubling the blocking window to 1–4 seconds. During that window, BLE scanning, WiFi, the ESPHome API, and the task watchdog are all starved.

#### RC2: Double manifest fetch at boot
`loadManifestV2()` fetches `/api/manifest`, then `loadSensorManifest()` fetches it again. 2 redundant HTTP requests during the most constrained startup window. Introduced in v7.5.2.0 when `loadManifestV2()` was added alongside `loadSensorManifest()` without consolidating them.

#### RC3: Polling mode initial burst fires 33+ paths immediately
`startPolling()` fired `pollAll(POLL_DEVICE.concat(livePaths))` with no initial defer, concurrent with `loadStatusSnapshot()` — 5 concurrent connections in the first 120ms.

#### RC4: No in-flight guard on loadHistory()
Unlike `loadStatusSnapshot()` and `loadStorageStats()` (which got in-flight guards in the hotfix), `loadHistory()` had no guard — rapid close/reopen or F5 during boot could run two history chains in parallel.

#### RC5: History bootstrap timer too short (5s)
Storage stats deferred to t+3s and the initial poll taking ~3.5s total meant history could start before both completed.

### Original root causes (v7.5.3.3-hotfix)
The dashboard JavaScript overwhelmed the ESP32-C3 HTTP server through six independent issues:

1. **SSE `ping` handler fires `loadStatusSnapshot()` on every ping** — 10-20+ redundant `/api/status` requests per minute.
2. **SSE `onopen` handler fires `loadStatusSnapshot()`** — duplicate `/api/status` at boot.
3. **Double status polling in polling mode** — 15s interval + 30s interval firing simultaneously.
4. **No in-flight guard on `loadStatusSnapshot()`** — concurrent calls stack up when ESP is slow.
5. **No in-flight guard on `loadStorageStats()`** — same stacking, compounded by retry logic.
6. **Startup request burst with no staggering** — 8-12+ HTTP requests within ~2 seconds of boot.

**Combined effect (original):** Peak concurrent connections at boot: 8-12+. Caused `httpd_accept_conn: error in accept (23)` followed by panic/reboot.

### Fix (continued — v7.5.3.5)
See `Docs/BUG-043-continued-fix-plan.md`:
1. `fetchDeviceHistory()` now fetches metrics **sequentially** with 300ms gap (replaces `Promise.all`)
2. `loadHistory()` has `_historyInFlight` in-flight guard
3. `App.Boot.start()` reuses `window._manifest.sensors` — eliminates second `/api/manifest` fetch
4. `startPolling()` defers initial poll by 1s, uses batch size 2, handles `loadStatusSnapshot()` internally
5. History bootstrap timer increased from 5s to 8s
6. `no_concurrent_history_fetch` preflight check added

**Note:** v7.5.3.5 mitigated dashboard-side concurrency but did **not** eliminate firmware-side blocking. Even a single serialized history request can block the HTTP task long enough to starve BLE/WiFi/API/watchdog work when history is large. The firmware-side root cause is addressed in the split follow-up PR below.

### Fix (firmware root-cause — NVS yield)
Implements the "Future Work" item from `Docs/BUG-043-continued-fix-plan.md`. Split-PR strategy: firmware-only fix first, dashboard hardening in a separate follow-up PR.

1. Added `maybe_yield_nvs_scan_(int iteration)` static helper in `dashboard/sensor_history_multi.h`
   - Calls `vTaskDelay(pdMS_TO_TICKS(1))` every 4 NVS blob reads (`NVS_SCAN_YIELD_INTERVAL = 4`)
   - Gives FreeRTOS scheduler a timeslice between blob reads without per-blob overhead
2. Applied yield to **all three** long NVS iteration loops:
   - `restore_from_nvs()` — boot-time RAM restore (up to RAM_SEGMENTS blobs)
   - `build_import_epoch_map_()` — import epoch-map scan (up to PERSIST_SLOTS blobs)
   - `handle_history_()` — per-request history streaming loop (up to `meta.valid_segments` blobs, max 1080)
3. No dashboard JS changes in this PR — dashboard request-scheduling hardening is a separate follow-up PR

### Fix (dashboard hardening — PR2)
Completes BUG-043 resolution by fully serializing the startup request schedule:

1. **SSE startup**: `connectSSE()` fires first; `loadStatusSnapshot()` deferred 2s. SSE state events carry initial state; immediate status fetch was unnecessary overhead during the fragile SSE-open window.
2. **Polling startup**: Initial `pollAll` changed from batch=2/120ms to **batch=1/200ms** (fully sequential, one request at a time).
3. **History inter-sensor gap**: `loadHistory()` waits **500ms** between sensors instead of chaining immediately — lets ESP32-C3 complete BLE/WiFi work between NVS scan loops.
4. **Storage stats defer**: Deferred from 3s → 5s to avoid overlapping with the sequential poll still in flight.
5. **History bootstrap defer**: Deferred from 8s → 10s to ensure sequential poll and storage stats both complete before NVS-heavy history starts.
6. `startup_poll_sequential` preflight regression guard added.
7. `dashboard/dashboard.h` regenerated.

**Favicon/routing note**: `/favicon.ico` returns HTTP 500 on real devices despite correct 204 handling in `sensor_history_multi.h`. Root cause: ESPHome's `web_server` component registers its catch-all `AsyncWebHandler` during component `setup()` (before our `on_boot` lambda runs), so it intercepts `/favicon.ico` first and returns 500 for unrecognized routes. The fix requires changing when `register_history_handler()` is called (from `on_boot` to a hook that executes before ESPHome's web_server setup). This is a separate, larger change documented in LESSON-OPS-054.

### Fix (original — v7.5.3.3-hotfix)
See `Docs/dashboard-stability-remediation-plan.md`:
1. In-flight guard on `loadStatusSnapshot()`
2. In-flight guard on `loadStorageStats()`
3. Remove `loadStatusSnapshot()` from SSE `ping` handler
4. Remove `loadStatusSnapshot()` from SSE `onopen` handler
5. Make 30s `statusSnapshotIntervalId` conditional — polling mode only
6. Remove `loadStatusSnapshot()` from `startPolling()` 15s interval
7. Stagger startup requests over 5s
8. Increase storage stats interval to 120s

### Rule
When debugging real-device crashes involving the dashboard:
1. Isolate single-endpoint behavior from full dashboard behavior
2. Inspect the browser Network tab before blaming one route
3. Check for duplicate interval creation and startup request storms
4. Count concurrent connections at boot — must not exceed ~4
5. Check for blocking firmware operations triggered by HTTP requests (e.g., NVS scans)
6. **Even a single serialized history request can block the HTTP task** if the firmware loops over many NVS blobs without yielding — always add `vTaskDelay` in long NVS scan loops
7. **SSE mode**: connect the stream first, then defer non-critical status fetches — the stream open is the most fragile moment

### Prevention
- **In-flight guards are mandatory** on all interval-driven fetch functions (LESSON-OPS-050)
- **History fetches must be sequential** — never use `Promise.all` for history endpoints (LESSON-OPS-052)
- **Startup polling must be batch=1** — fully sequential initial poll is mandatory for ESP32-C3 stability (LESSON-OPS-054)
- Never fire HTTP requests from SSE event handlers (`ping`, `onopen`)
- Only one polling interval per endpoint category
- Stagger startup requests: SSE status 2s, storage stats 5s, history 10s
- **Real-device validation with dashboard open** required before merge (LESSON-OPS-051)
- **NVS scan loops must yield** — any loop over persisted segments must call `vTaskDelay(pdMS_TO_TICKS(1))` periodically (LESSON-OPS-053)
- **ESPHome handler ordering**: `HistoryWebHandler` must be registered before ESPHome's web_server handler or it will never be reached for routes the catch-all intercepts (LESSON-OPS-054)

Related: LESSON-OPS-050, LESSON-OPS-051, LESSON-OPS-052, LESSON-OPS-053, LESSON-OPS-054

---

### BUG-042: `dashboard/dashboard.h` version check fails due to minification (post-v7.5.2.0)

**Symptom:** PR #25 added `dashboard_h_version_matches` to `scripts/preflight.sh` and CI failed with `dashboard_h_version_matches: FAIL` even though `dashboard.js` and `dashboard.html` had the correct version string `App.version = 'v7.5.2.0'`.

**Root cause:** CI runs `minify-dashboard.sh` then `generate-header.sh` before `preflight.sh`. The minifier (terser) converts `App.version = 'v7.5.2.0'` to `App.version="v7.5.2.0"` (removes spaces, converts single quotes to double quotes). The original `dashboard_h_version_matches` check used `grep -Fq "App.version = '${VER_TAG}'"` (fixed-string with spaces and single quotes), which never matches the minified form in the regenerated `dashboard.h`. The committed `dashboard.h` had the unminified form but is discarded when CI regenerates it.

**Fix:** Changed `dashboard_h_version_matches` to use `grep -Eq` with a regex pattern `App\.version[[:space:]]*=[[:space:]]*['\"]${VER_TAG}['\"]` that matches both the unminified source form and the minified generated form. Added `check_contains_regex()` helper to `scripts/preflight.sh` for future regex-based checks.

**Lesson:** See LESSON-OPS-048.

---

### BUG-041: Fixture generator VERSION bumped independently from canonical VERSION file (v7.5.1.3)

**Symptom:** CI preflight failed with "Generated files are out of sync with config/sensors.json." The diff showed `manifest.json` containing `v7.5.1.3` while the Python generator (using VERSION from `render_sensor_config.py`) expected `v7.5.1.0`.

**Root cause:** PR #20 changed `tests/fixtures/generate-fixtures.js` VERSION from `v7.5.1.0` to `v7.5.1.3` and regenerated the fixture files with the new version string, but did not update the canonical VERSION sources (`VERSION` file, `render_sensor_config.py` VERSION constant). The Python generator (`render_sensor_config.py --check`) regenerates expected fixtures from the canonical VERSION and compares against on-disk fixtures — since JS fixtures said `v7.5.1.3` but Python expected `v7.5.1.0`, the check failed.

**Fix:** Bumped all version references atomically to `7.5.1.3`: `VERSION` file, `render_sensor_config.py` VERSION constant, `generate-fixtures.js` VERSION constant, `dashboard.js` App.version, `dashboard.html` App.version, `sensor_history_multi.h` header comment, YAML header comment, and `register_history_handler()` string. Regenerated all artifacts via `python3 scripts/render_sensor_config.py --write` and `bash scripts/generate-header.sh`. Added a preflight check (`fixture_generator_version_sync`) to catch future drift.

**Lesson:** See LESSON-OPS-047.

---

### BUG-040: No automated validation of manifest v2 schema (v7.5.1.1)

**Symptom:** Generator could produce malformed JSON or missing required fields without detection until runtime or manual inspection.

**Root cause:** Preflight only validated that `src/gateway_manifest.h` existed, was included, and that the generator sync check passed. It did not verify the content of the generated manifest against the v2 schema contract.

**Fix:** Added preflight checks that validate `gateway_manifest.h` contains all required v2 schema fields: top-level fields, `gateway` block fields, `history` block fields, `metrics` array fields, and that `schema_version` is exactly `2`.

**Lesson:** See LESSON-OPS-046.

---

### BUG-039: Dashboard source and generated artifacts drifted after Phase 1 work (v7.5.0.1)

**Symptom:** `dashboard.html` was updated during Phase 1 manifest work but `dashboard.min.html` and `dashboard.h` were not regenerated. The embedded firmware payload still ran stale client logic — manifest-first boot and `/api/status` hydration were absent from what actually flashed.

**Root cause:** The workflow assumed edits to `dashboard.html` would propagate automatically. They do not — the minification and header-embedding steps must be run explicitly after every source edit.

**Fix:** Patched `dashboard/dashboard.html` directly as the source of truth, then regenerated `dashboard.min.html` and `dashboard.h` from that corrected source. Kept `dashboard.js` aligned to the same runtime logic.

**Lesson:** See LESSON-OPS-043.

---

### BUG-038: Dashboard Free Heap and Uptime showed "loading…" after Phase 1 OTA (v7.5.0.1)

**Symptom:** After flashing Phase 1 firmware, `/api/manifest` and `/api/status` both responded correctly, but the dashboard displayed `loading...` indefinitely for Free Heap and Uptime.

**Root cause:** The dashboard still expected `/sensor/Free Heap` and `/sensor/Uptime` — legacy entity-polling paths that the firmware no longer provided as ESPHome entities. The authoritative data was already available from `GET /api/status` but the dashboard code was not reading from it.

**Fix:** Switched all dashboard device-status widget hydration to `GET /api/status`. Removed dependency on legacy entity-polling paths for those values.

**Lesson:** See LESSON-OPS-042.

---

### BUG-037: Built-in ESPHome diagnostics disappeared from the built-in web page after Phase 1 (v7.5.0.1)

**Symptom:** The ESPHome built-in web page no longer showed Free Heap, Uptime, or Loop Time after Phase 1 firmware changes.

**Root cause:** The `debug.free`, `debug.loop_time`, and `uptime` sensor blocks were removed or were missing from `firmware/esp32-c3-multi-sensor.yaml` during Phase 1 YAML changes.

**Fix:** Restored `debug.free`, `debug.loop_time`, and `uptime: type: seconds` blocks in the YAML. Confirmed both the custom dashboard and the built-in ESPHome page show all three diagnostics after reflash.

**Lesson:** See LESSON-OPS-044.

---

### BUG-036: YAML generator reintroduced broken indentation after hotfix — preflight passed but compile failed (v7.5.0.1)

**Symptom:** After the initial YAML indentation fix, running `python3 scripts/render_sensor_config.py --write` again silently reintroduced bad indentation into the YAML. `bash ./scripts/preflight.sh` passed. `esphome compile` failed near the averaging block with `expected <block end>`.

**Root cause:** The hotfix had corrected one call site but `render_yaml_file()` still routed some YAML marker regions through `replace_marker_block()` instead of `apply_yaml_marker_block()`. Those paths produced correct YAML body content but inserted it without preserving the indentation level from the marker location.

**Fix:** Switched all YAML marker replacements in `render_sensor_config.py` to `apply_yaml_marker_block()`. Confirmed idempotence by running `--write` twice.

**Lesson:** See LESSON-OPS-041.

---

### BUG-035: YAML generator produced invalid indentation in ESPHome block scalars (v7.5.0.0)

**Symptom:** `esphome compile firmware/esp32-c3-multi-sensor.yaml` failed immediately after `render_sensor_config.py --write` with `expected <block end>, but found '<scalar>'` near line 135.

**Root cause:** The YAML generation path reinserted block content without preserving the indentation level of the marker location. The content was semantically correct but structurally invalid YAML inside lambda block scalar sections, `web_server.sorting_groups`, `sensor`, and `text_sensor` blocks.

**Fix:** Routed all YAML marker replacements through `apply_yaml_marker_block()`, which captures the indentation column of the marker line and re-applies it to every inserted line.

**Lesson:** See LESSON-OPS-040.

---

### BUG-034: `render_sensor_config.py` crashed with `re.PatternError: bad escape \x` on generated content (v7.5.0.0)

**Symptom:** Running `python3 scripts/render_sensor_config.py --write` raised `re.PatternError: bad escape \x at position N` during the replacement phase for generated strings containing Unicode escape sequences like `\xC2\xB0` (the degree symbol).

**Root cause:** Generated replacement text was passed directly to `re.sub()` in string replacement mode. Python's `re.sub` interprets backslash sequences in the replacement string as regex back-references or escapes. `\xC2\xB0` was not a valid regex escape, causing the error.

**Fix:** Changed all `re.sub()` calls for generated content to use lambda/function replacements. In lambda mode, the replacement value is treated as a literal string, so backslash sequences in generated output are not interpreted.

**Lesson:** See LESSON-OPS-039.

---

### BUG-033: Phase 1 patch script failed against compacted one-line source blocks (v7.5.0.0)

**Symptom:** `scripts/apply_phase1_manifest_patch.py` failed repeatedly when targeting `dashboard/sensor_history_multi.h`. Exact-string matches could not find their targets, even when the content appeared visually correct.

**Root cause:** The header file uses compacted one-line formatting for several function bodies and handler blocks. Patch scripts that matched on long multi-line strings or comment text failed when those strings had been compacted into a single line.

**Fix:** Rewrote the patch approach to use function-anchor detection, regex-based matching, and brace-aware block insertion rather than exact long-string matching. Going forward, this is a known constraint of the codebase.

**Lesson:** See LESSON-OPS-039.

---

### BUG-032: Multi-sensor CLI restore could erase retained history without an explicit confirmation prompt (v7.4.5.1)

The first v7.4.5.0 CLI backup/restore helper correctly routed merged CSVs through the existing erase-first `/api/import/begin` path, but it did so without an explicit operator confirmation.

**Fix:** `scripts/history_backup.py import` now prompts before erase-first multi-sensor import unless `--yes` is provided, and it also supports `--single-sensor <id>` to intentionally force the merge route from a merged CSV.

---

### BUG-031: `change_sensor_number.py` rollback messaging was too optimistic for structural renderer failures (v7.4.5.1)

The initial rollback path restored `config/sensors.json` and attempted a best-effort re-render, but it could still leave the operator uncertain if recovery was incomplete.

**Fix:** rollback now preserves the backup file on failure, prints manual recovery commands, and surfaces restore/re-render errors explicitly instead of assuming a clean rollback.

---

### BUG-030: Manifest validation normalized MACs by mutating caller data in place (v7.4.5.1)

The original validation helper silently normalized MAC addresses inside the caller-provided list.

**Fix:** manifest validation is now side-effect free. Canonicalization is explicit through `canonicalize_sensors()`, and save/load/render flows use normalized copies rather than mutating input objects.

---

### BUG-029: Session-level import design details were not propagated into the durable docs (v7.4.5.0)

**Symptom:** The repo behavior for single-sensor merge import existed in firmware and dashboard logic, but the high-value explanation — epoch-to-slot mapping, overlay of one sensor into an existing segment, reuse of the same slot when possible, and ~7 KB temporary overhead — was not consistently carried into changelog and handoff documentation.

**Root cause:** Documentation captured the user-visible feature but not enough of the internal design rationale.

**Fix:** Expanded changelog, `Docs/configuring-sensors.md`, and the per-session handoff to explicitly describe the merge-first single-sensor import model and how it differs from full multi-sensor replacement.

**Lesson:** See LESSON-OPS-036.

---

### BUG-028: Sensor-count changes depended on four-file manual edits, creating configuration drift risk (v7.4.5.0)

**Symptom:** Changing sensor count or replacing a sensor required hand-editing `sensor_history_multi.h`, the firmware YAML, `dashboard.js`, and `tests/fixtures/sensors.json`. It was easy to update three files and miss the fourth, which produced confusing preflight failures or worse — a compile-valid repo whose dashboard fallback / test fixtures no longer matched the active firmware configuration.

**Root cause:** The repo had no canonical source of truth for configured sensors. The same facts (sensor id, display name, MAC, count) were duplicated in multiple files.

**Fix:** Introduced a canonical manifest (`config/sensors.json`) plus a generator (`scripts/render_sensor_config.py`) and an interactive manager (`scripts/change_sensor_number.py`). The renderer now drives generated sections in the header, firmware YAML, dashboard fallback metadata, and baseline fixture manifest.

**Guardrail:** `scripts/preflight.sh` now runs `python3 scripts/render_sensor_config.py --check` so generated-file drift is caught before compile.

**Lesson:** See LESSON-OPS-037.

---

### BUG-027: Chromium missing shared libraries in ESPHome container — libnspr4.so not found (v7.4.4.0)

**Symptom:** All Playwright tests fail with `error while loading shared libraries: libnspr4.so: cannot open shared object file`. The binary exists and `--no-sandbox` is in the launch args, but the process crashes at the dynamic linker stage.

**Root cause:** `npx playwright install chromium` downloads the Chromium binary but does NOT install the required OS-level shared libraries. The ESPHome Docker container does not include them by default.

**Fix:** Use `npx playwright install --with-deps chromium`. This installs both the binary and all required system packages via `apt`.

**Lesson:** See LESSON-OPS-034.

---

### BUG-026: Chromium crashes silently in ESPHome/Docker containers — sandbox kernel feature missing (v7.4.4.0)

**Symptom:** All Playwright tests fail immediately with `browserType.launch: Target page, context or browser has been closed` — even after a successful install. The browser binary exists but the process crashes on startup.

**Root cause:** Chromium's default sandbox uses Linux user namespaces, which are disabled in many container environments including the ESPHome Docker container.

**Fix:** Add `launchOptions: { args: ['--no-sandbox', '--disable-setuid-sandbox'] }` to the `use` block in `playwright.config.js`.

**Lesson:** See LESSON-OPS-033.

---

### BUG-025: Fixture generate-fixtures.js used milliseconds for CSV timestamps (v7.4.4.0)

**Symptom:** Sensor-count variant fixtures would render completely empty charts. No error — just no data points.

**Root cause:** `Date.UTC()` returns epoch milliseconds. The dashboard's chart renderer calls `new Date(epoch * 1000)` — interpreting the value as seconds. A millisecond timestamp gets multiplied by 1000, producing dates in year ~58000, which fall outside any time range filter and are silently dropped.

**Fix:** Use epoch seconds throughout `generate-fixtures.js`. Anchor to `ANCHOR_EPOCH_SEC = 1741694400`.

**Lesson:** See LESSON-OPS-029.

---

### BUG-024: Second round of browser test failures — DOM behavior mismatches (v7.4.3.0 CI)

**Symptom:** 4 of 28 tests failed on second CI run after element ID fixes.

**Root causes — three distinct issues:**
1. Canvas selector wrong container — chart canvases live inside `.chart-card` divs, not `.sensor-card`
2. Theme class applied to `document.documentElement` (`<html>`), not `document.body`
3. `_onPreset()` calls `_applyAndClose()` directly — clicking Apply after a preset attempts to click an already-dismissed modal

**Fixes:** Assert named chart IDs with `toBeAttached()`; change theme assertions to `page.locator('html')`; remove the Apply click after preset.

**Lesson:** See LESSON-OPS-028.

---

### BUG-023: Output bundle file naming caused confusion about destination paths (v7.4.3.0)

**Fix:** Files renamed and placed in correct locations after clarification.

**Lesson:** See LESSON-OPS-025.

---

### BUG-022: `package-lock.json` not committed — CI failed on `npm ci` (v7.4.3.0)

**Symptom:** Browser CI job failed immediately: `Dependencies lock file is not found`.

**Fix:** `npm install` on device, then `git add package-lock.json && git commit`.

**Lesson:** See LESSON-OPS-024.

---

### BUG-021: `browser-tests.yml` committed to wrong branch — workflow never appeared in CI (v7.4.3.0)

**Symptom:** GitHub Actions showed no "Browser Tests" workflow.

**Root cause:** Workflow file was committed on the wrong feature branch. GitHub only registers workflow files from the default branch.

**Fix:** `git log --oneline --all -- .github/workflows/browser-tests.yml` identified the commit. `git checkout <sha> -- .github/workflows/browser-tests.yml` recovered and committed it to the correct branch.

**Lesson:** See LESSON-OPS-023.

---

### BUG-020: Browser test suite used wrong element IDs throughout — 14 of 28 tests failed (v7.4.3.0)

**Root cause:** Tests were written against assumed element IDs without verifying the actual dashboard HTML. Six distinct mismatches:

| Used in test | Actual ID in HTML |
|---|---|
| `#themeToggle` | `#themeBtn` |
| `#crApply` | `#customRangeApply` |
| `#crCancel` | `#customRangeCancel` |
| `.card-title` | `.sensor-card-header` |
| `data-history-range="7d"` | `data-history-range="168"` |
| `button[hasText=Export]` count | `[data-export-all]` + `[data-export-sensor]` attributes |

**Fix:** Audited all element IDs against the actual HTML before writing tests.

**Lesson:** See LESSON-OPS-022.

---

### BUG-019: "Data available: unknown" in custom range dialog on freshly-flashed device (v7.4.2.0)

**Fix:** Three-state availability display: both bounds non-zero → range shown; only newest non-zero → "up to [newest]"; both zero → "No persisted history yet."

---

### BUG-018: Duplicate `<script>` tag caused `Unexpected token '<'` dashboard failure (v7.4.2.0)

**Fix:** `sed -i '859d' dashboard/dashboard.html`. Prevention: use `head -n $((SCRIPT_LINE - 1))`, not `head -n $SCRIPT_LINE`. Verify with `grep -c '^<script>$' dashboard/dashboard.html` — must return `1`.

---

### BUG-017: `MAX_HISTORY_RANGE_HOURS` was 720, silently truncating 45d history display (v7.4.2.0)

**Fix:** `MAX_HISTORY_RANGE_HOURS = 1080`.

---

### BUG-016: `html-minifier-terser` CLI flags wrong (v7.4.1.0)

**Fix:** Use positional input plus `--output`.

---

### BUG-015: Single-sensor import "Unknown sensor ID" — off-by-one in URL path parsing (v7.4.0.2)

**Fix:** Corrected prefix length comparison and pointer offset. Prefer `sizeof("literal") - 1` over hand-counted lengths.

---

### BUG-014: Single-sensor import erased all flash data (v7.4.0.2)

**Fix:** Added `POST /api/import/begin/single/<id>` and merge-first behavior.

---

### BUG-013: Import over Cloudflare returned HTTP 502 (v7.4.0.1)

**Fix:** Suspend non-essential background activity during import and add pacing/backoff.

---

### BUG-012: Single-sensor export schema mismatch (v7.4.0.1)

**Fix:** Standardized on prefixed column headers for all export formats.

---

### BUG-011: Non-JSON server response crashed import error handling (v7.4.0)

**Fix:** Added safer text-first JSON response handling.

---

### BUG-010: `time()` ambiguous in ESPHome context (v7.4.0)

**Fix:** Use `::time(nullptr)`.

---

### BUG-009: Import POST body never delivered (v7.4.0)

**Fix:** Moved import payload transport into the URL path. **URL path is the reliable data channel** on this stack.

---

### Earlier important fixes

- **BUG-008:** Switched dashboard serving away from `beginResponseStream()` panic path
- **BUG-007:** Abandoned LittleFS-hosted dashboard in favor of embedded payload
- **BUG-006:** Fixed dashboard startup / event-binding ordering issue
- **BUG-005:** Theme switch now forces chart redraw
- **BUG-004:** 15-minute markers normalized to the intended visual size
- **BUG-003:** Chart markers now follow recolor changes
- **BUG-002:** Export All serialized to avoid socket-pool overload
- **BUG-001:** `/api/status` JSON truncation fixed by splitting output formatting

---

## Operational Lessons

### LESSON-OPS-059: Runtime device count and persisted-history count are different concepts in mixed-category firmware (2026-03-18)

**Date:** 2026-03-18

In mixed-category firmware (environmental BLE sensors + RAM-only network probes), the total
number of runtime `SensorEntity` devices (`NUM_DEVICES`) is not the same as the number of
devices whose history is written to flash (`NUM_SENSORS`). Aliasing `NUM_SENSORS = NUM_DEVICES`
appears harmless until a second device category is introduced — at that point the persisted
schema widens and all previously retained environmental history fails schema validation.

**Rule:** `NUM_SENSORS` (or any constant used to dimension flash-backed arrays) must always equal
the count of *environmentally persisted* devices only. A separate `NUM_ENV_SENSORS` constant
must be generated for this count. `NUM_SENSORS = NUM_ENV_SENSORS` must be the alias. Adding a
RAM-only device to the manifest must never silently widen the persisted schema.

**Preflight enforcement:** `scripts/preflight.sh` must contain:
- `num_env_sensors_constant_present` — `NUM_ENV_SENSORS =` present in generated header
- `num_sensors_aliases_env_sensors` — `NUM_SENSORS = NUM_ENV_SENSORS;` present in generated header
- `num_sensors_not_aliased_to_num_devices` — `NUM_SENSORS = NUM_DEVICES;` must **not** appear

Related: BUG-045

---

### LESSON-OPS-058: Prompt template device testing sections must include full local workflow (2026-03-18)

**Date:** 2026-03-18

Phase 3 prompt templates (e.g., v7.5.3.7) included device testing commands like `curl -s http://192.168.120.189/api/v2/history/office/temp` but did not include the prerequisite steps: pulling the repo, compiling, and flashing. An operator starting from scratch would not know the full workflow.

**Rule:** Every prompt's device testing section must include the complete sequence: (1) pull latest from main, (2) compile, (3) OTA flash, (4) verification commands, (5) expected output descriptions. Assume the operator is starting from a fresh terminal. Use the v7.5.3.7 instructions as the quality bar for detail level.

Related: BUG-044

---

### LESSON-OPS-057: Specified tests and checks must be tracked to implementation completion (2026-03-18)

**Date:** 2026-03-18

Two instruction documents (`BUG-043-preflight-enhancement-instructions.md` and `BUG-043-browser-test-implementation-instructions.md`) were written during BUG-043 resolution but never implemented. They fell through the cracks because they were not listed in the step index with explicit completion tracking.

**Rule:** Any instruction document that specifies code to be written must appear in a tracked step index (e.g., `phase3-prompt-templates-updated.md`) with a "Status: Pending/Complete" field. Untracked specifications become dead documents. Post-phase audits should verify all referenced instruction documents have corresponding implementations.

Related: BUG-044

---

### LESSON-OPS-056: Never use beginResponseStream for large HTTP responses on ESP32-C3

**Date:** 2026-03-17

`AsyncWebServer::beginResponseStream()` builds the response in an internal `std::string` that grows through repeated `print()` calls. Each `std::string` reallocation temporarily holds both old and new buffers. For a 24KB response (typical for 336 NVS segments × 4 points × 20 bytes/line), the growth from 16KB→32KB requires 48KB of simultaneous heap — nearly the entire free heap when SSE/polling connections are active.

**Rule:** Any HTTP response that could exceed ~10KB must use pre-reserved `std::string` with `csv.reserve(estimated_size)` followed by zero-copy `beginResponse(200, content_type, reinterpret_cast<const uint8_t*>(str.data()), str.size())`. This pattern makes a single heap allocation at the estimated final size, avoiding the reallocation cascade.

---

### LESSON-OPS-055: Gzip-compress large embedded responses; preflight must guard compressed format

**Date:** 2026-03-17

The ESP32-C3 HTTP server task blocks proportionally to response transfer size. The 190KB uncompressed `dashboard.html` blocked the task for 2–4 seconds per page load, starving BLE/WiFi/API/watchdog on the single-core device. Gzip compression (194KB → 45KB) reduced blocking to <1 second.

**Rules:**
1. `scripts/generate-header.sh` must gzip-compress the dashboard HTML and output a C `uint8_t[]` byte array (not a raw string literal)
2. `sensor_history_multi.h` must serve the dashboard with `Content-Encoding: gzip`
3. `scripts/preflight.sh` must verify: (a) `dashboard.h` contains `DASHBOARD_HTML_GZ` (gzip format), (b) does NOT contain `R"DASH64(` (raw literal), (c) file size is below 400KB threshold
4. `dashboard.html` must contain `<link rel="icon" href="data:,">` to prevent browser `/favicon.ico` requests (which return 500 due to ESPHome handler ordering)

---

### LESSON-OPS-054: Dashboard startup polling must be fully sequential (batch=1); ESPHome handler ordering affects custom routes (dashboard hardening PR2)

#### Part A: Startup polling must be fully sequential

The `pollAll()` function uses `Promise.all(batch.map(pollEntity))` to run each batch. With batch size > 1, multiple requests fire simultaneously. On the ESP32-C3, even 2 concurrent connections during the critical startup window (SSE open, fresh reboot, or F5) can trigger API disconnects or 502 errors.

**Rule:** The **initial poll in `startPolling()`** must always use `batchSize=1`. `Promise.all` with a single-element array is a sequential call, so this reuses the existing batching infrastructure without adding new code paths.

**Current values:**
- `pollAll(paths, 1, 200)` — initial startup poll, fully sequential, 200ms between requests
- `pollAll(livePaths)` — periodic live poll (uses default batch=4), which is acceptable for steady-state (device is stable and not in boot window)

**Preflight regression guard:** `scripts/preflight.sh` includes a `startup_poll_sequential` check that fails if `pollAll(POLL_DEVICE.concat(livePaths), 1` does not appear in both `dashboard.js` and `dashboard.html`.

#### Part B: ESPHome `AsyncWebHandler` registration order determines which handler answers a request

The `AsyncWebServer` (used by ESPHome's `web_server` component) iterates handlers in registration order and returns the first one where `canHandle()` returns `true`. ESPHome's built-in `web_server` (version 3) acts as a catch-all handler — its `canHandle()` returns `true` for any request it doesn't recognize, and its `handleRequest()` returns HTTP 500 for those routes.

The `HistoryWebHandler` is registered in an `on_boot` lambda (which runs after all component `setup()` calls). ESPHome's `web_server` component registers its handler during its own `setup()`. Therefore ESPHome's handler is at position 0 in the handler list and `HistoryWebHandler` is at position 1.

**Consequence:** For any route that ESPHome's handler intercepts (including `/favicon.ico`), `HistoryWebHandler::handleRequest()` is never called. Our `HistoryWebHandler` can only handle routes that ESPHome's handler does NOT claim.

**The observed symptom:** `/favicon.ico` returns HTTP 500 even though `HistoryWebHandler::canHandle()` returns `true` and `handleRequest()` would return 204 — ESPHome's catch-all gets there first.

**The fix (not yet implemented):** Change `register_history_handler()` to run before ESPHome's web_server setup — e.g., by creating a custom `esphome::Component` with a `setup_priority` that fires between `web_server_base::setup()` and `web_server::setup()`. This is a larger change requiring firmware/YAML modifications beyond the scope of this dashboard-hardening PR.

Related: BUG-043

---

### LESSON-OPS-053: NVS scan loops in firmware must yield to the FreeRTOS scheduler (firmware root-cause fix)

Any firmware loop that iterates over persisted NVS segment blobs (e.g., by calling `nvs_get_blob()` in a `for` loop) blocks the calling task for the full duration of the scan. On the ESP32-C3, this means the HTTP server task can block for 0.5–2 seconds (or more with large history), starving:

- BLE scanning / BLE task
- WiFi stack
- ESPHome API heartbeat (causes "unexpected disconnect" in ESPHome logs)
- FreeRTOS task watchdog (causes `component took a long time` warnings and eventually resets)

**Rule:** Any loop in `sensor_history_multi.h` (or any other firmware file) that reads more than a handful of NVS blobs must call `vTaskDelay(pdMS_TO_TICKS(1))` periodically to yield to the scheduler.

**Pattern to follow:**
```cpp
// In sensor_history_multi.h — apply to all NVS segment iteration loops.
static void maybe_yield_nvs_scan_(int iteration) {
  if (iteration > 0 && (iteration % NVS_SCAN_YIELD_INTERVAL == 0)) {
    vTaskDelay(pdMS_TO_TICKS(1));
  }
}

// Usage inside loop:
for (int n = 0; n < meta.valid_segments; n++) {
  maybe_yield_nvs_scan_(n);  // BUG-043: yield every 4 blobs
  int slot = ...;
  load_snapshot_from_handle_(handle, slot, snapshot);
  ...
}
```

The yield interval of 4 is a balance between low overhead and meaningful CPU relief. A 1ms yield every 4 blobs adds at most ~270ms of voluntary sleep over a 1080-blob scan, which is modest compared to the NVS read time itself.

This applies to **all** NVS iteration loops in the project, not just the three fixed in the BUG-043 follow-up:
- `restore_from_nvs()` — now fixed
- `build_import_epoch_map_()` — now fixed
- `handle_history_()` — now fixed
- Any future NVS iteration loop must follow the same pattern

Related: BUG-043

---

### LESSON-OPS-052: History endpoint NVS scan is a blocking operation — dashboard must never fetch history metrics concurrently (v7.5.3.5)

Each `/history/{id}/temp` or `/history/{id}/hum` request in the firmware (`sensor_history_multi.h`) triggers a **synchronous NVS scan loop** that reads up to 1080 NVS blobs without yielding to other tasks. This blocks the HTTP server task for 0.5–2 seconds per request.

Using `Promise.all` in `fetchDeviceHistory()` caused both temp and hum requests to fire simultaneously, doubling the blocking window to 1–4 seconds per sensor. During that window, BLE scanning, WiFi, the ESPHome API, and the FreeRTOS task watchdog are all starved — causing the crash.

**Mandatory rules for dashboard code:**
1. **`fetchDeviceHistory()` must fetch metrics sequentially**, never via `Promise.all`. Use a promise chain with a 300ms delay between each request to give the firmware breathing room.
2. **`loadHistory()` must have an in-flight guard** (`_historyInFlight`) to prevent concurrent history load chains from F5 refresh or button click during boot.
3. **History loading must be deferred long enough** for all other boot requests to complete first. The bootstrap timer must be ≥10s (sequential poll finishes ~t+8s, storage stats at t+5s, both must finish before history begins).
4. **Firmware fix (implemented):** `maybe_yield_nvs_scan_()` in `sensor_history_multi.h` calls `vTaskDelay(pdMS_TO_TICKS(1))` every 4 blob reads, yielding the CPU between batch reads. This eliminates the firmware root cause.
5. **Preflight enforces this rule:** `scripts/preflight.sh` includes a `no_concurrent_history_fetch` check that fails if `Promise.all(.*historyMeasurements` appears in either `dashboard.js` or `dashboard.html`.

Related: BUG-043

---

### LESSON-OPS-051: Dashboard code changes that affect network behavior require real-device validation with dashboard open (v7.5.3.3-hotfix)

Playwright tests validate rendering and data flow against a mock server with unlimited HTTP capacity. They do **NOT** validate HTTP connection pressure on a real ESP32-C3 (~4-7 concurrent connections). BUG-037 passed all 73 Playwright tests but crashed the real device within seconds of opening the dashboard.

**Rule:** Any dashboard change that modifies `setInterval()` / `setTimeout()` scheduling, `fetch()` call sites, SSE event handlers, boot sequence request ordering, or polling/refresh cadence **must** be validated on a real device with the dashboard open before the PR is merged.

**Real-device validation checklist:**
1. Open local dashboard — no crash for 5+ minutes
2. Close and reopen — no crash
3. Open remote dashboard (polling mode) — no crash for 3+ polling cycles
4. Check browser Network tab — no request storms or duplicate fetches
5. Check device logs — no `httpd_accept_conn: error in accept` warnings

Related: BUG-043

---

### LESSON-OPS-050: Dashboard HTTP request budgeting — ESP32-C3 has strict concurrent connection limits (v7.5.3.3-hotfix)

The ESP32-C3 HTTP server (ESP-IDF `httpd`) supports approximately 4-7 concurrent connections. Dashboard JavaScript must respect this constraint at all times.

**Rules for dashboard network code:**
1. **In-flight guards are mandatory** — every `fetch()` function that runs on an interval or event handler must have a module-level boolean guard preventing concurrent invocations. Pattern: set flag before fetch, clear in both `.then()` success and `.catch()` error paths.
2. **Never trigger HTTP fetches from SSE event handlers** — SSE `ping` and `onopen` should only update UI status indicators, never fire additional HTTP requests. SSE already delivers data via `state` events.
3. **Stagger startup requests** — boot sequence must not fire more than 2-3 concurrent requests. Use `setTimeout()` to spread non-critical fetches (storage stats, history) across 3-5 seconds.
4. **One polling interval per endpoint category** — never create two `setInterval()` calls that both invoke the same fetch function.
5. **Polling cadence should match data change rate** — storage stats change hourly (poll every 120s max), status changes every ~15 minutes (poll every 30s max).
6. **Verify with browser DevTools Network tab** — before any dashboard PR is merged, verify the request pattern. There should be no request storms, no duplicate concurrent fetches, and no unbounded request stacking.

Related: BUG-043

---

### LESSON-OPS-049: `dashboard.html` must be kept in sync with `dashboard.js` for all code changes — `bump-version.sh` now handles the version string automatically (v7.5.2.1/v7.5.2.2; **fixed in v7.5.3.0**)

`dashboard/dashboard.html` embeds all dashboard JavaScript inline (no `<script src>`). It is
the source of truth that `generate-header.sh` uses to produce `dashboard/dashboard.h` (the
embedded firmware payload). Prior to v7.5.3.0, `bump-version.sh` and `render_sensor_config.py --write`
only updated `dashboard/dashboard.js` — they did **not** touch `dashboard.html`.

**✅ Fixed in v7.5.3.0:** `bump-version.sh` now runs `sed -i "s/App\.version = 'v[0-9.]*'/..."` on
`dashboard/dashboard.html` immediately after updating `tests/fixtures/generate-fixtures.js`. The
`App.version` string is now updated atomically by the bump script.

**Remaining manual requirement:** Code changes to `App.Boot.start()` or any other JS logic in
`dashboard.js` must still be manually mirrored to `dashboard.html`. There is no automated tool that
propagates non-version JS edits from `dashboard.js` → `dashboard.html`. After any such edit:
1. Apply identical code changes to `dashboard/dashboard.html`.
2. Run `bash scripts/generate-header.sh` to regenerate `dashboard/dashboard.h`.
3. Confirm `bash scripts/preflight.sh` passes.

**Historical workaround (v7.5.2.x, no longer needed for version bumps):**
1. Run `bash scripts/bump-version.sh <new-version>` (will fail at preflight if dashboard.html is stale — that is expected).
2. Manually update `App.version` in `dashboard/dashboard.html` to the new version.
3. Apply the same code changes to `dashboard/dashboard.html` that were applied to `dashboard/dashboard.js`.
4. Run `bash scripts/generate-header.sh dashboard/dashboard.html dashboard/dashboard.h` (pass the html source explicitly to bypass the stale min.html).
5. Confirm `bash scripts/preflight.sh` passes.

---

### LESSON-OPS-048: Use `bump-version.sh` for all version bumps — never update version sources partially (post-v7.5.2.0)

Version drift occurs when the developer updates some canonical sources but misses others, or forgets to regenerate dependent artifacts. The version surfaces in at least eight places in this repo (VERSION, render_sensor_config.py, generate-fixtures.js, dashboard.html, dashboard.js, sensor_history_multi.h, firmware YAML, and the generated dashboard.h). Manually tracking all of them is error-prone.

**Rule:** Use `bash scripts/bump-version.sh <new-version>` for all version bumps. This script updates all four canonical sources atomically, runs `render_sensor_config.py --write` to regenerate all derived artifacts, runs `generate-header.sh` to regenerate `dashboard.h`, and then runs `preflight.sh` to verify sync. Do not manually edit individual version strings.

**Enforcement:** Preflight now includes `dashboard_h_version_matches` (detects missing `generate-header.sh`; uses regex to match both minified and non-minified forms) and `render_sensor_config_py_version_sync` (detects missing `render_sensor_config.py` VERSION update) in addition to the existing `fixture_generator_version_sync` and `render_sensor_config --check`.

**Version bump sources of truth (all updated by bump-version.sh):**
1. `VERSION` file (canonical root)
2. `scripts/render_sensor_config.py` VERSION constant
3. `tests/fixtures/generate-fixtures.js` VERSION constant
4. `dashboard/dashboard.html` App.version (**added in v7.5.3.0** — see LESSON-OPS-049)

**Derived artifacts (all regenerated by bump-version.sh):**
- `dashboard/dashboard.js` (App.version — via render_sensor_config.py --write)
- `dashboard/sensor_history_multi.h` (header comment — via render_sensor_config.py --write)
- `firmware/esp32-c3-multi-sensor.yaml` (header + register_history_handler — via render_sensor_config.py --write)
- `src/gateway_manifest.h` (firmware_version — via render_sensor_config.py --write)
- `tests/fixtures/manifest.json` and `api-status.json` (version fields — via render_sensor_config.py --write)
- `dashboard/dashboard.h` (embedded App.version — via generate-header.sh)

Related: BUG-042

---

### LESSON-OPS-047: Version strings in test fixture generators must match the canonical VERSION file (v7.5.1.3)

The fixture generator (`tests/fixtures/generate-fixtures.js`) embeds a VERSION constant that is stamped into generated fixture JSON files. The Python generator (`render_sensor_config.py --check`) independently derives the expected version from the canonical `VERSION` file and its own VERSION constant. If these two sources drift, the `--check` comparison will fail even though the generated fixture files are otherwise valid.

**Rule:** All version references must be bumped atomically in a single commit: `VERSION` file, `render_sensor_config.py` VERSION constant, `generate-fixtures.js` VERSION constant, `dashboard.js` App.version, `dashboard.html` App.version, `sensor_history_multi.h` header comments, YAML header comment, and `register_history_handler()` string. Never bump the fixture generator VERSION independently.

**Enforcement:** Preflight checks `fixture_generator_version_sync` that the VERSION extracted from `generate-fixtures.js` matches the canonical `VERSION` file. If they differ, preflight fails immediately.

Related: BUG-041

---

### LESSON-OPS-046: Generated artifacts with structured schemas need compile-time validation (v7.5.1.1)

For any generated file with a required schema (JSON, YAML, etc.), preflight must validate structure, not just existence. A generator bug or incomplete update can produce syntactically valid but semantically broken output — for example, a JSON file that parses correctly but is missing required fields. Existence checks and generator sync checks (`--check`) do not catch this class of failure.

Add field-level validation for every generated artifact that has a documented schema contract. This catches regressions early and prevents malformed output from reaching `main`.

Related: BUG-040

---

### LESSON-OPS-045: Preflight must include a YAML/ESPHome parse gate, not just generated-file sync checks (v7.5.0.1)

The existing preflight catches version drift and generator sync failures. It does not catch structurally invalid YAML that passes the sync check because the generator produced syntactically invalid output. Add a step that runs `esphome config firmware/esp32-c3-multi-sensor.yaml` (or equivalent YAML parse) to block bad YAML from reaching the compile stage.

Without this gate, a generator bug can produce invalid YAML that passes preflight, passes `--check`, and only fails at `esphome compile`. The gap between "preflight green" and "compile fails" wastes time and creates false confidence.

**Implementation**: v7.5.1.2 — preflight runs `esphome config firmware/esp32-c3-multi-sensor.yaml`

---

### LESSON-OPS-044: Runtime validation must cover both the custom dashboard and the built-in ESPHome web page (v7.5.0.1)

Dashboard-only runtime checks can mask regressions in the built-in ESPHome diagnostics page. After any YAML change, verify:
1. The custom dashboard loads correctly and all status fields hydrate
2. The ESPHome built-in web page at `/` shows Free Heap, Uptime, and Loop Time

These are served from different code paths. One can regress without the other showing symptoms.

---

### LESSON-OPS-043: `dashboard.html` is the source of truth — regenerate artifacts after every edit (v7.5.0.1)

Edit order must always be:
1. Edit `dashboard/dashboard.html` (source of truth)
2. Run `bash ./scripts/minify-dashboard.sh` → produces `dashboard.min.html`
3. Run `bash ./scripts/generate-header.sh dashboard/dashboard.min.html dashboard/dashboard.h`

Editing `dashboard.js` alone is not sufficient. The script block inside `dashboard.html` must also be updated, and both the minified intermediate and the embedded header must be regenerated. A preflight rule should verify that `dashboard.h` reflects the current state of `dashboard.html`.

---

### LESSON-OPS-042: Dashboard device-status widgets should hydrate from `GET /api/status`, not entity polling (v7.5.0.1)

Do not rely on `/sensor/<entity-name>` paths for dashboard status fields. The firmware already exposes authoritative status data — version, uptime, free heap, sensor validity, storage settings — from `GET /api/status`. Entity-polling paths are implementation details of ESPHome's built-in web interface and may not be stable across firmware changes.

---

### LESSON-OPS-041: YAML generator correctness requires both idempotent marker replacement and indentation preservation (v7.5.0.1)

YAML generation that passes content-only sync checks can still produce invalid YAML if indentation context is lost during marker replacement. Two properties must both hold:
1. Running `--write` twice produces no diff (idempotence)
2. Inserted block content inherits the indentation column of the marker line

`replace_marker_block()` satisfies (1) but not (2). Use `apply_yaml_marker_block()` for all YAML-targeted marker regions.

---

### LESSON-OPS-040: YAML generator must use indentation-aware insertion for all block scalar sections (v7.5.0.0)

When generating content for YAML files that contain block scalars (lambda bodies, sorting_groups, nested sensor blocks), the generator must preserve the indentation level of the target marker location. Content-correct YAML with wrong indentation is not valid YAML — ESPHome will reject it at parse time, not compile time.

---

### LESSON-OPS-039: Use lambda replacements in `re.sub()` when generated content may contain backslashes (v7.5.0.0)

Generated text that contains escape sequences like `\xC2\xB0`, `\n`, or `\t` is unsafe as a raw string argument to `re.sub()`. Use a lambda function as the replacement instead: `re.sub(pattern, lambda m: generated_text, source)`.

Also: do not use brittle exact-string patching against compacted one-line C++ source blocks. Use function-anchor detection, regex-based matching, or brace-aware insertion instead.

---

### LESSON-OPS-038: Safety prompts belong on destructive CLI paths, not only in prose documentation (v7.4.5.1)

Documenting that a path is destructive is not enough. If a CLI command can erase retained state, the operator should have to acknowledge that at runtime or opt into bypassing the prompt deliberately.

---

### LESSON-OPS-037: Design-level behavior needs to be documented, not just shipped (v7.4.5.0)

When a feature has a non-obvious internal model, preserve that model in durable documentation. The single-sensor import path is a good example: the useful fact is not only that it is "non-destructive," but *how* it works — epoch-to-slot scan, segment overlay, same-slot rewrite, new-slot allocation only for missing hours, and temporary memory overhead.

**Carry forward:** When a feature changes retained-history semantics, endpoint contract, or state-management design, record the internal mechanism in the changelog and session handoff, not only the user-facing label.

---

### LESSON-OPS-036: Repeated configuration belongs in one canonical manifest (v7.4.5.0)

If the same sensor facts appear in multiple repo files, manual editing will eventually drift. Move those facts into one canonical manifest and generate the dependent files from it.

**Carry forward:** `config/sensors.json` is the source of truth. Future sensor-related changes should flow through the manifest and renderer first.

---

### LESSON-OPS-035: Preflight checks that depend on npm packages must skip when node_modules is absent (v7.4.4.0)

The build CI (`ci.yml`) runs preflight before `npm ci` — `node_modules` does not exist at that point. Any preflight check that requires an npm package must guard with `[[ -d "node_modules/@playwright" ]]` and emit `SKIP` rather than `FAIL` when the guard is not met.

---

### LESSON-OPS-034: Always use --with-deps when installing Playwright in containers (v7.4.4.0)

`npx playwright install chromium` downloads the binary only. `npx playwright install --with-deps chromium` also installs the required OS shared libraries via apt. In any container or fresh Linux environment, always use `--with-deps`. See BUG-027.

---

### LESSON-OPS-033: Playwright in Docker/ESPHome containers requires --no-sandbox (v7.4.4.0)

Always add `launchOptions: { args: ['--no-sandbox', '--disable-setuid-sandbox'] }` to `playwright.config.js` when running in a container. The error `Target page, context or browser has been closed` immediately after browser launch is the signature of a sandbox crash. See BUG-026.

---

### LESSON-OPS-032: NVS count-mismatch protection is already in place — no new C++ guard needed (v7.4.4.0)

The `meta.num_sensors == NUM_SENSORS` check in the NVS restore path already rejects history segments from a different sensor count cleanly. The correct response to a count change is: load nothing from the old segments, require an explicit history delete, and document the procedure.

---

### LESSON-OPS-031: DEFAULT_SENSOR_META in dashboard.js is a required consistency target (v7.4.4.0)

The `DEFAULT_SENSOR_META` array in `dashboard.js` is a fallback used when `/sensors.json` fails to load. It must match `NUM_SENSORS`. Preflight checks this explicitly.

---

### LESSON-OPS-030: Preflight sensor-count checks belong in Node.js, not bash regex (v7.4.4.0)

Counting occurrences of patterns in YAML and C++ using bash `grep -c` and `sed` is fragile. Inline Node.js scripting within the bash preflight is more readable, reliable, and straightforward to extend.

---

### LESSON-OPS-029: CSV fixture timestamps must be epoch seconds (v7.4.4.0)

The dashboard's history chart pipeline uses `new Date(epoch * 1000)` — it expects epoch **seconds** as integers from CSV files. `Date.UTC()` and `Date.now()` return **milliseconds** and must not be used directly as CSV timestamp values. See BUG-025.

---

### LESSON-OPS-028: Verify DOM behavior, not just element IDs (v7.4.3.0)

Verifying element IDs with `grep` is necessary but not sufficient. Three categories require runtime understanding:

1. **CSS class targets** — `toggleTheme()` applies `light` to `document.documentElement` (`<html>`), not `document.body`.
2. **Interaction side-effects** — `_onPreset()` calls `_applyAndClose()` immediately. A preset click closes the modal; there is no confirmation step.
3. **Container relationships** — chart canvases are in `.chart-card` divs, not inside `.sensor-card`.

Rule: before writing any Playwright assertion, read both the HTML and the JS handler for that element.

---

### LESSON-OPS-027: New GitHub Actions workflows only appear after merging to main

GitHub registers workflow files from the default branch only. A new `.github/workflows/*.yml` file on a feature branch will not appear in the Actions sidebar until it is merged to `main`.

---

### LESSON-OPS-026: `data-history-range` button values are in hours, not human-readable labels

| Label | Attribute value |
|-------|----------------|
| 24h | `24` |
| 7d | `168` |
| 30d | `720` |
| 45d | `1080` |
| Custom | `custom` |

---

### LESSON-OPS-025: Output bundle files must clearly indicate their destination path

When delivering files that belong in subdirectories, document the full destination path explicitly in session notes or in the delivery message.

---

### LESSON-OPS-024: Commit `package-lock.json` in the same commit as `package.json`

Any time `package.json` is introduced or changed, commit `package-lock.json` in the same commit. `npm ci` requires the lockfile and will not generate one.

---

### LESSON-OPS-023: Verify new workflow files are committed to the correct branch and appear in git log

After committing a new workflow file: `git show --name-only HEAD | grep workflow`. Do not assume file-system presence equals committed state.

---

### LESSON-OPS-022: Always `grep` the actual HTML for element IDs before writing Playwright selectors

Never assume an ID from a variable name, comment, or context.

Specific gotchas in this codebase:
- Range button values are **hours**, not labels: 24, 168, 720, 1080, custom
- Export buttons use `data-export-all` and `data-export-sensor` attributes, not text matching
- Sensor names are raw text nodes inside `.sensor-card-header` — there is no `.card-title` class
- Export and sensor card elements are built dynamically — use `waitForFunction` before asserting them

---

### LESSON-OPS-021: Zero return values from API need explicit handling distinct from fetch errors

Do not conflate a successful API response containing `0` with a missing/failed response.

---

### LESSON-OPS-020: "Data available: unknown" is expected on a freshly-flashed device

The first NVS history persist runs at 2:10 AM. Until then, `retention_oldest_epoch` returns 0. This is not a bug or a fetch failure.

---

### LESSON-OPS-019: Minification savings are a correctness signal

After running `minify-dashboard.sh`, expected savings are ~30–35% of source size. If savings are below 10%, the script block was almost certainly doubled (embedded twice).

---

### LESSON-OPS-018: Script block sync must use N-1, not N, for `head` cut

When syncing `dashboard.js` into the `<script>` block of `dashboard.html`, use `head -n $((SCRIPT_LINE - 1))`, not `head -n $SCRIPT_LINE`. After every sync, verify: `grep -c '^<script>$' dashboard/dashboard.html` must return `1`.

---

### LESSON-OPS-017: Code and docs should be normalized in the same pass when possible

If a comment/header is clearly stale, normalize it during the same session that fixes the related documentation drift.

---

### LESSON-OPS-016: Every substantial development session should leave continuity breadcrumbs

For meaningful sessions, update: a session log, the fresh-start handoff, and any changed roadmap/implementation-plan docs.

---

### LESSON-OPS-015: Documentation must distinguish current behavior from planned behavior

- `README.md` = current shipped behavior only
- `architecture.md` = current architecture only
- `future-plans.md` / implementation plans = planned behavior

Do not advertise a roadmap item as if it is already merged.

---

### LESSON-OPS-014: `dashboard.h` shrinkage is the easiest signal that minification is active

If the generated header barely changed, the minified intermediate may not have been used.

---

### LESSON-OPS-013: `git pull` can fail after a broken or partial prior pull

If Git says local changes would be overwritten and the changes are unwanted, reset the affected file(s) before retrying.

---

### LESSON-OPS-012: Script execute permissions may be lost

After a fresh clone or after pulling new scripts, run `chmod +x scripts/*.sh`.

---

### LESSON-OPS-011: `html-minifier-terser` uses positional input plus `--output`

Do not script imaginary flags. Test the exact command in a shell first.

---

### LESSON-OPS-010: Cached builds may not reflect header-only changes clearly

If behavior looks stale after header or generated-file changes, use `esphome compile --clean`.

---

### LESSON-OPS-009: Version strings live in six places

1. `VERSION`
2. YAML header comment
3. `register_history_handler()` version string
4. `dashboard_link` publish-state text
5. `App.version` in `dashboard.js`
6. Version comment/header in `dashboard.html`

When a version bump happens, update all six together.

---

### LESSON-OPS-008: `CONFIG_HTTPD_MAX_REQ_HDR_LEN` is a RAM multiplier

Increasing it increases per-connection cost. On this device class, overly large header buffers can create new failures.

---

### LESSON-OPS-007: ESPHome ESP-IDF data-channel constraints matter

- POST body: not reliable for this use case
- Query params: not reliable in this path
- Headers: too limited once proxies add overhead
- **URL path: reliable**

---

### LESSON-OPS-006: Prefer local CLI or editor-driven updates over ad hoc web editing

This reduces accidental truncation, missing execute bits, and inconsistent file state.

---

### LESSON-OPS-005: Raw logs and curated docs stay separate

- Raw logs → `build-logs/` (gitignored)
- Durable documentation → `Docs/`

---

### LESSON-OPS-004: Hidden build directories break GitHub Actions artifact collection

Stage artifacts explicitly into known output directories.

---

### LESSON-OPS-003: Cloud CI and local compile need different secret handling

Local uses the symlinked real secrets file. CI uses temporary dummy secrets.

---

### LESSON-OPS-002: Comments in YAML do not affect ESPHome behavior

Only actual configuration matters.

---

### LESSON-OPS-001: File renames must update internal references

Preflight should catch cross-reference drift, but docs should still be reviewed after any rename.

---

## Regression Checklist

Any significant dashboard or data-path modification should re-check:

- Startup ordering
- Event binding
- Theme redraw
- Chart marker/background/border consistency
- History/min-max calculations
- Export All concurrency behavior
- SSE and polling behavior
- Import over LAN
- Import over Cloudflare
- Browser compatibility across the major test targets
- Dashboard manifest boot sequence (primary `/api/manifest`, fallback `/sensors.json`, fallback built-in defaults)
- Both custom dashboard and built-in ESPHome web page diagnostics (Free Heap, Uptime, Loop Time)

---

## Known Open Issues

### ISSUE-001: Export still causes a noticeable heap drop

The current export path remains acceptable for the present dataset sizes, but it is still not the most memory-efficient design for worst-case full-retention exports.

### ISSUE-002: Multi-sensor import remains erase-first

Single-sensor import is now safe/merge-based, but multi-sensor import still clears existing history before writing.

### ISSUE-003: `/api/manifest` response is a partial v2 schema

The endpoint was implemented as Phase 1, but the response does not yet include the full v2 schema as specified in `Docs/v7.5-v7.6-architecture-plan.md` — specifically: the `gateway` identity block, the `history` retention policy block, and per-measurement `class`, `data_type`, and `display` hints. These are required before Phase 2 (dashboard consuming full manifest) can be fully implemented.

### ISSUE-004: ✅ RESOLVED (v7.5.1.2) — Preflight does not gate on ESPHome YAML validity

`preflight.sh` validates version strings, generator sync, and fixture alignment but does not run `esphome config` to verify YAML parse. A generator bug can produce structurally invalid YAML that passes all preflight checks. See LESSON-OPS-045.

**Resolution**: Preflight now runs `esphome config` to validate YAML structure before allowing merge
