# Session Log — BUG-043 Dashboard Hardening PR2

**Date:** 2026-03-17
**Version:** no bump (dashboard-side fix continuation; no API changes)
**Related:** BUG-043, PR #39 (v7.5.3.5 dashboard mitigations), PR #40 (firmware NVS yield)
**Branch:** `copilot/bug-043-finish-dashboard-stabilization`

---

## Context

PR #39 (v7.5.3.5) reduced dashboard-induced crashes by:
- Eliminating double manifest fetch
- Making `fetchDeviceHistory()` sequential (was `Promise.all`)
- Adding `_historyInFlight` guard to `loadHistory()`
- Deferring initial poll by 1s and reducing batch from 4→2
- Extending history bootstrap defer from 5s→8s

PR #40 (firmware) added cooperative yielding in long NVS scan loops (`vTaskDelay` every 4 blob reads).

**Remaining issues after both PRs:**
1. SSE dashboard still crashes on initial open — `loadStatusSnapshot()` fired simultaneously with `connectSSE()`, adding connection pressure during the most fragile moment
2. Polling dashboard still crashes on F5 — initial poll with batch=2 still sends 2 concurrent connections, and the 120ms inter-batch gap is insufficient when the device is running hot
3. History sensors chain immediately on completion — no recovery time between NVS scan loops
4. Storage stats (t+3s) could overlap with sequential poll still in flight (which now takes ~7-8s)
5. History bootstrap (t+8s) could overlap with sequential poll tail

---

## Analysis

### SSE crash (initial open)
Current boot sequence in SSE mode:
```
t=0    manifest fetch
t=~200 loadStatusSnapshot() ← fires immediately before connectSSE
t=~200 connectSSE() ← opens /events stream
t=3s   storage stats
t=8s   history
```
Both `loadStatusSnapshot()` and `connectSSE()` fire concurrently. Even though SSE delivers state via `state` events (making the immediate status snapshot redundant), the concurrent open is problematic on a just-rebooted device.

**Fix A**: Connect SSE stream first, then defer status snapshot 2s.

### Polling F5 crash
Initial `pollAll(paths, 2)` with `Promise.all(batch.map())`:
- 2 concurrent requests per batch with 120ms inter-batch gap
- 30+ paths → 15 batches → 15 × (2 concurrent + 120ms) ≈ 3.3s total
- F5 starts this on a device that may have just served history/storage-stats

**Fix B**: Change to `pollAll(paths, 1, 200)` — single request per "batch", 200ms inter-request gap. Fully sequential. `Promise.all([x])` == just running `x`. Sequential poll at batch=1 takes ~7-8s for 30 paths — intentionally conservative.

### History inter-sensor gap
Current `loadHistory()` calls `loadNext()` immediately after each sensor's data is processed. With the firmware yielding fix (PR #40), each NVS scan still takes real wall-clock time. Giving 500ms recovery between sensors provides breathing room for BLE/WiFi/API tasks.

**Fix C**: `setTimeout(loadNext, 500)` in both success and failure paths.

### Storage stats overlap
With batch=1 polling taking ~7-8s, the storage stats at t=3s fires while polling is still in flight. Moving to t=5s ensures overlap is minimal (first ~4s of poll are done by then), and storage stats is non-critical below-fold data.

**Fix D**: Move storage stats defer from 3s → 5s.

### History bootstrap timing
Sequential poll (batch=1, ~30 paths, 200ms gap) completes at ~t=8-9s from first poll request at t=1s. History bootstrap at t=8s could start while poll is still in its last few requests. Moving to t=10s gives clear headroom.

**Fix E**: Move history bootstrap from 8s → 10s.

---

## Favicon/Routing Investigation

### Symptom
`/favicon.ico` returns HTTP 500 after clean rebuild/flash, even though:
- `sensor_history_multi.h` `canHandle()` returns `true` for `/favicon.ico`
- `sensor_history_multi.h` `handleRequest()` calls `request->send(204)` for `/favicon.ico`
- No `request->send(500)` in project code

### Root cause identified
ESPHome's `web_server` component (version 3) uses `AsyncWebServer::addHandler(this)` during its `setup()` phase to add itself as an `AsyncWebHandler`. This is a catch-all handler whose `canHandle()` returns `true` for requests it doesn't explicitly recognize, and whose `handleRequest()` returns HTTP 500 for those routes.

Our `register_history_handler()` is called in an `on_boot` lambda (`priority: -100`), which runs AFTER all component `setup()` calls. Therefore:
1. ESPHome's web_server handler: position 0 in `_handlers` list (added in setup)
2. Our `HistoryWebHandler`: position 1 in `_handlers` list (added in on_boot)

`AsyncWebServer` processes handlers in order. For `/favicon.ico`:
- ESPHome's handler's `canHandle()` → `true` → `handleRequest()` → HTTP 500
- Our handler never checked

### Code verdict
The source code is CORRECT. The handler logic is correct. The bug is purely in registration ORDER, not in the handler implementation.

### Why no repo-side fix in this PR
The fix requires changing WHEN `register_history_handler()` runs — specifically, it needs to run before ESPHome's `web_server::setup()` adds its handler. Options:
1. Create a custom `esphome::Component` with `setup_priority()` between `web_server_base` (base) and `web_server` (UI) — this is a firmware/YAML refactor
2. Use platform-specific `AsyncWebServer::prependHandler()` if it exists — ESPHome's bundled version doesn't expose this
3. Access `_handlers` (private LinkedList) directly via pointer cast — fragile, breaks with ESPHome updates

None of these qualify as "small, justified" changes that belong in a dashboard-hardening PR. Documented in LESSON-OPS-054. Filed as a separate cleanup task.

---

## Changes Made

### `dashboard/dashboard.js`
- **Fix A**: SSE mode — `connectSSE()` first, `loadStatusSnapshot()` deferred 2s
- **Fix B**: `startPolling()` initial poll: `pollAll(..., 1, 200)` (was `pollAll(..., 2)`)
- **Fix C**: `loadHistory()` `loadNext()`: `setTimeout(loadNext, 500)` in both success and failure paths
- **Fix D**: Storage stats defer: 3000 → 5000ms
- **Fix E**: History bootstrap defer: 8000 → 10000ms

### `dashboard/dashboard.html`
- Identical changes mirrored (source of truth per LESSON-OPS-043)

### `dashboard/dashboard.h`
- Regenerated from `dashboard/dashboard.html` via `scripts/generate-header.sh`

### `scripts/preflight.sh`
- Added `startup_poll_sequential` check: fails if `pollAll(POLL_DEVICE.concat(livePaths), 1` not found in both JS files

### `Docs/changelog.md`
- Added "BUG-043 Dashboard Hardening (no version bump) — 2026-03-17" entry with full startup budget table and favicon/routing note

### `Docs/bugs-and-lessons-learned.md`
- Updated BUG-043 status to FIXED (pending device validation)
- Added "Fix (dashboard hardening — PR2)" section
- Added LESSON-OPS-054 (sequential startup polling + ESPHome handler ordering)
- Updated LESSON-OPS-052 bootstrap timer reference from 8s to 10s

### `Docs/session-log-2026-03-17-BUG-043-dashboard-hardening-PR2.md`
- This file

---

## No Version Bump

No version bump for this PR. Reasons:
1. User preference: avoid version bumps unless required
2. No API changes, no interface changes, no breaking changes
3. Dashboard JS timing changes are internal scheduling — not visible in version strings
4. The changelog entry documents the changes clearly without needing a version marker

---

## Startup Request Budget (After This PR)

| Time | Event | Mode | Notes |
|------|-------|------|-------|
| t=0ms | `GET /api/manifest` | both | single manifest |
| t=~200ms | `GET /events` open | SSE | stream first |
| t=1000ms | `GET /…` path 1 | polling | batch=1 sequential |
| t=~1200ms | `GET /…` path 2 | polling | 200ms gap |
| t=2000ms | `GET /api/status` | SSE | 2s after SSE open |
| t=~1400ms–8500ms | paths 3–30 | polling | ~250ms each |
| t=5000ms | `GET /api/storage-stats` | both | deferred 5s |
| t=~8500ms | `GET /api/status` | polling | after poll completes |
| t=10000ms | `GET /history/s1/temp` | both | history start |
| t=~10300ms | `GET /history/s1/hum` | both | 300ms gap (fetchDeviceHistory) |
| t=~10800ms | `GET /history/s2/temp` | both | 500ms inter-sensor gap |
| t=~11100ms | `GET /history/s2/hum` | both | 300ms gap |
| t=~11600ms | `GET /history/s3/temp` | both | 500ms inter-sensor gap |
| t=~11900ms | `GET /history/s3/hum` | both | 300ms gap |

**Peak concurrent at any point: 1 request** (excluding the manifest which completes before transport start)

---

## Post-Merge Device Validation Checklist

### 1. Clean rebuild + flash from merged `main`
```bash
esphome run firmware/esp32-c3-multi-sensor.yaml
```

### 2. Favicon check
```bash
curl -i http://192.168.120.189/favicon.ico
```
Expected: HTTP 204 (if ESPHome handler ordering is resolved) or HTTP 500 (known limitation, LESSON-OPS-054). **This PR does NOT fix the favicon** — document the result for the next PR.

### 3. SSE dashboard — fresh open after reboot
- [ ] Browser DevTools → Network: `/api/manifest` first, then `/events` opens, then `GET /api/status` at ~t=2s
- [ ] No `ERR_CONNECTION_RESET` on `/events` during the first 30 seconds
- [ ] ESPHome logs: no `api took a long time` > 50ms during the 2s status snapshot window
- [ ] Dashboard shows live data within 5 seconds

### 4. SSE dashboard — F5 after 2 min uptime
- [ ] No crash/reboot in ESPHome logs
- [ ] Dashboard reconnects cleanly
- [ ] If F5 hits during history load: `History load already in flight — skipping` in browser console

### 5. Polling dashboard — fresh open (via `https://esp32-2.high-lands.online/`)
- [ ] Browser DevTools → Network: manifest first, then poll requests one-at-a-time with ~200ms gaps
- [ ] No 502 or ERR_CONNECTION_RESET during initial poll sequence
- [ ] `[polling] Initial poll done` message appears in browser console after ~8s

### 6. Polling dashboard — F5 after 2 min uptime
- [ ] No crash/reboot in ESPHome logs
- [ ] Poll restarts sequentially (batch=1)
- [ ] Storage stats loads at ~5s, history at ~10s

### 7. ESPHome log inspection
Expected after dashboard open and stable:
```
[I][history:...] history handler registered
# no: "api took a long time (>100ms)"
# no: "httpd_accept_conn: error in accept (23)"
# stable: "free heap: ~70K-72K"
```

### 8. Manual API curl (confirm still stable)
```bash
curl -s http://192.168.120.189/api/status | python3 -m json.tool
curl -s http://192.168.120.189/api/storage-stats | python3 -m json.tool
curl -s "http://192.168.120.189/history/office/temp" | head -5
curl -s "http://192.168.120.189/history/office/hum" | head -5
```
All should return 200 without causing API disconnect.

---

## Handoff Notes

This PR completes the dashboard-side BUG-043 work. Remaining items for a future PR:

1. **Favicon/routing fix**: Change `register_history_handler()` to register before ESPHome's web_server handler. Requires creating a custom ESPHome component with the right `setup_priority`, or finding another way to prepend the handler. See LESSON-OPS-054.

2. **Real-device validation**: All 8 checklist items above should be run after merge and results documented.

3. **If crashes persist**: Check ESPHome component blocking warnings in logs. If still seeing `api took a long time`, the firmware yield fix (PR #40) may need more aggressive yielding (every 2 iterations instead of every 4).
