# Phase Y — Copilot-Optimized PR Review Prompts (Deep Research Delegated)

_9 steps. For each step, the agent prompt (Step 1) is unchanged — use from
`prompts/handoff/phaseY/phase-y-two-session-prompts.md`._
_These prompts replace only the Step 2 (review) sections with a 4-step
context-window-optimized pattern: deep-research sub-agent → synthesis →
fix prompt generation → post-merge deliverables._
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Date: 2026-04-09_  

---

## How to Use

1. **Agent session** — use the Step 1 prompts from the original
   `phase-y-two-session-prompts.md` file (unchanged).
2. **Review session** — open a **fresh** Copilot chat and use the matching
   review prompt below. Replace all `<PLACEHOLDER>` tokens before pasting.
3. Each review prompt has **four steps**: deep-research → synthesis →
   fix prompt → post-merge deliverables. Wait for each step's results before
   proceeding to the next.

### Fill-in Checklist (apply to every step)

Before using any review prompt below, replace these placeholders:

- [ ] `<PR_NUMBER>` — the actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` through `<PASTE_REVIEW_URL_N>` — actual review/comment
  URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of the last fix commit (if applicable)

---
---

# v7.6.6.0 — PR Review: `provision.sh` Full Pipeline Automation

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.0 PR._

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.0 (Phase Y pre-step: provision.sh full pipeline
> automation) against the implementation prompt
> `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **Pipeline ordering** — does `run_full_pipeline()` match Critical Rule 37 exactly?
>    List every step in order (Step 0 through Step 8). Verify the step array matches:
>    bundle → render → fixtures → render → build → minify → header → check.
> 2. **Assembly placeholder** — Step 0 prints a skip message, does NOT execute a
>    nonexistent script? Is it a no-op comment only?
> 3. **`--dry-run` support** — prints all steps with `[DRY-RUN]` prefix, zero
>    filesystem changes? Test evidence present?
> 4. **`status` non-mutating** — `show_status()` / `status` case does NOT call
>    `run_full_pipeline()`?
> 5. **No `eval` usage** — direct command execution only in `run_full_pipeline()`?
> 6. **Dependency pre-checks** — `require_node()` and `require_npm_deps()` exist
>    and are called before pipeline execution?
> 7. **Error handling** — a failed step exits with clear message identifying which
>    step failed?
> 8. **CI-safe warning** — preserved for non-satellite modes?
> 9. **All board modes** — satellite, aggregator, and wroom all run full pipeline?
> 10. **No out-of-scope changes** — no firmware, tests, `sensor_history_multi.h`,
>     preflight, or build script changes?
> 11. **Playwright tests pass** — all 4 fixture sets green?
> 12. **Session log exists** — `Docs/session-log-*-v7.6.6.0.md`?
> 13. **Changelog entry** — present and accurate?
> 14. **LESSON-OPS entry** — added to `Docs/lessons/operations.md`?
>
> Also: read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.
> If a gate fails, include the specific file and line numbers involved.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md` to understand
the current stage and deliveries.

Current task: v7.6.6.0 — Phase Y pre-step (provision.sh pipeline automation).
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 14 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — were the reviewer findings warranted? Table format:
   source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed and what still needs work
4. **Concrete fix list** — what specific changes are needed before merge (if any)

Do NOT re-read full implementation files — use the sub-agent's findings. Only fetch
specific file sections (line ranges) if the sub-agent results are ambiguous.

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown format that:
- Addresses ONLY the remaining issues (not already-fixed ones)
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

## Step 4 — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.
Double-check the Workflow and Post-PR Closure Deliverables sections of
`prompts/handoff/phaseY/session-handoff-v7.6.6.0.md`.

### 4a. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.0-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Format reference: `prompts/phaseX/v7.6.5.7-PR148-consolidated-audit-and-lessons.md`
- Stable core questions (5 internal + 8 external reviewer)
- Step-specific supplement:
  - Does `--dry-run` print all 8 pipeline steps plus the assembly placeholder?
  - Does `status` remain non-mutating (no pipeline execution)?
  - Is the assembly step placeholder a no-op comment, not a missing command?
  - Is the pipeline ordering identical to Critical Rule 37?

Use the sub-agent results from Step 1 as the primary evidence source.

### 4b. Inspect Next Step Artifacts

Review and update if necessary:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md` — verify scope still matches
after seeing the actual `provision.sh` changes
- `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md` — verify
pipeline references and `provision.sh` integration points are accurate

Tag: `git tag -a v7.6.6.0 -m "Phase Y Pre-step: provision.sh full pipeline automation" && git push origin v7.6.6.0`

---
---

# v7.6.6.1 — PR Review: Establish Assembly Script and Baseline

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.1 PR._

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.1 (Phase Y: establish assembly script and
> 8-fragment baseline) against the implementation prompt
> `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **Fragment count** — exactly 8 files in `firmware/core/`? List all file names.
> 2. **Line counts** — do individual fragment line counts sum to 4,325?
>    Expected: 95 + 460 + 614 + 50 + 168 + 891 + 2006 + 41 = 4,325.
>    Report each fragment's `wc -l`.
> 3. **SHA-256 identity** — does `assemble-sensor-history.sh --check` exit 0?
>    Evidence in PR description or session log?
> 4. **Direct concatenation identity** — `diff` of assembled output vs `cat` of
>    fragments exits 0? Evidence present?
> 5. **`--list` output** — 8 fragments with correct line counts?
> 6. **Generator-aware `--check`** — `strip_generated()` strips SENSOR_MANIFEST
>    marker content? Implementation present?
> 7. **No code changes** — fragments are pure line-range extractions from
>    `sensor_history_multi.h`? No modifications?
> 8. **Boundary landmarks** — spot-check: `head -1` of data-model.h (TAG),
>    aggregator-runtime.h (`#if AGGREGATOR_ENABLED`), registration.h (comment)?
> 9. **Assembly step activated** — `provision.sh` calls assembly script in pipeline?
> 10. **Preflight fragment check** — `firmware_core_fragments_exist` added and passing?
> 11. **YAML unchanged** — no fragment files added to YAML `includes:`?
> 12. **MODULES array order** — correct order in `assemble-sensor-history.sh`?
> 13. **Extraction method** — `sed -n` used (not `split` command)?
> 14. **`sensor_history_multi.h` unmodified** — fragments are copies, not moves?
> 15. **Playwright tests pass** — all 4 fixture sets green?
> 16. **Session log exists** — `Docs/session-log-*-v7.6.6.1.md`?
> 17. **Changelog entry** — present and accurate?
>
> Also: read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.
> If a gate fails, include the specific file and line numbers involved.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md` to understand
the current stage and deliveries.

Current task: v7.6.6.1 — Establish assembly script and 8-fragment baseline.
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 17 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table format: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed and what still needs work
4. **Concrete fix list** — what specific changes are needed before merge (if any)

Do NOT re-read full files — use the sub-agent's findings. Only fetch specific file
sections if the sub-agent results are ambiguous on a particular gate.

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown format that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

## Step 4 — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.
Double-check the Workflow and Post-PR Closure Deliverables sections of
`prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`.

### 4a. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.1-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Format reference: `prompts/phaseX/v7.6.5.7-PR148-consolidated-audit-and-lessons.md`
- Stable core + step-specific supplement:
  - Fragment extraction: line counts sum to 4,325?
  - SHA-256 identity verified? All 8 fragments exist?
  - `--check` uses `strip_generated()` for generator-aware comparison?

Use the sub-agent results from Step 1 as the primary evidence source.

### 4b. Inspect Next Step Artifacts

Review and update if necessary:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`
- `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.1 -m "Phase Y: Establish assembly script and 8 fragment baseline" && git push origin v7.6.6.1`

---
---

# v7.6.6.2 — PR Review: Wire Assembly into Pipeline and Fragment-Level Preflight

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.2 PR._

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.2 (Phase Y: wire assembly into pipeline and
> fragment-level preflight) against the implementation prompt
> `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **Assembly step in pipeline** — `provision.sh` runs assembly as Step 0
>    (no longer a placeholder)?
> 2. **`firmware_core_assembly_check`** — new preflight function exists, calls
>    `assemble-sensor-history.sh --check`?
> 3. **`firmware_core_fragment_line_sum`** — new preflight function exists, verifies
>    fragment line counts sum to committed file line count?
> 4. **Both new checks pass** — evidence in PR description or session log?
> 5. **No assembly `--check` in pipeline** — `--check` only runs in preflight,
>    NOT as a pipeline step after the generator (per §4.2 of the Phase Y plan)?
> 6. **No fragment changes** — `git diff` shows zero changes to `firmware/core/`?
> 7. **No test changes** — no test file modifications?
> 8. **No assembly script changes** — `assemble-sensor-history.sh` unmodified?
> 9. **Playwright tests pass** — all 4 fixture sets green?
> 10. **`esphome config` validates** — evidence present?
> 11. **Session log exists** — `Docs/session-log-*-v7.6.6.2.md`?
> 12. **Changelog entry** — present and accurate?
>
> Also: read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.
> If a gate fails, include the specific file and line numbers involved.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md` to understand
the current stage and deliveries.

Current task: v7.6.6.2 — Wire assembly into pipeline and fragment-level preflight.
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 12 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table format: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed and what still needs work
4. **Concrete fix list** — what specific changes are needed before merge (if any)

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown format that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

## Step 4 — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.
Double-check the Post-PR Closure Deliverables section of
`prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`.

### 4a. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.2-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Stable core + step-specific supplement:
  - Assembly step active in provision.sh?
  - New preflight checks added and passing?
  - No `--check` after generator in pipeline (only in preflight)?

Use the sub-agent results from Step 1 as the primary evidence source.

### 4b. Inspect Next Step Artifacts

Review and update if necessary:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md`
- `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.2 -m "Phase Y: Wire assembly into pipeline and fragment-level preflight" && git push origin v7.6.6.2`

---
---

# v7.6.6.3 — PR Review: Fragment Editing Workflow Validated

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.3 PR._

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.3 (Phase Y: fragment editing workflow validated)
> against the implementation prompt
> `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **No permanent fragment changes** — `git diff` shows ZERO changes to
>    `firmware/core/`? All edits reverted?
> 2. **Four-step gate test documented** — evidence of the full PASS → CHANGE →
>    FAIL → PASS sequence?
>    - Step 1: Baseline `--check` PASSES
>    - Step 2: Add trailing blank line to `registration.h`, reassemble → line count
>      changes to 4,326
>    - Step 3: Deliberate-break: add space to `config.h` line 1, run `--check`
>      WITHOUT reassembling → must FAIL
>    - Step 4: Revert, run `--check` → must PASS again
> 3. **No assembly/preflight/provision.sh changes** — these scripts are unmodified?
> 4. **Fragment line counts unchanged** — total still 4,325?
> 5. **SHA-256 identity restored** — baseline SHA matches after revert?
> 6. **Playwright tests pass** — all 4 fixture sets green?
> 7. **Session log exists** — `Docs/session-log-*-v7.6.6.3.md`?
> 8. **Changelog entry** — present and accurate?
> 9. **No scope violations** — only changelog, version, and session log modified?
>
> Also: read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md` to understand
the current stage and deliveries.

Current task: v7.6.6.3 — Fragment editing workflow validated.
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 9 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table format: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed and what still needs work
4. **Concrete fix list** — what specific changes are needed before merge (if any)

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown format that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

## Step 4 — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

### 4a. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.3-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Stable core + step-specific supplement:
  - Edit→assemble→pipeline→check cycle works?
  - Deliberate-break test executed and documented?
  - No permanent fragment changes?

### 4b. Inspect Next Step Artifacts

Review and update if necessary:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md`
- `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.3 -m "Phase Y: Fragment editing workflow validated" && git push origin v7.6.6.3`

---
---

# v7.6.6.4 — PR Review: Ping Adapter Fragment Validation

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.4 PR._

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.4 (Phase Y: ping adapter fragment validation)
> against the implementation prompt
> `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **No fragment changes** — `git diff` shows ZERO changes to `firmware/core/`?
> 2. **Compile-guard intact** — `#ifdef PING_DEVICE_INDEX` is first line of
>    `firmware/core/ping-adapter.h`?
> 3. **PingAdapter class complete** — exactly 1 `class PingAdapter` match in the file?
> 4. **No cross-fragment symbol leakage** — no `s_cache_mutex`, no `HistoryMeta`
>    in `ping-adapter.h`?
> 5. **Line count correct** — `firmware/core/ping-adapter.h` is exactly 168 lines?
> 6. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 7. **No script/test/YAML changes** — only changelog, version, and session log modified?
> 8. **Playwright tests pass** — all 4 fixture sets green?
> 9. **`esphome config` validates** — evidence present?
> 10. **Session log exists** — `Docs/session-log-*-v7.6.6.4.md`?
> 11. **Changelog entry** — present and accurate?
>
> Also: read ALL PR review comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md` to understand
the current stage and deliveries.

Current task: v7.6.6.4 — Ping adapter fragment validation.
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 11 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table format: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining**
4. **Concrete fix list** — if any

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt.

---

## Step 4 — Post-merge Deliverables

### 4a. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.4-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Stable core + step-specific supplement:
  - PingAdapter fragment: compile-guard boundary intact?
  - No cross-fragment symbol leakage?
  - Assembly identity holds?

### 4b. Inspect Next Step Artifacts

Review and update if necessary:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md`
- `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.4 -m "Phase Y: Ping adapter fragment validation" && git push origin v7.6.6.4`

---
---

# v7.6.6.5 — PR Review: NVS Persistence Device Test Gate ⚠️ BLOCKING

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.5 PR._

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.5 (Phase Y: NVS persistence device test gate — BLOCKING) against the implementation prompt
> `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md`.
>
> ⚠️ This is a BLOCKING gate — Phase Y cannot proceed if it fails.
>
> Check these gates and report findings as a structured table:
>
> 1. **No source code changes** — only changelog and version files modified?
> 2. **Boot log evidence** — NVS restore messages present, no crash/panic?
> 3. **Test 1 — storage-stats** — valid JSON response with NVS statistics?
> 4. **Test 2 — manifest + history** — populated data from history endpoint?
> 5. **Test 3 — live endpoint** — `/api/v2/live` returns valid sensor data?
> 6. **Test 4 — status endpoint** — `/api/status` returns valid JSON?
> 7. **Test 5 — reboot persistence** — pre/post `storage-stats` comparison shows
>    segments did NOT decrease after reboot? Correct reboot curl command used
>    (`-d 'a=1'` not JSON content type)?
> 8. **Test 6 — hourly persist** — optional; noted if observed?
> 9. **Correct curl usage** — all POST commands use `-d 'a=1'`, no JSON content type?
> 10. **Correct board YAML** — committed `esp32-c3-multi-sensor.yaml` used (not generated)?
> 11. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 12. **Playwright tests pass** — all 4 fixture sets green?
> 13. **Session log exists** — with device test evidence?
> 14. **Changelog entry** — present and accurate?
> 15. **Bug escalation** — if any device test failed, was the escalation prompt used?
>
> Also: read ALL PR review comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md` to understand
the current stage and deliveries.

Current task: v7.6.6.5 — NVS persistence device test gate (BLOCKING).
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 15 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **BLOCKING gate verdict** — explicit PASS or FAIL for the overall device test gate
3. **Review comment assessment** — table format
4. **Resolved vs. remaining**
5. **Concrete fix list** — if any

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt.
If the BLOCKING gate FAILS, explicitly state: "⚠️ Phase Y is BLOCKED — do not
proceed to v7.6.6.6 until this gate passes."

---

## Step 4 — Post-merge Deliverables

### 4a. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.5-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Stable core + step-specific supplement:
  - NVS device test: boot restore confirmed?
  - History retention survives reboot?
  - Hourly persist writes observed (if applicable)?

### 4b. Inspect Next Step Artifacts

Review and update if necessary:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md`
- `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.5 -m "Phase Y: NVS persistence device test gate PASSED" && git push origin v7.6.6.5`

---
---

# v7.6.6.6 — PR Review: Aggregator Runtime Device Test Gate ⚠️ BLOCKING

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.6 PR._

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.6 (Phase Y: aggregator runtime device test
> gate — BLOCKING) against the implementation prompt
> `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md`.
>
> ⚠️ This is a BLOCKING gate — Phase Y cannot proceed if it fails.
>
> Check these gates and report findings as a structured table:
>
> 1. **No source code changes** — only changelog, version, and session log modified?
> 2. **Correct board YAML** — generated `esp32-s3-devkitc1-n16r8-gw.yaml` used for S3
>    (not the committed C3 YAML)?
> 3. **Aggregator poll task started** — boot log shows aggregator poll task init?
> 4. **Test 1 — gateways endpoint** — `/api/aggregator/gateways` returns valid JSON?
> 5. **Test 2 — aggregator live** — `/api/aggregator/live` returns valid JSON?
> 6. **Test 3 — proxy history** — proxy endpoint returns history data?
> 7. **Test 4 — test-satellite** — authenticated POST to `test-satellite` succeeds?
> 8. **Test 5 — add-satellite** — POST to `add-satellite` succeeds?
> 9. **Test 6 — config_generation** — gateways response shows config_generation field,
>    value increments after mutations?
> 10. **Test 7 — delete satellite** — authenticated DELETE to `/aggregator/satellite/0`
>     succeeds?
> 11. **Test 8 — re-add satellite** — satellite can be re-added after deletion?
> 12. **Test 9 — reboot persistence** — pre/post gateways comparison shows satellite
>     config survived reboot?
> 13. **Test 10 — reset-satellites** — authenticated POST to `reset-satellites` clears
>     satellite list?
> 14. **Satellite mode restored** — `bash scripts/provision.sh satellite` was run
>     BEFORE the PR was created? Evidence present?
> 15. **Correct curl usage** — `-d 'a=1'` for POST, no JSON content type?
> 16. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 17. **Playwright tests pass** — all 4 fixture sets green?
> 18. **Session log exists** — with device test evidence?
> 19. **Changelog entry** — present and accurate?
>
> Also: read ALL PR review comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md` to understand
the current stage and deliveries.

Current task: v7.6.6.6 — Aggregator runtime device test gate (BLOCKING).
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 19 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **BLOCKING gate verdict** — explicit PASS or FAIL for the overall device test gate
3. **Review comment assessment** — table format
4. **Resolved vs. remaining**
5. **Concrete fix list** — if any

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt.
If the BLOCKING gate FAILS, explicitly state: "⚠️ Phase Y is BLOCKED — do not
proceed to v7.6.6.7 until this gate passes."

---

## Step 4 — Post-merge Deliverables

### 4a. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.6-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Stable core + step-specific supplement:
  - Aggregator poll task starts?
  - All aggregator endpoints respond?
  - Satellite NVS survives reboot?
  - Satellite mode restored before PR?

### 4b. Inspect Next Step Artifacts

Review and update if necessary:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md`
- `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.6 -m "Phase Y: Aggregator runtime device test gate PASSED" && git push origin v7.6.6.6`

---
---

# v7.6.6.7 — PR Review: Full Endpoint Smoke Test

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.7 PR._

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.7 (Phase Y: full endpoint smoke test) against
> the implementation prompt
> `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **No source code changes** — only changelog, version, and session log modified?
> 2. **All 21 endpoints tested** — evidence table complete with HTTP status codes?
>    List all 21 and mark each tested/untested.
> 3. **Auth behavior verified** — both authenticated (200) and unauthenticated (401)
>    responses documented?
> 4. **Import cycle tested** — begin/data/finish sequence documented with evidence?
> 5. **Both boards tested** — C3 satellite (192.168.120.189) AND S3 aggregator
>    (192.168.120.191)?
> 6. **Both ESPHome configs validated** — `esphome config` for both board profiles?
> 7. **Correct board YAMLs** — C3 uses committed `esp32-c3-multi-sensor.yaml`,
>    S3 uses generated `esp32-s3-devkitc1-n16r8-gw.yaml`?
> 8. **Correct curl usage** — `-d 'a=1'` for POST, no JSON content type?
> 9. **Satellite mode restored** — `bash scripts/provision.sh satellite` was run
>    BEFORE the PR was created? Evidence present?
> 10. **Test ordering** — delete-data was NOT run before history tests?
> 11. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 12. **Playwright tests pass** — all 4 fixture sets green?
> 13. **Session log exists** — with endpoint evidence?
> 14. **Changelog entry** — present and accurate?
>
> Also: read ALL PR review comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md` to understand
the current stage and deliveries.

Current task: v7.6.6.7 — Full endpoint smoke test.
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 14 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **21-endpoint coverage table** — endpoint name, board, HTTP status, tested?
3. **Review comment assessment** — table format
4. **Resolved vs. remaining**
5. **Concrete fix list** — if any

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt.

---

## Step 4 — Post-merge Deliverables

### 4a. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.7-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Stable core + step-specific supplement:
  - All 21 endpoint handlers verified?
  - Both C3 and S3 board profiles tested?
  - Auth behavior confirmed?

### 4b. Inspect Next Step Artifacts

Review and update if necessary:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`
- `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.7 -m "Phase Y: Full endpoint smoke test PASSED" && git push origin v7.6.6.7`

---
---

# v7.6.6.8 — PR Review: Closure — Preflight, Documentation, Critical Rules

_Use this prompt in a fresh Copilot chat session to review the v7.6.6.8 PR._

**This is the final Phase Y step. All deliverables below are mandatory.**

## Step 1 — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.8 (Phase Y closure: preflight, documentation,
> Critical Rules 58–62) against the implementation prompt
> `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md`
> and handoff doc `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **6 new preflight checks** — do ALL of these functions exist in `scripts/preflight.sh`
>    and are they called in the main sequence?
>    - `sensor_history_monolith_is_assembled`
>    - `firmware_core_fragment_count`
>    - `no_generator_markers_in_fragments`
>    - `deferred_task_pairs_in_expected_homes`
>    - `maybe_yield_present_in_nvs_persistence`
>    - `mutex_single_owner`
>    List each with its implementation summary.
> 2. **ALL preflight checks pass** — total check count reported? Evidence in PR
>    description or session log?
> 3. **Critical Rules 58–62** — all 5 present in `prompts/prompt-index-and-workflow.md`?
>    Exact wording matches the Phase Y plan? Report the full text of each rule.
> 4. **Phase Y step table** — all 9 steps marked `✅ Complete` in prompt-index?
>    Report the full Phase Y step table.
> 5. **Phase Y completion summary** — present in prompt-index?
> 6. **README** — `firmware/core/` structure documented with fragment table?
> 7. **Firmware lessons** — `Docs/lessons/firmware.md` has fragment architecture lesson?
> 8. **Build-pipeline lessons** — `Docs/lessons/build-pipeline.md` has assembly step lesson?
> 9. **Phase Y results document** — `prompts/handoff/phaseY-results.md` exists?
>    Does it include: delivery metrics, bug count, test count, lessons learned?
> 10. **No fragment content changes** — `git diff` shows zero changes to `firmware/core/`?
> 11. **No test file changes** — no test modifications?
> 12. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 13. **`esphome config` validates** — evidence present?
> 14. **Playwright tests pass** — all 4 fixture sets green?
> 15. **Migration safety** — all 12 Phase Y migration safety rules verified across
>     the entire phase? Evidence or summary present?
> 16. **Session log exists** — `Docs/session-log-*-v7.6.6.8.md`?
> 17. **Changelog entry** — present and accurate?
>
> **prompt-index snapshot:** Read `prompts/prompt-index-and-workflow.md` fully and
> include in your report:
> - The complete Phase Y Step Index table (version, scope, status)
> - The complete Critical Rules table (number, rule summary, source)
> - The Revision History entry for v7.6.6.8 (if present)
> - The v7.6.6.8 delivery summary (if present)
> This avoids the synthesis session needing to re-read this large file.
>
> Also: read ALL PR review comments on PR #<PR_NUMBER>.
> For each reviewer finding, report: warranted (yes/no/partially), severity,
> fixed (yes/no), commit that fixed it.
>
> For each gate, report: PASS / FAIL / UNCLEAR, with a one-line evidence summary.
> If a gate fails, include the specific file and line numbers involved.

Wait for the sub-agent to return results before proceeding.

---

## Step 2 — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md` to understand
the current stage and deliveries.

Current task: v7.6.6.8 — Phase Y closure (final step).
PR: #<PR_NUMBER>

Following code reviews/comments were posted:

1. <PASTE_REVIEW_URL_1>

2. <PASTE_REVIEW_URL_2>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 1, provide:

1. **Gate checklist table** — all 17 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Critical Rules verification** — use the sub-agent's snapshot. Are Rules 58–62
   present with correct wording? Are all prior rules (1–57) still intact?
3. **Phase Y step table verification** — use the sub-agent's snapshot. All 9 steps
   `✅ Complete`?
4. **Review comment assessment** — table format: source, finding, warranted?, fixed?,
   remaining action
5. **Resolved vs. remaining** — what was fixed and what still needs work
6. **Concrete fix list** — what specific changes are needed before merge (if any)

Do NOT re-read `prompts/prompt-index-and-workflow.md` — use the sub-agent's snapshot
from Step 1 for Critical Rules and Step Index verification. Only fetch specific file
sections (line ranges) if the sub-agent results are ambiguous on a particular gate.

Post findings as a PR comment on #<PR_NUMBER>.

---

## Step 3 — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown format that:
- Addresses ONLY the remaining issues (not already-fixed ones)
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

## Step 4 — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.
Double-check the Workflow and Post-PR Closure Deliverables sections of
`prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`.

**This is the final Phase Y step. All deliverables below are mandatory.**

### 4a. Consolidated Audit (FINAL)

Produce `prompts/phaseY/v7.6.6.8-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseY/pr-audit-question-template-phaseY.md`
- Format reference: `prompts/phaseX/v7.6.5.7-PR148-consolidated-audit-and-lessons.md`
- Stable core questions (5 internal + 8 external reviewer)
- Closure supplement:
  - Do all 6 new preflight checks pass?
  - Are Critical Rules 58–62 added with correct wording?
  - Is the Phase Y results document complete and accurate?
  - Does the README accurately describe the `firmware/core/` structure?
  - Is the prompt-index updated to mark Phase Y complete?
  - Final migration safety: all 12 rules verified across entire Phase Y?

Use the sub-agent results from Step 1 as the primary evidence source.
Use the sub-agent's prompt-index snapshot for the Critical Rules and Step Index
tables — do NOT re-read the file.

### 4b. Phase Y Completion Summary

Provide a brief statement confirming:
- All 9 steps shipped (v7.6.6.0 through v7.6.6.8)
- Test counts maintained throughout (report final counts)
- Assembly identity maintained throughout
- Phase Y results document produced
- All 6 new preflight checks passing
- Critical Rules 58–62 added
- Next phase determination — flag for operator decision

Tag: `git tag -a v7.6.6.8 -m "Phase Y: Closure — sensor_history_multi.h architecture refactor complete" && git push origin v7.6.6.8`

**Phase Y is COMPLETE.**

---
_End of Phase Y Copilot-Optimized PR Review Prompts._