# Session Handoff — v7.6.0.1: POST /api/aggregator/add-satellite (Phase D Step 1)

_Date: 2026-03-29_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Assumption: v7.6.0.0 has been implemented, reviewed (PR #98 + PR #99 fixes), and merged to `main`_

---

## Project State Summary

**v7.6.0.0** is the current version on `main`. **Phase D Step 0 is COMPLETE.**

### What v7.6.0.0 delivered

- NVS satellite persistence layer (`agg_sats` namespace with `count`, `s{i}_id`, `s{i}_name`, `s{i}_url`, `s{i}_poll` keys)
- `load_satellites_from_nvs_()`, `save_satellites_to_nvs_()`, `save_single_satellite_to_nvs_()` functions
- `init_satellite_caches_()` replaces inline init loop in `aggregator_poll_task()`
- `runtime_satellite_count` replaces `MAX_SATELLITES` in all 7 loop bounds
- `SatelliteCache` extended with owned string buffers (`id_buf[32]`, `name_buf[64]`, `url_buf[128]`) and `set_identity()` helper
- `POST /api/system/reset-satellites` factory reset endpoint with authentication, honest error handling
- All-or-nothing NVS load semantics (corrupt entry → full fallback to compile-time defaults)
- NVS seeded with compile-time defaults on first boot and after factory reset
- NVS key buffers sized at `[16]` (safe for indices ≥ 10)
- PR #98: 2 commits + PR #99 fixes merged into branch, 13 files changed
- All Playwright tests pass, preflight passes, CodeQL 0 alerts

### Cumulative state entering Phase D Step 1

| Phase | Version Range | Status |
|-------|--------------|--------|
| Phase 1–3 | v7.5.0.x–v7.5.3.x | ✅ Complete |
| Phase 4 | v7.5.4.x | ✅ Complete |
| Phase 5 | v7.5.5.x | ✅ Complete |
| Phase 6 | v7.5.6.x | ✅ Complete |
| v7.5.7.0 | Bridge step | ✅ Complete |
| v7.6.0.0 | NVS satellite persistence layer | ✅ Complete 2026-03-29 |
| **Phase D Step 1** | **v7.6.0.1** | **⬅️ Starting** |

### Key infrastructure changes from v7.6.0.0 relevant to v7.6.0.1

- **`SatelliteCache.set_identity()`** — copies id/name/url/poll into owned buffers (`id_buf[32]`, `name_buf[64]`, `url_buf[128]`). Pointer lifetime safe for all callers.
- **`save_single_satellite_to_nvs_(int index)`** — writes one entry + updates count. Does NOT erase-all. This is the correct function for the add path.
- **`runtime_satellite_count`** — is the loop bound for all satellite iteration. Increment this when adding a satellite (under mutex).
- **NVS seeded on first boot** — `init_satellite_caches_()` calls `save_satellites_to_nvs_()` when falling back to compile-time defaults (PR #99 Fix 4). So `save_single_satellite_to_nvs_()` can safely write just the new entry.
- **`s_proxy_tmp` (32KB)** — the web handler buffer. Use for probing via `fetch_to_buffer()`. Do NOT use `s_fetch_tmp` from a web handler — it is owned by the polling task.
- **`authenticate_management_()`** — must be called on all mutation endpoints. Pattern: auth check → validation → mutation → response.

---

## Phase D Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.0.0 | NVS satellite persistence layer | ✅ Complete 2026-03-29 |
| v7.6.0.1 | POST /api/aggregator/add-satellite | ⬅️ Next |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | Pending |
| v7.6.0.3 | POST /api/aggregator/test-satellite | Pending |
| v7.6.0.4 | Dashboard add/remove/test UI | Pending |
| v7.6.0.5 | Playwright tests + Phase D closure | Pending |

---

## v7.6.0.1 Scope

Replace the 501 stub for `POST /api/aggregator/add-satellite` with a working implementation. **No dashboard changes. No test changes.**

### What v7.6.0.1 must deliver

1. **`probe_satellite_manifest_()` helper** — factor out now (will be reused by v7.6.0.3 `test-satellite`). Fetches `/api/manifest` from a candidate URL, extracts `gateway.id` and `gateway.name` via `strstr` parsing. Uses `s_proxy_tmp` (web handler context only). Returns `false` on unreachable/invalid.

2. **`handle_add_satellite_()` implementation** — replaces the 501 stub:
   - Parse query params: `url` (required), `name` (optional), `poll` (optional, default 30, min 10, max 3600)
   - Validate `url` starts with `http://`
   - Check `runtime_satellite_count < MAX_SATELLITES` (reject 409 if full)
   - Check no duplicate URL in `satellite_caches[0..runtime_satellite_count-1]`
   - Probe candidate via `probe_satellite_manifest_()`
   - Determine final name: request param > manifest `gateway.name` > derived from URL
   - `AGG_LOCK()` → `set_identity()` + `clear_cache()` + `runtime_satellite_count++` → `AGG_UNLOCK()`
   - `save_single_satellite_to_nvs_(new_idx)` (outside mutex — NVS is slow)
   - Return 200 `{"ok":true,"satellite":{"id":"...","name":"...","url":"...","poll":N}}`

3. **Routing change** — in `handleRequest()`, change stub call to `handle_add_satellite_(request)`

4. **Documentation**: `Docs/changelog.md` v7.6.0.1 entry, `Docs/bugs-and-lessons-learned.md` if new lessons

### v7.6.0.1 API contract

```
POST /api/aggregator/add-satellite?url=http://192.168.120.189&name=Kitchen&poll=30
```

| Condition | HTTP Status | Response |
|-----------|-------------|----------|
| Valid URL, probe succeeds | 200 | `{"ok":true,"satellite":{"id":"...","name":"...","url":"...","poll":30}}` |
| Missing `url` parameter | 400 | `{"ok":false,"message":"Missing url parameter","status":400}` |
| URL doesn't start with `http://` | 400 | `{"ok":false,"message":"URL must start with http://","status":400}` |
| Satellite list full (count >= MAX) | 409 | `{"ok":false,"message":"Satellite list full","status":409}` |
| Duplicate URL | 409 | `{"ok":false,"message":"URL already configured","status":409}` |
| Probe failed (unreachable/bad manifest) | 400 | `{"ok":false,"message":"Satellite unreachable or invalid manifest","status":400}` |
| Wrong HTTP method | 405 | `{"ok":false,"message":"Method not allowed","status":405}` |
| Mutex timeout | 503 | `{"ok":false,"message":"Mutex timeout","status":503}` |

---

## Pre-merge Checklist for v7.6.0.1

Before merging the v7.6.0.1 PR:

- [ ] v7.6.0.0 merged and tagged (`v7.6.0.0`)
- [ ] Device testing completed:
  - [ ] Test 1: Add a satellite via curl: `curl -d 'a=1' "http://192.168.120.191/api/aggregator/add-satellite?url=http://192.168.120.189&name=Test+Satellite"` (expected: 200 with satellite JSON)
  - [ ] Test 2: Verify new satellite appears in `/api/aggregator/gateways` after poll cycle
  - [ ] Test 3: Duplicate URL rejection (expected: 409 "URL already configured")
  - [ ] Test 4: Missing URL parameter (expected: 400 "Missing url parameter")
  - [ ] Test 5: Bad URL format (expected: 400 "URL must start with http://")
  - [ ] Test 6: Unreachable URL (expected: 400 "Satellite unreachable or invalid manifest")
  - [ ] Test 7: Reboot persistence: `curl -d 'a=1' -u ESPadmin:ESppass100 http://192.168.120.191/api/reboot` then verify
- [ ] All Playwright fixture sets passing:
  ```bash
  FIXTURE_SET=3sensor npx playwright test --project=chromium
  FIXTURE_SET=3sensor npx playwright test --project=firefox
  FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium
  FIXTURE_SET=system npx playwright test --grep "System" --project=chromium
  FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
  bash scripts/preflight.sh
  python3 scripts/render_sensor_config.py --check
  ```

---

## Lessons Learned from v7.6.0.0

These are back-ported from the v7.6.0.0 PR #98 + PR #99 review. The v7.6.0.1 prompt has been updated to incorporate findings 1–5.

### LESSON-OPS-092 — NVS key buffer sizing

**Source:** v7.6.0.0 PR #98. Agent chose `char key_*[8]` for NVS key buffers. Keys like `s10_name` are 8 chars + NUL = 9 bytes, which overflows an `[8]` buffer. Fixed in PR #99 to `[16]` (NVS max key length = 15 + NUL).

**Rule:** NVS key buffers must be `[16]` (the NVS key length limit is 15 chars + NUL). When a prompt specifies a key scheme with indexed names (`s{i}_suffix`), the buffer sizing must be calculated for the maximum expected index, not just the current index. Prompts must include explicit buffer sizes (`char key_*[16]`) in NVS code blocks.

### LESSON-OPS-093 — Management endpoints must have explicit auth requirement in prompt

**Source:** v7.6.0.0 PR #98. The prompt added `POST /api/system/reset-satellites` but did not specify that it requires `authenticate_management_()`. The agent omitted authentication. Fixed in PR #99.

**Rule:** Every prompt that adds an endpoint that mutates persistent state (NVS, file system, runtime config) must explicitly state: "This endpoint MUST call `authenticate_management_()` as the first action." Do not assume the agent will follow security conventions by analogy.

### LESSON-OPS-094 — NVS seeding on first boot is not automatic

**Source:** v7.6.0.0 PR #98. The prompt said "populate from compile-time arrays" but did not say "and write to NVS". The agent loaded from compile-time arrays but did not persist them to NVS. On the first mutation (add/remove), only the delta was written, and all defaults were lost on reboot. Fixed in PR #99.

**Rule:** When NVS is the single source of truth for runtime data that starts from compile-time defaults, the first-boot path must explicitly seed NVS with those defaults. Prompts must include this requirement: "After loading compile-time defaults, call `save_satellites_to_nvs_()` to seed NVS."

### LESSON-OPS-095 — All-or-nothing load semantics for NVS arrays

**Source:** v7.6.0.0 PR #98. When reading a counted NVS array, the agent used `break` on read failure, causing a partial load: the first N-1 entries were loaded and entry N was silently dropped. This creates an invisible topology shrink.

**Rule:** If any entry in a counted NVS array fails to read, the entire load must be aborted: close the NVS handle, return 0 (empty), and let the caller fall back to safe defaults. Prompts must specify this explicitly: "On any NVS read failure mid-array, close the handle and return 0 (all-or-nothing)."

### LESSON-OPS-096 — Boot-time init vs runtime mutation mutex ordering

**Source:** v7.6.0.0 PR #98. Copilot reviewer noted that `init_satellite_caches_()` runs without acquiring `s_cache_mutex`. The ESPHome startup sequence guarantees `aggregator_poll_task()` init completes before the web server accepts connections, so the current implementation is safe. However, the absence of a mutex creates technical debt if startup ordering ever changes.

**Rule:** For v7.6.0.1, the startup ordering guarantee holds. If init-time code is added in future steps, verify it runs before web handlers can fire. Future consideration: wrap init in the same mutex for defense-in-depth once runtime mutators are active.

### Post-v7.6.0.0 stabilization (BUG-075/076, LESSON-OPS-097–102, Critical Rules 38–42)

After v7.6.0.0 merged, device testing revealed that **every POST request with a body crashed the S3 aggregator**. Three days of investigation (PR #101, #102, #103, #104, #105) led to the root cause and fix:

**Root cause:** ESP-IDF's `HTTPD_DEFAULT_CONFIG()` hardcodes `.stack_size = 4096`. ESPHome's `web_server_idf.cpp` never overrides it. `CONFIG_HTTPD_STACK_SIZE` in `sdkconfig_options` is dead config with zero runtime effect. Even the lightest handler (auth check + 401 response) overflows 4 KB.

**Primary fix:** Local ESPHome component override in `firmware/local_components/web_server_idf/` patches `config.stack_size = 16384`. Managed by `scripts/patch-esphome-httpd-stack.sh` (re-run after ESPHome upgrades). Board profiles include `external_components` block.

**Secondary fix:** Deferred task pattern for NVS-heavy handlers (`handle_reset_satellites_()`, `handle_delete_data_()`): authenticate → respond → `xTaskCreate` with 8192-byte stack for NVS work.

**Content-type fix:** ESPHome only consumes `application/x-www-form-urlencoded` POST bodies. JSON bodies corrupt socket state. All dashboard `fetch()` POST calls use `Content-Type: application/x-www-form-urlencoded` with `body: 'a=1'`. All curl POST commands use `-d 'a=1'`.

**New lessons (full text in `Docs/bugs-and-lessons-learned.md`):**
- **LESSON-OPS-097:** Never commit generated files while operator configs are present
- **LESSON-OPS-098:** `sdkconfig_options` must be in board profiles, not templates
- **LESSON-OPS-099:** ESPHome only consumes `x-www-form-urlencoded` POST bodies
- **LESSON-OPS-100:** `CONFIG_HTTPD_STACK_SIZE` is dead config
- **LESSON-OPS-101:** Deferred task pattern for NVS-heavy HTTP handlers
- **LESSON-OPS-102:** httpd stack must be patched via local component override

**New Critical Rules (42 total — was 35):**
- **Rule 38:** Dashboard POST → `x-www-form-urlencoded`, `body: 'a=1'`
- **Rule 39:** curl POST → `-d 'a=1'`, never `-H "Content-Length: 0"`
- **Rule 40:** NVS bulk ops in HTTP handler → deferred task pattern
- **Rule 41:** Never add `CONFIG_HTTPD_STACK_SIZE` to board profiles
- **Rule 42:** Board profiles must include `external_components` for patched `web_server_idf`

---

## Workflow for v7.6.0.1

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for clarification.**

1. Ask human if PR for v7.6.0.1 has been opened and ask to provide the PR number
2. If PR has not been opened, **open a NEW coding agent session outside of this chat** and paste the prompt from `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md`
3. Wait for the agent to create the PR
4. Copilot PR reviewer reviews automatically and additional reviews might be posted
5. Human reviews PR against the Review Checklist in the prompt
6. Fix any issues
7. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
8. Provide to human all the necessary instructions to run tests
9. Provide instructions after merging PR to Main with tagging and pushing the tag

---

## Post-PR Closure Deliverables for v7.6.0.1

After the v7.6.0.1 PR is merged, produce these documents:

### 1. Session Handoff Document

**File:** `prompts/handoff/session-handoff-v7.6.0.2.md`
**Format:** Same as this document. Must include:
- Project state summary with v7.6.0.1 changes
- Phase D progress (v7.6.0.1 complete, v7.6.0.2 next)
- v7.6.0.2 scope: DELETE /api/aggregator/satellite/{id}
- Pre-merge checklist for v7.6.0.2
- Workflow and Post-PR Closure sections for v7.6.0.2
- Lessons learned from v7.6.0.1

### 2. PR and Prompt Audit Document

**⚠️ IMPORTANT: the PR and Prompt Audit Document must include answers to these questions:**

- Did the coding agent deliver properly and accurately what was required from the prompt? How is the execution quality?
- Did the codebase state at execution time match the prompt's assumptions? If function signatures, line numbers, or struct layouts had drifted from what the prompt described, how did the agent handle the delta — did it reconcile correctly or silently diverge?
- What implementation decisions did the agent make that were NOT specified in the prompt? Were those decisions correct? Should any of them be back-ported as explicit requirements into the prompt for reproducibility?
- If the coding agent did not execute properly what was required, then: why it happened and what caused it?
- Coding agent's prompt audit: was the prompt created according to the `Docs/writing-prompts-for-coding-agents-guide.md` guideline document, and if not, where was the deviation?
- If there were failures, how to prevent such failures by coding agents in future?
- Code reviews: are the changes/information mentioned in the PR comments/code audits warranted? Create list of PR comments and conclusion if changes warranted or not and why.

**File:** `prompts/phaseD/v7.6.0.1-PR<NN>-consolidated-audit-and-lessons.md`
**Format:** Same as `prompts/phase6/v7.5.7.0-PR93-consolidated-audit-and-lessons.md`

### 3. Updated Prompt Corrections (if needed)

If the v7.6.0.1 prompt audit reveals defects in subsequent Phase D prompts, produce correction text and apply to `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md` and beyond.

### 4. Updated prompt-index-and-workflow.md

Mark v7.6.0.1 as complete with date in the Phase D table.

---

## Device Testing Resources

Phase D requires two devices throughout:

- **S3 aggregator** (ESP32-S3-DevKitC-1 at 192.168.120.191, PSRAM-equipped, runs aggregator firmware with `config/aggregator.json`)
- **C3 satellite** (ESP32-C3 SuperMini at 192.168.120.189, reachable from aggregator over network)
- **WROOM-32D satellite** (ESP32-WROOM-32D at 192.168.120.190, running v7.5.7.0+, reachable from aggregator over network)

Device testing highlights per remaining steps:
- **v7.6.0.1:** Add satellite via API, verify polling starts, verify NVS persistence across reboot
- **v7.6.0.2:** Remove satellite via API, verify polling stops, verify NVS updated
- **v7.6.0.3:** Test-satellite probe, verify no side effects (satellite not added)
- **v7.6.0.4:** Full browser test of dashboard add/remove/test workflow
- **v7.6.0.5:** Playwright regression + Phase D closure verification

---

_End of session handoff document._
