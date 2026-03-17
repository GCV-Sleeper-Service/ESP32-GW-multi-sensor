# Session Log — 2026-03-17 — BUG-043 Firmware NVS Yield Fix

**Date:** 2026-03-17
**Base version:** v7.5.3.5
**No version bump** (firmware code fix + docs only; no API or interface changes)
**Related:** BUG-043, PR #39 (v7.5.3.5 dashboard mitigations)
**Strategy:** Split-PR — this PR covers firmware root-cause fix only; dashboard hardening is a separate follow-up PR

---

## Objective

Implement the firmware-side root-cause fix for BUG-043: add cooperative yielding in long NVS iteration loops in `dashboard/sensor_history_multi.h` to prevent HTTP task starvation.

Post-merge validation after PR #39 (v7.5.3.5) showed that even a single serialized history request can block the ESP32-C3 HTTP task long enough to starve BLE/WiFi/ESPHome API/watchdog work, causing:
- ESPHome API "unexpected disconnect" (360ms+ blocking warning in logs)
- Browser errors: `ERR_CONNECTION_RESET`, `502 Bad Gateway`, `500 Internal Server Error`
- Dashboard crash on open in SSE mode
- Dashboard crash on F5 in polling mode

---

## Root Cause (Firmware Side)

`sensor_history_multi.h` contains three functions that iterate over persisted NVS segment blobs in a tight loop with no `vTaskDelay()` between reads:

| Function | Loop bound | Risk |
|----------|-----------|------|
| `handle_history_()` | `meta.valid_segments` (up to 1080) | Per-request blocking during dashboard history load |
| `restore_from_nvs()` | `restore_segments` (up to RAM_SEGMENTS, ~24) | Boot-time blocking during restore |
| `build_import_epoch_map_()` | `meta.valid_segments` (up to 1080) | Import-time blocking |

Each `nvs_get_blob()` call in `load_snapshot_from_handle_()` is synchronous. With 1080 segments, a full scan can hold the HTTP server task for 0.5–2 seconds. No other tasks (BLE, WiFi, ESPHome API, watchdog) get CPU time during this window.

---

## Changes Made

### `dashboard/sensor_history_multi.h`

Added one new helper and three yield call sites:

**New helper (placed immediately before `load_snapshot_from_handle_()`):**
```cpp
// BUG-043 firmware fix: long NVS scan loops can block the ESP32-C3 HTTP task
// for hundreds of milliseconds, starving BLE/WiFi/API/watchdog-sensitive work.
// Yield to the FreeRTOS scheduler every NVS_SCAN_YIELD_INTERVAL iterations so
// other tasks (BLE, WiFi, ESPHome API) get CPU time during history reads.
static constexpr int NVS_SCAN_YIELD_INTERVAL = 4;
static void maybe_yield_nvs_scan_(int iteration) {
  if (iteration > 0 && (iteration % NVS_SCAN_YIELD_INTERVAL == 0)) {
    vTaskDelay(pdMS_TO_TICKS(1));
  }
}
```

**`restore_from_nvs()` loop:** yield every 4 segments during boot restore
```cpp
for (int n = 0; n < restore_segments; n++) {
  maybe_yield_nvs_scan_(n);  // BUG-043: yield every 4 blobs
  ...
}
```

**`build_import_epoch_map_()` loop:** yield every 4 segments during import epoch scan
```cpp
for (int i = 0; i < meta.valid_segments; i++) {
  maybe_yield_nvs_scan_(i);  // BUG-043: yield every 4 blobs
  ...
}
```

**`handle_history_()` loop:** yield every 4 segments during history streaming response
```cpp
for (int n = 0; n < meta.valid_segments; n++) {
  maybe_yield_nvs_scan_(n);  // BUG-043: yield every 4 blobs
  ...
}
```

### No changes to dashboard JS

This PR intentionally does NOT change:
- `dashboard/dashboard.js`
- `dashboard/dashboard.html`
- `dashboard/dashboard.h`
- Any polling schedules, boot sequencing, or request throttling

Those changes are reserved for the dashboard-hardening follow-up PR.

---

## Documentation Updated

- `Docs/changelog.md` — added firmware fix entry above v7.5.3.5 entry
- `Docs/bugs-and-lessons-learned.md` — updated BUG-043 status, added firmware root-cause fix section, updated Fix (continued) note, added LESSON-OPS-053
- `Docs/BUG-043-continued-fix-plan.md` — replaced "Future Work" section with "Split-PR Strategy" documenting what was implemented and what remains for PR 2
- `Docs/session-log-2026-03-17-BUG-043-firmware-nvs-yield.md` — this file

---

## Version Bump Decision

No version bump. Reasons:
1. User preference is to avoid version changes unless necessary
2. This is a firmware code fix (no API changes, no interface changes, no generated artifact changes)
3. The version string in `sensor_history_multi.h` header comment is in the generated `HEADER_BEGIN/END` marker block — bumping would require full `bump-version.sh` run and regeneration of all artifacts, which is out of scope for a focused firmware fix
4. The changelog entry documents the change clearly

---

## Validation Steps

### Pre-flash (code inspection)
- [x] `maybe_yield_nvs_scan_()` is defined before first use
- [x] FreeRTOS headers (`freertos/FreeRTOS.h`, `freertos/task.h`) already included at lines 79–80
- [x] `vTaskDelay`/`pdMS_TO_TICKS` already used elsewhere in the file (lines 955, 1222)
- [x] All three yield sites are in the correct loop bodies, not outside
- [x] No dashboard JS files changed

### Post-flash real-device validation checklist
1. **SSE mode — fresh open:**
   - [ ] Dashboard opens without crash
   - [ ] No `api took a long time` warnings > 100ms during history load
   - [ ] No ESPHome API disconnect during or after history load
2. **SSE mode — F5 after history loaded:**
   - [ ] No crash on refresh
   - [ ] `History load already in flight — skipping` if F5 during load
3. **Polling mode — fresh open:**
   - [ ] No crash on first open
   - [ ] Heap stable (no oscillation below 60K)
4. **Polling mode — F5 after ~3 min:**
   - [ ] No crash
5. **Device logs:**
   - [ ] No `component took a long time for an operation (>100ms)` during history reads
   - [ ] No `httpd_accept_conn: error in accept (23)`
   - [ ] Free heap stable at ~72K when dashboard idle
6. **Browser DevTools:**
   - [ ] `/history/{id}/temp` and `/history/{id}/hum` return 200 (not 500/502)
   - [ ] No `ERR_CONNECTION_RESET` during history load

---

## Handoff Notes for Dashboard Hardening PR

The second follow-up PR should consider:
- Making `pollAll()` support a fully sequential mode (batch size 1 with no `Promise.all`)
- Increasing inter-sensor gap in `loadHistory()` from 300ms to 500ms or more
- Deferring `loadStatusSnapshot()` in SSE mode or removing it from boot (SSE `state` events already deliver state)
- Further deferring storage stats (from 3s to 5–6s)
- Ensuring `_historyInFlight` guard is reset correctly on all error paths

See also: `Docs/BUG-043-continued-fix-plan.md` — "Future Work (dashboard hardening — PR 2, pending)"
