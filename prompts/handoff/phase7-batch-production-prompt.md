# Phase 7 — Batch Prompt Production Session Template

_Reusable prompt for producing agent prompt bundles for the next batch of Phase 7 steps._
_Each batch covers 2-3 steps. Produce this session after the previous batch's last step merges._
_Operator: paste this prompt into a Claude Opus session to produce the next batch._
_The final batch also produces the phase closure prompt._

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
4. `Docs/development-process-guide.md` — §2-3 (execution workflow, prompt structure), §4.3 (phase closure — relevant for final batch)
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
# Should pass

# Check the last merged step's session handoff exists
ls prompts/handoff/Phase7/session-handoff-v7.7.*.md

# Check Critical Rules count (should grow over the phase)
grep -c '^|' prompts/prompt-index-and-workflow.md | head -1

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
```

**The prompts you produce must reflect the code as it IS, not as the plan says it should be.** If a previous step changed something the plan didn't anticipate, the prompts must account for that reality.

### Deliverables Per Step (Implementation Steps)

For each implementation step, produce:

1. **`prompts/phase7/vX.Y.Z.W-agent-prompt-gpt-codex.md`** — 10-section agent prompt (§1-§11)
2. **`prompts/phase7/vX.Y.Z.W-claude-two-step.md`** — agent section + reviewer checklist
3. **`prompts/handoff/Phase7/session-handoff-vX.Y.Z.W.md`** — handoff for this step

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
1. Required reading (file list with read order)
2. Pre-implementation verification gate (grep checks)
3. Scope boundary (what IS and IS NOT in scope)
4. Critical rules checklist (applicable rules from the table)
5. Do-NOT list (common agent mistakes to prevent)
6. Implementation steps (with session log reference)
7. Acceptance criteria (checkboxes)
8. Pipeline commands (full regeneration + CI commands)
9. Verification gate (post-implementation checks)
10. Post-merge deliverables (CURRENT-STATE.md, changelog, session log)

### Constraints

- All file paths verified against cloned repo (grep, not memory)
- Checkpoints use queries not assertions
- Stop-don't-fix semantics on checkpoint failures
- **CURRENT-STATE.md update is a mandatory deliverable in EVERY implementation step** — the agent prompt must include explicit update instructions (version, "Last verified" date, "What Just Shipped", "Open Issues", "Unimplemented Recommendations", Architecture Quick Reference)
- Session log is a pre-merge acceptance criterion (Critical Rule 63)
- Checkpoint grep assertions mechanically derived from the code blocks in the same prompt (Critical Rule 64)
- PR body must include `Fixes #NNN` for any resolved GitHub issues
- PR body must reference the Phase 7 step tracking issue (for milestone progress)
- Every recommendation from consolidated audits must be routed to a GitHub issue or CURRENT-STATE.md — no third option

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

**Output file:** `prompts/handoff/Phase7/phase7-results.md`

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
  - [ ] CURRENT-STATE.md update instructions are accurate and marked MANDATORY
- [ ] Review each handoff for:
  - [ ] Phase 7 progress table reflects actual state
  - [ ] Risk assessment is realistic
  - [ ] Device testing plan matches the step's changes
- [ ] Review the two-step prompts for:
  - [ ] Reviewer checklist covers the step's specific risk areas
  - [ ] External reviewer focus areas are meaningful (not generic)
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

---

_End of batch production prompt template._
