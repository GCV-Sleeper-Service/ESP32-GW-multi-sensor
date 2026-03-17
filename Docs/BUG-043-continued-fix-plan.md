# BUG-043 Continued — Fix Plan

**Baseline:** `main` branch at commit `c5311f0`, version `v7.5.3.4`
**Related:** BUG-043, PRs #36–#38 (original hotfix), LESSON-OPS-050, LESSON-OPS-051, LESSON-OPS-052
**Fixed in:** v7.5.3.5

---

## Problem Statement

Despite the v7.5.3.3-hotfix (PRs #36–#38) correctly implementing all 8 remediation steps from `dashboard-stability-remediation-plan.md`, the ESP32-C3 still crashes when the dashboard is opened in either SSE or polling mode.

### Key observations from device logs

**SSE mode:** Dashboard loads and runs for ~1 minute, then the ESP crashes during history loading:
```
[21:45:21] debug set Warning flag: unspecified          ← component blocked
[21:45:23] debug cleared Warning flag                   ← 2 seconds blocked
INFO Processing unexpected disconnect from ESPHome API  ← device rebooted
```

**Polling mode:** Initial crash on open, then stabilization with oscillating heap (53K–73K):
```
[21:52:50] Last reset too quick; invoke in 8 restarts
WARNING Can't connect to ESPHome API: Timeout waiting for HelloResponse after 30.0s
[21:55:05] time took a long time for an operation (61 ms)
[21:56:33] esp32_ble_tracker took a long time for an operation (66 ms)
```

**No `httpd_accept_conn: error in accept (23)` in logs** — socket exhaustion is NOT the issue anymore. The original hotfix fixed that.

**When left untouched** (no dashboard open), device runs stable at 72.1 KB free heap.

---

## Root Cause Analysis

### RC1: Concurrent temp+hum history fetches block the HTTP server task (PRIMARY)

**Location:** `dashboard/dashboard.js` `fetchDeviceHistory()` function

**Problem:** `Promise.all(historyMeasurements.map(...))` fires all history requests simultaneously. Each `/history/{id}/temp` or `/history/{id}/hum` request triggers a **synchronous NVS scan loop** in `sensor_history_multi.h` that reads up to **1080 NVS blobs** without yielding. With accumulated history, this blocks the HTTP server task for **0.5–2 seconds per request**. With `Promise.all`, both temp AND hum fire concurrently, **doubling the blocking window to 1–4 seconds**. During that window, BLE scanning, WiFi, the ESPHome API, and the task watchdog are all starved. **This is the primary crash mechanism.**

### RC2: Double manifest fetch at boot

**Location:** `dashboard/dashboard.js` `App.Boot.start()`

**Problem:** `loadManifestV2()` fetches `/api/manifest`, then `loadSensorManifest()` immediately fetches it again. This wastes 1-2 HTTP requests and adds to connection pressure during the critical boot window. Introduced in v7.5.2.0 when `loadManifestV2()` was added alongside the existing `loadSensorManifest()` without consolidating them.

### RC3: Polling mode initial burst fires 33+ paths immediately

**Location:** `dashboard/dashboard.js` `startPolling()`

**Problem:** `pollAll(POLL_DEVICE.concat(livePaths))` fired 33 paths in batches of 4 with no initial defer, concurrent with `loadStatusSnapshot()` — **5 concurrent connections in the first 120ms**.

### RC4: No in-flight guard on loadHistory()

**Location:** `dashboard/dashboard.js` `loadHistory()`

**Problem:** Unlike `loadStatusSnapshot()` and `loadStorageStats()` (which got in-flight guards in PRs #36–#38), `loadHistory()` had no guard. If the user clicks "Refresh History" during boot loading, or hits F5, two history sequences run in parallel, compounding the NVS blocking problem.

### RC5: History bootstrap timer too short (5s)

**Location:** `dashboard/dashboard.js` `App.Boot.start()`

**Problem:** `historyBootstrapTimerId = setTimeout(..., 5000)`. Storage stats are deferred to t+3s, and the initial poll (33 paths, batch-4) takes approximately 3.5 seconds total. Both can still be in flight when history starts at t+5s.

---

## Request Budget (Before vs After Fix)

### Before fix (v7.5.3.4) — boot window analysis

| Time | Request | Notes |
|------|---------|-------|
| t=0ms | `GET /api/manifest` (loadManifestV2) | Manifest fetch #1 |
| t=~200ms | `GET /api/manifest` (loadSensorManifest) | **Duplicate! Manifest fetch #2** |
| t=~400ms | `GET /api/status` | Status snapshot |
| t=~400ms | `GET /events` (SSE) or `pollAll` (33 paths, batch-4) | Transport start |
| t=3000ms | `GET /api/storage-stats` | Storage stats |
| t=5000ms | `GET /history/s1/temp` + `GET /history/s1/hum` | **Concurrent NVS scans** |
| t=~5200ms | `GET /history/s2/temp` + `GET /history/s2/hum` | **Concurrent NVS scans** |
| t=~5400ms | `GET /history/s3/temp` + `GET /history/s3/hum` | **Concurrent NVS scans** |

**Peak concurrent at history start: 2–4 connections + NVS blocking for 1–4s = crash**

### After fix (v7.5.3.5) — boot window analysis

| Time | Request | Notes |
|------|---------|-------|
| t=0ms | `GET /api/manifest` (loadManifestV2) | Single manifest fetch |
| t=~400ms | `GET /api/status` (SSE mode only) | Status |
| t=~400ms | `GET /events` (SSE) or deferred (polling) | Transport start |
| t=1000ms | `pollAll` (33 paths, **batch-2**) (polling mode) | Deferred, smaller batch |
| t=~3500ms | `GET /api/status` (polling mode, after poll) | After poll completes |
| t=3000ms | `GET /api/storage-stats` | Storage stats |
| t=8000ms | `GET /history/s1/temp` | **Sequential** |
| t=~8300ms | `GET /history/s1/hum` | 300ms gap |
| t=~8600ms | `GET /history/s2/temp` | 300ms gap |
| t=~8900ms | `GET /history/s2/hum` | 300ms gap |
| ... | ... | |

**Peak concurrent at history start: 0–1 background connections + NVS blocking safely serialized = stable**

---

## Fixes Implemented

### Fix 1: Eliminate double manifest fetch

**File:** `dashboard/dashboard.js`, `dashboard/dashboard.html` — `App.Boot.start()`

After `loadManifestV2()` resolves, check if `window._manifest.sensors` exists and has entries. If yes, call `normalizeManifestSensors(window._manifest)` → `applySensorMeta(meta)` directly (same logic as `loadSensorManifest()`, but using already-loaded data). Only call `loadSensorManifest()` as a fallback if the v2 manifest had no sensor entries.

```javascript
}).then(function() {
  // BUG-043-cont Fix 1: reuse v2 manifest sensors — no second /api/manifest fetch
  if (window._manifest && window._manifest.sensors && window._manifest.sensors.length) {
    var meta = normalizeManifestSensors(window._manifest);
    applySensorMeta(meta);
    dlog('[manifest] Sensors loaded from v2 manifest cache (' + meta.length + ' sensors, no second fetch)', 'ok');
    return Promise.resolve();
  }
  return loadSensorManifest();
}).then(function() {
```

### Fix 2: Make history fetches sequential (CRITICAL — most impactful)

**File:** `dashboard/dashboard.js`, `dashboard/dashboard.html` — `fetchDeviceHistory()`

Replace `Promise.all` with a sequential promise chain with 300ms delays:

```javascript
// BUG-043-cont Fix 2: sequential fetches with 300ms gap — prevents concurrent NVS scans
var results = [];
var chain = Promise.resolve();
historyMeasurements.forEach(function(m) {
  chain = chain.then(function() {
    return fetch(ESP_HOST + m.url, {cache:'no-store'})
      .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
      .then(function(raw) { results.push({key: m.key, raw: raw}); })
      .then(function() { return new Promise(function(res) { setTimeout(res, 300); }); });
  });
});
return chain.then(function() { return results; });
```

### Fix 3: Add in-flight guard to loadHistory()

**File:** `dashboard/dashboard.js`, `dashboard/dashboard.html`

Add `var _historyInFlight = false;` guard variable. Set it to `true` at start of `loadHistory()` (return early if already `true`). Reset to `false` in the `sensorIdx >= SENSORS.length` completion branch of `loadNext()`.

### Fix 4: Defer initial poll in startPolling()

**File:** `dashboard/dashboard.js`, `dashboard/dashboard.html`

- Wrap the initial `pollAll()` in `setTimeout(..., 1000)` to give the manifest/status requests time to complete
- Use batch size 2 (instead of default 4) for the initial poll to reduce peak concurrent connections
- Move `loadStatusSnapshot()` inside `startPolling()` so it fires after the deferred poll, not simultaneously
- In the boot sequence, only call `loadStatusSnapshot()` explicitly in SSE mode — polling mode lets `startPolling()` handle it

### Fix 5: Increase history loading defer from 5s to 8s

**File:** `dashboard/dashboard.js`, `dashboard/dashboard.html`

Change `historyBootstrapTimerId = setTimeout(..., 5000)` to `setTimeout(..., 8000)`. This ensures both storage stats (t+3s) and the deferred initial poll (~t+3.5s) complete before the NVS-heavy history requests begin.

### Fix 6 & 7: Mirror to dashboard.html and regenerate dashboard.h

All JS changes applied identically to `dashboard/dashboard.html`. `dashboard/dashboard.h` regenerated via `bash scripts/generate-header.sh` (invoked by `bash scripts/bump-version.sh 7.5.3.5`).

### Fix 8: Add preflight check for concurrent history patterns

**File:** `scripts/preflight.sh`

```bash
# BUG-043-cont Fix 8: prevent regression — history fetch must be sequential, never Promise.all
if grep -Eq 'Promise\.all\(.*historyMeasurements' dashboard/dashboard.js dashboard/dashboard.html; then
  echo "✗ no_concurrent_history_fetch: FAIL — fetchDeviceHistory must NOT use Promise.all"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "no_concurrent_history_fetch: OK"
fi
```

---

## Acceptance Criteria

- [ ] `bash scripts/preflight.sh` passes (all checks including `no_concurrent_history_fetch: OK`)
- [ ] `dashboard/dashboard.js` version = `v7.5.3.5`
- [ ] `dashboard/dashboard.html` version = `v7.5.3.5`
- [ ] `dashboard/dashboard.h` regenerated from `dashboard.html`
- [ ] No `Promise.all(historyMeasurements` in either dashboard file
- [ ] `_historyInFlight` guard present in both dashboard files
- [ ] `setTimeout(..., 8000)` for history bootstrap in both dashboard files

---

## Device Validation Checklist

After flashing v7.5.3.5 firmware:

1. **Open local dashboard (SSE mode):**
   - [ ] No crash for 5+ minutes
   - [ ] History loads without device reboot
   - [ ] Browser console shows `[manifest] Sensors loaded from v2 manifest cache` (not two manifest fetches)
   - [ ] No ESPHome API disconnect during history load

2. **Close and reopen dashboard (SSE mode):**
   - [ ] No crash on second open
   - [ ] History loads again without crash

3. **Open remote dashboard (polling mode):**
   - [ ] No crash on first open
   - [ ] Heap remains stable (no oscillation below 60K)
   - [ ] History loads without crash

4. **F5 refresh after 3 min uptime:**
   - [ ] No crash
   - [ ] `History load already in flight — skipping` log message if refresh hits during history load

5. **Check browser DevTools Network tab:**
   - [ ] `/api/manifest` fetched only once at boot
   - [ ] History endpoints fetched sequentially (not simultaneously)
   - [ ] ~300ms gap between history fetches

6. **Check device logs:**
   - [ ] No `httpd_accept_conn: error in accept (23)`
   - [ ] No 2+ second component blocking warnings during history load
   - [ ] Free heap stable at ~72K when dashboard is open and idle

---

## Future Work

- Add `vTaskDelay(pdMS_TO_TICKS(1))` inside the NVS scan loop in `sensor_history_multi.h` to yield the CPU between blob reads. This would eliminate the root cause at the firmware level and remove the need for the 300ms browser-side delay.
