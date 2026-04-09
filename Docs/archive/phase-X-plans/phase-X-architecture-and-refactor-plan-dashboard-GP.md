# Phase X — Dashboard Architecture and Refactor Plan (`v7.6.5.0`–`v7.6.5.5`)

**Phase:** Phase X — Post-Phase D dashboard architecture refactor  
**Version range:** `v7.6.5.0`–`v7.6.5.5`  
**Status:** Planning only — not yet implemented  
**Repository:** `GCV-Sleeper-Service/ESP32-GW-multi-sensor`  
**Primary artifacts reviewed:** `Docs/phase-d-implementation-plan.md`, `dashboard/dashboard.js`, `dashboard/dashboard.html`, `scripts/minify-dashboard.sh`, `scripts/generate-header.sh`, `Docs/bugs-and-lessons-learned.md` (especially `LESSON-OPS-043`, `LESSON-OPS-052`, `LESSON-OPS-065`, `LESSON-OPS-074`, `LESSON-OPS-099`)

---

## Goal

Refactor the dashboard architecture without changing runtime behavior so that:

1. Future coding-agent tasks no longer require loading the entire dashboard monolith.
2. `dashboard.html` stops being a hand-maintained mirror of `dashboard.js`.
3. The dashboard can scale into Phase E and later work through component-level ownership instead of whole-file editing.
4. Existing Playwright coverage remains the non-negotiable regression gate at every step.
5. `dashboard.h` generation stays deterministic and reviewable.

This phase is **structural only**. It is not a feature phase.

---

## Current State Analysis

### 1. Current dashboard assets

| Artifact | Current role | Current problem |
|---|---|---|
| `dashboard/dashboard.js` | Hand-maintained monolithic JavaScript source | Large working-context requirement for any change |
| `dashboard/dashboard.html` | Hand-maintained HTML + CSS + inline JavaScript mirror used to generate `dashboard.h` | Second manual source of truth for the same runtime logic |
| `dashboard/dashboard.min.html` | Optional build artifact | Can become stale and still be picked up by `generate-header.sh` |
| `dashboard/dashboard.h` | Committed gzip-compressed firmware payload | Depends on correct regeneration order |
| `scripts/minify-dashboard.sh` | Minifies `dashboard.html` → `dashboard.min.html` | Operates on HTML only; no JS/module awareness |
| `scripts/generate-header.sh` | Gzip-compresses HTML and emits `dashboard.h` | Auto-prefers stale `.min.html` if present |
| `Docs/bugs-and-lessons-learned.md` | Durable operational memory | Confirms this dashboard pipeline already produced repeated drift/fixup bugs |

### 2. Current JavaScript size and shape

`dashboard/dashboard.js` is currently a **single, large runtime file** containing approximately:

- **~2.4K lines of JavaScript**
- **~100 top-level named functions / function blocks / IIFEs**
- **3 major “pseudo-modules” already embedded inside the monolith**
  - `App.Features`
  - `App.State`
  - `CustomRange`

That is before counting the mirrored inline copy inside `dashboard.html`.

For a typical dashboard change today, a coding agent usually has to read:

- the JS monolith,
- the matching inline script in `dashboard.html`,
- the surrounding HTML/CSS,
- the minify/header scripts,
- and often the relevant Playwright tests.

That pushes practical working context well above the user’s target and is the direct reason the file is difficult to maintain safely.

### 3. Current functional partition inside `dashboard.js`

The file is logically partitioned already, but only by comments and proximity — not by file boundaries.

#### Shared runtime logic

These blocks are used by both satellite and aggregator modes, or are mode-agnostic utilities:

| Area | Representative functions / blocks |
|---|---|
| App namespace and plugin shell | `App.*`, `App.Features`, `logNonFatal()` |
| Connection/config bootstrap | `FILE_FALLBACK_HOST`, `IS_FILE_MODE`, `ESP_HOST`, `TRANSPORT`, `App.Config` wiring |
| State management | `App.State` IIFE, sensor/history/chart state |
| Common helpers | `sensorSlug()`, `formatUtcForExport()`, `formatBytes()`, `esc*()`, `cToF()` |
| Manifest and metadata | `normalizeManifestSensors()`, `applySensorMeta()`, `loadSensorManifest()`, `loadManifestV2()`, `autoPromoteV1ToV2()` |
| Theme/UI utilities | `toggle()`, `toggleTheme()`, `bindEvents()`, debug log helpers |
| Time range / min-max / derived values | `CustomRange`, `calcDewPoint()`, `calcComfortEstimate()`, `updateMinMax()` |
| Card rendering registry | `CARD_RENDERERS`, `buildEnvironmentalCard()`, `buildNetworkCard()`, `buildSystemCard()`, `buildDeviceCards()` |
| Charts | `FREEZING_LINE_PLUGIN`, `tempChartOpts()`, `humChartOpts()`, `telemetryChartOpts()`, `initCharts()`, `updateChartsTheme()` |
| Shared live-card updates | `updateNetworkCards()`, `updateSystemCards()`, `updateUsageBar()`, `_updateSystemCardDOM()` |
| Boot/orchestration shell | `App module export wiring`, `updateBoardInfo()`, `App.Boot.start()` |

#### Satellite-only logic

These blocks are meaningful only for the local gateway / standard dashboard path:

| Area | Representative functions / blocks |
|---|---|
| Local status + telemetry | `applyStatusSnapshot()`, `loadStatusSnapshot()`, `updateTelemetry()`, `pushTelemetry()` |
| Local live entity handling | `handleState()`, `updateBattery()`, `updateRSSI()`, `updateDewPoint()`, `updateComfortLevel()` |
| SSE + polling transport | `connectSSE()`, `pollEntity()`, `pollAll()`, `startPolling()` |
| Storage stats | `applyStorageStats()`, `loadStorageStats()` |
| History loading | `parseCompactHistory()`, `loadHistory()`, `fetchSensorHistoryRows()` |
| CSV export | `getGatewayExportMeta()`, `buildSingleSensorCsv()`, `buildMergedSensorCsv()`, `exportSensorCSV()`, `exportAllCSV()` |
| Management/auth/import | `requestManagementCredentials()`, `postManagementAction()`, `rebootESP()`, `deleteHistoryData()`, `importHistoryData()`, `processImportFile()`, `parseImportCsv()`, `detectImportColumns()`, `buildImportSegments()`, `executeImport()` |

#### Aggregator-only logic

These blocks are only used when aggregator capability is present:

| Area | Representative functions / blocks |
|---|---|
| Aggregator mode detection | `detectAggregatorMode()` |
| Gateway tab / summary rendering | `renderGatewaySelector()`, `renderAllGatewaysSummary()` |
| Remote gateway device rendering | `renderGatewayDevices()`, `_populateGatewayDeviceLive()` |
| Aggregator settings screen | `renderSettingsPanel()` |
| Aggregator poll loop | `pollAggregatorLive()`, `initAggregatorDashboard()` |
| Aggregator view state | `_currentGwId`, `_currentGwSensors`, `_aggLiveInFlight`, `_aggDeviceLiveInFlight` |

#### Cross-cutting architectural problem

Several functions are **shared in name but contain aggregator-only branches** inside otherwise general code. The biggest examples are:

- `fetchDeviceHistory()` — shared helper with local and proxy-history branches
- `buildDeviceCards()` — shared registry but used in very different local/remote contexts
- `App.Boot.start()` — shared boot pipeline with aggregator overlay
- `pollV2Live()` / live-card updates — shared local network/system flow plus aggregator equivalents

These mixed-responsibility blocks are one of the reasons the monolith is hard to split safely unless file boundaries are deliberate.

### 4. Current CSS partition inside `dashboard.html`

The CSS is also monolithic, but it already has feature groupings that can be mapped directly to Level 3 components.

| CSS block / selector family | Feature ownership |
|---|---|
| `:root`, `body`, `.header`, `.status-*`, `.about-bar`, `.error-banner` | Global shell / app chrome |
| `.collapse-*` | Shared collapsible-section system |
| `.top-grid`, `.gateway-*`, `.device-info-*`, `.compact-*` | Gateway top area and management/documentation cards |
| `.storage-*` | History storage panel |
| `.credits-*` | Credits block |
| `.gpio-*` | GPIO / board-info panel |
| `.telemetry-*` | Telemetry panel |
| `.sensor-*`, `.reading-*`, `.sensor-minmax`, `.sensor-batt-*` | Environmental sensor cards |
| `.sensor-rssi-*`, `.dewpoint-*`, `.comfort-*`, `.sensor-env-*`, `.sensor-color-picker` | Sensor-card subfeatures |
| `.network-card`, `.system-card`, `.system-*` | Non-environmental device cards |
| `.charts-row`, `.chart-*`, `.history-*`, `.refresh-btn` | Realtime and retained-history chart panels |
| `.export-*` | Export history panel |
| `.footer`, `.debug-*` | Footer and debug log |
| `.auth-*` | Management auth modal |
| `.cr-*` | Custom date range modal |
| `:root.light ...`, `.theme-toggle` | Theme system |
| `@media (...)` | Responsive layout rules |
| `.gw-*`, `.settings-*` | Aggregator-only gateway selector, summary, and settings UI |

This mapping is useful because Level 3 should not invent component boundaries from scratch; it should follow the boundaries the CSS and DOM already imply.

### 5. Current build pipeline

Current pipeline is:

```text
dashboard/dashboard.html
  └─(optional) scripts/minify-dashboard.sh
        └─ dashboard/dashboard.min.html
              └─ scripts/generate-header.sh
                    └─ gzip-compressed dashboard/dashboard.h
```

#### What `minify-dashboard.sh` does today

- Takes `dashboard/dashboard.html` as input by default.
- Produces `dashboard/dashboard.min.html`.
- Minifies:
  - HTML
  - inline CSS
  - inline JS

#### What `generate-header.sh` does today

- Takes `dashboard/dashboard.html` as default input.
- If **no explicit input argument** is passed and `dashboard/dashboard.min.html` exists, it silently auto-selects that file instead.
- Gzip-compresses the HTML payload.
- Emits `dashboard/dashboard.h` as a C byte array.

#### Structural weaknesses in the current pipeline

1. **The true source of truth is not obvious**
   - `LESSON-OPS-043` says `dashboard.html` is the source of truth for embedded payload generation.
   - In practice, engineers also edit `dashboard.js`.
   - That creates two manual edit surfaces for one runtime.

2. **The minified intermediate can go stale**
   - `generate-header.sh` auto-prefers `.min.html`.
   - If `.min.html` is stale, the embedded firmware can lag behind the edited source.

3. **The pipeline has no JS assembly layer**
   - There is no supported way to split JS into source modules and reassemble them.
   - Any refactor must currently happen directly in the monolith.

### 6. Why `LESSON-OPS-043` exists, and what eliminates it

`LESSON-OPS-043` exists because the project currently keeps:

- a manually maintained runtime in `dashboard/dashboard.js`, and
- a second manually maintained inline copy of that runtime inside `dashboard/dashboard.html`.

That guarantees one of these failure modes will keep recurring:

1. a fix lands in `dashboard.js` only,
2. a fix lands in `dashboard.html` only,
3. `dashboard.min.html` stays stale,
4. `dashboard.h` is regenerated from the wrong upstream artifact,
5. review diff looks correct in one file while firmware still embeds the old one.

This is exactly the class of drift that produced `BUG-039` and the mirror-related rules around `LESSON-OPS-043`.

**The structural fix is not “be more careful.”**  
The structural fix is:

- one canonical JS source tree,
- one canonical HTML template,
- one deterministic build that injects JS into HTML,
- one deterministic gzip/header generation step,
- and a preflight gate that proves the generated artifacts match source.

That is the purpose of **Level 2**.

---

## Migration Safety Rules

These rules apply to **every** `v7.6.5.x` step.

- **No behavior changes.**  
  Structural reorganization only. Same endpoints, same DOM behavior, same chart behavior, same management-action behavior, same transport behavior.

- **All existing Playwright tests must pass after each step.**  
  This is the hard gate for merge readiness at each sub-step.

- **The generated dashboard payload must remain deterministic.**  
  Especially during Level 2, `dashboard.h` output must be compared against the pre-change baseline.

- **Each step must be independently revertable.**  
  No step may require “finish the next step first” to get back to a healthy branch.

- **No bundler-heavy toolchain jump.**  
  Prefer deterministic shell/Python assembly over introducing Webpack/Vite/Rollup complexity during this phase.

- **Keep committed generated artifacts.**  
  `dashboard.js`, `dashboard.html`, and `dashboard.h` may remain committed outputs for reviewability, even after their source-of-truth status changes.

- **Do not break existing Playwright tests.**  
  This gate must be written into every implementation prompt and every PR acceptance checklist for this phase.

---

## Proposed File Structure

### Before (current)

```text
dashboard/
  dashboard.js
  dashboard.html
  dashboard.h
scripts/
  minify-dashboard.sh
  generate-header.sh
```

### After Level 1 — Module split (`v7.6.5.0`–`v7.6.5.1`)

```text
dashboard/
  src/
    00-app-shell.js
    01-config-transport.js
    02-state.js
    03-utils-formatters.js
    04-manifest.js
    05-ui-helpers.js
    06-theme-events.js
    07-custom-range.js
    08-management-import-export.js
    09-card-renderers.js
    10-charts.js
    11-history-status.js
    12-sse-polling.js
    13-aggregator.js
    14-boot.js
  dashboard.js              # generated bundle, committed
  dashboard.html            # still manual at Level 1
  dashboard.h               # generated, committed
scripts/
  build-dashboard-js.sh     # new deterministic concatenation step
  minify-dashboard.sh
  generate-header.sh
```

### After Level 2 — Generated HTML (`v7.6.5.2`–`v7.6.5.3`)

```text
dashboard/
  src/
    ... module files ...
  dashboard.tmpl.html       # canonical HTML/CSS template
  dashboard.js              # generated bundle, committed
  dashboard.html            # generated from template + JS, committed
  dashboard.h               # generated gzip payload, committed
scripts/
  build-dashboard-js.sh
  build-dashboard-html.sh   # new: injects JS into template
  minify-dashboard.sh       # now orchestrates build-js + build-html + minify
  generate-header.sh        # now consumes generated html/min.html only
```

### After Level 3 — Component model (`v7.6.5.4`–`v7.6.5.5`)

```text
dashboard/
  app/
    main.js
    registry.js
    state.js
    transport.js
    charts.js
    manifest.js
  components/
    app-shell/
      template.html
      styles.css
      index.js
    gateway-top/
      template.html
      styles.css
      index.js
    storage-panel/
      template.html
      styles.css
      index.js
    telemetry-panel/
      template.html
      styles.css
      index.js
    gateways-panel/
      template.html
      styles.css
      index.js
    sensor-cards/
      template.html
      styles.css
      index.js
    realtime-charts/
      template.html
      styles.css
      index.js
    averages-panel/
      template.html
      styles.css
      index.js
    export-panel/
      template.html
      styles.css
      index.js
    auth-modal/
      template.html
      styles.css
      index.js
    custom-range-modal/
      template.html
      styles.css
      index.js
  dashboard.tmpl.html       # shell template with slots/placeholders
  dashboard.js              # generated assembled runtime, committed
  dashboard.html            # generated assembled HTML, committed
  dashboard.h               # generated gzip payload, committed
scripts/
  build-dashboard-js.sh     # evolves into component-aware assembler or delegates to new assembler
  build-dashboard-html.sh
  build-dashboard-components.sh
  minify-dashboard.sh
  generate-header.sh
```

---

## Refactor Principles

1. **Source-of-truth count must move from two to one.**
2. **File boundaries should follow feature ownership, not only technical layers.**
3. **Generated outputs stay reviewable and committed.**
4. **Build order must be explicit and deterministic.**
5. **Playwright remains the release gate; no “trust the refactor” merges.**
6. **Component boundaries must match actual CSS/DOM/runtime seams already present in the codebase.**
7. **The build system must stay simple enough for this repo’s operator workflow.**

---

## Version Number Mapping

| Version | Level | Step name | Primary outcome |
|---|---|---|---|
| `v7.6.5.0` | Level 1 | JS bundle scaffold and drift guardrails | Introduce module assembly path without changing runtime output |
| `v7.6.5.1` | Level 1 | Split dashboard monolith into focused source modules | Reduce coding-agent working context immediately |
| `v7.6.5.2` | Level 2 | Introduce HTML template + generated HTML in parallel | Prove generated HTML is equivalent before switching workflow |
| `v7.6.5.3` | Level 2 | Make generated HTML canonical and retire manual mirror workflow | Eliminate `LESSON-OPS-043` class failures |
| `v7.6.5.4` | Level 3 | Introduce component assembler and panel contracts | Establish scalable component model without changing UI |
| `v7.6.5.5` | Level 3 | Migrate panel/features into component directories | Future work can target one component at a time |

---

## Detailed Implementation Steps

### `v7.6.5.0` — JS bundle scaffold and drift guardrails

**Level:** Level 1 — Module split  
**Goal:** Introduce a deterministic JS assembly step before doing any real split, so the repo has a safe landing zone.

#### Scope

- Add a canonical JS assembly script.
- Keep runtime behavior unchanged.
- Keep `dashboard.html` manual for now.
- Create “write” and “check” modes so generated JS can be validated in preflight.

#### Files modified

| File | Change |
|---|---|
| `scripts/build-dashboard-js.sh` | New deterministic concatenation/check script |
| `dashboard/src/00-app-shell.js` | New seed module containing current monolith content initially |
| `dashboard/dashboard.js` | Becomes generated artifact written by the new script |
| `scripts/minify-dashboard.sh` | Invoke `build-dashboard-js.sh --check` or `--write` before minification |
| `Docs/bugs-and-lessons-learned.md` | Add new lesson only if implementation exposes new operational rule |
| `scripts/preflight.sh` | Add `dashboard_js_generated_sync` check |

#### Implementation details

- Start with **one source module** that reproduces the current monolith exactly.
- Do **not** split logic yet in this step.
- The purpose is to prove:
  - the repository can generate `dashboard/dashboard.js`,
  - the generated bundle is deterministic,
  - preflight can detect bundle drift before HTML/header generation.

#### Acceptance criteria

- [ ] `scripts/build-dashboard-js.sh --write` regenerates `dashboard/dashboard.js`
- [ ] `scripts/build-dashboard-js.sh --check` passes on a clean tree
- [ ] `dashboard/dashboard.js` runtime behavior is unchanged
- [ ] Existing Playwright tests pass unchanged
- [ ] Existing `dashboard.h` output remains unchanged after normal regeneration
- [ ] Step is independently revertable
- [ ] Explicit implementation gate: **do not break existing Playwright tests**

#### Risk rating

**Low**

This step adds scaffolding only and does not yet restructure runtime logic.

#### Estimated effort

**0.5–1 day**

#### Estimated coding-agent working context

**~10K–15K tokens**  
The step is mostly build-script and file-ownership setup.

---

### `v7.6.5.1` — Split dashboard monolith into focused source modules

**Level:** Level 1 — Module split  
**Goal:** Reduce dashboard task size immediately by splitting the monolith into module files sized for coding-agent work.

#### Scope

- Split the current monolith into ordered source files.
- Keep `dashboard/dashboard.js` as the generated assembled bundle.
- Keep `dashboard.html` manual until Level 2.

#### Proposed module boundaries

| Module | Approx target size | Content |
|---|---:|---|
| `00-app-shell.js` | 100–200 lines | `App` namespace, plugin shell, error logger |
| `01-config-transport.js` | 150–250 lines | host/transport detection, config wiring |
| `02-state.js` | 150–250 lines | `App.State`, shared globals, history range state |
| `03-utils-formatters.js` | 200–350 lines | formatting, CSV helpers, export helpers, metric formatters |
| `04-manifest.js` | 200–350 lines | manifest parsing, v1/v2 loading, sensor meta application |
| `05-ui-helpers.js` | 150–300 lines | debug log, errors, toggle helpers, board/status helpers |
| `06-theme-events.js` | 150–300 lines | theme handling, event binding, color-picker behavior |
| `07-custom-range.js` | 250–400 lines | `CustomRange` modal and range application |
| `08-management-import-export.js` | 300–400 lines | auth modal, management actions, CSV import/export |
| `09-card-renderers.js` | 250–400 lines | renderer registry, environmental/network/system cards |
| `10-charts.js` | 250–400 lines | chart options, init, theme, redraw helpers |
| `11-history-status.js` | 250–400 lines | storage stats, history parsing/loading, telemetry/status |
| `12-sse-polling.js` | 200–350 lines | SSE, polling, state handling |
| `13-aggregator.js` | 250–400 lines | aggregator detection, tab rendering, remote live updates |
| `14-boot.js` | 150–250 lines | module exports, boot orchestration, DOMContentLoaded |

#### Files modified

| File | Change |
|---|---|
| `dashboard/src/*.js` | New ordered source modules |
| `scripts/build-dashboard-js.sh` | Updated ordered concatenation manifest |
| `dashboard/dashboard.js` | Generated from source modules |
| `scripts/minify-dashboard.sh` | Runs JS build first, then HTML minification |
| `scripts/preflight.sh` | Add check that source modules rebuild current `dashboard.js` |

#### Implementation details

- Concatenation order must be explicit and stable.
- Avoid semantic refactors in this step.
- Keep global names unchanged to minimize risk.
- Do not change DOM IDs, chart config, transport selection, or management flow.
- Where a function spans multiple concerns, keep it in the module that owns the highest-risk behavior for now; deeper separation happens in Level 3.

#### Acceptance criteria

- [ ] Each module file is approximately 200–400 lines where practical
- [ ] `dashboard/dashboard.js` is generated, not hand-edited
- [ ] Existing runtime behavior is unchanged
- [ ] Existing Playwright tests pass unchanged
- [ ] No change to current embedded dashboard behavior after regeneration
- [ ] Step is independently revertable
- [ ] Explicit implementation gate: **do not break existing Playwright tests**

#### Risk rating

**Medium**

Behavior is supposed to stay identical, but function movement increases copy/paste and ordering risk.

#### Estimated effort

**1.5–2.5 days**

#### Estimated coding-agent working context after this step

**Typical feature task: ~12K–22K tokens**  
A future agent usually needs:

- one target module,
- one nearby shared module,
- one test file,
- maybe the build script order.

That is a substantial improvement from today.

---

### `v7.6.5.2` — Introduce HTML template + generated HTML in parallel

**Level:** Level 2 — Generated HTML  
**Goal:** Add a canonical template and generated HTML path without immediately removing the existing workflow.

#### Scope

- Introduce `dashboard/dashboard.tmpl.html`.
- Add `{{JS_PLACEHOLDER}}` marker.
- Generate `dashboard/dashboard.html` from template + generated JS.
- Keep old and new outputs comparable during this step.
- Add the **bit-for-bit equivalence gate** before switching workflows.

#### Files modified

| File | Change |
|---|---|
| `dashboard/dashboard.tmpl.html` | New canonical HTML/CSS template with `{{JS_PLACEHOLDER}}` |
| `scripts/build-dashboard-html.sh` | New HTML generation script |
| `dashboard/dashboard.html` | Generated output from template + `dashboard.js` |
| `scripts/minify-dashboard.sh` | Run JS build, then HTML generation, then minify |
| `scripts/generate-header.sh` | Add clearer provenance comments and input validation |
| `scripts/preflight.sh` | Add `dashboard_html_generated_sync` and equivalence checks |

#### Implementation details

- `dashboard/dashboard.tmpl.html` contains:
  - full HTML structure,
  - full CSS,
  - a single `{{JS_PLACEHOLDER}}` token inside the `<script>` block location.
- `scripts/build-dashboard-html.sh` injects built JS into that slot and writes `dashboard/dashboard.html`.
- During this step, implementation must **prove** the generated output is equivalent to the currently committed runtime output.
- The safest equivalence check is:
  1. regenerate old-path output,
  2. regenerate new-path output,
  3. compare resulting `dashboard.html`,
  4. minify both,
  5. compare resulting `dashboard.h` bytes or SHA-256 digests.

#### Acceptance criteria

- [ ] `dashboard/dashboard.tmpl.html` is the only hand-edited HTML source
- [ ] `dashboard/dashboard.html` is generated from template + built JS
- [ ] Generated `dashboard.html` matches the pre-switch runtime output
- [ ] Generated `dashboard.h` is **bit-for-bit identical** to the baseline payload before the workflow switch
- [ ] Existing Playwright tests pass unchanged
- [ ] Step is independently revertable
- [ ] Explicit implementation gate: **do not break existing Playwright tests**

#### Risk rating

**Medium**

This is the first source-of-truth change, but it is still gated by output equivalence.

#### Estimated effort

**1–2 days**

#### Estimated coding-agent working context after this step

**Typical feature task: ~10K–18K tokens**

At this point a feature change no longer requires reading both `dashboard.js` and the inline mirror inside `dashboard.html`.

---

### `v7.6.5.3` — Make generated HTML canonical and retire manual mirror workflow

**Level:** Level 2 — Generated HTML  
**Goal:** Finish the Level 2 source-of-truth shift and permanently eliminate manual JS/HTML mirroring.

#### Scope

- Make generated `dashboard.html` the only supported output.
- Update script comments and operator workflow docs.
- Remove wording that tells contributors to edit `dashboard.html` directly.
- Lock in the preflight rule that prevents manual drift.

#### Files modified

| File | Change |
|---|---|
| `scripts/minify-dashboard.sh` | Treat generated `dashboard.html` as input only |
| `scripts/generate-header.sh` | Update comments: source is template + modules, not hand-edited `dashboard.html` |
| `dashboard/dashboard.html` | Generated and committed only |
| `Docs/bugs-and-lessons-learned.md` | Add durable lesson describing the new canonical pipeline |
| `scripts/preflight.sh` | Fail if generated HTML or JS are out of sync |

#### Implementation details

- After this step, the canonical source chain becomes:

```text
dashboard/src/*.js
  └─ build-dashboard-js.sh
dashboard/dashboard.tmpl.html
  └─ build-dashboard-html.sh
dashboard/dashboard.html
  └─ minify-dashboard.sh
dashboard/dashboard.min.html
  └─ generate-header.sh
dashboard/dashboard.h
```

- Any instructions that say “edit `dashboard/dashboard.html`” must be replaced with:
  - edit modules,
  - edit template,
  - regenerate outputs.

#### Acceptance criteria

- [ ] No contributor workflow depends on hand-editing `dashboard/dashboard.html`
- [ ] Preflight fails if `dashboard.js` or `dashboard.html` are stale
- [ ] Existing Playwright tests pass unchanged
- [ ] Regenerated `dashboard.h` remains deterministic
- [ ] Step is independently revertable
- [ ] Explicit implementation gate: **do not break existing Playwright tests**

#### Risk rating

**Low–Medium**

Lower than `v7.6.5.2`, because the risky equivalence proof has already been completed.

#### Estimated effort

**0.5–1 day**

#### Estimated coding-agent working context after this step

**Typical feature task: ~8K–16K tokens**

This is the step that permanently removes the `LESSON-OPS-043` class of bug.

---

### `v7.6.5.4` — Introduce component assembler and panel contracts

**Level:** Level 3 — Component model  
**Goal:** Establish component directories and a deterministic assembly contract before moving full feature implementations.

#### Scope

- Introduce component directory structure.
- Introduce assembler script(s).
- Migrate only shell-level composition first.
- Keep behavior identical.

#### Files modified

| File | Change |
|---|---|
| `dashboard/components/*` | New component directories with `template.html`, `styles.css`, `index.js` |
| `dashboard/app/main.js` | New orchestration entrypoint |
| `dashboard/app/registry.js` | Component registration/composition order |
| `scripts/build-dashboard-components.sh` | New component assembler |
| `scripts/build-dashboard-js.sh` | Updated to assemble component JS in deterministic order |
| `scripts/build-dashboard-html.sh` | Updated to assemble component HTML/CSS into template shell |

#### Implementation details

- Do **not** fully migrate all feature logic in one jump.
- First move shell ownership and composition boundaries:
  - top shell,
  - panel insertion order,
  - shared CSS ordering,
  - component registration contract.
- Keep global runtime wiring stable until `v7.6.5.5`.

#### Acceptance criteria

- [ ] Component directory structure exists and assembles deterministically
- [ ] Component order is explicit in one registry file
- [ ] Existing dashboard output behavior is unchanged
- [ ] Existing Playwright tests pass unchanged
- [ ] Step is independently revertable
- [ ] Explicit implementation gate: **do not break existing Playwright tests**

#### Risk rating

**Medium**

The assembly contract changes, but most feature logic is still intact.

#### Estimated effort

**1–2 days**

#### Estimated coding-agent working context

**Refactor step itself: ~18K–28K tokens**  
This is the heaviest orchestration step in the phase.

---

### `v7.6.5.5` — Migrate panels/features into component directories

**Level:** Level 3 — Component model  
**Goal:** Finish the architectural shift so future feature work can target one component directory plus the orchestration entry point.

#### Scope

- Move each major panel/feature into a self-contained component directory.
- Extract per-component template/CSS/JS ownership.
- Keep assembled outputs committed.

#### Initial component target list

| Component | Source ownership moved out of monolith |
|---|---|
| `app-shell` | header, footer, status, global shell |
| `gateway-top` | device info, management, docs, gpio |
| `storage-panel` | storage stats card |
| `telemetry-panel` | telemetry chart card |
| `gateways-panel` | aggregator selector + summaries + settings |
| `sensor-cards` | environmental/network/system card rendering |
| `realtime-charts` | realtime charts |
| `averages-panel` | 15-minute retained-history charts |
| `export-panel` | export controls |
| `auth-modal` | management auth modal |
| `custom-range-modal` | custom range modal |

#### Files modified

| File | Change |
|---|---|
| `dashboard/components/*/*` | Real feature migration |
| `dashboard/app/main.js` | Runtime orchestration of components |
| `dashboard/app/state.js` | Shared contracts used by components |
| `scripts/build-dashboard-components.sh` | Final component assembly behavior |
| `dashboard/dashboard.js` | Generated assembled runtime |
| `dashboard/dashboard.html` | Generated assembled HTML |

#### Acceptance criteria

- [ ] Each panel/feature lives in a self-contained component directory
- [ ] A future feature change can normally be done by reading one component plus shared orchestration/state
- [ ] Existing Playwright tests pass unchanged
- [ ] Assembled `dashboard.html` and `dashboard.h` remain deterministic
- [ ] Step is independently revertable
- [ ] Explicit implementation gate: **do not break existing Playwright tests**

#### Risk rating

**Medium–High**

This step touches many files, but by now the build pipeline and source-of-truth model are already stable.

#### Estimated effort

**2–3 days**

#### Estimated coding-agent working context after this step

**Typical future feature task: ~6K–15K tokens**

That is the target end-state for Phase E and beyond.

---

## Build Pipeline Changes

### Current pipeline

```text
dashboard.html
  └─ minify-dashboard.sh
      └─ dashboard.min.html
          └─ generate-header.sh
              └─ dashboard.h
```

### Level 1 pipeline

```text
dashboard/src/*.js
  └─ build-dashboard-js.sh
      └─ dashboard.js

dashboard.html
  └─ minify-dashboard.sh   # still minifies manual html
      └─ dashboard.min.html
          └─ generate-header.sh
              └─ dashboard.h
```

#### `minify-dashboard.sh` changes in Level 1

- Before minifying HTML, run or validate JS assembly.
- Add either:
  - `scripts/build-dashboard-js.sh --check`, or
  - `scripts/build-dashboard-js.sh --write` followed by a clean-tree expectation.

Recommended shape:

```bash
# Level 1 addition inside minify-dashboard.sh
"$ROOT/scripts/build-dashboard-js.sh" --check
html-minifier-terser ... "$INPUT"
```

#### `generate-header.sh` changes in Level 1

- No payload-format change.
- Keep gzip generation unchanged.
- Optional improvement: fail loudly if input is older than source JS/template inputs once those exist.

### Level 2 pipeline

```text
dashboard/src/*.js
  └─ build-dashboard-js.sh
      └─ dashboard.js

dashboard/dashboard.tmpl.html + dashboard.js
  └─ build-dashboard-html.sh
      └─ dashboard.html
          └─ minify-dashboard.sh
              └─ dashboard.min.html
                  └─ generate-header.sh
                      └─ dashboard.h
```

#### `minify-dashboard.sh` changes in Level 2

Required behavior:

1. build JS bundle
2. build HTML from template + JS
3. minify generated HTML

Recommended shape:

```bash
"$ROOT/scripts/build-dashboard-js.sh" --write
"$ROOT/scripts/build-dashboard-html.sh" --write
html-minifier-terser ... dashboard/dashboard.html --output dashboard/dashboard.min.html
```

#### `generate-header.sh` changes in Level 2

Required changes:

- Update provenance comments:
  - old: “edit `dashboard/dashboard.html` directly”
  - new: “edit `dashboard/dashboard.tmpl.html` and `dashboard/src/*`”
- Prefer explicit inputs from the pipeline rather than silent fallback ambiguity.
- Add sync checks:
  - fail if `dashboard.html` is older than template or JS bundle,
  - fail if `dashboard.min.html` is older than generated HTML.

Recommended behavior:

```bash
INPUT="${1:-dashboard/dashboard.min.html}"
# fail if generated inputs are stale
# gzip and emit dashboard.h
```

#### Level 2 equivalence gate

Before switching workflow, compare:

```text
old dashboard.h SHA-256 == new dashboard.h SHA-256
```

If not identical, do not proceed to `v7.6.5.3`.

### Level 3 pipeline

```text
dashboard/components/* + dashboard/app/*
  └─ build-dashboard-components.sh
      ├─ assembled css/html fragments
      └─ assembled js fragments
          ├─ build-dashboard-js.sh
          │   └─ dashboard.js
          └─ build-dashboard-html.sh
              └─ dashboard.html
                  └─ minify-dashboard.sh
                      └─ dashboard.min.html
                          └─ generate-header.sh
                              └─ dashboard.h
```

#### `minify-dashboard.sh` changes in Level 3

- No longer knows or cares about individual components.
- It operates only on already assembled `dashboard.html`.
- It remains a minifier, not an assembler.

#### `generate-header.sh` changes in Level 3

- Remains the final gzip/embed stage.
- Comments should reference component/template sources, not generated outputs as editable sources.
- Keep it intentionally simple and deterministic.

---

## Coding-Agent Task Size Analysis

### Baseline — today

A typical non-trivial dashboard task currently requires reading:

- `dashboard/dashboard.js`
- matching inline script in `dashboard/dashboard.html`
- enough surrounding HTML/CSS to avoid breaking the DOM
- relevant build script(s)
- relevant test(s)

**Practical task context today:** **~45K–70K tokens**  
That is precisely the problem this refactor is intended to solve.

### After Level 1

Typical feature-task context becomes:

- one source module (`200–400` lines),
- one neighboring module,
- one test file,
- maybe the assembly order file.

**Expected task context:** **~12K–22K tokens**

### After Level 2

Typical feature-task context becomes:

- one JS module,
- one HTML template region,
- one test file.

The duplicate “read both JS and inline HTML script” requirement disappears.

**Expected task context:** **~8K–18K tokens**

### After Level 3

Typical feature-task context becomes:

- one component directory:
  - `index.js`
  - `template.html`
  - `styles.css`
- one shared state/orchestrator file,
- one test file.

**Expected task context:** **~6K–15K tokens**

### Per-step context estimate

| Version | Expected implementation context |
|---|---:|
| `v7.6.5.0` | ~10K–15K tokens |
| `v7.6.5.1` | ~18K–26K tokens |
| `v7.6.5.2` | ~14K–22K tokens |
| `v7.6.5.3` | ~10K–16K tokens |
| `v7.6.5.4` | ~18K–28K tokens |
| `v7.6.5.5` | ~16K–24K tokens |

---

## Rollout Order

### Recommended order

1. **Level 1 first**
2. **Level 2 second**
3. **Level 3 third**

### Why this order is correct

#### 1. Level 1 first

This gives immediate value with the lowest behavioral risk:

- coding-agent task size drops immediately,
- no HTML source-of-truth change yet,
- easier review diffs,
- easier future prompts.

#### 2. Level 2 second

Only after JS modules are stable should the project remove the JS/HTML mirror.

This is the step that permanently eliminates the `LESSON-OPS-043` / `BUG-039` class of failures.

#### 3. Level 3 third

The component model is the most scalable end-state, but it should land only after:

- JS assembly is already stable,
- generated HTML is already canonical,
- build outputs are already deterministic.

Trying to jump straight to components before Level 2 would combine:

- file split risk,
- build pipeline source-of-truth risk,
- HTML generation risk,
- component assembly risk,

into one large, unnecessary blast radius.

### Gate conditions before moving to the next level

| Move | Required gate |
|---|---|
| Level 1 → Level 2 | JS bundle generation stable; Playwright green; no unexplained output drift |
| Level 2 → Level 3 | Generated `dashboard.html` stable; `dashboard.h` equivalence proved during switch; no manual mirror steps remain |
| Phase X complete | Component assembly stable; future feature can be implemented by touching one component plus orchestration/state only |

---

## Risks and Mitigations

| Risk | Why it matters | Mitigation | Affected versions |
|---|---|---|---|
| Module concatenation order changes behavior | Current monolith relies on declaration order and globals | Freeze explicit ordered manifest in build script; no auto-discovery ordering | `v7.6.5.0`–`v7.6.5.1` |
| A moved function silently loses shared/global dependency | Large monolith uses many ambient globals | Split by existing comment boundaries first; avoid semantic rewrites during split | `v7.6.5.1` |
| Generated HTML differs from hand-maintained HTML | Could change runtime behavior while claiming “structure only” | Bit-for-bit `dashboard.h` equivalence gate before canonical switch | `v7.6.5.2` |
| Stale generated outputs reintroduce drift | Same class of problem in a new form | Add `--check` mode and preflight sync checks for JS + HTML generation | `v7.6.5.0`–`v7.6.5.3` |
| Component extraction changes CSS cascade order | Layout or theme regressions can appear without JS failures | Freeze CSS assembly order centrally; do not auto-sort components | `v7.6.5.4`–`v7.6.5.5` |
| Aggregator logic gets split from shared card/runtime paths incorrectly | Violates `LESSON-OPS-074` and can fork boot/runtime behavior | Keep aggregator as overlay on shared runtime; never split into separate product pipeline | `v7.6.5.1`–`v7.6.5.5` |
| Import/management POST behavior regresses | `LESSON-OPS-099` makes POST handling fragile on this stack | No behavior changes; import/auth code should move intact first, refactor only after green tests | `v7.6.5.1`, `v7.6.5.5` |
| Refactor diff becomes too large for safe review | Structural phases can hide mistakes inside broad churn | Keep six independently reviewable steps; each step revertable | Entire phase |
| Playwright is green but embedded payload changed unexpectedly | Build pipeline may differ even if browser tests pass | Compare generated payload hashes during Level 2 switch | `v7.6.5.2`–`v7.6.5.3` |

---

## What this changes for future implementation prompts

After Phase X:

- a feature prompt should point to one component directory or one module file,
- not to the entire dashboard monolith,
- and not to both `dashboard.js` and `dashboard.html`.

Expected prompt shape after full refactor:

```text
Read:
1. dashboard/components/sensor-cards/index.js
2. dashboard/components/sensor-cards/template.html
3. dashboard/components/sensor-cards/styles.css
4. dashboard/app/state.js
5. relevant Playwright group
```

That is the right scale for future Phase E work.

---

## Final recommendation

Implement this phase exactly in the sequence below:

1. `v7.6.5.0` — bundle scaffold
2. `v7.6.5.1` — module split
3. `v7.6.5.2` — template generation in parallel with equivalence gate
4. `v7.6.5.3` — generated HTML becomes canonical
5. `v7.6.5.4` — component assembler
6. `v7.6.5.5` — component migration

Do **not** skip directly to Level 3.

The highest-value structural fix is **Level 2**, but the safest path to get there is **Level 1 first**.

Level 3 should be treated as the scalability layer that prepares the dashboard for Phase E and beyond — not as the first move.

---

_End of plan._
