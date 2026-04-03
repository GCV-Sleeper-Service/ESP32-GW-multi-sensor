# Phase X — Dashboard Architecture and Refactor Plan

_Implementation Plan for v7.6.5.0–v7.6.5.7_

_Date: 2026-04-03_  
_Prerequisite: Phase D complete (v7.6.0.5 on `main`)_  
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

This document supersedes the earlier draft plans in:

- `Docs/phase-X-architecture-and-refactor-plan-dashboard-GP.md` (Draft A),[cite:3]
- `Docs/phase-X-architecture-and-refactor-plan-dashboard-PR.md` (Draft B).[cite:5]

It reconciles those drafts with the modular-architecture background note and the project’s lessons/bug history.[cite:1][cite:2][cite:4]

---

## 1. Goal

Refactor the dashboard source structure in three carefully staged, reversible levels so that:

1. **Future coding-agent tasks fit within a safe working context** (≈6K–15K tokens) rather than requiring the full dashboard monolith plus its HTML mirror.[cite:3][cite:5]
2. **The manual JS/HTML mirroring requirement (LESSON-OPS-043)** is permanently eliminated: `dashboard.html` becomes a generated artifact, not a hand-edited copy.[cite:2][cite:3][cite:5]
3. **Existing runtime behavior remains unchanged** across all Phase X steps — same endpoints, DOM structure, chart behavior, management actions, and network behavior.
4. **The embedded dashboard payload (`dashboard.h`) stays deterministic and reviewable**, generated via an explicit, documented build pipeline.[cite:1][cite:3][cite:5]
5. **Phase X prepares the dashboard for Phase E (v8.0.x) and beyond** by introducing a component model that matches existing CSS/DOM seams, without introducing new runtime concepts.[cite:3][cite:4][cite:5]

---

## 2. Architecture reference

Relevant existing documents and code:

- `Docs/phase-d-implementation-plan.md` — structure and versioning for Phase D, including the v7.6.0.0–v7.6.0.5 mapping.[cite:1]
- `Docs/bugs-and-lessons-learned.md` — especially LESSON-OPS-043, -052, -065, -074, -099 and related BUG entries.[cite:2]
- `Docs/approach-towards-modular-architecture-PR.md` — original analysis of Levels 1–3 and context-window constraints.[cite:4]
- `dashboard/dashboard.js` — current monolithic JS reference file (~2.6K lines).[cite:3][cite:5]
- `dashboard/dashboard.html` — current HTML + inline JS payload used to generate `dashboard.h`.[cite:2][cite:3][cite:5]
- `scripts/minify-dashboard.sh`, `scripts/generate-header.sh` — existing minification and header-embedding steps, already hardened by prior phases.[cite:1][cite:2]

---

## 3. Current state summary

### 3.1 Dashboard assets today

| Artifact | Role today | Problem today |
| :-- | :-- | :-- |
| `dashboard/dashboard.js` | Developer-facing JS source (not served by firmware) | 2,600-line monolith; large working context for any change.[cite:3][cite:5] |
| `dashboard/dashboard.html` | HTML+CSS+inline JS used to generate `dashboard.h` | Manual mirror of `dashboard.js`; source of LESSON-OPS-043 / BUG-039 drift.[cite:2][cite:3] |
| `dashboard/dashboard.min.html` | Minified HTML (build artifact) | Can become stale and still be embedded if regeneration order is wrong.[cite:2] |
| `dashboard/dashboard.h` | Committed, gzip-compressed firmware payload | Depends on correct, manual regeneration from HTML.[cite:1] |

### 3.2 Functional partition (high level)

`dashboard.js` already has implicit groupings, but only via comments and proximity:[cite:3][cite:5]

- **Shared runtime logic**: App namespace, transport detection, `App.State`, manifest loading, sensor meta application, helper functions, theme handling, charts, card renderers, SSE/polling, status/storage, management actions, and boot sequence.
- **Satellite-focused logic**: history fetching and CSV export/import, min/max calculations, derived values (dew point, comfort), and some telemetry handling.[cite:3][cite:5]
- **Aggregator-focused logic**: aggregator mode detection, gateway tabs and summaries, remote gateway device rendering, aggregator settings and polling.[cite:3][cite:5]

On the CSS/DOM side, the main seams already map to logical panels/components (sensor cards, charts, storage panel, telemetry panel, gateways panel, settings, custom-range modal, auth modal, etc.).[cite:3]

### 3.3 Build pipeline today

Today’s pipeline is:

```text
dashboard/dashboard.html   (hand-edited; contains inline JS)
  └─ scripts/minify-dashboard.sh
        └─ dashboard/dashboard.min.html
              └─ scripts/generate-header.sh
                    └─ dashboard/dashboard.h
```

This pipeline is the root cause of LESSON-OPS-043: any dashboard change must be applied twice (JS and HTML), and minified output can drift from source if `minify-dashboard.sh` or `generate-header.sh` are not run in the right order.[cite:2][cite:3]

---

## 4. Levels and overall strategy

Phase X uses the three-level structure from the modular-architecture note and both earlier drafts, with more granular, versioned steps adopted from Draft B.[cite:3][cite:4][cite:5]

1. **Level 1 — Module split (v7.6.5.0–v7.6.5.1)**  
   - Extract the `dashboard.js` monolith into smaller `dashboard/modules/*.js` files grouped by concern.
   - Introduce `scripts/bundle-dashboard.sh` to produce `dashboard/dashboard.js` from modules in a fixed order.
   - Keep `dashboard.html`, `minify-dashboard.sh`, and `generate-header.sh` behavior unchanged in this level.

2. **Level 2 — Generated HTML (v7.6.5.2–v7.6.5.3)**  
   - Introduce `dashboard/dashboard.tmpl.html` with a `{{JS_PLACEHOLDER}}` marker.
   - Add `scripts/build-dashboard.sh` to inject the bundled JS into the template to produce `dashboard.html`.
   - Prove byte-for-byte equivalence between generated and current `dashboard.html` and keep `dashboard.html` committed as a generated artifact.
   - Make the bundle+build pipeline canonical for generating `dashboard.html` and `dashboard.h`.

3. **Level 3 — Component model (v7.6.5.4–v7.6.5.7)**  
   - Introduce `dashboard/components/` and `dashboard/core/` directories and move modules accordingly.
   - Extract per-component HTML templates and CSS into dedicated files, using `{{COMPONENT:name}}` and `{{CSS:name}}` markers in the template.
   - Extend `build-dashboard.sh` into a multi-pass assembler (CSS → templates → JS).
   - Add build-pipeline Playwright tests and preflight checks as Phase X closure.

---

## 5. Version number mapping

| Version | Level | Step name | Primary outcome |
| :-- | :-- | :-- | :-- |
| `v7.6.5.0` | Level 1 | Module skeleton | Introduce `dashboard/modules/` and `bundle-dashboard.sh`; preserve bundled JS identity vs. monolith.[cite:5] |
| `v7.6.5.1` | Level 1 | CI & preflight wiring | Wire bundling into CI and `preflight.sh`.
| `v7.6.5.2` | Level 2 | HTML template introduction | Add `dashboard.tmpl.html` and `build-dashboard.sh`; prove bit-for-bit HTML equivalence.[cite:3][cite:5] |
| `v7.6.5.3` | Level 2 | Template-based pipeline canonical | Make bundle+build the canonical source for `dashboard.html` and `dashboard.h`; keep `dashboard.html` committed but generated.
| `v7.6.5.4` | Level 3 | Component scaffolding | Introduce `components/` and `core/` directories and move modules into them.[cite:3][cite:5] |
| `v7.6.5.5` | Level 3 | Component HTML extraction | Extract per-component `template.html` files and add `{{COMPONENT:name}}` markers.
| `v7.6.5.6` | Level 3 | Component CSS extraction | Extract per-component `styles.css` and global `core/base.css`, add `{{CSS:name}}` markers.
| `v7.6.5.7` | Level 3 | Closure and pipeline tests | Add build-pipeline tests, extra preflight guards, and docs updates; Phase X complete.[cite:5] |

---

## 6. Detailed steps

### 6.1 v7.6.5.0 — Establish module skeleton (Level 1, step 1)

**Goal:** Introduce `dashboard/modules/` and a deterministic bundler, without changing runtime behavior.

**Scope:**

- Create `dashboard/modules/` containing an initial set of JS modules that are functionally equivalent to the current monolith.
- Introduce `scripts/bundle-dashboard.sh` to concatenate those modules in dependency order into `dashboard/dashboard.js`.
- Keep `dashboard.html` and the minify/header pipeline unchanged in this version.

**Module set (initial):**[cite:5]

- `util.js` — helpers (`esc`, `escAttr`, `formatBytes`, `cToF`, logging, etc.).
- `config.js` — host/transport detection, `App.Config`.
- `state.js` — `App.State` IIFE and core state getters/setters.
- `manifest.js` — manifest loading and v1→v2 promotion.
- `history.js` — history fetch/parsing, respecting LESSON-OPS-052.
- `export.js` — CSV export pipeline.
- `import.js` — CSV import pipeline.
- `cards.js` — `CARD_RENDERERS`, environmental/network/system cards.
- `charts.js` — chart options, init, theme updates.
- `transport.js` — SSE + polling wiring.
- `telemetry.js` — telemetry updates.
- `live-devices.js` — network/system live card updates.
- `management.js` — reboot/delete-history/auth, respecting LESSON-OPS-099.
- `suspend-resume.js` — network suspend/resume.
- `custom-range.js` — `CustomRange` IIFE.
- `minmax.js` — min/max helpers.
- `sensor-ui.js` — card-level UI helpers (RSSI, dew point, comfort).
- `status-storage.js` — status and storage stats.
- `boot.js` — `App.Boot.start` and DOMContentLoaded.

**Bundler contract:**[cite:5]

- Concatenate modules in a fixed order into `dashboard/dashboard.js`.
- Add a short header comment indicating that the file is generated and that modules are the sources of truth.

**Identity gate:**

- After bundling, the content of `dashboard/dashboard.js` minus the small header comment must SHA-256 match the pre-split monolith; this is enforced via a one-time identity check and a preflight helper.

**Acceptance criteria:**

- `bundle-dashboard.sh` runs successfully and emits `dashboard/dashboard.js`.
- SHA-256 identity between bundled JS and original monolith (excluding the new header comment).
- `generate-header.sh` produces a `dashboard.h` that is byte-identical to the pre-step version.
- All Playwright tests pass across all fixture variants.
- `preflight.sh` passes.
- Real-device smoke test (per LESSON-OPS-051): dashboard opens and behaves identically before and after the step.

---

### 6.2 v7.6.5.1 — CI integration & preflight wiring (Level 1, step 2)

**Goal:** Make JS bundling a required, enforced part of the build.

**Scope:**

- Update CI workflows to run `bundle-dashboard.sh` before Playwright tests.
- Add a `dashboard_js_is_up_to_date` check in `scripts/preflight.sh` that rebundles into a temp file and fails if there is any diff vs. committed `dashboard.js`.[cite:5]
- Update `Docs/aggregator-setup.md` and any regen instructions to include bundling in the canonical pipeline.[cite:2][cite:5]

**Updated canonical regeneration pipeline (extending LESSON-OPS-091):**[cite:2][cite:5]

1. `python3 scripts/render_sensor_config.py --write`
2. `node tests/fixtures/generate-fixtures.js`
3. `bash scripts/bundle-dashboard.sh`
4. `bash scripts/minify-dashboard.sh`
5. `bash scripts/generate-header.sh`
6. `python3 scripts/render_sensor_config.py --check`

**Acceptance criteria:**

- CI fails if a module has been edited without rebundling.
- Local `preflight.sh` fails if `bundle-dashboard.sh` is not up to date.
- All Playwright tests pass.
- `dashboard.h` remains deterministic.

---

### 6.3 v7.6.5.2 — Introduce HTML template and JS injection (Level 2, step 1)

**Goal:** Add an HTML template and JS injection step while proving that generated HTML matches the current hand-maintained `dashboard.html` exactly.

**Scope:**

- Create `dashboard/dashboard.tmpl.html` by copying the current `dashboard.html` and replacing the entire `<script>…</script>` block with a `{{JS_PLACEHOLDER}}` marker.
- Create `scripts/build-dashboard.sh` that injects `dashboard/dashboard.js` into the placeholder to produce `dashboard/dashboard.html`.
- Keep `dashboard.html` committed; this step is about equivalence, not workflow change yet.

**Identity gate:**

- Save the last hand-maintained `dashboard.html` as a baseline.
- Run bundle+build to produce a generated `dashboard.html`.
- `diff` of generated vs. baseline must be empty.
- `generate-header.sh` must still produce a `dashboard.h` identical to the pre-step version.

**Updated canonical regeneration pipeline:**

1. `python3 scripts/render_sensor_config.py --write`
2. `node tests/fixtures/generate-fixtures.js`
3. `bash scripts/bundle-dashboard.sh`
4. `bash scripts/build-dashboard.sh`
5. `bash scripts/minify-dashboard.sh`
6. `bash scripts/generate-header.sh`
7. `python3 scripts/render_sensor_config.py --check`

**Acceptance criteria:**

- Template includes exactly one `{{JS_PLACEHOLDER}}` marker.
- `build-dashboard.sh` produces byte-identical `dashboard.html` vs. baseline.
- `dashboard.h` remains byte-identical.
- All Playwright tests pass.
- Real-device validation: dashboard still loads and behaves identically on actual hardware.

---

### 6.4 v7.6.5.3 — Make template-based build canonical (Level 2, step 2)

**Goal:** Fully switch to template-based generation for `dashboard.html` and `dashboard.h`, while keeping `dashboard.html` in version control as a generated artifact.

**Scope:**

- Update all regeneration scripts (including `bump-version.sh`) and documentation so that `bundle-dashboard.sh` + `build-dashboard.sh` is the only supported way to regenerate `dashboard.html`.
- Remove any remaining instructions that tell contributors to edit `dashboard.html` directly.
- Ensure `minify-dashboard.sh` always consumes the generated `dashboard.html`.

**Acceptance criteria:**

- `bump-version.sh` uses the regeneration pipeline instead of `sed` on `dashboard.html`.
- `preflight.sh` includes checks that `dashboard.html` is newer than or equal to its template and bundle inputs.
- Developers treat `dashboard.html` as generated-only; manual edits are overwritten and guarded by preflight.
- `dashboard.h` remains deterministic (same input produces same header).
- All Playwright tests pass.
- Real-device validation performed after regeneration.

---

### 6.5 v7.6.5.4 — Component scaffolding (Level 3, step 1)

**Goal:** Introduce component and core directories, move modules accordingly, without changing assembled output.

**Scope:**

- Create:
  - `dashboard/components/` with initial component directories: `sensor-cards/`, `charts/`, `settings-panel/`, `custom-range/`, `live-view/`, `gateway-panel/`.
  - `dashboard/core/` for shared runtime modules (config, state, manifest, history, etc.).[cite:3][cite:5]
- Move module files from `dashboard/modules/` into `components/*/index.js` or `core/*.js` according to their functional grouping.
- Update `bundle-dashboard.sh` to read from new locations in an explicit order.

**Ordering constraints:**

- Core modules (util → config → state → manifest → history → status/storage → suspend/resume, etc.) must be ordered so there are no reference-before-definition issues.[cite:5]
- Component modules (e.g., sensor cards, charts, settings panel, live view, gateway panel) follow core modules in the bundle.

**Acceptance criteria:**

- All modules moved; no code remains in `dashboard/modules/`.
- Bundling + build + minify + header generation produces a `dashboard.h` that is still byte-identical to v7.6.5.3.
- All Playwright tests pass.
- Real-device validation shows no behavioral difference.

---

### 6.6 v7.6.5.5 — Component HTML extraction (Level 3, step 2)

**Goal:** Extract per-component HTML templates and compose them into the main template via `{{COMPONENT:name}}` markers.

**Scope:**

- For each major panel/component, create a `template.html` file containing its HTML fragment, guided by the CSS/DOM mapping from the earlier analysis:[cite:3]
  - `components/sensor-cards/template.html` — `#sensorGrid` and related sensor card containers.
  - `components/charts/template.html` — realtime and averages chart sections.
  - `components/settings-panel/template.html` — storage, management, import/export, and settings UI.
  - `components/custom-range/template.html` — custom range modal.
  - `components/live-view/template.html` — live telemetry/cards area.
  - `components/gateway-panel/template.html` — gateways section and aggregator settings.
- Replace each section in `dashboard/dashboard.tmpl.html` with a corresponding `{{COMPONENT:name}}` marker.
- Update `build-dashboard.sh` to perform a first pass that resolves `{{COMPONENT:*}}` markers by inlining component templates before injecting JS.

**Identity gate:**

- As with v7.6.5.2, the fully assembled `dashboard.html` after all passes must be byte-identical to the pre-extraction version.

**Acceptance criteria:**

- All component `template.html` files exist and contain the correct HTML fragments.
- `build-dashboard.sh`’s multi-pass assembly (components, then JS) produces the same `dashboard.html` as before this step.
- `dashboard.h` remains deterministic.
- All Playwright tests pass.
- Real-device validation shows no UI or behavior changes.

---

### 6.7 v7.6.5.6 — Component CSS extraction (Level 3, step 3)

**Goal:** Extract component-scoped CSS into per-component `styles.css` files and global CSS into `core/base.css`, wiring them into the template via `{{CSS:name}}` markers, without changing rendered appearance.

**Scope:**

- Move CSS blocks from `dashboard/dashboard.tmpl.html` into:
  - `core/base.css` — global tokens (`:root`, theme variables, body, scrollbars, etc.).
  - `components/*/styles.css` — selectors specific to each component (e.g., `.sensor-card` into `sensor-cards/styles.css`, `.network-card` and `.system-card` into `sensor-cards/styles.css`, `.cr-*` into `custom-range/styles.css`, etc.).[cite:3]
- Replace inlined CSS in the template with `{{CSS:name}}` markers.
- Extend `build-dashboard.sh` to:
  - Pass 0: resolve `{{CSS:*}}` markers by inlining CSS files.
  - Pass 1: resolve `{{COMPONENT:*}}` templates.
  - Pass 2: inject JS at `{{JS_PLACEHOLDER}}`.

**Constraints:**

- Preserve all dark/light mode and `color-scheme` behavior from LESSON-OPS-065 when moving CSS for native widgets (`<input type=date>`, `<select>`).[cite:2]
- Do not change the CSS cascade in a way that alters visual layout; if a rule effectively spans components, keep it in `core/base.css`.

**Acceptance criteria:**

- Multi-pass assembly produces the same `dashboard.html` as before extraction (or differences limited to harmless formatting that do not affect minified output or `dashboard.h`).
- `dashboard.h` remains deterministic.
- Visual regression: screenshots before and after v7.6.5.6 show no visual differences.
- All Playwright tests pass.
- Real-device validation confirms identical appearance and behavior.

---

### 6.8 v7.6.5.7 — Phase X closure: tests, preflight, documentation

**Goal:** Add build-pipeline tests and preflight checks that lock in the new architecture, update docs, and declare Phase X complete.

**Scope:**

- Add new Playwright tests (e.g., Group 19) that:
  - Assert that `{{JS_PLACEHOLDER}}` and `{{COMPONENT:*}}` markers are not present in the served `dashboard.html`.
  - Verify that component `index.js`, `template.html`, and `styles.css` files exist on disk.
  - Optionally exercise a small number of interactions that prove the assembled pipeline is working (e.g., open settings panel, open custom range modal).
- Extend `preflight.sh` with:
  - Component existence checks.
  - A check that `bump-version.sh` uses the regeneration pipeline instead of editing `dashboard.html` directly.
- Update documentation:
  - `Docs/bugs-and-lessons-learned.md` with a short note that Phase X structurally resolves the LESSON-OPS-043 class of issues.
  - `Docs/aggregator-setup.md` and any developer workflow docs with the full, final regeneration pipeline.

**Acceptance criteria:**

- All Playwright test groups (including the new build-pipeline tests) pass for all fixture variants.
- `preflight.sh` passes, including new component existence and pipeline checks.
- `dashboard.html` remains a committed, generated artifact; `git status` is clean after a full regeneration on a clean checkout.
- At least one subsequent feature or bugfix PR successfully uses the new architecture without any LESSON-OPS-043-type drift.

---

## 7. Migration safety rules (all versions)

These rules apply to every Phase X step:

1. **No behavior changes inside refactor steps**  
   - Phase X steps must only reorganize code and build pipelines. Any functional change (bugfix or feature) must be a separate PR, to keep diff review manageable and reduce risk.

2. **Playwright is a hard gate**  
   - All existing Playwright groups and fixture variants must remain green. No tests may be deleted or disabled to force a refactor to pass.[cite:2]

3. **`dashboard.h` determinism**  
   - For each step, a given set of inputs (template, modules, build scripts) must produce the same `dashboard.h`. Changes to the pipeline must be justified and reflected in the plan.

4. **Real-device validation (LESSON-OPS-051)**  
   - Any step that touches dashboard JS, HTML, or build artifacts must be validated on actual hardware with the dashboard open (S3 aggregator and at least one satellite).[cite:2]

5. **Aggregator overlay semantics (LESSON-OPS-074)**  
   - The aggregator remains a satellite with aggregation enabled. `App.Boot.start` must continue to run the full satellite pipeline and then overlay aggregator UI; no forked boot path is allowed.[cite:2]

6. **History and POST semantics (LESSON-OPS-052, -099)**  
   - History-fetching code must stay sequential and guarded; no reintroduction of concurrency or `Promise.all` for history endpoints.[cite:2]
   - All dashboard POSTs continue to use `application/x-www-form-urlencoded` and existing parameter schemes; Phase X may not introduce JSON POST bodies or change management endpoint contracts.[cite:2]

7. **Generated artifacts are source-adjacent but not primary sources**  
   - After Level 2, contributors edit modules, components, and templates — not `dashboard.html`. Preflight and CI enforce sync between sources and generated artifacts.

8. **Each step is revertable**  
   - The plan is structured so that each version can be reverted without entangling subsequent steps, following the pattern established in previous phases.[cite:1][cite:5]

---

## 8. What this changes for future work

After Phase X:

- A typical dashboard change should require reading:
  - one component directory (`index.js`, `template.html`, `styles.css`),
  - one or two `dashboard/core/*.js` files for shared state/transport,
  - and the relevant tests.
- Coding-agent prompts can point at specific components instead of the entire monolithic dashboard.
- The LESSON-OPS-043 class of JS/HTML drift bugs is structurally eliminated: JS is defined in one place, and HTML is generated from a template plus that JS.[cite:2][cite:3][cite:5]
- The regeneration pipeline is explicit, deterministic, and enforced by CI and preflight, mirroring the level of rigor already applied to other generated artifacts in the repo.[cite:1][cite:2]

_Phase X is complete when all versions `v7.6.5.0–v7.6.5.7` are implemented as described above, all acceptance criteria are met, and subsequent work in Phase E can target individual components without revisiting dashboard architecture fundamentals._
