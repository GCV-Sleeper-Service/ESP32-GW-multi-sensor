# Session Handoff — v7.6.5.1: Wire Bundle into CI and Preflight (Phase X Level 1)

_Date: 2026-04-05_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.5.0 COMPLETE. 21 source modules under `dashboard/src/`, `bundle-dashboard.sh` operational, identity gate confirmed. Entering CI integration._

---

## Project State Summary

**v7.6.5.0 is complete.** The 3,955-line `dashboard.js` monolith has been split into 21 ordered source modules under `dashboard/src/`. `bundle-dashboard.sh` concatenates them back into a byte-identical `dashboard.js`. `main` is green, 402/0 tests.

### What v7.6.5.0 delivered

- 21 module files in `dashboard/src/` (contiguous slices of the original monolith)
- `scripts/bundle-dashboard.sh` with `--write` and `--check` modes
- Identity gate confirmed: SHA-256 of bundled output matches pre-split original
- No behavior changes — dashboard functionality identical
- `dashboard.html` unchanged (still manually maintained at Level 1)

### What v7.6.5.0 did NOT deliver

- No CI integration of the bundle check (that's this step)
- No preflight check for bundle sync (that's this step)
- No pipeline documentation update (that's this step)

---

## Phase X Progress Table

| Version | Scope | Level | Status |
|---------|-------|-------|--------|
| v7.6.4.0 | Documentation restructuring | Pre-step | ✅ Complete |
| v7.6.5.0 | Module split: 21 source modules | Level 1 | ✅ Complete |
| **v7.6.5.1** | **Wire bundle into CI and preflight** | **Level 1** | **⬅️ Next** |
| v7.6.5.2 | Create dashboard.tmpl.html and build-dashboard.sh | Level 2 | Pending |
| v7.6.5.3 | Retire manual mirror | Level 2 | Pending |
| v7.6.5.4–v7.6.5.6 | Component model (Level 3) | Level 3 | Pending |
| v7.6.5.7–v7.6.5.8 | Test split + closure | Test/Closure | Pending |

---

## v7.6.5.1 Scope

**This is a small step.** Three changes:

1. Add `dashboard_js_bundle_sync` check to `scripts/preflight.sh` — runs `bundle-dashboard.sh --check` and reports pass/fail.
2. Add `bash scripts/bundle-dashboard.sh --check` step to `.github/workflows/browser-tests.yml` — before Playwright, after existing preflight steps.
3. Update regeneration pipeline documentation — LESSON-OPS-091 in `Docs/lessons/build-pipeline.md` and `Docs/aggregator-setup.md` to include the bundle step.

The canonical pipeline after this step:

```
1. bash scripts/bundle-dashboard.sh --write          ← NEW, run first
2. python3 scripts/render_sensor_config.py --write   ← inject version + markers after bundle
3. node tests/fixtures/generate-fixtures.js
4. bash scripts/minify-dashboard.sh
5. bash scripts/generate-header.sh
6. python3 scripts/render_sensor_config.py --check
```

Running the bundler first avoids wiping generator markers; the generator runs once immediately after bundling.

### Acceptance criteria

- [ ] CI workflow includes bundle check before Playwright
- [ ] `dashboard_js_bundle_sync` preflight check passes on clean tree
- [ ] Editing a module without rebundling → preflight FAIL (verified with negative test)
- [ ] All 402 tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes

---

## Pre-merge Checklist for v7.6.5.1

- [ ] Read the coding agent prompt completely (`prompts/phaseX/v7.6.5.1-implementation-instructions-for-coding-agent.md`)
- [ ] Read this handoff completely
- [ ] Verify the new preflight check works on a clean tree
- [ ] Verify the negative case: edit a module, run preflight, confirm it fails
- [ ] Review CI workflow change — bundle check positioned correctly
- [ ] Run CI-exact Playwright commands across all fixture sets
- [ ] Confirm no source module files were modified
- [ ] Confirm `dashboard.html` unchanged

---

## Critical Rules Relevant to v7.6.5.1

| # | Rule | Why Relevant |
|---|------|-------------|
| 4 | Preflight must pass | Adding a new preflight check |
| 5 | CI-exact `FIXTURE_SET=` runs | Full acceptance gate |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 37 | Full regeneration pipeline | Updating pipeline documentation to include bundle step |

---

## Workflow for v7.6.5.1

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR
> for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for
> clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for this step. If PR has not been open, **open a NEW coding agent session outside of this chat** and paste the prompt
3. Agent adds preflight check, CI step, updates pipeline docs
4. Review the PR — small diff, verify CI positioning, check automatically posted reviews and additional external reviews that might be posted
5. Merge, tag `v7.6.5.1`
6. Produce consolidated audit and lessons file (see Post-PR Closure section below)
7. Check and update session handoff for v7.6.5.2 if necessary (see Post-PR Closure section below)
8. Check and update agent's prompt for v7.6.5.2 if necessary (see Post-PR Closure section below)

---

## Post-PR Closure Deliverables for v7.6.5.1

### 1. Consolidated Audit

**File:** `prompts/phaseX/v7.6.5.1-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseX/pr-audit-question-template.md`
**Format:** Same structure as `prompts/phaseX/v7.6.4.0-PR131-consolidated-audit-and-lessons.md`

Use stable core questions from `prompts/phaseX/pr-audit-question-template.md`  plus Level-Specific Supplements for Level 1:
- Did the identity gate pass (SHA-256 before = after)?
- Were all modules contiguous file slices with no function reordering?
- Did the agent introduce any behavioral changes?

### 2. Gate Check: Level 1 → Level 2

After v7.6.5.1 merges, verify the Level 1 → Level 2 gate condition: CI green, preflight passes, bundle identity confirmed. If all pass, Level 2 (v7.6.5.2) can proceed.

### 3. Session Handoff for v7.6.5.2

**File:** `prompts/handoff/session-handoff-v7.6.5.2.md` update if CI workflow positioning differs from what the next prompt assumes. Provide a patch for future step handoff files if necessary.  

### 4. Check Agent's prompt for v7.6.5.2

**File:** `prompts/phaseX/v7.6.5.2-implementation-instructions-for-coding-agent.md` is already produced, update if CI workflow positioning differs from what the next prompt assumes.  


---

## Device Testing

**Not applicable.** v7.6.5.1 is CI/tooling only. No runtime changes.

---

_End of session handoff document._
