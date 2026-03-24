# Multi-Board Infrastructure Setup (Coding Agent Prompt)

_Full self-contained implementation instructions for the coding agent_
_Date: 2026-03-22_
_Prerequisite: v7.5.5.1 merged (aggregator polling task, BUG-057 socket fix applied)_

**This is a build-infrastructure step. No VERSION bump. No firmware behavior changes.**

---

## 1. Repository & Setup

```
Clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
```

---

## 2. Required Reading (MUST complete before any changes)

Read these files **completely**:

1. `Docs/multi-board-infrastructure-plan.md` — full design rationale
2. `Docs/bugs-and-lessons-learned.md` — especially:
   - **LESSON-OPS-068** — use `lwip_*()` prefixed functions, not BSD socket aliases
   - **LESSON-OPS-059** — runtime device count vs persisted-history count are different
   - **LESSON-OPS-064** — endpoint audit when adding device categories
3. `scripts/sensor_manifest_lib.py` — existing validation patterns
4. `scripts/render_sensor_config.py` — existing generation pipeline, marker blocks, `--write`/`--check` modes
5. `firmware/esp32-c3-multi-sensor.yaml` — current YAML structure, all `SENSOR_MANIFEST:` marker blocks
6. `firmware/boards/` — the three board profile YAML files
7. `partitions/` — all partition table CSV files

---

## 3. Current Status

- v7.5.5.1 merged (aggregator polling task with BUG-057 lwIP fix)
- Three board profiles exist in `firmware/boards/` (C3, S3, WROOM-32D)
- Two new partition tables exist in `partitions/` (S3, WROOM)
- Generator currently produces ONLY the C3 YAML
- Generator does NOT support zero-sensor configurations
- No `config/gateway.json` schema exists yet

---

## 4. Pre-condition Checks

```bash
bash scripts/preflight.sh
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium
```

---

## 5. Exact Scope

### 5a. Create `config/gateway.json` schema and example

Create `config/gateway.example.json`:

```json
{
  "board": "esp32-s3-devkitc1-n16r8",
  "esphome_name": "esp32-n16r8-gw-1",
  "friendly_name": "ESP32-S3 Aggregator",
  "wifi_address": "192.168.120.191"
}
```

**Do NOT create `config/gateway.json` itself.** When this file is absent, the generator uses C3 defaults. It's created per-device by the operator.

### 5b. Extend `sensor_manifest_lib.py`

Add these functions:

```python
import yaml  # PyYAML — already available in ESPHome environment
import os

BOARDS_DIR = os.path.join(os.path.dirname(__file__), '..', 'firmware', 'boards')

def load_board_profile(board_id):
    """Load a board profile from firmware/boards/{board_id}.yaml.
    Returns dict or raises ManifestError."""
    profile_path = os.path.join(BOARDS_DIR, f"{board_id}.yaml")
    if not os.path.isfile(profile_path):
        raise ManifestError(f"Board profile not found: {profile_path}")
    with open(profile_path, 'r') as f:
        profile = yaml.safe_load(f)
    required_keys = ['board_id', 'chip_variant', 'esphome_board', 'flash_size',
                     'partitions', 'framework']
    for key in required_keys:
        if key not in profile:
            raise ManifestError(f"Board profile {board_id} missing required key: {key}")
    if profile['board_id'] != board_id:
        raise ManifestError(f"Board profile board_id mismatch: file={board_id}, content={profile['board_id']}")
    return profile

def load_gateway_config():
    """Load config/gateway.json if it exists. Returns dict or None."""
    gw_path = os.path.join(os.path.dirname(__file__), '..', 'config', 'gateway.json')
    if not os.path.isfile(gw_path):
        return None
    import json
    with open(gw_path, 'r') as f:
        config = json.load(f)
    validate_gateway_config(config)
    return config

def validate_gateway_config(config):
    """Validate gateway config schema. Raises ManifestError on failure."""
    if 'board' not in config:
        raise ManifestError("gateway.json missing 'board'")
    if 'esphome_name' not in config:
        raise ManifestError("gateway.json missing 'esphome_name'")
    if 'wifi_address' not in config:
        raise ManifestError("gateway.json missing 'wifi_address'")
    # Validate board reference
    load_board_profile(config['board'])  # will raise if not found
    # Validate name format (ESPHome requires lowercase, hyphens, digits)
    import re
    name = config['esphome_name']
    if not re.match(r'^[a-z0-9][a-z0-9-]*$', name):
        raise ManifestError(f"esphome_name must be lowercase alphanumeric with hyphens: {name}")
    # Validate IP format
    import ipaddress
    try:
        ipaddress.IPv4Address(config['wifi_address'])
    except ValueError:
        raise ManifestError(f"wifi_address must be a valid IPv4 address: {config['wifi_address']}")
```

### 5c. Extend `render_sensor_config.py`

**Add gateway config and board profile loading to `main()`:**

After loading the manifest and aggregator config, add:

```python
gateway_config = load_gateway_config()
board_profile = None
if gateway_config:
    board_profile = load_board_profile(gateway_config['board'])
else:
    board_profile = load_board_profile('esp32-c3-supermini')  # default
```

**Add a `generate_yaml()` function that accepts the board profile:**

The current YAML generation uses marker-block replacement in the existing C3 YAML. For multi-board, the approach changes:

1. If `config/gateway.json` is absent → existing behavior unchanged (modify C3 YAML in place)
2. If `config/gateway.json` is present → generate a NEW YAML file from a template, incorporating the board profile

**The new YAML generation must produce a complete, valid ESPHome YAML** with:
- `esphome:` block with name from gateway config
- `esp32:` block from board profile (variant, board, flash_size, partitions)
- `psram:` block from board profile (if present)
- `framework:` with `sdkconfig_options` from board profile
- All standard sections (logger, debug, ota, api, wifi, web_server)
- `on_boot:` lambdas (register_history_handler, ping adapter if configured, aggregator task if configured)
- `on_time:` 15-minute averaging lambdas (only if sensors exist)
- `on_time:` hourly persistence lambda (only if environmental sensors exist)
- ThermoPro sensor/RSSI blocks (only if environmental sensors exist)
- Text sensor blocks (only for configured sensors)
- Sorting groups (only for configured sensors)
- Standard diagnostic sensors (wifi_signal, debug, uptime)

**Output filename:** Derived from board profile: `firmware/{board_id}-gw.yaml`
Exception: when board is `esp32-c3-supermini`, output remains `firmware/esp32-c3-multi-sensor.yaml` for backward compatibility.

### 5d. Handle zero-sensor configurations

The generator must handle `sensors` array with:
- Zero entries (pure aggregator, no local sensors at all)
- Only non-BLE entries (e.g., only `wan_ping` with adapter `icmp_ping`)
- Only BLE entries (current behavior)
- Mixed BLE + non-BLE entries (current behavior)

**Rules for zero environmental sensors:**
- `NUM_ENV_SENSORS = 0`, `NUM_SENSORS = 0`
- NO `esp32_ble_tracker:` section in YAML
- NO ThermoPro `sensor:` blocks
- NO `ble_rssi` blocks
- NO per-sensor text_sensor blocks
- NO per-sensor sorting groups
- The `sensor:` section still contains wifi_signal, debug, uptime
- The averaging lambda body is empty (no `devices[i].compute_and_format()` calls)
- The persistence lambda skips if `NUM_SENSORS == 0`

**Rules for zero total devices:**
- `NUM_DEVICES = 0`
- All of the above, plus:
- NO ping adapter boot lambda
- The averaging lambda can be omitted entirely
- The persistence lambda can be omitted entirely

### 5e. Update preflight.sh

Add validation:
- If `config/gateway.json` exists, validate it references a valid board profile
- If `firmware/boards/` contains profiles, validate they have required fields
- The generated YAML (whichever board) should be checked for syntactic correctness

### 5f. Documentation

Update `Docs/configuring-sensors.md` with a new section on multi-board deployment:
- How to create `config/gateway.json`
- Available board profiles
- How to generate for a non-C3 board
- How to compile and flash for different boards

---

## 6. Critical Rules

1. **NO VERSION BUMP.** This is build infrastructure, not firmware behavior.
2. **Backward compatibility is mandatory.** When `config/gateway.json` is absent, the generator MUST produce identical output to the current version. Diff the before/after C3 YAML — it must be identical (or differ only in whitespace).
3. **Do not modify `sensor_history_multi.h`.** The C++ code is already board-agnostic.
4. **Do not modify `dashboard.js` or `dashboard.html`.** The dashboard is already board-agnostic.
5. **Do not modify `dashboard.h`.** No dashboard changes.
6. **PyYAML dependency:** The ESPHome environment has PyYAML available. If running outside ESPHome, `pip install pyyaml` may be needed. Add a note to the docs.
7. **All existing Playwright tests must still pass** — this is a generator-only change, no test behavior changes.
8. **Mirror rule does not apply** — no dashboard.js changes, so no dashboard.html mirroring needed.

---

## 7. Validation

```bash
# 1. Preflight must pass
bash scripts/preflight.sh

# 2. Generate for C3 (default, no gateway.json) — must produce identical YAML
python3 scripts/render_sensor_config.py --write
diff firmware/esp32-c3-multi-sensor.yaml firmware/esp32-c3-multi-sensor.yaml.bak  # should be empty

# 3. Generate for S3 (with gateway.json pointing to S3)
cat > config/gateway.json << 'EOF'
{
  "board": "esp32-s3-devkitc1-n16r8",
  "esphome_name": "esp32-n16r8-gw-1",
  "friendly_name": "ESP32-S3 Aggregator",
  "wifi_address": "192.168.120.191"
}
EOF
python3 scripts/render_sensor_config.py --write
# Verify: firmware/esp32-s3-devkitc1-n16r8-gw.yaml exists
# Verify: it contains variant: esp32s3, flash_size: 16MB
# Verify: it contains psram: section
# Verify: it contains the correct partitions path

# 4. Generate for S3 pure aggregator (zero sensors)
echo '{"schema_version": 2, "sensors": []}' > /tmp/empty-sensors.json
cp config/sensors.json config/sensors.json.bak
cp /tmp/empty-sensors.json config/sensors.json
python3 scripts/render_sensor_config.py --write
# Verify: generated YAML has NO esp32_ble_tracker section
# Verify: generated YAML has NO thermopro sensor blocks
# Verify: NUM_DEVICES = 0 in sensor_history_multi.h
mv config/sensors.json.bak config/sensors.json
python3 scripts/render_sensor_config.py --write  # restore

# 5. Clean up gateway.json (restore satellite mode)
rm config/gateway.json

# 6. Playwright tests must still pass
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium
```

---

## 8. Commit Message

```
infra: multi-board support — board profiles, gateway config, zero-sensor generation

Add board profile system (firmware/boards/*.yaml) and optional gateway config
(config/gateway.json) for multi-board deployment. The generator now supports:
- ESP32-C3 SuperMini (default, backward compatible)
- ESP32-S3-DevKitC1-N16R8 (16MB flash, 4MB history partition)
- ESP32-WROOM-32D (4MB flash, same as C3)

Zero-sensor configurations supported for pure aggregator deployments:
- Empty sensors array produces YAML without BLE tracker or ThermoPro blocks
- NUM_DEVICES=0 compiles correctly (all device loops are zero-iteration safe)

New partition tables:
- partitions/esp32-s3-multi-partitions.csv (4MB history, 3MB OTA slots)
- partitions/esp32-wroom-multi-partitions.csv (512KB history, same as C3)

No firmware behavior changes. No VERSION bump.
```

---

## 9. Session Log

Create `Docs/session-log-<DATE>-multi-board-infra.md` with standard session log format.

---

## 10. Post-Merge Verification (Human)

After merge, verify actual compilation on each board:

```bash
# S3 Aggregator:
cat > config/gateway.json << 'EOF'
{"board":"esp32-s3-devkitc1-n16r8","esphome_name":"esp32-n16r8-gw-1","friendly_name":"ESP32-S3 Aggregator","wifi_address":"192.168.120.191"}
EOF
cp config/aggregator.example.json config/aggregator.json
# Edit config/aggregator.json: set satellite base_url to 192.168.120.189
python3 scripts/render_sensor_config.py --write
esphome compile firmware/esp32-s3-devkitc1-n16r8-gw.yaml
# Expected: compilation successful

# WROOM-32D Aggregator:
cat > config/gateway.json << 'EOF'
{"board":"esp32-wroom-32d","esphome_name":"esp32-wroom-32d","friendly_name":"ESP32 WROOM Aggregator","wifi_address":"192.168.120.190"}
EOF
python3 scripts/render_sensor_config.py --write
esphome compile firmware/esp32-wroom-32d-gw.yaml
# Expected: compilation successful

# C3 Satellite (backward compat):
rm config/gateway.json config/aggregator.json
python3 scripts/render_sensor_config.py --write
esphome compile firmware/esp32-c3-multi-sensor.yaml
# Expected: compilation successful, YAML identical to before
```
