# Multi-Board Infrastructure Plan

_Date: 2026-03-22_
_Prerequisite: v7.5.5.1 merged (aggregator polling task)_
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Problem

The project has a single firmware target: ESP32-C3 SuperMini. Phase 5 introduces the aggregator role, which should run on more capable hardware (ESP32-S3, ESP32-WROOM-32D, and future boards). The current build pipeline hardcodes the C3 chip variant, flash size, partition table, and device identity directly in the YAML. Compiling the same firmware for a different board requires manually rewriting these sections — error-prone and not repeatable.

Additionally, an aggregator-only device may have zero local BLE sensors. The current generator assumes at least one sensor exists and would fail or produce incorrect YAML for a sensorless configuration.

---

## Design

### Three layers of configuration

**Layer 1 — Board profile** (`firmware/boards/{board-id}.yaml`): Static hardware definition. Chip variant, flash size, PSRAM, sdkconfig, partition table path. One file per board type, shared by all devices of that type. Checked into the repo. Rarely changes.

**Layer 2 — Gateway config** (`config/gateway.json`): Per-device deployment info. Board selection, ESPHome name, WiFi address, friendly name. One file per physical device. Not checked in (device-specific). Optional — when absent, the generator uses C3 defaults for backward compatibility.

**Layer 3 — Role config** (existing files): `config/sensors.json` defines what sensors/devices this gateway monitors. `config/aggregator.json` defines what satellites this gateway polls. These are already board-agnostic.

### Generator behavior

| `config/gateway.json` | `config/aggregator.json` | Result |
|---|---|---|
| Absent | Absent | ESP32-C3 satellite (existing behavior, fully backward compatible) |
| Absent | Present | ESP32-C3 aggregator (current v7.5.5.0+ behavior) |
| Present (board=S3) | Absent | ESP32-S3 satellite |
| Present (board=S3) | Present | ESP32-S3 aggregator |

### Output files

The generator produces one YAML file per invocation. The output filename is derived from the board profile:

| Board | Output YAML |
|---|---|
| esp32-c3-supermini (default) | `firmware/esp32-c3-multi-sensor.yaml` |
| esp32-s3-devkitc1-n16r8 | `firmware/esp32-s3-devkitc1-n16r8-gw.yaml` |
| esp32-wroom-32d | `firmware/esp32-wroom-32d-gw.yaml` |

The C++ headers (`sensor_history_multi.h`, `dashboard.h`, `gateway_manifest.h`, `aggregator_config.h`) are board-agnostic — the same headers compile on all variants. The generator does not need to produce different C++ for different boards.

### Zero-sensor aggregator support

When `config/sensors.json` has an empty `sensors` array (or only non-BLE devices like ping probes), the generator:

- Sets `NUM_DEVICES = 0` (or N for non-BLE devices only)
- Sets `NUM_ENV_SENSORS = 0`, `NUM_SENSORS = 0`
- Omits `esp32_ble_tracker:` from the YAML
- Omits all ThermoPro sensor/RSSI/text_sensor blocks
- Omits sorting groups for sensors that don't exist
- Keeps the web server, dashboard, API endpoints, aggregator task, and ping adapter (if configured)

The C++ code handles `NUM_DEVICES == 0` correctly because all device loops use `for (int i = 0; i < NUM_DEVICES; i++)` which executes zero iterations. The dashboard handles empty manifests through the Phase 2 fallback chain.

---

## Board Profiles

### Format

```yaml
# firmware/boards/{board-id}.yaml
board_id: "esp32-s3-devkitc1-n16r8"
chip_variant: "esp32s3"
esphome_board: "esp32-s3-devkitc1-n16r8"
flash_size: "16MB"
partitions: "../partitions/esp32-s3-multi-partitions.csv"
framework:
  type: "esp-idf"
sdkconfig_options:
  CONFIG_LWIP_MAX_SOCKETS: "16"
psram:
  mode: "octal"
  speed: "80MHz"
capabilities:
  ble: true
  psram: true
  dual_core: true
notes: "ESP32-S3-DevKitC-1 with 16MB flash, 8MB PSRAM"
```

The `capabilities` block is informational — it tells the generator whether BLE scanning is possible on this board. The generator uses it to decide whether `esp32_ble_tracker:` should be included when BLE sensors are configured.

### Supported boards (current)

| Board ID | Variant | Flash | PSRAM | BLE | Cores | Primary role |
|---|---|---|---|---|---|---|
| `esp32-c3-supermini` | esp32c3 | 4MB | No | Yes (5.0) | 1 | Satellite |
| `esp32-s3-devkitc1-n16r8` | esp32s3 | 16MB | 8MB | Yes (5.0) | 2 | Aggregator |
| `esp32-wroom-32d` | esp32 | 4MB | No | Yes (4.2) | 2 | Aggregator |

### Future boards (planned, no profiles yet)

| Board ID | Variant | Flash | BLE | Primary role | Notes |
|---|---|---|---|---|---|
| `esp32-c5-*` | esp32c5 | TBD | Yes (5.0+WiFi 6) | Either | Not yet supported in ESPHome stable |
| `esp32-c6-*` | esp32c6 | TBD | Yes (5.0+WiFi 6+Thread) | Either | ESPHome support maturing |
| `esp32-p4-*` | esp32p4 | TBD | No (needs external) | Aggregator | High-perf, no radio — needs coprocessor |
| `rpi-zero2w` | N/A | N/A | N/A | Aggregator | Separate codebase (Node.js/Python) |

Note: Raspberry Pi and ESP32-P4 aggregators are a separate implementation effort (different runtime, different build system). The multi-board infrastructure covers ESPHome-based boards only.

---

## Gateway Config Schema

```json
{
  "board": "esp32-s3-devkitc1-n16r8",
  "esphome_name": "esp32-n16r8-gw-1",
  "friendly_name": "ESP32-S3 Aggregator",
  "wifi_address": "192.168.120.191"
}
```

**Validation rules:**
- `board` must match a file in `firmware/boards/{board}.yaml`
- `esphome_name` must be a valid ESPHome device name (lowercase, hyphens, no spaces)
- `wifi_address` must be a valid IPv4 address
- `friendly_name` is a human-readable label (any UTF-8 string)

**When absent:** Generator uses defaults: board=`esp32-c3-supermini`, name from existing YAML, address from existing YAML. This preserves full backward compatibility for the existing C3 satellite workflow.

---

## Partition Tables

### ESP32-C3 (4MB flash) — existing, unchanged

```
# partitions/esp32-c3-multi-partitions.csv
nvs,        data, nvs,      0x9000,   0x4000,
otadata,    data, ota,      0xD000,   0x2000,
phy_init,   data, phy,      0xF000,   0x1000,
ota_0,      app,  ota_0,    0x10000,  0x1B0000,
ota_1,      app,  ota_1,    ,         0x1B0000,
history,    data, nvs,      ,         0x80000,
coredump,   data, coredump, ,         0x10000,
```

History: 512KB → ~19 days per device (3 ThermoPro + 1 ping)

### ESP32-S3 (16MB flash) — new

```
# partitions/esp32-s3-multi-partitions.csv
nvs,        data, nvs,      0x9000,   0x5000,
otadata,    data, ota,      0xE000,   0x2000,
phy_init,   data, phy,      0x10000,  0x1000,
ota_0,      app,  ota_0,    0x20000,  0x300000,
ota_1,      app,  ota_1,    ,         0x300000,
history,    data, nvs,      ,         0x400000,
coredump,   data, coredump, ,         0x10000,
```

History: 4MB → ~132 days per device (3 ThermoPro + 1 ping). OTA slots: 3MB each (ample for S3 binary).

### ESP32-WROOM-32D (4MB flash) — new

```
# partitions/esp32-wroom-multi-partitions.csv
nvs,        data, nvs,      0x9000,   0x4000,
otadata,    data, ota,      0xD000,   0x2000,
phy_init,   data, phy,      0xF000,   0x1000,
ota_0,      app,  ota_0,    0x10000,  0x1B0000,
ota_1,      app,  ota_1,    ,         0x1B0000,
history,    data, nvs,      ,         0x80000,
coredump,   data, coredump, ,         0x10000,
```

Same layout as C3 (same 4MB flash). History: 512KB.

---

## Generator Changes

### `sensor_manifest_lib.py`

New functions:
- `load_gateway_config()` — reads `config/gateway.json`, returns None if absent
- `validate_gateway_config(config)` — validates board reference, name format, IP
- `load_board_profile(board_id)` — reads `firmware/boards/{board_id}.yaml`, validates

### `render_sensor_config.py`

Changes:
- Load gateway config at startup (optional)
- Load board profile if gateway config specifies a board
- Pass board profile to YAML generation
- Generate board-specific `esp32:` block and `psram:` block
- Use `esphome_name` and `wifi_address` from gateway config
- Generate to board-specific output filename
- Handle `NUM_ENV_SENSORS == 0` (no BLE sensor blocks)
- Handle `NUM_DEVICES == 0` (no device blocks at all)

### Zero-sensor YAML structure

When sensors array is empty and aggregator.json is present (pure aggregator):

```yaml
esphome:
  name: "esp32-n16r8-gw-1"
  friendly_name: "ESP32-S3 Aggregator"
  ...
  on_boot:
    - priority: -100
      then:
        - lambda: |-
            register_history_handler(...);
    - priority: 600
      then:
        - lambda: |-
            #if AGGREGATOR_ENABLED
            start_aggregator_task();
            #endif

esp32:
  variant: esp32s3
  ...

web_server_base:
  ...
web_server:
  ...

# NO esp32_ble_tracker:
# NO thermopro sensor: blocks
# NO ble_rssi sensor: blocks
# NO per-sensor text_sensor: blocks

sensor:
  - platform: wifi_signal
    ...
  - platform: debug
    ...
  - platform: uptime
    ...

text_sensor:
  - platform: template
    name: "Description"
    ...
  - platform: template
    name: "Dashboard Paths"
    ...
```

---

## Implementation Sequence

This infrastructure work should be completed before v7.5.5.2 (aggregator API endpoints) so that v7.5.5.2 can be compiled and tested on actual S3 hardware.

**Step 1:** Create board profiles and partition tables (static files, no code changes)
**Step 2:** Extend `sensor_manifest_lib.py` with gateway config and board profile loading
**Step 3:** Extend `render_sensor_config.py` to accept board selection and generate board-specific YAML
**Step 4:** Handle zero-sensor configuration in the generator
**Step 5:** Validate by generating and compiling for S3 and WROOM-32D targets
**Step 6:** Update preflight.sh to validate board profiles
**Step 7:** Documentation

---

## What This Does NOT Change

- C++ code in `sensor_history_multi.h` (board-agnostic, compiles on all variants)
- Dashboard HTML/JS (board-agnostic)
- Test fixtures and Playwright tests (test behavior, not hardware)
- `config/sensors.json` schema (devices are independent of board hardware)
- `config/aggregator.json` schema (satellites are independent of board hardware)
- VERSION file (this is build infrastructure, not firmware behavior)
- The C3 satellite workflow (fully backward compatible when gateway.json absent)

---

_End of document._
