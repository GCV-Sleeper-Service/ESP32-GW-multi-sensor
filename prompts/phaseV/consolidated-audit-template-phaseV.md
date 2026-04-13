# Phase V — Consolidated Audit Template

_Copy this file as `prompts/phaseV/v7.6.X.Y-PR<NN>-consolidated-audit-and-lessons.md` after each step merges._
_Fill in every section. Do not leave sections blank — write "N/A" or "None" if not applicable._

---

# Consolidated Audit — v7.6.X.Y: [Step Title]

_Phase V Step [ID]. Completed [date]._
_PR #[NN] (`[branch-name]`)._
_Merge commit: `[sha]`._

---

## Internal Audit (Architectural Advisor)

### 1. Did the PR match the scope defined in the step prompt? Any deviations?

[Classify each deviation: Addition, Omission, Autonomous decision, Scope violation]

### 2. Did the codebase state match the prompt's assumptions?

[Line numbers, function signatures, file locations — any drift from what the prompt specified?]

### 3. Autonomous decisions not specified in the prompt?

[List each with classification: harmless / risky / scope violation. Back-port any warranted decisions into the prompt for reproducibility.]

### 4. New lessons or Critical Rules?

[Candidates only — numbered and sourced. Final numbering assigned during Phase V closure.]

### 5. Context that carries forward to next step

[What the next step's handoff/prompt needs to know that differs from the plan.]

---

## Acceptance Criteria Verification

| # | Criterion (from §6) | PASS/FAIL | Evidence |
|---|---|---|---|
| 1 | | | |
| 2 | | | |

---

## External Reviewer Issues and Resolutions

| Source | Finding | Severity | Warranted? | Fixed? | Commit | Classification |
|--------|---------|----------|-----------|--------|--------|----------------|
| | | | | | | |

---

## Delivery Status

| Item | Status |
|------|--------|
| Code changes per §5 | |
| ⛔ CHECKPOINT gates verified | |
| Preflight passes | |
| Assembly check passes (if fragments edited) | |
| Playwright all fixture sets green | |
| Session log created | |
| Changelog entry | |
| Instruction Compliance Output in PR | |
| Device testing results (if applicable) | |
| **Consolidated audit (this document)** | ✅ |
| **Next step handoff/prompt inspected** | |

---

## Next Step Inspection Results

**Handoff reviewed:** `prompts/handoff/phaseV/session-handoff-v7.6.X.Y.md`
**Agent prompt reviewed:** `prompts/phaseV/v7.6.X.Y-agent-prompt-gpt-codex.md`

**Updates needed?**
- [ ] No updates needed — plan assumptions still valid
- [ ] Line numbers updated (specify which)
- [ ] Function signatures updated (specify which)
- [ ] Carries-forward section updated with actual results

---

_End of consolidated audit._
