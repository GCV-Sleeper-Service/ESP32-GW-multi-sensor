# Phase X — Dashboard Architecture Refactor

_Implementation Plan for v7.6.5.x_
_Date: 2026-04-02_
_Prerequisite: Phase D Complete (v7.6.0.3+ on `main`)_
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

***

## Goal

Refactor the dashboard source structure in three independent, reversible levels so that any future coding-agent task fits within a 30,000-token working context, the manual JS/HTML mirroring requirement (LESSON-OPS-043) is permanently eliminated, and the codebase scales cleanly to Phase E (Captive Portal, v8.0.x) and beyond.

1. **Level 1 — Module Split:** Extract `dashboard.js` monolith into focused module files (~200–400 lines each). No behavior changes. No build-pipeline changes.
2. **Level 2 — Generated HTML:** Make `dashboard.html` a build output, not a hand-maintained file. Eliminates the LESSON-OPS-043 / BUG-039 class of failures permanently.
3. **Level 3 — Component Model:** Each dashboard panel becomes a self-contained directory with its own `index.js`, `styles.css`, and `template.html`. A build script assembles them into the final `dashboard.html` + `.h`.

**Key principle:** Every step produces a `dashboard.h` that is bit-for-bit identical to the one it replaces. The firmware is never touched. All Playwright tests must pass after every sub-step.

***

## Architecture Reference

- `dashboard/dashboard.js` — current monolith (analysed below)
- `dashboard/dashboard.html` — manually-maintained HTML mirror (LESSON-OPS-043)
- `scripts/minify-dashboard.sh` — HTML minification step
- `scripts/generate-header.sh` — gzip-compression + C header embedding
- `Docs/bugs-and-lessons-learned.md` — LESSON-OPS-043, -052, -065, -074, -099

***

## Current State Analysis

### dashboard.js — Monolith Metrics

| Metric | Value |
| :-- | :-- |
| Total lines | ~2,600 lines |
| Top-level `function` declarations | ~85 functions |
| IIFE / module objects | 4 (`App.Features`, `App.State`, `CustomRange`, `CARD_RENDERERS`) |
| Named `var` blocks with significant scope | ~25 |
| Inline `<script>` in `dashboard.html` that must mirror every change | 100% of `dashboard.js` |

### Functional Groups in dashboard.js

| Group | Satellite? | Aggregator? | Shared? | Approx. Lines |
| :-- | :-- | :-- | :-- | :-- |
| Config \& Bootstrap (`App.*` namespace init, `ESP_HOST`, `TRANSPORT`) | ✓ | ✓ | Shared | ~80 |
| `App.State` IIFE (getters/setters) | ✓ | ✓ | Shared | ~80 |
| Sensor Config (`makeSensorConfig`, `applySensorMeta`) | ✓ | ✓ | Shared | ~100 |
| Manifest Loading (`loadSensorManifest`, `loadManifestV2`, `autoPromoteV1ToV2`) | ✓ | ✓ | Shared | ~120 |
| History Fetch (`fetchDeviceHistory`, `loadHistory`, `parseCompactHistory`) | ✓ | ✓ | Shared | ~180 |
| CSV Export (`exportSensorCSV`, `buildSingleSensorCsv`, `triggerCsvDownload`) | ✓ | — | Satellite-primary | ~180 |
| CSV Import (`importHistoryData`, `executeImport`, `buildImportSegments`) | ✓ | — | Satellite-primary | ~350 |
| Sensor Cards (`CARD_RENDERERS`, `buildEnvironmentalCard`, `buildNetworkCard`) | ✓ | ✓ | Shared | ~250 |
| Min/Max (`updateMinMax`, `setMinMaxPeriod`) | ✓ | — | Satellite | ~80 |
| Custom Date Range (`CustomRange` IIFE, calendar) | ✓ | ✓ | Shared | ~260 |
| Charts (`initCharts`, all `*ChartOpts`, theme, `FREEZING_LINE_PLUGIN`) | ✓ | ✓ | Shared | ~220 |
| Live Telemetry (`updateBattery`, `updateTelemetry`, `pushTelemetry`) | ✓ | ✓ | Shared | ~80 |
| Network/System Cards (`updateNetworkCards`, `pollV2Live`) | ✓ | ✓ | Shared | ~100 |
| Transport — SSE (`connectSSE`, `handleState`) | ✓ | ✓ | Shared | ~80 |
| Transport — Polling (`startPolling`, `pollAll`, `delay`) | ✓ | ✓ | Shared | ~80 |
| Status/Storage (`loadStatusSnapshot`, `loadStorageStats`, `applyStorageStats`) | ✓ | ✓ | Shared | ~120 |
| Management (`rebootESP`, `deleteHistoryData`, `requestManagementCredentials`) | ✓ | ✓ | Shared | ~150 |
| Suspend/Resume (`suspendDashboardNetworkActivity`, `importState`) | ✓ | ✓ | Shared | ~100 |
| Helpers/Util (`esc`, `escAttr`, `cToF`, `formatBytes`, `dlog`) | ✓ | ✓ | Shared | ~120 |
| Metric Formatters (`METRIC_FORMATTERS`, `formatMetricValue`) | ✓ | ✓ | Shared | ~80 |
| UI Helpers (`bindEvents`, `toggle`, `toggleTheme`, `setHistoryRange`) | ✓ | ✓ | Shared | ~120 |
| Derived Calculations (`calcDewPoint`, `calcComfortEstimate`, `updateRSSI`) | ✓ | — | Satellite | ~100 |
| Boot Sequence (`App.Boot.start`) | ✓ | ✓ | Shared | ~80 |

### Why LESSON-OPS-043 Exists

`dashboard.html` is a **full copy** of the dashboard HTML with all JavaScript inline in a single `<script>` block. Every code change to `dashboard.js` must be manually mirrored to `dashboard.html`, which is then gzip-compressed into `dashboard.h` via `generate-header.sh`. `dashboard.js` is never served by the firmware — it exists as a developer-readable reference only.

This dual-file maintenance requirement caused fixup commits in every v7.6.0.x PR. LESSON-OPS-049 partially fixed version bumps (via `bump-version.sh` `sed`) but all logic changes remain unautomated. **The structural fix is Level 2:** make `dashboard.html` a build output generated from a template, so `dashboard.js` is the single source of truth for JavaScript.

### Current Build Pipeline

```
dashboard/dashboard.js          (developer edits — JS logic)
dashboard/dashboard.html        (developer edits — manually mirrored HTML)
        │
        ▼  [npm: html-minifier-terser]
dashboard/dashboard.min.html    (build artifact, gitignored)
        │
        ▼  [bash: generate-header.sh → gzip + python3 hex dump]
dashboard/dashboard.h           (committed C header, embedded in firmware)
        │
        ▼  [esphome compile]
firmware binary served at GET /
```

**Key sizes:**

- `dashboard.html` / `dashboard.js` each ~190 KB uncompressed
- `dashboard.min.html` ~90 KB minified
- `dashboard.h` ~45 KB gzipped + hex-encoded (committed)

***

## Proposed File Structure

### Current State (Before Any Refactor)

```
dashboard/
├── dashboard.js           # ← 2,600-line monolith (developer reference)
├── dashboard.html         # ← manually-maintained mirror (THE PROBLEM)
└── dashboard.h            # ← committed build artifact
scripts/
├── minify-dashboard.sh
└── generate-header.sh
```


### After Level 1 — Module Split

```
dashboard/
├── modules/
│   ├── util.js            # ~150 lines — esc, escAttr, cToF, formatBytes, dlog, pad2
│   ├── config.js          # ~150 lines — App.Config, ESP_HOST, TRANSPORT detection
│   ├── state.js           # ~120 lines — App.State IIFE, sensor/history/charts getters
│   ├── manifest.js        # ~200 lines — loadSensorManifest, loadManifestV2, autoPromote
│   ├── history.js         # ~280 lines — fetchDeviceHistory, loadHistory, parseCompact
│   ├── export.js          # ~250 lines — CSV export pipeline, triggerCsvDownload
│   ├── import.js          # ~380 lines — CSV import pipeline, executeImport, buildImportSegments
│   ├── cards.js           # ~320 lines — CARD_RENDERERS, buildEnvironmentalCard, buildNetworkCard
│   ├── charts.js          # ~300 lines — initCharts, chartOpts, theme update, freezingLine plugin
│   ├── transport.js       # ~250 lines — connectSSE, startPolling, pollAll, handleState
│   ├── telemetry.js       # ~150 lines — updateBattery, updateTelemetry, pushTelemetry
│   ├── live-devices.js    # ~150 lines — updateNetworkCards, updateSystemCards, pollV2Live
│   ├── management.js      # ~200 lines — rebootESP, deleteHistoryData, requestManagementCredentials
│   ├── suspend-resume.js  # ~150 lines — importState, suspendDashboard, resumeDashboard
│   ├── custom-range.js    # ~260 lines — CustomRange IIFE (calendar date picker)
│   ├── minmax.js          # ~120 lines — updateMinMax, setMinMaxPeriod
│   ├── sensor-ui.js       # ~180 lines — staleness, RSSI, dewPoint, comfort, bindEvents
│   ├── status-storage.js  # ~150 lines — loadStatusSnapshot, loadStorageStats, applyStorage
│   └── boot.js            # ~80 lines  — App.Boot.start + DOMContentLoaded
├── dashboard.js           # ← NOW an 80-line assembler concat stub
├── dashboard.html         # ← still manually maintained (eliminated in Level 2)
└── dashboard.h            # ← committed build artifact (unchanged)
scripts/
├── bundle-dashboard.sh    # NEW — concatenates modules/ in dependency order → dashboard.js
├── minify-dashboard.sh    # unchanged
└── generate-header.sh     # unchanged
```


### After Level 2 — Generated HTML

```
dashboard/
├── modules/               # ← same as Level 1
│   └── ...
├── dashboard.tmpl.html    # NEW — HTML structure with {{JS_PLACEHOLDER}} marker
├── dashboard.js           # ← regenerated by bundle-dashboard.sh (committed for reference)
├── dashboard.html         # ← BUILD OUTPUT only (gitignored from v7.6.5.3 onward)
└── dashboard.h            # ← committed build artifact (unchanged role)
scripts/
├── bundle-dashboard.sh    # produces dashboard.js from modules/
├── build-dashboard.sh     # NEW — injects dashboard.js into template → dashboard.html
├── minify-dashboard.sh    # unchanged
└── generate-header.sh     # unchanged
```


### After Level 3 — Component Model

```
dashboard/
├── components/
│   ├── sensor-cards/
│   │   ├── index.js        # ~300 lines — environmental/network/system card builders
│   │   ├── styles.css
│   │   └── template.html
│   ├── charts/
│   │   ├── index.js        # ~300 lines — Chart.js init, opts, theme
│   │   ├── styles.css
│   │   └── template.html
│   ├── settings-panel/
│   │   ├── index.js        # ~300 lines — management, import, export, storage
│   │   ├── styles.css
│   │   └── template.html
│   ├── custom-range/
│   │   ├── index.js        # ~260 lines — CustomRange IIFE
│   │   ├── styles.css
│   │   └── template.html
│   ├── live-view/
│   │   ├── index.js        # ~250 lines — SSE/polling, handleState, telemetry
│   │   └── styles.css
│   └── gateway-panel/
│       ├── index.js
│       ├── styles.css
│       └── template.html
├── core/
│   ├── config.js           # App.Config, transport detection
│   ├── state.js            # App.State
│   ├── util.js             # pure helpers
│   ├── boot.js             # App.Boot.start orchestrator
│   ├── manifest.js
│   ├── history.js
│   ├── status-storage.js
│   └── suspend-resume.js
├── dashboard.tmpl.html     # base template (from Level 2)
├── dashboard.js            # assembled by build-dashboard.sh (committed)
├── dashboard.html          # BUILD OUTPUT (gitignored)
└── dashboard.h             # committed C header
scripts/
├── build-dashboard.sh      # assembles components + core → dashboard.js + dashboard.html
├── minify-dashboard.sh     # unchanged
└── generate-header.sh      # unchanged
```


***

## Versioned Steps

### v7.6.5.0 — Establish Module Skeleton (Level 1, Step 1)

**Scope:** Create `dashboard/modules/` and split `dashboard.js` into 19 module files. `dashboard.js` becomes an assembler concat stub (~80 lines). `dashboard.html` is unchanged. `dashboard.h` must be bit-for-bit identical before and after.

**Files modified:**


| Action | File |
| :-- | :-- |
| CREATE dir | `dashboard/modules/` |
| CREATE × 19 | All files under `dashboard/modules/` listed above |
| CREATE | `scripts/bundle-dashboard.sh` |
| MODIFY | `dashboard/dashboard.js` (becomes concat stub referencing module order) |
| NO CHANGE | `dashboard/dashboard.html` |
| NO CHANGE | `dashboard/dashboard.h` |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | All locations to `7.6.5.0` |

**`bundle-dashboard.sh` contract:**

```bash
#!/usr/bin/env bash
# Concatenates dashboard/modules/ in dependency order into dashboard/dashboard.js
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}") /.." && pwd)"
cd "$ROOT"
MODULES=(
  util config state manifest
  history export import
  cards charts transport telemetry
  live-devices management suspend-resume
  custom-range minmax sensor-ui status-storage
  boot
)
OUT="dashboard/dashboard.js"
> "$OUT"
echo "// Auto-generated by bundle-dashboard.sh — edit files in dashboard/modules/ instead" >> "$OUT"
for mod in "${MODULES[@]}"; do
  echo "" >> "$OUT"
  echo "// ── module: $mod ──" >> "$OUT"
  cat "dashboard/modules/${mod}.js" >> "$OUT"
done
echo "Bundled ${#MODULES[@]} modules -> $OUT  ($(wc -c < "$OUT") bytes)"
```

**Identity check:** SHA-256 of bundled `dashboard.js` (minus the 2 header comment lines) must match the SHA-256 of the pre-split monolith. This is enforced by a new `dashboard_js_bundle_identity` check in `preflight.sh`.

**Acceptance criteria:**

- [ ] All 19 module files exist in `dashboard/modules/`
- [ ] `bash scripts/bundle-dashboard.sh` runs without error
- [ ] SHA-256 of bundled content (strip 2-line header comment) matches pre-split `dashboard.js`
- [ ] `bash scripts/generate-header.sh` produces byte-for-byte identical `dashboard.h`
- [ ] All existing Playwright tests pass across all fixture variants
- [ ] `bash scripts/preflight.sh` passes
- [ ] No behavior change — dashboard functionality identical on device

**Risk:** Low. Pure file split, no logic changes.
**Estimated effort:** 1–2 sessions.
**Context window for this task:** ~35,000 tokens (read monolith once to split; all subsequent tasks are per-module).

***

### v7.6.5.1 — Wire bundle-dashboard.sh into CI (Level 1, Step 2)

**Scope:** Integrate `bundle-dashboard.sh` into CI and `preflight.sh`. Add `dashboard_js_is_up_to_date` preflight check that rebundles into a temp file and diffs against committed `dashboard.js`. Update developer documentation.

**Files modified:**


| Action | File |
| :-- | :-- |
| MODIFY | `.github/workflows/browser-tests.yml` — add bundle step before test run |
| MODIFY | `scripts/preflight.sh` — add `dashboard_js_is_up_to_date` check |
| MODIFY | `Docs/aggregator-setup.md` — update regeneration pipeline |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | All locations to `7.6.5.1` |

**Updated canonical regeneration pipeline (extends LESSON-OPS-091):**

```
1. python3 scripts/render_sensor_config.py --write
2. node tests/fixtures/generate-fixtures.js
3. bash scripts/bundle-dashboard.sh           ← NEW (Level 1)
4. bash scripts/minify-dashboard.sh
5. bash scripts/generate-header.sh
6. python3 scripts/render_sensor_config.py --check
```

**Acceptance criteria:**

- [ ] CI bundle step runs before Playwright suite
- [ ] `dashboard_js_is_up_to_date` check passes in clean state
- [ ] Editing a module without rebundling → preflight FAIL (verified)
- [ ] All existing Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes

**Risk:** Very Low. Pure CI/tooling change.
**Estimated effort:** 0.5 sessions.
**Context window for this task:** ~3,000 tokens.

***

### v7.6.5.2 — Create dashboard.tmpl.html (Level 2, Step 1)

```
**Scope:** Extract the static HTML structure from `dashboard.html` into `dashboard/dashboard.tmpl.html`. Replace the entire `<script>…</script>` block with `{{JS_PLACEHOLDER}}`. Create `scripts/build-dashboard.sh` that injects `dashboard.js` into the template to produce `dashboard.html`. Verify byte-for-byte identity. `dashboard.html` is NOT yet gitignored — this step only proves the pipeline works.
```

**Files modified:**


| Action | File |
| :-- | :-- |
| CREATE | `dashboard/dashboard.tmpl.html` — HTML with `{{JS_PLACEHOLDER}}` marker |
| CREATE | `scripts/build-dashboard.sh` |
| NO CHANGE | `.gitignore` (dashboard.html still committed here) |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | All locations to `7.6.5.2` |

**`build-dashboard.sh` contract:**

```bash
#!/usr/bin/env bash
# Injects dashboard.js into dashboard.tmpl.html -> dashboard.html
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}") /.." && pwd)"
cd "$ROOT"
python3 - "dashboard/dashboard.tmpl.html" "dashboard/dashboard.js" "dashboard/dashboard.html" << 'PYEOF'
import sys
tmpl_path, js_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
tmpl = open(tmpl_path).read()
js   = open(js_path).read()
if '{{JS_PLACEHOLDER}}' not in tmpl:
    raise RuntimeError(f"Marker not found in {tmpl_path}")
out  = tmpl.replace('{{JS_PLACEHOLDER}}', js, 1)
open(out_path, 'w').write(out)
PYEOF
echo "Built dashboard/dashboard.html"
```

**Level 2 bit-for-bit gate:**

```bash
# Save the hand-maintained file
cp dashboard/dashboard.html dashboard/dashboard.html.orig
# Run the pipeline
bash scripts/bundle-dashboard.sh
bash scripts/build-dashboard.sh
# Gate: must be empty diff
diff dashboard/dashboard.html dashboard/dashboard.html.orig
```

This diff must exit 0 before proceeding to v7.6.5.3. If it fails, the template extraction has a whitespace or encoding difference that must be resolved first.

**Updated canonical regeneration pipeline:**

```
1. python3 scripts/render_sensor_config.py --write
2. node tests/fixtures/generate-fixtures.js
3. bash scripts/bundle-dashboard.sh
4. bash scripts/build-dashboard.sh            ← NEW (Level 2)
5. bash scripts/minify-dashboard.sh
6. bash scripts/generate-header.sh
7. python3 scripts/render_sensor_config.py --check
```

**Acceptance criteria:**

- [ ] `dashboard.tmpl.html` exists with exactly one `{{JS_PLACEHOLDER}}`
- [ ] `bash scripts/build-dashboard.sh` produces byte-for-byte identical `dashboard.html` vs. hand-maintained version
- [ ] `diff` of generated vs. original exits 0
- [ ] `bash scripts/generate-header.sh` produces identical `dashboard.h`
- [ ] All existing Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes
- [ ] New preflight check `dashboard_tmpl_has_placeholder` confirms marker presence

**Risk:** Medium. Whitespace differences between template injection and the original hand-maintained file can cause a non-zero diff. Use Python exact substitution (not prettify/beautify). Do not proceed to v7.6.5.3 until diff is empty.
**Estimated effort:** 1–2 sessions.
**Context window for this task:** ~20,000 tokens (read HTML shell, no JS).

***

### v7.6.5.3 — Remove Hand-Maintained dashboard.html; Wire CI (Level 2, Step 2)

**Scope:** Add `build-dashboard.sh` to CI. Gitignore `dashboard.html`. Delete the last committed `dashboard.html` from the repo. Add `dashboard_html_not_committed` hard gate to `preflight.sh`. LESSON-OPS-043 is now permanently resolved.

**Files modified:**


| Action | File |
| :-- | :-- |
| MODIFY | `.github/workflows/browser-tests.yml` — add `build-dashboard.sh` step |
| DELETE | `dashboard/dashboard.html` (last committed version) |
| MODIFY | `.gitignore` — add `dashboard/dashboard.html` |
| MODIFY | `scripts/preflight.sh` — add `dashboard_html_not_committed` hard gate |
| MODIFY | `scripts/bump-version.sh` — replace `sed` on `dashboard.html` with pipeline re-run |
| MODIFY | `Docs/bugs-and-lessons-learned.md` — add LESSON-OPS-110: Level 2 resolves LESSON-OPS-043 |
| UPDATE | `Docs/changelog.md` — Phase X Level 2 closure note |
| VERSION BUMP | All locations to `7.6.5.3` |

**`dashboard_html_not_committed` preflight check:**

```bash
if git ls-files --error-unmatch "dashboard/dashboard.html" &>/dev/null 2>&1; then
  print_result "FAIL" "dashboard_html_not_committed: dashboard.html must not be committed"
else
  print_result "OK  " "dashboard_html_not_committed"
fi
```

**What this permanently eliminates:**


| Before (every dashboard PR) | After v7.6.5.3 |
| :-- | :-- |
| Edit `dashboard.js` | Edit `dashboard/modules/<module>.js` |
| Manually copy change to `dashboard.html` | (eliminated) |
| Run `generate-header.sh` | Run `bundle-dashboard.sh && build-dashboard.sh && generate-header.sh` |
| Risk: forgot the mirror → fixup commit | Risk: impossible — `dashboard.html` is not a source file |

**Acceptance criteria:**

- [ ] `dashboard.html` absent from `git ls-files`
- [ ] `dashboard/dashboard.html` listed in `.gitignore`
- [ ] CI pipeline includes `build-dashboard.sh` before minification step
- [ ] `dashboard_html_not_committed` preflight check passes
- [ ] All existing Playwright tests pass (they use mock server, not the HTML file)
- [ ] `bash scripts/preflight.sh` passes
- [ ] `bump-version.sh` updated to use pipeline instead of `sed` on the now-gitignored file
- [ ] LESSON-OPS-043 cross-referenced as structurally resolved in changelog

**Risk:** Low, if v7.6.5.2 bit-for-bit gate passed. The only failure mode is if any Playwright test reads `dashboard.html` from disk directly (check `tests/mock-server/server.js` — it should serve the generated file, not the source).
**Estimated effort:** 0.5 sessions.
**Context window for this task:** ~3,000 tokens.

***

### v7.6.5.4 — Component Directory Scaffolding (Level 3, Step 1)

**Scope:** Create `dashboard/components/` and `dashboard/core/` directories. Move module files from `dashboard/modules/` into the appropriate component and core directories. Update `bundle-dashboard.sh` and `build-dashboard.sh` to use the new paths. No behavior changes.

**Files modified:**


| Action | File |
| :-- | :-- |
| CREATE dir | `dashboard/components/sensor-cards/`, `charts/`, `settings-panel/`, `custom-range/`, `live-view/`, `gateway-panel/` |
| CREATE dir | `dashboard/core/` |
| MOVE | `modules/cards.js` → `components/sensor-cards/index.js` |
| MOVE | `modules/charts.js` → `components/charts/index.js` |
| MOVE | `modules/custom-range.js` → `components/custom-range/index.js` |
| MOVE | `modules/import.js` + `export.js` + `management.js` → `components/settings-panel/index.js` |
| MOVE | `modules/transport.js` + `telemetry.js` + `live-devices.js` → `components/live-view/index.js` |
| MOVE | `modules/util.js` + `config.js` + `state.js` + `boot.js` → `core/` |
| MOVE | `modules/manifest.js` + `history.js` + `status-storage.js` + `suspend-resume.js` → `core/` |
| MOVE | `modules/sensor-ui.js` + `minmax.js` → `core/sensor-ui.js` + `core/minmax.js` |
| MODIFY | `scripts/bundle-dashboard.sh` — update paths |
| MODIFY | `scripts/preflight.sh` — update path references |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | All locations to `7.6.5.4` |

**Acceptance criteria:**

- [ ] All files moved to component/core directories
- [ ] `bash scripts/bundle-dashboard.sh` succeeds with new paths
- [ ] `bash scripts/build-dashboard.sh` produces byte-identical `dashboard.html`
- [ ] `bash scripts/generate-header.sh` produces identical `dashboard.h`
- [ ] All existing Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes

**Risk:** Low. Pure file moves + path updates.
**Estimated effort:** 1 session.
**Context window for this task:** ~3,000 tokens.

***

### v7.6.5.5 — Component Template HTML Extraction (Level 3, Step 2)

**Scope:** Extract HTML markup for each dashboard section from `dashboard.tmpl.html` into per-component `template.html` files. Replace section markup with `{{COMPONENT:name}}` markers. Update `build-dashboard.sh` to resolve component templates in a first pass before JS injection.

**Files modified:**


| Action | File |
| :-- | :-- |
| CREATE | `components/sensor-cards/template.html` — `#sensorGrid` section |
| CREATE | `components/charts/template.html` — chart canvas sections |
| CREATE | `components/settings-panel/template.html` — management/import/export/storage |
| CREATE | `components/custom-range/template.html` — `#customRangeModal` |
| CREATE | `components/live-view/template.html` — real-time display section |
| CREATE | `components/gateway-panel/template.html` — `#hdr-gateways` section |
| MODIFY | `dashboard/dashboard.tmpl.html` — replace sections with `{{COMPONENT:name}}` markers |
| MODIFY | `scripts/build-dashboard.sh` — add pass 1 to resolve component templates |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | All locations to `7.6.5.5` |

**`build-dashboard.sh` two-pass contract:**

```
Pass 1: For each {{COMPONENT:name}} in dashboard.tmpl.html,
        substitute contents of dashboard/components/<name>/template.html.
        → Produces fully-assembled HTML shell (all panels inlined).

Pass 2: Inject dashboard.js at {{JS_PLACEHOLDER}}.
        → Produces final dashboard/dashboard.html.
```

**Acceptance criteria:**

- [ ] All component `template.html` files exist
- [ ] Two-pass assembly produces byte-identical `dashboard.html` vs. v7.6.5.4 output
- [ ] `bash scripts/generate-header.sh` produces identical `dashboard.h`
- [ ] All existing Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes

**Risk:** Medium. HTML extraction must preserve whitespace exactly. Use Python exact substitution (same pattern as `{{JS_PLACEHOLDER}}`), never beautify. Bit-for-bit gate remains active.
**Estimated effort:** 1–2 sessions.
**Context window for this task:** ~15,000 tokens.

***

### v7.6.5.6 — Component CSS Extraction (Level 3, Step 3)

**Scope:** Extract CSS blocks that belong to each component from `dashboard.tmpl.html` into per-component `styles.css` files. Global CSS (`:root`, theme tokens, scrollbar, body, reset) moves to `core/base.css`. Update `build-dashboard.sh` for a CSS assembly pass.

**Files modified:**


| Action | File |
| :-- | :-- |
| CREATE | `components/sensor-cards/styles.css` |
| CREATE | `components/charts/styles.css` |
| CREATE | `components/settings-panel/styles.css` |
| CREATE | `components/custom-range/styles.css` |
| CREATE | `components/live-view/styles.css` |
| CREATE | `core/base.css` — `:root`, CSS variables, theme tokens, global reset |
| MODIFY | `dashboard/dashboard.tmpl.html` — replace `<style>` blocks with `{{CSS:component}}` markers |
| MODIFY | `scripts/build-dashboard.sh` — add CSS pass 0 before HTML and JS passes |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | All locations to `7.6.5.6` |

**`build-dashboard.sh` three-pass contract:**

```
Pass 0: For each {{CSS:name}} marker, inline contents of
        dashboard/components/<name>/styles.css (or core/base.css).
        → Produces CSS-complete template.

Pass 1: Resolve {{COMPONENT:name}} template markers.
        → Produces fully-assembled HTML shell.

Pass 2: Inject dashboard.js at {{JS_PLACEHOLDER}}.
        → Produces final dashboard/dashboard.html.
```

**Acceptance criteria:**

- [ ] All component `styles.css` files exist
- [ ] Three-pass assembly produces byte-identical `dashboard.html` vs. v7.6.5.5 output
- [ ] `bash scripts/generate-header.sh` produces identical `dashboard.h`
- [ ] All existing Playwright tests pass
- [ ] Visual regression: screenshot before and after v7.6.5.6 must show no rendered difference
- [ ] `bash scripts/preflight.sh` passes

**Risk:** Medium. CSS boundary identification (component-scoped vs. global) requires careful audit. Global CSS (`--color-*`, `:root`, `.light`, `body`, scrollbar) stays in `core/base.css`. If a CSS rule targets elements across component boundaries, it stays in `core/base.css`.
**Estimated effort:** 1–2 sessions.
**Context window for this task:** ~10,000 tokens.

***

### v7.6.5.7 — Phase X Closure: Tests, Documentation, Playwright Guard Update

**Scope:** Update Playwright tests to validate the build pipeline. Add preflight checks for component file existence. Update developer documentation. Phase X closure.

**Files modified:**


| Action | File |
| :-- | :-- |
| MODIFY | `tests/browser/dashboard.spec.js` — add Group 19: build pipeline smoke tests |
| MODIFY | `scripts/preflight.sh` — component/core file existence checks |
| MODIFY | `Docs/bugs-and-lessons-learned.md` — LESSON-OPS-110: Phase X resolved LESSON-OPS-043 |
| MODIFY | `Docs/aggregator-setup.md` — full updated developer workflow |
| UPDATE | `Docs/changelog.md` — Phase X closure entry |
| VERSION BUMP | All locations to `7.6.5.7` |

**New Playwright tests (Group 19 — `phase-x-build-pipeline.spec.js`):**

- `{{JS_PLACEHOLDER}}` does NOT appear in `dashboard.html` after build (injection worked)
- `dashboard.html` is not tracked by git (`git ls-files` returns empty)
- All component `index.js` files exist on disk
- All component `template.html` files exist on disk
- Bundled `dashboard.js` roundtrip (bundle → build → minify → header) passes version-match check
- `bump-version.sh` does not reference `dashboard.html` via `sed` (regression guard)

**Closure gate:**

- [ ] All Playwright test groups pass in CI across all fixture variants
- [ ] `bash scripts/preflight.sh` passes with all component-existence checks
- [ ] Developer workflow docs reviewed and approved
- [ ] `dashboard.html` absent from git at HEAD (confirmed via `git ls-files`)
- [ ] At least one subsequent feature PR (Phase E prep or hotfix) was shipped through the new pipeline without any LESSON-OPS-043 class issue

**Risk:** Low. Standard test infrastructure and documentation.
**Estimated effort:** 1 session.
**Context window for this task:** ~4,000 tokens.

***

## Build Pipeline Changes Summary

### Level 1 Changes

| Script | Before | After |
| :-- | :-- | :-- |
| `bundle-dashboard.sh` | Does not exist | Concatenates `modules/*.js` in order → `dashboard.js` |
| `minify-dashboard.sh` | Reads `dashboard.html` | Unchanged |
| `generate-header.sh` | Reads `dashboard.html` or `.min.html` | Unchanged |

### Level 2 Changes

| Script | Before | After |
| :-- | :-- | :-- |
| `build-dashboard.sh` | Does not exist | Injects `dashboard.js` → `dashboard.tmpl.html` → `dashboard.html` |
| `bundle-dashboard.sh` | Outputs `dashboard.js` | Unchanged |
| `minify-dashboard.sh` | Reads hand-maintained `dashboard.html` | Reads **generated** `dashboard.html` |
| `generate-header.sh` | Same | Unchanged |
| `bump-version.sh` | `sed` on `dashboard.html` | Runs `bundle-dashboard.sh && build-dashboard.sh` |

### Level 3 Changes

| Script | Before (Level 2) | After (Level 3) |
| :-- | :-- | :-- |
| `build-dashboard.sh` | Single-pass JS injection | Three-pass: CSS → component templates → JS |
| `bundle-dashboard.sh` | Reads `modules/` flat list | Reads `components/*/index.js` + `core/*.js` |
| `minify-dashboard.sh` | Unchanged | Unchanged |
| `generate-header.sh` | Unchanged | Unchanged |

### Full Pipeline After Level 3

```
[DEVELOPER EDITS]
  dashboard/components/<name>/index.js
  dashboard/components/<name>/styles.css
  dashboard/components/<name>/template.html
  dashboard/core/*.js

[BUILD PIPELINE]
  bash scripts/bundle-dashboard.sh
    → dashboard/dashboard.js

  bash scripts/build-dashboard.sh
    pass 0: inline {{CSS:name}} from components/*.css
    pass 1: resolve {{COMPONENT:name}} from components/template.html
    pass 2: inject dashboard.js at {{JS_PLACEHOLDER}}
    → dashboard/dashboard.html  (gitignored)

  bash scripts/minify-dashboard.sh
    → dashboard/dashboard.min.html  (gitignored)

  bash scripts/generate-header.sh
    → dashboard/dashboard.h  (committed)

  esphome compile → firmware binary
```


***

## Coding Agent Task Size Analysis

### Baseline — Today (Pre-Refactor)

| Task Type | Files Needed | Est. Tokens |
| :-- | :-- | :-- |
| Any dashboard feature | `dashboard.js` (2,600 lines) + `dashboard.html` (~same) | ~45,000 tokens |
| Bug fix in export | Full monolith × 2 (mirror requirement) | ~45,000 tokens |
| New sensor card type | Full monolith × 2 | ~45,000 tokens |
| Build pipeline change | Both scripts + both dashboard files | ~48,000 tokens |

> Context overflows at ~30,000 tokens for most coding agents. Every dashboard task today either truncates context (unsafe) or requires a human to pre-slice the relevant section.

### After Level 1 (Module Split)

| Task Type | Files Needed | Est. Tokens |
| :-- | :-- | :-- |
| Fix export bug | `modules/export.js` (~250 ln) + `modules/util.js` | ~6,000 tokens |
| New sensor card type | `modules/cards.js` (~320 ln) | ~5,000 tokens |
| Transport change | `modules/transport.js` + `modules/state.js` | ~7,000 tokens |
| Custom range bug | `modules/custom-range.js` (~260 ln) | ~4,000 tokens |
| Charts theme fix | `modules/charts.js` (~300 ln) | ~5,000 tokens |
| Build pipeline | `scripts/bundle-dashboard.sh` (~40 ln) | ~1,000 tokens |

> Any single dashboard feature fits comfortably within 10,000 tokens. The LESSON-OPS-043 mirror requirement still exists but is mitigated — editing a module and rebundling is audited by CI.

### After Level 2 (Generated HTML)

| Task Type | Files Needed | Est. Tokens |
| :-- | :-- | :-- |
| Any dashboard JS task | Same as Level 1 — no `dashboard.html` to read or mirror | Same as Level 1 |
| HTML structural change | `dashboard.tmpl.html` (HTML only, no JS) | ~15,000 tokens |
| Template + CSS change | `dashboard.tmpl.html` + CSS blocks | ~18,000 tokens |
| Build pipeline | `scripts/build-dashboard.sh` (~60 ln) | ~1,500 tokens |

> LESSON-OPS-043 tasks are eliminated. JS changes never touch HTML. HTML changes never touch JS.

### After Level 3 (Component Model)

| Task Type | Files Needed | Est. Tokens |
| :-- | :-- | :-- |
| New Phase E feature | `components/<name>/index.js` + `template.html` + `styles.css` | ~12,000 tokens |
| Charts feature | `components/charts/index.js` (~300 ln) + template | ~8,000 tokens |
| Settings panel feature | `components/settings-panel/index.js` + template | ~8,000 tokens |
| Gateway panel feature | `components/gateway-panel/index.js` + template | ~7,000 tokens |
| Global state change | `core/state.js` (~120 ln) | ~2,000 tokens |
| Build pipeline change | `scripts/build-dashboard.sh` (~80 ln) | ~2,000 tokens |

> A coding agent implementing any Phase E feature reads one component directory plus `core/state.js` — typically 8,000–15,000 tokens total.

***

## Migration Safety Rules

1. **No behavior changes** — every step is structural reorganization only. If a step requires a bug fix to pass tests, that bug fix is a separate PR before the refactor step.
2. **All existing Playwright tests must pass after every sub-step**, including all CI fixture variants (1sensor, 2sensor, 3sensor, 4sensor, mixed, system). No test may be deleted or disabled to make a refactor step pass.
3. **`dashboard.h` bit-for-bit identity gate (mandatory for Level 2):** Before deleting `dashboard.html` (v7.6.5.3), the build pipeline must produce byte-for-byte identical output to the hand-maintained file. This is enforced by a `diff` check in CI and in `preflight.sh`. A non-zero diff blocks v7.6.5.3 until root cause is fixed in v7.6.5.2.
4. **Each step must be independently revertable.** Each sub-step is a separate PR. Reverting v7.6.5.2 must not break v7.6.5.1. The chain is strictly forward-only with no cross-step dependencies except the explicit prerequisite listed in each step.
5. **`dashboard.js` remains readable committed source.** Even after Level 3, the assembled `dashboard.js` is committed for the `open from disk` device-testing workflow. It must be human-readable with module boundary comments.
6. **Module dependency order must be acyclic.** The order in `bundle-dashboard.sh` is the canonical load order: `util → config → state → manifest → ...`. No module may call a function defined in a later module. Verify with a one-time ESLint audit at v7.6.5.0.
7. **CSS extraction must not change rendered appearance** (v7.6.5.6). A visual regression screenshot taken before and after the step must show no visible difference. Use `playwright screenshot` as the comparison tool.

***

## Rollout Order

### Recommended Sequence

**Level 1 first.** Provides immediate coding-agent context reduction with minimal risk. Pure source reorganization, no build pipeline or firmware changes. Shippable as a single PR.

**Level 2 second.** Eliminates LESSON-OPS-043 permanently — the single highest-value structural change. The bit-for-bit gate makes it safe. Level 2 depends on Level 1 because `bundle-dashboard.sh` must exist before `build-dashboard.sh` can inject its output.

**Level 3 last.** Primarily an investment for Phase E (v8.0.x). Highest effort and highest risk. Should only proceed after Level 2 has been stable through at least one feature PR shipped via the new pipeline.

### Gate Conditions

| Gate | Condition to Advance |
| :-- | :-- |
| Level 1 → Level 2 | v7.6.5.1 merged, CI green, preflight passes, at least one device test with bundled dashboard |
| Level 2 → Level 3 | v7.6.5.3 merged, CI green, bit-for-bit gate confirmed, no LESSON-OPS-043 class event in subsequent PR |
| Level 3 → Phase E | v7.6.5.7 merged, Group 19 tests pass, component model proven on one Phase E-style task |


***

## Version Number Mapping

| Phase | Version Range | Description |
| :-- | :-- | :-- |
| Phase D | v7.6.0.0–v7.6.0.5 | Runtime Satellite Management |
| **Phase X** | **v7.6.5.0–v7.6.5.7** | **Dashboard Architecture Refactor** |
| Phase E | v8.0.x | Captive Portal + WiFi Config |


***

## Context Window Requirements per Step

| Step | Version | Key Input Files | Estimated Tokens |
| :-- | :-- | :-- | :-- |
| Module split | v7.6.5.0 | `dashboard.js` (2,600 lines) — read once to split | ~35,000 |
| CI integration | v7.6.5.1 | `browser-tests.yml`, `preflight.sh` | ~4,000 |
| Template creation | v7.6.5.2 | `dashboard.html` (HTML only; JS stripped) | ~20,000 |
| Remove hand-maintained HTML | v7.6.5.3 | `.gitignore`, `preflight.sh`, `browser-tests.yml` | ~3,000 |
| Component scaffolding | v7.6.5.4 | File list only (no file contents needed) | ~2,000 |
| Template HTML extraction | v7.6.5.5 | `dashboard.tmpl.html` (HTML only) | ~15,000 |
| CSS extraction | v7.6.5.6 | CSS blocks from `dashboard.tmpl.html` | ~10,000 |
| Tests + closure | v7.6.5.7 | `dashboard.spec.js`, `preflight.sh` | ~8,000 |

> v7.6.5.0 is the only step requiring the full monolith in context. Every subsequent step operates within 20,000 tokens or less.

***

## Risks and Mitigations

| Risk | Level | Likelihood | Severity | Mitigation |
| :-- | :-- | :-- | :-- | :-- |
| Module split breaks a subtle global variable dependency (out-of-order reference) | 1 | Medium | High | SHA-256 identity gate on bundled output vs. original; one-time ESLint no-undef audit |
| Bundle order creates reference-before-definition error | 1 | Medium | High | Browser smoke test with bundled file before CI submission |
| Template injection produces different whitespace than hand-maintained HTML | 2 | Medium | Medium | Bit-for-bit diff gate; Python exact substitution only — never prettify |
| Stale `dashboard.min.html` embedded by `generate-header.sh` | 2 | Low | High | v7.6.5.3 removes committed HTML; CI always rebuilds from clean state |
| CSS extraction moves component-scoped CSS into `core/base.css` accidentally | 3 | Medium | Medium | Visual regression screenshot diff before/after v7.6.5.6 |
| Component boundary creates circular dependency | 3 | Low | High | Dependency order is explicit and documented in `bundle-dashboard.sh`; enforce with ESLint |
| `build-dashboard.sh` not re-run before `generate-header.sh` on dev machine | 2+ | Medium | Medium | `dashboard_js_is_up_to_date` preflight check catches this |
| `bump-version.sh` still calls `sed` on the now-gitignored `dashboard.html` | 2 | High | Medium | v7.6.5.3 explicitly updates `bump-version.sh` to use pipeline instead |
| Phase E starts before Level 3 is stable, creating parallel work conflicts | 3 | Medium | Medium | Level 3 → Phase E gate condition requires proven component model first |
| Playwright tests break because mock server serves stale HTML | 2 | Low | Medium | CI builds `dashboard.html` before running tests; verify `server.js` uses generated file |


***

## Changelog Entry Template

```markdown
## v7.6.5.x — Phase X: Dashboard Architecture Refactor (Level N, Step M)

### Changes
- [description of structural change]

### Build Pipeline
- [updated pipeline step(s)]

### Migration Notes
- No behavior changes. `dashboard.h` output is bit-for-bit identical before and after.
- [any developer workflow changes]

### Tests
- All existing Playwright test groups pass unchanged across all fixture variants.
```


***

_End of Phase X implementation plan._

***

The document covers all eight requirements: current state analysis with line/function counts and a functional group table, before/after directory trees for all three levels, versioned steps v7.6.5.0–v7.6.5.7 with exact file lists and checklist acceptance criteria, build pipeline changes at each level, coding agent token estimates, migration safety rules, rollout order with gate conditions, and a risk/mitigation table.

