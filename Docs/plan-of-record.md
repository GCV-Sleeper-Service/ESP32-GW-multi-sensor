# Plan of Record

_The order and the scope of the steps from v7.7.1.1 to v1.0, and the work after v1.0._
_Written 2026-11-16 by the planning session of the restart, for the step R3c (PLAN-021, PLAN-024). It changes only through pull requests._

---

## 1. How to read this file

This file answers one question: which step comes next, and what is in it.

| Question | The source that wins |
|---|---|
| What was decided, and why? | `Docs/decisions/decision-log.md` |
| What is true now: version, boards, open issues? | `CURRENT-STATE.md` |
| Which step is next, what is its scope, when is it done? | This file |
| How is a step executed? | `Docs/development-process-guide.md`; the method itself is the HowTo it pins |
| What does the operator do in a step? | The page of the step in `Docs/operator/` |

Rules for this file:

- A step's pull request marks its own row in the ladder (section 3) and moves "You are here" (section 2). Process guide §2.5 item 2 asks for this.
- A change of the order or of the scope of a step writes a decision row first, then changes this file (HowTo §3.4).
- No planned date and no forecast date is stored here. Section 4 says how a forecast is computed.
- Nothing private is stored here: no MAC address, no hub port, no login.
- The fleet table is not here. It is in `CURRENT-STATE.md` (BOARD-002).
- The planning notes outside this repository are working notes in the private planning repository that `Docs/planner-start-here.md` names. They are not a source (PLAN-024, PLAN-035).

Who starts where: a planning or prompt-producing session starts at `Docs/planner-start-here.md`; a coding agent at `AGENTS.md`; the operator at `Docs/operator/`.

## 2. You are here

After PR #246 merges, the last merged step is **R4**, v7.7.1.2: per-device structs, keys, hash and persist defaults. The next action is production of the **v7.7.1.3** bundle by the planning session, then **R6**, its persist write path (PLAN-044). The v7.7.1.4 bundle follows R6's merge. PR #246 records the completed WROOM 24-hour observation, second C3 reading and assessed reviews A/B; final validation precedes operator merge.

## 3. The ladder

The steps in the order they run. Every step is on the path to v1.0, except R15, which runs beside Batch 4. Step names are kept from earlier plans, so they are not in numeric order; the first column is. SP is the standard procedure of section 6. Estimates follow section 4.

| # | Step | What happens | Operator's part | Needs | `VERSION` on `main` after (tag) | Estimate (sessions) | Actual (sessions) | Status |
|---|---|---|---|---|---|---|---|---|
| – | R0 | HowTo guide fixed and tagged | None | – | 7.7.1.1 (HowTo `v2.3.1`) | – | – | Done |
| 1 | R3a | Method-adoption PR: binds HowTo v2.3.1 and starts the pre-dispatch gate | Dispatch, review, merge | – | 7.7.1.1 | 2 to 3 | planning 3, operator 1 | Done 2026-11-14, PR #234 (`8062726`) |
| 2 | R1 | Environment check and history backups on the build host | Agent check, backups | – | 7.7.1.1 | 1 | not recorded | Done 2026-11-14 |
| 3 | R2 | Decisions | None left | – | 7.7.1.1 | – | – | Done 2026-11-11 |
| 4 | R3b | Housekeeping PR: documents match the code, fleet table, login out of the files agents read | Dispatch, review, merge, tracker bookkeeping | R3a | 7.7.1.1 | 2 to 3 | planning 5, operator 1 | Done 2026-11-15, PR #235 (`160e90c`) |
| 4a | R3c | Plan into the repository: this file, entry points by role, the archive of `Docs/`, the instruction files, the stop rules | Dispatch, review, merge | R3b | 7.7.1.1 | 2 to 3 | planning 4, operator 1 | Done 2026-11-16, PR #236 (`84e8569`) |
| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login, reproducible dashboard header | SP without the device moves | R3c | Unchanged | 2 to 3 | planning 2, operator 2 | Done 2026-11-16, PR #237 (`1a7bf84`) |
| 5a | R5c | CI runner pin (LOW): the four workflows on `ubuntu-24.04`, lint baseline mode in the C locale, two planner rules, the start prompt for a planning session | SP without the device moves | R5 | Unchanged | 1 to 2 | planning 2, operator 1 | Done: the pull request that pinned the runners to `ubuntu-24.04` |
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | planning 5, operator 2 | Merged; dry run (2026-11-20) and posting run (2026-11-21) passed (runs 44828100924 and 44861784463); done when the next code step uses the runner for review B |
| 6 | R5a | Producer contract and batch-production prompt v3.0 | Dispatch, review and merge one documentation PR | R5r | Unchanged | 1 to 2 | planning 2, operator 1 | Done: the pull request that added `prompts/producer-contract.md` |
| 6a | R5a.1 | Producer-contract fixes from the reviews of R5a, issue #242 (LOW, PLAN-042) | Dispatch, review and merge one documentation PR | R5a | Unchanged | 1 to 2 | planning 2, operator 1 | Done: the pull request that fixes issue #242 |
| 6b | R5a.2 | Method fixes from the reviews of R5a.1 (LOW, PLAN-043): an internal round at every tier, dispatch by a setup file, the checks `inline` and `body` of the review round | Dispatch, review and merge one documentation PR | R5a.1 | Unchanged | 1 to 2 | planning 2, operator 1 | Done: the pull request that adds PLAN-043 |
| 7 | R5b | Batch 2, rolling (PLAN-044): the method fixes from the reviews of PR #244, the assumption audit and the bundle of v7.7.1.2; the bundles of v7.7.1.3 and v7.7.1.4 follow after R4 and R6 | Dispatch, review and merge one documentation PR | R5a.2 | Unchanged | 4 to 6 | planning 2, operator 1 | Done: the pull request that adds PLAN-044 |
| 8 | R4 | v7.7.1.2: per-device structs, keys, hash (LOW) | SP | R5b | 7.7.1.2 (`v7.7.1.2`) | 2 to 3 | planning 3, operator 1 | Done 2026-11-24, PR #246 (`a33a5cc`) |
| 9 | R6 | v7.7.1.3: persist write path (MEDIUM), dual-write into a one-day ring; the test board .173 first; the new MAC of the sensor "outside" (PLAN-046) | SP; before dispatch, erase .173 and flash it over USB | R4; its bundle, produced after R4 merges, and one auditor session | 7.7.1.3 (`v7.7.1.3`) | 3 to 5 |  | Waiting |
| 10 | R7 | Compile gate for v7.7.1.4; backups | Backups copied off the build host; USB cable ready | R6 | 7.7.1.3 | 1 to 2 |  | Waiting |
| 11 | R8 | v7.7.1.4: restore engine and retention budgets (HIGH); .173 first, then the production boards | SP; stand by for USB recovery | R7; its bundle, produced after R6 merges, and two auditor sessions | 7.7.1.4 (`v7.7.1.4`) | 3 to 5 |  | Waiting |
| 12 | R18a | v7.7.1.5: new board secrets, per-board API key and OTA password (LOW) | New values; flash every project board in one sitting; paste the check output | R8 | 7.7.1.5 (`v7.7.1.5`) | 1 to 2 |  | Waiting |
| 13 | R9 | Batch 3 prompts produced and audited | The auditor sessions; dispatch, review and merge one documentation PR | R18a | 7.7.1.5 | 2 to 3 |  | Waiting |
| 14 | R10 | v7.7.2.1: engine switchover (MEDIUM) | SP | R9 | 7.7.2.1 (`v7.7.2.1`) | 3 to 5 |  | Waiting |
| 15 | R11 | Compile gate, rehearsal on .173, v7.7.2.2 migration (HIGH) | The rehearsal and the backups; SP | R10 | 7.7.2.2 (`v7.7.2.2`) | 4 to 6 |  | Waiting |
| 16 | R12 | v7.7.2.3: per-device delete and socket cap (MEDIUM) | SP; tag `v1.0-rc1` | R11 | 7.7.2.3 (`v7.7.2.3`, `v1.0-rc1`) | 2 to 3 |  | Waiting |
| 17 | R13 | Batch 4 prompts produced and audited | The auditor sessions; dispatch, review and merge one documentation PR | R12 | 7.7.2.3 | 1 to 2 |  | Waiting |
| 18 | R14 | v7.7.3.1: per-device export and import (MEDIUM) | SP | R13 | 7.7.3.1 (`v7.7.3.1`) | 3 to 5 |  | Waiting |
| – | R15 | Critical-rule retirement PR, documentation only, beside Batch 4 | Dispatch, review and merge | R5a | Unchanged | 1 to 2, not counted |  | Waiting; may slip past v1.0 |
| 19 | R16 | v7.7.3.2: bundle export and import (MEDIUM) | SP | R14 | 7.7.3.2 (`v7.7.3.2`) | 2 to 3 |  | Waiting |
| 20 | R17 | v7.7.3.3: Phase 7 closure (HIGH) | SP and the closure checks | R16 | 7.7.3.3 (`v7.7.3.3`) | 2 to 3 |  | Waiting |
| 21 | R18 | Tag v1.0 | Tag, release, README PR | R17 | 7.7.3.3 (`v1.0`) | 1 to 2 |  | Waiting |

v1.0 is v7.7.3.3 (PLAN-015). ESPHome stays at 2026.4.1 through v1.0 (PLAN-016).

## 4. Estimates

Quality, functionality and security come before speed. No estimate justifies skipping a check, shortening a review or merging early (PLAN-018).

- The unit is one session: one sitting of the operator in which one pull request is dispatched, reviewed and merged, or one operator task is done.
- An estimate is a range. Its low end is the planned length of the step. Its high end adds 40 %, rounded up.
- Sessions to go to a milestone: add the estimates of the rows that are not done, up to the row of the milestone. R15 is not counted.
- "Actual (sessions)" records what a step took, as "planning N, operator M" (PLAN-045). Planning: the producer and audit sessions of the step's gate record, plus the session that closed the step. Operator: the sittings from dispatch to merge, read from the PR's timeline; the operator corrects it. The PR of the next step writes it, from a line that the planning session gives. The rows before R4 were filled from the records and the PR timelines on 2026-11-22: a sitting there is a run of activity on the PR without a gap of 3 hours.
- A forecast is computed, never typed in: the day of the last completed step, plus the sessions to go divided by the operator's pace in sessions a week. It is computed again when a step completes. This file stores no forecast date, because it would be stale after every step.

## 5. Steps: scope and done-when

One block for each step from R3c on. A prompt may narrow a scope. Only a decision row may widen it.

### R3c: plan into the repository (documentation, LOW)

- Scope: this file; `Docs/planner-start-here.md`; the archive moves of PLAN-025 with `Docs/archive/README.md`; the instruction files (PLAN-029); the fallback coding agent (PLAN-026); the review round and the stop rules (PLAN-027); the decision rows PLAN-022 to PLAN-030; the operator pages for R3c and R5.
- Done when: the pull request is merged.
- State after: `VERSION` 7.7.1.1. A planner or an agent of any vendor can work from the repository alone.

### R5: tooling PR (LOW)

- Who: the planning session writes the prompt and runs its gate; the coding agent executes it. All five reviews of PLAN-019, as for any code PR at that time.
- Scope, and nothing else (PLAN-017, PLAN-020, PLAN-028, PLAN-031):
  1. `scripts/scope-gate.py`, copied from the HowTo at tag `v2.3.1` (`templates/scope-gate.py`), with the two integration cases of its `tests/run-tests.sh` adapted to this repository.
  2. Lint rule L8 in `scripts/lint-prompts.sh`: a `pdMS_TO_TICKS(N)` value within 3 lines of "Rule 61" in `prompts/**` that differs from the live value in `maybe_yield_nvs_scan_()` (`firmware/core/nvs-persistence.h`) is an ERROR.
  3. Two recurrence rules (ERROR): a step agent prompt whose PR body has no closing line `Fixes #N`; and any agent prompt that runs `git checkout main` or `git switch main`.
  4. A credential-literal rule (ERROR) for a literal login after `-u` or `--user`, and for `Authorization: Basic` with a value. The rule holds no real value.
  5. `scripts/stress-test-httpd-stack.sh`: no default login; it takes `ESP_USER` and `ESP_PASS` from the environment and stops when one is unset.
  6. `.github/workflows/ci.yml`: the required job `preflight-and-compile` still starts on every pull request. Its first step lists the changed paths. When every path is documentation, it runs preflight only and skips the ESPHome install and the compile. Any other path, and any path the list does not know, runs the full job (PLAN-028). The R5 prompt fixes the list of documentation paths and tests it in its rehearsal.
  7. `scripts/preflight.sh` prints the report of the browser test when that test fails (PLAN-020).
  8. A PR-body check that fails when a pull request that touches `prompts/**` has no "Pre-Implementation Verification" heading.
  9. `scripts/generate-header.sh` compresses with `gzip -n`, so `dashboard/dashboard.h` changes only when the dashboard changes; R5 writes the header once with the pipeline (PLAN-031).
- Each lint rule gets one passing and one failing fixture under `tests/lint-prompts/`, with made-up values only, and works in `--baseline` mode, so old prompts report EXISTING and do not block.
- The workflow `prompt-lint` also runs these fixtures and the two scope-gate cases (PLAN-031).
- Decided in R5 (PLAN-033): the planning tools (the prompt builder and the rehearsal script) and the operator's helper file stay outside the repository.
- Done when: merged; `bash scripts/lint-prompts.sh` runs the new rules, each with its two fixtures; `scripts/scope-gate.py` passes its two cases; the stress-test script stops without a login in the environment; a documentation-only pull request skips the compile; a second run of the pipeline leaves `dashboard/dashboard.h` unchanged; issue #228 §C is closed.
- State after: version unchanged.

### R5c: CI runner pin (LOW)

- Who: the planning session writes the prompt and runs its gate; the coding agent executes it. All five reviews of PLAN-019, as for any code PR at that time.
- Why: GitHub moves `ubuntu-latest` to Ubuntu 26.04, where Playwright 1.56.0 cannot install its browsers, so Browser Tests failed on PR #237 and on `main`. After the R5 merge the lint fixtures failed in the operator's shell, which runs in `en_US.UTF-8`.
- Scope, and nothing else (PLAN-034):
  1. The four workflows run on `ubuntu-24.04`; `browser-tests.yml` also starts when its own file changes.
  2. `scripts/lint-prompts.sh` runs `comm` with `LC_ALL=C` in baseline mode.
  3. `Docs/planner-start-here.md`: the two planner rules of PLAN-034 and the start prompt for a planning session; process guide section 7.1 says which workflows can be started by hand.
  4. This file, the decision log and `CURRENT-STATE.md`.
- Done when: merged; Browser Tests is green on the pull request and on `main`; the lint fixtures pass in `C.UTF-8` and in `en_US.UTF-8`.
- State after: version unchanged. Before each dispatch, the planning session checks the runs of the workflows that the step starts (PLAN-034).

### R5r: review-runner PR (MEDIUM)

- Who: the planning session writes the prompt; one independent auditor checks it before dispatch; the coding agent executes it. All five reviews. The runner cannot review the pull request that installs it.
- Scope: the workflow `.github/workflows/external-review.yml` and its script, as PLAN-022 states them; and every place that states the review pipeline, as PLAN-023 lists them.
- Decided before R5r (PLAN-036, PLAN-037): one profile, `default`, as variables of the GitHub environment `external-review`, with a documented way to add one; the turn texts in `Docs/templates/external-review-template.md`; the script on the Python standard library only; the dry run on PR #239 with its agent prompt and review file, because the diff of PR #235 holds deleted login literals. R5r also carries the planning repository (PLAN-035) and routes the PR #239 review A finding on `esphome run` advice.
- Decided by the dry run of 2026-11-20 and the posting run of 2026-11-21 (runs 44828100924 and 44861784463): Agent Platform accepts the federated identity directly, with no service account; the condition on `refs/heads/main` and `workflow_dispatch` accepts a run started from the Actions tab; the Python calls to the model work. Before the operator relies on credits from more than one Google subscription, Google's terms are checked.
- Done when: merged; a dry run on PR #239 posts nothing and writes a three-turn review to the run summary; one posting run posts one comment; the next code step uses the runner for review B.
- State after: version unchanged. PLAN-023 is in force: reviews A and C, then review B by the runner (section 7).

### R5a: producer contract and batch-production prompt v3.0 (documentation)

- Who: a prompt-producing session writes two files; the coding agent commits them in one documentation PR.
- Scope: `prompts/producer-contract.md`, at most 150 lines, binding rules only, each tagged with the lint rule, the gate or the judgment that enforces it; and `prompts/handoff/phase7-batch-production-prompt-v3.md`, a minimal change of v2.0 that must be shorter than v2.0 (PLAN-012). The contract covers: the live-extract table, symbol anchors, `<MEASURED>` placeholders, self-containedness, compile before dispatch for prescriptive prompts, the tier table with the prompt style of each tier, the pre-dispatch gate, the section skeleton of the HowTo agent-prompt template, the setup block and the review file, and the handoff template.
- R5a also decides: the form of the review file with its common part and the parts A, B and C; how a prompt hands over a long insertion; whether the Gemini inline reviewer gets a `.gemini/styleguide.md` (PLAN-029); and it takes the tracking rules of `Docs/archive/planning-2026-05/phase7-github-tracking-supplement.md` into the contract (PLAN-025).
- Decided in R5a (PLAN-038 to PLAN-041): the contract also holds the planner rules from review findings and from the audit of R5r; a long text reaches the agent as a supplied file; the review file has a common part, the checks of the step and the parts A, B and C; the Gemini inline reviewer gets `.gemini/styleguide.md`; the tracking supplement moves to the archive; an internal sub-agent audit comes before each external audit; the bundle goes to the planning repository; Gemini 4 Neon is the second auditor of a HIGH prompt. R5a is LOW: an internal sub-agent audit and no external auditor; reviews A and B on its PR.
- Done when: both files are on `main` and lint passes on them.

### R5a.1: producer-contract fixes (documentation, LOW)

- Why: reviews A and B of PR #241 found seven defects in the fixed texts of R5a. The operator routed them to issue #242 and put this step before R5b (PLAN-042).
- Scope: the findings of issue #242 and of its comment 7060767358 in `prompts/producer-contract.md`, batch prompt v3.0 and the start prompt of `Docs/planner-start-here.md`; compile before dispatch for every prompt that carries code, in contract rules 3.4 and 9.7, process guide §2.1 and §3.1, the audit template, the blocks R5b, R9 and R13 and section 6 of this file; the reading of the escaped-defects metric in the consolidated-audit template and in §8 of the record of R5a; the routing of the Gemini style-guide sync in a row of `CURRENT-STATE.md` and in §9 of the record of R5a.
- Who: the planning session writes the prompt, with one internal sub-agent audit (PLAN-040); the coding agent executes it; the inline round and review A run, reviews B and C do not.
- Done when: merged, and issue #242 is closed.
- State after: version unchanged. R5b is produced under the fixed contract.

### R5a.2: method fixes from the reviews of R5a.1 (documentation, LOW)

- Why: the reviews of PR #243 and the planner's process review of R5a.1 found that no check makes the agent wait for the inline round or keeps the PR body current, that the operator moves data that the planning session has already fixed, and four open questions of review A (PLAN-043).
- Scope: the coding agent of PLAN-019; one internal sub-agent round at every tier; dispatch by a setup file in the planning repository; the producer and audit numbers in the gate record; the Round Summary, the end-of-round step and the check blocks `inline` and `body`; the gate record as the operator's first comment; the after-merge check by the planning session; the filled start prompt at the end of "Read first"; review A's Q1 to Q4 of PR #243; the counts of the record of R5a.1; three rows of `CURRENT-STATE.md`.
- Who: the planning session writes the prompt, with one internal sub-agent round; the coding agent executes it; the inline round and review A run, reviews B and C do not.
- Done when: merged. It is the last method PR before R5b (risks 7 and 10).
- State after: version unchanged. R5b is produced under the changed contract, and its dispatch is the first by a setup file.

### R5b: Batch 2 re-produced (documentation)

- Who: a prompt-producing session; the coding agent commits the files. R5b itself is LOW: one internal round and no independent auditor; each bundle of the batch gets the auditors of its tier before its own dispatch (PLAN-044).
- Scope, rolling (PLAN-044): R5b's PR holds the method fixes from the reviews of PR #244, `AGENTS.md` included, PLAN-044, the bundle of v7.7.1.2 that replaces its May 2026 files under the same names, and `prompts/handoff/phase7/phase7-batch2-assumption-audit.md` with the live-extract table of v7.7.1.2; it deletes the three two-step files of May 2026. The bundle of v7.7.1.3 is produced after R4 merges and the bundle of v7.7.1.4 after R6 merges, each from the code then on `main`; each reaches `main` in its own step's PR, with its section of the assumption audit. The May prompts are source material, not text to copy.

| Step | Tier | Prompt style | Audit before dispatch |
|---|---|---|---|
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint and one internal round; the compile of any embedded code (PLAN-042) |
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint, one internal round (a further one optional when a round or an external audit finds a new HIGH or MEDIUM; at most three per planning session, PLAN-048) and one independent auditor; the compile of any embedded code (PLAN-042) |
| v7.7.1.4 | HIGH | Prescriptive | Lint, one internal round (a further one when a round or an external audit finds a new HIGH or MEDIUM; at most three per planning session, PLAN-048), two auditors from different model families reconciled in one file, and the compile gate in R7 |

- The assumption audit settles each leftover:
  - the third-audit findings of PR #233: H-1 (declaration order in v7.7.1.4), L-1 (boot test on both satellites), M-1 (pre-filled sizes), M-2 (line-number anchors);
  - the version is read from `/api/status/full`, because the public `/api/status` holds no version;
  - `Fixes #214`, `#215` and `#216` as closing lines; no pre-filled struct size; a branch check in place of `git checkout main`;
  - a test board first: v7.7.1.3 names .189, .170 and .173; v7.7.1.4 names .173 first, then .189, .170 and .191;
  - no login literal: `-u "$ESP_USER:$ESP_PASS"` only (SEC-003);
  - `dashboard/dashboard.h` is in the regenerated outputs of every code prompt that bumps the version, because the version is in the dashboard (R5 made the header reproducible);
  - a `.bin` size checkpoint against the OTA slot from v7.7.1.3 on; the WROOM's `min_free_heap` after a fresh boot and a day later.
- Compile before dispatch (PLAN-042): a prompt of any tier that carries code ending in a compiled artifact has that code compiled on a scratch branch first. If the prompt of v7.7.1.3 carries such code, its compile runs in its pre-dispatch gate, once v7.7.1.2 is on `main`; the compile of v7.7.1.4 runs in R7.
- Budget: one producer session for R5b and one for each later bundle, plus the audits. If the audit sessions pass twice the producer sessions, stop and decide (process guide §4.3 item 7).
- Done when: R5b is merged. The batch metrics of Batch 2 are recorded in the reconciliation file of v7.7.1.4, the last bundle of the batch (audit template §9, PLAN-044).
- State after: version unchanged. v7.7.1.2 is cleared for its pre-dispatch gate.

### R4: v7.7.1.2, per-device structs, key scheme, hash (LOW)

- Extra checks before the merge: the changelog shows measured `sizeof()` values; the C3 heap, read at an uptime of 180 s or more as the higher of two readings 30 s apart, is no more than 2 KB below the v7.7.1.1 baseline (PLAN-045); the `.bin` size is in the PR body; the WROOM's `min_free_heap` after a fresh boot and 24 hours later is in the PR body (PLAN-044). It is the first intent-style prompt, so its review findings and fix cycles are recorded with care. Its PR also commits the corrected texts of PLAN-045 (the R4 bundle, the process guide, the contract, the audit template, the planner page, this file and the decision row).
- Done when: tag `v7.7.1.2` exists and #214 is closed.
- State after: the new structs, key scheme and hash are in the code. Nothing uses them yet. Only the boards that the prompt's device tests flashed run 7.7.1.2; the fleet table in `CURRENT-STATE.md` records it.

### R6: v7.7.1.3, per-device persist write path (MEDIUM)

- Scope (PLAN-046): every hourly persist also writes one `DeviceSegment` per persistent device (dual-write) into a ring of 24 slots per device, one day; a v2 write is skipped when the history partition has fewer than 252 free NVS entries, so the old engine keeps its room; `/api/storage-stats` reports each device's ring from RAM; the sensor "outside" takes the MAC of its replacement. Nothing reads the new blobs yet.
- Before dispatch: the operator erases .173 and flashes v7.7.1.2 over USB, because .173 runs an older ESPHome default partition table without a history partition (PLAN-046).
- Extra checks: the host test of the write path; dual-write verified on the test board .173 first, then on .189 and .170, each after a persist cycle; the history partition's `used_entries` before and after; `c3heap` against .189's own reading just before the upload; the WROOM's `min_free_heap` at least 1,024 B at every reading of the step: fresh, after the first persist cycle and 24 hours later; the `.bin` size against the OTA slot; the Rule 40 and Rule 61 checks in the PR.
- Reviews: inline, A and C (Muse), then B: Gemini 4 Neon in Google Antigravity with part B of the review file, another surface of the AI Pro subscription as fallback; the runner cannot take R6's PR (PLAN-046, PLAN-047).
- Bundle: produced after R4 merged, from the code on `main`; one internal round, a second optional when the first finds a new HIGH or MEDIUM, and one auditor; after the auditor's second re-audit, a third internal round in place of a third re-audit (PLAN-048); it reaches `main` in this step's PR (PLAN-044).
- Done when: tag `v7.7.1.3` exists and #215 is closed.
- State after: every persist cycle writes the old blob and the new per-device blobs. Nothing reads the new ones yet. The operator watches the WROOM's NVS use and heap for a few days.

### R7: compile gate and backups before v7.7.1.4

- Why: v7.7.1.4 is prescriptive, and its restore code runs on boot. The tier rule has its embedded code compiled before dispatch. The coding agent gets this instruction; the task-group numbers are checked against the new prompt on the day:

```text
On a branch scratch/v7.7.1.4-compile-gate from origin/main (VERSION 7.7.1.3):
1. Apply ONLY the C++ code blocks of Task Groups 1-3 of
   prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md to firmware/core/nvs-persistence.h,
   at the insertion points the prompt names. Do not fix anything.
2. bash scripts/assemble-sensor-history.sh --write && bash scripts/assemble-sensor-history.sh --check
3. bash scripts/provision.sh satellite && esphome clean firmware/esp32-c3-multi-sensor.yaml \
   && timeout 900 esphome compile firmware/esp32-c3-multi-sensor.yaml
4. Report PASS or FAIL, the first 40 lines of any compiler error, and the .bin size.
Do not open a PR. Push nothing except the scratch branch, and delete it afterwards.
```

- If the gate fails, the prompt is wrong: it is fixed in a documentation PR, and the gate runs again. If the fix changes more than the failing lines, the two auditors check the changed part again.
- The operator backs up the history of every project board and copies the backups off the build host. A USB cable and the serial port for .189, .170 and .191 are ready.
- Done when: the gate passed and is recorded on #216, and the backups are off the build host.

### R8: v7.7.1.4, restore engine and retention budgets (HIGH)

- Flash over OTA. The partition tables do not change in this step (PLAN-015).
- Bundle: produced after R6 merges, from the code on `main`; one internal round, a further one when a round or an external audit finds a new HIGH or MEDIUM (at most three per planning session, PLAN-048), and two auditors; its compile gate is R7; it reaches `main` in this step's PR, and its reconciliation file records the batch metrics of Batch 2 (audit template §9, PLAN-044).
- Extra checks: boot restore works on .173 first; only after .173 has booted and served its history, on .189, .170 and .191; a retention-budget line is logged for each device; the declaration-order check is in the PR body; the `.bin` size is recorded.
- Recovery: if a board boot-loops, flash the v7.7.1.3 build over USB with `timeout 300 esphome upload <yaml> --device=<serial port>`, post the boot log to the PR, and stop the step. If a board comes back with empty history, import its history again from the R7 backup with `scripts/history_backup.py import`; the login comes from the operator's environment.
- Done when: tag `v7.7.1.4` exists, #216 is closed, the three production boards report 7.7.1.4, and each dashboard shows its history.
- State after: Batch 2 is complete. The old engine is still the one the dashboard reads, until R10.

### R18a: v7.7.1.5, new board secrets (LOW)

- Scope and conditions: section 8. The commands for the operator come with the operator page of the step and are tested on its day.
- Done when: merged and tagged; every project board answers 200 to the new management login and 401 to the old one; SEC-004 is in the decision log.

### R9 and R13: Batch 3 and Batch 4 prompts

- One documentation PR with every bundle of the batch, as R5b was planned before PLAN-044, with the producer contract and batch prompt v3.0. Batch 3: v7.7.2.1 (MEDIUM), v7.7.2.2 (HIGH), v7.7.2.3 (MEDIUM). Batch 4: v7.7.3.1 and v7.7.3.2 (MEDIUM), v7.7.3.3 (HIGH). One auditor for a MEDIUM step; two auditors from different model families for a HIGH step. The compile gate of a HIGH step waits until the step before it is on `main`; a prompt of another tier that carries code compiles it in its pre-dispatch gate (PLAN-042). The bundles and their audits go into one documentation PR, with the batch metrics.
- From R9 to v1.0 the method does not change (PLAN-012, PLAN-017).

### R10: v7.7.2.1, engine switchover and storage-stats v2 (MEDIUM)

- Done when: tag `v7.7.2.1`, #217 closed, the new engine is primary on .189, .170 and .191, and `/api/storage-stats` reports per device.
- With R4 and R6, this step gives the data that compares the intent style with the prescriptive steps of May 2026.

### R11: compile gate, rehearsal, v7.7.2.2 migration (HIGH)

- First: the compile-gate instruction of R7 with the code blocks of v7.7.2.2, on `main` at 7.7.2.1; backups; a rehearsal on .173 with imported real data.
- Extra checks: `/api/storage-stats` before and after on .189 and .170 shows at least 95 % of the retained segments; the rollback path was exercised once on .173.
- Done when: tag `v7.7.2.2` exists and #218 is closed.
- State after: the production boards hold migrated data. The old keys stay read-only until R17.

### R12: v7.7.2.3, per-device delete and socket cap (MEDIUM)

- Extra checks: `scripts/stress-test-httpd-stack.sh` passes on .189 and .170 at the new socket cap, with the httpd watermark at or above 2,000 B.
- Done when: tag `v7.7.2.3` exists, #219 and #224 are closed, and the same commit carries the tag `v1.0-rc1`.

### R14 and R16: v7.7.3.1 and v7.7.3.2, export and import (MEDIUM)

- R14 extra check: a round trip on the C3: export one device, delete it, import it, compare.
- Done when: tags `v7.7.3.1` and `v7.7.3.2` exist, and #220 and #221 are closed.

### R15: critical-rule retirement (documentation, beside Batch 4)

- Map each of the 67 Critical Rules in `prompts/prompt-index-and-workflow.md` to a lint rule, the producer contract, `AGENTS.md`, or history. A retired rule is marked, never renumbered, because prompts cite rule numbers.
- Done when: fewer than 67 rules are active and lint still passes on every prompt. It may slip past v1.0.

### R17: v7.7.3.3, Phase 7 closure (HIGH)

- First the compile gate with the code blocks of v7.7.3.3. Do not start this step on the day before a break.
- The PR holds the closure set (process guide §4.3): old-engine removal and the full regression suite; the stress test on .189, .170 and .191, with the httpd watermark at or above 2,000 B; a full-length WROOM history export at 60 % NVS fill or more, with the peak heap recorded (the BUG-082 acceptance line); an issue sweep; the KPI row and the three early-warning numbers in `CURRENT-STATE.md`; the method check of Batches 3 and 4 against Batch 2, as a decision row; the merge of `Docs/board-selection-guide-expansion.md` into the board selection guide (PLAN-025).
- Done when: tag `v7.7.3.3` exists, #222 is closed, and no open `phase/7` issue is without a milestone.

### R18: tag v1.0

- The operator tags `v1.0` on firmware 7.7.3.3 and publishes the release.
- In the same week one small documentation PR rewrites `README.md` for v1.0: the version line, the quick start, and the test counts from `npx playwright test --list`. It also corrects the header of `Docs/architecture-overview.md`.

## 6. Standard procedure for a code step (SP)

Eight moves. The binding text is in `Docs/development-process-guide.md` §2; this is the short form.

1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, checks that no fill-in is left, and compiles the code that the prompt carries and that ends in a compiled artifact (contract rule 3.4). Device values come only from the operator's latest fleet output. The operator posts the record as the first operator comment of the PR.
2. Dispatch. The operator pulls the planning repository on the build host and pastes the dispatch paragraph; the agent checks the setup file by its SHA-256 and follows it, and the setup file gives it the agent prompt, word for word (process guide §2.2, PLAN-043). A step prompt closes its issue with `Fixes #N`: #214 for v7.7.1.2, #215 for v7.7.1.3, #216 for v7.7.1.4, #217 for v7.7.2.1, #218 for v7.7.2.2, #219 and #224 for v7.7.2.3, #220 for v7.7.3.1, #221 for v7.7.3.2, #222 for v7.7.3.3.
3. Checkpoint failures. When the agent posts `⛔ CHECKPOINT FAILED`, it has stopped. If the prompt is wrong, the planning session corrects it; if the code is wrong, the agent investigates and reports. Nobody tells the agent to make the check pass.
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run: reviews A and C side by side, then review B, always last: Gemini 4 Neon in Google Antigravity with part B of the review file, or the runner (PLAN-023, PLAN-046, PLAN-047). The agent waits for the inline round with the check block `inline` and ends each round with the check block `body` (PLAN-043). Section 7 shows the scheme.
5. Evidence check before the merge: the agent runs the check block `body <PR#> final` as the last step of its last round and posts its last line, `body final PASS at <commit>`; the operator confirms that the commit is the head, and runs it again only if a commit came after (PLAN-046). The PR body holds the gate outputs, the per-item verification and the device evidence. The branch holds the session log, the consolidated audit, `CURRENT-STATE.md`, the changelog entry, and this file with the step's row marked.
6. Merge and tag, by the operator.
7. Post-merge check: the operator updates the checkout on the build host to `main`, and the boards that the step flashed report the new version; the planning session checks `main` and `VERSION` at its next restart check (PLAN-043).
8. Metrics and step closure. The agent fills the process-metrics block of the consolidated audit, with the producer and audit numbers of the gate record. The planning session reads the merged PR and the audit, and corrects the next prompt at its gate.

## 7. One code step with reviews A, B and C

```mermaid
sequenceDiagram
    autonumber
    participant P as Planning session
    participant Y as Operator
    participant A as Coding agent
    participant R as Reviewers
    P->>Y: Prompt, gate record, review file (common part, A, B, C)
    Y->>A: Dispatch paragraph: the setup file and its SHA-256
    A->>A: Branch, edits, checks, device tests
    A->>R: PR ready, then it posts /gemini review
    R-->>A: Inline reviews: Copilot, Gemini
    A->>Y: Assessment and fixes posted
    Y->>R: Start reviews A and C
    R-->>A: Reviews A and C, one comment each
    A->>Y: Second assessment and fixes
    Y->>R: Review B: Antigravity from the line of the block reviewb, or the runner from main
    R-->>A: Review B, one comment: Antigravity, one line and three passes, the file checked and posted by the operator; the runner, three turns
    A->>Y: Last fixes, then the consolidated audit
    Y->>P: Merged and tagged, then the report back
    P->>P: Step closure: correct the next prompt
```

This scheme holds from the merge of the review-runner PR, R5r (PLAN-022, PLAN-023). Review B runs in Gemini 4 Neon in Google Antigravity, in the runner or, on a step without review C, in Muse, each with part B of the review file; the step's review file names the default and the fallback, and the consolidated audit names any change (PLAN-046, PLAN-047). Review C is required on MEDIUM and HIGH firmware steps and optional elsewhere (PLAN-036).

Two files have similar names. The review file of a step holds the instructions for the reviewers; the planning session writes it before dispatch. The consolidated audit is the record of all reviews: each finding, whether it was warranted, and what was done; the coding agent writes it in the PR and completes it after the last review round (HowTo §6.2).

## 8. Security track

- Today (SEC-003, SEC-ADR-001 amendment 2026-11): the boards are reachable on the LAN only. No tracked file that agents read holds the management login. Agents and scripts take it from `$ESP_USER` and `$ESP_PASS`; the firmware reads it from the git-ignored `firmware/secrets.yaml`. Old values stay in git history, so only R18a makes them useless.
- R18a, v7.7.1.5, right after R8. One LOW pull request moves the native API key and the OTA password to per-board `!secret` entries: the render template, the C3 YAML and both bootstrap YAMLs. The operator creates the new values in `firmware/secrets.yaml`, flashes every board on project firmware in one sitting, and pastes the status codes into the PR. The management login changes in the same sitting on all boards, because the aggregator sends its own login to every satellite. SEC-004 records the result, and RV-08 and RV-09 of SEC-ADR-001 are resolved.
- D-1, per-board management logins: a design step inside the 8.0 research session, built in 8.1 if a design is chosen.
- D-2, a login for the ESPHome page and its OTA form: a design step inside U1.
- The re-publish gate. No Internet route is created before all four hold, and a decision row records them:
  1. R18a is merged, and the old password gets 401 on every project board.
  2. A Cloudflare Access application with an Allow policy covers the hostname before the route exists.
  3. Only the aggregator is published. Satellites stay on the LAN.
  4. SEC-002 is decided again for readers on the Internet: Access is the only gate for history, or a firmware step puts a login on history.
- Outbound connections of Phases 8 and 9 (Telegram, ntfy, Azure) are not routes. Their tokens follow SEC-003: `firmware/secrets.yaml` or the settings NVS namespace, never a tracked file.

## 9. After v1.0

Each phase opens with one research and prompt-production session, then runs its steps with SP. Version numbers after v1.0 are proposals; a prompt confirms each one.

| Work | Estimate (sessions) | Needs | Version |
|---|---|---|---|
| U1: ESPHome upgrade spike on .173 and .192, with D-2 and a partition-over-OTA rehearsal; go or no-go | 3 to 5 | v1.0 | – |
| U2, only on go: fleet upgrade (HIGH) | 4 to 6 | U1 ends in go | v7.7.4.1 |
| v1.1: the PLAN-004 partition layouts as their own HIGH step; over OTA if U1's rehearsal passed and U2 shipped, otherwise USB reflash with history re-import; .173 first. The former v7.7.5.x optimisation sprint (PLAN-010, PLAN-011) belongs to v1.1 | 5 to 7 | U2, or U1 on no-go | v7.7.4.2 / v1.1 |
| Phase 8 batch 1: 8.0 research (TLS client path on the S3, Telegram, rule schema, settings NVS namespace) with D-1; prompts 8.1 and 8.2; go or no-go on the TLS path | 2 to 3 | v1.1 | – |
| 8.1 settings NVS schema and UI | 4 to 6 | 8.0 | v8.1.0.1 |
| 8.2 Telegram channel | 3 to 5 | 8.1 | v8.1.0.2 |
| 8.3 ntfy.sh channel | 3 to 5 | 8.2 | v8.1.1.1 |
| 8.5 extra conditions (8.4 email only on request) | 2 to 3 | 8.3 | v8.1.3.1 |
| Phase 8 closure; Phase 9 batch 1 (9.0 research, a dated Azure price snapshot, prompts 9.1 and 9.2; PLAN-013) | 2 to 3 | 8.5 | – |
| 9.1 cloud settings | 3 to 5 | 9.0 | v9.0.0.1 |
| 9.2 hourly upload, beside the tier-2 skeleton | 5 to 7 | 9.1 | v9.0.0.2 |
| Calibration window: at least two weeks of billed usage, beside 9.3 and 9.4 | – | 9.2 | – |
| 9.3 store-and-forward | 4 to 6 | 9.2 | v9.0.1.1 |
| 9.4 MQTT bridge (optional) | 5 to 7 | 9.3 | v9.0.2.1 |
| 9.5 dashboard cloud status; cost model calibrated on the measured weeks | 5 to 7 | 9.4 and the calibration window | v9.0.3.1 |
| Tier-2 reference document and Phase 9 closure; tag | 5 to 7 | 9.5 | v1.2 |
| Zigbee spike and the single-chip against two-chip gate | 5 to 7 | Phase 9 closure | – |

Phase E comes after Phase 9, and its step E-b waits for the Zigbee spike (PLAN-014).

## 10. Open findings

Only findings that a ladder step owns, and that no issue and no row of `CURRENT-STATE.md` tracks.

| Finding | Owner |
|---|---|
| The leftovers of the May 2026 Batch 2 prompts (the list in section 5, R5b) | R5b for v7.7.1.2; the bundle of v7.7.1.4 for H-1 and L-1 of PR #233 (PLAN-044) |
| The RAM that NVS keeps for each key limits retention on boards without PSRAM, besides flash: ESP-IDF v5.5's page gives about 5.5 KB for 1,000 keys, and its source keeps one hash-list node of 4 bytes per item, in blocks of 29 nodes (128 B) per page, two items for a blob key; the per-device ring multiplies the keys by the devices | The bundle of v7.7.1.4 (PLAN-046) |
| .180 and .184 may also run a partition table without a history partition, as .173 did (read their `/api/storage-stats`) | Before U1 |

## 11. Risks

Ordered by expected effect on the schedule.

| # | Risk | How you will know | Mitigation |
|---|---|---|---|
| 1 | The operator has fewer sessions a week than planned | Two planned sessions in a row slip | No date is promised; the critical path never has two firmware steps in parallel; R15 can be dropped without moving v1.0 |
| 2 | The v7.7.2.2 migration loses retained history | `/api/storage-stats` after the migration shows fewer than 95 % of the segments; a boot loop | Backups in R7 and R11; rehearsal on .173 with real data; two auditors and a compile gate; old keys kept read-only until R17 |
| 3 | Review rounds grow on the HIGH steps (R8, R11, R17) | A PR reaches review round 3 | Compile gates before dispatch; intent style on MEDIUM steps; checkpoints that stop and do not fix, apart from one repair of the agent's own edit (PLAN-045) |
| 4 | The v7.7.1.4 restore crashes on boot | A board boot-loops after the OTA update | .173 first; USB cable ready; the v7.7.1.3 build kept for recovery; history re-import from the R7 backups |
| 5 | The C6 with 4 MB flash exceeds its OTA slot | A `.bin` above about 1,690 KB at any step from v7.7.1.3 | `.bin` size recorded at every step; a size checkpoint in every prompt from Batch 2 on |
| 6 | ESPHome drifts: the container is updated, or an upgrade is tried inside a phase | A version other than 2026.4.1 at a pre-dispatch gate | PLAN-016; the upgrade spike only after v1.0 on test boards |
| 7 | The adoption of the method grows into a methodology project | A change before v1.0 outside the lists of PLAN-017, PLAN-021 and PLAN-022; batch prompt v3.0 longer than v2.0 | PLAN-012; anything else waits until after v1.0 |
| 8 | The TLS client path of Phase 8 does not exist in this build | The 8.0 spike cannot post to Telegram from the S3 within 40 KB peak heap | 8.0 is a research step with a go or no-go; the fallback is the aggregator posting to the tier-2 ingest |
| 9 | Tier-2 grows into a product | A `tier2/` PR adds a component that the reference document does not list | A not-in-scope list from the first tier-2 PR; a hard stop at the Phase 9 closure |
| 10 | Planning produces documents and no merged steps | A session between two steps writes a methodology document; R5 or R5r grows beyond its list | PLAN-012; R5b has a session budget and a stop at two audit sessions for each producer session |
| 11 | The WROOM .170 runs out of heap | `min_free_heap` below 1,024 B at a reading of R6 or a later step | The floor stops the step (PLAN-046); memory changes measured later (BLE connection slots, the socket cap of #224, the RAM window of PLAN-011); .170 leaves the fleet if it cannot keep the floor |

## 12. What still holds of the feature roadmap

`Docs/archive/planning-2026-05/feature-roadmap.md` is history. Its phase order, its cloud target and the place of Phase E are superseded by PLAN-013 to PLAN-015. These parts still hold:

- The five principles: solve real problems; preserve stability; keep deployment simple; avoid over-engineering on a constrained target; adopt only what improves things step by step.
- Phase 10, dashboard UI (low to medium priority): responsive sizing and a multi-language interface. Translation sets cost flash on 4 MB boards. Plan: `Docs/phase-10-dashboard-ui-plan.md`.
- Phase 11, analytics (low priority): statistics in the browser first; no inference on the ESP32; cloud analytics only after Phase 9.
- Deferred: a heat-index value in the browser (low effort, in a dashboard phase); dashboard panes for a second sensor type (when one exists); an encrypted secrets partition (not a priority for a home deployment); Cloudflare Access as a deployment guide only, not a firmware feature (see the re-publish gate in section 8).
- `README.md` never presents a future capability as shipped.
- Phase names: a number for a feature phase, a letter for an infrastructure or refactoring phase.
