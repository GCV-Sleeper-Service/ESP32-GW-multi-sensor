# Phase Y — Two-Session Prompts Optimized for GPT Worker/Sub-Agent Use

_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_  
_Date: 2026-04-09_

These prompts are optimized for GPT-style coordinator sessions that can use workers/sub-agents or, if workers are unavailable, sequential focused passes.

The core design goal is:

- keep the **coordinator session** narrow
- push broad reading into **bounded workers**
- return **short structured briefs**
- open full files in the coordinator only when they will be edited, quoted, or directly verified

---

## Shared worker protocol

Use this protocol for every step unless the step says otherwise.

### Agent session protocol

Launch **three workers** before making edits.

**Worker A — Contract extractor**
- Read only the step handoff, the step implementation instructions, and the exact Phase Y plan subsection for this version.
- Return **max 600 tokens**.
- Output sections:
  1. Objective
  2. Allowed files to edit
  3. Forbidden files / forbidden actions
  4. Required validations
  5. Deliverables
  6. Unresolved risks or ambiguities

**Worker B — Code-surface extractor**
- Read only the target files for the step.
- Return **max 700 tokens**.
- Output sections:
  1. Relevant files and why
  2. Exact insertion points / functions / structures involved
  3. Existing invariants that must survive
  4. Likely regression traps
  5. Any file that the coordinator must open fully before editing

**Worker C — Validation/evidence extractor**
- Read only the validation surfaces for the step: relevant rules, test instructions, preflight expectations, device-test constraints, or evidence requirements.
- Return **max 500 tokens**.
- Output sections:
  1. Must-pass gates
  2. Minimum evidence required
  3. Common failure modes
  4. Any must-not-miss post-step deliverables

### Review session protocol

Launch **three workers** before writing the review.

**Worker R1 — Spec gate mapper**
- Read only the handoff, implementation instructions, and exact Phase Y plan subsection for the step.
- Return **max 600 tokens**.
- Output:
  1. Gate checklist
  2. Allowed scope
  3. Forbidden scope
  4. Required evidence
  5. Required post-merge deliverables

**Worker R2 — Diff auditor**
- Read only the PR diff and the files actually changed.
- Return **max 700 tokens**.
- Output:
  1. Files changed
  2. What changed by file
  3. Any scope violations
  4. Any likely regressions
  5. Which gates are satisfied directly by the diff

**Worker R3 — Evidence auditor**
- Read only test logs, session logs, PR description, review comments, issue comments, and any device-test evidence.
- Return **max 700 tokens**.
- Output:
  1. Validation evidence by gate
  2. Reviewer findings and whether they appear warranted
  3. What is fixed vs still unresolved
  4. Missing evidence, if any

### Coordinator rules

The coordinator session must follow all of these rules:

1. Do **not** reread every file named by the workers. Open full files only when:
   - you will edit them,
   - you must quote them,
   - a worker marked them ambiguous,
   - or the diff/evidence conflicts with the worker summary.
2. Keep a rolling coordinator summary of **max 400 tokens** containing:
   - current objective,
   - allowed files,
   - forbidden files,
   - remaining validations,
   - remaining deliverables.
3. If workers are unavailable, emulate them with **three sequential focused passes** and keep only the compact summaries.
4. Do not let workers paste long prose. Enforce the token caps.
5. For review steps, be **diff-first and evidence-first**. Do not reopen the full repo unless a gate cannot be decided otherwise.
6. Preserve the project’s strict scope discipline. Optimization is for context handling, not for relaxing requirements.

---

## Output format expected from the coordinator

### Agent session final output
- brief implementation summary
- changed files
- validation results
- remaining risks
- requested deliverables for the step

### Review session final output
- gate checklist table
- reviewer finding assessment table
- resolved vs remaining
- concrete fix list if needed
- post-merge deliverables if the PR is ready

---

---

# v7.6.6.0 — Pre-step: `provision.sh` full pipeline automation

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md`
- `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md`
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — only the `v7.6.6.0` subsection
- `prompts/prompt-index-and-workflow.md` — only rules directly cited by the step

### Worker B scope

- `scripts/provision.sh`
- `Docs/lessons/operations.md`
- `Docs/changelog.md`

### Worker C scope

- Full pipeline validation for satellite, aggregator, and wroom modes.
- Playwright across all four fixture sets.
- `bash scripts/preflight.sh`.

After the three workers return, the coordinator should:

- Add `run_full_pipeline()` with the exact Phase Y step order and no `eval`.
- Add `require_node()` and `require_npm_deps()` pre-checks.
- Add `--dry-run` support for satellite, aggregator, and wroom modes.
- Replace old workflow-print calls with actual pipeline execution where required.
- Keep `status` non-mutating.
- Preserve the Step 0 assembly placeholder as a printed skip/no-op until `v7.6.6.1`.
- Add the operations lesson, bump version, update changelog, run validations, and produce the session log/compliance table.

### Do-not list

- Do not modify `sensor_history_multi.h`.
- Do not modify firmware source or tests.
- Do not use `eval`.
- Do not make `status` mutating.

### Validation checklist

- Full pipeline validation for satellite, aggregator, and wroom modes.
- Playwright across all four fixture sets.
- `bash scripts/preflight.sh`.

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md`
- `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md`
- Phase plan `v7.6.6.0` subsection

### Worker R2 scope

- PR diff touching `scripts/provision.sh`, changelog, lesson file, version/session-log artifacts

### Worker R3 scope

- Pipeline ordering
- assembly placeholder behavior
- `--dry-run` behavior
- `status` non-mutating
- dependency pre-checks
- Playwright/preflight evidence
- review comments and fixes

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- Pipeline order matches the step contract exactly.
- Assembly placeholder is a printed skip/no-op, not an executed missing command.
- `--dry-run` prints steps and makes no filesystem changes.
- `status` does not call the pipeline.
- No `eval` usage.
- Pre-checks run before pipeline execution.
- No out-of-scope changes.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.0-PR<NN>-consolidated-audit-and-lessons.md`.
- Review and update `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`.
- Review and update `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md`.
- Apply the version tag command for `v7.6.6.0` if the repo workflow requires it.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

# v7.6.6.1 — Establish assembly script and baseline

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`
- `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md`
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — fragment manifest, boundaries, and `v7.6.6.1` subsection

### Worker B scope

- `dashboard/sensor_history_multi.h`
- `scripts/provision.sh`
- `scripts/preflight.sh`
- new `firmware/core/*.h` fragments
- new `scripts/assemble-sensor-history.sh`
- `Docs/changelog.md`

### Worker C scope

- `bash scripts/assemble-sensor-history.sh --check`
- `bash scripts/assemble-sensor-history.sh --list`
- `diff` assembled vs concatenated fragments
- `bash scripts/preflight.sh`
- `esphome config ...`
- Playwright across four fixture sets

After the three workers return, the coordinator should:

- Verify monolith line count, boundary landmarks, and baseline SHA before splitting.
- Create `firmware/core/` and extract the eight exact fragments using explicit line ranges.
- Verify fragment line counts sum to 4325 and direct concatenation matches the monolith.
- Create `scripts/assemble-sensor-history.sh` with `--write`, `--check`, `--list`, and `--dry-run`.
- Use generator-aware `--check` behavior for generated marker regions.
- Activate the assembly step in `provision.sh` and add fragment existence coverage in `preflight.sh`.
- Bump version, update changelog, run full validation.

### Do-not list

- Do not use `split`; use explicit extraction ranges.
- Do not modify YAML includes.
- Do not redirect `render_sensor_config.py` to fragments.
- Do not manually rewrite fragment contents beyond extraction/script work.

### Validation checklist

- `bash scripts/assemble-sensor-history.sh --check`
- `bash scripts/assemble-sensor-history.sh --list`
- `diff` assembled vs concatenated fragments
- `bash scripts/preflight.sh`
- `esphome config ...`
- Playwright across four fixture sets

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`
- `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md`
- Phase plan sections for fragment boundaries and assembly behavior

### Worker R2 scope

- PR diff touching fragment files, assembly script, provision, preflight, changelog

### Worker R3 scope

- line-count evidence
- boundary landmark evidence
- `--check`/`--list` output
- MODULES order
- YAML unchanged
- review comments/fixes

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- Exactly eight fragments exist.
- Line counts sum to 4325.
- Direct concatenation identity holds.
- Generator-aware `--check` is implemented correctly.
- Assembly step is active.
- YAML stayed unchanged.
- Changes are structural, not behavioral.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.1-PR<NN>-consolidated-audit-and-lessons.md`.
- Review and update the `v7.6.6.2` handoff and implementation-instructions artifacts.
- Apply the version tag command for `v7.6.6.1` if the repo workflow requires it.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

# v7.6.6.2 — Wire assembly into pipeline and fragment-level preflight

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`
- `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md`
- Phase plan `v7.6.6.2` subsection and §4.2 generator/assembly sync note

### Worker B scope

- `scripts/provision.sh`
- `scripts/preflight.sh`
- `Docs/changelog.md`

### Worker C scope

- Full pipeline
- `bash scripts/preflight.sh`
- Playwright across four fixture sets
- `esphome config ...`

After the three workers return, the coordinator should:

- Confirm the assembly write step is active in the canonical pipeline.
- Add `firmware_core_assembly_check` to preflight.
- Add `firmware_core_fragment_line_sum` to preflight.
- Keep assembly `--check` in preflight only, not as a post-generator pipeline step.
- Bump version, update changelog, run validations.

### Do-not list

- Do not edit fragments.
- Do not edit tests.
- Do not add assembly `--check` after generator steps.

### Validation checklist

- Full pipeline
- `bash scripts/preflight.sh`
- Playwright across four fixture sets
- `esphome config ...`

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- handoff `v7.6.6.2`
- implementation instructions `v7.6.6.2`
- plan `v7.6.6.2` and §4.2

### Worker R2 scope

- PR diff for `provision.sh`, `preflight.sh`, changelog, version/session log

### Worker R3 scope

- new preflight checks
- assembly write position in pipeline
- absence of assembly check after generator
- validation evidence

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- Assembly write is Step 0 in the pipeline.
- Two new preflight checks exist and pass.
- No fragment or test changes.
- No forbidden `--check` step was added after generator.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.2-PR<NN>-consolidated-audit-and-lessons.md`.
- Review and update the `v7.6.6.3` handoff and implementation-instructions artifacts.
- Apply the version tag command for `v7.6.6.2` if the repo workflow requires it.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

# v7.6.6.3 — Fragment editing workflow validated

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md`
- `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md`

### Worker B scope

- `scripts/assemble-sensor-history.sh`
- `firmware/core/registration.h` (temporary edit only)
- `firmware/core/config.h` (temporary edit only)
- `Docs/changelog.md`

### Worker C scope

- Identity gate before and after each transient change
- full pipeline
- Playwright
- preflight as required by the step

After the three workers return, the coordinator should:

- Record baseline SHA and passing `--check`.
- Perform the temporary blank-line change in `registration.h`, reassemble, and observe the expected line-count delta.
- Revert and verify baseline identity is restored.
- Perform the deliberate-break test in `config.h` without reassembling and verify `--check` fails.
- Revert and restore passing state.
- Document the PASS → CHANGE → FAIL → PASS sequence, then run normal validation.

### Do-not list

- Do not leave permanent fragment changes.
- Do not edit assembly/preflight/provision scripts.
- Do not skip the deliberate-break test.

### Validation checklist

- Identity gate before and after each transient change
- full pipeline
- Playwright
- preflight as required by the step

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- handoff `v7.6.6.3`
- implementation instructions `v7.6.6.3`

### Worker R2 scope

- PR diff should show no lasting fragment changes

### Worker R3 scope

- documented four-stage validation sequence
- line counts restored
- final diff clean for `firmware/core/`

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- No permanent fragment changes remain.
- The four-stage validation sequence is evidenced.
- No unrelated scripts were changed.
- Final fragment totals return to 4325.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.3-PR<NN>-consolidated-audit-and-lessons.md`.
- Review and update the `v7.6.6.4` handoff and implementation-instructions artifacts.
- Apply the version tag command for `v7.6.6.3` if the repo workflow requires it.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

# v7.6.6.4 — Ping adapter fragment validation

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md`
- `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md`

### Worker B scope

- `firmware/core/ping-adapter.h`
- `Docs/changelog.md`

### Worker C scope

- `assemble-sensor-history.sh --check`
- `wc -l firmware/core/ping-adapter.h`
- `esphome config ...`
- Playwright

After the three workers return, the coordinator should:

- Verify the compile guard and class integrity in `ping-adapter.h`.
- Verify there is no cross-fragment symbol leakage.
- Verify line count and assembly identity.
- Run pipeline/config/test validation, bump version, and update changelog.

### Do-not list

- Do not modify fragment content.
- Do not convert this into a functional edit step.
- Do not touch tests or YAML.

### Validation checklist

- `assemble-sensor-history.sh --check`
- `wc -l firmware/core/ping-adapter.h`
- `esphome config ...`
- Playwright

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- handoff `v7.6.6.4`
- implementation instructions `v7.6.6.4`

### Worker R2 scope

- PR diff should contain changelog/version/session-log only unless evidence artifacts are expected

### Worker R3 scope

- guard intact
- exactly one PingAdapter class
- no leaked symbols
- identity gate evidence

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- No fragment changes.
- Compile guard remains first line.
- Exactly one PingAdapter class exists.
- No cross-fragment symbol leakage.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.4-PR<NN>-consolidated-audit-and-lessons.md`.
- Review and update the `v7.6.6.5` handoff and implementation-instructions artifacts.
- Apply the version tag command for `v7.6.6.4` if the repo workflow requires it.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

# v7.6.6.5 — NVS persistence device test gate

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md`
- `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md`

### Worker B scope

- `firmware/core/nvs-persistence.h`
- device-test evidence/logs
- `Docs/changelog.md`
- version/session-log artifacts

### Worker C scope

- assembly identity
- Playwright
- device evidence table
- blocking-gate verdict
- `Docs/lessons/firmware.md` — only NVS-relevant lessons

After the three workers return, the coordinator should:

- Run the satellite pipeline and flash the committed C3 YAML.
- Capture boot/restore evidence.
- Verify storage-stats, manifest/history, live, and status endpoints.
- Verify reboot persistence using the required POST style.
- Observe hourly persist if available.
- If any device gate fails, stop and use the bug-escalation prompt instead of pushing ahead.

### Do-not list

- Do not modify source code.
- Do not use JSON POST bodies.
- Do not use generated YAML for the C3 step.
- Do not continue if the blocking gate fails.

### Validation checklist

- assembly identity
- Playwright
- device evidence table
- blocking-gate verdict
- `Docs/lessons/firmware.md` — only NVS-relevant lessons

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- handoff `v7.6.6.5`
- implementation instructions `v7.6.6.5`
- NVS-related lessons/constraints

### Worker R2 scope

- PR diff should be evidence-oriented, not source-edit oriented

### Worker R3 scope

- boot logs
- storage-stats JSON
- history/live/status output
- reboot persistence comparison
- POST command correctness
- blocking-gate verdict

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- No source code changes.
- Correct board YAML and POST style were used.
- Reboot persistence evidence is credible.
- Blocking gate is clearly PASS or FAIL.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.5-PR<NN>-consolidated-audit-and-lessons.md`.
- Review and update the `v7.6.6.6` handoff and implementation-instructions artifacts.
- If the blocking gate fails, state explicitly that Phase Y is blocked and do not advance the phase.
- Apply the version tag command for `v7.6.6.5` only if the gate truly passed.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

# v7.6.6.6 — Aggregator runtime device test gate

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md`
- `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md`

### Worker B scope

- `firmware/core/aggregator-runtime.h`
- `firmware/core/deferred-management.h`
- aggregator device evidence/logs
- `Docs/changelog.md`
- version/session-log artifacts

### Worker C scope

- assembly identity
- Playwright
- aggregator evidence table
- blocking-gate verdict
- satellite-mode restoration evidence

After the three workers return, the coordinator should:

- Run the aggregator provisioning flow and flash the generated S3 YAML.
- Verify poll-task start and all required aggregator endpoints.
- Verify add/delete/test/reset flows and config-generation behavior.
- Verify reboot persistence for satellite configuration.
- Switch the repo back to satellite mode before finalizing.
- If the blocking gate fails, stop and escalate.

### Do-not list

- Do not modify source code.
- Do not use the committed C3 YAML for S3.
- Do not forget to switch back to satellite mode.
- Do not continue if the blocking gate fails.

### Validation checklist

- assembly identity
- Playwright
- aggregator evidence table
- blocking-gate verdict
- satellite-mode restoration evidence

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- handoff `v7.6.6.6`
- implementation instructions `v7.6.6.6`
- aggregator/deferred task constraints

### Worker R2 scope

- PR diff should show evidence + version/changelog/session log, not source changes

### Worker R3 scope

- boot logs
- gateways/live/proxy results
- mutation endpoint results
- reboot persistence
- mode restore evidence

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- No source code changes.
- Correct generated S3 YAML was used.
- All required mutation flows were exercised.
- Blocking gate is clearly PASS or FAIL.
- Satellite mode was restored.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.6-PR<NN>-consolidated-audit-and-lessons.md`.
- Review and update the `v7.6.6.7` handoff and implementation-instructions artifacts.
- If the blocking gate fails, state explicitly that Phase Y is blocked and do not advance the phase.
- Apply the version tag command for `v7.6.6.6` only if the gate truly passed.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

# v7.6.6.7 — Full endpoint smoke test

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md`
- `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md`
- `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` — only the endpoint inventory section

### Worker B scope

- endpoint evidence tables
- version/changelog/session-log artifacts

### Worker C scope

- complete 21-endpoint evidence table
- assembly identity
- Playwright
- both config validations

After the three workers return, the coordinator should:

- Validate config for both board profiles before flashing.
- Test all local satellite endpoints, including auth and import-management flows.
- Test all aggregator endpoints on the S3 profile.
- Keep endpoint evidence in a complete table with statuses.
- Restore the repo to satellite mode before finalizing.

### Do-not list

- Do not skip any endpoint.
- Do not run delete-data before the history checks.
- Do not forget to restore satellite mode.
- Do not use JSON POST bodies.

### Validation checklist

- complete 21-endpoint evidence table
- assembly identity
- Playwright
- both config validations

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- handoff `v7.6.6.7`
- implementation instructions `v7.6.6.7`
- endpoint inventory section only

### Worker R2 scope

- PR diff centered on evidence artifacts and closure docs, not source changes

### Worker R3 scope

- 21-endpoint table
- auth behavior
- import cycle
- both board validations
- mode restoration

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- All 21 endpoints are explicitly covered.
- Auth behavior is demonstrated.
- Both board profiles were validated.
- Correct board YAMLs and POST style were used.
- Satellite mode was restored.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.7-PR<NN>-consolidated-audit-and-lessons.md`.
- Review and update the `v7.6.6.8` handoff and implementation-instructions artifacts.
- Apply the version tag command for `v7.6.6.7` if the repo workflow requires it.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

# v7.6.6.8 — Closure: preflight, documentation, critical rules

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Before editing anything, launch the workers with these exact scopes.

### Worker A scope

- `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`
- `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md`
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — only `v7.6.6.8` and exact rule wording
- `prompts/prompt-index-and-workflow.md`
- `prompts/handoff/phaseD/phaseD-results.md` as format reference

### Worker B scope

- `scripts/preflight.sh`
- `README.md`
- `Docs/lessons/firmware.md`
- `Docs/lessons/build-pipeline.md`
- `prompts/prompt-index-and-workflow.md`
- new `prompts/handoff/phaseY-results.md`
- `Docs/changelog.md`

### Worker C scope

- all preflight checks pass
- assembly identity
- `esphome config ...`
- Playwright
- final prompt-index/Phase Y closure verification
- exact wording check for Rules 58–62

After the three workers return, the coordinator should:

- Add the six closure preflight checks.
- Add Critical Rules 58–62 with exact wording from the plan.
- Mark Phase Y complete in the prompt index and add the completion summary.
- Document `firmware/core/` in README and lessons files.
- Create `prompts/handoff/phaseY-results.md`.
- Run full validation and report the final total preflight count.

### Do-not list

- Do not modify fragment content.
- Do not modify test files.
- Do not paraphrase the new Critical Rules.
- Do not change YAML.

### Validation checklist

- all preflight checks pass
- assembly identity
- `esphome config ...`
- Playwright
- final prompt-index/Phase Y closure verification
- exact wording check for Rules 58–62

### Coordinator instructions

- Do not reopen the entire step dependency tree once the worker briefs exist.
- Open full file contents only for files you will edit or directly verify.
- If the worker briefs conflict, resolve the conflict by fetching only the narrow file section needed.
- Keep the coordinator ledger under 400 tokens throughout the session.
- At the end, report: changed files, validations run, evidence collected, remaining risks, and step deliverables.

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared worker protocol** at the top of this file.

Open a fresh review session and launch the review workers with these scopes.

### Worker R1 scope

- handoff `v7.6.6.8`
- implementation instructions `v7.6.6.8`
- plan wording for closure checks and rules
- prompt-index snapshot requirements

### Worker R2 scope

- PR diff for preflight, README, lessons, prompt-index, results doc, changelog

### Worker R3 scope

- six new preflight checks
- Critical Rules 58–62 exact wording
- Phase Y step table marked complete
- results doc completeness
- migration safety summary

After the workers return, the coordinator must produce:

- A gate checklist table with PASS / FAIL / UNCLEAR and one-line evidence.
- A reviewer-finding assessment table: source, finding, warranted?, fixed?, remaining action.
- A resolved-vs-remaining summary.
- A concrete fix list if anything is still open.
- A focused fix prompt if the step is not merge-ready.

### Review gates to decide explicitly

- All six preflight checks exist and are wired.
- Rules 58–62 match plan wording exactly.
- Phase Y step table is fully completed.
- Results doc exists and is complete.
- No fragment or test content changes occurred.

### Post-merge deliverables to list when the PR is ready

- Create `prompts/phaseY/v7.6.6.8-PR<NN>-consolidated-audit-and-lessons.md`.
- Confirm the final Phase Y completion summary.
- Confirm that all nine steps shipped, the results document exists, the six preflight checks pass, and Rules 58–62 were added exactly.
- Apply the version tag command for `v7.6.6.8` if the repo workflow requires it.

### Review coordinator instructions

- Be diff-first. Do not reread the entire repo.
- Use the worker gate map as the primary contract source.
- Fetch full file contents only if the diff or evidence is ambiguous.
- Treat missing evidence separately from failing evidence.
- If a blocking device-test step fails, say so explicitly and do not soften the verdict.
- If post-merge deliverables are required by the step and the PR is merge-ready, list them explicitly before ending the session.

---

_End of Phase Y GPT-optimized two-session prompts._