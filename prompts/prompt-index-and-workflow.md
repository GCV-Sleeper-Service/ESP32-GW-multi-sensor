# Coding Agent Prompt Index and Workflow

_Single source of truth for all implementation prompts._
_Last updated: 2026-03-21 — post-Phase-4 review revision (see Revision History at bottom)_
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
| Phase 7 Implementation Plan | `Docs/v7.7-implementation-plan.md` | Step-level scope for Phase 7 |
| Bugs & Lessons Learned | `Docs/bugs-and-lessons-learned.md` | Project guardrails and failure history |
| **Prompt Writing Guide** | `Docs/writing-prompts-for-coding-agents-guide.md` | How to create and audit prompts |

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
- `<phase>` — `phase4`, `phase5`, `phase6`, or `phase7`
- `<version>` — e.g., `v7.5.5.0`
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
10. **Record results** — save heap values, screenshots, curl outputs. These become the "device testing results" you paste into the next step's prompt.

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

### Phase 5 — Aggregator MVP

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.5.5.0 | Aggregator config schema | `prompts/phase5/v7.5.5.0-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-21 |
| v7.5.5.1 | Aggregator polling task | `prompts/phase5/v7.5.5.1-implementation-instructions-for-coding-agent.md` | Pending |
| v7.5.5.2 | Aggregator API endpoints | `prompts/phase5/v7.5.5.2-implementation-instructions-for-coding-agent.md` | Pending |
| v7.5.5.3 | Aggregator dashboard UI | `prompts/phase5/v7.5.5.3-implementation-instructions-for-coding-agent.md` | Pending |
| v7.5.5.4 | Aggregator Playwright tests | `prompts/phase5/v7.5.5.4-implementation-instructions-for-coding-agent.md` | Pending |
| v7.5.5.5 | Phase 5 closure | `prompts/phase5/v7.5.5.5-implementation-instructions-for-coding-agent.md` | Pending |

**Phase 5 device testing requirements:**
- v7.5.5.0: compile-only (both with and without `aggregator.json`)
- v7.5.5.1: **requires TWO devices** — satellite + aggregator. Verify polling logs, satellite unaffected, heap stable, unreachable/recovery test
- v7.5.5.2: verify aggregator API endpoints, history proxy, heap after proxy
- v7.5.5.3: **requires TWO devices** — test satellite mode unchanged, test aggregator UI (gateway selector, stale indicators, per-gateway view)
- v7.5.5.4: Playwright only — no device testing
- v7.5.5.5: final verification, screenshot for record

### Phase 6 — Data Ingest and System Metrics

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.5.6.0 | POST /api/ingest endpoint | `prompts/phase6/v7.5.6.0-implementation-instructions-for-coding-agent.md` | Pending |
| v7.5.6.1 | System device category | `prompts/phase6/v7.5.6.1-implementation-instructions-for-coding-agent.md` | Pending |
| v7.5.6.2 | System card renderer | `prompts/phase6/v7.5.6.2-implementation-instructions-for-coding-agent.md` | Pending |
| v7.5.6.3 | Exporter scripts + docs | `prompts/phase6/v7.5.6.3-implementation-instructions-for-coding-agent.md` | Pending |
| v7.5.6.4 | Tests + Phase 6 closure | `prompts/phase6/v7.5.6.4-implementation-instructions-for-coding-agent.md` | Pending |

**Phase 6 device testing requirements:**
- v7.5.6.0: verify ingest endpoint with curl (200/404/400 cases), heap stable
- v7.5.6.1: full endpoint audit (sensors.json, api/status, api/v2/live, legacy history 404)
- v7.5.6.2: push test data via ingest, verify system card renders with usage bars
- v7.5.6.3: run bash/Python exporters from an external host, verify dashboard shows data
- v7.5.6.4: Playwright only + Phase 6 closure verification

### Phase 7 — Per-Device Persistence Engine

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

**Note:** Phase 7 prompts for v7.7.0.2 through v7.7.2.3 should be created when Phase 7 implementation begins — they require the Phase 6 codebase state to properly trace data paths and verify function names. See `prompts/phase7/prompt-index-and-workflow.md` for Phase 7-specific workflow details.

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

### 2026-03-21 — Post-Phase-4 Review Revision

**Context:** Comprehensive post-Phase-4 review identified 5 bugs (BUG-052 through BUG-056) and multiple prompt quality gaps. Four independent third-party analyses (GP, GE, Codex, SO) reviewed the Phase 4 prompt set and implementation quality.

**What was updated and why:**

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
