# Bugs Fixed & Lessons Learned

_Last updated: 2026-03-10 — v7.4.1.0 normalized baseline_

This file tracks significant bugs, root causes, fixes, and operational lessons.
It is also the place where project guardrails are recorded so they are not re-learned in later sessions.

---

## Bug Fixes

### BUG-016: `html-minifier-terser` CLI flags wrong (v7.4.1.0)

**Symptom:** `./scripts/minify-dashboard.sh` exited with `unknown option '--input-path'`.

**Root cause:** `html-minifier-terser` CLI does not use `--input-path` / `--output-path`.

**Fix:** Use positional input plus `--output`.

**Lesson:** Verify npm CLI syntax with `--help` before embedding commands into wrapper scripts.

---

### BUG-015: Single-sensor import "Unknown sensor ID" — off-by-one in URL path parsing (v7.4.0.2)

**Symptom:** Single-sensor import failed even though the sensor ID looked correct.

**Root cause:** The path prefix `/api/import/begin/single/` was counted incorrectly, leaving a leading slash on the extracted sensor ID.

**Fix:** Corrected both the prefix length comparison and pointer offset.

**Lesson:** Prefer `sizeof("literal") - 1` or `strlen()` over hand-counted path lengths.

---

### BUG-014: Single-sensor import erased all flash data (v7.4.0.2)

**Symptom:** Importing one sensor destroyed history for all sensors.

**Root cause:** The original import path erased the whole history partition before writing.
Because each persisted segment stores all sensors together, one-sensor replacement could not safely reuse the destructive path.

**Fix:** Added `POST /api/import/begin/single/<id>` and merge-first behavior.

**Lesson:** If storage blobs are multi-entity structures, partial import must merge, not replace.

---

### BUG-013: Import over Cloudflare returned HTTP 502 (v7.4.0.1)

**Symptom:** Import worked partially, then failed through the tunnel with 502.

**Root cause:** Background dashboard traffic and sustained import requests contended for the same limited HTTP/socket resources.

**Fix:** Suspend non-essential background activity during import and add pacing/backoff.

**Lesson:** On a constrained ESP origin, long-running operations must reduce concurrent background traffic.

---

### BUG-012: Single-sensor export schema mismatch (v7.4.0.1)

**Symptom:** Single-sensor export/import could map data to the wrong sensor.

**Root cause:** Single-sensor export used bare column names while merged export used sensor-prefixed columns.

**Fix:** Standardized on prefixed headers.

**Lesson:** Export and import must share one canonical schema.

---

### BUG-011: Non-JSON server response crashed import error handling (v7.4.0)

**Symptom:** Browser threw a JSON parse error instead of showing the real ESP/server error.

**Root cause:** Fetch handlers assumed JSON unconditionally.

**Fix:** Added safer text-first JSON response handling.

**Lesson:** Anything talking to ESP-IDF httpd must tolerate non-JSON error responses.

---

### BUG-010: `time()` ambiguous in ESPHome context (v7.4.0)

**Symptom:** Compile failure due to namespace ambiguity.

**Root cause:** ESPHome's `time` namespace collided with C standard library `time()`.

**Fix:** Use `::time(nullptr)`.

**Lesson:** Qualify standard-library calls when ESPHome namespaces can shadow them.

---

### BUG-009: Import POST body never delivered (v7.4.0)

**Symptom:** Import body appeared empty at the custom handler.

**Root cause:** On this ESPHome / ESP-IDF path, custom handlers do not receive request bodies in the way the original design assumed.

**Fix:** Moved import payload transport into the URL path.

**Lesson:** On this stack, **URL path is the reliable data channel** for custom import operations.

---

### Earlier important fixes

- **BUG-008:** Switched dashboard serving away from `beginResponseStream()` panic path
- **BUG-007:** Abandoned LittleFS-hosted dashboard in favor of embedded payload
- **BUG-006:** Fixed dashboard startup / event-binding ordering issue
- **BUG-005:** Theme switch now forces chart redraw
- **BUG-004:** 15-minute markers normalized to the intended visual size
- **BUG-003:** Chart markers now follow recolor changes
- **BUG-002:** Export All serialized to avoid socket-pool overload
- **BUG-001:** `/api/status` JSON truncation fixed by splitting output formatting

---

## Operational Lessons

### LESSON-OPS-001: File renames must update internal references

Preflight should catch cross-reference drift, but docs should still be reviewed after any rename.

### LESSON-OPS-002: Comments in YAML do not affect ESPHome behavior

Only actual configuration matters.

### LESSON-OPS-003: Cloud CI and local compile need different secret handling

Local uses the symlinked real secrets file.
CI uses temporary dummy secrets.

### LESSON-OPS-004: Hidden build directories break GitHub Actions artifact collection

Stage artifacts explicitly into known output directories.

### LESSON-OPS-005: Raw logs and curated docs stay separate

- Raw logs → `build-logs/` (gitignored)
- Durable documentation → `Docs/`

### LESSON-OPS-006: Prefer local CLI or editor-driven updates over ad hoc web editing

This reduces accidental truncation, missing execute bits, and inconsistent file state.

### LESSON-OPS-007: ESPHome ESP-IDF data-channel constraints matter

For custom handlers on this platform:

- POST body: not reliable for this use case
- Query params: not reliable in this path
- Headers: too limited once proxies add overhead
- **URL path: reliable**

### LESSON-OPS-008: `CONFIG_HTTPD_MAX_REQ_HDR_LEN` is a RAM multiplier

Increasing it increases per-connection cost.
On this device class, overly large header buffers can create new failures.

### LESSON-OPS-009: Version strings live in six places

Those six synchronized locations are:

1. `VERSION`
2. YAML header comment
3. `register_history_handler()` version string
4. `dashboard_link` publish-state text
5. `App.version` in `dashboard.js`
6. Version comment/header in `dashboard.html`

When a version bump happens, update all six together.

### LESSON-OPS-010: Cached builds may not reflect header-only changes clearly

If behavior looks stale after header or generated-file changes, use `esphome compile --clean`.

### LESSON-OPS-011: `html-minifier-terser` uses positional input plus `--output`

Do not script imaginary flags.
Test the exact command in a shell first.

### LESSON-OPS-012: Script execute permissions may be lost

Files introduced or rewritten through some repo workflows can lose the execute bit.
After a fresh clone or after pulling new scripts, run:

```bash
chmod +x scripts/*.sh
```

This instruction should appear in setup docs and handoff docs.

### LESSON-OPS-013: `git pull` can fail after a broken or partial prior pull

If Git says local changes would be overwritten and the changes are unwanted, reset the affected file(s) before retrying.

### LESSON-OPS-014: `dashboard.h` shrinkage is the easiest signal that minification is active

If the generated header barely changed, the minified intermediate may not have been used.

### LESSON-OPS-015: Documentation must distinguish current behavior from planned behavior

This project now has enough maturity that documentation drift becomes a real risk.
Use this rule:

- `README.md` = current shipped behavior only
- `architecture.md` = current architecture only
- `future-plans.md` / implementation plans = planned behavior

Do not advertise a roadmap item as if it is already merged.

### LESSON-OPS-016: Every substantial development session should leave continuity breadcrumbs

For meaningful sessions, update:

- A session log
- The fresh-start handoff
- Any changed roadmap/implementation-plan docs

That way a new session can restart cleanly without reconstructing history from chat logs.

### LESSON-OPS-017: Code and docs should be normalized in the same pass when possible

If a comment/header is clearly stale, normalize it during the same session that fixes the related documentation drift.
This reduces "almost aligned" repo states.

---

## Regression Checklist

Any significant dashboard or data-path modification should re-check:

- Startup ordering
- Event binding
- Theme redraw
- Chart marker/background/border consistency
- History/min-max calculations
- Export All concurrency behavior
- SSE and polling behavior
- Import over LAN
- Import over Cloudflare
- Browser compatibility across the major test targets

---

## Known Open Issues

### ISSUE-001: Export still causes a noticeable heap drop

The current export path remains acceptable for the present dataset sizes, but it is still not the most memory-efficient design for worst-case full-retention exports.

### ISSUE-002: Multi-sensor import remains erase-first

Single-sensor import is now safe/merge-based, but multi-sensor import still clears existing history before writing.
A future staging/swap approach would be safer.
