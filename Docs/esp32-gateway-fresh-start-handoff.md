# ESP32 Gateway — Fresh Start Handoff

_Last updated: 2026-03-09_
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Current version: v7.4.0.2 (pending compile/test)_
_Branch: `main`_

This is the single-source continuity document for resuming development in a fresh session.

---

## Project Summary

An ESP32-C3 SuperMini BLE gateway that receives ThermoPro TP357 temperature/humidity broadcasts and serves an embedded browser dashboard. The device retains 24h of history in RAM and up to 45 days of hourly history persisted to a dedicated NVS flash partition. No cloud services, database, or Home Assistant required.

See [architecture.md](architecture.md) for the full technical design.

---

## Current State (v7.4.0.2)

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

### Import design summary

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

**Transport**: Data encoded in URL path (`/api/import/d/<data>`, `/api/import/w/<data>`). This is the only proxy-safe channel on this platform.

**Stabilization**: Dashboard suspends background polling/SSE during import, adds pacing delays and retry/backoff for Cloudflare reliability.

### v7.4.0.2 status

- Preflight: PASS (23 checks)
- Compile: PENDING
- Device test: PENDING

### Repository coordinates

- **Repo:** `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`
- **Branch:** `main` at v7.4.0.2

### Resource usage (last measured at v7.4.0)

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

## What Comes Next — Priority Order

### Immediate: Validate v7.4.0.2

1. Compile firmware
2. Flash and test single-sensor import (verify other sensors preserved)
3. Test multi-sensor import (regression check)
4. Test both via LAN and Cloudflare
5. If pass: tag v7.4.0.2

### After v7.4.0.2 validation

1. **Custom date range selector** — dashboard-only change
2. **Playwright browser test automation** — mock backend, CI workflow
3. **Configurable sensor count** — comment-based 1-4 sensor config
4. **Dashboard minification** — free up flash headroom

See [future-plans.md](future-plans.md) for the complete roadmap.

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
| [v7.4.0-documentation.md](v7.4.0-documentation.md) | Import v1 per-version doc |
| [device-test-report-template.md](device-test-report-template.md) | Post-flash testing checklist |

---

## How to Start the Next Session

Provide the assistant with:

1. This document or the repo URL
2. Current test results (compile, LAN, Cloudflare)
3. What you want to work on next

Example:

> Continuing the ESP32 BLE gateway project.
> Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
> v7.4.0.2 validated — single-sensor merge works, multi-sensor regression clean.
> Next step: custom date range selector
