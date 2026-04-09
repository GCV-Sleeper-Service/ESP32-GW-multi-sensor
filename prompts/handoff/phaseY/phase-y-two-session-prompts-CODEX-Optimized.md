# Phase Y — Two-Session Prompts (CODEX Optimized with sub/agents-worker)

_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_  
_Date: 2026-04-09_

## Why this version is optimized for Codex

This version is designed for Codex-style execution where you can delegate heavy reading/checking to `sub/agents-worker` and keep the main session focused on decisions + edits.

### Core execution pattern (use for every step)

1. **Worker A — Context Scout**
   - Inputs: step handoff + implementation file.
   - Output: 1-page brief with exact requirements, Do-NOT constraints, and required files.
2. **Worker B — Evidence Runner**
   - Inputs: changed files, relevant scripts/tests.
   - Output: PASS/FAIL/UNCLEAR gate table with command evidence.
3. **Main session — Implement/Synthesize**
   - Apply only required edits.
   - Run only required checks.
   - Produce changelog/session artifacts.

### Mandatory anti-context-bloat rules

- Do **not** inline full files in chat.
- Do **not** re-read large docs if Worker A already summarized them.
- Pull only targeted line ranges when evidence is ambiguous.
- Keep reviewer output to structured tables (no long prose).

---

## v7.6.6.0 — Pre-Step: `provision.sh` Full Pipeline Automation

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** Read only:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md`
- `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md`
- Sections needed from:
  - `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` (v7.6.6.0 contract)
  - `prompts/prompt-index-and-workflow.md` (Rules 37, 49)
Return: required changes, strict constraints, validation checklist.

**Main-session implementation goals:**
1. Add `run_full_pipeline()` in `scripts/provision.sh` with exact required order.
2. Add dependency checks (`require_node`, `require_npm_deps`) before execution.
3. Add `--dry-run` behavior across board modes.
4. Replace `print_workflow()` callsites with `run_full_pipeline()`.
5. Add Step 0 assembly placeholder (no-op for this step).
6. Keep `status` non-mutating.
7. Add LESSON-OPS entry, version bump, changelog/session-log updates.
8. Run required validation set from Worker A checklist.

**Do NOT:** modify firmware/tests/`sensor_history_multi.h`; use `eval`; make `status` mutating.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** For PR `#<PR_NUMBER>`, verify gates for:
- pipeline order; Step 0 placeholder behavior; `--dry-run`; non-mutating `status`; no `eval`; dependency pre-checks; failure messaging; CI-safe warning; all board modes; out-of-scope file changes; validation evidence.
- Parse all review comments and map findings to fix commits.

Return: table `gate | pass/fail/unclear | evidence(file:line or command) | action`.

**Main-session synthesis:**
- Post compact PR comment: gate table + warranted/unwarranted review findings + remaining fixes.
- If needed, generate fix-only prompt.
- After merge, generate required consolidated audit + next-step handoff/instruction updates.

---

## v7.6.6.1 — Establish Assembly Script and Baseline

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** Read handoff/instructions for v7.6.6.1 and extract exact fragment boundaries + assembly script contract.

**Main-session implementation goals:**
1. Create `firmware/core/` and extract 8 fragments using explicit `sed -n` ranges.
2. Verify line-sum and byte/semantic identity checks required by plan.
3. Implement `scripts/assemble-sensor-history.sh` (`--write --check --list --dry-run`) with generator-aware check behavior.
4. Activate assembly in `provision.sh`; add preflight fragment-existence check.
5. Version bump, changelog/session log, required validation.

**Do NOT:** use `split`; modify source monolith content; alter YAML includes; redirect generator inputs.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** For PR `#<PR_NUMBER>`, verify gates for 8 fragments, line totals, identity checks, `--list`, generator-aware `--check`, boundary landmarks, pipeline activation, preflight update, YAML invariants, module order, extraction method, tests/log/changelog.

Return structured PASS/FAIL table and reviewer-comment disposition mapping.

**Main-session synthesis:** post PR review summary, create fix prompt if needed, and post-merge deliverables.

---

## v7.6.6.2 — Wire Assembly into Pipeline and Fragment-Level Preflight

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** Extract required deltas from v7.6.6.2 handoff/instructions.

**Main-session implementation goals:**
1. Confirm assembly step is active in pipeline.
2. Add `firmware_core_assembly_check` in `scripts/preflight.sh` calling `assemble-sensor-history.sh --check`.
3. Add `firmware_core_fragment_line_sum` check.
4. Version/changelog/session-log updates and required validation.

**Do NOT:** modify fragments, assembly script, tests; add assembly `--check` as post-generator pipeline step.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** Verify pipeline Step 0 assembly, both new preflight checks + evidence, absence of post-generator pipeline `--check`, and no forbidden file changes.

Return compact gate table with evidence.

**Main-session synthesis:** PR comment + fix prompt (if needed) + post-merge deliverables.

---

## v7.6.6.3 — Fragment Editing Workflow Validated

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** Extract exact validation cycle requirements for PASS→CHANGE→FAIL→PASS sequence.

**Main-session implementation goals:** execute/document required 4-part workflow without leaving permanent fragment changes; run required validations; update version/changelog/session log.

**Do NOT:** modify assembly/preflight/provision logic for this step.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** verify zero persistent fragment changes, documented 4-step evidence sequence, unchanged fragment total, and required test evidence.

Return gate table + reviewer finding disposition.

**Main-session synthesis:** PR comment + optional fix prompt + post-merge deliverables.

---

## v7.6.6.4 — Ping Adapter Fragment Validation

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** summarize v7.6.6.4 required ping-adapter fragment edits, invariants, and validation requirements.

**Main-session goals:** implement only approved ping-adapter scope in fragment workflow, run required checks, produce version/changelog/session-log artifacts.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** verify only intended ping-adapter fragment scope changed; identity/assembly/preflight invariants preserved; required tests and logs present.

Return gate table + outstanding actions.

---

## v7.6.6.5 — NVS Persistence Device Test Gate (BLOCKING)

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** summarize blocking-device-gate requirements, evidence format, and pass/fail criteria for v7.6.6.5.

**Main-session goals:** execute implementation and device-test evidence collection exactly as required; keep non-scope files untouched; update artifacts.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** validate blocking gate criteria and evidence quality; classify findings as merge-blocking or follow-up.

Return gate table with explicit blocker column.

---

## v7.6.6.6 — Aggregator Runtime Device Test Gate (BLOCKING)

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** summarize runtime-gate requirements, required telemetry/log proof, and constraints.

**Main-session goals:** implement required runtime path changes, gather required device-test evidence, update artifacts.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** validate runtime blocking gates, evidence completeness, and no out-of-scope regressions.

Return gate table + blocker decisions.

---

## v7.6.6.7 — Full Endpoint Smoke Test

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** summarize endpoint smoke-test scope and expected evidence.

**Main-session goals:** execute smoke suite and required code/doc updates; capture reproducible command evidence and update artifacts.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** validate endpoint coverage, pass/fail outcomes, and artifact completeness.

Return gate table + any residual risks.

---

## v7.6.6.8 — Closure: Preflight, Documentation, Critical Rules

### Step 1 — Agent Prompt (Codex)

Use `sub/agents-worker` first.

**Worker A task:** read v7.6.6.8 handoff/instructions and produce exact closure checklist for docs, rule updates, and phase table alignment.

**Main-session goals:** complete closure edits, final consistency checks, and required release artifacts.

### Step 2 — Review Prompt (Codex)

Use `sub/agents-worker`.

**Worker B task:** verify closure checklist completion, prompt-index consistency, critical-rule updates, and final phase alignment.

Return final gate table and readiness verdict.

---

## Reusable placeholders

- `<PR_NUMBER>`
- `<PASTE_REVIEW_URL_1..N>`
- `<LAST_FIX_COMMIT>`
- `<SESSION_LOG_PATH>`
- `<AUDIT_DOC_PATH>`

