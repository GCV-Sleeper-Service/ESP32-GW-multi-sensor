# ESP32-C3 Multi-Sensor BLE Gateway

A standalone BLE-to-WiFi gateway built on the **ESP32-C3 SuperMini**. It passively receives temperature and humidity broadcasts from multiple **ThermoPro TP357** Bluetooth sensors, computes 15-minute rolling averages, retains 24 hours in RAM, persists up to 45 days of hourly history to flash, and serves everything through an embedded HTML dashboard with real-time charts.

No cloud. No database. No Home Assistant required. Just an ESP32, the gateway firmware, and a browser.

> **Current default configuration on `main`: 3 BLE sensors.**
> The architecture already scales with sensor count, and the **planned v7.4.4.x work** is to make the supported range **1–4 sensors** fully documented and preflight-validated. Until that lands, the repo should not claim 4-sensor support as a current out-of-the-box default.

**Total hardware cost: ~$35 USD.**

![Dashboard Overview](Images/dashboard-overview.png)

## What It Does

- Receives BLE advertisements from ThermoPro TP357 sensors
- Current repo default: **3 configured sensors**
- Displays live temperature (°C/°F), humidity, dew point, battery, and RSSI per sensor
- Computes 15-minute rolling averages aligned to wall-clock boundaries
- Keeps 24h of history in RAM and persists up to 45 days of hourly history to a dedicated NVS partition
- Serves an embedded HTML dashboard directly from the ESP32 — no external hosted UI required
- Dashboard supports dark/light mode, collapsible sections, CSV export/import, and **24h / 7d / 30d / 45d** history ranges
- Accessible on LAN or over the internet via Cloudflare tunnel
- Dashboard HTML/JS is minified before embedding in `dashboard.h` to save flash space

![Sensor Cards](Images/dashboard-sensors.png)

![Charts and Export](Images/dashboard-charts.png)

## Hardware

| Item | Qty | ~Price | Notes |
|------|-----|--------|-------|
| ESP32-C3 SuperMini | 1 | $3–5 | Amazon, AliExpress |
| ThermoPro TP357 | 1–3 currently configured | $9–10 each | BLE temperature/humidity |
| USB-C cable + adapter | 1 | $3 | For initial flash only |

No breadboard, no wiring, no soldering.
Each TP357 runs on a single AAA battery lasting roughly 6–9 months.

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

# 4. Make sure helper scripts are executable
chmod +x scripts/*.sh

# 5. Edit the configured sensor MAC addresses
# See Docs/architecture.md for the current 3-sensor default and configuration notes

# 6. Compile and flash
esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml
```

Open `http://<esp-ip>/dashboard.html` in your browser.

## Repository Layout

```
ESP32-GW-multi-sensor/
  .github/workflows/ci.yml          CI: preflight + compile
  dashboard/
    dashboard.html                  Editable dashboard source
    dashboard.js                    Dashboard JavaScript
    dashboard.h                     Generated embedded payload (committed)
    sensor_history_multi.h          Backend: history, persistence, API endpoints
  firmware/
    esp32-c3-multi-sensor.yaml      ESPHome firmware configuration
  partitions/
    esp32-c3-multi-partitions.csv   Custom partition table (512 KiB history)
  scripts/                          Helper scripts (preflight, minify, compile, deploy)
  secrets/                          secrets-example.yaml (real secrets gitignored)
  Images/                           Dashboard screenshots
  Docs/                             Project documentation
  VERSION                           Current version number
```

## API Endpoints

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/dashboard.html` | GET | No | Embedded dashboard |
| `/sensors.json` | GET | No | Sensor manifest |
| `/history/{id}/temp` | GET | No | Temperature history stream |
| `/history/{id}/hum` | GET | No | Humidity history stream |
| `/api/status` | GET | No | Version, uptime, sensor health, heap |
| `/api/storage-stats` | GET | No | Partition and retention statistics |
| `/api/reboot` | POST | Basic | Reboot the ESP |
| `/api/delete-data` | POST | Basic | Erase persisted history |
| `/api/import/begin` | POST | Basic | Start multi-sensor import (erases history) |
| `/api/import/begin/single/<id>` | POST | Basic | Start single-sensor merge import |
| `/api/import/d/<data>` | POST | Basic | Add import data points |
| `/api/import/w/<data>` | POST | Basic | Add data points + write segment |
| `/api/import/finish` | POST | Basic | Finalize import, restore RAM |

## Development

The repo uses a GitHub-first workflow with branch protection on `main`:

1. Create a feature branch and make changes
2. Run `./scripts/test-local.sh` or `./scripts/preflight.sh`
3. Push and open a PR so CI validates preflight + compile automatically
4. Flash and test on the real device
5. Merge after CI green and device validation

See [Docs/development-pipeline.md](Docs/development-pipeline.md) for the full process.

## Current Version

**v7.4.1.0** — Dashboard minification pipeline and repo-normalized documentation baseline.
See [Docs/changelog.md](Docs/changelog.md) for released history.

## Documentation

| Document | Purpose |
|----------|---------|
| [Fresh Start Handoff](Docs/esp32-gateway-fresh-start-handoff.md) | Complete project context for resuming development |
| [Development Pipeline](Docs/development-pipeline.md) | Workflow, CI, versioning, and local process |
| [Architecture](Docs/architecture.md) | Software design, data flow, retention model, configuration |
| [Implementation Plan](Docs/implementation-plan-next-features-7.4.1.x.md) | Detailed next-feature implementation plan after v7.4.1.0 |
| [Custom Date Range Planning](Docs/planning-v7.4.2.0-custom-date-range.md) | Feature-specific planning supplement for the next release |
| [Changelog](Docs/changelog.md) | Version history with what changed and why |
| [Build History](Docs/build-history.md) | Curated ledger of accepted builds |
| [Bugs & Lessons Learned](Docs/bugs-and-lessons-learned.md) | Accumulated fixes and technical lessons |
| [Future Plans](Docs/future-plans.md) | Roadmap and release prioritization |
| [Device Test Report Template](Docs/device-test-report-template.md) | Post-flash testing checklist |

## License

MIT
