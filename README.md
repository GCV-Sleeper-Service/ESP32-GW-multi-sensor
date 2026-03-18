# ESP32-C3 Multi-Sensor BLE Gateway

A standalone BLE-to-WiFi gateway built on the **ESP32-C3 SuperMini**. It passively receives temperature and humidity broadcasts from multiple **ThermoPro TP357** Bluetooth sensors, computes 15-minute rolling averages, retains 24 hours in RAM, persists up to 45 days of hourly history to flash, and serves everything through a gzip-compressed embedded HTML dashboard with real-time charts.

No cloud. No database. No Home Assistant required. Just an ESP32, the gateway firmware, and a browser.

> **Current version: v7.5.3.5** — manifest-driven architecture with SensorEntity model, gzip-compressed dashboard, sequential history serving, and Playwright browser test suite.
> Default configuration on `main`: **3 BLE sensors**. Supports **1–4 sensors** via `config/sensors.json`.

**Total hardware cost: ~$35 USD.**

![Dashboard Overview](Images/dashboard-overview.png)

## What It Does

- Receives BLE advertisements from ThermoPro TP357 sensors (1–4 configurable)
- Displays live temperature (°C/°F), humidity, dew point, battery, and RSSI per sensor
- Computes 15-minute rolling averages aligned to wall-clock boundaries
- Keeps 24h of history in RAM and persists up to 45 days of hourly history to a dedicated NVS partition
- Serves a gzip-compressed embedded HTML dashboard directly from the ESP32
- Dashboard supports dark/light mode, 24h/7d/30d/45d history ranges with min/max, CSV export/import, storage statistics, and device management
- Manifest-driven sensor configuration — single JSON file generates all firmware, dashboard, and test artifacts
- Accessible on LAN or over the internet via Cloudflare tunnel (auto-detects SSE vs polling transport)
- Playwright browser regression test suite with fixture-driven mock server
- CI pipeline with preflight validation, ESPHome YAML parse check, and automated test runs

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor.git
cd ESP32-GW-multi-sensor

# 2. Create your secrets file
cp secrets/secrets-example.yaml secrets/secrets.yaml
# Edit secrets/secrets.yaml with your WiFi credentials and management password

# 3. Symlink secrets for ESPHome (Linux/LXC)
ln -s ../secrets/secrets.yaml firmware/secrets.yaml

# 4. Make helper scripts executable
chmod +x scripts/*.sh scripts/*.py

# 5. Review / change configured sensors (canonical source: config/sensors.json)
python3 scripts/change_sensor_number.py

# 6. Build pipeline
npm ci                                    # install test/build dependencies
./scripts/minify-dashboard.sh             # minify HTML source
./scripts/generate-header.sh              # gzip-compress + embed into dashboard.h

# 7. Validate
bash ./scripts/preflight.sh               # repo consistency checks
npm run test:browser                      # Playwright regression tests

# 8. Compile and flash
esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml
```

Open `http://<esp-ip>/dashboard.html` in your browser.

## Sensor Configuration Workflow

The repo uses a canonical manifest (`config/sensors.json`) to drive all generated artifacts. No manual multi-file editing required.

Primary files and scripts:

- `config/sensors.json` — canonical sensor manifest (name, MAC, display order)
- `scripts/change_sensor_number.py` — interactive add/remove flow
- `scripts/render_sensor_config.py` — regenerates YAML, C++, and JS from the manifest
- `scripts/history_backup.py` — CLI backup/restore helper for retained history

When sensor count changes, retained history layout changes too. Back up retained history first, then flash the new firmware, delete old retained history, and restore the backup.

```bash
# Export
python3 scripts/history_backup.py export \
  --host http://192.168.120.189 \
  --output backup-before-sensor-change.csv

# Import (after reflash)
python3 scripts/history_backup.py import \
  --host http://192.168.120.189 \
  --input backup-before-sensor-change.csv \
  --username <user> --password <pass>
```

## Repository Layout

```text
ESP32-GW-multi-sensor/
  config/
    sensors.json                   Canonical sensor manifest
  dashboard/
    dashboard.html                 Editable dashboard source (HTML + JS)
    dashboard.js                   Dashboard JavaScript (standalone reference)
    dashboard.h                    Generated gzip-compressed payload (committed)
    sensor_history_multi.h         Backend: history, persistence, API endpoints
  firmware/
    esp32-c3-multi-sensor.yaml     ESPHome firmware configuration
  partitions/
    esp32-c3-multi-partitions.csv  Custom partition table (512 KiB history)
  scripts/
    change_sensor_number.py        Interactive manifest editor
    render_sensor_config.py        Generator for sensor-dependent files
    generate-header.sh             Gzip-compress dashboard into C header
    minify-dashboard.sh            HTML/JS minification
    bump-version.sh                Atomic version bump across all files
    history_backup.py              CLI export/import helper
    preflight.sh                   Repo validation (~25 checks)
  src/
    gateway_manifest.h             Generated manifest v2 JSON (compiled into firmware)
  tests/
    browser/                       Playwright browser regression specs
    fixtures/                      Mock API data and generated variants
    mock-server/                   Local HTTP mock for Playwright
  Docs/                            Project documentation, session logs, architecture plans
  VERSION                          Current version number
```

## API Endpoints

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/dashboard.html` | GET | No | Embedded dashboard (gzip-compressed) |
| `/dashboard-download` | GET | No | Dashboard as file download |
| `/api/manifest` | GET | No | Manifest v2 — sensors, metrics, history config |
| `/sensors.json` | GET | No | Legacy sensor manifest (v1 compatibility) |
| `/api/status` | GET | No | Version, uptime, sensor health, free heap |
| `/api/storage-stats` | GET | No | Partition sizes and retention statistics |
| `/history/{id}/temp` | GET | No | Temperature history (NVS + RAM, CSV) |
| `/history/{id}/hum` | GET | No | Humidity history (NVS + RAM, CSV) |
| `/api/reboot` | POST | Basic | Reboot the ESP |
| `/api/delete-data` | POST | Basic | Erase persisted history |
| `/api/import/begin` | POST | Basic | Start multi-sensor import (erases history) |
| `/api/import/begin/single/{id}` | POST | Basic | Start single-sensor merge import |
| `/api/import/d/{data}` | POST | Basic | Add import data points |
| `/api/import/w/{data}` | POST | Basic | Add data points + write segment |
| `/api/import/finish` | POST | Basic | Finalize import, restore RAM |

## Architecture

The project follows a manifest-driven architecture. A single `config/sensors.json` drives code generation across the entire stack:

- **Python generator** (`render_sensor_config.py`) reads the manifest and produces C++ sensor arrays, YAML configuration blocks, gateway manifest JSON header, and test fixtures
- **Firmware** runs ESPHome on ESP-IDF (not Arduino) for BLE + WiFi coexistence on the single-core ESP32-C3
- **Dashboard** is a self-contained HTML/JS application embedded in firmware flash as a gzip-compressed C byte array (~45KB), served with `Content-Encoding: gzip`
- **History** uses a pre-reserved string pattern for CSV response building to avoid heap exhaustion on the memory-constrained ESP32-C3

See [Docs/v7.5-v7.6-architecture-plan.md](Docs/v7.5-v7.6-architecture-plan.md) for the full architecture document covering the SensorEntity model, manifest v2 schema, dashboard renderer registry, and aggregation roadmap.

## Current Version

**v7.5.3.5** — Phase 3 in progress (SensorEntity model). Phases 1–2 complete (manifest v2, dashboard renderer registry). BUG-043 dashboard stability fully resolved.

See [Docs/changelog.md](Docs/changelog.md) for full release history.
