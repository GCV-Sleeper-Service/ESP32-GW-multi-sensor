# Bugs Fixed & Lessons Learned

_Last updated: 2026-03-08 — v7.3.5.0_

This document tracks significant bugs, their root causes, fixes, and the technical lessons derived from each. It also captures operational lessons from the development process. Updated with each version.

---

## Bug Fixes

### BUG-001: /api/status JSON truncation (v7.3.5.0)

**Symptom:** `curl /api/status` returned truncated JSON ending at `"free_heap` with no value or closing brace.

**Root cause:** Three JSON fields were packed into a single `snprintf` call targeting a `char num[64]` buffer. The formatted output was 72 bytes, causing silent truncation at the buffer boundary.

**Fix:** Split the single `snprintf` into three separate `snprintf` + `print` calls, each well under the 64-byte buffer limit.

**Lesson:** Any `snprintf` targeting a fixed buffer in this codebase must be audited for worst-case output length. The `char num[64]` pattern is used throughout `sensor_history_multi.h` (including `handle_storage_stats_`). Future additions should use the split-print pattern or increase the buffer with a documented rationale.

---

### BUG-002: Export All HTTP 502 (v7.3.4.2)

**Symptom:** Clicking "Export All" in the dashboard produced an HTTP 502 error, particularly when accessed through Cloudflare.

**Root cause:** The merged export path was too bursty — it fired concurrent fetch requests for all sensor histories simultaneously, overwhelming the ESP's limited socket pool and Cloudflare's proxy buffering.

**Fix:** Serialized the retained-history fetches using `fetchAllSensorHistoryRowsSequentially()` so requests happen one at a time.

**Lesson:** The ESP32-C3 web server has very limited concurrent socket capacity. Any feature that triggers multiple HTTP requests should serialize them or implement backpressure.

---

### BUG-003: Chart markers not following sensor recolor (v7.3.4.2)

**Symptom:** When a user changed a sensor's display color, chart lines updated but point markers retained the old color.

**Root cause:** The recolor logic only updated the line `borderColor` property but not `pointBackgroundColor` or other marker-related dataset properties.

**Fix:** Updated all marker-related chart properties (`pointBackgroundColor`, `pointBorderColor`) during the recolor operation.

**Lesson:** Chart.js datasets have multiple visual properties per element. When changing colors, all properties must be updated together.

---

### BUG-004: 15-minute chart markers oversized (v7.3.4.2)

**Symptom:** Point markers on the 15-minute average charts were noticeably larger than those on the real-time charts.

**Root cause:** Inconsistent `pointRadius` settings between the two chart configurations.

**Fix:** Matched 15-minute chart marker sizes to the real-time chart marker sizes.

---

### BUG-005: Theme toggle not forcing chart redraw (v7.3.4.2)

**Symptom:** After switching between dark and light mode, charts retained the old theme's colors until the user did a hard refresh (Ctrl+F5).

**Root cause:** Theme switch updated CSS custom properties and UI state but did not trigger a Chart.js redraw/update cycle.

**Fix:** Added `refreshChartsAfterVisualChange()` call on theme switch to force all charts to redraw with the current theme colors.

**Lesson:** Any visual state change that affects chart appearance must include an explicit chart redraw. CSS changes alone don't propagate into Canvas-rendered Chart.js elements.

---

### BUG-006: Dashboard startup "connecting..." blocker (v7.3.4.1)

**Symptom:** Dashboard loaded but stayed permanently on "connecting..." with no sensor data appearing.

**Root cause:** The Phase 1 structural changes in v7.3.4 introduced a timing issue where `bindEvents()` was called before the DOM elements it targeted were fully available.

**Fix:** Adjusted initialization ordering to ensure DOM readiness before event binding.

**Lesson:** Moving from inline handlers to centralized `bindEvents()` changes the timing contract. Event binding must be sequenced after DOM construction.

---

### BUG-007: LittleFS dashboard hosting failure (v4.4)

**Symptom:** Attempted to host the dashboard HTML file on LittleFS. Validation failures prevented it from working.

**Root cause:** LittleFS on ESP32-C3 with ESP-IDF had compatibility and validation issues that weren't solvable within the project constraints.

**Fix:** Abandoned LittleFS approach in v4.5. Switched to embedded dashboard in a C++ header file (`dashboard.h`), served via `beginResponse(data, size)`.

**Lesson:** For this project, embedding the dashboard in firmware flash/rodata is more reliable than filesystem-based hosting. The HTML lives in flash, not heap.

---

### BUG-008: Dashboard serving runtime panic (v4.6.2)

**Symptom:** Opening `/dashboard.html` caused the ESP32 to crash.

**Root cause:** Using `beginResponseStream()` + `print()` for the large dashboard payload caused heap exhaustion.

**Fix:** Switched to `beginResponse(200, content_type, data, size)` which wraps the existing buffer without copying to heap.

**Lesson:** Never use streaming response patterns for large static payloads on the ESP32. The zero-copy `beginResponse(data, size)` pattern is required.

---

## Operational Lessons

### LESSON-OPS-001: File renames must update all internal references

Renaming files in the repo tree is not sufficient. Internal references in scripts, YAML includes, and C++ `#include` directives must all be updated. The preflight script now validates cross-references to catch this.

### LESSON-OPS-002: Comments in YAML do not affect ESPHome behavior

Human comments about file paths or requirements do not change how ESPHome resolves `!secret` or `include` paths. Only actual configuration matters.

### LESSON-OPS-003: Cloud CI and local compile need different secrets

Local compile uses real `secrets.yaml` via symlink. CI generates temporary compile-only secrets. Both models must be maintained.

### LESSON-OPS-004: Hidden build directories break GitHub Actions artifacts

Build output under hidden paths (`.esphome/`) is not uploaded by `actions/upload-artifact` by default. Firmware binaries must be staged into visible directories (`artifacts/firmware/`).

### LESSON-OPS-005: Raw logs and curated docs should stay separate

Machine-generated build logs belong in `build-logs/` (gitignored) or GitHub Actions artifacts. Human-facing continuity docs belong in `Docs/` (committed).

### LESSON-OPS-006: Prefer local CLI editing over GitHub web edits

For firmware, dashboard, and workflow files, local editing with validation before commit produces fewer errors than GitHub web editing.

### LESSON-OPS-007: Git rebase conflicts in CI YAML

When `.github/workflows/ci.yml` conflicts during rebase, replace the file with the intended final version, stage, continue rebase, then push. Use `--force-with-lease` only when rebase requires it.

---

## Regression Checklist (for future changes)

Any dashboard modification should regression-test:

1. Startup ordering — does the dashboard load and connect?
2. Event binding completeness — do all buttons/controls work?
3. Chart redraw behavior — do theme switches and data updates render correctly?
4. All dataset visual properties — not just line color, but markers, backgrounds, borders
5. Concurrency pressure — does Export All or history loading overwhelm the ESP?
6. Min/max calculation — do all time range selectors produce correct values?
7. Transport modes — does the dashboard work in both SSE and polling modes?
