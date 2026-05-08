# Phase 9 — Cloud Data Upload Plan

_Date: 2026-05-07 (multi-phase planning session)_
_Version range: v9.0.x_
_Depends on: Phase 7 (persist cycle hooks), Phase 8 (TLS infrastructure shared)_

---

## Goal

Optional cloud data upload for long-term storage and external dashboards. InfluxDB Cloud first, MQTT bridge included. Opt-in, disabled by default, zero impact when disabled. Local-first philosophy preserved.

## Architecture Decisions

| ID | Decision | Rationale |
|---|---|---|
| C-1 | Aggregator as cloud gateway (satellites proxy through aggregator) | Single TLS connection, aggregator has all data |
| C-2 | InfluxDB Cloud as primary target | Native time-series, free tier, simple line protocol |
| C-3 | Upload on persist cycle (hourly), not real-time | Piggybacks on NVS persist; ~500 bytes/device/hour |
| C-4 | Cloud credentials in NVS (same pattern as notifications) | Consistent credential management |
| C-5 | MQTT bridge included (not deferred) | ESPHome native support, Home Assistant integration |
| C-6 | Store-and-forward ring buffer (24 unsent segments) | Handles transient WiFi outages without data loss |

## Step Breakdown

| Step | Version | Scope | Version bump? |
|---|---|---|---|
| 9.0 | — | Research: InfluxDB line protocol, MQTT + ESPHome coexistence, esp_tls heap | No |
| 9.1 | v9.0.0.1 | Cloud settings NVS schema + dashboard config UI | Yes |
| 9.2 | v9.0.0.2 | InfluxDB upload: esp_tls POST, hourly upload task | Yes |
| 9.3 | v9.0.1.1 | Store-and-forward: ring buffer for unsent segments | Yes |
| 9.4 | v9.0.2.1 | MQTT bridge: ESPHome MQTT component integration | Yes |
| 9.5 | v9.0.3.1 | Dashboard cloud status indicator, upload history | Yes |

## Local-First Philosophy

- Disabled by default. `#if CLOUD_ENABLED` guards around all cloud code.
- Graceful degradation when cloud unreachable — no errors, no degraded dashboard.
- History, dashboard, import/export, notifications all work without cloud.
- README update: "No cloud required. Optional cloud upload for long-term storage."

## Memory/Flash Budget

| Component | Heap | Flash |
|---|---|---|
| Cloud settings + credentials | ~1 KB | ~5 KB |
| InfluxDB upload task | 4 KB stack + ~40 KB TLS (temporary) | ~15 KB |
| Store-and-forward ring (24 segments) | ~6 KB | ~2 KB |
| MQTT component (if enabled) | ~10 KB | ~20-30 KB |
| **Total (with MQTT)** | **~21 KB static + 40 KB peak** | **~47-52 KB** |

Same TLS board capability matrix as Phase 8 — cloud upload only on PSRAM + C6 boards.

---

_End of Phase 9 plan._
