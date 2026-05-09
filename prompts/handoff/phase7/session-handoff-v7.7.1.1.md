# Session Handoff — v7.7.1.1: Chunked HTTP Streaming (BUG-082 Fix)

_Date: 2026-05-08 (updated post-PR-225 audit)_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.7.1.0 on `main`. Health-check task delivering runtime telemetry._

---

## Project State Summary

**v7.7.1.0 is complete.** Health-check telemetry task runs every 60s, logging heap, stack watermarks, NVS stats, and uptime. The health-check provides runtime visibility into the exact problem this step fixes.

**BUG-082 is still open.** WROOM and C3 boards crash when serving history after ~3 weeks of data accumulation. The dashboard is unusable on those boards. This step fixes it.

### v7.7.1.0 baseline values (C3 satellite — operator device testing, pre-merge)

| Metric | Value |
|--------|-------|
| `heap_free` (serial HEALTH:) | 39,704 B |
| `heap_free_total` (serial HEALTH:) | 47,460 B |
| `min_free` internal | 29,776 B |
| `httpd_stack_wm` | 12,932 B |
| `hc_stack_wm` | 2,176 B |
| `nvs_used` | 5,274 entries |
| `nvs_free` | 10,854 entries |
| `nvs_total` | 16,128 entries |

Use these as the "before" comparison baseline in v7.7.1.1 device testing.

### Open follow-up items from v7.7.1.0 (non-blocking for merge, required before v7.7.1.1 closes)

- **NI-001 (Medium) — WROOM previous-boot `IllegalInstruction` crash:** The WROOM satellite emitted `*** CRASH DETECTED ON PREVIOUS BOOT *** Fault - IllegalInstruction` after v7.7.1.0 OTA flash. HTTP API responded correctly post-reboot. Root cause unknown — may be pre-existing, may be related to health-check task on WROOM. **Investigate during v7.7.1.1 WROOM device testing.** If the crash recurs or the fault is linked to the health-check task, escalate before merging v7.7.1.1.
- **NI-002 (Low) — WROOM + S3 `HEALTH:` log lines not observed:** Neither WROOM (130s window) nor S3 (90s window) emitted observable `HEALTH:` serial lines after v7.7.1.0 flash. The C3 confirmed HEALTH: output at the expected interval. Use a >150s capture window for WROOM and S3 in v7.7.1.1 device testing, but treat that as necessary rather than sufficient: also verify the flashed board config has `logger.level: INFO`, serial output enabled if UART capture is required, and `start_health_check_task_()` present in generated `on_boot`. A confirmed `HEALTH:` line on WROOM is a gate for v7.7.1.1.

---

## Phase 7 Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.7.0.0 | ESPHome component defaults audit (research) | Complete |
| v7.7.1.0 | Health-check telemetry task | Complete (PR #225) |
| **v7.7.1.1** | **Chunked HTTP streaming (BUG-082 fix)** | **⬅️ Current** |
| v7.7.1.2 | Per-device structs, key scheme, hash | Pending |
| v7.7.1.3 | Per-device persist engine (write path) | Pending |
| v7.7.1.4 | Per-device restore engine + retention budget | Pending |

---

## BUG-082 Root Cause (from Docs/lessons/firmware.md)

The history handlers (`handle_history_()` and `handle_api_v2_history_()`) build the entire CSV response as a `std::string` in RAM before sending. `csv.reserve(cap)` pre-allocates but does NOT truncate — `.append()` grows the string past the reserved capacity.

On WROOM (~34 KB free heap):
- NVS contains ~556 segments × 4 points × ~18 bytes/line = ~40 KB of CSV
- `csv.reserve(12000)` allocates 12 KB
- Loop appends ~40 KB → `std::string` reallocates 12→24→48 KB
- During 24→48 KB reallocation, both old and new buffers coexist = 72 KB
- 72 KB > 34 KB free → heap exhaustion → crash

**The fix:** Stream NVS segments directly to the HTTP response using `httpd_resp_send_chunk()`. Each chunk is ~100-500 bytes (one segment's CSV lines). Peak heap: ~744 bytes (SegmentSnapshot + line buffer). No `std::string` at all.

---

## v7.7.1.1 Scope

### What this step does

1. Adds two chunked-streaming helper functions to `firmware/core/web-handler.h`
2. Rewrites `handle_history_()` to stream NVS segments + RAM buffer via chunks
3. Rewrites `handle_api_v2_history_()` to stream RAM buffer via chunks
4. Eliminates all `csv.reserve()` usage from web-handler.h

### What this step does NOT do

- No changes to NVS persistence engine (no `seg_NNN` key changes)
- No changes to `SegmentSnapshot` struct or `append_snapshot_series_csv_()`
- No changes to `HistoryBuffer::append_csv_to()`
- No changes to the CSV format (epoch,value\n)
- No dashboard changes (browsers handle `Transfer-Encoding: chunked` transparently)
- No aggregator proxy handler changes
- No new HTTP endpoints
- No new firmware fragments

### Key technical enabler

`AsyncWebServerRequest` exposes `operator httpd_req_t *()` (line ~189 of `firmware/local_components/web_server_idf/web_server_idf.h`). This allows direct access to the raw ESP-IDF httpd request handle from within the AsyncWebHandler framework. No need to drop to raw handlers or register separate ESP-IDF routes.

### Files modified

- `firmware/core/web-handler.h` — add helpers, rewrite two handlers
- `Docs/changelog.md` — v7.7.1.1 entry
- `CURRENT-STATE.md` — resolve BUG-082, update version
- `VERSION` — via bump-version.sh
- Session log `Docs/session-log-<DATE>-v7.7.1.1.md`

### Acceptance criteria

See `prompts/phase7/v7.7.1.1-agent-prompt-gpt-codex.md` §7 for the full checklist.

---

## Codebase state entering v7.7.1.1

### Logger level (important — do not revert)

`firmware/esp32-c3-multi-sensor.yaml` now has:

```yaml
logger:
  level: INFO
  logs:
    wifi: ERROR
    api: ERROR
```

This was changed from `WARN` in v7.7.1.0 to make `HEALTH:` telemetry visible. ESPHome does not allow per-tag levels more verbose than the global level — `WARN` global would silently suppress all `ESP_LOGI` output. **Do not revert this change.** If noise from other subsystems becomes a problem, add additional per-tag suppressors.

### Fragment count

The assembly pipeline now expects **9 fragments**. Any checkpoint grep referencing "8 fragments" is stale. Use:
- `bash scripts/assemble-sensor-history.sh --list | grep -c 'firmware/core/'` → `9`
- `grep -c '^  "firmware/core/.*\.h"$' scripts/assemble-sensor-history.sh` → `9`

### Step Index table

The Phase 7 step table in `prompts/prompt-index-and-workflow.md` still shows the pre-planning version mapping (NI-003 from v7.7.1.0 audit). Update the table in this PR to reflect the actual executed sequence.

---

## Pre-merge Checklist for v7.7.1.1

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates (A, B) verified
- [ ] All acceptance criteria in §7 met
- [ ] ⛔ PRE-PR GATE in §8 passes
- [ ] CURRENT-STATE.md updated (mandatory — version, What Just Shipped, BUG-082 resolved)
- [ ] PR body contains `Fixes #139` (auto-closes BUG-082 issue on merge)
- [ ] PR body references Phase 7 step tracking issue for v7.7.1.1
- [ ] Session log created (Rule 63)
- [ ] Instruction Compliance Output table in PR description
- [ ] NI-001: WROOM `IllegalInstruction` crash status confirmed or tracked
- [ ] NI-002: WROOM `HEALTH:` log lines confirmed (>150s capture window)
- [ ] Step Index table updated in `prompt-index-and-workflow.md` (NI-003)

---

## Critical Rules Relevant to v7.7.1.1

| # | Rule | Why Relevant |
|---|------|-------------|
| 8 | No beginResponseStream >10 KB | This step eliminates beginResponse too |
| 11 | NVS scan loops must yield | `maybe_yield_nvs_scan_()` in chunked loop |
| 24 | Report internal and total heap separately | Health-check already does this; verify chunked handler doesn't break it |
| 40 | Deferred task for NVS writes | NOT applicable — handlers are read-only |
| 58 | Edit fragments, not assembled artifact | `web-handler.h` is a fragment |
| 62 | Assembly order unchanged | No new fragments, no reorder |
| 63 | Session log is pre-merge acceptance criterion | Mandatory |
| 64 | Checkpoint greps mechanically derived | All greps must match code changes |

---

## Risk: HIGH — production crash fix, handler rewrite

**Primary risk:** The `httpd_req_t*` conversion operator has not been used for chunked responses in this project before. If the conversion doesn't work as expected (e.g., if the AsyncWebHandler framework has already committed response headers), the chunked response will fail.

**Mitigation:**
- The conversion operator is a simple pointer cast (line ~189, ~195 of web_server_idf.h) — no complex state management
- `httpd_resp_send_chunk()` is the standard ESP-IDF API for chunked responses
- The helper functions gracefully handle send failures by returning ESP_ERR and stopping the loop
- Health-check telemetry (v7.7.1.0) provides real-time heap visibility during testing
- Device testing on WROOM (the crash board) is mandatory post-merge

**Secondary risk:** CSV format regression. The dashboard's `parseCompactHistory()` expects exact `epoch,value\n` format. The chunked helpers produce identical line format — same `snprintf` patterns as the existing code.

**Additional risk (NI-001):** WROOM had an `IllegalInstruction` crash on previous boot after v7.7.1.0 OTA. If the root cause is still live, the WROOM device testing for this step may be unreliable. Investigate and resolve before treating WROOM results as valid.

---

## Workflow for v7.7.1.1

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt
3. Agent implements per §6 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Review the PR — verify scope, acceptance criteria, Critical Rules
6. Send to ALL external reviewers (HIGH-risk step)
7. Merge, tag `v7.7.1.1`
8. **CRITICAL device testing:** flash WROOM AND C3, verify no crash on history serve
9. Produce consolidated audit with device test measurements
10. Inspect and update v7.7.1.2 handoff + agent prompt

---

## Device Testing (CRITICAL — This Is the BUG-082 Verification)

| Board | IP | Role | Why |
|-------|-----|------|-----|
| WROOM-32D | `192.168.120.170` | Satellite | **Tightest heap — original crash board; also NI-001 crash to investigate** |
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite | Second crash board |

After flash:
- [ ] `curl -v /history/office/temp` on WROOM returns chunked CSV — NO crash
- [ ] `curl -v /history/office/temp` on C3 returns chunked CSV — NO crash
- [ ] `curl -v /api/v2/history/office/temp` on both boards returns chunked CSV
- [ ] Dashboard history charts render correctly on both boards
- [ ] Health-check logs show peak heap usage < 5 KB during history serve
- [ ] `scripts/stress-test-httpd-stack.sh` passes on at least C3
- [ ] **NI-002 gate:** WROOM serial log confirms `HEALTH:` lines within 150s capture window after verifying the flashed config still enables INFO logging, serial output, and `start_health_check_task_()`
- [ ] **NI-001 gate:** WROOM does NOT report `*** CRASH DETECTED ON PREVIOUS BOOT ***` after v7.7.1.1 OTA

**If WROOM crashes:** capture serial log immediately. This means the chunked approach has a bug. Do NOT close the PR as resolved.

---

## Context That Carries Forward to v7.7.1.2

- History endpoints now use chunked streaming — no more full-CSV-in-RAM
- BUG-082 is resolved — dashboards work on all boards regardless of NVS history size
- The `SegmentSnapshot` struct is still the NVS read format — v7.7.1.2 introduces `DeviceSegment`
- `csv.reserve()` pattern is gone from web-handler.h — no regression risk for new endpoints
- `httpd_resp_send_chunk()` pattern is now proven — reusable for future per-device history endpoints
- Health-check baseline measurements from v7.7.1.0 establish the "before" comparison; v7.7.1.1 device tests provide the "after"
- Logger level is `INFO` with per-tag suppressors — this is intentional and must be maintained
- Fragment count is 9 — all future checkpoint greps must use anchored patterns counting 9

---

_End of session handoff document._
