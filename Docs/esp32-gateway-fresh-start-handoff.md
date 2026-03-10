# ESP32 Gateway — Fresh Start Handoff

_Last updated: 2026-03-09_
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Current version: v7.4.0 (pending merge of PR #2)_
_Active branch: `feature/import-v1`_

This is the single-source continuity document for resuming development in a fresh session.

---

## Project Summary

An ESP32-C3 SuperMini BLE gateway that receives ThermoPro TP357 temperature/humidity broadcasts and serves an embedded browser dashboard. The device retains 24h of history in RAM and up to 45 days of hourly history persisted to a dedicated NVS flash partition. No cloud services, database, or Home Assistant required.

See [architecture.md](architecture.md) for the full technical design.

---

## Current State

### What is working (v7.4.0 on feature/import-v1)

- 3-sensor BLE reception (Office, First Floor, Outside)
- Live dashboard with real-time and 15-minute averaged charts
- 45-day hourly persistence to dedicated 512 KiB history partition
- CSV export (per-sensor and serialized Export All)
- **CSV import via `POST /api/import/{begin,d/,w/,finish}`** — NEW in v7.4.0
- `/api/status` health endpoint
- `/api/storage-stats` partition statistics
- Management actions (reboot, delete data) with Basic auth + lockout
- Dark/light mode with chart redraw
- GitHub Actions CI: preflight + compile on every push/PR
- Branch protection on `main`

### Import transport status

Import uses a **URL-path-based** data transport:
```
POST /api/import/d/office,temp,1772528400,21.50;office,hum,...   (accumulate data)
POST /api/import/w/office,temp,1772531100,20.70;...              (accumulate + write to NVS)
```

This design was reached after three transport iterations that failed:
1. POST body — ESPHome ESP-IDF never delivers body to handler
2. URL query parameters — `url_to()` strips query string, returns path only
3. Custom headers (X-Data) — works on LAN but Cloudflare adds headers that exceed ESP-IDF's 512-byte header buffer limit, causing HTTP 431

The URL path approach is the proven channel (already used by `/history/{id}/temp` through Cloudflare).

**Testing status as of session end:**
- Multi-sensor import via LAN: **PASS** (135 segments, 2988 accepted)
- Single-sensor import via LAN: **PASS** (with X-Data transport) / **UNTESTED** with path transport
- Import via Cloudflare tunnel: **UNTESTED** with path transport — this is the key test for tomorrow

### Pending before merge

1. Flash the latest path-based transport build
2. Test import via LAN (both multi-sensor and single-sensor CSV)
3. Test import via Cloudflare tunnel
4. If all pass: convert PR #2 to ready, merge, tag v7.4.0

### Repository coordinates

- **Repo:** `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`
- **Main version:** v7.3.5.0 (after PR #1 merge)
- **Feature branch:** `feature/import-v1` at v7.4.0
- **PR #2:** Draft, CI should be green after latest push

### Resource usage

| Metric | Value |
|--------|-------|
| RAM | ~15.8% of 327 KiB |
| Flash | ~88.2% of 1.69 MiB |
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

## What Was Accomplished This Session

### 1. Documentation reorganization (complete)

Rewrote the entire Docs structure from 13 overlapping files to a clean purpose-driven set. Created root README with screenshots. Committed and pushed to main.

### 2. Import v1 feature (in progress — PR #2)

Full CSV import capability with browser-side parsing/validation and ESP-side NVS writes.

**Transport evolution (critical context):**
- Attempt 1: POST body via `handleBody()` → failed (ESP-IDF doesn't call it)
- Attempt 2: URL query params → failed (`url_to()` strips query string)
- Attempt 3: Custom headers (X-Data/X-Write) → works on LAN, fails through Cloudflare (431)
- **Attempt 4: URL path encoding** → current approach, should work everywhere

### 3. Version bump v7.3.5.0 (complete)

Updated VERSION, YAML, dashboard.js, register_history_handler across all locations.

### 4. Cosmetic fixes (complete)

- Dashboard description shortened to 4 lines, updated to v7.4.0
- History Storage card header includes context note, verbose footer removed
- Stale v7.3.4.2 references cleaned from YAML and C++ header comments

---

## What Comes Next — Priority Order

### Immediate: Validate path-based import transport

1. Flash latest build from `feature/import-v1`
2. Test import via LAN direct (multi-sensor + single-sensor CSVs)
3. Test import via Cloudflare tunnel (the critical test)
4. If pass → merge PR #2, tag v7.4.0

### After v7.4.0 merge

1. **Custom date range selector** — dashboard-only change
2. **Playwright browser test automation** — mock backend, CI workflow
3. **Configurable sensor count** — comment-based 1-4 sensor config
4. **Dashboard minification** — free up flash headroom

See [future-plans.md](future-plans.md) for the complete roadmap.

---

## Key Lessons From This Session

1. **ESPHome ESP-IDF does not deliver POST body** to custom handlers — `handleBody()` is Arduino-only
2. **`url_to()` strips query parameters** — returns path only
3. **Custom headers fail through Cloudflare** — CF adds its own headers, total exceeds ESP-IDF's 512-byte limit
4. **`CONFIG_HTTPD_MAX_REQ_HDR_LEN: "2048"` crashes the dashboard** — too much RAM per connection on 320KB device
5. **URL path is the universal reliable channel** — preserved by all proxies, already proven in this codebase
6. **`time()` is ambiguous in ESPHome** — must use `::time()` to avoid conflict with `esphome::time` namespace
7. **Import should not erase history before data is validated** — destructive-first is a design risk (partially addressed: begin still erases, but browser validates comprehensively before calling begin)

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
| [v7.4.0-documentation.md](v7.4.0-documentation.md) | Per-version doc for import v1 |
| [device-test-report-template.md](device-test-report-template.md) | Post-flash testing checklist |

---

## How to Start the Next Session

Provide the assistant with:

1. This document or the repo URL
2. Whether PR #2 has been merged or is still on the feature branch
3. Import test results (LAN and Cloudflare)

Example:

> Continuing the ESP32 BLE gateway project.
> Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
> PR #2 merged / still on feature/import-v1.
> Import via Cloudflare: PASS / FAIL with error: ...
> Next step: [merge and tag / fix import / custom date range]
