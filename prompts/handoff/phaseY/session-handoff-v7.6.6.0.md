# Session Handoff — v7.6.6.0: Pre-Step — `provision.sh` Full Pipeline Automation

_Date: 2026-04-08_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: Phase X COMPLETE (v7.6.5.8 merged). Phase Y prompt package produced. Entering Phase Y execution._

---

## Project State Summary

**Phase X is complete.** The dashboard monolith has been refactored into a modular component architecture with a three-pass build pipeline. All 402 Playwright tests pass. `main` is at v7.6.5.8.

**Phase Y begins now.** The target is `dashboard/sensor_history_multi.h` — a 4,325-line firmware monolith that will be split into 8 fragment source files in `firmware/core/`, assembled by a new `scripts/assemble-sensor-history.sh` script.

This pre-step (v7.6.6.0) does NOT touch `sensor_history_multi.h`. It automates the `provision.sh` pipeline so that all regeneration steps run automatically on board switch, instead of requiring 8 manual commands.

---

## Phase Y Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| **v7.6.6.0** | **Pre-step: provision.sh full pipeline automation** | **⬅️ Current** |
| v7.6.6.1 | Establish assembly script + 8 fragments + SHA-256 baseline | Pending |
| v7.6.6.2 | Wire assembly into pipeline + fragment-level preflight | Pending |
| v7.6.6.3 | Validate edit-fragment workflow end-to-end | Pending |
| v7.6.6.4 | Ping adapter fragment validation | Pending |
| v7.6.6.5 | Device test gate: NVS persistence on C3 | Pending |
| v7.6.6.6 | Device test gate: aggregator runtime on S3 | Pending |
| v7.6.6.7 | Full endpoint smoke test (all 21 handlers) | Pending |
| v7.6.6.8 | Closure: preflight + docs + Critical Rules 58–62 | Pending |

---

## v7.6.6.0 Scope

Automate the full 8-step regeneration pipeline inside `provision.sh` so that switching board configurations runs all steps automatically.

### What this step does

1. Add a `run_full_pipeline()` function to `scripts/provision.sh`
2. Add `--dry-run` support to all board modes
3. Add dependency pre-checks (`require_node`, `require_npm_deps`)
4. Include a placeholder (no-op comment) for the assembly step that v7.6.6.1 will activate
5. Replace `print_workflow()` manual step listing with actual `run_full_pipeline()` execution
6. Preserve `status` as non-mutating

### What this step does NOT do

- No changes to `sensor_history_multi.h`
- No creation of `firmware/core/` or fragment files
- No creation of `assemble-sensor-history.sh`
- No changes to test files or build scripts (other than `provision.sh`)
- No firmware behavior changes

### Acceptance criteria

- [ ] `bash scripts/provision.sh satellite` runs all 8 active pipeline steps automatically
- [ ] `bash scripts/provision.sh aggregator` and `wroom` do the same
- [ ] `bash scripts/provision.sh satellite --dry-run` prints all steps without executing
- [ ] `status` remains non-mutating
- [ ] Step 0 placeholder for assembly script is present (no-op comment until v7.6.6.1)
- [ ] CI-safe satellite mode warning preserved
- [ ] `bash scripts/preflight.sh` passes
- [ ] No firmware/runtime behavior changes

---

## Pre-merge Checklist for v7.6.6.0

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] After implementation, verify `--dry-run` prints all steps correctly
- [ ] Verify `status` does not run any pipeline steps
- [ ] Verify aggregator and wroom modes both run the full pipeline
- [ ] Verify the assembly step placeholder is a no-op comment (not an error)
- [ ] No changes to any file except `scripts/provision.sh`, `Docs/changelog.md`, and `Docs/lessons/operations.md`

---

## Critical Rules Relevant to v7.6.6.0

| # | Rule | Why Relevant |
|---|------|-------------|
| 4 | Preflight must pass | Validates state after pipeline changes |
| 5 | CI-exact `FIXTURE_SET=` runs | Full acceptance gate |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 37 | Full regeneration pipeline | This step automates the pipeline |
| 49 | provision.sh is mandatory entry point | This step enhances provision.sh |

---

## Risk: Low

Tooling-only change to `provision.sh`. No firmware code changes, no test changes. Main risk is pipeline step ordering error — caught by `preflight.sh` and `render_sensor_config.py --check`.

---

## Workflow for v7.6.6.0

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for this step is open. If PR has not been opened, **open a NEW coding agent session outside of this chat** and paste the prompt
3. Agent modifies `scripts/provision.sh` per the implementation prompt
4. Agent runs all pipeline modes and verifies
5. Review the PR — verify pipeline ordering, `--dry-run` output, `status` non-mutation
6. Merge, tag `v7.6.6.0`
7. Produce consolidated audit (see Post-PR Closure section below)
8. Check and update session handoff for v7.6.6.1 if necessary
9. Check and update agent's prompt for v7.6.6.1 if necessary

---

## Post-PR Closure Deliverables for v7.6.6.0

### 1. Consolidated Audit

**File:** `prompts/phaseY/v7.6.6.0-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseY/pr-audit-question-template-phaseY.md`
**Format:** Same structure as Phase X audit documents

Use stable core. Step-specific supplement:
- Does `--dry-run` print all 8 pipeline steps plus the assembly placeholder?
- Does `status` remain non-mutating (no pipeline execution)?
- Is the assembly step placeholder a no-op comment, not a missing command?

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md` — verify the v7.6.6.1 scope still matches after seeing the actual `provision.sh` changes
- `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md` — verify the pipeline references and `provision.sh` integration points are accurate

---

## Device Testing

**Not applicable.** No firmware changes. Tooling automation only.

---

_End of session handoff document._
