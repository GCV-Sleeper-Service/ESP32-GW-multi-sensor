# Bugs Fixed & Lessons Learned

_Last updated: 2026-03-10 — v7.4.1.0_

This document tracks significant bugs, root causes, fixes, and technical lessons. Updated with each version.

---

## Bug Fixes

### BUG-016: html-minifier-terser CLI flags wrong (v7.4.1.0)

**Symptom:** `./scripts/minify-dashboard.sh` exited immediately with `error: unknown option '--input-path'`.

**Root cause:** `html-minifier-terser` CLI does not accept `--input-path` or `--output-path` flags. The correct invocation uses the input file as a **positional argument** and `--output <file>` for the output path.

**Fix:** Changed the call from:
```bash
html-minifier-terser ... --input-path "$INPUT" --output-path "$OUTPUT"
```
to:
```bash
html-minifier-terser ... --output "$OUTPUT" "$INPUT"
```

**Lesson:** Always verify CLI flag syntax against `html-minifier-terser --help` before scripting. The tool's README and npm page show the positional argument convention clearly. When writing wrapper scripts for npm tools, prefer testing the exact invocation in a shell before embedding it in a script.

---

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

### BUG-012: Single-sensor export schema mismatch (v7.4.0.1)

**Symptom:** Importing a single-sensor CSV exported from the dashboard mapped all data into the Office sensor regardless of which sensor was exported.

**Root cause:** Merged export used prefixed headers (`outside_temp_c`, `office_humidity_pct`), but single-sensor export used bare headers (`temp_c`, `humidity_pct`). The importer could not identify which sensor the bare-column data belonged to and fell back to the first configured sensor.

**Fix:** Single-sensor export now uses the same prefixed header convention as merged export. Legacy bare-header files are supported only when the filename contains a recognizable sensor token. Ambiguous files are rejected with an explicit error instead of silently importing into the wrong sensor.

**Lesson:** Export and import must share one canonical column naming scheme. Silent fallback to a default sensor is dangerous for destructive operations.

---

### BUG-013: Import over Cloudflare 502 Bad Gateway (v7.4.0.1)

**Symptom:** After fixing the 431 error with URL-path transport, imports through Cloudflare tunnel started failing with 502 Bad Gateway during sustained batch uploads.

**Root cause:** The ESP origin was overwhelmed by concurrent traffic: import batches plus background dashboard polling (SSE/REST), storage stats refreshes, and history reloads all competing for the same limited HTTP connection pool.

**Fix:** Dashboard suspends all background network activity during import (SSE, polling, storage refreshes, history timers). Added pacing delays between batches and retry with exponential backoff for transient errors. Resumes cleanly after import completes.

**Lesson:** Any long-running operation on a resource-constrained ESP origin must suppress non-essential dashboard traffic. A design that survives one request can still fail under sustained sequential requests if the dashboard keeps polling.

---

### BUG-014: Single-sensor import erases all flash data (v7.4.0.2)

**Symptom:** Importing a single-sensor CSV erased all sensor data from flash, leaving only the imported sensor's data. Other sensors' history was lost.

**Root cause:** `/api/import/begin` unconditionally called `clear_persisted_history_()` which does `nvs_flash_erase_partition()` — a full partition erase. Each NVS segment blob stores data for all sensors in a shared `SegmentSnapshot` structure, so there was no way to selectively erase one sensor.

**Fix:** Added a new endpoint `POST /api/import/begin/single/<sensor_id>` that skips the partition erase and instead builds an epoch-to-slot map by scanning existing segments. During write, the firmware reads existing segments, overlays the target sensor's data, and writes the merged segment back. New hourly segments (not found in existing data) are written to the next available slot. Multi-sensor import retains the original erase-first behavior.

**Lesson:** When import data is a subset of the storage structure (one sensor in a multi-sensor segment), the firmware must merge rather than replace. The epoch-to-slot map approach costs ~6.5KB temporary RAM but avoids destructive behavior.

---

### BUG-015: Single-sensor import "Unknown sensor ID" — off-by-one in URL path parsing (v7.4.0.2)

**Symptom:** Single-sensor import failed with `HTTP 500: {"ok":false,"message":"Unknown sensor ID in import path","status":400}`. Multi-sensor import worked fine.

**Root cause:** The URL path prefix `/api/import/begin/single/` is 25 characters, but `strncmp` and the pointer offset both used 24. So `p + 24` pointed to `"/outside"` (with leading slash) instead of `"outside"`. The `strcmp` against `sensors[i].id` failed because of the extra `/`.

**Fix:** Changed both `strncmp(p, "/api/import/begin/single/", 24)` to 25, and `p + 24` to `p + 25` in both `canHandle` and `handleRequest`.

**Lesson:** When computing string offsets for URL path extraction, always verify the prefix length. Use `sizeof("/api/import/begin/single/") - 1` or `strlen()` instead of manually counted literals. Off-by-one in path parsing is silent until the extracted value is compared against known identifiers.

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

### LESSON-OPS-009: Version strings live in six places
VERSION file, YAML header comment, `register_history_handler()` lambda, `dashboard_link` publish_state text, `App.version` in `dashboard.js`, and version comment in `dashboard.html`. All six must match on every version bump. The preflight script validates `App.version` against VERSION. Large files (dashboard.js ~102KB, dashboard.html ~153KB) cannot be pushed via GitHub API — use targeted `sed -i` commands locally.

### LESSON-OPS-010: Cached builds may not reflect header changes
ESPHome's `build_time_str` is set during YAML→C++ generation, not during compilation. Changing `.h` files triggers recompilation but the timestamp in the binary stays old. Use `esphome compile --clean` when in doubt.

### LESSON-OPS-011: html-minifier-terser uses positional arg + --output flag
`html-minifier-terser [options] --output <outfile> <infile>` — there are no `--input-path` or `--output-path` flags. Always verify npm tool CLI syntax with `--help` before scripting. Test the exact invocation in a shell before embedding it in a script.

### LESSON-OPS-012: Script execute permissions are not preserved through GitHub API push
Files pushed via the GitHub API are created without execute permission (`-rw-r--r--`). Always run `chmod +x scripts/*.sh` after a fresh clone or after pulling new scripts. Consider adding a `chmod` step to the local setup instructions in the handoff doc.

### LESSON-OPS-013: git pull fails with local changes from a previous (broken) pull
If a file was partially pulled before a merge abort, `git pull` will refuse with "Your local changes would be overwritten." Fix with `git checkout -- <file>` to discard the local copy, then retry `git pull`.

### LESSON-OPS-014: dashboard.h size reduction confirms minification is active
After regenerating `dashboard.h` from `dashboard.min.html`, the file should be noticeably smaller than the unminified version. A 3,059-line reduction in the commit diff is the expected signal. If `git diff --stat` shows only a few lines changed in `dashboard.h`, the minified source was NOT used — check that `dashboard.min.html` exists and that `generate-header.sh` reports "Using minified source".

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

### ISSUE-002: Import erases history before data is written (partially resolved in v7.4.0.2)

Multi-sensor `/api/import/begin` still clears the history partition before writing. If the upload fails, history is lost. Single-sensor import (`/api/import/begin/single/<id>`) avoids this by merging into existing segments without erasing. Future improvement for multi-sensor: write to a staging area, then swap.

### ISSUE-003: httpd_accept_conn error 23 (ENFILE) at boot — cosmetic

After OTA flash, the ESPHome log shows several `httpd_accept_conn: error in accept (23)` lines during the first ~90 seconds. ENFILE = system file table full (socket exhaustion). This is caused by the browser/dashboard making multiple simultaneous connections at boot while `CONFIG_LWIP_MAX_SOCKETS: "13"` is already tuned to its practical maximum for this platform. The errors are transient, self-resolve, and do not affect dashboard operation. Not a blocker. Future mitigation: stagger dashboard connection attempts on load.
