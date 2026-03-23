# Configuring Sensor Count (1–4)

_Last updated: 2026-03-12 — v7.4.5.1_

This document is the authoritative procedure for changing the ESP32 gateway between **1, 2, 3, or 4 configured sensors**.

As of **v7.4.5.1**, the recommended workflow is no longer “edit four files by hand.”
The repo now uses a **canonical sensor manifest** plus a renderer:

- `config/sensors.json` — single source of truth
- `scripts/change_sensor_number.py` — interactive add/remove flow
- `scripts/render_sensor_config.py` — regenerates dependent files
- `scripts/history_backup.py` — CLI backup/restore helper for retained history

---

## What changes when sensor count changes

Sensor count is a **compile-time constant**. It affects the binary layout of retained hourly history segments in flash.

A firmware compiled for 2 sensors and a firmware compiled for 4 sensors do **not** share the same retained-history layout.

When you change sensor count and flash the new firmware:

1. The new firmware detects the mismatch (`meta.num_sensors != NUM_SENSORS`) and refuses to load the old history.
2. You must delete the old retained history before trusting the new baseline.
3. Old data is still reusable **if you export it first and then re-import it after the change**.

---

## Backup and restore options

### Browser dashboard

The dashboard already supports:

- per-sensor CSV export
- merged **Export All** CSV
- multi-sensor import (replacement-first)
- single-sensor import (merge-first)

For sensor-count changes, the safest backup is **Export All** from the dashboard.

### CLI helper

There is no dedicated “download full backup” firmware endpoint today. Export works by reading the existing public history routes:

- `GET /sensors.json`
- `GET /history/<sensor_id>/temp`
- `GET /history/<sensor_id>/hum`

To make that practical from the command line, use the helper. It now defaults to a 60-second HTTP timeout and also accepts `--timeout <seconds>` for slower links:

```bash
python3 scripts/history_backup.py export \
  --host http://192.168.120.189 \
  --output backup-before-sensor-change.csv
```

Restore uses the existing management import API:

- `POST /api/import/begin`
- `POST /api/import/begin/single/<sensor_id>`
- `POST /api/import/d/<batch>`
- `POST /api/import/w/<batch>`
- `POST /api/import/finish`

Example restore:

```bash
python3 scripts/history_backup.py import \
  --host http://192.168.120.189 \
  --input backup-before-sensor-change.csv \
  --username <user> \
  --password <pass>
```

For multi-sensor CSV restores, the CLI now pauses for an explicit erase-first confirmation unless you pass `--yes`.

If you want to restore just one sensor from a merged CSV, use:

```bash
python3 scripts/history_backup.py import \
  --host http://192.168.120.189 \
  --input backup-before-sensor-change.csv \
  --single-sensor outside \
  --username <user> \
  --password <pass>
```

---

## Recommended workflow

### Option A — interactive workflow (recommended)

Run:

```bash
python3 scripts/change_sensor_number.py
```

The script will:

1. Warn you before add/remove confirmation that retained history must be backed up before the eventual flash
2. Read the current configuration from `config/sensors.json`
3. Show the current sensor count and configured sensors
4. Offer only valid actions
   - if count is 1: add only
   - if count is 4: remove only
   - otherwise: add or remove
5. Validate new sensor name and MAC address
6. Update the canonical manifest
7. Re-render the dependent files:
   - `dashboard/sensor_history_multi.h`
   - `firmware/esp32-c3-multi-sensor.yaml`
   - `dashboard/dashboard.js`
   - `tests/fixtures/sensors.json`
8. Print the exact next commands to run

### Option B — direct manifest edit + render

Edit `config/sensors.json` manually, then run:

```bash
python3 scripts/render_sensor_config.py --write
```

### Validate after either option

```bash
bash ./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

---

## Full count-change procedure with history preservation

### 1. Back up retained history first

Preferred CLI method:

```bash
python3 scripts/history_backup.py export \
  --host http://192.168.120.189 \
  --output backup-before-sensor-change.csv
```

Or use the dashboard’s **Export All** button.

### 2. Change sensor configuration

```bash
python3 scripts/change_sensor_number.py
```

### 3. Validate generated files

```bash
bash ./scripts/preflight.sh
```

### 4. Compile and flash the new firmware

```bash
esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml
```

### 5. Delete old retained history layout

Dashboard path:
- Management → Delete Data

API path:

```bash
curl -u "<user>:<pass>" -X POST http://192.168.120.189/api/delete-data
```

### 6. Restore the backup

CLI restore:

- merged CSV: expect an erase-first confirmation prompt unless `--yes` is supplied
- one sensor from a merged CSV: add `--single-sensor <id>` to route through the merge path intentionally


```bash
python3 scripts/history_backup.py import \
  --host http://192.168.120.189 \
  --input backup-before-sensor-change.csv \
  --username <user> \
  --password <pass>
```

Or import through the dashboard.

---

## Current generated files

The manifest drives these files:

| File | Purpose |
|------|---------|
| `config/sensors.json` | Canonical sensor manifest |
| `dashboard/sensor_history_multi.h` | `NUM_SENSORS` and `sensors[]` initializer |
| `firmware/esp32-c3-multi-sensor.yaml` | Sensor-specific BLE, RSSI, averaging, grouping, and text-sensor blocks |
| `dashboard/dashboard.js` | `DEFAULT_SENSOR_META` fallback |
| `tests/fixtures/sensors.json` | Baseline mock manifest |

---

---

## Multi-board deployment

_Added for multi-board infrastructure support._

The generator supports multiple ESP32 board variants. By default (no `config/gateway.json`), it targets the ESP32-C3 SuperMini. To target a different board, create `config/gateway.json`.

### Available board profiles

| Board ID | Chip | Flash | PSRAM | Notes |
|----------|------|-------|-------|-------|
| `esp32-c3-supermini` | ESP32-C3 | 4MB | No | Default satellite board |
| `esp32-s3-devkitc1-n16r8` | ESP32-S3 | 16MB | 8MB | Recommended aggregator board |
| `esp32-wroom-32d` | ESP32 | 4MB | No | Original ESP32, good backup aggregator |

Board profiles are defined in `firmware/boards/{board-id}.yaml`.

### How to create `config/gateway.json`

Copy the example and edit:

```bash
cp config/gateway.example.json config/gateway.json
# Edit config/gateway.json with your board, name, and IP address
```

Example for an S3 aggregator:

```json
{
  "board": "esp32-s3-devkitc1-n16r8",
  "esphome_name": "esp32-n16r8-gw-1",
  "friendly_name": "ESP32-S3 Aggregator",
  "wifi_address": "192.168.120.191"
}
```

Required fields:

| Field | Description |
|-------|-------------|
| `board` | Must match a board profile filename in `firmware/boards/` |
| `esphome_name` | ESPHome device name (lowercase, hyphens, digits only) |
| `wifi_address` | IP address where ESPHome OTA/API reaches the device |

Optional fields:

| Field | Description |
|-------|-------------|
| `friendly_name` | Human-readable name shown in the dashboard; if omitted, defaults to `"{board_id} Gateway"` |
| `manual_ip` | Object with `static_ip`, `gateway`, `subnet` (and optional `dns1`) — assigns a static IP on the device |

**`wifi_address` vs `manual_ip`:**

- `wifi_address` is **always required** — it tells ESPHome OTA/API where to reach the device
- `manual_ip` is **optional** — when present, the device assigns itself a static IP instead of relying on DHCP
- Without `manual_ip`, the device gets its IP from DHCP; `wifi_address` must match the device's actual IP (typically via a DHCP reservation on the router)
- With `manual_ip`, the device assigns the static IP directly; no DHCP reservation needed

**Do NOT commit `config/gateway.json` to the repository.** It is per-device configuration. The example file (`config/gateway.example.json`) is committed as a template.

### How to generate for a non-C3 board

```bash
# 1. Create config/gateway.json (see above)
# 2. Optionally set up aggregator config
cp config/aggregator.example.json config/aggregator.json
# Edit config/aggregator.json with your satellite URLs

# 3. Generate the YAML
python3 scripts/render_sensor_config.py --write
# Output: firmware/{board-id}-gw.yaml (e.g. firmware/esp32-s3-devkitc1-n16r8-gw.yaml)

# 4. Validate
bash scripts/preflight.sh
```

### How to compile and flash for different boards

```bash
# S3 Aggregator:
esphome compile firmware/esp32-s3-devkitc1-n16r8-gw.yaml
esphome run firmware/esp32-s3-devkitc1-n16r8-gw.yaml

# WROOM-32D:
esphome compile firmware/esp32-wroom-32d-gw.yaml
esphome run firmware/esp32-wroom-32d-gw.yaml

# C3 with gateway.json (e.g. esphome_name "esp32-c3-garage"):
esphome compile firmware/esp32-c3-garage-gw.yaml
esphome run firmware/esp32-c3-garage-gw.yaml

# C3 Satellite (default — no gateway.json needed):
esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml
```

### Zero-sensor configurations (pure aggregator)

When `config/gateway.json` is present, the sensor manifest may have zero sensors. This creates a pure aggregator that only polls satellites — no local BLE sensors.

```json
{"schema_version": 2, "sensors": []}
```

The generated YAML will omit BLE tracker and ThermoPro sections while keeping diagnostic sensors (WiFi signal, heap, uptime).

### PyYAML dependency

The board profile loader uses PyYAML. In the ESPHome environment, PyYAML is already available. If running outside ESPHome:

```bash
pip install pyyaml
```

---

## Notes on import behavior

### Multi-sensor import

`POST /api/import/begin`

- clears retained history first
- rebuilds retained history from the CSV
- use this for full restore after a sensor-count change

### Single-sensor import

`POST /api/import/begin/single/<sensor_id>`

- preserves other sensors’ retained data
- builds an epoch-to-slot map of existing segments
- reads existing hourly segments, overlays only the target sensor’s temp/humidity arrays, and writes the merged segment back to the same slot
- creates a new segment only when no existing segment covers that hour
- temporary working memory during import is about 7 KB

That merge-first behavior is ideal for repairing or backfilling one sensor without erasing other sensors.

---

## Manual fallback

If the automation scripts are unavailable, you can still edit the repo manually — but the manifest-driven path is preferred.

If you must do it by hand, keep these files aligned:

- `dashboard/sensor_history_multi.h`
- `firmware/esp32-c3-multi-sensor.yaml`
- `dashboard/dashboard.js`
- `tests/fixtures/sensors.json`

Then run:

```bash
bash ./scripts/preflight.sh
```

If preflight fails, fix the mismatch before compiling.
