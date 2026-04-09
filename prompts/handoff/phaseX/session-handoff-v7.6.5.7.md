# Session Handoff — v7.6.5.7: Test Spec Split (Phase X Test/Closure)

_Date: 2026-04-05_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.5.6 COMPLETE. Level 3 done — component model fully operational with JS, HTML templates, and CSS per component. Three-pass build verified. Visual regression clean. Entering test infrastructure._

---

## Project State Summary

**v7.6.5.6 is complete.** The component model is fully operational:

```
dashboard/
  core/         10 JS files + base.css
  components/   8 directories, each with index.js + template.html + styles.css
  dashboard.tmpl.html  ← shell with {{CSS_PLACEHOLDER}} + {{COMPONENT:*}} + {{JS_PLACEHOLDER}}
  dashboard.js         ← GENERATED bundle
  dashboard.html       ← GENERATED (three-pass: CSS → templates → JS)
  dashboard.h          ← committed gzip C header
```

Three-pass assembly produces output identical to the original monolith structure. All 402 tests pass. Visual regression confirmed clean. `main` is green.

### Level 3 → Test/Closure gate condition: PASSED

- Three-pass assembly stable ✓
- Visual regression clean ✓
- All tests green ✓

---

## Phase X Progress Table

| Version | Scope | Level | Status |
|---------|-------|-------|--------|
| v7.6.4.0 | Documentation restructuring | Pre-step | ✅ Complete |
| v7.6.5.0–v7.6.5.1 | Module split + CI wiring | Level 1 | ✅ Complete |
| v7.6.5.2–v7.6.5.3 | Template creation + mirror retirement | Level 2 | ✅ Complete |
| v7.6.5.4–v7.6.5.6 | Component model (dirs, HTML, CSS) | Level 3 | ✅ Complete |
| **v7.6.5.7** | **Test spec split** | **Test/Closure** | **⬅️ Next** |
| v7.6.5.8 | Phase X closure | Test/Closure | Pending |

---

## v7.6.5.7 Scope

Split the 1,853-line `tests/browser/dashboard.spec.js` monolith into domain-scoped test files that mirror the component structure. All test counts must remain unchanged: 402 pass / 0 fail.

### What this step does

1. Extract shared test helpers (e.g., `loadDashboard()`, fixture detection, skip guards) into `tests/browser/test-helpers.js`.
2. Split test groups into focused test files by domain.
3. Each domain test file imports shared helpers from `test-helpers.js`.
4. Verify total test count unchanged: 402/0 across all four fixture sets.
5. Verify each test file runs independently.

### Proposed test file structure (from plan §6 v7.6.5.7)

| Test file | Groups | Approx lines |
|------------|--------|-------------|
| `boot-structure.spec.js` | 1–3 | ~80 |
| `sensor-cards.spec.js` | 2, 11, 17, 18 | ~200 |
| `history-charts.spec.js` | 4, 5, 13, 16 | ~300 |
| `theme-export.spec.js` | 6, 7, 8 | ~80 |
| `metric-formatters.spec.js` | 12 | ~60 |
| `regression.spec.js` | 14, 15 | ~200 |
| `aggregator.spec.js` | 19 | ~130 |
| `system-devices.spec.js` | 20 | ~60 |
| `satellite-management.spec.js` | 21 | ~210 |
| `test-helpers.js` | Shared setup | ~100 |

**Important:** These are starting-point assignments. The agent must read the actual test file and adjust group-to-file mapping if a `test.describe` block logically belongs with a different domain or if groups overlap. The golden rule is: every test appears exactly once, total count is 402.

### Acceptance criteria

- [ ] All test groups exist in domain-scoped files
- [ ] Total test count unchanged: 402 pass / 0 fail across all four fixture sets
- [ ] Shared test helpers extracted into `test-helpers.js`
- [ ] Each test file loadable independently
- [ ] Preflight passes
- [ ] No dashboard source or build script changes

---

## Pre-merge Checklist for v7.6.5.7

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] Record pre-split test counts (per fixture set) for comparison
- [ ] After split, verify post-split counts match exactly
- [ ] Verify each domain test file runs independently: `FIXTURE_SET=3sensor npx playwright test tests/browser/<file> --project=chromium`
- [ ] Verify Playwright discovers all `*.spec.js` files (check `playwright.config.js` `testMatch`)
- [ ] Verify no skip guards were lost during split
- [ ] No dashboard source code changes

---

## Critical Rules Relevant to v7.6.5.7

| # | Rule | Why Relevant |
|---|------|-------------|
| 5 | CI-exact `FIXTURE_SET=` runs | Must verify all fixture sets |
| 18 | Fixture/matrix changes require audit | Test structure change |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 32 | Test signatures only destructure used fixtures | Applies to all moved tests |

---

## Risk: Low

Test file splitting is mechanical. The main risks are:
- **Lost tests.** A group accidentally omitted. Caught by count comparison.
- **Duplicate tests.** A group included in two files. Caught by count comparison (would show >402).
- **Broken imports.** `test-helpers.js` not imported correctly. Caught by running each file independently.
- **Missing skip guards.** An aggregator-only test group loses its `test.skip` guard. Caught by running non-aggregator fixture sets.

---

## Workflow for v7.6.5.7

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR
> for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for
> clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for this step is open. If PR has not been open, **open a NEW coding agent session outside of this chat** and paste the prompt
3. Agent reads the full test file, identifies group boundaries
4. Agent extracts helpers, splits groups into domain files
5. Agent verifies counts match and each file runs independently
6. Review the PR — verify group assignments, count match
7. Merge, tag `v7.6.5.7`
8. Produce consolidated audit and lessons file (see Post-PR Closure section below)
9. Check and update session handoff for v7.6.5.8 if necessary (see Post-PR Closure section below)
10. Check and update agent's prompt for v7.6.5.8 if necessary (see Post-PR Closure section below)
---

## Post-PR Closure Deliverables for v7.6.5.7

### 1. Consolidated Audit

**File:** `prompts/phaseX/v7.6.5.7-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseX/pr-audit-question-template.md`
**Format:** Same structure as `prompts/phaseX/v7.6.4.0-PR131-consolidated-audit-and-lessons.md`

Use stable core + Test/Closure supplement:
- Is the total test count unchanged (402/0)?
- Can each test file run independently?
- Were any skip guards lost during split?

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/session-handoff-v7.6.5.8.md` — verify the closure step's scope still matches reality. If the test split revealed any issues or required unexpected changes, update the handoff. Update if the test file structure or component names differ from what those assume (especially the preflight component-existence check list in v7.6.5.8)
- `prompts/phaseX/v7.6.5.8-implementation-instructions-for-coding-agent.md` — verify the preflight component-existence check list matches the delivered file structure. Update any stale file paths or component names. Verify the proposed new critical rules (47–48) still make sense given the delivered architecture. Update if the test file structure or component names differ from what those assume (especially the preflight component-existence check list in v7.6.5.8)

---

## Device Testing

**Not applicable.** No dashboard or firmware changes. Test infrastructure only.

---

_End of session handoff document._
