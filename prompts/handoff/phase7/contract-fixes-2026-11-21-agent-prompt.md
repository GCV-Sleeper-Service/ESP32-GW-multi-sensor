# Producer-contract fixes (R5a.1) — the findings of issue #242 in the producer contract and batch prompt v3.0, compile before dispatch at every tier, the reading of the escaped-defects metric (GPT/Codex Agent Prompt)

_Full self-contained implementation instructions (LOW tier)_
_Date: 2026-11-21_
_Prerequisite: `main` contains `d7740b5` (PR #241, R5a); `VERSION` 7.7.1.1_
_Risk: LOW — line edits of ten documents and two supplied pages; no firmware source, no script, no workflow, no partition, no version bump, no board, no generated file. The operator set the tier and the order on 2026-11-21 (PLAN-042)_
_Doctrinal precedence: where this prompt and `Docs/development-process-guide.md` conflict, the process guide governs, except for the two exemptions of §5: no changelog entry, and no change of "Last verified" or "What Just Shipped" in `CURRENT-STATE.md`._

---

## ⚠️ Universal Execution Preamble

1. Do NOT optimise, restructure, or "improve" these instructions. Execute them literally.
2. Do NOT remove safety constraints, even if they seem redundant.
3. Do NOT make changes to files not listed in §3.
4. If an instruction seems wrong, STOP and flag it — do not silently fix it.
5. If you run out of context, STOP at the last completed checkpoint and report what remains.

## ⚠️ Lessons that shape this step

- Every gate and every checkpoint is in the check file `/root/r5a1/contract-fixes-2026-11-21-checks.sh`. The setup block has checked its SHA-256 and committed a copy as `prompts/handoff/phase7/contract-fixes-2026-11-21-checks.sh`. Run each one exactly as this prompt writes it, for example `bash /root/r5a1/contract-fixes-2026-11-21-checks.sh A`. Never type a check by hand, never retype a check from this prompt, and never edit the check file (PLAN-031).
- The check file also writes the scope list (`... scope`) and copies the two supplied files (`... copy`). Never open a supplied file in an editor, and never change one: the operator page and the review file are fixed texts.
- This prompt is LOW and holds no code. Apart from the blocks of the check file, apply every edit of Task Groups 1 to 3 with your file-edit tool, one item at a time, in the order given. Never apply edits with a script that parses this prompt (PR #234, stop 1).
- If one of your own commands fails, repair it and repeat the step. Run no checkpoint while an edit before it is missing (PR #234, stop 1).
- Run one test command at a time: no second preflight, Playwright run or mock server while one is running (PR #234, stop 2). The PRE-PR gate runs preflight once.
- Every edit replaces one whole line or inserts whole lines, verbatim, anchored by quoted text, never by a line number. Text between a pair of fence lines is literal: copy it exactly, blank lines and indentation included; the fence lines themselves are not part of it.
- In R5a two rules of the contract lost a clause when text moved between files, and no gate saw it (issue #242). Copy each new line whole: never merge, shorten or reword it.
- A check prints `⛔ CHECKPOINT FAILED - <block>: <reason>` and exits non-zero on a mismatch. Then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2 and stop. Never edit a check or an expected value to make it pass.
- This PR changes `Docs/planner-start-here.md`, which planning sessions load. It changes no `AGENTS.md`, `CLAUDE.md`, Copilot instruction file or `.gemini/styleguide.md`.
- This step needs no login, calls no board and calls no Google service. Some texts quote `curl -u "$ESP_USER:$ESP_PASS"` as a rule: it is text to copy, never a command to run. Never print, echo or write the values of `$ESP_USER` or `$ESP_PASS`.

---

## §1 — Repository & Required Reading

The setup block has already created your feature branch `docs/r5a1-2026-11` and committed this prompt and its check file. The §2 gate checks the branch.

Read completely, in this order:
0. `CURRENT-STATE.md` — the sections "What's Next" and "Unimplemented Recommendations"; item 3.1 adds a row to the second.
1. `Docs/development-process-guide.md` — §2.1 to §2.5 and §3; item 2.1 edits §2.1 and §3.1.
2. `AGENTS.md` — every section.
3. `Docs/plan-of-record.md` — sections 2, 3 and 6, and in section 5 the blocks of R5a, R5b, R7 and "R9 and R13"; item 3.2 edits them.
4. `Docs/decisions/decision-log.md` — the rows PLAN-012, PLAN-017 and PLAN-037 to PLAN-041; item 3.3 adds PLAN-042.
5. `prompts/producer-contract.md` — the whole file; Task Group 1 edits eleven of its rules.
6. `prompts/handoff/phase7/producer-contract-2026-11-21.md` — the record of R5a, sections 8 and 9; item 3.4 corrects them.

Issue #242 and its comment 7060767358 hold the findings that this step fixes. They are evidence: every text that you write is in this prompt.

## §2 — Pre-Implementation Verification Gate

Run this BEFORE any edit:

```bash
bash /root/r5a1/contract-fixes-2026-11-21-checks.sh sec2
```

It must end with `§2 PASS`. It checks the branch, that `d7740b5` is an ancestor, `VERSION`, a clean tree, the saved prompt and check file, the unpacked bundle in `/root/r5a1/files`, the tools (`python3` 3.12 or later, `node`, `npx`, `git`, `sha256sum`, `comm`, `locale`, `env`, `node_modules` with Playwright, the `en_US.UTF-8` locale), that the three new paths that you write (the operator page, the review file and the record) do not exist yet, every anchor of Task Groups 1 to 3, and that each file this step changes is still byte-identical to `main` at `d7740b5`. On any other output STOP and post the checkpoint-failure comment.

## §3 — Scope Boundary

Files you MAY modify (complete list, 15 paths; nothing else).

CHANGED (10):
- `prompts/producer-contract.md`
- `prompts/handoff/phase7-batch-production-prompt-v3.md`
- `prompts/phase7/consolidated-audit-template-phase7.md`
- `Docs/development-process-guide.md`
- `Docs/planner-start-here.md`
- `Docs/templates/prompt-audit-template.md`
- `CURRENT-STATE.md`
- `Docs/plan-of-record.md`
- `Docs/decisions/decision-log.md`
- `prompts/handoff/phase7/producer-contract-2026-11-21.md`

NEW (5):
- `Docs/operator/R5a.1-contract-fixes.md`
- `prompts/handoff/phase7/contract-fixes-2026-11-21-review.md`
- `prompts/handoff/phase7/contract-fixes-2026-11-21-agent-prompt.md`
- `prompts/handoff/phase7/contract-fixes-2026-11-21-checks.sh`
- `prompts/handoff/phase7/contract-fixes-2026-11-21.md`

Write the list to the file that `git rev-parse --git-path scope-allowed.txt` names; it sits inside `.git`. The PRE-PR gate checks every changed path against it with `scripts/scope-gate.py`:

```bash
bash /root/r5a1/contract-fixes-2026-11-21-checks.sh scope
```

It must print `scope list written: 15 paths`.

Files you MUST NOT modify: anything under `firmware/`, `src/`, `partitions/`, `config/`, `dashboard/`, `scripts/`, `tests/`, `.github/`, `.gemini/` and `Docs/lessons/`; every other file under `prompts/`; `package.json`, `package-lock.json`, `playwright.config.js`; `AGENTS.md`, `CLAUDE.md`, `README.md`, `VERSION`, `Docs/changelog.md`; every other file under `Docs/`. If the pipeline that `AGENTS.md` asks for before a commit changes `dashboard/dashboard.h` or another generated file, STOP: R5 made the header reproducible, so a change there is a finding.

You MUST NOT: run `bash scripts/bump-version.sh`; run `esphome compile`, `esphome upload` or `esphome run`; contact any board; call any Google service; start a workflow by hand; create a GitHub environment, variable or secret; create, close or edit issues or milestones; change branch protection; delete or move a file; merge.

## §4 — Critical Rules Checklist

- Rule 4 — `bash scripts/preflight.sh` must pass; the PRE-PR gate runs it.
- Rule 64 — every count in a check comes from the text of this prompt, not from memory.
- PLAN-012 — batch prompt v3.0 stays shorter than version 2.0, `prompts/handoff/phase7-batch-production-prompt-update.md`: fewer lines and fewer bytes.
- PLAN-038 — `prompts/producer-contract.md` has at most 150 lines, each numbered rule ends with its tag, and the file changes only through a pull request with a decision row; PLAN-042 is that row.
- PLAN-029 — `AGENTS.md` is the one source of rules for agents and reviewers; this step changes no instruction file.
- SEC-003 — no login, key or token in any command, file or PR text.

## §5 — DO-NOT List

- Do NOT reword, reformat or move text around an edit of Task Groups 1 to 3.
- Do NOT change a rule of the contract other than the eleven lines of Task Group 1, and do NOT renumber a rule.
- Do NOT write a lesson entry in `Docs/lessons/`. The new rule 8.6 binds from R5b on; this step lists candidate lessons in its record only.
- Do NOT bump the version or add a changelog entry. The changelog entry of process guide §2.5 does not apply to this step, because `VERSION` does not change; §3 and this section govern here.
- Do NOT change the line "_Last verified: ..." or "_Next action: ...", or the table "What Just Shipped", of `CURRENT-STATE.md`. Process guide §2.5 item 2 asks for "Last verified" and "What Just Shipped", but neither applies here: "Last verified" records the operator's check of the boards, and "What Just Shipped" lists versioned steps. R5b stays the next action. Item 3.1 is the whole change of `CURRENT-STATE.md` in this step.
- Do NOT change `AGENTS.md`, `CLAUDE.md`, a Copilot instruction file or `.gemini/styleguide.md`.
- Do NOT change an older batch-production prompt: version 1 and version 2.0 stay as history.

## §6 — Implementation Steps

Commit after each checkpoint that passes, with a message that names the task group, and push.

### Task Group 1 — The producer texts: contract, batch prompt v3.0, consolidated-audit template

The findings of issue #242 in the contract and in batch prompt v3.0, compile before dispatch at every tier (rules 3.4 and 9.7), the rule on lesson entries (8.6) and the reading of the escaped-defects metric (PLAN-042). Each replaced line keeps its rule number.

**1.1** `prompts/producer-contract.md`, rules 1.5, 2.3, 3.1 and 3.4:
replace the line
```
5. Every command that the producer gives the operator, in a page, a gate record or a chat, the producer ran first, exactly as written. A command that needs a board, the login or a cloud account, which the producer cannot run, is marked so where it is given and checked against the vendor's page. [gate: rehearsal; judgment]
```
with
```
5. Every command that the producer gives the operator, in a page, a gate record or a chat, the producer ran first, exactly as written. A command that needs a board, the login or a cloud account, which the producer cannot run, is marked so where it is given and checked: a board command against `AGENTS.md` "Device Testing" and the operator's latest `fleet` output, any other command against the vendor's page. [gate: rehearsal; judgment]
```
and replace the line
```
3. Board values come only from the fleet table of `CURRENT-STATE.md` and the operator's latest `fleet` output. A step that runs on boards tests every board that its block in the plan of record names, the test board first where the block says so. [L4; L5; judgment]
```
with
```
3. Board values come only from the fleet table of `CURRENT-STATE.md` and the operator's latest `fleet` output. A step that runs on boards tests every board that its block in the plan of record names, the test board first where the block says so. [L4 and L5 for the two known stale WROOM values; judgment]
```
and replace the line
```
1. Every edit is anchored by quoted text or by a symbol (a file and a function), never by a line number. The §2 gate checks that each anchor exists, as often as the prompt says. [gate: §2]
```
with
```
1. Every edit is anchored by quoted text or by a symbol (a file and a function), never by a line number. The §2 gate checks that each anchor exists, as often as the prompt says. [gate: §2; judgment]
```
and replace the line
```
4. Code that a prompt prescribes and that ends in a compiled artifact is applied on a scratch branch from `origin/main`, assembled and compiled before dispatch, as plan of record R7 shows; the result goes into the gate record. For a HIGH step this waits until the step before it is on `main`. [gate: compile]
```
with
```
4. Code that a prompt of any tier carries and that ends in a compiled artifact is applied on a scratch branch from `origin/main`, assembled and compiled before dispatch, as plan of record R7 shows (HowTo §5.3 item 5); the result goes into the gate record. When that code needs the step before it, the compile waits until that step is on `main` and runs in the pre-dispatch gate (rule 9.7); a HIGH step also has its compile-gate step in the plan of record, which waits until the step before it is on `main`. [gate: compile]
```

**1.2** `prompts/producer-contract.md`, rules 4.3, 4.4 and 7.4:
replace the line
```
3. No login, key or token in any file of the bundle. No secret in a command argument: a check that needs a secret reads it from the environment inside one process; the login stays in `$ESP_USER` and `$ESP_PASS` (SEC-003). [L11; gate: PRE-PR; judgment]
```
with
```
3. No login, key or token in any file of the bundle. No secret in a command argument: this covers the written text of every command and the checks of a check file. A check that needs a secret reads it from the environment inside one process; the login stays in `$ESP_USER` and `$ESP_PASS` (SEC-003), so `curl -u "$ESP_USER:$ESP_PASS"` of `AGENTS.md` stays allowed in a command that the agent or the operator runs. [L11; gate: PRE-PR; judgment]
```
and replace the line
```
4. An agent prompt never runs `git checkout main` or `git switch main`; it checks the branch instead. [L10]
```
with
```
4. An agent prompt never runs `git checkout main` or `git switch main`; it checks the branch instead. [L10; gate: §2]
```
and replace the line
```
4. §3 lists every path that the PR may change, with every file that canonical tools change as a side effect (`bash scripts/bump-version.sh` and the pipeline), taken from a rehearsal run, never from an older list. A rename lists both paths. The check file writes the list; the PRE-PR gate runs `scripts/scope-gate.py` on it. A statement of scope names the files it covers. [gate: PRE-PR]
```
with
```
4. §3 lists every path that the PR may change, with every file that canonical tools change as a side effect (`bash scripts/bump-version.sh` and the pipeline), taken from a rehearsal run, never from an older list. A rename lists both paths. The check file writes the list; the PRE-PR gate runs `scripts/scope-gate.py` on it. A statement of scope names the files it covers. [gate: rehearsal; gate: PRE-PR; judgment]
```

**1.3** `prompts/producer-contract.md`, rules 8.1, 8.6, 9.2 and 9.7:
replace the line
```
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state, and no check depends on an order or a spelling that the prompt leaves free. [gate: rehearsal]
```
with
```
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state. No supplied test and no check depends on an order, a spelling or a shared state that the prompt leaves free. [gate: rehearsal; judgment]
```
and replace the line
```
6. Tracking: a step that resolves an issue closes it with `Fixes #<n>` and moves it in `CURRENT-STATE.md`; a new architectural decision is a row of `Docs/decisions/decision-log.md` in the same PR; a new Critical Rule goes to `prompts/prompt-index-and-workflow.md`; the record lists candidate lessons and the operator gives them their numbers in `Docs/lessons/`; the operator updates the board measurement log when device tests show new baselines. [L9; judgment]
```
with
```
6. Tracking: a step that resolves an issue closes it with `Fixes #<n>` and moves it in `CURRENT-STATE.md`; a new architectural decision is a row of `Docs/decisions/decision-log.md` in the same PR; a new Critical Rule goes to `prompts/prompt-index-and-workflow.md`; the record lists candidate lessons, the agent writes each lesson entry in `Docs/lessons/` in the PR (so §3 lists `Docs/lessons/index.md` and the domain files that may take one), and the operator gives its final number before the merge, which the agent writes in; the operator updates the board measurement log when device tests show new baselines. [L9; judgment]
```
and replace the line
```
2. Negative tests: each gate and checkpoint stops when its condition is broken. Supplied tests fail with no implementation and with one that refuses everything; a test that only reads the source is named so in the test file; each defect that an audit found, put back into the reference one at a time, makes a test fail. [gate: rehearsal]
```
with
```
2. Negative tests: each gate and checkpoint stops when its condition is broken. Every test of behaviour fails with no implementation and with one that refuses everything; a test that only reads the source is named so in the test file; each defect that an audit found, put back into the reference one at a time, makes a test fail. [gate: rehearsal]
```
and replace the line
```
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, for a HIGH step the compile. The record is the first comment of the PR. A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
```
with
```
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, and the compile of rule 3.4 for a prompt of any tier that carries code ending in a compiled artifact. The record is the first comment of the PR. A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
```

**1.4** `prompts/handoff/phase7-batch-production-prompt-v3.md`, the trigger of Batch 2 and the three searches of "Verify before producing":
replace the line
```
| Batch 2 | R5b | R5a merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
```
with
```
| Batch 2 | R5b | R5a.1 merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
```
and replace the line
```
grep -n 'handle_history_\|handle_api_v2_history_\|SegmentSnapshot' firmware/core/web-handler.h | head -5
```
with
```
grep -n 'handle_history_\|handle_api_v2_history_\|SegmentSnapshot' firmware/core/web-handler.h
```
and replace the line
```
grep -n 'struct.*Segment\|struct.*Device\|struct.*Event' firmware/core/data-model.h | head -5
```
with
```
grep -n 'struct.*Segment\|struct.*Device\|struct.*Event' firmware/core/data-model.h  # no match: no output and exit 1; record "none"
```
and replace the line
```
grep -n 'struct.*Segment\|struct.*Device\|struct.*Meta' firmware/core/nvs-persistence.h | head -5
```
with
```
grep -n 'struct.*Segment\|struct.*Device\|struct.*Meta' firmware/core/nvs-persistence.h
```

**1.5** `prompts/phase7/consolidated-audit-template-phase7.md`, the reading of the metric of escaped defects:
immediately after the line that begins with
```
_Completed after the last review round and committed before merge._
```
insert
```

_Defects that escaped the prompt gates into agent execution: the unique defects of the step's bundle (prompt, check file, supplied texts, tests) that the producer's gates and audits missed and that were found after dispatch, each counted once; an error of the agent's own is not one of them (PLAN-042)._
```

⛔ **CHECKPOINT A** — every edit of items 1.1 to 1.5; in each file the old wording that an item removes is gone from the whole file; the line counts of the three files; the contract still has at most 150 lines and each of its numbered rules ends with a tag in square brackets; batch prompt v3.0 still has fewer lines and fewer bytes than version 2.0; lint in normal mode passes on the three files.

```bash
bash /root/r5a1/contract-fixes-2026-11-21-checks.sh A
```

### Task Group 2 — The process documents: process guide, planner page, audit template

The same rule on compile before dispatch in every place that states it (contract rule 1.4), and the answers to review A's Q1 and Q2 in the start prompt of a planning session.

**2.1** `Docs/development-process-guide.md`, the pre-dispatch gate (§2.1 item 6) and the tier table (§3.1):
replace the line
```
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and for a HIGH step compiles any embedded code on a scratch branch. Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.
```
with
```
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and, for a prompt of any tier that carries code ending in a compiled artifact, compiles that code on a scratch branch from `origin/main` (`prompts/producer-contract.md` rule 3.4, PLAN-042). Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.
```
and replace the line
```
| LOW | v7.7.1.2 | Lint | Intent and acceptance criteria |
```
with
```
| LOW | v7.7.1.2 | Lint; embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria |
```
and replace the line
```
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037) | Intent and acceptance criteria; prescribe only interface contracts |
```
with
```
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria; prescribe only interface contracts |
```
and replace the line
```
Transition (PLAN-017): the Batch 2 prompts of May 2026 (v7.7.1.2-v7.7.1.4) are not dispatched. They are re-produced under the method of record and audited at their tier before dispatch; the compile of v7.7.1.4's embedded code runs once v7.7.1.3 is on `main`.
```
with
```
Transition (PLAN-017): the Batch 2 prompts of May 2026 (v7.7.1.2-v7.7.1.4) are not dispatched. They are re-produced under the method of record and audited at their tier before dispatch; the compile of v7.7.1.4's embedded code runs once v7.7.1.3 is on `main`. Embedded code of any tier that needs the step before it is compiled once that step is on `main`, in the pre-dispatch gate of §2.1 item 6 (PLAN-042).
```

**2.2** `Docs/planner-start-here.md`, the start prompt: commands that the planner cannot run, and secrets in commands:
replace the line
```
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
```
with
```
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check: a board command against AGENTS.md "Device Testing" and my latest fleet output, any other against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument: this covers the written text of a command and the checks of a check file; curl -u "$ESP_USER:$ESP_PASS" stays allowed in a command that I run. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
```

**2.3** `Docs/templates/prompt-audit-template.md`, the tier table, §7 steps 9 and 10, §9, the version and its changelog row:
replace the line
```
| LOW | Lint | No independent audit or reconciliation file |
```
with
```
| LOW | Lint; compile embedded code on a scratch branch | No independent audit or reconciliation file; compile evidence if code is embedded |
```
and replace the line
```
| MEDIUM | Lint + one independent auditor | One audit report; no reconciliation file |
```
with
```
| MEDIUM | Lint + one independent auditor; compile embedded code on a scratch branch | One audit report; no reconciliation file; compile evidence if code is embedded |
```
and replace the line
```
9. MEDIUM: confirm the single audit report has zero HIGH / CRITICAL findings; do not create a reconciliation file. HIGH: issue the reconciliation report (per §6) confirming zero HIGH / CRITICAL findings, and record a successful scratch-branch compile for any embedded code.
```
with
```
9. MEDIUM: confirm the single audit report has zero HIGH / CRITICAL findings; do not create a reconciliation file. HIGH: issue the reconciliation report (per §6) confirming zero HIGH / CRITICAL findings. Every tier: record a successful scratch-branch compile for any embedded code (PLAN-042).
```
and replace the line
```
10. Dispatch only after the tier's gate is satisfied: LOW lint passes; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed, with compile evidence for any embedded code. Every tier also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
```
with
```
10. Dispatch only after the tier's gate is satisfied: LOW lint passes; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed. Every tier has compile evidence for any embedded code (PLAN-042) and also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
```
and replace the line
```
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017): LOW = lint only; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file, and a compile gate for embedded code.
```
with
```
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017): LOW = lint; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file; every tier = a compile gate for embedded code (PLAN-042).
```
and replace the line
```
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint only; MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
```
with
```
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint and no auditor, and every tier compiles its embedded code on a scratch branch (PLAN-042); MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
```
and replace the line
```
This section applies to HIGH only. LOW requires lint only; MEDIUM uses its single audit report without reconciliation (PLAN-017).
```
with
```
This section applies to HIGH only. LOW requires lint and no audit report; MEDIUM uses its single audit report without reconciliation (PLAN-017).
```
and replace the line
```
For LOW, steps 4–9 are not applicable; lint and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
```
with
```
For LOW, steps 4 to 8 and the audit part of step 9 are not applicable; lint, the compile of step 9 and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
```
and replace the line
```
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint only:
```
with
```
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint and no audit:
```
and replace the line
```
- **Template version:** v1.3
```
with
```
- **Template version:** v1.4
```
and immediately after the line that begins with
```
| v1.3 | 2026-11-21 |
```
insert
```
| v1.4 | 2026-11-21 | R5a.1 (PLAN-042): embedded code is compiled on a scratch branch before dispatch at every tier, not only HIGH: the note on how to use this file, the tier table, §6, §7 steps 9 and 10, §8 and §9. |
```

⛔ **CHECKPOINT B** — every edit of items 2.1 to 2.3; the old wording that an item removes is gone from the whole file; the line counts of the three files.

```bash
bash /root/r5a1/contract-fixes-2026-11-21-checks.sh B
```

### Task Group 3 — State, plan, decision, the record of R5a, supplied pages

**3.1** `CURRENT-STATE.md`, a row of "Unimplemented Recommendations" for the Gemini style-guide sync:
immediately after the line that begins with
```
| R5a internal audit (2026-11-21) |
```
insert
```
| R5a review A (PR #241) | A check in preflight or lint that the four parts of `.gemini/styleguide.md` still equal `AGENTS.md` word for word, as CHECKPOINT A of R5a compared them; today only contract rule 1.4 and PLAN-039 keep the two files in step, by reading (issue #242, comment 7060767358) | **Not implemented** — routed to a later tooling step that the operator schedules |
```

**3.2** `Docs/plan-of-record.md`, "You are here", the ladder, the block of R5a.1, and compile before dispatch in the blocks R5b, R9 and R13:
replace the line
```
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a**, the producer contract. The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
```
with
```
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a.1**, the fixes of the producer contract from the reviews of R5a (PLAN-042). The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
```
and immediately after the line that begins with
```
| 6 | R5a |
```
insert
```
| 6a | R5a.1 | Producer-contract fixes from the reviews of R5a, issue #242 (LOW, PLAN-042) | Dispatch, review and merge one documentation PR | R5a | Unchanged | 1 to 2 | Done: the pull request that fixes issue #242 |
```
and replace the line
```
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a | Unchanged | 4 to 6 | Waiting |
```
with
```
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a.1 | Unchanged | 4 to 6 | Waiting |
```
and immediately after the line that begins with
```
- Done when: both files are on `main` and lint passes on them.
```
insert
```

### R5a.1: producer-contract fixes (documentation, LOW)

- Why: reviews A and B of PR #241 found seven defects in the fixed texts of R5a. The operator routed them to issue #242 and put this step before R5b (PLAN-042).
- Scope: the findings of issue #242 and of its comment 7060767358 in `prompts/producer-contract.md`, batch prompt v3.0 and the start prompt of `Docs/planner-start-here.md`; compile before dispatch for every prompt that carries code, in contract rules 3.4 and 9.7, process guide §2.1 and §3.1, the audit template, the blocks R5b, R9 and R13 and section 6 of this file; the reading of the escaped-defects metric in the consolidated-audit template and in §8 of the record of R5a; the routing of the Gemini style-guide sync in a row of `CURRENT-STATE.md` and in §9 of the record of R5a.
- Who: the planning session writes the prompt, with one internal sub-agent audit (PLAN-040); the coding agent executes it; the inline round and review A run, reviews B and C do not.
- Done when: merged, and issue #242 is closed.
- State after: version unchanged. R5b is produced under the fixed contract.
```
and immediately after the line that begins with
```
  - a `.bin` size checkpoint against the OTA slot from v7.7.1.3 on;
```
insert
```
- Compile before dispatch (PLAN-042): a prompt of any tier that carries code ending in a compiled artifact has that code compiled on a scratch branch first. If the prompt of v7.7.1.3 carries such code, its compile runs in its pre-dispatch gate, once v7.7.1.2 is on `main`; the compile of v7.7.1.4 runs in R7.
```
and replace the line
```
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint |
```
with
```
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint; the compile of any embedded code (PLAN-042) |
```
and replace the line
```
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint and one independent auditor |
```
with
```
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint and one independent auditor; the compile of any embedded code (PLAN-042) |
```
and replace the line
```
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, and checks that no fill-in is left. Device values come only from the operator's latest fleet output. The record is the first comment of the PR.
```
with
```
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, checks that no fill-in is left, and compiles the code that the prompt carries and that ends in a compiled artifact (contract rule 3.4). Device values come only from the operator's latest fleet output. The record is the first comment of the PR.
```
and replace the line
```
- As R5b, with the producer contract and batch prompt v3.0. Batch 3: v7.7.2.1 (MEDIUM), v7.7.2.2 (HIGH), v7.7.2.3 (MEDIUM). Batch 4: v7.7.3.1 and v7.7.3.2 (MEDIUM), v7.7.3.3 (HIGH). One auditor for a MEDIUM step; two auditors from different model families for a HIGH step. The compile gate of a HIGH step waits until the step before it is on `main`. The bundles and their audits go into one documentation PR, with the batch metrics.
```
with
```
- As R5b, with the producer contract and batch prompt v3.0. Batch 3: v7.7.2.1 (MEDIUM), v7.7.2.2 (HIGH), v7.7.2.3 (MEDIUM). Batch 4: v7.7.3.1 and v7.7.3.2 (MEDIUM), v7.7.3.3 (HIGH). One auditor for a MEDIUM step; two auditors from different model families for a HIGH step. The compile gate of a HIGH step waits until the step before it is on `main`; a prompt of another tier that carries code compiles it in its pre-dispatch gate (PLAN-042). The bundles and their audits go into one documentation PR, with the batch metrics.
```

**3.3** `Docs/decisions/decision-log.md`, the decision row PLAN-042:
immediately after the line that begins with
```
| 2026-11-21 | PLAN-041 |
```
insert
```
| 2026-11-21 | PLAN-042 | R5a.1 before R5b, and the producer-contract fixes of issue #242 (operator decisions 2026-11-21, within PLAN-012 and PLAN-017: they complete the producer contract of the PLAN-017 list). The findings of reviews A and B on PR #241 against fixed texts (issue #242) are fixed, or recorded as a lesson, in one small LOW documentation PR, row 6a of the plan of record, before R5b; its producer audit is lint and one internal sub-agent round (PLAN-040), and its pull request gets the inline round and review A only; it writes no lesson entry. Compile before dispatch: every prompt, of any tier, that carries code ending in a compiled artifact has that code compiled on a scratch branch before dispatch, as HowTo §5.3 item 5 and PLAN-017 say, not only a HIGH prompt; code that needs the step before it compiles in the pre-dispatch gate once that step is on `main`, and a HIGH step keeps its compile-gate step; contract rules 3.4 and 9.7, process guide §2.1 item 6 and §3.1 and the audit template say the same. Lessons: the agent writes each lesson entry in `Docs/lessons/` in the PR, and the operator gives its final number before the merge. The process metric "defects that escaped the prompt gates into agent execution" counts the unique defects of a bundle (prompt, check file, supplied texts, tests) that the producer's gates and audits missed and that were found after dispatch; an error of the agent's own is not one of them; for R5a it is 7, not 1. Answers to review A of PR #241 (comment 7060381647): rule 1.5's exception stands, and a board command is checked against `AGENTS.md` "Device Testing" and the operator's latest `fleet` output; rule 4.3 covers the written text of a command and the checks of a check file, and `curl -u "$ESP_USER:$ESP_PASS"` stays allowed; PLAN-038 to PLAN-041 state the operator's decisions; an internal audit round is not an audit session (PLAN-040) | `prompts/handoff/phase7/contract-fixes-2026-11-21.md` §6 |
```

**3.4** `prompts/handoff/phase7/producer-contract-2026-11-21.md`, §8 and one row of §9 of the record of R5a:
replace the line
```
| Defects that escaped the prompt gates into agent execution | 1 |
```
with
```
| Defects that escaped the prompt gates into agent execution | 7 |
```
and replace the line
```
Producer and audit counts come from the operator's explicit metrics comment 7059068448 on PR #241. They confirm 1 and 0; internal producer-audit rounds are excluded per PLAN-037/PLAN-040. The earlier gate record had forecast the same values but was not the final metrics confirmation. The execution-defect count is the premature metrics/provenance choice in A L4. The seven fixed-text review findings are tracked in sections 3 and 5 separately from execution failures. No device was contacted.
```
with
```
Producer and audit counts come from the operator's explicit metrics comment 7059068448 on PR #241. They confirm 1 and 0; internal producer-audit rounds are excluded per PLAN-037/PLAN-040. The earlier gate record had forecast the same values but was not the final metrics confirmation. Corrected in R5a.1 (PLAN-042; issue #242, comment 7060767358): the execution-defect count is the seven fixed-text findings of issue #242 (review A's M1, M2, L1, L2, L3 and L5, and review B's check-file diagnostic), the unique defects of the bundle that the producer's gates and audits missed and that were found after dispatch. The count was 1 before, the premature metrics/provenance choice in A L4; that is an error of the agent's own, and section 4 records it. No device was contacted.
```
and replace the line
```
| A suggestion: automated Gemini style-guide sync | Reported for operator routing to a later tooling issue; no new gate added in this PR. |
```
with
```
| A suggestion: automated Gemini style-guide sync | Routed by the operator to issue #242 (comment 7060767358); R5a.1 adds a row to "Unimplemented Recommendations" of `CURRENT-STATE.md` that routes it to a later tooling step (PLAN-042). |
```

**3.5** Copy the two supplied files: the operator page `Docs/operator/R5a.1-contract-fixes.md` and the review file `prompts/handoff/phase7/contract-fixes-2026-11-21-review.md`. It must print `copied 2 files`.

```bash
bash /root/r5a1/contract-fixes-2026-11-21-checks.sh copy
```

⛔ **CHECKPOINT C** — every edit of items 3.1 to 3.4; the old wording that an item removes is gone from the whole file; the line counts of the four files; the decision log has 66 lines that begin with `| ` (65 before) and its last line is unchanged; the two supplied files; the Mermaid block of the operator page holds no semicolon.

```bash
bash /root/r5a1/contract-fixes-2026-11-21-checks.sh C
```

### Task Group 4 — Record of this step (its consolidated audit)

**4.0** The setup block has made this prompt and its check file, verbatim, the first commit after the bootstrap commit. Confirm it with `git log --oneline -- prompts/handoff/phase7/contract-fixes-2026-11-21-agent-prompt.md prompts/handoff/phase7/contract-fixes-2026-11-21-checks.sh`: one commit. If it is missing, STOP.

**4.1** Create `prompts/handoff/phase7/contract-fixes-2026-11-21.md` with these nine sections, each under a heading line that begins `## §<number> `, in this order and each once: §1 Why (R5a.1 in the plan of record, issue #242 and its comment 7060767358, PLAN-012, PLAN-017, PLAN-042); §2 Edit list, a table with one row per item 1.1 to 1.5, 2.1 to 2.3 and 3.1 to 3.5, and three cells in each row: the bare item number (such as 1.1), the check that covers it, and its observed output; §3 Review findings by severity (write the line `pending` until step 5 of the review round; then update §3 after each round, so that it is complete after the last round; name every reviewer that ran, and state plainly when one did not post or did not complete, PLAN-032); §4 Agent autonomous decisions: every choice that this prompt did not fix, each with its reason, or the line `none`; §5 Prompt Quality Score per `Docs/development-process-guide.md` §6.2, with any use of the recovery of the PRE-PR gate (write the line `pending` until step 5 of the review round, which fills §5 together with §3, before that round's PRE-PR run; a use of the recovery goes into §5 as the PRE-PR block says); §6 Operator decisions recorded by this PR — the table below, verbatim; §7 Operator bookkeeping — the sentence below, verbatim; §8 Process metrics — the five rows of the table "Process metrics" in `prompts/phase7/consolidated-audit-template-phase7.md`, with these names: producer sessions for this step's prompt, audit sessions for this step's prompt, fix-cycle commits after the first review round, defects that escaped the prompt gates into agent execution, defects that escaped to devices; §9 Recommendations and where each was routed (process guide §2.5 item 4 (d)), and any candidate lesson, or the line `none` for each.

For §8 the operator gives you the first two numbers, producer sessions and audit sessions (official rounds only, PLAN-037; an internal round is not one, PLAN-040), in a PR comment; until then write `pending` in their rows, and fill them in your next commit after that comment. Take the other three from this PR. Count the defects that escaped the prompt gates into agent execution as item 1.5 defines them: the unique defects of this step's bundle (this prompt, its check file and the two supplied files) that were found after dispatch, by a checkpoint, by you or by a review, each counted once; an error of your own is not one of them, and goes into §4.

Table for §6 of the record:
```
| ID | Decision | Reason |
|---|---|---|
| PLAN-042 | R5a.1 comes before R5b as its own small LOW documentation PR, with lint and one internal sub-agent audit round, the inline round and review A; it fixes the findings of issue #242 and its comment 7060767358. Every prompt that carries code ending in a compiled artifact is compiled before dispatch, at every tier. The agent writes lesson entries in the PR, and the operator gives their numbers before the merge. The escaped-defects metric counts the unique defects of a bundle found after dispatch: 7 for R5a. The answers to review A's Q1 to Q3 of comment 7060381647 | The reviews of PR #241 found seven defects in fixed texts that the agent could not fix there; HowTo §5.3 item 5 and PLAN-017 compile all code that a prompt carries, while the contract, the process guide and the audit template said HIGH only; the metric compares the producer's gates across steps (process guide §4.3 item 8), so one reading is fixed before R5b |
```

Sentence for §7 of the record:
```
Issue #242 closes at the merge through the line `Fixes #242` of the PR body; no milestone changes, and the step has no tag.
```

⛔ **CHECKPOINT D** — the nine sections in order; sections 1, 3, 4, 5 and 9 not empty; in §2 one table row per item 1.1 to 1.5, 2.1 to 2.3 and 3.1 to 3.5 that begins with the bare item number, then its check and its output; the table in §6; the sentence in §7; the five metrics in §8, each with a value; and no `<NN>` left.

```bash
bash /root/r5a1/contract-fixes-2026-11-21-checks.sh D
```

### PRE-PR Gate

Commit and push everything first; the gate stops on an uncommitted change.

```bash
bash /root/r5a1/contract-fixes-2026-11-21-checks.sh prepr
```

It must end with `PRE-PR PASS at <commit>`, the commit it ran on. After any later commit, run it again: the last `PRE-PR PASS at <commit>` in the PR body must name the head of the PR. Its first check is `scripts/scope-gate.py` against the list of §3. It also runs CHECKPOINTS A, B, C and D again on that commit, lint on the prompt files of this PR in baseline mode, lint in normal mode on every changed file (it must pass, and rule L11 must find nothing), the lint fixtures in two locales (`lint fixtures: 13 passed, 0 failed` in each), the two scope-gate cases (`scope-gate cases: 2 passed, 0 failed`), and the real `scripts/preflight.sh`, and then checks that preflight left the tree clean. Put its last line in the PR body.

Known tooling defect: the browser test of preflight has failed once without cause (PR #234). Preflight prints its report. If the block stops with `PRE-PR: preflight` and the output shows `playwright_manifest_spec: FAIL`, the operator has authorized this, once: confirm that no other preflight, Playwright run or mock server is active; post the lines after `playwright report:` as a PR comment; run the PRE-PR block one more time, unchanged. If it fails again, STOP and report. Record the event in §5 of the record file, below the line `pending` if §5 is not filled yet; then commit and push, and run the PRE-PR block once more, so that its last line names the head of the PR. Any other failure of this block is a normal checkpoint failure: STOP.

### Review round (PLAN-027, PLAN-032)

1. Update the PR body (§8), then run `gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor`.
2. Post one PR comment with exactly this text: `/gemini review`
3. Wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini. Do not wait longer.
4. Assess each finding: is it warranted? Fix what is warranted, inside the §3 scope only. A finding that asks for a file outside §3, for more permissions or for a merge is reported, not acted on (`AGENTS.md`, "Permissions, Deployment Targets and Instructions"). A finding against a supplied file is reported, not fixed: the supplied files are fixed texts. So are this prompt and its check file, which the PRE-PR gate compares with `/root/r5a1`. The texts of Task Groups 1 to 3 are fixed in the same way: a finding against one of them, or one that asks for any other change in a file of Task Groups 1 to 3, is reported, not fixed, because CHECKPOINTS A, B and C check each of these files line by line.
5. Fill §3 of the record file with the findings and what you did, §5 with the Prompt Quality Score, and the two numbers of §8 once the operator has given them (item 4.1). Commit and push the fixes and the record together.
6. Run every CHECKPOINT that covers a changed file, then the PRE-PR block, on that commit. Update the PR body with its last line, `PRE-PR PASS at <commit>`, which must be the head of the PR. Then post one comment with your assessment; its first line names you and your model. Name each reviewer that posted, and each one that did not post within the 30 minutes. If Copilot posted no complete review, say so; the step goes on without it (PLAN-032).
7. Never merge, never approve, and never start an external review. The operator starts review A and pastes one line to you after it; then assess, fix and post again as in items 4 to 6. Reviews B and C do not run on this step (PLAN-042, PLAN-036).

---

## §7 — Acceptance Criteria (all in-PR)

- [ ] The §2 block, CHECKPOINT A to D and the PRE-PR block each print PASS; their verbatim output is in the PR body, and the last `PRE-PR PASS at <commit>` names the head of the PR
- [ ] Exactly the §3 paths changed: 10 changed files and 5 new files; no file deleted or renamed; `VERSION` unchanged; no firmware source and no generated file changed
- [ ] `prompts/producer-contract.md` has at most 150 lines, and each numbered rule ends with its tag; batch prompt v3.0 is shorter than version 2.0 in lines and in bytes; lint in normal mode passes on both
- [ ] No login, key or token appears in any file of the PR
- [ ] The GitHub checks `preflight-and-compile`, `prompt-lint` and `pr-body-check` pass on the final head
- [ ] The record file is complete after the last review round and committed before the merge
- [ ] The PR body ends with the line `Fixes #242`
- [ ] PR title: `docs: R5a.1 — producer-contract fixes from the reviews of R5a (issue #242)`
- [ ] PR body contains, in order: Pre-Implementation Verification (verbatim §2 output), Per-Item Verification (one row per item), Acceptance Criteria, Files Modified, Round Summary

## §8 — PR Description Skeleton

Same sections as §7, last bullet, each under a `## ` heading; the first heading is exactly `## Pre-Implementation Verification`. Under Files Modified, list the 10 changed files and the 5 new files by name, and paste the line `scope-gate: base …` that `scripts/scope-gate.py` printed in the PRE-PR gate. Device testing: N/A — this step flashes no board and calls no board. The last line of the body is `Fixes #242`.

Until the body has that heading, the check `pr-body-check` fails on this PR; that is expected. Every path of this PR is a documentation path of the CI fast path (PLAN-028), so `preflight-and-compile` runs preflight only, with no ESPHome install and no compile. Browser Tests does not start: no changed path matches its filter. Give the results in the Round Summary.

## §9 — Post-Merge Bookkeeping (tag and close only)

This step has no tag. The merge closes issue #242 through the line `Fixes #242`. You do none of it.
