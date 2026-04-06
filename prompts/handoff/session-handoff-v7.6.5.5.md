# Session Handoff — v7.6.5.5: Component HTML Template Extraction (Phase X Level 3)

_Date: 2026-04-05_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.5.4 COMPLETE. Component/core directories created, files moved, identity gate confirmed. Entering HTML template decomposition._

---

## Project State Summary

**v7.6.5.4 is complete.** The component directory structure is in place: `dashboard/core/` (10 JS files + boot.js) and `dashboard/components/` (8 component directories, each with `index.js`). `dashboard/src/` has been removed. `bundle-dashboard.sh` uses the new paths. `main` is green, 402/0 tests.

### Current directory structure

```
dashboard/
  core/
    app-shell.js, config.js, sensor-defs.js, history.js, manifest.js,
    status-snapshot.js, ui-helpers.js, staleness-derived.js,
    suspend-resume.js, boot.js
  components/
    sensor-cards/index.js
    charts/index.js
    custom-range/index.js
    auth-modal/index.js
    settings-panel/index.js
    gateway-panel/index.js
    live-view/index.js
    device-info/          ← directory exists but no index.js yet (device-info JS is in core/)
  dashboard.tmpl.html     ← HTML/CSS template with {{JS_PLACEHOLDER}}
  dashboard.js            ← GENERATED bundle
  dashboard.html          ← GENERATED from template + JS
  dashboard.h             ← committed gzip C header
```

**Note:** `device-info` may not have an `index.js` at this point — the device-info JavaScript logic may live in `core/` files. The `device-info` component directory is primarily for its `template.html` (containing the board SVG and top-grid HTML) and eventually its `styles.css`. Verify the actual state of `dashboard/components/device-info/` before starting.

---

## Phase X Progress Table

| Version | Scope | Level | Status |
|---------|-------|-------|--------|
| v7.6.4.0 | Documentation restructuring | Pre-step | ✅ Complete |
| v7.6.5.0–v7.6.5.1 | Module split + CI wiring | Level 1 | ✅ Complete |
| v7.6.5.2–v7.6.5.3 | Template creation + mirror retirement | Level 2 | ✅ Complete |
| v7.6.5.4 | Component directory scaffolding | Level 3 | ✅ Complete |
| **v7.6.5.5** | **Component HTML template extraction** | **Level 3** | **⬅️ Next** |
| v7.6.5.6 | CSS extraction | Level 3 | Pending |
| v7.6.5.7 | Test spec split | Test/Closure | Pending |
| v7.6.5.8 | Phase X closure | Test/Closure | Pending |

---

## v7.6.5.5 Scope

Extract HTML markup for each dashboard section from `dashboard.tmpl.html` into per-component `template.html` files. Update `build-dashboard.sh` for two-pass assembly.

### What this step does

1. Read `dashboard.tmpl.html` and identify the HTML sections for each component by their DOM identifiers.
2. Extract each section into `dashboard/components/<name>/template.html`.
3. Replace extracted sections in `dashboard.tmpl.html` with `{{COMPONENT:name}}` markers.
4. Update `build-dashboard.sh` for two-pass assembly: Pass 1 resolves `{{COMPONENT:name}}` markers → Pass 2 injects JS at `{{JS_PLACEHOLDER}}`.
5. Verify two-pass output matches v7.6.5.4 output exactly.

### Component template targets (from plan §6 v7.6.5.5)

| Component | DOM identifiers | Notes |
|-----------|----------------|-------|
| `device-info` | `#c3DescriptionBlock`, `.top-grid` | Includes the existing C3 board SVG |
| `sensor-cards` | `#sensorGrid` | Sensor grid section |
| `charts` | `.charts-row`, `#chartSection` | Chart canvases and history controls |
| `settings-panel` | `#storageCard`, `#exportSection` | Storage, export, import, management |
| `custom-range` | `#customRangeModal` | Calendar modal |
| `auth-modal` | `#authModal` | Auth dialog |
| `live-view` | `#telemetrySection` | Telemetry panel |
| `gateway-panel` | `#hdr-gateways`, `#gwSelector` | Aggregator selector, summary, settings |

### Key constraints

- **Whitespace preservation.** Extract exactly as written. No prettification, no reformatting.
- **No DOM splitting.** A `<div>` and its closing `</div>` must be in the same template file. Never split a DOM element across component boundaries.
- **Marker placement.** Each `{{COMPONENT:name}}` sits on its own line at the exact position where the HTML block was removed.

### Acceptance criteria

- [ ] All 8 component `template.html` files exist
- [ ] Two-pass assembly produces output identical to v7.6.5.4 `dashboard.html`
- [ ] `generate-header.sh` produces identical `dashboard.h`
- [ ] All 402 tests pass
- [ ] Preflight passes

---

## Pre-merge Checklist for v7.6.5.5

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] Verify `dashboard.tmpl.html` before extraction — identify exact line ranges for each HTML section
- [ ] Verify two-pass assembly produces identical output (diff gate)
- [ ] Verify no DOM elements were split across component boundaries
- [ ] Run CI-exact Playwright across all fixture sets
- [ ] Preflight passes

---

## Critical Rules Relevant to v7.6.5.5

| # | Rule | Why Relevant |
|---|------|-------------|
| 4 | Preflight must pass | Validates sync |
| 5 | CI-exact `FIXTURE_SET=` runs | Full acceptance gate |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 37 | Full regeneration pipeline | Two-pass build |
| 38 | POST semantics | Preserved through assembly |

---

## Risk: Medium

HTML extraction must preserve whitespace exactly. The most likely failure mode is extracting a section boundary one line too early or late, causing a whitespace diff. The fix is to re-examine the HTML structure and adjust the extraction boundary.

If the diff gate fails, check for:
- Extra or missing blank lines at extraction boundaries
- Indentation differences between the extracted template and the marker replacement
- A closing `</div>` that belongs to the parent structure, not the component

---

## Workflow for v7.6.5.5

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR
> for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for
> clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for this step is open. If PR has not been open, **open a NEW coding agent session outside of this chat** and paste the prompt
3. Agent reads `dashboard.tmpl.html`, identifies sections, extracts templates
4. Agent updates `build-dashboard.sh` for two-pass assembly
5. Agent verifies output matches previous step
6. Review the PR — verify extraction boundaries, diff gate, check and assess the inline and external PR reviews if posted
7. Merge, tag `v7.6.5.5`
8. Produce consolidated audit and lessons file (see Post-PR Closure section below)
9. Check and update session handoff for v7.6.5.6 if necessary (see Post-PR Closure section below)
10. Check and update agent's prompt for v7.6.5.6 if necessary (see Post-PR Closure section below)

---

## Post-PR Closure Deliverables for v7.6.5.5

### 1. Consolidated Audit

**File:** `prompts/phaseX/v7.6.5.5-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseX/pr-audit-question-template.md`
**Format:** Same structure as `prompts/phaseX/v7.6.4.0-PR131-consolidated-audit-and-lessons.md`

Use stable core questions from `prompts/phaseX/pr-audit-question-template.md`  plus Level-Specific Supplements for Level 3:
- Were component template boundaries accurate (no DOM elements split)?
- Did the two-pass assembly produce identical output?
- Are all 8 component `template.html` files present?

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/session-handoff-v7.6.5.6.md` — verify the CSS partition table still matches the delivered `dashboard.tmpl.html` state. If template extraction changed which CSS selectors remain in the shell vs. which moved to components, update the handoff accordingly.
- `prompts/phaseX/v7.6.5.6-implementation-instructions-for-coding-agent.md` — verify CSS selector families and their component targets still match. The CSS extraction step depends on the HTML template structure being stable — if v7.6.5.5 changed the template structure in any way the prompt didn't anticipate, update the CSS mapping.

---



## Device Testing

**Not applicable.** Output is identical to v7.6.5.4 (verified by diff gate). No runtime change.

---

_End of session handoff document._
