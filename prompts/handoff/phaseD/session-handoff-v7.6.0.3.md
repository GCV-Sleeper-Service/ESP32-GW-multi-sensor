# Session Handoff — v7.6.0.3: POST /api/aggregator/test-satellite (Phase D Step 3)

_Date: 2026-04-02_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.0.3 planning notes. v7.6.0.2 is COMPLETE and merged to main. POST /api/aggregator/test-satellite remains a 501 stub._

---

## Project State Summary

**v7.6.0.2** is the current version on `main`. **Phase D Step 2 is COMPLETE.**

### What v7.6.0.2 delivered

- `handle_delete_satellite_()` implementation replacing the 501 stub
- Array compaction with `set_identity` + field-by-field copy
- SatelliteNVSSnapshot pattern for safe deferred NVS saves
- Generation counter (`s_satellite_config_gen`) for poll task stale-data detection
- `s_nvs_save_in_progress` flag to prevent concurrent NVS saves
- `AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN` replacing magic number
- GET/POST → 405 wiring for wrong-method requests on DELETE URI
- PR #110: 6 commits, 26 files changed

### v7.6.0.2 post-merge fixups

- **BUG-079 (HTTP DELETE handler registration):** `AsyncWebServer::begin()` in `web_server_idf.cpp` only registered GET/POST/OPTIONS. No HTTP_DELETE handler. Plain-text 405 from ESP-IDF httpd. Fixed by PR #114 + PR #115 fixup. Added HTTP_DELETE URI handler registration, PATCH2 sentinels, patch script updated.
- **device-test-v7.6.0.2.sh T1 auth bug:** Missing `-u` flag caused 401 instead of 400. Script bug, not firmware bug. Fixed in PR #116.

### Cumulative state entering Phase D Step 3

| Phase | Version Range | Status |
|-------|--------------|--------|
| Phase 1–3 | v7.5.0.x–v7.5.3.x | ✅ Complete |
| Phase 4 | v7.5.4.x | ✅ Complete |
| Phase 5 | v7.5.5.x | ✅ Complete |
| Phase 6 | v7.5.6.x | ✅ Complete |
| v7.5.7.0 | Bridge step | ✅ Complete |
| v7.6.0.0 | NVS satellite persistence layer | ✅ Complete 2026-03-29 |
| v7.6.0.1 | POST /api/aggregator/add-satellite | ✅ Complete 2026-03-31 |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | ✅ Complete 2026-04-02 |
| **v7.6.0.3** | **POST /api/aggregator/test-satellite** | **⬅️ This session** |

### Key infrastructure changes from v7.6.0.2 relevant to v7.6.0.3

- **`probe_satellite_manifest_()`** exists (added v7.6.0.1) and uses `s_proxy_tmp`. v7.6.0.3 reuses it directly. After it returns true, `s_proxy_tmp` still contains the full manifest JSON — v7.6.0.3 parses `hardware` and `sensor_count` from it.
- **HTTP_DELETE is now registered** at the transport layer. No new HTTP methods needed for v7.6.0.3 (POST is already registered).
- **`handle_aggregator_stub_501_()`** should have no remaining callers after v7.6.0.3 replaces the last 501 stub. The v7.6.0.3 prompt instructs to remove it.
- **All HTTP status codes mapped** in `init_response_()` (BUG-078 fix). Device tests can rely on exact HTTP status matching.
- **Critical Rules now total 44** (Rules 43–44 added for BUG-078/BUG-077 in v7.6.0.1 era).

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

## v7.6.0.3 Scope

Replace the 501 stub for `POST /api/aggregator/test-satellite` with a working probe endpoint. **NO side effects — does not add the satellite, does not modify NVS, does not modify satellite_caches[].** No dashboard changes. No test changes.

### What v7.6.0.3 must deliver

1. **`handle_test_satellite_()` implementation** — replaces the 501 stub:
   - Parse `url` query parameter (required)
   - Validate URL format (must start with `http://`)
   - Probe via existing `probe_satellite_manifest_()` — reuses v7.6.0.1 helper
   - Extract `hardware` and `sensor_count` from `s_proxy_tmp` (strstr-based parsing)
   - Return 200 with gateway summary JSON

2. **501 stub cleanup** — if `handle_aggregator_stub_501_()` has no remaining callers, remove it

3. **Routing change** — replace the 501 stub call for test-satellite path in `handleRequest()`

4. **Documentation**: `Docs/changelog.md` v7.6.0.3 entry, `Docs/bugs-and-lessons-learned.md` if new lessons

### v7.6.0.3 API contract

```
POST /api/aggregator/test-satellite?url=http://192.168.120.189
```

| Condition | HTTP Status | Response |
|-----------|-------------|----------|
| Valid URL, probe succeeds | 200 | `{"ok":true,"gateway":{"id":"...","name":"...","hardware":"...","sensor_count":N}}` |
| Missing `url` parameter | 400 | `{"ok":false,"message":"Missing url parameter","status":400}` |
| URL doesn't start with `http://` | 400 | `{"ok":false,"message":"URL must start with http://","status":400}` |
| Probe failed | 400 | `{"ok":false,"message":"Satellite unreachable or invalid manifest","status":400}` |
| Wrong HTTP method | 405 | `{"ok":false,"message":"Method not allowed","status":405}` |

---

## Pre-merge Checklist for v7.6.0.3

- [ ] v7.6.0.2 merged, tagged (`v7.6.0.2`), all fixups committed
- [ ] Device testing completed (via automated script):
  ```bash
  bash scripts/provision.sh aggregator
  # ... regeneration pipeline ...
  esphome clean firmware/esp32-s3-devkitc1-n16r8-gw.yaml
  esphome run firmware/esp32-s3-devkitc1-n16r8-gw.yaml
  bash scripts/device-test-v7.6.0.3.sh 192.168.120.191
  ```
  - [ ] T1: Test reachable satellite (200 + gateway object)
  - [ ] T2: Test unreachable URL (400)
  - [ ] T3: Missing URL parameter (400)
  - [ ] T4: Verify no side effects (satellite count unchanged)
  - [ ] T5: Bad URL format (400)
  - [ ] T6: Wrong method GET (405)
  - [ ] T7: Wrong method DELETE (405)
- [ ] All Playwright fixture sets passing
- [ ] preflight.sh passes
- [ ] `render_sensor_config.py --check` passes
- [ ] No `String` (Arduino) type in any new code (Critical Rule 44)
- [ ] Switched back to CI-safe mode: `bash scripts/provision.sh satellite`

### v7.6.0.3 prompt known issues

1. **Line 155: `String url_param`** — The prompt code block at §5d line 155 uses Arduino `String`. The coding agent MUST use `std::string` instead (Critical Rule 44 / BUG-077). This is the same bug pattern as v7.6.0.1.
2. **§7 Rule 2:** Shows `bump-version.sh 7.6.0.1` — should be `7.6.0.3`.

---

## v7.6.0.2 Lessons Relevant to v7.6.0.3

### LESSON-OPS-105 — NVS snapshot pattern (2026-04-02)

NVS save tasks run outside the mutex — data can change between task scheduling and execution. Use a snapshot pattern. **Not directly relevant to v7.6.0.3 (no NVS writes), but confirms the pattern.**

### LESSON-OPS-106 — Concurrent deferred task serialization (2026-04-02)

Concurrent deferred tasks from rapid mutations can corrupt NVS. Serialize with a flag. **Not relevant to v7.6.0.3 (read-only endpoint).**

### LESSON-OPS-107 — Generation counter for stale data (2026-04-02)

Poll task must detect config changes during multi-step fetch sequences. **Not relevant to v7.6.0.3 (no config mutation).**

### LESSON-OPS-108 — handleRequest() GET fallthrough method guard (2026-04-02)

The GET fallthrough in `handleRequest()` has no method guard. New routes added there intercept ALL methods. Non-GET/POST dispatch must use explicit `request->method()` checks placed BEFORE the GET fallthrough. **Relevant: v7.6.0.3 handler must check `request->method() != HTTP_POST` and return 405.**

### LESSON-OPS-109 — Plain-text 405 vs JSON 405 diagnostic (2026-04-02)

Plain-text 405 from ESP-IDF means transport-layer rejection. JSON 405 from `send_json_error_()` means the handler ran. **Useful for debugging if device tests show wrong 405 format.**

---

## Workflow for v7.6.0.3

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for clarification.**

1. Ask human if PR for v7.6.0.3 has been opened and ask to provide the PR number
2. If PR has not been opened, **open a NEW coding agent session outside of this chat** and paste the prompt from `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md`
3. Wait for the agent to create the PR
4. Copilot PR reviewer reviews automatically and additional reviews might be posted
5. Human reviews PR against the Review Checklist in the prompt
6. Fix any issues
7. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
8. Provide to human all the necessary instructions to run tests
9. Provide instructions after merging PR to Main with tagging and pushing the tag

---

## Post-PR Closure Deliverables for v7.6.0.3

After the v7.6.0.3 PR is merged, produce these documents:

### 1. Session Handoff Document

**File:** `prompts/handoff/session-handoff-v7.6.0.4.md`
**Format:** Same as this document.

### 2. PR and Prompt Audit Document

**File:** `prompts/phaseD/v7.6.0.3-PR<NN>-consolidated-audit-and-lessons.md`
**Format:** Same as `prompts/phaseD/v7.6.0.2-PR110-consolidated-audit-and-lessons.md`

**⚠️ IMPORTANT: Must answer these questions:**
- Did the coding agent deliver properly and accurately what was required?
- Did the codebase state match the prompt's assumptions?
- What implementation decisions did the agent make beyond the prompt?
- Coding agent prompt audit against the writing guide
- PR comment review and disposition

### 3. Updated Prompt Corrections (if needed)

Apply corrections to subsequent Phase D prompts if the audit reveals defects.

### 4. Updated prompt-index-and-workflow.md

Mark v7.6.0.3 as complete with date.

---

## Device Test Script Reconciliation

v7.6.0.3 has a pre-built device test script created during the v7.6.0.2 session:

**File:** `scripts/device-test-v7.6.0.3.sh`
**Usage:** `bash scripts/device-test-v7.6.0.3.sh [aggregator_ip] [satellite_url]`

After the v7.6.0.3 PR is merged but BEFORE device testing:
1. Compare the implemented handler's response branches against the test script's expectations
2. Identify any gaps introduced by review fixes or implementation decisions
3. Update the test script if needed
4. Document any changes in the gap analysis table

This follows the pattern established by BUG-079 in v7.6.0.2.

---

## Device Testing Audit & Automated Script

> **⚠️ MANDATORY SECTION — required in every handoff document.**
> Audits the implementation prompt's §11 device tests, identifies gaps, and provides an automated script.

### Why this section exists

Experience from Phase D (v7.6.0.1 PR #108, v7.6.0.2 PR #110) established that:
1. Prompt-provided device tests may have gaps vs. actual implementation (review fixes add branches)
2. Manual curl sequences are error-prone (missing `-d 'a=1'`, wrong timing, no cleanup)
3. Test results must be machine-parseable for audit documentation
4. curl flags must comply with Critical Rules 38/39

### Checklist for this section

- [ ] **Read §11** of `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md`
- [ ] **Read §12** (Contract-Lock for Mock) — every contract row should have a corresponding test
- [ ] **Read the implementation** in `dashboard/sensor_history_multi.h` — identify all response branches
- [ ] **Read review findings** (if PR already reviewed) — fixes may add new branches not in §11
- [ ] **Cross-reference** §11 tests against contract table + implementation branches + review findings
- [ ] **Verify curl flags**: all POST must use `-d 'a=1'` (Rule 39), correct method
- [ ] **Verify timing**: T2 (unreachable URL) needs `--max-time 20` for probe timeout
- [ ] **Produce gap analysis table** (severity: 🔴 BLOCKING / 🟡 MEDIUM / 🟠 LOW)
- [ ] **Update `scripts/device-test-v7.6.0.3.sh`** if gaps found
- [ ] **Produce automated bash script** — already exists at `scripts/device-test-v7.6.0.3.sh`

### Gap Analysis — v7.6.0.3

Pre-implementation gap analysis (based on prompt §11 vs §12):

| # | Finding | Severity | Issue |
|---|---------|----------|-------|
| G1 | §11 missing bad URL format test (ftp://) | 🟡 MEDIUM | Covered by T5 in device-test-v7.6.0.3.sh |
| G2 | §11 missing wrong method tests | 🟡 MEDIUM | Covered by T6/T7 in device-test-v7.6.0.3.sh |
| G3 | `String` in prompt code block (line 155) | 🔴 BLOCKING | Must use `std::string` — Critical Rule 44 |

**Note:** G1 and G2 were anticipated during v7.6.0.2 closure and pre-filled in the device test script. G3 is a prompt defect the coding agent must catch or be warned about.

### Automated Script

**File:** `scripts/device-test-v7.6.0.3.sh` (already exists)
**Usage:** `bash scripts/device-test-v7.6.0.3.sh [aggregator_ip] [satellite_url]`

---

## Device Testing Resources

- **S3 aggregator** (ESP32-S3-DevKitC-1 at 192.168.120.191, PSRAM-equipped, serial `/dev/ttyACM0`)
- **C3 satellite** (ESP32-C3 SuperMini at 192.168.120.189)
- **WROOM-32D satellite** (ESP32-WROOM-32D at 192.168.120.190)
- **Placeholder satellite** (sat-esp32-4m-188 at 192.168.120.188 — responds to pings, no API)

Current `config/aggregator.json` has 3 entries (2 real + 1 placeholder), giving MAX_SATELLITES=3.

### Provisioning workflow

```bash
# Before device testing:
bash scripts/provision.sh aggregator   # switch to S3 aggregator mode
# ... regeneration + compile + flash ...
bash scripts/device-test-v7.6.0.3.sh 192.168.120.191

# After device testing, before push:
bash scripts/provision.sh satellite    # switch back to CI-safe mode
bash scripts/provision.sh status       # verify CI-safe=YES
```

---

_End of session handoff document._
