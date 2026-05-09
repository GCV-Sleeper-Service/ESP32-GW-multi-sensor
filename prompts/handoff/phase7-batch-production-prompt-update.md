# Phase 7 — Batch Prompt Production Session Template

_Reusable prompt for producing agent prompt bundles for the next batch of Phase 7 steps._
_Each batch covers 2-3 steps. Produce this session after the previous batch's last step merges._
_Operator: paste this prompt into a Claude Opus session to produce the next batch._
_The final batch also produces the phase closure prompt._
_Version 2.0 — 2026-05-08 (amended post-Batch-1 lessons — see §Errata)_

---

## Trigger Table

| Batch | Trigger | Steps to Produce | Key Theme |
|-------|---------|-----------------|-----------|
| Batch 1 | Phase 7 planning complete | v7.7.0.0, v7.7.1.0, v7.7.1.1 | Research, health-check, chunked streaming |
| **Batch 2** | **v7.7.1.1 merged** | **v7.7.1.2, v7.7.1.3, v7.7.1.4** | **Per-device structs, persist write, persist restore** |
| Batch 3 | v7.7.1.4 merged | v7.7.2.1, v7.7.2.2, v7.7.2.3 | Switchover, migration, per-device delete |
| Batch 4 | v7.7.2.3 merged | v7.7.3.1, v7.7.3.2, v7.7.3.3 | Export/import, bundle, old engine removal + full regression |
| Batch 5 (final) | v7.7.3.3 merged | v7.7.5.0, v7.7.5.1, v7.7.5.2 + **closure prompt** | NVS dedup study, RAM window, binary dedup + **phase closure** |

**Important:** v7.7.3.3 is NOT the closure step. Its scope is old engine removal + full Playwright regression. Phase 7 closure happens after v7.7.5.x (the optimization sprint) because v7.7.x.x is still Phase 7.

**v7.7.5.x steps are conditional:**
- v7.7.5.0 (NVS dedup study) always runs — it's research
- v7.7.5.1 (RAM window reduction) always runs — depends on chunked streaming (v7.7.1.1)
- v7.7.5.2 (BinaryDeviceSegment) runs only if v7.7.5.0 study recommends it

If the study says "not worth it," v7.7.5.2 is skipped and Phase 7 closes after v7.7.5.1 (or v7.7.5.0 if RAM reduction is also deferred).

---

## Errata: Batch 1 Post-Mortem (Structural Fixes Applied Below)

Batch 1 prompts (v7.7.1.0 and v7.7.1.1) had five structural defects:

| # | Defect | Root Cause | Fix Applied |
|---|--------|-----------|-------------|
| E-1 | Consolidated audit, session log, CURRENT-STATE.md listed as "post-merge deliverables" in §9 | §9 title inherited pre-Phase VY language; development-process-guide.md §2.5 says these are IN-PR mandatory deliverables | §9 renamed to "Post-Merge Bookkeeping (tag and close only)". All documentation moves to §6 implementation steps. |
| E-2 | Device testing (compile, upload, curl) punted entirely to operator | Prompt producer created a separate "Operator Device Testing" section | Agent prompt includes device testing as §6 steps wherever the agent has serial/network access. Operator-only actions (visual dashboard checks) are explicitly marked. |
| E-3 | Stale board info: WROOM IP .190 (correct: .170), YAML filename wrong | Prompt producer used memorized values instead of reading CURRENT-STATE.md | Added "Board Info Extraction Gate" to mandatory verification (see below) |
| E-4 | Scope boundary listed 4 files but `bump-version.sh` touches 6+ source files + regenerates 6+ artifacts | Prompt didn't account for canonical pipeline side effects | Added "Scope Boundary Must Whitelist Pipeline Artifacts" constraint |
| E-5 | Assembly `--check` before `--write` after fragment edits caused false failures | Prompt ordered checkpoint before regeneration | Added constraint: always `--write` then `--check` after any fragment edit |

---

## Instructions for Prompt Producer (Claude Opus)

You are the prompt producer for the ESP32-GW Multi-Sensor Gateway project.
Read the codebase, then produce agent prompt bundles for the next batch of Phase 7 steps.

### Setup

```
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor
```

### Mandatory Reading (in order)

1. `CURRENT-STATE.md` — current version, open issues, board measurements, unimplemented recommendations. **This is the ground truth. If it contradicts the plan, CURRENT-STATE.md wins.**
2. `Docs/phase-7-review-and-rewrite.md` — THE Phase 7 plan. Read the step details for the steps you're producing.
3. `Docs/multi-phase-planning-session-summary.md` — full session record with operator decisions. Points 1-3 (retention, boards, binary sensor dedup) are essential for Batches 2-5. Point 6 (recommendation → issue routing) applies to all batches.
4. `Docs/development-process-guide.md` — **READ THE FULL DOCUMENT**, especially:
   - §2.3 (device testing: agent runs compile/upload/curl)
   - §2.5 (in-PR mandatory deliverables vs post-merge bookkeeping — **CRITICAL: consolidated audit, CURRENT-STATE.md, changelog, session log, handoff updates are all IN-PR, not post-merge**)
   - §3.2 (checkpoint authoring: queries not assertions, stop-don't-fix)
   - §3.3 (scope guards)
   - §4.1 (Assumption Audit Gate)
   - §4.3 (phase closure — relevant for final batch)
5. `Docs/writing-guide/methodology.md` — 10-section prompt anatomy
6. `prompts/prompt-index-and-workflow.md` — Critical Rules table (all current rules)
7. `AGENTS.md` — what inline reviewers see
8. The **session handoff from the last merged step** — carries-forward context
9. The **consolidated audit from the last merged step** — prompt improvements, new rules, baseline changes
10. `Docs/phase-V-capacity-study.md` §6 — EventLog design for binary sensors (relevant for Batch 2+ and especially Batch 5)
11. `Docs/v7.7-v7.8-persistence-architecture.md` — per-device key scheme, FNV-1a hash, retention budgeting (relevant for Batch 2+)
12. `Docs/decisions/decision-log.md` — Phase 7 decisions (PLAN-001 through PLAN-011)
13. `Docs/phase7-github-tracking-supplement.md` — standing rules for issue tracking, milestone management, documentation lifecycle
14. All `firmware/core/*.h` files that the new steps will modify — read the ACTUAL code, not memory

### Verify Before Producing

Run these checks to confirm codebase state. **If ANY check reveals a discrepancy between the plan (`Docs/phase-7-review-and-rewrite.md`) and the actual codebase, STOP and ask the operator for clarification before producing prompts.** The plan was written at a point in time — the codebase is the ground truth.

```bash
cat VERSION
# Should match the version of the last merged step

ls firmware/core/*.h | wc -l
# Should be 9 (after v7.7.1.0 adds health-check.h)

bash scripts/preflight.sh
# Should pass (playwright check may SKIP if node_modules missing — acceptable)

# Check the last merged step's session handoff exists
ls prompts/handoff/phase7/session-handoff-v7.7.*.md

# Check Critical Rules count (should grow over the phase)
grep -c '^| [0-9]' prompts/prompt-index-and-workflow.md

# Verify CURRENT-STATE.md "Last verified" date is recent
head -3 CURRENT-STATE.md

# Check for any new open issues since last batch
# (operator should provide issue list if gh CLI unavailable)

# Verify the Phase 7 plan's assumptions against actual code:
# - Do the functions mentioned in the plan exist at expected locations?
# - Have any structs changed since the plan was written?
# - Are there new fragments, endpoints, or dashboard modules not in the plan?
grep -n 'handle_history_\|handle_api_v2_history_\|SegmentSnapshot' firmware/core/web-handler.h | head -5
grep -n 'struct.*Segment\|struct.*Device\|struct.*Event' firmware/core/data-model.h | head -5
grep -n 'struct.*Segment\|struct.*Device\|struct.*Meta' firmware/core/nvs-persistence.h | head -5
```

### ⛔ Board Info Extraction Gate (NEW — Batch 1 post-mortem)

**Before writing ANY device testing commands in prompts**, extract the following from `CURRENT-STATE.md` "Board Fleet and Measurements" table:

```bash
# Extract board IPs, roles, and chip types
grep -A 20 'Board Fleet and Measurements' CURRENT-STATE.md | grep '|.*\.' | head -6

# Verify WROOM YAML filename from provision.sh
grep 'wroom' scripts/provision.sh | head -5

# Verify C3 YAML filename
ls firmware/esp32-c3-*.yaml

# Check WROOM board profile for generated YAML name
grep 'board_id' firmware/boards/esp32-wroom-32d.yaml
```

**Record the extracted values and use ONLY these in the prompts. Never use memorized values.**

| Board | IP | YAML | Role |
|-------|-----|------|------|
| [from CURRENT-STATE.md] | [from CURRENT-STATE.md] | [from provision.sh / board profile] | [from CURRENT-STATE.md] |

### ⛔ Spec File Path Gate (NEW — Batch 1 post-mortem)

```bash
# Verify actual Playwright spec file locations
find tests -name "*.spec.js" | sort
```

**Use ONLY the paths returned by this command in Playwright gate commands. Pre-v7.6.5.7 paths (`tests/mixed.spec.js`) are stale.**

**The prompts you produce must reflect the code as it IS, not as the plan says it should be.** If a previous step changed something the plan didn't anticipate, the prompts must account for that reality.

### Deliverables Per Step (Implementation Steps)

For each implementation step, produce:

1. **`prompts/phase7/vX.Y.Z.W-agent-prompt-gpt-codex.md`** — 10-section agent prompt (§1-§10)
2. **`prompts/phase7/vX.Y.Z.W-claude-two-step.md`** — agent section + reviewer checklist
3. **`prompts/handoff/phase7/session-handoff-vX.Y.Z.W.md`** — handoff for this step

For research steps (v7.7.5.0), produce:

1. **`prompts/phase7/vX.Y.Z.W-research-prompt.md`** — research prompt (no code, no version bump)

### GitHub Issue & Documentation Tracking Checklist

For EACH step prompt you produce, verify these tracking items are addressed:

**In the agent prompt:**
- [ ] If the step fixes a known issue: PR body template includes `Fixes #NNN`
- [ ] If the step resolves a BUG-NNN: CURRENT-STATE.md update instructions move it to resolved
- [ ] If the step discovers new issues: instructions to file GitHub issues with labels and Phase 7 milestone
- [ ] If the step adds new Critical Rules: instructions to add them to `prompts/prompt-index-and-workflow.md`
- [ ] If the step adds new LESSON-OPS entries: instructions to add them to `Docs/lessons/firmware.md`
- [ ] Decision log entry required if a new architectural decision was made during the step
- [ ] CURRENT-STATE.md update is explicitly marked MANDATORY with specific fields to update

**In the consolidated audit template:**
- [ ] §2 findings track which issues were opened/closed/updated
- [ ] §7 recommendations are routed to GitHub issues or CURRENT-STATE.md (no third option)

**In the session handoff:**
- [ ] Open issues table reflects current state after the previous step
- [ ] Any issues discovered during the previous step are noted

### Prompt Anatomy (10 Sections)

Every implementation agent prompt follows this structure:

1. **§1 — Required reading** (file list with read order)
2. **§2 — Pre-implementation verification gate** (grep checks)
3. **§3 — Scope boundary** (what IS and IS NOT in scope, with HARD/SOFT distinction)
4. **§4 — Critical rules checklist** (applicable rules from the table)
5. **§5 — Do-NOT list** (common agent mistakes to prevent)
6. **§6 — Implementation steps** (code changes, documentation updates, device testing, session log — ALL in-PR deliverables)
7. **§7 — Acceptance criteria** (checkboxes)
8. **§8 — Pipeline commands and pre-PR gate** (full regeneration + CI commands)
9. **§9 — Post-merge bookkeeping** (ONLY: tag the release, close issues via PR link — NO documentation here)
10. **§10 — Multi-LLM execution preamble** (if applicable)

### Constraints

- All file paths verified against cloned repo (grep, not memory)
- Checkpoints use queries not assertions
- Stop-don't-fix semantics on checkpoint failures
- **CURRENT-STATE.md update is an in-PR mandatory deliverable in EVERY implementation step** — the agent prompt must include explicit update instructions in §6 (version, "Last verified" date, "What Just Shipped", "Open Issues", "Unimplemented Recommendations", Architecture Quick Reference)
- **Consolidated audit is an in-PR mandatory deliverable** — the agent produces it during the PR, not after merge (development-process-guide.md §2.5 item 4)
- **Session log is an in-PR mandatory deliverable** and pre-merge acceptance criterion (Critical Rule 63)
- Checkpoint grep assertions mechanically derived from the code blocks in the same prompt (Critical Rule 64)
- PR body must include `Fixes #NNN` for any resolved GitHub issues
- PR body must reference the Phase 7 step tracking issue (for milestone progress)
- Every recommendation from consolidated audits must be routed to a GitHub issue or CURRENT-STATE.md — no third option
- **§9 contains ONLY mechanical post-merge bookkeeping** (tag, issue auto-close). If you find documentation tasks in §9, move them to §6. This is the #1 cause of missing deliverables (Phase Y: 44% omission rate when session log was in §9).

### Scope Boundary Must Whitelist Pipeline Artifacts (NEW — Batch 1 post-mortem)

When a step includes a version bump via `bash scripts/bump-version.sh`, the scope boundary (§3) MUST list all files the script directly modifies:

**Source files modified by `bump-version.sh`:**
- `VERSION`
- `scripts/render_sensor_config.py` (VERSION constant)
- `tests/fixtures/generate-fixtures.js` (VERSION constant)
- `dashboard/core/app-shell.js` (App.version)
- `firmware/core/config.h` (version comment)
- `firmware/core/data-model.h` (version comment)

**Regenerated artifacts (from pipeline scripts triggered by bump-version.sh):**
- `dashboard/dashboard.js`, `dashboard/dashboard.html` (bundle)
- `dashboard/dashboard.h` (gzip header)
- `dashboard/sensor_history_multi.h` (assembly)
- `src/gateway_manifest.h` (manifest)
- `tests/fixtures/manifest.json`, `tests/fixtures/api-status.json` (fixtures)
- `tests/fixtures/variants/*/` (variant fixtures)

The scope boundary should state: _"The following files are modified by `bump-version.sh` and the regeneration pipeline. Do NOT count changes to these files as scope violations."_

### Scope Guard: HARD vs SOFT Prohibitions (NEW — Batch 1 post-mortem)

Distinguish two types of scope prohibitions:

- **⛔ HARD** — do not cross regardless. Example: "Do not modify dashboard source logic." If the core change fundamentally requires crossing this boundary, STOP and post a PR comment.
- **⛔ SOFT (assumption-dependent)** — do not modify unless the core change breaks this file's assumptions. Example: "Do not modify `aggregator-runtime.h` — assumes encoding transparency for `/api/v2/history`." If the assumption is falsified by the core change, document the deviation in the session log and apply the minimum fix.

### Assembly and Checkpoint Ordering (NEW — Batch 1 post-mortem)

After ANY edit to a `firmware/core/*.h` fragment:
1. Run `bash scripts/assemble-sensor-history.sh --write` FIRST
2. THEN run `bash scripts/assemble-sensor-history.sh --check`
3. THEN run checkpoint greps

Never checkpoint before regeneration — the assembled artifact is stale until `--write` runs.

### Device Testing Delegation (NEW — Batch 1 post-mortem)

Per `Docs/development-process-guide.md` §2.3:

**Agent MUST do (in §6):**
- `bash scripts/provision.sh <role>` (to generate the target board YAML)
- `esphome clean`, `esphome compile`, `esphome upload` (with `timeout 300`)
- `curl` smoke tests (status, history endpoints)
- Capture and post output as PR comment
- `bash scripts/provision.sh satellite` before push (CI safety)

**Operator ONLY does:**
- Visual dashboard verification (requires browser)
- Serial log capture when UART is needed (if agent cannot access serial)
- Final merge decision

If the agent has network access to the board (it does via IP), the agent performs all curl-based verification. The agent prompt MUST include the compile+flash+curl sequence as §6 implementation steps, not as a separate post-merge "operator" section.

---

## Final Batch: Phase Closure Deliverables

**When producing the FINAL batch of any phase** (for Phase 7: Batch 5), the prompt producer produces one additional deliverable beyond the step prompts:

### Phase Closure Prompt

**File:** `prompts/phase7/phase7-closure-prompt.md`

This is a Claude advisory prompt (not an agent execution prompt). It is run in a fresh session after the final step merges. It produces the phase closure documentation.

The closure prompt must contain these sections:

**§1 — Gate on readiness (replaces separate readiness assessment)**
- Verify all Phase 7 step tracking issues are closed
- Verify all session logs exist (Rule 63)
- Verify all consolidated audits exist
- Verify CURRENT-STATE.md is current
- Verify `prompts/prompt-index-and-workflow.md` has all Critical Rules added during the phase
- If ANY gate fails: STOP and list the blocking items. Do NOT proceed to analysis.

**§2 — Issue sweep**
- Read all GitHub issues with `phase/7` label (operator provides issue list if gh CLI unavailable)
- Classify each: RESOLVED (closed by PR) / DEFERRED (moved to next phase milestone) / NEW (discovered during Phase 7, still open)
- Produce issue sweep table
- For deferred issues: specify which milestone they move to

**§3 — Closure analysis (plan vs delivery)**
- Read `Docs/phase-7-review-and-rewrite.md` (the plan) and compare to actual delivery
- For each planned step: was it delivered as planned, modified, or skipped?
- Agent autonomous decisions aggregate: how many helpful / harmful / neutral across all steps?
- Prompt quality trend: fix cycles per step over the phase
- Device test baselines: final measurements vs Phase 7 entry measurements

**§4 — KPIs**
- Steps in phase: planned vs actual
- Fix cycles per step (average)
- Wall-clock per step (estimated average)
- New bugs discovered during phase
- New Critical Rules added
- Checkpoint saves (errors caught before PR)
- Compare to Phase V and Phase VX KPIs in CURRENT-STATE.md

**§5 — Phase results summary**
- PR table: step version, PR#, agent, fix cycles, key outcome
- Critical Rules added during phase (table with numbers and text)
- LESSON-OPS entries added during phase
- Decision log entries added during phase
- Device test baselines at phase end (heap, stack watermarks, NVS utilization)

**§6 — Writing guide updates**
- New gap categories discovered during Phase 7
- Checkpoint learnings (patterns that worked, patterns that didn't)
- Prompt structure improvements to carry forward

**§7 — Recommendation routing**
- Every recommendation from this closure → either a GitHub issue or CURRENT-STATE.md entry
- No third option
- Issues get labels for the next phase milestone

**§8 — CURRENT-STATE.md comprehensive update**
- Mark Phase 7 as complete in "Active phase"
- Update "Last completed phase" to Phase 7
- Update "Active phase" to next phase (Phase E)
- Update KPI baselines table with Phase 7 row
- Move resolved issues out, add any new ones from closure analysis
- Update Architecture Quick Reference if Phase 7 changed the architecture
- Update "Planning Documents" table

**Output file:** `prompts/handoff/phase7/phase7-results.md`

This results document is the permanent project record for Phase 7. It is committed to main as the final Phase 7 deliverable. The GitHub Phase 7 milestone is closed after this document is committed.

---

## Batch-Specific Context

_Fill in this section before pasting into the session. Replace the placeholders with the actual batch details._

### Batch Number: [2 / 3 / 4 / 5-final]

### Last Merged Step: v7.7.[X.Y]

### Steps to Produce

| Step | Version | Content | Risk | Key Files Modified |
|------|---------|---------|------|--------------------|
| [N] | v7.7.[A.B] | [description from Phase 7 plan] | [Low/Medium/High] | [files] |
| [N+1] | v7.7.[C.D] | [description] | [risk] | [files] |
| [N+2] | v7.7.[E.F] | [description] | [risk] | [files] |

_If this is the final batch, add:_

| Closure | — | Phase 7 closure prompt | — | — |

### Issues to Track This Batch

| Issue | Current State | Expected State After Batch |
|-------|--------------|---------------------------|
| #139 / BUG-082 | [open/resolved] | [no change / close if not already] |
| #137 | [open] | [no change / close / update milestone] |
| [new issues from previous steps] | | |

### Is This the Final Batch?

- [ ] **YES** — also produce `prompts/phase7/phase7-closure-prompt.md` per the "Final Batch: Phase Closure Deliverables" section above
- [ ] **NO** — produce step prompts only

### Carries-Forward from Last Batch

_Copy from the last step's consolidated audit "Context That Carries Forward" and the session handoff._

[paste here]

### Additional Context for This Batch

_Any operator notes, hardware changes, or process updates since the last batch._

[paste here]

---

## Post-Production Checklist (Operator)

After the prompt producer delivers the batch:

- [ ] Review each agent prompt for:
  - [ ] File paths verified against current repo state
  - [ ] Checkpoint grep counts mechanically correct (Rule 64)
  - [ ] `Fixes #NNN` present for any issue resolutions
  - [ ] Critical Rules subset is correct and complete
  - [ ] CURRENT-STATE.md update instructions are in §6 and marked MANDATORY
  - [ ] Consolidated audit production is in §6, NOT in §9
  - [ ] Session log production is in §6, NOT in §9
  - [ ] §9 contains ONLY tag + issue close — no documentation
  - [ ] Board IPs and YAML filenames match CURRENT-STATE.md exactly
  - [ ] Playwright commands use `tests/browser/*.spec.js` paths
  - [ ] Assembly checkpoints use `--write` before `--check`
  - [ ] Scope boundary whitelists `bump-version.sh` artifacts
  - [ ] Scope guard uses HARD/SOFT distinction for prohibitions
- [ ] Review each handoff for:
  - [ ] Phase 7 progress table reflects actual state
  - [ ] Risk assessment is realistic
  - [ ] Device testing plan matches the step's changes
- [ ] Review the two-step prompts for:
  - [ ] Reviewer checklist covers the step's specific risk areas
  - [ ] External reviewer focus areas are meaningful (not generic)
  - [ ] Post-merge section says ONLY: tag, close issues
- [ ] If final batch: review the closure prompt for:
  - [ ] All 8 sections present (readiness gate through CURRENT-STATE.md update)
  - [ ] Issue list is current (operator verifies against GitHub)
  - [ ] KPI baseline numbers are from actual CURRENT-STATE.md, not estimates
- [ ] Commit all prompt files to `main`

---

## Reuse Pattern for Future Phases

This batch production prompt and closure pattern generalizes to every future phase. The process is:

### Phase Lifecycle

```
Planning session (Claude Opus advisory)
  → Phase plan document (e.g., Docs/phase-E-captive-portal-plan.md)
  → GitHub infrastructure (milestone, labels, step tracking issues, Discussion)
  → CURRENT-STATE.md updated with phase plan
  │
  ├─ Batch 1 prompt production (this template, adapted)
  │   → Step prompts → Agent execution → Review → Merge
  │   → Each step: CURRENT-STATE.md updated, tracking issue closed, consolidated audit
  │
  ├─ Batch 2 prompt production (triggered by last step of Batch 1 merging)
  │   → ... same cycle ...
  │
  ├─ ... more batches ...
  │
  └─ Final batch prompt production
      → Step prompts (same as above)
      → Phase closure prompt (additional deliverable)
      → After final step merges: run closure prompt
      → Phase results document committed
      → CURRENT-STATE.md marks phase complete
      → GitHub milestone closed
```

### Adapting for a New Phase

1. Copy this file as `prompts/handoff/phaseN-batch-production-prompt.md`
2. Replace "Phase 7" with the new phase name throughout
3. Update the trigger table with the new phase's batches (include any optimization sprints)
4. Update mandatory reading to include the new phase's plan document
5. Update the closure prompt section to reference the new phase's plan
6. The 10-section prompt anatomy, constraints, tracking checklists, and closure §1-§8 structure are phase-agnostic — keep them as-is

### Invariants Across All Phases

- CURRENT-STATE.md is always the ground truth and always updated every step
- Every step has a tracking issue closed by the PR
- Every recommendation is routed to an issue or CURRENT-STATE.md
- The prompt producer reads the actual codebase, not the plan alone
- Discrepancies between plan and code trigger operator clarification, not silent assumptions
- The final batch produces the closure prompt alongside the step prompts
- The closure prompt is the single document that handles readiness check, issue sweep, closure analysis, KPIs, results summary, writing guide updates, recommendation routing, and CURRENT-STATE.md comprehensive update
- Phase closure happens after ALL version-numbered steps in that phase, including optimization sprints
- All documentation deliverables (consolidated audit, session log, CURRENT-STATE.md, changelog, handoff updates) are IN-PR mandatory deliverables per development-process-guide.md §2.5
- §9 of every agent prompt contains ONLY post-merge bookkeeping (tag, issue auto-close)
- Board IPs, YAML filenames, and credentials are extracted from CURRENT-STATE.md, never from memory
- Scope boundaries whitelist `bump-version.sh` artifacts explicitly
- Assembly checkpoints always run `--write` before `--check`

---

_End of batch production prompt template._
