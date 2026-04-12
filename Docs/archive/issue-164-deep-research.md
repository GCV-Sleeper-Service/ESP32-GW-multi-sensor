# Issue #164 — Memory Footprint on Satellites (ESP32-C3)

**Labels:** `memory` `esp32-c3` `regression` `critical`  
**Milestone:** v7.7.x

---

## Current State

Free internal heap on fresh boot is approximately **~55 KB** (confirmed via
`/api/status` → `free_heap_internal`). This is a regression of **>20 KB** from
an earlier baseline of >75 KB measured before the multi-device sensor expansion
phases (pre-Phase 4 / pre-v7.5.x).

The C3 has **400 KB total SRAM, no PSRAM**. On the C3, `esp_get_free_heap_size()`
and `esp_get_free_internal_heap_size()` return the same value (Rule 24: always
report both for cross-board portability, but they are identical on C3).

The ~55 KB floor is dangerously close to the crash threshold. A single history
response with a full NVS partition (1080 segments × 4 points × 20 B/line =
~86 KB pre-reserved `std::string`) will fail to allocate when SSE is active and
TCP buffers are live. Issue #139 (history loading crash) is a direct downstream
consequence of this margin.

---

## Heap Consumption Inventory (C3 Satellite Build, `AGGREGATOR_ENABLED=0`)

**Constants:**
- `HISTORY_POINTS_PER_SERIES = 96`, `sizeof(HistoryBuffer) = 776 B`
- `PERSIST_SLOTS = 1080`, `sizeof(SegmentSnapshot) ≈ 228–236 B`
- `NUM_DEVICES = 5` (3 env + 1 network + 1 system), `NUM_SENSORS = 3`
- `CONFIG_LWIP_MAX_SOCKETS = 18` (`firmware/esp32-c3-multi-sensor.yaml:113`)
- httpd task stack = 16,384 B (patched `local_components/web_server_idf/web_server_idf.cpp`)

### Static / Global Allocations (link-time, always present)

| Consumer | Size | File:line | Pre-regression? |
|---|---|---|---|
| `entity_hbuf_office_temp/hum` (2× HistoryBuffer) | 1,552 B | data-model.h:310–311 | Yes |
| `entity_hbuf_first_floor_temp/hum` (2×) | 1,552 B | data-model.h:312–313 | Yes |
| `entity_hbuf_outside_temp/hum` (2×) | 1,552 B | data-model.h:314–315 | Yes |
| `entity_hbuf_wan_ping_ping_ms/success_pct` (2×) | 1,552 B | data-model.h:316–317 | **No — added v7.5.4.1** |
| `entity_hbuf_nas01_cpu_pct/ram_pct/disk_pct` (3×) | 2,328 B | data-model.h:318–320 | **No — added v7.5.6.1** |
| **Total HistoryBuffers** | **8,536 B** | 11 static globals | 4,656 B was baseline |
| `devices[5]` (SensorEntity array) | ~980 B | data-model.h:329–400 | ~588 B was baseline |
| `g_history_restored_from_nvs`, `s_delete_data_in_progress` | ~2 B | nvs-persistence.h:42, deferred-management.h:17 | Yes |
| `GATEWAY_MANIFEST_JSON[]` | ~800 B (flash rodata) | src/gateway_manifest.h | Yes |
| `DASHBOARD_HTML_GZ[37,002]` | **37,002 B flash only — 0 SRAM** | dashboard/dashboard.h | Yes (was ~45 KB pre-Phase X) |

### Task Stack Allocations (boot-time, permanent)

| Task | Stack | Source | Pre-regression? |
|---|---|---|---|
| httpd task (patched ESPHome) | **16,384 B** | `local_components/web_server_idf/web_server_idf.cpp` | **No — was 4,096 B before v7.6.0.0** |
| ESPHome main loop | ~8,192 B | ESPHome core | Yes |
| BLE / esp32_ble_tracker | ~4,096–8,192 B | ESPHome BLE | Yes |
| WiFi/LwIP tasks | ~5,120 B | ESP-IDF | Yes |
| `ping_adapter` RTOS task | **4,096 B** | ping-adapter.h:13 | **No — added v7.5.4.1** |
| esp_ping internal task (transient ~600ms/min) | 2,048 B | ping-adapter.h:89 | **No — added v7.5.4.1** |
| `hist_reboot` (on-demand, transient) | 2,048 B | deferred-management.h:9 | Yes |
| `hist_delete` (on-demand, transient) | 8,192 B | deferred-management.h:29 | Yes |

**Aggregator tasks** (`agg_poll` 10,240 B, `agg_reset_sats` 8,192 B, `agg_nvs_save` 8,192 B) are all inside `#if AGGREGATOR_ENABLED` — **zero cost on C3 satellite.**

### Runtime / Transient Heap (active during operations)

| Operation | Peak | Source |
|---|---|---|
| `restore_from_nvs()` at boot | ~228 B (one SegmentSnapshot, heap) | nvs-persistence.h — freed before handler returns |
| `persist_hourly_segment()` (hourly at :10) | ~228 B | nvs-persistence.h:554 — freed after NVS write |
| `/history/{id}/temp` full NVS (1080 segs) | **up to ~86 KB** (pre-reserved string) | web-handler.h:1374–1379 — freed after send |
| `/history/{id}/temp` half-full NVS (540 segs) | **~43 KB** | Same pattern |
| `/api/import/begin` (single mode) | ~8,868 B (EpochSlotEntry[1080] + SegmentSnapshot) | web-handler.h:698,806 — held until /finish |
| SSE `/events` open connection | ~2–4 KB | ESPHome SSE handler |
| TCP socket buffers (18 sockets configured) | ~600–800 B/socket active | lwIP |

### ESPHome / Framework Overhead (estimates from BUG-043/BUG-062 observations)

| Consumer | Estimate |
|---|---|
| BLE scanner (esp32_ble_tracker) | ~8–12 KB |
| WiFi driver static structures | ~10–15 KB |
| lwIP stack + 18-socket pool | ~14–18 KB |
| ESPHome component registry + 30+ sensors/text_sensors | ~4–8 KB |
| Logger (INFO level, ring buffer) | ~1–2 KB |

---

## Regression Source Analysis

The >20 KB regression traces to **four additive changes** across v7.5.x and v7.6.0.x:

| Phase | Change | Est. heap cost |
|---|---|---|
| Pre-regression baseline | 3 env sensors, 6 HistoryBuffers, httpd 4 KB stack | **Baseline >75 KB** |
| **v7.5.4.1 — wan_ping device** | +2 HistoryBuffers (1,552 B static) + `ping_adapter` task (4,096 B) | **~5.6 KB** |
| **v7.5.6.1 — nas01 system device** | +3 HistoryBuffers (2,328 B static) | **~2.3 KB** |
| **v7.6.0.0 — httpd stack 4 KB → 16 KB** (BUG-075 fix, mandatory) | Permanent task stack increase | **+12,288 B** |
| **v7.5.3.4 + subsequent — socket count 13 → 16 → 18** | ~5 additional sockets × ~700 B/socket | **~3.5 KB** |
| **Cumulative regression** | | **~23–24 KB** |

**Largest single factor: httpd stack raise (+12 KB, v7.6.0.0).** This was mandatory to fix BUG-075 (100%-reproducible `StoreProhibited` panics on every POST request). It **cannot be safely reverted** without re-introducing the crash.

**Phase X (dashboard refactor, v7.6.5.x):** Zero SRAM impact. `DASHBOARD_HTML_GZ[]` lives in flash and is never copied to SRAM. Dashboard gzip actually decreased from ~45 KB to ~36 KB in Phase X, but this saves only flash, not SRAM.

**Phase Y (fragment split):** Zero functional or SRAM changes.

---

## Proposed Investigation Steps (On-Device)

Add temporary `ESP_LOGI` instrumentation and measure `esp_get_free_internal_heap_size()` at each stage. Use `curl -s http://<ip>/api/status | python3 -m json.tool` for HTTP-accessible stages.

### Step 1 — Heap before `register_history_handler()` (add temporary log)
```cpp
// firmware/core/registration.h, top of register_history_handler(), before restore_from_nvs():
ESP_LOGI(TAG, "heap before register: internal=%u total=%u",
         esp_get_free_internal_heap_size(), esp_get_free_heap_size());
```

### Step 2 — Heap after boot, before any client connects
```bash
curl -s http://<ip>/api/status | python3 -m json.tool
# Record: free_heap_internal (≈55 KB expected)
```

### Step 3 — Heap around `restore_from_nvs()` (add temporary logs)
```cpp
// firmware/core/nvs-persistence.h, around line 488 (before loop) and ~551 (after delete snapshot):
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

### Step 5 — Heap during `/history/office/temp` with full NVS (add temporary logs)
```cpp
// firmware/core/web-handler.h, in handle_history_(), before/after csv build:
ESP_LOGI(TAG, "heap before history reserve(%u): %u", (unsigned)est_bytes,
         esp_get_free_internal_heap_size());
// ... csv reserve + NVS loop + send ...
ESP_LOGI(TAG, "heap after history send: %u", esp_get_free_internal_heap_size());
```

### Step 6 — httpd task stack watermark (add to deepest handler)
```cpp
// firmware/core/web-handler.h, end of handle_import_begin_() before request->send():
ESP_LOGI(TAG, "httpd stack hwm: %u bytes free",
         uxTaskGetStackHighWaterMark(NULL) * sizeof(StackType_t));
```
Run a full import sequence (begin → several /d/ → /finish) with Basic auth.

### Step 7 — ping_adapter stack watermark
```cpp
// firmware/core/ping-adapter.h, in ping_task_() before vTaskDelay(60000):
ESP_LOGI(TAG, "ping_adapter hwm: %u", uxTaskGetStackHighWaterMark(NULL) * sizeof(StackType_t));
```
Wait for 2 complete ping cycles including a DNS-failure cycle.

Report all seven values as a table before proceeding with fixes.

---

## Proposed Fixes (Ranked)

### Priority 1 — Right-size httpd task stack (HIGH IMPACT — 4–6 KB, HIGH RISK)
**Requires Step 6 watermark measurement first. Never reduce below measured_peak + 2,048 B.**

| Watermark headroom | Safe reduction | New value | Savings |
|---|---|---|---|
| ≥ 6 KB | Yes | 10,240 B | **6 KB** |
| ≥ 4 KB | Yes | 12,288 B | **4 KB** |
| ≥ 2 KB | Yes | 14,336 B | **2 KB** |
| < 2 KB | No reduction | 16,384 B (keep) | 0 |

**File:** `firmware/local_components/web_server_idf/web_server_idf.cpp`

### Priority 2 — Disable `history_enabled` for NAS system metrics (~2.3 KB static, LOW RISK)
Set `history_enabled = false` for all three entries in `metrics_system[]` at `data-model.h:303–308`.
Delete globals at `data-model.h:318–320`. Update `devices[4]` metric_states to `history = nullptr`.
**Impact:** `GET /api/v2/history/nas01/{cpu_pct,ram_pct,disk_pct}` returns 404. NAS live values unaffected. No NVS schema change.

### Priority 3 — Reduce `ping_adapter` stack (~2 KB, MEDIUM RISK)
**Requires Step 7 watermark. Reduce to 2,048 B only if watermark shows ≥512 B headroom.**  
**File:** `firmware/core/ping-adapter.h:13`

### Priority 4 — Reduce `CONFIG_LWIP_MAX_SOCKETS` 18 → 15 (~2–3 KB, MEDIUM RISK)
Retains 2 sockets above documented 13-socket peak. Never reduce below 13.  
**Validation:** Real-device SSE + polling stability for 5 minutes with two concurrent browser tabs.  
**File:** `firmware/esp32-c3-multi-sensor.yaml:113`

### Priority 5 — Logger level INFO → WARN (~1 KB, NO RISK)
**File:** `firmware/esp32-c3-multi-sensor.yaml:117`

**Total plausible gain (P2–P5 without watermark gating): ~7–9 KB → free heap ~62–64 KB.**  
**Total with P1 (if watermark supports 6 KB reduction): ~13–15 KB → free heap ~68–70 KB.**

---

## Acceptance Criteria

- [ ] `esp_get_free_internal_heap_size()` at boot (after `register_history_handler()`, before first HTTP request) ≥ **70 KB**
- [ ] `free_heap_internal` at `/api/status` after dashboard open + first history load (3 sensors, SSE active) ≥ **50 KB**
- [ ] No crash during `/history/{id}/temp` with NVS at ≥720 segments
- [ ] httpd task FreeRTOS stack watermark ≥ 2,048 B headroom after full import sequence with auth (Step 6 measurement)
- [ ] `ping_adapter` task watermark ≥ 512 B headroom (Step 7 measurement)
- [ ] Both `free_heap` and `free_heap_internal` reported in `/api/status` (Rule 24)
- [ ] Real-device dashboard session (SSE mode) stable for 5+ minutes post-flash
- [ ] No `httpd_accept_conn: error in accept` during 5-minute session with two concurrent browser tabs

---

## Dependencies

- **Blocks:** Issue #139 (history loading crash). Recovery of ≥10 KB free heap at steady state should eliminate the allocation failure in `handle_history_()` that causes #139.
- **Related:** Issue #165 (code optimization) — complementary. **Recommended order:** complete Steps 1–7 on-device measurements from this issue first, then execute #165 changes in priority order, then re-run measurements to confirm targets met. Close both issues together when acceptance criteria are met.
- **Depends on:** No new phases required. All changes are within existing files in `firmware/core/`, `firmware/local_components/`, and the YAML config. Do not touch assembled `dashboard/sensor_history_multi.h` directly — edit fragments in `firmware/core/`.

---

## Out of Scope

- Changes to `SegmentSnapshot`/`HistoryMeta` binary layout (invalidates all NVS history)
- Changes to `PERSIST_SLOTS`, `HISTORY_HOURS`, or `HISTORY_INTERVAL_MINUTES` (NVS layout + retention)
- Adding PSRAM to the C3 (hardware decision)
- Aggregator-enabled builds (this issue is C3 satellite `AGGREGATOR_ENABLED=0` only)
- Reverting the httpd component override — required by BUG-075, non-negotiable