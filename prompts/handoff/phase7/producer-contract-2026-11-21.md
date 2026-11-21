# R5a — Producer contract: record of this step

PR: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/241

## §1 Why

R5a establishes the producer contract and batch-production prompt v3.0 before R5b re-produces Batch 2. PLAN-012 requires v3.0 to be shorter than v2.0; PLAN-025 moves the tracking supplement unchanged to the archive; PLAN-029 keeps AGENTS.md as the source of reviewer rules. PLAN-038 to PLAN-041 record the contract, Gemini style guide, internal producer audits and model decisions. This documentation step changes no version and contacts no board.

## §2 Edit list

| Item | Check | Observed output |
|---|---|---|
| 1.1 | copy 1; A | copied 3 files; CHECKPOINT A PASS |
| 2.1 | B | CHECKPOINT B PASS |
| 2.2 | B | CHECKPOINT B PASS |
| 2.3 | B | CHECKPOINT B PASS |
| 2.4 | B | CHECKPOINT B PASS |
| 2.5 | B | CHECKPOINT B PASS |
| 2.6 | B | CHECKPOINT B PASS |
| 2.7 | B | CHECKPOINT B PASS |
| 2.8 | B | CHECKPOINT B PASS |
| 2.9 | B | CHECKPOINT B PASS |
| 2.10 | B | CHECKPOINT B PASS |
| 2.11 | B | CHECKPOINT B PASS |
| 2.12 | B | CHECKPOINT B PASS |
| 2.13 | B | CHECKPOINT B PASS |
| 2.14 | B | CHECKPOINT B PASS |
| 2.15 | move; B | moved 1 file; CHECKPOINT B PASS |
| 3.1 | copy 3; C | copied 4 files; CHECKPOINT C PASS |

## §3 Review findings by severity

pending

## §4 Agent autonomous decisions

none

## §5 Prompt Quality Score

pending

## §6 Operator decisions recorded by this PR

| ID | Decision | Reason |
|---|---|---|
| PLAN-038 | The producer contract holds the binding rules of a bundle, the planner rules from review findings and from the audit of R5r, and the tracking rules; batch prompt v3.0 replaces version 2.0; a long text reaches the agent as a supplied file; the form of the review file; the tracking supplement moves to the archive; R5a is LOW, with an internal audit and no external auditor, and reviews A and B by the runner are to run on its PR | One source of producer rules of about 150 lines (HowTo §5.4); v3.0 shorter than v2.0 (PLAN-012); R5c and R5r handed over their long texts as supplied files, and each arrived byte for byte |
| PLAN-039 | The Gemini inline reviewer gets `.gemini/styleguide.md`, which copies four parts of `AGENTS.md` word for word | Google's pages name `.gemini/styleguide.md` and do not name `AGENTS.md`; without the file Gemini reviews without the rules of the project |
| PLAN-040 | An internal sub-agent audit before each external audit, at most two rounds; the bundle and the gate record in the planning repository | In the R5r trial the internal executing checks found every defect that would have stopped the agent, and the external auditor found more gaps in the text; both are needed |
| PLAN-041 | Gemini 4 Neon is the second auditor of a HIGH prompt; the runner stays the default for review B with its model list; each planning session checks the runner's models on Google's lifecycle page | The operator's choice of 2026-11-21; Neon and Argon are both selectable in AI Studio, and Neon is not yet on Agent Platform |

## §7 Operator bookkeeping

No issue closes in this step, and no milestone changes. After the merge the operator marks §E of issue #228 closed in the status table of its body, with the number of this pull request.

## §8 Process metrics

| Metric | Value |
|---|---|
| Producer sessions for this step's prompt | pending |
| Audit sessions for this step's prompt | pending |
| Fix-cycle commits after the first review round | 0 |
| Defects that escaped the prompt gates into agent execution | 0 |
| Defects that escaped to devices | 0 |

## §9 Recommendations and where each was routed

The prescribed CURRENT-STATE.md rows route runner regression tests, commit-pinned inputs, unverified answer filtering, CI evidence, profiles and model comparisons to the operator's later runner-hardening step. The Audit Gate Notice inconsistency is routed to the next PR that changes AGENTS.md. The existing CI action-runtime warning remains recorded for operator scheduling. No additional recommendation arose during implementation.
