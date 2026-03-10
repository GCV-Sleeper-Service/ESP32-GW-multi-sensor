# Changelog

All notable changes to the ESP32-C3 Multi-Sensor BLE Gateway.

---

## v7.4.0 — 2026-03-09 (pending merge)

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
