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

The first commit after empty bootstrap `d6653e1` is `d0f2746`, containing only the supplied prompt copied byte for byte to `prompts/handoff/phase7/method-adoption-2026-11-14-agent-prompt.md`. `cmp` exited 0 with no output; this commit is pushed to the feature branch.

The unchanged CHECKPOINT G block was run after all Task Group 7 edits were complete:

```text
CHECKPOINT G PASS
```

## §3 Review findings by severity

No review round has run at this execution checkpoint; the GitHub review list is empty. The three inline reviewers (Copilot, Codex and Gemini) have not run. External reviewers have not run. This section must be completed after the review round and committed before merge.

| Severity | Review findings |
|---|---|
| Blocking / Critical | Not yet assessed by reviewers |
| High | Not yet assessed by reviewers |
| Medium | Not yet assessed by reviewers |
| Low / Cosmetic | Not yet assessed by reviewers |

The execution error and operator-authorized recovery are recorded below; they are not presented as reviewer findings.

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
| Fix cycles | 0 | No review round or commits addressing review findings yet. |
| Checkpoint saves | 1 | CHECKPOINT G exposed incomplete execution at 7.3; it did not identify a defect in the prompt or repository. |
| Checkpoint stops | 2 | Premature CHECKPOINT G execution, then the PRE-PR preflight failure at the Playwright manifest step. |
| Preventable review findings | 0 observed | No reviews have run; this is not a final review result. |
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
| Fix-cycle commits after the first review round | 0 | No review round has run. |
| Defects that escaped the prompt gates into agent execution | 0 observed | The recorded failure was an execution-command error; the operator confirmed no prompt or repository mismatch. |
| Defects that escaped to devices | 0 | Documentation-only work; no device deployment. |

Producer and audit session counts are supplied by the operator. The other three numbers reflect this PR at implementation completion. Review-dependent metrics and review findings are completed after the last review round and committed before merge.
