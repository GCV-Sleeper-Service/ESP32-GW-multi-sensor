# Issue #165 — Code Optimization (Memory-Focused, C3 Satellite)

**Labels:** `optimization` `memory` `esp32-c3` `tech-debt`  
**Milestone:** v7.7.x

---

## Scope

"Optimization" in this issue means **SRAM reduction** specifically on the ESP32-C3
satellite build (`AGGREGATOR_ENABLED=0`). The C3 has 400 KB SRAM, no PSRAM, and
currently boots with ~55 KB free internal heap — a regression of >20 KB from the
>75 KB baseline (tracked in #164).

CPU / speed optimization is **not** in scope. The bottleneck is memory pressure, not compute.

The goal is to identify and execute specific code changes that recover heap, reduce
static footprint, and eliminate dead code — without changing firmware behaviour,
violating fragment boundary rules, or touching the assembled `dashboard/sensor_history_multi.h`.

---

## Relationship to #164

Issue #164 defines the investigation, measurement protocol, and acceptance criteria.
**Complete #164 Steps 1–7 (on-device heap measurements and stack watermarks) before
executing any changes here.** This issue is the "execution" complement.

**Recommended order:**
1. Complete #164 Steps 1–7 on-device measurements.
2. Execute OPT-02 and OPT-05 immediately (no gate required).
3. Execute OPT-04 with dashboard stability validation.
4. Execute OPT-03 after Step 7 watermark confirms safety.
5. Execute OPT-01 after Step 6 watermark confirms headroom.
6. Re-run #164 measurements after each batch. Close both issues when acceptance criteria met.

---

## Specific Optimization Opportunities

### OPT-01 — Right-size httpd task stack
**Priority:** 1 (highest single impact)  
**Expected gain:** 2–6 KB depending on watermark  
**Risk:** HIGH — requires on-device FreeRTOS watermark measurement before any reduction  
**Gate:** #164 Step 6 watermark result

**Current state:**
`firmware/local_components/web_server_idf/web_server_idf.cpp` — `config.stack_size = 16384`.
Required by BUG-075 to fix stack overflows on POST handlers. Previous 4 KB value caused
100%-reproducible `StoreProhibited` panics.

**Optimization:**
After watermark measurement (Step 6 of #164), apply the following decision:

| Watermark headroom | New value | Savings |
|---|---|---|
| ≥ 6 KB | 10,240 B | **6 KB** |
| ≥ 4 KB | 12,288 B | **4 KB** |
| ≥ 2 KB | 14,336 B | **2 KB** |
| < 2 KB | No change | 0 |

**Hard rule: never set below measured_peak + 2,048 B safety margin.**  
Also update `scripts/patch-esphome-httpd-stack.sh` to apply the new value when re-run after an ESPHome upgrade.

**File:** `firmware/local_components/web_server_idf/web_server_idf.cpp`

---

### OPT-02 — Disable `history_enabled` for NAS system metrics on C3
**Priority:** 2  
**Expected gain:** ~2,328 B static SRAM (freed at link time)  
**Risk:** LOW — no NVS schema change; only removes unused RAM ring buffers  
**Gate:** None — safe to ship immediately

**Current state (`firmware/core/data-model.h:303–308`):**
```cpp
static const MetricDef metrics_system[] = {
  {"cpu_pct",    "CPU Usage",  "%", 0, true},   // allocates entity_hbuf_nas01_cpu_pct (776 B)
  {"ram_pct",    "RAM Usage",  "%", 0, true},   // allocates entity_hbuf_nas01_ram_pct (776 B)
  {"disk_pct",   "Disk Usage", "%", 0, true},   // allocates entity_hbuf_nas01_disk_pct (776 B)
  {"uptime_hrs", "Uptime",     "h", 3, false}
};
```

**Change:**
```cpp
static const MetricDef metrics_system[] = {
  {"cpu_pct",    "CPU Usage",  "%", 0, false},  // saves 776 B static SRAM
  {"ram_pct",    "RAM Usage",  "%", 0, false},  // saves 776 B static SRAM
  {"disk_pct",   "Disk Usage", "%", 0, false},  // saves 776 B static SRAM
  {"uptime_hrs", "Uptime",     "h", 3, false}
};
```

Also delete the now-unused static globals at `data-model.h:318–320`:
```cpp
// DELETE these three lines:
static HistoryBuffer entity_hbuf_nas01_cpu_pct;
static HistoryBuffer entity_hbuf_nas01_ram_pct;
static HistoryBuffer entity_hbuf_nas01_disk_pct;
```

And update `devices[4]` metric_states at `data-model.h:390–393` to set `history = nullptr`
for metrics 0–2 (replace `&entity_hbuf_nas01_cpu_pct`, `..._ram_pct`, `..._disk_pct` with `nullptr`).

**Impact:** `GET /api/v2/history/nas01/{cpu_pct,ram_pct,disk_pct}` returns 404.
NAS health history charts will show no data. NAS live values and 15-minute averaging
pipeline are completely unaffected.

**Files to edit** (fragment sources only — do not edit assembled file):
- `firmware/core/data-model.h:303–308` (MetricDef flags)
- `firmware/core/data-model.h:318–320` (static HistoryBuffer globals — delete)
- `firmware/core/data-model.h:390–393` (devices[4] metric_states history pointers)

---

### OPT-03 — Reduce `ping_adapter` task stack
**Priority:** 3  
**Expected gain:** ~2,048 B permanent task stack  
**Risk:** MEDIUM — requires watermark confirmation  
**Gate:** #164 Step 7 watermark result

**Current state (`firmware/core/ping-adapter.h:13`):**
```cpp
xTaskCreate(ping_task_, "ping_adapter", 4096, this, tskIDLE_PRIORITY + 1, nullptr);
```

The deepest frame in `ping_task_()` uses:
- `wifi_ap_record_t ap_info` (~40 B)
- `addrinfo hints`, `addrinfo* res` (~64 B stack)
- `esp_ping_config_t cfg` (~40 B), `esp_ping_callbacks_t cbs` (~24 B)
- Semaphore take + arithmetic

Estimated stack usage: ~300–500 B. A 2,048 B stack should be sufficient.
**Only reduce if Step 7 watermark shows ≥ 512 B headroom.**

**Change after gate:**
```cpp
xTaskCreate(ping_task_, "ping_adapter", 2048, this, tskIDLE_PRIORITY + 1, nullptr);
```

**File:** `firmware/core/ping-adapter.h:13`

---

### OPT-04 — Reduce `CONFIG_LWIP_MAX_SOCKETS` 18 → 15
**Priority:** 4  
**Expected gain:** ~1,800–2,400 B (~3 sockets × ~600–800 B/socket)  
**Risk:** MEDIUM — validate with real-device SSE + polling stability test  
**Gate:** Real-device validation per LESSON-OPS-051

**Current state (`firmware/esp32-c3-multi-sensor.yaml:113`):**
```yaml
CONFIG_LWIP_MAX_SOCKETS: "18"
```
YAML comment (lines 83–90) documents the allocation rationale: ~8 base + ~5 dashboard = 13 peak.
18 provides 5 sockets of headroom. 15 provides 2 sockets of headroom — acceptable margin.

**Change:**
```yaml
CONFIG_LWIP_MAX_SOCKETS: "15"
```

**Validation (mandatory per LESSON-OPS-051):** After OTA flash, open dashboard in SSE mode
from one tab AND polling mode from a second tab simultaneously. Monitor device logs for 5 minutes.
Zero `httpd_accept_conn: error in accept (23)` messages required.
**Never reduce below "13" under any circumstances.**

**File:** `firmware/esp32-c3-multi-sensor.yaml:113`

---

### OPT-05 — Logger level INFO → WARN
**Priority:** 5  
**Expected gain:** ~512–1,024 B (log ring buffer + format string area)  
**Risk:** NONE — can be reverted at any time for a debugging session  
**Gate:** None

**Current state (`firmware/esp32-c3-multi-sensor.yaml:116–119`):**
```yaml
logger:
  level: INFO
  logs:
    wifi: WARN
    api: WARN
```

**Change:**
```yaml
logger:
  level: WARN
  logs:
    wifi: ERROR
    api: ERROR
```

**File:** `firmware/esp32-c3-multi-sensor.yaml:116–119`

---

### OPT-06 — Delete dead `stream_snapshot_series_()` and `HistoryBuffer::stream_to()`
**Priority:** 6  
**Expected gain:** Negligible SRAM (~0); ~400–600 B flash reduction  
**Risk:** NONE  
**Gate:** Verify zero call sites first

**Verification:**
```bash
grep -rn "stream_snapshot_series_\|->stream_to(" firmware/
```
Both functions should return zero call sites (only definitions). If confirmed:

- Delete `firmware/core/nvs-persistence.h:381–411` (`stream_snapshot_series_()`)
- Delete `firmware/core/data-model.h:88–107` (`HistoryBuffer::stream_to()`)
- Delete the comment at `nvs-persistence.h:413–414` that references the now-deleted function

These functions were superseded by `append_snapshot_series_csv_()` and `append_csv_to()`
in the BUG-043 rev2 fix. Their presence creates confusion about which streaming path is current.

**Files:**
- `firmware/core/nvs-persistence.h:381–411`
- `firmware/core/data-model.h:88–107`

---

### OPT-07 — SensorEntity struct padding audit (defer)
**Priority:** 7 (defer unless OPT-01 through OPT-05 are insufficient)  
**Expected gain:** ~100–200 B  
**Risk:** LOW but invasive

`MAX_METRICS_PER_DEVICE = 4` (`data-model.h:147`) allocates 4 `MetricState` slots per device.
`wan_ping` uses only 2 metrics (2 unused slots × ~28 B ≈ 56 B). `nas01` uses 4 but 3 will
have `history = nullptr` after OPT-02. The `char temp_avg_str[32]`, `hum_avg_str[16]`,
`batt_str[16]` fields exist on all 5 devices including the 2 non-env ones (~128 B waste).
Total: ~184 B. Too small for a structural refactor now; document as v8 data model consideration.

---

### OPT-08 — Import session timeout (correctness, not size)
**Priority:** 8  
**Expected gain:** 0 direct; documents known ~8.9 KB leak on client disconnect  
**Risk:** LOW (documentation only)

During `POST /api/import/begin` (single mode), `import_snapshot_` (~228 B) and
`import_epoch_map_[1080]` (~8,640 B) are heap-allocated and held until `/finish`.
If the client disconnects without calling `/finish`, the ~8.9 KB remains allocated until
the next `/begin` call (which calls `cleanup_import_state_()` first — `web-handler.h:784`).

No code change needed. Add a code comment at `web-handler.h:779` (start of `handle_import_begin_()`)
documenting this behavior and the existing protection mechanism.

---

## Out of Scope

1. **Fragment boundary changes (Rule 62):** The 8-fragment split across `config.h`,
   `data-model.h`, `nvs-persistence.h`, `aggregator-runtime.h`, `web-handler.h`,
   `ping-adapter.h`, `deferred-management.h`, `registration.h` must not be reorganized.

2. **Direct edits to `dashboard/sensor_history_multi.h` (Rule 58):** This is a generated
   artifact. All changes must be made to the fragment files in `firmware/core/` and then
   assembled via `bash scripts/assemble-sensor-history.sh --write`.

3. **`SegmentSnapshot` or `HistoryMeta` binary layout changes:** On-NVS format is tied to
   magic/version constants. Any layout change requires a migration plan or partition erase.

4. **Changes to `PERSIST_SLOTS` (1080), `HISTORY_HOURS` (24), `HISTORY_INTERVAL_MINUTES` (15):**
   These affect NVS layout, user-visible retention, and pre-reserved response buffer sizes.

5. **Removing the httpd component override** (`firmware/local_components/web_server_idf/`):
   Required by BUG-075. The 4 KB stock httpd stack causes 100%-reproducible panics.

6. **Aggregator-side statics** (`SatelliteCache[]`, `s_fetch_tmp`, `s_proxy_tmp`): All inside
   `#if AGGREGATOR_ENABLED`. Zero-cost on C3 satellite. Do not touch.

7. **`beginResponseStream` reintroduction (Rule 8):** The pre-reserved `std::string` +
   `beginResponse(200, type, data.data(), size)` pattern in `handle_history_()` is mandatory.
   The BUG-043 rev2 fix exists precisely because `beginResponseStream` caused heap exhaustion
   at 16 KB→32 KB reallocation.

8. **Dashboard gzip size reduction:** `DASHBOARD_HTML_GZ[]` lives in flash, not SRAM.
   Reducing it saves flash and transfer time only, not C3 heap budget.

---

## Prioritized Action Summary

| # | Action | File(s) | Gain | Risk | Gate |
|---|---|---|---|---|---|
| OPT-01 | Measure httpd watermark → reduce if safe | `local_components/web_server_idf/web_server_idf.cpp` | 2–6 KB | HIGH | Step 6 watermark ≥ 2 KB headroom |
| OPT-02 | Disable NAS health history buffers | `firmware/core/data-model.h:303–320, 390–393` | **~2.3 KB static** | LOW | None — ship immediately |
| OPT-03 | Reduce ping_adapter stack after watermark | `firmware/core/ping-adapter.h:13` | **~2 KB** | MEDIUM | Step 7 watermark ≥ 512 B |
| OPT-04 | Reduce MAX_SOCKETS 18 → 15 | `firmware/esp32-c3-multi-sensor.yaml:113` | **~2–3 KB** | MEDIUM | Real-device stability test |
| OPT-05 | Logger INFO → WARN | `firmware/esp32-c3-multi-sensor.yaml:117` | **~1 KB** | NONE | None |
| OPT-06 | Delete dead stream functions | `nvs-persistence.h:381–411`, `data-model.h:88–107` | ~0 SRAM | NONE | grep confirms 0 call sites |
| OPT-07 | Struct padding audit (defer) | `data-model.h` | <300 B | LOW | Only if OPT-01–05 insufficient |
| OPT-08 | Import watchdog docs (comment only) | `web-handler.h:779` | 0 | LOW | None |

**Total plausible gain (OPT-02 through OPT-05, no gate):** ~7–9 KB → free heap ~62–64 KB at boot.  
**Total with OPT-01 at 6 KB reduction:** ~13–15 KB → free heap ~68–70 KB at boot.  
The **≥70 KB free internal heap at boot** acceptance criterion from #164 is achievable with all five optimizations.

---

## Acceptance Criteria

- [ ] All changes compile cleanly: `esphome compile firmware/esp32-c3-multi-sensor.yaml`
- [ ] Preflight passes without error: `bash scripts/preflight.sh`
- [ ] `free_heap_internal` at `/api/status` on fresh boot ≥ **65 KB** (OPT-02 through OPT-05 alone)
- [ ] `free_heap_internal` at `/api/status` on fresh boot ≥ **70 KB** (with OPT-01 reduction confirmed safe)
- [ ] Real-device dashboard session (SSE mode) stable for 5+ minutes post-flash
- [ ] No `httpd_accept_conn: error in accept` during 5-minute session with two concurrent browser tabs
- [ ] httpd task FreeRTOS watermark ≥ 2,048 B after full import sequence (confirms OPT-01 is safe)
- [ ] `ping_adapter` watermark ≥ 512 B headroom (confirms OPT-03 is safe)
- [ ] `grep -rn "stream_snapshot_series_\|->stream_to(" firmware/` returns zero results after OPT-06
- [ ] Issue #139 (history loading crash) no longer reproducible after #164 and #165 changes applied