# ESP32 Gateway — Fresh Start Handoff

_Last updated: 2026-03-12 — v7.4.5.0 complete (ready for review and device validation)_
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Current version: v7.4.5.0 — canonical sensor-manifest workflow added_
_Branch: `main`_

This is the single-source continuity document for resuming development in a fresh session.

---

## Project Summary

An ESP32-C3 SuperMini BLE gateway that receives ThermoPro TP357 temperature/humidity broadcasts and serves an embedded browser dashboard. The device retains 24h of history in RAM and up to 45 days of hourly history persisted to a dedicated NVS flash partition. No cloud services, database, or Home Assistant required.

See [architecture.md](architecture.md) for the full technical design.

---

## Current State (v7.4.5.0 — Manifest-Driven Sensor Configuration Added)

### What is working

- 3-sensor BLE reception (Office, First Floor, Outside)
- Live dashboard with real-time and 15-minute averaged charts
- 45-day hourly persistence to dedicated 512 KiB history partition
- CSV export (per-sensor with prefixed headers, and serialized Export All)
- CSV import — multi-sensor (replacement-first) and single-sensor (merge-first)
- Import works over both LAN direct and Cloudflare tunnel
- `/api/status` health endpoint
- `/api/storage-stats` partition statistics
- Management actions (reboot, delete data) with Basic auth + lockout
- Dark/light mode with chart redraw
- GitHub Actions CI: preflight + compile on every push/PR
- Branch protection on `main`
- Dashboard minification pipeline (v7.4.1.0): html-minifier-terser, ~40KB flash savings
- Custom date range selector (v7.4.2.0)
- Playwright browser regression suite (v7.4.3.0)
- Configurable sensor count 1–4 (v7.4.4.0)
- **Canonical manifest workflow (v7.4.5.0):**
  - `config/sensors.json` is now the single source of truth
  - `scripts/change_sensor_number.py` provides an interactive add/remove workflow
  - `scripts/render_sensor_config.py` regenerates the header, firmware YAML, dashboard fallback metadata, and baseline fixture manifest
  - `scripts/history_backup.py` provides CLI export/import for retained history backup and restore during sensor-count changes
  - `scripts/preflight.sh` now validates manifest drift and regenerates root fixtures from the active manifest before optional browser smoke checks

### Important retained-history rule

Changing sensor count still changes the persisted history schema.

The correct safe workflow is:

1. Export/backup retained history first
2. Change sensor configuration
3. Validate + flash new firmware
4. Delete old retained history on the device
5. Re-import the saved data

### Single-sensor import design summary

Single-sensor import is not just “non-destructive” in a vague sense.

The important implementation detail is:

- the firmware scans existing NVS segments and builds an epoch-to-slot map during `/api/import/begin/single/<sensor_id>`
- when an imported hour already exists, the firmware reads that segment, overlays only the target sensor’s temp/humidity arrays, and writes the merged segment back to the same slot
- when the hour does not already exist, it allocates a new slot
- temporary working memory during the merge path is about 7 KB

That behavior should be preserved in future documentation and code discussions.

### Immediate next validation work

1. Run the new manifest workflow in the real repo clone:
   - `python3 scripts/change_sensor_number.py`
   - `bash ./scripts/preflight.sh`
2. Device-validate at least one real sensor-count change path (for example 3 → 2 or 3 → 4)
3. Confirm the CLI backup/restore helper against the real ESP endpoints
4. Update CI or workflow docs further only if device validation exposes gaps

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

16. **Fixture CSVs must use epoch seconds** — dashboard multiplies by 1000 expecting seconds; `Date.UTC()` returns milliseconds (LESSON-OPS-029)

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
