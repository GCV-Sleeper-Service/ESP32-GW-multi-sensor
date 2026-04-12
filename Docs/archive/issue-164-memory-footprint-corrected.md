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
| `ping_adapter` RTOS task | **4,096 B** | ping-adapter.h:13 (guarded by `#ifdef PING_DEVICE_INDEX`) | Created at boot; always present on this config since `PING_DEVICE_INDEX` is defined |
| `hist_reboot` task | **2,048 B** | deferred-management.h:9 | **On-demand only** — spawned by POST /api/reboot; not permanent |
| `hist_delete` task | **8,192 B** | deferred-management.h:29 | **On-demand only** — spawned by POST /api/delete-data; not permanent |

**Aggregator tasks (`agg_poll`, `agg_reset_sats`, `agg_nvs_save`) are all guarded
by `#if AGGREGATOR_ENABLED` and are zero-cost on the C3 satellite build.**

### Runtime / Transient Heap (active during requests or operations)

| Operation | Peak allocation | Source |
|---|---|---|
| `restore_from_nvs()` at boot | `sizeof(SegmentSnapshot)` ≈ 230 B + `HistoryMeta` stack-local | nvs-persistence.h:481. One snapshot reused across all restored segments. Freed before handler returns. |
| `persist_hourly_segment()` (hourly, at :10) | `sizeof(SegmentSnapshot)` ≈ 230 B | nvs-persistence.h:555. Heap-allocated, freed after NVS write. |
| `GET /history/{id}/temp` or `/history/{id}/hum` **(legacy, NVS-unbounded)** | **Up to ~86 KB** (1080 segments × 4 points × ~20 B/line, pre-reserved `std::string`) | web-handler.h: `csv.reserve(est_bytes)` where `est_bytes = est_points * 20 + 128`; `est_points = PERSIST_SLOTS × PERSIST_POINTS_PER_SEGMENT + HISTORY_POINTS_PER_SERIES = 1080×4+96 = 4,416`. **Deterministic crash on C3 (~55 KB free) when SSE active.** Freed after `request->send()`. |
| `GET /api/v2/history/{device}/{metric}` **(RAM-bounded)** | **~2 KB max** (96 points × ~20 B/line + overhead) | Reads in-RAM `HistoryBuffer` only — never scans NVS. Bounded at compile time by `HISTORY_POINTS_PER_SERIES=96`. Safe on C3 at any NVS state. |
| `/api/import/begin` (single mode) | `sizeof(SegmentSnapshot)` ≈ 230 B + `EpochSlotEntry[1080]` ≈ **6,480 B** (`EpochSlotEntry` = uint32_t epoch + uint16_t slot = 6 B; 1080 × 6 = 6,480 B) | Epoch map + snapshot both heap-allocated; held until /finish, freed by `cleanup_import_state_()`. |
| TCP send/receive socket buffers (per open connection) | ~6 × ~1,460 B ≈ **~8.8 KB** (estimate for `CONFIG_LWIP_MAX_SOCKETS=18`) | lwIP per-socket buffers; configured to 18 sockets in YAML:113. |
| ESPHome API native connection (HA) | ~2–4 KB (estimate) | ESPHome API component |
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

The **>20 KB regression** from >75 KB to ~55 KB traces to four additive changes across phases:

| Phase | Change | Estimated heap cost |
|---|---|---|
| Pre-regression baseline | 3 env sensors only, 6 HistoryBuffers, httpd 4 KB stack | **Baseline >75 KB** |
| **v7.5.4.1 — `wan_ping` device** | Adds 2 × `HistoryBuffer` (1,552 B) + `ping_adapter` task stack (4,096 B) | **~5.6 KB** |
| **v7.5.6.1 — `nas01` system device** | Adds 3 × `HistoryBuffer` (2,328 B) | **~2.3 KB** |
| **v7.6.0.0 — httpd stack 4 KB → 16 KB** (BUG-075 fix, mandatory) | Permanent task stack increase | **+12,288 B** |
| **v7.5.3.4 + subsequent — socket count 13 → 16 → 18** | lwIP per-socket overhead × ~5 additional sockets × ~700 B/socket | **~3.5 KB** |
| **Cumulative regression** | | **~23–24 KB** matches observed >20 KB regression |

The **single largest regression factor** is the httpd stack raise (+12 KB, v7.6.0.0).
This was mandatory to fix BUG-075 (100%-reproducible `StoreProhibited` panics on every
POST request). It **cannot be safely reverted** without re-introducing the crash.

The **second largest factor** is the addition of non-environmental devices (ping + system)
which added 5 new `HistoryBuffer` static globals (~5.9 KB total static SRAM) plus the
permanent `ping_adapter` task stack (4 KB).

**Phase X (dashboard refactor, v7.6.5.x):** Zero SRAM impact. `DASHBOARD_HTML_GZ[]` lives
in flash and is never copied to SRAM.

**Phase Y (fragment split):** Zero functional or SRAM changes.

---

## Proposed Investigation Steps (On-Device)

Add temporary `ESP_LOGI` instrumentation and measure `esp_get_free_internal_heap_size()`
at each stage. Use `curl -s http://<ip>/api/status | python3 -m json.tool` for
HTTP-accessible stages.

### Step 1 — Heap before `register_history_handler()`

Add a temporary log at the start of the `on_boot` lambda (priority -100) before
`register_history_handler()`:
```cpp
ESP_LOGI(TAG, "heap before register: internal=%u total=%u",
         esp_get_free_internal_heap_size(), esp_get_free_heap_size());
```

### Step 2 — Heap after boot, before any client connects

```bash
curl -s http://<ip>/api/status | python3 -m json.tool
# Record: free_heap_internal (≈55 KB expected)
```

### Step 3 — Heap around `restore_from_nvs()`

Add temporary logs in nvs-persistence.h at line ~488 (before restore loop) and
~551 (after loop + `delete snapshot`):
```cpp
ESP_LOGI(TAG, "heap before restore_from_nvs: %u", esp_get_free_internal_heap_size());
// ... existing loop ...
ESP_LOGI(TAG, "heap after restore_from_nvs: %u", esp_get_free_internal_heap_size());
```

### Step 4 — Heap after dashboard open + first history fetch completes

```bash
# Open dashboard in SSE mode, wait for first /history/office/temp to complete, then:
curl -s http://<ip>/api/status | python3 -m json.tool
# Record: free_heap_internal
```

### Step 5 — Heap during `GET /history/office/temp` with full NVS

Add temporary logs in `handle_history_()` in web-handler.h:
```cpp
ESP_LOGI(TAG, "heap before history reserve(%u): %u", (unsigned)est_bytes,
         esp_get_free_internal_heap_size());
// ... csv reserve + NVS loop + send ...
ESP_LOGI(TAG, "heap after history send: %u", esp_get_free_internal_heap_size());
```

### Step 6 — httpd task FreeRTOS stack watermark

Add to end of `handle_import_begin_()` in web-handler.h, before `request->send()`:
```cpp
ESP_LOGI(TAG, "httpd stack hwm: %u bytes free",
         uxTaskGetStackHighWaterMark(NULL) * sizeof(StackType_t));
```
Run a **full import sequence** (begin → several /api/import/d/ → /finish) with Basic
auth. Also exercise `/api/reboot` and `/api/delete-data` to ensure the deepest call
path is covered.

**This measurement is the gate for Priority 1 (httpd stack reduction).** Do not reduce
`config.stack_size` below `measured_peak + 2,048 B`.

### Step 7 — `ping_adapter` task FreeRTOS stack watermark

Add to `ping_task_()` in ping-adapter.h, before `vTaskDelay(60000)`:
```cpp
ESP_LOGI(TAG, "ping_adapter hwm: %u", uxTaskGetStackHighWaterMark(NULL) * sizeof(StackType_t));
```
Wait for **at least 2 complete ping cycles**, including a DNS-failure cycle and an
all-pings-timeout cycle, to exercise the deepest frame.

**This measurement is the gate for Priority 3 (ping_adapter stack reduction).** Only
reduce to 2,048 B if watermark shows ≥512 B headroom.

**Report all seven values as a table before proceeding with any fixes.**

---

## Proposed Fixes (Ranked by Effort vs. Expected Gain)

### Priority 1 — Right-size httpd task stack (medium effort, 2–6 KB gain, HIGH RISK)

**Requires Step 6 watermark measurement first. Never reduce below measured_peak + 2,048 B.**

| Watermark headroom | Safe reduction | New value | Savings |
|---|---|---|---|
| ≥ 6 KB | Yes | 10,240 B | **6 KB** |
| ≥ 4 KB | Yes | 12,288 B | **4 KB** |
| ≥ 2 KB | Yes | 14,336 B | **2 KB** |
| < 2 KB | No reduction | 16,384 B (keep) | 0 |

Also update `scripts/patch-esphome-httpd-stack.sh` to apply the new value when
re-run after an ESPHome upgrade.

**File:** `firmware/local_components/web_server_idf/web_server_idf.cpp`

---

### Priority 2 — Disable `history_enabled` for NAS system metrics (~2.3 KB, LOW RISK)

Set `history_enabled = false` for `cpu_pct`, `ram_pct`, `disk_pct` in
`metrics_system[]` at `data-model.h:303–308`.
Delete globals at `data-model.h:318–320`.
Update `devices[4]` metric_states at `data-model.h:~391–394` to set
`history = nullptr` for metrics 0–2.

**Gate:** None — safe to ship immediately.

**Impact:** `GET /api/v2/history/nas01/{cpu_pct,ram_pct,disk_pct}` returns 404.
NAS health history charts will show no data. NAS live values and the 15-minute
averaging pipeline are completely unaffected. No NVS schema change.

**File:** `firmware/core/data-model.h` lines 303–308, 318–320, ~391–394.

---

### Priority 3 — Reduce `ping_adapter` task stack (~2 KB, MEDIUM RISK)

**Requires Step 7 watermark. Reduce to 2,048 B only if watermark shows ≥512 B headroom.**

The `ping_task_` deepest frame includes DNS (`~64 B`), ping config (`~40 B`),
`wifi_ap_record_t` (~40 B), semaphore take, and basic arithmetic. A 2,048 B stack
should be sufficient but must be confirmed on-device.

```cpp
// firmware/core/ping-adapter.h line 13 — after gate:
xTaskCreate(ping_task_, "ping_adapter", 2048, this, tskIDLE_PRIORITY + 1, nullptr);
```

**File:** `firmware/core/ping-adapter.h` line 13.

---

### Priority 4 — Reduce `CONFIG_LWIP_MAX_SOCKETS` 18 → 15 (~2–3 KB, MEDIUM RISK)

**Current:** `CONFIG_LWIP_MAX_SOCKETS: "18"` (`firmware/esp32-c3-multi-sensor.yaml` line 113).
YAML comment (lines 83–90) documents ~8 base + ~5 dashboard = 13 socket peak.
18 provides 5 sockets of headroom; 15 provides 2 — acceptable margin.

**Validation (mandatory per LESSON-OPS-051):** After OTA flash, open dashboard in SSE
mode from one tab AND polling mode from a second tab simultaneously. Monitor device logs
for 5 minutes. Zero `httpd_accept_conn: error in accept (23)` messages required.
**Never reduce below "13" under any circumstances.**

**File:** `firmware/esp32-c3-multi-sensor.yaml` line 113.

---

### Priority 5 — Logger level INFO → WARN (~1 KB, NO RISK)

**Current:** `level: INFO` (`firmware/esp32-c3-multi-sensor.yaml` line 117).

**Proposed:**
```yaml
logger:
  level: WARN
  logs:
    wifi: ERROR
    api: ERROR
```

Can be reverted to INFO at any time for a debugging session with a simple re-flash.
No firmware logic depends on log level.

**File:** `firmware/esp32-c3-multi-sensor.yaml` lines 116–119.

---

## Acceptance Criteria

- [ ] `esp_get_free_internal_heap_size()` at boot (after `register_history_handler()`,
  before any HTTP request) ≥ **70 KB**
- [ ] `free_heap_internal` at `/api/status` after dashboard open + first history
  load (3 sensors, SSE active) ≥ **50 KB**
- [ ] No crash during `GET /history/{id}/temp` with NVS at ≥720 segments
- [ ] httpd task FreeRTOS stack watermark ≥ 2,048 B headroom after full import sequence
  with Basic auth (Step 6 measurement — gate for Priority 1)
- [ ] `ping_adapter` task FreeRTOS stack watermark ≥ 512 B headroom after 2 complete
  ping cycles including DNS-failure path (Step 7 measurement — gate for Priority 3)
- [ ] Both `free_heap` and `free_heap_internal` reported in `/api/status`
  (per BUG-062 fix requirement, Rule 24)
- [ ] Real-device dashboard session (SSE mode) stable for 5+ minutes post-flash
- [ ] No `httpd_accept_conn: error in accept` during 5-minute session with two
  concurrent browser tabs
- [ ] Issue #139 (history loading crash) no longer reproducible after #164 and
  #165 changes are applied

---

## Dependencies

- **Blocks:** Issue #139 (history loading crash) — that crash is a direct symptom
  of insufficient heap margin during `handle_history_()`. Recovery of ≥10 KB free
  heap at steady state should eliminate the allocation failure that causes #139.
- **Related to:** Issue #165 (code optimization) — complementary; #164 defines
  the targets and measurements, #165 defines the code changes that achieve them.
  **Recommended order:** complete Steps 1–7 on-device measurements first, then execute
  #165 changes in priority order, then re-run #164 measurements to confirm targets met.
  Close both issues together when acceptance criteria are met.
- **Depends on:** No new phases required. All changes are within existing files
  in `firmware/core/`, `firmware/local_components/`, and the YAML config.
  Do not touch assembled `dashboard/sensor_history_multi.h` directly — edit fragments
  in `firmware/core/`.

---

## Out of Scope

- Changes to `SegmentSnapshot` binary layout (would invalidate all NVS history)
- Changes to `PERSIST_SLOTS`, `HISTORY_HOURS`, or `HISTORY_INTERVAL_MINUTES`
- Adding PSRAM to the C3 (hardware decision)
- Aggregator-enabled builds — this issue is C3 satellite (`AGGREGATOR_ENABLED=0`) only
- Reverting the httpd component override — required by BUG-075, non-negotiable