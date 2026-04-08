# Phase Y Deep Research Brief — `sensor_history_multi.h` Decomposition

_Generated: 2026-04-08_
_Baseline: v7.6.5.8 on `main`_
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Purpose

This document is a structured research brief for the planning agent that will write the Phase Y refactor plan. It answers the eight research questions posed in the Phase Y brief specification, with specific evidence from the codebase at HEAD (v7.6.5.8).

**Scope reminder:** Phase Y is the structural split of `dashboard/sensor_history_multi.h` into modules. The following are out of scope and are not researched here: YAML slimming, new board templates, sensor/device addition/removal workflow, dashboard bug fixes, per-device persistence engine implementation (Phase 7), and documentation reorganization.

---

## R1. Module Boundary Verification

### Confirmed Line Ranges (v7.6.5.8 HEAD — 4325 lines total)

Landmark verification from direct file inspection:

| Landmark | Confirmed Line |
|---|---|
| `#pragma once` | 1 |
| `static const char *const TAG = "history";` | 96 |
| `// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>` | 375 |
| `// <<< SENSOR_MANIFEST:HEADER_END >>>` | 379 |
| `// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>` | 381 |
| `// <<< SENSOR_MANIFEST:ENTITY_END >>>` | 496 |
| `struct HistoryMeta {` | 556 |
| `static constexpr int NVS_SCAN_YIELD_INTERVAL = 2;` | 800 |
| `static bool restore_from_nvs() {` | 1004 |
| `static void persist_hourly_segment(...)` | 1109 |
| `static void reboot_task_(void *param)` | 1170 |
| `static volatile bool s_delete_data_in_progress = false;` | 1186 |
| `#ifdef PING_DEVICE_INDEX` (PingAdapter start) | 1220 |
| `#endif  // PING_DEVICE_INDEX` | 1369 |
| `#if AGGREGATOR_ENABLED` | 1388 |
| `struct SatelliteCache {` | 1409 |
| `static SemaphoreHandle_t s_cache_mutex = nullptr;` | 1479 |
| `#define AGG_LOCK()` | 1487 |
| `static bool fetch_to_buffer(...)` | 1511 |
| `static bool probe_satellite_manifest_(...)` | 1614 |
| `static int load_satellites_from_nvs_()` | 1707 |
| `static void aggregator_poll_task(void* arg)` | 1922 |
| `static volatile bool s_reset_satellites_in_progress` | 2157 |
| `static void start_aggregator_task()` | 2261 |
| `#endif  // AGGREGATOR_ENABLED` | 2272 |
| `class HistoryWebHandler : public AsyncWebHandler {` | 2279 |
| `bool canHandle(...)` | 2311 |
| `void handleRequest(...)` | 2365 |
| `void handle_dashboard_(...)` | 2687 |
| `void handle_manifest_(...)` | 2705 |
| `void handle_api_manifest_(...)` (inline) | 2722 |
| `void handle_api_v2_live_(...)` | 2724 |
| `void handle_api_v2_history_(...)` | 2749 |
| `void handle_api_ingest_(...)` | 2808 |
| `void handle_reboot_(...)` | 2881 |
| `void handle_delete_data_(...)` | 2890 |
| `void handle_import_begin_(...)` | 3057 |
| `void handle_import_data_(...)` | 3113 |
| `void handle_import_finish_(...)` | 3323 |
| `void handle_storage_stats_(...)` | 3400 |
| `void handle_status_(...)` | 3511 |
| `void handle_history_(...)` | 3581 |
| `void handle_aggregator_gateways_(...)` | 3709 |
| `void handle_aggregator_live_(...)` | 3801 |
| `void handle_aggregator_proxy_(...)` | 3834 |
| `void handle_add_satellite_(...)` | 3935 |
| `void handle_delete_satellite_(...)` | 4074 |
| `void handle_test_satellite_(...)` | 4158 |
| `void handle_reset_satellites_(...)` | 4255 |
| End of `HistoryWebHandler` class (`};`) | 4283 |
| `static void register_history_handler(...)` | 4290 |
| End of file | 4325 |

### Module Boundary Table

| Subsystem | Verified Range(s) | Contiguous? | Cross-references to other subsystems |
|---|---|---|---|
| Standard includes + compile-time config | 1–95 | YES | None (no refs outside) |
| `HistEntry` + `HistoryBuffer` class | 96–231 | YES | Used in ENTITY block (MetricState.history), NVS core (HistEntry in SegmentSnapshot), all handlers that read history |
| `MetricDef`, `MetricState` structs | 232–260 | YES | Used in `SensorEntity` (261-369) |
| `SensorEntity` struct | 261–369 | YES | Used in ENTITY block, NVS core, PingAdapter, all handlers via `devices[]` |
| **SENSOR_MANIFEST:HEADER** marker block | 375–379 | YES (5 lines) | Contains config-guide comments; no code symbols |
| **SENSOR_MANIFEST:ENTITY** marker block | 381–496 | YES (116 lines) | `devices[]`, `NUM_DEVICES`, `NUM_ENV_SENSORS`, `NUM_SENSORS`, `PING_DEVICE_INDEX`, `PING_TARGET`, all `entity_hbuf_*` statics; consumed by every other subsystem |
| NVS segment model (constants + structs) | 526–586 | YES | `HistoryMeta`, `SegmentSnapshot` used in all NVS helpers and handlers |
| NVS core helpers | 587–1002 | YES | `ensure_history_nvs_ready_`, `open_history_nvs_`, `load/save_history_meta_`, `clear_persisted_history_`, snapshot helpers — called from restore, persist, delete, import |
| `restore_from_nvs` | 1004–1107 | YES | Calls `open_history_nvs_`, `load_history_meta_`, `allocate_snapshot_`, `clear_runtime_histories_`, `append_snapshot_to_ram_` — deep coupling to NVS core |
| `persist_hourly_segment` | 1109–1168 | YES | Calls NVS core, accesses `devices[i]` via `build_segment_snapshot_` |
| Deferred management tasks (reboot, delete-data) | 1170–1203 | YES | `reboot_task_` + `schedule_reboot_`; `delete_data_task_` + `schedule_delete_data_`; called from handlers at 2881 and 2890 |
| **PingAdapter** | 1220–1369 | YES (guarded by `#ifdef PING_DEVICE_INDEX`) | Accesses `devices[PING_DEVICE_INDEX]` — cross-dep on ENTITY block |
| **Aggregator runtime** (#if AGGREGATOR_ENABLED) | 1388–2272 | YES as a single `#if` block | See sub-table below |
| ↳ Aggregator constants + structs + mutex + buffers | 1388–1501 | YES | `SatelliteCache`, `SatelliteNVSSnapshot`, `s_cache_mutex`, `AGG_LOCK`/`AGG_UNLOCK`, `s_fetch_tmp`, `s_proxy_tmp` — consumed by both aggregator islands |
| ↳ `fetch_to_buffer` | 1511–1612 | YES | Used by `aggregator_poll_task` (1922) and `handle_aggregator_proxy_` (3834), `handle_test_satellite_` (4158), `probe_satellite_manifest_` (1614) |
| ↳ `probe_satellite_manifest_` | 1614–1700 | YES | Uses `s_proxy_tmp`; called from `handle_test_satellite_` (4158), `handle_add_satellite_` (3935) |
| ↳ NVS satellite persistence | 1702–1920 | YES | `load/save_satellites_from/to_nvs_`, `save_single_satellite_to_nvs_`, `init_satellite_caches_`; called from poll task and handler management functions |
| ↳ `aggregator_poll_task` | 1922–2151 | YES | Uses `satellite_caches[]`, `s_cache_mutex`, `fetch_to_buffer`, `satellite_config_generation` |
| ↳ Deferred satellite tasks | 2153–2259 | YES | `reset_satellites_task_`, `schedule_reset_satellites_`, `save_satellites_nvs_task_`, `schedule_save_satellites_nvs_` — called from handlers |
| ↳ `start_aggregator_task` | 2261–2270 | YES | Called from YAML `on_boot` lambda |
| **HistoryWebHandler** (class) | 2279–4283 | YES (class boundary) | References nearly every top-level symbol |
| ↳ Route classification + canHandle + dispatch | 2279–2523 | YES | Calls every handler method |
| ↳ Private helpers (auth, import state, etc.) | 2525–2680 | YES | `authenticate_management_`, `base64_decode_`, `secure_equals_`, `add_common_headers_`, `send_json_error_`; called from all handlers |
| ↳ Core endpoint handlers | 2681–3708 | YES (contiguous inside class) | Calls NVS helpers, accesses `devices[]`, `s_delete_data_in_progress` |
| ↳ **Aggregator endpoint handlers** | 3709–4282 | YES (contiguous inside class) | Second island of aggregator subsystem; uses `satellite_caches[]`, `s_cache_mutex`, `s_proxy_tmp`, `fetch_to_buffer` |
| **Registration / orchestration** | 4285–4325 | YES | `register_history_handler`; calls `restore_from_nvs()`, instantiates `HistoryWebHandler` |

### Contiguity Classifications

**CONTIGUOUS (extractable as a single slice):**
- `HistEntry` + `HistoryBuffer` (96–231)
- `MetricDef` + `MetricState` + `SensorEntity` (232–369)
- SENSOR_MANIFEST marker blocks (375–496)
- NVS segment model + NVS core + restore + persist (526–1168) — large but contiguous
- Deferred management tasks (1170–1203)
- **PingAdapter** (1220–1369) — best first-extraction candidate
- Aggregator runtime core block (1388–2272)
- Registration/orchestration tail (4285–4325)

**SCATTERED (requires consolidation):**
- **Full aggregator subsystem**: top-level runtime block (1388–2272) + endpoint methods inside HistoryWebHandler (3709–4282) — two islands
- **Import engine**: state in HistoryWebHandler private members (2532–2543) + handlers (3057–3399) + NVS helpers called from there
- **Auth/management**: helpers in class (2639–2680) + management handlers (2881–3056) + all handlers that call `authenticate_management_`
- **Deferred task registry**: two clusters (1170–1203 and 2153–2259) separated by PingAdapter and aggregator runtime

### Open Questions — R1
- Q1: Should `handle_api_manifest_` (inline one-liner at 2722) be co-located with the manifest-serving logic in the data-model module or remain in the web handler module? It is currently inlined into handleRequest's GET path.
- Q2: `probe_satellite_manifest_` (1614–1700) uses `s_proxy_tmp` (a web-handler-context-only buffer). Should it live in the aggregator runtime module or the aggregator web-handler module? The current comment says "MUST be called from web handler context only".
- Q3: The `handle_options_` handler (2681–2685) is three lines. Depending on split strategy, it could live in a core handler module or remain inline. No functional consequence either way.

---

## R2. Dependency Graph

### Symbol-Level Cross-Subsystem Dependencies

| Symbol | Defined in | Consumed in subsystems | Type |
|---|---|---|---|
| `devices[]` | ENTITY block (381–496) | NVS core (`build_segment_snapshot_`, `append_snapshot_to_ram_`), PingAdapter (1288–1362), all web handlers | `static SensorEntity[NUM_DEVICES]` |
| `NUM_DEVICES` | ENTITY block (417) | `clear_runtime_histories_` (613), `register_history_handler` (4314), handlers iterating devices | `constexpr int` |
| `NUM_SENSORS` | ENTITY block (419) | `SegmentSnapshot` dimensions (580–586), all NVS snapshot helpers iterating sensors | `constexpr int` |
| `NUM_ENV_SENSORS` | ENTITY block (418) | aliased into `NUM_SENSORS`; used by persistence schema | `constexpr int` |
| `PING_DEVICE_INDEX` | ENTITY block (421) | PingAdapter start in YAML `on_boot` lambda; `PingAdapter::ping_task_` | `#define int` |
| `PING_TARGET` | ENTITY block (422) | YAML `on_boot` lambda | `#define const char*` |
| `entity_hbuf_*` statics | ENTITY block (405–415) | `devices[]` array (history pointers), web handlers read via MetricState | `static HistoryBuffer` |
| `HISTORY_SERIES_TEMP/HUM` | compile-time config (116–117) | `stream_snapshot_series_` (940, 948), `append_snapshot_series_csv_` (980, 986), `handle_history_` | `constexpr int` |
| `HISTORY_NAMESPACE` | 551 | `open_history_nvs_` (667), all NVS callers | `const char*` |
| `HISTORY_PARTITION_LABEL` | 554 | `ensure_history_nvs_ready_`, `clear_persisted_history_`, `open_history_nvs_`, `handle_storage_stats_` | `const char*` |
| `PERSIST_SLOTS` | 548 | `restore_from_nvs` (1047), `persist_hourly_segment` (1136, 1149, 1150), `load_history_meta_` (717) | `constexpr int` |
| `RAM_SEGMENTS` | 547 | `restore_from_nvs` (1044) | `constexpr int` |
| `NVS_SCAN_YIELD_INTERVAL` | 800 | `maybe_yield_nvs_scan_` (802) | `constexpr int` |
| `maybe_yield_nvs_scan_()` | 801–804 | `restore_from_nvs` (1056), `build_import_epoch_map_` (in import handlers), `handle_history_` | `static void` |
| `clear_runtime_histories_()` | 613–629 | `restore_from_nvs` (1042), `clear_persisted_history_` (788), `handle_import_begin_` | `static void` |
| `g_history_restored_from_nvs` | 597 | `restore_from_nvs` (1104), `handle_status_` | `static bool` |
| `find_partition_size_bytes_()` | 599–605 | `handle_storage_stats_` (3400+) | `static uint32_t` |
| `TAG` | 96 | All logging in non-aggregator code | `const char* const` |
| `TAG_AGG` | 1393 | All logging in aggregator block | `const char* const` |
| `s_cache_mutex` | 1479 | `aggregator_poll_task` (1949, 1987, 2034, 2073, 2107, 2138), `handle_aggregator_gateways_` (3870), `handle_aggregator_live_` (3801+), `handle_aggregator_proxy_` (3870), `handle_add_satellite_` (3935+), `handle_delete_satellite_` (4074+), `handle_test_satellite_` (4158+), `reset_satellites_task_` (2178), `schedule_save_satellites_nvs_` (2234) | `static SemaphoreHandle_t` |
| `AGG_LOCK()` / `AGG_UNLOCK()` | 1487–1488 | Same as `s_cache_mutex` consumers | `#define` macros |
| `satellite_caches[]` | 1464 | `aggregator_poll_task`, all aggregator handlers, reset/save tasks | `static SatelliteCache[MAX_SATELLITES]` |
| `runtime_satellite_count` | 1465 | `aggregator_poll_task`, `init_satellite_caches_`, `save_satellites_to_nvs_`, all aggregator handlers | `static int` |
| `satellite_config_generation` | 1466 | `aggregator_poll_task` (1964), `reset_satellites_task_` (2186), `handle_add_satellite_` (3935+), `handle_delete_satellite_` (4074+) | `static uint32_t` |
| `s_fetch_tmp` | 1495 | `aggregator_poll_task` (1985, 2032, 2071), `probe_satellite_manifest_` — **MUST be aggregator-task context only** | `static char[AGG_MANIFEST_BUF_SIZE]` |
| `s_proxy_tmp` | 1500 | `probe_satellite_manifest_` (1632), `handle_aggregator_proxy_` (3903), `handle_test_satellite_` (4158+) — **MUST be web-handler context only** | `static char[32768]` |
| `s_proxy_len` | 1501 | `handle_aggregator_proxy_` | `static uint16_t` |
| `s_delete_data_in_progress` | 1186 | `delete_data_task_` (1193), `schedule_delete_data_` (1200), `handle_delete_data_` (2890+) | `static volatile bool` |
| `s_reset_satellites_in_progress` | 2157 | `reset_satellites_task_` (2197), `schedule_reset_satellites_` (2201+), `handle_reset_satellites_` (4262, 4266) | `static volatile bool` |
| `s_nvs_save_in_progress` | 2158 | `save_satellites_nvs_task_` (2215), `schedule_save_satellites_nvs_` (2220), `handle_delete_satellite_` (4074+) | `static volatile bool` |
| `authenticate_management_()` | 2639–2679 | `handle_reboot_` (2881), `handle_delete_data_` (2890+), `handle_import_begin_` (3057+), `handle_add_satellite_` (3935+), `handle_test_satellite_` (4158+), `handle_reset_satellites_` (4255+) | private class method |
| `send_json_error_()` | 2603–2621 | Every management handler, every aggregator handler | private class method |
| `add_common_headers_()` | 2597–2601 | Every handler that returns a response | private class method |
| `GATEWAY_MANIFEST_JSON` | `src/gateway_manifest.h` (generated) | `handle_api_manifest_` (2722) | extern `const char*` |
| `DASHBOARD_HTML_GZ` / `DASHBOARD_HTML_GZ_LEN` | `dashboard/dashboard.h` (generated) | `handle_dashboard_` (2694) | extern arrays |
| `restore_from_nvs()` | 1004–1107 | `register_history_handler` (4301) | `static bool` |
| `persist_hourly_segment()` | 1109–1168 | YAML `on_time` lambda — **outside the header** | `static void` |
| `start_aggregator_task()` | 2261–2270 | YAML `on_boot` lambda — **outside the header** | `static void` |
| `register_history_handler()` | 4290–4325 | YAML `on_boot` lambda — **outside the header** | `static void` |

### Dependency Adjacency Matrix

Rows = "is consumed BY", columns = "depends ON":

| Consuming subsystem | HistEntry/HistBuf | SensorEntity/Metrics | ENTITY block | NVS model/core | PingAdapter | Aggregator runtime | Aggregator handlers | Core handlers | Auth/import | Registration |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| HistEntry/HistBuf (96–231) | — | | | | | | | | | |
| SensorEntity/Metrics (261–369) | ✓ | — | | | | | | | | |
| ENTITY block (381–496) | ✓ | ✓ | — | | | | | | | |
| NVS model/core (526–1168) | ✓ | ✓ | ✓ (devices[]) | — | | | | | | |
| PingAdapter (1220–1369) | | ✓ | ✓ (devices[]) | | — | | | | | |
| Aggregator runtime (1388–2272) | | | ✓ (MAX_SATS) | | | — | | | | |
| Aggregator handlers (3709–4282) | | | ✓ | | | ✓ (caches, mutex) | — | | ✓ (auth, send_json_error) | |
| Core handlers (2681–3708) | ✓ | ✓ | ✓ (devices[]) | ✓ | | | | — | ✓ (auth) | |
| Auth/import (2525–2680) | | | ✓ (import state uses HistoryMeta) | ✓ (SegmentSnapshot) | | | | | — | |
| Registration (4285–4325) | | | ✓ | ✓ (calls restore) | | ✓ | ✓ | ✓ (creates handler) | | — |

### Shared Constants Cross-Boundary Summary

| Constant | Lives In | Subsystems That Consume It Across Module Boundaries |
|---|---|---|
| `NUM_SENSORS` | ENTITY block | NVS model (SegmentSnapshot dimensions), NVS core (all snapshot helpers), handle_history_ |
| `NUM_DEVICES` | ENTITY block | NVS core (clear_runtime_histories_), handle_api_v2_live_, register_history_handler |
| `PERSIST_SLOTS`, `RAM_SEGMENTS` | NVS model | restore_from_nvs, persist_hourly_segment, load_history_meta_ |
| `AGG_LOCK`/`AGG_UNLOCK` | Aggregator runtime | Aggregator handlers, reset/save deferred tasks |
| `MAX_SATELLITES` | src/aggregator_config.h (generated) | Aggregator struct sizing, reset task, handle_reset_satellites_ |

### Open Questions — R2

- Q4: `probe_satellite_manifest_()` uses `s_proxy_tmp` (web-handler context only) but lives in the aggregator-runtime section (1614–1700). Its cross-context constraint must be documented and enforced at the module boundary. If it moves to the aggregator-handlers module, the comment constraint is clearer. If it stays in aggregator-runtime, it becomes a hidden coupling.
- Q5: The `import_*` mutable state in HistoryWebHandler private members (2532–2543) uses `HistoryMeta` and `SegmentSnapshot` types from the NVS model subsystem. This means the import-engine module cannot be cleanly separated from the NVS model module without explicit forward declarations or a shared types header.

---

## R3. Generator Interaction Analysis

### Marker Block Positions

`render_sensor_config.py` (ROOT = `scripts/render_sensor_config.py`) defines the following marker pairs and their target files:

| Marker pair | Target file | Lines in target (at HEAD) | Content generated |
|---|---|---|---|
| `SENSOR_MANIFEST:HEADER_BEGIN/END` | `dashboard/sensor_history_multi.h` | 375–379 | 3-line comment (no executable code) |
| `SENSOR_MANIFEST:ENTITY_BEGIN/END` | `dashboard/sensor_history_multi.h` | 381–496 | MetricDef arrays, HistoryBuffer statics, `NUM_DEVICES`, `NUM_ENV_SENSORS`, `NUM_SENSORS`, `PING_DEVICE_INDEX`, `PING_TARGET`, `devices[]` array |
| `SENSOR_MANIFEST:DEFAULT_SENSOR_META_BEGIN/END` | `dashboard/dashboard.js` | unknown | `var DEFAULT_SENSOR_META = [...]` |
| `SENSOR_MANIFEST:AVERAGING_BEGIN/END` | `firmware/esp32-c3-multi-sensor.yaml` | 180–204 | `devices[i].compute_and_format(epoch)` / `compute_averages(epoch)` calls per sensor |
| `SENSOR_MANIFEST:SORTING_GROUPS_BEGIN/END` | `firmware/esp32-c3-multi-sensor.yaml` | ~244–260 | `- id: group_{sid}` ESPHome entries per sensor |
| `SENSOR_MANIFEST:THERMOPRO_BEGIN/END` | `firmware/esp32-c3-multi-sensor.yaml` | in sensor block | BLE platform config per ThermoPro sensor |
| `SENSOR_MANIFEST:RSSI_BEGIN/END` | `firmware/esp32-c3-multi-sensor.yaml` | in sensor block | RSSI sensors |
| `SENSOR_MANIFEST:TEXT_SENSORS_BEGIN/END` | `firmware/esp32-c3-multi-sensor.yaml` | in sensor block | Text sensor outputs |
| `SENSOR_MANIFEST:PING_BOOT_BEGIN/END` | `firmware/esp32-c3-multi-sensor.yaml` | 64–69 | `#ifdef PING_DEVICE_INDEX` boot lambda |

### Generated Symbols Consumed Outside Marker Blocks

The ENTITY block generates symbols that are consumed extensively outside the marker block itself:

| Generated symbol | Location generated | First consumption outside block |
|---|---|---|
| `devices[NUM_DEVICES]` | ENTITY block (424–495) | NVS core line 613 (`clear_runtime_histories_` iterates NUM_DEVICES) |
| `NUM_DEVICES` | ENTITY block (417) | Line 613 |
| `NUM_ENV_SENSORS` | ENTITY block (418) | Line 419 (aliased), NVS model line 559 |
| `NUM_SENSORS` | ENTITY block (419) | NVS model line 559, 571, 572, 582–584 |
| `PING_DEVICE_INDEX` | ENTITY block (421) | PingAdapter start guard line 1220, YAML `on_boot` lambda |
| `PING_TARGET` | ENTITY block (422) | YAML `on_boot` lambda line 67 |
| `entity_hbuf_*` statics | ENTITY block (405–415) | `devices[]` initializer list within same block (history pointer assignments) |
| `metrics_thermopro[]` etc. | ENTITY block | `devices[]` initializer list within same block |

### Generator File Path Writes

`render_sensor_config.py` currently defines (lines 14–26):

```python
HEADER_PATH = ROOT / "dashboard" / "sensor_history_multi.h"
YAML_PATH   = ROOT / "firmware" / "esp32-c3-multi-sensor.yaml"
JS_PATH     = ROOT / "dashboard" / "dashboard.js"
GATEWAY_MANIFEST_H_PATH = ROOT / "src" / "gateway_manifest.h"
AGGREGATOR_CONFIG_H_PATH = ROOT / "src" / "aggregator_config.h"
FIXTURE_SENSORS_PATH = ROOT / "tests" / "fixtures" / "sensors.json"
FIXTURE_MANIFEST_PATH = ROOT / "tests" / "fixtures" / "manifest.json"
FIXTURE_STATUS_PATH = ROOT / "tests" / "fixtures" / "api-status.json"
```

The generator uses a single `HEADER_PATH` variable. The `replace_marker_block()` function (lines 55–60) operates on the full file text of `HEADER_PATH`.

### Generator Migration Options

**Option A — Generator writes into split fragment files directly**

The generator would need to know that:
- `SENSOR_MANIFEST:HEADER_BEGIN/END` lives in `firmware_modules/data-model.h`
- `SENSOR_MANIFEST:ENTITY_BEGIN/END` lives in `firmware_modules/data-model.h`

Trade-offs:
- Pro: No assembly step needed; fragments are the authoritative source
- Con: Generator must know module split boundaries; any reorganization requires generator changes
- Con: Version checks referencing `sensor_history_multi.h` header comment would need updating

**Option B — Retain `sensor_history_multi.h` as assembled artifact (recommended)**

`sensor_history_multi.h` remains a committed, assembled artifact (analogous to `dashboard.js`). Fragment files are sources; an assembly script concatenates them into `sensor_history_multi.h`. Generator continues to write into `sensor_history_multi.h` as before. A `--check` mode verifies that the assembled output matches the fragments.

Trade-offs:
- Pro: Zero generator changes; YAML `includes:` unchanged; all preflight checks unchanged
- Pro: Matches the Phase X pattern (bundle-first → generate into assembled output)
- Con: Must define assembly order carefully to avoid C++ ODR issues
- Con: Fragments contain incomplete code (only valid when assembled)

**Option C — Include-chain assembly (C preprocessor as assembler)**

`sensor_history_multi.h` contains only `#include` directives to fragment files. The C++ preprocessor assembles at compile time. No explicit assembly script.

Trade-offs:
- Pro: No separate assembly tool needed
- Pro: YAML `includes:` list unchanged (still only `sensor_history_multi.h`)
- Con: Forward declarations required for cross-fragment symbol references
- Con: Source-level identity gate becomes harder (can't compare assembled file)
- Con: Generator still writes to `sensor_history_multi.h` — must decide if generated content lives in fragments or in the assembly file

**Recommended approach:** Option B (assembled artifact). This matches the Phase X pattern, avoids C++ forward-declaration complexity, requires zero generator changes, and preserves all existing preflight checks. An assembly script (`assemble-firmware-modules.sh --check/--write`) verifies fragment→assembly integrity.

### Open Questions — R3

- Q6: The YAML `on_time` lambda at line 180 references `AVERAGING_BEGIN/END` markers. After a split, the YAML must still see `devices[]` and `compute_and_format()` from whichever fragment defines them. This is not a generator problem — it's an include-order problem in the YAML. The generator does not need to change, but the YAML `includes:` list must include all fragment files in the correct order.
- Q7: If Option B is chosen, the HEADER_PATH constant in render_sensor_config.py continues to point to `dashboard/sensor_history_multi.h` — no changes required. If Option A or C is chosen, HEADER_PATH must become a list or the generator must be refactored.

---

## R4. Include Order Constraints

### Current `includes:` List (firmware/esp32-c3-multi-sensor.yaml lines 40–44)

```yaml
includes:
  - ../dashboard/dashboard.h
  - ../dashboard/sensor_history_multi.h
  - ../src/gateway_manifest.h
  - ../src/aggregator_config.h
```

**Order rationale:**
1. `dashboard.h` MUST come first: `sensor_history_multi.h` references `DASHBOARD_HTML_GZ` and `DASHBOARD_HTML_GZ_LEN` (line 2694), which are defined in `dashboard.h`. Without this, the firmware build fails with "undefined reference to DASHBOARD_HTML_GZ" (documented at header lines 75–79).
2. `sensor_history_multi.h` second: consumes `DASHBOARD_HTML_GZ` from step 1. Also contains `#include "gateway_manifest.h"` (line 93) and `#include "aggregator_config.h"` (line 94) internally — but these are in the YAML `includes:` list separately too, likely for ESPHome dependency tracking.
3. `gateway_manifest.h` and `aggregator_config.h`: included internally by `sensor_history_multi.h` via relative paths; appear in the YAML list for ESPHome to track them as changed dependencies.

### YAML `on_boot` and `on_time` Wiring

Functions called from YAML lambdas that the include chain must satisfy:

| Lambda location | YAML line | Symbol referenced | Lives in file section |
|---|---|---|---|
| `on_boot` priority -100 | 56 | `register_history_handler(id(web_base), ...)` | sensor_history_multi.h line 4290 |
| `on_boot` priority 600 (ping) | 67 | `PingAdapter`, `ping_adapter.start(PING_DEVICE_INDEX, PING_TARGET)` | sensor_history_multi.h 1220–1369, ENTITY block 421–422 |
| `on_boot` priority 600 (aggregator) | 78 | `start_aggregator_task()` | sensor_history_multi.h line 2261 |
| `on_time` every 15 min | 182–204 | `devices[i].compute_and_format(epoch)`, `devices[i].compute_averages(epoch)` | sensor_history_multi.h ENTITY block 424–495, SensorEntity 297–368 |
| `on_time` every hour (`persist_minute`) | 221 | `persist_hourly_segment(now.timestamp)` | sensor_history_multi.h line 1109 |

### Proposed Include Order After Splitting (Option B — assembled artifact)

If sensor_history_multi.h is retained as the assembled artifact, the YAML `includes:` list does **not change**. This is the key advantage of Option B.

If Option A or C is chosen, the YAML `includes:` would require all fragment files in dependency order:

```yaml
includes:
  - ../dashboard/dashboard.h                          # 1. DASHBOARD_HTML_GZ — must be first
  - ../dashboard/firmware_modules/config.h            # 2. compile-time constants (#defines)
  - ../dashboard/firmware_modules/data-model.h        # 3. HistEntry, HistoryBuffer, SensorEntity, ENTITY block
  - ../dashboard/firmware_modules/nvs-persistence.h   # 4. NVS model + helpers — depends on data-model
  - ../dashboard/firmware_modules/ping-adapter.h      # 5. PingAdapter — depends on data-model
  - ../dashboard/firmware_modules/aggregator-core.h   # 6. Aggregator runtime — depends on data-model, nvs-persistence for agg_sats
  - ../dashboard/firmware_modules/web-handlers.h      # 7. HistoryWebHandler — depends on all above
  - ../dashboard/firmware_modules/registration.h      # 8. register_history_handler — depends on all above
  - ../src/gateway_manifest.h
  - ../src/aggregator_config.h
```

**Justification:** C++ requires forward declarations or prior definition for all symbols used. The ordering above follows the strict dependency chain: constants → data model → NVS → adapters → handlers → registration.

### Open Questions — R4

- Q8: `gateway_manifest.h` and `aggregator_config.h` appear in both the YAML `includes:` list AND as `#include` directives inside `sensor_history_multi.h` (lines 93–94). After splitting, which fragment owns those `#include` directives? Likely `data-model.h` (since `GATEWAY_MANIFEST_JSON` is used in `handle_api_manifest_` and `AGGREGATOR_ENABLED` guards the aggregator block). `#pragma once` on all fragment headers would prevent double-inclusion.

---

## R5. Verification Strategy Assessment

The four options from `Docs/phase-X-context-for-phase-Y.md` §7:

### Option 1: `gcc -E` Preprocessor Output Comparison

**Feasibility:** LOW-MEDIUM

In the ESPHome/ESP-IDF build environment:
- The compiler is `riscv32-esp-elf-gcc` (for ESP32-C3), not host `gcc`. The exact preprocessor output depends on all IDF include paths, platform-specific macros, and SDK versions.
- Reproducing the exact compiler invocation outside the ESPHome build pipeline requires extracting compile commands from the build log.
- Timestamps embedded in `__DATE__`/`__TIME__` macros (if used anywhere) would cause false differences.
- ESPHome generates intermediate C++ files that include the user headers — the target for comparison is not trivially accessible.

**Assessment:** Theoretically correct but operationally fragile. Requires full ESPHome build environment. Not recommended as a primary gate.

### Option 2: Object File Comparison (stripping timestamps)

**Feasibility:** LOW

- ESP-IDF object files contain non-deterministic elements beyond timestamps: debug info paths, section alignment padding, linker-generated metadata.
- ESPHome does not guarantee deterministic builds by default.
- Even if timestamps are stripped, changing a `#include` path (from `sensor_history_multi.h` to fragments) causes different debug info sections.
- No established toolchain for stripping all non-deterministic elements from ESP-IDF `.o` files.

**Assessment:** Not viable. Object-level comparison is too fragile in the ESPHome ESP-IDF environment.

### Option 3: Functional Equivalence (device test + Playwright)

**Feasibility:** HIGH (partially)

- Playwright tests already exist for all API routes and are domain-scoped post-Phase X.
- Mock server (`tests/mock-server/server.js`) faithfully simulates the firmware API contract.
- Browser tests do not exercise the firmware binary — they test the dashboard consuming the firmware's API shape.
- Device testing (actual ESP32-C3 flashed with firmware) is required for true equivalence, and requires physical hardware.

**Assessment:** Best available strategy for runtime behavioral equivalence. Can gate "the API contract is unchanged" conclusively. Cannot gate "the C++ code is semantically identical to the original monolith" without compile verification. Recommended as the final acceptance gate, not the primary identity gate.

### Option 4: Source-Level Identity (`#include` chain reproduces preprocessor output)

**Feasibility:** HIGH

- If Option B (assembled artifact) is chosen: the assembly script produces `sensor_history_multi.h` from fragment files. A `--check` mode computes SHA-256 of the assembled output and compares it against the committed file. If they match byte-for-byte, the fragments are a faithful decomposition of the original monolith.
- This is exactly the approach used by `bundle-dashboard.sh --check` for `dashboard.js`.
- Fully automatable with no build environment dependency.
- Can run in CI as a preflight check.

**Assessment:** Recommended primary identity gate for Phase Y. Requires adopting Option B (assembled artifact). The gate is: "sha256(assembled from fragments) == sha256(committed sensor_history_multi.h)".

### Recommended Strategy

**Primary gate (during split):** Source-level identity (Option 4) — assembly `--check` verifying that `sensor_history_multi.h` == concatenation of fragments in defined order. This runs locally and in CI without build environment.

**Final acceptance gate:** Functional equivalence (Option 3) — compile the firmware (via `esphome compile`) and run all Playwright tests against the mock server. Device test on physical hardware before tagging the split complete.

**Rationale:** Option 4 ensures no accidental code change during extraction. Option 3 ensures the assembled firmware behaves identically at runtime. The combination is the same two-tier approach used in Phase X (byte-identity check + Playwright).

---

## R6. Preflight & Test Impact

### Checks That Reference `sensor_history_multi.h` Directly

From `scripts/preflight.sh`:

| Check name | preflight.sh line | What it checks | Impact of split |
|---|---|---|---|
| `REQUIRED_FILES` list | 37 | `dashboard/sensor_history_multi.h` must exist | Must remain — file is the assembled artifact (Option B) |
| `history_header_version_matches` | 67 | File header comment contains version string `sensor_history_multi-v{VER}.h` | Must remain in assembled artifact header |
| `history_handler_has_api_manifest_route` | 68 | `/api/manifest` string present in file | Must remain in assembled artifact |
| `history_handler_has_api_v2_live_route` | 69 | `/api/v2/live` string present in file | Must remain in assembled artifact |
| `history_handler_has_api_v2_history_route` | 70 | `/api/v2/history/` string present in file | Must remain in assembled artifact |
| `history_handler_has_api_ingest_route` | 71 | `/api/ingest/` string present in file | Must remain in assembled artifact |
| `firmware_gzip_content_encoding` | 137 | `Content-Encoding", "gzip` present in file | Must remain in assembled artifact |
| `gateway_manifest_h_included` | 125 | `#include "gateway_manifest.h"` present in file | Must remain in assembled artifact (or in data-model fragment if Option C) |
| `gateway_manifest_json_used` | 131 | `GATEWAY_MANIFEST_JSON` string present | Must remain |
| `no_streaming_history_response` | 156 | No `beginResponseStream.*text/plain` in file | Must remain |
| `nvs_yield_present` | 163 | ≥3 calls to `maybe_yield_nvs_scan_` | Count valid on assembled artifact; must count across all fragments if using Option C |
| `num_env_sensors_constant_present` | 319 | `static constexpr int NUM_ENV_SENSORS =` in file | Must remain in ENTITY block (assembled) |
| `num_sensors_aliases_env_sensors` | 321 | `static constexpr int NUM_SENSORS = NUM_ENV_SENSORS;` | Must remain |
| `num_sensors_not_aliased_to_num_devices` | 323 | NOT `static constexpr int NUM_SENSORS = NUM_DEVICES;` | Must remain |
| `aggregator_config_h_included` | 328 | `#include "aggregator_config.h"` present | Must remain |
| `aggregator_route_gateways` | 366 | `/api/aggregator/gateways` string (conditional) | Must remain |
| `aggregator_route_live` | 368 | `/api/aggregator/live` string (conditional) | Must remain |
| `aggregator_route_proxy` | 370 | `/api/aggregator/proxy/` string (conditional) | Must remain |

**Total direct references: 18 checks.**

Under Option B (assembled artifact), **all 18 checks continue to pass without modification**, because they check the assembled file content, not the fragment files. This is the strongest argument for Option B from an operational standpoint.

### Checks That Break During Split (Option C / Include-chain approach only)

If `sensor_history_multi.h` becomes an include-only file (containing only `#include` directives), then all 18 content-based checks above would fail. They would need to be rewritten to check against specific fragment files or use `cat`/assembly to reconstruct the content before checking.

### New Checks Needed (regardless of approach)

| New check | Purpose |
|---|---|
| Fragment files exist in `REQUIRED_FILES` | Ensure each fragment in `firmware_modules/` is tracked |
| Assembly `--check` passes | Verify assembled `sensor_history_multi.h` matches fragment concatenation |
| Fragment include order consistency | Verify YAML `includes:` (if listing fragments) follows the required order |
| No symbols defined in multiple fragments | ODR guard — no duplicate static definitions |

### Preflight Impact Table

| Impact category | Option B (assembled artifact) | Option C (include-chain) |
|---|---|---|
| Existing checks that break | **0** | ~18 (all content checks) |
| New checks required | ~3 (fragment existence, assembly check, ODR guard) | ~18 (rewrite all content checks + fragment checks) |
| `render_sensor_config.py --check` | Unaffected | Requires generator update |
| `bundle-dashboard.sh` pattern | Analogous assembly script | Not applicable |
| CI risk during split | Low | Medium-High |

---

## R7. Phase 7 Extension Points

### What Phase 7 Adds to `sensor_history_multi.h`

From `Docs/v7.7-implementation-plan.md` and `Docs/v7.7-v7.8-persistence-architecture.md`:

**v7.7.0.0 (structs + generator):**
- New structs in `sensor_history_multi.h`: `DeviceHistoryMeta`, `DeviceSegmentHeader`, `DeviceSegment`
- New helpers: `device_id_hash_()`, `make_device_meta_key_()`, `make_device_segment_key_()`
- Generator produces: `PERSIST_DEVICE_COUNT`, `PERSIST_DEVICE_IDS[]`, `PERSIST_METRIC_COUNTS[]`

**v7.7.0.1 (write path):**
- New functions: `persist_device_segment_()`, `persist_all_devices_v2()`, `load_device_meta_()`, `save_device_meta_()`
- YAML `on_time` hourly lambda gets: `persist_all_devices_v2()` call

**v7.7.0.2 (restore path):**
- New functions: `restore_device_()`, `calculate_retention_budget_()`, `restore_all_devices_v2()`
- YAML `on_boot` lambda gets: `restore_all_devices_v2()` call

**v7.7.0.3 (engine swap):**
- `sensor_history_multi.h` swaps primary persist/restore to v2 engine
- Adds per-device storage stats handler

**v7.7.1.0 (migration):**
- New functions: `migrate_v7_to_v8_()`, `check_and_run_migration_()`
- YAML `on_boot` lambda gets migration call before restore

### Which Phase Y Modules Phase 7 Extends

| Phase Y module | Phase 7 additions | Risk if module boundary is wrong |
|---|---|---|
| `data-model.h` (ENTITY block + structs) | `DeviceHistoryMeta`, `DeviceSegmentHeader`, `DeviceSegment` structs appended after `SegmentSnapshot`; new generator constants `PERSIST_DEVICE_COUNT` etc. in ENTITY block | HIGH — `DeviceSegment` uses `MAX_PERSIST_METRICS` and `HistEntry` types from the same module; must be in same translation unit as `HistEntry` and `HistoryBuffer` |
| `nvs-persistence.h` (NVS core) | `persist_device_segment_()`, `persist_all_devices_v2()`, `restore_device_()`, `restore_all_devices_v2()`, `load_device_meta_()`, `save_device_meta_()`, `calculate_retention_budget_()`, `migrate_v7_to_v8_()` | HIGH — all these functions use `HistoryBuffer`, `HistEntry`, `SensorEntity devices[]`, `PERSIST_SLOTS`, `maybe_yield_nvs_scan_()` — must see all of data-model |
| YAML `on_time` interval lambda | `persist_all_devices_v2()` call added | LOW — only requires that `persist_all_devices_v2` is exported from `nvs-persistence.h` |
| YAML `on_boot` lambda | `restore_all_devices_v2()` and migration calls added | LOW — same |
| `web-handlers.h` (HistoryWebHandler) | v7.7.0.3: updated `handle_storage_stats_()` for per-device format | MEDIUM — requires `DeviceHistoryMeta` types to be visible |

### Interfaces the Phase Y Split Must Expose for Clean Phase 7 Integration

| Interface | Required by Phase 7 | Phase Y must ensure |
|---|---|---|
| `HistEntry`, `HistoryBuffer` types | `DeviceSegment` embeds `HistEntry data[MAX_PERSIST_METRICS][PERSIST_POINTS_PER_SEGMENT]`; restore loads via `HistoryBuffer::load_from()` | These must be in `data-model.h` (before any NVS module) |
| `SensorEntity devices[]` array + `NUM_DEVICES` | Phase 7 restore iterates `devices[i]` to populate history buffers | `data-model.h` owns these; NVS module accesses them as extern or via direct include |
| `maybe_yield_nvs_scan_()` | Phase 7 restore loops call it between device restores | Must be exported from whichever module defines it (currently NVS core) |
| `open_history_nvs_()` / partition helpers | Phase 7 functions use the same history NVS partition | Must be in `nvs-persistence.h` (shared with existing persist/restore) |
| `PERSIST_DEVICE_COUNT`, `PERSIST_DEVICE_IDS[]` | Phase 7 loops over these to identify which devices to persist | Generator must emit these into the ENTITY block in `data-model.h`; Phase Y split must not break the ENTITY marker block |
| `MAX_PERSIST_METRICS` | Embedded in `DeviceSegment` | Phase Y should define this in `data-model.h` or a compile-time constants header so Phase 7 can access it without circular includes |

### Extension Point Requirements Per Proposed Module

| Module | Must expose | Must not do |
|---|---|---|
| `data-model.h` | `HistEntry`, `HistoryBuffer`, `MetricDef`, `MetricState`, `SensorEntity`, `devices[]`, `NUM_DEVICES`, `NUM_SENSORS`, `HISTORY_*` constants, `PERSIST_*` constants, ENTITY marker block | Not define NVS handles, FreeRTOS handles, or any runtime state that belongs in other modules |
| `nvs-persistence.h` | `restore_from_nvs()`, `persist_hourly_segment()`, `maybe_yield_nvs_scan_()`, `clear_persisted_history_()`, all NVS helpers | Not define web handler classes; not hold aggregator state |
| `ping-adapter.h` | `PingAdapter` class | Only access `devices[]` via the module boundary; no NVS or aggregator dependencies |
| `aggregator-core.h` | `SatelliteCache`, `satellite_caches[]`, `AGG_LOCK`/`AGG_UNLOCK`, `s_cache_mutex`, `fetch_to_buffer`, `start_aggregator_task()`, deferred satellite tasks | Not define web handler methods; `s_proxy_tmp` should live here but have clear "web-handler context only" documentation |
| `web-handlers.h` | `HistoryWebHandler` class (full) | Not instantiate its own static data beyond import state and auth state |
| `registration.h` | `register_history_handler()` | Just the registration tail; no significant logic |

---

## R8. provision.sh Automation Gap

### Current 8-Step Pipeline

From `scripts/provision.sh` `print_workflow()` function (lines 171–213):

**What runs automatically:** `provision.sh <target>` internally calls `run_render()` (lines 136–146), which runs `render_sensor_config.py --write` once before printing the pipeline instructions.

**What is printed for manual execution (8 steps):**

| Step | Command | Purpose |
|---|---|---|
| 1 | `bash scripts/bundle-dashboard.sh --write` | Assemble source modules → `dashboard.js` |
| 2 | `python3 scripts/render_sensor_config.py --write` | Re-inject `DEFAULT_SENSOR_META` markers (bundle overwrites dashboard.js, erasing prior injection) |
| 3 | `node tests/fixtures/generate-fixtures.js` | Regenerate test fixtures from current config |
| 4 | `python3 scripts/render_sensor_config.py --write` | Re-inject after fixture generation may have modified dashboard.js state |
| 5 | `bash scripts/build-dashboard.sh --write` | Template + JS → `dashboard.html` |
| 6 | `bash scripts/minify-dashboard.sh` | `dashboard.html` → `dashboard.min.html` |
| 7 | `bash scripts/generate-header.sh` | `dashboard.min.html` → `dashboard.h` (gzip C header) |
| 8 | `python3 scripts/render_sensor_config.py --check` | Final verification (markers in sync) |

**Ordering problem:** `provision.sh` auto-runs `render_sensor_config.py --write` as step 0, but the printed pipeline requires `bundle-dashboard.sh --write` (step 1) to run BEFORE `render_sensor_config.py --write` (step 2). The auto-run at step 0 puts the render in the wrong pipeline position. The auto-run is harmless (it sets up initial config state), but the step 0 render will be overwritten by step 1 (bundle) + step 2 (re-render). This means the auto-run is redundant but not harmful.

### What Full Automation Would Require

To execute all 8 steps automatically after `provision.sh <target>`:

1. `node`/`npm` must be available on the host (for `generate-fixtures.js` and `bundle-dashboard.sh`)
2. Each step must succeed before the next runs (already handled by `set -euo pipefail` if added)
3. No user confirmation prompts between steps
4. The script must handle the `generate-fixtures.js` node dependency check
5. `minify-dashboard.sh` requires `html-minifier-terser` via `npx` (needs node_modules or global install)
6. `generate-header.sh` requires `gzip` (standard on Linux/macOS)

**Automation blockers:**
- `node` availability is not guaranteed in all deployment environments
- `minify-dashboard.sh` requires npm devDependencies (`html-minifier-terser`, `terser`) — `npm install` would need to run first
- Current `provision.sh` does not validate npm dependencies

### v7.6.6.0 Pre-Step Specification

A `v7.6.6.0` pre-step for provision.sh automation would add a `--auto` flag or a new `full-pipeline` command that:

```bash
# Pre-checks before automation
require_node() { command -v node || { echo "ERROR: node not found"; exit 1; }; }
require_npm_deps() { [[ -d node_modules/@playwright/test ]] || npm install; }

# Auto-run full pipeline (Critical Rule 37 sequence)
bash scripts/bundle-dashboard.sh --write
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
python3 scripts/render_sensor_config.py --write
bash scripts/build-dashboard.sh --write
bash scripts/minify-dashboard.sh
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
```

**Gap summary:**

| Gap | Current state | Required for full automation |
|---|---|---|
| render_sensor_config.py | Auto-runs once (wrong pipeline position) | Move to post-bundle position only |
| bundle-dashboard.sh | Manual | Auto-run first in pipeline |
| generate-fixtures.js | Manual | Auto-run with node availability check |
| build-dashboard.sh | Manual | Auto-run after re-render |
| minify-dashboard.sh | Manual | Auto-run with npm dep check |
| generate-header.sh | Manual | Auto-run with gzip check |
| render_sensor_config.py --check | Manual | Auto-run last as verification |
| preflight.sh | Not in pipeline, separate step | Optionally chain after pipeline |

**For Phase Y:** The assembly step (`assemble-firmware-modules.sh --write`) would need to be inserted into the pipeline. Under Option B, it would run before `render_sensor_config.py --write` (the assembly produces `sensor_history_multi.h` which the generator then writes into). The proposed Phase Y position in the pipeline:

```
[0] provision.sh switch (copies .bak → active configs)
[1] assemble-firmware-modules.sh --write       ← NEW in Phase Y
[2] bundle-dashboard.sh --write
[3] render_sensor_config.py --write
[4] generate-fixtures.js
[5] render_sensor_config.py --write
[6] build-dashboard.sh --write
[7] minify-dashboard.sh
[8] generate-header.sh
[9] render_sensor_config.py --check
```

---

## Summary: Key Open Questions for the Planning Agent

| # | Question | Impacts |
|---|---|---|
| Q1 | Should `handle_api_manifest_` (inline at L2722) live in the web-handler module or data-model module? | Module boundary for `web-handlers.h` |
| Q2 | Should `probe_satellite_manifest_()` (uses `s_proxy_tmp`) move to aggregator-handlers module despite living in aggregator-runtime section? | Context-safety documentation, module boundary |
| Q3 | Where does `handle_options_` (3 lines) belong? | Cosmetic but needs a home |
| Q4 | Does Phase Y adopt Option B (assembled artifact, zero generator changes) or Option C (include-chain, requires generator and preflight changes)? | Generator, preflight, YAML, CI, all downstream work |
| Q5 | Which fragment owns the `#include "gateway_manifest.h"` and `#include "aggregator_config.h"` directives? | data-model.h vs. a config/includes header |
| Q6 | Does the YAML `includes:` list remain unchanged (Option B) or list fragment files explicitly (Option C)? | Tied to Q4 |
| Q7 | Does provision.sh get a `--auto` flag for full pipeline automation in this phase, or is that deferred to a separate v7.6.6.0 task? | Scope boundary decision |
| Q8 | Is `assemble-firmware-modules.sh` a new standalone script, or is it integrated into `provision.sh`? | Architecture of new build tool |

---

_End of Phase Y Deep Research Brief._
