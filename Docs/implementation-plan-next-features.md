# Implementation Plan — Next Four Features

_Project: ESP32-C3 Multi-Sensor BLE Gateway_
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Baseline version: v7.4.0.2_
_Date: 2026-03-09_

This document provides complete implementation plans for the next four roadmap items. Each section is self-contained with enough detail for a developer (or AI assistant) to implement without needing the full project history.

---

## Table of Contents

1. [Custom Date Range Display (v7.4.1b)](#1-custom-date-range-display)
2. [Playwright Browser Test Automation](#2-playwright-browser-test-automation)
3. [Configurable Sensor Count](#3-configurable-sensor-count)
4. [Dashboard Minification](#4-dashboard-minification)

---

## 1. Custom Date Range Display

### 1.1 Goal

Add a "Custom" button after the existing 45d range button in both the **sensor min/max panes** and **15-minute average chart panes**. When clicked, it opens a date-range picker dialog modeled on the Home Assistant style: a left sidebar of quick-select presets, a calendar month view, and start/end time selectors. The available date range is constrained to what data actually exists in flash.

### 1.2 Current Architecture (Must Understand)

**Range buttons**: The dashboard currently has 24h / 7d / 30d / 45d buttons in two locations:
- Sensor min/max cards (below each sensor's detail)
- 15-minute averaged chart section

These buttons set `HISTORY_RANGE_HOURS` via `App.State.setHistoryRangeHours(hours)` and trigger `loadHistory()` which fetches from `/history/{sensor_id}/temp` and `/history/{sensor_id}/hum`. The data returned includes ALL available history (flash + RAM merged). The dashboard then client-side filters to the selected time range.

**History data format**: Each `/history/{id}/{metric}` endpoint returns newline-delimited `epoch,value` pairs, oldest first. The dashboard parses these into arrays and renders charts filtered to `[now - range_hours, now]`.

**Storage stats**: `GET /api/storage-stats` returns JSON including `retention_oldest_epoch` and `retention_newest_epoch` which give the actual date range of persisted data.

**Key state variables** (in dashboard.js):
- `HISTORY_RANGE_HOURS` — currently selected range
- `MAX_HISTORY_RANGE_HOURS` — maximum (1080 = 45 days)
- `avgHistoryStore` — loaded history data
- `chartsReady` — boolean, charts initialized

### 1.3 UX Design

The dialog should match the dashboard's existing dark theme (`#1a1a2e` background, `#0f3460` accents, `#16213e` cards, cyan `#00d4ff` highlights). It must work on both desktop and mobile viewports.

**Dialog layout** (inspired by Home Assistant's date picker):

```
┌──────────────────────────────────────────────┐
│  Custom Date Range                       [X] │
├────────────────┬─────────────────────────────┤
│                │                             │
│  Today         │    < March 2026 >           │
│  Yesterday     │  Sun Mon Tue Wed Thu Fri Sat│
│  Last 24h      │  [22] 23  24  25  26  27  28│
│  Last 7 days   │   1   2   3   4   5   6   7│
│  Last 30 days  │  [8] [9]  10  11  12  13  14│
│  Last 45 days  │   15  16  17  18  19  20  21│
│                │   22  23  24  25  26  27  28│
│                │   29  30  31   .   .   .   .│
│                ├─────────────────────────────┤
│                │  From: [Mar 1] [12:00] [AM] │
│                │  To:   [Mar 9] [11:00] [PM] │
├────────────────┴─────────────────────────────┤
│  Data available: Feb 1 – Mar 9               │
│                    [Cancel]  [Apply]          │
└──────────────────────────────────────────────┘
```

**Quick presets** (left sidebar):
- Today, Yesterday, Last 24h, Last 7 days, Last 30 days, Last 45 days
- These map directly to time ranges relative to now
- Clicking a preset updates the calendar highlights and time fields, then closes the dialog

**Calendar**:
- Month navigation with `<` `>` arrows
- Current date highlighted with accent ring
- Selected start/end range highlighted with background fill
- Dates outside the available data range should be grayed out / unselectable
- Dates with no data in flash should be dimmed

**Time selectors**:
- From (start) date + time
- To (end) date + time
- Use `<select>` dropdowns for hours and AM/PM (consistent with HA screenshot)
- Minutes can be fixed at :00 increments (data is 15-min averaged, so finer granularity has minimal value)

**Available range indicator**: Show "Data available: [oldest date] – [newest date]" to inform the user

**Buttons**: Cancel (close without changing) and Apply (set the custom range and reload charts)

### 1.4 Implementation Steps

#### Step 1: Get available date range from /api/storage-stats

The storage stats endpoint already returns `retention_oldest_epoch` and `retention_newest_epoch`. Load these when the Custom dialog opens:

```javascript
function getAvailableDateRange() {
  return fetch(ESP_HOST + '/api/storage-stats')
    .then(safeJsonResponse)
    .then(function(data) {
      return {
        oldest: data.retention_oldest_epoch || 0,
        newest: data.retention_newest_epoch || Math.floor(Date.now() / 1000)
      };
    });
}
```

#### Step 2: Add "Custom" button to both range-button groups

In `dashboard.html`, after the 45d button in both the min/max pane and the averaged chart pane, add:

```html
<button class="range-btn" data-hours="custom">Custom</button>
```

In `bindEvents()` in `dashboard.js`, handle `data-hours="custom"` differently from numeric values — call `openCustomRangeDialog()` instead of setting hours directly.

#### Step 3: Build the dialog HTML

Add the dialog as a hidden modal in the HTML body (similar pattern to the existing `authModal`):

```html
<div id="customRangeModal" class="modal hidden" role="dialog" aria-hidden="true">
  <div class="custom-range-container">
    <div class="custom-range-header">
      <span>Custom Date Range</span>
      <button id="customRangeClose" class="modal-close">&times;</button>
    </div>
    <div class="custom-range-body">
      <div class="custom-range-presets">
        <!-- preset buttons -->
      </div>
      <div class="custom-range-calendar">
        <!-- calendar grid + time selectors -->
      </div>
    </div>
    <div class="custom-range-footer">
      <span id="customRangeAvail" class="range-availability"></span>
      <button id="customRangeCancel">Cancel</button>
      <button id="customRangeApply" class="btn-primary">Apply</button>
    </div>
  </div>
</div>
```

#### Step 4: Implement calendar rendering in JS

Add a `CustomRangeDialog` module to `dashboard.js`:

```javascript
var CustomRange = (function() {
  var state = {
    visible: false,
    availableOldest: 0,
    availableNewest: 0,
    selectedStart: null,   // Date object
    selectedEnd: null,     // Date object
    viewMonth: null,       // {year, month} currently displayed
    selectingStart: true   // toggling between start/end selection
  };

  function open() {
    // 1. Fetch available date range from /api/storage-stats
    // 2. Set initial selection to current view range (or last 7d default)
    // 3. Render calendar for current month
    // 4. Show modal
  }

  function renderCalendar() {
    // Build 6×7 grid for state.viewMonth
    // Gray out dates outside available range
    // Highlight selected start–end range
    // Mark today with accent ring
  }

  function onDateClick(dateObj) {
    // If selecting start: set start, switch to end selection
    // If selecting end: set end (must be >= start)
    // Update calendar highlights and time fields
  }

  function onPresetClick(preset) {
    // Calculate start/end from preset name
    // Set fields, apply immediately, close dialog
  }

  function apply() {
    // Convert selected start/end to epoch range
    // Store as custom range state
    // Trigger chart reload with custom filter
    // Close dialog
  }

  return { open: open, close: close, apply: apply };
})();
```

#### Step 5: Modify chart data filtering for custom range

Currently `loadHistory()` loads all data and the chart rendering filters by `HISTORY_RANGE_HOURS`. Add support for an absolute epoch range:

```javascript
// New state
var CUSTOM_RANGE_START = 0;  // epoch, 0 = not using custom range
var CUSTOM_RANGE_END = 0;

// In chart data filtering, check custom range first:
function getEffectiveTimeRange() {
  if (CUSTOM_RANGE_START > 0 && CUSTOM_RANGE_END > 0) {
    return { start: CUSTOM_RANGE_START, end: CUSTOM_RANGE_END };
  }
  var now = Math.floor(Date.now() / 1000);
  return { start: now - (HISTORY_RANGE_HOURS * 3600), end: now };
}
```

Update all chart rendering and min/max calculation functions to use `getEffectiveTimeRange()` instead of computing from `HISTORY_RANGE_HOURS`.

#### Step 6: CSS styling

Add styles matching the existing dashboard dark theme:

```css
.custom-range-container {
  background: #16213e;
  border: 1px solid #0f3460;
  border-radius: 8px;
  max-width: 520px;
  margin: 5vh auto;
  color: #e0e0e0;
}
.custom-range-body {
  display: flex;
  min-height: 320px;
}
.custom-range-presets {
  width: 140px;
  border-right: 1px solid #0f3460;
  padding: 12px 0;
}
.custom-range-presets button {
  display: block;
  width: 100%;
  text-align: left;
  padding: 8px 16px;
  background: transparent;
  border: none;
  color: #e0e0e0;
  cursor: pointer;
}
.custom-range-presets button:hover {
  background: #0f3460;
}
.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 2px;
  text-align: center;
}
.calendar-day {
  padding: 6px;
  cursor: pointer;
  border-radius: 50%;
}
.calendar-day.in-range {
  background: rgba(0, 212, 255, 0.15);
}
.calendar-day.range-start,
.calendar-day.range-end {
  background: #00d4ff;
  color: #1a1a2e;
  font-weight: bold;
}
.calendar-day.today {
  border: 2px solid #00d4ff;
}
.calendar-day.unavailable {
  color: #555;
  pointer-events: none;
}
```

#### Step 7: Mobile responsiveness

On viewports < 480px, stack the preset sidebar above the calendar:

```css
@media (max-width: 480px) {
  .custom-range-body { flex-direction: column; }
  .custom-range-presets {
    width: 100%;
    border-right: none;
    border-bottom: 1px solid #0f3460;
    display: flex;
    flex-wrap: wrap;
  }
  .custom-range-presets button { width: auto; }
}
```

### 1.5 Testing Checklist

- [ ] Custom button appears after 45d in both min/max and chart panes
- [ ] Dialog opens, shows correct available date range
- [ ] Calendar navigation works (month forward/back)
- [ ] Dates outside available data range are grayed out
- [ ] Start/end date selection works with visual highlighting
- [ ] Quick presets (Today, Yesterday, etc.) set range and close dialog
- [ ] Apply button updates charts to custom range
- [ ] Custom range persists across chart switches until a standard button (24h/7d/etc.) is pressed
- [ ] Cancel closes dialog without changing range
- [ ] Works on mobile viewport
- [ ] Works through Cloudflare tunnel
- [ ] Does not break existing 24h/7d/30d/45d buttons

### 1.6 Files to Change

| File | Changes |
|------|---------|
| `dashboard/dashboard.js` | CustomRange module, getEffectiveTimeRange(), custom button handler |
| `dashboard/dashboard.html` | Custom button in two locations, modal HTML, new CSS |
| `dashboard/dashboard.h` | Regenerated |
| `VERSION` | Bump |
| `firmware/esp32-c3-multi-sensor.yaml` | Version bump |

### 1.7 No Firmware Endpoint Changes Needed

All data filtering is client-side. The `/history/{id}/{metric}` endpoints already return full history. The `/api/storage-stats` endpoint already provides the available date range. No new API endpoints are required.

---

## 2. Playwright Browser Test Automation

### 2.1 Goal

Add repeatable browser automation to validate key dashboard behavior and prevent regressions. Tests run against a local mock backend (not a live ESP device), making them deterministic and CI-friendly.

### 2.2 Architecture

```
tests/
  playwright/
    fixtures/
      sensors.json                 # Mock /sensors.json response
      history-office-temp.txt      # Mock history data
      history-office-hum.txt
      history-first_floor-temp.txt
      history-first_floor-hum.txt
      history-outside-temp.txt
      history-outside-hum.txt
      storage-stats.json           # Mock /api/storage-stats
      status.json                  # Mock /api/status
    helpers/
      mock-server.js               # Express server serving mock data
      test-utils.js                # Shared test helpers
    dashboard.spec.ts              # Page load, cards, theme
    export.spec.ts                 # Export buttons, CSV format
    import-ui.spec.ts              # Import dialog, file selection
    range-selector.spec.ts         # Range buttons, custom date range
playwright.config.ts
package.json                       # Playwright + Express dependencies
```

### 2.3 Mock Server Design

A lightweight Express server that serves:
- `GET /dashboard.html` → the actual dashboard HTML from `dashboard/dashboard.html`
- `GET /sensors.json` → fixture JSON
- `GET /history/:sensor/:metric` → fixture text files
- `GET /api/storage-stats` → fixture JSON
- `GET /api/status` → fixture JSON
- `POST /api/import/begin` → `{"ok":true,"mode":"multi","message":"mock"}`
- `POST /api/reboot` → `{"ok":true,"message":"mock"}`
- SSE endpoint at `/events` that sends periodic state updates (or a no-op for polling mode)

The mock server should be configurable via environment variables for scenarios like "empty history" or "single sensor only".

### 2.4 Fixture Data

Generate realistic fixture data matching the production export format:
- 498 rows covering ~5.6 days at 15-minute intervals
- 3 sensors with realistic temperature (-5°C to 35°C) and humidity (20%–95%) ranges
- Some intentional gaps (missing rows) to test gap handling
- Timestamps in the recent past

Script to generate fixtures:

```javascript
// scripts/generate-test-fixtures.js
const fs = require('fs');
const sensors = ['office', 'first_floor', 'outside'];
const now = Math.floor(Date.now() / 1000);
const start = now - (5.6 * 24 * 3600);

sensors.forEach(sensor => {
  let tempLines = [], humLines = [];
  for (let t = start; t < now; t += 900) {
    if (Math.random() < 0.02) continue; // 2% gaps
    const temp = (20 + 10 * Math.sin(t / 86400 * Math.PI * 2)).toFixed(1);
    const hum = (50 + 20 * Math.cos(t / 86400 * Math.PI * 2)).toFixed(1);
    tempLines.push(`${t},${temp}`);
    humLines.push(`${t},${hum}`);
  }
  fs.writeFileSync(`tests/playwright/fixtures/history-${sensor}-temp.txt`,
                    tempLines.join('\n'));
  fs.writeFileSync(`tests/playwright/fixtures/history-${sensor}-hum.txt`,
                    humLines.join('\n'));
});
```

### 2.5 Test Suites

#### Milestone 1: Smoke/Regression (implement first)

**dashboard.spec.ts:**
```typescript
test('dashboard loads without blank screen', async ({ page }) => {
  await page.goto('/dashboard.html');
  await expect(page.locator('.sensor-card')).toHaveCount(3);
});

test('all sensor cards render with names', async ({ page }) => {
  await page.goto('/dashboard.html');
  await expect(page.getByText('Office')).toBeVisible();
  await expect(page.getByText('First Floor')).toBeVisible();
  await expect(page.getByText('Outside')).toBeVisible();
});

test('theme toggle switches between dark and light', async ({ page }) => {
  await page.goto('/dashboard.html');
  const toggle = page.locator('#themeToggle');
  await toggle.click();
  // Verify body has light mode class
  await expect(page.locator('html')).toHaveClass(/light/);
});

test('charts render without errors', async ({ page }) => {
  await page.goto('/dashboard.html');
  // Wait for Chart.js to load and render
  await page.waitForFunction(() => document.querySelectorAll('canvas').length > 0);
  const canvases = page.locator('canvas');
  await expect(canvases.first()).toBeVisible();
});
```

**export.spec.ts:**
```typescript
test('export buttons are present for each sensor', async ({ page }) => {
  await page.goto('/dashboard.html');
  const exportBtns = page.locator('[data-export-sensor]');
  await expect(exportBtns).toHaveCount(3);
});

test('Export All button is present', async ({ page }) => {
  await page.goto('/dashboard.html');
  await expect(page.locator('[data-export-all]')).toBeVisible();
});
```

**import-ui.spec.ts:**
```typescript
test('Import History button is present', async ({ page }) => {
  await page.goto('/dashboard.html');
  await expect(page.getByText('Import History')).toBeVisible();
});

test('Import triggers file picker', async ({ page }) => {
  // Verify the hidden file input exists
  await page.goto('/dashboard.html');
  const fileInput = page.locator('#importFileInput');
  await expect(fileInput).toBeAttached();
});
```

**range-selector.spec.ts:**
```typescript
test('range buttons render', async ({ page }) => {
  await page.goto('/dashboard.html');
  await expect(page.locator('.range-btn')).toHaveCount.toBeGreaterThan(4);
});

test('clicking 7d button changes active range', async ({ page }) => {
  await page.goto('/dashboard.html');
  const btn7d = page.locator('.range-btn[data-hours="168"]');
  await btn7d.click();
  await expect(btn7d).toHaveClass(/active/);
});
```

### 2.6 Browser Matrix

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
    { name: 'mobile', use: { ...devices['Pixel 5'] } },
  ],
});
```

### 2.7 CI Integration

Add `.github/workflows/browser-tests.yml`:

```yaml
name: Browser Tests
on:
  push:
    paths: ['dashboard/**', 'tests/**']
  pull_request:
    paths: ['dashboard/**', 'tests/**']

jobs:
  playwright:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run test:browser
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```

### 2.8 Implementation Order

1. Set up `package.json` with Playwright + Express dependencies
2. Create mock server in `tests/playwright/helpers/mock-server.js`
3. Generate fixture data
4. Write `playwright.config.ts`
5. Implement `dashboard.spec.ts` (smoke tests) — get this passing first
6. Add remaining test files incrementally
7. Add CI workflow (initially as optional/non-blocking)
8. After stable: promote to blocking checks

---

## 3. Configurable Sensor Count

### 3.1 Goal

Document and validate that the system supports 1–4 sensors without code changes beyond configuration. Provide a clear guide for adding/removing sensors, and add a preflight check to catch mismatches.

### 3.2 What Already Supports Variable Sensor Count

The `SensorSlot` array and `NUM_SENSORS` constant already parameterize sensor count. The dashboard loads sensors dynamically from `/sensors.json`. The key areas that need attention:

| Area | Current State | Action Needed |
|------|--------------|---------------|
| `sensor_history_multi.h` `NUM_SENSORS` | Hardcoded to 3 | Document how to change |
| `sensor_history_multi.h` `sensors[]` array | 3 entries | Must match NUM_SENSORS |
| YAML BLE tracker | 3 sensor blocks | Must match NUM_SENSORS |
| YAML sensor lambdas | 3 sets of lambdas | Must match NUM_SENSORS |
| Dashboard JS | Dynamic from `/sensors.json` | Already flexible |
| `SegmentSnapshot` struct | Arrays sized by NUM_SENSORS | Automatic |
| Flash storage | Segment size scales with NUM_SENSORS | May affect total retention |
| NVS compatibility | Segment size encoded in header | **Breaking change if changed on existing device** |

### 3.3 Implementation Steps

#### Step 1: Document the procedure

Create `Docs/configuring-sensors.md`:

```markdown
# Configuring Sensor Count (1–4)

## Changing the number of sensors

1. In `dashboard/sensor_history_multi.h`:
   - Change `NUM_SENSORS` to 1, 2, 3, or 4
   - Update the `sensors[]` array to match (add/remove SensorSlot entries)

2. In `firmware/esp32-c3-multi-sensor.yaml`:
   - Add/remove BLE tracker sections for each sensor
   - Add/remove the corresponding lambda blocks
   - Update the on_boot lambda if it references sensor indices

3. **IMPORTANT**: Changing NUM_SENSORS changes the SegmentSnapshot size.
   Existing persisted history WILL NOT be compatible. You must erase the
   history partition after changing sensor count:
   - Use the "Delete History" button in the dashboard, OR
   - Flash with `esphome run --clean`

## Adding a 4th sensor

Example SensorSlot entry:
  {
    .id   = "garage",
    .name = "Garage",
    .mac  = "AA:BB:CC:DD:EE:FF"
  }

Example YAML BLE block:
  [copy existing sensor block, change MAC and names]

## Removing a sensor

Remove the SensorSlot entry, decrement NUM_SENSORS, remove the YAML blocks.
Always erase history after changing count.
```

#### Step 2: Add preflight validation

Add to `scripts/preflight.sh`:

```bash
# Count SensorSlot entries in C++ matches NUM_SENSORS
CPP_COUNT=$(grep -c '\.id *=' dashboard/sensor_history_multi.h)
NUM_SENSORS=$(grep 'NUM_SENSORS = ' dashboard/sensor_history_multi.h | grep -oP '\d+')
if [ "$CPP_COUNT" -ne "$NUM_SENSORS" ]; then
  echo "sensor_count_check: FAIL (${CPP_COUNT} slots vs NUM_SENSORS=${NUM_SENSORS})"
  exit 1
fi
echo "sensor_count_check: PASS"
```

#### Step 3: Test with 1, 2, and 4 sensors

For each count, verify: compile succeeds, dashboard renders correct number of cards, export/import works, history persistence works.

### 3.4 Flash Impact Analysis

| NUM_SENSORS | SegmentSnapshot Size | Retention at 512KB | Notes |
|-------------|---------------------|-------------------|-------|
| 1 | ~52 bytes | ~90 days | Excellent |
| 2 | ~100 bytes | ~67 days | Good |
| 3 | ~148 bytes | ~45 days | Current |
| 4 | ~196 bytes | ~34 days | Acceptable |

Document this table in the configuration guide.

---

## 4. Dashboard Minification

### 4.1 Goal

Minify the dashboard HTML/JS/CSS before generating the embedded `.h` header file. This reduces flash usage by ~20–25 KiB, providing headroom for future features.

### 4.2 Approach

Add a minification step between editing `dashboard.html` and generating `dashboard.h`:

```
dashboard.html (source, human-readable)
    ↓  scripts/minify-dashboard.sh
dashboard.min.html (minified, not committed)
    ↓  scripts/generate-header.sh (modified to use .min.html)
dashboard.h (embedded payload, committed)
```

### 4.3 Implementation Steps

#### Step 1: Install minification tools

```bash
npm install -g terser html-minifier-terser
```

Or add to a project-level `package.json` (if created for Playwright):

```json
{
  "devDependencies": {
    "terser": "^5.31.0",
    "html-minifier-terser": "^7.2.0"
  }
}
```

#### Step 2: Create `scripts/minify-dashboard.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

INPUT="${1:-dashboard/dashboard.html}"
OUTPUT="${2:-dashboard/dashboard.min.html}"

npx html-minifier-terser \
  --collapse-whitespace \
  --remove-comments \
  --remove-optional-tags \
  --minify-css true \
  --minify-js '{"compress":{"dead_code":true,"drop_console":false},"mangle":true}' \
  --input "$INPUT" \
  --output "$OUTPUT"

ORIG=$(wc -c < "$INPUT")
MINI=$(wc -c < "$OUTPUT")
SAVED=$((ORIG - MINI))
echo "Minified: ${ORIG} → ${MINI} bytes (saved ${SAVED} bytes, $(( SAVED * 100 / ORIG ))%)"
```

#### Step 3: Modify `scripts/generate-header.sh`

Change the default input to use the minified version if it exists:

```bash
INPUT="${1:-dashboard/dashboard.html}"
MINIFIED="${INPUT%.html}.min.html"
if [ -f "$MINIFIED" ]; then
  INPUT="$MINIFIED"
  echo "Using minified source: $INPUT"
fi
```

#### Step 4: Update build workflow

The build sequence becomes:

```bash
# After editing dashboard.html or dashboard.js:
./scripts/minify-dashboard.sh         # produces dashboard.min.html
./scripts/generate-header.sh          # uses .min.html → dashboard.h
./scripts/preflight.sh                # validates
esphome compile ...
```

#### Step 5: Add to CI

In `.github/workflows/ci.yml`, add the minification step before the compile step:

```yaml
- run: npm install terser html-minifier-terser
- run: ./scripts/minify-dashboard.sh
```

#### Step 6: `.gitignore` the minified intermediate

Add to `.gitignore`:
```
dashboard/dashboard.min.html
```

The minified file is a build artifact, not a source file. Only `dashboard.html` (source) and `dashboard.h` (committed generated output) belong in the repo.

### 4.4 Expected Results

Based on typical HTML/JS/CSS minification ratios:

| File | Original | Minified (est.) | Savings |
|------|----------|-----------------|---------|
| dashboard.html | ~150 KB | ~110 KB | ~40 KB |

At 88.2% flash usage, saving 40 KB brings it down to ~85.9% — meaningful headroom for future features.

### 4.5 Validation

- Dashboard functions identically after minification
- Preflight still passes (the `.h` contains minified content, but the checks reference the source `.js`)
- All Chart.js features work (minification must not break dynamic property access)
- Dark/light theme switching works
- Export/import works
- Test in Firefox (strictest JS engine)

---

## Implementation Order

**Recommended sequence:**

1. **Dashboard minification** (Step 4) — small effort, immediate flash savings, foundation for larger changes
2. **Custom date range** (Step 1) — user-facing feature, dashboard-only, no firmware changes
3. **Playwright automation** (Step 2) — prevents regressions from steps 1–2, locks in quality
4. **Configurable sensor count** (Step 3) — documentation + validation, lowest risk

**Alternative if you want visible progress first:**

1. Custom date range → 2. Minification → 3. Playwright → 4. Sensor count

Each feature should be on its own branch and merged independently.

---

## Critical Rules for All Features

These rules come from accumulated project experience and must be followed:

1. **dashboard.html is the source of truth** — edit HTML, then sync JS, then regenerate .h
2. **dashboard.js and the `<script>` block in dashboard.html must be identical** — always rebuild HTML from parts after editing JS
3. **Run `generate-header.sh` after any HTML change** — dashboard.h is committed but derived
4. **Run `preflight.sh` before every commit** — catches version drift, missing functions, syntax errors
5. **Version strings live in 6 places** — VERSION, dashboard.js, dashboard.html (header comment + description), YAML (header + register_history_handler + dashboard_link), sensor_history_multi.h header
6. **Test in Firefox** — it has stricter cross-origin and privacy behavior
7. **Test through Cloudflare tunnel** — SSE buffering and proxy behavior differ from LAN
8. **When counting characters in URL path prefixes, verify the count** — lesson from BUG-015
9. **URL path is the only reliable data channel to the ESP** — POST body and query params don't work on ESP-IDF
10. **Suspend background polling during long operations** — prevents 502 on the constrained ESP origin
