# Session Handoff — v7.6.0.0: Phase D Start — Runtime Satellite Management (v7.6.0.x)

_Date: 2026-03-28_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Assumption: v7.5.7.0 has been implemented, tested, and merged to `main`_

---

## Project State Summary

**v7.5.7.0** is the current version on `main`. **Phase 6 is COMPLETE. v7.5.7.0 (bridge step) is COMPLETE.**

### What v7.5.7.0 delivered

- `AGG_MANIFEST_BUF_SIZE = 8192` — manifest buffer doubled, named constant replaces magic number
- `s_fetch_tmp` increased to 8192 to match manifest buffer
- Truncation detection guard in `handle_aggregator_gateways_()` — truncated manifests emit `"manifest":null` with warning log
- PSRAM-aware aggregator gating in `render_sensor_config.py`: no PSRAM → `AGGREGATOR_ENABLED 0` (satellite only), PSRAM → up to 8 satellites
- `#define AGG_MANIFEST_BUF_SIZE 8192` emitted in generated `aggregator_config.h`
- BUG-074 and LESSON-OPS-085 documented
- `Docs/aggregator-setup.md` updated with buffer sizes and PSRAM scaling rules
- **Fixup commit (`4336f33`) — PR #93 audit corrections:**
  - Heading hierarchy fixed in `Docs/aggregator-setup.md` (`## 2.1)` → `### 2.1)`)
  - Magic numbers extracted to `SATELLITE_CAP_PSRAM = 8` and `AGG_MANIFEST_BUF_SIZE_BYTES = 8192` module-level constants in `render_sensor_config.py`
  - Instruction Compliance Output table (16 rows) added to session log

**PR #93 merged 2026-03-28. 5 commits, 28 files changed.**

### Cumulative state entering Phase D

| Phase | Version Range | Status |
|-------|--------------|--------|
| Phase 1–3 | v7.5.0.x–v7.5.3.x | ✅ Complete |
| Phase 4 | v7.5.4.x | ✅ Complete |
| Phase 5 | v7.5.5.x | ✅ Complete |
| Phase 6 | v7.5.6.x | ✅ Complete |
| v7.5.7.0 | Bridge step | ✅ Complete |
| **Phase D** | **v7.6.0.x** | **⬅️ Starting** |

### Key infrastructure that Phase D builds on

- **`SatelliteCache` struct** — static array of `MAX_SATELLITES` entries with manifest/live/status JSON buffers, health tracking, and mutex protection
- **Inline init loop in `aggregator_poll_task()`** — currently copies compile-time arrays (`SATELLITE_IDS[]`, `SATELLITE_NAMES[]`, etc.) into `satellite_caches[]`. Phase D v7.6.0.0 replaces this with `init_satellite_caches_()` that tries NVS first.
- **Stub endpoints** — `POST /api/aggregator/add-satellite`, `DELETE /api/aggregator/satellite/{id}`, `POST /api/aggregator/test-satellite` all return 501 today. Phase D v7.6.0.1–v7.6.0.3 replace these with working implementations.
- **Dashboard Settings panel** — read-only display of satellite list. Phase D v7.6.0.4 adds add/remove/test controls.
- **`MAX_SATELLITES`** — compile-time constant. After v7.5.7.0, boards without PSRAM get `AGGREGATOR_ENABLED 0` (satellite only). PSRAM boards get up to 8 satellites capped by `SATELLITE_CAP_PSRAM = 8`. Phase D introduces `runtime_satellite_count` to track actual count at runtime while `MAX_SATELLITES` remains the array sizing upper bound.
- **Aggregator mutex** — `s_cache_mutex` protects all `satellite_caches[]` reads/writes. Phase D NVS operations and API handlers must acquire this mutex.
- **`generate_aggregator_config_h()`** — as of v7.5.7.0: accepts a `board_profile` parameter; for PSRAM boards caps `MAX_SATELLITES` at `SATELLITE_CAP_PSRAM = 8`; emits `#define AGG_MANIFEST_BUF_SIZE 8192` using `AGG_MANIFEST_BUF_SIZE_BYTES`. **Do NOT change this function during Phase D.**

---

## Pre-Phase-D Checklist

Before starting v7.6.0.0:

- [x] v7.5.7.0 merged to main and tagged — merged 2026-03-28T21:19:35Z
- [x] Device testing completed:
  - [x] S3 aggregator compiles and boots with `MAX_SATELLITES` ≤ 8
  - [x] `/api/aggregator/gateways` returns valid JSON
  - [x] Heap values recorded (internal + total)
  - [x] WROOM-32D satellite at .190 updated to v7.5.7.0
- [x] All Playwright fixture sets passing:
  ```bash
  FIXTURE_SET=3sensor npx playwright test --project=chromium
  FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium
  FIXTURE_SET=system npx playwright test --grep "System Devices" --project=chromium
  FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
  bash scripts/preflight.sh
  python3 scripts/render_sensor_config.py --check
  ```

### Pre-Phase-D Housekeeping PRs
PR #96: fixed hardcoded sensor_count in preflight.sh (dynamic computation)
PR #97: documented LESSON-OPS-089
PR #96 must be merged before v7.6.0.0 starts (otherwise preflight fails on S3 profile) - merged

---

## Phase D Step Index

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.6.0.0 | NVS satellite persistence layer + runtime loop migration | `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md` | Pending |
| v7.6.0.1 | POST /api/aggregator/add-satellite | `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md` | Pending |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md` | Pending |
| v7.6.0.3 | POST /api/aggregator/test-satellite | `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md` | Pending |
| v7.6.0.4 | Dashboard add/remove/test UI | `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent.md` | Pending |
| v7.6.0.5 | Playwright tests + Phase D closure | `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent.md` | Pending |

**Note:** Superseded drafts (base, updated, CL variants) and the comparison report have been archived. The canonical prompts above are the execution set — they are the detailed CL variants renamed to the standard naming convention.

---

## What to Read Before v7.6.0.0

1. `Docs/phase-d-implementation-plan.md` — the Phase D plan. Covers NVS storage design, key scheme (`agg_sats` namespace, `s0_id`/`s0_name`/`s0_url`/`s0_poll` pattern), boot sequence, API contracts for all three endpoints.
2. `Docs/architecture-forward-looking-notes.md` — Section 1 (PSRAM aggregator restriction), Section 2 (manifest serving separation), Section 4 (NVS compaction risk).
3. `Docs/aggregator-setup.md` — updated in v7.5.7.0 with buffer sizes and PSRAM scaling rules.
4. `prompts/prompt-index-and-workflow.md` — all 35 critical rules. Phase D prompts reference them.
5. `Docs/writing-prompts-for-coding-agents-guide.md` — especially §3.12 (mock contract fidelity) for the new API endpoints, and §3.13 (code quality gates).
6. `Docs/bugs-and-lessons-learned.md` — ALL entries. For Phase D:
   - BUG-043 (NVS scan yielding) — NVS loops must yield
   - BUG-048 (blob size mismatch) — NVS read failures must be handled gracefully
   - BUG-074 (manifest truncation) — the bug v7.5.7.0 fixed; informs buffer sizing decisions
   - LESSON-OPS-053 (NVS handles must close on every path)
   - LESSON-OPS-074 (aggregator boot = satellite + overlay)
   - LESSON-OPS-086 (Do-NOT lists must exclude expected regeneration churn)
   - LESSON-OPS-087 (cross-language constant consistency in prompt code)
   - LESSON-OPS-088 (compliance tables need placeholder rows)
7. `dashboard/sensor_history_multi.h` — the main file. Key locations:
   - `SatelliteCache` struct (~line 1371)
   - Inline init loop in `aggregator_poll_task()` (~line 1545) — the code v7.6.0.0 replaces with `init_satellite_caches_()`
   - `aggregator_poll_task()` — the polling loop that uses `MAX_SATELLITES` (will change to `runtime_satellite_count`)
   - Stub endpoints (~line 3270+): `handle_add_satellite_()`, `handle_remove_satellite_()`, `handle_test_satellite_()`
   - All `for (int i = 0; i < MAX_SATELLITES; i++)` loops — v7.6.0.0 changes these to `runtime_satellite_count`

---

## Key Design Decisions for Phase D

These are settled — do not revisit during implementation:

1. **`runtime_satellite_count` replaces `MAX_SATELLITES` in loop bounds.** `MAX_SATELLITES` remains the compile-time array size. `runtime_satellite_count` tracks the actual active count. Set at boot from NVS (or compile-time fallback), incremented/decremented by add/remove APIs.

2. **NVS namespace `"agg_sats"`.** Separate from the history namespace. Keys: `count` (u8), `s{i}_id` (str), `s{i}_name` (str), `s{i}_url` (str), `s{i}_poll` (u16).

3. **Compile-time fallback on first boot.** If `count` key is absent from NVS, populate from `SATELLITE_IDS[]` / `SATELLITE_NAMES[]` / `SATELLITE_URLS[]` / `SATELLITE_POLL_INTERVALS[]` and write to NVS. This makes the first boot seamless.

4. **Add-satellite uses query parameters** (not JSON body). Contract: `POST /api/aggregator/add-satellite?url=...&name=...&poll=30`. This is consistent with `/api/ingest` and avoids the `handleBody()` limitation on ESPHome's AsyncWebServer.

5. **Test-satellite probes `/api/manifest`** at the candidate URL and returns the parsed manifest to the caller. No side effects — does not add the satellite.

6. **Remove-satellite by ID** (not by index). `DELETE /api/aggregator/satellite/{id}`. Compacts the array to avoid gaps.

7. **`POST /api/system/reset-satellites`** — resets NVS satellite list to compile-time defaults. This is the escape hatch if NVS becomes corrupted.

---

## Phase 6 and v7.5.7.0 Lessons Relevant to Phase D

| Lesson | Relevance to Phase D |
|--------|---------------------|
| LESSON-OPS-081 (mock contract fidelity) | Phase D adds 3 new API endpoints (add, remove, test). Each needs a full contract-lock in the prompt and contract-faithful mocks. |
| LESSON-OPS-082 (fixture composition ripple) | Phase D changes the aggregator fixture when `runtime_satellite_count` is introduced. Downstream text (test descriptions, skip reasons) must be audited. |
| Rule 29 (prompt code = production code) | Phase D prompts contain C++ code blocks. They have been reviewed but verify during execution. |
| Rule 30 (no stub-level mocking) | Mock endpoints for add/remove/test must mirror all firmware validation branches. |
| LESSON-OPS-074 (aggregator boot = satellite + overlay) | The NVS satellite loading in v7.6.0.0 is an extension of the boot overlay pattern. It must not break the satellite boot path. |
| LESSON-OPS-086 (Do-NOT regeneration exclusion) | Phase D prompts qualify "no dashboard changes" to exclude version bump churn. Applied in 2026-03-28 revision. |
| LESSON-OPS-087 (cross-language constant policy) | Phase D prompts with Python code blocks must use named constants, not bare literals. |
| LESSON-OPS-088 (compliance table templating) | v7.6.0.0 prompt now includes placeholder rows in the compliance table. |

---

## Device Testing Resources

Phase D requires two devices throughout:

- **S3 aggregator** (ESP32-S3-DevKitC-1 at 192.168.120.191, PSRAM-equipped, runs aggregator firmware with `config/aggregator.json`)
- **C3 satellite** (ESP32-C3 SuperMini at 192.168.120.189, reachable from aggregator over network)
- **WROOM-32D satellite** (ESP32-WROOM-32D at 192.168.120.190, running v7.5.7.0, reachable from aggregator over network)

Device testing highlights per step:
- **v7.6.0.0:** Boot with NVS satellites, reboot and verify persistence, clear NVS and verify compile-time fallback
- **v7.6.0.1:** Add satellite via API, verify polling starts, verify NVS persistence across reboot
- **v7.6.0.2:** Remove satellite via API, verify polling stops, verify NVS updated
- **v7.6.0.3:** Test-satellite probe, verify no side effects (satellite not added)
- **v7.6.0.4:** Full browser test of dashboard add/remove/test workflow
- **v7.6.0.5:** Playwright regression + Phase D closure verification

---

## Workflow for v7.6.0.0

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for clarification.**

1. Ask human if PR for v7.6.0.0 has been opened and ask to provide the PR number
2. If PR has not been opened, **Open a NEW coding agent session outside of this chat** and paste the prompt from `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md`
3. Wait for the agent to create the PR
4. Copilot PR reviewer reviews automatically and additional reviews might be posted
5. Human reviews PR against the Review Checklist in the prompt
6. Fix any issues
7. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
8. Provide to human all the necessary instructions to run tests. **IMPORTANT**: if as a result of the PR testing, the testing section in `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md` needs to be updated, provide updated section.
9. Provide instructions after merging PR to Main with tagging and pushing the tag

---

## Post-PR Closure Deliverables (for v7.6.0.0)

After the v7.6.0.0 PR is merged, produce these documents:

### 1. Session Handoff Document
**Format:** Same as this document. Must include:
- Project state summary with v7.6.0.0 changes
- Phase D progress (v7.6.0.0 complete, v7.6.0.1 next)
- v7.6.0.1 scope: add satellite via API, verify polling starts, NVS persistence across reboot
- Pre-merge checklist for v7.6.0.1
- Workflow and Post-PR Closure sections for v7.6.0.1
- Lessons learned from v7.6.0.0

**File:** `prompts/handoff/session-handoff-v7.6.0.1.md`

### 2. PR and Prompt Audit Document

**⚠️ IMPORTANT: the PR and Prompt Audit Document must include answers to these questions:**

- Did the coding agent deliver properly and accurately what was required from the prompt? How is the execution quality?
- Did the codebase state at execution time match the prompt's assumptions? If function signatures, line numbers, or struct layouts had drifted from what the prompt described, how did the agent handle the delta — did it reconcile correctly or silently diverge?
- What implementation decisions did the agent make that were NOT specified in the prompt? Were those decisions correct? Should any of them be back-ported as explicit requirements into the prompt for reproducibility?
- If the coding agent did not execute properly what was required, then: why it happened and what caused it?
- Coding agent's prompt audit: was the prompt created according to the `Docs/writing-prompts-for-coding-agents-guide.md` guideline document, and if not, where was the deviation?
- If there were failures, how to prevent such failures by coding agents in future?
- Code reviews: are the changes/information mentioned in the PR comments/code audits warranted? Create list of PR comments and conclusion if changes warranted or not and why.

**File:** `prompts/phaseD/v7.6.0.0-PR<NN>-consolidated-audit-and-lessons.md`
**Format:** Same as `prompts/phase6/v7.5.7.0-PR93-consolidated-audit-and-lessons.md`

### 3. Updated Prompt Corrections (if needed)
If the v7.6.0.0 prompt audit reveals defects in subsequent Phase D prompts, produce correction text and apply to `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md` and beyond.

### 4. Updated prompt-index-and-workflow.md
Mark v7.6.0.0 as complete with date in the Step Index.

---

## Post-Phase-D Roadmap

After Phase D completes (v7.6.0.5 merged):
1. **Phase 7** (v7.7.0.x–v7.7.2.x) — Per-device persistence engine. Prompts exist for v7.7.0.0, v7.7.0.1, v7.7.1.0.
2. **Phase E** (v8.0.x) — Captive portal + WiFi config. Not yet planned.

---

_End of session handoff document._
