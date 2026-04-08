# ESP32 Multi-Sensor BLE Gateway

A manifest-driven IoT gateway platform built on ESP32. Receives BLE sensor broadcasts, accepts pushed metrics from external systems, aggregates data from multiple satellite gateways, and serves everything through an embedded HTML dashboard with real-time charts.

Supports **ESP32-C3**, **ESP32-S3**, **ESP32-WROOM-32D**, and other ESP32 variants via board profiles. Single devices operate as satellites; more capable devices can aggregate multiple satellites into a unified dashboard.

No cloud. No database. No Home Assistant required. Just ESP32 hardware, the gateway firmware, and a browser.

> **Current version: v7.5.5.5** — Phase 5 complete (Aggregator MVP).
> Multi-board support, unified satellite/aggregator architecture, manifest-driven dashboard with environmental + network device cards.
> Default config on `main`: **3 BLE sensors + 1 WAN ping probe** on ESP32-C3.

**Satellite hardware cost: ~$35 USD.**

![Dashboard Overview](Images/dashboard-overview.png)

## What It Does

**Satellite gateway (any ESP32 board):**
- Receives BLE advertisements from ThermoPro TP357 sensors (1–4 configurable)
- Monitors WAN connectivity via ICMP ping probes
- Accepts pushed metrics from external systems via `POST /api/ingest` (Phase 6)
- Displays live temperature (°C/°F), humidity, dew point, battery, RSSI, and network latency
- Computes 15-minute rolling averages aligned to wall-clock boundaries
- Retains 24h in RAM + up to 45 days of hourly history in dedicated NVS flash partition
- Serves a gzip-compressed embedded dashboard (~45KB) directly from the ESP32
- CSV export/import, dark/light mode, storage statistics, device management

**Aggregator gateway (ESP32-S3 or higher recommended):**
- All satellite capabilities plus multi-gateway aggregation
- Polls satellite APIs and presents a unified dashboard with per-gateway tabs
- Gateway selector with status indicators, summary cards, per-device views
- Settings panel showing satellite configuration and health
- Runtime satellite management planned for Phase D (v7.6.x)

**Development infrastructure:**
- Manifest-driven code generation — single `config/sensors.json` drives firmware, dashboard, and test artifacts
- Multi-board support via board profiles (`firmware/boards/*.yaml`)
- Playwright browser regression suite (117 tests across 3 fixture variants)
- CI pipeline with 53 preflight checks, fixture validation, and automated test runs

## Quick Start

```bash
# 1. Clone
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor.git
cd ESP32-GW-multi-sensor

# 2. Secrets
cp secrets/secrets-example.yaml secrets/secrets.yaml
# Edit with your WiFi credentials and management password

# 3. Symlink secrets for ESPHome
ln -s ../secrets/secrets.yaml firmware/secrets.yaml

# 4. Make scripts executable
chmod +x scripts/*.sh scripts/*.py

# 5. Build pipeline
npm ci
bash scripts/generate-header.sh

# 6. Validate
bash scripts/preflight.sh
python3 scripts/render_sensor_config.py --check
FIXTURE_SET=3sensor npx playwright test --project=chromium

# 7. Compile and flash
esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml
```

Open `http://<esp-ip>/dashboard.html` in your browser.

For aggregator setup, see [Docs/aggregator-setup.md](Docs/aggregator-setup.md).

## Sensor Configuration

The repo uses a canonical manifest (`config/sensors.json`) to drive all generated artifacts:

- `config/sensors.json` — sensor definitions (name, MAC, category, adapter)
- `scripts/render_sensor_config.py` — generates C++ headers, YAML, JS, and test fixtures
- `scripts/bump-version.sh` — atomic version bump across all files
- `tests/fixtures/generate-fixtures.js` — generates test fixture variants

```bash
# After editing sensors.json:
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
bash scripts/preflight.sh
```

## Repository Layout

```text
ESP32-GW-multi-sensor/
  config/
    sensors.json                   Canonical sensor manifest (v2 schema)
    sensors.v2.example.json        Reference manifest with mixed device types
    gateway.json                   Per-device identity config (gitignored)
    aggregator.json                Aggregator satellite list (gitignored)
  dashboard/
    dashboard.html                 Dashboard source (HTML + inline JS)
    dashboard.js                   Dashboard JavaScript (standalone reference)
    dashboard.h                    Generated gzip-compressed payload
    sensor_history_multi.h         Firmware: SensorEntity model, history, API, aggregator
  firmware/
    esp32-c3-multi-sensor.yaml     ESPHome config (C3 default)
    boards/                        Board profiles (C3, S3, WROOM-32D)
  partitions/
    esp32-c3-multi-partitions.csv  C3 partition table
    esp32-s3-multi-partitions.csv  S3 partition table
    esp32-wroom-multi-partitions.csv WROOM partition table
  scripts/
    render_sensor_config.py        Generator for all sensor-dependent files
    generate-header.sh             Gzip dashboard into C header
    bump-version.sh                Atomic version bump
    preflight.sh                   Repo validation (53 checks)
    exporters/                     System metrics exporter scripts (Phase 6)
  src/
    gateway_manifest.h             Generated manifest v2 JSON
    aggregator_config.h            Generated aggregator constants
  tests/
    browser/                       Playwright specs (117 tests)
    fixtures/                      Mock API data and variant fixtures
    mock-server/                   Local HTTP mock for Playwright
  prompts/                         Per-step AI agent implementation instructions
  Docs/                            Architecture, implementation plans, changelog
  VERSION                          Current version number
```

## API Endpoints

### Data API (v2)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/dashboard.html` | GET | Embedded dashboard |
| `/api/manifest` | GET | Manifest v2 — devices, metrics, gateway metadata |
| `/api/v2/live` | GET | Current values for all devices (JSON) |
| `/api/v2/history/{device}/{metric}` | GET | Per-device per-metric history (CSV) |
| `/api/status` | GET | Version, uptime, sensor health, free heap |
| `/api/storage-stats` | GET | Partition sizes and retention statistics |
| `/api/ingest/{device}/{metric}?val={float}` | POST | Push external metrics (Phase 6) |

### Aggregator API (when `AGGREGATOR_ENABLED`)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/aggregator/gateways` | GET | Satellite list with cached manifests and status |
| `/api/aggregator/live` | GET | Merged live data from all satellites |
| `/api/aggregator/proxy/{gw_id}/...` | GET | Proxy requests to satellite APIs |
| `/api/aggregator/add-satellite` | POST | Add satellite (stub — Phase D) |
| `/api/aggregator/satellite/{id}` | DELETE | Remove satellite (stub — Phase D) |
| `/api/aggregator/test-satellite` | POST | Probe satellite URL (stub — Phase D) |

### Legacy + Management

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/sensors.json` | GET | No | v1 sensor list (backward compat) |
| `/history/{id}/temp` | GET | No | Legacy temperature history |
| `/history/{id}/hum` | GET | No | Legacy humidity history |
| `/api/reboot` | POST | Basic | Reboot the ESP |
| `/api/delete-data` | POST | Basic | Erase persisted history |
| `/api/import/*` | POST | Basic | CSV history import (multi/single) |

## Testing

**Playwright browser tests** (117 tests across 3 fixture variants):

```bash
npm ci
npx playwright install --with-deps chromium firefox
FIXTURE_SET=3sensor npx playwright test --project=chromium    # baseline: 97 pass, 18 skip
FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium   # 7 pass
FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium  # 11 pass
```

**Preflight checks** (53 checks) validate version sync, manifest schema, fixture integrity, and build pipeline:

```bash
bash scripts/preflight.sh
python3 scripts/render_sensor_config.py --check
```

**Device testing** (manual, post-merge) validates real hardware behavior.

## Architecture

The project follows a manifest-driven architecture. `config/sensors.json` drives code generation:

- **Python generator** produces C++ entity arrays, YAML configs, gateway manifest headers, and test fixtures
- **Firmware** runs ESPHome on ESP-IDF for BLE + WiFi coexistence
- **SensorEntity model** — generalized structs supporting environmental, network, and system device categories
- **Dashboard** uses `CARD_RENDERERS` and `METRIC_FORMATTERS` registries for manifest-driven rendering
- **Aggregator** uses a unified boot path (satellite pipeline + overlay) per LESSON-OPS-074

See [Docs/v7.5-v7.6-architecture-plan.md](Docs/v7.5-v7.6-architecture-plan.md) for the full architecture document.

## Dashboard Architecture

The dashboard is built from modular source files using a three-pass build pipeline:

1. **JS modules** (`dashboard/core/*.js` + `dashboard/components/*/index.js`) are bundled into `dashboard/dashboard.js`
2. **Generator** (`render_sensor_config.py`) injects sensor metadata into the bundle
3. **HTML assembly** (`build-dashboard.sh`) combines CSS, component templates, and JS into `dashboard/dashboard.html`
4. **Minification** and **header generation** produce the final firmware-embedded artifact

`dashboard.js` and `dashboard.html` are generated files — never edit them directly. Edit the source modules and run the pipeline.

See `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` for the full architecture plan.

## Development Roadmap

| Phase | Version | Description | Status |
|-------|---------|-------------|--------|
| Phase 1 | v7.5.0.x | Manifest v2 + `/api/manifest` | ✅ Complete |
| Phase 2 | v7.5.1.x | Dashboard consumes v2 manifest | ✅ Complete |
| Phase 3 | v7.5.3.x | C++ SensorEntity model | ✅ Complete |
| Phase 4 | v7.5.4.x | First non-climate sensor (ping probe) | ✅ Complete |
| Phase 5 | v7.5.5.x | Aggregator MVP (multi-gateway) | ✅ Complete |
| **Phase 6** | **v7.5.6.x** | **Data ingest + system metrics** | **Next** |
| Phase D | v7.6.0.x | Runtime satellite management | Planned |
| Phase 7 | v7.7.x | Per-device persistence engine | Planned |
| Phase E | v8.x | Captive portal + WiFi config | Future |

## Documentation

| Document | Content |
|----------|---------|
| [Docs/changelog.md](Docs/changelog.md) | Full release history |
| [Docs/v7.5-v7.6-architecture-plan.md](Docs/v7.5-v7.6-architecture-plan.md) | Architecture plan (Phases 1–6) |
| [Docs/phase-d-implementation-plan.md](Docs/phase-d-implementation-plan.md) | Phase D (runtime satellite management) |
| [Docs/phase6-implementation-plan.md](Docs/phase6-implementation-plan.md) | Phase 6 (data ingest + system metrics) |
| [Docs/v7.7-v7.8-persistence-architecture.md](Docs/v7.7-v7.8-persistence-architecture.md) | Phase 7 persistence architecture |
| [Docs/aggregator-setup.md](Docs/aggregator-setup.md) | Aggregator deployment guide |
| [Docs/bugs-and-lessons-learned.md](Docs/bugs-and-lessons-learned.md) | Bug database + operational lessons |
| [Docs/writing-prompts-for-coding-agents-guide.md](Docs/writing-prompts-for-coding-agents-guide.md) | AI agent prompt methodology |

## License

This project is provided as-is for personal and educational use.
