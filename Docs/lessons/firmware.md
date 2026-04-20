# Lessons — Firmware

_Split from Docs/bugs-and-lessons-learned.md at v7.6.4.0._

## Bug Fixes

### BUG-010: `time()` ambiguous in ESPHome context (v7.4.0)

**Fix:** Use `::time(nullptr)`.

---

### BUG-016: `html-minifier-terser` CLI flags wrong (v7.4.1.0)

**Fix:** Use positional input plus `--output`.

---

### BUG-017: `MAX_HISTORY_RANGE_HOURS` was 720, silently truncating 45d history display (v7.4.2.0)

**Fix:** `MAX_HISTORY_RANGE_HOURS = 1080`.

---

### BUG-023: Output bundle file naming caused confusion about destination paths (v7.4.3.0)

**Fix:** Files renamed and placed in correct locations after clarification.

**Lesson:** See LESSON-OPS-025.

---

### Follow-up to BUG-043: Preflight enhancements and browser regression tests specified but never implemented (2026-03-18)

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

## BUG-044 — Fixture/test drift after manifest metric expansion

### Symptom

After adding system-device metrics to manifest v2, preflight failed in the
Playwright manifest check and `render_sensor_config.py --check` reported fixture
drift. The failures appeared as stale expectations (`['temp','hum']`) and
out-of-sync baseline fixture manifest content.

### Root Cause

The system-device metric expansion changed the top-level manifest `metrics`
payload and added `external_push` measurement entries, but test expectations and
fixture-generation paths still assumed env-only top-level metrics.

### Fix

- Updated fixture generator (`tests/fixtures/generate-fixtures.js`) to emit
  system metrics and `external_push` measurement mappings.
- Updated Playwright assertions to validate manifest metrics via
  `arrayContaining(...)` and to derive expected sensor lists from `/api/manifest`
  for satellite-mode boot checks.
- Regenerated baseline + variants via required generators.

### Prevention

Any manifest schema/metrics change must include:
- fixture generator update,
- baseline + variant regeneration,
- Playwright expectation audit for fixed cardinality assumptions.


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

### BUG-057 — lwIP BSD socket aliases collide with `esphome::socket` namespace (2026-03-22)

**Date:** 2026-03-22
**Version observed:** v7.5.5.1
**Status:** FIXED (v7.5.5.1, same PR)

**Symptoms:** CI compilation fails with `error: reference to 'socket' is ambiguous`. The compiler cannot distinguish between lwIP's `int socket(int, int, int)` function and ESPHome's `namespace esphome::socket`.

**Root cause:** The `fetch_to_buffer()` function used BSD-compatible socket function names (`socket()`, `connect()`, `send()`, `recv()`, `close()`, `setsockopt()`). These are inline convenience aliases defined in `lwip/sockets.h` that wrap the real lwIP functions. ESPHome defines a C++ namespace `esphome::socket` (in `esphome/components/socket/headers.h`) which creates a name collision.

**Fix:** Replace all BSD socket aliases with their `lwip_*` prefixed equivalents (`lwip_socket()`, `lwip_connect()`, `lwip_send()`, `lwip_recv()`, `lwip_close()`, `lwip_setsockopt()`). These are the actual lwIP function names with no namespace collision.

**Prevention:** LESSON-OPS-068.


---

### BUG-058 — Aggregator backoff never activates for satellites that were never reachable (2026-03-23)

**Severity:** Performance degradation (C3 single-core stall)
**Introduced in:** v7.5.5.1 (aggregator polling task)
**Fixed in:** v7.5.5.1 post-merge patch

**Symptoms:** When an aggregator boots with an offline satellite, the polling task retries all three endpoints (live, status, manifest) every 5 seconds instead of backing off to 300 seconds. Each failed `fetch_to_buffer()` blocks for the 5-second socket timeout, causing 15 seconds of blocking per loop on the single-core C3.

**Root cause:** The "due" check uses `(sat.last_live_fetch == 0)` to detect "never fetched" and force an immediate attempt. But on failure, `last_live_fetch` is never updated from `0`, so the check is always true on the next iteration. The `effective_interval` of 300 seconds is computed but never consulted because the `== 0` clause short-circuits it.

**Fix:** When a satellite is declared unreachable (3+ consecutive failures), seed any still-zero `last_*_fetch` timestamps to `now` so the 300s backoff interval starts counting. The seeding is deliberately NOT applied on failures 1-2, which allows the normal retry frequency to handle transient boot-order races where the satellite comes up seconds after the aggregator. Additionally, the interval tracking was switched from wall-clock (`::time(nullptr)`) to monotonic uptime (`esp_timer_get_time() / 1000000ULL`) because wall-clock returns 0 before SNTP synchronization, which would make the seeding a no-op and leave the backoff broken during the pre-SNTP window.

**Prevention:** LESSON-OPS-069.


---

### BUG-059 — Validator accepts `https://` satellite URLs that firmware cannot fetch (2026-03-23)

**Severity:** Config-time silent failure → runtime permanent unreachable
**Introduced in:** v7.5.5.0 (aggregator config validator)
**Fixed in:** v7.5.5.1 post-merge patch

**Symptoms:** Aggregator config with `"base_url": "https://192.168.x.x"` passes `validate_aggregator_config()` but the satellite is permanently marked unreachable at runtime because `fetch_to_buffer()` only supports `http://`.

**Root cause:** The Python validator accepted both `http://` and `https://` prefixes, but the C++ HTTP client (`fetch_to_buffer()`) uses raw lwIP sockets without TLS — it rejects any URL not starting with `http://`.

**Fix:** Reject `https://` URLs in the validator with a clear error message explaining that HTTPS satellite polling is not currently supported.

**Prevention:** Config validators must only accept URL schemes that the firmware can actually handle. When adding TLS support in the future, update both the validator AND the firmware simultaneously.


---

### BUG-060 — PyYAML `import yaml` at module level breaks satellite workflow without pip install (2026-03-23)

**Severity:** Build-breaking (preflight crash)
**Introduced in:** Multi-board infrastructure (PR #66)
**Fixed in:** eeb1a13 (lazy import inside `load_board_profile()`)

**Symptoms:** `bash scripts/preflight.sh` crashes with `ModuleNotFoundError: No module named 'yaml'` even on the C3 satellite path that never uses board profiles.

**Root cause:** `import yaml` at the top level of `sensor_manifest_lib.py`. The satellite workflow never calls `load_board_profile()` but the import fails before any function is called. PyYAML is available in the ESPHome environment but not guaranteed on all systems.

**Fix:** Moved `import yaml` inside `load_board_profile()` as a lazy import. The module only loads when board profiles are actually needed.

**Prevention:** LESSON-OPS-071.


---

### BUG-061 — S3 partition table placed ota_0 at wrong offset, bricking the board (2026-03-23)

**Severity:** Board-bricking (requires serial recovery)
**Introduced in:** Multi-board infrastructure (PR #66)
**Fixed in:** a024cac (corrected partition table committed)

**Symptoms:** S3 board entered boot loop after flashing. PlatformIO wrote the firmware to 0x10000 (its default app offset), but the partition table had ota_0 at 0x20000 (after oversized NVS). The bootloader looked for the app at 0x20000, found nothing, and reset.

**Root cause:** The S3 partition table used a larger NVS (0x5000 = 20KB), which pushed phy_init to 0x10000 and ota_0 to 0x20000. PlatformIO ignores the partition table's ota_0 offset when writing — it always flashes to 0x10000.

**Fix:** Corrected the S3 partition table to use NVS at 0x4000 (16KB, matching C3 and WROOM), placing ota_0 at 0x10000. Added documentation comments to the partition CSV explaining the 0x10000 requirement.

**Prevention:** LESSON-OPS-070. Preflight must validate ota_0 offset in all partition CSVs (check not yet implemented — planned for pre-v7.5.5.2 infrastructure commit).


---

### BUG-062 — `/api/status` reports PSRAM as `free_heap` on S3, misleading monitoring (2026-03-23)

**Severity:** Misleading diagnostics (not a crash)
**Introduced in:** v7.5.5.1 (first S3 deployment)
**Fixed in:** Pending (documented, fix planned for pre-v7.5.5.2 infrastructure commit)

**Symptoms:** `curl /api/status` on the S3 aggregator reports `free_heap: 8847360` (8.4 MB). This is the PSRAM-inclusive value. The ESPHome debug sensor shows ~32 KB (internal SRAM only). Monitoring scripts or dashboards that compare heap values across C3 and S3 get wildly different numbers that aren't comparable.

**Root cause:** `esp_get_free_heap_size()` returns total free heap including PSRAM on boards that have it. On the C3 (no PSRAM), this is internal SRAM only (~70 KB). On the S3 (8 MB PSRAM), this includes PSRAM (~8.4 MB). The values are not comparable across board types.

**Fix (planned):** Report both values in `/api/status`:
```json
{
  "free_heap": 32768,
  "free_heap_internal": 32768,
  "free_heap_total": 8847360
}
```
`free_heap` stays as internal-only for backward compatibility. `free_heap_total` is additive. Use `esp_get_free_internal_heap_size()` for the internal value.

**Prevention:** LESSON-OPS-072.


---

### BUG-064 — Aggregator boot path skips satellite pipeline entirely (2026-03-25)

**Severity:** Critical — all local functionality broken on aggregator
**Introduced in:** v7.5.5.3
**Fixed in:** v7.5.5.3 hotfix

**Symptoms:** Aggregator dashboard showed: (1) red "connecting" dot in upper right, (2) "loading..." on History Storage, (3) "waiting for telemetry..." on Telemetry chart, (4) no local sensor cards (WAN ping not rendered), (5) Real-Time Charts stuck on "waiting for sensor data..."

**Root cause:** `App.Boot.start()` had a forked if/else structure. The aggregator path only called `loadManifestV2()` → `updateBoardInfo()` → `initAggregatorDashboard()`. It skipped ALL satellite functions: no `buildSensorCards()`, no `initCharts()`, no `connectSSE()` / `startPolling()`, no `loadStorageStats()`, no `loadStatusSnapshot()`, no `loadHistory()`, no `pollV2Live()`. The code comment explicitly said "Local device cards are NOT rendered here."

This directly violated **Principle 1** from the design document: "An aggregator is a satellite with aggregation enabled. Every satellite capability is available to an aggregator. The `AGGREGATOR_ENABLED` flag adds aggregator capabilities; it never subtracts satellite capabilities."

**Fix:** Unified boot path — removed the if/else fork. Both satellite and aggregator run the identical pipeline (manifest → sensor load → cards → charts → SSE/polling → status → storage stats → history). At the end, if `isAggregator` is true, `initAggregatorDashboard()` overlays the Gateways section.

**Prevention:** LESSON-OPS-074.


---

### BUG-070 — Aggregator fixture `manifest.sensors` format mismatch (2026-03-25)

**Severity:** Test authoring error (caught in development)
**Introduced in:** v7.5.5.4 initial fixture draft
**Fixed in:** v7.5.5.4

**Symptoms:** `renderGatewayDevices()` showed "No device data available" despite fixture containing gateway manifest data.

**Root cause:** The `aggregator-gateways.json` fixture used `"devices": {}` (object format) for the nested gateway manifest, but `renderGatewayDevices()` checks `manifest.sensors` (array). The satellite manifest v2 format uses a `sensors` array, not a `devices` object.

**Fix:** Changed `aggregator-gateways.json` fixture to use `"sensors": [...]` array format matching the actual v2 manifest schema.


---

### BUG-075 — httpd task stack overflow on S3 aggregator — management POST handlers (v7.6.0.0 fixup)

**Symptom:** Every POST request with a body to any management endpoint
(`/api/system/reset-satellites`, `/api/delete-data`) crashes the S3 aggregator
with `StoreProhibited` in `vPortYieldFromInt`, `EXCVADDR: 0xfffffec0`, fully
corrupted backtrace. 100% reproducible, independent of satellite polling state.

**Root cause:** ESP-IDF's `HTTPD_DEFAULT_CONFIG()` macro hardcodes
`.stack_size = 4096` as a literal integer. ESPHome's `web_server_idf.cpp`
(confirmed at build path `src/esphome/components/web_server_idf/web_server_idf.cpp`,
lines 123–133) calls `httpd_start()` with `HTTPD_DEFAULT_CONFIG()` and never
overrides `stack_size`. The httpd task therefore runs at 4 KB regardless of any
`CONFIG_HTTPD_STACK_SIZE` sdkconfig setting — that setting is dead code.
`handle_reset_satellites_()` performed two full NVS open/write/commit cycles,
AGG_LOCK/UNLOCK, a satellite loop with string copies, and save_satellites_to_nvs_() —
far exceeding 4 KB. `handle_delete_data_()` called `nvs_flash_erase_partition()` —
same overflow.

**Non-fixes attempted:**
- `CONFIG_HTTPD_STACK_SIZE: "24576"` in board profiles → no effect
- `CONFIG_HTTPD_STACK_SIZE: "65536"` → same crash
- Stopping satellite polling → same crash (race condition ruled out)

**Fix (primary):** Local ESPHome component override. The `web_server_idf`
component is copied into `firmware/local_components/web_server_idf/` and patched
to set `config.stack_size = 16384` after `HTTPD_DEFAULT_CONFIG()`. Board profiles
reference this via `external_components`. Managed by
`scripts/patch-esphome-httpd-stack.sh`; re-run after every ESPHome upgrade.

**Fix (secondary):** Deferred task pattern. `handle_reset_satellites_()` and
`handle_delete_data_()` authenticate + send HTTP response immediately + spawn a
dedicated `xTaskCreate` task (8192-byte stack) for NVS work. Even with the
16 KB httpd stack, NVS operations should not run on the httpd task. Pattern
mirrors the existing `schedule_reboot_()` implementation.

**Note:** Testing proved that the deferred task pattern alone is NOT sufficient.
Even the lightest handler (unauthenticated request → `send_json_error_(401)`)
overflows the 4 KB stack. The component override is mandatory.

**Prevention:** See LESSON-OPS-100, LESSON-OPS-101, and LESSON-OPS-102.


---

### BUG-076 — POST requests with any body crash S3 aggregator (v7.6.0.0 fixup)

**Symptom:** Same crash as BUG-075 (`StoreProhibited` / `vPortYieldFromInt`).
All POST requests with a body crash the board — `application/x-www-form-urlencoded`,
`application/json`, any content type, any non-zero body size.

**Root cause:** BUG-075 (httpd task stack overflow). The body presence is not
the cause — it is what triggers our handler code, which then overflows the stack.

**Secondary issue:** `dashboard.js` and `dashboard.html` sent
`Content-Type: application/json` with `body: '{}'`. ESPHome's
`request_post_handler` does not consume JSON POST bodies — it falls through to
the GET handler path without reading the socket, corrupting socket state for
subsequent responses. This is a secondary crash vector layered on top of BUG-075.

**Fix:** (1) BUG-075 deferred task fix resolves the primary crash.
(2) Dashboard POST calls changed to `Content-Type: application/x-www-form-urlencoded`
with `body: 'a=1'` to use the only body type ESPHome actually consumes.

**Prevention:** See LESSON-OPS-099, LESSON-OPS-100, LESSON-OPS-101.
Critical Rules 38–41.


---

### BUG-077 — `handle_add_satellite_()` uses Arduino `String` type — ESP-IDF build failure (v7.6.0.1)

**Symptom:** After merging PR #108 and pulling locally, `esphome compile` fails
at `sensor_history_multi.h` line 3622 (line number varies by local state):
`error: 'String' was not declared in this scope`.

**Root cause:** The coding agent generated `String url_param = request->getParam("url")->value();`
using the Arduino `String` type. ESPHome's IDF build target does not have Arduino
compatibility — only `std::string` is available. The agent's CI sandbox runs
Playwright/preflight tests but does not perform actual ESP-IDF compilation, so
the Arduino-ism passed CI.

**Secondary issue:** A first manual fix changed `String` to bare `string` (no
namespace qualifier), which also fails because the codebase has no
`using namespace std;` directive.

**Fix:** `std::string url_param = request->getParam("url")->value();`

**Introduced by:** PR #108 (v7.6.0.1).
Codified as Critical Rule 44, LESSON-OPS-104.


---

### BUG-078 — Local component `init_response_()` maps all non-200/404/409 status codes to HTTP 500 (v7.6.0.1 fixup)

**Symptom:** Device testing of `POST /api/aggregator/add-satellite` error paths
showed correct JSON body (`"status":400`) but curl reported HTTP 500 for every
error response. Only 200, 404, and 409 responses had correct HTTP status codes.

**Root cause:** `firmware/local_components/web_server_idf/web_server_idf.cpp`,
function `AsyncWebServerRequest::init_response_()`. The `switch(code)` block
created during the BUG-075/076 local component override only had cases for
200, 404, and 409. The `default` branch mapped to `HTTPD_500`. This is actually
a pre-existing bug in stock ESPHome's `web_server_idf.cpp` — the local override
inherited it, and we are the first to use 400/401/405 from handlers.

**Impact:** Every `send_json_error_(request, 400, ...)` call across the entire
codebase returned HTTP 500 to clients. Authentication failures (401), method
rejections (405), rate limiting (429), and stub endpoints (501) were all affected.
The JSON body was always correct — only the HTTP status line was wrong.

**Fix:** Expanded the switch to cover 200, 204, 301, 302, 400, 401, 403, 404,
405, 408, 409, 429, 500, 501, 503, with a `snprintf` fallback for any
unrecognized code. Also updated `scripts/patch-esphome-httpd-stack.sh` awareness:
after re-running the script on ESPHome upgrade, verify the status code switch
is still intact (the script copies upstream and re-applies only the stack patch).

**Introduced by:** PR #105 (BUG-075/076 fix). Present in stock ESPHome.
Codified as Critical Rule 43, LESSON-OPS-103.


---

### BUG-079 — DELETE requests rejected by httpd layer with 405 before reaching handler (v7.6.0.2 fixup)

**Symptom:** Every `curl -X DELETE` to `/api/aggregator/satellite/{id}` returned HTTP 405
with plain-text `"Specified method is invalid for this resource"`. All device test DELETE
cases (T1-T4, T10) failed. GET and POST to the same URL correctly returned JSON 405 from
the handler.

**Root cause:** `firmware/local_components/web_server_idf/web_server_idf.cpp`,
function `AsyncWebServer::begin()`. The local component (introduced in PR #105 as the
BUG-075/076 stack-size fix) copied stock ESPHome's `begin()` which registers URI handlers
only for `HTTP_GET`, `HTTP_POST`, and `HTTP_OPTIONS`. No `HTTP_DELETE` handler was ever
registered. When a DELETE request arrives, ESP-IDF httpd finds no registered handler for
that method and immediately returns its built-in plain-text 405 — before calling any
`canHandle()` or `handleRequest()` on our handler objects. The `canHandle()` and
`handleRequest()` routing in `dashboard/sensor_history_multi.h` was correct; they were
simply never reached for DELETE requests.

**Diagnostic signature:** A plain-text 405 (not JSON) means the request never reached
our handler at all. Our handler's `send_json_error_()` always returns `application/json`.
GET and POST returning JSON 405 (method-not-allowed from our handler) confirmed the
transport layer was selectively blocking only DELETE.

**Fix:** Added `HTTP_DELETE` URI handler registration in `AsyncWebServer::begin()` in
`firmware/local_components/web_server_idf/web_server_idf.cpp`, after the existing OPTIONS
handler. DELETE requests have no body, so they use the same `request_handler` path as GET.
Also updated `scripts/patch-esphome-httpd-stack.sh` to apply this patch automatically
when re-running after an ESPHome upgrade.

**Introduced by:** PR #105 (BUG-075/076 fix) — the local component was created without
registering a DELETE handler. Present throughout v7.6.0.0 and v7.6.0.1; first exposed by
the DELETE satellite endpoint added in PR #110 (v7.6.0.2).

**Fixed by:** PR #114. See LESSON-OPS-108, LESSON-OPS-109.


---

### BUG-082: `csv.reserve(cap)` does not truncate - string grows unbounded past reserved capacity (v7.6.9.4)

**Symptom:** WROOM board (192.168.120.190) crashes with heap exhaustion when serving `/history/{id}/temp` or when dashboard loads history at boot, despite v7.6.9.4 adaptive cap computing a safe reserve value of ~12 KB.

**Root cause:** `std::string::reserve(N)` pre-allocates capacity N but does NOT prevent the string from growing beyond N through `.append()` calls. The NVS scan loop in `handle_history_()` (`firmware/core/web-handler.h`) appended ~40 KB of CSV data (556 segments x 4 points x ~18 bytes/line) into a string reserved at 12 KB, triggering repeated reallocations. During reallocation from ~24 KB -> ~48 KB, `std::string` temporarily holds both old and new buffers (72 KB total), exceeding the WROOM's ~34 KB free heap.

**Resolution:** Deferred to Phase 7. The proper fix is chunked HTTP streaming - serving NVS segments in paged responses (~3.6 KB each) instead of building the full CSV in RAM. A simple truncation guard (`break` when `csv.size() >= adaptive_cap`) was considered but rejected because it would truncate history display on ALL boards (including C3) as their NVS fills up, not just WROOM.

**Data safety:** NVS data is intact on flash. Raw partition backup extracted via `esptool read_flash 0x370000 0x80000`. Offline parser script (`scripts/parse_nvs_history.py`) available for extraction.

**Lesson:** `reserve()` is an allocation optimization, not a size constraint. Any time a `reserve()` cap is introduced as a safety net for heap-constrained boards, verify whether the subsequent append loops actually enforce the cap as a truncation limit. See LESSON-OPS-127.


---

## Lessons Learned

### LESSON-OPS-005: Raw logs and curated docs stay separate

- Raw logs → `build-logs/` (gitignored)
- Durable documentation → `Docs/`

---

### LESSON-OPS-007: ESPHome ESP-IDF data-channel constraints matter

- POST body: not reliable for this use case
- Query params: not reliable in this path
- Headers: too limited once proxies add overhead
- **URL path: reliable**

---

### LESSON-OPS-008: `CONFIG_HTTPD_MAX_REQ_HDR_LEN` is a RAM multiplier

Increasing it increases per-connection cost. On this device class, overly large header buffers can create new failures.

---

### LESSON-OPS-011: `html-minifier-terser` uses positional input plus `--output`

Do not script imaginary flags. Test the exact command in a shell first.

---

### LESSON-OPS-012: Script execute permissions may be lost

After a fresh clone or after pulling new scripts, run `chmod +x scripts/*.sh`.

---

### LESSON-OPS-013: `git pull` can fail after a broken or partial prior pull

If Git says local changes would be overwritten and the changes are unwanted, reset the affected file(s) before retrying.

---

### LESSON-OPS-015: Documentation must distinguish current behavior from planned behavior

- `README.md` = current shipped behavior only
- `architecture.md` = current architecture only
- `future-plans.md` / implementation plans = planned behavior

Do not advertise a roadmap item as if it is already merged.

---

### LESSON-OPS-016: Every substantial development session should leave continuity breadcrumbs

For meaningful sessions, update: a session log, the fresh-start handoff, and any changed roadmap/implementation-plan docs.

---

### LESSON-OPS-017: Code and docs should be normalized in the same pass when possible

If a comment/header is clearly stale, normalize it during the same session that fixes the related documentation drift.

---

### LESSON-OPS-020: "Data available: unknown" is expected on a freshly-flashed device

The first NVS history persist runs at 2:10 AM. Until then, `retention_oldest_epoch` returns 0. This is not a bug or a fetch failure.

---

### LESSON-OPS-023: Verify new workflow files are committed to the correct branch and appear in git log

After committing a new workflow file: `git show --name-only HEAD | grep workflow`. Do not assume file-system presence equals committed state.

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

### LESSON-OPS-027: New GitHub Actions workflows only appear after merging to main

GitHub registers workflow files from the default branch only. A new `.github/workflows/*.yml` file on a feature branch will not appear in the Actions sidebar until it is merged to `main`.

---

### LESSON-OPS-032: NVS count-mismatch protection is already in place — no new C++ guard needed (v7.4.4.0)

The `meta.num_sensors == NUM_SENSORS` check in the NVS restore path already rejects history segments from a different sensor count cleanly. The correct response to a count change is: load nothing from the old segments, require an explicit history delete, and document the procedure.

---

### LESSON-OPS-036: Repeated configuration belongs in one canonical manifest (v7.4.5.0)

If the same sensor facts appear in multiple repo files, manual editing will eventually drift. Move those facts into one canonical manifest and generate the dependent files from it.

**Carry forward:** `config/sensors.json` is the source of truth. Future sensor-related changes should flow through the manifest and renderer first.

---

### LESSON-OPS-038: Safety prompts belong on destructive CLI paths, not only in prose documentation (v7.4.5.1)

Documenting that a path is destructive is not enough. If a CLI command can erase retained state, the operator should have to acknowledge that at runtime or opt into bypassing the prompt deliberately.

---

### LESSON-OPS-039: Use lambda replacements in `re.sub()` when generated content may contain backslashes (v7.5.0.0)

Generated text that contains escape sequences like `\xC2\xB0`, `\n`, or `\t` is unsafe as a raw string argument to `re.sub()`. Use a lambda function as the replacement instead: `re.sub(pattern, lambda m: generated_text, source)`.

Also: do not use brittle exact-string patching against compacted one-line C++ source blocks. Use function-anchor detection, regex-based matching, or brace-aware insertion instead.

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

### LESSON-OPS-056: Never use beginResponseStream for large HTTP responses on ESP32-C3

**Date:** 2026-03-17

`AsyncWebServer::beginResponseStream()` builds the response in an internal `std::string` that grows through repeated `print()` calls. Each `std::string` reallocation temporarily holds both old and new buffers. For a 24KB response (typical for 336 NVS segments × 4 points × 20 bytes/line), the growth from 16KB→32KB requires 48KB of simultaneous heap — nearly the entire free heap when SSE/polling connections are active.

**Rule:** Any HTTP response that could exceed ~10KB must use pre-reserved `std::string` with `csv.reserve(estimated_size)` followed by zero-copy `beginResponse(200, content_type, reinterpret_cast<const uint8_t*>(str.data()), str.size())`. This pattern makes a single heap allocation at the estimated final size, avoiding the reallocation cascade.

---

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

### LESSON-OPS-060: Compile-time NVS schema constant changes require a firmware migration/re-save path (2026-03-19)

**Date:** 2026-03-19

When a compile-time constant used in an NVS-persisted struct (e.g., `NUM_SENSORS` in
`HistoryMeta`) changes between firmware versions, validation code that compares the persisted
value against the new constant will reject the stored blob. If the rejection only resets the
in-memory copy without writing the corrected value back to NVS, the rejection repeats on every
boot — an infinite stale-meta loop.

**Rule:** Any validation function that detects a schema mismatch in a persisted NVS blob must
either:
1. Persist the corrected/default metadata back to NVS before returning, or
2. Signal to its caller (e.g., via an output flag) that the corrected metadata needs to be
   persisted, and the caller must do so before proceeding.

Simply resetting the struct in RAM is never sufficient — the stale blob survives reboots.

**Corollary:** When persisting corrected metadata, be careful about NVS handle open modes.
`NVS_READONLY` handles cannot write. The migration path must obtain a `NVS_READWRITE` handle
(either by reopening or by opening writable from the start), save, and close it cleanly on
all code paths.

Related: BUG-046, BUG-045

---

### LESSON-OPS-061: Never change compile-time constants that dimension persisted NVS structs without a migration plan (2026-03-19)

**Date:** 2026-03-19

When a compile-time constant (e.g., `NUM_SENSORS`) is used to size arrays inside a
struct that is written to NVS as a blob (e.g., `SegmentSnapshot`), changing that constant
changes the struct's `sizeof()`. All existing blobs become a different byte length than
the new struct layout. `nvs_get_blob()` returns `ESP_ERR_NVS_INVALID_LENGTH` — the data
is not just schema-invalid, it is **physically unreadable** without a cross-schema deserializer.

This is worse than a schema mismatch in a metadata header (which BUG-046/LESSON-OPS-060
addressed). Metadata can be corrected in-place because the struct layout didn't change.
Data blobs with array dimensions baked in cannot.

**Rule:**
1. Never change a compile-time constant that dimensions a persisted struct without a migration
   plan that accounts for the blob size change.
2. The restore loop (`restore_from_nvs()`) must detect `ESP_ERR_NVS_INVALID_LENGTH` and
   recalibrate `meta.valid_segments` to exclude unloadable ghost slots. The recalibrated
   meta must be persisted back to NVS so subsequent boots don't repeat futile load attempts.
3. Preflight should assert `sizeof(SegmentSnapshot)` hasn't changed when `NUM_SENSORS` is
   expected to remain constant. Any prompt that touches sensor count constants must include
   an explicit "verify `sizeof(SegmentSnapshot)` is unchanged" acceptance criterion.
4. Data in incompatible blobs is unrecoverable without a dedicated cross-schema converter.
   Users should be advised to CSV-export before any firmware update that might change
   persistence-related constants.

Related: BUG-048, BUG-046, BUG-045, LESSON-OPS-060

---

### LESSON-OPS-068: Use lwip_*() prefixed functions, not BSD socket aliases, in ESPHome C++ code (2026-03-22)

**Context:** ESPHome defines `namespace esphome::socket` which collides with lwIP's BSD-compatible inline wrappers (`socket()`, `connect()`, `close()` etc.). This is not visible when reading lwIP documentation because the aliases work fine in standalone ESP-IDF projects — the collision only appears inside the ESPHome build environment.

**Rule:** In any C++ code that runs inside ESPHome (headers included via YAML `includes:`), always use the `lwip_*` prefixed function names for socket operations:
- `lwip_socket()` not `socket()`
- `lwip_connect()` not `connect()`
- `lwip_send()` not `send()`
- `lwip_recv()` not `recv()`
- `lwip_close()` not `close()`
- `lwip_setsockopt()` not `setsockopt()`
- `lwip_getaddrinfo()` not `getaddrinfo()` (already used by PingAdapter)
- `lwip_freeaddrinfo()` not `freeaddrinfo()` (already used by PingAdapter)

**Applies to:** All current and future code that uses lwIP sockets — aggregator polling, history proxy, any future HTTP client code.

Related: BUG-057, PR #64

---

### LESSON-OPS-069: Interval-based "due" checks must handle the never-succeeded case (2026-03-23)

**Context:** A common pattern for periodic tasks is `bool due = (last_run == 0) || (now - last_run >= interval)`. The `== 0` clause handles the "first run" case. But if the first run FAILS and `last_run` is never set, the task retries on every loop iteration regardless of the interval — the backoff is dead code.

**Rule:** When a periodic operation fails and the timestamp was never set (still 0), set it to `now` so the interval starts counting — but only after the failure threshold is crossed. Seeding too early (on first failure) prevents legitimate retries during transient conditions like boot-order races. The seeding should be coupled with the state transition (e.g., "declared unreachable"), not with every individual failure. Additionally, interval tracking should use monotonic time (e.g., `esp_timer_get_time()`), not wall-clock time (`::time(nullptr)`), because wall-clock may be 0 before SNTP sync — making any `== 0` sentinel check unreliable. This applies to any pattern where:
1. A timestamp field starts at 0 (meaning "never done")
2. The timestamp is only updated on success
3. A backoff/interval check uses the timestamp

**Applies to:** Aggregator polling task, any future periodic fetch/sync operations.

Related: BUG-058

---

### LESSON-OPS-070: All ESP32 partition tables must have ota_0 at 0x10000 (2026-03-23)

**Context:** PlatformIO/esptool writes the application binary to offset 0x10000 regardless of what the partition table says. The S3 partition table had ota_0 at 0x20000 (due to oversized NVS), which meant the bootloader looked for the app at the wrong address.

**Rule:** In every partition table for any ESP32 variant (C3, S3, C5, C6, WROOM), `ota_0` must start at `0x10000`. This is non-negotiable. The fixed items (NVS at 0x9000/0x4000, otadata at 0xD000/0x2000, phy_init at 0xF000/0x1000) must fit before 0x10000 with no overlap. Preflight must validate: `grep ota_0 partitions/*.csv` → offset must be `0x10000` for every file.

**Applies to:** All current and future partition tables.

Related: BUG-061

**Date:** 2026-03-22

When creating a new generated header file (e.g., `src/aggregator_config.h`) that is `#include`d
from an existing ESPHome-managed header (`sensor_history_multi.h`), the new file must ALSO be
added to the `includes:` list in `firmware/esp32-c3-multi-sensor.yaml`. ESPHome only copies
files listed in `includes:` into its build directory — without this entry, the compiler cannot
find the header even though the `#include` directive is syntactically correct.

**Discovered during:** v7.5.5.0 implementation. The first commit added `#include "aggregator_config.h"`
to `sensor_history_multi.h` and generated `src/aggregator_config.h`, but did not add
`../src/aggregator_config.h` to the YAML `includes:`. CI compilation failed. A second commit
was required to fix it.

**Rule:** When any implementation step creates a new header file under `src/` or `dashboard/`,
immediately check `firmware/esp32-c3-multi-sensor.yaml` `includes:` and add the new file path
there. Treat the YAML includes list as part of the same atomic change as the `#include` directive.

**Prevention:** Add a preflight check in a future step that cross-references all `#include` directives
in ESPHome-managed headers against the YAML `includes:` list.

Related: v7.5.5.0 PR #62

---


### LESSON-OPS-072: `esp_get_free_heap_size()` includes PSRAM on boards that have it (2026-03-23)

**Context:** The S3 aggregator reported 8.4 MB free heap via `/api/status`, which is correct (it includes PSRAM) but misleading when compared to C3 values (~70 KB, internal SRAM only). Monitoring dashboards and health checks that threshold on free heap will behave differently across board types.

**Rule:** Always report both internal and total heap separately. Use `esp_get_free_internal_heap_size()` for internal SRAM (comparable across all boards) and `esp_get_free_heap_size()` for total (includes PSRAM where available). The `/api/status` endpoint should expose `free_heap` (internal, backward-compatible), `free_heap_internal`, and `free_heap_total`.

Related: BUG-062

---


### LESSON-OPS-074: Aggregator boot must be a superset of satellite boot, never a fork (2026-03-25)

**Context:** The v7.5.5.3 aggregator boot path was implemented as an if/else branch that replaced the satellite pipeline entirely. The aggregator loaded the manifest and called `initAggregatorDashboard()` but skipped local sensor cards, SSE/polling, storage stats, telemetry, and history. This broke every local feature on the aggregator device.

**Rule:** Per Principle 1 ("roles are capability tiers"), the aggregator boot path must be: run the full satellite pipeline first, then overlay aggregator UI at the end. Never fork the boot path into separate branches where one skips the other's functionality. The aggregator is a satellite with aggregation ON TOP, not a different product.

**Pattern:**
```javascript
// CORRECT: unified pipeline + overlay
detectAggregatorMode().then(function(isAgg) {
  // ... full satellite pipeline (manifest, cards, charts, SSE, stats, history) ...
  if (isAgg) initAggregatorDashboard(); // overlay at the end
});

// WRONG: forked pipeline
if (isAgg) { /* aggregator-only path — skips satellite */ }
else { /* satellite-only path */ }
```

**Applies to:** All future dashboard boot flow changes, any new role additions.

Related: BUG-064, BUG-065



---

### LESSON-OPS-076: Aggregator fixture `manifest` block must use `sensors` array (v2 format) (2026-03-25)

**Context:** The v7.5.5.4 prompt example showed `"devices": {}` (object) inside the
cached gateway manifest in `aggregator-gateways.json`. The satellite manifest v2 format
uses a `sensors: [...]` array. `renderGatewayDevices()` checks `manifest.sensors` and
returns "No device data available" if it's absent or empty.

**Rule:** Embedded gateway manifests in `aggregator-gateways.json` must use the standard
v2 manifest format: `"sensors": [{ "id": ..., "name": ..., "category": ... }]`.

**Detection:** "No device data available" displayed in gateway device view despite fixture
containing manifest data.

---

### LESSON-OPS-085: Validate fetched content wasn't truncated before embedding in composed JSON responses (2026-03-28)

When composing a JSON response from cached or proxied upstream payloads, never assume a fixed-size fetch buffer captured a complete document. If `fetch_to_buffer()` (or equivalent) reaches `buf_size - 1`, treat the payload as likely truncated and do not embed it verbatim.

For aggregator manifests specifically, guard with `manifest_len >= AGG_MANIFEST_BUF_SIZE - 1` and emit `"manifest":null` plus a warning log. This preserves valid top-level JSON and prevents one oversized satellite payload from breaking the entire `/api/aggregator/gateways` response.

---

## LESSON-OPS-083 — Playwright test signatures must not include unused fixture arguments (v7.5.6.4)

**Version:** v7.5.6.4
**Source:** PR #87 review comment (Gemini r2997248086) — test `/api/v2/live returns system device data` destructured `{ page, request }` but only used `request`.

When writing a Playwright test that only uses the `request` fixture (e.g., a pure API test), do not include `page` in the destructured argument list. Including `page` forces Playwright to create a browser context even when it is not needed, wasting ~1–2 s per test run.

**Rule:** Every test function signature must destructure only the fixtures it actually uses. Before merging, scan all new tests for unused Playwright fixture arguments.

---

## LESSON-OPS-082 — Fixture composition changes require downstream text audit (v7.5.6.4)

**Version:** v7.5.6.4
**Source:** PR #87 — mixed fixture gained `nas01` (3 → 4 sensors) but skip-reason strings referencing "3 sensors" remained in multiple locations.

When a prompt changes a fixture's sensor count or composition:
1. The prompt MUST include an explicit instruction: "After updating the fixture, search all `test.skip()` reason strings in `dashboard.spec.js` for references to the old sensor count and update them."
2. The prompt MUST also flag any group header comments that describe the fixture by composition.

A fixture change is not complete until all downstream text references to that fixture's old composition are updated.

---

## LESSON-OPS-081 — Mock endpoint prompts must enumerate all firmware validation branches (v7.5.6.4)

**Version:** v7.5.6.4
**Source:** PR #87 — mock `/api/ingest` required 2 fix commits because the prompt only specified device validation, not metric/val validation.

When a prompt asks the agent to create a mock endpoint for an existing firmware API, the prompt MUST:
1. Name the firmware function to read (e.g., `handle_api_ingest_()`)
2. Enumerate all positive and negative validation branches
3. Specify exact response shapes for success (`{"ok":true}`) and failure (`{"ok":false,"message":"...","status":N}`)
4. Require one test per branch
5. Explicitly prohibit stub-level mocking: "Do NOT reduce this mock to a 'device exists → 200' stub"

A mock that only validates device existence is a stub, not a contract-faithful implementation. It hides client-side bugs and causes merge-blocking review comments.

---

## LESSON-OPS-080 — System fixture skip guards (v7.5.6.4)

**Version:** v7.5.6.4
**Symptom:** After adding the `system` fixture variant (2 env + 1 net + 1 sys = 4 sensors),
7 existing tests failed because they assumed the 3sensor-specific sensor list
(`office`, `first_floor`, `outside`) or expected exactly 3 env sensors.

**Skip guards added (v7.5.6.4):**
- `2. Sensor cards / sensor card headers contain expected sensor names` — 'Outside' absent from system fixture
- `14. Phase 2 Closure / scenario 1` — 'Outside' name check is 3sensor-specific
- `14. Phase 2 Closure / scenario 2` — sensors.json fallback count (3) is 3sensor-specific; system has 2 env entries
- `14. Phase 2 Closure / scenario 4` — `envSensors.length === 3` is 3sensor-specific; system has 2 env sensors
- `15. Phase 3 Closure / dashboard renders identically` — 'Outside' name check is 3sensor-specific
- `17. Phase 4 Step 2 / environmental cards have full ThermoPro layout` — `.sensor-card:not(.network-card)` includes system card which lacks `.sensor-env-grid`
- `manifest.spec.js / dashboard falls back to /sensors.json` — fallback sensor list is 3sensor-specific

**Prevention:** When adding a new fixture variant, always run `FIXTURE_SET=<new> npx playwright test --project=chromium` (full suite, no `--grep`) to discover incompatibilities before merging.

---

### LESSON-OPS-100: ESPHome httpd task stack is hardcoded at 4 KB — CONFIG_HTTPD_STACK_SIZE has no effect (2026-03-30)

`HTTPD_DEFAULT_CONFIG()` in ESP-IDF hardcodes `.stack_size = 4096` as a literal.
ESPHome's `web_server_idf.cpp` never overrides this. `CONFIG_HTTPD_STACK_SIZE` in
`sdkconfig_options` is completely inert — do not add it to any board profile.
The only way to increase the httpd stack is via a local ESPHome component override
(see LESSON-OPS-102). NVS-heavy handlers must additionally use the deferred task
pattern (see LESSON-OPS-101). Codified as Critical Rules 40, 41, and 42.

---

### LESSON-OPS-101: Deferred task pattern for NVS-heavy HTTP handlers (2026-03-30)

HTTP request handlers share the httpd task's 4 KB stack. Any handler performing
NVS operations, mutex acquisition, or substantial string work will overflow it.
Use the deferred task pattern: handler authenticates, sends HTTP response, then
calls `xTaskCreate` to spawn a task (minimum 8192 bytes for NVS work) that does
the heavy lifting. The spawned task must call `vTaskDelete(nullptr)` when done.
This is the pattern already used by `schedule_reboot_()` / `reboot_task_`.
Minimum task stack for NVS operations: 8192 bytes. Add
`uxTaskGetStackHighWaterMark()` logging before release to confirm sizing.

---

### LESSON-OPS-102: ESPHome httpd stack must be patched via local component override (2026-03-31)

Because `CONFIG_HTTPD_STACK_SIZE` is inert (LESSON-OPS-100), the only way to
increase the httpd task stack is to override ESPHome's `web_server_idf` component
locally. The script `scripts/patch-esphome-httpd-stack.sh` copies the upstream
component into `firmware/local_components/web_server_idf/` and patches
`config.stack_size = 16384` into `AsyncWebServer::begin()`. Board profiles must
include an `external_components` block pointing to `local_components`. The script
must be re-run after every ESPHome version upgrade. Use `--check` to verify.
Codified as Critical Rule 42.

---

### LESSON-OPS-103: Local component `init_response_()` must map all HTTP status codes used by handlers (2026-04-01)

The `web_server_idf` local component override (`firmware/local_components/web_server_idf/`)
contains a `switch(code)` in `init_response_()` that maps integer status codes to
`httpd_resp_set_status()` strings. If a handler uses a status code not in the switch,
the response silently becomes HTTP 500 regardless of the JSON body content.

**Rule:** After running `scripts/patch-esphome-httpd-stack.sh` (which copies
upstream and re-applies only the stack patch), manually verify that
`init_response_()` still contains the expanded status code switch with the
`snprintf` fallback. The upstream copy may overwrite the expanded switch.
Consider adding a verification step to the patch script.
Codified as Critical Rule 43.

---


### LESSON-OPS-104: Always use `std::string`, never Arduino `String` or bare `string`, in ESP-IDF code (2026-04-01)

The coding agent's sandbox does not perform ESP-IDF compilation — it runs
Playwright tests and preflight checks only. Arduino-isms like `String` (capital S)
pass all CI checks but break the real build. When manually fixing, bare `string`
(no namespace) also fails because this codebase has no `using namespace std;`.

**Rule:** In all `.h`/`.cpp` files compiled under ESP-IDF: always use `std::string`,
`std::vector`, etc. Never rely on `using namespace std`. Treat any capital-S
`String` in agent-generated code as a review red flag during PR review.
Codified as Critical Rule 44.

---

### LESSON-OPS-105 — Snapshot-based deferred NVS persistence (2026-04-02)

**Context:** v7.6.0.2 DELETE endpoint needs to persist satellite config to NVS after
array compaction, but NVS write is too slow for the HTTP handler stack (Critical Rule 40).
The initial implementation called `save_satellites_to_nvs_()` directly from a deferred
FreeRTOS task, which reads global state (`satellite_caches[]`, `runtime_satellite_count`)
without holding the mutex — creating a torn-read race condition.

**Solution:** Capture a `SatelliteNVSSnapshot` struct under `AGG_LOCK()` in the caller
(HTTP handler context), then pass the heap-allocated snapshot to the deferred task as
`pvParameters`. The task writes the snapshot to NVS and frees it. No lock needed during
the slow flash write.

**Pattern:** snapshot-under-lock → heap-allocate → pass to task → write → free → delete task.
Applicable anywhere a slow I/O operation needs a consistent view of mutex-protected state.

---

### LESSON-OPS-106 — Config-generation counter for poll-task safety (2026-04-02)

**Context:** `aggregator_poll_task()` iterates `satellite_caches[]` by index, performs
HTTP fetches (slow, outside lock), then writes results back under `AGG_LOCK()`. If a
delete compacts the array during the fetch, the poll task writes data to the wrong slot
(index shifted) or a removed satellite.

**Solution:** Added `satellite_config_generation` counter (incremented under `AGG_LOCK()`
on every add/delete/reset). The poll task snapshots `{id, base_url, generation}` under
lock before fetching. After fetch, re-acquires lock and verifies generation matches before
writing results. If generation changed, discards fetched data (logs warning) and re-reads
on next cycle.

**Trade-off:** Discards one poll cycle of data on config change. Acceptable because config
changes (add/delete) are rare human-initiated operations, not high-frequency events.

---

### LESSON-OPS-107 — NVS save failure after delete is a known limitation (2026-04-02)

**Context:** After DELETE compacts the satellite array and decrements
`runtime_satellite_count`, the deferred NVS save may fail (flash error, task creation
failure). If NVS is not updated, the deleted satellite reappears after reboot (NVS still
has the old config).

**Status:** Accepted known limitation for v7.6.0.2. Rollback after compaction is
impractical — would require re-inserting the deleted entry at its original position and
re-expanding the array. The deferred snapshot pattern minimizes but cannot eliminate this
window. A future improvement could retry NVS writes or add a "dirty" flag checked at boot.

---

### LESSON-OPS-108 — handleRequest() GET fallthrough has no method guard (2026-04-02)

**Context:** In AsyncWebServer handlers, `handleRequest()` typically has a series of early-return
method guards (`if (request->method() == HTTP_DELETE) { ... return; }`), followed by a "fallthrough"
section that assumes the method is GET. If any DELETE/POST/OPTIONS check is missing from `canHandle()`,
the request falls through to the GET section, which sends a generic 404 or attempts to serve a GET
resource, producing confusing behavior.

**Rule:** Every `handleRequest()` method should have explicit method guards for ALL supported methods
before the GET fallthrough section. If a method is checked in `canHandle()` but the corresponding
dispatch is missing or out-of-order in `handleRequest()`, the request will reach the GET fallthrough
and produce incorrect responses.

**Diagnostic signature:** Plain-text 405 responses (not JSON) indicate `canHandle()` returned false,
so the request never reached the handler. See LESSON-OPS-109.

---

### LESSON-OPS-109 — Plain-text 405 = canHandle() returned false (2026-04-02)

**Observation:** ESPAsyncWebServer (built on ESP-IDF httpd layer) sends plain-text 405 responses when
NO registered handler returns `true` from `canHandle()` for a given {method, path} combination. If the
handler sends JSON 405, it means `canHandle()` returned true but `handleRequest()` explicitly rejected
the method. If the handler sends **plain-text** 405, it means `canHandle()` returned false and the
request never reached the handler at all.

**Diagnostic rule:**
- **Plain-text 405:** Bug is in `canHandle()` (method/path check missing or incorrect)
- **JSON 405:** Bug is in `handleRequest()` (method dispatch logic)

**Example:** BUG-079 — DELETE to `/api/aggregator/satellite/{id}` returned plain-text 405 because
the `canHandle()` HTTP_DELETE check was missing, even though `handleRequest()` had proper DELETE
dispatch code.

---

### LESSON-OPS-110 — Prompt code snippets for endpoint handlers must include explicit auth policy (2026-04-03)

**Observation:** When a prompt replaces an existing stub handler with a new implementation,
omitting `authenticate_management_()` from the prompt's code block is a prompt defect that
coding agents will faithfully reproduce. The replaced stub's auth call is the authoritative
reference — if the replacement prompt omits it, the agent will drop it.

**Root cause (v7.6.0.3):** The `handle_test_satellite_()` prompt snippet did not include an
explicit auth decision. The agent produced an unauthenticated handler. Auth was added
during the Copilot review pass (`b43340c`), but the defect originated in the prompt.

**Rule:** From v7.6.0.4 onward, every endpoint handler code block in a prompt must include
an explicit auth decision in one of these forms:
```
Auth: REQUIRED — call authenticate_management_() before any logic
Auth: NOT REQUIRED — [one-sentence rationale]
```

**Corollary:** Destructive or topology-revealing management endpoints require auth.
Add/discovery endpoints may be open with documented rationale.

---

## LESSON-OPS-118 — Fragment boundary comments may reference adjacent-fragment symbols

**Date:** 2026-04-10
**Trigger:** v7.6.6.4 CHECKPOINT A false failure — `grep -c "s_cache_mutex" firmware/core/ping-adapter.h` returned 1 due to a documentation comment at lines 160–168 describing thread-safety for the aggregator-runtime section.

**Root cause:** When fragments are extracted via `sed -n` line ranges, documentation comments at section boundaries may reference symbols that belong to the next fragment. This is correct content — the monolith's byte-identical split includes these comments. A raw `grep -c` cannot distinguish comments from code usage.

**Rule:** All cross-fragment symbol leakage checks must strip comment lines before grepping:
```bash
grep -v '^\s*//' firmware/core/some-fragment.h | grep -c "symbol_name"
```

**Affected checks:**
- v7.6.6.4 CHECKPOINT A (cross-fragment leakage)
- v7.6.6.8 `mutex_single_owner` preflight check

**See also:** LESSON-OPS-097 (identity gate), Critical Rule 37 (pipeline ordering)

---

### LESSON-OPS-122 — Fragment architecture for sensor_history_multi.h (Phase Y)

**Date:** 2026-04-12
**Context:** The 4,325-line `sensor_history_multi.h` monolith was split into 8 source fragments in `firmware/core/` using Option B (assembled artifact). The committed `sensor_history_multi.h` is generated by concatenating fragments — the compiler sees a single translation unit.

**Key constraints:**
- Assembly concatenation order is the dependency order — never reorder fragments
- `s_cache_mutex` defined once in `aggregator-runtime.h` — visible to `web-handler.h` via assembly order
- All 4 deferred-task pairs have specific fragment homes — visibility guaranteed by assembly order
- Generator marker blocks have delimiter stubs in `data-model.h` — generator writes into assembled artifact only
- `maybe_yield_nvs_scan_()` defined once in `nvs-persistence.h` — called from `web-handler.h` via assembly order
- YAML `includes:` references only the assembled artifact — never fragment files

**Verification:** `assemble-sensor-history.sh --check` validates non-generated regions match. Preflight checks validate fragment count, deferred-task homes, mutex ownership, and yield function presence.

**See also:** Critical Rules 58–62, LESSON-OPS-118 (fragment boundary comments), build-pipeline.md LESSON-OPS-123.

---

### LESSON-OPS-125 — Reviewer inline suggestions break SHA-256 identity gate (Phase Y closure)

**Date:** 2026-04-12

**Problem:** During Phase Y v7.6.6.1, a reviewer bot (Gemini) posted an inline code suggestion for `aggregator-runtime.h` — a security fix for an `lwip_send` buffer over-read. The agent accepted the suggestion directly, which modified the fragment file. This was correct behaviour (the fix was valid), but it changed the SHA-256 hash of the assembled artifact, causing the identity gate to fail.

**Root cause:** Reviewer inline suggestions bypass the agent's implementation instructions. The agent applies them without checking whether the affected file is under an identity gate. For assembled-artifact architectures (Phase Y's fragment model), any change to a fragment file must be followed by `assemble-sensor-history.sh --write` and a fresh `--check` pass.

**Fix for prompts touching fragment files:** Add explicit guidance:
```
Do not accept inline code suggestions from reviewer bots for fragment files without re-running the assembly pipeline. The SHA-256 gate will fail on any unassembled change.
```

**Note:** The Gemini security fix was correct and was properly propagated. The lesson is about the *process* of accepting it, not the *content* of the fix.

**See also:** Critical Rules 58, 62 (fragment architecture guardrails), LESSON-OPS-122 (fragment architecture).

---

### BUG-083: C3 template YAML missing external_components - httpd stack override inactive since v7.6.8.0 (2026-04-20)

The `firmware/local_components/web_server_idf/` override that patches the httpd task
stack from 4 KB to 16 KB (BUG-076 fix) was never compiled into the C3 firmware.
The C3 template YAML (`firmware/esp32-c3-multi-sensor.yaml`) lacked the
`external_components` block that directs ESPHome to use the local override.

**Root cause:** `render_sensor_config.py` has two code paths:
- With `gateway.json` (WROOM, S3): `generate_board_yaml()` reads the board profile
  and emits `external_components`. Override active.
- Without `gateway.json` (C3 default): `render_yaml_file()` does in-place marker
  substitution only. `external_components` from the board profile is never read.

The board profile (`firmware/boards/esp32-c3-supermini.yaml`) has always had the
correct `external_components` entry. The C3 simply never goes through the code path
that uses it.

**Impact:** The C3 ran with 636 bytes of stack headroom (on a 4 KB stack) for 3+
months of Phase V. Any slightly deeper handler call chain could have caused a stack
overflow crash. WROOM and S3 had 13,000+ bytes headroom on 16 KB.

**Fix:** Add `external_components` block directly to the C3 template YAML. Add a
preflight guard to prevent recurrence.

**Diagnostic error:** The initial v7.6.9.5 analysis attributed the 20x watermark gap
to RISC-V vs Xtensa architecture differences (register windows). This was plausible
but wrong - actual peak usage is ~3,400 B on both architectures. The gap was
entirely caused by different stack sizes. See LESSON-OPS-128.

---
