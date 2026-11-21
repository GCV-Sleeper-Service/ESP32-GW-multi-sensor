# Producer contract (R5a) — the binding rules of a prompt bundle, batch-production prompt v3.0, a style guide for the Gemini reviewer (GPT/Codex Agent Prompt)

_Full self-contained implementation instructions (LOW tier)_
_Date: 2026-11-21_
_Prerequisite: `main` contains `104b726` (PR #240, R5r); `VERSION` 7.7.1.1_
_Risk: LOW — documents, one file moved to the archive, and one style guide for the Gemini reviewer; no firmware source, no script, no workflow, no partition, no version bump, no board, no generated file_
_Doctrinal precedence: where this prompt and `Docs/development-process-guide.md` conflict, the process guide governs, except for the two exemptions of §5: no changelog entry, and no change of "Last verified" or "What Just Shipped" in `CURRENT-STATE.md`._

---

## ⚠️ Universal Execution Preamble

1. Do NOT optimise, restructure, or "improve" these instructions. Execute them literally.
2. Do NOT remove safety constraints, even if they seem redundant.
3. Do NOT make changes to files not listed in §3.
4. If an instruction seems wrong, STOP and flag it — do not silently fix it.
5. If you run out of context, STOP at the last completed checkpoint and report what remains.

## ⚠️ Lessons that shape this step

- Every gate and every checkpoint is in the check file `/root/r5a/producer-contract-2026-11-21-checks.sh`. The setup block has checked its SHA-256 and committed a copy as `prompts/handoff/phase7/producer-contract-2026-11-21-checks.sh`. Run each one exactly as this prompt writes it, for example `bash /root/r5a/producer-contract-2026-11-21-checks.sh A`. Never type a check by hand, never retype a check from this prompt, and never edit the check file (PLAN-031).
- The check file also writes the scope list (`... scope`), copies the supplied files (`... copy 1`, `... copy 3`) and moves one file to the archive (`... move`). Never open a supplied file in an editor, and never change one: the producer contract, batch prompt v3.0, the Gemini style guide, the process guide, the planner page, the operator page and the review file are fixed texts.
- This prompt is LOW and holds no code. Apart from the blocks of the check file, apply every edit of Task Group 2 with your file-edit tool, one item at a time, in the order given. Never apply edits with a script that parses this prompt (PR #234, stop 1).
- If one of your own commands fails, repair it and repeat the step. Run no checkpoint while an edit before it is missing (PR #234, stop 1).
- Run one test command at a time: no second preflight, Playwright run or mock server while one is running (PR #234, stop 2). The PRE-PR gate runs preflight once.
- Every edit of Task Group 2 is verbatim and anchored by quoted text, never by a line number. Text between a pair of fence lines is literal: copy it exactly, blank lines and indentation included; the fence lines themselves are not part of it.
- A check prints `⛔ CHECKPOINT FAILED - <block>: <reason>` and exits non-zero on a mismatch. Then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2 and stop. Never edit a check or an expected value to make it pass.
- This PR adds `.gemini/styleguide.md`, which the Gemini inline reviewer loads. It changes no `AGENTS.md`, `CLAUDE.md` or Copilot instruction file.
- This step needs no login, calls no board and calls no Google service. Never print, echo or write `$ESP_USER` or `$ESP_PASS`.

---

## §1 — Repository & Required Reading

The setup block has already created your feature branch `docs/r5a-2026-11` and committed this prompt and its check file. The §2 gate checks the branch.

Read completely, in this order:
0. `CURRENT-STATE.md` — every section; Task Group 2 edits six places.
1. `Docs/development-process-guide.md` — §2.2 to §2.5, §3 and §7.
2. `AGENTS.md` — every section.
3. `Docs/plan-of-record.md` — sections 2, 3, 5 (the blocks of R5r, R5a and R5b) and 10.
4. `Docs/decisions/decision-log.md` — the rows PLAN-012, PLAN-017, PLAN-023, PLAN-025, PLAN-029, PLAN-035 and PLAN-037.
5. After `copy 1`: `prompts/producer-contract.md`, `prompts/handoff/phase7-batch-production-prompt-v3.md` and `.gemini/styleguide.md`, whole files.

## §2 — Pre-Implementation Verification Gate

Run this BEFORE any edit:

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh sec2
```

It must end with `§2 PASS`. It checks the branch, that `104b726` is an ancestor, `VERSION`, a clean tree, the saved prompt and check file, the unpacked bundle in `/root/r5a/files`, the tools (`python3` 3.12 or later, `node_modules` with Playwright, the `en_US.UTF-8` locale), that no new path of §3 exists yet, every anchor of Task Group 2, and that each file this step changes or moves is still byte-identical to `main` at `104b726`. On any other output STOP and post the checkpoint-failure comment.

## §3 — Scope Boundary

Files you MAY modify (complete list, 17 paths; nothing else).

CHANGED (7):
- `CURRENT-STATE.md`
- `Docs/plan-of-record.md`
- `Docs/decisions/decision-log.md`
- `Docs/development-process-guide.md`
- `Docs/planner-start-here.md`
- `Docs/templates/prompt-audit-template.md`
- `Docs/archive/README.md`

NEW (9):
- `prompts/producer-contract.md`
- `prompts/handoff/phase7-batch-production-prompt-v3.md`
- `.gemini/styleguide.md`
- `Docs/operator/R5a-producer-contract.md`
- `prompts/handoff/phase7/producer-contract-2026-11-21-review.md`
- `prompts/handoff/phase7/producer-contract-2026-11-21-agent-prompt.md`
- `prompts/handoff/phase7/producer-contract-2026-11-21-checks.sh`
- `prompts/handoff/phase7/producer-contract-2026-11-21.md`
- `Docs/archive/planning-2026-05/phase7-github-tracking-supplement.md`

MOVED AWAY (1), only by the block `move`:
- `Docs/phase7-github-tracking-supplement.md`

Write the list to the file that `git rev-parse --git-path scope-allowed.txt` names; it sits inside `.git`. The PRE-PR gate checks every changed path against it with `scripts/scope-gate.py`, which counts a move as the old path and the new path:

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh scope
```

It must print `scope list written: 17 paths`.

Files you MUST NOT modify: anything under `firmware/`, `src/`, `partitions/`, `config/`, `dashboard/`, `scripts/`, `tests/` and `.github/`; every other file under `prompts/` and `.gemini/`; `package.json`, `package-lock.json`, `playwright.config.js`; `AGENTS.md`, `CLAUDE.md`, `README.md`, `VERSION`, `Docs/changelog.md`; every other file under `Docs/`. If the pipeline that `AGENTS.md` asks for before a commit changes `dashboard/dashboard.h` or another generated file, STOP: R5 made the header reproducible, so a change there is a finding.

You MUST NOT: run `bash scripts/bump-version.sh`; run `esphome compile`, `esphome upload` or `esphome run`; contact any board; call any Google service; start a workflow by hand; create a GitHub environment, variable or secret; create, close or edit issues or milestones; change branch protection; delete or move a file other than by the block `move`; merge.

## §4 — Critical Rules Checklist

- Rule 4 — `bash scripts/preflight.sh` must pass; the PRE-PR gate runs it.
- Rule 64 — every count in a check comes from the text of this prompt, not from memory.
- PLAN-012 — batch prompt v3.0 must be shorter than version 2.0, `prompts/handoff/phase7-batch-production-prompt-update.md`: fewer lines and fewer bytes.
- PLAN-025 — a file moves to `Docs/archive/` with `git mv` and no edit, so the move is a pure rename; live files that name it get the new path, while `Docs/changelog.md`, `prompts/**`, `Docs/archive/**` and the rows of the decision log keep the old one.
- PLAN-029 — `AGENTS.md` is the one source of rules for agents and reviewers; `.gemini/styleguide.md` copies four of its parts word for word.
- SEC-003 — no login, key or token in any command, file or PR text.

## §5 — DO-NOT List

- Do NOT reword, reformat or move text around an edit of Task Group 2.
- Do NOT edit the moved file: the block `move` renames it with `git mv`, and CHECKPOINT B checks that its content did not change.
- Do NOT add `.gemini/config.yaml` or any other file under `.gemini/`.
- Do NOT bump the version or add a changelog entry. The changelog entry of process guide §2.5 does not apply to this step, because `VERSION` does not change; §3 and this section govern here.
- Do NOT change the line "_Last verified: ..." or the table "What Just Shipped" of `CURRENT-STATE.md`. Process guide §2.5 item 2 asks for both, but neither applies here: "Last verified" records the operator's check of the boards, and "What Just Shipped" lists versioned steps. Task Group 2 is the whole change of `CURRENT-STATE.md` in this step.
- Do NOT change `AGENTS.md`, `CLAUDE.md` or a Copilot instruction file.
- Do NOT change an older batch-production prompt: version 1 and version 2.0 stay as history.

## §6 — Implementation Steps

Commit after each checkpoint that passes, with a message that names the task group, and push.

### Task Group 1 — The new texts: producer contract, batch prompt v3.0, Gemini style guide

**1.1** Copy the three supplied files: `prompts/producer-contract.md` (the binding rules of a prompt bundle, each tagged with the lint rule, the gate or the judgment that enforces it), `prompts/handoff/phase7-batch-production-prompt-v3.md` (version 3.0 of the batch-production prompt) and `.gemini/styleguide.md` (four parts of `AGENTS.md`, word for word, for the Gemini reviewer). It must print `copied 3 files`.

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh copy 1
```

⛔ **CHECKPOINT A** — the three files are the supplied ones; the contract has at most 150 lines, and each of its numbered rules ends with a tag in square brackets; batch prompt v3.0 has fewer lines and fewer bytes than version 2.0; lint in normal mode passes on both prompt files; below its line `---`, `.gemini/styleguide.md` holds four parts of `AGENTS.md` word for word, and nothing else: the table of generated files (the section "Generated Files (NEVER edit directly)"), the section "Critical Rules", the section "Code Review Checklist" and the section "Severity Classification".

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh A
```

### Task Group 2 — Documents: state, plan, decisions, audit template, archive

The step's choices and the operator's decisions of 2026-11-19 and 2026-11-21 are recorded (PLAN-038 to PLAN-041), the runner's runs are recorded, and the tracking supplement moves to the archive. CHECKPOINT B searches the whole file for the old wording of each status mark.

**2.1** `CURRENT-STATE.md`: exactly one line begins with `_Next action: `. Replace that whole line with
```
_Next action: R5b, the Batch 2 prompts re-produced under the producer contract `prompts/producer-contract.md` with batch prompt v3.0 (PLAN-017, PLAN-038). The review runner passed its dry run (2026-11-20) and its posting run (2026-11-21) on PR #239; the next code step, R4, uses it for review B. The order and the scope of every step are in `Docs/plan-of-record.md` (PLAN-024). Phase 7 Step v7.7.1.2 is dispatched after R5b._
```

**2.2** `CURRENT-STATE.md`: replace the line
```
1. **R5a, R5b** — the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017). No firmware change. Review B runs on the review runner from now on (PLAN-022, PLAN-023).
```
with
```
1. **R5b** — the Batch 2 prompts re-produced under the producer contract and batch prompt v3.0 (PLAN-017, PLAN-038). No firmware change. Review B runs on the review runner (PLAN-022, PLAN-023).
```

**2.3** `CURRENT-STATE.md`: replace the line
```
| R5c planning (CI logs) | The actions `checkout@v4`, `setup-node@v4`, `setup-python@v5`, `cache@v4` and `upload-artifact@v4` target Node.js 20; the runner forces them to Node.js 24 and warns that Node.js 20 is deprecated. `setup-node` also installs Node.js 20 for the jobs | **Not implemented** — no job fails yet; the operator decides when a CI maintenance step updates them |
```
with
```
| R5c planning (CI logs) | The actions `checkout@v4`, `setup-node@v4`, `setup-python@v5`, `cache@v4` and `upload-artifact@v4` target Node.js 20; the runner forces them to Node.js 24 and warns that Node.js 20 is deprecated. `setup-node` also installs Node.js 20 for the jobs. `.github/workflows/external-review.yml` pins `actions/checkout` at v4.4.0, which gives the same warning (run 44861784463) | **Not implemented** — no job fails yet; the operator decides when a CI maintenance step updates them |
```

**2.4** `CURRENT-STATE.md`: replace the line
```
| R5r | Prove the review runner on GitHub: a dry run on PR #239 that posts nothing and writes three turns to the run summary, then one posting run that posts one comment | **Pending operator post-merge check** — `Docs/operator/R5r-review-runner.md`, sections "Dry run" and "Posting run"; until both pass, a code step that needs review B waits for the runner, or the operator chooses to run review B as a Muse session in three turns (PLAN-023) |
```
with
```
| R5r | Prove the review runner on GitHub: a dry run on PR #239 that posts nothing and writes three turns to the run summary, then one posting run that posts one comment | **Done 2026-11-21** — dry run 44828100924 (`gemini-4-argon`, 2026-11-20) wrote three turns to its summary; posting run 44861784463 (`gemini-4-hydrogen`, 2026-11-21) posted one comment on PR #239; the sign-in used direct federation, with no service account. The last condition of R5r in plan of record section 5, that the next code step uses the runner for review B, is checked at R4 |
| PR #240 inline review and review A M1 | The three inline fixes of the runner (thought parts screened before reuse, the raw PR title screened, every Link header read) and the fix of review A finding M1 (encoded at signs and slashes) have no permanent test: their regression tests ran from a temporary file, because the supplied test file was fixed | **Not implemented** — routed to a later runner-hardening tooling step that the operator schedules |
| PR #240 review A L1, Q1 and Q2 | L1 (LOW): the runner reads the diff and the file list of the PR without pinning them to the two commits that its header prints; reading them through the compare endpoint, pinned to both commits, closes it. Q1: hidden HTML (comments, `<details>`) in the model's answer. Q2: Unicode spaces before a slash. Q1 and Q2 are not verified | **Not implemented** — routed to the runner-hardening step |
| R5r runs (2026-11-21) | The runner sends no check-run data, so review B marks the CI gates UNCLEAR and advises FIX FIRST on every step whose review file has CI gates; a data block with the check runs of the PR head (name, status, conclusion, head commit) fixes it | **Not implemented** — routed to the runner-hardening step; until then the operator's merge checklist covers the CI gates |
| R5r runs (2026-11-21) | A second profile (step 4 of "Add a profile" in `Docs/operator/R5r-review-runner.md`); a comparison of the runner's models on a PR with seeded defects; and, for the operator page, deleting an earlier runner comment before a new run, so that the model does not review its own earlier output | **Not implemented** — routed to the runner-hardening step |
| R5a internal audit (2026-11-21) | `AGENTS.md`, "PR Title and Body — Preservation Rules" item 2, names an "Audit Gate Notice" among the sections of a PR body. No document under `Docs/` defines it. The May 2026 prompt `prompts/handoff/phase7/issue-228-CDE-producer-session-prompt.md` gave a text for the PR of issue #228 §C to §E, which no longer holds, because the Batch 2 prompts are re-produced first (PLAN-017); §8 of the prompts of the restart steps does not ask for it, and R5a does not use it. Rule 7.10 of `prompts/producer-contract.md` asks for it only when a prompt gives its text | **Not implemented** — routed to the next pull request that changes `AGENTS.md` |
```

**2.5** `CURRENT-STATE.md`: immediately after the line that begins with
```
| The nine Batch 2 prompt files of May 2026:
```
insert
```
| `prompts/handoff/phase7-batch-production-prompt.md` (version 1), `prompts/handoff/phase7-batch-production-prompt-update.md` (version 2.0), and the banner of `prompts/handoff/phase7-prompt-production-instructions.md`, which names version 2.0 as current | 2026-05 | **Superseded** by `prompts/producer-contract.md` and `prompts/handoff/phase7-batch-production-prompt-v3.md` (PLAN-038). History only. |
```

**2.6** `CURRENT-STATE.md`: immediately after the line that begins with
```
| `Docs/planner-start-here.md` |
```
insert
```
| `prompts/producer-contract.md` | Producer contract: the binding rules of a prompt bundle (PLAN-038) |
```
and replace the line
```
_Documents that are history only are in `Docs/archive/`. `Docs/archive/README.md` lists what moved there on 2026-11-16 (PLAN-025)._
```
with
```
_Documents that are history only are in `Docs/archive/`. `Docs/archive/README.md` lists what moved there on 2026-11-16 and on 2026-11-21 (PLAN-025, PLAN-038)._
```

**2.7** `Docs/plan-of-record.md`: replace the line
```
The next step is **R5a**, the producer contract. The last merged step is **R5r**, the review-runner PR; its dry run and posting run come before the next code step.
```
with
```
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a**, the producer contract. The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
```

**2.8** `Docs/plan-of-record.md`: replace the line
```
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Merged: the pull request that added `.github/workflows/external-review.yml`; done when the conditions of its block in section 5 hold |
```
with
```
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Merged; dry run (2026-11-20) and posting run (2026-11-21) passed (runs 44828100924 and 44861784463); done when the next code step uses the runner for review B |
```

**2.9** `Docs/plan-of-record.md`: replace the line
```
| 6 | R5a | Producer contract and batch-production prompt v3.0 | Dispatch, review and merge one documentation PR | R5r | Unchanged | 1 to 2 | Waiting |
```
with
```
| 6 | R5a | Producer contract and batch-production prompt v3.0 | Dispatch, review and merge one documentation PR | R5r | Unchanged | 1 to 2 | Done: the pull request that added `prompts/producer-contract.md` |
```

**2.10** `Docs/plan-of-record.md`: replace the line
```
- R5a also decides: the form of the review file with its common part and the parts A, B and C; how a prompt hands over a long insertion; whether the Gemini inline reviewer gets a `.gemini/styleguide.md` (PLAN-029); and it takes the tracking rules of `Docs/phase7-github-tracking-supplement.md` into the contract (PLAN-025).
```
with
```
- R5a also decides: the form of the review file with its common part and the parts A, B and C; how a prompt hands over a long insertion; whether the Gemini inline reviewer gets a `.gemini/styleguide.md` (PLAN-029); and it takes the tracking rules of `Docs/archive/planning-2026-05/phase7-github-tracking-supplement.md` into the contract (PLAN-025).
- Decided in R5a (PLAN-038 to PLAN-041): the contract also holds the planner rules from review findings and from the audit of R5r; a long text reaches the agent as a supplied file; the review file has a common part, the checks of the step and the parts A, B and C; the Gemini inline reviewer gets `.gemini/styleguide.md`; the tracking supplement moves to the archive; an internal sub-agent audit comes before each external audit; the bundle goes to the planning repository; Gemini 4 Neon is the second auditor of a HIGH prompt. R5a is LOW: an internal sub-agent audit and no external auditor; reviews A and B on its PR.
```

**2.11** `Docs/plan-of-record.md`: delete the line
```
| The Gemini inline reviewer loads no instruction file of this repository | R5a |
```
and delete the line
```
| Three points of the review runner are not verified (section 5, R5r) | R5r, first dry run |
```
and replace the line
```
- Not verified yet, and decided by the first dry run: that Google's Agent Platform accepts the federated identity directly (the other way is a service account without a key); which value the `ref` claim has for a run from the Actions tab; the Python calls to the model. Before the operator relies on credits from more than one Google subscription, Google's terms are checked.
```
with
```
- Decided by the dry run of 2026-11-20 and the posting run of 2026-11-21 (runs 44828100924 and 44861784463): Agent Platform accepts the federated identity directly, with no service account; the condition on `refs/heads/main` and `workflow_dispatch` accepts a run started from the Actions tab; the Python calls to the model work. Before the operator relies on credits from more than one Google subscription, Google's terms are checked.
```
and replace the line
```
  - `dashboard/dashboard.h` is in the regenerated outputs of every code prompt, because each build changes it;
```
with
```
  - `dashboard/dashboard.h` is in the regenerated outputs of every code prompt that bumps the version, because the version is in the dashboard (R5 made the header reproducible);
```

**2.12** `Docs/decisions/decision-log.md`: immediately after the line that begins with
```
| 2026-11-18 | PLAN-037 |
```
insert
```
| 2026-11-21 | PLAN-038 | Producer contract and batch-production prompt v3.0 (R5a, within PLAN-012 and PLAN-017). `prompts/producer-contract.md` holds the binding rules of a prompt bundle, at most 150 lines, each tagged with the lint rule, the gate or the judgment that enforces it. It also holds the rules from review findings and from the audit of R5r that `Docs/planner-start-here.md` held, and the tracking rules of `Docs/phase7-github-tracking-supplement.md`, which moves to `Docs/archive/planning-2026-05/` with `git mv` (PLAN-025). `prompts/handoff/phase7-batch-production-prompt-v3.md` replaces version 2.0 and is shorter. The planning session decided the forms: a long text (a new file, a whole rewritten file, an insertion of more than 10 lines) reaches the agent as a supplied file with its SHA-256, copied by the check file; the review file has a table of reviews A, B and C, a common part, the checks of the step, parts A and B, part C when review C runs, and the line for after a review; a firmware step has no two-step prompt. The operator decided on 2026-11-21 that R5a is LOW, with an internal sub-agent audit and no external auditor, and that reviews A and B by the runner run on its pull request. This widens the scope of R5a in the plan of record (two files) to the places that state the rules it changes (contract rule 1.4) and to the operator decisions of 2026-11-19 and 2026-11-21 | `prompts/handoff/phase7/producer-contract-2026-11-21.md` §6 |
| 2026-11-21 | PLAN-039 | The Gemini inline reviewer gets `.gemini/styleguide.md` (operator decision 2026-11-21; completes PLAN-029). Google's pages on its code review (customize-repo-review and style-guide, read 2026-11-21) name `.gemini/config.yaml` and a style guide `styleguide.md` in the folder `.gemini/`; they do not name `AGENTS.md`. The file copies four parts of `AGENTS.md` word for word: the table of generated files, the section "Critical Rules", the review checklist and the severities. A PR that changes one of these parts of `AGENTS.md` changes the file too. No `.gemini/config.yaml` | `prompts/handoff/phase7/producer-contract-2026-11-21.md` §6 |
| 2026-11-21 | PLAN-040 | Planner working method (operator decisions 2026-11-19, after the R5r trial in `steps/R5r/subagent-trial-2026-11-18.md` of the planning repository). Before each external audit, one internal sub-agent audits the bundle with the external audit prompt and executes it: it runs the gates, writes its own implementation to the contract of the prompt and applies the edits. The planning session checks each finding against the sources and fixes what holds. It stops when a round finds no new HIGH or MEDIUM, or after two internal rounds; the external audit of PLAN-037 stays. An internal round is not an audit session of the process metrics, as the operator counted R5r's internal checks on PR #240. Each step's bundle, setup block, gate record and planning tools go to `steps/<step>/` of the planning repository, and the gate record gives the SHA-256 of the bundle (amends PLAN-035) | `prompts/producer-contract.md`, rules 1.3 and 5.4 |
| 2026-11-21 | PLAN-041 | Models (operator decisions 2026-11-21; amends PLAN-037). The second auditor of a HIGH prompt is Gemini 4 Neon in AI Studio, in place of Gemini 4 Argon. The review runner stays the default for review B, and its model list stays until Gemini 4 Neon is on Agent Platform. Each planning session reads Google's page "Model versions and lifecycle" for the runner's models; a model change of the runner is a small LOW pull request, then a dry run | `Docs/planner-start-here.md`, the restart check and step 6 |
```

After 2.12 the decision log has 65 lines that begin with `| ` (61 before), and its last line does not change.

**2.13** `Docs/templates/prompt-audit-template.md`: replace the line
```
   - `prompts/handoff/<<phase>>-batch-production-prompt-update.md` — for the canonical scope-guard whitelist and Errata.
```
with
```
   - `prompts/producer-contract.md` — the binding rules of a bundle (PLAN-038); `prompts/handoff/phase7-batch-production-prompt-v3.md` — the lessons of Phase 7 and the live-extract table of a batch.
```
and replace the line
```
- **Template version:** v1.2
```
with
```
- **Template version:** v1.3
```
and immediately after the line that begins with
```
| v1.2 | 2026-11-18 |
```
insert
```
| v1.3 | 2026-11-21 | R5a (PLAN-038, PLAN-040): the doctrinal sources name the producer contract and batch prompt v3.0; a note under §7 step 4 sets the internal sub-agent audit before the external audit. |
```
and immediately after the line that begins with
```
4. MEDIUM: launch one independent auditor using this template.
```
insert
```
   PLAN-040 (2026-11-21): before step 4, one internal sub-agent audits the bundle with this audit prompt and executes it; the planning session checks each finding and fixes what holds; at most two internal rounds. It does not replace the audit of step 4. PLAN-037 and PLAN-041 name the auditors.
```

**2.14** `Docs/archive/README.md`: immediately after the line that begins with
```
| `Docs/session-log-2026-05-06-v7.6.10.4.md` |
```
insert
```

## What moved here on 2026-11-21

One file, with `git mv` and no edit, in R5a (PLAN-025, PLAN-038). Its tracking rules are now in `prompts/producer-contract.md`, section 8.

| Old path | New path |
|---|---|
| `Docs/phase7-github-tracking-supplement.md` | `Docs/archive/planning-2026-05/phase7-github-tracking-supplement.md` |
```

**2.15** Move the tracking supplement to the archive with `git mv`. It must print `moved 1 file`.

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh move
```

⛔ **CHECKPOINT B** — every edit and every status mark of Task Group 2, the line counts of each changed file, and the move as a pure rename.

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh B
```

### Task Group 3 — Supplied pages: process guide, planner page, operator page, review file

**3.1** Copy the four supplied files: the new versions of `Docs/development-process-guide.md` (§2.2 and §3.1 point to the producer contract; §7.2 names `.gemini/styleguide.md`) and `Docs/planner-start-here.md` (the contract in the reading order; the runner's models in the restart check; the internal audit, Gemini 4 Neon and the hand-over to the planning repository in "How a step is produced"; its rule sections moved into the contract), the operator page `Docs/operator/R5a-producer-contract.md`, and the review file `prompts/handoff/phase7/producer-contract-2026-11-21-review.md`. It must print `copied 4 files`.

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh copy 3
```

⛔ **CHECKPOINT C** — the four supplied files; outside `prompts/`, `Docs/archive/`, `Docs/changelog.md` and the decision log, no file names the old path of the tracking supplement; the planner page names no Gemini 4 Argon and has no rule sections of its own; neither the audit template nor the process guide names version 2.0 (`phase7-batch-production-prompt-update.md`) or a `claude-two-step` file; the Mermaid block of the operator page holds no semicolon.

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh C
```

### Task Group 4 — Record of this step (its consolidated audit)

**4.0** The setup block has made this prompt and its check file, verbatim, the first commit after the bootstrap commit. Confirm it with `git log --oneline -- prompts/handoff/phase7/producer-contract-2026-11-21-agent-prompt.md prompts/handoff/phase7/producer-contract-2026-11-21-checks.sh`: one commit. If it is missing, STOP.

**4.1** Create `prompts/handoff/phase7/producer-contract-2026-11-21.md` with these nine sections, each under a heading line that begins `## §<number> `, in this order and each once: §1 Why (R5a in the plan of record, PLAN-012, PLAN-025, PLAN-029, PLAN-038 to PLAN-041); §2 Edit list, a table with one row per item 1.1, 2.1 to 2.15 and 3.1, and three cells in each row: the bare item number (such as 2.1), the check that covers it, and its observed output; §3 Review findings by severity (write the line `pending` until step 5 of the review round; then update §3 after each round, so that it is complete after the last round; name every reviewer that ran, and state plainly when one did not post or did not complete, PLAN-032); §4 Agent autonomous decisions: every choice that this prompt did not fix, each with its reason, or the line `none`; §5 Prompt Quality Score per `Docs/development-process-guide.md` §6.2, with any use of the recovery of the PRE-PR gate (write the line `pending` until step 5 of the review round, which fills §5 together with §3, before that round's PRE-PR run; a use of the recovery goes into §5 as the PRE-PR block says); §6 Operator decisions recorded by this PR — the table below, verbatim; §7 Operator bookkeeping — the sentence below, verbatim; §8 Process metrics — the five rows of the table "Process metrics" in `prompts/phase7/consolidated-audit-template-phase7.md`, with these names: producer sessions for this step's prompt, audit sessions for this step's prompt, fix-cycle commits after the first review round, defects that escaped the prompt gates into agent execution, defects that escaped to devices; §9 Recommendations and where each was routed (process guide §2.5 item 4 (d)). For §8 the operator gives you the first two numbers, producer sessions and audit sessions (official rounds only, PLAN-037), in a PR comment; until then write `pending` in their rows, and fill them in your next commit after that comment. Take the other three from this PR.

Table for §6 of the record:
```
| ID | Decision | Reason |
|---|---|---|
| PLAN-038 | The producer contract holds the binding rules of a bundle, the planner rules from review findings and from the audit of R5r, and the tracking rules; batch prompt v3.0 replaces version 2.0; a long text reaches the agent as a supplied file; the form of the review file; the tracking supplement moves to the archive; R5a is LOW, with an internal audit and no external auditor, and reviews A and B by the runner are to run on its PR | One source of producer rules of about 150 lines (HowTo §5.4); v3.0 shorter than v2.0 (PLAN-012); R5c and R5r handed over their long texts as supplied files, and each arrived byte for byte |
| PLAN-039 | The Gemini inline reviewer gets `.gemini/styleguide.md`, which copies four parts of `AGENTS.md` word for word | Google's pages name `.gemini/styleguide.md` and do not name `AGENTS.md`; without the file Gemini reviews without the rules of the project |
| PLAN-040 | An internal sub-agent audit before each external audit, at most two rounds; the bundle and the gate record in the planning repository | In the R5r trial the internal executing checks found every defect that would have stopped the agent, and the external auditor found more gaps in the text; both are needed |
| PLAN-041 | Gemini 4 Neon is the second auditor of a HIGH prompt; the runner stays the default for review B with its model list; each planning session checks the runner's models on Google's lifecycle page | The operator's choice of 2026-11-21; Neon and Argon are both selectable in AI Studio, and Neon is not yet on Agent Platform |
```

Sentence for §7 of the record:
```
No issue closes in this step, and no milestone changes. After the merge the operator marks §E of issue #228 closed in the status table of its body, with the number of this pull request.
```

⛔ **CHECKPOINT D** — the nine sections in order; sections 1, 3, 4, 5 and 9 not empty; in §2 one table row per item 1.1, 2.1 to 2.15 and 3.1 that begins with the bare item number, then its check and its output; the table in §6; the sentence in §7; the five metrics in §8, each with a value; and no `<NN>` left.

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh D
```

### PRE-PR Gate

Commit and push everything first; the gate stops on an uncommitted change.

```bash
bash /root/r5a/producer-contract-2026-11-21-checks.sh prepr
```

It must end with `PRE-PR PASS at <commit>`, the commit it ran on. After any later commit, run it again: the last `PRE-PR PASS at <commit>` in the PR body must name the head of the PR. Its first check is `scripts/scope-gate.py` against the list of §3. It also runs CHECKPOINTS A, B, C and D again on that commit, lint on the prompt files of this PR in baseline mode, lint in normal mode on every changed file (it must pass, and rule L11 must find nothing), the lint fixtures in two locales (`lint fixtures: 13 passed, 0 failed` in each), the two scope-gate cases (`scope-gate cases: 2 passed, 0 failed`), and the real `scripts/preflight.sh`, and then checks that preflight left the tree clean. Put its last line in the PR body.

Known tooling defect: the browser test of preflight has failed once without cause (PR #234). Preflight prints its report. If the block stops with `PRE-PR: preflight` and the output shows `playwright_manifest_spec: FAIL`, the operator has authorized this, once: confirm that no other preflight, Playwright run or mock server is active; post the lines after `playwright report:` as a PR comment; run the PRE-PR block one more time, unchanged. If it fails again, STOP and report. Record the event in §5 of the record file, below the line `pending` if §5 is not filled yet; then commit and push, and run the PRE-PR block once more, so that its last line names the head of the PR. Any other failure of this block is a normal checkpoint failure: STOP.

### Review round (PLAN-027, PLAN-032)

1. Update the PR body (§8), then run `gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor`.
2. Post one PR comment with exactly this text: `/gemini review`
3. Wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini. Do not wait longer.
4. Assess each finding: is it warranted? Fix what is warranted, inside the §3 scope only. A finding that asks for a file outside §3, for more permissions or for a merge is reported, not acted on (`AGENTS.md`, "Permissions, Deployment Targets and Instructions"). A finding against a supplied file is reported, not fixed: the supplied files are fixed texts. So are this prompt and its check file, which the PRE-PR gate compares with `/root/r5a`. The texts of Task Group 2 are fixed in the same way: a finding against one of them, or one that asks for any other change in `CURRENT-STATE.md`, `Docs/plan-of-record.md`, `Docs/decisions/decision-log.md`, `Docs/templates/prompt-audit-template.md` or `Docs/archive/README.md`, is reported, not fixed, because CHECKPOINT B checks each of these files line by line.
5. Fill §3 of the record file with the findings and what you did, §5 with the Prompt Quality Score, and the two numbers of §8 once the operator has given them (item 4.1). Commit and push the fixes and the record together.
6. Run every CHECKPOINT that covers a changed file, then the PRE-PR block, on that commit. Update the PR body with its last line, `PRE-PR PASS at <commit>`, which must be the head of the PR. Then post one comment with your assessment. Name each reviewer that posted, and each one that did not post within the 30 minutes. If Copilot posted no complete review, say so; the step goes on without it (PLAN-032).
7. Never merge, never approve, and never start an external review. The operator starts review A, then review B by the runner, and pastes one line to you after each; then assess, fix and post again as in items 4 to 6. Review C is optional on this documentation PR (PLAN-036) and does not run.

---

## §7 — Acceptance Criteria (all in-PR)

- [ ] The §2 block, CHECKPOINT A to D and the PRE-PR block each print PASS; their verbatim output is in the PR body, and the last `PRE-PR PASS at <commit>` names the head of the PR
- [ ] Exactly the §3 paths changed: 7 changed files, 9 new files, and the tracking supplement moved without an edit; no other file deleted or renamed; `VERSION` unchanged; no firmware source and no generated file changed
- [ ] `prompts/producer-contract.md` has at most 150 lines, and each numbered rule ends with its tag; batch prompt v3.0 is shorter than version 2.0 in lines and in bytes; lint in normal mode passes on both
- [ ] `.gemini/styleguide.md` holds its four parts of `AGENTS.md` word for word
- [ ] No login, key or token appears in any file of the PR
- [ ] The GitHub checks `preflight-and-compile`, `prompt-lint` and `pr-body-check` pass on the final head
- [ ] The record file is complete after the last review round and committed before the merge
- [ ] PR title: `docs: R5a — producer contract, batch-production prompt v3.0, Gemini style guide`
- [ ] PR body contains, in order: Pre-Implementation Verification (verbatim §2 output), Per-Item Verification (one row per item), Acceptance Criteria, Files Modified, Round Summary

## §8 — PR Description Skeleton

Same sections as §7, last bullet, each under a `## ` heading; the first heading is exactly `## Pre-Implementation Verification`. Under Files Modified, list the 7 changed files, the 9 new files and the moved file by name, and paste the line that `scripts/scope-gate.py` printed in the PRE-PR gate. Device testing: N/A — this step flashes no board and calls no board.

Until the body has that heading, the check `pr-body-check` fails on this PR; that is expected. The check `preflight-and-compile` takes its full job on this PR, with the ESPHome compile, because `.gemini/styleguide.md` is not on its list of documentation paths (PLAN-028). Browser Tests does not start: no changed path matches its filter. Give the results in the Round Summary.

## §9 — Post-Merge Bookkeeping (tag and close only)

This step has no tag, and it closes no issue. After the merge the operator marks §E of issue #228 closed in its status table. You do none of it.
