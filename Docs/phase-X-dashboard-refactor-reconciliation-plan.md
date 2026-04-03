# Phase X — Dashboard Refactor Reconciliation Plan

_Last updated: 2026-04-03_

This document explains how the two existing Phase X dashboard architecture plans are reconciled into a single authoritative implementation plan. It assumes familiarity with:

- `Docs/phase-d-implementation-plan.md` (Phase D versioning and implementation patterns),[cite:1]
- `Docs/bugs-and-lessons-learned.md` (especially LESSON-OPS-043, -052, -065, -074, -099),[cite:2]
- `Docs/approach-towards-modular-architecture-PR.md` (original three-level modularization analysis),[cite:4]
- `Docs/phase-X-architecture-and-refactor-plan-dashboard-GP.md` (Draft A),[cite:3]
- `Docs/phase-X-architecture-and-refactor-plan-dashboard-PR.md` (Draft B).[cite:5]

The reconciled plan itself lives in `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`.

---

## 1. Chosen baseline and version range

### 1.1 Version mapping

The reconciled plan adopts Draft B’s version range and mapping, extended over `v7.6.5.0–v7.6.5.7`:[cite:1][cite:5]

| Phase | Version Range | Description |
| :-- | :-- | :-- |
| Phase D | `v7.6.0.0–v7.6.0.5` | Runtime Satellite Management (already shipped).[cite:1] |
| **Phase X** | **`v7.6.5.0–v7.6.5.7`** | **Dashboard Architecture Refactor.**[cite:3][cite:5] |
| Phase E | `v8.0.x` | Captive Portal + WiFi Config (future work). |

### 1.2 Three structural levels

The reconciled plan preserves the three-level structure shared by the background analysis and both drafts:[cite:3][cite:4][cite:5]

1. **Level 1 — Module split**  
   Break the `dashboard.js` monolith into smaller modules while keeping runtime behavior and the existing HTML/minify/header pipeline unchanged.

2. **Level 2 — Generated HTML**  
   Introduce a template-based build so that `dashboard.html` is generated from a JS bundle and an HTML template, eliminating the manual JS/HTML mirroring that caused LESSON-OPS-043 and BUG-039.[cite:2][cite:3][cite:5]

3. **Level 3 — Component model**  
   Introduce component and core directories so each panel (sensor cards, charts, settings, aggregator gateways, etc.) can evolve in isolation with its own JS/HTML/CSS, without increasing working-context pressure.[cite:3][cite:4][cite:5]

---

## 2. Where the reconciled plan follows Draft A

The reconciled plan adopts the following from Draft A:[cite:3]

1. **Deeper current-state and CSS mapping**  
   - Uses Draft A’s classification of `dashboard.js` into shared, satellite-only, and aggregator-only areas as the baseline for deciding module and component boundaries.
   - Reuses Draft A’s CSS partition table (e.g., `.sensor-*`, `.network-card`, `.gw-*`, `.cr-*`) to guide which selectors live in which component `styles.css` files at Level 3.

2. **Refactor principles**  
   - Retains the principles that file boundaries must follow feature ownership, generated outputs must remain deterministic, and component boundaries should match real DOM and CSS seams.[cite:3]

3. **Generated artifacts remain committed for review**  
   - Keeps `dashboard/dashboard.html` **committed**, even after it becomes a generated file, so reviewers can diff the assembled HTML alongside the JS and header.[cite:3]
   - This choice differs from Draft B’s proposal to gitignore `dashboard.html`; see §3.3.

4. **High-level step framing**  
   - Maintains the conceptual breakdown of the phase into: bundle scaffold, module split, template introduction, template canonicalization, component assembler, and component migration, while allowing Draft B’s finer-grained steps to sit underneath.[cite:3][cite:5]

5. **Context-window analysis**  
   - Carries forward Draft A’s context-window targets (≈6K–15K tokens for a typical future dashboard task) as the success criterion for Phase X.

---

## 3. Where the reconciled plan follows Draft B

The reconciled plan adopts the following from Draft B:[cite:5]

### 3.1 Detailed step decomposition

- Uses Draft B’s **seven implementation steps** (plus closure) within the three levels:
  - `v7.6.5.0` — Establish module skeleton under `dashboard/modules/` and create `bundle-dashboard.sh`.
  - `v7.6.5.1` — Wire `bundle-dashboard.sh` into CI and `preflight.sh`.
  - `v7.6.5.2` — Introduce `dashboard.tmpl.html` with `{{JS_PLACEHOLDER}}` and `build-dashboard.sh`, and prove byte-for-byte HTML equivalence.
  - `v7.6.5.3` — Make the template-based pipeline canonical for generating `dashboard.html` and `dashboard.h` (without gitignoring `dashboard.html`).
  - `v7.6.5.4` — Introduce `dashboard/components/` and `dashboard/core/` scaffolding and move modules into those directories.
  - `v7.6.5.5` — Extract per-component HTML templates and add `{{COMPONENT:name}}` markers.
  - `v7.6.5.6` — Extract per-component CSS with `{{CSS:name}}` markers and multi-pass assembly.
  - `v7.6.5.7` — Phase X closure: new build-pipeline tests, additional preflight checks, and docs updates.[cite:5]

### 3.2 Concrete file and script naming

- Uses Draft B’s file names and layout as the baseline:
  - `dashboard/modules/*.js` at Level 1, evolving into `dashboard/components/*/index.js` + `dashboard/core/*.js` at Level 3.
  - `scripts/bundle-dashboard.sh` as the JS bundler.
  - `scripts/build-dashboard.sh` as the multi-pass HTML/CSS/JS assembler.[cite:5]

### 3.3 Preflight and CI integration

- Adopts the new and updated preflight checks from Draft B, adapted to the "HTML remains committed" decision:
  - `dashboard_js_is_up_to_date` — rebundling into a temp file must yield no diff vs. committed `dashboard.js`.
  - `dashboard_tmpl_has_placeholder` — ensures `{{JS_PLACEHOLDER}}` exists.
  - Component existence checks and pipeline sanity checks at closure (`v7.6.5.7`).[cite:5]
- Integrates `bundle-dashboard.sh` and `build-dashboard.sh` into CI before minification and Playwright runs, as described in Draft B.[cite:5]

### 3.4 Bit-for-bit identity gates

- Preserves all bit-for-bit gates from Draft B:
  - Bundled `dashboard.js` (minus small header comment) must SHA-256 match the pre-split monolith at `v7.6.5.0`.[cite:5]
  - Generated `dashboard.html` must be byte-for-byte identical to the last hand-maintained HTML at `v7.6.5.2`.
  - `dashboard.h` must remain byte-identical before and after each structural step until the pipeline is fully canonicalized.[cite:5]

### 3.5 Closure and new tests

- Incorporates Draft B’s Phase X closure step (`v7.6.5.7`) adding:
  - Build-pipeline smoke tests (e.g., that `{{JS_PLACEHOLDER}}` and `{{COMPONENT:*}}` markers do not leak into the final HTML),
  - Tests asserting that component and core files exist on disk,
  - Guards ensuring `bump-version.sh` uses the regeneration pipeline instead of directly editing `dashboard.html`.[cite:5]

---

## 4. Resolved tensions between drafts

### 4.1 `dashboard.html` commitment vs. gitignore

- **Draft A**: wants generated outputs (including `dashboard.html`) to remain committed for reviewability.[cite:3]
- **Draft B**: proposes gitignoring `dashboard.html` and enforcing that it never be committed via preflight.[cite:5]

**Reconciled decision:**

- Keep `dashboard/dashboard.html` **committed**, but:
  - Mark it clearly as **generated** in comments.
  - Make `bundle-dashboard.sh` + `build-dashboard.sh` + `generate-header.sh` the canonical way to regenerate it.
  - Use preflight checks to ensure it is always in sync with the template and modules (i.e., edits to `dashboard.html` will be overwritten and out-of-sync changes will fail preflight).
- This preserves Draft A’s reviewability goal while still giving Draft B’s pipeline and identity gates enforcement power.

### 4.2 Granularity of Level 3 steps

- **Draft A**: collapses Level 3 into two versions (component assembler and migration).[cite:3]
- **Draft B**: splits Level 3 into multiple smaller moves (scaffolding, HTML extraction, CSS extraction, closure/tests).[cite:5]

**Reconciled decision:**

- Keep Draft B’s finer-grained steps (`v7.6.5.4–v7.6.5.7`), which reduce risk and match how the repo already treats multi-step refactors in other phases.
- Use Draft A’s CSS and DOM mapping to drive how templates and styles are partitioned across components.

### 4.3 Explicitness about aggregator semantics

- **Both drafts** preserve a single runtime and mention aggregator functionality, but do not restate LESSON-OPS-074 directly when defining Level 3.[cite:2][cite:3][cite:5]

**Reconciled decision:**

- The unified plan explicitly requires that:
  - The aggregator remains an overlay on the satellite dashboard boot path (unified `App.Boot.start` pipeline), per LESSON-OPS-074.[cite:2]
  - All componentization work must preserve this invariant: aggregator-related components (gateway panel, settings) are composed *on top of* the base layout, not via a separate boot flow.

### 4.4 Integration of lessons for POST handling and history endpoints

- **Both drafts** state “no behavior change” but do not explicitly restate LESSON-OPS-052 (history NVS scans are blocking) or LESSON-OPS-099 (x-www-form-urlencoded POST bodies only) as constraints for Phase X.[cite:2][cite:3][cite:5]

**Reconciled decision:**

- The final plan will explicitly call out:
  - POST endpoints and body handling must remain unchanged across Phase X; no content-type or request-shape changes are allowed in refactor steps.[cite:2]
  - History-related JS (e.g., `fetchDeviceHistory`, `loadHistory`) must continue to respect LESSON-OPS-052’s rules about sequential history fetches and in-flight guards.[cite:2]

---

## 5. Additional guardrails brought in from bugs & lessons

Beyond what is explicitly named in the drafts, the reconciled plan bakes in these lessons as non-negotiable constraints:[cite:2]

1. **LESSON-OPS-043 — JS/HTML drift**  
   - Structural fix via Level 2: `dashboard.html` is generated from `dashboard.tmpl.html` + `dashboard.js`, and manual mirroring is no longer part of the workflow.

2. **LESSON-OPS-051 — real-device validation**  
   - Each Phase X step that changes file organization or the build pipeline must be validated on real hardware with the dashboard open before merge, even when all tests pass.

3. **LESSON-OPS-052 — history endpoint blocking**  
   - History fetching behavior must remain sequential and guarded; no attempt at “cleanup” of those paths is allowed inside Phase X refactor steps.

4. **LESSON-OPS-065 — color-scheme for native widgets**  
   - When extracting CSS into component stylesheets, the dark/light `color-scheme` behavior for `<input type=date>` and `<select>` must be preserved exactly.[cite:2]

5. **LESSON-OPS-074 — aggregator boot must be a superset**  
   - Componentization cannot introduce a forked boot path for the aggregator; aggregator components must layer onto the core satellite pipeline.

6. **LESSON-OPS-099 — POST body semantics**  
   - All dashboard POSTs to firmware (management, import/export, Phase D endpoints) must continue to use `application/x-www-form-urlencoded` with small dummy bodies where appropriate. Structural refactors may not introduce `application/json` POST bodies.

These are all reflected explicitly in the final reconciled Phase X plan.

---

## 6. Summary of the reconciled plan

In brief, the unified plan:

- **Uses Draft B’s step-by-step, file-level implementation structure and version range**,
- **Enriches it with Draft A’s deeper analysis of current JS, CSS, and DOM structure**, especially for defining component boundaries,
- **Keeps `dashboard.html` as a generated but committed artifact**, reconciling Draft A’s reviewability concern with Draft B’s pipeline checks,
- **Integrates key operational lessons** (043, 051, 052, 065, 074, 099) as explicit Phase X constraints rather than implicit background knowledge,
- And culminates in a **single canonical document**: `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`, which supersedes both earlier drafts.
