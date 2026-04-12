# Issue #164 — Memory Footprint on Satellites (ESP32-C3)

**Labels:** `memory` `esp32-c3` `regression` `critical`  
**Milestone:** v7.7.x

---

## Current State

Free internal heap on fresh boot is approximately **~55 KB** (confirmed via
`/api/status` → `free_heap_internal`). This is a regression of **>20 KB** from
an earlier baseline of >75 KB measured before the multi-device sensor expansion
phases (pre-Phase D / pre-v7.5.x).

The C3 has **400 KB total SRAM, no PSRAM**. On the C3, `esp_get_free_heap_size()`
and `esp_get_free_internal_heap_size()` return the same value (Rule 24 applies:
always report both for cross-board portability, but they will be identical on C3).

The ~55 KB floor is dangerously close to the crash threshold. A single history
request with a full NVS partition (1080 segments × PERSIST_POINTS_PER_SEGMENT)
allocates a `SegmentSnapshot` (~230 bytes) plus a pre-reserved `std::string` CSV
buffer. With SSE open and TCP socket buffers active, this can push the minimum
instantaneous free heap below the crash point. Issue #139 (history loading crash)
is a direct downstream consequence of this margin.

---

## Heap Consumption Inventory (C3 Satellite Build)

All values are for the **C3 satellite** (`AGGREGATOR_ENABLED=0`).  
`sizeof(HistEntry) = 8` bytes (uint32_t epoch + float value).  
`HISTORY_POINTS_PER_SERIES = (24×60)/15 = 96` points per ring buffer.  
`PERSIST_POINTS_PER_SEGMENT = 4` (1h / 15min).  
`NUM_SENSORS = 3` (env sensors only, persisted).  
`NUM_DEVICES = 5` (3 env + 1 network + 1 system).  
`PERSIST_SLOTS = 45 × 24 = 1080`.

### Static / Global Allocations (link-time, always present)

| Consumer | Size | Notes |
|---|---|---|
| `entity_hbuf_office_temp` (`HistoryBuffer`) | `96 × 8 + 8 = 776 B` | Static global, data-model.h:310 |
| `entity_hbuf_office_hum` | 776 B | data-model.h:311 |
| `entity_hbuf_first_floor_temp` | 776 B | data-model.h:312 |
| `entity_hbuf_first_floor_hum` | 776 B | data-model.h:313 |
| `entity_hbuf_outside_temp` | 776 B | data-model.h:314 |
| `entity_hbuf_outside_hum` | 776 B | data-model.h:315 |
| `entity_hbuf_wan_ping_ping_ms` | 776 B | data-model.h:316 |
| `entity_hbuf_wan_ping_success_pct` | 776 B | data-model.h:317 |
| `entity_hbuf_nas01_cpu_pct` | 776 B | data-model.h:318 |
| `entity_hbuf_nas01_ram_pct` | 776 B | data-model.h:319 |
| `entity_hbuf_nas01_disk_pct` | 776 B | data-model.h:320 |
| **Total HistoryBuffers** | **~8,536 B (~8.3 KB)** | 11 history-enabled metrics |
| `devices[5]` (`SensorEntity` array) | `~5 × ~120 B ≈ 600 B` | Includes `temp_avg_str[32]`, `hum_avg_str[16]`, `batt_str[16]`, plus `MetricState[4]` per device |
| `g_history_restored_from_nvs` | 1 B | nvs-persistence.h:42 |
| `GATEWAY_MANIFEST_JSON` (string literal in gateway_manifest.h) | ~200–500 B (estimate) | Served from flash but pointer is in SRAM rodata |
| `DASHBOARD_HTML_GZ` / `DASHBOARD_HTML_GZ_LEN` | **~45 KB in flash** (not SRAM) | Served directly from flash via `beginResponse(200, type, ptr, len)`; does NOT occupy SRAM |

**Note:** `DASHBOARD_HTML_GZ[]` lives in flash (rodata), not SRAM. It does NOT
consume any heap. The httpd task maps it read-only during the `send()`.

### Task Stack Allocations (boot-time, permanent)

| Task | Stack | Source | Notes |
|---|---|---|---|
| httpd task (ESPHome web_server_idf) | **16,384 B** | local_components override (BUG-075 fix) | Was 4096 B before BUG-075; raised to 16 KB by patched component |
| ESPHome main loop task | ~8,192 B (estimate) | ESPHome core | Standard ESPHome task |
| BLE / esp32_ble_tracker task | ~4,096–8,192 B (estimate) | ESPHome BLE component | Scans for ThermoPro advertisements |
| WiFi/LwIP task (ESP-IDF) | ~3,072–4,096 B (estimate) | ESP-IDF WiFi | Static system task |
| `ping_adapter` RTOS task | **4,096 B** | ping-adapter.h:13 (guarded by `#ifdef PING_DEVICE_INDEX`) | Created at boot priority 600; always present on this config since `PING_DEVICE_INDEX` is defined |
| `hist_reboot` task | **2,048 B** | deferred-management.h:9 | **On-demand only** — spawned by POST /api/reboot; not permanent |
| `hist_delete` task | **8,192 B** | deferred-management.h:29 | **On-demand only** — spawned by POST /api/delete-data; not permanent |

**Aggregator tasks (`agg_poll`, `agg_reset_sats`, `agg_nvs_save`) are all guarded
by `#if AGGREGATOR_ENABLED` and are zero-cost on the C3 satellite build.**

### Runtime / Transient Heap (active during requests or operations)

| Operation | Peak allocation | Source |
|---|---|---|
| `restore_from_nvs()` at boot | `sizeof(SegmentSnapshot)` ≈ 230 B + `HistoryMeta` stack-local | nvs-persistence.h:481. One snapshot reused across all restored segments. Freed before handler registration. |
| `persist_hourly_segment()` (hourly, at :10) | `sizeof(SegmentSnapshot)` ≈ 230 B | nvs-persistence.h:555. Heap-allocated, freed after NVS write. |
| `/history/{id}/temp` or `/history/{id}/hum` | **Up to ~22 KB** (full 1080-segment history × 20 bytes/line) | web-handler.h: `csv.reserve(est_bytes)` pre-allocates; freed after `request->send()`. |
| `/api/v2/history/{device}/{metric}` | Up to ~22 KB same pattern | Same pre-reserved std::string pattern |
| `/api/import/begin` (single mode) | `sizeof(SegmentSnapshot)` ≈ 230 B + `EpochSlotEntry[1080]` ≈ 8,640 B | Epoch map + snapshot both heap-allocated; freed at /finish. |
| TCP send/receive socket buffers (per open connection) | ~6 × ~1,460 B ≈ **~8.8 KB** (estimate for `CONFIG_LWIP_MAX_SOCKETS=18`) | lwIP per-socket buffers; configured to 18 sockets in YAML:113 |
| ESPHome API native API connection (HA) | ~2–4 KB (estimate) | ESPHome API component |
| SNTP, mDNS | ~2 KB (estimate) | ESP-IDF system |

### ESPHome / Framework Overhead (estimates from BUG-043/BUG-062 logs)

| Consumer | Size estimate | Source |
|---|---|---|
| BLE scanner (esp32_ble_tracker) | ~8–12 KB | Known from BLE component; scan window active |
| WiFi driver static structures | ~10–15 KB | ESP-IDF WiFi driver |
| ESPHome component registry + sensors/text_sensors | ~4–8 KB | 30+ sensor/text_sensor entities in YAML |
| lwIP TCP/IP stack + socket pool (18 sockets) | ~12–16 KB | CONFIG_LWIP_MAX_SOCKETS=18; ~600–800 B/socket overhead |
| ESPHome logger (INFO level) | ~1–2 KB | Ring buffer + formatting |

---

## Regression Source Analysis

The **>20 KB regression** from >75 KB to ~55 KB appears to originate from
multiple additive changes across phases:

| Phase | Change | Estimated heap cost |
|---|---|---|
| Pre-regression baseline | 3 env sensors only, minimal device model | Baseline >75 KB |
| Addition of `wan_ping` device (PING_DEVICE_INDEX) | Adds 2 × `HistoryBuffer` (1,552 B) + `ping_adapter` task stack (4,096 B) | **~5.6 KB** |
| Addition of `nas01` device (system/external_push) | Adds 3 × `HistoryBuffer` (2,328 B) | **~2.3 KB** |
| httpd stack raise from 4 KB → 16 KB (BUG-075 fix) | Permanent task stack increase | **+12 KB** |
| Socket budget raise: 13 → 18 sockets (YAML:113) | lwIP per-socket overhead × 5 additional sockets | **~3–4 KB** |
| **Cumulative regression estimate** | | **~23–24 KB** matches observed >20 KB regression |

The **single largest regression factor** is the httpd stack raise (+12 KB), which
was necessary to fix BUG-075 (real crash on POST requests) but is a permanent
overhead on the C3. It is **not safe to revert** without re-introducing stack
overflows on management POST handlers.

The **second largest factor** is the addition of non-environmental devices
(ping + system) which added 5 new `HistoryBuffer` static globals (~5.9 KB total
static SRAM) plus the permanent `ping_adapter` task stack (4 KB).

---

## Proposed Investigation Steps (On-Device)

Take the following measurements on a live C3 satellite at specific boot stages.
Use `curl -s http://<ip>/api/status | python3 -m json.tool` for each.

### Step 1 — Heap before `register_history_handler()`
Not easily measurable over HTTP. Use ESPHome logger: add a temporary log at the
start of the `on_boot` lambda (priority -100) before `register_history_handler()`:
```cpp
ESP_LOGI(TAG, "heap before register: %u", esp_get_free_internal_heap_size());
```

### Step 2 — Heap after boot, before dashboard open
```bash
curl -s http://<ip>/api/status | python3 -m json.tool
```
Record `free_heap` and `free_heap_internal`.

### Step 3 — Heap around `restore_from_nvs()`
Add temporary logs in nvs-persistence.h at line ~488 (before restore loop) and
~551 (after loop + `delete snapshot`):
```cpp
ESP_LOGI(TAG, "heap before restore: %u", esp_get_free_internal_heap_size());
// ... restore loop ...
ESP_LOGI(TAG, "heap after restore: %u", esp_get_free_internal_heap_size());
```

### Step 4 — Heap after dashboard open + first history fetch
```bash
curl -s http://<ip>/api/status | python3 -m json.tool
```
Record after SSE connects and the first `/history/office/temp` completes.

### Step 5 — Heap during `/history/office/temp` with full NVS
Add temporary logs in `handle_history_()`: 
```cpp
ESP_LOGI(TAG, "heap before history build: %u", esp_get_free_internal_heap_size());
// ... csv build + send ...
ESP_LOGI(TAG, "heap after send: %u", esp_get_free_internal_heap_size());
```

### Step 6 — Heap around hourly persist cycle
Add temporary logs in `persist_hourly_segment()` at nvs-persistence.h:554 and :612:
```cpp
ESP_LOGI(TAG, "heap before persist: %u", esp_get_free_internal_heap_size());
// ... NVS write ...
ESP_LOGI(TAG, "heap after persist: %u", esp_get_free_internal_heap_size());
```

Report all six values as a table in investigation notes before proceeding with fixes.

---

## Proposed Fixes (Ranked by Effort vs. Expected Gain)

### Priority 1 — Right-size httpd stack (medium effort, ~4–6 KB gain, HIGH RISK)

**Current:** 16,384 B (`firmware/local_components/web_server_idf/web_server_idf.cpp`,
BUG-075 fix).

**Proposed:** Instrument the deepest call path through the httpd task to measure
actual peak stack depth using FreeRTOS watermark API:
```cpp
// Add to end of handle_import_begin_() — the deepest management handler:
ESP_LOGI(TAG, "httpd hwm: %u bytes free",
         uxTaskGetStackHighWaterMark(NULL) * sizeof(StackType_t));
```
Run a complete import sequence (begin → several /d/ → /finish) with Basic auth.
If watermark shows ≥4 KB headroom, reduce stack to 12,288 B (saves 4 KB).
If ≥6 KB headroom, consider 10,240 B (saves 6 KB).

**Hard rule: do not reduce below 10 KB without device-confirmed watermark data.**

**File:** `firmware/local_components/web_server_idf/web_server_idf.cpp`

---

### Priority 2 — Disable history_enabled for non-env metrics on C3 (low-medium effort, ~2.3 KB gain, LOW RISK)

**Current:** `firmware/core/data-model.h` lines 303–308. `metrics_system[]` has
`cpu_pct`, `ram_pct`, `disk_pct` all with `history_enabled = true`, producing 3
static `HistoryBuffer` globals (lines 318–320) = 3 × 776 B = **2,328 B** of
permanent SRAM.

**Proposed (Option A — conservative):**
```cpp
// firmware/core/data-model.h lines 303–308
static const MetricDef metrics_system[] = {
  {"cpu_pct",    "CPU Usage",  "%", 0, false},  // was true
  {"ram_pct",    "RAM Usage",  "%", 0, false},  // was true
  {"disk_pct",   "Disk Usage", "%", 0, false},  // was true
  {"uptime_hrs", "Uptime",     "h", 3, false}
};
```
Impact: `/api/v2/history/nas01/cpu_pct` etc. will return 404. NAS health charts
will show no history. The `wan_ping` history buffers are preserved (latency trends
are useful on the satellite dashboard).

**File:** `firmware/core/data-model.h` lines 303–308.

---

### Priority 3 — Reduce ping_adapter task stack (low effort, ~2 KB gain, MEDIUM RISK)

**Current:** 4,096 B (ping-adapter.h:13).

**Proposed:** The `ping_task_` deepest frame includes DNS (`~64 B`), ping config
(`~40 B`), semaphore take, and basic arithmetic. A 2,048 B stack should be
sufficient. Measure first:
```cpp
// End of ping_task_ loop body, before vTaskDelay(60000):
ESP_LOGI(TAG, "ping_adapter hwm: %u",
         uxTaskGetStackHighWaterMark(NULL) * sizeof(StackType_t));
```
Reduce to 2,048 only if measured watermark shows ≥512 B headroom.

**File:** `firmware/core/ping-adapter.h` line 13.

---

### Priority 4 — Reduce lwIP socket count 18 → 15 (low effort, ~2–3 KB gain, MEDIUM RISK)

**Current:** `CONFIG_LWIP_MAX_SOCKETS: "18"` (`firmware/esp32-c3-multi-sensor.yaml` line 113).

**Proposed:** Reduce to 15. The YAML comment documents the 13-socket peak. This
retains 2 sockets of headroom while saving ~3 KB (~600 B/socket × 3 sockets).

**Risk:** Never reduce below 13 without real-device dashboard validation per
LESSON-OPS-051. Reducing below 14 risks ENFILE crashes under multi-tab use.

**File:** `firmware/esp32-c3-multi-sensor.yaml` line 113.

---

### Priority 5 — Logger level INFO → WARN (trivial effort, ~1 KB gain, NO RISK)

**Current:** `level: INFO` (`firmware/esp32-c3-multi-sensor.yaml` line 117).

**Proposed:**
```yaml
logger:
  level: WARN
  logs:
    wifi: ERROR
    api: ERROR
```

**File:** `firmware/esp32-c3-multi-sensor.yaml` lines 116–119.

---

## Acceptance Criteria

- [ ] `esp_get_free_internal_heap_size()` at boot (after `register_history_handler()`,
  before any HTTP request) ≥ **70 KB**
- [ ] `free_heap_internal` at `/api/status` after dashboard open + first history
  load (3 sensors, SSE active) ≥ **50 KB**
- [ ] No crash during `/history/{id}/temp` with NVS at ≥720 segments
- [ ] httpd task stack watermark confirms ≥2,048 B headroom after deepest management
  POST (full import begin/data/finish sequence with auth)
- [ ] Both `free_heap` and `free_heap_internal` reported in `/api/status`
  (per BUG-062 fix requirement, Rule 24)
- [ ] Real-device dashboard session (SSE mode) stable for 5+ minutes post-flash

---

## Dependencies

- **Blocks:** Issue #139 (history loading crash) — that crash is a direct symptom
  of insufficient heap margin during `handle_history_()`. Recovery of ≥10 KB free
  heap at steady state should eliminate the allocation failure that causes #139.
- **Related to:** Issue #165 (code optimization) — complementary; #164 defines
  the targets and measurements, #165 defines the code changes that achieve them.
  **Recommended order:** complete #164 on-device measurements first, then execute
  #165 changes in priority order, then re-run #164 measurements to confirm targets met.
- **Depends on:** No new phases required. All changes are within existing files
  in `firmware/core/`, `firmware/local_components/`, and the YAML config.

---

## Out of Scope

- Changes to `SegmentSnapshot` binary layout (would invalidate all NVS history).
- Changes to `PERSIST_SLOTS`, `HISTORY_HOURS`, or `HISTORY_INTERVAL_MINUTES`.
- Adding PSRAM to the C3 (hardware decision).
- Aggregator-enabled builds — this issue is C3 satellite (`AGGREGATOR_ENABLED=0`) only.
- Reverting the httpd component override — required by BUG-075, non-negotiable.
