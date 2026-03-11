# Changelog

All notable changes to the ESP32-C3 Multi-Sensor BLE Gateway.

---

## v7.4.1.0 — 2026-03-10

**Added:** Dashboard minification pipeline

- New script `scripts/minify-dashboard.sh` — runs `html-minifier-terser` on `dashboard.html` to produce `dashboard.min.html` (build artifact, gitignored)
- `scripts/generate-header.sh` updated — auto-detects `dashboard.min.html` when present; falls back to `dashboard.html` if not (backwards-compatible)
- CI workflow updated — installs `html-minifier-terser`, runs minify → generate-header → preflight → compile in sequence
- `.gitignore` updated — adds `dashboard/dashboard.min.html` and `node_modules/`
- Expected flash savings: ~40KB (~88% → ~86%)

**Pipeline sequence (local):**
```
dashboard.html → minify-dashboard.sh → dashboard.min.html (gitignored)
                                      → generate-header.sh → dashboard.h (committed)
```

**Key behaviours:**
- `dashboard.min.html` is never committed — it is a build artifact
- `generate-header.sh` picks up `.min.html` automatically when present (no argument needed)
- CI always produces the minified binary; local builds without the tool fall back gracefully

---

## v7.4.0.2 — 2026-03-09

**Added:** Single-sensor non-destructive import

- New endpoint: `POST /api/import/begin/single/<sensor_id>` for merge import
- Single-sensor CSV import now preserves other sensors' data in flash
- Firmware builds epoch-to-slot map to locate existing segments for merge
- Existing segments are read, overlaid with imported sensor data, and written back
- New segments created only for hours not already in flash
- Dashboard auto-detects single vs multi sensor from CSV columns
- Confirmation dialog adapts messaging: "replace all" vs "replace sensor X only"

**Fixed:** Import mode selection

- Multi-sensor CSV import still uses replacement-first model (unchanged behavior)
- Single-sensor import no longer erases flash before writing

---

## v7.4.0.1 — 2026-03-09 (rolled into v7.4.0 codebase)

**Fixed:** Single-sensor CSV export/import schema mismatch

- Single-sensor CSV exports now use prefixed headers (`outside_temp_c`) matching merged export format
- Legacy bare-header single-sensor CSVs handled safely via filename detection
- Removed unsafe fallback that silently mapped ambiguous files to first sensor (Office)
- Added import time estimate to confirmation dialog
- Added remaining-time indicator during batch import progress

**Fixed:** Import failures through Cloudflare tunnel

- Dashboard suspends background polling/SSE during import to reduce origin pressure
- Added pacing delays between batches (120ms data, 320ms write)
- Added retry with exponential backoff for transient tunnel errors (502/503/504)
- Eliminated HTTP 502 "Bad Gateway" during sustained import over Cloudflare

---

## v7.4.0 — 2026-03-09 (merged via PR #2)

**Added:** CSV import feature

- New import endpoints: `POST /api/import/begin`, `/api/import/d/<data>`, `/api/import/w/<data>`, `/api/import/finish`
- Data transported via URL path (proxy-safe, works through Cloudflare)
- Replacement-first model: existing history cleared before import
- Browser-side validation: timestamp range, value ranges, sensor ID matching, deduplication
- ESP-side validation: sensor lookup, epoch range, value bounds, segment slot overflow
- Dashboard UI: "Import History" button in management card, file picker, progress display, auto-reload
- Supports both single-sensor and merged multi-sensor CSV formats (auto-detected from column headers)
- Sequential batch upload with configurable batch size (250 chars/batch)
- Safe JSON response handling for non-JSON server errors

**Fixed:** Dashboard description and storage text

- Dashboard description shortened to 4 lines, updated to v7.4.0
- History Storage card: verbose footer replaced with inline header note
- Stale v7.3.4.2 references cleaned from YAML comments and C++ header

**Transport evolution (development history):**
This feature went through four transport iterations before reaching the final design:
1. POST body via `handleBody()` — ESP-IDF does not call this (Arduino-only API)
2. URL query parameters — `url_to()` strips query string
3. Custom headers (X-Data/X-Write) — works on LAN, fails through Cloudflare (HTTP 431)
4. URL path encoding — final design, proxy-safe

---

## v7.3.5.0 — 2026-03-08

**Added:** `/api/status` health endpoint

- New `GET /api/status` endpoint returning JSON with version, uptime, sensor count, per-sensor health, free heap
- No authentication required (read-only health check)
- First feature developed through the full GitHub PR workflow (PR #1)

**Fixed:** JSON truncation bug in `/api/status`

- Three JSON fields packed into single `snprintf` targeting 64-byte buffer. Output was 72 bytes. Fix: split into separate print calls.

**Infrastructure:**

- Branch protection configured on `main`
- Root README.md with screenshots in Images/
- Documentation reorganized: 13 overlapping files consolidated into purpose-driven structure
- `scripts/test-local.sh` added
- `Docs/device-test-report-template.md` added
- Version bump applied across VERSION, YAML, dashboard.js, register_history_handler

---

## v7.3.4.2 — 2026-03-07

**Fixed:** Four dashboard issues

- `Export All` HTTP 502 — serialized fetches via `fetchAllSensorHistoryRowsSequentially()`
- Chart point markers not following sensor recolor — updated all marker properties
- 15-minute chart markers oversized — matched to real-time size
- Theme toggle not forcing chart redraw — added `refreshChartsAfterVisualChange()`

**Infrastructure:**

- Repository normalized to canonical paths
- GitHub Actions CI pipeline established
- Helper scripts: preflight, generate-header, deploy, compile-with-log, test-local
- Secrets handling: example committed, real gitignored, CI uses dummy secrets

---

## v7.3.4.1 — 2026-03-06

**Fixed:** Dashboard startup blocker — initialization ordering for `bindEvents()`

---

## v7.3.4 — 2026-03-06

**Changed:** Phase 1 structural enforcement — `App.State` chokepoints, centralized `bindEvents()`, removed inline handlers

---

## v7.3.3 — 2026-03-05

**Baseline:** Stabilization release. Transport/CORS/date-axis regressions addressed.

---

## Earlier versions

See previous changelog entries in git history. Key milestones:
- v7.x: Dedicated history partition, 45-day retention, storage stats, management section
- v6.0: Persistent history (daily NVS snapshots, 30 days)
- v5.0: Dashboard features (min/max, RSSI, dew point, dark/light, CSV export)
- v4.x: Embedded dashboard in firmware
- v3: Per-sensor tracking, batched polling
- v2: AsyncWebHandler pattern for ESP-IDF
- v1: Multi-sensor SensorSlot architecture

---

## v7.4.2.0 — 2026-03-11

**Added:** Custom Date Range Selector

- New "Custom" button added after 45d in both the 15-minute averaged chart range toggle and per-sensor min/max pane toggles
- Clicking Custom opens a modal date-range picker: 6 quick-select presets (Today, Yesterday, Last 24h, Last 7d, Last 30d, Last 45d), a month calendar with two-click start→end selection, hour + AM/PM time selectors, and an available-data footer sourced from `/api/storage-stats`
- Custom range applies simultaneously to all chart views and min/max calculations
- Standard range buttons (24h/7d/30d/45d) clear the custom range state when clicked
- Calendar greys out dates outside the flash-retained data window
- Mobile-responsive: preset sidebar stacks above calendar on narrow viewports
- Matches existing dark/light theme via CSS custom properties

**Fixed:** BUG-016 — `MAX_HISTORY_RANGE_HOURS` was 720 (30d) but 45d range button existed

- `MAX_HISTORY_RANGE_HOURS` corrected to 1080 (45 days)
- History store trim logic now correctly retains up to 45 days of 15-min data
- Without this fix, the 45d chart button would trim data at 30d

**Fixed:** `sensor_history_multi.h` file header comment

- Header comment still referenced `v7.4.0.2`; corrected to `v7.4.2.0`

**Architecture additions:**
- `getEffectiveTimeRange()` — centralises all time-range logic; returns `{start, end}` in ms; custom range takes priority over preset hours
- `CUSTOM_RANGE_START` / `CUSTOM_RANGE_END` — module-level epoch state; 0 = inactive
- `CustomRange` IIFE — `open()`, `close()`, `apply()`, `bindModalEvents()`; fully self-contained
- `filterPointsForRange()` — now zero-argument; delegates to `getEffectiveTimeRange()`
