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

Inline round on implementation commit d8acfa017905c146b01df140a9a50de73196e01c: no Blocking, High, Medium, Low or Cosmetic findings were posted. No implementation fix was warranted.

| Reviewer | Result | Assessment and disposition |
|---|---|---|
| Codex | Completed with no findings | The automatic review completed without findings; the operator's additional manual request also completed, with a receipt stating no major issues. No change required. |
| Gemini | Completed with no findings | Its review of 2026-11-21 06:53:46 UTC reported no comments or feedback. Its initial unsupported-file-types response preceded the completed review. No change required. |
| Copilot | Posted, incomplete | The COMMENTED review reported no open issues, but expressly said it could not complete the selected tier because of model policy or plan restrictions. Counted as no complete review, per PLAN-032. |

The prescribed review comment was posted at 2026-11-21 06:50:51 UTC. All three reviewers posted within the 30-minute window; none was absent. No inline threads were present when assessed. Review C does not run on this documentation step.

### Later reviews and comments

| Reviewer / source | Reviewed head | Result and coverage |
|---|---|---|
| Codex security review, comment 7059063682 | f268404 | No Blocking, High or Medium security findings; posted after the inline assessment and now recorded. |
| Review A, Claude Opus 5.5, effort xhigh, comment 7059851432 | f268404 | Two Medium findings, five Low findings and three questions. The reviewer read the full diff and source evidence but did not execute the check file; its tool permissions refused the adapted copy. |
| Review B, runner gemini-4-hydrogen, thinking HIGH, comment 7059995778 | f268404 | Confirmed review A's findings, added one Low diagnostic issue, and identified the incomplete record and evidence missing from the runner's inputs. Prompt and review-file hashes match the dispatched specification. |

All findings below were checked against repository sources. Review comments are evidence; they do not authorize changes to the fixed supplied texts or Task Group 2. No Blocking or High finding was posted. The operator has routed all seven fixed-text findings to [issue #242](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/242): six fixes in R5a.1 before R5b, and the check-file diagnostic as a lesson only. They are not fixed in this PR. The answers and routing are confirmed by [operator comment 7060381647](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/241#issuecomment-7060381647) and the issue body.

### Medium

| Finding | Assessment and evidence | Disposition |
|---|---|---|
| A M1; B S3: contract 9.2 weakens the negative-test requirement | Warranted. The planner page on base 104b726 requires every behaviour test to fail with no implementation and with a refusing implementation. Contract 9.2 says supplied tests fail, allowing a reading in which only the suite must fail. The earlier R5r audit records tests passing without a script. | Routed by the operator to issue #242, R5a.1 before R5b: restore the requirement for each behaviour test. The supplied contract is immutable in this PR. |
| A M2; B S3: contract 8.1 narrows the rule from tests to checks | Warranted. The removed planner rule covered any test depending on unspecified order or spelling. Contract 8.1 sits in the check-file rule and says no check; rules 9.2 and 9.3 do not explicitly prohibit supplied tests rejecting a valid implementation. R5r audit item 9 records shared-log and header-case defects. | Routed by the operator to issue #242, R5a.1 before R5b: explicitly cover supplied tests and checks, including unspecified shared state. No supplied text changed. |

### Low

| Finding | Assessment and evidence | Disposition |
|---|---|---|
| A L1: enforcement tags on contract 2.3, 3.1, 4.4 and 7.4 | Warranted as a precision issue. L4/L5 detect two specific stale WROOM literals, L10 rejects main checkouts inside agent-prompt code fences but does not require a branch check, the section 2 gate verifies anchor presence, and the scope gate verifies allowed paths rather than rehearsal provenance. | Routed by the operator to issue #242, R5a.1 before R5b: qualify lint coverage and add the specified judgment/rehearsal/section 2 tags. |
| A L2: contract 3.4 and 9.7 leave the compile tier ambiguous | Warranted as an ambiguity. Rule 3.4 covers prescribed code that becomes a compiled artifact; 9.7 explicitly lists the compile for HIGH, while 5.2 permits MEDIUM interface prescriptions. | Routed by the operator to issue #242, R5a.1 before R5b: align contract 3.4/9.7 and process guide 3.1 on compile scope, with the operator's decision. No tier policy chosen by the agent. |
| A L3: batch v3.0 verification output is truncated | Warranted as an extraction hazard. The three source searches end in head -5, while the live-extract requirements call for every named signature/value. A truncated search alone is insufficient evidence of completeness, even though the later prose still requires full extraction. | Routed by the operator to issue #242, R5a.1 before R5b: drop head -5 from the three verification searches. |
| A L4; B AC7: record provenance and missing later security review | Warranted. The previous record filled the session counts from gate-record comment 7058792444 before the operator's explicit metrics comment 7059068448. The values were correct but the timing/provenance was wrong. The security review was posted after that record commit. | Fixed here: section 8 cites the explicit operator confirmation; section 4 records the premature choice; this section adds security review, reviews A/B and every disposition. |
| A L5: contract 8.6 leaves lesson-entry ownership/timing unclear | Warranted as a clarification. The archive names agent in PR or operator, while the contract says the operator assigns lesson numbers without explicitly assigning entry creation or its timing. | Routed by the operator to issue #242, R5a.1 before R5b: name who writes the lesson entry and require it in the PR. |
| B new Low: checkpoint B diagnostic says four new rows | Warranted. The R5r heredoc contains five following rows, and the assertion compares all five; only the failure message says four. The reviewed approximate line was inaccurate: the committed diagnostic is at line 268. | Routed to issue #242 as a lesson only, with no fix: the check file is history after merge. Preserve the dispatched check file and expected hashes; this is a diagnostic defect, not a failing assertion. |

### Questions and runner evidence limits

| Item | Assessment and disposition |
|---|---|
| A Q1: command-rehearsal exception | Answered by operator comment 7060381647: rule 1.5's exception is accepted. A board command is checked against AGENTS.md "Device Testing" and the operator's latest fleet output. Issue #242 records the wording change for R5a.1 before R5b. |
| A Q2: secrets in arguments versus environment-based curl | Answered by operator comment 7060381647: the rule covers the written text of a command and the checks of a check file. AGENTS.md's curl -u "$ESP_USER:$ESP_PASS" stays allowed. Issue #242 records the clarification for R5a.1 before R5b; no board or credential was accessed. |
| A Q3; B S7: fidelity to private operator decisions | Confirmed by operator comment 7060381647: PLAN-038 to PLAN-041 state the operator's decisions of 2026-11-19 and 2026-11-21. The earlier evidence gap is resolved by this explicit confirmation; the 1/0 metrics confirmation remains separately recorded. |
| B AC7 | Fixed by this completed review record and corrected metrics provenance. The PR body must reflect the updated record and final-head PRE-PR evidence. |
| B AC6 | Runner input limitation, not an observed CI failure. Direct GitHub inspection confirms all three required checks succeeded on f268404. Checks must pass again on the record-fix head before merge. |
| B S1 | The lint implementations and check-file assertions were read directly; the four tag-coverage concerns are recorded as A L1, not represented as resolved by passing lint. |
| B S6 | The supplied style guide and AGENTS.md were inspected locally; checkpoint A/PRE-PR recompare the four copied parts exactly. Review A independently read the vendor pages. This round does not independently reverify Google's documentation; absence from runner inputs is not proof of a content defect. |
| B advice: rerender or follow-up | The operator chose issue #242 and R5a.1 before R5b, with no change to fixed texts in this PR. The agent records that routing only; no issue or fixed text is edited here. |

## §4 Agent autonomous decisions

One harmful process choice in the inline round: the agent treated the gate record's forecast of producer/audit session counts as the operator's final metrics confirmation and filled them early. The values did not change, but the source and timing were wrong. A L4 exposed this; the present record cites the later explicit operator comment and preserves the history of the correction. No other implementation choice was taken outside the prompt.

## §5 Prompt Quality Score

Prompt Quality Score:

- Fix cycles: 1
- Checkpoint saves: 0
- Preventable review findings: 8
- Agent autonomous decisions: 1 (helpful: 0; harmful: 1; neutral: 0)

The supplied instructions executed through all checkpoints without a mismatch. The eight findings are the two Medium and five Low findings from A plus B's diagnostic issue; B's repeated findings are not counted twice. Seven concern fixed producer texts; one is the agent's record defect. The current record correction is one fix-cycle commit after review, whereas the first routine inline-assessment commit contained no corrective fix. No PRE-PR recovery was used. Passing execution gates did not detect the two weakened producer rules.

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
| Producer sessions for this step's prompt | 1 |
| Audit sessions for this step's prompt | 0 |
| Fix-cycle commits after the first review round | 1 |
| Defects that escaped the prompt gates into agent execution | 7 |
| Defects that escaped to devices | 0 |

Producer and audit counts come from the operator's explicit metrics comment 7059068448 on PR #241. They confirm 1 and 0; internal producer-audit rounds are excluded per PLAN-037/PLAN-040. The earlier gate record had forecast the same values but was not the final metrics confirmation. Corrected in R5a.1 (PLAN-042; issue #242, comment 7060767358): the execution-defect count is the seven fixed-text findings of issue #242 (review A's M1, M2, L1, L2, L3 and L5, and review B's check-file diagnostic), the unique defects of the bundle that the producer's gates and audits missed and that were found after dispatch. The count was 1 before, the premature metrics/provenance choice in A L4; that is an error of the agent's own, and section 4 records it. No device was contacted.

## §9 Recommendations and where each was routed

The prescribed CURRENT-STATE.md rows route runner regression tests, commit-pinned inputs, unverified answer filtering, CI evidence, profiles and model comparisons to the operator's later runner-hardening step. The Audit Gate Notice inconsistency is routed to the next PR that changes AGENTS.md. The existing CI action-runtime warning remains recorded for operator scheduling.

| Recommendation | Destination and current state |
|---|---|
| A M1/M2 and L1/L2/L3/L5; Q1/Q2 clarifications | Routed by the operator to [issue #242](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/242), R5a.1: a small LOW documentation PR before R5b, with a decision row for the order. Six fixed-text findings are tracked for fixes there; none is fixed in this PR. |
| B diagnostic count | The seventh fixed-text finding is recorded in issue #242 as a lesson only, no fix. The assertion tests five rows correctly; the historic check file and its four-row diagnostic stay unchanged. |
| Q1: rule 1.5's exception | Accepted by [operator comment 7060381647](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/241#issuecomment-7060381647). Check board commands against AGENTS.md "Device Testing" and the operator's latest fleet output; wording is tracked in issue #242. |
| Q2: credential rule scope | The same operator comment confirms that the rule covers written command text and check-file checks; AGENTS.md's curl -u "$ESP_USER:$ESP_PASS" remains allowed. Wording is tracked in issue #242. |
| Q3 and S7 operator-decision fidelity | The same operator comment confirms PLAN-038 to PLAN-041 state the decisions of 2026-11-19 and 2026-11-21. Answer recorded; operator confirmation is no longer pending. |
| A suggestion: automated Gemini style-guide sync | Routed by the operator to issue #242 (comment 7060767358); R5a.1 adds a row to "Unimplemented Recommendations" of `CURRENT-STATE.md` that routes it to a later tooling step (PLAN-042). |
| A note: CI freshness before a later R5b dispatch | Existing contract 9.6 already requires a sufficiently recent successful main run; operator starts it if needed. No workflow was manually started here. |

The task prompt's review step 4 expressly freezes CURRENT-STATE.md and the other Task Group 2 files, and scope forbids creating/editing issues or milestones. The operator has completed routing of all seven fixed-text findings to issue #242 and answered Q1 to Q3. Six fixes await R5a.1 before R5b; the diagnostic is retained as a lesson only. This update records those decisions without changing fixed texts, another repository file or the issue.
