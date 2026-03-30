# v7.6.0.0 Post-Merge Incident Report: HTTPD POST Crash and Reboot Loop

_Date: 2026-03-30_  
_Target: ESP32-S3 aggregator (`192.168.120.191`)

---

## 1) What is currently happening (observed problems)

### A) POST requests with `Content-Length: 0` can crash the board
- Reproducible with:
  - `curl -v -X POST -d '' -u ESPadmin:ESppass100 http://192.168.120.191/api/system/reset-satellites`
- Result:
  - Client sees `Recv failure: Connection reset by peer`.
  - Device panics (`StoreProhibited`) and reboots.
  - Backtrace is often corrupted and lands in FreeRTOS context-switch paths (`vPortYieldFromInt`), consistent with prior memory corruption in HTTP handling.

### B) POST requests without `Content-Length` do not crash (clean 411)
- Reproducible with:
  - `curl -v -X POST -u ESPadmin:ESppass100 http://192.168.120.191/api/system/reset-satellites`
- Result:
  - `HTTP/1.1 411 Length Required`
  - ESPHome log warning: `Content length is required for post: /api/system/reset-satellites`
  - Board remains stable.

### C) Dashboard-open reboot action can trigger repeated failures
- Observed behavior:
  - With dashboard open, clicking ESP reboot can lead to repeated crash/reboot behavior until dashboard page is closed.
- Serial evidence includes:
  - `***ERROR*** A stack overflow in task httpd has been detected.`
  - `assert failed: sys_arch_sem_wait ... taking semaphore failed`
  - decoded path through lwIP `select` and `httpd_server/httpd_thread`.

---

## 2) What tests have been done

1. **Board-profile sdkconfig changes and rebuild**
   - S3 profile updated to:
     - `CONFIG_LWIP_MAX_SOCKETS: "24"`
     - `CONFIG_HTTPD_STACK_SIZE: "16384"`
   - C3 and WROOM profiles updated to include `CONFIG_HTTPD_STACK_SIZE: "8192"`.
   - Regenerated YAML using `python3 scripts/render_sensor_config.py --write`.
   - Verified generated S3 YAML contains expected sdkconfig options.

2. **Controlled POST request-shape tests**
   - `POST + -d ''` (Content-Length: 0) to `/api/system/reset-satellites` causes crash.
   - `POST` without `-d` (no Content-Length) returns 411 and does not crash.

3. **Dashboard-triggered reboot behavior**
   - With dashboard open, reboot button action can produce repeated httpd-related panics and reboot loops.
   - Closing dashboard stops loop behavior.

4. **Serial backtrace capture**
   - Multiple panics collected; some traces corrupted, but repeated signal centers on HTTPD/lwIP/FreeRTOS scheduling failure after problematic request paths.

---

## 3) Primary suspicions causing the problem

### Suspicion #1 (highest confidence)
**ESPHome `web_server_idf` edge-case bug in accepted zero-length POST handling.**

Why:
- Clear bifurcation:
  - Missing Content-Length -> framework rejects with 411 (safe path)
  - Content-Length: 0 -> accepted path -> crash

### Suspicion #2
**Dashboard POST request construction mismatch + silent error handling.**

Why:
- Some dashboard POST calls are sent without explicit body.
- Browser may omit Content-Length for bodyless POST, producing 411.
- Error swallowing can hide failures and make behavior appear inconsistent.

### Suspicion #3
**HTTPD task/lwIP stress during reboot while dashboard remains connected and retries/reconnects.**

Why:
- Repeated stack overflow and `sys_arch_sem_wait` assertion observed in `httpd_server` path while dashboard remains open.

### Suspicion #4 (lower confidence)
Residual custom handler misuse (request lifecycle, double-send, invalid pointer usage), but current evidence points first to framework/request-shape interaction.

---

## 4) Proposed fixes

### Fix A — Dashboard JS request-shape hardening (immediate)
For all dashboard POST calls, send a non-empty JSON body and explicit content-type:

```js
fetch(url, {
  method: 'POST',
  headers: {
    'Authorization': 'Basic ...',
    'Content-Type': 'application/json'
  },
  body: '{}',
  cache: 'no-store'
})
```

Apply to:
- management actions (reboot/delete/reset)
- import begin/data/finish POST paths

### Fix B — Firmware-side defensive guardrails
- Add early POST validation and fail-safe responses for malformed/unsupported request states.
- Avoid unsafe operations unless request object is fully valid.
- Keep handler logic minimal and deterministic on HTTPD task.

### Fix C — Keep board-profile hardening
- Retain profile-based `sdkconfig_options` (especially sockets and HTTPD stack).
- Ensure changes exist in board profiles, not only in template YAML.

### Fix D — Upstream tracking
- File/track ESPHome issue with minimal reproducer:
  - POST without Content-Length -> 411 (safe)
  - POST with Content-Length: 0 -> crash

---

## 5) How to confirm fixes are working

Run the following matrix after implementing Fix A + Fix B:

1. `curl -v -X POST -d '' -u ESPadmin:ESppass100 http://192.168.120.191/api/system/reset-satellites`
   - Expected: no crash; controlled HTTP response.

2. `curl -v -X POST -u ESPadmin:ESppass100 http://192.168.120.191/api/system/reset-satellites`
   - Expected: 411 or controlled error; no crash.

3. `curl -v -X POST -d '{}' -H 'Content-Type: application/json' -u ESPadmin:ESppass100 http://192.168.120.191/api/reboot`
   - Expected: intentional reboot only; no panic pre-reboot.

4. Dashboard open + reboot button
   - Expected: one clean reboot, then recovery.
   - No crash loop, no repeated httpd stack overflow, no lwIP semaphore assert.

5. Regression validation
   - Unauth reset -> 401 JSON
   - Auth reset -> success JSON with count
   - Aggregator gateways endpoint remains healthy
   - Persistence across reboot verified

---

## 6) Way forward to avoid this class of problem

1. **Standardize HTTP contract**
   - All frontend POSTs must include explicit JSON body and content-type.
   - Enforce via a shared `postJson()` helper.

2. **Add negative integration tests**
   - POST no body / no Content-Length
   - POST Content-Length: 0
   - POST `{}` body
   - Validate “no device crash” as required outcome.

3. **Improve observability for incident builds**
   - Maintain a debug profile with serial logging enabled for panic capture.
   - Add lightweight endpoint-entry/exit logs around management routes.

4. **Track framework risk explicitly**
   - Open/monitor upstream issue for `web_server_idf` zero-length POST behavior.
   - Record workaround policy in project docs.

5. **Keep board-profile-first config process**
   - Continue applying `sdkconfig_options` in board profiles and regenerate from there.

---

## 7) Should future development steps be altered?

**Yes — sequencing should be adjusted.**

Before proceeding with additional Phase D features (`add/delete/test satellite` APIs), complete this stabilization sequence:

1. Land dashboard POST request-shape fixes.
2. Land firmware-side POST defensive guards.
3. Re-run full Phase D Step 0 verification (including dashboard-open reboot stability).
4. Only then continue with v7.6.0.1+ feature work.

This reduces risk of building new features atop unstable HTTP server behavior.

---

_End of report._
