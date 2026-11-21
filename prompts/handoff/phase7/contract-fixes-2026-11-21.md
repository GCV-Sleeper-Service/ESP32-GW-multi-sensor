# R5a.1 — Contract fixes record

## §1 Why

R5a.1 is the low-risk documentation step that applies producer-contract fixes before R5b, as routed by issue #242 and comment 7060767358. It preserves PLAN-012 and PLAN-017 constraints while recording PLAN-042 as the governing decision for order, compile-before-dispatch wording, escaped-defect metric interpretation, and review-question clarifications.

## §2 Edit list

| Item | Check | Observed output |
|---|---|---|
| 1.1 | A | CHECKPOINT A PASS |
| 1.2 | A | CHECKPOINT A PASS |
| 1.3 | A | CHECKPOINT A PASS |
| 1.4 | A | CHECKPOINT A PASS |
| 1.5 | A | CHECKPOINT A PASS |
| 2.1 | B | CHECKPOINT B PASS |
| 2.2 | B | CHECKPOINT B PASS |
| 2.3 | B | CHECKPOINT B PASS |
| 3.1 | C | CHECKPOINT C PASS |
| 3.2 | C | CHECKPOINT C PASS |
| 3.3 | C | CHECKPOINT C PASS |
| 3.4 | C | CHECKPOINT C PASS |
| 3.5 | copy; C | copied 2 files; CHECKPOINT C PASS |

## §3 Review findings by severity

pending

## §4 Agent autonomous decisions

none

## §5 Prompt Quality Score

pending

## §6 Operator decisions recorded by this PR

| ID | Decision | Reason |
|---|---|---|
| PLAN-042 | R5a.1 comes before R5b as its own small LOW documentation PR, with lint and one internal sub-agent audit round, the inline round and review A; it fixes the findings of issue #242 and its comment 7060767358. Every prompt that carries code ending in a compiled artifact is compiled before dispatch, at every tier. The agent writes lesson entries in the PR, and the operator gives their numbers before the merge. The escaped-defects metric counts the unique defects of a bundle found after dispatch: 7 for R5a. The answers to review A's Q1 to Q3 of comment 7060381647 | The reviews of PR #241 found seven defects in fixed texts that the agent could not fix there; HowTo §5.3 item 5 and PLAN-017 compile all code that a prompt carries, while the contract, the process guide and the audit template said HIGH only; the metric compares the producer's gates across steps (process guide §4.3 item 8), so one reading is fixed before R5b |

## §7 Operator bookkeeping

Issue #242 closes at the merge through the line `Fixes #242` of the PR body; no milestone changes, and the step has no tag.

## §8 Process metrics

| Metric | Value |
|---|---|
| producer sessions for this step's prompt | pending |
| audit sessions for this step's prompt | pending |
| fix-cycle commits after the first review round | 0 |
| defects that escaped the prompt gates into agent execution | 0 |
| defects that escaped to devices | 0 |

## §9 Recommendations and where each was routed

none