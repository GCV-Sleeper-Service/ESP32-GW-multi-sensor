# Session Log — 2026-03-16 — v7.5.3.3 device validation and dashboard instability

## Summary

This session performed post-merge device validation for `v7.5.3.3` on real hardware and discovered that the primary runtime instability is **dashboard-triggered HTTP load**, not `/api/v2/live` by itself.

Initial suspicion was that `/api/v2/live` caused panic/reboot. Subsequent A/B testing and request isolation showed:

- `v7.5.3.2`
  - `/api/status` works
  - `/api/v2/live` returns empty reply
  - no crash from direct curl tests
- `v7.5.3.3`
  - `/api/status` works
  - `/api/v2/live` returns empty reply
  - direct curl tests do **not** reliably crash the device
  - dashboard access can trigger panic/reboot
  - remote hosted dashboard in polling mode is worse and can trigger repeated crashes

## Versions tested

- `v7.5.3.2` — rollback branch at commit `d282cb23aeb772cbf19bd637584ce9c3c30e6b12`
- `v7.5.3.3` — merged `main` at commit `692320b2a59196444a23b5e6fe129813c5e84ed8`

## Key findings

### 1. `/api/v2/live` is not implemented yet in this phase
Repo docs and search results confirmed:

- `Docs/phase3-implementation-plan.md` defines **v7.5.3.4** as the step to add `/api/v2/live`
- `Docs/session-log-2026-03-16-v7.5.3.2.md` explicitly says `/api/v2/live` was not added yet
- therefore empty reply from `/api/v2/live` is not itself a regression for `v7.5.3.2` / `v7.5.3.3`

### 2. Direct endpoint tests are not the primary crash trigger
For `v7.5.3.3`, direct requests to:
- `/`
- `/api/status`
- `/api/v2/live`

did not consistently crash the device during later validation.

### 3. The real trigger is dashboard access
Observed behavior:

- local dashboard `http://192.168.120.189/dashboard.html`
  - causes crash shortly after opening
  - after reboot, page may remain open and device may stabilize
  - closing and reopening the page reproduces the crash
- remote dashboard `https://esp32-2.high-lands.online/dashboard.html`
  - uses polling mode
  - crashes on opening
  - continues causing repeated crashes on subsequent polls

### 4. Network tab indicates repeated request pressure
Local dashboard network inspection showed:
- long-lived `events` EventSource connection
- repeated `status` fetches
- repeated `storage-stats` fetches
- additional `temp` / `hum` requests

This suggests the device is being overloaded by dashboard startup and/or recurring polling behavior even when SSE is active.

### 5. Logs indicate HTTP/socket stress and instability
Representative logs:
- `httpd_accept_conn: error in accept (23)`
- API disconnects
- component blocking warnings
- reset reason displayed as `exception/panic`

## Device observations

### Heap
Observed free heap with local dashboard + ESPHome logs connected:
- approximately `69.7 KB`

This is not catastrophically low by itself, but may be insufficient headroom under concurrent:
- BLE processing
- web server activity
- dashboard startup requests
- ESPHome API logging connection

### Browser console observations
Console showed:
- manifest load success from `/api/manifest`
- favicon `500`
- EventSource reset / connection reset behavior after crash
- async listener/channel closure errors after disconnect

These secondary browser errors appear consistent with the device resetting while the page is active.

## Working conclusion

The main unresolved issue is:

> Dashboard-triggered instability caused by HTTP request fanout / repeated polling / overlapping refresh activity on the ESP32-C3 web server.

This is **not** primarily a `/api/v2/live` correctness issue.

## Validation status for v7.5.3.3

### Passed
- build
- OTA flash
- basic boot
- 15-minute history accumulation
- no immediate crash from isolated curl tests

### Failed / unresolved
- dashboard stability on real device
- local dashboard open/reopen stability
- remote hosted dashboard polling stability

## Recommended next step

Do not advance to the next planned feature step until dashboard stability is addressed.

Next session should focus on:
1. dashboard request scheduling
2. duplicate / overlapping `/api/status` calls
3. startup request fanout reduction
4. storage stats refresh cadence
5. polling vs SSE suppression logic
6. one-client real-device validation

## Candidate root causes to investigate in code

- duplicate calls to `loadStatusSnapshot()`
- `startPolling()` invoked more than once
- polling still active when SSE is connected
- dashboard boot sequence starting too many fetches concurrently
- repeated `storage-stats` refresh under constrained HTTP/socket limits
- remote hosted mode forcing more expensive polling behavior

## Recommendation on rollout

`v7.5.3.3` should not be considered fully device-validated for dashboard usage.