# Session Log — 2026-03-21 — v7.5.4.5 Post-Phase-4 Review and Fixes

**Version:** v7.5.4.5 (patch)
**Session type:** Comprehensive Phase 4 review + bugfix
**Baseline:** v7.5.4.4 on `main` (Phase 4 complete)

---

## Session Goal

Full post-Phase-4 review: assess implementation quality vs architecture plan,
identify gaps and regressions, fix calendar CSS issues, fix API contract
violations, and document findings for future prompt improvement.

## Issues Found

### BUG-052 — `/sensors.json` includes non-environmental devices

The v1 legacy endpoint `/sensors.json` returned all 4 devices including
`wan_ping`. The architecture plan (Section 5.3) specifies this as an
environmental-only projection. None of the Phase 4 prompts instructed the
coding agent to update `handle_manifest_()` when adding the ping device.

**Fix:** Filter `handle_manifest_()` to only emit devices with `category_id == 0`.

### BUG-053 — `/api/status` outputs ThermoPro fields for all device categories

The status handler output `temp_valid` and `hum_valid` for every device
including `wan_ping` where they are always `false` and semantically meaningless.

**Fix:** Add `category` field to each sensor entry. Only emit `temp_valid`/`hum_valid`
for environmental devices (`category_id == 0`).

### BUG-054 — Calendar date picker dark/light mode CSS issues

Custom Date Range modal had two styling problems:
- **Dark mode:** Native browser date picker calendar popup rendered with white
  background because `color-scheme: dark` was not set on `<input type=date>`
  and `<select>` elements. Time dropdown also had no dark-mode-aware styling.
- **Light mode:** From/To date inputs and time selects had hardcoded dark
  background (`rgba(15,23,42,.5)`) instead of white. Modal buttons also had
  dark backgrounds.

**Fix:** Added `color-scheme:dark` to date/select inputs in default (dark) mode.
Added comprehensive `:root.light` overrides for `.cr-time-row input[type=date]`,
`.cr-time-row select`, `.cr-btn`, `.cr-btn.primary`, and `.auth-*` elements.

### BUG-056 — WAN Latency data plotted on Temperature/Humidity charts

Multi-layer failure: `mkDS()` created chart datasets for all sensors including
network, `fetchDeviceHistory()` fallback fetched ping data via legacy
`/history/wan_ping/temp` path, firmware returned ping HistoryBuffer contents.

**Fix:** Six changes across dashboard.js, dashboard.html, and sensor_history_multi.h:
- `applySensorMeta()`: assign `s.chartIdx` (environmental=0,1,2,...; others=-1)
- `mkDS()`: filter to `chartIdx >= 0` before creating datasets
- `handleState()`: guard chart push with `s.chartIdx >= 0`
- `applyHistoryRange()`: skip non-environmental, use `s.chartIdx`
- `loadHistory()`: skip non-environmental sensors
- `handle_history_()`: 404 for non-environmental on legacy `/history/{id}/temp|hum`

### BUG-055 — `bump-version.sh` produces stale `dashboard.h`

`generate-header.sh` auto-selects `dashboard.min.html` when it exists, but
`bump-version.sh` never re-minified after updating `dashboard.html`. The stale
`.min.html` still contained the old `App.version`, causing preflight failure.

**Fix:** `bump-version.sh` now checks for `.min.html` and either re-runs
`minify-dashboard.sh` (if installed) or removes the stale file.

## Heap Analysis (informational — no code change)

### SSE/Hosted mode heap drop (dashboard-hosted-mode-heap-drop-1/2.png)

~40KB drop (73K → 34K) over 30-60 seconds on page load or F5. Caused by
sequential history fetches — each environmental sensor's history response
builds a ~33KB `std::string` from NVS flash segments. Six history responses
(3 sensors × 2 metrics) produce the sawtooth. The pre-reserved string
pattern (BUG-043 fix) is already optimal for this web server architecture.

Reducing this further would require paginated history (`?since=epoch`) so the
dashboard only fetches incremental data on refresh — a Phase 5+ optimization.

### Polling mode heap oscillation (dashboard-polling-mode-8h-running.png)

39K-73K oscillation over 8 hours from LWIP TCP buffer allocation/deallocation
during REST polling cycles. Every 15s poll cycle allocates TCP socket buffers
that are freed on connection close. This is inherent to HTTP-based polling on
a constrained device. Increasing poll interval from 15s to 30s would reduce
frequency but the pattern is fundamental.

## Files Changed

| File | Change |
|------|--------|
| `dashboard/dashboard.html` | Calendar CSS: `color-scheme:dark`, light-mode overrides; chart category filtering (`chartIdx`) |
| `dashboard/dashboard.js` | Chart category filtering mirrored from dashboard.html |
| `dashboard/sensor_history_multi.h` | `handle_manifest_()`: environmental filter. `handle_status_()`: category field. `handle_history_()`: 404 for non-environmental legacy paths |
| `scripts/bump-version.sh` | Re-minify or remove stale `.min.html` before `generate-header.sh` |
| `Docs/changelog.md` | v7.5.4.5 entry |
| `Docs/bugs-and-lessons-learned.md` | BUG-052 through BUG-056, LESSON-OPS-064 through LESSON-OPS-066 |
| `Docs/session-log-2026-03-21-v7.5.4.5-post-phase4-fixes.md` | This file |

## Prompt Quality Notes (for later discussion)

Phase 4 prompts were well-structured but had a blind spot: none of them
scoped the impact of adding a new device category on existing endpoints
(`/sensors.json`, `/api/status`). The prompts focused on the new code path
(adapter, card renderer, tests) but did not include a checklist item like
"verify ALL existing endpoints emit correct data for the new device type."

Recommendation: add an "endpoint audit" step to any phase that introduces
a new device category or changes the device list shape.
