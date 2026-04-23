# Phase VX — Consolidated Audit Template

_Copy this file as `prompts/phaseVX/v7.6.10.X-PRNN-consolidated-audit-and-lessons.md` after each step merges._
_Fill in every section. Do not leave sections blank — write "N/A" or "None" if not applicable._

---

# Consolidated Audit — v7.6.10.X: [Step Title]

_Phase VX Step [ID]. Completed [date]._
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

[Candidates only — numbered and sourced. Final numbering assigned during Phase VX closure.]

### 5. Context that carries forward to next step

[What the next step's handoff/prompt needs to know that differs from the plan.]

---

## Acceptance Criteria Verification

Copy each criterion from the agent's implementation prompt §6. Mark each PASS or FAIL with evidence.

| # | Criterion (from agent prompt §6) | PASS/FAIL | Evidence |
|---|---|---|---|
| 1 | [copy verbatim from §6] | | |
| 2 | | | |

---

## External Reviewer Issues and Resolutions

Record findings from all external reviewers (Codex, GPT, Copilot, Perplexity, Kiro).

| Source | Finding | Severity | Warranted? | Fixed? | Commit | Classification |
|--------|---------|----------|-----------|--------|--------|----------------|
| | | | | | | |

---

## Compilation Evidence

_Phase VX specific: record binary sizes for all boards that compiled._

| Board | Binary size | RAM % | Flash % | Compile result |
|---|---|---|---|---|
| | | | | |

---

## Device Test Results

_Phase VX specific: record post-merge device test results (operator-executed)._

| Board | IP | Flashed? | free_heap | httpd_stack_wm | Stress min_wm | Pass? |
|---|---|---|---|---|---|---|
| | | | | | | |

---

## Session Log Verification

| Check | Status |
|---|---|
| Session log file exists at `Docs/session-log-YYYY-MM-DD-v7.6.10.X.md`? | |
| Instruction Compliance Output table in PR description? | |
| All ⛔ CHECKPOINTs documented with pass/fail? | |

---

## Prompt Index Update

| Check | Status |
|---|---|
| `prompts/prompt-index-and-workflow.md` updated with this step? | |
| Step status changed from queued to complete? | |
| PR number recorded? | |

---

## Summary

| Metric | Value |
|---|---|
| Files changed | |
| Files added | |
| Insertions | |
| Deletions | |
| New Critical Rules | |
| New BUG entries | |
| New LESSON entries | |
| Boards that compiled | |
| Boards that failed | |

---

_End of consolidated audit._
