# Implementation Plan — Next Features (post-v7.4.1.0 baseline)

_Snapshot date: 2026-03-10_
_Current repo version: v7.4.1.0_
_Branch baseline: `main`_

This is the canonical detailed implementation plan after the completion of **v7.4.1.0 dashboard minification**.
It supersedes older wording that still treated minification as upcoming work.

---

## 1. Planning Baseline

The original next-features plan included four roadmap items:

1. Custom date range
2. Playwright browser tests
3. Configurable sensor count
4. Dashboard minification

That fourth item is now complete in **v7.4.1.0**.
So the active plan from this point forward is:

1. **v7.4.2.x — Custom Date Range Selector**
2. **v7.4.3.x — Playwright Browser Test Automation**
3. **v7.4.4.x — Configurable Sensor Count (1–4)**

---

## 2. Completed Reference Item — Dashboard Minification

### Status

**Complete in v7.4.1.0**

### Outcome

- `dashboard.html` remains source of truth
- `dashboard.min.html` is produced as a gitignored intermediate
- `generate-header.sh` regenerates `dashboard.h`
- CI runs the pipeline automatically
- Flash pressure was reduced enough to create safer headroom for the next features

### Why it matters to future work

All upcoming dashboard work must preserve this pipeline.
No feature should reintroduce direct editing of generated files.

---

## 3. Feature 1 — v7.4.2.x Custom Date Range Selector

### Goal

Add a **Custom** range option alongside the existing fixed range buttons so the user can choose an arbitrary start and end time bounded by the actual data available in storage.

### Current architecture this feature must respect

- History endpoints already deliver all available history data per sensor
- Dashboard currently filters chart windows using the fixed presets: **24h / 7d / 30d / 45d**
- `/api/storage-stats` already exposes retention bounds that can inform the UI
- The dashboard is embedded and must remain dependency-light

### Target user experience

- Add a **Custom** button after the fixed preset buttons
- Clicking it opens a date-range picker dialog
- Available range is bounded by actual retained history
- Applying the range updates all relevant history-based charts together
- Clicking a preset should clear the custom-range state and return to the standard preset behavior

### Recommended implementation style

- **Vanilla JS only**
- No external UI library
- Keep the modal/dialog consistent with the existing dashboard theme
- Mobile-safe layout

### Recommended internal state

```javascript
App.State.customDateRange = {
  fromEpoch: null,
  toEpoch: null,
  active: false
};
```

### Recommended implementation steps

1. Add Custom buttons in both relevant range-selector groups
2. Fetch available date bounds from `/api/storage-stats`
3. Add modal markup and CSS in `dashboard.html`
4. Add dialog state + calendar/time handling in `dashboard.js`
5. When custom range is active, filter loaded chart data client-side by epoch
6. Ensure min/max summaries reflect the active custom window
7. Ensure preset buttons clear custom state correctly
8. Run dashboard regeneration pipeline and full validation

### Files expected to change

- `dashboard/dashboard.html`
- `dashboard/dashboard.js`
- `dashboard/dashboard.h` (regenerated)
- `VERSION`
- `firmware/esp32-c3-multi-sensor.yaml`
- `Docs/changelog.md`
- `Docs/build-history.md`
- `Docs/esp32-gateway-fresh-start-handoff.md`
- Session log for the implementation session

### Key risks

- Modal complexity and event-binding regressions
- Range state fighting the preset state
- Stale min/max values after range switch
- Chart redraw edge cases between dark/light mode and custom ranges
- Mobile usability

### Validation focus

- All existing preset buttons still work
- Custom range updates all intended charts
- Min/max values match the filtered data
- Theme toggle still redraws properly
- Chrome, Firefox, Edge, and at least one mobile browser
- LAN and Cloudflare access path sanity

---

## 4. Feature 2 — v7.4.3.x Playwright Browser Test Automation

### Goal

Introduce browser-level regression testing for the dashboard so UI and interaction changes are caught before device testing.

### Why this is next after custom range

The custom date-range feature will materially increase frontend complexity.
That is the right moment to add automated dashboard regression coverage.

### Testing approach

- Use a mock or fixture-driven backend
- Avoid dependency on live ESP availability in CI
- Focus on dashboard behavior rather than firmware behavior

### Initial test scope

- Dashboard loads
- Sensor cards render
- Theme toggle works
- Range buttons work
- Export buttons exist and basic flows initiate correctly
- Custom-range modal opens/closes once that feature lands
- No major console errors during startup flow

### CI design

Use a separate workflow from firmware compile so browser failures are easier to isolate.
Store screenshots/traces on failure.

### Files expected to change

- `.github/workflows/` new browser workflow
- Playwright config and test files
- Possibly a mock-data fixture directory
- `Docs/development-pipeline.md`
- `Docs/bugs-and-lessons-learned.md` if new testing lessons emerge

### Key risks

- Brittle tests that overfit UI details
- Too much coupling to generated/minified dashboard output
- False negatives from asynchronous chart rendering

### Validation focus

- Stable CI execution
- Useful screenshots/traces
- Tests assert behavior, not fragile pixel-perfect layout

---

## 5. Feature 3 — v7.4.4.x Configurable Sensor Count (1–4)

### Goal

Normalize the project so sensor count can be configured from 1 to 4 in a disciplined, documented, and validated way.

### Current reality

- Current repo default is 3 sensors
- Dashboard frontend is already dynamic enough to support variable sensor manifests
- Persistence and YAML/C++ alignment are the critical constraints

### What this feature must accomplish

- Document the change procedure clearly
- Add preflight checks that validate sensor-count alignment
- Make the README and architecture docs truthful once the feature is actually complete
- Explicitly handle retained-history compatibility expectations
- Test 1, 2, 3, and 4-sensor configurations

### Recommended preflight checks

At minimum validate:

- `NUM_SENSORS` matches the number of configured C++ sensor slots
- YAML blocks and generated/public-facing manifest align with that count as far as practical
- Any configuration doc examples use a supported count and consistent naming

### Important storage warning

Changing sensor count changes multi-sensor segment sizing assumptions.
Treat persisted history as incompatible unless the final implementation includes a deliberate migration strategy.
The safe operational guidance is to erase/reset history after a sensor-count change.

### Recommended documentation deliverables for this feature

- Updated `README.md`
- Updated `Docs/architecture.md`
- Updated `Docs/future-plans.md`
- Possibly a dedicated `Docs/configuring-sensors.md`
- Updated handoff + session log

### Key risks

- Silent mismatch between C++ and YAML definitions
- Retained-history corruption or misleading partial compatibility
- Docs claiming configurability before the workflow is actually validated end-to-end

### Validation focus

- Compile success for 1/2/3/4 sensor variants
- Dashboard renders correct number of cards
- History endpoints behave correctly
- Export/import sanity after sensor-count changes
- Clear user guidance that history reset is expected

---

## 6. Recommended Order and Rationale

Active recommended order:

1. Custom Date Range
2. Playwright Automation
3. Configurable Sensor Count (1–4)

Why this order still makes sense:

- Custom range gives immediate user-visible value
- Playwright then protects the growing dashboard surface
- Sensor-count configurability comes after stronger frontend regression coverage exists

---

## 7. Rules That Apply to All Upcoming Features

- `dashboard.html` remains the editable dashboard source of truth
- `dashboard.js` and the embedded JS path must stay synchronized
- After dashboard changes, run the full regenerate pipeline
- Run preflight before every commit
- Keep the six version-bearing locations synchronized on any version bump
- Test in Firefox, not only Chromium
- Test the Cloudflare/public path for user-facing changes that could be affected by transport/runtime differences
- Document meaningful sessions with both a session log and handoff update
- Keep docs honest: current behavior in README/architecture, future behavior in roadmap/plan docs
