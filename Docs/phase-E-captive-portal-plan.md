# Phase E — Captive Portal Provisioning Plan

_Date: 2026-05-07 (multi-phase planning session)_
_Version range: v8.0.x_
_Depends on: Phase 7 complete_

---

## Goal

A freshly flashed board creates a WiFi AP, serves a configuration portal, accepts credentials and role selection, and reboots into station mode. Eliminates the requirement to edit `secrets.yaml` and recompile for each new deployment.

## Architecture Decisions

| ID | Decision | Rationale |
|---|---|---|
| E-1 | ESPHome `captive_portal:` component as base, custom HTML overlay | Reuses AP/DNS plumbing; replace UI only |
| E-2 | WiFi credentials in NVS (runtime), not `secrets.yaml` (compile-time) | First-boot AP mode → portal → NVS → reboot → station mode |
| E-3 | Role selection gated by `esp_psram_get_size()` at runtime | No PSRAM = satellite only; 2 MB = ≤4 sats; 4 MB+ = ≤8 sats |
| E-4 | Sensor discovery (BLE + Zigbee) deferred to Phase E-b | Complex; MVP uses compile-time manifest |
| E-5 | Portal HTML embedded in firmware (not separate partition) | Small (~5-10 KB gzipped); fits alongside dashboard |
| E-6 | Factory reset = targeted NVS namespace clear + reboot to AP | Follows existing deferred task pattern |

## Step Breakdown

### Phase E-a: Minimum Viable Portal (v8.0.0.x)

| Step | Version | Scope | Version bump? |
|---|---|---|---|
| E-a.0 | — | Research: ESPHome captive_portal internals, HTML replaceability | No |
| E-a.1 | v8.0.0.1 | NVS WiFi credential storage; boot check: NVS → station, else → AP | Yes |
| E-a.2 | v8.0.0.2 | Portal HTML: WiFi form, device name, role selector (PSRAM-gated) | Yes |
| E-a.3 | v8.0.0.3 | Reboot-to-station after portal submission | Yes |
| E-a.4 | v8.0.0.4 | Factory reset: `POST /api/system/factory-reset` | Yes |

### Phase E-b: Sensor Discovery (v8.0.1.x) — depends on Phase 7

| Step | Scope |
|---|---|
| E-b.0 | BLE scan: discover ThermoPro/BLE sensors, present MAC list (research) |
| E-b.1 | Zigbee coordinator mode: open network, discover Zigbee devices |
| E-b.2 | User selects sensors (BLE and/or Zigbee), saved to NVS |
| E-b.3 | Boot: read sensor config from NVS, generate runtime manifest |

### Phase E-c: Aggregator Setup Wizard (v8.0.2.x) — depends on E-b

| Step | Scope |
|---|---|
| E-c.0 | Satellite discovery via mDNS/broadcast (research) |
| E-c.1 | Aggregator setup wizard: select satellites, configure polling |
| E-c.2 | Regression and phase closure |

## Memory/Flash Budget

| Component | Heap | Flash |
|---|---|---|
| WiFi provisioning code | ~2 KB (NVS ops, temporary) | ~8-12 KB |
| Portal HTML (gzipped) | ~5-10 KB (static const) | ~5-10 KB |
| PSRAM detection logic | Negligible | ~500 B |
| Factory reset handler | Negligible (deferred task) | ~2 KB |
| **Total E-a** | **~10 KB peak** | **~20-25 KB** |

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| ESPHome captive_portal not customizable enough | High | Research in E-a.0; fallback: raw ESP-IDF AP + httpd |
| Portal increases binary, pushing C6 past OTA | Medium | Small portal (~5 KB); monitor size |
| NVS credential storage unencrypted | Medium | Document security model (same as secrets.yaml on flash) |

## Dependencies

- Requires: Phase 7 (per-device NVS infrastructure)
- Requires: `authFetch()` pattern (Phase VX — done)
- Enables: Phase 8 notifications (credential storage pattern reusable)
- Enables: Phase 9 cloud (same NVS credential pattern)

---

_End of Phase E plan._
