# Planning Document — v7.4.2.0 Custom Date Range Selector

_Status: PLANNING — not yet implemented_
_Extracted from: session-log-2026-03-10 (design session, no code applied)_
_Target version: v7.4.2.0_
_Prerequisite: v7.4.1.0 validated and merged (✅ DONE)_

This document captures the full design specification for the custom date range feature.
Implementation has NOT started. This is the reference document to use when beginning
the v7.4.2.0 development session.

---

## Feature Summary

Add a "Custom" button after the existing 24h/7d/30d/45d selectors in both the
sensor min/max pane and the 15-minute averaged chart pane. Clicking it opens
a date-range picker dialog. The selected range applies to all charts
simultaneously. Standard range buttons remain fully functional and clear
the custom range state.

---

## Design Constraints

- **No external library.** Vanilla JS only — keeps firmware self-contained.
- **No firmware changes.** Dashboard-only change. All data already available client-side.
- **No new endpoints.** `/history/{sensor_id}/{series}` already returns full history.
  `/api/storage-stats` already provides `retention_oldest_epoch` / `retention_newest_epoch`.
- Matches existing dark theme (`--bg-card`, `--border`, `--accent-green`)
- Light theme compatible (`:root.light` overrides included)
- Modal pattern identical to the existing `authModal`
- Mobile-responsive: sidebar stacks above calendar on viewports < 480px

---

## UX Design

### Trigger
- "Custom" button added after the 45d button in:
  - The sensor min/max pane (`#minmaxRangeToggle`)
  - The 15-minute averaged chart pane (`#historyRangeToggle`)

### Dialog Layout
- Left sidebar: 6 quick-select presets
  - Today, Yesterday, Last 24h, Last 7 days, Last 30 days, Last 45 days
- Center: Calendar month view with `<` / `>` navigation
- Right panel: Start/End date + hour + AM/PM selectors
- Footer strip: "Data available" showing `retention_oldest_epoch` → `retention_newest_epoch`
- Buttons: Cancel | Apply

### Interaction
- Two-click start→end calendar selection with range highlighting
- Preset buttons set range immediately and close the dialog
- Apply button sets range, triggers `loadHistory()`, closes dialog
- Cancel closes without changing current range
- Standard range buttons (24h/7d/30d/45d) zero out `CUSTOM_RANGE_START/END`

---

## Implementation Design

### New state variables (module-level in dashboard.js)

```javascript
let CUSTOM_RANGE_START = 0;  // epoch int, 0 = not in use
let CUSTOM_RANGE_END   = 0;  // epoch int, 0 = not in use
```

### New function: `getEffectiveTimeRange()`

Centralises time-range logic. Returns `{start, end}` epoch pair.
All chart rendering and min/max calculation paths route through this.

```javascript
function getEffectiveTimeRange() {
  if (CUSTOM_RANGE_START && CUSTOM_RANGE_END) {
    return { start: CUSTOM_RANGE_START, end: CUSTOM_RANGE_END };
  }
  const end = Math.floor(Date.now() / 1000);
  const start = end - (App.State.historyRangeHours * 3600);
  return { start, end };
}
```

### New module: `CustomRange` IIFE

| Method | Purpose |
|--------|---------|
| `open()` | Fetch `/api/storage-stats`, initialise state, render dialog |
| `renderCalendar(year, month)` | Build 6×7 grid; grey out unavailable dates |
| `onDateClick(dateObj)` | Two-click start→end selection with visual highlighting |
| `onPresetClick(name)` | Map preset label to epoch range, apply immediately |
| `apply()` | Set `CUSTOM_RANGE_START/END`, trigger `loadHistory()`, close dialog |
| `close()` | Hide modal, no state change |

### `bindEvents()` update

`data-hours="custom"` branch calls `CustomRange.open()` instead of
`App.State.setHistoryRangeHours()`. Standard range buttons zero
`CUSTOM_RANGE_START/END` before proceeding.

### `filterPointsForRange()` update

Call `getEffectiveTimeRange()` instead of computing a fixed cutoff
from `HISTORY_RANGE_HOURS`.

### `setHistoryRange()` update

Zero `CUSTOM_RANGE_START/END` before applying a standard range,
preventing stale custom state.

---

## Files to Change

| File | Change |
|------|--------|
| `dashboard/dashboard.html` | Add "Custom" button, modal markup, CSS (`.custom-range-*`, `.calendar-*`) |
| `dashboard/dashboard.js` | Add state vars, `getEffectiveTimeRange()`, `CustomRange` IIFE, update `bindEvents/filterPoints/setHistoryRange` |
| `dashboard/dashboard.h` | Regenerate via pipeline |
| `firmware/esp32-c3-multi-sensor.yaml` | Version bump (4 locations) |
| `VERSION` | `7.4.1.0` → `7.4.2.0` |
| `Docs/` | Session log, handoff update, changelog entry, build history entry |

---

## Acceptance Criteria

1. "Custom" button appears after 45d in both min/max and chart panes
2. Clicking Custom opens the date-range dialog
3. Calendar renders for current month; available range footer shows correct dates
4. Preset buttons (Today, Yesterday, Last 24h, etc.) work and close the dialog
5. Calendar start/end selection works with range highlighting
6. Apply button updates charts to the custom range
7. Standard range buttons (24h/7d/30d/45d) clear the custom range
8. Cancel closes dialog without changing current range
9. Works on mobile viewport (sidebar stacks above calendar)
10. Light theme displays correctly in the dialog
11. No JS console errors
12. Preflight 23/23 PASS
13. Flash remains below 90%

---

## Lessons Identified (for when implementing)

1. **`getEffectiveTimeRange()` prevents range state fragmentation** — centralise
   time-range calculation into one function so every future feature gets the
   correct range automatically.
2. **Custom range state must be cleared by standard buttons** — forgetting this
   causes standard buttons to appear active but charts still render the old
   custom range.
3. **Storage-stats fetch at dialog-open time is correct** — ensures the displayed
   available range is always current, even after data import or extended uptime.
