# Architecture & Technical Reference

_Last updated: 2026-03-11 — v7.4.2.0_

This document describes the **current** architecture of the ESP32-C3 Multi-Sensor BLE Gateway on `main`.
Where future capability differs from the current checked-in default, that is stated explicitly so the documentation does not over-claim beyond the present codebase.

---

## 1. System Overview

The project is an **ESP32-C3 SuperMini** gateway that listens for ThermoPro TP357 BLE broadcasts and serves a self-contained dashboard directly from the device.

Current baseline on `main`:

- **1–4 sensors supported; default 3 (compile-time configurable, see Docs/configuring-sensors.md)**
- **24h** of 15-minute history kept in RAM
- **up to 45 days** of hourly history persisted to a dedicated 512 KiB history partition
- Dashboard embedded in firmware through `dashboard.h`
- Management actions protected with Basic auth
- CSV export and import supported
- Import supports both destructive multi-sensor replacement and non-destructive single-sensor merge
- Dashboard payload is minified before regeneration of `dashboard.h`

The architecture is fully normalized for configurable 1–4 sensor count as of v7.4.4.0. See Docs/configuring-sensors.md for the change procedure.

---

## 2. Software Stack

The firmware runs on **ESPHome** using Espressif's native **ESP-IDF** framework rather than Arduino. That choice is deliberate for BLE + WiFi coexistence, memory discipline, and web server behavior on the single-core ESP32-C3.

### Key components

| Component | Purpose |
|-----------|---------|
| `esp32_ble_tracker` | Passive BLE scanning for sensor advertisements |
| `thermopro_ble` | Decodes ThermoPro TP357 BLE packet format |
| `ble_rssi` | Tracks per-sensor RSSI |
| `web_server` (v3) | Built-in HTTP server, SSE, custom endpoints |
| `sntp` | Time synchronization for wall-clock aligned averaging |
| `dashboard/sensor_history_multi.h` | Sensor structs, RAM history, flash persistence, HTTP endpoints |
| `dashboard/dashboard.html` | Human-readable dashboard source of truth |
| `dashboard/dashboard.js` | Dashboard JavaScript logic mirrored into HTML build flow |
| `dashboard/dashboard.h` | Generated embedded dashboard payload committed to the repo |
| `api` | Retained for ESPHome boot/init stability |

---

## 3. Sensor Architecture

Each physical sensor is represented by a `SensorSlot` structure in `sensor_history_multi.h`.
That structure encapsulates sensor identity, rolling accumulators, latest battery/RSSI data, last-seen timing, and both temperature and humidity history buffers.

### Current state

- `NUM_SENSORS` is currently set to **3** on `main`
- The `sensors[]` array contains **NUM_SENSORS entries** (1–4; default 3)
- The YAML contains **matching BLE/tracker/text sensor blocks** for those configured sensors
- The dashboard frontend is already dynamic enough to render what the manifest reports

### Important distinction

- **Current default:** 3 configured sensors
- **Configurable range:** 1–4 sensors (v7.4.4.0 — fully implemented)

