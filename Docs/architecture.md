# Architecture & Technical Reference

_Last updated: 2026-03-11 — v7.4.2.0_

This document describes the **current** architecture of the ESP32-C3 Multi-Sensor BLE Gateway on `main`.
Where future capability differs from the current checked-in default, that is stated explicitly so the documentation does not over-claim beyond the present codebase.

---

## 1. System Overview

The project is an **ESP32-C3 SuperMini** gateway that listens for ThermoPro TP357 BLE broadcasts and serves a self-contained dashboard directly from the device.

Current baseline on `main`:

- **3 sensors configured by default**
- **24h** of 15-minute history kept in RAM
- **up to 45 days** of hourly history persisted to a dedicated 512 KiB history partition
- Dashboard embedded in firmware through `dashboard.h`
- Management actions protected with Basic auth
- CSV export and import supported
- Import supports both destructive multi-sensor replacement and non-destructive single-sensor merge
- Dashboard payload is minified before regeneration of `dashboard.h`

The architecture is already structurally compatible with variable sensor count, but the repo's documented, fully normalized out-of-the-box baseline is still **3 sensors** until the configurable 1–4 sensor work is completed in a later 7.4.x release.

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
- The `sensors[]` array currently contains **3 configured sensor entries**
- The YAML contains **matching BLE/tracker/text sensor blocks** for those configured sensors
- The dashboard frontend is already dynamic enough to render what the manifest reports

### Important distinction

- **Current default:** 3 configured sensors
- **Planned configurable range:** 1–4 sensors (v7.4.4.x)

Until the configurable-sensor work is completed, documentation should describe the checked-in default as **3 sensors**, while noting that the architecture and roadmap are being prepared for a configurable **1–4 sensor** range.

### Sensor-count change implications

Changing sensor count affects more than presentation:

- `NUM_SENSORS` in C++ must match the `sensors[]` array
- YAML BLE/tracker/text-sensor blocks must match the same count
- `SegmentSnapshot` sizing changes with sensor count
- Persisted history compatibility is affected, because the segment structure encodes multi-sensor data layout

Sensor-count changes are not "cosmetic configuration."
They are **storage-structure-affecting changes** and should be treated as a controlled feature with documentation, preflight validation, and explicit history-reset guidance.

---

## 4. Data Flow

### Live readings / real-time charts

```
BLE broadcast
  → YAML on_value lambda
  → range / validity checks
  → SensorSlot state update
  → publish_state to ESPHome entities
  → dashboard receives updates via SSE or polling
  → browser updates cards, charts, dew point, comfort, RSSI presentation
```

### 15-minute averaging

```
15-minute boundary
  → compute averaged values per sensor
  → append 15-minute point to RAM ring buffers
  → publish average strings/sensors
  → browser charts update
```

### Hourly persistence

```
hourly persistence checkpoint
  → latest RAM-derived segment serialized
  → dedicated history partition updated
  → retention window maintained as circular hourly storage
```

### Dashboard history loading

```
browser opens /dashboard.html
  → load sensor manifest
  → fetch temperature + humidity history endpoints per sensor
  → merge persisted history + current RAM layer
  → render charts and min/max ranges
```

---

## 5. Retention Model

The gateway uses a two-tier history model.

**RAM layer**

- Fixed-size ring buffers
- 15-minute points
- 24 hours of newest history
- Static allocation, no heap fragmentation risk for the retained chart data itself

**Persisted layer**

- Dedicated 512 KiB NVS partition
- Hourly segments
- Circular retention
- Target retention: up to 45 days with the current 3-sensor baseline

**Restore-on-boot behavior**

On boot, the firmware restores the newest valid persisted segments back into RAM so the dashboard is not empty after restart.

---

## 6. Partition Layout

| Partition | Approx. size | Purpose |
|-----------|-------------|---------|
| `nvs` | 16 KiB | System NVS |
| `otadata` | 8 KiB | OTA state |
| `phy_init` | 4 KiB | PHY calibration |
| `ota_0` | ~1.69 MiB | Application slot A |
| `ota_1` | ~1.69 MiB | Application slot B |
| `history` | 512 KiB | Dedicated persisted history |
| `coredump` | 64 KiB | Crash dump storage |

---

## 7. Resource Profile

The values below are the current baseline guidance for v7.4.2.0 and should be treated as approximate operating numbers, not immutable constants.

| Metric | Approx. value | Notes |
|--------|--------------|-------|
| RAM usage | ~15.8% of 327 KiB | Typical baseline |
| Free heap | ~78–84 KiB | Typical runtime range |
| Flash usage | ~86.8% of OTA slot | After dashboard minification + custom date range feature |
| History partition | 512 KiB | Dedicated NVS storage |

The dashboard minification pipeline (v7.4.1.0) saves ~33% of source HTML. v7.4.2.0 adds the custom date range selector, bringing flash to ~86.8%.

---

## 8. Dashboard Architecture

### Source-of-truth model

The canonical dashboard editing flow is:

```
dashboard.html  →  minify-dashboard.sh  →  dashboard.min.html (artifact only)
                →  generate-header.sh   →  dashboard.h (committed)
```

Key rules:

- `dashboard.html` remains the human-readable source of truth
- `dashboard.min.html` is a build artifact and stays gitignored
- `dashboard.h` is derived but committed so tagged builds remain self-contained
- `dashboard.js` and the JS embedded into `dashboard.html` must stay in sync

### Current dashboard feature set

- Dark/light mode
- Collapsible cards
- Real-time temperature/humidity charts
- 15-minute average charts
- Range selectors: 24h / 7d / 30d / 45d / Custom
- Custom date range picker: calendar modal with presets, start/end selection, available-data bounds
- Min/max summaries derived from loaded chart data (respects active range, including custom)
- CSV export per sensor and Export All
- CSV import UI
- ESP management actions
- Documentation / status / storage panels

### Not current yet

The following is planned, not current:

- Automated Playwright browser regression suite
- Fully normalized 1–4 configurable sensor-count workflow

Those belong to the next 7.4.x phases and should not be described as currently shipped behavior.

---

## 9. Import / Export Model

### Export

The dashboard can export:

- Single-sensor CSV
- Merged all-sensor CSV

Export All is serialized to avoid overloading the ESP's constrained socket pool.

### Import

There are two import models:

**Multi-sensor import**

- Begins with `POST /api/import/begin`
- Replacement-first model
- Clears persisted history before writing new imported data

**Single-sensor import**

- Begins with `POST /api/import/begin/single/<id>`
- Merge-first model
- Preserves other sensors' existing data
- Overlays incoming data only for the target sensor

### Transport constraint

For custom handlers on this stack, the reliable transport is the URL path, not POST body or query parameters.
That constraint is now a core architectural rule and is documented in the lessons-learned file.

---

## 10. Access Modes

The dashboard is intended to work both:

- Directly on LAN via `http://<esp-ip>/dashboard.html`
- Through a Cloudflare tunnel / public hostname path

The codebase already includes logic to handle different transport/runtime conditions between direct access and proxied access.
Operationally, Cloudflare remains part of the supported deployment story, but browser- and path-specific behavior should continue to be regression-tested as dashboard complexity grows.

---

## 11. Configuration Guidance

### Secrets

Use:

- `secrets/secrets-example.yaml` as committed template
- `secrets/secrets.yaml` as local real-secrets file
- `firmware/secrets.yaml` as local symlink

### Sensor MAC addresses

Sensor identity is configured in both:

- `dashboard/sensor_history_multi.h`
- `firmware/esp32-c3-multi-sensor.yaml`

Those definitions must stay aligned.

### Script permissions

After a fresh clone or after pulling newly created scripts, run:

```bash
chmod +x scripts/*.sh
```

This is now part of the standard local setup guidance because execute permissions may be lost in some repository update paths.

---

## 12. Design Decisions

### Why embedded dashboard instead of separate hosted file

The embedded dashboard avoids external file drift, avoids needing a separately hosted HTML file, and keeps the release artifact self-contained.

### Why ESP-IDF instead of Arduino

The project prioritizes BLE/WiFi coexistence, lower-level control, and predictable behavior on the constrained ESP32-C3 platform.

### Why fixed RAM ring buffers

This avoids heap fragmentation and keeps history retention predictable.

### Why some older version comments stay in code

Some version references in comments are deliberate historical breadcrumbs, especially where they explain architectural carry-forward decisions. Examples that remain intentional include:

- Preserved `histv631` namespace for storage continuity
- References to the v7.3 structural-enforcement phase
- Notes about retaining stable v7.2/v7.3 transport/init behavior

Those should stay.
Only comments that misstate the current repo version without historical purpose should be normalized.

---

## 13. Troubleshooting Notes

### Dashboard stuck on connecting

Check reachability first, then browser console/network behavior, then whether access mode is LAN direct vs proxied.

### Sensor cards show blanks

Common causes:

- Wrong MAC address
- Sensor out of range
- Sensor battery issue
- No recent BLE packets seen

### Export/import instability

On this platform, concurrency matters.
Long-running operations should suspend or reduce non-essential background traffic where possible.

### After changing storage-structure-related settings

If you change sensor count or otherwise alter persisted data layout assumptions, treat old persisted history as incompatible unless the specific feature design says otherwise.

---

## 14. Documentation Discipline

To keep docs and code in line:

- `README.md` must describe current shipped behavior, not roadmap behavior
- `architecture.md` must describe current architecture and explicitly label planned capability as planned
- `future-plans.md` and `implementation-plan-next-features-7.4.1.x.md` are where planned features belong
- Session logs and the fresh-start handoff must be updated whenever a development session materially changes state, workflow, or next steps
- When a version bump happens, all six version-bearing locations must be updated together
