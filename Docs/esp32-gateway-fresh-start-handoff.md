# ESP32 Gateway — Fresh Start Handoff

_Last updated: 2026-03-11 — v7.4.3.0 complete and merged_
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Current version: v7.4.3.0 — SHIPPED_
_Branch: `main`_

This is the single-source continuity document for resuming development in a fresh session.

---

## Project Summary

An ESP32-C3 SuperMini BLE gateway that receives ThermoPro TP357 temperature/humidity broadcasts and serves an embedded browser dashboard. The device retains 24h of history in RAM and up to 45 days of hourly history persisted to a dedicated NVS flash partition. No cloud services, database, or Home Assistant required.

See [architecture.md](architecture.md) for the full technical design.

---

## Current State (v7.4.3.0 — COMPLETE)

### What is working

- 3-sensor BLE reception (Office, First Floor, Outside)
- Live dashboard with real-time and 15-minute averaged charts
- 45-day hourly persistence to dedicated 512 KiB history partition
- CSV export (per-sensor with prefixed headers, and serialized Export All)
- CSV import — multi-sensor (replacement-first) and single-sensor (non-destructive merge)
- Import works over both LAN direct and Cloudflare tunnel
- `/api/status` health endpoint
- `/api/storage-stats` partition statistics
- Management actions (reboot, delete data) with Basic auth + lockout
- Dark/light mode with chart redraw
- GitHub Actions CI: preflight + compile on every push/PR
- Branch protection on `main`
- Dashboard minification pipeline (v7.4.1.0): html-minifier-terser, ~40KB flash savings
- Custom Date Range Selector (v7.4.2.0): modal calendar, 6 presets, live data-availability footer
- **Playwright browser regression test suite (v7.4.3.0):** 28 tests across 8 groups, mock server, fixture data, separate CI workflow

### Playwright test suite summary (v7.4.3.0)

- `tests/mock-server/server.js` — zero-dependency Node.js mock of the full ESP32 API surface
- `tests/fixtures/` — deterministic fixture data (72h history, 3 sensors, anchored epoch)
- `tests/browser/dashboard.spec.js` — 28 tests across 8 groups (boot/structure, sensor cards, transport/status, history/charts, custom date range, theme toggle, export controls, console error guard)
- `playwright.config.js` — webServer auto-starts mock server before tests
- `.github/workflows/browser-tests.yml` — triggers on dashboard or test file changes only
- **Final result:** 28/28 PASS in CI (required 2 fix iterations after initial implementation)

### Custom date range summary (v7.4.2.0)

- "Custom" button added after 45d in the chart range toggle and all per-sensor min/max toggles
- Modal: 6 presets (Today / Yesterday / Last 24h / 7d / 30d / 45d), navigable calendar with two-click start→end selection, hour+AM/PM time selectors, data-availability footer from `/api/storage-stats`
- `getEffectiveTimeRange()` centralises time-range logic — charts and min/max both route through it
- Custom range state (`CUSTOM_RANGE_START/END`) cleared when any standard preset button is clicked
- "Data available" footer shows full range when both bounds known; "up to [date]" when only newest known; "No persisted history yet" on a freshly-flashed device (first NVS persist happens at 2:10 AM)

### Minification pipeline summary (v7.4.1.0)

```
dashboard.html → minify-dashboard.sh → dashboard.min.html (gitignored)
                                      → generate-header.sh → dashboard.h (committed)
```

- `dashboard.min.html` is never committed — build artifact only
- `generate-header.sh` auto-detects `.min.html` when present (no argument needed)
- CI installs `html-minifier-terser` and runs the full pipeline before preflight
- Local builds without the tool installed still work (fallback to `.html`)
- Typical savings: ~33% of source HTML (~40KB) — confirms script block sync is correct

### Import design summary (unchanged from v7.4.0.2)

**Multi-sensor import** (`POST /api/import/begin`): Erases all history before writing. Full replacement.

**Single-sensor import** (`POST /api/import/begin/single/<sensor_id>`): Does NOT erase history. Merges imported data into existing segments. Other sensors preserved.

**Transport:** Data encoded in URL path. Only proxy-safe channel on this platform.

### Repository coordinates

- **Repo:** `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`
- **Branch:** `main` (v7.4.3.0 merged and tagged)
- **Feature branches:** None open
- **Next branch to create:** `feature/configurable-sensor-count`

### Resource usage (measured at v7.4.2.0, unchanged at v7.4.3.0)

| Metric | Value |
|--------|-------|
| RAM | ~15.8% of 327 KiB |
| Flash | ~86.8% of 1.69 MiB |
| Free heap | ~78–84 KiB typical |
| History partition | 512 KiB dedicated |

**Note:** v7.4.3.0 is test infrastructure only — no firmware change, no device reflash. Device still runs v7.4.2.0 firmware.

---

## Development Environment

- **ESPHome container:** LXC on same LAN as ESP devices
- **Repo clone:** `/root/config/ESP32-GW-multi-sensor`
- **Windows workstation:** GitHub Desktop, VS Code, Git
- **ESP device:** ESP32-C3 SuperMini at 192.168.120.189
- **Cloudflare:** Reverse proxy for internet access

---

## What Comes Next

### Next Feature: v7.4.4.x — Configurable Sensor Count (1–4)

**Branch to create:** `feature/configurable-sensor-count`

Normalize the project so sensor count is clearly documented, safely configurable from 1 to 4, and validated by preflight.

**Key scope points:**
- Document the change procedure clearly (what to change, in what order)
- Add preflight checks validating `NUM_SENSORS` alignment across C++, YAML, and manifest
- Make architecture docs truthful for any supported count
- Explicitly handle retained-history compatibility (sensor count change = history reset required)
- Possibly a dedicated `Docs/configuring-sensors.md`
- Playwright test coverage for card count variation

**Key risks:**
- Silent mismatch between C++ and YAML sensor definitions
- Retained-history corruption or misleading partial compatibility on count change
- Docs claiming configurability before the workflow is actually validated

See [future-plans.md](future-plans.md) for the full roadmap.

---

## Key Lessons — Always Carry Forward

1. **ESPHome ESP-IDF does not deliver POST body** to custom handlers
2. **`url_to()` strips query parameters** — URL path is the only reliable data channel
3. **Custom headers fail through Cloudflare** — CF adds headers that exceed the limit
4. **Export and import must share one canonical schema** — prefixed columns always
5. **Suspend dashboard traffic during long-running operations** — prevents 502s
6. **HTML/JS/.h must stay synchronized** — any dashboard change updates all three
7. **Six version strings must all be bumped together** — see LESSON-OPS-009
8. **Script block sync: use `head -n $((SCRIPT_LINE - 1))`** — verify with `grep -c '^<script>$'` returns exactly 1 afterwards
9. **Minification savings of ~33% confirm correct sync** — savings <10% = script block doubled
10. **`MAX_HISTORY_RANGE_HOURS` must match the largest range button** — mismatch silently truncates history
11. **"Data available: unknown" on fresh device = first NVS persist at 2:10 AM** — not a bug
12. **`package-lock.json` must be committed alongside `package.json`** — `npm ci` will not generate it
13. **New CI workflow files only appear in Actions sidebar after merging to main** — expected behavior
14. **Verify element IDs AND DOM behavior before writing browser tests** — class targets, interaction side-effects, and container relationships all require reading the actual JS and HTML
15. **`data-history-range` values are hours** — 168, 720, 1080; not "7d", "30d", "45d"
16. **`toggleTheme()` applies `light` class to `<html>`, not `<body>`** — test `page.locator('html')` accordingly

See [bugs-and-lessons-learned.md](bugs-and-lessons-learned.md) for the full record.

---

## Documentation Map

| Document | Purpose |
|----------|---------| 
| This file | Complete context for resuming development |
| [architecture.md](architecture.md) | Software design, data flows, retention model |
| [development-pipeline.md](development-pipeline.md) | Workflow, CI, process |
| [changelog.md](changelog.md) | Version history |
| [build-history.md](build-history.md) | Curated build ledger |
| [bugs-and-lessons-learned.md](bugs-and-lessons-learned.md) | Fixes, patterns, pitfalls (reverse chronological) |
| [future-plans.md](future-plans.md) | Roadmap and feature assessment |
| [implementation-plan-next-features-7.4.1.x.md](implementation-plan-next-features-7.4.1.x.md) | Detailed plans for upcoming features |
| [v7.4.0-documentation.md](v7.4.0-documentation.md) | Import v1 per-version reference |
| [v7.3.5.0-documentation.md](v7.3.5.0-documentation.md) | /api/status per-version reference |
| [device-test-report-template.md](device-test-report-template.md) | Post-flash testing checklist |
| Session logs (`session-log-*.md`) | Per-session development history |

---

## How to Start the Next Session

Provide the assistant with:

1. This document or the repo URL
2. Current test results (compile, LAN, Cloudflare)
3. What you want to work on next

Example (starting v7.4.4.x):

> Continuing the ESP32 BLE gateway project.
> Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
> v7.4.3.0 is complete and merged. Device still running v7.4.2.0 firmware (no reflash needed for v7.4.3.0).
> Flash at ~86.8%. Playwright browser tests: 28/28 PASS.
> Ready to start v7.4.4.x — Configurable Sensor Count.
> Please read the handoff doc, implementation plan Feature 3, and provide a detailed implementation plan.
