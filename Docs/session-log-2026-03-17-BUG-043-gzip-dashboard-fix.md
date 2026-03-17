# Session Log — BUG-043 Dashboard Stability: Gzip Compression Fix

**Date:** 2026-03-17
**Version:** v7.5.3.5 → v7.5.4.0
**Baseline:** main branch at commit `44edbe4` (post-PR#41 merge)
**Related:** BUG-043, PRs #39–#41, LESSON-OPS-050–054

---

## Request Understanding

The user reports that despite PRs #39–#41 implementing all planned dashboard stability mitigations (sequential history fetches, in-flight guards, cooperative NVS yielding, serialized boot/poll/history, reduced batch sizes), the ESP32-C3 still exhibits instability:

1. **Polling mode**: Dashboard loads initially but crashes on F5. Free heap oscillates 44K–73K.
2. **SSE mode**: Crashes 30–60s after page open, crashes on F5. Once stabilized, heap is calmer.
3. **`/favicon.ico` still returns HTTP 500** despite firmware handler sending 204.
4. **Manual curl commands work fine** — no instability from individual endpoint access.

The crash trigger is consistently the browser requesting the full page, not individual API endpoints.

---

## Deliverables

1. Comprehensive root cause analysis explaining why PRs #39–#41 didn't fully resolve the issue
2. Concrete fix implementation
3. Downloadable code package with proper directory structure
4. Deployment, test, and push commands
5. Assessment of proposed browser test plans

---

## Root Cause Analysis

### Why the previous fixes were reasonable but insufficient

The PRs #39–#41 correctly identified and fixed the **request scheduling** problems (concurrent history fetches, in-flight guard gaps, polling burst, SSE redundant requests). These were real issues. The request budget analysis was accurate, and the fixes reduced request pressure significantly.

However, the fixes treated the **request count** as the bottleneck while missing the **response size** bottleneck. The core problem is:

### RC-ACTUAL: The 190KB uncompressed dashboard HTML transfer blocks the HTTP task for 2–4 seconds

**Evidence chain:**

1. **Manual curl works fine** — individual API endpoints return small JSON/CSV payloads (< 5KB each). These complete quickly and don't block the HTTP task.

2. **Dashboard open/F5 causes instability** — both trigger a `GET /dashboard.html` request that transfers **194,533 bytes** of uncompressed HTML. On the ESP32-C3's single core, this monopolizes the HTTP server task for 2–4 seconds (TCP send buffer fills, blocks waiting for ACKs, drains incrementally).

3. **Heap oscillates 44K–73K in polling mode** — the 29KB swing corresponds to TCP send buffers being allocated during the 190KB transfer, then freed. At the low point (44K), there's barely enough heap for concurrent operations.

4. **F5 is worse than initial open** — F5 sends TCP RST on all active connections, then immediately requests `/dashboard.html` again. The ESP hasn't finished cleaning up the old connections when the new 190KB transfer starts. Connection slot exhaustion or heap exhaustion follows.

5. **SSE mode crashes slower (30–60s)** — the SSE EventSource holds one persistent connection. When the 190KB dashboard HTML finishes transferring, the SSE stream starts. But if any concurrent request arrives during the initial transfer window (storage-stats at t+5s, history at t+10s), the single-core ESP32-C3 can't service both the ongoing HTML transfer AND the new request.

6. **`gzip -9` compresses dashboard.html from 194,533 → 44,926 bytes (77% reduction)** — this directly translates to a 4.3× reduction in HTTP task blocking time.

### RC-FAVICON: Handler registration order puts ESPHome's web_server before our HistoryWebHandler

The firmware registers `HistoryWebHandler` in `on_boot` at priority `-100` (runs after component setup). ESPHome's `web_server` component registers its own handler during component initialization (runs earlier). When the ESP-IDF HTTP server receives `/favicon.ico`, ESPHome's handler gets first look, doesn't know how to serve a favicon, and returns 500. Our handler's `request->send(204)` at line 1071 never executes.

**Why the previous plan didn't catch this:** The remediation plan focused on dashboard JS request scheduling. The favicon 500 was noted but classified as cosmetic. In reality, every page load generates a browser-initiated `/favicon.ico` request that adds connection pressure during the critical boot window.

---

## Solution Design

### Fix 1: Gzip-compress the dashboard HTML in the build pipeline (PRIMARY FIX)

Modify `scripts/generate-header.sh` to:
1. Gzip the input HTML with maximum compression (`gzip -9`)
2. Output a C `uint8_t[]` byte array (not a raw string literal — gzip output is binary)
3. Include a version comment readable by preflight checks

This changes `dashboard.h` from a 190KB raw string to a ~45KB gzip byte array.

### Fix 2: Serve gzipped dashboard with `Content-Encoding: gzip`

Modify `handle_dashboard_()` in `sensor_history_multi.h` to:
1. Reference the gzipped array and its length
2. Add `Content-Encoding: gzip` response header
3. Browser decompresses transparently — works for both viewing and download

### Fix 3: Inline favicon to prevent browser request

Add `<link rel="icon" href="data:,">` to `dashboard.html` `<head>`. This tells the browser "the favicon is an empty data URI" — no HTTP request to `/favicon.ico` is ever made. Eliminates one connection during the critical boot window and removes the 500 error entirely for browser clients.

### Fix 4: Update preflight checks

Since `dashboard.h` is now binary gzip data, the version grep needs to check the embedded comment line instead of searching for `App.version` inside the payload.

---

## Impact Assessment

| Metric | Before | After |
|--------|--------|-------|
| Dashboard transfer size | 194,533 bytes | ~44,926 bytes |
| HTTP task blocking (dashboard serve) | 2–4 seconds | 0.4–0.8 seconds |
| Favicon requests per page load | 1 (→ 500 error) | 0 |
| Flash usage for dashboard | ~195 KB | ~45 KB |
| Connection pressure at boot | 3+ concurrent | 2 concurrent |

---

## Files Modified

| File | Change |
|------|--------|
| `dashboard/dashboard.html` | Add inline favicon `<link>` |
| `scripts/generate-header.sh` | Gzip compress + C byte array output |
| `dashboard/sensor_history_multi.h` | Serve gzipped content with Content-Encoding header |
| `scripts/preflight.sh` | Update dashboard.h version check for gzip format |
| `dashboard/dashboard.h` | Regenerated (now gzip byte array) |

---

## Assessment: Proposed Browser Test Plans

The browser test proposals in `BUG-043-post-PR41-test-plans.md` are **well-structured and appropriate** for catching JS-level regressions (request ordering, duplicate requests, in-flight guards, timing). Specifically:

**Tests that make sense and should be implemented:**
- Duplicate request prevention (manifest, history, status, storage)
- `loadHistory()` reentrancy / `_historyInFlight` guard
- `_historyInFlight` recovery after failure
- Transport regression (SSE vs polling mode branching)
- Startup timing sequence validation

**Tests that can't catch this specific bug:**
- None of the browser tests would have caught the gzip/transfer-size issue because Playwright runs against a mock server with unlimited bandwidth and zero transfer delay. The 190KB HTML loads instantaneously in the test environment.

**Recommendation:** Implement the proposed browser tests for JS regression coverage, but add a **static analysis check** in preflight.sh that verifies dashboard.h uses gzip format and is below a size threshold (e.g., 100KB). This catches accidental regression to uncompressed serving.

_End of session log._

---

## Rev2: Post-Gzip Testing — Continued Crash Analysis

### Test Result

Gzip compression deployed successfully (confirmed 48KB transfer, Content-Encoding: gzip in response headers). However, the dashboard crash persisted — the gzip change was necessary (reduces transfer blocking) but did not address the actual crash mechanism.

### True Root Cause: `beginResponseStream` reallocation cascade in `handle_history_()`

The crash occurs when `handle_history_()` builds a history CSV response using `beginResponseStream("text/plain")`. This creates an `AsyncResponseStream` backed by a `std::string` that grows through repeated `resp->print()` calls. With 336 NVS segments (14 days of hourly persistence), each containing 4 data points per sensor:

1. **1,344+ print() calls** → std::string grows through 128→256→512→...→16K→32K
2. At the **16K→32K transition**, both old (16K) and new (32K) buffers exist simultaneously = **48KB temporary heap usage**
3. With SSE connection + TCP buffers (~6KB) + API connection + other overhead, total exceeds available ~55-60KB free heap
4. **Allocation failure → crash/reboot**

This explains every observed symptom:
- **curl works** — single connection, full 72K heap available, reallocation completes
- **SSE mode crash at 30-60s** — SSE holds ~6K of buffers, history loads at t+10s, the 48K realloc peak + 6K SSE = 54K > available
- **Polling mode oscillation then crash on F5** — polling background connections consume heap, F5 restarts everything simultaneously
- **No crash when dashboard is idle** — history load is a one-time event; once complete, the string is freed

### Rev2 Fixes Applied

**1. Pre-reserved `std::string` with `reserve()`** — replaces `beginResponseStream`. Calculates expected CSV size upfront (`segments × points_per_segment × 20 bytes/line`), reserves that capacity in a single allocation, then appends CSV data without any reallocation.

**2. Raw-bytes `beginResponse` for zero-copy send** — instead of `beginResponse(200, type, csv.c_str())` which copies the string into the response, uses `beginResponse(200, type, reinterpret_cast<const uint8_t*>(csv.data()), csv.size())` which wraps the existing buffer.

**3. String-based CSV builders** — new `HistoryBuffer::append_csv_to()` and `append_snapshot_series_csv_()` that write directly to the pre-reserved string.

**4. More aggressive NVS yielding** — changed from 1ms/4-reads to 5ms/2-reads, giving BLE/WiFi/API 2.5× more CPU time between NVS reads.

### Files Modified (Rev2)

| File | Change |
|------|--------|
| `dashboard/sensor_history_multi.h` | Pre-reserved string history response, string CSV builders, aggressive NVS yield |

(All other files from Rev1 remain — gzip dashboard, inline favicon, preflight checks)

_End of Rev2._
