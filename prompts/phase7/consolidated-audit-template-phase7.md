# Phase 7 — Consolidated Audit Template

_Copy this file as `prompts/phase7/v7.7.X.Y-PR<NN>-consolidated-audit-and-lessons.md` after each step merges._
_Fill in every section. Do not leave sections blank — write "N/A" or "None" if not applicable._

---

# Consolidated Audit — v7.7.X.Y: [Step Title]

_Phase 7 Step [ID]. Completed [date]._
_PR #[NN] (`[branch-name]`)._
_Merge commit: `[sha]`._
_Agent: [Copilot / Codex / GPT / Kiro]._

---

## §1 — PR Metadata

| Field | Value |
|-------|-------|
| PR Number | #[NN] |
| Branch | `[branch-name]` |
| Step Version | v7.7.X.Y |
| Executing Agent | [agent name] |
| Inline Reviewers | [Copilot, Codex, Gemini — list which participated] |
| External Reviewers | [GPT, Codex, Perplexity — list which participated] |
| Device Testing | [YES / NO / CRITICAL] |
| Fix Cycles | [0 / 1 / 2 / ...] |

---

## §2 — Findings by Severity

Record ALL findings from ALL reviewers. Include the reviewer source for each finding.

### Critical

| # | Finding | Source | Fixed? | Commit | Notes |
|---|---------|--------|--------|--------|-------|
| | | | | | |

### High

| # | Finding | Source | Fixed? | Commit | Notes |
|---|---------|--------|--------|--------|-------|
| | | | | | |

### Medium

| # | Finding | Source | Fixed? | Commit | Notes |
|---|---------|--------|--------|--------|-------|
| | | | | | |

### Low / Info

| # | Finding | Source | Warranted? | Notes |
|---|---------|--------|-----------|-------|
| | | | | |

---

## §3 — Agent Autonomous Decisions

List every change the agent made that was NOT explicitly specified in the prompt. Classify each.

| # | Decision | Classification | Impact |
|---|----------|---------------|--------|
| | | Helpful / Harmful / Neutral / Scope violation | |

**Scope violation policy:** Any scope violation is a Blocking finding. If the violation was beneficial, back-port it into the prompt for reproducibility and document in §4.

---

## §4 — Prompt Quality Score

| Metric | Value | Notes |
|--------|-------|-------|
| Fix cycles | [0/1/2/...] | Times PR needed additional commits after review |
| Checkpoint saves | [N] | Checkpoints that caught errors before they became PR findings |
| Preventable review findings | [N] | Review findings the prompt should have prevented |
| Agent autonomous decisions | [N] (H/N/S) | Helpful / Neutral / Scope violation |
| **Overall score** | [1-5] | 5=perfect, 4=minor gaps, 3=functional gaps, 2=major gaps, 1=rewrite needed |

**Justification:** [1-2 sentences explaining the score]

**Prompt improvements for next step:** [List any changes to make to subsequent prompts based on this step's experience]

---

## §5 — Acceptance Criteria Checklist

Copy each criterion from the agent prompt §7 (Acceptance Criteria). Mark each PASS or FAIL with evidence.

| # | Criterion (from agent prompt §7) | PASS/FAIL | Evidence |
|---|---|---|---|
| 1 | [copy verbatim] | | [grep output, test result, etc.] |
| 2 | | | |
| 3 | | | |

---

## §6 — Device Test Results

_Fill in as part of the in-PR §6 acceptance criteria BEFORE marking the PR ready. If device testing
is not applicable for this step, write "N/A — no device testing required." Per
`Docs/development-process-guide.md` §2.5 deliverable 1 (consolidated audit), device test results
are an in-PR mandatory deliverable — not a post-merge activity._

### Test Matrix

| Test | Board | IP | Result | Evidence |
|------|-------|-----|--------|----------|
| [from agent prompt §6 Task Group device testing] | [C3/WROOM/S3] | [.189/.170/.191] | PASS/FAIL | [curl output, serial log excerpt, heap values] |

### Measurements (Phase 7 Baseline Tracking)

| Metric | C3 (.189) | WROOM (.170) | S3 (.191) | Notes |
|--------|-----------|-------------|-----------|-------|
| free_heap (boot) | | | | |
| min_free_heap | | | | |
| httpd_stack_wm | | | | |
| nvs_used_entries | | | | |
| nvs_free_entries | | | | |
| Peak heap during history serve | | | | v7.7.1.1+ only |

_Compare against baselines in `Docs/board-measurement-log-v7.6.10.md` and v7.7.1.0 health-check output._

**If any test failed:** describe symptom, link to bug escalation if used, note whether deferred or fixed in follow-up.

---

## §7 — Recommendations for Next Step

### GitHub Issue State Changes This Step

| Issue # | Title | Action | PR Reference |
|---------|-------|--------|-------------|
| [step tracking issue] | Phase 7: v7.7.X.Y: ... | Closed via PR | `Closes #NNN` in PR body |
| | | | |

_List every issue opened, closed, updated, or commented on during this step. Every recommendation from this audit must be routed to either a GitHub issue or CURRENT-STATE.md "Unimplemented Recommendations" — no third option._

### Must-do before v7.7.[next]

- [ ] [Any blocking items discovered during this step]

### Should-do (improve next step's prompt)

- [ ] [Prompt improvements based on agent behavior or review findings]

### Observation (no action required)

- [ ] [Interesting findings that don't require immediate action]

### New Critical Rules (candidates)

| # | Candidate Rule | Source |
|---|---------------|--------|
| [next #] | [rule text] | [this audit] |

### New Lessons (candidates)

| # | Candidate Lesson | Source |
|---|-----------------|--------|
| LESSON-OPS-[next] | [lesson text] | [this audit] |

---

## Delivery Status

| Item | Status |
|------|--------|
| Code changes per §6 of agent prompt | |
| ⛔ CHECKPOINT gates verified | |
| Preflight passes | |
| Assembly check passes (if fragments edited) | |
| Playwright all fixture sets green | |
| Session log created (Rule 63) | |
| Changelog entry | |
| CURRENT-STATE.md updated | |
| Instruction Compliance Output in PR | |
| External reviewer feedback addressed | |
| Device testing results recorded | |
| **Consolidated audit (this document)** | ✅ |
| **Next step handoff/prompt inspected** | |

---

## Next Step Inspection Results

**Handoff reviewed:** `prompts/handoff/phase7/session-handoff-v7.7.[next].md`
**Agent prompt reviewed:** `prompts/phase7/v7.7.[next]-agent-prompt-gpt-codex.md`
**Claude two-step reviewed:** `prompts/phase7/v7.7.[next]-claude-two-step.md`

**Updates needed?**
- [ ] No updates needed — plan assumptions still valid
- [ ] Line numbers updated (specify which)
- [ ] Function signatures updated (specify which)
- [ ] Carries-forward section updated with actual results
- [ ] New checkpoint added based on this step's findings

---

_End of consolidated audit._
