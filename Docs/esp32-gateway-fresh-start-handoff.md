# ESP32 Gateway — Fresh Start Handoff

_Last updated: 2026-03-10 (repo normalization)_
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Current version: v7.4.1.0 — VALIDATED AND MERGED_
_Branch: `main`_

This is the single-source continuity document for resuming development in a fresh session.

---

## Project Summary

An ESP32-C3 SuperMini BLE gateway that receives ThermoPro TP357 temperature/humidity broadcasts and serves an embedded browser dashboard. The device retains 24h of history in RAM and up to 45 days of hourly history persisted to a dedicated NVS flash partition. No cloud services, database, or Home Assistant required.

See [architecture.md](architecture.md) for the full technical design.

---

## Current State (v7.4.1.0 — COMPLETE)

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
- **Dashboard minification pipeline** (v7.4.1.0): html-minifier-terser + terser, ~40KB flash savings

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

### v7.4.1.0 status

- Remote commit: ✅ DONE
- Local sed steps (dashboard.js, dashboard.html version strings): ✅ DONE
- Minification run: ✅ DONE
- Regenerate dashboard.h: ✅ DONE
- Preflight: ✅ PASS (23/23)
- Compile: ✅ PASS
- Device test: ✅ PASS
- Merged to main: ✅ DONE
- Tagged v7.4.1.0: ✅ DONE

### Repository coordinates

- **Repo:** `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`
- **Branch:** `main` (v7.4.1.0 merged and tagged)
- **Feature branches:** None (all stale branches deleted after normalization)

### Resource usage (measured at v7.4.1.0)

| Metric | Value |
|--------|-------|
| RAM | ~15.8% of 327 KiB |
| Flash | ~86.1% of 1.69 MiB (after minification, down from ~88.2% at v7.4.0.2) |
| Free heap | ~78-84 KiB typical |
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

### Next Feature: v7.4.2.0 — Custom Date Range Selector

**Branch to create:** `feature/custom-date-range`

This is a **dashboard-only change** (no firmware or endpoint changes). A detailed design document and implementation plan is available in:
- [planning-v7.4.2.0-custom-date-range.md](planning-v7.4.2.0-custom-date-range.md) — full UX spec, JS module design, acceptance criteria
- [implementation-plan-next-features-7.4.1.x.md](implementation-plan-next-features-7.4.1.x.md) — Feature 2 section

**Summary:**
- Add "Custom" button after 45d in min/max and chart panes
- Date-range picker modal (vanilla JS, no external library)
- `getEffectiveTimeRange()` centralises time-range logic
- `CustomRange` IIFE module: calendar, presets, start/end selection
- Standard range buttons clear custom range state
- Fetches `/api/storage-stats` at dialog-open time for available date range
- Mobile responsive

**Steps to start:**
1. Create branch: `git checkout -b feature/custom-date-range`
2. Read the planning document above for full design details
3. Implement dashboard.html and dashboard.js changes
4. Run pipeline: `minify-dashboard.sh` → `generate-header.sh` → `preflight.sh`
5. Compile, flash, test
6. Commit, push, open PR

### After v7.4.2.0

1. **Playwright browser test automation** (v7.4.3.x) — mock backend + CI
2. **Configurable sensor count** (v7.4.4.x) — docs + preflight validation

See [future-plans.md](future-plans.md) and [implementation-plan-next-features-7.4.1.x.md](implementation-plan-next-features-7.4.1.x.md) for detail.

---

## Key Lessons — Always Carry Forward

1. **ESPHome ESP-IDF does not deliver POST body** to custom handlers
2. **`url_to()` strips query parameters** — returns path only
3. **Custom headers fail through Cloudflare** — CF adds headers that exceed 512-byte limit
4. **URL path is the universal reliable channel** — proven in this codebase
5. **Export and import must share one canonical schema** — prefixed columns always
6. **Silent fallback to default sensor is dangerous** — fail explicitly instead
7. **Suspend dashboard traffic during long-running operations** — prevents 502s
8. **When import data is a subset of storage structure, merge rather than replace** — epoch-to-slot map approach
9. **Keep HTML/JS/.h synchronized** — any dashboard change must update all three
10. **Check all version strings after every bump** — VERSION, YAML, JS, register_history_handler, HTML comments
11. **Large files (>100KB) require local sed for version bumps** — GitHub API has payload limits; use targeted sed -i for single-line changes in dashboard.js and dashboard.html
12. **generate-header.sh auto-detects .min.html** — CI gets minified binary automatically; local without tools falls back gracefully
13. **Doc-only commits still trigger CI** (~4.5 min compile); batch all doc changes into a single commit to minimise CI runs

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
| [implementation-plan-next-features-7.4.1.x.md](implementation-plan-next-features-7.4.1.x.md) | Detailed plans for next 4 features |
| [planning-v7.4.2.0-custom-date-range.md](planning-v7.4.2.0-custom-date-range.md) | Design spec for v7.4.2.0 (next feature) |
| [v7.4.0-documentation.md](v7.4.0-documentation.md) | Import v1 per-version doc |
| [device-test-report-template.md](device-test-report-template.md) | Post-flash testing checklist |
| [session-log-2026-03-09-v7.4.0.2.md](session-log-2026-03-09-v7.4.0.2.md) | v7.4.0.2 session log |
| [session-log-2026-03-10-v7.4.1.0.md](session-log-2026-03-10-v7.4.1.0.md) | v7.4.1.0 session log |
| [session-log-2026-03-10-v7.4.1.0-repo-normalization.md](session-log-2026-03-10-v7.4.1.0-repo-normalization.md) | Repo normalization session log |

---

## How to Start the Next Session

Provide the assistant with:

1. This document or the repo URL
2. Current test results (compile, LAN, Cloudflare)
3. What you want to work on next

Example (starting v7.4.2.0):

> Continuing the ESP32 BLE gateway project.
> Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
> v7.4.1.0 is complete and merged. Flash at ~86.1%.
> Ready to start v7.4.2.0 — custom date range selector.
> Please read the planning document and implement.
