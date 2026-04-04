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

- `gateway.json` and `aggregator.json` are **human-authored** deployment configs — they are NOT generated. You create them manually.
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

### 7.1) Full Regeneration Pipeline

**⚠️ ALWAYS run the complete pipeline before compiling firmware.** The pipeline generates all derived artifacts from the config files. Missing any step can produce stale or mismatched firmware.

```bash
# Step 1: Generate C++ headers, YAML, and test fixtures from config
python3 scripts/render_sensor_config.py --write

# Step 2: Regenerate test fixture files
node tests/fixtures/generate-fixtures.js

# Step 3: Minify dashboard HTML (produces dashboard.min.html)
bash scripts/minify-dashboard.sh

# Step 4: Generate gzip-compressed dashboard header (uses .min.html if present)
bash scripts/generate-header.sh

# Step 5: Verify all generated files are in sync
python3 scripts/render_sensor_config.py --check

# Step 6: Run preflight checks
bash scripts/preflight.sh
```

**Why `minify-dashboard.sh` matters:** `generate-header.sh` auto-detects `dashboard.min.html` and uses it if present. Without the minification step, the firmware embeds the unminified HTML — larger flash footprint and slower page load. If `dashboard.min.html` already exists from a previous run but `dashboard.html` has been modified since (e.g. version bump), the stale minified copy gets embedded. Always re-run the minification step.

### 7.2) Which YAML Do I Compile?

**⚠️ CRITICAL: The YAML you compile must match the board you are flashing.** The C3 satellite template (`firmware/esp32-c3-multi-sensor.yaml`) is the only YAML committed to the repo. All other board YAMLs are **generated** by `render_sensor_config.py --write` and are **gitignored** — they only exist in your local working copy after generation.

| Target board | YAML to compile | How it gets there | Role determined by |
|---|---|---|---|
| ESP32-C3 SuperMini (default satellite) | `firmware/esp32-c3-multi-sensor.yaml` | Committed to repo (template, modified in-place when no gateway.json) | Always satellite (no PSRAM) |
| ESP32-C3 SuperMini (with gateway.json) | `firmware/{esphome_name}-gw.yaml` | **Generated** by `render_sensor_config.py --write` | Always satellite (no PSRAM) |
| ESP32-S3-DevKitC-1 N16R8 | `firmware/esp32-s3-devkitc1-n16r8-gw.yaml` | **Generated** by `render_sensor_config.py --write` | Aggregator if `aggregator.json` exists; satellite otherwise |
| ESP32-WROOM-32D | `firmware/esp32-wroom-32d-gw.yaml` | **Generated** by `render_sensor_config.py --write` | Always satellite (no PSRAM) |

**If the generated YAML doesn't exist, you forgot to run `render_sensor_config.py --write` with the correct `gateway.json` in place.** The generator prints the files it updated — look for the YAML path in the output.

**DO NOT compile `firmware/esp32-c3-multi-sensor.yaml` for non-C3 boards.** This is a C3-specific template. Compiling it for an S3 will produce satellite firmware for the wrong chip architecture, without any aggregator capability.

### 7.3) Verify Generated Artifacts

After running the regeneration pipeline, verify the key outputs:

```bash
# Check that the correct YAML was generated for your board
ls -la firmware/esp32-s3-devkitc1-n16r8-gw.yaml  # for S3 aggregator
# or
ls -la firmware/esp32-wroom-32d-gw.yaml            # for WROOM satellite

# Check aggregator is enabled (for aggregator builds)
grep -n "AGGREGATOR_ENABLED" src/aggregator_config.h
# Expected for aggregator: #define AGGREGATOR_ENABLED 1

# Check board identity in generated YAML
head -5 firmware/esp32-s3-devkitc1-n16r8-gw.yaml
# Should show: "# S3 Aggregator - vX.Y.Z.W" and board profile reference
```

### 7.4) Compile and Flash

```bash
# === S3 AGGREGATOR ===
esphome clean firmware/esp32-s3-devkitc1-n16r8-gw.yaml
esphome run firmware/esp32-s3-devkitc1-n16r8-gw.yaml
# Select OTA at 192.168.120.191 or USB with correct passthrough (LESSON-OPS-073)

# === C3 SATELLITE (default, no gateway.json) ===
esphome clean firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml
# Select OTA at 192.168.120.189 or USB

# === WROOM-32D SATELLITE ===
esphome clean firmware/esp32-wroom-32d-gw.yaml
esphome run firmware/esp32-wroom-32d-gw.yaml
# Select OTA at 192.168.120.190 or USB
```

## 8) Accessing the Dashboard

- Open `http://<aggregator-ip>`.
- Layout has two sections:
  - **GATEWAYS**: selector tabs, all-gateway summary, per-gateway views, settings.
  - **SENSORS**: local sensors on the aggregator device.
- "All Gateways" gives reachability and metadata summary.

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
| Dashboard shows local sensors but no Gateways card | Compiled wrong YAML — used C3 template instead of generated S3 YAML | Verify YAML path per Section 7.2 table, re-run pipeline, recompile correct YAML |
| History charts empty for remote gateway | Proxy path/upstream issue | Validate satellite `/api/v2/history/{device}/{metric}` directly |
| High latency/slow UI | Too many satellites for board RAM | Reduce satellites or move to S3/Pi |
| Wrong board info in About section | Board metadata mismatch | Validate manifest `gateway.hardware` and board profile selection |
| Generated YAML not found after `--write` | Missing or incorrect `config/gateway.json` | Verify `gateway.json` exists and `board` field matches a board profile |
| `AGGREGATOR_ENABLED 0` on S3 board | Missing `config/aggregator.json` or board profile has `psram: false` | Verify both config files are present and board profile is correct |

## 12) Testing and Validation (v7.6.0.5+)

The satellite management mock server routes are now implemented and tested as of v7.6.0.5 (PR #129). The Playwright test suite covers add/test/delete workflows and all firmware error branches.

### Running aggregator fixture tests

```bash
FIXTURE_SET=aggregator npx playwright test --project=chromium
```

This runs Test Group 21 (Satellite Management) with 19 tests:
- 12 API contract tests (all validation branches)
- 2 UI rendering tests (Settings panel form and remove buttons)
- 5 PR #128 regression guards (BUG-080 / BUG-081 / LESSON-OPS-111)

### Mock server endpoints

The mock server (`tests/mock-server/server.js`) provides stateful satellite management for test automation:
- `POST /api/aggregator/add-satellite?url=...&name=...&poll=30` — add satellite to managed list
- `DELETE /api/aggregator/satellite/{id}?auth=mock` — remove satellite (auth required)
- `POST /api/aggregator/test-satellite?url=...&auth=mock` — probe without adding (auth required)
- `POST /api/system/reset-satellites?auth=mock` — restore fixture defaults (auth required)

All endpoints include full validation: body guard, URL format checks, capacity limits, poll clamping (10-3600s), method 405 handling, and monotonic ID generation.

## 13) Reverting to Satellite Mode

```bash
rm -f config/aggregator.json
python3 scripts/render_sensor_config.py --write
bash scripts/minify-dashboard.sh
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

### Generated YAML files are gitignored

All `firmware/*-gw.yaml` files are generated and gitignored. They are produced by
`render_sensor_config.py --write` based on the board profile and gateway config. Only
`firmware/esp32-c3-multi-sensor.yaml` (the C3 template) is committed to the repo.

**Do NOT compile a committed YAML for a non-C3 board.** If you need to flash an S3 or
WROOM board, you MUST run the regeneration pipeline first to produce the generated YAML.

### Fixture regeneration on version bumps

Every version bump must run the full regeneration pipeline and verify (Critical Rule 28):

```bash
bash scripts/bump-version.sh <version>
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/minify-dashboard.sh
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
grep -q "free_heap" tests/fixtures/api-status.json || echo "ERROR: free_heap missing"
bash scripts/preflight.sh
```
