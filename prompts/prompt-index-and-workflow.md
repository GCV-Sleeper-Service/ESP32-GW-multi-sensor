Coding Agent Prompt Index and Workflow

_Single source of truth for all implementation prompts._
_Last updated: 2026-05-06 — Phase VX complete (v7.6.10.4). Current Phase: **Phase VY** (methodology audit). Next: multi-phase planning, then Phase 7._
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
| **Architecture Overview** | `Docs/architecture-overview.md` | Project architecture entry point — hardware, firmware, dashboard, build pipeline, phase history |
| Persistence Architecture | `Docs/v7.7-v7.8-persistence-architecture.md` | Per-device persistence design for Phase 7 |
| Phase D Implementation Plan | `Docs/phase-d-implementation-plan.md` | Step-level scope for Phase D (API contracts reference) |
| Phase 7 Implementation Plan | `Docs/v7.7-implementation-plan.md` | Step-level scope for Phase 7 |
| Phase Y Plan | `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` | Firmware refactor plan |
| Phase Y Inventory | `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` | Current state inventory for Phase Y |
| Bugs & Lessons Learned | `Docs/lessons/index.md` | Project guardrails and failure history (split by domain at v7.6.4.0) |
| **Prompt Writing Guide** | `Docs/writing-guide/methodology.md` | How to create and audit prompts (split into methodology + gap catalog at v7.6.4.0) |
| **Phase D Results and Summary** | `prompts/handoff/phaseD/phaseD-results.md` | Phase D delivery record, lessons, API contracts |
| **Phase X Results and Summary** | `prompts/handoff/phaseX/phaseX-results.md` | Phase X delivery record, lessons, metrics |
| Phase X Architecture Plan | `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` | Dashboard refactor design (methodology reference) |
| Phase X Audit Template | `prompts/phaseX/pr-audit-question-template.md` | Stable core + level-specific PR audit questions |
| Archived plans (Phases 3–6) | `Docs/archive/completed-phases/` | Historical implementation plans |

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
and execute the device testing as a §6 (in-PR) acceptance criterion before marking the PR ready.

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

Phase 3 complete (v7.5.3.0–v7.5.3.9). SensorEntity C++ model, v2 API endpoints, BUG-043/044 fixes. Plan: `Docs/archive/completed-phases/phase3-implementation-plan.md`.

### Phase 4 — First Non-Climate Sensor (Ping Probe) ✅ COMPLETE

Phase 4 complete (v7.5.4.0–v7.5.4.5, 2026-03-19 to 2026-03-21). ICMP ping adapter, network card renderer, mixed-category fixtures. Plan: `Docs/archive/completed-phases/phase4-implementation-plan.md`. Prompts: `prompts/phase4/`.

### Phase 5 — Aggregator MVP ✅ COMPLETE

Phase 5 complete (v7.5.5.0–v7.5.5.5, 2026-03-21 to 2026-03-25). Aggregator config, polling, API, dashboard UI, Playwright tests. Plan: `Docs/archive/completed-phases/phase5-implementation-plan.md`. Prompts: `prompts/phase5/`.

### Phase 6 — Data Ingest and System Metrics ✅ COMPLETE

Phase 6 complete (v7.5.6.0–v7.5.6.4, 2026-03-26). POST /api/ingest, system device category, card renderer, exporters, tests. v7.5.7.0 (aggregator manifest truncation fix, 2026-03-28) also shipped. Plan: `Docs/archive/completed-phases/phase6-implementation-plan.md`. Prompts: `prompts/phase6/`.

### Phase D — Runtime Satellite Management (v7.6.0.x) ✅ COMPLETE

Phase D complete (v7.6.0.0–v7.6.0.5, 2026-03-29 to 2026-04-04). Runtime satellite management — add/remove/test satellites via dashboard UI, NVS persistence, deferred task pattern. 7 bugs fixed (BUG-075–081), 402/0 tests, Critical Rules 38–46 added. Results: `prompts/handoff/phaseD/phaseD-results.md`. Prompts: `prompts/phaseD/`.

Open Item OI-001: fix inaccurate parallelism comment in `tests/mock-server/server.js` lines 92–95 — first Phase 7 PR touching `server.js` must resolve this.

### Phase X — Dashboard Architecture Refactor (v7.6.4.0–v7.6.5.8) ✅ COMPLETE

Phase X complete (v7.6.4.0 + v7.6.5.0–v7.6.5.8, 2026-04-05 to 2026-04-08). Dashboard monolith (3,955 lines) refactored into modular component architecture with three-pass build pipeline. Context reduced 6x–8x (55K→8K tokens). LESSON-OPS-043 structurally resolved. 11 new Critical Rules (47–57). 402/0 tests maintained throughout. Results: `prompts/handoff/phaseX/phaseX-results.md`. Quality check: `prompts/handoff/phaseX/phaseX-results-quality-check.md`. Plan: `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`. Prompts: `prompts/phaseX/`.

### Phase Y — Firmware Refactor: sensor_history_multi.h ✅ COMPLETE

Phase Y complete (v7.6.6.0–v7.6.6.8, 2026-04-10 to 2026-04-12). Firmware monolith (4,325 lines) decomposed into 8 source fragments in `firmware/core/`, assembled by `scripts/assemble-sensor-history.sh`. Option B (assembled artifact) — zero generator changes, zero YAML changes, SHA-256 identity gate. Context reduced 3.6×–9× per task. 5 new Critical Rules (58–62) added. 402/0 Playwright tests maintained throughout. Device tests passed on both C3 and S3 hardware. Results: `prompts/handoff/phaseY/phaseY-results.md`. Plan: `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`. Prompts: `prompts/phaseY/`.

**Version range:** v7.6.6.0–v7.6.6.8
**Plan:** `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`
**Inventory:** `Docs/phase-Y-current-state-inventory-sensor-history-v2.md`
**Audit Template:** `prompts/phaseY/pr-audit-question-template-phaseY.md`
**Bug Escalation:** `prompts/phaseY/phase-y-bug-escalation-prompt.md`
**Two-Session Prompts:** `prompts/handoff/phaseY/phase-y-two-session-prompts.md`

| Version | Scope | Prompt File | Handoff | Status |
|---------|-------|-------------|---------|--------|
| v7.6.6.0 | Pre-step: `provision.sh` full pipeline automation | `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md` | ✅ Complete |
| v7.6.6.1 | Establish assembly script + 8 fragments + SHA-256 baseline | `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md` | ✅ Complete |
| v7.6.6.2 | Wire assembly into pipeline + fragment-level preflight | `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md` | ✅ Complete |
| v7.6.6.3 | Validate edit-fragment workflow end-to-end | `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md` | ✅ Complete |
| v7.6.6.4 | Ping adapter fragment validation | `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md` | ✅ Complete |
| v7.6.6.5 | Device test gate: NVS persistence on C3 | `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md` | ✅ Complete |
| v7.6.6.6 | Device test gate: aggregator runtime on S3 | `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md` | ✅ Complete |
| v7.6.6.7 | Full endpoint smoke test (all 21 handlers) | `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md` | ✅ Complete |
| v7.6.6.8 | Closure: preflight + docs + Critical Rules 58–62 | `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md` | `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md` | ✅ Complete |

### Phase V — Bug Fixing, Optimization & Security Hardening (v7.6.7.0–v7.6.9.5) ✅ COMPLETE

Phase V complete (v7.6.7.0–v7.6.9.5, 2026-04-13 to 2026-04-20). Security hardening (auth guards on all write endpoints, SEC-ADR-001), dashboard enhancements (device cards, CSV export, manifest), heap-adaptive history cap (#139 partial), C3 stack override fix (BUG-083). 2 bugs fixed (BUG-082, BUG-083), 3 new LESSON-OPS entries (126–128), 1 LESSON-SEC entry (LESSON-SEC-001), Critical Rule 64 added. Results: `prompts/handoff/phaseV/phaseV-results.md`. Plan: `Docs/phase-V-implementation-plan.md`. Prompts: `prompts/phaseV/`.

Phase V used a different prompt methodology from Phases D/X/Y: Claude advisory sessions producing agent prompts (two-step pattern), Kiro/GPT/Codex executing those prompts, Perplexity three-turn PR review. Prompts follow the naming pattern `v7.6.X.Y-agent-prompt-gpt-codex.md` and `v7.6.X.Y-claude-two-step.md` rather than the standard `implementation-instructions-for-coding-agent.md` convention.

**Version range:** v7.6.7.0–v7.6.9.5 (13 version-step PRs: #176–#184, #191–#193, #195; plus #194 docs, #197 issue sweep)
**Plan:** `Docs/phase-V-implementation-plan.md`
**Addendum:** `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md`
**Capacity study:** `Docs/phase-V-capacity-study.md`
**Audit Template:** `prompts/phaseV/consolidated-audit-template-phaseV.md`

| Version | Scope | Prompt File | Handoff | Status |
|---------|-------|-------------|---------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix, NAS history disable, logger level | `prompts/phaseV/v7.6.7.0-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.7.0.md` | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix (Rule 40) | `prompts/phaseV/v7.6.7.1-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.7.1.md` | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Version badge, dead code, import comment | `prompts/phaseV/v7.6.7.2-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.7.2.md` | ✅ Complete |
| v7.6.7.3 | Operational telemetry in /api/status | _(operator-directed, no formal prompt)_ | _(no handoff — V1 measurement protocol)_ | ✅ Complete |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status field split | `prompts/phaseV/v7.6.8.0-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.8.0.md` | ✅ Complete |
| v7.6.8.1 | V2-E/F/G: History auth + heap cap + DoS cooldown + SEC-ADR | `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.8.1.md` | ✅ Complete |
| v7.6.8.2 | V2-H: Socket reduction (V2-I/J blocked) | `prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.8.2.md` | ✅ Complete |
| v7.6.9.0 | V3-A: Dashboard device card cleanup | `prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.0.md` | ✅ Complete |
| v7.6.9.1 | V3-B/C: Satellite hostname/IP + CSV role column | `prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.1.md` | ✅ Complete |
| v7.6.9.2 | V3-D/E: Manifest-driven export + AGG-ADR | `prompts/phaseV/v7.6.9.2-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.2.md` | ✅ Complete |
| v7.6.9.3 | V3-F: Struct audit / Phase V preliminary closure | `prompts/phaseV/v7.6.9.3-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.3.md` | ✅ Complete |
| v7.6.9.4 | V4: Heap-adaptive history cap + boot sequencing | `prompts/phaseV/v7.6.9.4-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.4.md` | ✅ Complete |
| v7.6.9.5 | V5: C3 httpd stack override fix (BUG-083) | `prompts/phaseV/v7.6.9.5-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.5.md` | ✅ Complete |

### Phase VX — Board Onboarding Sprint (v7.6.10.0–v7.6.10.3+)

Phase VX is an infrastructure sprint between Phase V closure and Phase 7. ESPHome upgraded from 2026.2.1 to 2026.4.1 (ESP-IDF 5.5.4). Up to 3 new boards (S3 SuperMini, C6 SuperMini, C5 WROOM-1U) onboarded into the provisioning pipeline. Measurement dataset produced for multi-phase planning.

Phase VX uses the same prompt methodology as Phase V: Claude advisory sessions producing agent prompts (two-step pattern), Kiro/GPT/Codex executing those prompts, Perplexity three-turn PR review.

**Version range:** v7.6.10.0–v7.6.10.3 (+ optional v7.6.10.4)
**Sprint prompt:** `prompts/handoff/phaseVX/phaseVX-board-onboarding-sprint-prompt.md`
**Sprint assessment:** `prompts/handoff/phaseVX/phaseVX-sprint-assessment.md`
**Audit Template:** `prompts/phaseVX/consolidated-audit-template-phaseVX.md`
**Measurement Protocol:** `Docs/board-measurement-protocol-v7.6.10.md`
**Measurement Log:** `Docs/board-measurement-log-v7.6.10.md`

| Version | Scope | Prompt File | Handoff | Status |
|---------|-------|-------------|---------|--------|
| v7.6.10.0 | ESPHome 2026.4.1 upgrade verification + local component re-patch | `prompts/phaseVX/v7.6.10.0-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseVX/session-handoff-v7.6.10.0.md` | ✅ Complete (PR #200) |
| v7.6.10.1 | Board profiles + partition tables for 3 new boards | `prompts/phaseVX/v7.6.10.1-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseVX/session-handoff-v7.6.10.1.md` | ✅ Complete |
| v7.6.10.2 | Flash, measure, document | _(operator-driven, see measurement protocol)_ | _(no agent handoff)_ | ✅ Complete |
| v7.6.10.3 | Capacity study + board selection guide update | _(Claude advisory session)_ | `prompts/handoff/phaseVX/session-handoff-v7.6.10.3.md` | ✅ Complete |
| v7.6.10.4 | Dashboard auth refactor | `prompts/phaseVX/v7.6.10.4-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseVX/session-handoff-v7.6.10.4.md` | ✅ Complete (PR #202) |

**New boards onboarded:**

| board_id | Name | Chip | Flash | PSRAM | IP | Compiled? |
|----------|------|------|-------|-------|----|-----------|
| esp32-s3-supermini-4m | sat-s3-4m-173 | ESP32-S3 | 4 MB | 2 MB quad | 192.168.120.173 | Yes |
| esp32-c5-wroom1u-8m | sat-c5-8m-180 | ESP32-C5 | 8 MB | 8 MB quad | 192.168.120.180 | Yes |
| esp32-c6-supermini-4m | sat-c6-4m-184 | ESP32-C6 | 4 MB | None | 192.168.120.184 | Yes |

**Findings:**
- BUG-084: Heap exhaustion under 8 concurrent HTTP connections on non-PSRAM boards (C3, WROOM). Stack is fine (watermark ~12,900 B on 16 KB stack). Stress test script needs concurrent request reduction.
- S3 watermark dropped from 12,528 B to 10,036 B after ESPHome 2026.4.1 — monitor.
- IRAM optimization (`sram1_as_iram`) not applicable — would worsen heap pressure on WROOM. N/A for RISC-V boards.


### Phase 7 — Per-Device Persistence Engine — After Phase V

**`main` is at v7.6.9.5. Phase VX (v7.6.10.x) runs first, then Phase VY planning, then Phase 7 starts at v7.7.0.0.**

Before starting Phase 7, read `prompts/handoff/phaseD/phaseD-results.md` for the active lessons and API contracts that Phase 7 must remain compatible with. Also read `prompts/handoff/session-handoff-v7.7.0.0.md` for the full Phase 7 entry context.

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.7.0.0 | ESPHome component defaults audit (research) | `prompts/phase7/v7.7.0.0-research-prompt.md` | Complete |
| v7.7.1.0 | Health-check telemetry task + measurement baseline | `prompts/phase7/v7.7.1.0-agent-prompt-gpt-codex.md` | Complete |
| v7.7.1.1 | Chunked HTTP streaming for history endpoints (BUG-082 fix) | `prompts/phase7/v7.7.1.1-agent-prompt-gpt-codex.md` | Complete |
| v7.7.1.2 | Per-device structs, key scheme, hash function | _Prompt not yet created_ | Pending |
| v7.7.1.3 | Per-device persist engine (write path) | _Prompt not yet created_ | Pending |
| v7.7.1.4 | Per-device restore engine (boot path) + retention budget | _Prompt not yet created_ | Pending |
| v7.7.2.1 | Wire new engine, storage stats v2, switchover | _Prompt not yet created_ | Pending |
| v7.7.2.2 | v7→v8 one-time migration | _Prompt not yet created_ | Pending |
| v7.7.2.3 | Per-device delete API + dashboard UI | _Prompt not yet created_ | Pending |
| v7.7.3.1 | Per-device export/import | _Prompt not yet created_ | Pending |
| v7.7.3.2 | Multi-device bundle export/import | _Prompt not yet created_ | Pending |
| v7.7.3.3 | Full regression, old engine removal, phase closure | _Prompt not yet created_ | Pending |

**Note:** The older Phase 7 table above was superseded by the 2026-05-07 multi-phase planning rewrite. The active sequence starts with research step `v7.7.0.0`, then implementation steps `v7.7.1.0`, `v7.7.1.1`, `v7.7.1.2`, `v7.7.1.3`, `v7.7.1.4`, followed by `v7.7.2.x` integration and `v7.7.3.x` export/closure work.

---

## Version Number ↔ Phase Mapping

| Phase | Version Range | Description | Implementation Plan |
|-------|--------------|-------------|---------------------|
| Phase 1 | v7.5.0.x | Manifest v2 endpoint | `Docs/archive/completed-phases/v7.5-v7.6-architecture-plan.md` §11 |
| Phase 2 | v7.5.1.x | Dashboard consumes manifest | Same |
| Phase 3 | v7.5.3.x | SensorEntity C++ model | `Docs/archive/completed-phases/phase3-implementation-plan.md` |
| Phase 4 | v7.5.4.x | First non-climate sensor (ping) | `Docs/archive/completed-phases/phase4-implementation-plan.md` |
| Phase 5 | v7.5.5.x | Aggregator MVP | `Docs/archive/completed-phases/phase5-implementation-plan.md` |
| Phase 6 | v7.5.6.x | Data ingest + system metrics | `Docs/archive/completed-phases/phase6-implementation-plan.md` |
| **Phase D** | **v7.6.0.x** | **Runtime satellite management** | **`Docs/phase-d-implementation-plan.md`** |
| **Phase X** | **v7.6.4.0** | **Documentation restructuring (pre-step)** | **`Docs/phase-X-architecture-and-refactor-plan-dashboard.md`** |
| **Phase X** | **v7.6.5.0–v7.6.5.8** | **Dashboard architecture refactor** | **Same** |
| **Phase Y** | **v7.6.6.x** | **Firmware refactor (sensor_history_multi.h)** | **`Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`** |
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
| 6 | ~~Mirror all dashboard.js changes to dashboard.html~~ **Structurally resolved by Phase X v7.6.5.3.** dashboard.html is now generated by build-dashboard.sh. Never edit dashboard.js or dashboard.html directly — edit source modules and run the pipeline. | LESSON-OPS-043 (resolved) |
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
| 37 | Full regeneration pipeline (CI/satellite default): `bundle-dashboard.sh --write` → `render_sensor_config.py --write` → `node generate-fixtures.js` → `render_sensor_config.py --write` → `build-dashboard.sh --write` → `minify-dashboard.sh` → `generate-header.sh` → `render_sensor_config.py --check`. For local device testing with non-default hardware, use `bash scripts/provision.sh <aggregator\|wroom>` BEFORE the pipeline, and `bash scripts/provision.sh satellite` after local testing and before pushing to remote. | LESSON-OPS-091 (updated at Phase X v7.6.5.8) |
| 38 | All dashboard `fetch()` POST calls must use `Content-Type: application/x-www-form-urlencoded` with `body: \'a=1\'`. ESPHome does not consume JSON POST bodies. | BUG-076 / LESSON-OPS-099 |
| 39 | All `curl` POST commands must use `-d \'a=1\'`. Never use `-H "Content-Type: application/json"`, never use `-d \'\'`, never use bare `-X POST` without a body. | BUG-076 / LESSON-OPS-099 |
| 40 | Any HTTP handler performing NVS operations must use the deferred task pattern (`xTaskCreate`, 8192+ byte stack). Never perform NVS work synchronously in an HTTP handler. | BUG-075 / LESSON-OPS-100/101 |
| 41 | Never add `CONFIG_HTTPD_STACK_SIZE` to any board profile `sdkconfig_options` in `firmware/boards/*.yaml` or in generated board YAMLs. It has zero runtime effect — ESPHome hardcodes the httpd task stack at 4 KB and ignores this setting. The legacy `firmware/esp32-c3-multi-sensor.yaml` template is exempt from this rule. | BUG-075 / LESSON-OPS-100 |
| 42 | All board profiles must include an `external_components` block referencing `firmware/local_components` for the patched `web_server_idf` component. Without this, the httpd task runs at 4 KB and all POST handlers crash. Run `scripts/patch-esphome-httpd-stack.sh --check` to verify. | BUG-075 / LESSON-OPS-102 |
| 43 | After re-running `scripts/patch-esphome-httpd-stack.sh` (ESPHome upgrade), verify that `init_response_()` in the local component still contains the expanded HTTP status code switch with `snprintf` fallback. The patch script only applies the stack size line — the status code fix must be preserved manually. | BUG-078 / LESSON-OPS-103 |
| 44 | Never use Arduino `String` (capital S) or bare `string` in ESP-IDF code. Always use `std::string`. The coding agent\'s CI does not perform ESP-IDF compilation — Arduino-isms pass CI but break the real build. Treat `String` in agent-generated code as a PR review red flag. | BUG-077 / LESSON-OPS-104 |
| 45 | DOM references captured before an async auth flow (`requestManagementCredentials()`) become stale if `pollAggregatorLive()` fires during the wait and rebuilds `innerHTML`. Always re-query stable `id` nodes AFTER async boundaries. Suppress poll-driven rerenders while any action flag is true or while a management input has focus. | BUG-080/081 / LESSON-OPS-111 |
| 46 | Mock server response shapes must be verified against the live firmware `httpd_resp_sendstr()` call — not the prompt description, not an audit table, not a prior session summary. The firmware contract is the single source of truth. | LESSON-OPS-112 |
| 47 | Source modules live in dashboard/core/ and dashboard/components/*/. dashboard.js and dashboard.html are generated — never edit directly. | Phase X v7.6.5.3 |
| 48 | After any module edit, run the full pipeline: bundle-dashboard.sh --write → render_sensor_config.py --write → build-dashboard.sh --write → minify-dashboard.sh → generate-header.sh | Phase X v7.6.5.0 |
| 49 | scripts/provision.sh is the mandatory entry point for switching between aggregator, WROOM satellite, and C3 satellite (default/CI-safe) configs. Always run `bash scripts/provision.sh satellite` before pushing to remote — failure to do so will break CI. Run `bash scripts/provision.sh status` to verify current state at any time. | Phase X v7.6.5.8 |
| 50 | When planning file concatenations for non-contiguous modules, verify that all source modules in the group are physically adjacent in the bundle output. Modules can only be safely concatenated if contiguous. If intervening modules exist, keep them as separate components — the identity gate will catch violations but the plan should catch them first. | LESSON-OPS-118 / v7.6.5.4 |
| 51 | `build-dashboard.sh` marker resolution must use `re.subn` with **lambda replacement** and CRLF-tolerant `\r?\n` patterns — never `bytes.replace()` with hardcoded `\n`, never `re.sub()` with raw bytes as replacement (backreference risk). | BUG-076 / LESSON-OPS-099; updated v7.6.5.6 (Gemini HIGH finding) |
| 52 | Build tool dependencies used via shell scripts must be wired as `devDependencies` with `npx` invocation in scripts — never as global-only requirements. Global-only tooling causes silent CI mismatches on fresh installs. | v7.6.5.5 PR #146 CODEX/GPT review finding 
| | | 
| 53 | When using `re.sub()` / `re.subn()` to inject raw file contents (CSS, JS, HTML) as a replacement, ALWAYS use a lambda function — never pass raw bytes directly. CSS/JS commonly contain backslash sequences that `re.sub` interprets as backreferences. | LESSON-OPS-121  v7.6.5.6 PR #147 |
| 54 | When an acceptance criterion is contradicted by another requirement, the agent MUST stop and escalate to the operator — never self-waive. Document the contradiction in session log § Accepted Exceptions after operator confirms the waiver. | v7.6.5.6 PR #147 — agent self-waived output-identity gate |
| 55 | CSS partition rule is "by selector target" — which component does this rule style? Global `@media` rules targeting selectors from multiple components belong in `core/base.css` regardless of source proximity in the original file. | v7.6.5.6 PR #147 — global @media initially misplaced |
| 56 | Version bumps (VERSION file, App.version, fixtures, firmware YAML) are out of scope for test-only PRs. Version bumps belong in the step that delivers code changes. | v7.6.5.7 PR #148 — three agents attempted version bumps before revert |
| 57 | When splitting a monolithic test file into domain-scoped files, any pre-existing spec file that receives new test groups must be audited for duplicate helper functions. Local copies must be replaced with imports from the shared helpers module. | v7.6.5.7 PR #148 — `manifest.spec.js` had divergent local copies |
| 58 | Source modules for `sensor_history_multi.h` live in `firmware/core/`. Never add code to `dashboard/sensor_history_multi.h` directly — it is an assembled artifact. | Phase Y v7.6.6.1 |
| 59 | `render_sensor_config.py` writes into the assembled `dashboard/sensor_history_multi.h`. Never redirect the generator to fragment files. | Phase Y D3 |
| 60 | `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` are defined once in `firmware/core/aggregator-runtime.h`. Never redefine or shadow them. | Phase Y v7.6.6.6 |
| 61 | `maybe_yield_nvs_scan_()` is defined once in `firmware/core/nvs-persistence.h`. Call it in every NVS scan loop. | Phase Y v7.6.6.5 |
| 62 | The assembly fragment order in `assemble-sensor-history.sh` is the dependency order. Never reorder fragments. | Phase Y v7.6.6.1 |
| 63 | Session log is a **pre-merge acceptance criterion** (§6), not a post-merge deliverable (§9). Required sections: ESPHome output (or documented absence), Playwright fixture table, evidence summary. Agents treat §9 as optional — placing the session log there caused 4/9 Phase Y steps to ship without it. | Phase Y closure analysis — 44% omission rate when in §9 |
| 64 | Checkpoint grep assertions in agent prompts must be mechanically derived from the replacement block in the same prompt — never estimated from memory or a prior session. Mismatched counts cause agents to loop on phantom failures or silently accept wrong state. | LESSON-OPS-126 / v7.6.9.4 |
| 65 | All new HTTP endpoints must include `authenticate_management_()` for write/management operations and `authFetch()` in dashboard fetch calls | Phase 7 planning review |
| 66 | After adding new HTTP handlers, run `scripts/stress-test-httpd-stack.sh` on at least one board per architecture. Minimum watermark ≥ 2,000 B. | Phase 7 planning review |
| 67 | Binary sensor metrics use `EventLog` (state-change-only deduplication), not `HistoryBuffer` (periodic readings) | PLAN-002 |

---

## Board Provisioning for Local Device Testing

Use `scripts/provision.sh` to switch between hardware targets without breaking CI.

| Command | Board | CI-safe |
|---|---|---|
| `bash scripts/provision.sh satellite` | C3 SuperMini (default) | ✅ YES |
| `bash scripts/provision.sh aggregator` | ESP32-S3 agg-s3-16m-1 | ❌ NO |
| `bash scripts/provision.sh wroom` | WROOM sat-esp32-4m-190 | ❌ NO |
| `bash scripts/provision.sh status` | (inspect only) | n/a |

**Mandatory rule:** Run `bash scripts/provision.sh satellite` before every `git push`.
The script runs `render_sensor_config.py --write` automatically on switch. Run the remaining pipeline steps after.

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

### 2026-04-08 — Documentation Reorganization (Issue #140)

| Change | Why |
|--------|-----|
| **Docs reorganized** | Session logs → `Docs/archive/session-logs/`; completed phase plans → `Docs/archive/completed-phases/`; Phase X artifacts → `Docs/archive/phase-x-artifacts/`; postmortems → `Docs/archive/postmortems/` |
| **`Docs/architecture-overview.md` created** | New canonical architecture entry point consolidating project overview, phase history, active documents, and key constraints |
| **Lessons index audited and fixed** | 9 missing entries added (BUG-043, BUG-072/073, LESSON-OPS-080–083, LESSON-OPS-119/120); 1 phantom entry removed (BUG-082); LESSON-OPS-117/118 duplication resolved (dashboard.md canonical, build-pipeline.md demoted to notes) |
| **Changelog fixed** | Missing `## [v7.6.5.3]` heading added; PR #150 post-merge note added under v7.6.5.8; v7.6.5.7 version-skip annotation added |
| **Phase Y section added** | v7.6.6.x, status Planned, links to plan and inventory documents |
| **Completed phases summarized** | Phase 3–6, Phase D, Phase X step tables replaced with one-line summaries and archive references |
| **Related Documents updated** | Architecture overview added; archived plans referenced; phaseD-results.md path corrected to `prompts/handoff/phaseD/` |
| **Phase X handoffs moved** | `prompts/handoff/session-handoff-v7.6.*.md` → `prompts/handoff/phaseX/` |
| **README updated** | Phase D marked complete; aggregator API stubs updated; architecture doc link updated; Phase Y noted as planned |
| **Revision history condensed** | Per-step entries replaced with phase-level summaries |

### 2026-04-12 — Phase Y Closure (v7.6.6.8)

Phase Y complete. All 9 steps delivered. Critical Rules 58–62 added. 6 new preflight checks added (68 total). Phase Y results document produced (`prompts/handoff/phaseY/phaseY-results.md`).

### 2026-04-10 through 2026-04-11 — Phase Y Execution (v7.6.6.0–v7.6.6.7)

Per-step revision entries condensed. Delivery details preserved in Phase Y results (`prompts/handoff/phaseY/phaseY-results.md`) and individual consolidated audits (`prompts/phaseY/v7.6.6.x-PRxxx-consolidated-audit-and-lessons.md`).

### 2026-04-08 — Phase X Closure (v7.6.5.8)

Phase X complete. All 10 steps delivered. Critical Rules 47–57 added. Board provisioning table added. Phase X results document produced.


### 2026-04-06 through 2026-04-08 — Phase X Execution (v7.6.5.0–v7.6.5.7)

Per-step revision entries for each Phase X step have been condensed. Detailed delivery summaries are preserved in the Phase X results document (`prompts/handoff/phaseX/phaseX-results.md`) and in individual consolidated audits (`prompts/phaseX/v7.6.5.x-PRxxx-consolidated-audit-and-lessons.md`).

### 2026-04-04 — Phase D Closure (v7.6.0.5)

Phase D complete. All 6 steps delivered. Critical Rules 38–46 added. Phase D results document produced. OI-001 noted.

### 2026-03-29 through 2026-04-02 — Phase D Execution (v7.6.0.0–v7.6.0.4)

Per-step revision entries condensed. Delivery details preserved in Phase D results (`prompts/handoff/phaseD/phaseD-results.md`).

### 2026-03-18 through 2026-03-28 — Phases 3–6 + v7.5.7.0

Per-step revision entries condensed. Step tables, device testing requirements, and delivery details are preserved in the archived implementation plans (`Docs/archive/completed-phases/`) and in the changelog (`Docs/changelog.md`).

### 2026-03-18 — Initial Version

Created to replace three overlapping prompt management documents. Consolidated Phase 3, Phase 4, and Phase 5 step indices into a single workflow document.

---

_End of document._
