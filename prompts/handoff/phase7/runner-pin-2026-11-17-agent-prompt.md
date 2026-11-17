# CI runner pin (R5c) — workflows on ubuntu-24.04, lint baseline in the C locale, planner rules and start prompt (GPT/Codex Agent Prompt)

_Full self-contained implementation instructions_
_Date: 2026-11-17_
_Prerequisite: `main` contains `1a7bf84` (PR #237, R5 tooling); `VERSION` 7.7.1.1_
_Risk: LOW — four workflow files, one line of one script, documents; no firmware source, no partition, no version bump, no board, no generated file_
_Doctrinal precedence: where this prompt and `Docs/development-process-guide.md` conflict, the process guide governs._

---

## ⚠️ Universal Execution Preamble

1. Do NOT optimise, restructure, or "improve" these instructions. Execute them literally.
2. Do NOT remove safety constraints, even if they seem redundant.
3. Do NOT make changes to files not listed in §3.
4. If an instruction seems wrong, STOP and flag it — do not silently fix it.
5. If you run out of context, STOP at the last completed checkpoint and report what remains.

## ⚠️ Lessons that shape this step

- Every gate and every checkpoint is in the check file `/root/r5c/runner-pin-2026-11-17-checks.sh`. The setup block has checked its SHA-256 and committed a copy as `prompts/handoff/phase7/runner-pin-2026-11-17-checks.sh`. Run each one exactly as this prompt writes it, for example `bash /root/r5c/runner-pin-2026-11-17-checks.sh A`. Never type a check by hand, never retype a check from this prompt, and never edit the check file (PLAN-031).
- The check file also writes the scope list (`bash /root/r5c/runner-pin-2026-11-17-checks.sh scope`) and copies the supplied files (`bash /root/r5c/runner-pin-2026-11-17-checks.sh copy 3`). Apart from these, apply every edit of Task Groups 1 to 3 with your file-edit tool, one item at a time, in the order given. Never apply edits with a script that parses this prompt (PR #234, stop 1).
- If one of your own commands fails, repair it and repeat the step. Run no checkpoint while an edit before it is missing (PR #234, stop 1).
- Run one test command at a time: no second preflight, Playwright run or mock server while one is running (PR #234, stop 2). The PRE-PR gate runs preflight once.
- Every edit is verbatim and anchored by quoted text, never by a line number. Text between a pair of fence lines is literal: copy it exactly, blank lines and indentation included; the fence lines themselves are not part of it.
- A check prints `⛔ CHECKPOINT FAILED - <block>: <reason>` and exits non-zero on a mismatch. Then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2 and stop. Never edit a check or an expected value to make it pass.
- CHECKPOINT B and the PRE-PR gate run the lint fixtures in two locales, `C.UTF-8` and `en_US.UTF-8`. The §2 gate proves first that the defect of this step shows in `en_US.UTF-8`: 12 passed, 1 failed. That result is expected in §2, before the edit of item 2.1.
- This step needs no login and calls no board. Never print, echo or write `$ESP_USER` or `$ESP_PASS`.

---

## §1 — Repository & Required Reading

The setup block has already created your feature branch `tooling/r5c-2026-11` and committed this prompt and its check file. The §2 gate checks the branch.

Read completely, in this order:
0. `CURRENT-STATE.md` — every section; Task Group 3 edits two rows and adds two.
1. `Docs/development-process-guide.md` — §2.2 to §2.5, §3.2 and §7.
2. `AGENTS.md` — every section.
3. `Docs/plan-of-record.md` — sections 2, 3 and 5 (the blocks of R5 and R5r).
4. The four files in `.github/workflows/` and the functions `violation_keys` and `check_file_baseline` in `scripts/lint-prompts.sh`.

## §2 — Pre-Implementation Verification Gate

Run this BEFORE any edit:

```bash
bash /root/r5c/runner-pin-2026-11-17-checks.sh sec2
```

It must end with `§2 PASS`. It checks the branch, that `1a7bf84` is an ancestor, `VERSION`, a clean tree, the saved prompt and check file, the tools (a Python with PyYAML, `node_modules` with Playwright, the `en_US.UTF-8` locale), that the lint fixtures give 13 passed in `C.UTF-8` and 12 passed, 1 failed in `en_US.UTF-8`, that no new path of §3 exists yet, every anchor of Task Groups 1 to 3, and that each file this step changes is still byte-identical to `main` at `1a7bf84`. On any other output STOP and post the checkpoint-failure comment.

## §3 — Scope Boundary

Files you MAY modify (complete list, 15 paths; nothing else).

CHANGED (10):
- `.github/workflows/browser-tests.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/pr-body-check.yml`
- `.github/workflows/prompt-lint.yml`
- `scripts/lint-prompts.sh`
- `CURRENT-STATE.md`
- `Docs/plan-of-record.md`
- `Docs/decisions/decision-log.md`
- `Docs/development-process-guide.md`
- `Docs/planner-start-here.md`

NEW (5):
- `Docs/operator/R5c-runner-pin.md`
- `prompts/handoff/phase7/runner-pin-2026-11-17-review.md`
- `prompts/handoff/phase7/runner-pin-2026-11-17.md`
- `prompts/handoff/phase7/runner-pin-2026-11-17-agent-prompt.md`
- `prompts/handoff/phase7/runner-pin-2026-11-17-checks.sh`

Write this list, one bare path per line, to the file that `git rev-parse --git-path scope-allowed.txt` names; it sits inside `.git`, so it is never part of the change. The PRE-PR gate checks every changed path against it with `scripts/scope-gate.py`:

```bash
bash /root/r5c/runner-pin-2026-11-17-checks.sh scope
```

It must print `scope list written: 15 paths`.

Files you MUST NOT modify: anything under `firmware/`, `src/`, `partitions/`, `config/`, `dashboard/` and `tests/`; every other file under `scripts/`, `.github/` and `prompts/`; `package.json`, `package-lock.json`, `playwright.config.js`; `AGENTS.md`, `CLAUDE.md`, `README.md`, `VERSION`, `Docs/changelog.md`; every other file under `Docs/`. If the pipeline that `AGENTS.md` asks for before a commit changes `dashboard/dashboard.h` or another generated file, STOP: R5 made the header reproducible, so a change there is a finding.

You MUST NOT: run `bash scripts/bump-version.sh`; run `esphome compile`, `esphome upload` or `esphome run`; contact any board; start a workflow by hand; create, close or edit issues or milestones; change branch protection; delete a file; merge.

## §4 — Critical Rules Checklist

- Rule 4 — no generated file is edited, by hand or by the pipeline: this step changes none.
- Rules 62/63 — checkpoints are queries with expected values; on mismatch STOP, do not fix.
- PLAN-020 — a required check must report on every pull request: do not add a path filter to the `pull_request` trigger of `ci.yml` or `pr-body-check.yml`, and do not rename a job.
- SEC-003 — no login in any command, file or PR text.

## §5 — DO-NOT List

- Do NOT reword, reformat or move text around an edit.
- Do NOT open a supplied file in an editor: the check file copies it byte for byte.
- Do NOT change a job name, a step name, a trigger or a version of an action in any workflow. Only the lines that items 1.1 to 1.5 name change.
- Do NOT add `LC_ALL` anywhere else in `scripts/lint-prompts.sh`: the sort in `violation_keys` already has it.
- Do NOT bump the version or add a changelog entry: `VERSION` does not change in this step.
- Do NOT change `AGENTS.md`, `CLAUDE.md` or a Copilot instruction file.

## §6 — Implementation Steps

Commit after each checkpoint that passes, with a message that names the task group, and push.

### Task Group 1 — Workflows on ubuntu-24.04 (PLAN-034)

GitHub moves the label `ubuntu-latest` to Ubuntu 26.04, where Playwright 1.56.0 cannot install its browsers. Every job runs on `ubuntu-24.04` from now on, so the operating system changes only through a pull request. Each of the four files has exactly one line `    runs-on: ubuntu-latest`. Browser Tests also starts when its own file changes, so this pull request runs it.

**1.1** `.github/workflows/browser-tests.yml`: replace the line
```
    runs-on: ubuntu-latest
```
with
```
    # Pinned to one Ubuntu release: the runner's OS changes only through a pull request (R5c, PLAN-034).
    runs-on: ubuntu-24.04
```

**1.2** `.github/workflows/ci.yml`: replace the line
```
    runs-on: ubuntu-latest
```
with
```
    # Pinned to one Ubuntu release: the runner's OS changes only through a pull request (R5c, PLAN-034).
    runs-on: ubuntu-24.04
```

**1.3** `.github/workflows/pr-body-check.yml`: replace the line
```
    runs-on: ubuntu-latest
```
with
```
    # Pinned to one Ubuntu release: the runner's OS changes only through a pull request (R5c, PLAN-034).
    runs-on: ubuntu-24.04
```

**1.4** `.github/workflows/prompt-lint.yml`: replace the line
```
    runs-on: ubuntu-latest
```
with
```
    # Pinned to one Ubuntu release: the runner's OS changes only through a pull request (R5c, PLAN-034).
    runs-on: ubuntu-24.04
```

**1.5** `.github/workflows/browser-tests.yml`: exactly two lines read
```
      - 'scripts/bundle-dashboard.sh'
```
one in the `paths` list of `push` and one in the `paths` list of `pull_request`. Immediately after each of the two, insert
```
      - '.github/workflows/browser-tests.yml'
```

⛔ **CHECKPOINT A** — every job of the four workflows runs on `ubuntu-24.04`, Browser Tests watches its own file, and nothing else in the workflows changed.

```bash
bash /root/r5c/runner-pin-2026-11-17-checks.sh A
```

### Task Group 2 — Lint baseline in the C locale (PLAN-034)

`violation_keys` sorts with `LC_ALL=C`, but `comm` ran in the shell's locale. In `en_US.UTF-8`, `comm` then stops with "not in sorted order", and the fixture case "L11 baseline: new violation beside existing" fails. CI runs in `C.UTF-8` and did not show it.

**2.1** `scripts/lint-prompts.sh`: replace the line
```
  comm -23 "$tmp_head_keys" "$tmp_base_keys" > "$tmp_new_keys"
```
with
```
  # LC_ALL=C: comm compares in the byte order of the sort in violation_keys, whatever the shell's locale (R5c, PLAN-034).
  LC_ALL=C comm -23 "$tmp_head_keys" "$tmp_base_keys" > "$tmp_new_keys"
```

⛔ **CHECKPOINT B** — the lint fixtures pass in `C.UTF-8` and in `en_US.UTF-8`; lint of all prompts against `origin/main` gives the same result in both locales: 0 ERROR and 152 EXISTING lines.

```bash
bash /root/r5c/runner-pin-2026-11-17-checks.sh B
```

### Task Group 3 — Documents: state, plan, decisions, process guide, planner page, operator page, review file

Two rows of `CURRENT-STATE.md` change status, and two rows are added. In `Docs/plan-of-record.md` "You are here", the row of R5 and the row of R5r change, and R5c gets a row and a block. CHECKPOINT C searches the whole file for the old wording of each status mark.

**3.1** `CURRENT-STATE.md`: replace the line
```
| PR #237 CI | Browser Tests cannot install browsers: Playwright 1.56.0 does not support the runner's `ubuntu26.04-x64` platform | **Not implemented** — a separate scoped CI/dependency compatibility follow-up; the Browser Tests workflow and dependency files are outside R5 scope |
```
with
```
| PR #237 CI | Browser Tests cannot install browsers: Playwright 1.56.0 does not support the runner's `ubuntu26.04-x64` platform | **Implemented in R5c** — the four workflows run on `ubuntu-24.04` (PLAN-034); `browser-tests.yml` also starts when its own file changes |
```

**3.2** `CURRENT-STATE.md`: replace the line
```
| PR #237 external review A | Exercise the documentation CI fast path on a clean GitHub runner after the PyYAML fix | **Pending operator post-merge check** — run the existing one-off documentation PR procedure in the R5 prompt §9 and operator page immediately after merge, before relying on the fast path for real documentation PRs; no agent-created smoke PR or merge |
```
with
```
| PR #237 external review A | Exercise the documentation CI fast path on a clean GitHub runner after the PyYAML fix | **Done after the R5 merge** — in the operator's PR #238 (closed, never merged) `preflight-and-compile` took the fast path and passed in 26 seconds |
```

**3.3** `CURRENT-STATE.md`: immediately after the line that item 3.2 wrote, insert
```
| R5 after-merge check | Lint baseline mode sorted the violation keys with `LC_ALL=C` but ran `comm` in the shell's locale; in `en_US.UTF-8` `comm` stopped with "not in sorted order", and one fixture case failed on the build host (12 passed, 1 failed). CI runs in `C.UTF-8` and did not show it | **Implemented in R5c** — `LC_ALL=C comm -23` (PLAN-034); a fixture run in a non-C locale joins the next fixture production (PLAN-031) |
| R5c planning (CI logs) | The actions at `@v4` (checkout, setup-node, cache, upload-artifact) target Node.js 20; the runner forces them to Node.js 24 and warns that Node.js 20 is deprecated. `setup-node` also installs Node.js 20 for the jobs | **Not implemented** — no job fails yet; the operator decides when a CI maintenance step updates them |
```

**3.4** `Docs/plan-of-record.md`: replace the line
```
The next step is **R5r**, the review-runner PR. The last merged step is **R5**, the tooling PR.
```
with
```
The next step is **R5r**, the review-runner PR. The last merged step is **R5c**, the CI runner pin.
```

**3.5** `Docs/plan-of-record.md`: replace the line
```
| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login, reproducible dashboard header | SP without the device moves | R3c | Unchanged | 2 to 3 | Done: the pull request that added `scripts/scope-gate.py` |
```
with
```
| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login, reproducible dashboard header | SP without the device moves | R3c | Unchanged | 2 to 3 | Done 2026-11-16, PR #237 (`1a7bf84`) |
```

**3.6** `Docs/plan-of-record.md`: immediately after the line that item 3.5 wrote, insert
```
| 5a | R5c | CI runner pin (LOW): the four workflows on `ubuntu-24.04`, lint baseline mode in the C locale, two planner rules, the start prompt for a planning session | SP without the device moves | R5 | Unchanged | 1 to 2 | Done: the pull request that pinned the runners to `ubuntu-24.04` |
```

**3.7** `Docs/plan-of-record.md`: replace the line
```
| 5a | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5 | Unchanged | 2 to 4 | Waiting |
```
with
```
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Waiting |
```

**3.8** `Docs/plan-of-record.md`: immediately before the line
```
### R5r: review-runner PR (MEDIUM)
```
insert this text, then one blank line
```
### R5c: CI runner pin (LOW)

- Who: the planning session writes the prompt and runs its gate; the coding agent executes it. All five reviews, as for any code PR.
- Why: GitHub moves `ubuntu-latest` to Ubuntu 26.04, where Playwright 1.56.0 cannot install its browsers, so Browser Tests failed on PR #237 and on `main`. After the R5 merge the lint fixtures failed in the operator's shell, which runs in `en_US.UTF-8`.
- Scope, and nothing else (PLAN-034):
  1. The four workflows run on `ubuntu-24.04`; `browser-tests.yml` also starts when its own file changes.
  2. `scripts/lint-prompts.sh` runs `comm` with `LC_ALL=C` in baseline mode.
  3. `Docs/planner-start-here.md`: the two planner rules of PLAN-034 and the start prompt for a planning session; process guide section 7.1 says which workflows can be started by hand.
  4. This file, the decision log and `CURRENT-STATE.md`.
- Done when: merged; Browser Tests is green on the pull request and on `main`; the lint fixtures pass in `C.UTF-8` and in `en_US.UTF-8`.
- State after: version unchanged. Before each dispatch, the planning session checks the runs of the workflows that the step starts (PLAN-034).
```

**3.9** `Docs/decisions/decision-log.md`: immediately after the line that begins with
```
| 2026-11-16 | PLAN-033 |
```
insert
```
| 2026-11-17 | PLAN-034 | R5c, a small LOW step before R5r (operator decisions 2026-11-17; an exception to PLAN-012): the four workflows run on `ubuntu-24.04`, not `ubuntu-latest`, so the operating system of a job changes only through a pull request (GitHub moves `ubuntu-latest` to Ubuntu 26.04, where Playwright 1.56.0 cannot install its browsers); `browser-tests.yml` also starts when its own file changes; lint baseline mode runs `comm` with `LC_ALL=C`, the order of its sort. Two planner rules in `Docs/planner-start-here.md`: before dispatch, CI and Browser Tests, when the step's paths start them, need a green run on `main` at most 7 days old, or the operator starts one from the Actions tab first, and `prompt-lint` and `pr-body-check`, which cannot run green on `main`, need a green run on the last merged pull request that started them; a rehearsal that stands in for CI uses a clean Python with no packages beyond those that the workflow installs. The planner page also holds the start prompt for a planning session, with a placeholder for the notebook link, because the repository is public | `prompts/handoff/phase7/runner-pin-2026-11-17.md` §6 |
```

**3.10** `Docs/development-process-guide.md`: replace the line
```
Manual trigger via `workflow_dispatch` is always available.
```
with
```
Every workflow runs on `ubuntu-24.04`, not `ubuntu-latest`, so the operating system of a job changes only through a pull request (PLAN-034). `ci.yml`, `browser-tests.yml` and `prompt-lint.yml` can also be started by hand from the Actions tab (`workflow_dispatch`); `pr-body-check.yml` cannot, because it checks a pull request. A manual run of `prompt-lint.yml` lints every prompt without a baseline, so it fails while old prompts hold violations.
```

**3.11** Copy the three supplied files: the new version of `Docs/planner-start-here.md` (its rules section gains two rules and names PR #237; a new section holds the start prompt for a planning session), the operator page `Docs/operator/R5c-runner-pin.md` and the review file `prompts/handoff/phase7/runner-pin-2026-11-17-review.md`. It must print `copied 3 files`.

```bash
bash /root/r5c/runner-pin-2026-11-17-checks.sh copy 3
```

⛔ **CHECKPOINT C** — every edit and every status mark of Task Group 3, and the three supplied files.

```bash
bash /root/r5c/runner-pin-2026-11-17-checks.sh C
```

### Task Group 4 — Record of this step (its consolidated audit)

**4.0** The setup block has made this prompt and its check file, verbatim, the first commit after the bootstrap commit. Confirm it with `git log --oneline -- prompts/handoff/phase7/runner-pin-2026-11-17-agent-prompt.md prompts/handoff/phase7/runner-pin-2026-11-17-checks.sh`: one commit. If it is missing, STOP.

**4.1** Create `prompts/handoff/phase7/runner-pin-2026-11-17.md` with these nine sections, each under a heading line that begins `## §<number> `, in this order: §1 Why (R5c in the plan of record and PLAN-034: the runner move to Ubuntu 26.04, the locale defect found after the R5 merge, the two planner rules); §2 Edit list, one row per item 1.1 to 3.11 with the check that covers it and its observed output; §3 Review findings by severity (fill after the last review round; name every reviewer that ran, and state plainly when one did not post or did not complete, PLAN-032); §4 Agent autonomous decisions (expected none); §5 Prompt Quality Score per `Docs/development-process-guide.md` §6.2, with any use of the recovery of the PRE-PR gate; §6 Operator decisions recorded by this PR — the table below, verbatim; §7 Operator bookkeeping — the sentence below, verbatim; §8 Process metrics (the five numbers of HowTo v2 §5.6); §9 Recommendations and where each was routed (process guide §2.5 item 4 (d)). For §8 the operator supplies two numbers: producer sessions 1 (restart check, R5 closure, decisions, production, rehearsal and gate on 2026-11-17) and audit sessions 0 (LOW tier: lint and one rehearsal inside the producer session). Take the other three from this PR. In §3 also give the result of Browser Tests on the final head, with the image name from the log.

Table for §6 of the record:
```
| ID | Decision | Reason |
|---|---|---|
| PLAN-034 | R5c before R5r: the four workflows on `ubuntu-24.04`; `browser-tests.yml` starts on its own file; `LC_ALL=C` for `comm` in lint baseline mode; two planner rules; the start prompt in the planner page | `ubuntu-latest` moved to Ubuntu 26.04, where Playwright 1.56.0 cannot install its browsers, and Browser Tests failed on PR #237 and on `main`. The lint fixtures failed in the operator's shell. The planning session had not checked the state of Browser Tests, and the Python of its rehearsal had PyYAML, which CI lacks |
```

Sentence for §7 of the record:
```
No issue closes in this step, no milestone changes, and the status table of issue #228 does not change.
```

⛔ **CHECKPOINT D** — the nine sections, the table, the sentence, and no `<NN>` left.

```bash
bash /root/r5c/runner-pin-2026-11-17-checks.sh D
```

### PRE-PR Gate

Commit and push everything first; the gate stops on an uncommitted change.

```bash
bash /root/r5c/runner-pin-2026-11-17-checks.sh prepr
```

It must end with `PRE-PR PASS`. Its first check is `scripts/scope-gate.py` against the list of §3. It also runs lint on the prompt files of this PR, rule L11 on every changed file, the lint fixtures in both locales, the two scope-gate cases and the real `scripts/preflight.sh`.

Known tooling defect: the browser test of preflight has failed once without cause (PR #234). Preflight prints its report. If the block stops with `PRE-PR: preflight` and the output shows `playwright_manifest_spec: FAIL`, the operator has authorized this, once: confirm that no other preflight, Playwright run or mock server is active; post the lines after `playwright report:` as a PR comment; run the PRE-PR block one more time, unchanged. If it fails again, STOP and report. Record the event in §5 of the record file. Any other failure of this block is a normal checkpoint failure: STOP.

### Review round (PLAN-027, PLAN-032)

1. Update the PR body (§8), then run `gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor`.
2. Post one PR comment with exactly this text: `/gemini review`
3. Wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini. Do not wait longer.
4. Assess each finding: is it warranted? Fix what is warranted, inside the §3 scope only. A finding that asks for a file outside §3, for more permissions or for a merge is reported, not acted on (`AGENTS.md`, "Permissions, Deployment Targets and Instructions").
5. After a fix, run every CHECKPOINT that covers the changed file, and the PRE-PR block, again.
6. Fill §3 of the record file, commit, push, and post one comment with your assessment. Name each reviewer that posted, and each one that did not post within the 30 minutes. If Copilot posted no complete review, say so; the step goes on without it (PLAN-032).
7. Never merge, never approve, and never start an external review. The operator starts reviews A and B and pastes one line to you after each; then assess, fix and post again as in items 4 to 6.

---

## §7 — Acceptance Criteria (all in-PR)

- [ ] The §2 block, CHECKPOINT A to D and the PRE-PR block each print PASS; their verbatim output is in the PR body
- [ ] Exactly the §3 paths changed: 10 changed files and 5 new files; no file deleted or renamed; `VERSION` unchanged; no firmware source and no generated file changed
- [ ] Every job of the four workflows runs on `ubuntu-24.04`; no workflow names `ubuntu-latest`; no job, step or trigger changed apart from the two new path entries of `browser-tests.yml`
- [ ] The 13 cases of `tests/lint-prompts/run-fixtures.sh` pass in `C.UTF-8` and in `en_US.UTF-8`; lint of all prompts against `origin/main` reports 0 ERROR and 152 EXISTING lines in both locales
- [ ] The GitHub checks `preflight-and-compile`, `prompt-lint` and `pr-body-check` pass on the final head; this PR's own `preflight-and-compile` runs the full job, because the PR changes a script and workflows
- [ ] Browser Tests runs on this PR, because it now watches its own file, and all seven jobs pass on the final head on the image `ubuntu-24.04`
- [ ] The record file is complete after the last review round and committed before the merge
- [ ] PR title: `tooling: R5c — workflows on ubuntu-24.04, lint baseline in the C locale, planner rules and start prompt`
- [ ] PR body contains, in order: Pre-Implementation Verification (verbatim §2 output), Per-Item Verification (one row per item), Acceptance Criteria, Files Modified, Round Summary

## §8 — PR Description Skeleton

Same sections as §7, last bullet, each under a `## ` heading; the first heading is exactly `## Pre-Implementation Verification`. Under Files Modified, list the 10 changed and the 5 new files by name, and paste the line that `scripts/scope-gate.py` printed in the PRE-PR gate. Device testing: N/A — this step flashes no board and calls no board.

Until the body has that heading, the check `pr-body-check` fails on this PR; that is expected, and the check runs again when you edit the body. In the Round Summary give the result of each check on the final head, Browser Tests included, with the image name that its job log shows under "Runner Image".

## §9 — Post-Merge Bookkeeping (tag and close only)

This step has no tag, and it closes no issue. After the merge the operator runs the block of "After the merge" in `Docs/operator/R5c-runner-pin.md` and checks that the merge started green runs of CI and Browser Tests on `main`. You run none of it.
