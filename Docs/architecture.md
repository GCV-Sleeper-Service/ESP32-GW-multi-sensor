# Architecture & Technical Reference

_Last updated: 2026-03-13 — v7.5.0.0_

This document describes the **current** architecture of the ESP32-C3 Multi-Sensor BLE Gateway on `main`.

---

## 1. System Overview

The project is an **ESP32-C3 SuperMini** gateway that listens for ThermoPro TP357 BLE broadcasts and serves a self-contained dashboard directly from the device.

Current baseline on `main`:
- **1–4 sensors supported; default 3 (compile-time configurable, see `Docs/configuring-sensors.md`)**
- **24h** of 15-minute history kept in RAM
- **up to 45 days** of hourly history persisted to a dedicated 512 KiB history partition
- dashboard embedded in firmware through `dashboard.h`
- management actions protected with Basic auth
- CSV export and import supported
- import supports both destructive multi-sensor replacement and non-destructive single-sensor merge
- dashboard boot now prefers **`/api/manifest`** and keeps **`/sensors.json`** as a compatibility fallback

---

## 2. Software Stack

The firmware runs on **ESPHome** using Espressif's native **ESP-IDF** framework rather than Arduino. That choice is deliberate for BLE + WiFi coexistence, memory discipline, and web server behavior on the single-core ESP32-C3.

### Key components

| Component | Purpose |
|---|---|
| `esp32_ble_tracker` | Passive BLE scanning for sensor advertisements |
| `thermopro_ble` | Decodes ThermoPro TP357 BLE packet format |
| `ble_rssi` | Tracks per-sensor RSSI |
| `web_server` (v3) | Built-in HTTP server, SSE, custom endpoints |
| `sntp` | Time synchronization for wall-clock aligned averaging |
| `dashboard/sensor_history_multi.h` | Sensor structs, RAM history, flash persistence, HTTP endpoints |
| `dashboard/dashboard.html` | Human-readable dashboard source of truth |
| `dashboard/dashboard.js` | Dashboard JavaScript logic mirrored into the HTML build flow and used by tests/tooling |
| `dashboard/dashboard.h` | Generated embedded dashboard payload committed to the repo |

---

## 3. Sensor Architecture

Each physical sensor is represented by a `SensorSlot` structure in `sensor_history_multi.h`. That structure encapsulates sensor identity, rolling accumulators, latest battery data, last-seen timing, and both temperature and humidity history buffers.

### Current state
- `NUM_SENSORS` is currently set to **3** on `main`
- the `sensors[]` array contains **NUM_SENSORS entries**
- the YAML contains matching BLE/tracker/text-sensor blocks for those configured sensors
- the dashboard frontend renders sensor cards/charts from manifest-provided sensor metadata rather than a hardcoded count

---

## 4. HTTP / Dashboard Contract

### Current read endpoints
- `GET /dashboard`
- `GET /dashboard.html`
- `GET /dashboard-download`
- `GET /history/<sensor-id>/temp`
- `GET /history/<sensor-id>/hum`
- `GET /api/storage-stats`
- `GET /api/status`
- `GET /api/manifest` ← **current preferred dashboard bootstrap contract**
- `GET /sensors.json` ← **legacy compatibility projection retained intentionally**

### Manifest contract

`/api/manifest` returns a v2 JSON object with:
- top-level schema/version metadata
- shared metric metadata (`temp`, `hum`) including units and value bounds
- per-sensor entries with stable `id`, display `name`, and metric-specific history paths

The dashboard currently uses that payload mainly to derive the active sensor set and to preserve room for future metric expansion, while temperature/humidity remain the implemented metric pair in the UI.

### Compatibility rule

The dashboard boot order is intentionally:
1. `/api/manifest`
2. `/sensors.json`
3. built-in default sensor metadata

This is the repo’s guardrail against partial upgrades and test/device skew.

---

## 5. Retained History Model

### RAM layer
- 24 hours of 15-minute points per series
- explicit gap insertion when no valid reading exists at a bucket boundary

### Flash layer
- 1-hour segment snapshots persisted to a dedicated history NVS partition
- circular retention sized for roughly 45 days
- `GET /history/*` merges flash segments with newer RAM points on read

### Import behavior

#### Multi-sensor import
- erase-first
- writes new retained history sequentially

#### Single-sensor import
- merge-first
- the firmware builds an epoch-to-slot map from existing retained segments at `/api/import/begin/single/<id>`
- on each write batch it looks up whether that hour already exists
- if it exists, it reads the existing segment, overlays only the target sensor arrays, recalculates snapshot bounds, and writes the merged result back to the same slot
- if it does not exist, it writes a new slot at `next_slot`
- temporary memory overhead for the merge path remains roughly ~7 KiB

This design note is intentionally retained because it affects future history, manifest, and restore work.

---

## 6. Test / Tooling Model

### Canonical configuration source
`config/sensors.json` is the single source of truth for sensor id/name/MAC configuration.

### Generated artifacts
The repo uses `scripts/render_sensor_config.py` to keep the following aligned with the canonical manifest:
- generated sensor block in `dashboard/sensor_history_multi.h`
- generated sensor fallback block in `dashboard/dashboard.js`
- generated YAML sections in `firmware/esp32-c3-multi-sensor.yaml`
- baseline test fixtures under `tests/fixtures/`

### Browser tests
The mock-server + Playwright stack validates dashboard boot behavior without a live device. As of v7.5.0.0, that includes manifest-v2 boot and legacy-fallback coverage.
