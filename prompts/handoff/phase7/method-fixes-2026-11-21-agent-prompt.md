# Method fixes (R5a.2) — an internal audit round at every tier, dispatch by a setup file, the checks `inline` and `body` of the review round, review A's Q1 to Q4 of PR #243 (GPT/Codex Agent Prompt)

_Full self-contained implementation instructions (LOW tier)_
_Date: 2026-11-21_
_Prerequisite: `main` contains `d0a4414` (PR #243, R5a.1); `VERSION` 7.7.1.1_
_Risk: LOW — line edits of ten documents and two supplied pages; no firmware source, no script, no workflow, no partition, no version bump, no board, no generated file. The operator set the tier and the order on 2026-11-21 (PLAN-043)_
_Doctrinal precedence: where this prompt and `Docs/development-process-guide.md` conflict, the process guide governs, except for the two exemptions of §5: no changelog entry, and no change of "Last verified", "Next action" or "What Just Shipped" in `CURRENT-STATE.md`._

---

## ⚠️ Universal Execution Preamble

1. Do NOT optimise, restructure, or "improve" these instructions. Execute them literally.
2. Do NOT remove safety constraints, even if they seem redundant.
3. Do NOT make changes to files not listed in §3.
4. If an instruction seems wrong, STOP and flag it — do not silently fix it.
5. If you run out of context, STOP at the last completed checkpoint and report what remains.

## ⚠️ Lessons that shape this step

- Every gate and every checkpoint is in the check file `/root/r5a2/method-fixes-2026-11-21-checks.sh`. The setup block has checked its SHA-256 and committed a copy as `prompts/handoff/phase7/method-fixes-2026-11-21-checks.sh`. Run each one exactly as this prompt writes it, for example `bash /root/r5a2/method-fixes-2026-11-21-checks.sh A`. Never type a check by hand, never retype a check from this prompt, and never edit the check file (PLAN-031).
- The check file also writes the scope list (`... scope`) and copies the two supplied files (`... copy`). Never open a supplied file in an editor, and never change one: the operator page and the review file are fixed texts.
- This prompt is LOW and holds no code. Apart from the blocks of the check file, apply every edit of Task Groups 1 to 3 with your file-edit tool, one item at a time, in the order given. Never apply edits with a script that parses this prompt (PR #234, stop 1).
- If one of your own commands fails, repair it and repeat the step. Run no checkpoint while an edit before it is missing (PR #234, stop 1).
- Run one test command at a time: no second preflight, Playwright run or mock server while one is running (PR #234, stop 2). The PRE-PR gate runs preflight once.
- Every edit replaces one whole line or inserts whole lines, verbatim, anchored by quoted text, never by a line number. Text between a pair of fence lines is literal: copy it exactly, blank lines and indentation included; the fence lines themselves are not part of it.
- In R5a two rules of the contract lost a clause when text moved between files, and no gate saw it (issue #242). Copy each new line whole: never merge, shorten or reword it.
- In R5a.1 the agent assessed the inline round three minutes after `/gemini review`, before any of the three reviewers had posted, and pushed a commit while they were reviewing (PR #243, review A F1). In this step the block `inline` waits for them; push nothing until it prints `inline PASS`.
- In R5a and R5a.1 the PR body kept "pending" in its Round Summary and in ticked criteria after the last round (PR #241, PR #243). Each round now ends with the block `body`, which fails on that.
- In R5a.1 the agent renamed itself to match a review finding. Name yourself and your model as your harness shows them; answer a finding about your name, never fix it by renaming.
- A check prints `⛔ CHECKPOINT FAILED - <block>: <reason>` and exits non-zero on a mismatch. Then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2 and stop. Never edit a check or an expected value to make it pass.
- This PR changes `Docs/planner-start-here.md`, which planning sessions load. It changes no `AGENTS.md`, `CLAUDE.md`, Copilot instruction file or `.gemini/styleguide.md`.
- This step needs no board login, calls no board and calls no Google service. The blocks `inline` and `body` read the PR through `gh api`, with the GitHub login that `gh` already has. Some texts quote `curl -u "$ESP_USER:$ESP_PASS"` as a rule: it is text to copy, never a command to run. Never print, echo or write the values of `$ESP_USER` or `$ESP_PASS`.

---

## §1 — Repository & Required Reading

The setup block has already created your feature branch `docs/r5a2-2026-11` and committed this prompt and its check file. The §2 gate checks the branch.

Read completely, in this order:
0. `CURRENT-STATE.md` — the sections "What's Next" and "Unimplemented Recommendations"; item 3.1 adds three rows to the second.
1. `Docs/development-process-guide.md` — §2.1 to §2.5 and §3.1; item 2.1 edits them.
2. `AGENTS.md` — every section.
3. `Docs/plan-of-record.md` — sections 2, 3, 6 and 7, and in section 5 the blocks of R5a.1 and R5b; item 3.2 edits them.
4. `Docs/decisions/decision-log.md` — the rows PLAN-017, PLAN-019, PLAN-026, PLAN-027, PLAN-032, PLAN-035, PLAN-040 and PLAN-042; item 3.3 adds PLAN-043.
5. `prompts/producer-contract.md` — the whole file; Task Group 1 edits nine of its rules and adds rule 7.13.
6. `prompts/handoff/phase7-batch-production-prompt-v3.md` — the table of batches; item 1.6 edits it.
7. `prompts/handoff/phase7/contract-fixes-2026-11-21.md` — the record of R5a.1, sections 5 and 8; item 3.4 corrects section 8.

PR #243, its review A (comment 7067240679) and its follow-up (comment 7067888643) hold the findings and the four questions that this step answers. They are evidence: every text that you write is in this prompt.

## §2 — Pre-Implementation Verification Gate

Run this BEFORE any edit:

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh sec2
```

It must end with `§2 PASS`. It checks the branch, that `d0a4414` is an ancestor, `VERSION`, a clean tree, the saved prompt and check file, the unpacked bundle in `/root/r5a2/files`, the tools (`python3` 3.12 or later, `node`, `npx`, `git`, `gh`, `sha256sum`, `comm`, `locale`, `env`, `node_modules` with Playwright, the `en_US.UTF-8` locale), that `gh` is logged in, that the three new paths that you write (the operator page, the review file and the record) do not exist yet, every anchor of Task Groups 1 to 3, and that each file this step changes is still byte-identical to `main` at `d0a4414`. On any other output STOP and post the checkpoint-failure comment.

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
- `prompts/handoff/phase7/contract-fixes-2026-11-21.md`

NEW (5):
- `Docs/operator/R5a.2-method-fixes.md`
- `prompts/handoff/phase7/method-fixes-2026-11-21-review.md`
- `prompts/handoff/phase7/method-fixes-2026-11-21-agent-prompt.md`
- `prompts/handoff/phase7/method-fixes-2026-11-21-checks.sh`
- `prompts/handoff/phase7/method-fixes-2026-11-21.md`

Write the list to the file that `git rev-parse --git-path scope-allowed.txt` names; it sits inside `.git`. The PRE-PR gate checks every changed path against it with `scripts/scope-gate.py`:

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh scope
```

It must print `scope list written: 15 paths`.

Files you MUST NOT modify: anything under `firmware/`, `src/`, `partitions/`, `config/`, `dashboard/`, `scripts/`, `tests/`, `.github/`, `.gemini/` and `Docs/lessons/`; every other file under `prompts/`; `package.json`, `package-lock.json`, `playwright.config.js`; `AGENTS.md`, `CLAUDE.md`, `README.md`, `VERSION`, `Docs/changelog.md`; every other file under `Docs/`. If the pipeline that `AGENTS.md` asks for before a commit changes `dashboard/dashboard.h` or another generated file, STOP: R5 made the header reproducible, so a change there is a finding.

You MUST NOT: run `bash scripts/bump-version.sh`; run `esphome compile`, `esphome upload` or `esphome run`; contact any board; call any Google service; start a workflow by hand; create a GitHub environment, variable or secret; create, close or edit issues or milestones; change branch protection; delete or move a file; read, pull or push the planning repository; merge.

## §4 — Critical Rules Checklist

- Rule 4 — `bash scripts/preflight.sh` must pass; the PRE-PR gate runs it.
- Rule 64 — every count in a check comes from the text of this prompt, not from memory.
- PLAN-012 — R5a.2 is the last method PR before R5b; it adds no rule that this prompt does not give. Batch prompt v3.0 stays shorter than version 2.0, `prompts/handoff/phase7-batch-production-prompt-update.md`: fewer lines and fewer bytes.
- PLAN-038 — `prompts/producer-contract.md` has at most 150 lines, each numbered rule ends with its tag, and the file changes only through a pull request with a decision row; PLAN-043 is that row.
- PLAN-027 and PLAN-032 — you start the inline round yourself; when Copilot posts no complete review, your assessment says so and the step goes on.
- PLAN-029 — `AGENTS.md` is the one source of rules for agents and reviewers; this step changes no instruction file.
- SEC-003 — no login, key or token in any command, file or PR text.

## §5 — DO-NOT List

- Do NOT reword, reformat or move text around an edit of Task Groups 1 to 3.
- Do NOT change a rule of the contract other than the lines of Task Group 1, and do NOT renumber a rule.
- Do NOT write a lesson entry in `Docs/lessons/`. List candidate lessons in §9 of the record only.
- Do NOT bump the version or add a changelog entry. The changelog entry of process guide §2.5 does not apply to this step, because `VERSION` does not change; §3 and this section govern here.
- Do NOT change the line "_Last verified: ..." or "_Next action: ...", or the table "What Just Shipped", of `CURRENT-STATE.md`. Process guide §2.5 item 2 asks for "Last verified" and "What Just Shipped", but neither applies here: "Last verified" records the operator's check of the boards, and "What Just Shipped" lists versioned steps. R5b stays the next action. Item 3.1 is the whole change of `CURRENT-STATE.md` in this step.
- Do NOT change `AGENTS.md`, `CLAUDE.md`, a Copilot instruction file or `.gemini/styleguide.md`. Item 3.1 routes the stale line of `AGENTS.md` instead.
- Do NOT change the operator page or the review file of R5a.1: they are the record of that dispatch; item 3.4 corrects the count instead.

## §6 — Implementation Steps

Commit after each checkpoint that passes, with a message that names the task group, and push.

### Task Group 1 — The producer texts: contract, consolidated-audit template, batch prompt v3.0

One internal round at every tier (rules 5.3 and 5.4), dispatch by a setup file and the operator's first comment (rules 6.3, 9.7 and 9.8), the Round Summary and the review round (rules 7.10, 7.12 and the new 7.13), the answers to review A's Q1, Q2 and Q4 of PR #243, and the trigger of Batch 2. Each replaced line keeps its rule number.

**1.1** `prompts/producer-contract.md`, rules 5.3 and 5.4: one internal round at every tier, and the pointer to rule 3.4:
replace the line
```
3. The tier sets the producer audit: LOW, lint; MEDIUM, one external auditor, GPT Astra in its own ChatGPT session; HIGH, two from different model families, GPT Astra and Gemini 4 Neon in AI Studio (PLAN-037, PLAN-041). Each auditor works in a session of its own. [gate: audit]
```
with
```
3. The tier sets the producer audit: LOW, lint and the internal round of rule 5.4; MEDIUM, the same and one external auditor, GPT Astra in its own ChatGPT session; HIGH, the same and two external auditors from different model families, GPT Astra and Gemini 4 Neon in AI Studio (PLAN-037, PLAN-041). Each auditor works in a session of its own. At every tier, code that the prompt carries is also compiled (rule 3.4). [gate: audit; gate: compile]
```
and replace the line
```
4. Before each external audit, one internal sub-agent audits the bundle with the external audit prompt and executes it: it runs the gates, writes its own implementation to the contract of the prompt and applies the edits. The producer checks each finding and fixes what holds. Stop at no new HIGH or MEDIUM, or after two internal rounds. The external audit stays (PLAN-040). [gate: audit]
```
with
```
4. At every tier, before dispatch and before any external audit, one internal sub-agent audits the bundle with an audit prompt from `Docs/templates/prompt-audit-template.md`, the external audit prompt where the tier has one, and executes it: it runs the gates, writes its own implementation to the contract of the prompt and applies the edits. The producer checks each finding and fixes what holds. LOW and MEDIUM run one round; HIGH runs a second round when the first finds a new HIGH or MEDIUM, and never a third. The external audit stays (PLAN-040, PLAN-043). [gate: audit]
```

**1.2** `prompts/producer-contract.md`, rules 6.3, 9.7 and 9.8: dispatch by a setup file, the gate record as the operator's first comment, the hand-over:
replace the line
```
3. The setup block is block A of process guide §2.2 with the branch, the PR title and the paths filled in, and one more step after the draft PR: it checks the SHA-256 of the prompt and of the check file and commits both, verbatim, as the first commit after the bootstrap commit. [gate: §2]
```
with
```
3. The setup block is block A of process guide §2.2 with the branch, the PR title and the paths filled in, and two more steps: before the branch work, it unpacks the bundle from the operator's clone of the planning repository and runs the file check of every file of the bundle; after the draft PR, it checks the SHA-256 of the prompt and of the check file and commits both, verbatim, as the first commit after the bootstrap commit. It is a file in `steps/<step>/`: the operator pulls the planning repository on the build host and pastes the dispatch paragraph, which names the setup file and its SHA-256, and the agent checks that hash before it runs a line of the file (PLAN-043). [gate: §2; gate: hand-over; judgment]
```
and replace the line
```
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, and the compile of rule 3.4 for a prompt of any tier that carries code ending in a compiled artifact. The record is the first comment of the PR. A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
```
with
```
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, and the compile of rule 3.4 for a prompt of any tier that carries code ending in a compiled artifact. The operator posts the record as the first operator comment of the PR; an inline bot may post before it (PLAN-043). A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
```
and replace the line
```
8. Hand-over: the producer gives the operator the bundle, the setup block, the operator page and the gate record. The gate record names the model, the provider and the tool that produced the prompt, and the builder and the rehearsal script (PLAN-030, PLAN-033); its file check runs first on the build host and checks the SHA-256 of every file of the bundle, before the setup block runs. [gate: hand-over]
```
with
```
8. Hand-over: the producer commits the bundle, the setup file and the gate record to `steps/<step>/` of the planning repository and gives the operator, in chat, the dispatch paragraph: the path of the setup file and its SHA-256. The gate record names the model, the provider and the tool that produced the prompt, the harness and the model of the coding agent as the operator names them, and the builder and the rehearsal script (PLAN-030, PLAN-033, PLAN-043); it gives the two numbers that the agent copies into §8 of the record, producer sessions and audit sessions. The file check of the setup file checks the SHA-256 of every file of the bundle before the branch work. [gate: hand-over]
```

**1.3** `prompts/producer-contract.md`, rules 7.10 and 7.12, and the new rule 7.13: the Round Summary, the end-of-round step, the blocks `inline` and `body`:
replace the line
```
10. §8 starts the PR body with the heading `## Pre-Implementation Verification`, then Per-Item Verification, Acceptance Criteria, Files Modified (with the line of the scope gate) and Round Summary; a prompt that wants the Audit Gate Notice that `AGENTS.md` names gives its text. The last `PRE-PR PASS at <commit>` in the body names the head of the PR. [gate: CI; judgment]
```
with
```
10. §8 starts the PR body with the heading `## Pre-Implementation Verification`, then Per-Item Verification, Acceptance Criteria, Files Modified (with the line of the scope gate) and Round Summary; a prompt that wants the Audit Gate Notice that `AGENTS.md` names gives its text. The Round Summary is a table with one row for each review round that the step runs, which begins with the name of the round (`| Inline |`, `| Review A |`, `| Review B |`, `| Review C |`) and gives the reviewers, the head that each reviewed, the findings and the outcome, or `pending` before the round. A ticked criterion says no `pending`. The last `PRE-PR PASS at <commit>` in the body names the head of the PR. [gate: CI; gate: checkpoint; judgment]
```
and replace the line
```
12. Items 8 to 13 of the setup block of process guide §2.2 hold: edits by the file-edit tool, the repair of one's own failed command, one test at a time, the review round, the stops, and the check file. A known tooling defect gets the recovery that the prompt writes, once (PLAN-027). [judgment]
```
with
```
12. Items 8 to 14 of the setup block of process guide §2.2 hold: edits by the file-edit tool, the repair of one's own failed command, one test at a time, the review round, the stops, the check file and the end of a round. A known tooling defect gets the recovery that the prompt writes, once (PLAN-027). [judgment]
```
and immediately after the line that begins with
```
12. Items 8 to 
```
insert
```
13. The review round of §6: the agent edits the PR body with `gh api --method PATCH`, runs `gh pr ready` and posts `/gemini review`; it pushes nothing until the check block `inline <PR#>` prints `inline PASS`, which waits for the three inline reviewers, at most 30 minutes after that comment (after `inline WAIT` it runs the block again); then it assesses and fixes. Each round ends with one end-of-round step: the record, the row of the round in the Round Summary, the boxes of the criteria that hold, the PRE-PR block and its last line in the body, the check block `body <PR#>`, then one assessment comment whose first line names the agent and its model as its harness shows them. A finding about the agent's own name is answered, never fixed by renaming. The agent runs `inline` only until it prints `inline PASS`, never after its first push. The blocks `inline` and `body` are those of the last merged check file, with the rounds of the step, and the prompt names the logins of the inline reviewers and the marks that the blocks read (PLAN-043). [gate: checkpoint; judgment]
```

**1.4** `prompts/producer-contract.md`, rule 8.1: any choice that the prompt leaves free (review A's Q1 of PR #243):
replace the line
```
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state. No supplied test and no check depends on an order, a spelling or a shared state that the prompt leaves free. [gate: rehearsal; judgment]
```
with
```
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state. No supplied test and no check depends on an order, a spelling, a shared state or any other choice that the prompt leaves free, such as an import. [gate: rehearsal; judgment]
```

**1.5** `prompts/phase7/consolidated-audit-template-phase7.md`, the definition of fix cycles and fix-cycle commits (review A's Q4 of PR #243):
replace the line
```
| Fix cycles | [0/1/2/...] | Times PR needed additional commits after review |
```
with
```
| Fix cycles | [0/1/2/...] | Review rounds that ended in at least one fix-cycle commit (PLAN-043) |
```
and immediately after the line that begins with
```
_Defects that escaped the prompt gates into agent execution: the unique defects
```
insert
```

_Fix-cycle commits after the first review round: the commits after the first review round that change a file because of a review finding, the fixes of the inline round's findings included; a commit that records a round and fixes no finding is not one. It is a count per step; HowTo §5.6 counts fix-cycle PRs per batch (PLAN-043)._
```

**1.6** `prompts/handoff/phase7-batch-production-prompt-v3.md`, the trigger of Batch 2:
replace the line
```
| Batch 2 | R5b | R5a.1 merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
```
with
```
| Batch 2 | R5b | R5a.2 merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
```

⛔ **CHECKPOINT A** — every edit of items 1.1 to 1.6; in each file the old wording that an item removes is gone from the whole file; the line counts of the three files; the contract still has at most 150 lines, each of its numbered rules ends with a tag in square brackets, and section 7 numbers its rules 1 to 13; batch prompt v3.0 still has fewer lines and fewer bytes than version 2.0; lint in normal mode passes on the three files.

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh A
```

### Task Group 2 — The process documents: process guide, planner page, audit template

The same rules in every place that states them (contract rule 1.4), and the answer to review A's Q3 of PR #243 in the start prompt of a planning session.

**2.1** `Docs/development-process-guide.md`, §2.1 item 6, §2.2, §2.4 and the tier table of §3.1:
replace the line
```
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and, for a prompt of any tier that carries code ending in a compiled artifact, compiles that code on a scratch branch from `origin/main` (`prompts/producer-contract.md` rule 3.4, PLAN-042). Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.
```
with
```
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and, for a prompt of any tier that carries code ending in a compiled artifact, compiles that code on a scratch branch from `origin/main` (`prompts/producer-contract.md` rule 3.4, PLAN-042). Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs, and the producer and audit numbers of the step) is the operator's first comment on the PR; an inline bot may post before it (PLAN-043). A mismatch is fixed in the prompt, never by changing an expected value to fit.
```
and replace the line
```
The operator gives the agent two things:
```
with
```
The operator pulls the planning repository on the build host and pastes the dispatch paragraph of the planning session: the path of the step's setup file in `steps/<step>/` and its SHA-256. The agent checks that hash and stops if it differs; then the setup file gives it two things (PLAN-043):
```
and replace the line
```
7) Update PR description (use PR176-178 as reference)
```
with
```
7) Write the PR body to §8 of the prompt, and edit it with `gh api --method PATCH repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pulls/<PR#> -F body=@<file>`
```
and replace the line
```
11) After `gh pr ready`: post the comment `/gemini review` on the PR; wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini; then assess each finding, fix what is warranted, and post one comment with your assessment that names any reviewer that did not post. Never merge, approve or start an external review
```
with
```
11) After `gh pr ready`: post the comment `/gemini review` on the PR; run the check block `inline <PR#>` until it prints `inline PASS` (it waits for Copilot, Codex and Gemini, at most 30 minutes after the comment), and push nothing before it; then assess each finding, fix what is warranted, and post one comment with your assessment that names any reviewer that did not post. Never merge, approve or start an external review
```
and immediately after the line that begins with
```
13) Run every gate and checkpoint from the check file that the prompt names
```
insert
```
14) End every review round with the end-of-round step of the prompt: the record, the row of the round in the Round Summary, the criteria, the PRE-PR block and its last line in the body, the check block `body <PR#>`, then your assessment, whose first line names you and your model as your harness shows them
```
and replace the line
```
Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance. Item 13 holds from R5 on (PLAN-031): the planning session hands over every check in one check file with its SHA-256.
```
with
```
Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance. Item 13 holds from R5 on (PLAN-031): the planning session hands over every check in one check file with its SHA-256. The block `inline` of item 11 and item 14 hold from R5a.2 on, the dispatch paragraph from R5b on (PLAN-043).
```
and replace the line
```
Claude Code is the fallback coding agent (PLAN-026). The agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout.
```
with
```
The coding agent runs an OpenAI Codex model, in the GitHub Copilot Chat agent of VS Code or in OpenAI's Codex agent; the gate record and the operator page name the harness and the model of each dispatch, and the agent names itself as its harness shows it (PLAN-043). Claude Code is the fallback coding agent (PLAN-026). The agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout.
```
and replace the line
```
| LOW | v7.7.1.2 | Lint; embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria |
```
with
```
| LOW | v7.7.1.2 | Lint + one internal audit round (PLAN-043); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria |
```
and replace the line
```
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria; prescribe only interface contracts |
```
with
```
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + one internal audit round (PLAN-040, PLAN-043), then one independent auditor (PLAN-037); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria; prescribe only interface contracts |
```
and replace the line
```
| HIGH | v7.7.1.4, v7.7.2.2, v7.7.3.3 | Lint + an internal audit (PLAN-040), then two auditors from different model families (PLAN-037, PLAN-041), reconciled in one file; embedded code compiled on a scratch branch before dispatch | Prescriptive allowed |
```
with
```
| HIGH | v7.7.1.4, v7.7.2.2, v7.7.3.3 | Lint + one or two internal audit rounds (PLAN-040, PLAN-043), then two auditors from different model families (PLAN-037, PLAN-041), reconciled in one file; embedded code compiled on a scratch branch before dispatch | Prescriptive allowed |
```
and replace the line
```
2. **Fix cycles per step** — times a PR needed additional commits after review. Track average.
```
with
```
2. **Fix cycles per step** — review rounds that ended in at least one fix-cycle commit, as the consolidated-audit template defines it (PLAN-043). Track average.
```

**2.2** `Docs/planner-start-here.md`, steps 6 to 8 of production, the start prompt (review A's Q3 of PR #243), and the end of a session:
replace the line
```
6. Before an external audit, one internal sub-agent audits the bundle with the external audit prompt and executes it: it runs the gates, writes its own implementation to the contract of the prompt, and applies the edits. The planning session checks each finding against the sources and fixes what holds. It stops when a round finds no new HIGH or MEDIUM, or after two internal rounds; the external audit stays (PLAN-040). Then, for a MEDIUM step, one independent auditor checks the bundle before dispatch: GPT Astra in its own ChatGPT session. For a HIGH step, two: GPT Astra and Gemini 4 Neon in AI Studio (PLAN-017, PLAN-037, PLAN-041). The planning session writes the audit prompt from `Docs/templates/prompt-audit-template.md`; the prompt names the parts of the bundle that are pending by design. The operator gives it and the bundle to the auditor in a session of its own and pastes the whole report back. The planning session checks each finding against the sources before it acts, fixes the bundle where the finding is right, rehearses again, and puts the audit prompt, the report and its dispositions into the audit file of the step, which the agent commits. When the fixes change the bundle, a new session audits the changed parts with a new prompt (template §7 step 8): its first turn without the earlier report, its second turn with the report and the dispositions. The planning session rates each finding by the severities of PLAN-037, with its evidence; where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (template §7 step 9, PLAN-037). The audit file of the step holds the prompts, the reports and the dispositions, in place of separate report files (template §7 step 5).
```
with
```
6. At every tier, before dispatch and before any external audit, one internal sub-agent audits the bundle with an audit prompt from `Docs/templates/prompt-audit-template.md`, the external audit prompt where the tier has one, and executes it: it runs the gates, writes its own implementation to the contract of the prompt, and applies the edits. The planning session checks each finding against the sources and fixes what holds. LOW and MEDIUM run one round; HIGH runs a second round when the first finds a new HIGH or MEDIUM, and never a third; the external audit stays (PLAN-040, PLAN-043). Then, for a MEDIUM step, one independent auditor checks the bundle before dispatch: GPT Astra in its own ChatGPT session. For a HIGH step, two: GPT Astra and Gemini 4 Neon in AI Studio (PLAN-017, PLAN-037, PLAN-041). The planning session writes the audit prompt from `Docs/templates/prompt-audit-template.md`; the prompt names the parts of the bundle that are pending by design. The operator gives it and the bundle to the auditor in a session of its own and pastes the whole report back. The planning session checks each finding against the sources before it acts, fixes the bundle where the finding is right, rehearses again, and puts the audit prompt, the report and its dispositions into the audit file of the step, which the agent commits. When the fixes change the bundle, a new session audits the changed parts with a new prompt (template §7 step 8): its first turn without the earlier report, its second turn with the report and the dispositions. The planning session rates each finding by the severities of PLAN-037, with its evidence; where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (template §7 step 9, PLAN-037). The audit file of the step holds the prompts, the reports and the dispositions, in place of separate report files (template §7 step 5).
```
and replace the line
```
7. Hand over: the prompt, the check file, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text. The check file holds every gate and checkpoint of the prompt, so the agent runs it and types no check (PLAN-031). The bundle, the setup block, the gate record and the planning tools go to `steps/<step>/` of the planning repository; the gate record gives the SHA-256 of the bundle (PLAN-040).
```
with
```
7. Hand over: the prompt, the check file, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text. The check file holds every gate and checkpoint of the prompt, so the agent runs it and types no check (PLAN-031). The bundle, the setup block, the gate record and the planning tools go to `steps/<step>/` of the planning repository; the gate record gives the SHA-256 of the bundle (PLAN-040), the harness and the model of the coding agent as the operator names them, and the producer and audit numbers. The operator pulls the planning repository on the build host; the planning session gives the dispatch paragraph in chat: the path of the setup file and its SHA-256 (PLAN-043).
```
and replace the line
```
8. After the merge, close the step: read the merged pull request and its audit, and correct the next prompt at its gate.
```
with
```
8. After the merge, close the step at the next restart check: confirm in your own clone that `main` holds the merge and that the checks of the step's operator page for after the merge pass, read the merged pull request and its audit, and correct the next prompt at its gate. After the merge the operator only updates the checkout on the build host to `main` (PLAN-043).
```
and replace the line
```
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check: a board command against AGENTS.md "Device Testing" and my latest fleet output, any other against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument: this covers the written text of a command and the checks of a check file; curl -u "$ESP_USER:$ESP_PASS" stays allowed in a command that I run. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
```
with
```
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check: a board command against AGENTS.md "Device Testing" and my latest fleet output, any other against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument: this covers the written text of a command and the checks of a check file; curl -u "$ESP_USER:$ESP_PASS" stays allowed in a command that the coding agent or I run. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
```
and immediately after the line that begins with
```
Keep working notes outside this repository, in the private planning repository
```
insert
```

At the end of its work, a planning session replaces "Read first" of the planning repository's `README.md` and ends it with the start prompt of the next session, filled in, with the open questions for the operator under "My decisions" (PLAN-043).
```

**2.3** `Docs/templates/prompt-audit-template.md`, an internal round at every tier: the note on how to use this file, the tier table, §6, §7, §8, §9, the version and the changelog:
replace the line
```
- **Template version:** v1.4
```
with
```
- **Template version:** v1.5
```
and replace the line
```
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint and no auditor, and every tier compiles its embedded code on a scratch branch (PLAN-042); MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
```
with
```
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint, one internal sub-agent round with an audit prompt from this template and no external auditor (PLAN-043), and every tier compiles its embedded code on a scratch branch (PLAN-042); MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
```
and replace the line
```
| LOW | Lint; compile embedded code on a scratch branch | No independent audit or reconciliation file; compile evidence if code is embedded |
```
with
```
| LOW | Lint + one internal round; compile embedded code on a scratch branch | No independent audit or reconciliation file; compile evidence if code is embedded |
```
and replace the line
```
| MEDIUM | Lint + one independent auditor; compile embedded code on a scratch branch | One audit report; no reconciliation file; compile evidence if code is embedded |
```
with
```
| MEDIUM | Lint + one internal round + one independent auditor; compile embedded code on a scratch branch | One audit report; no reconciliation file; compile evidence if code is embedded |
```
and replace the line
```
| HIGH | Lint + two independent auditors from different model families; compile embedded code on a scratch branch | Two audit reports and one reconciliation file; compile evidence if code is embedded |
```
with
```
| HIGH | Lint + one or two internal rounds + two independent auditors from different model families; compile embedded code on a scratch branch | Two audit reports and one reconciliation file; compile evidence if code is embedded |
```
and replace the line
```
This section applies to HIGH only. LOW requires lint and no audit report; MEDIUM uses its single audit report without reconciliation (PLAN-017).
```
with
```
This section applies to HIGH only. LOW requires lint, one internal round and no audit report; MEDIUM uses its single audit report without reconciliation (PLAN-017).
```
and replace the line
```
For LOW, steps 4 to 8 and the audit part of step 9 are not applicable; lint, the compile of step 9 and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
```
with
```
For LOW, steps 4 to 8 and the audit part of step 9 are not applicable; lint, the internal round of the note under step 4, the compile of step 9 and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
```
and replace the line
```
   PLAN-040 (2026-11-21): before step 4, one internal sub-agent audits the bundle with this audit prompt and executes it; the planning session checks each finding and fixes what holds; at most two internal rounds. It does not replace the audit of step 4. PLAN-037 and PLAN-041 name the auditors.
```
with
```
   PLAN-040 and PLAN-043 (2026-11-21): at every tier, before step 4, one internal sub-agent audits the bundle with this audit prompt and executes it; the planning session checks each finding and fixes what holds; LOW and MEDIUM run one round, HIGH a second when the first finds a new HIGH or MEDIUM, and never a third. It does not replace the audit of step 4. PLAN-037 and PLAN-041 name the auditors.
```
and replace the line
```
10. Dispatch only after the tier's gate is satisfied: LOW lint passes; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed. Every tier has compile evidence for any embedded code (PLAN-042) and also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
```
with
```
10. Dispatch only after the tier's gate is satisfied: LOW lint passes and its internal round is done; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed. Every tier has compile evidence for any embedded code (PLAN-042) and also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
```
and replace the line
```
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint and no audit:
```
with
```
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint, one internal round and no external audit:
```
and replace the line
```
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017): LOW = lint; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file; every tier = a compile gate for embedded code (PLAN-042).
```
with
```
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017, PLAN-043): every tier = one internal sub-agent round, HIGH at most two; LOW = lint; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file; every tier = a compile gate for embedded code (PLAN-042).
```
and immediately after the line that begins with
```
| v1.4 | 2026-11-21 |
```
insert
```
| v1.5 | 2026-11-21 | R5a.2 (PLAN-043): one internal sub-agent round at every tier, LOW included, and HIGH at most two: the note on how to use this file, the tier table, §6, §7 (the note under step 4, the LOW paragraph and step 10), §8 and §9. |
```

⛔ **CHECKPOINT B** — every edit of items 2.1 to 2.3; the old wording that an item removes is gone from the whole file; the line counts of the three files; the setup block of process guide §2.2 numbers its items 1 to 14.

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh B
```

### Task Group 3 — State, plan, decision, the record of R5a.1, supplied pages

**3.1** `CURRENT-STATE.md`, three rows of "Unimplemented Recommendations":
immediately after the line that begins with
```
| R5a review A (PR #241) |
```
insert
```
| R5a.1 process review (2026-11-21) | A `.gemini/config.yaml` with `code_review.pull_request_opened.code_review: false`, so that Gemini reviews only after `/gemini review` and posts nothing when a draft PR opens (Google's page "Customize Gemini Code Assist behavior in GitHub", read 2026-11-21); one test PR must show that `/gemini review` still works. It changes PLAN-039, "No `.gemini/config.yaml`" | **Not implemented** — routed to a later tooling step that the operator schedules (PLAN-043) |
| R5a.1 process review (2026-11-21) | The required check `pr-body-check.yml` also checks what the block `body` of a check file checks (the last `PRE-PR PASS at <commit>` names the head; no ticked criterion says pending; one Round Summary row for each round), so that GitHub enforces the PR body, edits after the merge included | **Not implemented** — routed to a later tooling step that the operator schedules (PLAN-043) |
| R5a.2 production (2026-11-21) | `AGENTS.md`, "PR Description Standards", still says "Use PRs #176-178 as reference for description format"; those PRs have no Round Summary, and process guide §2.2 item 7 no longer names them. Until it changes, §8 of the step's prompt governs the PR body | **Not implemented** — routed to the next pull request that changes `AGENTS.md` (PLAN-043) |
```

**3.2** `Docs/plan-of-record.md`, "You are here", row 6b and R5b's row of the ladder, the block of R5a.2, and sections 6 and 7:
replace the line
```
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a.1**, the fixes of the producer contract from the reviews of R5a (PLAN-042). The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
```
with
```
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a.2**, the method fixes from the reviews of R5a.1 (PLAN-043). The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
```
and immediately after the line that begins with
```
| 6a | R5a.1 |
```
insert
```
| 6b | R5a.2 | Method fixes from the reviews of R5a.1 (LOW, PLAN-043): an internal round at every tier, dispatch by a setup file, the checks `inline` and `body` of the review round | Dispatch, review and merge one documentation PR | R5a.1 | Unchanged | 1 to 2 | Done: the pull request that adds PLAN-043 |
```
and replace the line
```
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a.1 | Unchanged | 4 to 6 | Waiting |
```
with
```
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a.2 | Unchanged | 4 to 6 | Waiting |
```
and immediately after the line that begins with
```
- State after: version unchanged. R5b is produced under the fixed contract.
```
insert
```

### R5a.2: method fixes from the reviews of R5a.1 (documentation, LOW)

- Why: the reviews of PR #243 and the planner's process review of R5a.1 found that no check makes the agent wait for the inline round or keeps the PR body current, that the operator moves data that the planning session has already fixed, and four open questions of review A (PLAN-043).
- Scope: the coding agent of PLAN-019; one internal sub-agent round at every tier; dispatch by a setup file in the planning repository; the producer and audit numbers in the gate record; the Round Summary, the end-of-round step and the check blocks `inline` and `body`; the gate record as the operator's first comment; the after-merge check by the planning session; the filled start prompt at the end of "Read first"; review A's Q1 to Q4 of PR #243; the counts of the record of R5a.1; three rows of `CURRENT-STATE.md`.
- Who: the planning session writes the prompt, with one internal sub-agent round; the coding agent executes it; the inline round and review A run, reviews B and C do not.
- Done when: merged. It is the last method PR before R5b (risks 7 and 10).
- State after: version unchanged. R5b is produced under the changed contract, and its dispatch is the first by a setup file.
```
and replace the line
```
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint; the compile of any embedded code (PLAN-042) |
```
with
```
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint and one internal round; the compile of any embedded code (PLAN-042) |
```
and replace the line
```
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint and one independent auditor; the compile of any embedded code (PLAN-042) |
```
with
```
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint, one internal round and one independent auditor; the compile of any embedded code (PLAN-042) |
```
and replace the line
```
| v7.7.1.4 | HIGH | Prescriptive | Lint, two auditors from different model families reconciled in one file, and the compile gate in R7 |
```
with
```
| v7.7.1.4 | HIGH | Prescriptive | Lint, one or two internal rounds, two auditors from different model families reconciled in one file, and the compile gate in R7 |
```
and replace the line
```
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, checks that no fill-in is left, and compiles the code that the prompt carries and that ends in a compiled artifact (contract rule 3.4). Device values come only from the operator's latest fleet output. The record is the first comment of the PR.
```
with
```
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, checks that no fill-in is left, and compiles the code that the prompt carries and that ends in a compiled artifact (contract rule 3.4). Device values come only from the operator's latest fleet output. The operator posts the record as the first operator comment of the PR.
```
and replace the line
```
2. Dispatch. The operator pastes the setup block (process guide §2.2) and then the agent prompt, word for word. A step prompt closes its issue with `Fixes #N`: #214 for v7.7.1.2, #215 for v7.7.1.3, #216 for v7.7.1.4, #217 for v7.7.2.1, #218 for v7.7.2.2, #219 and #224 for v7.7.2.3, #220 for v7.7.3.1, #221 for v7.7.3.2, #222 for v7.7.3.3.
```
with
```
2. Dispatch. The operator pulls the planning repository on the build host and pastes the dispatch paragraph; the agent checks the setup file by its SHA-256 and follows it, and the setup file gives it the agent prompt, word for word (process guide §2.2, PLAN-043). A step prompt closes its issue with `Fixes #N`: #214 for v7.7.1.2, #215 for v7.7.1.3, #216 for v7.7.1.4, #217 for v7.7.2.1, #218 for v7.7.2.2, #219 and #224 for v7.7.2.3, #220 for v7.7.3.1, #221 for v7.7.3.2, #222 for v7.7.3.3.
```
and replace the line
```
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run: reviews A and C side by side, then review B by the runner, always last (PLAN-023). Section 7 shows the scheme.
```
with
```
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run: reviews A and C side by side, then review B by the runner, always last (PLAN-023). The agent waits for the inline round with the check block `inline` and ends each round with the check block `body` (PLAN-043). Section 7 shows the scheme.
```
and replace the line
```
5. Evidence check before the merge, by the operator. The PR body holds the gate outputs, the per-item verification and the device evidence. The branch holds the session log, the consolidated audit, `CURRENT-STATE.md`, the changelog entry, and this file with the step's row marked.
```
with
```
5. Evidence check before the merge, by the operator: the check block `body <PR#> final` prints `body final PASS`. The PR body holds the gate outputs, the per-item verification and the device evidence. The branch holds the session log, the consolidated audit, `CURRENT-STATE.md`, the changelog entry, and this file with the step's row marked.
```
and replace the line
```
7. Post-merge check: `VERSION` shows the new version; the boards that the step flashed report it.
```
with
```
7. Post-merge check: the operator updates the checkout on the build host to `main`, and the boards that the step flashed report the new version; the planning session checks `main` and `VERSION` at its next restart check (PLAN-043).
```
and replace the line
```
8. Metrics and step closure. The agent fills the process-metrics block of the consolidated audit. The planning session reads the merged PR and the audit, and corrects the next prompt at its gate.
```
with
```
8. Metrics and step closure. The agent fills the process-metrics block of the consolidated audit, with the producer and audit numbers of the gate record. The planning session reads the merged PR and the audit, and corrects the next prompt at its gate.
```
and replace the line
```
    Y->>A: Dispatch: setup block, then the prompt
```
with
```
    Y->>A: Dispatch paragraph: the setup file and its SHA-256
```

**3.3** `Docs/decisions/decision-log.md`, the decision row PLAN-043:
immediately after the line that begins with
```
| 2026-11-21 | PLAN-042 |
```
insert
```
| 2026-11-21 | PLAN-043 | R5a.2 before R5b, and the method changes from the reviews of R5a.1 (operator decisions 2026-11-21, within PLAN-012 and PLAN-017; R5a.2 is the last method PR before R5b): one small LOW documentation PR, row 6b of the plan of record, with one internal sub-agent round, the inline round and review A. Coding agent (amends the coding-agent clause of PLAN-019; PLAN-026 stands): an OpenAI Codex model codes, in the GitHub Copilot Chat agent of VS Code or in OpenAI's Codex agent; the operator names the harness and the model of each dispatch, the gate record and the operator page state them, and the agent names itself as its harness shows it. Internal audit (amends PLAN-040 and the tier rule of PLAN-017): one internal sub-agent round at every tier before dispatch, LOW included; HIGH runs a second round when the first finds a new HIGH or MEDIUM, and never a third. Dispatch (amends PLAN-035): the bundle, the setup file and the gate record are in `steps/<step>/` of the planning repository; the operator pulls that repository on the build host and pastes the dispatch paragraph, the path of the setup file and its SHA-256; the agent checks the hash, then follows the file, which unpacks the bundle and runs its file check; the agent never pulls or pushes the planning repository. The operator posts the gate record as the first operator comment of the PR and so keeps the independent anchor; the gate record gives the producer and audit numbers, which the agent copies into §8 of the record; the operator comments only if they change. Review round: the agent waits for the inline round with the check block `inline` (at most 30 minutes after `/gemini review`), pushes nothing before it passes, ends each round with one end-of-round step closed by the check block `body`, and edits the PR body with `gh api --method PATCH`; before the merge `body <PR#> final` prints PASS. After the merge the operator only updates the checkout on the build host to `main`; the planning session checks `main` at its next restart check. Each planning session ends "Read first" of the planning repository with the filled start prompt of the next one. Answers to review A of PR #243 (comment 7067240679): Q1, rule 8.1 covers any choice that the prompt leaves free, an import included; Q2, rule 5.3 points to rule 3.4; Q3, the start prompt allows `curl -u "$ESP_USER:$ESP_PASS"` in a command of the coding agent or the operator, as rule 4.3 does; Q4, a fix-cycle commit is a commit after the first review round that changes a file because of a review finding, §5 of a record counts the rounds with one and §8 the commits, a count per step in place of the fix-cycle PRs of HowTo §5.6, which a batch counts. The record of R5a.1 counts 2 escaped defects (the `curl -u` wording; the harness label "Codex" of its operator page and review file) and 1 fix-cycle commit. A `.gemini/config.yaml` test and an extension of `pr-body-check.yml` wait for a later tooling step | `prompts/handoff/phase7/method-fixes-2026-11-21.md` §6 |
```

**3.4** `prompts/handoff/phase7/contract-fixes-2026-11-21.md`, §8 of the record of R5a.1: the counts of review A's Q3 and Q4:
replace the line
```
| fix-cycle commits after the first review round | 2 |
```
with
```
| fix-cycle commits after the first review round | 1 |
```
and replace the line
```
| defects that escaped the prompt gates into agent execution | 0 |
```
with
```
| defects that escaped the prompt gates into agent execution | 2 |
```
and immediately after the line that begins with
```
| defects that escaped to devices | 0 |
```
insert
```

Corrected in R5a.2 (PLAN-043; review A of PR #243, Q3 and Q4): two defects of the bundle escaped into agent execution. The start prompt of `Docs/planner-start-here.md` allowed `curl -u "$ESP_USER:$ESP_PASS"` only "in a command that I run", against rule 4.3; the operator page and the review file named the coding agent "Codex", where the operator ran the GitHub Copilot Chat agent with GPT-5.3-Codex. One fix-cycle commit: `8bfb315` fixed review A's F1 and F2; `7b9d03d` recorded the inline round early and fixed no finding.
```

**3.5** Copy the two supplied files: the operator page `Docs/operator/R5a.2-method-fixes.md` and the review file `prompts/handoff/phase7/method-fixes-2026-11-21-review.md`. It must print `copied 2 files`.

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh copy
```

⛔ **CHECKPOINT C** — every edit of items 3.1 to 3.4; the old wording that an item removes is gone from the whole file; the line counts of the four files; the decision log has 67 lines that begin with `| ` (66 before) and its last line is unchanged; the two supplied files; the Mermaid blocks of the operator page and of the plan of record hold no semicolon.

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh C
```

### Task Group 4 — Record of this step (its consolidated audit)

**4.0** The setup block has made this prompt and its check file, verbatim, the first commit after the bootstrap commit. Confirm it with `git log --oneline -- prompts/handoff/phase7/method-fixes-2026-11-21-agent-prompt.md prompts/handoff/phase7/method-fixes-2026-11-21-checks.sh`: one commit. If it is missing, STOP.

**4.1** Create `prompts/handoff/phase7/method-fixes-2026-11-21.md` with these nine sections, each under a heading line that begins `## §<number> `, in this order and each once: §1 Why (R5a.2 in the plan of record, review A of PR #243 and its follow-up, PLAN-012, PLAN-017, PLAN-043); §2 Edit list, a table with one row per item 1.1 to 1.6, 2.1 to 2.3 and 3.1 to 3.5, and three cells in each row: the bare item number (such as 1.1), the check that covers it, and its observed output; §3 Review findings by severity (write the line `pending` until the end-of-round step of the first round; then update §3 in each end-of-round step, so that it is complete after the last round; name every reviewer that ran, and state plainly when one did not post or did not complete, PLAN-032); §4 Agent autonomous decisions: every choice that this prompt did not fix, each with its reason, or the line `none`; §5 Prompt Quality Score per `Docs/development-process-guide.md` §6.2, with any use of the recovery of the PRE-PR gate (write the line `pending` until the end-of-round step of the first round, which fills §5 together with §3; a use of the recovery goes into §5 as the PRE-PR block says); §6 Operator decisions recorded by this PR — the table below, verbatim; §7 Operator bookkeeping — the sentence below, verbatim; §8 Process metrics — the five rows of the table "Process metrics" in `prompts/phase7/consolidated-audit-template-phase7.md`, with these names: producer sessions for this step's prompt, audit sessions for this step's prompt, fix-cycle commits after the first review round, defects that escaped the prompt gates into agent execution, defects that escaped to devices; §9 Recommendations and where each was routed (process guide §2.5 item 4 (d)), and any candidate lesson, or the line `none` for each.

For §8 take the first two numbers, producer sessions and audit sessions, from the line of the gate record, the operator's first comment on the PR, that begins `Producer sessions for this step's prompt:`; if a later comment of the operator gives other numbers, take those. If the gate record is not on the PR yet, write `pending` in those two rows and fill them in the end-of-round step. Take the other three from this PR, as Task Group 1 defines them: a fix-cycle commit is a commit after the first review round that changes a file because of a review finding, the fixes of the inline round's findings included, and §5 counts the rounds that had one; the defects that escaped the prompt gates into agent execution are the unique defects of this step's bundle (this prompt, its check file and the two supplied files) that were found after dispatch, each counted once; an error of your own is not one of them, and goes into §4.

Table for §6 of the record:
```
| ID | Decision | Reason |
|---|---|---|
| PLAN-043 | R5a.2 comes before R5b as its own small LOW documentation PR, the last method PR before R5b, with one internal sub-agent round, the inline round and review A. An OpenAI Codex model codes, in the GitHub Copilot Chat agent of VS Code or in OpenAI's Codex agent, and the gate record names the harness and the model of each dispatch. One internal sub-agent round at every tier; HIGH at most two. Dispatch by a setup file in the planning repository, which the operator pulls, and a dispatch paragraph with its SHA-256. The operator posts the gate record as the first operator comment, with the producer and audit numbers. The check blocks `inline` and `body` close the review round. The answers to review A's Q1 to Q4 of PR #243; the counts of the record of R5a.1 | Reviews A of PRs #241 and #243 found the same gaps that no check enforced: the wait for the inline round, the PR body after a round, the agent's name; the operator moved data that the planning session had already fixed; each internal round of R5a and R5a.1 found a MEDIUM that the rehearsal missed; review A's four questions of PR #243 were unrouted |
```

Sentence for §7 of the record:
```
This step closes no issue; no milestone changes, and the step has no tag.
```

⛔ **CHECKPOINT D** — the nine sections in order; sections 1, 3, 4, 5 and 9 not empty; in §2 one table row per item 1.1 to 1.6, 2.1 to 2.3 and 3.1 to 3.5 that begins with the bare item number, then its check and its output; the table in §6; the sentence in §7; the five metrics in §8, each with a value; and no `<NN>` left.

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh D
```

### PRE-PR Gate

Commit and push everything first; the gate stops on an uncommitted change.

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh prepr
```

It must end with `PRE-PR PASS at <commit>`, the commit it ran on. After any later commit, run it again: the last `PRE-PR PASS at <commit>` in the PR body must name the head of the PR. Its first check is `scripts/scope-gate.py` against the list of §3. It also runs CHECKPOINTS A, B, C and D again on that commit, lint on the prompt files of this PR in baseline mode, lint in normal mode on every changed file (it must pass, and rule L11 must find nothing), the lint fixtures in two locales (`lint fixtures: 13 passed, 0 failed` in each), the two scope-gate cases (`scope-gate cases: 2 passed, 0 failed`), and the real `scripts/preflight.sh`, and then checks that preflight left the tree clean. Put its last line in the PR body.

Known tooling defect: the browser test of preflight has failed once without cause (PR #234). Preflight prints its report. If the block stops with `PRE-PR: preflight` and the output shows `playwright_manifest_spec: FAIL`, the operator has authorized this, once: confirm that no other preflight, Playwright run or mock server is active; post the lines after `playwright report:` as a PR comment; run the PRE-PR block one more time, unchanged. If it fails again, STOP and report. Record the event in §5 of the record file, below the line `pending` if §5 is not filled yet; then commit and push, and run the PRE-PR block once more, so that its last line names the head of the PR. Any other failure of this block is a normal checkpoint failure: STOP.

### Review round (PLAN-027, PLAN-032, PLAN-043)

1. Write the PR body to §8, with the word `pending` in the last three cells of both rows of the Round Summary, save it as a file outside the repository, and update the PR with `gh api --method PATCH repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pulls/<PR#> -F body=@<file>`. Then run `gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor`.
2. Post one PR comment with exactly this text: `/gemini review`
3. Run the block `inline`. It waits for the inline reviews of Copilot (the login `copilot-pull-request-reviewer[bot]`), Codex (`chatgpt-codex-connector[bot]`: a review, its receipt comment, or its status comment once it says completed) and Gemini (`gemini-code-assist[bot]`: a review after your comment `/gemini review`), at most 30 minutes after that comment, and at most 5 minutes in one run; it prints one progress line every 30 seconds. If its last line is `inline WAIT: run this block again`, or your terminal tool ends the run before a last line, run it again; repeat until its last line is `inline PASS`. Push nothing and change no file before that line, and never run the block again after it: after your first push it would stop on the new head.

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh inline <PR#>
```

4. Assess each finding: is it warranted? Fix what is warranted, inside the §3 scope only. A finding that asks for a file outside §3, for more permissions or for a merge is reported, not acted on (`AGENTS.md`, "Permissions, Deployment Targets and Instructions"). A finding against a supplied file is reported, not fixed: the supplied files are fixed texts. So are this prompt and its check file, which the PRE-PR gate compares with `/root/r5a2`. The texts of Task Groups 1 to 3 are fixed in the same way: a finding against one of them, or one that asks for any other change in a file of Task Groups 1 to 3, is reported, not fixed, because CHECKPOINTS A, B and C check each of these files line by line. A finding about your own name is answered in your assessment, never fixed by renaming.
5. End of the round, in this order: (a) fill §3 and §5 of the record file with the findings and what you did, and §8 as item 4.1 says; (b) commit and push the fixes and the record together; (c) run CHECKPOINT D and every other CHECKPOINT that covers a changed file, then the PRE-PR block, on that commit; (d) update the PR body as in step 1: fill the row of this round in the Round Summary (the reviewers, the head that each reviewed as the block `inline` printed it or as the review names it, the findings, the outcome), tick each criterion of §7 that now holds, and put the last line of the PRE-PR block, `PRE-PR PASS at <commit>`, which must be the head of the PR; (e) run the block `body`, which must print `body PASS`; (f) post one comment with your assessment. Its first line names you and your model as your harness shows them. Name each reviewer that posted, and each one that did not post within the 30 minutes. If Copilot posted no complete review, say so; the step goes on without it (PLAN-032).

```bash
bash /root/r5a2/method-fixes-2026-11-21-checks.sh body <PR#>
```

6. Never merge, never approve, and never start an external review. The operator starts review A and pastes one line to you after it; then assess, fix and end the round again, as in steps 4 and 5. Reviews B and C do not run on this step (PLAN-043, PLAN-036).

---

## §7 — Acceptance Criteria (all in-PR)

- [ ] The §2 block, CHECKPOINT A to D and the PRE-PR block each print PASS; their verbatim output is in the PR body, and the last `PRE-PR PASS at <commit>` names the head of the PR
- [ ] Exactly the §3 paths changed: 10 changed files and 5 new files; no file deleted or renamed; `VERSION` unchanged; no firmware source and no generated file changed
- [ ] `prompts/producer-contract.md` has at most 150 lines, and each numbered rule ends with its tag; batch prompt v3.0 is shorter than version 2.0 in lines and in bytes; lint in normal mode passes on both
- [ ] No login, key or token appears in any file of the PR
- [ ] The block `inline` printed `inline PASS` before the first assessment, and no commit was pushed between `gh pr ready` and that line
- [ ] The GitHub checks `preflight-and-compile`, `prompt-lint` and `pr-body-check` pass on the final head
- [ ] The record file is complete after the last review round and committed before the merge
- [ ] The block `body` printed `body PASS` at the end of each round
- [ ] PR title: `docs: R5a.2 — method fixes from the reviews of R5a.1 (PLAN-043)`
- [ ] PR body contains, in order: Pre-Implementation Verification (verbatim §2 output), Per-Item Verification (one row per item), Acceptance Criteria, Files Modified, Round Summary

## §8 — PR Description Skeleton

Same sections as §7, last bullet, each under a `## ` heading; the first heading is exactly `## Pre-Implementation Verification`. Under Files Modified, list the 10 changed files and the 5 new files by name, and paste the line `scope-gate: base …` that `scripts/scope-gate.py` printed in the PRE-PR gate. Device testing: N/A — this step flashes no board and calls no board. Under Round Summary, this table, with one row per round of this step; the block `body` checks that each row begins as shown and that a row of a round that has run no longer says `pending`:

```
| Round | Reviewers | Head reviewed | Findings | Outcome |
|---|---|---|---|---|
| Inline | Copilot, Codex, Gemini | pending | pending | pending |
| Review A | Claude, in its own session | pending | pending | pending |
```

Reviews B and C do not run on this step; say so under the table. The block `body` knows that review A has posted by a comment that begins `## Review A`, the first line of the review file's output form. A ticked criterion never says `pending`.

Until the body has the heading `## Pre-Implementation Verification`, the check `pr-body-check` fails on this PR; that is expected. Every path of this PR is a documentation path of the CI fast path (PLAN-028), so `preflight-and-compile` runs preflight only, with no ESPHome install and no compile. Browser Tests does not start: no changed path matches its filter.

## §9 — Post-Merge Bookkeeping (tag and close only)

This step has no tag and closes no issue. You do none of it.
