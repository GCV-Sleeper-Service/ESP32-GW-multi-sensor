# Issue #165 — Code Optimization (Memory-Focused, C3 Satellite)

**Labels:** `optimization` `memory` `esp32-c3` `tech-debt`  
**Milestone:** v7.7.x

---

## Scope

"Optimization" in this issue means **SRAM reduction** specifically on the ESP32-C3
satellite build (`AGGREGATOR_ENABLED=0`). The C3 has 400 KB SRAM, no PSRAM, and
currently boots with ~55 KB free internal heap — a regression of >20 KB from the
>75 KB baseline (tracked in #164).

CPU / speed optimization is **not** in scope here. The C3 is single-core at
160 MHz and the bottleneck is memory pressure, not compute.

The goal of this issue is to identify and execute the specific code changes that
recover heap, reduce static footprint, and eliminate dead code from the satellite
build — without changing firmware behaviour or violating any fragment boundary rules.

---

## Relationship to #164

Issue #164 defines the investigation, measurement protocol, and target acceptance
criteria. **Read and complete #164's on-device measurement steps before executing
any changes here.** This issue is the "execution" complement to #164's
"investigation."

**Recommended order:**
1. Complete #164 Step 1–6 on-device heap measurements.
2. Execute optimizations from this issue in priority order.
3. Re-run #164 measurements after each batch to confirm gains.
4. Close both issues together when #164 acceptance criteria are met.

---

## Specific Optimization Opportunities

### OPT-01 — Right-size httpd task stack
**Priority:** 1 (highest impact)
**Expected gain:** 4–6 KB
**Risk:** HIGH — requires on-device watermark measurement before any reduction

**Current state:**
`firmware/local_components/web_server_idf/web_server_idf.cpp` — the patched
`httpd_start()` call sets `config.stack_size = 16384` (16 KB). This was
required by BUG-075 to fix stack overflows on management POST handlers. The
previous value of 4 KB caused 100%-reproducible `StoreProhibited` panics.

**Optimization:**
Before reducing, instrument the deepest httpd call path using FreeRTOS watermark:
```cpp
// Add temporarily to end of handle_import_begin_() in web-handler.h:
ESP_LOGI(TAG, "httpd hwm: %u bytes free",
         uxTaskGetStackHighWaterMark(NULL) * sizeof(StackType_t));
```
Run a full import sequence (begin → several /api/import/d/ → /finish) with
Basic auth from a real device. Also test `/api/reboot` and `/api/delete-data`.

Decision table:
| Measured watermark headroom | Safe reduction | New value | Savings |
|---|---|---|---|
| ≥ 6 KB | Yes | 10,240 B | 6 KB |
| ≥ 4 KB | Yes | 12,288 B | 4 KB |
| ≥ 2 KB | Yes | 14,336 B | 2 KB |
| < 2 KB | No reduction | 16,384 B (keep) | 0 |

**Hard rule: never reduce below measured_peak + 2,048 B safety margin.**

**File:** `firmware/local_components/web_server_idf/web_server_idf.cpp`

---

### OPT-02 — Disable `history_enabled` for NAS system metrics on C3 satellite
**Priority:** 2
**Expected gain:** ~2,328 B static SRAM (freed at link time)
**Risk:** LOW — no NVS schema change; only removes RAM ring buffers for non-env data

**Current state:**
`firmware/core/data-model.h` lines 303–308:
```cpp
static const MetricDef metrics_system[] = {
  {"cpu_pct",    "CPU Usage",  "%", 0, true},   // allocates entity_hbuf_nas01_cpu_pct
  {"ram_pct",    "RAM Usage",  "%", 0, true},   // allocates entity_hbuf_nas01_ram_pct
  {"disk_pct",   "Disk Usage", "%", 0, true},   // allocates entity_hbuf_nas01_disk_pct
  {"uptime_hrs", "Uptime",     "h", 3, false}
};
```
The three `true` entries cause 3 static `HistoryBuffer` globals at data-model.h
lines 318–320 = 3 × 776 B = **2,328 B** of permanent SRAM.

**Optimization:**
```cpp
static const MetricDef metrics_system[] = {
  {"cpu_pct",    "CPU Usage",  "%", 0, false},  // saves 776 B static SRAM
  {"ram_pct",    "RAM Usage",  "%", 0, false},  // saves 776 B static SRAM
  {"disk_pct",   "Disk Usage", "%", 0, false},  // saves 776 B static SRAM
  {"uptime_hrs", "Uptime",     "h", 3, false}
};
```
Also delete the now-unused globals at data-model.h lines 318–320:
```cpp
// DELETE these three lines:
static HistoryBuffer entity_hbuf_nas01_cpu_pct;
static HistoryBuffer entity_hbuf_nas01_ram_pct;
static HistoryBuffer entity_hbuf_nas01_disk_pct;
```
And update `devices[4]` metric_states entries (data-model.h ~lines 391–394) to
set `history = nullptr` for metrics 0–2.

**Impact:** `GET /api/v2/history/nas01/cpu_pct`, `/ram_pct`, `/disk_pct` will
return HTTP 404. NAS health history charts in the dashboard will show no data.
NAS live values and the 15-minute averaging pipeline are unaffected.

**Files:**
- `firmware/core/data-model.h` lines 303–308 (MetricDef flags)
- `firmware/core/data-model.h` lines 318–320 (static HistoryBuffer globals)
- `firmware/core/data-model.h` ~lines 391–394 (devices[4] metric_states history pointers)

---

### OPT-03 — Reduce `ping_adapter` task stack
**Priority:** 3
**Expected gain:** ~2,048 B (stack permanent allocation)
**Risk:** MEDIUM — requires on-device watermark confirmation

**Current state:**
`firmware/core/ping-adapter.h` line 13:
```cpp
xTaskCreate(ping_task_, "ping_adapter", 4096, this, tskIDLE_PRIORITY + 1, nullptr);
```
The `ping_task_` loop's deepest frame includes:
- `wifi_ap_record_t ap_info` (~40 B)
- DNS: `addrinfo hints`, `addrinfo* res` (~64 B)
- `esp_ping_config_t cfg` (~40 B), `esp_ping_callbacks_t cbs` (~24 B)
- Semaphore take + arithmetic

A 2,048 B stack should be sufficient but must be confirmed.

**Measurement:** Add temporarily to `ping_task_` before `vTaskDelay(60000)`:
```cpp
ESP_LOGI(TAG, "ping_adapter hwm: %u",
         uxTaskGetStackHighWaterMark(NULL) * sizeof(StackType_t));
```
Run at least 2 full ping cycles including the DNS-failure and all-pings-timeout
paths. Reduce to 2,048 only if watermark shows ≥512 B headroom.

**File:** `firmware/core/ping-adapter.h` line 13.

---

### OPT-04 — Reduce lwIP socket count from 18 to 15
**Priority:** 4
**Expected gain:** ~1,800–2,400 B (3 sockets × ~600–800 B/socket)
**Risk:** MEDIUM — validate dashboard stability after change

**Current state:**
`firmware/esp32-c3-multi-sensor.yaml` line 113: `CONFIG_LWIP_MAX_SOCKETS: "18"`.
The YAML comment (lines 83–90) documents the allocation rationale:
~8 base system sockets + ~5 dashboard sockets = 13 peak. 18 provides 5 sockets
of headroom.

**Proposed:** Reduce to "15". This retains 2 sockets of headroom above the
documented 13-socket peak while saving ~3 sockets × ~600–800 B.

**Validation required (LESSON-OPS-051):** After OTA flash, open dashboard in SSE
mode from one browser tab AND polling mode from a second tab simultaneously.
Monitor device logs for 5 minutes. Zero `httpd_accept_conn: error in accept`
messages required. Never reduce below "13" under any circumstances.

**File:** `firmware/esp32-c3-multi-sensor.yaml` line 113.

---

### OPT-05 — Logger level INFO → WARN on production C3 satellite
**Priority:** 5
**Expected gain:** ~512–1,024 B (log ring buffer + format string overhead)
**Risk:** NONE

**Current state:**
`firmware/esp32-c3-multi-sensor.yaml` lines 116–119:
```yaml
logger:
  level: INFO
  logs:
    wifi: WARN
    api: WARN
```

**Proposed:**
```yaml
logger:
  level: WARN
  logs:
    wifi: ERROR
    api: ERROR
```
Can be reverted to INFO at any time for a debugging session with a simple
re-flash. No firmware logic depends on log level.

**File:** `firmware/esp32-c3-multi-sensor.yaml` lines 116–119.

---

### OPT-06 — Delete dead `stream_snapshot_series_()` and `HistoryBuffer::stream_to()`
**Priority:** 6
**Expected gain:** Negligible SRAM; ~400–600 B flash (binary size reduction)
**Risk:** NONE

**Current state:**
`firmware/core/nvs-persistence.h` lines 381–411 defines `stream_snapshot_series_()`
which writes NVS segment CSV data to an `AsyncResponseStream*`. This function was
superseded by `append_snapshot_series_csv_()` (lines 417–447) as part of the
BUG-043 rev2 fix ("pre-reserved std::string instead of beginResponseStream"). It
is no longer called anywhere.

`firmware/core/data-model.h` lines 88–107 defines `HistoryBuffer::stream_to()`
which streams CSV to an `AsyncResponseStream*`. This was also superseded by
`HistoryBuffer::append_csv_to()` (lines 112–130) in the same fix. It is likely
no longer called.

**Verification before deleting:**
```bash
grep -rn "stream_snapshot_series_\|stream_to(" firmware/
```
If both functions return zero call sites, delete them. This removes dead code and
prevents future confusion about which streaming path is current.

**Files:**
- `firmware/core/nvs-persistence.h` lines 381–411 (`stream_snapshot_series_`)
- `firmware/core/data-model.h` lines 88–107 (`HistoryBuffer::stream_to`)

---

### OPT-07 — Audit SensorEntity struct padding and over-allocation (investigative)
**Priority:** 7 (defer unless other gains are insufficient)
**Expected gain:** ~100–300 B
**Risk:** LOW

**Current state:**
Each `SensorEntity` has `MetricState metric_states[MAX_METRICS_PER_DEVICE]`
where `MAX_METRICS_PER_DEVICE = 4` (data-model.h:147). The `wan_ping` device
uses only 2 metrics but allocates 4 `MetricState` slots (~28 B each = ~56 B waste).

`SensorEntity` also contains `char temp_avg_str[32]`, `char hum_avg_str[16]`, and
`char batt_str[16]` for all 5 devices including `wan_ping` and
`nas01`, which never call `compute_and_format()`. That is 64 B × 2 non-env devices =
128 B waste.

Total waste from both: ~184 B across the devices[] array. Too small to justify a
structural refactor at this time. Document as a v8 data model consideration.

**Files:** `firmware/core/data-model.h` lines 147, 183–190, 329–400.

---

### OPT-08 — Add import session watchdog to free heap on client disconnect (correctness)
**Priority:** 8 (correctness improvement, not a size optimization)
**Expected gain:** Recovers up to ~8.9 KB if a client disconnects
without calling /finish
**Risk:** LOW

**Current state:**
During `POST /api/import/begin` (single-sensor mode), the handler allocates:
- `import_snapshot_` = `new SegmentSnapshot()` ≈ 230 B (web-handler.h:806)
- `import_epoch_map_` = `new EpochSlotEntry[1080]` ≈ 6,480 B (web-handler.h:698)

These are held for the duration of the import session (potentially many minutes)
and freed only when `/api/import/finish` is called. If the client disconnects
before calling `/finish`, the heap remains allocated until the next `/begin` call
(which calls `cleanup_import_state_()` as its first action — web-handler.h:784).

**Proposed:** Document this as a known limitation. The existing pre-call to
`cleanup_import_state_()` in `/begin` is the only protection. A timeout-based
watchdog would require a background timer task which adds its own overhead.
Accept current behaviour; note in docs that abandoned import sessions occupy ~8.9 KB
until the next `/begin` call.

No code change required at this time. File as documentation-only update.

**Files:** `firmware/core/web-handler.h` lines 779–833 (handle_import_begin_ comment).

---

## Out of Scope

The following changes are explicitly **out of scope** for this issue:

1. **Fragment boundary changes (Rule 62).** The split across `config.h`,
   `data-model.h`, `nvs-persistence.h`, `aggregator-runtime.h`, `web-handler.h`,
   `ping-adapter.h`, `deferred-management.h`, `registration.h` must not be
   reorganized.

2. **`SegmentSnapshot` or `HistoryMeta` binary layout changes.** On-NVS format
   is tied to the magic/version constants. Any layout change requires a migration
   or partition erase.

3. **Changes to `PERSIST_SLOTS` (1080), `HISTORY_HOURS` (24), or
   `HISTORY_INTERVAL_MINUTES` (15).** These affect NVS layout, user-visible
   retention, and response sizes.

4. **Removing the httpd component override** (`firmware/local_components/web_server_idf/`).
   Required by BUG-075. The 4 KB stock httpd stack causes 100%-reproducible panics.
   Do not revert.

5. **Aggregator-side statics** (`SatelliteCache[]`, `s_fetch_tmp[8192]`,
   `s_proxy_tmp[32768]`). All inside `#if AGGREGATOR_ENABLED`. Zero-cost on the
   C3 satellite build. Do not touch here.

6. **`beginResponseStream` reintroduction (Rule 8).** The pre-reserved
   `std::string` + `beginResponse(200, type, data.data(), data.size())` pattern
   in `handle_history_()` and `handle_api_v2_history_()` is mandatory. The BUG-043
   rev2 fix exists precisely because `beginResponseStream` caused heap exhaustion
   at 16K→32K reallocation. Do not revert.

7. **Dashboard (`dashboard.h`) size changes.** The gzip-compressed dashboard at
   ~45 KB lives in flash (not SRAM). Reducing dashboard size is a separate
   concern and does not directly affect the C3 heap budget.

---

## Prioritized Action Summary

| # | Action | File(s) | Gain estimate | Risk | Gate |
|---|---|---|---|---|---|
| OPT-01 | Measure httpd stack watermark → reduce if safe | `web_server_idf.cpp` | 4–6 KB | HIGH | Device watermark ≥ 2 KB headroom required |
| OPT-02 | Disable NAS health history buffers | `data-model.h:303–308, 318–320` | ~2.3 KB static | LOW | None — safe to ship immediately |
| OPT-03 | Reduce ping_adapter stack after watermark | `ping-adapter.h:13` | ~2 KB | MEDIUM | Device watermark ≥ 512 B required |
| OPT-04 | Reduce MAX_SOCKETS 18 → 15 | `esp32-c3-multi-sensor.yaml:113` | ~2–3 KB | MEDIUM | Real-device SSE + polling stability test |
| OPT-05 | Logger level INFO → WARN | `esp32-c3-multi-sensor.yaml:116–119` | ~1 KB | NONE | None |
| OPT-06 | Delete dead stream_snapshot_series_ + stream_to | `nvs-persistence.h:381–411`, `data-model.h:88–107` | ~0 SRAM, ~500 B flash | NONE | grep confirms zero call sites |
| OPT-07 | Struct padding audit (defer) | `data-model.h` | <300 B | LOW | Only if OPT-01 to OPT-05 insufficient |
| OPT-08 | Import watchdog (docs only) | `web-handler.h` comment | 0 direct | LOW | Documentation update only |

**Total plausible SRAM gain from OPT-01 through OPT-05:** approximately **11–14 KB**,
which would restore free internal heap from ~55 KB to ~66–69 KB at boot.
With OPT-01 stack reduction confirmed safe, the **target of ≥70 KB free internal
heap at boot** (from #164 acceptance criteria) is achievable.

---

## Acceptance Criteria

- [ ] All changes compile cleanly: `esphome compile firmware/esp32-c3-multi-sensor.yaml`
- [ ] Preflight passes without error: `bash scripts/preflight.sh`
- [ ] `free_heap_internal` at `/api/status` on fresh boot ≥ **65 KB** (OPT-02 through OPT-05 alone, without OPT-01)
- [ ] `free_heap_internal` at `/api/status` on fresh boot ≥ **70 KB** (after OPT-01 stack reduction confirmed safe)
- [ ] Real-device dashboard session (SSE mode) stable for 5+ minutes post-flash
- [ ] No `httpd_accept_conn: error in accept` during 5-minute dashboard session with two concurrent browser tabs
- [ ] FreeRTOS stack watermark for httpd task ≥ 2,048 B headroom after full import sequence (confirms OPT-01 reduction is safe)
- [ ] FreeRTOS stack watermark for `ping_adapter` task ≥ 512 B headroom (confirms OPT-03 reduction is safe)
- [ ] `grep -rn "stream_snapshot_series_\|->stream_to(" firmware/` returns zero results after OPT-06
- [ ] Issue #139 (history loading crash) no longer reproducible after #164 and #165 changes are applied
