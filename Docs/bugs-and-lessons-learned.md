# Bugs Fixed & Lessons Learned

_Last updated: 2026-03-09 — v7.4.0_

This document tracks significant bugs, root causes, fixes, and technical lessons. Updated with each version.

---

## Bug Fixes

### BUG-009: Import POST body never delivered (v7.4.0)

**Symptom:** `POST /api/import/segment` with CSV data in the request body always returned "Empty body — expected sensor data lines." Flash history was already erased.

**Root cause:** ESPHome's ESP-IDF web server wrapper does not call `handleBody()`. That method exists only in the Arduino AsyncWebServer implementation. On ESP-IDF, the POST body is consumed by the httpd layer and never forwarded to the custom handler.

**Fix attempt 1 (URL query params):** Moved data to `?d=...` query string. Failed because `url_to()` returns only the path, stripping everything after `?`.

**Fix attempt 2 (Custom headers X-Data/X-Write):** Moved data to custom HTTP headers. Worked on LAN direct access. Failed through Cloudflare tunnel with HTTP 431 because Cloudflare adds ~6 extra headers (CF-Connecting-IP, CF-RAY, CF-Visitor, etc.) that push the total header size past the ESP-IDF httpd's 512-byte `CONFIG_HTTPD_MAX_REQ_HDR_LEN` limit.

**Fix attempt 2a (Increase header buffer):** Set `CONFIG_HTTPD_MAX_REQ_HDR_LEN: "1024"` — still 431 through Cloudflare for some requests. Setting to 2048 caused the dashboard to display a blank page (too much RAM per connection).

**Fix (final — URL path encoding):** Data encoded directly in the URL path:
```
POST /api/import/d/office,temp,1772528400,21.50;office,hum,...
POST /api/import/w/first_floor,temp,...  (write flag)
```
The URL path is preserved by all proxies and is already proven in this codebase (`/history/{id}/temp` works through Cloudflare).

**Lesson:** On ESPHome ESP-IDF, the only reliable data channels from browser to custom handler are: (1) URL path, (2) request headers (limited to ~300 bytes available after browser/proxy overhead), (3) `get_header()` for small values. POST body and URL query parameters are NOT available to custom `AsyncWebHandler` subclasses.

---

### BUG-010: `time()` ambiguous in ESPHome context (v7.4.0)

**Symptom:** Compile error: `reference to 'time' is ambiguous` between C standard library `time()` and `esphome::time` namespace.

**Root cause:** ESPHome defines a `time` namespace that shadows the C standard library function when called without qualification.

**Fix:** Use `::time(nullptr)` instead of `time(nullptr)` to force resolution from the global C namespace.

**Lesson:** Any C standard library function that shares a name with an ESPHome namespace must be called with the `::` global scope prefix. This applies to `time` and potentially others.

---

### BUG-011: Non-JSON server response crashes import error handling (v7.4.0)

**Symptom:** When the ESP returned "Header fields are too long" (plain text, not JSON), the browser's `.json()` call threw an uncaught parse error. The user saw `Unexpected token 'H'...` instead of the actual server message.

**Root cause:** All three import fetch calls used `.then(function(r) { return r.json(); })` without checking the response content type or HTTP status first.

**Fix:** Added `safeJsonResponse()` helper that reads the response as text first, checks HTTP status, then attempts JSON parse. Error messages now show the actual server response.

**Lesson:** Any fetch to the ESP must handle non-JSON responses gracefully. The ESP-IDF httpd returns plain text error pages for built-in errors (413, 431, 500).

---

### BUG-001: /api/status JSON truncation (v7.3.5.0)

**Symptom:** `curl /api/status` returned truncated JSON.

**Root cause:** 72 bytes formatted into a 64-byte `snprintf` buffer.

**Fix:** Split into three separate `snprintf` + `print` calls.

---

### BUG-002: Export All HTTP 502 (v7.3.4.2)

**Root cause:** Concurrent fetch requests overwhelmed ESP socket pool.

**Fix:** Serialized via `fetchAllSensorHistoryRowsSequentially()`.

---

### BUG-003: Chart markers not following recolor (v7.3.4.2)

**Fix:** Updated `pointBackgroundColor` and `pointBorderColor` during recolor.

---

### BUG-004: 15-minute markers oversized (v7.3.4.2)

**Fix:** Matched `pointRadius` to real-time chart settings.

---

### BUG-005: Theme toggle not forcing chart redraw (v7.3.4.2)

**Fix:** Added `refreshChartsAfterVisualChange()` call on theme switch.

---

### BUG-006: Dashboard startup "connecting..." blocker (v7.3.4.1)

**Fix:** Adjusted initialization ordering for `bindEvents()`.

---

### BUG-007: LittleFS dashboard hosting failure (v4.4)

**Fix:** Abandoned LittleFS; switched to embedded dashboard in C++ header.

---

### BUG-008: Dashboard serving runtime panic (v4.6.2)

**Fix:** Switched from `beginResponseStream()` to `beginResponse(data, size)`.

---

## Operational Lessons

### LESSON-OPS-001: File renames must update all internal references
Preflight script catches cross-reference drift.

### LESSON-OPS-002: Comments in YAML don't affect ESPHome behavior
Only actual configuration matters for `!secret` and `include` resolution.

### LESSON-OPS-003: Cloud CI and local compile need different secrets
Local uses symlink; CI generates temporary dummy secrets.

### LESSON-OPS-004: Hidden build directories break GitHub Actions artifacts
Stage firmware to `artifacts/firmware/`.

### LESSON-OPS-005: Raw logs and curated docs stay separate
`build-logs/` (gitignored) vs `Docs/` (committed).

### LESSON-OPS-006: Prefer local CLI editing over GitHub web edits

### LESSON-OPS-007: ESPHome ESP-IDF data channel constraints
POST body: NOT available to custom handlers. URL query params: stripped by `url_to()`. Headers: limited to ~300 bytes after browser/proxy overhead. URL path: reliable, preserved by all proxies, proven in this codebase. This is the most important lesson from v7.4.0 development.

### LESSON-OPS-008: CONFIG_HTTPD_MAX_REQ_HDR_LEN is a RAM multiplier
Each concurrent connection allocates this buffer. Setting it to 2048 on a 320KB device causes dashboard failures. The default 512 is a practical ceiling for this platform.

### LESSON-OPS-009: Version strings live in four places
VERSION file, YAML header comment, `App.version` in dashboard.js, `register_history_handler()` lambda. All four must match. The preflight script validates `App.version` against VERSION; extend to cover the other two.

### LESSON-OPS-010: Cached builds may not reflect header changes
ESPHome's `build_time_str` is set during YAML→C++ generation, not during compilation. Changing `.h` files triggers recompilation but the timestamp in the binary stays old. Use `esphome compile --clean` when in doubt.

---

## Regression Checklist

Any dashboard modification should regression-test:

1. Startup ordering — does the dashboard load and connect?
2. Event binding — do all buttons/controls work?
3. Chart redraw — do theme switches and data updates render correctly?
4. Dataset visual properties — markers, backgrounds, borders
5. Concurrency — does Export All or history loading overwhelm the ESP?
6. Min/max calculation — all time range selectors
7. Transport modes — SSE and polling
8. Import — multi-sensor CSV, single-sensor CSV, via LAN, via Cloudflare

---

## Known Open Issues

### ISSUE-001: Export causes ~40KB heap drop

During CSV export, `beginResponseStream()` allocates a large buffer. With 498 data points this is manageable (~44KB free heap remains). With 45 days of data (~4300 points per sensor), it could get tight. Future optimization: chunked streaming with smaller buffer.

### ISSUE-002: Import erases history before data is written

The `/api/import/begin` endpoint clears the history partition immediately. If the subsequent data upload fails (network error, browser crash), history is lost with nothing to replace it. The browser does validate comprehensively before calling begin, but the destructive-first pattern remains a risk. Future improvement: write to a staging area first, then swap.
