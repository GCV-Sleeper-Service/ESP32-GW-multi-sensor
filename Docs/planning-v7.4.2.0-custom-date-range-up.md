# Planning — v7.4.2.0 Custom Date Range Selector

_Last updated: 2026-03-10_
_Status: planned, not yet implemented_
_Baseline repo version: v7.4.1.0_

This document is a feature-specific planning supplement for the next implementation session.
The cross-feature priority order lives in `Docs/implementation-plan-next-features-7.4.1.x.md`.

---

## Feature Intent

Add a **Custom** date-range selector to the dashboard so the user can inspect arbitrary historical windows bounded by the actual stored data.

The existing fixed ranges remain:

- 24h
- 7d
- 30d
- 45d

The new custom range should sit alongside those presets rather than replace them.

---

## What Must Stay True

- Fixed preset buttons must continue to work exactly as they do now
- No backend protocol redesign should be required
- Filtering should remain browser-side
- The dashboard must remain dependency-light and embedded-friendly
- Mobile behavior must be considered during the first implementation, not as an afterthought

---

## Existing Data/State Sources

The feature should build on what already exists:

- `/history/{sensor_id}/{metric}` endpoints already provide the data stream needed for client-side filtering
- `/api/storage-stats` provides the available retained date bounds
- Current dashboard state already tracks fixed history ranges and chart redraw behavior

---

## UI Direction

Recommended UI shape:

- `Custom` button added after `45d`
- Modal/dialog overlay styled to match the existing dashboard
- Start and end date/time fields
- Available-range display from oldest/newest retained data
- Cancel/apply actions
- Preset selection should clear custom-range state

A Home Assistant-inspired feel is acceptable, but it should remain a lightweight custom implementation rather than a transplanted UI dependency.

---

## Suggested Internal Behavior

### App state

Add explicit custom-range state:

```javascript
customDateRange: {
  active: false,
  fromEpoch: null,
  toEpoch: null
}
```

### Filtering behavior

When custom range is active:

- Charts filter data to `[fromEpoch, toEpoch]`
- Min/max calculations must use the filtered dataset
- Any badge or range label should make the active mode obvious

When a preset is selected:

- Custom range is cleared
- Preset behavior resumes as the active source of truth

---

## Files Likely to Change

- `dashboard/dashboard.html`
- `dashboard/dashboard.js`
- `dashboard/dashboard.h` (generated)
- `VERSION`
- `firmware/esp32-c3-multi-sensor.yaml`
- Session log
- Handoff
- Changelog/build-history if the implementation is accepted

---

## Risks to Watch Closely

- Event binding regressions from modal UI additions
- Stale chart/min-max state after switching between preset and custom ranges
- Mobile layout issues for the date picker dialog
- Theme/redraw problems after applying a custom range
- Additional browser-path differences between LAN direct and Cloudflare/public access

---

## Validation Checklist for the Implementation Session

- [ ] Custom button appears in the intended locations
- [ ] Dialog opens/closes reliably
- [ ] Available data bounds are shown correctly
- [ ] Applying a range updates charts correctly
- [ ] Preset buttons still work after custom range use
- [ ] Min/max summaries reflect the active range
- [ ] Theme switch still redraws correctly
- [ ] Chrome / Firefox / Edge sanity check completed
- [ ] Mobile-browser sanity check completed
