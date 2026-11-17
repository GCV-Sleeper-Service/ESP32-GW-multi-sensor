# R5c — CI runner pin: consolidated audit

PR: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/239

## §1 Why

R5c precedes R5r in the plan of record (PLAN-034). Browser Tests failed after `ubuntu-latest` moved to Ubuntu 26.04, where Playwright 1.56.0 cannot install browsers. The post-R5 check also exposed a locale mismatch: violation keys were sorted in C byte order, while `comm` compared them in the operator's locale. The four workflows now use `ubuntu-24.04`, and baseline comparison uses `LC_ALL=C`.

The planner page requires recent successful runs of the workflows that a step starts and a clean Python environment for rehearsals that stand in for CI. It also contains the planning-session start prompt with a public notebook-link placeholder.

## §2 Edit list

Each checkpoint command comes from the immutable supplied check file. The pre-implementation gate printed `locale for CHECKPOINT B: en_US.utf8` and `§2 PASS`.

| Item | Edit | Check | Observed output |
|---|---|---|---|
| 1.1 | Pin Browser Tests runner | A | `workflows: every job on ubuntu-24.04, nothing else changed`; `CHECKPOINT A PASS` |
| 1.2 | Pin CI runner | A | `CHECKPOINT A PASS` |
| 1.3 | Pin PR Body Check runner | A | `CHECKPOINT A PASS` |
| 1.4 | Pin Prompt Lint runner | A | `CHECKPOINT A PASS` |
| 1.5 | Watch Browser Tests' own workflow in both path lists | A | `CHECKPOINT A PASS` |
| 2.1 | Compare baseline keys with `LC_ALL=C comm -23` | B | `CHECKPOINT B PASS`: 13 fixtures pass in both locales; 0 ERROR and 152 EXISTING lines in each full-corpus scan |
| 3.1 | Mark runner incompatibility implemented | C | `CHECKPOINT C PASS` |
| 3.2 | Record PR #238 documentation fast-path result | C | `CHECKPOINT C PASS` |
| 3.3 | Record locale fix and deferred Node maintenance | C | `CHECKPOINT C PASS` |
| 3.4 | Move plan's last-step marker to R5c | C | `CHECKPOINT C PASS` |
| 3.5 | Record R5 merge and commit | C | `CHECKPOINT C PASS` |
| 3.6 | Add R5c ladder row | C | `CHECKPOINT C PASS` |
| 3.7 | Make R5r depend on R5c | C | `CHECKPOINT C PASS` |
| 3.8 | Add R5c scope and done-when block | C | `CHECKPOINT C PASS` |
| 3.9 | Add PLAN-034 decision verbatim | C | `CHECKPOINT C PASS` |
| 3.10 | Correct manual workflow-trigger description | C | `CHECKPOINT C PASS` |
| 3.11 | Copy planner page, operator page and review file verbatim | copy 3; C | `copied 3 files`; `CHECKPOINT C PASS` |

The prompt and check file were committed together as `d887f43`, the first commit after bootstrap `21720d2`. Task Groups 1, 2 and 3 were committed and pushed after their passing checkpoints. Provisioning before each commit left generated files unchanged.

## §3 Review findings by severity

The inline round started at 2026-11-17 06:32:03 UTC and all three reviewers responded within six minutes, inside the 30-minute limit. The operator subsequently supplied [review A by Claude Opus 5.5, effort xhigh](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/239#issuecomment-6941132981) and [review B by Muse Spark 1.3, reasoning setting not named by its interface](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/239#issuecomment-6941318868). Both reviewed `4b3e680`; B added no new findings. A disclosed that the prompt producer used the same model in another session, so correlated blind spots remain a review limitation.

| Severity | Reviewer | Finding and assessment | Disposition |
|---|---|---|---|
| Low | Copilot | [Planner rule says Prompt Lint cannot run green on main](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/239#discussion_r4596183773). Manual dispatch exists, but it scans the full corpus without a baseline; the current corpus has 152 pre-existing violations. Thus the statement describes the current repository correctly. Process guide §7.1 explicitly explains that manual runs fail while old prompts hold violations. The rule also says to update every place that states a rule when that rule changes. | No change warranted for current behavior. Cleaning up the legacy corpus would change this premise and require its rule to be updated then. The supplied planner page remains verbatim. |
| Low | Review A1; repeated by B | The Node.js maintenance note omitted `actions/setup-python@v5`, which the reviewed CI log explicitly includes in its Node.js 20 warning. Warranted documentation omission in the prescribed text. | Added `setup-python@v5` to the existing CURRENT-STATE.md maintenance row in `2a12423`. Actual action/runtime upgrades remain deferred to the operator-decided CI maintenance step. |
| Low | Review A2; repeated by B | This record cited Browser Tests on `67c7cd9` while putting the newer `4b3e680` evidence only in the editable PR body. Warranted durable-evidence gap. | Recorded run 44032957134 and its image evidence below. This record completion commit changes only `prompts/`; the preceding review-fix commit changes only CURRENT-STATE.md. New-head CI results are added to the PR after the push. |
| Cosmetic | Review A3; repeated by B | The paragraph after the prescribed §7 sentence was accurate and passed D; the prompt requires that sentence verbatim but does not explicitly prohibit additional prose. No behavioral defect. | Removed the optional paragraph for a concise bookkeeping section. The prescribed sentence remains verbatim. |
| Cosmetic | Review A4; repeated by B | Check C correctly compares against `16 3`, but its failure message says 17 added lines. Warranted diagnostic-only producer defect; no incorrect test condition. | Preserved the immutable check file and its correct comparison. Routed the message correction to the next check-file production (PLAN-031), explicitly in the existing CURRENT-STATE.md verification follow-up row. |
| None | Codex | [Completed code review](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/239#issuecomment-6940708436) on `67c7cd9`, with no findings. | No fix required. |
| None | Gemini | [Completed review](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/239#pullrequestreview-5934035087), with no review comments. Its earlier unsupported-file notice was posted before the implementation, on the bootstrap PR. | No fix required. |

Copilot posted one finding and a submission, but explicitly stated that it was unable to complete the selected review tier because of model policy or plan restrictions. No complete Copilot review was posted. No reviewer was entirely absent; the incomplete Copilot review is recorded per PLAN-032.

Browser Tests result on the head reviewed by A and B, `4b3e680b9aa4953ca199fe428b38b168125c8617`: all seven matrix jobs passed in [run 44032957134](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/44032957134). The [3sensor job log](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/44032957134/job/133868994725) contains:

```text
2026-11-17T06:40:34.4437349Z Image: ubuntu-24.04
2026-11-17T06:40:34.4437857Z Version: 20261111.370.1
2026-11-17T06:42:47.5697885Z   106 skipped
2026-11-17T06:42:47.5698181Z   192 passed (1.8m)
```

Full `preflight-and-compile`, Prompt Lint and PR Body Check also passed on that head. Since those runs, only documentation has changed: the maintenance/routing note in CURRENT-STATE.md (`2a12423`) and this record under `prompts/`. The commit completing this record changes only `prompts/`; it cannot contain its own future CI result. The PR Round Summary records checks on the new head after the push. All five reviewers responded; Copilot's incomplete review is the only missing complete review.

Review A Q1, repeated by B: a documentation-only merge does not automatically start CI on `main`, because its push paths exclude documentation. Under PLAN-034, a manual run is needed only when there is no successful CI run on `main` at most seven days old; a recent qualifying run remains sufficient after a documentation merge. No change to the operator's policy or workflow triggers is inferred, and no workflow was dispatched.

Review A Q2, repeated by B: confirmed that older helpers print `esphome run` advice in `scripts/provision.sh`, `scripts/render_sensor_config.py`, `scripts/change_sensor_number.py` and `scripts/patch-esphome-httpd-stack.sh`. The printed `esphome run` commands were not executed. These files are outside R5c's editable scope; their existing advice is reported to the operator, with no edit or new step assignment inferred.

## §4 Agent autonomous decisions

None beyond the user-authorized review assessment and fixes. The additional edits affect two existing maintenance/routing rows and this audit. No supplied file, check or expected value was changed. No board was contacted, no workflow was started by hand, and no issue or milestone was edited.

## §5 Prompt Quality Score

- Fix cycles: 1; one combined external-review assessment round corrected the maintenance note and durable audit evidence.
- Checkpoint saves: 0; §2 and checkpoints A to D passed on their first invocation.
- Preventable review findings: 3; the omitted action (A1), durable-evidence gap (A2) and cosmetic diagnostic mismatch (A4). The optional §7 paragraph and Copilot's current-state observation are not counted as defects.
- Agent autonomous decisions: 0 (helpful 0, harmful 0, neutral 0).
- PRE-PR recovery: not used; the initial gate ended with `playwright_manifest_spec: PASS` and `PRE-PR PASS`.

Invocation repair: `gh pr edit` failed on its obsolete GraphQL Projects (classic) field. Repeating the authorized description update through `gh api --method PATCH`, reading the identical prepared body file, succeeded. This changed no repository file, supplied check or expected value. It was not the PRE-PR recovery.

Summary judgment: the dispatched anchors matched, the locale defect reproduced before the edit, and §2, A to D and PRE-PR passed. Codex and Gemini completed without findings; Copilot's incomplete review supplied one Low wording observation, assessed above. External A identified documentation/evidence gaps and one immutable diagnostic typo; B repeated those findings and identified no new issue. The maintenance note and durable evidence are corrected, and the typo is tracked for future check-file production. C covers the maintenance/routing edits; D and PRE-PR cover record completion, with fresh outputs posted in the PR. No workflow or script change was required by the reviews.

## §6 Operator decisions recorded by this PR

| ID | Decision | Reason |
|---|---|---|
| PLAN-034 | R5c before R5r: the four workflows on `ubuntu-24.04`; `browser-tests.yml` starts on its own file; `LC_ALL=C` for `comm` in lint baseline mode; two planner rules; the start prompt in the planner page | `ubuntu-latest` moved to Ubuntu 26.04, where Playwright 1.56.0 cannot install its browsers, and Browser Tests failed on PR #237 and on `main`. The lint fixtures failed in the operator's shell. The planning session had not checked the state of Browser Tests, and the Python of its rehearsal had PyYAML, which CI lacks |

## §7 Operator bookkeeping

No issue closes in this step, no milestone changes, and the status table of issue #228 does not change.

## §8 Process metrics

| Metric | Value | Evidence |
|---|---|---|
| Producer sessions for this step's prompt | 1 | Operator supplied: restart check, R5 closure, decisions, production, rehearsal and gate on 2026-11-17. |
| Audit sessions for this step's prompt | 0 | Operator supplied: LOW tier, lint and one rehearsal inside the producer session. |
| Fix-cycle commits after the first review round | 2 | `2a12423` corrects the maintenance note and tracks the diagnostic; this record completion commit corrects the durable evidence and records the external dispositions. Both belong to one review-fix cycle. |
| Defects that escaped the prompt gates into agent execution | 2 | The prescribed Node.js action list omitted setup-python, and the check file has a cosmetic failure-message typo. The audit evidence gap is separately corrected in this review round. |
| Defects that escaped to devices | 0 | No board contact or deployment. |

## §9 Recommendations and where each was routed

The non-C-locale fixture run is routed to the next fixture production (PLAN-031) in CURRENT-STATE.md. The same verification follow-up row now explicitly tracks correction of the immutable check file's 17-versus-16 diagnostic in the next check-file production. Node.js action/runtime maintenance remains routed to an operator-decided CI maintenance step; its existing CURRENT-STATE.md row now includes `setup-python@v5`.

The record-evidence recommendation is implemented above. Copilot's suggested wording change remains closed as no current behavior defect, consistent with reviews A and B. The extra §7 paragraph is removed. Advice printed by the four out-of-scope helpers is reported in §3 and the PR assessment; no expansion of R5c or operator scheduling decision is inferred. No issue or milestone was created or edited.
