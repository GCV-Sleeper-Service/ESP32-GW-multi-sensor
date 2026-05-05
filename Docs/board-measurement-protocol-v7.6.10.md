# Board Measurement Protocol — v7.6.10

_Phase VX Step 2. Operator-driven — not an agent prompt._
_Purpose: Flash each board with project firmware, collect baseline telemetry, run stress tests, record results._
_Updated: 2026-05-05 — corrected IPs, added BUG-084 stress test guidance._

---

## Prerequisites

- v7.6.10.1 merged (board profiles and partition tables committed)
- All boards physically connected and responding to ping
- `esphome --version` shows 2026.4.1
- `bash scripts/patch-esphome-httpd-stack.sh --check` passes
- Stress test script updated with BUG-084 fixes (`--concurrent` parameter support)

---

## Board Fleet

| Board | board_id | IP | Serial | Role |
|---|---|---|---|---|
| ESP32-C3 SuperMini | esp32-c3-supermini | 192.168.120.189 | — | Satellite (existing) |
| ESP32-WROOM-32D | esp32-wroom-32d | 192.168.120.170 | — | Satellite (existing) |
| ESP32-S3-DevKitC1-N16R8 | esp32-s3-devkitc1-n16r8 | 192.168.120.191 | /dev/ttyACM0 | Aggregator (existing) |
| ESP32-S3 SuperMini | esp32-s3-supermini-4m | 192.168.120.173 | TBD | Satellite (new) |
| ESP32-C5-WROOM-1U | esp32-c5-wroom1u-8m | 192.168.120.180 | TBD | Satellite (new) |
| ESP32-C6 SuperMini | esp32-c6-supermini-4m | 192.168.120.184 | TBD | Satellite (new) |

---

## Stress Test Guidance (BUG-084)

8 concurrent HTTP connections crash non-PSRAM boards (C3, WROOM, C6) via heap exhaustion.
The stack is fine — the crash is a heap resource limit, not a stack overflow.

**Use the correct concurrency level per board:**

| Board | PSRAM | Recommended `--concurrent` |
|---|---|---|
| C3, WROOM, C6 | None | 4 (default) |
| S3 SuperMini | 2 MB | 4 (conservative — verify heap first) |
| S3 DevKitC, C5 | 8 MB | 8 |

```bash
# Non-PSRAM boards (default --concurrent=4)
bash scripts/stress-test-httpd-stack.sh 192.168.120.189

# PSRAM boards (can try 8)
bash scripts/stress-test-httpd-stack.sh 192.168.120.191 --concurrent=8
```

---

## Step-by-Step Protocol

### For each NEW board:

**1. Create test firmware YAML**

The new boards don't have gateway configs yet. Create a minimal but representative test YAML that uses the board profile's settings and includes the web server, debug sensors, and the local component override. Use the placeholder YAMLs (uploaded during board preparation) as a starting point, but ensure they reference:
- Correct `variant`, `board`, `flash_size` from the board profile
- Custom partition table via `partitions:` field
- `external_components` referencing `firmware/local_components`
- `web_server` with auth (for stress test compatibility)

Example for the C6:
```yaml
esphome:
  name: sat-c6-4m-184
  friendly_name: sat-c6-4m-184

esp32:
  variant: esp32c6
  board: esp32-c6-devkitm-1
  flash_size: 4MB
  framework:
    type: esp-idf
    sdkconfig_options:
      CONFIG_LWIP_MAX_SOCKETS: "15"

partitions:
  csvfile: partitions/esp32-c6-multi-partitions.csv

external_components:
  - source:
      type: local
      path: firmware/local_components
    components: [web_server_idf]

logger:
  level: INFO

api:

ota:
  - platform: esphome

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  ap:
    ssid: "Sat-C6-4M-184 Fallback"

captive_portal:

web_server:
  port: 80
  version: 3
  log: false
  auth:
    username: ESPadmin
    password: ESPpass100

debug:

sensor:
  - platform: debug
    free:
      name: "Free RAM"
      filters:
        - lambda: return x / 1024.0;
      unit_of_measurement: "KB"
    fragmentation:
      name: "Heap Fragmentation"
  - platform: uptime
    name: "Uptime"
```

For the S3 SuperMini, add the `psram:` block. For the C5, add `psram:` and `CONFIG_XTAL_FREQ_48: 'y'`.

**2. Compile and flash**

```bash
esphome compile <test-yaml>
esphome upload <test-yaml> --device=/dev/ttyACM1
```

Or via OTA if the board is already on the network:
```bash
esphome run <test-yaml> --device=<BOARD_IP>
```

**3. Wait 2 minutes for boot stabilisation**

**4. Collect baseline telemetry**

```bash
# Basic status (no auth required for web_server v3 sensor endpoints)
curl -s http://<BOARD_IP>/sensor/free_ram/state
curl -s http://<BOARD_IP>/sensor/heap_fragmentation/state
curl -s http://<BOARD_IP>/sensor/uptime/state

# If the board has the full firmware with /api/status/full:
curl -s -u ESPadmin:ESPpass100 http://<BOARD_IP>/api/status/full | jq '{
  version, httpd_stack_watermark_bytes, free_heap, min_free_heap,
  uptime_seconds, psram_size, flash_size
}'
```

Note: The test firmware won't have `/api/status/full` (that's the project's custom handler). Baseline measurements from the debug sensor are sufficient:
- Free RAM (from debug sensor)
- Heap fragmentation (from debug sensor)
- Free PSRAM (from debug sensor, if applicable)

**5. Run stress test**

```bash
# Non-PSRAM boards (C3, WROOM, C6) — use default concurrent=4
bash scripts/stress-test-httpd-stack.sh <BOARD_IP>

# PSRAM boards (S3, C5) — can use higher concurrency
bash scripts/stress-test-httpd-stack.sh <BOARD_IP> --concurrent=8
```

Note: The stress test requires the board to have `/api/status/full`. If running with minimal test firmware, the stress test will fail. In that case, record the debug sensor values as the baseline and note "stress test N/A — minimal firmware".

If the boards are later flashed with full project firmware (after provision.sh integration in Phase 7), re-run the stress test.

**6. Record results in `Docs/board-measurement-log-v7.6.10.md`**

---

### For each EXISTING board:

The v7.6.10.0 baselines are already captured (see measurement log). To refresh:

```bash
# C3
curl -s -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full | jq '{
  version, httpd_stack_watermark_bytes, free_heap, min_free_heap, uptime_seconds
}'
bash scripts/stress-test-httpd-stack.sh 192.168.120.189

# WROOM
curl -s -u ESPadmin:ESPpass100 http://192.168.120.170/api/status/full | jq '{
  version, httpd_stack_watermark_bytes, free_heap, min_free_heap, uptime_seconds
}'
bash scripts/stress-test-httpd-stack.sh 192.168.120.170

# S3
curl -s -u ESPadmin:ESPpass100 http://192.168.120.191/api/status/full | jq '{
  version, httpd_stack_watermark_bytes, free_heap, min_free_heap, uptime_seconds
}'
bash scripts/stress-test-httpd-stack.sh 192.168.120.191 --concurrent=8
```

---

## Measurement Notes

- **`free_heap` vs `min_free_heap`:** `free_heap` is the current value. `min_free_heap` is the lowest since boot — more useful for capacity planning.
- **PSRAM boards:** `free_heap` may include PSRAM on S3 boards. Check whether the value is unreasonably large (>300 KB on a 512 KB SRAM chip = PSRAM is included). Record both values and note "includes PSRAM" where applicable.
- **Binary sizes:** Record the build output's RAM and Flash percentages for each board.
- **C5 crystal warning:** If esptool shows "Detected crystal freq 0.58 MHz" during flash — this is cosmetic (esptool misdetection). It does not affect operation.
- **BUG-084:** If a board crashes during stress test, record the pre-stress watermark as the stack measurement and note "crashed during wave N (heap exhaustion — BUG-084)". The stack watermark at baseline is the relevant measurement for stack sizing.

---

_End of measurement protocol._
