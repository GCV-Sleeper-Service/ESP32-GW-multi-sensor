# Phase Y — Copilot-Optimized PR Review Prompts

_Agent prompts are unchanged from `phase-y-two-session-prompts.md`._
_Review session prompts have been rewritten to use the deep-research sub-agent pattern_
_to minimise context-window consumption without sacrificing review quality._
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_

---

> **How to use these review prompts**
>
> Each review section below is a self-contained prompt for a fresh Copilot chat session.
> Paste it after the coding agent has created its PR.
> Follow the four steps in order:
> 1. **Deep Research** — fire the sub-agent; wait for results.
> 2. **Synthesis** — use sub-agent output to build the gate table; post as PR comment.
> 3. **Fix Prompt Generation** — only if issues remain.
> 4. **Post-merge Deliverables** — mandatory before closing the session.
>
> Replace every `<PLACEHOLDER>` before sending.

---
---

# v7.6.6.0 — Pre-Step: `provision.sh` Full Pipeline Automation

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md` — session context.
2. Read `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§1).
   Pay special attention to:
   - `scripts/provision.sh` — understand `run_render()`, `print_workflow()`, and the three
     `activate_*()` functions. You will replace `print_workflow()` with `run_full_pipeline()`.
   - `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §3 v7.6.6.0 for the
     exact `run_full_pipeline()` contract and step array.
   - `prompts/prompt-index-and-workflow.md` — Critical Rules #37 (pipeline) and #49 (provision.sh).

Then implement in this order:

  1. Add `run_full_pipeline()` to `provision.sh` with the exact step array from the plan
  2. Add `require_node()` and `require_npm_deps()` dependency pre-checks
  3. Add `--dry-run` support to all board modes
  4. Replace `print_workflow()` calls with `run_full_pipeline()` calls in activate functions
  5. Add Step 0 placeholder for `assemble-sensor-history.sh` (no-op comment until v7.6.6.1)
  6. Verify `status` remains non-mutating
  7. Add LESSON-OPS entry to `Docs/lessons/operations.md`
  8. Version bump: `bash scripts/bump-version.sh 7.6.6.0`
  9. Full pipeline validation for satellite, aggregator, and wroom modes
  10. Changelog entry
  11. Full Playwright suite across all four fixture sets
  12. `bash scripts/preflight.sh`
  13. Session log + Instruction Compliance Output table

Follow all rules listed under "Critical Rules" in §7 of the implementation instructions.

Do NOT modify `sensor_history_multi.h`, any firmware file, or any test file.
Do NOT use `eval` for pipeline step execution.
Do NOT make `status` mutating.

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.0 (`provision.sh` full pipeline automation) against
> `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **Pipeline ordering** — does `run_full_pipeline()` match Critical Rule 37 exactly?
>    Report the full step array defined in the function.
> 2. **Assembly placeholder** — does Step 0 print a skip message and NOT execute
>    a nonexistent script?
> 3. **`--dry-run`** — prints all steps with `[DRY-RUN]` prefix, zero filesystem changes?
> 4. **`status` non-mutating** — does NOT call `run_full_pipeline()`?
> 5. **No `eval` usage** — direct command execution only?
> 6. **Dependency pre-checks** — `require_node()` and `require_npm_deps()` called before pipeline?
> 7. **Error handling** — failed step exits with clear message identifying which step?
> 8. **CI-safe warning** — preserved for non-satellite modes?
> 9. **All board modes** — satellite, aggregator, wroom all run full pipeline?
> 10. **No forbidden changes** — no firmware, test, or `sensor_history_multi.h` changes?
> 11. **Tests green** — `esphome config` validates? All 4 Playwright fixture sets pass?
>
> Also: read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.
> If a gate fails, include specific file and line numbers.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.0 — `provision.sh` full pipeline automation.
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 11 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

- `prompts/phaseY/v7.6.6.0-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `session-handoff-v7.6.6.1.md` and
  `v7.6.6.1-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.0 -m "Phase Y Pre-step: provision.sh full pipeline automation" && git push origin v7.6.6.0`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---
---

# v7.6.6.1 — Establish Assembly Script and Baseline

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md` — session context and fragment manifest.
2. Read `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§1).
   Pay special attention to:
   - `dashboard/sensor_history_multi.h` — the 4,325-line file being split. Verify boundary
     landmarks with `grep -n` (lines 96, 556, 1170, 1220, 1388, 2279, 4290).
   - `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §2.3 (fragment manifest
     with line ranges), §3 v7.6.6.1 (assembly script specification).

Then — before splitting — verify boundaries:

  a. `wc -l dashboard/sensor_history_multi.h` — must be 4325.
  b. Verify all 7 boundary landmarks with `grep -n`.
  c. Record baseline SHA-256.

Only after confirming, implement in this order:

  1. Create `firmware/core/` directory
  2. Extract 8 fragments using `sed -n` with exact line ranges from §5b
  3. Verify: `wc -l firmware/core/*.h | tail -1` must show 4325 total
  4. Verify: `diff dashboard/sensor_history_multi.h <(cat firmware/core/*.h)` must exit 0
  5. Create `scripts/assemble-sensor-history.sh` from plan specification (--write/--check/--list/--dry-run)
  6. Activate assembly step in `provision.sh` (replace placeholder)
  7. Add `firmware_core_fragments_exist` check to `preflight.sh`
  8. Version bump: `bash scripts/bump-version.sh 7.6.6.1`
  9. Full pipeline, identity gate, Playwright suite
  10. Changelog entry + session log

Do NOT use `split` command — use `sed -n` with explicit line ranges only.
Do NOT modify `sensor_history_multi.h` — fragments are copies, not moves.
Do NOT add fragments to YAML `includes:`.
Do NOT redirect `render_sensor_config.py` to fragment files.
The `--check` mode MUST use `strip_generated()` to handle generator marker content.

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.1 (assembly script and baseline) against
> `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **Fragment count** — exactly 8 files in `firmware/core/`? List them.
> 2. **Line counts** — 95+460+614+50+168+891+2006+41 = 4,325? Report each fragment's
>    `wc -l` output.
> 3. **SHA-256 identity** — `assemble-sensor-history.sh --check` exits 0?
> 4. **Direct concatenation identity** — `diff` of assembled vs `cat` of fragments exits 0?
> 5. **`--list` correct** — 8 fragments with correct line counts?
> 6. **Generator-aware `--check`** — `strip_generated()` strips SENSOR_MANIFEST marker content?
> 7. **No code changes** — fragments are pure line-range extractions? No modifications?
> 8. **Boundary landmarks** — spot-check `head -1` of data-model.h (TAG),
>    aggregator-runtime.h (`#if AGGREGATOR_ENABLED`), registration.h (comment)?
> 9. **Assembly step activated** — `provision.sh` runs assembly step (not placeholder)?
> 10. **Preflight fragment check** — `firmware_core_fragments_exist` added and passing?
> 11. **YAML unchanged** — no fragment files in `includes:`?
> 12. **MODULES array order correct**?
> 13. **Tests green** — identity gate passes, all 4 Playwright fixture sets pass?
>
> Also read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.1 — establish assembly script and baseline.
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 13 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

- `prompts/phaseY/v7.6.6.1-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `session-handoff-v7.6.6.2.md` and
  `v7.6.6.2-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.1 -m "Phase Y: Establish assembly script and 8 fragment baseline" && git push origin v7.6.6.1`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---
---

# v7.6.6.2 — Wire Assembly into Pipeline and Fragment-Level Preflight

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md` — session context.
2. Read `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§1).
   Pay special attention to:
   - `scripts/provision.sh` — understand where the assembly step was activated in v7.6.6.1.
   - `scripts/preflight.sh` — understand the existing Phase Y check (`firmware_core_fragments_exist`).
   - `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §3 v7.6.6.2 and §4.2
     (generator/assembly sync issue).

Then implement:

  1. Verify assembly step is active in `provision.sh` pipeline
  2. Add `firmware_core_assembly_check` to `preflight.sh` — calls `assemble-sensor-history.sh --check`
  3. Add `firmware_core_fragment_line_sum` to `preflight.sh` — verifies fragment line counts sum to committed file
  4. Version bump, changelog, full pipeline, Playwright suite

Do NOT modify fragments, assembly script, or test files.
Do NOT add `--check` as a pipeline step after the generator (see §4.2 — runs in preflight only).

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.2 (wire assembly into pipeline and fragment-level
> preflight) against `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **Assembly step in pipeline** — `provision.sh` runs assembly as Step 0?
> 2. **Two new preflight checks added** — `firmware_core_assembly_check` AND
>    `firmware_core_fragment_line_sum` both present in `preflight.sh`?
> 3. **Both new checks pass** — report evidence from PR?
> 4. **No `--check` in pipeline after generator** — assembly `--check` is in preflight only,
>    NOT called as a pipeline step in provision.sh?
> 5. **No fragment changes** — `firmware/core/` files untouched?
> 6. **No test changes** — test files untouched?
> 7. **No assembly script changes** — `assemble-sensor-history.sh` untouched?
> 8. **Tests green** — all 4 Playwright fixture sets pass?
>
> Also read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.2 — wire assembly into pipeline and fragment-level preflight.
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 8 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

- `prompts/phaseY/v7.6.6.2-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `session-handoff-v7.6.6.3.md` and
  `v7.6.6.3-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.2 -m "Phase Y: Wire assembly into pipeline and fragment-level preflight" && git push origin v7.6.6.2`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---
---

# v7.6.6.3 — Fragment Editing Workflow Validated

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md` — session context.
2. Read `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md` in full.
3. Read `scripts/assemble-sensor-history.sh` — understand `--write` and `--check` modes.

Then implement the validation cycle:

  1. Record baseline SHA-256 and verify `--check` PASSES
  2. Add trailing blank line to `registration.h`, reassemble, verify line count changes (4326)
  3. Revert the blank line, reassemble, verify SHA-256 matches baseline (IDENTITY RESTORED)
  4. Deliberate-break test: add space to config.h line 1, run `--check` WITHOUT reassembling — must FAIL
  5. Revert, run `--check` — must PASS again
  6. Document all four results (PASS → CHANGE → FAIL → PASS)
  7. Full pipeline, version bump, changelog, Playwright suite

Do NOT leave any permanent content changes in fragment files.
Do NOT modify the assembly script or preflight script.
Do NOT skip the deliberate-break test.

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.3 (fragment editing workflow validation) against
> `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **No permanent fragment changes** — `git diff` shows ZERO changes to `firmware/core/`?
> 2. **Four-step gate test documented** — PASS → CHANGE → FAIL → PASS sequence with evidence
>    for all four states? Include the actual output evidence from the PR.
> 3. **No assembly/preflight/provision.sh changes** — these scripts untouched?
> 4. **Fragment line counts unchanged** — total still 4,325?
> 5. **Tests green** — all 4 Playwright fixture sets pass?
>
> Also read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.3 — fragment editing workflow validated.
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 5 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

- `prompts/phaseY/v7.6.6.3-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `session-handoff-v7.6.6.4.md` and
  `v7.6.6.4-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.3 -m "Phase Y: Fragment editing workflow validated" && git push origin v7.6.6.3`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---
---

# v7.6.6.4 — Ping Adapter Fragment Validation

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md` — session context.
2. Read `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md` in full.
3. Read `firmware/core/ping-adapter.h` — the fragment being validated. Verify `#ifdef PING_DEVICE_INDEX` starts the file and the PingAdapter class is complete.

Then implement:

  1. Validate fragment content: `head -1 firmware/core/ping-adapter.h` → `#ifdef PING_DEVICE_INDEX`
  2. Verify PingAdapter class exists: `grep "class PingAdapter"` → exactly 1 match
  3. Verify no cross-fragment symbol leakage (no `s_cache_mutex`, no `HistoryMeta` in this fragment)
  4. Verify `wc -l` → 168 lines
  5. Assembly identity gate: `assemble-sensor-history.sh --check` → PASS
  6. Full pipeline, ESPHome config validation, Playwright suite
  7. Version bump, changelog

Do NOT modify any fragment file content.
Do NOT treat this as a "first real edit" step — no functional changes.
If ping device is configured, optionally run device smoke test.

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.4 (ping adapter fragment validation) against
> `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **No fragment changes** — `git diff` shows ZERO changes to `firmware/core/`?
> 2. **Compile-guard intact** — `#ifdef PING_DEVICE_INDEX` is first line of ping-adapter.h?
> 3. **PingAdapter class complete** — exactly 1 `class PingAdapter` match in the fragment?
> 4. **No cross-fragment symbol leakage** — no `s_cache_mutex`, no `HistoryMeta` in ping-adapter.h?
> 5. **Line count correct** — ping-adapter.h is exactly 168 lines?
> 6. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 7. **No script/test/YAML changes** — these files untouched?
> 8. **Tests green** — all 4 Playwright fixture sets pass?
>
> Also read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.4 — ping adapter fragment validation.
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 8 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

- `prompts/phaseY/v7.6.6.4-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `session-handoff-v7.6.6.5.md` and
  `v7.6.6.5-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.4 -m "Phase Y: Ping adapter fragment validation" && git push origin v7.6.6.4`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---
---

# v7.6.6.5 — NVS Persistence Device Test Gate ⚠️ BLOCKING

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

**⚠️ BLOCKING GATE — Phase Y cannot proceed if this step fails.**

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md` — session context.
2. Read `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md` in full.
3. Read `firmware/core/nvs-persistence.h` — understand `HistoryMeta`, `restore_from_nvs()`, `persist_hourly_segment()`, `maybe_yield_nvs_scan_()`.
4. Read `Docs/lessons/firmware.md` — NVS-related bugs and constraints.

Then implement the device test protocol on C3 at `192.168.120.189`:

  1. `bash scripts/provision.sh satellite` — full pipeline
  2. Flash C3: `cd firmware && esphome run esp32-c3-multi-sensor.yaml`
  3. Capture boot log — verify NVS restore messages, no crash
  4. Test 1: `curl -s http://192.168.120.189/api/storage-stats | python3 -m json.tool`
  5. Test 2: `curl -s http://192.168.120.189/api/manifest | python3 -m json.tool` then history endpoint
  6. Test 3: `curl -s http://192.168.120.189/api/v2/live | python3 -m json.tool`
  7. Test 4: `curl -s http://192.168.120.189/api/status | python3 -m json.tool`
  8. Test 5 (reboot persistence): record storage-stats → `curl -s -u ESPadmin:ESppass100 -d 'a=1' -X POST http://192.168.120.189/api/reboot` → wait 60s → re-check storage-stats → segments must not decrease
  9. Test 6 (optional): observe hourly persist cycle
  10. Document ALL evidence in PR
  11. Playwright suite, version bump, changelog

Do NOT use `Content-Type: application/json` — use `-d 'a=1'` for all POST.
Do NOT use generated YAML for C3 — use committed `esp32-c3-multi-sensor.yaml`.
Do NOT modify any source code.
If any device test fails, STOP and escalate using `prompts/phaseY/phase-y-bug-escalation-prompt.md`.

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.5 (NVS persistence device test gate — BLOCKING) against
> `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **No source code changes** — only changelog and version files modified?
> 2. **Boot log evidence present** — NVS restore messages, no crash? Include evidence snippet.
> 3. **Storage-stats evidence** — valid JSON with NVS statistics? Include evidence.
> 4. **History endpoint evidence** — populated data returned?
> 5. **Reboot persistence evidence** — pre/post comparison showing segments did NOT decrease?
> 6. **Correct curl usage** — `-d 'a=1'` for POST, no JSON content type used?
> 7. **Correct board YAML** — committed `esp32-c3-multi-sensor.yaml` (not generated)?
> 8. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 9. **Tests green** — all 4 Playwright fixture sets pass?
>
> Also read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.5 — NVS persistence device test gate (BLOCKING).
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 9 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

⚠️ If Gate 1 (no source changes), Gate 2 (boot log), Gate 5 (reboot persistence), or Gate 9 (tests)
are FAIL, do NOT recommend merge — this is a blocking gate.

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

- `prompts/phaseY/v7.6.6.5-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `session-handoff-v7.6.6.6.md` and
  `v7.6.6.6-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.5 -m "Phase Y: NVS persistence device test gate PASSED" && git push origin v7.6.6.5`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---
---

# v7.6.6.6 — Aggregator Runtime Device Test Gate ⚠️ BLOCKING

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

**⚠️ BLOCKING GATE — Phase Y cannot proceed if this step fails.**

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md` — session context.
2. Read `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md` in full.
3. Read `firmware/core/aggregator-runtime.h` — understand `SatelliteCache`, `s_cache_mutex`, poll task, deferred satellite tasks.
4. Read `firmware/core/deferred-management.h` — deferred reboot/delete-data pairs.

Then implement the device test protocol on S3 at `192.168.120.191`:

  1. `bash scripts/provision.sh aggregator` — generates S3-specific YAML
  2. Flash S3: `cd firmware && esphome run esp32-s3-devkitc1-n16r8-gw.yaml`
  3. Capture boot log — verify aggregator poll task start
  4. Test 1: `curl -s http://192.168.120.191/api/aggregator/gateways | python3 -m json.tool`
  5. Test 2: `curl -s http://192.168.120.191/api/aggregator/live | python3 -m json.tool`
  6. Test 3: Proxy history endpoint
  7. Test 4: `curl -s -u ESPadmin:ESppass100 -d "ip=192.168.120.189" -X POST http://192.168.120.191/api/aggregator/test-satellite`
  8. Test 5: `curl -s -d "ip=192.168.120.189" -X POST http://192.168.120.191/api/aggregator/add-satellite`
  9. Test 6: Check config_generation in gateways response
  10. Test 7: `curl -s -u ESPadmin:ESppass100 -X DELETE http://192.168.120.191/api/aggregator/satellite/0`
  11. Test 8: Re-add satellite, Test 9: Reboot persistence (pre/post gateways comparison)
  12. Test 10: `curl -s -u ESPadmin:ESppass100 -d 'a=1' -X POST http://192.168.120.191/api/system/reset-satellites`
  13. **MANDATORY: `bash scripts/provision.sh satellite`** — switch back before PR
  14. Document ALL evidence, Playwright suite, version bump, changelog

Do NOT use committed C3 YAML for S3 — use GENERATED `esp32-s3-devkitc1-n16r8-gw.yaml` (Critical Rule 36).
Do NOT forget to switch back to satellite mode.
Do NOT modify any source code.

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.6 (aggregator runtime device test gate — BLOCKING) against
> `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **No source code changes** — only changelog and version files modified?
> 2. **Correct board YAML** — generated `esp32-s3-devkitc1-n16r8-gw.yaml` used (not committed C3 YAML)?
> 3. **Aggregator poll task started** — boot log evidence present?
> 4. **All aggregator endpoints tested** — gateways, live, proxy all have evidence?
> 5. **Satellite mutation tested** — add, delete, test-satellite, reset-satellites all tested?
> 6. **Reboot persistence** — satellite config survived reboot (pre/post comparison)?
> 7. **Config generation incremented** — `config_generation` counter increased after mutation?
> 8. **Correct curl usage** — `-d 'a=1'` for POST, no JSON content type?
> 9. **Satellite mode restored** — `provision.sh satellite` run as last step before PR?
> 10. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 11. **Tests green** — all 4 Playwright fixture sets pass?
>
> Also read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.6 — aggregator runtime device test gate (BLOCKING).
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 11 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

⚠️ If Gate 2 (correct board YAML), Gate 6 (reboot persistence), Gate 9 (satellite mode restored),
or Gate 11 (tests) are FAIL, do NOT recommend merge — this is a blocking gate.

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

- `prompts/phaseY/v7.6.6.6-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `session-handoff-v7.6.6.7.md` and
  `v7.6.6.7-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.6 -m "Phase Y: Aggregator runtime device test gate PASSED" && git push origin v7.6.6.6`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---
---

# v7.6.6.7 — Full Endpoint Smoke Test

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md` — session context and endpoint list.
2. Read `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md` in full.
3. Read `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` — §5 (all 21 endpoints).

Then implement the comprehensive endpoint test across both boards:

**Phase A — C3 Satellite (21 endpoints at `192.168.120.189`):**
  1. Flash C3: `esphome run esp32-c3-multi-sensor.yaml`
  2. Test all 13 local endpoints (history, manifest, dashboard, status, live, ingest)
  3. Test auth behavior (401 unauthenticated → 200 authenticated)
  4. Test all 8 import/management endpoints (begin, data, finish, reboot, delete-data, reset-satellites)

**Phase B — S3 Aggregator (6 endpoints at `192.168.120.191`):**
  5. `bash scripts/provision.sh aggregator`
  6. Flash S3: `esphome run esp32-s3-devkitc1-n16r8-gw.yaml`
  7. Test all 6 aggregator endpoints (gateways, live, proxy, add, test, delete)

**Phase C — Cleanup:**
  8. **MANDATORY: `bash scripts/provision.sh satellite`**
  9. Playwright suite, version bump, changelog
  10. Fill in the 21-endpoint evidence table in PR description

Validate `esphome config` for BOTH board profiles before flashing.
Do NOT skip any of the 21 endpoints.
Do NOT run delete-data before other history tests.
Do NOT forget to switch back to satellite mode.
All POST commands use `-d 'a=1'` — never JSON content type.

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.7 (full endpoint smoke test) against
> `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **No source code changes** — only changelog and version files modified?
> 2. **All 21 endpoints tested** — evidence table complete with HTTP status codes for all 21?
>    Report any missing endpoints.
> 3. **Auth behavior verified** — both 401 unauthenticated and 200 authenticated cases documented?
> 4. **Import cycle tested** — begin/data/finish sequence evidence present?
> 5. **Both boards tested** — C3 satellite AND S3 aggregator both have evidence?
> 6. **Both ESPHome configs validated** — `esphome config` run for BOTH board profiles?
> 7. **Correct board YAMLs** — C3 uses committed YAML, S3 uses generated YAML?
> 8. **Correct curl usage** — `-d 'a=1'` for POST, no JSON content type?
> 9. **Satellite mode restored** — `provision.sh satellite` run as last step?
> 10. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 11. **Tests green** — all 4 Playwright fixture sets pass?
>
> Also read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.7 — full endpoint smoke test.
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 11 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.

- `prompts/phaseY/v7.6.6.7-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `session-handoff-v7.6.6.8.md` and
  `v7.6.6.8-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.7 -m "Phase Y: Full endpoint smoke test PASSED" && git push origin v7.6.6.7`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---
---

# v7.6.6.8 — Closure: Preflight, Documentation, Critical Rules

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md` — session context and closure scope.
2. Read `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md` in full.
3. Read `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §3 v7.6.6.8 (exact
   preflight checks and Critical Rules wording).
4. Read `scripts/preflight.sh` — count existing checks, understand function pattern.
5. Read `prompts/prompt-index-and-workflow.md` — Critical Rules table.
6. Read `prompts/handoff/phaseD/phaseD-results.md` — format reference for results document.

Then implement:

  1. Add 6 new preflight checks to `preflight.sh`:
     - `sensor_history_monolith_is_assembled` — `assemble-sensor-history.sh --check` passes
     - `firmware_core_fragment_count` — exactly 8 fragments
     - `no_generator_markers_in_fragments` — no SENSOR_MANIFEST content between delimiters
     - `deferred_task_pairs_in_expected_homes` — all 4 pairs in correct fragments
     - `maybe_yield_present_in_nvs_persistence` — function defined in nvs-persistence.h
     - `mutex_single_owner` — `s_cache_mutex` defined only in aggregator-runtime.h
  2. Add Critical Rules 58–62 to `prompts/prompt-index-and-workflow.md` (exact plan wording)
  3. Update Phase Y step statuses to ✅ Complete, add completion summary
  4. Update `README.md` — document `firmware/core/` structure with fragment table
  5. Update `Docs/lessons/firmware.md` — fragment architecture lesson
  6. Update `Docs/lessons/build-pipeline.md` — assembly step documentation
  7. Create `prompts/handoff/phaseY-results.md` — Phase Y results document
  8. Version bump, changelog, full pipeline, Playwright suite
  9. Verify ALL preflight checks pass (report total count)

Do NOT modify fragment content, assembly script, test files, or YAML.
Use EXACT Critical Rule wording from the Phase Y plan.

## Step 2 — Review Prompt (Context-Window Optimized)

_Use this prompt in a fresh Copilot chat session after the agent has created PR #<PR_NUMBER>._

**This is the final Phase Y step. All deliverables below are mandatory.**

---

### Step 2-A — Deep Research (sub-agent)

Use the deep-research agent on `GCV-Sleeper-Service/ESP32-GW-multi-sensor` with this query:

> Investigate PR #<PR_NUMBER> for v7.6.6.8 (Phase Y closure) against
> `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md`
> and `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`.
>
> Check these gates and report findings as a structured table:
>
> 1. **6 new preflight checks** — all 6 functions exist in `preflight.sh` AND are called in
>    main sequence? List all 6 by function name.
> 2. **ALL preflight checks pass** — report total count from PR evidence.
> 3. **Critical Rules 58–62** — exact wording from Phase Y plan? All 5 present?
>    Report each rule number and its one-line summary.
> 4. **Phase Y step table** — all 9 steps marked ✅ Complete?
>    Report the full Phase Y Step Index table so synthesis does not re-read the file.
> 5. **Phase Y completion summary present** — in `prompts/prompt-index-and-workflow.md`?
> 6. **README updated** — `firmware/core/` structure documented with fragment table?
> 7. **Firmware lessons** — fragment architecture lesson added to `Docs/lessons/firmware.md`?
> 8. **Build-pipeline lessons** — assembly step lesson added to `Docs/lessons/build-pipeline.md`?
> 9. **Phase Y results document** — `prompts/handoff/phaseY-results.md` exists and complete?
>    Does it include delivery metrics, lessons learned, and all 9 steps?
> 10. **No fragment content changes** — `firmware/core/` files untouched?
> 11. **No test file changes** — test files untouched?
> 12. **Assembly identity holds** — `assemble-sensor-history.sh --check` passes?
> 13. **ESPHome config validates**?
> 14. **Tests green** — all 4 Playwright fixture sets pass?
> 15. **Final migration safety** — all 12 Phase Y migration safety rules verified across
>     entire Phase Y? Report which rules were verified and how.
>
> **prompt-index snapshot:** Read `prompts/prompt-index-and-workflow.md` fully and include:
> - The complete Phase Y Step Index table (version, scope, status)
> - The complete Critical Rules table (number, rule summary, source) — especially Rules 58–62
> - The Revision History entry for v7.6.6.8 (if present)
> - The v7.6.6.8 / Phase Y delivery summary (if present)
> This avoids the synthesis session needing to re-read this large file.
>
> Also read ALL PR review comments and issue comments on PR #<PR_NUMBER>.
> For each reviewer finding report: warranted (yes/no/partially), severity, fixed (yes/no),
> commit that fixed it.
>
> For each gate report: PASS / FAIL / UNCLEAR with a one-line evidence summary.

Wait for the sub-agent to return results before proceeding.

---

### Step 2-B — Synthesis (this session)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Current task: v7.6.6.8 — Phase Y closure (final step).
PR: #<PR_NUMBER>

Review comments posted:
1. <PASTE_REVIEW_URL_1>

The last commit/comment with fixes is <LAST_FIX_COMMIT>.

Using the deep-research results from Step 2-A, provide:

1. **Gate checklist table** — all 15 gates with PASS/FAIL/UNCLEAR and one-line evidence
2. **Review comment assessment** — table: source, finding, warranted?, fixed?, remaining action
3. **Resolved vs. remaining** — what was fixed vs. what still needs work
4. **Concrete fix list** — specific changes needed before merge (if any)

Do NOT re-read `prompts/prompt-index-and-workflow.md` — use the sub-agent's snapshot from
Step 2-A for Critical Rules and Step Index verification. Only fetch specific file sections
(line ranges) if the sub-agent results are ambiguous on a particular gate.

Post findings as a PR comment on #<PR_NUMBER>.

---

### Step 2-C — Fix Prompt Generation (if needed)

If issues remain, generate a downloadable fix prompt in markdown that:
- Addresses ONLY the remaining issues
- Includes a Do-NOT list to prevent regressions
- Follows the project's existing prompt conventions

---

### Step 2-D — Post-merge Deliverables

IMPORTANT: Once PR is merged, produce these BEFORE closing the session.
Double-check the Workflow and Post-PR Closure Deliverables sections of
`prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`.

**This is the final Phase Y step. All deliverables below are mandatory.**

#### 2-D-i. Consolidated Audit

Produce `prompts/phaseY/v7.6.6.8-PR<NN>-consolidated-audit-and-lessons.md` using:
- Template: `prompts/phaseX/pr-audit-question-template.md` (adapt for Phase Y)
- Format reference: `prompts/phaseX/v7.6.5.8-PR<NN>-consolidated-audit-and-lessons.md`
- Stable core questions (5 internal + 4 external reviewer)
- Closure supplement:
  - Are all new Critical Rules (58–62) traceable to a specific Phase Y step?
  - Does the Phase Y results document accurately reflect what was delivered?
  - Are all 9 Phase Y steps marked complete?
  - Does the README `firmware/core/` section match reality?
  - Is the assembly step correctly documented in Critical Rules and pipeline sections?
  - Is `sensor_history_multi.h` fully reproduced from fragments with zero diff?

Use the sub-agent results from Step 2-A as the primary evidence source.
Use the sub-agent's prompt-index snapshot for Critical Rules and Step Index tables —
do NOT re-read the file.

#### 2-D-ii. Prompt Index Updates

Using the sub-agent's prompt-index snapshot as baseline, provide necessary edits to
`prompts/prompt-index-and-workflow.md`:
- v7.6.6.8 → `✅ Complete <DATE>`
- Phase Y section header → `✅ COMPLETE`
- Add v7.6.6.8 delivery summary
- Add any new Critical Rules from this step
- Add Revision History entry
- Update "Next Phase ⬅ NEXT" marker per operator decision

#### 2-D-iii. Phase Y Completion Summary

Provide a brief statement confirming:
- All 9 steps shipped (v7.6.6.0 through v7.6.6.8)
- Test count maintained throughout
- Phase Y results document produced
- `sensor_history_multi.h` successfully fragmented and assembly proven
- Next phase determination — flag for operator decision

Tag: `git tag -a v7.6.6.8 -m "Phase Y: Closure — sensor_history_multi.h architecture refactor complete" && git push origin v7.6.6.8`

---

### Fill-in Checklist

- [ ] `<PR_NUMBER>` — actual PR number
- [ ] `<PASTE_REVIEW_URL_1>` — actual review/comment URLs (remove unused slots)
- [ ] `<LAST_FIX_COMMIT>` — SHA of last fix commit

---

_End of Phase Y Copilot-Optimized PR Review Prompts._
