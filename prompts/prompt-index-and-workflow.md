Coding Agent Prompt Index and Workflow

_Single source of truth for all implementation prompts._
_Last updated: 2026-04-04 — Phase D complete (v7.6.0.5); Critical Rules 43–44 confirmed; Phase D results and summary produced_
_Replaces: `phase3-prompt-templates.md`, `phase3-prompt-templates-updated.md`, `prompt-update-summary.md`_

---

## How This Works

Each implementation step has a self-contained prompt file that a coding agent can execute from scratch. The prompt contains everything the agent needs: context, required reading, exact scope, critical rules, acceptance criteria, and device testing instructions.

Your job as the human operator is to:

1. Pick the next step from the Step Index below
2. Copy the prompt into a new conversation with the coding agent
3. Supervise the PR, merge, device-test, and tag
4. Record results and move to the next step

### Related Documents

| Document | Location | Purpose |
|----------|----------|---------| 
| Architecture Plan | `Docs/v7.5-v7.6-architecture-plan.md` | Design rationale and phase definitions |
| Persistence Architecture | `Docs/v7.7-v7.8-persistence-architecture.md` | Per-device persistence design for Phase 7 |
| Phase 4 Implementation Plan | `Docs/phase4-implementation-plan.md` | Step-level scope for Phase 4 |
| Phase 5 Implementation Plan | `Docs/phase5-implementation-plan.md` | Step-level scope for Phase 5 |
| Phase 6 Implementation Plan | `Docs/phase6-implementation-plan.md` | Step-level scope for Phase 6 |
| Phase D Implementation Plan | `Docs/phase-d-implementation-plan.md` | Step-level scope for Phase D |
| Phase 7 Implementation Plan | `Docs/v7.7-implementation-plan.md` | Step-level scope for Phase 7 |
| Bugs & Lessons Learned | `Docs/bugs-and-lessons-learned.md` | Project guardrails and failure history |
| **Prompt Writing Guide** | `Docs/writing-prompts-for-coding-agents-guide.md` | How to create and audit prompts |
| Architecture Forward-Looking Notes | `Docs/architecture-forward-looking-notes.md` | Post-Phase-6 architectural decisions and risks |
| **Phase D Results and Summary** | `prompts/handoff/phaseD-results.md` | Phase D delivery record, lessons, API contracts |

---

## Step-by-Step Workflow

### Before starting a step

1. Confirm the previous step is merged to `main` and tagged
2. If the previous step required device testing, confirm results are recorded
3. Verify `main` is green: `bash scripts/preflight.sh` and Playwright pass
4. Check the Step Index below for the next step and its prompt file location

### Giving the prompt to the coding agent

Open a **new conversation** with the coding agent (do not continue a previous conversation — each step starts fresh). Paste this:

```
Clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the implementation instructions file completely:
prompts/<phase>/<version>-implementation-instructions-for-coding-agent.md

Then read every file listed in the "Required Reading" section of that document.

Then implement the step exactly as specified.

Current status:
- Previous step v<PREV_VERSION> is complete and merged
- Device testing results from previous step: <PASTE RESULTS OR "confirmed passing">
- main is green, all Playwright tests pass
- Current date: <TODAY>

Follow all rules listed under "Critical Rules" in the instructions file.
After implementation, run validation (preflight + Playwright), create a PR,
and provide the exact device testing checklist for me to execute post-merge.

MANDATORY deliverables (in addition to the code):
- Session log: Docs/session-log-<TODAY>-<VERSION>.md
- Instruction Compliance Output table in the PR description
- Validation Evidence (exact command + pass/fail/skip counts)

Do NOT proceed to any later step.
```

Fill in:
- `<phase>` — `phase4`, `phase5`, `phase6`, `phaseD`, or `phase7`
- `<version>` — e.g., `v7.7.0.0`
- `<PREV_VERSION>` — the version that was just completed
- `<TODAY>` — current date
- Device testing results — paste the actual curl outputs / heap values / screenshots from the previous step

### While the agent works

The agent will:
1. Clone the repo
2. Read the instructions and required files
3. Implement the changes
4. Run preflight and Playwright tests
5. Create a session log
6. Provide an Instruction Compliance Output table
7. Create a PR
8. Provide a device testing checklist

### After the agent completes

1. **Verify the session log exists** — `Docs/session-log-<DATE>-<VERSION>.md`
2. **Verify the Instruction Compliance Output** — every prompt requirement mapped to code
3. **Review the PR diff** — look for anything that contradicts the instructions
4. **Approve pending CI workflows** if needed (first-time contributors may need approval)
5. **Wait for all CI checks to pass** — do not merge on red
6. **If any workflow fails:** copy the exact failure output, send it back to the agent in the same conversation, and wait for the fix
7. **Merge only if all checks are green**
8. **Execute the device testing checklist** the agent provided (if applicable)
9. **Apply the git tag:**
   ```bash
   git pull origin main
   git tag -a v<VERSION> -m "<description from instructions file>"
   git push origin v<VERSION>
   ```
10. **Record results** — save heap values, screenshots, curl outputs. These become the "device testing results" you paste into the next step\'s prompt.

---

## Step Index

### Phase 3 — C++ SensorEntity Model ✅ COMPLETE

All steps shipped. No prompts needed.

| Version | Scope | Status |
|---------|-------|--------|
| v7.5.3.0 | Pre-Phase 3 cleanup | ✅ Complete |
| v7.5.3.1 | Define SensorEntity structs | ✅ Complete |
| v7.5.3.2 | Generator dual output | ✅ Complete |
| v7.5.3.3 | Wire YAML lambdas (dual-write) | ✅ Complete |
| v7.5.3.4 | BUG-043 hotfix + LWIP sockets | ✅ Complete |
| v7.5.3.5 | BUG-043 continued fix (sequential history) | ✅ Complete |
| (no bump) | BUG-043 gzip + pre-reserved history response | ✅ Complete |
| v7.5.3.6 | `/api/v2/live` endpoint | ✅ Complete |
| v7.5.3.7 | `/api/v2/history` endpoint (RAM-only) | ✅ Complete |
| v7.5.3.8 | Remove SensorSlot (BIG SWITCHOVER) | ✅ Complete |
| v7.5.3.9 | Phase 3 closure | ✅ Complete |

### BUG-043 / BUG-044 Supplementary ✅ COMPLETE

| Item | Scope | Status |
|------|-------|--------|
| Preflight enhancements | 5 new checks | ✅ Complete (2026-03-18) |
| Browser regression tests | Group 16: 8 tests | ✅ Complete (2026-03-18) |

### Phase 4 — First Non-Climate Sensor (Ping Probe) ✅ COMPLETE

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.5.4.0 | Add ping device to manifest (BUG-045 fix) | _(completed, no expanded prompt needed)_ | ✅ Complete |
| v7.5.4.1 | Implement ICMP ping adapter | `prompts/phase4/v7.5.4.1-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-19 |
| v7.5.4.2 | Add network card renderer | `prompts/phase4/v7.5.4.2-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-19 |
| v7.5.4.3 | Mixed-category test fixtures | `prompts/phase4/v7.5.4.3-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-20 |
| v7.5.4.4 | Phase 4 closure | `prompts/phase4/v7.5.4.4-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-20 |
| **v7.5.4.5** | **Post-Phase-4 review fixes** | _(manual review session, not agent-driven)_ | ✅ Complete 2026-03-21 |

**v7.5.4.5 fixes (from post-Phase-4 review):**
- BUG-052: `/sensors.json` v1 projection filtered to environmental only
- BUG-053: `/api/status` category-aware fields
- BUG-054: Calendar date picker dark/light mode CSS
- BUG-055: `bump-version.sh` stale `.min.html` handling
- BUG-056: WAN Latency removed from temperature/humidity charts (`chartIdx` filtering)

### Phase 5 — Aggregator MVP ✅ COMPLETE

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.5.5.0 | Aggregator config schema | `prompts/phase5/v7.5.5.0-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-21 |
| v7.5.5.1 | Aggregator polling task | `prompts/phase5/v7.5.5.1-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-22 |
| (no bump) | Multi-board infrastructure | PR #66 + follow-up fixes (BUG-060, BUG-061) | ✅ Complete 2026-03-24 |
| (no bump) | Pre-v7.5.5.2 infrastructure | Config separation, ota_0 preflight, validate-device.sh, PR66 Codex fixes, BUG-062 | ✅ Complete 2026-03-24 |
| v7.5.5.2 | Aggregator API endpoints | `prompts/phase5/v7.5.5.2-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-24 |
| v7.5.5.3 | Aggregator dashboard UI + settings panel groundwork | `prompts/phase5/v7.5.5.3-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-24 |
| (no bump) | v7.5.5.3 hotfix: BUG-064–067, LESSON-OPS-074 | Manual session (not agent-driven) | ✅ Complete 2026-03-25 |
| v7.5.5.4 | Aggregator Playwright tests | `prompts/phase5/v7.5.5.4-hotfix-addendum.md` + `v7.5.5.4-implementation-instructions-for-coding-agent-updated.md` | ✅ Complete 2026-03-25 |
| v7.5.5.5 | Phase 5 closure | `prompts/phase5/v7.5.5.5-update-notes.md` + `v7.5.5.5-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-25 |

**Phase 5 device testing requirements:**
- v7.5.5.0: compile-only (both with and without `aggregator.json`)
- v7.5.5.1: **requires TWO devices** — satellite + aggregator. Verify polling logs, satellite unaffected, heap stable, unreachable/recovery test
- Pre-v7.5.5.2 infra: run `validate-device.sh` on both devices, verify S3 uses its own sensor config, verify preflight catches bad ota_0
- v7.5.5.2: verify aggregator API endpoints, history proxy, heap after proxy
- v7.5.5.3: **requires TWO devices** — test satellite mode unchanged, test aggregator UI (gateway selector, settings panel, stale indicators, per-gateway view, board-correct About card)
- v7.5.5.4: Playwright only — no device testing
- v7.5.5.5: final verification, screenshot for record

### Phase 6 — Data Ingest and System Metrics ✅ COMPLETE

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.5.6.0 | POST /api/ingest endpoint | `prompts/phase6/v7.5.6.0-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-26 |
| v7.5.6.1 | System device category | `prompts/phase6/v7.5.6.1-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-26 |
| v7.5.6.2 | System card renderer | `prompts/phase6/v7.5.6.2-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-26 |
| v7.5.6.3 | Exporter scripts + docs | `prompts/phase6/v7.5.6.3-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-26 |
| v7.5.6.4 | Tests + Phase 6 closure | `prompts/phase6/v7.5.6.4-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-26 |

**Phase 6 device testing requirements:**
- v7.5.6.0: verify ingest endpoint with curl (200/404/400 cases), heap stable
- v7.5.6.1: full endpoint audit (sensors.json, api/status, api/v2/live, legacy history 404)
- v7.5.6.2: push test data via ingest, verify system card renders with usage bars
- v7.5.6.3: run bash/Python exporters from an external host, verify dashboard shows data
- v7.5.6.4: Playwright only + Phase 6 closure verification

### v7.5.7.0 — Aggregator Manifest Truncation Fix + PSRAM Scaling ✅ COMPLETE

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.5.7.0 | Manifest buffer increase, truncation guard, PSRAM-aware MAX_SATELLITES | `prompts/phase6/v7.5.7.0-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-28 |

**Reference:** [Issue #85](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/85) — resolved by PR #93

**v7.5.7.0 device testing requirements:**
- Compile and flash aggregator board (S3)
- Verify manifest buffer handles 5+ sensor satellites without truncation
- Verify AGGREGATOR_ENABLED=1 and MAX_SATELLITES=8 on S3, AGGREGATOR_ENABLED=0 on C3 (satellite only)
- Verify `/api/aggregator/gateways` emits valid JSON for all satellites
- Heap check after aggregator boot

### Phase D — Runtime Satellite Management (v7.6.0.x) ✅ COMPLETE

**Phase D delivered runtime satellite management — satellites can be added, removed, and tested via the dashboard UI at runtime, with no YAML editing or reflashing required.**

**Phase D results and summary:** `prompts/handoff/phaseD-results.md` — delivery record, API contracts, active lessons, delivery metrics, retrospective.

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.6.0.0 | NVS satellite persistence layer | `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-29 |
| v7.6.0.1 | POST /api/aggregator/add-satellite | `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-31 |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-04-02 |
| v7.6.0.3 | POST /api/aggregator/test-satellite | `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-04-02 |
| v7.6.0.4 | Dashboard add/remove/test UI (PR #126 + PR #128) | `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-04-03 |
| v7.6.0.5 | Playwright tests + Phase D closure | `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-04-04 |

**Phase D delivery summary (from `prompts/phaseD/phaseD-results.md`):**
- 7 new bugs discovered and fixed (BUG-075 through BUG-081)
- 402/0 tests across all four fixture sets (3sensor: 99, mixed: 96, system: 100, aggregator: 107)
- Every step required exactly 1 fixup PR or equivalent — ≤1 target met, never beaten
- New LESSON-OPS entries: 097–114 (see `Docs/bugs-and-lessons-learned.md`)
- New Critical Rules: 38–44 (all in the table below)
- Open Item OI-001: fix inaccurate parallelism comment in `tests/mock-server/server.js` lines 92–95 — first Phase 7 PR that touches `server.js` must resolve this

**Phase D device testing requirements (for reference):**
- v7.6.0.0: boot with NVS satellite list, reboot persistence, fallback to compile-time defaults
- v7.6.0.1: add satellite via API, verify polling starts, verify NVS persistence after reboot
- v7.6.0.2: remove satellite via API, verify polling stops, verify NVS updated, array dense after compaction
- v7.6.0.3: test-satellite probe returns manifest info, verify no side effects (no NVS write, satellite count unchanged)
- v7.6.0.4: full dashboard add/remove/test workflow via browser; verify async safety (no stale panel during poll)
- v7.6.0.5: Playwright + Phase D closure verification (all 4 fixture sets)

### Phase 7 — Per-Device Persistence Engine ⬅ NEXT

**`main` is at v7.6.0.5. Phase 7 starts at v7.7.0.0.**

Before starting Phase 7, read `prompts/handoff/phaseD-results.md` for the active lessons and API contracts that Phase 7 must remain compatible with. Also read `prompts/handoff/session-handoff-v7.7.0.0.md` for the full Phase 7 entry context.

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.7.0.0 | Per-device structs, key scheme, hash | `prompts/phase7/v7.7.0.0-implementation-instructions-for-coding-agent.md` | Pending |
| v7.7.0.1 | Per-device persist (write path) | `prompts/phase7/v7.7.0.1-implementation-instructions-for-coding-agent.md` | Pending |
| v7.7.0.2 | Per-device restore (boot) + retention budget | _Prompt not yet created_ | Pending |
| v7.7.0.3 | Wire new engine, storage-stats v2 | _Prompt not yet created_ | Pending |
| v7.7.1.0 | v7→v8 one-time migration | `prompts/phase7/v7.7.1.0-implementation-instructions-for-coding-agent.md` | Pending |
| v7.7.1.1 | Per-device delete API | _Prompt not yet created_ | Pending |
| v7.7.1.2 | Dashboard per-device storage UI | _Prompt not yet created_ | Pending |
| v7.7.2.0 | Per-device CSV export | _Prompt not yet created_ | Pending |
| v7.7.2.1 | Per-device CSV import (merge) | _Prompt not yet created_ | Pending |
| v7.7.2.2 | Multi-device bundle export/import | _Prompt not yet created_ | Pending |
| v7.7.2.3 | Full regression + Phase 7 closure | _Prompt not yet created_ | Pending |

**Note:** Phase 7 prompts for v7.7.0.2 through v7.7.2.3 are to be created during the post-Phase-D preparation session (see `prompts/handoff/session-prompt-post-phaseD-completion.md` Steps 4–6). They require the post-Phase-D codebase state to properly trace data paths and verify function names.

---

## Version Number ↔ Phase Mapping

| Phase | Version Range | Description | Implementation Plan |
|-------|--------------|-------------|---------------------|
| Phase 1 | v7.5.0.x | Manifest v2 endpoint | `Docs/v7.5-v7.6-architecture-plan.md` §11 |
| Phase 2 | v7.5.1.x | Dashboard consumes manifest | Same |
| Phase 3 | v7.5.3.x | SensorEntity C++ model | `Docs/phase3-implementation-plan.md` |
| Phase 4 | v7.5.4.x | First non-climate sensor (ping) | `Docs/phase4-implementation-plan.md` |
| Phase 5 | v7.5.5.x | Aggregator MVP | `Docs/phase5-implementation-plan.md` |
| Phase 6 | v7.5.6.x | Data ingest + system metrics | `Docs/phase6-implementation-plan.md` |
| **Phase D** | **v7.6.0.x** | **Runtime satellite management** | **`Docs/phase-d-implementation-plan.md`** |
| **Phase 7** | **v7.7.0.x–v7.7.2.x** | **Per-device persistence engine** | **`Docs/v7.7-v7.8-persistence-architecture.md`** |
| Phase E | v8.0.x | Captive portal + WiFi config | _Not yet planned_ |

---

## Critical Rules (Apply to Every Step)

These come from bugs and lessons learned and are baked into every prompt. They are listed here for reference — you do not need to add them to the prompt text; they are already in each prompt file.

| # | Rule | Source |
|---|------|--------|
| 1 | Use `::time(nullptr)` not `time(nullptr)` in ESPHome C++ | Project convention |
| 2 | Use `bash scripts/bump-version.sh <version>` for every version bump | All steps |
| 3 | Regenerate all artifacts after source changes | All steps |
| 4 | Run `bash scripts/preflight.sh` — must pass | All steps |
| 5 | Run full Playwright suite with CI-exact `FIXTURE_SET=` commands — bare `npx playwright test` is NOT sufficient | All steps (revised 2026-03-21) |
| 6 | Mirror all `dashboard.js` changes to `dashboard.html` | LESSON-OPS-043 |
| 7 | Never fire concurrent history requests from dashboard JS | LESSON-OPS-052 |
| 8 | Never use `beginResponseStream` for responses >10KB | LESSON-OPS-056 |
| 9 | Dashboard.h must be gzip-compressed | LESSON-OPS-055 |
| 10 | In-flight guards mandatory on interval-driven fetch functions | LESSON-OPS-050 |
| 11 | NVS scan loops must yield (`vTaskDelay` every N blobs) | LESSON-OPS-053 |
| 12 | `NUM_SENSORS` must alias `NUM_ENV_SENSORS`, never `NUM_DEVICES` | BUG-045 |
| 13 | Device testing sections must include full pull/compile/flash/verify workflow | LESSON-OPS-058 |
| 14 | Specified tests/checks must be tracked to implementation completion | LESSON-OPS-057 |
| 15 | Adding a new device category requires an endpoint audit of ALL existing endpoints | LESSON-OPS-064 |
| 16 | Native browser widgets need `color-scheme` CSS property for dark/light mode | LESSON-OPS-065 |
| 17 | Build pipeline intermediate artifacts must be re-derived on version bumps | LESSON-OPS-066 |
| 18 | Adding a new fixture variant requires a MANDATORY full-suite audit under that variant | BUG-051 / LESSON-OPS-063 |
| 19 | Expanding a shared array (SENSORS) requires auditing ALL index-based consumers | BUG-056 |
| 20 | Every step must produce a session log as a MANDATORY deliverable | Phase 4 review finding |
| 21 | Every step must produce an Instruction Compliance Output table in the PR | Phase 4 review finding |
| 22 | All partition tables must have `ota_0` at `0x10000` — verify before flashing | LESSON-OPS-070 / BUG-061 |
| 23 | Module-level imports for optional deps (e.g. `yaml`) must be lazy (inside the function that needs them) | LESSON-OPS-071 / BUG-060 |
| 24 | `esp_get_free_heap_size()` includes PSRAM — report both internal and total heap separately | LESSON-OPS-072 / BUG-062 |
| 25 | LXC USB passthrough loses permissions on device reconnect — use udev rules or flash from host | LESSON-OPS-073 |
| 26 | Aggregator boot must be a superset of satellite boot, never a fork — unified pipeline + overlay | LESSON-OPS-074 / BUG-064 |
| 27 | ESPHome IDF socket calls must use `lwip_*` prefixed functions, not BSD socket aliases | LESSON-OPS-068 / BUG-057 |
| 28 | Version bumps require BOTH `render_sensor_config.py --write` AND `node tests/fixtures/generate-fixtures.js`, then verify with `--check` and `grep free_heap tests/fixtures/api-status.json` | LESSON-OPS-077 / BUG-062 |
| 29 | Prompt-provided code blocks must be reviewed as production code before prompt publication | LESSON-OPS-084 / Phase 6 audit |
| 30 | Mock endpoints must mirror all firmware validation branches — stub-level mocking prohibited | LESSON-OPS-081 |
| 31 | Fixture composition changes require downstream text audit (skip reasons, comments, helpers) | LESSON-OPS-082 |
| 32 | Playwright test signatures must only destructure used fixtures | LESSON-OPS-083 |
| 33 | Unsupported-platform stub functions must return the documented safe default (usually `0.0`) | Phase 6.3 audit finding |
| 34 | Shell scripts with locale-sensitive commands must use `LC_ALL=C` | Phase 6.3 audit finding |
| 35 | Python network/file resources must use context managers (`with`) in long-running modes | Phase 6.3 audit finding |
| 36 | Device testing firmware commands must reference the GENERATED YAML for the target board — never use the committed C3 template (`esp32-c3-multi-sensor.yaml`) for non-C3 boards. Generated YAMLs are gitignored and only exist after `render_sensor_config.py --write`. | LESSON-OPS-090 |
| 37 | Regeneration pipeline must include `minify-dashboard.sh` before `generate-header.sh`. Full pipeline: `render_sensor_config.py --write` → `generate-fixtures.js` → `minify-dashboard.sh` → `generate-header.sh` → `render_sensor_config.py --check` | LESSON-OPS-091 |
| 38 | All dashboard `fetch()` POST calls must use `Content-Type: application/x-www-form-urlencoded` with `body: \'a=1\'`. ESPHome does not consume JSON POST bodies. | BUG-076 / LESSON-OPS-099 |
| 39 | All `curl` POST commands must use `-d \'a=1\'`. Never use `-H "Content-Type: application/json"`, never use `-d \'\'`, never use bare `-X POST` without a body. | BUG-076 / LESSON-OPS-099 |
| 40 | Any HTTP handler performing NVS operations must use the deferred task pattern (`xTaskCreate`, 8192+ byte stack). Never perform NVS work synchronously in an HTTP handler. | BUG-075 / LESSON-OPS-100/101 |
| 41 | Never add `CONFIG_HTTPD_STACK_SIZE` to any board profile `sdkconfig_options` in `firmware/boards/*.yaml` or in generated board YAMLs. It has zero runtime effect — ESPHome hardcodes the httpd task stack at 4 KB and ignores this setting. The legacy `firmware/esp32-c3-multi-sensor.yaml` template is exempt from this rule. | BUG-075 / LESSON-OPS-100 |
| 42 | All board profiles must include an `external_components` block referencing `firmware/local_components` for the patched `web_server_idf` component. Without this, the httpd task runs at 4 KB and all POST handlers crash. Run `scripts/patch-esphome-httpd-stack.sh --check` to verify. | BUG-075 / LESSON-OPS-102 |
| 43 | After re-running `scripts/patch-esphome-httpd-stack.sh` (ESPHome upgrade), verify that `init_response_()` in the local component still contains the expanded HTTP status code switch with `snprintf` fallback. The patch script only applies the stack size line — the status code fix must be preserved manually. | BUG-078 / LESSON-OPS-103 |
| 44 | Never use Arduino `String` (capital S) or bare `string` in ESP-IDF code. Always use `std::string`. The coding agent\'s CI does not perform ESP-IDF compilation — Arduino-isms pass CI but break the real build. Treat `String` in agent-generated code as a PR review red flag. | BUG-077 / LESSON-OPS-104 |
| 45 | DOM references captured before an async auth flow (`requestManagementCredentials()`) become stale if `pollAggregatorLive()` fires during the wait and rebuilds `innerHTML`. Always re-query stable `id` nodes AFTER async boundaries. Suppress poll-driven rerenders while any action flag is true or while a management input has focus. | BUG-080/081 / LESSON-OPS-111 |
| 46 | Mock server response shapes must be verified against the live firmware `httpd_resp_sendstr()` call — not the prompt description, not an audit table, not a prior session summary. The firmware contract is the single source of truth. | LESSON-OPS-112 |

---

## Prompt File Naming Convention

Each step has exactly one prompt file:

```
prompts/<phase>/<version>-implementation-instructions-for-coding-agent.md
```

Examples:
- `prompts/phase4/v7.5.4.1-implementation-instructions-for-coding-agent.md`
- `prompts/phase5/v7.5.5.3-implementation-instructions-for-coding-agent.md`
- `prompts/phase6/v7.5.6.0-implementation-instructions-for-coding-agent.md`
- `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md`
- `prompts/phase7/v7.7.0.0-implementation-instructions-for-coding-agent.md`

Phase 3 prompts (`prompts/phase3/`) are retained for historical reference but all Phase 3 steps are complete.

---

## Files Superseded by This Document

The following files are obsolete and should be deleted:

| File | Reason |
|------|--------|
| `prompts/phase3-prompt-templates.md` | Replaced by this document |
| `prompts/phase3-prompt-templates-updated.md` | Replaced by this document |
| `prompts/prompt-update-summary.md` | Replaced by this document |

Additionally, the original (non-expanded) prompt files in `prompts/phase4/` are superseded by the `-for-coding-agent.md` versions:

| Superseded File | Replaced By |
|----------------|-------------|
| `prompts/phase4/v7.5.4.0-implementation-instructions.md` | Step already complete — retained for reference |
| `prompts/phase4/v7.5.4.1-implementation-instructions.md` | `v7.5.4.1-implementation-instructions-for-coding-agent.md` |
| `prompts/phase4/v7.5.4.2-implementation-instructions.md` | `v7.5.4.2-implementation-instructions-for-coding-agent.md` |
| `prompts/phase4/v7.5.4.3-implementation-instructions.md` | `v7.5.4.3-implementation-instructions-for-coding-agent.md` |
| `prompts/phase4/v7.5.4.4-implementation-instructions.md` | `v7.5.4.4-implementation-instructions-for-coding-agent.md` |

---

## Maintaining This Document

After each step completes:

1. Update the Step Index: change the completed step to `✅ Complete` with date
2. If the step revealed new critical rules, add them to the Critical Rules table
3. If the step required prompt changes to subsequent steps, note those changes and update the affected files (see `Docs/writing-prompts-for-coding-agents-guide.md` Section 11 for the audit methodology)
4. Verify the session log was created by the agent — if missing, create it manually before moving to the next step

---

## Revision History

### 2026-04-04 — Phase D Complete; Critical Rules 45–46 Added; Phase D Results Document Produced

**Context:** Phase D (v7.6.0.0–v7.6.0.5) fully merged and verified. Post-Phase-D documentation session. Document restored from truncated commit state and updated to reflect Phase D closure.

| Change | Why |
|--------|-----|
| **Phase D steps v7.6.0.3–v7.6.0.5 marked complete** | All six steps confirmed shipped; 402/0 tests green across all four fixture sets |
| **Phase D COMPLETE banner added to Step Index** | Phase D is closed; Phase 7 is now the active next milestone |
| **`prompts/handoff/phaseD-results.md` added to Related Documents** | New canonical Phase D delivery record; Phase 7 prompts must read this before authoring |
| **Phase D delivery summary added to Step Index** | Quick-reference for operator: bug count, test count, fixup rate, open items |
| **Open Item OI-001 noted** | Inaccurate parallelism comment in `server.js` lines 92–95; must be fixed in first Phase 7 PR touching that file |
| **Critical Rule 45 added** | BUG-080/081 / LESSON-OPS-111: DOM staleness after async auth flows — re-query after `await`, suppress poll rerenders during in-flight actions |
| **Critical Rule 46 added** | LESSON-OPS-112: mock response shapes verified against firmware `httpd_resp_sendstr()` — not prompt descriptions |
| **Phase 7 ⬅ NEXT marker added** | Operator orientation: main is at v7.6.0.5, next step is v7.7.0.0 |
| **`<phase>` fill-in hint updated** | Added `phaseD` example to workflow template for completeness |
| **Document header `_Last updated_` refreshed** | Reflects current session date and closure state |

### 2026-04-02 — v7.6.0.2 Complete; Critical Rules 43–44 Added

| Change | Why |
|--------|-----|
| **v7.6.0.2 marked complete** | PR #114 + #116 merged 2026-04-02 |
| **Critical Rules 43–44 added** | BUG-077 (Arduino `String`), BUG-078 (`init_response_()` status code mapping), BUG-079 (`HTTP_DELETE` not registered in `begin()`) |

### 2026-03-31 — BUG-075/076 Root Cause Resolved; Critical Rules 38–42 Added

**Context:** PR #105 branch — dashboard content-type fixes, generated file regeneration, documentation updates.

| Change | Why |
|--------|-----|
| **Critical Rules 38–42 added** | httpd stack hardcoded at 4 KB by ESPHome — CONFIG_HTTPD_STACK_SIZE inert. Local component override (`firmware/local_components/web_server_idf/`) patches stack to 16 KB. Deferred task pattern required for NVS handlers. ESPHome only supports form-urlencoded POST. |
| **BUG-075/076 root cause resolved** | httpd task stack hardcoded at 4 KB by ESPHome; deferred task pattern (xTaskCreate 8192-byte stack) applied to management handlers |
| **dashboard.js / dashboard.html content-type fixed** | Changed from `application/json` to `application/x-www-form-urlencoded`; `body: \'{}\'` → `body: \'a=1\'` |
| **LESSON-OPS-099–101 added** | ESPHome POST body consumption rules; httpd stack limit; deferred task pattern |

### 2026-03-29 — v7.6.0.0 Complete (Phase D Step 0)

**Context:** v7.6.0.0 merged (PR #98 + review fixes PR #99). NVS satellite persistence layer operational. Device testing fix applied to all Phase D prompts.

| Change | Why |
|--------|-----|
| **v7.6.0.0 marked complete** | PR #98 merged with review fixes from PR #99 |
| **v7.6.0.1 prompt updated** | Back-ported 5 findings from v7.6.0.0 review (mutex, NVS seeding, key buffers, auth pattern, erase semantics) — Section 3a added |
| **All Phase D device testing sections fixed** | All 6 prompts referenced wrong YAML (`esp32-c3-multi-sensor.yaml` instead of `esp32-s3-devkitc1-n16r8-gw.yaml`) — LESSON-OPS-090 |
| **Regeneration pipeline completed** | `minify-dashboard.sh` added to all pipeline references — LESSON-OPS-091 |
| **Critical Rules 36–37 added** | Rule 36 (correct YAML path), Rule 37 (full pipeline with minification) |
| **`render_sensor_config.py` enhancement** | Prints build target/commands after `--write` to prevent YAML path confusion |
| **LESSON-OPS-090–096** | 7 new lessons from v7.6.0.0 execution and review |
| **`Docs/aggregator-setup.md` rewritten Section 7** | Added "Which YAML Do I Compile?" decision table, complete 5-step pipeline |

### 2026-03-28 — Post-v7.5.7.0 Completion and Phase D Readiness

**Context:** v7.5.7.0 merged (PR #93). Phase D prompts finalized and corrections applied.

| Change | Why |
|--------|-----|
| **v7.5.7.0 marked complete** | PR #93 merged 2026-03-28T21:19:35Z |
| **Phase D prompt files linked** | Canonical prompts exist in `prompts/phaseD/`, replacing "_Prompt not yet created_" placeholders |
| **v7.5.7.0 audit corrections applied to Phase D prompts** | LESSON-OPS-086 (Do-NOT regeneration churn), LESSON-OPS-087 (cross-language constants), LESSON-OPS-088 (compliance table templating) |
| **Device testing sections expanded** | Specific build/flash commands, `esphome clean` requirement, preflight steps, concrete device IPs |
| **`curl -X POST` commands fixed** | Added `-H "Content-Length: 0"` — curl does not send POST without it |

### 2026-03-27 — Post-Phase-6 Completion Update

**Context:** Phase 6 complete (v7.5.6.4). Post-phase documentation batch merged. Phase D preparation underway.

| Change | Why |
|--------|-----|
| **Phase 6 steps v7.5.6.2–6.4 marked complete** | Workflow index was stale — steps had been merged but not reflected |
| **v7.5.7.0 added to index** | Manifest truncation fix (Issue #85) must ship before Phase D |
| **Critical rules 29–35 added** | Phase 6 audit identified 7 new rules for prompt quality, mock fidelity, fixture ripple, script quality |
| **Architecture Forward-Looking Notes added to Related Documents** | New document created during Phase 6 assessment |
| **Phase 7 prompts reviewed and updated** | Checked against updated writing guide (§3.12, §3.13) |

### 2026-03-24 — Architecture Review Revision

**Context:** Comprehensive repo analysis after multi-board infrastructure push. User design principles reviewed. Architecture revision document produced.

| Change | Why |
|--------|-----|
| **Infrastructure step added to Phase 5 index** | Config separation, ota_0 preflight, validate-device.sh, PR66 Codex fixes, BUG-062 must be done before v7.5.5.2 |
| **v7.5.5.3 scope expanded** | User principles require dashboard-first configuration. Settings panel groundwork (read-only satellite list, stubbed management API) included to avoid dashboard rework later. |
| **Critical rules 22–25 added** | LESSON-OPS-070 (ota_0), LESSON-OPS-071 (lazy imports), LESSON-OPS-072 (heap PSRAM), LESSON-OPS-073 (LXC USB) |
| **Multi-board infrastructure step marked complete** | PR #66 + BUG-060/061 follow-up fixes |
| **Device testing requirements updated** | Pre-v7.5.5.2 infra step needs validate-device.sh testing; v7.5.5.3 needs settings panel and board About card testing |

### 2026-03-21 — Post-Phase-4 Review Revision

**Context:** Comprehensive post-Phase-4 review identified 5 bugs (BUG-052 through BUG-056) and multiple prompt quality gaps. Four independent third-party analyses (GP, GE, Codex, SO) reviewed the Phase 4 prompt set and implementation quality.

| Change | Why |
|--------|-----|
| **Phase 5 prompts revised (all 6 files)** | SO analysis identified 18 gaps. Critical fixes: CI-exact pre-conditions, FreeRTOS mutex for shared cache, pointer lifetime clarification, `_aggregatorReady` signal, MANDATORY existing-test audit, `waitForAggregatorReady()` helper, URL collision check, preflight updates, mock server 404, Closure Gate. |
| **Phase 6 prompts created (5 new files)** | Created from scratch incorporating all Phase 4 lessons: endpoint audit checklist, `chartIdx` verification, `NUM_SENSORS` protection, test group guardrails, MANDATORY fixture audit, CI matrix instructions. |
| **Phase 7 prompts updated (3 files)** | CI-exact pre-conditions, session log mandate, Instruction Compliance Output. 8 remaining prompts to be created when implementation begins. |
| **Writing guide updated (1115 lines)** | 3 new gap categories (11-13), Section 13 with 5 case studies, expanded Appendix B. |
| **Session log mandate added to ALL prompts** | Phase 4 produced zero session logs. Now a MANDATORY deliverable in every prompt. |
| **Instruction Compliance Output added to ALL prompts** | Prevents PR-057 class deviation where agents implement differently than specified. |
| **Validation Evidence added to test-step prompts** | Exact command + pass/fail/skip counts required as proof of CI-exact execution. |
| **Step Index expanded** | v7.5.4.5, Phase 6, expanded Phase 7 with "prompt not yet created" status. |
| **Critical Rules expanded (15→21)** | Rules 15-21 from LESSON-OPS-064/065/066, BUG-051/056, and review findings. |
| **Workflow updated** | Agent deliverables now include session log, compliance output, validation evidence. |

### 2026-03-18 — Initial Version

Created to replace three overlapping prompt management documents. Consolidated Phase 3, Phase 4, and Phase 5 step indices into a single workflow document.

---

_End of document._
