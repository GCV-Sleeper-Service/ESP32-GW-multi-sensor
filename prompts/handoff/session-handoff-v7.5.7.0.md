# Session Handoff — v7.5.7.0: Aggregator Manifest Truncation Fix + PSRAM-Aware Scaling

_Date: 2026-03-27_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_

---

## Project State Summary

**v7.5.6.4** is the current version on `main`. **Phase 6 is COMPLETE.**

Key changes in v7.5.6.4 (PR #87):
- Created `system` fixture variant (`tests/fixtures/variants/system/`) with 2 env + 1 network + 1 system = 4 sensors
- Updated `mixed` fixture to include `nas01` (LESSON-OPS-079 compliance)
- Added Playwright Group 20: System Devices and Data Ingest (8 tests)
- Extended mock server with contract-faithful `/api/ingest` route (device + metric + val validation)
- BUG-072 fix: `last_seen` null-safe check (`!= null`) in `updateNetworkCards()`
- BUG-073 fix: `escHtml()` applied to `target` in `buildNetworkCard()`
- CI matrix updated with `system` fixture set and Group 20 step
- Phase 6 closure documentation complete (architecture plan, phase plan, changelog)
- Version bumped to 7.5.6.4 across all locations
- Full regeneration pipeline (Critical Rule 28) executed

Cumulative Phase 6 delivered:
- v7.5.6.0: `POST /api/ingest/{device_id}/{metric_key}?val={float}` endpoint ✅
- v7.5.6.1: `nas01` system device in manifest, `external_push` adapter ✅
- v7.5.6.2: System card renderer with usage bars, satellite + aggregator support ✅
- v7.5.6.3: Example exporter scripts + comprehensive documentation ✅
- v7.5.6.4: Test fixtures + Playwright + Phase 6 closure ✅

---

## Pre-merge Checklist

Before starting v7.5.7.0:

- [ ] PR #87 merged to main ✅ (merged 2026-03-26T20:47:41Z)
- [ ] Tag created: `git tag -a v7.5.6.4 -m "Phase 6 Complete: Data ingest and system metrics"`
- [ ] Tag pushed: `git push origin v7.5.6.4`
- [ ] Local Playwright validation passed (3sensor, mixed, system, aggregator):
  ```bash
  FIXTURE_SET=3sensor npx playwright test --project=chromium
  FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium
  FIXTURE_SET=system npx playwright test --grep "System" --project=chromium
  FIXTURE_SET=system npx playwright test --project=chromium  # FULL, no grep
  FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
  ```
- [ ] Device test completed:
  ```bash
  # On a Linux host (NAS, Pi, etc.):
  bash scripts/exporters/system-metrics-exporter.sh http://192.168.120.189 nas01
  python3 scripts/exporters/system-metrics-exporter.py --gateway http://192.168.120.189 --device nas01
  # Verify dashboard shows real values on system card
  ```

---

## What to Read Before v7.5.7.0

1. `Docs/v7.5-v7.6-architecture-plan.md` — main architecture (Phases 1-6)
3. `Docs/phase6-implementation-plan.md` — Phase 6 (Data Ingest)
4. `Docs/bugs-and-lessons-learned.md` —  ALL entries, BUG-071 - Truncation root cause, BUG-057 through BUG-069 and LESSON-OPS-068 through LESSON-OPS-074
5. `Docs/changelog.md` — all Phase 6 entries 
6. All session logs from the most recent steps (check Docs/ for session-log-* files) — the v7.5.6.x session logs
7. `Docs/aggregator-satellite-gateway-principles.txt` — forward looking plan and user design principles
8. `Docs/phase-d-implementation-plan.md` — next phase implementation plan
9. `prompts/prompt-index-and-workflow.md` — step index and critical rules (35 rules)
10. Prompt audit for phase6 reports in prompts/phase6/ - `v7.5.6.0-PR80-consolidated-audit-and-lessons.md`, `v7.5.6.1-PR82-consolidated-audit-and-lessons.md`, `v7.5.6.2-PR83-consolidated-audit-and-lessons.md`, `v7.5.6.3-PR84-consolidated-audit-and-lessons.md`, `v7.5.6.4-PR87-consolidated-audit-and-lessons.md`
11. prompts/handoff/session-handoff* - session handoff files for phase6
12. `writing-prompts-for-coding-agents-guide.md` - master document how to write prompts for coding agents
13. `Docs/v7.7-implementation-plan.md` 
14. `Docs/v7.7-v7.8-persistence-architecture.md`
15. `prompts/v7.5.7.0-implementation-instructions-for-coding-agent.md` - the coding agent's prompt to implement v7.5.7.0


## Phase Progress

| Step | Version | Scope | Status |
|------|---------|-------|--------|
| Phase 6 | v7.5.6.0–v7.5.6.4 | Data ingest + system metrics | ✅ COMPLETE |
| **Next** | **v7.5.7.0** | **Aggregator manifest truncation fix + PSRAM scaling** | **⬅️ Next** |

---

## v7.5.7.0 Scope

Reference: [Issue #85](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/85) — "[BUG-071][ARCH] Aggregator manifest truncation, satellite scaling, and PSRAM-aware support for v7.5.7.0"

The scope covers:
1. **Buffer increase:** Aggregator manifest buffer from 4096 → 8192 bytes in `SatelliteCache` struct
2. **Truncation detection guard:** Add runtime check that rejects/logs truncated JSON manifests (detect `manifest_len == AGG_MANIFEST_BUF_SIZE - 1`, log warning, omit broken manifest from `/api/aggregator/gateways` response)
3. **PSRAM-aware `MAX_SATELLITES` scaling** in `render_sensor_config.py`:
   - No PSRAM → satellite only (AGGREGATOR_ENABLED 0) (ESP32-C3 SuperMini, ESP32-WROOM-32D, any board that does not have PSRAM)
   - PSRAM ≥ 4MB → up to 8 satellites (ESP32-S3 N16R8)
4. **Documentation updates:** `Docs/aggregator-setup.md` and `Docs/v7.5-v7.6-architecture-plan.md` updated for new limits, `Docs/bugs-and-lessons-learned.md` updated with new bugs and lessons, if any

---

## Key Codebase Facts for v7.5.7.0

- `dashboard/sensor_history_multi.h` contains the aggregator code under `#if AGGREGATOR_ENABLED`
- `SatelliteCache` struct stores polled satellite data; manifest buffer is currently 4096 bytes
- `render_sensor_config.py` generates the `MAX_SATELLITES` constant; board profiles drive this
- `config/gateway.json` / `config/aggregator.json` are gitignored deployment configs
- Board definitions in `firmware/boards/*.yaml` specify PSRAM availability via `capabilities.psram`
- Aggregator manifest buffer size is currently 4096 bytes — insufficient for 4+ satellites with system devices (BUG-071)
- `s_fetch_tmp` is a separate 32768-byte buffer (not the manifest buffer); the manifest buffer is inside `SatelliteCache`

---

## Lessons from Phase 6 

1. **Mock contract fidelity (LESSON-OPS-081):** Always enumerate all firmware error branches when asking agents to create mock endpoints. A "device exists → 200" stub hides client-side bugs and always triggers merge-blocking review comments.

2. **Downstream text updates (LESSON-OPS-082):** When changing fixture composition, require updating skip-reason strings that reference the old composition. A fixture change is not complete until all downstream text is updated.

3. **Test signature cleanliness:** Only destructure used Playwright fixtures (`page`, `request`, etc.) in test signatures. Unused fixtures should be removed.

4. **Carry-forward audits work well:** BUG-072/073 were cleanly resolved as carry-forwards in the implementation commit. This pattern is reliable.

5. **Group number from source file:** The instruction to derive group number by reading `dashboard.spec.js` (not hardcoding in the prompt) worked perfectly — agent chose Group 20 correctly.

6. **Existing-test compatibility audit prevents BUG-051 recurrence:** The mandatory full-suite run with skip guards is essential when adding new fixture variants. §5f audit must remain in all future fixture-adding prompts.

7. **Two review rounds for one under-specified requirement:** A1 (mock ingest) required 2 separate fix commits (one for metric validation, one for val validation). A single well-specified contract-lock section in the prompt would have reduced the PR from 4 commits to 2.

---


## Workflow for v7.5.7.0

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document - ask human if PR for this session has been opened yet and if yes, ask to provide PR number to work on. **
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly. ** 
> **⚠️ IMPORTANT: If something is not clear, when reading instructions, stop and ask for clarification ** 

1. Ask human if PR for v7.5.7.0 has been opened and ask to provide the PR number
2. If PR has not been opened, **Open a NEW coding agent session outside of this chat** and paste the prompt from `prompts/v7.5.7.0-implementation-instructions-for-coding-agent.md`
3. Wait for the agent to create the PR 
4. Copilot PR reviewer reviews automatically and additional reviews might be posted
5. Human reviews PR against the Review Checklist in the prompt
6. Fix any issues
7. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
9. Provide to human all the necessary instructions to run tests. **IMPORTANT**: if as a result of the PR testing that was outlined in the testing section of `prompts/v7.5.7.0-implementation-instructions-for-coding-agent.md`, needs to be updated, provide updated section.
10. Provide instructions after merging PR to Main with tagging and pushing the tag  


## Post-PR Closure Deliverables (for v7.5.7.0)

After the v7.5.7.0 PR is merged, produce these documents:

### 1. Session Handoff Document
**Format:** Same as this document. Must include:
- Project state summary with v7.5.7.0 changes and Phase 6 Complete status
- phaseD overall scope and v7.6.0.0 scope: Boot with NVS satellites, reboot and verify persistence, clear NVS and verify compile-time fallback
- Pre-merge checklist for v7.6.0.0
- Lessons learned from Phase 6 and v7.5.7.0 overall 

**File:** `prompts/handoff/session-handoff-phaseD-start.md` - file has been already created, update as necessary with the information from v7.5.7.0 closure 

### 2. PR and Prompt Audit Document

**⚠️ IMPORTANT: the PR and Prompt Audit Document must include answering on the following questions:**

- Did the coding agent deliver properly and accurately what was required from the prompt? How is the execution quality?
- Did the codebase state at execution time match the prompt's assumptions? If function signatures, line numbers, or struct layouts had drifted from what the prompt described, how did the agent handle the delta — did it reconcile correctly or silently diverge?
- What implementation decisions did the agent make that were NOT specified in the prompt? Were those decisions correct? Should any of them be back-ported as explicit requirements into the prompt for reproducibility?
- If the coding agent did not execute properly what was required, then: why it happened and what caused it? 
- Please provide coding agent's prompt audit: did the prompt was created accosting to the `Docs/writing-prompts-for-coding-agents-guide.md` guideline document and if not, where was deviation?
- If there were failures, how to prevent in future such failures by coding agents?
- Code reviews: are the changes/information mentioned in the PR comments/code audits warranted? Please create list of PR comments and your conclusion if changes warranted or not and why.

**File:** `prompts/v7.5.7.0-PR-consolidated-audit-and-lessons.md` - put actual PR number here
**Format:** Same as `prompts/phase6/v7.5.6.4-PR87-consolidated-audit-and-lessons.md`

### 3. Updated Prompt Corrections (if needed)
If the v7.5.7.0 prompt audit reveals defects in the v7.6.0.0 prompt that is the next step - `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md` - produce correction text.


## What Comes After v7.5.7.0 

### Phase D Step Index

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.6.0.0 | NVS satellite persistence layer + runtime loop migration | `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.1 | POST /api/aggregator/add-satellite | `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.3 | POST /api/aggregator/test-satellite | `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.4 | Dashboard add/remove/test UI | `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent-updated.md` | Pending |
| v7.6.0.5 | Playwright tests + Phase D closure | `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent-updated.md` | Pending |


### Post-Phase-D Roadmap

After Phase D completes (v7.6.0.5 merged):
1. **Phase 7** (v7.7.0.x–v7.7.2.x) — Per-device persistence engine. Prompts exist for v7.7.0.0, v7.7.0.1, v7.7.1.0.
2. **Phase E** (v8.0.x) — Captive portal + WiFi config. Not yet planned.

---

_End of session handoff document._
