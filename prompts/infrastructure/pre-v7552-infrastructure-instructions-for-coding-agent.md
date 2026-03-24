# Pre-v7.5.5.2 Infrastructure — Config Separation, Deployment Validation, and Bug Fixes

_Full self-contained implementation instructions for the coding agent_
_Date: 2026-03-24_
_Prerequisite: v7.5.5.1 merged, multi-board infrastructure merged, BUG-060/061 fixes merged_

**This is a build-infrastructure step. No VERSION bump. No firmware behavior changes except BUG-062 (heap reporting).**

---

## 1. Repository & Setup

```
Clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
```

---

## 2. Required Reading (MUST complete before any changes)

Read these files **completely**:

1. `Docs/bugs-and-lessons-learned.md` — ALL entries, especially:
   - **BUG-062** — `/api/status` reports PSRAM-inclusive heap on S3. You will fix this.
   - **LESSON-OPS-056** — pre-reserved string for responses >10KB, never `beginResponseStream`. The status handler currently uses `beginResponseStream` — it is small enough to be acceptable, but you must NOT introduce a new large-response handler using it.
   - **LESSON-OPS-070** — all partition tables must have `ota_0` at `0x10000`. You will add a preflight check for this.
   - **LESSON-OPS-071** — lazy imports for optional dependencies. Already fixed for yaml; be aware of the pattern.
   - **LESSON-OPS-068** — use `lwip_*()` prefixed functions. Not directly relevant to this step but context for the codebase.

2. `scripts/render_sensor_config.py` — Read the `main()` function (starts ~line 1155) carefully. Understand:
   - `MANIFEST_PATH` (line 20) — currently hardcoded to `config/sensors.json`. You will make this overridable via `gateway.json`.
   - `load_manifest()` call at line 1181 — uses `MANIFEST_PATH`. After your change, it must use the path from `gateway_config['sensors_file']` when present.
   - `generate_board_yaml()` (starts ~line 579) — produces complete YAML for non-C3 boards. You do NOT modify this function.
   - `render_yaml_file()` — modifies C3 YAML in place via marker blocks. You do NOT modify this function.

3. `scripts/sensor_manifest_lib.py` — Read:
   - `validate_gateway_config()` (starts ~line 392) — you will add `sensors_file` validation here.
   - `load_gateway_config()` (starts ~line 375) — reads `config/gateway.json`. You do NOT modify this function.

4. `dashboard/sensor_history_multi.h` — Read ONLY the `handle_status_()` function (starts ~line 2696, ends ~line 2757). Understand:
   - Line 2702: `uint32_t free_heap = esp_get_free_heap_size();` — this includes PSRAM on S3 boards. You will change this to report both internal and total.
   - Line 2751: the final JSON field `"free_heap"` — backward compatibility requires keeping this field name but changing its value to internal-only.
   - The function uses `beginResponseStream` — this is acceptable because the status response is small (<2KB). Do NOT change it to pre-reserved string.

5. `scripts/preflight.sh` — Skim the structure. You will add a partition table validation check.

6. `Docs/aggregator-architecture-improvement-plan.md` — Read Phases A, B, and C (config separation, validate-device.sh, partition ota_0 check). These are what you are implementing.

7. `firmware/boards/esp32-s3-devkitc1-n16r8.yaml` — Read the board profile. Note that `logger:` and `baud_rate: 0` are commented out. You will uncomment them.

---

## 3. Current Status

- v7.5.5.1 merged and running on C3 satellite (192.168.120.189) and S3 aggregator (192.168.120.191)
- Multi-board infrastructure merged (PR #66 + follow-up fixes)
- BUG-060 (lazy yaml import) and BUG-061 (S3 partition table) fixed
- BUG-062 (heap reporting) documented but NOT fixed — you fix it in this step
- The S3 aggregator currently uses the C3 satellite's `config/sensors.json` — wrong sensors for the board. You fix this with config separation.
- main is green
- Current date: 2026-03-24

---

## 4. Pre-condition Checks

```bash
bash scripts/preflight.sh
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=3sensor npx playwright test --project=firefox
FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium
```

All must pass before proceeding.

---

## 5. Exact Scope

This step has 6 independent changes. Implement them in this order.

### 5a. Config separation — `sensors_file` in `gateway.json`

**What:** When `config/gateway.json` contains a `sensors_file` field, the generator reads the sensor manifest from that path instead of `config/sensors.json`.

**Why:** The S3 aggregator currently inherits the C3's ThermoPro sensors, which are physically near the C3, not the S3. The aggregator needs its own sensor config.

**Data flow — how `sensors_file` propagates:**

```
config/gateway.json (has sensors_file field)
    → load_gateway_config() reads it
    → validate_gateway_config() validates the path exists
    → main() in render_sensor_config.py uses the path instead of MANIFEST_PATH
    → load_manifest() reads sensors from the custom path
    → all downstream generation uses the correct sensors
```

**Changes to `scripts/sensor_manifest_lib.py`:**

In `validate_gateway_config()`, after the existing `manual_ip` validation block (~line 430), add validation for the optional `sensors_file` field:

```python
    # Validate optional sensors_file path
    sensors_file = config.get('sensors_file')
    if sensors_file is not None:
        if not isinstance(sensors_file, str):
            raise ManifestError(f"sensors_file must be a string path, got {type(sensors_file).__name__}")
        sensors_path = Path(__file__).resolve().parent.parent / sensors_file
        if not sensors_path.is_file():
            raise ManifestError(f"sensors_file not found: {sensors_file} (resolved to {sensors_path})")
```

**WHY validate path existence:** A typo in `sensors_file` would cause `load_manifest()` to raise a confusing `FileNotFoundError`. Validating early in the gateway config gives a clear error message pointing to the config file, not the manifest loader.

**Changes to `scripts/render_sensor_config.py`:**

In `main()`, after loading `gateway_config` (~line 1168) and before loading the manifest (~line 1181), add:

```python
    # Determine sensor manifest path — gateway config can override the default
    manifest_path = MANIFEST_PATH
    if gateway_config and 'sensors_file' in gateway_config:
        manifest_path = ROOT / gateway_config['sensors_file']
```

Then change line 1181 from:
```python
        sensors = load_manifest(MANIFEST_PATH, allow_empty=allow_empty)
```
to:
```python
        sensors = load_manifest(manifest_path, allow_empty=allow_empty)
```

**Create the aggregator sensor config file — `config/sensors-agg-s3-16m-1.json`:**

```json
{
  "schema_version": 2,
  "sensors": [
    {
      "id": "wan_ping",
      "name": "WAN Latency",
      "category": "network",
      "adapter": "icmp_ping",
      "source": { "target": "8.8.8.8" }
    }
  ]
}
```

**Update `config/gateway.example.json`** to include the `sensors_file` field:

```json
{
  "board": "esp32-s3-devkitc1-n16r8",
  "esphome_name": "agg-s3-16m-1",
  "friendly_name": "S3 Aggregator",
  "wifi_address": "192.168.120.191",
  "sensors_file": "config/sensors-agg-s3-16m-1.json"
}
```

**Do NOT modify `load_manifest()` or `load_gateway_config()`.** The manifest path override happens in `main()` only.

### 5b. Partition `ota_0` preflight check

**What:** Add a check to `scripts/preflight.sh` that verifies `ota_0` starts at `0x10000` in every partition table CSV.

**Why:** BUG-061 bricked the S3 because the partition table had `ota_0` at `0x20000`. This check prevents the same class of error from reaching production.

**Add to `scripts/preflight.sh`**, in the validation section (after the existing board profile checks, before the final summary):

```bash
# ── Partition table ota_0 offset validation ─────────────────────────
for csv in partitions/*.csv; do
  csv_name=$(basename "$csv" .csv)
  OTA0_LINE=$(grep "ota_0" "$csv" 2>/dev/null || true)
  if [[ -z "$OTA0_LINE" ]]; then
    echo "partition_ota0_${csv_name}: SKIP (no ota_0 entry)"
    continue
  fi
  OTA0_OFFSET=$(echo "$OTA0_LINE" | awk -F',' '{print $4}' | tr -d ' ')
  if [[ "$OTA0_OFFSET" != "0x10000" ]]; then
    echo "partition_ota0_${csv_name}: FAIL — ota_0 at $OTA0_OFFSET (must be 0x10000)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "partition_ota0_${csv_name}: PASS"
  fi
  TOTAL=$((TOTAL + 1))
done
```

**Verify** the variable names `FAIL_COUNT` and `TOTAL` match the existing counter variable names in `preflight.sh`. Read the script to find the correct names — they may be `fail_count` and `total` or similar. Use the exact names from the script.

### 5c. `scripts/validate-device.sh` — deployment validation script

**What:** Create a new script that validates a deployed device by checking connectivity, API status, manifest, dashboard, and heap stability.

**Why:** Currently deployment validation requires running ~12 manual `curl` commands. This script automates it for both satellite and aggregator roles.

**Create `scripts/validate-device.sh`:**

```bash
#!/usr/bin/env bash
# Validate a deployed ESP32 gateway device.
# Usage: bash scripts/validate-device.sh <device-ip> [satellite|aggregator]
set -euo pipefail

DEVICE_IP="${1:-}"
ROLE="${2:-satellite}"

if [[ -z "$DEVICE_IP" ]]; then
  echo "Usage: bash scripts/validate-device.sh <device-ip> [satellite|aggregator]"
  exit 1
fi

PASS=0
FAIL=0
TOTAL=0

check() {
  TOTAL=$((TOTAL + 1))
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name — expected '$expected', got '$(echo "$actual" | head -c 120)'"
    FAIL=$((FAIL + 1))
  fi
}

echo "Validating $ROLE at $DEVICE_IP..."
echo ""

# ── Connectivity ─────────────────────────────────────────────────
echo "→ Connectivity"
PING_RESULT=$(ping -c 1 -W 2 "$DEVICE_IP" 2>&1 || true)
check "ping" "1 received" "$PING_RESULT"

# ── API status ───────────────────────────────────────────────────
echo "→ API status"
STATUS=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/status" 2>&1 || echo "CURL_FAILED")
check "api/status responds" '"ok":true' "$STATUS"
check "version present" '"version":' "$STATUS"

if [[ "$STATUS" != "CURL_FAILED" ]]; then
  VERSION=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','?'))" 2>/dev/null || echo "?")
  HEAP=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('free_heap',0))" 2>/dev/null || echo "0")
  SENSORS=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sensor_count',0))" 2>/dev/null || echo "0")
  echo "  → version=$VERSION heap=$HEAP sensors=$SENSORS"
  HEAP_OK=$(python3 -c "print('true' if int('$HEAP') > 20000 else 'false')" 2>/dev/null || echo "false")
  check "heap > 20KB" "true" "$HEAP_OK"
fi

# ── Manifest ─────────────────────────────────────────────────────
echo "→ Manifest"
MANIFEST=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/manifest" 2>&1 || echo "CURL_FAILED")
check "api/manifest responds" '"schema_version":2' "$MANIFEST"

# ── Dashboard ────────────────────────────────────────────────────
echo "→ Dashboard"
DASH_CODE=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 5 "http://$DEVICE_IP/dashboard" 2>&1 || echo "000")
check "dashboard serves (200)" "200" "$DASH_CODE"

# ── Role-specific checks ────────────────────────────────────────
if [[ "$ROLE" == "aggregator" ]]; then
  echo "→ Aggregator endpoints"
  AGG=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/aggregator/gateways" 2>&1 || echo "CURL_FAILED")
  if [[ "$AGG" == "CURL_FAILED" ]]; then
    echo "  ⊘ aggregator/gateways: not yet implemented (expected pre-v7.5.5.2)"
  else
    check "aggregator/gateways responds" '"gateways"' "$AGG"
  fi
fi

if [[ "$ROLE" == "satellite" ]]; then
  echo "→ Satellite endpoints"
  LIVE=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/v2/live" 2>&1 || echo "CURL_FAILED")
  check "api/v2/live responds" '"devices"' "$LIVE"
fi

# ── Heap stability (10s window) ──────────────────────────────────
echo "→ Heap stability (10s)"
HEAP1=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/status" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('free_heap',0))" 2>/dev/null || echo "0")
sleep 10
HEAP2=$(curl -sf --max-time 5 "http://$DEVICE_IP/api/status" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('free_heap',0))" 2>/dev/null || echo "0")
DRIFT=$((HEAP1 - HEAP2))
DRIFT_ABS=${DRIFT#-}
DRIFT_OK=$(python3 -c "print('true' if int('$DRIFT_ABS') < 10000 else 'false')" 2>/dev/null || echo "false")
check "heap drift < 10KB" "true" "$DRIFT_OK"
echo "  → heap: $HEAP1 → $HEAP2 (drift: $DRIFT bytes)"

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  $PASS passed, $FAIL failed, $TOTAL total"
if [[ $FAIL -gt 0 ]]; then
  echo "  ✗ VALIDATION FAILED"
  exit 1
else
  echo "  ✓ ALL CHECKS PASSED"
fi
```

**Make executable:** `chmod +x scripts/validate-device.sh`

### 5d. BUG-062 fix — Report both internal and total heap in `/api/status`

**What:** Change `handle_status_()` in `dashboard/sensor_history_multi.h` to report `free_heap` as internal SRAM only (backward compatible), and add `free_heap_internal` and `free_heap_total` fields.

**Why:** On S3 boards with PSRAM, `esp_get_free_heap_size()` returns ~8.4 MB, which is not comparable to C3's ~70 KB. Monitoring tools and dashboards need the internal SRAM value for cross-board comparison.

**In `dashboard/sensor_history_multi.h`, function `handle_status_()`:**

Change the heap variable declaration at ~line 2702 from:

```cpp
    uint32_t free_heap = esp_get_free_heap_size();
```

to:

```cpp
    uint32_t free_heap_internal = esp_get_free_internal_heap_size();
    uint32_t free_heap_total = esp_get_free_heap_size();
```

Then change the final JSON output at ~line 2751 from:

```cpp
    snprintf(num, sizeof(num), "\"free_heap\":%u}", (unsigned) free_heap);
    resp->print(num);
```

to:

```cpp
    snprintf(num, sizeof(num), "\"free_heap\":%u,", (unsigned) free_heap_internal);
    resp->print(num);
    snprintf(num, sizeof(num), "\"free_heap_internal\":%u,", (unsigned) free_heap_internal);
    resp->print(num);
    snprintf(num, sizeof(num), "\"free_heap_total\":%u}", (unsigned) free_heap_total);
    resp->print(num);
```

**WHY `free_heap` = internal:** The existing `free_heap` field is consumed by the dashboard JS, monitoring scripts, and the `validate-device.sh` script. On C3, `esp_get_free_heap_size()` equals internal (no PSRAM). Changing `free_heap` to internal-only maintains the same value on C3 while giving S3 a comparable number. The `free_heap_total` field is additive for tools that want the PSRAM-inclusive value.

**Update the fixture file `tests/fixtures/api-status.json`** (if it exists) to include the new fields. If you modify the fixture, also update `generate-fixtures.js` to produce matching output.

**⚠️ CRITICAL: Do NOT change the response from `beginResponseStream` to pre-reserved string.** The status response is small (<2 KB). Changing the response method is out of scope and risky.

### 5e. S3 board profile — uncomment `logger.baud_rate`

**What:** Uncomment the `logger:` and `baud_rate: 0` lines in `firmware/boards/esp32-s3-devkitc1-n16r8.yaml`.

**Why:** The S3 DevKit uses USB-JTAG for serial. Without `baud_rate: 0`, the logger tries to write to a UART that conflicts with the USB-JTAG interface. The generator already reads `logger.baud_rate` from the profile and includes it in generated YAML — but the value is currently commented out, so nothing is generated.

**In `firmware/boards/esp32-s3-devkitc1-n16r8.yaml`, change:**

```yaml
#logger:
#  baud_rate: 0
```

to:

```yaml
logger:
  baud_rate: 0
```

### 5f. Housekeeping

**5f-i. Move bootstrap YAMLs to `firmware/bootstrap/`:**

The files `firmware/esp32-n16r8-gw-1.yaml` (63 lines) and `firmware/esp32-wroom-32d.yaml` (49 lines) are hand-authored minimal configs used for initial board flashing. They are NOT generator output — they lack includes, lambdas, sensors, persistence, and dashboard. A coding agent or contributor could mistake them for active firmware.

```bash
mkdir -p firmware/bootstrap
git mv firmware/esp32-n16r8-gw-1.yaml firmware/bootstrap/esp32-n16r8-gw-1.yaml
git mv firmware/esp32-wroom-32d.yaml firmware/bootstrap/esp32-wroom-32d.yaml
```

Create `firmware/bootstrap/README.md`:

```markdown
# Bootstrap YAML Files

These are minimal ESPHome configurations used for initial board flashing only.
They contain just enough to get a board online (WiFi, OTA, web server) but do NOT
include the full gateway firmware (dashboard, sensors, persistence, aggregator).

After initial flash, use `render_sensor_config.py` with `config/gateway.json` to
generate the full firmware YAML for each board.

These files should NOT be used for production deployment.
```

**5f-ii. Deduplicate `.gitignore`:**

The `.gitignore` currently has `config/gateway.json` 3 times and `config/aggregator.json` 2 times. Remove duplicates so each entry appears once.

**5f-iii. Add aggregator sensor config exclusion pattern to `.gitignore`:**

Add a pattern for per-deployment sensor configs:

```
# Per-deployment sensor configs (operator creates per-device)
config/sensors-*.json
```

This excludes files like `config/sensors-agg-s3-16m-1.json` from tracking. The `config/sensors.json` (default C3 config) is NOT matched by this pattern and remains tracked.

---

## 6. Do NOT (Explicit Scope Boundaries)

1. **Do NOT bump the VERSION.** This is infrastructure, not a firmware release.
2. **Do NOT modify `generate_board_yaml()` or `render_yaml_file()`.** YAML generation logic is not in scope.
3. **Do NOT modify `dashboard.js` or `dashboard.html`.** No dashboard behavior changes.
4. **Do NOT regenerate `dashboard.h`.** No dashboard changes.
5. **Do NOT modify any Playwright test files** or test fixtures (except `api-status.json` for the new heap fields).
6. **Do NOT modify `firmware/esp32-c3-multi-sensor.yaml`.** The C3 YAML is untouched.
7. **Do NOT modify any file in `prompts/`.** Prompt updates are handled separately.
8. **Do NOT create or modify `config/gateway.json` or `config/aggregator.json`.** These are per-deployment files in `.gitignore`. Only the `.example.json` files and the aggregator sensor config are tracked.
9. **Do NOT touch the aggregator polling task, `SatelliteCache`, or any `#if AGGREGATOR_ENABLED` code** except the `handle_status_()` heap fix.

---

## 7. Critical Rules (Non-Negotiable)

| # | Rule | Source |
|---|------|--------|
| 1 | `ota_0` must be at `0x10000` in all partition tables | LESSON-OPS-070 |
| 2 | Lazy imports for optional dependencies (yaml already fixed) | LESSON-OPS-071 |
| 3 | `free_heap` field must remain backward compatible (C3 value unchanged) | BUG-062 |
| 4 | No `beginResponseStream` for responses >10KB | LESSON-OPS-056 |
| 5 | All `::time(nullptr)` for display timestamps, `esp_timer_get_time()` for intervals | LESSON-OPS-069 |
| 6 | `NUM_SENSORS` must alias `NUM_ENV_SENSORS`, never `NUM_DEVICES` | BUG-045 |
| 7 | Mirror dashboard.js changes to dashboard.html | LESSON-OPS-043 (not applicable — no dashboard changes) |

---

## 8. Documentation Updates

**Update `Docs/configuring-sensors.md`:**

Add a subsection under the multi-board deployment section explaining `sensors_file`:

- When to use it (when the aggregator needs different sensors than the satellite)
- How to create a per-device sensor config
- The naming convention: `sensors-{gateway-name}.json`
- That `config/sensors.json` remains the default when `sensors_file` is absent

---

## 9. Review Checklist

Before creating the PR, verify each item:

```
[ ] python3 scripts/render_sensor_config.py --check passes (without gateway.json)
[ ] bash scripts/preflight.sh passes, including the new ota_0 check
[ ] FIXTURE_SET=3sensor npx playwright test --project=chromium — all pass
[ ] FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium — all pass
[ ] grep "ota_0" output in preflight shows PASS for all 3 partition CSVs
[ ] config/sensors-agg-s3-16m-1.json is valid JSON and loads without error
[ ] validate-device.sh is executable (chmod +x)
[ ] firmware/bootstrap/ contains the two moved YAML files + README
[ ] firmware/esp32-n16r8-gw-1.yaml and firmware/esp32-wroom-32d.yaml no longer exist in firmware/
[ ] .gitignore has no duplicate entries
[ ] S3 board profile has logger.baud_rate: 0 uncommented
[ ] No changes to dashboard.js, dashboard.html, dashboard.h, or any Playwright test file (except api-status fixture if needed)
```

---

## 10. Validation — Config Separation Specifically

After all changes, run this sequence to verify `sensors_file` works:

```bash
# 1. Default mode (no gateway.json) — must produce identical C3 output
rm -f config/gateway.json
python3 scripts/render_sensor_config.py --check
# Expected: PASS

# 2. Create a test gateway.json with sensors_file
cat > /tmp/test-gateway.json << 'EOF'
{
  "board": "esp32-s3-devkitc1-n16r8",
  "esphome_name": "agg-s3-16m-1",
  "friendly_name": "S3 Aggregator",
  "wifi_address": "192.168.120.191",
  "sensors_file": "config/sensors-agg-s3-16m-1.json"
}
EOF
cp /tmp/test-gateway.json config/gateway.json
python3 scripts/render_sensor_config.py --write
# Expected: generates YAML with only wan_ping sensor, no ThermoPro

# 3. Verify the generated YAML has no ThermoPro blocks
grep -c "thermopro" firmware/esp32-s3-devkitc1-n16r8-gw.yaml || echo "0 thermopro references — correct"
# Expected: 0

# 4. Verify the generated YAML has ping adapter
grep "PING_DEVICE_INDEX" firmware/esp32-s3-devkitc1-n16r8-gw.yaml
# Expected: present

# 5. Clean up — restore default mode
rm config/gateway.json
python3 scripts/render_sensor_config.py --write
```

---

## 11. Device Testing (Human — post-merge)

```bash
# 1. Validate C3 satellite
bash scripts/validate-device.sh 192.168.120.189 satellite
# Expected: ALL CHECKS PASSED

# 2. Validate S3 aggregator
bash scripts/validate-device.sh 192.168.120.191 aggregator
# Expected: ALL CHECKS PASSED (aggregator/gateways may show "not yet implemented")

# 3. Verify BUG-062 fix on S3 (after reflash with new firmware)
curl -s http://192.168.120.191/api/status | python3 -m json.tool | grep heap
# Expected:
#   "free_heap": <internal SRAM, ~30-50KB>,
#   "free_heap_internal": <same as free_heap>,
#   "free_heap_total": <~8MB, includes PSRAM>

# 4. Verify BUG-062 fix on C3
curl -s http://192.168.120.189/api/status | python3 -m json.tool | grep heap
# Expected:
#   "free_heap": <~60-70KB>,
#   "free_heap_internal": <same as free_heap>,
#   "free_heap_total": <same as free_heap, C3 has no PSRAM>

# 5. Verify config separation (after creating gateway.json on the S3)
# On the ESPHome host:
cat > config/gateway.json << 'EOF'
{
  "board": "esp32-s3-devkitc1-n16r8",
  "esphome_name": "agg-s3-16m-1",
  "friendly_name": "S3 Aggregator",
  "wifi_address": "192.168.120.191",
  "sensors_file": "config/sensors-agg-s3-16m-1.json"
}
EOF
python3 scripts/render_sensor_config.py --write
esphome compile firmware/esp32-s3-devkitc1-n16r8-gw.yaml
esphome run firmware/esp32-s3-devkitc1-n16r8-gw.yaml --device 192.168.120.191
# Wait 30s for boot
curl -s http://192.168.120.191/api/manifest | python3 -c "import sys,json; m=json.load(sys.stdin); print(f'Sensors: {m.get(\"sensor_count\", \"?\")}'); [print(f'  - {s[\"id\"]} ({s[\"category\"]})') for s in m.get('sensors',[])]"
# Expected: Sensors: 1, with wan_ping (network) only — no ThermoPro
```

---

## 12. Commit Message

```
infra: config separation, validate-device.sh, ota_0 preflight, BUG-062 heap fix

- sensors_file in gateway.json overrides config/sensors.json per device
- scripts/validate-device.sh for automated deployment validation
- Partition ota_0 offset check in preflight.sh
- BUG-062: /api/status reports free_heap_internal and free_heap_total separately
- S3 board profile: logger.baud_rate: 0 uncommented
- Bootstrap YAMLs moved to firmware/bootstrap/
- .gitignore cleanup (dedup, sensors-*.json pattern)
```

---

## 13. Session Log

Create `Docs/session-log-<DATE>-pre-v7552-infrastructure.md` with:
- List of all changes made
- Validation results (preflight, Playwright, config separation test)
- Any issues encountered

---

## 14. Instruction Compliance Output

In the PR description, include a table mapping each instruction section to the code that implements it:

| Instruction | Implementation | File(s) |
|-------------|---------------|---------|
| 5a: sensors_file | `validate_gateway_config()` + `main()` path override | `sensor_manifest_lib.py`, `render_sensor_config.py` |
| 5b: ota_0 preflight | Partition CSV loop | `preflight.sh` |
| 5c: validate-device.sh | New script | `scripts/validate-device.sh` |
| 5d: BUG-062 | `handle_status_()` heap fields | `sensor_history_multi.h` |
| 5e: S3 baud_rate | Uncomment logger block | `esp32-s3-devkitc1-n16r8.yaml` |
| 5f: Housekeeping | git mv, .gitignore, README | Multiple |
