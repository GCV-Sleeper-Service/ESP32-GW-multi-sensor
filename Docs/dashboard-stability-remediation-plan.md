# Dashboard Stability Remediation Plan — BUG-037

_Remediation Plan for v7.5.3.3-hotfix_
_Date: 2026-03-16_
_Prerequisite: v7.5.3.3 merged on `main`; dashboard instability confirmed on real device_
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_
_Related: BUG-037, LESSON-OPS-050, LESSON-OPS-051_

---

## Goal

Eliminate the dashboard-triggered ESP32-C3 crash/reboot observed during post-merge validation of `v7.5.3.3`. The device must remain stable when the dashboard is opened locally, remotely, closed and reopened, and left running for extended periods.

**Key principle:** This is a focused stabilization hotfix. No new features, no version bump, no `/api/v2/live` implementation, no SensorEntity migration work. The only changes are to `dashboard/dashboard.js` request scheduling logic and the generated dashboard artifacts.

---

## Background Reference

- `Docs/dashboard-instability-investigation-2026-03-16_Version2` — observed behavior, evidence, and root cause hypothesis
- `Docs/session-log-2026-03-16-v7.5.3.3-dashboard-instability_Version2` — session log with device validation details
- `Docs/handoff-2026-03-16-v7.5.3.3-dashboard-instability_Version2` — handoff notes
- `Docs/bugs-and-lessons-learned.md` — BUG-037 entry
- `Docs/phase3-implementation-plan.md` — confirms `/api/v2/live` is `v7.5.3.4`, not current scope

---

## Confirmed Root Cause Analysis

Real-device testing confirmed that the ESP32-C3 crashes are caused by **HTTP connection/socket exhaustion** from the dashboard JavaScript creating excessive concurrent and overlapping requests. The ESP-IDF HTTP server has limited connection slots (~4-7 concurrent), and the dashboard overwhelms this capacity through six independent issues acting together.

### Issue 1: SSE `ping` handler triggers `loadStatusSnapshot()` on every ping

**Location:** `dashboard/dashboard.js` line 2891
**Code:**
```javascript
evtSource.addEventListener('ping', function() {
  document.getElementById('statusDot').classList.add('connected');
  document.getElementById('statusText').textContent = 'connected (SSE)';
  loadStatusSnapshot().catch(function(){});  // ← unnecessary HTTP request
});
```

**Problem:** SSE pings fire frequently (every few seconds). Each ping triggers a full `GET /api/status` fetch. SSE already delivers real-time state via `state` events, making these fetches entirely redundant in SSE mode.

**Impact:** 10-20+ extra `/api/status` requests per minute while SSE is connected.

---

### Issue 2: SSE `onopen` handler triggers `loadStatusSnapshot()`

**Location:** `dashboard/dashboard.js` line 2892
**Code:**
```javascript
evtSource.onopen = function() {
  document.getElementById('statusDot').classList.add('connected');
  document.getElementById('statusText').textContent = 'connected (SSE)';
  dlog('SSE connected', 'ok');
  loadStatusSnapshot().catch(function(){});  // ← fires during boot alongside explicit call
};
```

**Problem:** The boot sequence at line 2999 already calls `loadStatusSnapshot()` explicitly. When `connectSSE()` is called at line 3000, the SSE `onopen` fires almost immediately, creating a second concurrent `/api/status` request within milliseconds of the first.

**Impact:** Doubled status request on every SSE connect/reconnect.

---

### Issue 3: Double status polling in polling mode

**Location:** `dashboard/dashboard.js` lines 2918-2932 and 3007-3010

**Boot sequence creates a 30s status interval (line 3007):**
```javascript
statusSnapshotIntervalId = setInterval(function() {
  if (isImportActive()) return;
  loadStatusSnapshot().catch(function(){});
}, 30000);
```

**`startPolling()` includes `loadStatusSnapshot()` in its 15s interval (line 2926):**
```javascript
pollingLiveIntervalId = setInterval(function() {
  if (isImportActive()) return;
  Promise.all([pollAll(livePaths), loadStatusSnapshot()]).catch(function(){});
}, 15000);
```

**Problem:** In polling mode, `loadStatusSnapshot()` is called every 15s (from `startPolling`) AND every 30s (from the boot-created interval). Every 30 seconds both fire simultaneously.

**Impact:** 1.5x the intended status polling rate, with periodic overlap every 30s.

---

### Issue 4: No in-flight guard on `loadStatusSnapshot()`

**Location:** `dashboard/dashboard.js` lines 698-707
**Code:**
```javascript
function loadStatusSnapshot() {
  if (isImportActive()) return Promise.resolve(false);
  return fetch(ESP_HOST + '/api/status', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(status) { return applyStatusSnapshot(status); })
    .catch(function(err) {
      dlog('Status snapshot failed: ' + err.message, 'err');
      return false;
    });
}
```

**Problem:** No guard against concurrent invocations. When the ESP is slow to respond (under load), multiple callers (boot, SSE ping, SSE onopen, polling interval, status interval) can stack up overlapping requests. Each pending request holds an HTTP connection slot on the ESP.

**Impact:** Under load, 3-5 concurrent `/api/status` requests can be in flight simultaneously.

---

### Issue 5: No in-flight guard on `loadStorageStats()`

**Location:** `dashboard/dashboard.js` lines 1530-1557

**Problem:** Same issue as `loadStatusSnapshot()`. Additionally, `loadStorageStats()` has built-in retry logic (up to 3 attempts with recursive calls on failure), so a single failed call can cascade into 3 requests.

**Impact:** Under load, cascading retries can create 3+ concurrent `/api/storage-stats` requests.

---

### Issue 6: Startup request burst — no staggering

**Location:** `dashboard/dashboard.js` lines 2999-3014
**Code:**
```javascript
loadStatusSnapshot().catch(function(){});                    // immediate
if (TRANSPORT === 'sse') { connectSSE(); }                   // immediate (triggers onopen → another loadStatusSnapshot)
else { startPolling(); }                                      // immediate (triggers loadStatusSnapshot + pollAll)
loadStorageStats().catch(function(){});                       // immediate
storageStatsIntervalId = setInterval(..., 60000);             // interval created immediately
statusSnapshotIntervalId = setInterval(..., 30000);           // interval created immediately
historyBootstrapTimerId = setTimeout(function() {
  loadHistory();                                              // 2s delay, then 6 CSV fetches (temp+hum × 3 sensors)
}, 2000);
```

**Problem:** Within ~2 seconds of boot, the dashboard fires:
1. `GET /api/status` (explicit)
2. `GET /api/status` (SSE onopen or startPolling initial)
3. SSE EventSource connection OR `pollAll()` (multiple entity fetches)
4. `GET /api/storage-stats`
5. 6× history CSV fetches at t+2s (`/history/{id}/temp`, `/history/{id}/hum` × 3 sensors)

This creates 8-12+ HTTP requests within 2 seconds — well beyond the ESP-IDF HTTP server's concurrent connection capacity.

**Impact:** Connection queue overflow → `httpd_accept_conn: error in accept (23)` → eventual panic/reboot.

---

### Combined effect on ESP32-C3

The ESP-IDF HTTP server on ESP32-C3 supports approximately 4-7 concurrent connections. The dashboard's combined behavior at startup can create 8-12+ simultaneous requests, and ongoing SSE ping/status polling can sustain 3-5 concurrent requests indefinitely. This exceeds the server's capacity, causes socket exhaustion, and triggers the observed `httpd_accept_conn: error in accept (23)` followed by panic/reboot.

Remote hosted (polling) mode is worse because:
- No SSE, so all data comes via polling (`pollAll` every 15s + `loadStatusSnapshot` every 15s + 30s)
- Close/reopen repeats the full startup burst
- Cloudflare proxy adds latency, keeping connections open longer

---

## Remediation Steps

This remediation is implemented as a **single PR** since all fixes are tightly coupled dashboard JS changes that must be deployed together to be effective. The fixes are ordered by implementation sequence within the PR.

---

### Fix 1 — Add in-flight guard to `loadStatusSnapshot()`

**Scope:** Prevent concurrent `/api/status` requests from stacking up.

**File modified:** `dashboard/dashboard.js` (around line 698)

**Implementation:**

Add a module-level flag `_statusInFlight` above the function. When a request is in flight, subsequent calls return immediately with a resolved promise.

```javascript
var _statusInFlight = false;

function loadStatusSnapshot() {
  if (isImportActive()) return Promise.resolve(false);
  if (_statusInFlight) return Promise.resolve(false);
  _statusInFlight = true;
  return fetch(ESP_HOST + '/api/status', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(status) { return applyStatusSnapshot(status); })
    .catch(function(err) {
      dlog('Status snapshot failed: ' + err.message, 'err');
      return false;
    })
    .then(function(result) { _statusInFlight = false; return result; },
          function(err) { _statusInFlight = false; throw err; });
}
```

**Critical notes:**
- The flag must be cleared in both success and error paths using a `.then(onFulfilled, onRejected)` pattern
- The guard does NOT block callers — it returns a resolved promise so callers' `.then()` chains still work
- The `isImportActive()` check is preserved and runs before the in-flight check

**Verification:**
- Open browser DevTools Network tab
- Rapidly fire multiple status requests (e.g., via SSE reconnect)
- Confirm only one `/api/status` request is in flight at any time

---

### Fix 2 — Add in-flight guard to `loadStorageStats()`

**Scope:** Prevent concurrent `/api/storage-stats` requests from stacking up. Internal retry attempts are still allowed.

**File modified:** `dashboard/dashboard.js` (around line 1530)

**Implementation:**

Add a module-level flag `_storageStatsInFlight` above the function. The guard only blocks new top-level calls (`attempt` is undefined/0). Internal retries (`attempt > 0`) bypass the guard since they are sequential, not concurrent.

```javascript
var _storageStatsInFlight = false;

function loadStorageStats(attempt) {
  if (isImportActive()) return Promise.resolve(null);
  var tryNum = Number(attempt || 0);
  if (_storageStatsInFlight && tryNum === 0) return Promise.resolve(null);
  _storageStatsInFlight = true;
  var statusEl = document.getElementById('storage-status');
  if (statusEl) {
    statusEl.textContent = tryNum === 0
      ? 'Refreshing storage statistics...'
      : 'Retrying storage statistics (' + (tryNum + 1) + '/3)...';
  }
  return fetch(ESP_HOST + '/api/storage-stats', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(data) { _storageStatsInFlight = false; applyStorageStats(data); return data; })
    .catch(function(err) {
      if (tryNum < 2) {
        return new Promise(function(resolve) {
          setTimeout(resolve, 600 * (tryNum + 1));
        }).then(function() {
          return loadStorageStats(tryNum + 1);
        });
      }
      _storageStatsInFlight = false;
      if (statusEl) {
        var hint = (window.location.protocol === 'file:')
          ? ' Check fallback host and CORS headers.'
          : '';
        statusEl.textContent = 'Storage stats failed: ' + err.message + hint;
      }
      throw err;
    });
}
```

**Critical notes:**
- The flag is cleared on success and on final failure (after all retries exhausted)
- The flag is NOT cleared between retry attempts — retries are sequential via the recursive call
- The `tryNum === 0` condition ensures retries are not blocked by the in-flight guard

---

### Fix 3 — Remove `loadStatusSnapshot()` from SSE `ping` handler

**Scope:** Eliminate redundant `/api/status` fetches on every SSE ping event.

**File modified:** `dashboard/dashboard.js` (line 2891)

**Current code:**
```javascript
evtSource.addEventListener('ping', function() {
  document.getElementById('statusDot').classList.add('connected');
  document.getElementById('statusText').textContent = 'connected (SSE)';
  loadStatusSnapshot().catch(function(){});
});
```

**New code:**
```javascript
evtSource.addEventListener('ping', function() {
  document.getElementById('statusDot').classList.add('connected');
  document.getElementById('statusText').textContent = 'connected (SSE)';
});
```

**Critical notes:**
- SSE `state` events already deliver real-time sensor data — the ping handler only needs to update the connection indicator
- The boot sequence calls `loadStatusSnapshot()` once at startup, which is sufficient
- This single change eliminates the largest source of redundant HTTP requests (10-20+/minute)

---

### Fix 4 — Remove `loadStatusSnapshot()` from SSE `onopen` handler

**Scope:** Eliminate the duplicate status request that fires when SSE connects during boot.

**File modified:** `dashboard/dashboard.js` (line 2892)

**Current code:**
```javascript
evtSource.onopen = function() {
  document.getElementById('statusDot').classList.add('connected');
  document.getElementById('statusText').textContent = 'connected (SSE)';
  dlog('SSE connected', 'ok');
  loadStatusSnapshot().catch(function(){});
};
```

**New code:**
```javascript
evtSource.onopen = function() {
  document.getElementById('statusDot').classList.add('connected');
  document.getElementById('statusText').textContent = 'connected (SSE)';
  dlog('SSE connected', 'ok');
};
```

**Critical notes:**
- The boot sequence at line 2999 already calls `loadStatusSnapshot()` explicitly
- Removing it from `onopen` prevents the immediate double-fetch on boot
- On SSE reconnect (after a transient disconnect), the status will refresh via the next interval tick or the next SSE `state` event — no data is lost

---

### Fix 5 — Make 30s `statusSnapshotIntervalId` conditional (polling mode only)

**Scope:** In SSE mode, state is delivered via SSE events. The 30s `/api/status` polling interval is unnecessary and should only exist in polling mode.

**File modified:** `dashboard/dashboard.js` (lines 3007-3010 in `App.Boot.start()`)

**Current code:**
```javascript
statusSnapshotIntervalId = setInterval(function() {
  if (isImportActive()) return;
  loadStatusSnapshot().catch(function(){});
}, 30000);
```

**New code:**
```javascript
if (TRANSPORT !== 'sse') {
  statusSnapshotIntervalId = setInterval(function() {
    if (isImportActive()) return;
    loadStatusSnapshot().catch(function(){});
  }, 30000);
}
```

**Critical notes:**
- In SSE mode, `loadStatusSnapshot()` is called once at boot (line 2999) and then state updates arrive via SSE `state` events
- In polling mode, this 30s interval remains the sole status refresh mechanism (see Fix 6)
- The `resumeDashboardNetworkActivity()` function (line 1633) also creates this interval — that code must also be wrapped in the same `TRANSPORT !== 'sse'` condition

**Also update `resumeDashboardNetworkActivity()` (line 1633):**
```javascript
if (!statusSnapshotIntervalId && TRANSPORT !== 'sse') {
  statusSnapshotIntervalId = setInterval(function() {
    if (isImportActive()) return;
    loadStatusSnapshot().catch(function(){});
  }, 30000);
}
```

---

### Fix 6 — Remove duplicate `loadStatusSnapshot()` from `startPolling()` 15s interval

**Scope:** In polling mode, status was being fetched at both 15s (inside `startPolling`) and 30s (from boot interval). Remove the duplicate from the 15s interval.

**File modified:** `dashboard/dashboard.js` (lines 2923-2927 in `startPolling()`)

**Current code:**
```javascript
Promise.all([pollAll(POLL_DEVICE.concat(livePaths)), loadStatusSnapshot()]).then(function() { dlog('Initial poll done', 'ok'); });
pollingLiveIntervalId = setInterval(function() {
  if (isImportActive()) return;
  Promise.all([pollAll(livePaths), loadStatusSnapshot()]).catch(function(){});
}, 15000);
```

**New code:**
```javascript
Promise.all([pollAll(POLL_DEVICE.concat(livePaths)), loadStatusSnapshot()]).then(function() { dlog('Initial poll done', 'ok'); });
pollingLiveIntervalId = setInterval(function() {
  if (isImportActive()) return;
  pollAll(livePaths).catch(function(){});
}, 15000);
```

**Critical notes:**
- The initial `loadStatusSnapshot()` call is preserved (needed for first data load)
- The 15s interval now only polls sensor entity data via `pollAll(livePaths)`
- Status is refreshed via the 30s `statusSnapshotIntervalId` (Fix 5 ensures this exists in polling mode)
- Net effect: status is fetched every 30s instead of every 15s in polling mode

---

### Fix 7 — Stagger startup requests

**Scope:** Spread the boot-time request burst across 5+ seconds instead of firing everything within ~200ms.

**File modified:** `dashboard/dashboard.js` (lines 2999-3014 in `App.Boot.start()`)

**Current code:**
```javascript
loadStatusSnapshot().catch(function(){});
if (TRANSPORT === 'sse') { try { connectSSE(); } catch(e) { ... } }
else { try { startPolling(); } catch(e) { ... } }
loadStorageStats().catch(function(){});
storageStatsIntervalId = setInterval(function() { ... }, 60000);
statusSnapshotIntervalId = setInterval(function() { ... }, 30000);
historyBootstrapTimerId = setTimeout(function() { loadHistory(); }, 2000);
```

**New code:**
```javascript
loadStatusSnapshot().catch(function(){});
if (TRANSPORT === 'sse') { try { connectSSE(); } catch(e) { ... } }
else { try { startPolling(); } catch(e) { ... } }

// Stagger non-critical requests to avoid overwhelming the ESP32-C3 HTTP server
// (BUG-037: startup request burst caused httpd_accept_conn failures and panic/reboot)
setTimeout(function() {
  if (isImportActive()) return;
  loadStorageStats().catch(function(){});
  storageStatsIntervalId = setInterval(function() {
    if (isImportActive()) return;
    loadStorageStats().catch(function(){});
  }, 120000);
}, 3000);

if (TRANSPORT !== 'sse') {
  statusSnapshotIntervalId = setInterval(function() {
    if (isImportActive()) return;
    loadStatusSnapshot().catch(function(){});
  }, 30000);
}

historyBootstrapTimerId = setTimeout(function() {
  if (isImportActive()) return;
  loadHistory();
}, 5000);
```

**Startup timeline after fix:**

| Time | Action | Connections |
|------|--------|-------------|
| t+0ms | `loadStatusSnapshot()` | 1 |
| t+0ms | `connectSSE()` or `startPolling()` initial | 1-2 |
| t+3000ms | `loadStorageStats()` | 1 |
| t+5000ms | `loadHistory()` (6 CSV fetches, sequential per sensor) | 1-2 |

**Critical notes:**
- `loadStatusSnapshot()` and transport connection remain immediate — these are needed for the initial UI render
- `loadStorageStats()` deferred to t+3s — storage stats are displayed below the fold and are not urgently needed
- `loadHistory()` deferred from t+2s to t+5s — gives storage stats time to complete first
- Storage stats interval created inside the same `setTimeout` to avoid an early first tick
- The history load already fetches sequentially per sensor (via `Promise.all` per sensor, then chained), so once it starts it creates moderate load, but the 5s delay ensures the initial burst has cleared

---

### Fix 8 — Increase storage stats interval from 60s to 120s

**Scope:** Reduce the frequency of `/api/storage-stats` requests. Storage statistics change only when NVS persist cycles complete (every ~60 minutes), so polling every 60s is unnecessarily aggressive.

**File modified:** `dashboard/dashboard.js`

**Locations to update:**
1. Boot sequence `storageStatsIntervalId` creation (formerly line 3003-3006) — change `60000` to `120000`
2. `resumeDashboardNetworkActivity()` (line 1628-1631) — change `60000` to `120000`

**Critical notes:**
- 120s is still far more frequent than the ~60-minute NVS persist cycle
- After explicit actions (delete history, import), `loadStorageStats()` is called directly — no delay
- The in-flight guard (Fix 2) prevents overlap even at the old 60s cadence, but 120s further reduces baseline load

---

### Fix 9 — Mirror all changes to `dashboard/dashboard.html`

**Scope:** `dashboard/dashboard.html` embeds the dashboard JavaScript inline. All fixes from Fix 1-8 must be applied identically to the corresponding code in `dashboard.html`.

**File modified:** `dashboard/dashboard.html`

**Locations (line numbers from the `dashboard.html` grep results):**
1. Line 1562 — `loadStatusSnapshot()`: add `_statusInFlight` guard (Fix 1)
2. Before line 1530 equivalent — `loadStorageStats()`: add `_storageStatsInFlight` guard (Fix 2)
3. Line 3755 — SSE `ping` handler: remove `loadStatusSnapshot()` (Fix 3)
4. Line 3756 — SSE `onopen` handler: remove `loadStatusSnapshot()` (Fix 4)
5. Lines 3871-3873 — boot `statusSnapshotIntervalId`: wrap in `TRANSPORT !== 'sse'` (Fix 5)
6. Lines 2497-2500 — `resumeDashboardNetworkActivity()` `statusSnapshotIntervalId`: add `TRANSPORT !== 'sse'` condition (Fix 5)
7. Line 3790 — `startPolling()` 15s interval: remove `loadStatusSnapshot()` (Fix 6)
8. Lines 3863-3878 — boot sequence: apply staggering (Fix 7)
9. Lines 3867, 2492 — storage stats intervals: change `60000` to `120000` (Fix 8)

**Critical notes:**
- Per LESSON-OPS-049: `dashboard.html` is the source of truth for the embedded firmware payload
- Changes must be byte-identical in logic to `dashboard.js`
- After editing, `generate-header.sh` must be run to regenerate `dashboard.min.html` and `dashboard.h`

---

### Fix 10 — Regenerate dashboard artifacts

**Scope:** Regenerate `dashboard/dashboard.min.html` and `dashboard/dashboard.h` from the updated `dashboard/dashboard.html`.

**Commands:**
```bash
bash scripts/generate-header.sh
```

**Verification:**
```bash
bash scripts/preflight.sh
```

**Critical notes:**
- Per LESSON-OPS-043: `dashboard.html` is the HTML source of truth; `dashboard.h` is generated
- Per BUG-039: Always regenerate after any `dashboard.html` edit
- Per BUG-042: Preflight uses regex-based version check that handles both minified and unminified forms

---

### Fix 11 — Update documentation

**Scope:** Update project documentation to reflect the fix and prevent recurrence.

**Files modified:**
- `Docs/bugs-and-lessons-learned.md` — Update BUG-037 with confirmed root cause; add LESSON-OPS-050 and LESSON-OPS-051
- `Docs/changelog.md` — Add hotfix entry

**BUG-037 update:** Replace "Root cause hypothesis" with "Confirmed root cause" detailing all six issues and their fixes.

**New lessons:**
- **LESSON-OPS-050:** Dashboard HTTP request budgeting — ESP32-C3 guardrails
- **LESSON-OPS-051:** Dashboard code changes require real-device validation before merge

See the "Lessons Learned" section below for full text.

---

## Request Budget Summary

### Before remediation

| Source | Cadence | Transport | Requests/minute |
|--------|---------|-----------|-----------------|
| SSE ping → `loadStatusSnapshot()` | ~every 3-5s | SSE | 12-20 |
| SSE onopen → `loadStatusSnapshot()` | on connect | SSE | 1 (burst) |
| Boot `statusSnapshotIntervalId` | 30s | Both | 2 |
| `startPolling()` → `loadStatusSnapshot()` | 15s | Polling | 4 |
| `storageStatsIntervalId` | 60s | Both | 1 |
| Boot burst (first 2s) | once | Both | 8-12 (burst) |
| **Overlapping in-flight** | any | Both | **unlimited stacking** |

**Peak concurrent connections at boot:** 8-12+
**Sustained concurrent connections (SSE):** 3-5
**Sustained concurrent connections (polling):** 4-6

### After remediation

| Source | Cadence | Transport | Requests/minute |
|--------|---------|-----------|-----------------|
| SSE ping | N/A (removed) | SSE | 0 |
| SSE onopen | N/A (removed) | SSE | 0 |
| Boot `statusSnapshotIntervalId` | 30s, polling only | Polling | 2 |
| `startPolling()` live data only | 15s | Polling | 0 (status removed) |
| `storageStatsIntervalId` | 120s | Both | 0.5 |
| Boot burst (staggered over 5s) | once | Both | 3-4 (staggered) |
| **In-flight guard** | any | Both | **max 1 per endpoint** |

**Peak concurrent connections at boot:** 2-3 (staggered)
**Sustained concurrent connections (SSE):** 1 (SSE stream only)
**Sustained concurrent connections (polling):** 2-3

---

## Lessons Learned

### LESSON-OPS-050: Dashboard HTTP request budgeting — ESP32-C3 guardrails

The ESP32-C3 HTTP server (ESP-IDF `httpd`) supports approximately 4-7 concurrent connections. Dashboard JavaScript must respect this constraint:

**Rules for dashboard network code:**
1. **In-flight guards are mandatory** — every `fetch()` function that runs on an interval or event must have a module-level boolean guard preventing concurrent invocations
2. **Never trigger HTTP fetches from SSE event handlers** — SSE `ping` and `onopen` should only update UI indicators, not fire additional HTTP requests. SSE already delivers data.
3. **Stagger startup requests** — boot sequence must not fire more than 2-3 concurrent requests. Use `setTimeout()` to spread non-critical fetches across 3-5 seconds.
4. **One polling interval per endpoint category** — never create two intervals that both call the same fetch function
5. **Polling cadence should match data change rate** — storage stats change every ~60 minutes, so polling every 120s is sufficient. Status changes every ~15 minutes (averaging cycle), so 30s polling is sufficient.
6. **Test with browser DevTools Network tab** — before any dashboard PR is merged, verify the request pattern in the Network tab. There should be no request storms, no duplicate concurrent fetches, and no unbounded request stacking.

### LESSON-OPS-051: Dashboard code changes require real-device validation with dashboard open

Playwright tests validate rendering and data flow against a mock server with unlimited capacity. They do NOT validate HTTP connection pressure on a real ESP32-C3. Any dashboard change that modifies:
- `setInterval()` / `setTimeout()` scheduling
- `fetch()` call sites
- SSE event handlers
- Boot sequence request ordering
- Polling/refresh cadence

...MUST be validated on a real device with the dashboard open before the PR is merged. The validation checklist:
1. Open local dashboard — no crash for 5+ minutes
2. Close and reopen — no crash
3. Open remote dashboard (polling mode) — no crash for 3+ polling cycles
4. Check browser Network tab — no request storms or duplicate fetches
5. Check device logs — no `httpd_accept_conn: error in accept` warnings

---

## Files Modified (Complete List)

| File | Change type | Fix # |
|------|-------------|-------|
| `dashboard/dashboard.js` | Add in-flight guards, remove SSE fetch triggers, stagger boot, reduce cadence | 1-8 |
| `dashboard/dashboard.html` | Mirror all JS changes | 9 |
| `dashboard/dashboard.min.html` | Regenerated | 10 |
| `dashboard/dashboard.h` | Regenerated | 10 |
| `Docs/bugs-and-lessons-learned.md` | BUG-037 confirmed root cause, LESSON-OPS-050, LESSON-OPS-051 | 11 |
| `Docs/changelog.md` | Hotfix entry | 11 |
| `Docs/dashboard-stability-remediation-plan.md` | New: this document | — |

---

## Acceptance Criteria

All must be true before the PR is merged:

- [ ] `loadStatusSnapshot()` has an in-flight guard (`_statusInFlight`)
- [ ] `loadStorageStats()` has an in-flight guard (`_storageStatsInFlight`)
- [ ] SSE `ping` handler does NOT call `loadStatusSnapshot()`
- [ ] SSE `onopen` handler does NOT call `loadStatusSnapshot()`
- [ ] Boot 30s `statusSnapshotIntervalId` is only created in polling mode (`TRANSPORT !== 'sse'`)
- [ ] `resumeDashboardNetworkActivity()` 30s status interval is only created in polling mode
- [ ] `startPolling()` 15s interval does NOT call `loadStatusSnapshot()`
- [ ] Startup `loadStorageStats()` is deferred by 3s
- [ ] Startup `loadHistory()` is deferred by 5s (up from 2s)
- [ ] Storage stats interval is 120s (up from 60s)
- [ ] All changes are mirrored in `dashboard/dashboard.html`
- [ ] `dashboard.min.html` and `dashboard.h` are regenerated
- [ ] `scripts/preflight.sh` passes
- [ ] All Playwright tests pass (no behavior change)
- [ ] `Docs/bugs-and-lessons-learned.md` updated with confirmed root cause and new lessons
- [ ] `Docs/changelog.md` updated with hotfix entry

---

## Device Validation Checklist (post-flash)

This checklist must be executed on the real ESP32-C3 device after OTA flashing the hotfix:

1. **Wait 1-2 minutes** after boot — confirm device runs normally without dashboard open
2. **Open local dashboard** at `http://192.168.120.189/dashboard.html`
   - Confirm no reboot within 5 minutes
   - Confirm sensor data loads and updates
   - Check browser Network tab — no request storms
3. **Close and reopen** the dashboard
   - Confirm no reboot on reopen
4. **Leave dashboard open** for 10+ minutes
   - Confirm sustained stability
   - Confirm no `httpd_accept_conn` errors in device logs
5. **Open remote dashboard** at `https://esp32-2.high-lands.online/dashboard.html`
   - Confirm no crash on open
   - Observe 3+ polling cycles (~45 seconds)
   - Confirm no repeated crash loop
6. **Record heap** via `/api/status` before and after dashboard open
   - Free heap should remain above ~60KB with dashboard active
7. **Verify BLE/history** — confirm BLE collection and 15-minute averaging continue during dashboard activity

---

## Non-Goals

Do **NOT** combine this remediation with:
- `/api/v2/live` implementation (that is `v7.5.3.4`)
- SensorEntity migration work
- Version bump (no version change — this is a hotfix within `v7.5.3.3`)
- New features of any kind
- Dashboard rendering changes
- Firmware C++ changes

---

_End of Dashboard Stability Remediation Plan._
