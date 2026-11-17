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

Inline review has not started. Copilot, Codex and Gemini results will be recorded after the inline round. External reviews A and B remain operator initiated; neither has run yet. No findings have been assessed at this stage.

Browser Tests is running on implementation head `fbadf55`; final-head results and the Runner Image log evidence will be recorded after the last review round. The expected temporary PR-body check failure is pending the required description update.

## §4 Agent autonomous decisions

None. All implementation edits and supplied-file copies follow the dispatched prompt. No board was contacted, no workflow was started by hand, and no issue or milestone was edited.

## §5 Prompt Quality Score

- Fix cycles: 0 so far.
- Checkpoint saves: 0; §2 and checkpoints A to C passed on their first invocation.
- Preventable review findings: 0 so far; reviews pending.
- Agent autonomous decisions: 0 (helpful 0, harmful 0, neutral 0).
- PRE-PR recovery: not used; initial gate pending.

Summary judgment: the dispatched anchors matched, the locale defect reproduced before the edit, and the prescribed implementation passed checkpoints A to C. Checkpoint D, PRE-PR and reviews follow this initial record.

## §6 Operator decisions recorded by this PR

| ID | Decision | Reason |
|---|---|---|
| PLAN-034 | R5c before R5r: the four workflows on `ubuntu-24.04`; `browser-tests.yml` starts on its own file; `LC_ALL=C` for `comm` in lint baseline mode; two planner rules; the start prompt in the planner page | `ubuntu-latest` moved to Ubuntu 26.04, where Playwright 1.56.0 cannot install its browsers, and Browser Tests failed on PR #237 and on `main`. The lint fixtures failed in the operator's shell. The planning session had not checked the state of Browser Tests, and the Python of its rehearsal had PyYAML, which CI lacks |

## §7 Operator bookkeeping

No issue closes in this step, no milestone changes, and the status table of issue #228 does not change.

After merge the operator checks CI and Browser Tests on `main` using the supplied operator page. This agent does not merge or run that post-merge procedure.

## §8 Process metrics

| Metric | Value | Evidence |
|---|---|---|
| Producer sessions for this step's prompt | 1 | Operator supplied: restart check, R5 closure, decisions, production, rehearsal and gate on 2026-11-17. |
| Audit sessions for this step's prompt | 0 | Operator supplied: LOW tier, lint and one rehearsal inside the producer session. |
| Fix-cycle commits after the first review round | 0 so far | Inline round pending. |
| Defects that escaped the prompt gates into agent execution | 0 so far | All gates run so far passed on their first invocation. |
| Defects that escaped to devices | 0 | No board contact or deployment. |

## §9 Recommendations and where each was routed

The non-C-locale fixture run is routed to the next fixture production (PLAN-031) in CURRENT-STATE.md. Node.js action/runtime maintenance is routed to an operator-decided CI maintenance step in CURRENT-STATE.md. No additional recommendation has been produced at this stage; review dispositions and any new routing will be recorded after the inline round.
