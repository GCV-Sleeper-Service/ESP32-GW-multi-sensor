# Configuring Sensor Count (1–4)

_Last updated: 2026-03-12 — v7.4.5.0_

This document is the authoritative procedure for changing the ESP32 gateway between **1, 2, 3, or 4 configured sensors**.

As of **v7.4.5.0**, the recommended workflow is no longer “edit four files by hand.”
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

To make that practical from the command line, use the new helper:

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

---

## Recommended workflow

### Option A — interactive workflow (recommended)

Run:

```bash
python3 scripts/change_sensor_number.py
```

The script will:

1. Read the current configuration from `config/sensors.json`
2. Show the current sensor count and configured sensors
3. Offer only valid actions
   - if count is 1: add only
   - if count is 4: remove only
   - otherwise: add or remove
4. Validate new sensor name and MAC address
5. Update the canonical manifest
6. Re-render the dependent files:
   - `dashboard/sensor_history_multi.h`
   - `firmware/esp32-c3-multi-sensor.yaml`
   - `dashboard/dashboard.js`
   - `tests/fixtures/sensors.json`
7. Print the exact next commands to run

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
