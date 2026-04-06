# Session Handoff — v7.6.5.0: Module Split (Phase X Level 1 — The Hard Step)

_Date: 2026-04-05_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.4.0 COMPLETE. Documentation restructured into domain-scoped files. Entering Level 1._

---

## Project State Summary

**v7.6.4.0 is complete.** Documentation has been split into domain-scoped files under `Docs/lessons/` and `Docs/writing-guide/`. `main` is green, 402/0 tests across all four fixture sets. No code changes since Phase D.

### Cumulative state entering v7.6.5.0

| Phase | Version Range | Status |
|-------|--------------|--------|
| Phase 1–6 | v7.5.0.x–v7.5.6.x | ✅ Complete |
| v7.5.7.0 | Bridge step | ✅ Complete |
| Phase D | v7.6.0.0–v7.6.0.5 | ✅ Complete |
| v7.6.4.0 | Documentation restructuring | ✅ Complete |
| **v7.6.5.0** | **Module split: 21 source modules** | **⬅️ This session** |
| v7.6.5.1–v7.6.5.8 | Remaining Phase X steps | Pending |

---

## Phase X Progress Table

| Version | Scope | Level | Status |
|---------|-------|-------|--------|
| v7.6.4.0 | Documentation restructuring | Pre-step | ✅ Complete |
| **v7.6.5.0** | **Module split: 21 source modules from monolith** | **Level 1** | **⬅️ Next** |
| v7.6.5.1 | Wire bundle into CI and preflight | Level 1 | Pending |
| v7.6.5.2 | Create dashboard.tmpl.html and build-dashboard.sh | Level 2 | Pending |
| v7.6.5.3 | Retire manual HTML mirror | Level 2 | Pending |
| v7.6.5.4 | Component directory scaffolding | Level 3 | Pending |
| v7.6.5.5 | Component HTML template extraction | Level 3 | Pending |
| v7.6.5.6 | Component CSS extraction | Level 3 | Pending |
| v7.6.5.7 | Test spec split | Test/Closure | Pending |
| v7.6.5.8 | Phase X closure | Test/Closure | Pending |

---

## v7.6.5.0 Scope — The Critical Module Split

**This is the hardest step in Phase X.** Split the 3,955-line `dashboard.js` monolith into 21 ordered source modules under `dashboard/src/`. Introduce `bundle-dashboard.sh`. The assembled `dashboard.js` must be content-identical to the pre-split monolith.

### Key design decisions

1. **Module order = file order.** Each module is a contiguous slice of the original `dashboard.js`. Concatenation order (00→20) reproduces the original file exactly.
2. **No function reordering.** Functions stay where they physically sit in the monolith. Some groupings may look unexpected (e.g., `buildSingleSensorCsv` in `03-history-fetch.js` not `09-export.js`) because the identity gate demands it.
3. **Generator markers live in `02-sensor-defs.js`.** The `SENSOR_MANIFEST:DEFAULT_SENSOR_META` block at lines 196–202 falls in the sensor definitions section.

### Module boundary table (verified at HEAD `98276b1`)

| Module | Approx lines | First function/var | Last function/var |
|--------|-------------|-------------------|------------------|
| `00-app-shell.js` | ~71 | `var App = ...` | `logNonFatal()` |
| `01-config-state.js` | ~119 | `var FILE_FALLBACK_HOST` | `App.State IIFE` |
| `02-sensor-defs.js` | ~178 | `var SENSOR_COLORS` | `formatMetricValue()` |
| `03-history-fetch.js` | ~216 | `parseHistoryMetricLines()` | `currentExportDateTag()` |
| `04-manifest.js` | ~151 | `makeSensorConfig()` | `autoPromoteV1ToV2()` |
| `05-status-snapshot.js` | ~65 | `var TELEMETRY_IDS` | `loadStatusSnapshot()` |
| `06-ui-helpers.js` | ~248 | `esc()` | `bindEvents()` |
| `07-staleness-derived.js` | ~121 | `calcDewPoint()` | `setMinMaxPeriod()` |
| `08-custom-range.js` | ~329 | `var CustomRange = (function()` | CustomRange IIFE end |
| `09-export.js` | ~64 | `exportSensorCSV()` | `resetHistoryVisuals()` |
| `10-storage-stats.js` | ~100 | `applyStorageStats()` | polling interval vars |
| `11-suspend-resume.js` | ~86 | `isImportActive()` | `isTransientImportError()` |
| `12-management.js` | ~168 | `importFetchJsonWithRetry()` | `deleteHistoryData()` |
| `13-import.js` | ~426 | `importHistoryData()` | `executeImport()` |
| `14-cards.js` | ~270 | `updateBadge()` | `buildExportButtons()` |
| `15-minmax.js` | ~52 | `updateMinMax()` | `updateMinMax()` end |
| `16-charts.js` | ~200 | `var FREEZING_LINE_PLUGIN` | `initCharts()` |
| `17-live-updates.js` | ~156 | `updateBattery()` | `loadHistory()` |
| `18-transport.js` | ~276 | `handleState()` | App module exports block |
| `19-aggregator.js` | ~508 | `detectAggregatorMode()` | `pollAggregatorLive()` |
| `20-boot.js` | ~134 | `updateBoardInfo()` | `DOMContentLoaded` |

### `bundle-dashboard.sh` contract

The script concatenates `dashboard/src/*.js` in the explicit MODULES order → `dashboard/dashboard.js`. Supports `--write` and `--check` modes. Output must be byte-for-byte identical to the current monolith. See Phase X plan §6 v7.6.5.0 for the full script.

### Identity gate

```bash
SHA_BEFORE=$(sha256sum dashboard/dashboard.js | cut -d' ' -f1)
bash scripts/bundle-dashboard.sh --write
SHA_AFTER=$(sha256sum dashboard/dashboard.js | cut -d' ' -f1)
[[ "$SHA_BEFORE" == "$SHA_AFTER" ]] || { echo "IDENTITY GATE FAILED"; exit 1; }
```

---

## Pre-merge Checklist for v7.6.5.0

- [ ] Read the coding agent prompt completely (`prompts/phaseX/v7.6.5.0-implementation-instructions-for-coding-agent.md`)
- [ ] Read this handoff completely
- [ ] Read the Phase X plan §4.1 (module list) and §6 v7.6.5.0 (scope)
- [ ] Verify identity gate: SHA-256 of bundled output matches pre-split original
- [ ] Verify `bundle-dashboard.sh --check` passes
- [ ] Verify `generate-header.sh` produces unchanged `dashboard.h`
- [ ] Run CI-exact Playwright commands across ALL fixture sets
- [ ] Run `bash scripts/preflight.sh`
- [ ] Run `python3 scripts/render_sensor_config.py --check`
- [ ] Visually confirm module boundaries: first/last function in each file matches the table above
- [ ] Confirm `dashboard.html` is UNCHANGED (still manually maintained at Level 1)
- [ ] Confirm no behavioral changes to dashboard functionality

---

## Critical Rules Relevant to v7.6.5.0

| # | Rule | Why Relevant |
|---|------|-------------|
| 3 | Regenerate all artifacts after source changes | Bundle → generator → minify → header |
| 4 | Preflight must pass | Validates generated artifacts in sync |
| 5 | CI-exact `FIXTURE_SET=` runs | Full acceptance gate |
| 6 | Mirror JS ↔ HTML | `dashboard.html` unchanged this step, but rule still active |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 37 | Full regeneration pipeline | Pipeline now includes `bundle-dashboard.sh` |
| 38 | POST semantics unchanged | All POST fetch calls moved intact |

---

## Workflow for v7.6.5.0

> **⚠️ This is the highest-context step (~35K tokens). The coding agent must read the full monolith once to split.**

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR
> for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for
> clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for v7.6.5.1. If PR has not been open, **open a NEW coding agent session outside of this chat** and paste the prompt
3. The agent:
   a. Records SHA-256 of current `dashboard.js`
   b. Creates `dashboard/src/` with 21 module files (contiguous slices)
   c. Creates `scripts/bundle-dashboard.sh`
   d. Runs bundle → verifies SHA-256 identity
   e. Runs full pipeline and Playwright
4. Review the PR — verify module boundaries, identity gate, no behavior changes, check automatically posted reviews and additional external reviews that might be posted
5. Merge, tag `v7.6.5.0`
6. Produce consolidated audit and lessons file (see Post-PR Closure section below)
7. Check and update session handoff for v7.6.5.1 if necessary (see Post-PR Closure section below)
8. Check and update agent's prompt for v7.6.5.1 if necessary (see Post-PR Closure section below)
---

## Post-PR Closure Deliverables for v7.6.5.0

### 1. Consolidated Audit

**File:** `prompts/phaseX/v7.6.5.0-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseX/pr-audit-question-template.md`
**Format:** Same structure as `prompts/phaseX/v7.6.4.0-PR131-consolidated-audit-and-lessons.md`

Use stable core questions from `prompts/phaseX/pr-audit-question-template.md`  plus Level-Specific Supplements for Level 1:
- Did the identity gate pass (SHA-256 before = after)?
- Were all modules contiguous file slices with no function reordering?
- Did the agent introduce any behavioral changes?

### 2. Session Handoff for v7.6.5.1

**File:** `prompts/handoff/session-handoff-v7.6.5.1.md` is already produced,  if this or previous steps reveals something unexpected (identity gate fails, a module boundary needs adjustment), provide a patch for this and future step handoff files if necessary.  

### 3. Check Agent's prompt for v7.6.5.1

**File:** `prompts/phaseX/v7.6.5.1-implementation-instructions-for-coding-agent.md` is already produced, provide a patch for this and future step prompts files if necessary.  

---

## Device Testing

**Not applicable at Level 1.** The bundled `dashboard.js` is content-identical to the pre-split monolith. No runtime behavior change. The acceptance gate is the identity gate + Playwright.

At Level 2 transition (v7.6.5.3), device testing becomes mandatory per Migration Safety Rule 11.

---

_End of session handoff document._
