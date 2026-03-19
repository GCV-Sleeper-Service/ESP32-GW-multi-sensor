# Coding Agent Prompt Index and Workflow

_Single source of truth for all implementation prompts._
_Last updated: 2026-03-18_
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
| Phase 4 Implementation Plan | `Docs/phase4-implementation-plan.md` | Step-level scope for Phase 4 |
| Phase 5 Implementation Plan | `Docs/phase5-implementation-plan.md` | Step-level scope for Phase 5 |
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
Do NOT proceed to any later step.
```

Fill in:
- `<phase>` — `phase4` or `phase5`
- `<version>` — e.g., `v7.5.4.1`
- `<PREV_VERSION>` — the version that was just completed
- `<TODAY>` — current date
- Device testing results — paste the actual curl outputs / heap values / screenshots from the previous step

### While the agent works

The agent will:
1. Clone the repo
2. Read the instructions and required files
3. Implement the changes
4. Run preflight and Playwright tests
5. Create a PR
6. Provide a device testing checklist

### After the agent completes

1. **Review the PR diff** — look for anything that contradicts the instructions
2. **Approve pending CI workflows** if needed (first-time contributors may need approval)
3. **Wait for all CI checks to pass** — do not merge on red
4. **If any workflow fails:** copy the exact failure output, send it back to the agent in the same conversation, and wait for the fix
5. **Merge only if all checks are green**
6. **Execute the device testing checklist** the agent provided (if applicable)
7. **Apply the git tag:**
   ```bash
   git pull origin main
   git tag -a v<VERSION> -m "<description from instructions file>"
   git push origin v<VERSION>
   ```
8. **Record results** — save heap values, screenshots, curl outputs. These become the "device testing results" you paste into the next step's prompt.

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

### Phase 4 — First Non-Climate Sensor (Ping Probe)

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.5.4.0 | Add ping device to manifest (BUG-045 fix) | _(completed, no expanded prompt needed)_ | ✅ Complete |
| v7.5.4.1 | Implement ICMP ping adapter | `prompts/phase4/v7.5.4.1-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-19 |
| v7.5.4.2 | Add network card renderer | `prompts/phase4/v7.5.4.2-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-19 |
| v7.5.4.3 | Mixed-category test fixtures | `prompts/phase4/v7.5.4.3-implementation-instructions-for-coding-agent.md` | ✅ Complete 2026-03-19 |
| **v7.5.4.4** | **Phase 4 closure** | `prompts/phase4/v7.5.4.4-implementation-instructions-for-coding-agent.md` | **⬅️ Next** |

**Phase 4 device testing requirements:**
- v7.5.4.0: compile + flash, verify ping device in `/api/manifest` (null values expected)
- v7.5.4.1: **critical** — verify ping data in `/api/v2/live`, verify non-empty history after 15 min, heap stable
- v7.5.4.2: **critical** — visual check both card types, network card shows live values, F5 stability
- v7.5.4.3: Playwright only — no device testing
- v7.5.4.4: final verification of all endpoints, screenshot for record

### Phase 5 — Aggregator MVP

| Version | Scope | Prompt File | Status |
|---------|-------|-------------|--------|
| v7.5.5.0 | Aggregator config schema | `prompts/phase5/v7.5.5.0-implementation-instructions-for-coding-agent.md` | Pending |
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

---

## Critical Rules (Apply to Every Step)

These come from BUG-043 through BUG-045 and are baked into every prompt. They are listed here for reference — you do not need to add them to the prompt text; they are already in each prompt file.

| # | Rule | Source |
|---|------|--------|
| 1 | Use `::time(nullptr)` not `time(nullptr)` in ESPHome C++ | Project convention |
| 2 | Use `bash scripts/bump-version.sh <version>` for every version bump | All steps |
| 3 | Regenerate all artifacts after source changes | All steps |
| 4 | Run `bash scripts/preflight.sh` — must pass | All steps |
| 5 | Run full Playwright suite — all tests must pass | All steps |
| 6 | Mirror all `dashboard.js` changes to `dashboard.html` | LESSON-OPS-043 |
| 7 | Never fire concurrent history requests from dashboard JS | LESSON-OPS-052 |
| 8 | Never use `beginResponseStream` for responses >10KB | LESSON-OPS-056 |
| 9 | Dashboard.h must be gzip-compressed | LESSON-OPS-055 |
| 10 | In-flight guards mandatory on interval-driven fetch functions | LESSON-OPS-050 |
| 11 | NVS scan loops must yield (`vTaskDelay` every N blobs) | LESSON-OPS-053 |
| 12 | `NUM_SENSORS` must alias `NUM_ENV_SENSORS`, never `NUM_DEVICES` | BUG-045 |
| 13 | Device testing sections must include full pull/compile/flash/verify workflow | LESSON-OPS-058 |
| 14 | Specified tests/checks must be tracked to implementation completion | LESSON-OPS-057 |

---

## Prompt File Naming Convention

Each step has exactly one prompt file:

```
prompts/<phase>/<version>-implementation-instructions-for-coding-agent.md
```

Examples:
- `prompts/phase4/v7.5.4.1-implementation-instructions-for-coding-agent.md`
- `prompts/phase5/v7.5.5.3-implementation-instructions-for-coding-agent.md`

Phase 3 prompts (`prompts/phase3/`) are retained for historical reference but all Phase 3 steps are complete. They do not need to be executed again.

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

The original Phase 5 files (`prompts/phase5/v7.5.5.x-implementation-instructions.md`) are superseded by the new `-for-coding-agent.md` versions.

---

## Maintaining This Document

After each step completes:

1. Update the Step Index: change the completed step to `✅ Complete` and move the `⬅️ Next` marker
2. If the step revealed new critical rules, add them to the table in the Critical Rules section
3. If the step required prompt changes to subsequent steps, note those changes and update the affected files (see `Docs/writing-prompts-for-coding-agents-guide.md` Section 10 for the audit methodology)

---

_End of document._
