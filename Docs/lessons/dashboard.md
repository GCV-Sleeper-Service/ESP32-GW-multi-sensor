# Lessons — Dashboard

_Split from Docs/bugs-and-lessons-learned.md at v7.6.4.0._

## Bug Fixes

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


---

### BUG-011: Non-JSON server response crashed import error handling (v7.4.0)

**Fix:** Added safer text-first JSON response handling.

---


---

### BUG-012: Single-sensor export schema mismatch (v7.4.0.1)

**Fix:** Standardized on prefixed column headers for all export formats.

---


---

### BUG-013: Import over Cloudflare returned HTTP 502 (v7.4.0.1)

**Fix:** Suspend non-essential background activity during import and add pacing/backoff.

---


---

### BUG-014: Single-sensor import erased all flash data (v7.4.0.2)

**Fix:** Added `POST /api/import/begin/single/<id>` and merge-first behavior.

---


---

### BUG-015: Single-sensor import "Unknown sensor ID" — off-by-one in URL path parsing (v7.4.0.2)

**Fix:** Corrected prefix length comparison and pointer offset. Prefer `sizeof("literal") - 1` over hand-counted lengths.

---


---

### BUG-018: Duplicate `<script>` tag caused `Unexpected token '<'` dashboard failure (v7.4.2.0)

**Fix:** `sed -i '859d' dashboard/dashboard.html`. Prevention: use `head -n $((SCRIPT_LINE - 1))`, not `head -n $SCRIPT_LINE`. Verify with `grep -c '^<script>$' dashboard/dashboard.html` — must return `1`.

---


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


---

### BUG-022: `package-lock.json` not committed — CI failed on `npm ci` (v7.4.3.0)

**Symptom:** Browser CI job failed immediately: `Dependencies lock file is not found`.

**Fix:** `npm install` on device, then `git add package-lock.json && git commit`.

**Lesson:** See LESSON-OPS-024.

---


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


---

### BUG-025: Fixture generate-fixtures.js used milliseconds for CSV timestamps (v7.4.4.0)

**Symptom:** Sensor-count variant fixtures would render completely empty charts. No error — just no data points.

**Root cause:** `Date.UTC()` returns epoch milliseconds. The dashboard's chart renderer calls `new Date(epoch * 1000)` — interpreting the value as seconds. A millisecond timestamp gets multiplied by 1000, producing dates in year ~58000, which fall outside any time range filter and are silently dropped.

**Fix:** Use epoch seconds throughout `generate-fixtures.js`. Anchor to `ANCHOR_EPOCH_SEC = 1741694400`.

**Lesson:** See LESSON-OPS-029.

---


---

### BUG-029: Session-level import design details were not propagated into the durable docs (v7.4.5.0)

**Symptom:** The repo behavior for single-sensor merge import existed in firmware and dashboard logic, but the high-value explanation — epoch-to-slot mapping, overlay of one sensor into an existing segment, reuse of the same slot when possible, and ~7 KB temporary overhead — was not consistently carried into changelog and handoff documentation.

**Root cause:** Documentation captured the user-visible feature but not enough of the internal design rationale.

**Fix:** Expanded changelog, `Docs/configuring-sensors.md`, and the per-session handoff to explicitly describe the merge-first single-sensor import model and how it differs from full multi-sensor replacement.

**Lesson:** See LESSON-OPS-036.

---


---

### BUG-030: Manifest validation normalized MACs by mutating caller data in place (v7.4.5.1)

The original validation helper silently normalized MAC addresses inside the caller-provided list.

**Fix:** manifest validation is now side-effect free. Canonicalization is explicit through `canonicalize_sensors()`, and save/load/render flows use normalized copies rather than mutating input objects.

---


---

### BUG-032: Multi-sensor CLI restore could erase retained history without an explicit confirmation prompt (v7.4.5.1)

The first v7.4.5.0 CLI backup/restore helper correctly routed merged CSVs through the existing erase-first `/api/import/begin` path, but it did so without an explicit operator confirmation.

**Fix:** `scripts/history_backup.py import` now prompts before erase-first multi-sensor import unless `--yes` is provided, and it also supports `--single-sensor <id>` to intentionally force the merge route from a merged CSV.

---


---

### BUG-033: Phase 1 patch script failed against compacted one-line source blocks (v7.5.0.0)

**Symptom:** `scripts/apply_phase1_manifest_patch.py` failed repeatedly when targeting `dashboard/sensor_history_multi.h`. Exact-string matches could not find their targets, even when the content appeared visually correct.

**Root cause:** The header file uses compacted one-line formatting for several function bodies and handler blocks. Patch scripts that matched on long multi-line strings or comment text failed when those strings had been compacted into a single line.

**Fix:** Rewrote the patch approach to use function-anchor detection, regex-based matching, and brace-aware block insertion rather than exact long-string matching. Going forward, this is a known constraint of the codebase.

**Lesson:** See LESSON-OPS-039.

---


---

### BUG-034: `render_sensor_config.py` crashed with `re.PatternError: bad escape \x` on generated content (v7.5.0.0)

**Symptom:** Running `python3 scripts/render_sensor_config.py --write` raised `re.PatternError: bad escape \x at position N` during the replacement phase for generated strings containing Unicode escape sequences like `\xC2\xB0` (the degree symbol).

**Root cause:** Generated replacement text was passed directly to `re.sub()` in string replacement mode. Python's `re.sub` interprets backslash sequences in the replacement string as regex back-references or escapes. `\xC2\xB0` was not a valid regex escape, causing the error.

**Fix:** Changed all `re.sub()` calls for generated content to use lambda/function replacements. In lambda mode, the replacement value is treated as a literal string, so backslash sequences in generated output are not interpreted.

**Lesson:** See LESSON-OPS-039.

---


---

### BUG-037: Built-in ESPHome diagnostics disappeared from the built-in web page after Phase 1 (v7.5.0.1)

**Symptom:** The ESPHome built-in web page no longer showed Free Heap, Uptime, or Loop Time after Phase 1 firmware changes.

**Root cause:** The `debug.free`, `debug.loop_time`, and `uptime` sensor blocks were removed or were missing from `firmware/esp32-c3-multi-sensor.yaml` during Phase 1 YAML changes.

**Fix:** Restored `debug.free`, `debug.loop_time`, and `uptime: type: seconds` blocks in the YAML. Confirmed both the custom dashboard and the built-in ESPHome page show all three diagnostics after reflash.

**Lesson:** See LESSON-OPS-044.

---


---

### BUG-038: Dashboard Free Heap and Uptime showed "loading…" after Phase 1 OTA (v7.5.0.1)

**Symptom:** After flashing Phase 1 firmware, `/api/manifest` and `/api/status` both responded correctly, but the dashboard displayed `loading...` indefinitely for Free Heap and Uptime.

**Root cause:** The dashboard still expected `/sensor/Free Heap` and `/sensor/Uptime` — legacy entity-polling paths that the firmware no longer provided as ESPHome entities. The authoritative data was already available from `GET /api/status` but the dashboard code was not reading from it.

**Fix:** Switched all dashboard device-status widget hydration to `GET /api/status`. Removed dependency on legacy entity-polling paths for those values.

**Lesson:** See LESSON-OPS-042.

---


---

### BUG-039: Dashboard source and generated artifacts drifted after Phase 1 work (v7.5.0.1)

**Symptom:** `dashboard.html` was updated during Phase 1 manifest work but `dashboard.min.html` and `dashboard.h` were not regenerated. The embedded firmware payload still ran stale client logic — manifest-first boot and `/api/status` hydration were absent from what actually flashed.

**Root cause:** The workflow assumed edits to `dashboard.html` would propagate automatically. They do not — the minification and header-embedding steps must be run explicitly after every source edit.

**Fix:** Patched `dashboard/dashboard.html` directly as the source of truth, then regenerated `dashboard.min.html` and `dashboard.h` from that corrected source. Kept `dashboard.js` aligned to the same runtime logic.

**Lesson:** See LESSON-OPS-043.

---


---

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


---

### BUG-046 — Stale NVS `HistoryMeta` never overwritten after `num_sensors` schema correction (2026-03-19)

**Date:** 2026-03-19
**Version observed:** v7.5.4.0 (devices that received the temporary `NUM_SENSORS=4` build)
**Status:** FIXED

**Symptom:** Devices that were flashed with the temporary bad `NUM_SENSORS=4` build
(BUG-045) continued to log on every boot:

```
[W][history:674][httpd]: history meta invalid or schema mismatch — resetting
```

Even after the BUG-045 code fix restored `NUM_SENSORS = NUM_ENV_SENSORS = 3`, devices
with stale `hist_meta` NVS blobs (written with `num_sensors=4`) never recovered. Dashboard
history remained empty indefinitely unless the user manually erased history.

**Root cause:** `load_history_meta_()` detected the `num_sensors` mismatch and reset the
in-memory `HistoryMeta` to defaults, but never persisted the corrected metadata back to NVS.
`restore_from_nvs()` opened NVS read-only and exited early when `load_history_meta_()` returned
false, so the stale blob was never overwritten. The mismatch repeated on every boot.

**Fix:**
- Modify `load_history_meta_()` to distinguish recoverable stale `num_sensors` mismatch from
  true corruption. When `magic`, `version`, `points_per_series`, and `points_per_segment` all
  match current expectations, only `num_sensors` differs — this is the known recoverable case
  from BUG-045. Correct `num_sensors` in-place and preserve valid segment bookkeeping.
- Add a `bool *needs_nvs_persist` output parameter so callers know the corrected meta must be
  saved back to NVS.
- In `restore_from_nvs()`, after loading meta, check `needs_nvs_persist`. If true, close the
  read-only handle, reopen read-write, save the corrected metadata, and close. Then reopen
  read-only for the snapshot restore loop.
- For true corruption, also persist the default metadata to break the stale-meta loop.
- Add explicit log messages distinguishing migration from corruption from successful persistence.
- Dashboard: add per-sensor catch in `fetchAllSensorHistoryRowsSequentially` and guard
  `buildMergedSensorCsv` against undefined/null row entries to prevent uncaught errors when
  history is temporarily empty after migration.

**Prevention:** LESSON-OPS-060 (see below).

Related: BUG-045, LESSON-OPS-060

---


---

### BUG-048 — NVS `SegmentSnapshot` blobs from `NUM_SENSORS=4` period physically incompatible with corrected firmware (2026-03-19)

**Date:** 2026-03-19
**Version observed:** v7.5.4.0 (post-BUG-046 fix — history loads only 36 points instead of full retained history)
**Status:** FIXED

**Symptom:** After merging the BUG-046 meta migration fix (PR #53), the dashboard loads history
but only shows ~36 data points (approximately 9 hours of new data collected since the fix).
Previously retained 45-day ThermoPro history is missing. The firmware no longer logs the
"schema mismatch — resetting" loop, but the full history is not recovered.

**Root cause:** The BUG-046 fix correctly migrated the `HistoryMeta` blob (correcting `num_sensors`
from 4 to 3 and persisting it). However, the individual `SegmentSnapshot` blobs written to NVS
during the buggy `NUM_SENSORS=4` period have a **physically different byte size** because the
struct contains fixed-size arrays dimensioned by `NUM_SENSORS` at compile time:

```
// With NUM_SENSORS=4: sizeof(SegmentSnapshot) ≈ 298 bytes
HistEntry temp[4][PERSIST_POINTS_PER_SEGMENT]
HistEntry hum[4][PERSIST_POINTS_PER_SEGMENT]
uint16_t temp_counts[4]
uint16_t hum_counts[4]

// With NUM_SENSORS=3: sizeof(SegmentSnapshot) ≈ 230 bytes
HistEntry temp[3][PERSIST_POINTS_PER_SEGMENT]
HistEntry hum[3][PERSIST_POINTS_PER_SEGMENT]
uint16_t temp_counts[3]
uint16_t hum_counts[3]
```

When `nvs_get_blob()` tries to read a 298-byte blob into a 230-byte buffer, ESP-IDF returns
`ESP_ERR_NVS_INVALID_LENGTH`. The blob is never read, and `load_snapshot_from_handle_()` returned
`false` silently — no log message indicated the real failure mode.

The restore loop in `restore_from_nvs()` attempted to load all `meta.valid_segments` slots
(which included ghost references to the incompatible blobs), skipped them all, and only found the
few new segments written after the fix. The meta was never recalibrated to reflect the reduced
valid segment count, so every subsequent boot repeated the same futile load attempts.

**Fix:**
- `load_snapshot_from_handle_()`: added diagnostic logging when `nvs_get_blob()` returns
  `ESP_ERR_NVS_INVALID_LENGTH`, identifying the stored-vs-expected byte size and referencing
  BUG-048.
- `restore_from_nvs()`: after the restore loop, if `skipped_size_mismatch > 0` and
  `restored < restore_segments`, recalibrate `meta.valid_segments` to match only the
  actually-restorable segment count. Persist the recalibrated meta back to NVS so that:
  - Subsequent boots don't waste time retrying unloadable slots
  - The restore window targets only readable segments
  - Future `persist_hourly_segment()` calls correctly grow `valid_segments` from the
    recalibrated baseline as new compatible segments are written

**Impact:** The history lost during the `NUM_SENSORS=4` period is **unrecoverable** — the blobs
are physically a different size and cannot be deserialized into the current struct layout without
a complex cross-schema converter. The recalibration ensures the system recovers cleanly and
begins accumulating new history from a known-good baseline. Users who need the old data should
use the CSV export they took before the v7.5.4.0 flash (if available) and re-import via the
single-sensor merge import.

**Prevention:** LESSON-OPS-061 (see below). Also: the v7.5.4.0 implementation prompt now includes
an explicit acceptance criterion verifying that `sizeof(SegmentSnapshot)` has not changed.

Related: BUG-046, BUG-045, LESSON-OPS-061, LESSON-OPS-060

---


---

### BUG-049 — Firefox Playwright Group 13 tests fail: SSE teardown timeout + slow boot (2026-03-19)

**Date:** 2026-03-19
**Version observed:** v7.5.4.0
**Status:** FIXED

**Symptom:** Two Firefox-only failures in Group 13 (Manifest-driven history fetching):
- Test 137 (`fetchDeviceHistory is a callable function`): All assertions pass. Failure occurs in
  teardown — `browserContext.close()` hangs for 48.9s waiting for the SSE `EventSource` TCP
  connection to close, exceeding the 30s test timeout.
- Test 138 (`App.API.fetchDeviceHistory is exported`): `waitForDashboardReady()` times out at
  15s waiting for `.sensor-card` to become visible. Firefox's slower event loop means the
  dashboard boot sequence (manifest fetch → card render → DOM paint) takes longer than Chromium.

**Root cause:** Firefox's Gecko engine holds SSE TCP connections open during `browserContext.close()`
if EventSource callbacks (`onopen`, `onerror`, `onmessage`) are still attached. The existing
`stopDashboardNetwork()` called `evtSource.close()` but did not null out the callbacks first.
Additionally, Group 13 used the default 15s `loadDashboard()` timeout, insufficient for Firefox's
slower rendering pipeline.

**Fix:**
- `stopDashboardNetwork()` in `dashboard.spec.js`: null out `onopen`, `onerror`, `onmessage`
  before calling `.close()` on `EventSource`.
- `suspendDashboardNetworkActivity()` in `dashboard.js` and `dashboard.html`: same callback-
  nulling pattern applied to production code (LESSON-OPS-043 mirror).
- Group 13 `test.describe()`: added `test.setTimeout(90000)` for Firefox SSE teardown headroom.
- All Group 13 `loadDashboard()` calls: increased timeout to `{ timeout: 30000 }`.

**Prevention:** LESSON-OPS-062 (see below).

Related: LESSON-OPS-062, LESSON-OPS-043

---


---

### BUG-052 — `/sensors.json` v1 projection includes non-environmental devices (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.4
**Status:** FIXED (v7.5.4.5)

**Symptom:** `curl /sensors.json` returned 4 entries including `wan_ping`. The architecture plan (Section 5.3) specifies `/sensors.json` as a v1 compatibility projection containing only environmental sensors.

**Root cause:** `handle_manifest_()` (which serves `/sensors.json`) iterated `NUM_DEVICES` without filtering by category. When `wan_ping` was added in v7.5.4.0, `NUM_DEVICES` became 4 but the handler was not updated. The dashboard's fallback path (`/sensors.json` → auto-promote to v2 with ThermoPro defaults) would incorrectly treat `wan_ping` as a ThermoPro sensor.

**Why not caught:** Phase 4 prompts focused on the new code (adapter, card renderer, tests) but did not include a checkpoint for existing endpoints like `/sensors.json`. The Playwright test fixture for `sensors.json` already had only 3 entries (correct), so tests passed even though the real firmware returned 4.

**Fix:** `handle_manifest_()` now skips devices with `category_id != 0` (non-environmental).

**Prevention:** LESSON-OPS-064.

---


---

### BUG-054 — Calendar date picker dark/light mode CSS issues (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.4
**Status:** FIXED (v7.5.4.5)

**Symptom — dark mode:** Native browser date picker calendar popup (triggered by clicking the calendar icon on `<input type=date>`) rendered with a white background. Time `<select>` dropdowns also had browser-default white backgrounds.

**Symptom — light mode:** From/To date input fields and time select dropdowns had hardcoded dark backgrounds (`rgba(15,23,42,.5)`) making text unreadable. Modal buttons also dark.

**Root cause:** The CSS for `.cr-time-row input[type=date]` and `.cr-time-row select` used hardcoded dark-theme colors with no `color-scheme` property and no `:root.light` overrides. The `color-scheme` CSS property tells the browser to render native widgets (date pickers, selects) in light or dark mode — without it, browsers default to their light variant regardless of page theme.

**Fix:** Added `color-scheme:dark` to date/select inputs in default (dark) theme. Added `:root.light` CSS overrides that set white backgrounds, appropriate text colors, and `color-scheme:light`.

---


---

### BUG-056 — WAN Latency ping data appears on Temperature/Humidity charts (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.4
**Status:** FIXED (v7.5.4.5)

**Symptom:** The WAN Latency device appeared as a flat line on both the real-time and
15-minute average Temperature and Humidity charts. Ping latency (~5ms) plotted as ~5°C,
success rate (100%) plotted as 100% humidity.

**Root cause — multi-layer failure across dashboard and firmware:**

1. **`mkDS()` created chart datasets for ALL sensors.** `SENSORS.map()` generated one dataset
   per entry in SENSORS, including the `wan_ping` network device (dataset index 3). The
   temperature/humidity charts are environmental-only — network devices should not have datasets.

2. **`applyHistoryRange()` used SENSORS array index as dataset index.** With SENSORS containing
   `[office(0), first_floor(1), outside(2), wan_ping(3)]`, `wan_ping` at `idx=3` would write
   to `datasets[3]` which was the dataset created in step 1.

3. **`fetchDeviceHistory()` fallback fetched wrong data.** The manifest's global `metrics[]`
   only defines `temp` and `hum`. When looking up `wan_ping`'s measurements (`ping_ms`,
   `success_pct`) against global metrics, no match was found → `historyMeasurements` was empty
   → the fallback triggered: `[{key:'temp', url:'/history/wan_ping/temp'}, {key:'hum', url:'/history/wan_ping/hum'}]`.

4. **Firmware legacy `/history/{id}/temp` handler returned ping data.** `handle_history_()`
   matched `wan_ping` by device ID, then mapped `temp` → `metric_states[0]` (the ping_ms
   HistoryBuffer) and `hum` → `metric_states[1]` (the success_pct HistoryBuffer). These
   buffers contained real ping data, which was returned as if it were temperature/humidity.

5. **`loadHistory()` stored this data as temp/hum.** The received CSV was stored in
   `ensureHistoryStore('wan_ping').temp` and `.hum`, which `applyHistoryRange()` then
   plotted on the environmental charts.

**Fix — six changes across three files:**

| File | Change |
|------|--------|
| `dashboard/dashboard.js` + `.html` | `applySensorMeta()`: assign `s.chartIdx` (0,1,2,... for environmental, -1 for others) |
| `dashboard/dashboard.js` + `.html` | `mkDS()`: filter to `s.chartIdx >= 0` before creating datasets |
| `dashboard/dashboard.js` + `.html` | `handleState()`: guard chart push with `s.chartIdx >= 0`, use `s.chartIdx` not `idx` |
| `dashboard/dashboard.js` + `.html` | `applyHistoryRange()`: skip `s.chartIdx < 0`, use `s.chartIdx` not `idx` |
| `dashboard/dashboard.js` + `.html` | `loadHistory()`: skip non-environmental sensors entirely |
| `sensor_history_multi.h` | `handle_history_()`: 404 for non-environmental devices on legacy `/history/{id}/temp\|hum` |

**Why not caught in Phase 4:**
- The v7.5.4.2 prompt (network card renderer) correctly identified that network devices need
  a separate data path (`/api/v2/live` polling). But it did not address the chart side — it
  stated "chart support comes in a later step" and "chart rendering excluded for network device."
  This prevented chart *canvases* from being added to network cards, but did not prevent the
  existing environmental charts from including network device datasets.
- The v7.5.4.3 prompt (tests) tested that chart canvases exist for environmental devices but
  did not assert that chart datasets exclude non-environmental sensors.
- The v7.5.4.2 change to include all categories in SENSORS (removing the environmental-only
  filter) was the correct architectural direction, but the chart code was not updated to
  account for the expanded SENSORS array.

**Prevention:** LESSON-OPS-064 (endpoint audit) applies here to chart code as well.
When expanding SENSORS to include non-environmental devices, audit ALL code that iterates
SENSORS with index-based dataset access.

---


---

### BUG-063 — Proxy endpoint served truncated history as HTTP 200 (2026-03-24)

**Severity:** Data corruption (silent truncation)
**Introduced in:** v7.5.5.2 initial commit
**Fixed in:** v7.5.5.2 review fix

**Symptoms:** When a satellite's history response exceeded 32KB (the
`s_proxy_tmp` buffer size), `fetch_to_buffer()` filled the buffer and
stopped reading. The proxy returned the truncated data as HTTP 200,
causing dashboard charts to display incomplete datasets.

**Root cause:** No truncation detection after `fetch_to_buffer()`. The
function silently stops reading at the buffer limit.

**Fix:** Check `s_proxy_len >= sizeof(s_proxy_tmp) - 1` after fetch.
If true, return 502 with `{"error":"upstream_response_too_large","max_bytes":32768}`.

**Prevention:** Any proxy/relay endpoint that uses a fixed-size buffer
must check for truncation before serving the response.


---

### BUG-065 — Gateway cards rendered inside SENSORS section (2026-03-25)

**Severity:** Layout / architecture violation
**Introduced in:** v7.5.5.3
**Fixed in:** v7.5.5.3 hotfix

**Symptoms:** On the aggregator, gateway selector tabs and satellite device cards appeared inside the "SENSORS" collapsible section, mixed with local sensor cards. The SENSORS heading was visible above gateway content. Per the design principles, the Gateways section should be separate from and above the local Sensors section.

**Root cause:** `renderGatewaySelector()` inserted the tab bar before `#sensorGrid` using `insertAdjacentHTML('beforebegin')`. All aggregator render functions (`renderAllGatewaysSummary`, `renderGatewayDevices`, `renderSettingsPanel`) wrote to `sensorGrid.innerHTML`, overwriting local sensor content.

**Fix:** Added a new Gateways collapsible section (`#hdr-gateways` / `#body-gateways`) above the SENSORS section in `dashboard.html`, hidden by default. Contains `#gwSelectorContainer` for the tab bar and `#gwGrid` for gateway content. All aggregator render functions now target the new elements. `initAggregatorDashboard()` unhides the section. SENSORS section is reserved for local sensors only.


---

### BUG-066 — Remote satellite cards show "calculating..." for history min/max (2026-03-25)

**Severity:** Cosmetic / confusing UX
**Introduced in:** v7.5.5.3
**Fixed in:** v7.5.5.3 hotfix

**Symptoms:** When viewing a per-gateway satellite tab on the aggregator dashboard, environmental sensor cards showed "temp: calculating... / hum: calculating..." in the min/max sections, forever.

**Root cause:** The environmental card renderer includes min/max placeholders that are populated by `loadHistory()`, which fetches from local endpoints only. No proxy history fetch exists for remote satellite data. The placeholders were never updated.

**Fix:** After rendering remote satellite cards in `renderGatewayDevices()`, replace all `.minmax-line .waiting` elements with "—" and hide the range toggle buttons. Proxy history fetch is a planned future feature.


---

### BUG-067 — C3-specific content displayed on non-C3 boards (2026-03-25)

**Severity:** Cosmetic / design principle violation
**Introduced in:** v7.5.5.3 (incomplete `updateBoardInfo()`)
**Fixed in:** v7.5.5.3 hotfix

**Symptoms:** On the S3 aggregator, the About card showed "ESP32-C3 SuperMini Gateway" as the title, displayed the C3 board SVG photo, the C3 GPIO pinout table, and the ThermoPro-specific description paragraph. All of this content is irrelevant to an ESP32-S3 device.

**Root cause:** `updateBoardInfo()` only hid the C3 SVG pinout image (`#pinoutDiagram`). The title text, GPIO pinout card, and description paragraph had no `id` attributes and were not conditionally hidden.

**Fix:** Added `id` attributes (`gpioCard`, `aboutCardTitle`, `c3DescriptionBlock`) to the hardcoded C3 content in `dashboard.html`. Extended `updateBoardInfo()` to hide the GPIO card and description, and replace the title with the board's actual name from the manifest.

**Prevention:** LESSON-OPS-074. Principle 4: Board content correctness — the dashboard must never show information from a different board.


---

### BUG-068 — Manifest `gateway.hardware` hardcoded to "ESP32-C3" regardless of board (2026-03-25)

**Severity:** Functional — breaks board-aware About card (BUG-067 fix depends on this)
**Introduced in:** `sensor_manifest_lib.py` `manifest_v2()` defaults
**Fixed in:** v7.5.5.3 hotfix-2

**Symptoms:** `curl /api/manifest` on the S3 aggregator returned `"hardware": "ESP32-C3"`. The `updateBoardInfo()` function (BUG-067 fix) checks this field to hide C3-specific content. With the wrong hardware string, C3 About card title, GPIO pinout, and description were still visible on the S3.

**Root cause:** `manifest_v2()` in `sensor_manifest_lib.py` has a hardcoded default `gateway_meta` with `"hardware": "ESP32-C3"`. Neither `generate_gateway_manifest_h()` nor the fixture generation in `render_sensor_config.py` passed a board-aware `gateway_meta`. The board profile's `chip_variant` field (e.g., `"esp32s3"`) was never mapped to the manifest.

**Fix:** `render_sensor_config.py` now builds `gateway_meta` from the board profile (`chip_variant` → human-readable hardware string via lookup table), gateway config (`friendly_name`, `esphome_name`), and aggregator config (`role`). This `gateway_meta` is passed to both `manifest_v2()` and `generate_gateway_manifest_h()`.

**Prevention:** When adding a new generated field that varies by deployment, verify it flows from the config source (board profile, gateway.json) through the generator to the output artifact. Hardcoded defaults should only apply when no config is present.


---

### BUG-069 — Environmental chart sections visible with no environmental sensors (2026-03-25)

**Severity:** UX confusion
**Introduced in:** Dashboard design (always present)
**Fixed in:** v7.5.5.3 hotfix-2

**Symptoms:** On the S3 aggregator with only WAN ping as a local sensor, the Temperature Real Time, Humidity Real Time, Temperature 15M Avg, and Humidity 15M Avg chart sections all displayed with "waiting for sensor data..." forever. These charts only make sense when environmental sensors (ThermoPro) are configured locally.

**Root cause:** The chart sections are hardcoded in `dashboard.html` and always visible. `initCharts()` creates the chart objects unconditionally. No check exists for whether any environmental sensors are present.

**Fix:** After `initCharts()` in the boot path, check `SENSORS.some(s => s.category === 'environmental')`. If false, hide `#hdr-realtime`, `#body-realtime`, `#divider-charts`, `#hdr-averages`, `#body-averages`. Added `id` attributes to these HTML sections to enable targeting.


---

### BUG-071 — Aggregator `aggregator-live.json` used JSON string for `live` field (2026-03-25)

**Severity:** Test authoring error (caught in development)
**Introduced in:** v7.5.5.4 initial fixture draft (following prompt example literally)
**Fixed in:** v7.5.5.4

**Symptoms:** `_populateGatewayDeviceLive()` returned early without populating live values; environmental and network cards stayed in "waiting" state.

**Root cause:** The prompt example showed `"live": "{\"timestamp\":...,\"devices\":{...}}"` (JSON string). The actual code checks `gwLive.live.devices` directly — it does NOT parse a JSON string. A JSON string has `.devices === undefined`, causing the early return guard to trigger.

**Fix:** Changed `aggregator-live.json` fixture to use `"live": { "timestamp": ..., "devices": {...} }` (JSON object, not string).


---

### BUG-074 — Aggregator manifest buffer truncation produces broken JSON (v7.5.7.0)

**Symptom:** `/api/aggregator/gateways` returns invalid JSON when a satellite has a manifest exceeding 4095 bytes. The dashboard fails to render the gateway's device list.

**Root cause:** `SatelliteCache.manifest_json` was a 4096-byte buffer. `fetch_to_buffer()` silently truncates responses exceeding `buf_size - 1`. The truncated (invalid) JSON was embedded verbatim in the `/api/aggregator/gateways` response, breaking the entire JSON document.

**Detection:** The truncation was invisible — no log message, no error return. The only symptom was dashboard malfunction when a satellite with 5+ sensors was polled.

**Fix:** (1) Increased `manifest_json` and `s_fetch_tmp` to 8192 bytes via `AGG_MANIFEST_BUF_SIZE` constant. (2) Added truncation detection guard in `handle_aggregator_gateways_()`: if `manifest_len >= AGG_MANIFEST_BUF_SIZE - 1`, emit `"manifest":null` and log a warning instead of embedding the truncated JSON.

**Prevention:** LESSON-OPS-085: When embedding fetched content into a composed JSON response, always validate that the content was not truncated before embedding. Buffer-size assumptions are especially dangerous for variable-length content like manifests that grow as sensors are added.

## BUG-073 — `buildNetworkCard()` XSS via unescaped `target` string (fixed v7.5.6.4)

### Symptom

The `source.target` field from the manifest (e.g. `"8.8.8.8"`) was inserted into
the network card HTML without HTML escaping. A malicious manifest could inject
HTML/script tags via this field.

### Root Cause

`buildNetworkCard()` used `target` directly in the innerHTML string without calling
`escHtml()`. The `description` in `buildSystemCard()` already used `escHtml()`
(correct), but `target` in the network card did not.

### Fix (v7.5.6.4)

Changed `'>' + target + '</div>'` to `'>' + escHtml(target) + '</div>'`.
Mirrored in both `dashboard.js` and `dashboard.html`.

## BUG-072 — `updateNetworkCards()` truthy check on `last_seen` (fixed v7.5.6.4)

### Symptom

When `last_seen` is `0` (epoch 0, valid timestamp), the last-seen display in the
network card would silently remain as `last: —` instead of showing the timestamp.

### Root Cause

`updateNetworkCards()` used a truthy check: `if (seenEl && devData.last_seen)`.
A `last_seen` value of `0` is falsy in JavaScript, so the display was not updated.

### Fix (v7.5.6.4)

Changed to strict null check: `if (seenEl && devData.last_seen != null)`.
Mirrored in both `dashboard.js` and `dashboard.html`.


---

### BUG-080 — Input fields cleared when clicking Test or Add in satellite configuration panel (v7.6.0.4 fixup)

**Symptom:** Typing a URL and friendly name into the satellite configuration inputs, then
clicking Test or Add, wiped both fields before the handler ran. The only workaround was to
click a neutral area of the page first to "commit" the focus, then click the button.

**Root cause:** The regression was caused by the satellite Settings panel being rebuilt
while a button-initiated workflow was still in progress, not by a fallthrough in the global
`document.addEventListener('click', ...)` router in `bindEvents()`. The panel already had an
existing re-render path via the aggregator live-poll watcher (`pollAggregatorLive()` →
`renderSettingsPanel()`), and the Settings tab's own click handling was therefore operating
against DOM that could be replaced underneath it. When `renderSettingsPanel()` rebuilt the
panel with fresh `innerHTML`, the active URL/name input elements were destroyed and
recreated, so the in-progress interaction observed cleared fields before the async
credential prompt could resolve.

**Fix (PR #128):** Added `e.stopPropagation()` as the very first statement in the `click`
event listeners for `sat-test-btn`, `sat-add-btn`, and each `.settings-btn-remove` button
inside `renderSettingsPanel()`. This prevents the click event from reaching the global
`bindEvents()` router, which addresses the immediate click-interaction case.

**Follow-up fix (PR #128 Copilot R2):** Added guards to the `pollAggregatorLive()` →
`renderSettingsPanel()` call path: the settings panel is now skipped when
`_satTestInFlight === true` (a satellite test is actively in progress) or when either
`sat-url-input` / `sat-name-input` has keyboard focus (the user is actively typing). This
addresses the 15-second periodic re-render case that `stopPropagation()` alone cannot
prevent.

**Files changed:** `dashboard/dashboard.js`, `dashboard/dashboard.html`, `dashboard/dashboard.h`

Related: BUG-081, LESSON-OPS-043, LESSON-OPS-111

---


---

### BUG-081 — Auth dialog resolves but no status update or network request fires (v7.6.0.4 fixup)

**Symptom:** After clicking Test in the satellite configuration panel and entering valid
management credentials in the auth dialog, the dialog dismissed correctly but nothing
further happened — no "Testing..." message, no success/failure result, no network
request visible in DevTools.

**Root cause:** `_handleTestSatellite(urlInput, statusEl)` used `statusEl` (a DOM element
reference captured at click time) inside `.then()` callbacks of
`requestManagementCredentials()`. If `pollAggregatorLive()` fired during the async wait
(auth modal open or network fetch in progress), `renderSettingsPanel()` replaced the
settings panel's `innerHTML`, detaching the original element. Assignments to a detached
element succeed in JavaScript but have zero visible effect on the rendered page.

**Fix (PR #128):** Renamed the URL input read to `capturedUrl` (a plain string), and
renamed `statusEl` to `capturedStatusEl` (a snapshot reference) to make the synchronous
capture intent explicit.

**Follow-up fix (PR #128 Copilot R1):** Replaced `capturedStatusEl` with fresh
`document.getElementById('sat-add-status')` re-queries at every write point inside the
async callbacks. If `pollAggregatorLive()` has rebuilt the panel in the meantime, the
new element in the live document is used — ensuring the status message is always
visible regardless of how many poll cycles have fired.

**Files changed:** `dashboard/dashboard.js`, `dashboard/dashboard.html`, `dashboard/dashboard.h`

Related: BUG-080, LESSON-OPS-043, LESSON-OPS-111

---


---

## Lessons Learned

### LESSON-OPS-009: Version strings live in six places

1. `VERSION`
2. YAML header comment
3. `register_history_handler()` version string
4. `dashboard_link` publish-state text
5. `App.version` in `dashboard.js`
6. Version comment/header in `dashboard.html`

When a version bump happens, update all six together.

---


---

### LESSON-OPS-014: `dashboard.h` shrinkage is the easiest signal that minification is active

If the generated header barely changed, the minified intermediate may not have been used.

---


---

### LESSON-OPS-018: Script block sync must use N-1, not N, for `head` cut

When syncing `dashboard.js` into the `<script>` block of `dashboard.html`, use `head -n $((SCRIPT_LINE - 1))`, not `head -n $SCRIPT_LINE`. After every sync, verify: `grep -c '^<script>$' dashboard/dashboard.html` must return `1`.

---


---

### LESSON-OPS-019: Minification savings are a correctness signal

After running `minify-dashboard.sh`, expected savings are ~30–35% of source size. If savings are below 10%, the script block was almost certainly doubled (embedded twice).

---


---

### LESSON-OPS-022: Always `grep` the actual HTML for element IDs before writing Playwright selectors

Never assume an ID from a variable name, comment, or context.

Specific gotchas in this codebase:
- Range button values are **hours**, not labels: 24, 168, 720, 1080, custom
- Export buttons use `data-export-all` and `data-export-sensor` attributes, not text matching
- Sensor names are raw text nodes inside `.sensor-card-header` — there is no `.card-title` class
- Export and sensor card elements are built dynamically — use `waitForFunction` before asserting them

---


---

### LESSON-OPS-028: Verify DOM behavior, not just element IDs (v7.4.3.0)

Verifying element IDs with `grep` is necessary but not sufficient. Three categories require runtime understanding:

1. **CSS class targets** — `toggleTheme()` applies `light` to `document.documentElement` (`<html>`), not `document.body`.
2. **Interaction side-effects** — `_onPreset()` calls `_applyAndClose()` immediately. A preset click closes the modal; there is no confirmation step.
3. **Container relationships** — chart canvases are in `.chart-card` divs, not inside `.sensor-card`.

Rule: before writing any Playwright assertion, read both the HTML and the JS handler for that element.

---


---

### LESSON-OPS-029: CSV fixture timestamps must be epoch seconds (v7.4.4.0)

The dashboard's history chart pipeline uses `new Date(epoch * 1000)` — it expects epoch **seconds** as integers from CSV files. `Date.UTC()` and `Date.now()` return **milliseconds** and must not be used directly as CSV timestamp values. See BUG-025.

---


---

### LESSON-OPS-031: DEFAULT_SENSOR_META in dashboard.js is a required consistency target (v7.4.4.0)

The `DEFAULT_SENSOR_META` array in `dashboard.js` is a fallback used when `/sensors.json` fails to load. It must match `NUM_SENSORS`. Preflight checks this explicitly.

---


---

### LESSON-OPS-033: Playwright in Docker/ESPHome containers requires --no-sandbox (v7.4.4.0)

Always add `launchOptions: { args: ['--no-sandbox', '--disable-setuid-sandbox'] }` to `playwright.config.js` when running in a container. The error `Target page, context or browser has been closed` immediately after browser launch is the signature of a sandbox crash. See BUG-026.

---


---

### LESSON-OPS-037: Design-level behavior needs to be documented, not just shipped (v7.4.5.0)

When a feature has a non-obvious internal model, preserve that model in durable documentation. The single-sensor import path is a good example: the useful fact is not only that it is "non-destructive," but *how* it works — epoch-to-slot scan, segment overlay, same-slot rewrite, new-slot allocation only for missing hours, and temporary memory overhead.

**Carry forward:** When a feature changes retained-history semantics, endpoint contract, or state-management design, record the internal mechanism in the changelog and session handoff, not only the user-facing label.

---


---

### LESSON-OPS-042: Dashboard device-status widgets should hydrate from `GET /api/status`, not entity polling (v7.5.0.1)

Do not rely on `/sensor/<entity-name>` paths for dashboard status fields. The firmware already exposes authoritative status data — version, uptime, free heap, sensor validity, storage settings — from `GET /api/status`. Entity-polling paths are implementation details of ESPHome's built-in web interface and may not be stable across firmware changes.

---


---

### LESSON-OPS-043: `dashboard.html` is the source of truth — regenerate artifacts after every edit (v7.5.0.1)

Edit order must always be:
1. Edit `dashboard/dashboard.html` (source of truth)
2. Run `bash ./scripts/minify-dashboard.sh` → produces `dashboard.min.html`
3. Run `bash ./scripts/generate-header.sh dashboard/dashboard.min.html dashboard/dashboard.h`

Editing `dashboard.js` alone is not sufficient. The script block inside `dashboard.html` must also be updated, and both the minified intermediate and the embedded header must be regenerated. A preflight rule should verify that `dashboard.h` reflects the current state of `dashboard.html`.

**Structurally resolved at v7.6.5.3.** `dashboard.html` is now a generated artifact
produced by `build-dashboard.sh`. There is no manual mirror to maintain. The failure
class described in this lesson can no longer occur.

---


---

### LESSON-OPS-044: Runtime validation must cover both the custom dashboard and the built-in ESPHome web page (v7.5.0.1)

Dashboard-only runtime checks can mask regressions in the built-in ESPHome diagnostics page. After any YAML change, verify:
1. The custom dashboard loads correctly and all status fields hydrate
2. The ESPHome built-in web page at `/` shows Free Heap, Uptime, and Loop Time

These are served from different code paths. One can regress without the other showing symptoms.

---


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


---

### LESSON-OPS-062: Firefox requires EventSource callbacks nulled before `.close()` to release the TCP connection (2026-03-19)

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


---

### LESSON-OPS-065: CSS for native browser widgets (`<input type=date>`, `<select>`) needs `color-scheme` (2026-03-21)

**Date:** 2026-03-21

Native HTML form elements like date pickers and select dropdowns are rendered by the browser,
not by your CSS. Setting `background` and `color` on them changes the input field appearance
but does NOT change the popup calendar or dropdown list appearance. The `color-scheme: dark`
CSS property tells the browser to render these native widgets in dark mode.

**Rule:** When building dark-mode UIs, always add `color-scheme: dark` to `<input type=date>`,
`<select>`, and other native form elements. Add `:root.light` overrides with `color-scheme: light`.

Related: BUG-054

---


---

### LESSON-OPS-078: Keep manifest tests shape-aware, not hard-coded to old metric sets

When categories/metrics are expected to grow over phases, assertions should verify
required subsets and invariants (e.g., environmental metrics must still exist)
instead of strict full-array equality to legacy values.

---


---

### LESSON-OPS-099: ESPHome IDF httpd only consumes x-www-form-urlencoded POST bodies (2026-03-30)

ESPHome's `web_server_idf` component only reads POST body bytes for
`Content-Type: application/x-www-form-urlencoded` and `multipart/form-data`.
For `application/json`, it logs "Unsupported content type for POST" and routes
to the GET handler path without consuming body bytes. Unconsumed bytes corrupt
socket state when the response is sent. All dashboard POST calls and curl POST
commands must use `Content-Type: application/x-www-form-urlencoded` with
`body: 'a=1'`. Codified as Critical Rules 38 and 39.

---


---

### LESSON-OPS-111 — Captured DOM references become stale across innerHTML re-renders (2026-04-04)

**Date:** 2026-04-04
**Scope:** Dashboard JS — async handlers, settings panel
**Trigger:** PR #128 Copilot review comments r3034831162, r3034831171

**Lesson:**
Capturing a DOM element reference before an async operation (e.g.,
`var el = document.getElementById(...)`) is unsafe if any code path can replace the
containing element's `innerHTML` before the async callbacks fire. The captured reference
remains a valid JS object but is detached from the live document; writes to `.textContent`
or `.classList` succeed silently with no visible effect.

**Rule:** In async callbacks that update UI status, always re-query by stable `id` at
write time:
```js
var liveEl = document.getElementById('known-stable-id');
if (liveEl) liveEl.textContent = '...';
```

**Companion rule:** Any periodic re-render (timer, poll loop) that replaces `innerHTML`
must guard against active user interaction (focused inputs, in-flight async state) before
tearing down the DOM:
```js
var urlInput  = document.getElementById('sat-url-input');
var nameInput = document.getElementById('sat-name-input');
var inputFocused = (document.activeElement === urlInput ||
                    document.activeElement === nameInput);
if (!_satTestInFlight && !_satAddInFlight && !_satRemoveInFlight && !inputFocused) {
  renderSettingsPanel(data.gateways);
}
```
See BUG-080/BUG-081 and the PR #128 follow-up for the full guard pattern.

---


---
