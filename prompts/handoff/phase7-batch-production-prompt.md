# Phase 7 — Batch Prompt Production Session Template

_Reusable prompt for producing agent prompt bundles for the next batch of Phase 7 steps._
_Each batch covers 3 steps. Produce this session after the previous batch's last step merges._
_Operator: paste this prompt into a Claude Opus session to produce the next batch._

---

## Trigger Table

| Batch | Trigger | Steps to Produce | Key Theme |
|-------|---------|-----------------|-----------|
| Batch 1 | Phase 7 planning complete | v7.7.0.0, v7.7.1.0, v7.7.1.1 | Research, health-check, chunked streaming |
| **Batch 2** | **v7.7.1.1 merged** | **v7.7.1.2, v7.7.1.3, v7.7.1.4** | **Per-device structs, persist write, persist restore** |
| Batch 3 | v7.7.1.4 merged | v7.7.2.1, v7.7.2.2, v7.7.2.3 | Switchover, migration, per-device delete |
| Batch 4 | v7.7.2.3 merged | v7.7.3.1, v7.7.3.2, v7.7.3.3 | Export/import, bundle, phase closure |

---

## Instructions for Prompt Producer (Claude Opus)

You are the prompt producer for the ESP32-GW Multi-Sensor Gateway project.
Read the codebase, then produce agent prompt bundles for the next three Phase 7 steps.

### Setup

```
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor
```

### Mandatory Reading (in order)

1. `CURRENT-STATE.md` — current version, open issues, board measurements, unimplemented recommendations
2. `Docs/phase-7-review-and-rewrite.md` — THE Phase 7 plan. Read the step details for the steps you're producing.
3. `Docs/development-process-guide.md` — §2-3 (execution workflow, prompt structure)
4. `Docs/writing-guide/methodology.md` — 10-section prompt anatomy
5. `prompts/prompt-index-and-workflow.md` — Critical Rules table (all current rules)
6. `AGENTS.md` — what inline reviewers see
7. The **session handoff from the last merged step** — carries-forward context
8. The **consolidated audit from the last merged step** — any prompt improvements, new rules, or baseline changes
9. `Docs/phase-V-capacity-study.md` §6 — EventLog design for binary sensors (relevant for Batch 2+)
10. `Docs/v7.7-v7.8-persistence-architecture.md` — per-device key scheme, FNV-1a hash, retention budgeting (relevant for Batch 2+)
11. `Docs/decisions/decision-log.md` — Phase 7 decisions (PLAN-001 through PLAN-011)
12. `Docs/multi-phase-planning-session-summary.md` — full session record with operator decisions (if it exists — check before reading)
13. All `firmware/core/*.h` files that the new steps will modify — read the ACTUAL code, not memory

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
ls prompts/handoff/phase7/session-handoff-v7.7.*.md

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
3. **`prompts/handoff/phase7/session-handoff-vX.Y.Z.W.md`** — handoff for this step

### GitHub Issue & Documentation Tracking Checklist

For EACH step prompt you produce, verify these tracking items are addressed:

**In the agent prompt:**
- [ ] If the step fixes a known issue: PR body template includes `Fixes #NNN`
- [ ] If the step resolves a BUG-NNN: CURRENT-STATE.md update instructions move it to resolved
- [ ] If the step discovers new issues: instructions to file GitHub issues with labels and Phase 7 milestone
- [ ] If the step adds new Critical Rules: instructions to add them to `prompts/prompt-index-and-workflow.md`
- [ ] If the step adds new LESSON-OPS entries: instructions to add them to `Docs/lessons/firmware.md`
- [ ] Decision log entry required if a new architectural decision was made during the step

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
- **CURRENT-STATE.md update is a mandatory deliverable in EVERY implementation step** — the agent prompt must include explicit update instructions (version, "What Just Shipped", "Open Issues", "Unimplemented Recommendations", Architecture Quick Reference)
- Session log is a pre-merge acceptance criterion (Critical Rule 63)
- Checkpoint grep assertions mechanically derived from the code blocks in the same prompt (Critical Rule 64)
- PR body must include `Fixes #NNN` for any resolved GitHub issues
- PR body must reference the Phase 7 step tracking issue (for milestone progress)
- Every recommendation from consolidated audits must be routed to a GitHub issue or CURRENT-STATE.md — no third option

---

## Future Phase Prompt Production Pattern

This batch production template is designed for Phase 7 but the process generalizes to future phases. When Phase 7 closes and the next phase begins:

1. **Run the multi-phase planning session** (per `Docs/multi-phase-session-run-instructions.md`) to produce the phase plan
2. **Create GitHub infrastructure** — milestone, labels, step tracking issues, and a planning Discussion (use the post-session action script from `Docs/multi-phase-planning-session-summary.md`)
3. **Adapt this batch production prompt** — replace "Phase 7" with the new phase name, update the trigger table, update mandatory reading list to include the new phase plan
4. **Produce batch 1 prompts** — paste the adapted prompt into a Claude Opus session
5. **Execute, review, merge** — each step updates CURRENT-STATE.md, closes its tracking issue, produces a consolidated audit
6. **Produce next batch** — after the batch's last step merges, repeat from step 4

The invariants across all phases:
- CURRENT-STATE.md is always the ground truth and always updated
- Every step has a tracking issue closed by the PR
- Every recommendation is routed to an issue or CURRENT-STATE.md
- The prompt producer reads the actual codebase, not the plan alone
- Discrepancies between plan and code trigger operator clarification, not silent assumptions

---

## Batch-Specific Context

_Fill in this section before pasting into the session. Replace the placeholders with the actual batch details._

### Batch Number: [2 / 3 / 4]

### Last Merged Step: v7.7.[X.Y]

### Steps to Produce

| Step | Version | Content | Risk | Key Files Modified |
|------|---------|---------|------|--------------------|
| [N] | v7.7.[A.B] | [description from Phase 7 plan] | [Low/Medium/High] | [files] |
| [N+1] | v7.7.[C.D] | [description] | [risk] | [files] |
| [N+2] | v7.7.[E.F] | [description] | [risk] | [files] |

### Issues to Track This Batch

| Issue | Current State | Expected State After Batch |
|-------|--------------|---------------------------|
| #139 / BUG-082 | [open/resolved] | [no change / close if not already] |
| #137 | [open] | [no change / close / update milestone] |
| [new issues from previous steps] | | |

### Carries-Forward from Last Batch

_Copy from the last step's consolidated audit §5 "Context That Carries Forward" and the session handoff._

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
  - [ ] CURRENT-STATE.md update instructions are accurate
- [ ] Review each handoff for:
  - [ ] Phase 7 progress table reflects actual state
  - [ ] Risk assessment is realistic
  - [ ] Device testing plan matches the step's changes
- [ ] Review the two-step prompts for:
  - [ ] Reviewer checklist covers the step's specific risk areas
  - [ ] External reviewer focus areas are meaningful (not generic)
- [ ] Commit all prompt files to `main`
- [ ] Verify `Docs/multi-phase-planning-session-summary.md` is committed (if it exists locally)

---

_End of batch production prompt template._
