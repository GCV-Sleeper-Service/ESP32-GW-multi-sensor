# Changelog

All notable changes to the ESP32-C3 Multi-Sensor BLE Gateway.

---

## v7.3.5.0 — 2026-03-08

**Added:** `/api/status` health endpoint

- New `GET /api/status` endpoint returning JSON with version, uptime, sensor count, per-sensor health (id, name, last_seen, temp/hum validity), RAM history points, persist days, and free heap
- No authentication required (read-only health check)
- First feature developed through the full GitHub PR workflow (PR #1)

**Fixed:** JSON truncation bug in `/api/status`

- Initial implementation packed three JSON fields into a single `snprintf` call targeting a 64-byte buffer. Formatted output was 72 bytes, causing silent truncation. Fix splits into three separate `snprintf` + `print` calls.

**Infrastructure:**

- Branch protection configured on `main` (requires PR + CI green)
- Root README.md removed from Docs/ and relocated to repo root
- `scripts/test-local.sh` added for one-command local validation
- `Docs/device-test-report-template.md` added

---

## v7.3.4.2 — 2026-03-07

**Fixed:** Four dashboard issues on top of the v7.3.4 structural work

- `Export All` failing with HTTP 502 — serialized retained-history fetches to reduce ESP/proxy request bursts
- Chart point markers not following sensor recolor — updated all marker-related properties during recolor
- 15-minute chart markers oversized — reduced to match real-time chart marker size
- Theme toggle not forcing chart redraw — added `refreshChartsAfterVisualChange()` call on theme switch

**Infrastructure:**

- Repository normalized to canonical paths (no more versioned filenames in includes/scripts)
- GitHub Actions CI pipeline established (preflight + compile)
- Helper scripts added: `preflight.sh`, `generate-header.sh`, `deploy-to-esphome.sh`, `compile-with-log.sh`
- `.gitignore` configured for secrets, build logs, and ESPHome build directories
- `VERSION` file added to repo root
- Secrets handling: example file committed, real secrets gitignored, CI uses temporary dummy secrets

---

## v7.3.4.1 — 2026-03-06

**Fixed:** Dashboard startup blocker

- Dashboard stayed on "connecting..." due to event binding timing issue introduced in v7.3.4 structural changes
- Repaired initialization ordering to ensure bindEvents() fires after DOM is ready

---

## v7.3.4 — 2026-03-06

**Changed:** Phase 1 structural enforcement

- Introduced `App.State` write chokepoints to centralize state mutations
- Centralized `bindEvents()` function replacing scattered inline handlers
- Removed inline `onclick`/`onchange` handlers from HTML
- Prepared codebase for safer incremental feature additions

---

## v7.3.3 — 2026-03-05

**Baseline:** Stabilization release

- Addressed transport/CORS/date-axis regressions from earlier versions
- App namespace and plugin hooks in place
- Dashboard/history decoupled in YAML include order
- Considered the stable baseline before Phase 1 structural work

---

## v7.2.5 and earlier — Pre-GitHub era

These versions were delivered as ZIP bundles before the GitHub-first workflow was established.

### v7.x Series — Dedicated History Partition + Dashboard Evolution

- Hourly persistence to a dedicated 512 KiB NVS history partition (replacing daily snapshots to default NVS)
- 45-day retention (up from 30 days)
- `/api/storage-stats` endpoint with partition info and retention estimates
- Dashboard management section (reboot, delete data with Basic auth)
- History storage statistics panel in dashboard
- GPIO pinout diagram
- Documentation cards
- Comfort level estimate (ASHRAE-55-inspired proxy)
- 24h/7d/30d/45d min/max selectors

### v6.0 — Persistent History Release

- Reduced live RAM retention from 72h to 24h
- Added daily NVS snapshot persistence for up to 30 days
- Boot-time restore of newest valid snapshot
- Expanded min/max selectors to 24h/7d/30d
- Excel-friendly CSV timestamps (YYYY-MM-DD HH:MM:SS)
- `/history/*` endpoints stream persisted + live data merged

### v5.0 — Dashboard Features

- 24h/72h min/max toggle per sensor card
- BLE RSSI signal bars with color-coded strength
- Dew point calculation (Magnus formula, browser-side)
- Dark/light mode toggle
- Staleness indicator (yellow >2min, red >5min)
- CSV history export (per-sensor and Export All)

### v4.x — Embedded Dashboard

- v4.6.2: Fixed dashboard serving runtime panic (`beginResponse(data, size)`)
- v4.5: Pivoted to embedded dashboard in .h header with custom HTTP routes
- v4.4: Attempted LittleFS dashboard hosting (validation failure — abandoned)

### v3 — Per-Sensor Tracking

- Per-sensor `last_seen` tracking
- Explicit "NA" gap handling for stale data
- Batched polling for Cloudflare compatibility

### v2 — AsyncWebHandler Pattern

- Fixed `AsyncWebHandler` pattern for ESPHome ESP-IDF compatibility

### v1 (originally v11) — Multi-Sensor Architecture

- `SensorSlot` struct replacing per-sensor globals
- Streaming HTTP endpoints for efficient history delivery
- Custom `AsyncWebHandler` registered via `WebServerBase::add_handler()`
