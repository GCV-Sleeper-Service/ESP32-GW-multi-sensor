# ESP32 Gateway — Fresh Start Handoff

_Last updated: 2026-03-11 — v7.4.3.0 (Playwright test suite)
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Current version: v7.4.3.0 — PENDING CI
_Branch: `main`_

This is the single-source continuity document for resuming development in a fresh session.

---

## Project Summary

An ESP32-C3 SuperMini BLE gateway that receives ThermoPro TP357 temperature/humidity broadcasts and serves an embedded browser dashboard. The device retains 24h of history in RAM and up to 45 days of hourly history persisted to a dedicated NVS flash partition. No cloud services, database, or Home Assistant required.

See [architecture.md](architecture.md) for the full technical design.

---

## Current State (v7.4.2.0 — COMPLETE)

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
- Dashboard minification pipeline (v7.4.1.0): html-minifier-terser, ~60KB flash savings
- **Custom Date Range Selector (v7.4.2.0):** Custom button in both chart and min/max panes, modal calendar picker with presets, range applied to all charts simultaneously

### Custom date range summary (v7.4.2.0)

- "Custom" button added after 45d in the chart range toggle and all per-sensor min/max toggles
- Modal: 6 presets (Today / Yesterday / Last 24h / 7d / 30d / 45d), navigable calendar with two-click start→end selection, hour+AM/PM time selectors, data-availability footer from `/api/storage-stats`
- `getEffectiveTimeRange()` centralises time-range logic — charts and min/max both route through it
- Custom range state (`CUSTOM_RANGE_START/END`) cleared when any standard preset button is clicked
- "Data available" footer shows full range when both bounds known; "up to [date]" when only newest known; "No persisted history yet" on a freshly-flashed device (first NVS persist happens at 2:10 AM)
- Mobile responsive (sidebar stacks above calendar below 480px)

### Minification pipeline summary

**Local build sequence:**
```
dashboard.html → minify-dashboard.sh → dashboard.min.html (gitignored)
                                      → generate-header.sh → dashboard.h (committed)
```

**Key behaviours:**
- `dashboard.min.html` is never committed — it is a build artifact
- `generate-header.sh` auto-detects `.min.html` when present (no argument needed)
- CI installs `html-minifier-terser` and runs the full pipeline before preflight
- Local builds without the tool installed still work (fallback to `.html`)
- Typical savings: ~33% of source HTML (60KB) — confirms script block sync is correct

### Import design summary (unchanged from v7.4.0.2)

**Multi-sensor import** (`POST /api/import/begin`):
- Erases all history before writing
- Sequential batch upload via URL-path encoding
- Full replacement of all sensor data

**Single-sensor import** (`POST /api/import/begin/single/<sensor_id>`):
- Does NOT erase history
- Builds epoch-to-slot map by scanning existing NVS segments
- Merges imported data into existing segments (overlays target sensor only)
- Creates new segments for hours not found in existing data
- Other sensors' data is preserved

**Transport**: Data encoded in URL path. This is the only proxy-safe channel on this platform.

### Repository coordinates

- **Repo:** `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`
- **Branch:** `main` (v7.4.2.0 merged and tagged)
- **Feature branches:** None open

### Resource usage (measured at v7.4.2.0)

| Metric | Value |
|--------|-------|
| RAM | ~15.8% of 327 KiB |
| Flash | ~86.8% of 1.69 MiB (unchanged — no reflash for v7.4.3.0) |
| Free heap | ~78–84 KiB typical |
| History partition | 512 KiB dedicated |

---

## Development Environment

- **ESPHome container:** LXC on same LAN as ESP devices
- **Repo clone:** `/root/config/ESP32-GW-multi-sensor`
- **Windows workstation:** GitHub Desktop, VS Code, Git
- **ESP device:** ESP32-C3 SuperMini at 192.168.120.189
- **Cloudflare:** Reverse proxy for internet access

---

## What Comes Next — Priority Order

### Next Feature: v7.4.4.x — Configurable Sensor Count (1–4)

**Branch to create:** `feature/playwright-tests`

Add automated browser regression coverage so dashboard changes stop relying only on manual checks. See [implementation-plan-next-features-7.4.1.x.md](implementation-plan-next-features-7.4.1.x.md) — Feature 2 section for full spec.

**Summary:**
- Mock Express backend serving fixture data (no real ESP required)
- Playwright test suite covering: page load, chart rendering, range buttons, custom date range dialog, import/export UI, theme toggle
- Dedicated CI workflow (separate from ESPHome compile)
- Screenshots/traces on failure
- Chrome/Chromium first

### After v7.4.3.x

1. **Configurable sensor count** (v7.4.4.x) — docs + preflight validation for 1–4 sensors

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
8. **Script block sync: use `head -n $((SCRIPT_LINE - 1))`** then append JS then `</script>` and tail — verify with `grep -c '^<script>$'` returns exactly 1 afterwards
9. **Minification savings of ~33% confirm correct sync** — if savings are <10%, the script block was embedded twice
10. **`</script>` inside JS strings breaks HTML parsing** — minification with `--minify-js` can be sensitive to this; validate with the smoke test after any minifier flag change
11. **"Data available: unknown" in the custom range dialog = no persisted data yet** — first NVS persist at 2:10 AM; not a bug
12. **`MAX_HISTORY_RANGE_HOURS` must match the largest range button** — mismatch silently truncates history display
13. **Large files (>100KB) require local sed for version bumps** — GitHub API has payload limits
14. **`generate-header.sh` auto-detects `.min.html`** — CI gets minified binary automatically

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
| [bugs-and-lessons-learned.md](bugs-and-lessons-learned.md) | Fixes, patterns, pitfalls |
| [future-plans.md](future-plans.md) | Roadmap and feature assessment |
| [implementation-plan-next-features-7.4.1.x.md](implementation-plan-next-features-7.4.1.x.md) | Detailed plans for next features (Playwright, sensor count) |
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

Example (starting v7.4.3.x):

> Continuing the ESP32 BLE gateway project.
> Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
> v7.4.2.0 is complete and merged. Flash at ~86.8%.
> Ready to start v7.4.3.x — Playwright browser test automation.
> Please clone the repo, read the implementation plan, and implement.
