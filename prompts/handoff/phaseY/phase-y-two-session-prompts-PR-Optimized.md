# Phase Y — Two-Session Prompts Optimized for Perplexity

_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_  
_Date: 2026-04-09_  
_Optimized for: Perplexity AI (stateless, MCP GitHub tool access, no persistent sub-agents)_

---

## How these prompts differ from the originals

The original prompts were written for **Claude Code** — an IDE agent with a persistent shell, local file system, and iterative REPL. Perplexity operates differently:

- **No shell execution.** Every file read is a GitHub MCP API call that consumes context tokens.
- **No persistent sub-agent workers.** The entire session is one context window; there is no "coordinator + workers" hierarchy.
- **Stateless per turn.** Nothing persists between conversations unless committed to the repo.
- **Context is the scarcest resource.** Loading large files upfront (e.g., the full `sensor_history_multi.h` monolith) can consume 30–60 % of the working window before any work begins.

The design goal for these prompts is:

- **Inline compact context** at the top of every prompt (≤ 400 tokens) so constraints are in high-attention positions.
- **Deferred, targeted reads** — only fetch the exact file or section needed at the moment of the edit, not a bulk upfront read list.
- **Three-turn session split** for agent work: Turn 1 loads constraints + plans a narrow read list, Turn 2 executes edits, Turn 3 verifies and produces the compliance table.
- **Evidence-first reviews** — load the PR diff and evidence artifacts first; only open source files if the diff is ambiguous.
- **Table-first output** — gate compliance tables (≤ 600 tokens) rather than long prose session logs (2 000–4 000 tokens).

---

## Shared Perplexity session protocol

This protocol applies to every step unless the step section says otherwise.

### Agent session — three-turn structure

**Turn 1 — Constraints + read plan (≤ 300 tokens output)**

Read only:
- The inline context header for the step (provided directly in the prompt below).
- The step handoff file.
- The implementation-instructions file for the step.

Produce a compact read plan:
1. Files you will edit (list, max 5 lines).
2. Files you need to read before editing (list exact sections if possible, max 5 lines).
3. Forbidden files / forbidden actions (copy from the inline context header).
4. Validations you will run after editing.
5. Unresolved ambiguities, if any (max 3 lines).

Do **not** open any source file yet. Do **not** start editing.

**Turn 2 — Execute**

Open files only from the Turn 1 read plan, and only the sections needed for the edit.  
Make the edits described in the step's implementation instructions.  
After each edit, record: file changed, what changed, why.

**Turn 3 — Verify + compliance table**

Run the validations from the Turn 1 plan.  
Produce the compliance table (see Output format below).  
Report remaining risks and post-step deliverables.

### Agent session — coordinator constraints

- **Never open a file that is not on the Turn 1 read plan** unless a new ambiguity requires it.
- **Never reopen a file you have already fully read.** Quote from memory or fetch only the needed line range.
- **Keep a running ledger** of context spent: files opened, tokens estimated. Stop and report if you are approaching 60 % context usage without having reached Turn 3.
- **Do not open `sensor_history_multi.h` in full** at any step. If you need content from it, read a specific line range only.
- **Do not read the full Phase Y architecture doc.** The relevant subsection path is provided in each step's inline context header.
- **Scope discipline is not relaxed.** These optimizations are for context handling only, not for loosening requirements.

---

### Review session — three-turn structure

**Turn 1 — Spec extraction (≤ 300 tokens output)**

Read only:
- The inline review context header (provided below).
- The step handoff file.
- The implementation-instructions file.

Produce:
1. Gate checklist (items only, one line each).
2. Allowed diff scope.
3. Required evidence artifacts.
4. Blocking gate verdict criteria.

Do **not** open the PR diff yet.

**Turn 2 — Diff + evidence audit**

Fetch the PR diff for the exact files listed in the gate checklist.  
Fetch evidence artifacts listed in Turn 1 (logs, session log, compliance table from the agent session).  
For each gate: record PASS / FAIL / UNCLEAR with one-line evidence.  
Only open source files if a gate cannot be decided from the diff alone.

**Turn 3 — Verdict + output**

Produce the full review output (see Output format below).  
If post-merge deliverables are required, list them explicitly.

### Review session — coordinator constraints

- **Diff-first.** Do not open source files unless the diff is ambiguous.
- **Missing evidence ≠ failing evidence.** Mark gates UNCLEAR, not FAIL, when evidence is simply absent from the PR.
- **Do not soften blocking device-test failures.** If a device gate fails, the verdict is BLOCKED regardless of other gates.
- **Do not reread the full repo.** Treat the gate checklist from Turn 1 as the complete contract.

---

## Output formats

### Agent session — Turn 3 output

```
## Compliance table — v7.6.6.X

| Gate | Status | Evidence |
|------|--------|----------|
| [gate 1] | PASS/FAIL | [one-line evidence] |
...

## Changed files
- [file]: [what changed]

## Validations run
- [validation]: [result]

## Remaining risks
- [risk, if any]

## Post-step deliverables
- [deliverable, if any]
```

### Review session — Turn 3 output

```
## Gate checklist — v7.6.6.X PR #NN

| Gate | Status | Evidence |
|------|--------|----------|
| [gate 1] | PASS/FAIL/UNCLEAR | [one-line evidence] |
...

## Reviewer finding assessment

| Finding | Warranted? | Fixed? | Remaining action |
|---------|------------|--------|-----------------|
| [finding] | Y/N | Y/N | [action or none] |

## Resolved vs. remaining
- Resolved: [list]
- Remaining: [list or "none"]

## Verdict
MERGE-READY / NEEDS-FIX / BLOCKED

## Fix list (if NEEDS-FIX)
1. [specific fix]

## Post-merge deliverables (if MERGE-READY)
- [deliverable]
```

---

---

# v7.6.6.0 — Pre-step: `provision.sh` full pipeline automation

## Inline context — agent

```
Objective: Add run_full_pipeline() to provision.sh with the exact Phase Y step order.
Allowed edits: scripts/provision.sh, Docs/changelog.md, version artifact, session log.
⛔ Do NOT: modify sensor_history_multi.h · modify firmware source or tests · use eval · make status mutating.
Validation: full pipeline (satellite + aggregator + wroom) · Playwright (4 fixture sets) · bash scripts/preflight.sh.
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md §v7.6.6.0.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md`
- `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md`
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §v7.6.6.0 subsection only
- `prompts/prompt-index-and-workflow.md` — only rules directly cited by the step

After completing Turn 1, proceed to Turn 2: open `scripts/provision.sh` and implement:
- `run_full_pipeline()` with the exact Phase Y step order and no `eval`
- `require_node()` and `require_npm_deps()` pre-checks
- `--dry-run` support for satellite, aggregator, and wroom modes
- Replace old workflow-print calls with actual pipeline execution where required
- Keep `status` non-mutating
- Preserve the Step 0 assembly placeholder as a printed skip/no-op until `v7.6.6.1`

Also update: operations lesson, version bump, changelog.

Then Turn 3: run validations and produce the compliance table.

## Inline context — review

```
Objective: Verify provision.sh pipeline automation matches the v7.6.6.0 contract.
Diff scope: scripts/provision.sh · changelog · lesson file · version/session-log artifacts.
⛔ Out of scope: firmware source · tests · sensor_history_multi.h.
Gates: pipeline order exact · assembly placeholder is no-op · --dry-run prints only · status non-mutating · no eval · pre-checks before pipeline · no out-of-scope changes.
Evidence needed: pipeline run output · preflight output · Playwright results.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md`
- `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md`
- Phase plan §v7.6.6.0 subsection only

**Turn 2 diff + evidence fetch:**
- PR diff for `scripts/provision.sh`, changelog, lesson file, version/session-log artifacts
- Agent session compliance table and validation logs from the PR description or comments

**Review gates to decide explicitly:**
- Pipeline order matches the step contract exactly
- Assembly placeholder is a printed skip/no-op, not an executed missing command
- `--dry-run` prints steps and makes no filesystem changes
- `status` does not call the pipeline
- No `eval` usage
- Pre-checks run before pipeline execution
- No out-of-scope changes

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.0-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`
- Review and update `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md`
- Apply version tag for `v7.6.6.0` if repo workflow requires it

---

# v7.6.6.1 — Establish assembly script and baseline

## Inline context — agent

```
Objective: Split sensor_history_multi.h into 8 fragments in firmware/core/ and create assemble-sensor-history.sh.
Allowed edits: firmware/core/ (new files only) · scripts/assemble-sensor-history.sh (new) · scripts/provision.sh (activate assembly step) · scripts/preflight.sh (fragment existence coverage) · Docs/changelog.md · version artifact · session log.
⛔ Do NOT: use split (use explicit line ranges) · modify YAML includes · redirect render_sensor_config.py to fragments · modify test files · modify sensor_history_multi.h content.
Validation: assemble-sensor-history.sh --check · --list · diff assembled vs concatenated · bash scripts/preflight.sh · esphome config · Playwright (4 fixture sets).
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md — fragment manifest, boundaries, §v7.6.6.1.
Key constraint: fragment line counts must sum to 4325 and direct concatenation must match the monolith.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`
- `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md`
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — fragment manifest, boundary section, and §v7.6.6.1 subsection only

After Turn 1, proceed to Turn 2:
- Verify monolith line count and baseline SHA before any split
- Extract the 8 fragments using explicit line ranges (no `split` command)
- Verify fragment line counts sum to 4325 and direct concatenation matches monolith
- Create `scripts/assemble-sensor-history.sh` with `--write`, `--check`, `--list`, and `--dry-run`
- Implement generator-aware `--check` behavior for generated marker regions
- Activate the assembly step in `provision.sh`
- Add fragment existence coverage in `preflight.sh`
- Bump version, update changelog

Turn 3: run all validations, produce compliance table.

**⚠️ Context warning:** Do NOT open `sensor_history_multi.h` in full. Read only the line count (`wc -l`) and specific boundary line ranges as needed. The file is ~18 000 tokens.

## Inline context — review

```
Objective: Verify 8 fragments exist, sum to 4325 lines, identity holds, assembly script is correct.
Diff scope: firmware/core/ (8 new .h files) · scripts/assemble-sensor-history.sh (new) · scripts/provision.sh · scripts/preflight.sh · changelog.
⛔ Out of scope: sensor_history_multi.h content changes · YAML · test files.
Gates: exactly 8 fragments · line counts sum to 4325 · concatenation identity holds · generator-aware --check · assembly step active · YAML unchanged · changes structural not behavioral.
Evidence needed: wc -l output · --check output · --list output · diff assembled vs concatenated.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`
- `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md`
- Phase plan fragment boundary section and §v7.6.6.1 only

**Turn 2 diff + evidence fetch:**
- PR diff for fragment files, assembly script, provision, preflight, changelog
- Agent compliance table and evidence logs from the PR description or comments

**Review gates to decide explicitly:**
- Exactly eight fragments exist
- Line counts sum to 4325
- Direct concatenation identity holds
- Generator-aware `--check` is implemented correctly
- Assembly step is active
- YAML stayed unchanged
- Changes are structural, not behavioral

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.1-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update the `v7.6.6.2` handoff and implementation-instructions artifacts
- Apply version tag for `v7.6.6.1` if repo workflow requires it

---

# v7.6.6.2 — Wire assembly into pipeline and fragment-level preflight

## Inline context — agent

```
Objective: Confirm assembly write step is active in canonical pipeline; add two new preflight checks.
Allowed edits: scripts/provision.sh · scripts/preflight.sh · Docs/changelog.md · version artifact · session log.
⛔ Do NOT: edit fragments · edit tests · add assembly --check after generator steps.
New preflight checks: firmware_core_assembly_check · firmware_core_fragment_line_sum.
Validation: full pipeline · bash scripts/preflight.sh · Playwright (4 fixture sets) · esphome config.
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md §v7.6.6.2 and §4.2 generator/assembly sync note.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`
- `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md`
- Phase plan §v7.6.6.2 subsection and §4.2 only

After Turn 1, proceed to Turn 2:
- Confirm the assembly write step is active in the canonical pipeline position (Step 0)
- Add `firmware_core_assembly_check` to preflight
- Add `firmware_core_fragment_line_sum` to preflight
- Keep assembly `--check` in preflight only — do NOT add it after generator steps
- Bump version, update changelog

Turn 3: run all validations, produce compliance table.

## Inline context — review

```
Objective: Verify two new preflight checks exist, assembly write is Step 0 in pipeline, no forbidden --check added.
Diff scope: scripts/provision.sh · scripts/preflight.sh · changelog · version/session log.
⛔ Out of scope: fragments · tests · any source files.
Gates: assembly write is Step 0 · two new preflight checks exist and pass · no fragment/test changes · no assembly --check after generator.
Evidence needed: preflight run output · pipeline run output.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`
- `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md`
- Phase plan §v7.6.6.2 and §4.2 only

**Turn 2 diff + evidence fetch:**
- PR diff for `provision.sh`, `preflight.sh`, changelog, version/session log
- Agent compliance table and preflight/pipeline logs

**Review gates to decide explicitly:**
- Assembly write is Step 0 in the pipeline
- Two new preflight checks exist and pass
- No fragment or test changes
- No forbidden `--check` step was added after generator

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.2-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update the `v7.6.6.3` handoff and implementation-instructions artifacts
- Apply version tag for `v7.6.6.2` if repo workflow requires it

---

# v7.6.6.3 — Fragment editing workflow validated

## Inline context — agent

```
Objective: Validate the fragment edit → assemble → verify → revert cycle. Produce documented four-stage evidence sequence.
Allowed edits: firmware/core/registration.h (transient blank-line add then revert) · firmware/core/config.h (transient deliberate break then revert). No permanent changes to any fragment.
⛔ Do NOT: leave permanent fragment changes · edit assembly/preflight/provision scripts · skip the deliberate-break test.
Required sequence: PASS baseline → CHANGE (add blank line to registration.h, reassemble, observe delta) → FAIL (break config.h without reassembling, verify --check fails) → PASS (revert both, verify identity restored).
Validation: identity gate before/after each transient change · full pipeline · Playwright · preflight.
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md §v7.6.6.3.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md`
- `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md`

After Turn 1, proceed to Turn 2:
- Record baseline SHA and passing `--check`
- Perform transient blank-line change in `registration.h`, reassemble, observe expected line-count delta
- Revert and verify baseline identity is restored
- Perform deliberate-break test in `config.h` without reassembling, verify `--check` fails
- Revert and restore passing state
- Document the PASS → CHANGE → FAIL → PASS sequence
- Run normal validation (no permanent changes to fragments)

Turn 3: verify final fragment total is 4325, produce compliance table.

## Inline context — review

```
Objective: Confirm no permanent fragment changes remain; four-stage validation sequence is evidenced.
Diff scope: changelog · version/session log only (firmware/core/ diff should be empty or revert-clean).
⛔ Out of scope: any lasting changes to firmware/core/ · assembly/preflight/provision scripts.
Gates: no permanent fragment changes · four-stage sequence evidenced · no unrelated script changes · final fragment total returns to 4325.
Evidence needed: SHA before/after · --check outputs at each stage · final wc -l total.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md`
- `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md`

**Turn 2 diff + evidence fetch:**
- PR diff (should show no lasting fragment changes)
- Agent compliance table with the four-stage sequence evidence

**Review gates to decide explicitly:**
- No permanent fragment changes remain
- The four-stage validation sequence is evidenced
- No unrelated scripts were changed
- Final fragment totals return to 4325

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.3-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update the `v7.6.6.4` handoff and implementation-instructions artifacts
- Apply version tag for `v7.6.6.3` if repo workflow requires it

---

# v7.6.6.4 — Ping adapter fragment validation

## Inline context — agent

```
Objective: Validate ping-adapter.h compile guard, class integrity, and no cross-fragment symbol leakage. No source edits.
Allowed changes: Docs/changelog.md · version artifact · session log only.
⛔ Do NOT: modify fragment content · make this a functional edit step · touch tests or YAML.
Validation: assemble-sensor-history.sh --check · wc -l firmware/core/ping-adapter.h · esphome config · Playwright.
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md §v7.6.6.4.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md`
- `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md`

After Turn 1, proceed to Turn 2:
- Read `firmware/core/ping-adapter.h` (this step requires reading the file to validate it — read it once only)
- Verify compile guard is the first line
- Verify there is exactly one PingAdapter class
- Verify no cross-fragment symbol leakage
- Verify line count and assembly identity
- Update changelog and bump version (no source changes)

Turn 3: run validations, produce compliance table.

## Inline context — review

```
Objective: Confirm no fragment changes; guard/class/symbol integrity evidenced.
Diff scope: changelog · version/session log only.
⛔ Out of scope: firmware/core/ · tests · YAML.
Gates: no fragment changes · compile guard is first line · exactly one PingAdapter class · no cross-fragment symbol leakage · identity gate evidence present.
Evidence needed: wc -l output · --check output · grep evidence for guard and class.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md`
- `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md`

**Turn 2 diff + evidence fetch:**
- PR diff (should contain changelog/version/session-log only)
- Agent compliance table with guard, class, and symbol evidence

**Review gates to decide explicitly:**
- No fragment changes
- Compile guard remains first line
- Exactly one PingAdapter class exists
- No cross-fragment symbol leakage

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.4-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update the `v7.6.6.5` handoff and implementation-instructions artifacts
- Apply version tag for `v7.6.6.4` if repo workflow requires it

---

# v7.6.6.5 — NVS persistence device test gate

## Inline context — agent

```
Objective: Flash committed C3 YAML, run NVS persistence device test, capture evidence. No source edits.
Allowed changes: device evidence artifacts · Docs/changelog.md · version artifact · session log.
⛔ Do NOT: modify source code · use JSON POST bodies · use generated YAML for the C3 step · continue if the blocking gate fails.
Blocking gate: reboot persistence must be verified; if it fails, stop and escalate — do NOT push ahead.
Validation: assembly identity · Playwright · device evidence table · blocking-gate verdict · Docs/lessons/firmware.md NVS-relevant lessons only.
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md §v7.6.6.5.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md`
- `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md`
- `Docs/lessons/firmware.md` — NVS-relevant sections only

After Turn 1, proceed to Turn 2:
- Run the satellite pipeline and flash the committed C3 YAML
- Capture boot and restore evidence
- Verify storage-stats, manifest/history, live, and status endpoints
- Verify reboot persistence using the required POST style (not JSON POST bodies)
- Observe hourly persist if available
- **If any device gate fails: STOP. Do not bump version or push. Report BLOCKED.**

Turn 3: produce evidence table and compliance table.

## Inline context — review

```
Objective: Confirm no source changes; device evidence credible; blocking gate verdict explicit.
Diff scope: evidence artifacts · changelog · version/session log only.
⛔ Out of scope: source code · YAML changes · test files.
Gates: no source code changes · correct board YAML and POST style · reboot persistence evidence credible · blocking gate is explicitly PASS or FAIL (not softened).
Evidence needed: boot logs · storage-stats JSON · history/live/status output · reboot before/after comparison.
Blocking rule: if device gate FAIL → verdict is BLOCKED; do not advance Phase Y.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md`
- `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md`
- NVS-related lessons/constraints only

**Turn 2 diff + evidence fetch:**
- PR diff (should be evidence-oriented, not source-edit oriented)
- Boot logs, storage-stats JSON, history/live/status output, reboot persistence comparison from PR description or attached evidence

**Review gates to decide explicitly:**
- No source code changes
- Correct board YAML and POST style were used
- Reboot persistence evidence is credible
- Blocking gate is clearly PASS or FAIL

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.5-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update the `v7.6.6.6` handoff and implementation-instructions artifacts
- If the blocking gate fails, state explicitly that Phase Y is blocked — do not advance the phase
- Apply version tag for `v7.6.6.5` only if the gate truly passed

---

# v7.6.6.6 — Aggregator runtime device test gate

## Inline context — agent

```
Objective: Run aggregator provisioning flow, flash generated S3 YAML, run aggregator device tests, restore satellite mode. No source edits.
Allowed changes: device evidence artifacts · Docs/changelog.md · version artifact · session log.
⛔ Do NOT: modify source code · use the committed C3 YAML for S3 · forget to switch back to satellite mode · continue if the blocking gate fails.
Blocking gate: all required aggregator endpoints + reboot persistence + satellite mode restoration.
Validation: assembly identity · Playwright · aggregator evidence table · blocking-gate verdict · satellite-mode restoration evidence.
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md §v7.6.6.6.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md`
- `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md`

After Turn 1, proceed to Turn 2:
- Run the aggregator provisioning flow and flash the generated S3 YAML
- Verify poll-task start and all required aggregator endpoints
- Verify add/delete/test/reset flows and config-generation behavior
- Verify reboot persistence for satellite configuration
- **Switch the repo back to satellite mode before finalizing**
- **If the blocking gate fails: STOP. Do not proceed.**

Turn 3: produce evidence table and compliance table. Confirm satellite mode restored.

## Inline context — review

```
Objective: Confirm no source changes; all aggregator mutation flows evidenced; mode restored; blocking gate explicit.
Diff scope: evidence artifacts · changelog · version/session log only.
⛔ Out of scope: source code · YAML changes · test files.
Gates: no source code changes · correct generated S3 YAML used · all mutation flows exercised · blocking gate PASS or FAIL · satellite mode restored.
Evidence needed: boot logs · gateways/live/proxy results · mutation endpoint results · reboot persistence · mode restore confirmation.
Blocking rule: if device gate FAIL → verdict is BLOCKED.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md`
- `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md`
- aggregator/deferred task constraints section only

**Turn 2 diff + evidence fetch:**
- PR diff (should show evidence + version/changelog/session log, not source changes)
- Boot logs, gateway/live/proxy results, mutation results, reboot persistence, mode restore confirmation

**Review gates to decide explicitly:**
- No source code changes
- Correct generated S3 YAML was used
- All required mutation flows were exercised
- Blocking gate is clearly PASS or FAIL
- Satellite mode was restored

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.6-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update the `v7.6.6.7` handoff and implementation-instructions artifacts
- If the blocking gate fails, state explicitly that Phase Y is blocked — do not advance the phase
- Apply version tag for `v7.6.6.6` only if the gate truly passed

---

# v7.6.6.7 — Full endpoint smoke test

## Inline context — agent

```
Objective: Validate all 21 endpoints across both board profiles; capture complete evidence table. No source edits.
Allowed changes: endpoint evidence table · Docs/changelog.md · version artifact · session log.
⛔ Do NOT: skip any endpoint · run delete-data before history checks · forget to restore satellite mode · use JSON POST bodies.
Validation: complete 21-endpoint evidence table · assembly identity · Playwright · both config validations (C3 + S3).
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md §v7.6.6.7 and endpoint inventory section only.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md`
- `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md`
- `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` — endpoint inventory section only

After Turn 1, proceed to Turn 2:
- Validate config for both board profiles before flashing
- Test all local satellite endpoints, including auth and import-management flows
- Test all aggregator endpoints on the S3 profile
- Maintain a running endpoint evidence table (all 21 rows populated before concluding)
- **Restore the repo to satellite mode before finalizing**

Turn 3: verify all 21 endpoints covered, produce compliance table.

## Inline context — review

```
Objective: Confirm all 21 endpoints explicitly covered; both board profiles validated; satellite mode restored.
Diff scope: evidence artifacts · changelog · version/session log only.
⛔ Out of scope: source code · YAML changes · test files.
Gates: all 21 endpoints covered · auth behavior demonstrated · both board profiles validated · correct board YAMLs and POST style · satellite mode restored.
Evidence needed: 21-endpoint table · config validation output for both boards · mode restore confirmation.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md`
- `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md`
- Endpoint inventory section only

**Turn 2 diff + evidence fetch:**
- PR diff centered on evidence artifacts and closure docs, not source changes
- 21-endpoint evidence table, auth behavior evidence, both board validation outputs, mode restoration confirmation

**Review gates to decide explicitly:**
- All 21 endpoints are explicitly covered
- Auth behavior is demonstrated
- Both board profiles were validated
- Correct board YAMLs and POST style were used
- Satellite mode was restored

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.7-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update the `v7.6.6.8` handoff and implementation-instructions artifacts
- Apply version tag for `v7.6.6.7` if repo workflow requires it

---

# v7.6.6.8 — Closure: preflight, documentation, critical rules

## Inline context — agent

```
Objective: Add 6 closure preflight checks, add Critical Rules 58–62 with exact plan wording, mark Phase Y complete in prompt index, document firmware/core/ in README and lessons, create phaseY-results.md.
Allowed edits: scripts/preflight.sh · README.md · Docs/lessons/firmware.md · Docs/lessons/build-pipeline.md · prompts/prompt-index-and-workflow.md · prompts/handoff/phaseY-results.md (new) · Docs/changelog.md · version artifact · session log.
⛔ Do NOT: modify fragment content · modify test files · paraphrase Critical Rules 58–62 (exact wording required) · change YAML.
Validation: all preflight checks pass · assembly identity · esphome config · Playwright · final prompt-index/Phase Y closure verification · exact wording check for Rules 58–62.
Phase Y plan section: Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md §v7.6.6.8 and exact rule wording.
Reference format: prompts/handoff/phaseD/phaseD-results.md.
```

## Step 1 — Agent prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`
- `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md`
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §v7.6.6.8 and exact rule wording sections only
- `prompts/handoff/phaseD/phaseD-results.md` — format reference only (read briefly, do not summarize)
- `prompts/prompt-index-and-workflow.md` — current structure only (to know where to insert Phase Y completion)

After Turn 1, proceed to Turn 2:
- Add the six closure preflight checks
- Add Critical Rules 58–62 with **exact** wording from the plan (do not paraphrase)
- Mark Phase Y complete in the prompt index and add the completion summary
- Document `firmware/core/` in README and lessons files
- Create `prompts/handoff/phaseY-results.md`
- Bump version, update changelog

Turn 3: run all validations, produce compliance table with final total preflight count.

## Inline context — review

```
Objective: Confirm all 6 preflight checks exist, Rules 58–62 match exact plan wording, Phase Y step table complete, results doc present.
Diff scope: scripts/preflight.sh · README.md · Docs/lessons/ · prompts/prompt-index-and-workflow.md · prompts/handoff/phaseY-results.md · changelog.
⛔ Out of scope: firmware/core/ content · test files · YAML.
Gates: 6 new preflight checks exist and wired · Rules 58–62 match plan wording exactly · Phase Y step table fully completed · results doc exists and complete · no fragment or test content changes.
Evidence needed: preflight run output with total count · exact wording comparison for Rules 58–62 · prompt-index Phase Y completion entry.
```

## Step 2 — Review prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Use the **Shared Perplexity session protocol** above.

**Turn 1 reads (do not open more than these):**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`
- `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md`
- Plan wording for closure checks and rules (§v7.6.6.8 only)
- Prompt-index snapshot requirements only

**Turn 2 diff + evidence fetch:**
- PR diff for preflight, README, lessons, prompt-index, results doc, changelog
- Agent compliance table with Rules 58–62 wording verification and preflight count

**Review gates to decide explicitly:**
- All six preflight checks exist and are wired
- Rules 58–62 match plan wording exactly
- Phase Y step table is fully completed
- Results doc exists and is complete
- No fragment or test content changes occurred

**Post-merge deliverables when merge-ready:**
- Create `prompts/phaseY/v7.6.6.8-PR<NN>-consolidated-audit-and-lessons.md`
- Confirm the final Phase Y completion summary
- Confirm that all nine steps shipped, the results document exists, the six preflight checks pass, and Rules 58–62 were added exactly
- Apply version tag for `v7.6.6.8` if repo workflow requires it

---

## Token budget reference

The table below summarises estimated context usage per step for these prompts compared to the original Claude Code prompts.

| Step | PR Agent (orig) | PR Agent (this) | PR Review (orig) | PR Review (this) |
|------|-----------------|-----------------|------------------|------------------|
| v7.6.6.0 | ~65 000 | ~8 000 | ~55 000 | ~6 000 |
| v7.6.6.1 | ~80 000 | ~10 000 | ~65 000 | ~7 500 |
| v7.6.6.2 | ~55 000 | ~6 500 | ~50 000 | ~5 500 |
| v7.6.6.3 | ~55 000 | ~6 000 | ~50 000 | ~5 000 |
| v7.6.6.4 | ~55 000 | ~5 500 | ~48 000 | ~4 500 |
| v7.6.6.5 | ~65 000 | ~7 000 | ~55 000 | ~5 500 |
| v7.6.6.6 | ~65 000 | ~7 000 | ~55 000 | ~5 500 |
| v7.6.6.7 | ~60 000 | ~7 000 | ~52 000 | ~5 500 |
| v7.6.6.8 | ~70 000 | ~9 000 | ~60 000 | ~7 000 |
| **Total** | **~570 000** | **~66 000** | **~490 000** | **~52 000** |
| **Savings** | | **−88 %** | | **−89 %** |

Savings come from: (1) inline context headers replacing full file reads, (2) deferred targeted reads replacing bulk upfront file lists, (3) no sub-agent pattern (no coordinator overhead), (4) table-first output replacing prose session logs.

Quality is preserved because: constraints are front-loaded in high-attention positions, gate checklists are explicit and complete, and the three-turn session structure ensures the implementation plan is reviewed before any edit is made.

---

_End of Phase Y Perplexity-optimized two-session prompts._
