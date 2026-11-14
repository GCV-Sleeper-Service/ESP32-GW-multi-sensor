# Method adoption — HowTo v2.3.1

_PR #234 · branch `docs/method-adoption-2026-11` · PLAN-012 and PLAN-017._
_Execution record: 2026-11-13 to 2026-11-14 (America/Los_Angeles). The operator-supplied adoption date and artifact names are 2026-11-14._

## §1 Why

The operator adopts HowTo-LLM-Assisted-Workflow-v2 at `v2.3.1` (`450c446`) before the restart housekeeping PR. Development paused on 2026-05-10 for reasons outside the project. This PR binds the method in the project process guide, records PLAN-012 and PLAN-017, and updates the project instructions and audit templates. Firmware remains at v7.7.1.1.

The supplied prompt's SHA-256 matches `066d1c630a89864d5f546498044990f3e58123d38965959892d3574113793f1f`. The pre-implementation gate printed `§2 PASS` against the checkout based on `b64cd770f87ff0d8a3c7697065c97dfe23d1129d`.

## §2 Edit list

Each command below was run after Task Group 7 was complete. Outputs are listed in command order.

| Item | Verification command | Observed output |
|---|---|---|
| 7.1 | `` grep -c 'at tag `v2.3.1`' Docs/development-process-guide.md `` | `` 1 `` |
| 7.2 | `` grep -c '^5\. After a pause\\|^6\. Pre-dispatch gate (PLAN-017)' Docs/development-process-guide.md `` | `` 2 `` |
| 7.3 | `` grep -c 'Risk tiers (PLAN-017)' Docs/development-process-guide.md `` | `` 1 `` |
| 7.4 | `` grep -c '^> [56]\. ' Docs/development-process-guide.md `` | `` 2 `` |
| 7.5 | `` grep -c '^[78]\. ' Docs/development-process-guide.md `` | `` 2 `` |
| 7.6 | `` wc -l < Docs/llm-assisted-development-guide.md `` | `` 3 `` |
| 7.7 | `` grep -c '^## 0\. This project' CLAUDE.md `` | `` 1 `` |
| 7.8 | `` grep -c '^### Process metrics (HowTo v2' prompts/phase7/consolidated-audit-template-phase7.md ``<br>`` grep -c 'commit it before merge' prompts/phase7/consolidated-audit-template-phase7.md `` | `` 1 ``<br>`` 1 `` |
| 7.9 | `` grep -c '^## §9 Batch process metrics' Docs/templates/prompt-audit-template.md `` | `` 1 `` |
| 7.10 | `` grep -c 'PLAN-01[27]' Docs/decisions/decision-log.md ``<br>`` grep -c '^- \*\*Method of record:\*\*' CURRENT-STATE.md ``<br>`` grep -c '^\| Verification : production sessions' CURRENT-STATE.md `` | `` 2 ``<br>`` 1 ``<br>`` 1 `` |
| 7.11 | `` grep -c '^Changes already made: ' Docs/development-process-guide.md ``<br>`` grep -c 'A failing test inside a task group is ordinary work' Docs/development-process-guide.md `` | `` 1 ``<br>`` 1 `` |
| 7.12 | `` grep -c '^1) Confirm the checkout has no unrelated work' Docs/development-process-guide.md `` | `` 1 `` |
| 7.13 | `` grep -c '^## Permissions, Deployment Targets and Instructions$' AGENTS.md `` | `` 1 `` |

Items 7.1, 7.2 and 7.12 were also compared character for character with the supplied prompt and required no correction. Item 7.2 has one blank line after item 6. Item 7.3 preserves its internal blank lines and its final blank line. All remaining insertions were applied individually with the file-edit tool in prompt order after operator authorization to continue.

The operator subsequently requested assessment and fixes for PR reviews. That follow-up aligns the existing audit-template instructions with the adopted tiers; the original prompt, checks and expected values remain unchanged. The review dispositions are recorded in §3.

The first commit after empty bootstrap `d6653e1` is `d0f2746`, containing only the supplied prompt copied byte for byte to `prompts/handoff/phase7/method-adoption-2026-11-14-agent-prompt.md`. `cmp` exited 0 with no output; this commit is pushed to the feature branch.

The unchanged CHECKPOINT G block was run after all Task Group 7 edits were complete:

```text
CHECKPOINT G PASS
```

## §3 Review findings by severity

First inline review round assessed on 2026-11-14 against implementation commit `6069d71`. Codex and Gemini submitted reviews. Copilot posted an approval-oriented overview with no findings, but explicitly reported that it could not complete the selected review tier because of model policy or plan restrictions; this is not counted as a completed full Copilot review. External reviewers have not run.

| Severity | Review findings |
|---|---|
| Blocking / Critical | None reported. |
| High | None reported. |
| Medium | Codex P2: the audit template's old auditor counts and mandatory reconciliation contradicted PLAN-017. Warranted; fixed in template v1.1 by aligning the usage instructions, §0, §3, §6, §7 and §8 with LOW lint, MEDIUM one auditor without reconciliation, and HIGH two auditors from different model families plus reconciliation and the embedded-code compile gate. Existing failure and third-auditor escalation safeguards are retained. |
| Low / Cosmetic | Gemini marked the phrase “board addresses your prompt names” medium priority. Assessed as a cosmetic preference: “names” is a valid verb and the deployment boundary is clear. No change; retain the operator-prescribed text of item 7.13. |

Sources: [Codex finding](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/234#discussion_r4572481385), [Gemini suggestion](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/234#discussion_r4572669380), [Copilot limitation](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/234#pullrequestreview-5903050784).

Validation: traced LOW, MEDIUM and HIGH from §0 through §7 to confirm each tier's auditor count and dispatch artifacts agree with the process guide. Prompt lint on the three changed prompt paths reports zero violations; `git diff --check` exits 0. The template version and its changelog are updated; the project VERSION and the preserved agent prompt are unchanged.

The execution errors and operator-authorized recoveries are recorded below; they are not presented as reviewer findings. No review is claimed as approval of the follow-up commit before it is reviewed.

## §4 Agent autonomous decisions

| Decision | Classification | Impact and disposition |
|---|---|---|
| Ran CHECKPOINT G after the edit helper failed at item 7.3, while Task Group 7 was incomplete. | Harmful | Caused the premature CHECKPOINT G stop at 7.3 and required an operator decision to continue. The agent stopped and posted the failure comment; it did not change the prompt, a check or an expected value. |

Failure comment: [CHECKPOINT G stop](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/234#issuecomment-6872401402). The helper raised `IndexError: list index out of range` while extracting the 7.3 insertion. The operator confirmed that the prompt and repository were as expected and authorized continuation.

Recovery followed the operator's instructions: verified the working tree, the two commits and the original prompt hash; pushed `d0f2746`; checked the three existing edits; then applied each remaining item individually without parsing the prompt with a script. During 7.8, a patch with hunks in reverse file order was rejected. It was repaired and repeated as two successful edits before any checkpoint ran. These command failures were execution errors, not evidence of a prompt or repository mismatch.

For this continuation, a failed edit command is repaired and repeated before moving on. A checkpoint is run only after all preceding edits are complete. No other autonomous scope or deployment decisions were made.

## §5 Prompt Quality Score

| Metric | Value | Evidence |
|---|---|---|
| Fix cycles | 1 | One follow-up commit addresses the warranted Codex finding from the first inline review round. |
| Checkpoint saves | 1 | CHECKPOINT G exposed incomplete execution at 7.3; it did not identify a defect in the prompt or repository. |
| Checkpoint stops | 2 | Premature CHECKPOINT G execution, then the PRE-PR preflight failure at the Playwright manifest step. |
| Preventable review findings | 1 | The prompt's new tier rule should also have reconciled the audit template's existing auditor-count and dispatch instructions. |
| Agent autonomous decisions | 1 harmful; 0 helpful; 0 neutral | Premature CHECKPOINT G execution, recorded in §4. |

The operator confirmed that the prompt and repository were as expected. The stop was caused by the agent's command handling; the method-adoption edits completed without changing the prompt, checks or expected values. Review-dependent metrics remain provisional until the last review round.

The second stop was [PRE-PR: preflight](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/234#issuecomment-6873146081). Lint reported zero violations and preflight printed successful checks through `mutex_single_owner: PASS`, then exited during the Playwright manifest step, whose standard output the script suppresses. The agent stopped without changing a script, prompt, check, expected value, test or environment.

The operator authorized a read-only diagnostic on 2026-11-14. A process check found no active preflight, Playwright or mock-server process. The exact Playwright command was run with visible output, one command at a time: `npx playwright test tests/browser/manifest.spec.js --project=chromium; echo "playwright exit $?"`. It reported `10 passed (14.6s)` and `playwright exit 0`; the last 40 lines were [posted on the PR](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/234#issuecomment-6874291707). cause not found; passed on a second run without a change.

After that diagnostic, the unchanged PRE-PR Gate was run once. It exited 0 and ended with `playwright_manifest_spec: PASS` and `PRE-PR PASS`. CHECKPOINT G and CHECKPOINT H had already printed PASS. No fix was attempted for the unexplained Playwright failure.

## §6 Recommendations routed

No new recommendations were produced. No issues or milestones were created, edited or closed. The operator's command-recovery instruction is recorded in §4 and was applied in this continuation. The existing adoption follow-ups remain those explicitly listed in PLAN-017; this PR adds no new follow-up scope.

## §7 Process metrics

| Metric | Value | Evidence |
|---|---|---|
| Producer sessions for this step's prompt | 2 | Operator-supplied planning record: two sessions wrote, amended and rehearsed the prompt, 2026-11-04 to 05 and 2026-11-10 to 14. |
| Audit sessions for this step's prompt | 0 | Operator confirmed no separate audit session for this documentation-only step; checks were lint and three rehearsals inside the producer sessions. |
| Fix-cycle commits after the first review round | 1 | One follow-up commit fixes the audit-template tier conflict. |
| Defects that escaped the prompt gates into agent execution | 1 | Codex identified the audit-template tier conflict in the resulting PR; the prompt gates did not detect it. The earlier command failures remain execution errors. |
| Defects that escaped to devices | 0 | Documentation-only work; no device deployment. |

Producer and audit session counts are supplied by the operator. The other three numbers reflect this PR after the first review-fix round. Review-dependent metrics and review findings must reflect the last review round and be committed before merge.
