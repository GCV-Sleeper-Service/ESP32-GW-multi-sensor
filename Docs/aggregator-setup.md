# Aggregator Deployment Guide (Phase 5)

## 1) Overview

The aggregator role polls one or more satellite gateways, caches their manifest/live/status data, and serves a unified dashboard with gateway-aware views.  
Satellite and aggregator are capability tiers in one firmware architecture: an aggregator is a satellite plus aggregation overlay.

## 2) Hardware Requirements

- **ESP32-C3 SuperMini (4MB)**: satellite role only. No PSRAM — insufficient memory for aggregator infrastructure. Excellent as a compact, low-power sensor gateway.
- **ESP32-S3 (recommended aggregator for up to 8 satellites)**: PSRAM enables the aggregator role. Required for all aggregator deployments.
- **ESP32-WROOM-32D**: satellite role only. No PSRAM — supported as a compile target but not recommended for aggregator use.
- **Raspberry Pi Zero 2W (or similar)**: preferred for larger deployments (>5 satellites), via separate implementation outside this firmware path.

### 2.1) Buffer Sizes and PSRAM Scaling Rules

#### Buffer Sizes

- Aggregator manifest cache buffer is **8192 bytes** (`AGG_MANIFEST_BUF_SIZE`).
- If a satellite manifest reaches the truncation threshold (`manifest_len >= AGG_MANIFEST_BUF_SIZE - 1`), the aggregator omits it from `/api/aggregator/gateways` as `"manifest":null` and logs a warning.
- Reference sizing: a satellite with 5 sensors plus system devices typically produces a manifest around 5–6KB.

#### PSRAM Scaling Rules (enforced by generator)

`scripts/render_sensor_config.py` enforces aggregator role eligibility and caps at build time:

| Board profile | `capabilities.psram` | Aggregator role | `MAX_SATELLITES` cap |
|---|---:|---|---:|
| `esp32-s3-devkitc1-n16r8` | true | Enabled | 8 |
| `esp32-c3-supermini` | false | Disabled (satellite-only) | 0 (aggregator off) |
| `esp32-wroom-32d` | false | Disabled (satellite-only) | 0 (aggregator off) |

If `config/aggregator.json` lists more satellites than the board cap, generation emits a warning and truncates to the cap.

#### Board Recommendations

- **Use ESP32-S3 with PSRAM for aggregator deployments.**
- **ESP32-C3 and ESP32-WROOM-32D should be used as satellites only.**
- The build system enforces this policy by generating `AGGREGATOR_ENABLED 0` on non-PSRAM boards, even if `aggregator.json` exists.

## 3) Naming Convention (recommended, not mandatory)

Gateway hostnames are recommended as:

- Satellite: `sat-{chip}-{flash}m-{location}`
- Aggregator: `agg-{chip}-{flash}m-{location}`

Examples: `sat-c3-4m-office`, `agg-s3-16m-hq1`, `agg-pi-00m-main`.

Keep gateway names plain text (avoid HTML special characters) for safe dashboard rendering and clear manifests.

## 4) Prerequisites

- At least one satellite already flashed and reachable over the network.
- ESPHome/tooling available for compile/flash.
- L3 routing/firewall path from aggregator to each satellite `base_url`.
- Board profile selected for the target board.

## 5) Board Profile System and Config Separation

Board profiles live in:

- `firmware/boards/esp32-c3-supermini.yaml`
- `firmware/boards/esp32-s3-devkitc1-n16r8.yaml`
- `firmware/boards/esp32-wroom-32d.yaml`

Deployment config files:

- `config/gateway.json` — per-device board/identity selection (including optional `sensors_file`)
- `config/aggregator.json` — aggregator satellite list and polling settings
- `config/sensors.json` (or `sensors_file`) — local sensors for this device

Important separation:

- `gateway.json` and `aggregator.json` are deployment configs.
- For CI-style generation validation (`render_sensor_config.py --check`), keep both absent unless specifically validating deployment variants.

## 6) Configuration Steps

### 6.1 Create gateway config (board selection)

Copy `config/gateway.example.json` to `config/gateway.json` and set:

- `board`
- `esphome_name`
- `friendly_name`
- `wifi_address`
- optional `sensors_file`

Use `sensors_file` when you want per-device sensor manifests (for example aggregator-specific local sensors).

### 6.2 Create aggregator config

Copy `config/aggregator.example.json` to `config/aggregator.json`, then configure:

- `id` (unique)
- `name` (plain text)
- `base_url` (must start with `http://`, no TLS in current implementation)
- `poll_interval_seconds` (10–300, typical 30)

### 6.3 Configure local sensors

- If aggregator has local sensors, configure them in `config/sensors.json` (or `sensors_file`).
- Zero-sensor aggregator is valid with gateway-config path enabled.

## 7) Build and Flash

Generate artifacts:

```bash
python3 scripts/render_sensor_config.py --write
bash scripts/generate-header.sh
```

Verify generated aggregator header:

```bash
grep -n "AGGREGATOR_ENABLED" src/aggregator_config.h
```

Compile (board-dependent):

```bash
# C3 default path
esphome compile firmware/esp32-c3-multi-sensor.yaml

# Non-C3 board profiles generate board-specific YAML
esphome compile firmware/<board-id>-gw.yaml
```

Flash:

```bash
esphome run firmware/<target-yaml> --device <ip-or-serial>
```

## 8) Accessing the Dashboard

- Open `http://<aggregator-ip>`.
- Layout has two sections:
  - **GATEWAYS**: selector tabs, all-gateway summary, per-gateway views, settings.
  - **SENSORS**: local sensors on the aggregator device.
- “All Gateways” gives reachability and metadata summary.

## 9) Network Requirements

- Aggregator must reach each satellite `base_url` and port (typically 80).
- Satellite does **not** need inbound connectivity to aggregator.
- Across VLANs, ensure routes/ACLs allow aggregator-origin HTTP to satellites.
- Firewall rule: allow aggregator → satellite HTTP.

## 10) Monitoring and Health Checks

- `GET /api/status` on aggregator: firmware, uptime, heap.
- `GET /api/aggregator/gateways`: reachability and cached gateway metadata.
- `GET /api/aggregator/live`: unified current values from cached satellite data.
- Watch heap trend over time; sustained drift indicates memory pressure/leak investigation needed.

## 11) Troubleshooting

| Symptom | Likely Cause | Action |
|---|---|---|
| Satellite marked unreachable | Wrong IP, network/routing/firewall issue, satellite offline | Validate direct reachability and satellite `/api/status` |
| Empty aggregator gateway view | Missing/invalid `config/aggregator.json` or stale generated artifacts | Re-run render step and confirm `AGGREGATOR_ENABLED 1` |
| History charts empty for remote gateway | Proxy path/upstream issue | Validate satellite `/api/v2/history/{device}/{metric}` directly |
| High latency/slow UI | Too many satellites for board RAM | Reduce satellites or move to S3/Pi |
| Wrong board info in About section | Board metadata mismatch | Validate manifest `gateway.hardware` and board profile selection |

## 12) Reverting to Satellite Mode

```bash
rm -f config/aggregator.json
python3 scripts/render_sensor_config.py --write
bash scripts/generate-header.sh
esphome compile firmware/<target-yaml>
esphome run firmware/<target-yaml> --device <ip-or-serial>
```

## 13) Security Considerations

- Satellite read APIs are unauthenticated in current phase.
- Aggregator polls read-only endpoints (`/api/manifest`, `/api/status`, `/api/v2/live`).
- Deploy satellites/aggregator on trusted or isolated network segments.
- Future roadmap includes runtime satellite management and stronger auth controls.

## 14) Partition and Storage Notes

- Ensure selected board partition table places `ota_0` at `0x10000`.
- S3 and WROOM partition profiles are included and should be used with matching board profile.
- Persistence and retention behavior remains local-device scoped.

## 15) CI / Development Pipeline Notes

### Deployment configs are gitignored

`config/gateway.json` and `config/aggregator.json` are deployment-specific files listed
in `.gitignore`. They are NOT present in CI. Their presence changes what the generator
produces:

- **With `aggregator.json`:** Generator outputs `AGGREGATOR_ENABLED 1`, satellite list,
  aggregator-specific YAML. The generated fixture and header reflect aggregator mode.
- **Without `aggregator.json`:** Generator outputs `AGGREGATOR_ENABLED 0` and satellite
  (C3 default) configuration. CI expects this output.

**Workaround for local development on an aggregator device:** Before running
`render_sensor_config.py --write` / `--check`, `preflight.sh`, or the Playwright
test suite, temporarily move deployment configs out of the way:

```bash
# Before CI-style checks
mv config/gateway.json config/gateway.json.bak 2>/dev/null
mv config/aggregator.json config/aggregator.json.bak 2>/dev/null

# Run checks (expects C3 satellite defaults)
python3 scripts/render_sensor_config.py --check
bash scripts/preflight.sh
FIXTURE_SET=3sensor npx playwright test --project=chromium

# Restore after checks
mv config/gateway.json.bak config/gateway.json 2>/dev/null
mv config/aggregator.json.bak config/aggregator.json 2>/dev/null
```

**Proper fix (future):** Per-target builds or a `--target` flag in the generator that
selects the expected output profile. Tracked as a Phase D improvement.

### Fixture regeneration on version bumps

Every version bump must run both generators and verify (Critical Rule 28):

```bash
bash scripts/bump-version.sh <version>
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
grep -q "free_heap" tests/fixtures/api-status.json || echo "ERROR: free_heap missing"
bash scripts/preflight.sh
```
