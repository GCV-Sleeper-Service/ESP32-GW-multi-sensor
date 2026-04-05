# Phase X Plan — Revision Changelog

_Date: 2026-04-05_
_Applied to: `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`_

---

## Summary

The Phase X plan has been revised against the actual codebase at HEAD `24f68ab`. The most significant change is a complete rewrite of the module boundary table (§4.1) — the original plan assigned functions to modules based on logical grouping rather than physical file position, which would have broken the identity gate.

---

## Critical Fix: Module Boundaries (§4.1)

### Problem

The original plan's 21 modules assigned functions to modules by logical affinity (e.g., all export functions in one module, all helpers in another). However, the identity gate requires byte-identical output when modules are concatenated in order. This means each module must be a **contiguous slice** of the original `dashboard.js` — functions cannot be moved between modules.

The original assignments were incorrect in several ways:

| Original assignment | Actual position | Problem |
|---|---|---|
| `buildSingleSensorCsv` in `18-export.js` | Line 529 (in history fetch section) | 983 lines away from `exportSensorCSV` at line 1512 |
| `triggerCsvDownload` in `18-export.js` | Line 363 (in helpers section) | 1149 lines away from `exportSensorCSV` |
| `esc*`, `cToF` in `03-helpers.js` | Lines 810–813 (after status snapshot) | Plan placed them at ~200, actual position ~810 |
| `DEFAULT_SENSOR_META` in `04-manifest.js` | Lines 196–202 (in sensor defs section) | `makeSensorConfig` starts at line 592, 390 lines later |
| `loadHistory` in `05-history.js` | Line 2943 (after charts) | Plan grouped it with `fetchDeviceHistory` at line 433 |
| Modules 15 (management) before 16 (suspend) | File has suspend at 1677, management at 1780 | Reversed order would break identity gate |

### Fix

All 21 modules were remapped as contiguous file slices. Module names were updated to reflect their actual contents (e.g., `01-config-transport.js` + `02-state.js` → `01-config-state.js` since config and state are physically adjacent and only 46+72 lines). An explicit note was added explaining that module assignments reflect physical file position, not ideal logical grouping.

### Module name changes

| Old name | New name | Reason |
|---|---|---|
| `01-config-transport.js` + `02-state.js` | `01-config-state.js` | Merged — only 46+72 lines when split; physically adjacent |
| `03-helpers.js` | `02-sensor-defs.js` | Actually contains sensor defs, generator markers, and metric formatters — not esc/cToF |
| `04-manifest.js` | `04-manifest.js` | Same name but different content — no longer includes DEFAULT_SENSOR_META |
| `05-history.js` | `03-history-fetch.js` | Contains fetch + CSV builders; `loadHistory` is actually in module 17 |
| `06-status-storage.js` | `05-status-snapshot.js` | Split — storage stats are at line 1576, not adjacent to status snapshot |
| `07-ui-events.js` | `06-ui-helpers.js` | Actually contains esc*, cToF, formatBytes which were previously in `03-helpers` |
| `09-minmax.js` | `15-minmax.js` | updateMinMax is at line 2629, not 1158; setMinMaxPeriod stays in staleness-derived |
| `10-custom-range.js` | `08-custom-range.js` | Renumbered to match file order |
| `11-cards.js` | `14-cards.js` | CARD_RENDERERS at line 2414, not 1000s |
| `12-charts.js` | `16-charts.js` | Charts start at line 2681 |
| `13-transport.js` + `14-live-devices.js` | `17-live-updates.js` + `18-transport.js` | Transport/SSE at 3037, live updates at 2881 |
| `18-export.js` | `09-export.js` | exportSensorCSV at line 1512 (after CustomRange) |
| (new) | `10-storage-stats.js` | applyStorageStats/loadStorageStats at 1576 — separate from status snapshot |

---

## Revision Notes Incorporation

All three items from `Docs/phase-x-revision-notes.md` have been incorporated:

### Item 1: Documentation Split as Pre-Step v7.6.4.0

- Added `v7.6.4.0` step to §6 with full scope, split targets, and acceptance criteria
- Includes both bugs/lessons split and writing guide split
- Updated §8 to reference v7.6.4.0 instead of v7.6.5.8
- Updated §10 rollout order with pre-step
- Updated v7.6.5.8 scope to remove doc restructuring
- Updated §12 version mapping table
- Updated header version range to `v7.6.4.0–v7.6.5.8`

### Item 2: Implementation Prompts as Deliverable

- Added §15 "Implementation Prompts" section specifying the `prompts/phaseX/` directory structure and prompt anatomy

### Item 3: SVG Board Images Future Enhancement

- Added future enhancement note to §4.3 `device-info` component description
- Notes that existing C3 SVG should be extracted during v7.6.5.5

---

## Other Changes

| Section | Change | Reason |
|---|---|---|
| §2.5 | Generator markers referenced as `02-sensor-defs.js` not `04-manifest.js` | Markers are at lines 196–202, within the sensor-defs slice |
| §4.3 core files | Updated file names to match corrected module names | Consistency with §4.1 |
| §4.3 device-info | Added `(includes existing C3 board SVG)` to template.html description | Revision notes Item 3 |
| §6 v7.6.5.0 | Bundle script MODULES array uses corrected names | Consistency with §4.1 |
| §6 v7.6.5.4 | File moves table uses corrected source module names | Consistency with §4.1 |
| §9 | Task size examples use corrected module names and line counts | Consistency with §4.1 |
| §10 | Added pre-step gate condition | v7.6.4.0 added |
| §15→§16 | Reconciliation notes renumbered, step count updated to 10 | v7.6.4.0 added |

---

_End of revision changelog._
