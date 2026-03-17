# Manual/Device Validation Plan for PR #41 Merge

## A. Build/Flash Verification
- **Test**: Verify that the firmware builds successfully without errors.
- **Curl Command**: `curl -X GET http://<device_ip>/firmware`  
- **Pass/Fail Criteria**: The command should return a valid firmware version.

## B. Endpoint Sanity
- **Test**: Check that all expected API endpoints are functional.
- **Curl Command**: `curl -X GET http://<device_ip>/api/status`  
- **Pass/Fail Criteria**: HTTP status 200 on all endpoints.

## C. Manual Heavy-Route Stability
- **Test**: Instruct heavy traffic to a key route.
- **Curl Command**: `curl -X GET http://<device_ip>/api/data?type=heavy`  
- **Pass/Fail Criteria**: No dropped requests or timeouts.

## D. SSE Tests
- **Test**: Subscribe to Server Sent Events.
- **Curl Command**: `curl -N http://<device_ip>/api/events`  
- **Pass/Fail Criteria**: Event stream should not disconnect unexpectedly.

## E. Polling Tests
- **Test**: Validate data polling integrity.
- **Curl Command**: `curl -X GET http://<device_ip>/api/poll`  
- **Pass/Fail Criteria**: Data returned is consistent across polling requests.

## F. History-Loading Behavior
- **Test**: Check how history events load over time.
- **Curl Command**: `curl -X GET http://<device_ip>/api/history`  
- **Pass/Fail Criteria**: Correct historical data returned.

## G. Storage Stats Timing
- **Test**: Measure the time to retrieve storage statistics.
- **Curl Command**: `curl -X GET http://<device_ip>/api/storage/stats`  
- **Pass/Fail Criteria**: Timing within acceptable limits.

## H. Long-Run Stability
- **Test**: Let the system run for an extended period and monitor.
- **Curl Command**: N/A  
- **Pass/Fail Criteria**: System remains responsive and efficient over 24 hours.

## I. Repeatability/Reopen Testing
- **Test**: Restart the device and repeat previous tests to ensure consistency.
- **Curl Command**: N/A  
- **Pass/Fail Criteria**: All tests should yield the same results after reboot.

# BUG-043 Post-PR41 Manual / Device Test Plan

This document defines the required real-device validation suite after the dashboard-side stabilization PR for BUG-043 is merged.

## Purpose

These tests validate that:

- firmware remains stable after the PR #40 yielding fix
- dashboard-side startup/poll/history hardening from PR #41 eliminates the remaining crash scenarios
- SSE and polling modes both remain stable during open, refresh, and history-loading phases
- manual endpoint access remains stable
- no regressions were introduced in dashboard boot behavior

---

## Preconditions

Before running tests:

1. Merge the PR into `main`
2. Pull the latest code
3. Perform a clean rebuild and flash

```bash
git checkout main
git pull
esphome clean firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml
```

4. Keep ESPHome logs attached during the full test session

---

## A. Build / Flash Verification

### A1. Confirm successful boot

Observe the first 1-2 minutes of ESPHome logs after flash.

Expected:
- normal boot
- no boot loop
- no repeated disconnect/reconnect cycle
- safe mode resets normally

### A2. Record baseline boot logs

Save the initial boot section for comparison against failures later.

---

## B. Basic Endpoint Sanity Tests

Run from a second shell:

```bash
curl -i http://192.168.120.189/favicon.ico
curl -i http://192.168.120.189/api/manifest
curl -i http://192.168.120.189/api/status
curl -i http://192.168.120.189/api/storage-stats
curl -i http://192.168.120.189/history/office/temp
curl -i http://192.168.120.189/history/office/hum
curl -i http://192.168.120.189/history/first_floor/temp
curl -i http://192.168.120.189/history/outside/temp
```

Expected:
- `/favicon.ico` returns `204 No Content` or the explicitly intended success response
- `/api/manifest` returns valid JSON
- `/api/status` returns valid JSON
- `/api/storage-stats` returns valid JSON
- `/history/...` endpoints return CSV-like text

Pass criteria:
- no reboot
- no ESPHome API disconnect
- no major blocking warnings tied to these requests

---

## C. Manual Stability Tests for Heavy Routes

Run:

```bash
curl http://192.168.120.189/api/storage-stats > /tmp/storage-stats.json
curl http://192.168.120.189/history/office/temp > /tmp/office-temp.csv
curl http://192.168.120.189/history/office/hum > /tmp/office-hum.csv
curl http://192.168.120.189/history/first_floor/temp > /tmp/first-floor-temp.csv
curl http://192.168.120.189/history/outside/temp > /tmp/outside-temp.csv
```

Watch logs while doing this.

Pass criteria:
- no reboot
- no disconnect
- no sustained or repeated severe blocking warnings
- no instability triggered by history/storage access

---

## D. SSE Mode Tests

### D1. Fresh Boot -> SSE Open
1. Reboot device or use freshly flashed device
2. Wait for stable boot
3. Open local dashboard in SSE mode
4. Observe for 5 minutes

### D2. SSE Refresh
5. Press `F5`
6. Observe for 5 more minutes

### D3. SSE Idle Stability
7. Leave the page open long enough for:
   - storage stats timing window
   - history bootstrap timing window
   - steady-state SSE behavior

Pass criteria:
- no crash
- no reboot
- no API disconnect loop
- dashboard remains usable
- EventSource remains healthy or recovers cleanly without device reset

---

## E. Polling Mode Tests

### E1. Initial Open
1. Open hosted/remote dashboard in polling mode
2. Allow full initialization
3. Observe at least 2 polling cycles

### E2. Refresh
4. Press `F5`
5. Observe at least 2 more polling cycles

Pass criteria:
- no crash
- no reboot
- no disconnect loop
- no 502 burst caused by device reset
- dashboard remains usable after refresh

---

## F. History-Loading Behavior Tests

### F1. Initial History Load
- confirm charts load
- confirm data appears for all sensors
- confirm no crash during initial history retrieval

### F2. Manual History Refresh
If UI supports it:
- trigger history reload
- observe logs
- confirm no reboot and no stuck loading state

### F3. Refresh + History Reload
- refresh page
- confirm history still loads correctly
- verify no duplicate-load crash behavior

Pass criteria:
- no duplicate-request crash
- no stuck in-flight behavior
- charts continue working after reload/refresh

---

## G. Storage Stats Timing Test

Open dashboard after clean boot and watch the storage-stats timing window.

Verify:
- storage stats appears
- no crash when it loads
- no visible overlap-induced instability

Pass criteria:
- stable dashboard
- no reboot
- no API disconnect

---

## H. Long-Run Stability Test

### H1. SSE Long Run
- leave local SSE dashboard open for 10-15 minutes

### H2. Polling Long Run
- leave polling dashboard open for 10-15 minutes

Pass criteria:
- no spontaneous reboot
- no API disconnect loop
- no accumulating instability

---

## I. Negative / Repeatability Tests

### I1. Close/Reopen
- close dashboard tab
- reopen dashboard
- confirm device remains stable

### I2. Reboot + Quick Retest
- reboot device
- repeat quick SSE open
- repeat quick polling open

Pass criteria:
- issue does not only disappear for a single run
- behavior is repeatable and stable

---

## Logs to Watch For

### Bad signs
- `Processing unexpected disconnect from ESPHome API`
- `WARNING Disconnected from API`
- `debug set Warning flag`
- `logger took a long time`
- `api took a long time`
- `web_server took a long time`
- reboot / safe mode activity immediately after dashboard actions

### Good signs
- dashboard actions no longer correlate with disconnect/reboot
- manual curls remain stable
- open and refresh no longer crash the device

---

## Suggested Results Matrix

| Test | Pass/Fail | Notes |
|---|---|---|
| `/favicon.ico` returns expected success response |  |  |
| `/api/manifest` valid |  |  |
| `/api/status` valid |  |  |
| `/api/storage-stats` valid |  |  |
| manual history curls stable |  |  |
| SSE open after boot |  |  |
| SSE F5 |  |  |
| polling open |  |  |
| polling F5 |  |  |
| history charts load |  |  |
| manual history refresh works |  |  |
| 10-15 min SSE stable |  |  |
| 10-15 min polling stable |  |  |
| no API disconnects |  |  |
| no reboot |  |  |

---

## Final Acceptance

BUG-043 should only be considered fully resolved when:

- SSE mode is stable on open and refresh
- polling mode is stable on open and refresh
- manual history/storage access remains stable
- no reboot/disconnect loop occurs
- no significant blocking warnings correlate with dashboard operations


# BUG-043 Proposed Browser / Playwright Test Additions

This document proposes browser-side regression tests to reduce the chance of reintroducing the dashboard behaviors that contributed to BUG-043.

## Purpose

These tests are intended to catch JavaScript/request-scheduling regressions such as:

- duplicate requests
- too many concurrent fetches
- incorrect boot ordering
- polling vs SSE logic regressions
- favicon fetch behavior
- `loadHistory()` being called twice
- `pollAll()` using concurrent startup behavior
- `_historyInFlight` getting stuck
- unexpected changes in manifest/status/storage/history startup timing

These tests are **not** a full replacement for real-device validation.

---

## What Browser Tests Can Catch Well

Browser tests can reliably detect:

- request ordering regressions
- duplicate request creation
- timing/sequence regressions in startup logic
- incorrect transport branching (SSE vs polling)
- missing/deferred request logic
- stuck client-side guards
- favicon request behavior
- request bursts reintroduced by future refactors

---

## What Browser Tests Cannot Fully Prove

Browser tests alone cannot reliably prove:

- actual ESP32-C3 watchdog starvation
- FreeRTOS task starvation
- BLE/Wi-Fi/API contention
- true device reboot behavior under hardware load

Those require:
- real-device validation, or
- hardware-in-the-loop testing

---

## Recommended Test Layers

### Layer 1: Browser / Playwright Regression Tests
Use mocked network and request observation to catch dashboard JS regressions quickly in CI.

### Layer 2: Real-Device Manual Validation
Required for final acceptance of BUG-043 fixes.

### Layer 3: Optional Hardware-in-the-Loop Automation
Best long-term solution for preventing recurrence of device-specific stability bugs.

---

## Proposed Browser / Playwright Tests

### 1. Favicon Request Test
Verify that opening the dashboard does not produce a failed favicon request.

Assertions:
- `/favicon.ico` does not return `500`
- or dashboard explicitly serves/declares an icon in a way that prevents error spam

### 2. SSE Boot Ordering Test
In SSE mode, assert that startup requests occur in the intended safe order.

Validate:
- manifest loads first
- `/events` connects at the intended point
- `loadStatusSnapshot()` is deferred or omitted initially per implementation
- storage/history requests do not overlap the fragile startup window incorrectly

### 3. Polling Startup Concurrency Test
In polling mode, assert that startup polling is fully sequential or otherwise constrained as designed.

Validate:
- no unsafe `Promise.all` startup burst
- initial poll paths are requested one-by-one in the expected order
- refresh (`F5`) does not recreate the original burst problem

### 4. Duplicate Request Prevention Test
Track network requests during boot and assert:
- no duplicate manifest fetch
- no duplicate history bootstrap
- no redundant status fetch burst
- no duplicate storage stats fetch during initial window

### 5. `loadHistory()` Reentrancy Test
Simulate repeated history-triggering actions while history is already loading.

Validate:
- second call does not start overlapping history chain
- guard prevents concurrent execution
- UI remains functional

### 6. `_historyInFlight` Recovery Test
Force a failed history request.

Validate:
- `_historyInFlight` resets after failure
- a later history request can run successfully
- UI is not stuck in a permanently blocked state

### 7. `pollAll()` Behavior Test
Instrument startup polling and assert:
- initial poll path is sequential
- no concurrent `Promise.all` startup batching remains if that is the intended fix
- later polling behavior matches the intended design

### 8. Manifest / Status / Storage / History Timing Test
Capture request timestamps and order.

Validate:
- manifest timing remains first
- status/storage/history timing matches design intent
- future changes do not silently reintroduce overlap

### 9. Transport Regression Test
Run one suite in SSE mode and one in polling mode.

Validate:
- SSE-specific boot path does not accidentally use polling assumptions
- polling mode does not accidentally trigger SSE-only code
- refresh behavior remains transport-correct

---

## Suggested Test Design Approaches

### Mocked-Network Browser Tests
Use mocked or intercepted network responses to:
- inspect request order
- detect duplicate requests
- simulate slow responses
- simulate history fetch failures
- verify recovery behavior

### Real Endpoint Browser Tests
Where available, run browser tests against a local served dashboard with controlled endpoint responses.

### Hardware-in-the-Loop Tests
If feasible in the future:
- run Playwright against a real ESP32 device
- monitor `/api/status` or device availability during page load / refresh
- combine browser automation with external device health checks

---

## Suggested Assertions by Failure Mode

### Duplicate requests
Assert request counts for:
- `/api/manifest`
- `/api/status`
- `/api/storage-stats`
- `/history/...`

### Too many concurrent fetches
Assert max concurrent in-flight fetches during startup are below the intended threshold.

### Incorrect boot ordering
Assert the startup sequence matches intended design.

### Polling vs SSE regressions
Assert separate mode-specific request patterns.

### Favicon behavior
Assert no failing browser favicon request on dashboard load.

### `loadHistory()` called twice
Assert only one history-loading chain runs at a time.

### Concurrent startup `pollAll()`
Assert startup polling does not issue concurrent batch requests if sequential behavior is required.

### `_historyInFlight` stuck
Assert failure clears the guard and allows retry.

### Startup timing drift
Assert key timing windows remain conservative and stable.

---

## Favicon Strategy Discussion

## Could a real `favicon.ico` be embedded?
Yes, technically.

Possible approaches:
1. embed a small binary `favicon.ico` in firmware and serve it from `/favicon.ico`
2. embed an inline data-URL favicon in `dashboard.html`
3. serve a tiny PNG/SVG icon and reference it via `<link rel=\"icon\">`

## Should the project do that?
Not necessarily.

If `/favicon.ico` can reliably return `204 No Content`, that is sufficient and lower complexity.

Adding a real favicon would:
- increase build/generation complexity
- require maintaining an asset in the pipeline
- require keeping generated/minified outputs consistent

## Recommendation
- primary fix: make `/favicon.ico` reliably return a non-error response (`204` is acceptable)
- optional enhancement: add a tiny embedded or inline favicon only if the project wants branded dashboard behavior and route/build issues are already resolved

---

## Proposed Outcome

Add browser-side regression coverage for request ordering, concurrency, in-flight guards, and favicon behavior, while keeping real-device validation mandatory for final acceptance of stability fixes.
