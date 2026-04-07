# Session Handoff — v7.6.5.6: Component CSS Extraction (Phase X Level 3)

_Date: 2026-04-07_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.5.5 COMPLETE. Component HTML templates extracted, two-pass assembly operational
and verified. Entering CSS decomposition._

---

## Project State Summary

**v7.6.5.5 is complete.** All 8 component directories now have both `index.js` and
`template.html`. `dashboard.tmpl.html` uses `{{COMPONENT:name}}` markers for HTML sections
and `{{JS_PLACEHOLDER}}` for JS. Two-pass assembly in `build-dashboard.sh` produces output
identical to v7.6.5.4. `main` is green, 402/0 tests.

### Current directory structure

```
dashboard/
  core/
    app-shell.js, config.js, sensor-defs.js, history.js, manifest.js,
    status-snapshot.js, ui-helpers.js, staleness-derived.js,
    suspend-resume.js, boot.js
  components/
    sensor-cards/     index.js, template.html
    charts/           index.js, template.html
    custom-range/     index.js, template.html
    auth-modal/       index.js, template.html
    settings-panel/   index.js, template.html
    gateway-panel/    index.js, template.html
    live-view/        index.js, template.html
    device-info/      template.html  (index.js if applicable)
    import-panel/     index.js  ← JS-only; NO template.html, NO styles.css
  dashboard.tmpl.html  ← shell with {{COMPONENT:*}} + {{JS_PLACEHOLDER}}
  dashboard.js         ← GENERATED bundle
  dashboard.html       ← GENERATED from template + JS
  dashboard.h          ← committed gzip C header
```

After this step, each of the 8 template-bearing components gains a `styles.css` and
`core/` gains `base.css`.

### v7.6.5.5 Accepted Exceptions (carry forward — affect CSS assignment)

Two DOM sections that were planned for component extraction remained in the shell due to
non-contiguous DOM placement. Their CSS must stay in `core/base.css`, not in the
component `styles.css` files:

| Shell element | CSS selectors affected | Why stays in shell |
|---------------|----------------------|-------------------|
| `#c3DescriptionBlock` / `.about-bar` | `.about-bar` selector family | Non-contiguous with `.top-grid`; kept in `<header>` area |
| `.export-section` / `#exportSection` | `.export-*` selectors | Non-contiguous with `.storage-card`; kept below `charts` section |

`import-panel` has no CSS at all — JS-only component.

---

## Phase X Progress Table

| Version | Scope | Level | Status |
|---------|-------|-------|--------|
| v7.6.4.0 | Documentation restructuring | Pre-step | ✅ Complete |
| v7.6.5.0–v7.6.5.1 | Module split + CI wiring | Level 1 | ✅ Complete |
| v7.6.5.2–v7.6.5.3 | Template creation + mirror retirement | Level 2 | ✅ Complete |
| v7.6.5.4 | Component directory scaffolding | Level 3 | ✅ Complete |
| v7.6.5.5 | HTML template extraction | Level 3 | ✅ Complete |
| **v7.6.5.6** | **CSS extraction** | **Level 3** | **⬅️ Next** |
| v7.6.5.7 | Test spec split | Test/Closure | Pending |
| v7.6.5.8 | Phase X closure | Test/Closure | Pending |

---

## v7.6.5.6 Scope

Extract CSS from the `<style>` block in `dashboard.tmpl.html` into per-component
`styles.css` files and `core/base.css`. Update `build-dashboard.sh` for three-pass
assembly.

### What this step does

1. Read the `<style>` block in `dashboard.tmpl.html` (approximately lines 26–497,
   ~471 lines of CSS on PR #146 head — **re-read the file to confirm exact boundaries
   before extraction**).
2. Partition CSS rules by selector family per the plan §3.3 mapping table (see below).
3. Create `dashboard/core/base.css` for global CSS (`:root`, theme tokens, resets,
   breakpoints, shared structural selectors, and shell-resident elements from
   v7.6.5.5 accepted exceptions).
4. Create `styles.css` for each of the 8 template-bearing component directories.
5. Replace `<style>` content in `dashboard.tmpl.html` with `{{CSS_PLACEHOLDER}}`.
6. Update `build-dashboard.sh` for three-pass assembly:
   - **Pass 0:** Concatenate `core/base.css` + `components/*/styles.css` in cascade
     order → replace `{{CSS_PLACEHOLDER}}`
   - **Pass 1:** Resolve `{{COMPONENT:name}}` template markers (existing; keep CRLF-
     tolerant `re.sub`)
   - **Pass 2:** Inject `dashboard.js` at `{{JS_PLACEHOLDER}}`
7. Verify three-pass output matches v7.6.5.5 output exactly.

### CSS partition reference (from plan §3.3, updated for v7.6.5.5 accepted exceptions)

| CSS selector family | Target file | Note |
|-------------------|------------|------|
| `:root`, `body`, `.header`, `*` resets, scrollbar | `core/base.css` | |
| `.status-*`, `.about-bar`, `.error-banner` | `core/base.css` | `.about-bar` stays in shell (v7.6.5.5 exception) |
| `.collapse-*` | `core/base.css` | |
| `.credits-*` | `core/base.css` | |
| `.footer`, `.debug-*` | `core/base.css` | |
| `:root.light ...`, `.theme-toggle` | `core/base.css` | |
| Global `@media` breakpoints | `core/base.css` | |
| `.export-*` | `core/base.css` | `.export-section` stays in shell (v7.6.5.5 exception) |
| `.top-grid`, `.gateway-*`, `.device-info-*`, `.compact-*`, `.gpio-*` | `components/device-info/styles.css` | |
| `.sensor-*`, `.reading-*`, `.network-card`, `.system-card`, `.system-*` | `components/sensor-cards/styles.css` | |
| `.charts-row`, `.chart-*`, `.history-*`, `.refresh-btn` | `components/charts/styles.css` | |
| `.storage-*` | `components/settings-panel/styles.css` | |
| `.telemetry-*` | `components/live-view/styles.css` | |
| `.auth-*` | `components/auth-modal/styles.css` | |
| `.cr-*` | `components/custom-range/styles.css` | |
| `.gw-*`, `.settings-*` | `components/gateway-panel/styles.css` | |

**Critical constraint:** The concatenation order of CSS files in `build-dashboard.sh`
must match the original cascade order in the `<style>` block. CSS rules that appear
earlier in the original must come from files listed earlier in the concatenation.
Do not alphabetize or auto-sort.

**Pass 0 marker replacement must use `re.sub` with `\r?\n`** (same CRLF-tolerant
approach as Pass 1) — never `bytes.replace()` with a hardcoded `\n`.

### Acceptance criteria

- [ ] `core/base.css` contains only global CSS (+ shell-resident selector families)
- [ ] All 8 component `styles.css` files exist (no `import-panel/styles.css`)
- [ ] Three-pass assembly produces output identical to v7.6.5.5 `dashboard.html`
- [ ] `generate-header.sh` produces identical `dashboard.h`
- [ ] All 402 tests pass
- [ ] Visual regression: screenshot before and after shows no rendered difference
- [ ] Preflight passes

---

## Pre-merge Checklist for v7.6.5.6

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] Re-read `dashboard.tmpl.html` to confirm actual `<style>` block line boundaries
- [ ] Verify CSS partition boundaries before extraction
- [ ] Verify three-pass assembly output matches v7.6.5.5 (diff gate)
- [ ] Verify CSS cascade order is preserved in the build script concatenation list
- [ ] Verify `.about-bar` and `.export-*` CSS went to `core/base.css` (not component files)
- [ ] Verify component-specific `@media` rules went to the correct component
- [ ] Verify no `import-panel/styles.css` was created
- [ ] Visual regression: load dashboard in browser before and after, compare
- [ ] Run CI-exact Playwright across all fixture sets
- [ ] Preflight passes

---

## Critical Rules Relevant to v7.6.5.6

| # | Rule | Why Relevant |
|---|------|-------------|
| 4 | Preflight must pass | Validates sync |
| 5 | CI-exact `FIXTURE_SET=` runs | Full acceptance gate |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 37 | Full regeneration pipeline | Pipeline now includes three-pass build |
| 51 | CRLF-tolerant `re.sub` for ALL marker replacements | Pass 0 (CSS) must use same pattern as Pass 1 (components) |
| 52 | `devDependencies` + `npx` for build tools | Any new build-only tool added must use `devDependencies` |

---

## Risk: Medium

CSS boundary identification is the trickiest part of Level 3. Common pitfalls:

- **Shell-resident selectors.** `.about-bar` and `.export-*` are in the shell DOM (not
  in any component `template.html`) — their CSS must go to `core/base.css`. Do NOT put
  them in `device-info/styles.css` or `settings-panel/styles.css`.
- **Cross-component selectors.** A CSS rule like `.collapse-btn .sensor-name` targets
  elements from two different components. These rules stay in `core/base.css`.
- **Responsive breakpoints.** `@media` rules that contain selectors from multiple
  components stay in `core/base.css`. Component-specific `@media` rules go with the
  component. The `@media (max-width:480px)` block inside the `/* Custom Date Range Modal
  */` section is component-specific (`.cr-*`) → goes with `custom-range`.
- **Cascade order drift.** If the CSS files are concatenated in wrong order, specificity
  changes can alter rendered appearance even though the same rules exist. The visual
  regression check catches this.

---

## Workflow for v7.6.5.6

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR
> for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for
> clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for this step is open. If PR has not been open, **open a NEW coding
   agent session outside of this chat** and paste the prompt
3. Agent reads CSS, partitions by selector family, creates files
4. Agent updates `build-dashboard.sh` for three-pass assembly
5. Agent verifies output matches v7.6.5.5 and does visual regression
6. Review the PR — verify CSS boundaries, cascade order, shell-resident selectors,
   diff gate, check and assess the inline and external PR reviews if posted
7. Merge, tag `v7.6.5.6`
8. Produce consolidated audit and lessons file (see Post-PR Closure section below)
9. Check and update session handoff for v7.6.5.7 if necessary (see Post-PR Closure
   section below)
10. Check and update agent's prompt for v7.6.5.7 if necessary (see Post-PR Closure
    section below)

---

## Post-PR Closure Deliverables for v7.6.5.6

### 1. Consolidated Audit

**File:** `prompts/phaseX/v7.6.5.6-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseX/pr-audit-question-template.md`
**Format:** Same structure as `prompts/phaseX/v7.6.5.5-PR146-consolidated-audit-and-lessons.md`

Use stable core questions from `prompts/phaseX/pr-audit-question-template.md` plus Level-
Specific Supplements for Level 3:
- Did the CSS cascade order survive extraction?
- Were shell-resident selectors (`.about-bar`, `.export-*`) correctly routed to `core/base.css`?
- Did the three-pass assembly produce identical output?
- Visual regression: any rendered differences?
- Was `import-panel/styles.css` correctly absent?

### 2. Gate Check: Level 3 → Test/Closure

After v7.6.5.6 merges, verify the Level 3 → Test/Closure gate:
- Three-pass assembly stable ✓
- Visual regression clean ✓
- All tests green ✓

### 3. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/session-handoff-v7.6.5.7.md` — verify test group assignments still
  make sense given the delivered component structure. If any component boundary changed
  during CSS extraction, the test grouping may need adjustment.
- `prompts/phaseX/v7.6.5.7-implementation-instructions-for-coding-agent.md` — verify
  test file names, group numbers, and the proposed test file structure table still align
  with the delivered component model.

---

## Device Testing

**Not applicable for this step.** Output is identical to v7.6.5.5 (verified by diff gate).
Visual regression in browser from disk is sufficient.

---

_End of session handoff document._
