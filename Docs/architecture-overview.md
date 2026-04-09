# ESP32-GW Multi-Sensor — Architecture Overview

_Last updated: 2026-04-08 — Phase X complete, Phase Y planned._

---

## Project Summary

A manifest-driven IoT gateway platform built on ESP32. Receives BLE sensor broadcasts, accepts pushed metrics from external systems, aggregates data from multiple satellite gateways, and serves everything through an embedded HTML dashboard with real-time charts.

**Current version:** v7.6.5.8 — Phase X complete (Dashboard Architecture Refactor).

---

## System Architecture

### Hardware Targets

| Board | Role | PSRAM | Max Satellites |
|-------|------|-------|----------------|
| ESP32-C3 SuperMini | Satellite only | None | N/A |
| ESP32-WROOM-32D | Satellite only | None | N/A |
| ESP32-S3-DevKitC1-N16R8 | Satellite + Aggregator | 8MB | 8 |

**Design rule:** Aggregator role is restricted to PSRAM-equipped boards. No PSRAM = satellite-only; 2MB PSRAM caps at 4 satellites; 4MB+ caps at 8 satellites.

### Firmware Stack

- **ESPHome 2026.2.1** with ESP-IDF 5.5.2 backend
- Local component override at `firmware/local_components/web_server_idf/` (httpd stack patched to 16KB)
- Board profiles in `firmware/boards/*.yaml` drive code generation via `render_sensor_config.py`
- NVS persistence for satellite configuration (Phase D) and sensor history
- Deferred task pattern for NVS handlers (httpd task is too small for NVS operations)

### Dashboard Architecture (Phase X)

The dashboard was refactored from a 3,955-line monolith into a modular component architecture:

- **`dashboard/core/`** — 10 core JS modules + `base.css`
- **`dashboard/components/*/`** — 9 components (7 full triad: JS + HTML + CSS; 1 template+CSS only; 1 JS-only)
- **`dashboard/dashboard.tmpl.html`** — HTML template with placeholder markers
- **`dashboard.js`** and **`dashboard.html`** are **generated artifacts** — never edit directly

**Three-pass build pipeline:**
1. Pass 0: Concatenate CSS files → replace `{{CSS_PLACEHOLDER}}`
2. Pass 1: Replace `{{COMPONENT:name}}` markers → component templates
3. Pass 2: Replace `{{JS_PLACEHOLDER}}` → bundled JS

See `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` for the full dashboard architecture plan.

### Build Pipeline

Canonical regeneration (all 8 steps):
```
bundle-dashboard.sh --write → render_sensor_config.py --write →
generate-fixtures.js → render_sensor_config.py --write →
build-dashboard.sh --write → minify-dashboard.sh →
generate-header.sh → render_sensor_config.py --check
```

Board switching: `scripts/provision.sh <aggregator|wroom|satellite>`. Always run `provision.sh satellite` before pushing (CI safety).

### Test Infrastructure

- **Playwright:** 402 tests across 4 fixture sets (3sensor, mixed, system, aggregator)
- **Preflight:** 68 checks including component file existence, bundle sync, build sync
- **CI:** GitHub Actions with matrix strategy for fixture variants

---

## Phase History

| Phase | Version Range | Scope | Status |
|-------|--------------|-------|--------|
| Phase 1 | v7.5.0.x | Manifest v2 endpoint | ✅ Complete |
| Phase 2 | v7.5.1.x | Dashboard consumes manifest | ✅ Complete |
| Phase 3 | v7.5.3.x | SensorEntity C++ model | ✅ Complete |
| Phase 4 | v7.5.4.x | First non-climate sensor (ping) | ✅ Complete |
| Phase 5 | v7.5.5.x | Aggregator MVP | ✅ Complete |
| Phase 6 | v7.5.6.x | Data ingest + system metrics | ✅ Complete |
| Phase D | v7.6.0.x | Runtime satellite management | ✅ Complete |
| Phase X | v7.6.4.0–v7.6.5.8 | Dashboard architecture refactor | ✅ Complete |
| **Phase Y** | **v7.6.6.x** | **Firmware refactor (sensor_history_multi.h)** | **Planned** |
| Phase 7 | v7.7.0.x–v7.7.2.x | Per-device persistence engine | Planned |
| Phase E | v8.0.x | Captive portal + WiFi config | Not yet planned |

---

## Active Planning Documents

| Document | Purpose |
|----------|---------|
| `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` | Phase Y firmware refactor plan |
| `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` | Phase Y current state inventory |
| `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` | Phase X plan (methodology reference) |
| `Docs/phase-d-implementation-plan.md` | Phase D plan (API contracts reference) |
| `Docs/v7.7-implementation-plan.md` | Phase 7 step-level scope |
| `Docs/v7.7-v7.8-persistence-architecture.md` | Phase 7/8 persistence design |
| `Docs/changelog.md` | Full version history |
| `Docs/lessons/index.md` | Bugs and lessons learned (by domain) |
| `Docs/writing-guide/methodology.md` | Prompt writing methodology |
| `Docs/aggregator-setup.md` | Operator documentation for aggregator configuration |
| `Docs/data-ingest-setup.md` | Operator documentation for data ingest |
| `Docs/esp32-board-selection-guide.md` | Board selection and capability reference |
| `prompts/prompt-index-and-workflow.md` | Master prompt index and workflow |
| `prompts/handoff/phaseX-results.md` | Phase X delivery record |
| `prompts/handoff/phaseD/phaseD-results.md` | Phase D delivery record |

---

## Key Architectural Constraints

These constraints are enforced by Critical Rules and must be observed in all future phases:

1. **POST body handling:** ESPHome only supports `application/x-www-form-urlencoded`. All `fetch()` POST calls use `body: 'a=1'`. No JSON POST bodies.
2. **httpd stack:** ESPHome hardcodes httpd task stack at 4KB. Local component override patches to 16KB. NVS operations still require deferred task pattern (`xTaskCreate`, 8192+ byte stack).
3. **Generated artifacts:** `dashboard.js`, `dashboard.html`, `dashboard.h`, and board-specific YAML are all generated. Never edit directly.
4. **Dense array invariant:** No code may cache a satellite's array index and assume it remains stable across add/delete operations.
5. **PSRAM partitioning:** Aggregator role requires PSRAM. Scaling caps enforced per board profile.
6. **`ota_0` at `0x10000`:** All partition tables must maintain this offset.

---

## Archived Documentation

Historical plans, session logs, and postmortems are preserved in `Docs/archive/`:
- `Docs/archive/session-logs/` — all session logs
- `Docs/archive/completed-phases/` — Phase 3–6 implementation plans, v7.5-v7.6 architecture plan
- `Docs/archive/phase-x-artifacts/` — Phase X revision notes, dependency audit, context docs
- `Docs/archive/postmortems/` — BUG-075/076 postmortem and documentation updates
- `Docs/archive/phase-X-plans/` — Phase X plan drafts from multiple agents

---

_End of document._
