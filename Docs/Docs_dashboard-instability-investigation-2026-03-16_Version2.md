# Dashboard Instability Investigation — 2026-03-16

## Purpose

This document captures the observed behavior, likely root cause, and implementation plan for the real-device dashboard instability discovered while validating `v7.5.3.3`.

---

## 1. Observed behavior

### Stable cases
The device can:
- boot successfully after OTA
- run for 30+ minutes without immediate instability
- continue BLE collection
- continue 15-minute averaging / history logging
- respond to direct requests such as:
  - `/`
  - `/api/status`
  - `/api/v2/live`

### Unstable cases
Dashboard access triggers instability.

#### Local direct dashboard
Opening:
- `http://192.168.120.189/dashboard.html`

Observed behavior:
- page opens and initially shows apparently valid data
- within several seconds, uptime drops/reset is observed
- logs indicate device crashed/rebooted
- after reboot, page may remain open and device may stabilize
- if page is closed and reopened, crash is reproduced again

#### Remote hosted dashboard
Opening:
- `https://esp32-2.high-lands.online/dashboard.html`

Observed behavior:
- dashboard runs in polling mode
- crash happens on open
- repeated crashes continue on later polling cycles (roughly every 15 seconds)

---

## 2. What is *not* the root issue

### `/api/v2/live` is not the current milestone
`/api/v2/live` is planned for `v7.5.3.4`, not `v7.5.3.2` or `v7.5.3.3`.

Therefore:
- empty reply from `/api/v2/live` is expected in current phase state
- lack of `/api/v2/live` data should not be treated as the immediate bug target

---

## 3. Evidence collected

### Device logs
Observed during dashboard-triggered failures:
- `httpd_accept_conn: error in accept (23)`
- ESPHome API disconnect / reconnect
- component blocking warnings
- dashboard reset reason `exception/panic`

### Browser console
Observed:
- manifest loads successfully from `/api/manifest`
- favicon request returns `500`
- EventSource reset / connection reset after crash
- async listener/channel closure errors after disconnect/reset

### Browser Network tab
Observed request pattern included:
- `events` EventSource connection
- repeated `/api/status` fetches
- repeated `/api/storage-stats` fetches
- other startup requests

### Resource snapshot
Observed free heap:
- about `69.7 KB`

This does not prove the root cause by itself, but indicates limited headroom.

---

## 4. Working root cause hypothesis

The dashboard likely overloads the ESP32-C3 HTTP stack with one or more of:

1. **startup request fanout**
   - too many simultaneous fetches at page load

2. **duplicate refresh loops**
   - status or storage refresh started more than once

3. **polling + SSE overlap**
   - polling activity not fully suppressed while SSE is connected

4. **overlapping in-flight requests**
   - next interval fires before previous request finishes

5. **hosted remote mode amplification**
   - remote/polling transport causes more frequent or more expensive request patterns than local same-origin access

The repeated `httpd_accept_conn` failures strongly suggest HTTP/socket pressure rather than a single malformed endpoint implementation.

---

## 5. Most suspicious code areas

Priority files:
- `dashboard/dashboard.js`
- generated `dashboard/dashboard.h`
- dashboard boot sequence and transport selection
- status refresh logic
- storage stats refresh logic
- polling interval lifecycle
- SSE connection lifecycle

Priority functions / behaviors to inspect:
- `loadStatusSnapshot()`
- `startPolling()`
- periodic refresh setup for storage stats
- any code path calling status fetch on:
  - boot
  - SSE open
  - SSE ping
  - reconnect
  - interval
- any missing guard against creating duplicate intervals

---

## 6. Remediation goals

### Functional goals
- dashboard open should not reboot the device
- closing and reopening dashboard should not reboot the device
- remote hosted polling mode should not repeatedly crash the device

### Technical goals
- ensure only one active polling interval per category
- suppress unnecessary polling while SSE is connected
- serialize/stagger startup requests
- avoid overlapping fetches
- reduce pressure from `/api/status` and `/api/storage-stats`
- preserve existing dashboard functionality once stable

---

## 7. Implementation plan

### Phase A — Instrument and isolate
1. Inspect all call sites for `loadStatusSnapshot()`
2. Inspect all `setInterval()` creation paths
3. Confirm whether `startPolling()` can run more than once
4. Confirm whether SSE mode still leaves status/storage polling too aggressive
5. Add temporary debug counters / logs in JS if needed

### Phase B — Reduce request pressure
1. Gate status polling so only one request can be in flight
2. Prevent duplicate status interval creation
3. Prevent duplicate storage stats interval creation
4. In SSE mode, reduce status polling to minimal cadence or disable entirely except for explicit fallback
5. Delay noncritical startup calls until core UI is connected
6. Serialize expensive startup fetches instead of parallel fanout

### Phase C — Validate locally
1. open local dashboard once
2. verify no reset for at least 10 minutes
3. close and reopen
4. verify no reset
5. test with and without ESPHome logs connection

### Phase D — Validate remotely
1. open remote hosted dashboard
2. verify no reset on open
3. observe at least two or three polling cycles
4. verify no repeated crash loop

---

## 8. Acceptance criteria

A fix is acceptable only if all are true:

- local `dashboard.html` no longer causes reboot after open
- local close/reopen does not retrigger crash
- remote hosted polling mode no longer causes repeated resets
- `/api/status` request frequency is controlled and intentional
- no repeated `httpd_accept_conn: error in accept (23)` during normal dashboard use
- BLE/history behavior remains intact
- heap remains within acceptable range during dashboard activity

---

## 9. Non-goals for the next fix session

Do **not** combine this work with:
- `/api/v2/live` implementation
- Phase 3.4 feature work
- SensorEntity endpoint migration
- unrelated feature additions

This should be a focused stabilization session.