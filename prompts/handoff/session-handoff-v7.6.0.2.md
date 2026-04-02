# Session Handoff — v7.6.0.2: DELETE /api/aggregator/satellite/{id} (Phase D Step 2)

_Date: 2026-04-02_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.0.2 is COMPLETE. Implementation (PR #110), BUG-079 fix (PR #114), device testing all done._

---

## Project State Summary

**v7.6.0.1** is the current version on `main`. **Phase D Step 1 is COMPLETE.**

### What v7.6.0.1 delivered

- `POST /api/aggregator/add-satellite` — working endpoint replacing the 501 stub
- `probe_satellite_manifest_()` static helper — factored out for reuse by v7.6.0.3
- Query param parsing: `url` (required), `name` (optional), `poll` (optional, default 30, clamped 10–3600)
- Validation chain: format check → capacity check → duplicate check → probe → add
- TOCTOU protection: capacity + duplicate re-validated under `AGG_LOCK()`
- NVS rollback: if `save_single_satellite_to_nvs_()` fails, runtime state rolled back
- URL-derived name fallback: extracts host[:port] from URL when no name provided
- PR #108: 4 commits, 26 files changed, 8 review fixes applied

### v7.6.0.1 post-merge fixups (committed as v7.6.0.1 fixup, not a version bump)

- **BUG-077 (build-breaking):** `String url_param` → `std::string url_param` in `handle_add_satellite_()`. The coding agent used Arduino's `String` type which doesn't exist in ESP-IDF builds. CI passed because Playwright tests don't compile firmware.
- **BUG-078 (HTTP status codes wrong):** `init_response_()` in `firmware/local_components/web_server_idf/web_server_idf.cpp` only mapped 200/404/409; all other codes (400, 401, 405, 429, 501, 503) defaulted to HTTP 500. Pre-existing ESPHome bug exposed during device testing. Fixed with expanded switch + `snprintf` fallback.
- **canHandle() GET routing:** Added add-satellite and test-satellite to `canHandle()`'s GET section so the handler can return 405 Method Not Allowed for GET requests instead of ESPHome dropping the connection.

### Cumulative state entering Phase D Step 2

| Phase | Version Range | Status |
|-------|--------------|--------|
| Phase 1–3 | v7.5.0.x–v7.5.3.x | ✅ Complete |
| Phase 4 | v7.5.4.x | ✅ Complete |
| Phase 5 | v7.5.5.x | ✅ Complete |
| Phase 6 | v7.5.6.x | ✅ Complete |
| v7.5.7.0 | Bridge step | ✅ Complete |
| v7.6.0.0 | NVS satellite persistence layer | ✅ Complete 2026-03-29 |
| v7.6.0.1 | POST /api/aggregator/add-satellite | ✅ Complete 2026-03-31 |
| **v7.6.0.2** | **DELETE /api/aggregator/satellite/{id}** | **✅ Complete 2026-04-02** |

### Key infrastructure changes from v7.6.0.1 relevant to v7.6.0.2

- **`probe_satellite_manifest_()`** exists and uses `s_proxy_tmp`. Not needed for delete, but confirms the pattern for web-handler-context helpers.
- **`handle_add_satellite_()`** demonstrates the full mutation pattern: validate → probe → `AGG_LOCK()` → mutate → `AGG_UNLOCK()` → NVS save. Delete follows the same pattern minus the probe.
- **In-lock re-validation (TOCTOU):** v7.6.0.1 re-validates capacity and duplicate inside the mutex. v7.6.0.2 should re-validate that the target satellite still exists at the expected index inside the mutex.
- **NVS rollback on save failure:** v7.6.0.1 rolls back `runtime_satellite_count` if NVS write fails. For delete, rollback after array compaction is more complex — consider whether it's feasible or if "log and continue" is acceptable.
- **BUG-078 is fixed:** `init_response_()` now correctly maps all HTTP status codes. Device tests can rely on exact HTTP code matching.
- **Critical Rules now total 44** (was 42). Rules 43–44 added for BUG-077/078.

---

## Phase D Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.0.0 | NVS satellite persistence layer | ✅ Complete 2026-03-29 |
| v7.6.0.1 | POST /api/aggregator/add-satellite | ✅ Complete 2026-03-31 |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | ✅ Complete 2026-04-02 |
| v7.6.0.3 | POST /api/aggregator/test-satellite | ⬅️ Next |
| v7.6.0.4 | Dashboard add/remove/test UI | Pending |
| v7.6.0.5 | Playwright tests + Phase D closure | Pending |

---

## v7.6.0.2 Scope

Replace the 501 stub for `DELETE /api/aggregator/satellite/{id}` with a working implementation. **No dashboard changes. No test changes.**

### What v7.6.0.2 must deliver

1. **`handle_delete_satellite_()` implementation** — replaces the 501 stub:
   - Parse satellite ID from URL path (after `/api/aggregator/satellite/`)
   - Authenticate via `authenticate_management_()`
   - Validate ID is non-empty
   - `AGG_LOCK()` → scan for matching `.id` → compact array → `runtime_satellite_count--` → `AGG_UNLOCK()`
   - `save_satellites_to_nvs_()` via deferred task (Critical Rule 40 — bulk NVS, not single save)
   - Return 200 `{"ok":true}`

2. **Array compaction** — the critical invariant. After deleting satellite at index `del_idx`, shift all higher-index satellites down by one and clear the vacated last slot. No code anywhere may cache a satellite array index.

3. **Routing change** — replace the 501 stub call for DELETE path in `handleRequest()`.

4. **Documentation**: `Docs/changelog.md` v7.6.0.2 entry, `Docs/bugs-and-lessons-learned.md` if new lessons.

### v7.6.0.2 API contract

```
DELETE /api/aggregator/satellite/{satellite_id}
Authorization: Basic <base64(username:password)>
Content-Type: application/x-www-form-urlencoded
Body: a=1
```

| Condition | HTTP Status | Response |
|-----------|-------------|----------|
| Valid ID, satellite found | 200 | `{"ok":true}` |
| Missing/empty satellite ID | 400 | `{"ok":false,"message":"Missing satellite ID","status":400}` |
| Satellite ID not found | 404 | `{"ok":false,"message":"Unknown satellite ID","status":404}` |
| Authentication failure | 401 | `{"ok":false,"message":"Management authentication required","status":401}` |
| Wrong HTTP method | 405 | `{"ok":false,"message":"Method not allowed","status":405}` |
| Mutex timeout | 503 | `{"ok":false,"message":"Mutex timeout","status":503}` |

---

## Pre-merge Checklist for v7.6.0.2

Before merging the v7.6.0.2 PR:

- [x] v7.6.0.1 merged, tagged (`v7.6.0.1`), fixup committed
- [x] Device testing completed:
  - [x] Test 1: Delete a satellite via curl (expect 200 + `{"ok":true}`)
  - [x] Test 2: Verify deleted satellite gone from `/api/aggregator/gateways`
  - [x] Test 3: Verify remaining satellites are still polled
  - [x] Test 4: Delete unknown ID (expect 404)
  - [x] Test 5: Delete with empty ID (expect 400)
  - [x] Test 6: Delete without auth (expect 401)
  - [x] Test 7: Reboot persistence — deleted satellite stays deleted after reboot
  - [x] Test 8: Add-then-delete cycle — add satellite, delete it, verify clean state
- [x] All Playwright fixture sets passing
- [x] preflight.sh passes
- [x] `render_sensor_config.py --check` passes
- [x] No `String` (Arduino) type in any new code (Critical Rule 44)
- [ ] Device testing completed via automated script (T1 had auth bug in script — firmware is correct):
  ```bash
  bash scripts/provision.sh aggregator
  # ... regeneration pipeline ...
  esphome clean firmware/esp32-s3-devkitc1-n16r8-gw.yaml
  esphome run firmware/esp32-s3-devkitc1-n16r8-gw.yaml
  bash scripts/device-test-v7.6.0.2.sh 192.168.120.191
  ```
  - [x] T1-T3: Error paths pass (empty ID, unknown ID, no auth)
  - [x] T4-T7: Delete happy path + verification + compaction
  - [x] T8: Reboot persistence (deleted satellite stays deleted)
  - [x] T10: Compaction stress (delete first, second shifts to first)
  - [x] T11: State restored to initial
- [x] Switched back to CI-safe mode: `bash scripts/provision.sh satellite`


### v7.6.0.2 prompt corrections needed

1. **Critical Rules count:** Change "All 42 Critical Rules" → "All 44 Critical Rules" in §2 item 5 and §7.
2. **§2 item 5:** Add "especially ... 43, 44" to the list of relevant rules.
3. **§3 Current Status:** Update to reflect v7.6.0.1 complete, BUG-077/078 fixed.

---

## v7.6.0.1 Lessons Relevant to v7.6.0.2

### LESSON-OPS-103 — init_response_() status code coverage (2026-04-01)

If BUG-078 fix is not committed before the v7.6.0.2 agent runs, all error responses will still show HTTP 500 in device testing. Ensure the local component fix is merged first.

### LESSON-OPS-104 — Always use std::string (2026-04-01)

The v7.6.0.2 prompt's code blocks don't use `String` (no query param parsing in delete), but review any agent-generated code for this pattern.

### BUG-078 T4 — canHandle() must accept all methods for endpoints with method checks

The v7.6.0.2 `canHandle()` already accepts DELETE on `/api/aggregator/satellite/` (line 2123). Verify the handler returns 405 for wrong methods. If not, add routing similar to the add-satellite GET fix.

### NVS save failure handling for delete

v7.6.0.1 rolls back `runtime_satellite_count` if NVS save fails. For delete, the array has already been compacted under mutex. Rolling back would require re-inserting the deleted satellite at its original position — complex and error-prone. The v7.6.0.2 prompt uses the deferred task pattern, which means the HTTP response is sent before NVS write. If NVS fails, the satellite is gone from runtime but still in NVS — it reappears on reboot. This is acceptable for now; document as a known limitation.

---

## Workflow for v7.6.0.2

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for clarification.**

1. Ask human if PR for v7.6.0.2 has been opened and ask to provide the PR number
2. If PR has not been opened, **open a NEW coding agent session outside of this chat** and paste the prompt from `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md`
3. Wait for the agent to create the PR
4. Copilot PR reviewer reviews automatically and additional reviews might be posted
5. Human reviews PR against the Review Checklist in the prompt
6. Fix any issues
7. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
8. Provide to human all the necessary instructions to run tests
9. Provide instructions after merging PR to Main with tagging and pushing the tag

---

## Post-PR Closure Deliverables for v7.6.0.2

After the v7.6.0.2 PR is merged, produce these documents:

### 1. Session Handoff Document

**File:** `prompts/handoff/session-handoff-v7.6.0.3.md`
**Format:** Same as this document.

### 2. PR and Prompt Audit Document

**File:** `prompts/phaseD/v7.6.0.2-PR<NN>-consolidated-audit-and-lessons.md`
**Format:** Same as `prompts/phaseD/v7.6.0.1-PR108-consolidated-audit-and-lessons.md`

**⚠️ IMPORTANT: Must answer these questions:**
- Did the coding agent deliver properly and accurately what was required?
- Did the codebase state match the prompt's assumptions?
- What implementation decisions did the agent make beyond the prompt?
- Coding agent prompt audit against the writing guide
- PR comment review and disposition

### 3. Updated Prompt Corrections (if needed)

Apply corrections to subsequent Phase D prompts if the audit reveals defects.

### 4. Updated prompt-index-and-workflow.md

Mark v7.6.0.2 as complete with date.

---

## v7.6.0.2 Post-Implementation Summary

### What was delivered

- **PR #110** — `handle_delete_satellite_()` implementation replacing the 501 stub
  - Array compaction with `set_identity` + field-by-field copy
  - `SatelliteNVSSnapshot` pattern to prevent torn reads during deferred NVS save
  - Generation counter (`s_satellite_config_gen`) to detect config changes during poll cycles
  - `s_nvs_save_in_progress` flag to prevent concurrent deferred NVS save tasks
  - GET/POST → 405 wiring for wrong-method requests
  - CORS `Access-Control-Allow-Methods` updated to include DELETE
  - 6 commits, 2 files changed

### BUG-079 — HTTP DELETE handler registration

- **Root cause:** `web_server_idf.cpp` `AsyncWebServer::begin()` only registered HTTP_GET, HTTP_POST, and HTTP_OPTIONS URI handlers. No HTTP_DELETE handler was registered. ESP-IDF httpd returned its built-in plain-text 405 before any `canHandle()`/`handleRequest()` was called.
- **Diagnostic signature:** Plain-text 405 (not JSON) = request never reached our handler. Our `send_json_error_()` always returns `application/json`.
- **Fix:** PR #114 + PR #115 fixup. Added `HTTP_DELETE` URI handler registration. Updated `patch-esphome-httpd-stack.sh` with PATCH2 sentinels for the DELETE handler.
- **Introduced by:** PR #105 (BUG-075/076 local component). Latent until v7.6.0.2 added the first DELETE endpoint.

### Device test results (manual confirmation after BUG-079 fix)

```
Reset satellites: {"ok":true,"message":"Satellite reset scheduled","satellite_count":3}
DELETE sat-c3-4m-189: HTTP 200 → {"ok":true}
ESPHome log: Deleting satellite[0]: id=sat-c3-4m-189
ESPHome log: NVS agg_sats: saved 2 satellites from snapshot
```

### PR timeline

| PR | Purpose | Status |
|----|---------|--------|
| #110 | v7.6.0.2 implementation | ✅ Merged |
| #111 | BUG-079 fix attempt (wrong target) | ✅ Closed (not merged) |
| #112 | device-test-v7.6.0.3.sh + handoff update | 🟡 Open (this PR) |
| #113 | BUG-079 doc-only (superseded) | ✅ Closed (not merged) |
| #114 | BUG-079 actual fix | ✅ Merged |
| #115 | PR #114 fixup (sentinels) | ✅ Merged (squashed into #114) |

---

## Forward-Looking Deliverable: v7.6.0.3 Device Test Script

### What was delivered

The automated device test script for v7.6.0.3 (`POST /api/aggregator/test-satellite`) has been created ahead of the v7.6.0.3 implementation:

**File:** `scripts/device-test-v7.6.0.3.sh`
**Usage:** `bash scripts/device-test-v7.6.0.3.sh [aggregator_ip] [satellite_url]`

This script was derived from:
1. `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md` — §11 (Device Testing) and §12 (Contract-Lock for Mock)
2. `scripts/device-test-v7.6.0.2.sh` — structural template

### Tests covered

| # | Test | Source | Expected |
|---|------|--------|----------|
| T1 | Test reachable satellite | §11 Test 1 | 200 + ok=true + gateway object with id, name, hardware, sensor_count |
| T2 | Test unreachable URL | §11 Test 2 | 400 + "Satellite unreachable or invalid manifest" |
| T3 | Missing URL parameter | §11 Test 3 | 400 + "Missing url parameter" |
| T4 | Verify no side effects | §11 Test 4 | Gateway count unchanged after test-satellite call |
| T5 | Bad URL format | §12 contract row | 400 + "URL must start with http://" |
| T6 | Wrong method (GET) | §12 contract row | 405 + "Method not allowed" |
| T7 | Wrong method (DELETE) | §12 contract row | 405 + "Method not allowed" |

### ⚠️ Section 11 update caveat

This script was written based on the v7.6.0.3 prompt's §11 as it exists today. **During v7.6.0.3 implementation and review, the coding agent or reviewers may identify additional error paths, edge cases, or contract changes that require updates to §11.**

If the v7.6.0.3 PR review reveals that Section 11 needs to be updated or modified (e.g., new error responses, changed messages, additional test scenarios from review fixes), then **`scripts/device-test-v7.6.0.3.sh` MUST be updated to match** before device testing begins.

The v7.6.0.3 session handoff document (`prompts/handoff/session-handoff-v7.6.0.3.md`) should include a reconciliation step:
1. Compare the implemented handler's response branches against the test script's expectations
2. Identify any gaps introduced by review fixes or implementation decisions
3. Update the test script if needed
4. Document any changes in the gap analysis table

This follows the same pattern established by BUG-079 in v7.6.0.2, where fixup commits changed routing behavior that was not anticipated by the original test script.

---

## Device Testing Audit & Automated Script

> **⚠️ MANDATORY SECTION — required in every handoff document.**
> Audits the implementation prompt's §11 device tests, identifies gaps, and provides an automated script.

### Why this section exists

Experience from Phase D (v7.6.0.1 PR #108) established that:
1. Prompt-provided device tests may have gaps vs. actual implementation (review fixes add branches)
2. Manual curl sequences are error-prone (missing `-d 'a=1'`, wrong timing, no cleanup)
3. Test results must be machine-parseable for audit documentation
4. curl flags must comply with Critical Rules 38/39 — prompts written before those rules may violate them

### Checklist for this section

- [ ] **Read §11** of `prompts/phaseD/v<VERSION>-implementation-instructions-for-coding-agent.md`
- [ ] **Read §12** (Contract-Lock for Mock) — every contract row should have a corresponding test
- [ ] **Read the implementation** in `dashboard/sensor_history_multi.h` — identify all response branches
- [ ] **Read review findings** (if PR already reviewed) — fixes may add new branches not in §11
- [ ] **Cross-reference** §11 tests against contract table + implementation branches + review findings
- [ ] **Verify curl flags**: all POST/DELETE must use `-d 'a=1'` (Rule 39), correct `-X` method
- [ ] **Verify timing**: reboot tests must account for async NVS saves, poll cycle delays
- [ ] **Produce gap analysis table** (severity: 🔴 BLOCKING / 🟡 MEDIUM / 🟠 LOW)
- [ ] **Produce corrected test sequence** (replaces §11 if gaps found)
- [ ] **Produce automated bash script** at `scripts/device-test-v<VERSION>.sh`

### Gap Analysis — v<VERSION>

| # | Finding | Severity | Issue |
|---|---------|----------|-------|
| G1 | ... | 🔴/🟡/🟠 | ... |

### Corrected §11 Tests

(Only if gaps were found — provide complete corrected test sequence)

### Automated Script

**File:** `scripts/device-test-v<VERSION>.sh`
**Usage:** `bash scripts/device-test-v<VERSION>.sh [aggregator_ip] [satellite_url]`

Script requirements:
- Pre-flight reachability check
- Cleanup of prior test state (idempotent re-runs)
- All tests from corrected §11 + gap-fill tests
- Proper timing (NVS save waits, reboot waits, poll cycle waits)
- `-d 'a=1'` on ALL POST/DELETE per Rule 39
- Post-test cleanup (factory reset or targeted removal)
- Markdown results table output
- Exit code 0/1 for pass/fail

---

## Device Testing Resources

- **S3 aggregator** (ESP32-S3-DevKitC-1 at 192.168.120.191, PSRAM-equipped, serial `/dev/ttyACM0`)
- **C3 satellite** (ESP32-C3 SuperMini at 192.168.120.189)
- **WROOM-32D satellite** (ESP32-WROOM-32D at 192.168.120.190)
- **Placeholder satellite** (sat-esp32-4m-188 at 192.168.120.188 — responds to pings, no API)

Current `config/aggregator.json` has 3 entries (2 real + 1 placeholder), giving MAX_SATELLITES=3.

Device testing for v7.6.0.2 requires at least one deletable satellite. The placeholder at .188 is a good candidate — it's unreachable for API but is in the satellite list. Deleting it verifies the array compaction without losing a working satellite.

**Test sequence suggestion:**
1. Delete the placeholder satellite (.188) → verify it's gone from gateways
2. Verify .189 and .190 still poll correctly
3. Reboot → verify .188 is still deleted
4. Add .188 back (will fail probe — unreachable) or add a different URL
5. Reset to compile-time defaults to restore the placeholder

### Provisioning workflow

```bash
# Before device testing:
bash scripts/provision.sh aggregator   # switch to S3 aggregator mode
# ... regeneration + compile + flash ...
bash scripts/device-test-v7.6.0.2.sh 192.168.120.191

# After device testing, before push:
bash scripts/provision.sh satellite    # switch back to CI-safe mode
bash scripts/provision.sh status       # verify CI-safe=YES
```
---

_End of session handoff document._
