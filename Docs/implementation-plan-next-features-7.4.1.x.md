# Implementation Plan — Next Features (as of v7.4.1.x)

_Snapshot date: 2026-03-10_
_Current version: v7.4.1.0 (validated)_
_Branch: `main`_

> This file is the versioned snapshot of the feature implementation plan that was active during the v7.4.1.x cycle. The original `implementation-plan-next-features.md` was renamed to this file after v7.4.1.0 was validated.
>
> For the current active plan, see this file — it is the canonical implementation plan as of v7.4.1.0.

---

## Feature Priority Order

| # | Version | Feature | Status |
|---|---------|---------|--------|
| 1 | v7.4.1.x | Dashboard Minification pipeline | ✅ DONE (v7.4.1.0 validated 2026-03-10) |
| 2 | v7.4.2.x | Custom Date Range selector | 🔜 Next |
| 3 | v7.4.3.x | Playwright browser test automation | Planned |
| 4 | v7.4.4.x | Configurable sensor count | Planned |

---

## Feature 1: Dashboard Minification ✅ COMPLETE

**Goal:** Reduce flash usage by minifying `dashboard.html` before embedding into `dashboard.h`.

**Result:**
- Flash: 88.2% → 86.1% (−48,611 bytes, −31% of dashboard payload)
- Tool: `html-minifier-terser` + `terser` inline JS compression
- Pipeline: `minify-dashboard.sh` → `generate-header.sh` → `preflight.sh` → `esphome compile`
- CI: Full automated pipeline on every push
- `dashboard.min.html` is gitignored (build artifact)
- `dashboard.h` is committed (embedded payload)

**Key lesson learned:** `html-minifier-terser` CLI uses positional arg + `--output`, not `--input-path`/`--output-path`.

---

## Feature 2: Custom Date Range Selector (v7.4.2.x)

**Goal:** Allow the user to select a custom start/end date range for the dashboard charts, beyond the fixed 24h/7d/30d/45d presets.

### UX Design

- Add a "Custom" option to the existing time-range selector buttons
- On click: open a date-range picker dialog (HA-style, two calendar months side by side)
- Date range is applied to all charts simultaneously
- Preset buttons remain fully functional
- Mobile-friendly: dialog stacks to single-month view on narrow screens

### Implementation Approach

**No external library.** The date picker is implemented in vanilla JS within `dashboard.js` / `dashboard.html` to keep the firmware self-contained and avoid adding npm dependencies to the embedded payload.

**Data source:** The existing `/history/{sensor_id}/{series}` endpoints already return all available data. The date range filter is applied client-side by slicing the returned arrays by timestamp.

**State:** The selected range is stored in `App.State.customDateRange = { from: epoch, to: epoch }`. It is cleared when the user clicks a preset button.

### Files Changed
- `dashboard/dashboard.html` — add date picker dialog markup and CSS
- `dashboard/dashboard.js` — add picker logic, range state, chart filter
- `dashboard/dashboard.h` — regenerated (run pipeline after dashboard changes)
- `firmware/esp32-c3-multi-sensor.yaml` — version bump
- `VERSION` — bump to `7.4.2.0`
- `Docs/` — session log, handoff update, changelog, build history

### No firmware changes required
All filtering is client-side. No new endpoints. No changes to `sensor_history_multi.h`.

### Acceptance Criteria
1. "Custom" button opens the date picker dialog
2. User selects a start and end date; dialog closes on confirm
3. All charts update to show only the selected range
4. Preset buttons (24h, 7d, 30d, 45d) clear the custom range and work as before
5. Custom range survives a page refresh (stored in `localStorage`)
6. Works on mobile (single-column layout)
7. Preflight 23/23 PASS
8. Flash remains below 90%

---

## Feature 3: Playwright Browser Test Automation (v7.4.3.x)

**Goal:** Automated end-to-end browser tests for the dashboard using Playwright, runnable in CI with a mock backend.

### Approach

- Mock backend: a small Node.js or Python HTTP server that serves static fixture data from `/history/*`, `/sensors.json`, `/api/status`, and `/api/storage-stats`
- Tests cover: dashboard load, chart render, time-range switching, export, import, theme toggle, custom date range
- CI: Playwright tests run after compile step on every PR
- Local: `npm test` or `npx playwright test`

### Files Added
- `tests/` — Playwright test files
- `tests/mock-server/` — mock backend
- `tests/fixtures/` — static history data
- `package.json` — Playwright dependency
- `.github/workflows/ci.yml` — Playwright step

---

## Feature 4: Configurable Sensor Count (v7.4.4.x)

**Goal:** Make the number of sensors (currently hardcoded to 3) configurable without modifying core firmware logic.

### Approach

- Define `SENSOR_COUNT` as a compile-time constant
- All loops, arrays, and YAML sensor blocks are parameterized
- Preflight validates that the YAML sensor count matches `SENSOR_COUNT`
- Documentation: add a "how to add a 4th sensor" guide

### Constraint
This is a docs + preflight change primarily. The firmware C++ already uses `sensors[0..2]` loops that can be refactored to use a `SENSOR_COUNT` constant with minimal risk.
