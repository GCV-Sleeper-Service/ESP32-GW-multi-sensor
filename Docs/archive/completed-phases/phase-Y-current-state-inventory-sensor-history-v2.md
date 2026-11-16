# Phase Y Current-State Inventory — `sensor_history_multi.h` (v2)

## 1. Executive Summary

At `v7.6.5.8` HEAD, `dashboard/sensor_history_multi.h` is a **4,325-line** multi-role firmware integration unit. It is no longer accurately described as a narrow history-persistence header.

The file now owns or directly hosts all of the following responsibilities:

- persisted history schema and NVS lifecycle (`HistoryMeta`, `SegmentSnapshotHeader`, `SegmentSnapshot`, restore/migration/recalibration)
- 24-hour RAM history buffers and history response assembly
- runtime device/entity model (`MetricDef`, `MetricState`, `SensorEntity`)
- CSV import / merge / finalize flows
- management auth, lockout, and deferred destructive actions
- HTTP route classification and endpoint dispatch
- embedded dashboard payload serving (`DASHBOARD_HTML_GZ`)
- aggregator runtime cache, polling, proxying, runtime satellite mutation, and satellite NVS persistence
- ping adapter background tasking
- boot-time registration / orchestration
- generator-owned sensor/entity/config blocks injected in-place by `render_sensor_config.py`

This is a materially different file from the one inventoried in the earlier Phase Y v1 document. The largest growth driver is **Phase D runtime satellite management**, which added implemented satellite mutation endpoints, satellite NVS persistence helpers, a deferred satellite-reset task, and supporting concurrency/control logic. The file also now sits inside a substantially different surrounding architecture because **Phase X replaced the monolithic dashboard/test/doc layout with a generated component architecture and split browser specs**.

For Phase Y planning, the correct mental model is:

> `sensor_history_multi.h` is a monolithic host for several real subsystems that already exist implicitly, with hard seams between generated topology, persisted schema, request/runtime context, and local HTTP stack constraints.

It should not be treated as a single-purpose history module.

---

## 2. Current File Metrics

### 2.1 Exact size and type inventory

| Metric | Current HEAD value | Notes |
|---|---:|---|
| Exact line count | **4,325** | HEAD target for this inventory |
| Named struct types | **10** | 9 top-level + nested `EpochSlotEntry` |
| Classes | **3** | `HistoryBuffer`, `PingAdapter`, `HistoryWebHandler` |
| Top-level helper / free functions | **38** | Outside class bodies |
| Endpoint-specific handler methods | **21** | `HistoryWebHandler` endpoint families only; excludes generic dispatcher/auth helpers |
| Deferred-task helper pairs | **4** | Reboot, delete-data, reset-satellites, save-satellites-NVS |
| Generator marker blocks | **2** | `SENSOR_MANIFEST:HEADER`, `SENSOR_MANIFEST:ENTITY` |
| Named compile-time constants / macros | **31** | Includes `#define` and `static constexpr` constants/macros owned in this file |
| Static shared buffers / arrays | **15** | 11 generated `HistoryBuffer` statics + `devices[]` + `satellite_caches[]` + `s_fetch_tmp` + `s_proxy_tmp` |
| Runtime devices in current generated block | **5** | 3 environmental + 1 network + 1 system |
| Persisted environmental sensor count | **3** | `NUM_ENV_SENSORS`, aliased to `NUM_SENSORS` |

### 2.2 Named structs

**Top-level structs**

1. `HistEntry`
2. `MetricDef`
3. `MetricState`
4. `SensorEntity`
5. `HistoryMeta`
6. `SegmentSnapshotHeader`
7. `SegmentSnapshot`
8. `SatelliteCache`
9. `SatelliteNVSSnapshot`

**Nested named struct**

10. `EpochSlotEntry` (inside `HistoryWebHandler`)

### 2.3 Classes

1. `HistoryBuffer`
2. `PingAdapter`
3. `HistoryWebHandler`

### 2.4 Top-level helper / free functions (38)

1. `allocate_snapshot_`
2. `find_partition_size_bytes_`
3. `make_segment_key_`
4. `clear_runtime_histories_`
5. `ensure_history_nvs_ready_`
6. `open_history_nvs_`
7. `default_history_meta_`
8. `load_history_meta_`
9. `save_history_meta_`
10. `clear_persisted_history_`
11. `maybe_yield_nvs_scan_`
12. `load_snapshot_from_handle_`
13. `export_latest_entries_`
14. `build_segment_snapshot_`
15. `append_snapshot_to_ram_`
16. `stream_snapshot_series_`
17. `append_snapshot_series_csv_`
18. `restore_from_nvs`
19. `persist_hourly_segment`
20. `reboot_task_`
21. `schedule_reboot_`
22. `delete_data_task_`
23. `schedule_delete_data_`
24. `init_aggregator_mutex`
25. `fetch_to_buffer`
26. `probe_satellite_manifest_`
27. `load_satellites_from_nvs_`
28. `save_satellites_to_nvs_`
29. `save_satellites_snapshot_to_nvs_`
30. `save_single_satellite_to_nvs_`
31. `init_satellite_caches_`
32. `aggregator_poll_task`
33. `reset_satellites_task_`
34. `schedule_reset_satellites_`
35. `save_satellites_nvs_task_`
36. `schedule_save_satellites_nvs_`
37. `start_aggregator_task`
38. `register_history_handler`

### 2.5 Endpoint-specific handler methods (21)

1. `handle_dashboard_`
2. `handle_manifest_`
3. `handle_api_manifest_`
4. `handle_api_v2_live_`
5. `handle_api_v2_history_`
6. `handle_api_ingest_`
7. `handle_reboot_`
8. `handle_delete_data_`
9. `handle_import_begin_`
10. `handle_import_data_`
11. `handle_import_finish_`
12. `handle_storage_stats_`
13. `handle_status_`
14. `handle_history_`
15. `handle_aggregator_gateways_`
16. `handle_aggregator_live_`
17. `handle_aggregator_proxy_`
18. `handle_add_satellite_`
19. `handle_delete_satellite_`
20. `handle_test_satellite_`
21. `handle_reset_satellites_`

**Related non-endpoint dispatch/support methods** that are still architecturally important but not counted above:

- `canHandle`
- `handleRequest`
- `handle_options_`
- `is_management_post_route_`
- `is_post_or_options_route_`
- auth / error / helper methods

### 2.6 Deferred-task helper pairs (4)

| Task function | Scheduler / trigger function | Purpose |
|---|---|---|
| `reboot_task_` | `schedule_reboot_` | Deferred reboot |
| `delete_data_task_` | `schedule_delete_data_` | Deferred history erase |
| `reset_satellites_task_` | `schedule_reset_satellites_` | Deferred factory reset of runtime satellites |
| `save_satellites_nvs_task_` | `schedule_save_satellites_nvs_` | Deferred snapshot-based NVS save after runtime mutation |

### 2.7 Generator marker blocks (2)

1. `SENSOR_MANIFEST:HEADER`
2. `SENSOR_MANIFEST:ENTITY`

### 2.8 Compile-time constants / macros (31)

`HISTORY_HOURS`, `HISTORY_INTERVAL_MINUTES`, `PERSIST_DAYS`, `HISTORY_POINTS_PER_SERIES`, `HISTORY_META_MAGIC`, `HISTORY_META_VERSION`, `HISTORY_SERIES_TEMP`, `HISTORY_SERIES_HUM`, `AUTH_FAILURE_DELAY_MS`, `AUTH_LOCKOUT_MS`, `AUTH_MAX_FAILURES`, `AUTH_REALM`, `MAX_METRICS_PER_DEVICE`, `NUM_DEVICES`, `NUM_ENV_SENSORS`, `NUM_SENSORS`, `PING_DEVICE_INDEX`, `PING_TARGET`, `PERSIST_SEGMENT_HOURS`, `PERSIST_POINTS_PER_SEGMENT`, `RAM_SEGMENTS`, `PERSIST_SLOTS`, `HISTORY_NAMESPACE`, `HISTORY_PARTITION_LABEL`, `NVS_SCAN_YIELD_INTERVAL`, `AGG_MANIFEST_BUF_SIZE`, `AGGREGATOR_TEST_SATELLITE_ROUTE`, `AGGREGATOR_TEST_SATELLITE_ROUTE_LEN`, `AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN`, `AGG_LOCK`, `AGG_UNLOCK`

### 2.9 Static shared buffers / arrays (15)

**Generated `HistoryBuffer` statics (11)**

- `entity_hbuf_office_temp`
- `entity_hbuf_office_hum`
- `entity_hbuf_first_floor_temp`
- `entity_hbuf_first_floor_hum`
- `entity_hbuf_outside_temp`
- `entity_hbuf_outside_hum`
- `entity_hbuf_wan_ping_ping_ms`
- `entity_hbuf_wan_ping_success_pct`
- `entity_hbuf_nas01_cpu_pct`
- `entity_hbuf_nas01_ram_pct`
- `entity_hbuf_nas01_disk_pct`

**Other file-scope shared storage**

- `devices[NUM_DEVICES]`
- `satellite_caches[MAX_SATELLITES]`
- `s_fetch_tmp[AGG_MANIFEST_BUF_SIZE]`
- `s_proxy_tmp[32768]`

### 2.10 Current generated device topology

| Device ID | Category | Adapter | Persisted to flash-backed history? |
|---|---|---|---|
| `office` | environmental | `thermopro_ble` | Yes |
| `first_floor` | environmental | `thermopro_ble` | Yes |
| `outside` | environmental | `thermopro_ble` | Yes |
| `wan_ping` | network | `icmp_ping` | No (`NUM_SENSORS` excludes it) |
| `nas01` | system | `external_push` | No (`NUM_SENSORS` excludes it) |

---

## 3. Top-Level Responsibility Map

> **Line-range note:** the ranges below are **analysis ranges**, not compiler/source-map anchors. The repository connector used for this inventory exposes HEAD blob content cleanly but does not expose stable line-number anchors for every span. They are still useful for Phase Y contiguous-slice planning.

| Responsibility area | What it owns | Ownership | Approx. line range | Move risk | Why it is risky |
|---|---|---|---|---|---|
| Header, includes, base constants, `HistoryBuffer` primitives | compile-time knobs, base includes, RAM ring-buffer primitive | Hand-maintained | ~1–260 | Medium | Internally cohesive, but everything else depends on the constants and `HistoryBuffer` interface |
| Runtime model + generated topology seam | `MetricDef`, `MetricState`, `SensorEntity`, marker-delimited generated entity/config blocks, runtime device counts | Mixed | ~261–625 | Very high | Generator/runtime seam; drift here breaks persistence, route behavior, manifest assumptions, and tests |
| Persisted history schema + NVS core | `HistoryMeta`, `SegmentSnapshot*`, meta load/save, schema migration, recalibration, restore, hourly persist | Hand-maintained | ~626–1870 | Very high | Physical blob layout and migration behavior are data-retention-critical |
| Deferred task helpers | reboot/delete task helpers and scheduling | Hand-maintained | ~1871–1950 | High | Small block, but tied to local HTTP stack survival rules |
| Ping adapter | `PingAdapter`, ping callbacks, task, generated ping device coupling | Hand-maintained with generated coupling | ~1951–2235 | Medium | Good local cohesion, but writes into generated device array and relies on generated ping constants |
| Aggregator runtime core | `SatelliteCache`, `SatelliteNVSSnapshot`, mutex/buffers, fetch helper, probe helper, NVS satellite persistence, poll task, reset/save deferred tasks | Mixed | ~2236–3290 | Very high | Large Phase D subsystem with its own concurrency, NVS model, network client, and mutation rules |
| HTTP/API gateway inside `HistoryWebHandler` | route classification, method dispatch, auth, management, manifest/status/history/import serving | Hand-maintained | ~3291–4040 | Very high | This is the public contract surface for dashboard, tests, mock server, and operator workflows |
| Aggregator endpoint methods inside `HistoryWebHandler` | gateways/live/proxy/add/delete/test/reset endpoints | Hand-maintained | ~4041–4295 | Very high | Phase D logic is split between the class and the top-level aggregator runtime block |
| Registration/orchestration tail | `register_history_handler()`, boot-time restore, handler registration | Hand-maintained | ~4296–4325 | High | Boot order and include order are behaviorally significant |

### Phase D additions now present in the map

The v1 inventory did not describe the following as implemented current-state responsibilities. They are now first-class inventory items:

- satellite NVS persistence helpers:
  - `load_satellites_from_nvs_`
  - `save_satellites_to_nvs_`
  - `save_satellites_snapshot_to_nvs_`
  - `save_single_satellite_to_nvs_`
  - `init_satellite_caches_`
- runtime mutation / validation handlers:
  - `handle_add_satellite_()`
  - `handle_delete_satellite_()`
  - `handle_test_satellite_()`
- deferred satellite-reset / deferred NVS-save support:
  - `reset_satellites_task_()` / `schedule_reset_satellites_()`
  - `save_satellites_nvs_task_()` / `schedule_save_satellites_nvs_()`
- aggregator config-race protection:
  - `satellite_config_generation`
- snapshot-based deferred persistence contract:
  - `SatelliteNVSSnapshot`

That addition materially changes the file’s decomposition: the aggregator subsystem is no longer just polling/cache/proxy logic. It now also owns runtime topology mutation and persistence semantics.

---

## 4. Generated vs Hand-Maintained Ownership

### 4.1 Marker-delimited ownership inside `sensor_history_multi.h`

| Marker block | Ownership | What it emits / controls | Current placement |
|---|---|---|---|
| `SENSOR_MANIFEST:HEADER` | Generated by `scripts/render_sensor_config.py` | explanatory comments around device-count semantics (`NUM_DEVICES` vs `NUM_ENV_SENSORS` vs `NUM_SENSORS`) | Early runtime-model section |
| `SENSOR_MANIFEST:ENTITY` | Generated by `scripts/render_sensor_config.py` | metric definition arrays, generated `HistoryBuffer` statics, device counts, ping constants, generated `devices[]` topology | Early runtime-model section |

### 4.2 Generated dependencies consumed by the file

| File | Ownership | Role in current-state contract |
|---|---|---|
| `src/gateway_manifest.h` | Generated | Supplies `GATEWAY_MANIFEST_JSON` for `GET /api/manifest` |
| `src/aggregator_config.h` | Generated | Supplies compile-time aggregator enablement/topology defaults; current default HEAD is CI-safe stub with `AGGREGATOR_ENABLED 0` |

### 4.3 Hand-maintained areas

The following remain hand-maintained even though they depend on generated outputs:

- persisted-history schema and NVS logic
- route classification / dispatch / auth
- import engine
- management handlers and deferred-task scheduling
- ping adapter implementation
- aggregator runtime logic, proxying, polling, NVS mutation helpers, and route handlers
- registration/orchestration

### 4.4 Interaction with `render_sensor_config.py`

`render_sensor_config.py` is the canonical owner of the generated sensor/runtime topology. It updates this file in place, and also regenerates:

- `src/gateway_manifest.h`
- `src/aggregator_config.h`
- firmware YAML marker regions / include wiring
- fixture artifacts
- dashboard SENSOR_MANIFEST marker content

That means the true ownership seam is not limited to the two marker blocks. The hand-maintained logic throughout the file also assumes the generated outputs remain semantically aligned.

### 4.5 Primary drift risks at the generator seam

| Drift risk | Failure mode |
|---|---|
| `NUM_SENSORS` semantics drift from `NUM_ENV_SENSORS` | persisted schema widening and history invalidation (BUG-045 family) |
| Metric ordering changes | wrong series mapping, especially where code still assumes temp/hum are `metric_states[0/1]` for environmental devices |
| Device/category topology changes without matching dashboard/test regeneration | manifest/route/dashboard/fixture drift |
| Generator run omitted after config switch | committed artifacts diverge from active config |
| Operator configs left in place during regeneration | environment-specific generated state leaks into commit-bound artifacts |

### 4.6 Ownership conclusion

The v1 inventory was correct that generated-vs-hand ownership is the defining architectural seam. At HEAD that seam is even more important because:

- the runtime device model is broader (environmental + network + system)
- the dashboard is generated from components, not edited monolithically
- `provision.sh` and the 8-step pipeline now sit directly between config switching and safe artifact regeneration

---

## 5. Endpoint Inventory

> **Method note:** `canHandle()`/`handleRequest()` intentionally accept some non-canonical methods on certain routes so the handler can return JSON 405 rather than letting the lower layer return a transport-level plain-text 405. The table below lists the **canonical route contract**.

### 5.1 Local history / manifest / dashboard / status routes

| Route | Method | Auth | Primary consumer(s) | v1 status | Current-state note |
|---|---|---|---|---|---|
| `/history/{id}/temp` | GET | No | environmental charts, history fetch fallback, mock server parity | Present in v1 | Now explicitly 404s for non-environmental devices |
| `/history/{id}/hum` | GET | No | environmental charts, history fetch fallback, mock server parity | Present in v1 | Same |
| `/sensors.json` | GET | No | legacy fallback boot path | Present in v1 | Still environmental-only projection |
| `/api/manifest` | GET | No | dashboard boot, manifest tests, mock server, fixture generation assumptions | Present in v1 | Served directly from generated `gateway_manifest.h` |
| `/dashboard` | GET | No | browser entry | Present in v1 | Gzip-served dashboard payload |
| `/dashboard.html` | GET | No | browser entry / tests | Present in v1 | Same payload as `/dashboard` |
| `/dashboard-download` | GET | No | operator dashboard download workflow | Present in v1 | Attachment response |
| `/favicon.ico` | GET | No | browser suppression path | Present in v1 | Still handled here, but local HTTP stack ordering remains relevant |
| `/api/storage-stats` | GET | No | storage card, diagnostics, mock server | Present in v1 | Includes partition sizing and retention estimates |
| `/api/status` | GET | No | device/about cards, diagnostics, mock server | Present in v1 | Includes `free_heap`, `free_heap_internal`, `free_heap_total` |
| `/api/v2/live` | GET | No | live dashboard data, mixed-category UI, mock server | Present in v1 | Unified live view across device categories |
| `/api/v2/history/{device}/{metric}` | GET | No | non-legacy metric history fetch, aggregator proxy target, mock server | Present in v1 | Current history API for non-env metrics |
| `/api/ingest/{device}/{metric}` | POST | No | external push clients, mock server | Present in v1 | Value and device/metric validation live here |

### 5.2 Import and management routes

| Route | Method | Auth | Primary consumer(s) | v1 status | Current-state note |
|---|---|---|---|---|---|
| `/api/import/begin` | POST | Yes | dashboard import UI / operator tooling | Present in v1 | Erase-first multi-sensor mode |
| `/api/import/begin/single/{sensor_id}` | POST | Yes | dashboard import UI / operator tooling | Present in v1 | Merge-first single-sensor mode |
| `/api/import/d/{data}` | POST | Yes | dashboard import chunking | Present in v1 | URL-path payload contract preserved |
| `/api/import/w/{data}` | POST | Yes | dashboard import chunking | Present in v1 | Write-on-chunk variant |
| `/api/import/finish` | POST | Yes | dashboard import completion | Present in v1 | Persists meta and restores RAM history |
| `/api/reboot` | POST | Yes | dashboard management UI | Present in v1 | Deferred-task implementation |
| `/api/delete-data` | POST | Yes | dashboard management UI | Present in v1 | Deferred-task implementation |
| `/api/system/reset-satellites` | POST | Yes | aggregator settings / runtime-management UI | Present in v1 | **Expanded since v1**: now real deferred task, not just route presence |

### 5.3 Aggregator routes

| Route | Method | Auth | Primary consumer(s) | v1 status | Current-state note |
|---|---|---|---|---|---|
| `/api/aggregator/gateways` | GET | No | gateway panel | Present in v1 | Cached gateway summary + embedded manifest/status-derived metadata |
| `/api/aggregator/live` | GET | No | gateway panel | Present in v1 | Unified live cache response |
| `/api/aggregator/proxy/{gw}/history/{device}/{metric}` | GET | No | gateway history proxy fetches | Present in v1 | Fixed-buffer proxy with truncation detection |
| `/api/aggregator/add-satellite` | POST | **No** | runtime satellite add flow in gateway settings panel | Present in v1 as stub/placeholder | **Expanded since v1**: real implementation, manifest probe, NVS write, rollback-on-failure |
| `/api/aggregator/test-satellite` | POST | Yes | runtime satellite test flow in gateway settings panel | Present in v1 as stub/placeholder | **Expanded since v1**: real implementation, probe-only, no mutation |
| `/api/aggregator/satellite/{id}` | DELETE | Yes | runtime satellite removal in gateway settings panel | Present in v1 as stub/placeholder | **Expanded since v1**: real implementation, array compaction + deferred NVS save |

### 5.4 Route-family observations

1. The file still owns both **legacy** and **current** history surfaces.
2. It still owns both **local device** and **aggregator** API surfaces.
3. The biggest delta since v1 is not the existence of the satellite routes, but that they are now fully implemented and materially coupled to the runtime/NVS/concurrency model.
4. The dashboard/test/mock integration surface is now broader because Phase X split the dashboard runtime into modules/components while preserving the same firmware-owned route families.

---

## 6. Data Model and Persistence Inventory

### 6.1 Runtime model

| Type | Role | Ownership |
|---|---|---|
| `MetricDef` | metric schema for a device category | mixed (definitions generated in current block) |
| `MetricState` | runtime value / accumulator / validity / history pointer | hand-maintained type, generated instance topology |
| `SensorEntity` | canonical runtime device model | hand-maintained type, generated instance topology |
| `devices[]` | active runtime topology | generated |

### 6.2 Persisted history model

| Type | Role | Coupling / risk |
|---|---|---|
| `HistEntry` | atomic time/value entry | low individually, pervasive in all history paths |
| `HistoryBuffer` | RAM ring buffer | medium; used by live runtime and history serving |
| `HistoryMeta` | persisted global metadata | very high; migration + schema guard |
| `SegmentSnapshotHeader` | per-segment schema/header | very high; validates compatibility |
| `SegmentSnapshot` | persisted hourly blob | extreme; physical size depends on `NUM_SENSORS` |

### 6.3 Persistence geometry and invariants

| Constant / field | Current value / meaning |
|---|---|
| `NUM_DEVICES` | 5 total runtime devices |
| `NUM_ENV_SENSORS` | 3 environmental/persisted devices |
| `NUM_SENSORS` | alias to `NUM_ENV_SENSORS` |
| `PERSIST_SEGMENT_HOURS` | 1 hour |
| `PERSIST_POINTS_PER_SEGMENT` | 4 |
| `RAM_SEGMENTS` | `HISTORY_POINTS_PER_SERIES / PERSIST_POINTS_PER_SEGMENT` |
| `PERSIST_SLOTS` | `PERSIST_DAYS * (24 / PERSIST_SEGMENT_HOURS)` |
| `HISTORY_NAMESPACE` | `histv631` |
| `HISTORY_PARTITION_LABEL` | `history` |
| segment key scheme | `seg_%03d` |
| meta key | `hist_meta` |

### 6.4 Persisted-history sensitivity points

The following remain the dominant schema constraints for any future structural split:

- `SegmentSnapshot` dimensions directly embed `NUM_SENSORS`
- `HistoryMeta`/`SegmentSnapshotHeader` validate current compile-time dimensions
- `restore_from_nvs()` performs migration, recalibration, and cleanup work, not just restore
- `handle_history_()` merges flash-backed history and RAM history
- import logic overlays or appends into persisted hourly slots

That means BUG-045 / 046 / 048 are still defining architectural constraints at HEAD.

### 6.5 Satellite persistence model (Phase D)

| Item | Current-state contract |
|---|---|
| NVS namespace | `agg_sats` |
| count key | `count` (`u8`) |
| per-satellite keys | `s{i}_id`, `s{i}_name`, `s{i}_url`, `s{i}_poll` |
| runtime carrier | `SatelliteCache` |
| deferred-save carrier | `SatelliteNVSSnapshot` |
| startup load path | `init_satellite_caches_()` → NVS first → compile-time defaults fallback → NVS seed |
| mutation persistence paths | add = direct single save; delete = deferred snapshot save; reset = deferred reset + default reseed |
| race-protection aid | `satellite_config_generation` |

### 6.6 Important current-state nuance

The full aggregator subsystem is compiled under `#if AGGREGATOR_ENABLED`, but the current generated `src/aggregator_config.h` on default/CI-safe HEAD sets `AGGREGATOR_ENABLED 0`. That means:

- the code is part of the file’s current architecture inventory
- the default generated build path does not exercise it unless a non-default config/provision workflow is used

That matters for Phase Y planning because the code footprint is real even when the default generated config keeps it off.

---

## 7. Runtime Concurrency / Tasking / Locking Inventory

### 7.1 Explicit task creation inventory

| Task / runtime context | Spawn path | Stack size | Current role |
|---|---|---:|---|
| `ping_adapter` (`PingAdapter::ping_task_`) | `PingAdapter::start()` | 4096 | periodic ICMP probe feeding network metrics |
| `hist_reboot` (`reboot_task_`) | `schedule_reboot_()` | 2048 | deferred reboot |
| `hist_delete` (`delete_data_task_`) | `schedule_delete_data_()` | 8192 | deferred history erase |
| `agg_poll` (`aggregator_poll_task`) | `start_aggregator_task()` | 10240 | aggregator polling/cache refresh |
| `agg_reset_sats` (`reset_satellites_task_`) | `schedule_reset_satellites_()` | 8192 | deferred factory reset of runtime satellites |
| `agg_nvs_save` (`save_satellites_nvs_task_`) | `schedule_save_satellites_nvs_()` | 8192 | deferred snapshot-based NVS save |

### 7.2 Deferred-task pairs

The file now uses **four** explicit deferred-task patterns:

- `reboot_task_()` / `schedule_reboot_()`
- `delete_data_task_()` / `schedule_delete_data_()`
- `reset_satellites_task_()` / `schedule_reset_satellites_()`
- `save_satellites_nvs_task_()` / `schedule_save_satellites_nvs_()`

The first three were the relevant shape in v1. The fourth pair is a meaningful Phase D addition because runtime satellite deletion now includes deferred NVS persistence via snapshot handoff.

### 7.3 Locking and coordination objects

| Primitive | Current use |
|---|---|
| `s_cache_mutex` | protects shared reads/writes of `satellite_caches[]` |
| `AGG_LOCK()` / `AGG_UNLOCK()` | macro wrappers around the mutex |
| `PingAdapter::sem_` | ping completion synchronization |
| `s_delete_data_in_progress` | prevents duplicate history erase task scheduling |
| `s_reset_satellites_in_progress` | prevents duplicate reset scheduling |
| `s_nvs_save_in_progress` | prevents duplicate deferred NVS-save scheduling |
| `satellite_config_generation` | invalidates in-flight aggregator poll operations after topology change |

### 7.4 Shared buffer ownership model

| Buffer / array | Intended owner / execution context |
|---|---|
| generated `HistoryBuffer` statics | runtime metrics + history handlers |
| `devices[]` | shared runtime model; written by adapters / read by handlers |
| `s_fetch_tmp` | aggregator polling task only |
| `s_proxy_tmp` | web-handler context only |
| `satellite_caches[]` | shared between aggregator polling task and web handlers under mutex |
| `import_*` mutable state inside `HistoryWebHandler` | request/handler-owned state, not background-task-safe |

### 7.5 Yield / starvation safeguards

The file still codifies BUG-043 protections directly:

- `NVS_SCAN_YIELD_INTERVAL = 2`
- `maybe_yield_nvs_scan_()` delays 5 ms every 2 iterations
- applied in:
  - `restore_from_nvs()`
  - `build_import_epoch_map_()`
  - `handle_history_()`

That means any Phase Y structural split that moves these loops must preserve the current scheduler-yield behavior, not merely the loop logic.

### 7.6 Concurrency conclusion

The file is coupled not only by shared data and routes, but also by **execution context**:

- httpd task vs deferred task
- handler context vs background poll task
- mutex-protected shared cache vs single-owner temp buffers
- boot-time ordering vs runtime mutation

That concurrency model is materially larger than in v1 because Phase D added runtime satellite mutation and deferred NVS-save behavior.

---

## 8. Integration Surface Map

### 8.1 Generator / build / firmware integration

| File | Current relationship to `sensor_history_multi.h` |
|---|---|
| `scripts/render_sensor_config.py` | canonical owner of in-file marker blocks and related generated artifacts |
| `scripts/sensor_manifest_lib.py` | manifest/config contracts consumed by generator and, indirectly, by the file’s route/runtime expectations |
| `scripts/preflight.sh` | architectural guardrail layer; now expanded to 68 checks |
| `scripts/provision.sh` | mandatory local board-config switch entry point; auto-runs `render_sensor_config.py --write` and prints the full 8-step pipeline |
| `firmware/esp32-c3-multi-sensor.yaml` | include order and `on_boot`/interval wiring for registration and startup tasks |
| `firmware/boards/esp32-c3-supermini.yaml` | board-profile example, including local `web_server_idf` override wiring |
| `src/gateway_manifest.h` | generated manifest served by `/api/manifest` |
| `src/aggregator_config.h` | generated aggregator enablement/topology dependency |

### 8.2 Dashboard contract surface (post-Phase X)

| File(s) | Current relationship |
|---|---|
| `dashboard/core/config.js` | boot/config module; now part of generated dashboard assembly rather than a monolith |
| `dashboard/core/history.js` | current history-fetch logic and route-consumption pattern |
| `dashboard/components/gateway-panel/index.js` | aggregator route consumer, including runtime satellite management UX |
| `dashboard/dashboard.js` | **generated artifact**, not hand-maintained source |
| `dashboard/dashboard.html` | **generated artifact** via build pipeline, not hand-maintained source |

### 8.3 Test contract surface (post-Phase X)

| File(s) | Current relationship |
|---|---|
| `tests/browser/boot-structure.spec.js` | manifest/boot contract assumptions |
| `tests/browser/history-charts.spec.js` | history route assumptions |
| `tests/browser/aggregator.spec.js` | aggregator cache/proxy/gateway assumptions |
| `tests/browser/satellite-management.spec.js` | add/delete/test/reset runtime-management assumptions |
| `tests/browser/test-helpers.js` | shared browser-test runtime helpers after spec split |
| `tests/mock-server/server.js` | mock implementation of route families |
| `tests/fixtures/generate-fixtures.js` | fixture-generation assumptions tied to manifest and endpoint shape |

### 8.4 Local HTTP stack dependency

| File | Current relationship |
|---|---|
| `firmware/local_components/web_server_idf/web_server_idf.cpp` | patched local HTTP stack override: 16 KB httpd stack, DELETE registration, expanded status mapping |
| `scripts/patch-esphome-httpd-stack.sh` | operational guardrail that copies/patches/verifies the local override |

### 8.5 Lessons / documentation surface (post-Phase X)

| File(s) | Current relationship |
|---|---|
| `Docs/lessons/index.md` | entry-point index for bug/lesson corpus |
| `Docs/lessons/firmware.md` | firmware-domain constraints for this file |
| `Docs/lessons/dashboard.md` | dashboard-side constraints on how routes are consumed |
| `Docs/lessons/operations.md` | operator / validation workflow constraints |
| `Docs/lessons/build-pipeline.md` | generator/pipeline/provision constraints |
| `Docs/writing-guide/*` | post-split prompt/writing guidance; replaces monolithic writing guide as current structure |

### 8.6 Current integration-surface conclusions

1. The dashboard is no longer a single file. The firmware contract is now consumed by a **component architecture** and a generated artifact pipeline.
2. The browser suite is no longer a single `dashboard.spec.js`. It is a **domain-scoped spec set plus shared test helpers**.
3. The lessons corpus is no longer a single content source. The real content now lives under `Docs/lessons/*.md`.
4. `Docs/configuring-sensors.md` is **not present** as a current input. The file still contains a stale comment referencing it, but there is no current standalone sensor-configuration document to cite as source.

---

## 9. Natural Subsystem Boundaries

> **Planning focus:** Phase X used contiguous-slice extraction where possible. Phase Y planning needs to know which boundaries still map to contiguous slices and which do not.

| Candidate subsystem | v1 assessment still valid? | Phase D / Phase X effect | Approx. current range(s) | Contiguous or scattered? | Phase Y note |
|---|---|---|---|---|---|
| Generated topology / runtime model seam | Yes | Stronger now because more generated artifacts surround the file | ~261–625, but dependencies are global | **Contiguous code, scattered dependencies** | Good for ownership analysis, poor for manual extraction without generator-first strategy |
| Persisted history / NVS core | Yes | Still dominant risk center | ~626–1870, plus route touchpoints later | **Mostly contiguous core, scattered consumers** | Could be carved as a service later, but not as a single no-touch slice without adapter work |
| Import engine | Yes | Still tightly bound to persistence; no Phase X relief | helper/state in class + persistence coupling | **Scattered** | Not a good first contiguous-slice target |
| Ping adapter | Yes | Boundary still clean | ~1951–2235 | **Contiguous** | Good candidate for Phase X-style extraction if desired |
| Aggregator runtime core (cache/poll/NVS/probe) | Partially | Phase D made it much larger and more self-consistent | ~2236–3290 | **Contiguous top-level block** | Good slice candidate **only** for the non-route portion |
| Aggregator endpoint layer | Weaker as single boundary | Phase D added real mutation handlers | ~4041–4295 | **Contiguous block inside class** | Second island of the aggregator subsystem |
| Full aggregator subsystem | Changed materially | v1 treated it as a nested subsystem; now it spans runtime + routes + deferred save/reset | ~2236–3290 and ~4041–4295 | **Scattered across two islands** | Not a one-slice split anymore |
| Auth / management layer | Yes | Phase D adds more management-state and mutation behavior | task helpers ~1871–1950 + class methods in route block | **Scattered** | Structural extraction would need explicit seams for task scheduling and auth policy |
| Route dispatch / API gateway | Yes | Even more central after dashboard/test split | ~3291–4295 | **Contiguous** | Large contiguous class, but very cross-coupled |
| Registration / orchestration | Yes | Unchanged in principle | ~4296–4325 | **Contiguous** | Tiny tail; easy to isolate conceptually |

### 9.1 What changed since v1 boundary analysis?

The biggest boundary change is the **aggregator subsystem**:

- **v1 state:** aggregator was already a substantial nested subsystem, but satellite add/delete/test were still described as placeholders/stubs.
- **v2 state:** aggregator now spans:
  - top-level runtime/cache/NVS/poll/probe helpers
  - deferred task helpers
  - mutation-safe snapshot persistence
  - route handlers inside `HistoryWebHandler`
  - dashboard/runtime-management test and UI consumers

So the aggregator is now better understood as a **two-island subsystem** rather than a single embedded block.

### 9.2 Best current contiguous-slice candidates

| Candidate | Why it is viable |
|---|---|
| `PingAdapter` block | single contiguous class, low fan-out, clear runtime purpose |
| registration/orchestration tail | very small, clearly bounded |
| top-level aggregator runtime block | contiguous, coherent, but only half of the aggregator subsystem |
| aggregator endpoint cluster inside `HistoryWebHandler` | contiguous within the class, but only the route half |

### 9.3 Poor contiguous-slice candidates

| Candidate | Why it is poor |
|---|---|
| full persistence subsystem | core is contiguous, but route/import/status/history serving touchpoints are scattered |
| import engine | state + helpers + route handlers + persistence coupling are interleaved |
| full aggregator subsystem | split across two islands plus task helpers |
| auth/management subsystem | class logic depends on top-level deferred task helpers |

---

## 10. High-Risk Refactor Zones

| Area | Why high-risk | What breaks if mishandled | Current guardrails |
|---|---|---|---|
| `NUM_DEVICES` / `NUM_ENV_SENSORS` / `NUM_SENSORS` split | runtime vs persisted-width separation is mandatory | history schema widening, retained-history invalidation | BUG-045/046/048 lessons, generator contract, preflight checks |
| `HistoryMeta` / `SegmentSnapshot*` layout and migration | physical blob compatibility and repair logic live here | retained-history loss, repeated stale-meta loop, ghost-slot retries | BUG-046/048 fixes, lessons, preflight expectations |
| `restore_from_nvs()` | mixes restore, migration, recalibration, cleanup | empty history, repeated retries, wrong `valid_segments` | lesson corpus, real-device behavior history |
| `handle_history_()` | merges flash + RAM + yield + response construction | instability, truncation, duplicate data, memory regressions | BUG-043 protections, no-streaming approach, history tests |
| `fetch_to_buffer()` + fixed buffers | underpins aggregator fetch/proxy behavior | truncation, silent corruption, invalid composed responses | BUG-063/074/085 lessons |
| runtime satellite mutation + NVS save | topology mutation and persistence are now coupled | torn reads, stale NVS, delete/add inconsistency | `satellite_config_generation`, snapshot save task, mutex discipline |
| `HistoryWebHandler` dispatcher | owns public route contract and method routing | dashboard/test/mock breakage, wrong 405/404 behavior | browser specs, mock server, method-handling lessons |
| local HTTP stack assumptions | handler viability depends on patched `web_server_idf` behavior | POST/body failures, stack overflows, DELETE breakage, wrong status codes | local component override + patch script + firmware lessons |
| generated marker seam | small code region, large semantic blast radius | generator/runtime/dashboard/test drift | `render_sensor_config.py --check`, preflight, pipeline discipline |

---

## 11. Guardrails Already Present

### 11.1 Generator and pipeline guardrails

- `scripts/render_sensor_config.py --check` guards generated artifact sync
- canonical 8-step regeneration pipeline now documented and expected:
  1. `bundle-dashboard.sh --write`
  2. `render_sensor_config.py --write`
  3. `generate-fixtures.js`
  4. `render_sensor_config.py --write`
  5. `build-dashboard.sh --write`
  6. `minify-dashboard.sh`
  7. `generate-header.sh`
  8. `render_sensor_config.py --check`
- `scripts/provision.sh` is now the mandatory local board-config switch entry point

### 11.2 Preflight / CI guardrails

- `scripts/preflight.sh` has expanded to **68 checks**
- includes `dashboard_component_files()` to verify all **36** dashboard source files exist
- continues to enforce key history/manifest/generator invariants
- Phase X added bundle/build-oriented checks around the generated dashboard architecture and artifact flow

### 11.3 Test guardrails

- browser tests are now domain-scoped rather than monolithic
- `tests/browser/test-helpers.js` centralizes shared helper behavior
- `tests/mock-server/server.js` preserves contract-faithful route families
- `tests/fixtures/generate-fixtures.js` encodes fixture-level API shape expectations

### 11.4 Local HTTP stack guardrails

- local `web_server_idf` override raises httpd stack to 16 KB
- DELETE registration is patched into the local component
- expanded HTTP status mapping is preserved in the local override
- `scripts/patch-esphome-httpd-stack.sh --check` verifies required patch presence

### 11.5 Lessons / rules guardrails now relevant to this file

The post-split lessons corpus codifies the historical failure modes that most constrain Phase Y work, especially:

- BUG-043 family (history scan / scheduling / response construction)
- BUG-045 / 046 / 048 family (`NUM_SENSORS`, migration, unreadable blobs)
- BUG-075 / 076 / 077 / 078 / 079 family (stack size, body handling, ESP-IDF types, status mapping, DELETE routing)
- BUG-080 / 081 + LESSON-OPS-111 (dashboard settings panel / stale DOM interaction with runtime-management routes)
- LESSON-OPS-091 / 116 / 117 / 118 / 119 / 120 (pipeline order, provision workflow, generated artifact handling, contiguous-slice planning, three-pass build)

### 11.6 Critical Rules 47–57 context

Phase X added a new rule cluster around:

- generated artifact handling
- bundle-first pipeline order
- `provision.sh` workflow discipline
- component/file existence enforcement
- build-stage ordering assumptions required by the componentized dashboard

Those rules now form part of the architecture boundary around this file even though they live outside it.

---

## 12. Missing Guardrails / Weak Spots

### 12.1 Addressed since v1

The following v1 weak spots are materially improved:

- dashboard source is no longer a monolith; source ownership is clearer
- browser tests are no longer one large spec file
- lessons and writing guidance have been split into domain-specific files
- preflight/build pipeline coverage is substantially broader
- local board switching now has a named operational entry point (`provision.sh`)

### 12.2 Remaining weak spots

| Weak spot | Why it still matters |
|---|---|
| No machine-checked route inventory / auth matrix | route existence is tested indirectly, but not from a single authoritative map |
| No explicit `sizeof(SegmentSnapshot)` guard in preflight | bug history says this is one of the most dangerous drift points |
| No standalone current sensor-configuration workflow doc | removed `Docs/configuring-sensors.md` leaves a documentation gap; header comment is stale |
| `provision.sh` only auto-runs the render step | operator must still manually run the remaining 7 steps |
| Full aggregator subsystem is not exercised by default CI-safe generated config | runtime-management code can drift if non-default config workflows are skipped |
| No structural guard preventing further responsibility accumulation in `HistoryWebHandler` | class remains the sink for new route logic |
| No automated architecture map for contiguous/scattered subsystem status | planning still requires manual rediscovery without a document like this one |
| Some planning docs lag the current repo state | code/tree on `main` must remain authoritative over stale narrative text |

---

## 13. Delta Analysis: v1 → v2

| Area | v1 state | v2 state | Impact on Phase Y planning |
|---|---|---|---|
| File size | ~2.2K–2.5K lines (approx.) | **4,325 lines** | Much larger split scope; Phase Y should assume a heavier decomposition pass |
| Named struct inventory | 9 primary structs (approx.) | **10 named struct types** (9 top-level + nested `EpochSlotEntry`) | Type inventory is broader and more explicit |
| Classes | 3 | **3** | Same count, but responsibilities inside `HistoryWebHandler` and aggregator support grew |
| Top-level helper functions | 30+ (approx.) | **38** | More helper surface, especially aggregator/satellite management |
| Endpoint-specific handlers | ~20 | **21** | Route surface slightly larger; more importantly, more of it is now implemented runtime-management logic |
| Deferred-task pairs | 3 | **4** | Added deferred snapshot-based NVS save path |
| Aggregator subsystem | polling/cache/proxy plus placeholder mutation routes | implemented add/delete/test/reset + satellite NVS + generation counter + snapshot save | Aggregator is now a true two-island subsystem, not a lightweight extension |
| Satellite management routes | listed as placeholder/stubbed routes | fully implemented handlers with real runtime/NVS behavior | Phase Y must treat satellite management as real architecture, not future scope |
| Dashboard architecture | monolithic dashboard mental model still present around file | modular `dashboard/core/` + `dashboard/components/*/`, generated artifacts | Integration surface is broader and file-path assumptions changed |
| Browser test architecture | monolithic `dashboard.spec.js` era | domain-scoped specs + `test-helpers.js` | Route/contract validation is more granular and more distributed |
| Lessons/docs structure | monolithic docs source still assumed by older inventory | `Docs/lessons/*.md` and `Docs/writing-guide/*` are the live content structure | All planning inputs must use post-Phase X paths |
| Pipeline model | simpler regeneration story | 8-step canonical pipeline + `provision.sh` | Refactor planning must treat artifact order as a hard constraint |
| Preflight | materially smaller than current | **68 checks** + `dashboard_component_files()` for 36 files | More guardrails already exist; Phase Y should build on them rather than re-inventing them |
| `Docs/configuring-sensors.md` | older ecosystem still referenced it | confirmed absent as current input | This is now a documentation gap, not a planning input |
| Boundary analysis | aggregator already nested, but smaller | aggregator materially expanded and split across runtime + route islands | Contiguous-slice viability changed; full aggregator split is no longer one-slice-friendly |
| Generated artifact rules | pre-Phase X rule set | critical rules 47–57 now in force | Phase Y must preserve generated-artifact discipline |

### 13.1 Main planning consequence of the delta

The single most important difference between v1 and v2 is:

> The file is not just larger; its **largest growth area is a new implemented runtime-management subsystem** that cuts across concurrency, persistence, route dispatch, and dashboard integration.

That changes the decomposition problem. Phase Y can no longer think only in terms of “history core + route wrapper.” It must plan around:

- a persisted-history subsystem
- a generated runtime topology seam
- a large route/auth host class
- a two-island aggregator subsystem
- tasking/locking/HTTP-stack constraints that now extend into runtime satellite mutation

---

## 14. Inputs Recommended for the Phase Y Refactor Planning Session

### 14.1 Read first

1. `Docs/phase-Y-current-state-inventory-sensor-history-v2.md`
2. `dashboard/sensor_history_multi.h`
3. `scripts/render_sensor_config.py`
4. `scripts/sensor_manifest_lib.py`
5. `firmware/esp32-c3-multi-sensor.yaml`
6. `src/gateway_manifest.h`
7. `src/aggregator_config.h`
8. `dashboard/core/config.js`
9. `dashboard/core/history.js`
10. `dashboard/components/gateway-panel/index.js`
11. `tests/browser/boot-structure.spec.js`
12. `tests/browser/history-charts.spec.js`
13. `tests/browser/aggregator.spec.js`
14. `tests/browser/satellite-management.spec.js`
15. `tests/browser/test-helpers.js`
16. `tests/mock-server/server.js`
17. `tests/fixtures/generate-fixtures.js`
18. `scripts/preflight.sh`
19. `scripts/provision.sh`
20. `firmware/local_components/web_server_idf/web_server_idf.cpp`
21. `scripts/patch-esphome-httpd-stack.sh`
22. `Docs/lessons/index.md`
23. `Docs/lessons/firmware.md`
24. `Docs/lessons/dashboard.md`
25. `Docs/lessons/operations.md`
26. `Docs/lessons/build-pipeline.md`

### 14.2 Findings that should shape the future plan

- Treat `sensor_history_multi.h` as a **multi-subsystem integration unit**, not as “history code.”
- Preserve the **generated-vs-hand seam** as a first-class architectural boundary.
- Preserve the **persisted-history schema** as a no-behavior-change zone unless migration work is explicitly in scope.
- Preserve the **public route contract**: paths, methods, auth policy, payload shape, and legacy compatibility behavior.
- Preserve the **local HTTP stack assumptions** that forced the current deferred-task and body-handling patterns.
- Treat the **aggregator subsystem** as a larger, implemented runtime-management subsystem, not a stub.

### 14.3 Areas that should be treated as “no behavior change / structural only” in initial Phase Y planning

- `HistoryMeta` / `SegmentSnapshot*` layout and migration behavior
- `NUM_DEVICES` / `NUM_ENV_SENSORS` / `NUM_SENSORS` semantics
- route paths and canonical methods
- route auth policy, including the current unauthenticated `add-satellite` exception unless security scope is explicitly widened
- dashboard boot contract (`/api/manifest` primary, `/sensors.json` fallback)
- BUG-043 yield / no-streaming history behavior
- deferred-task pattern for NVS-heavy or management-heavy work
- local `web_server_idf` override requirements
- generator-owned marker blocks and their emitted semantics

### 14.4 Contiguous vs scattered subsystem summary for Phase X-style extraction

| Subsystem / slice candidate | Status |
|---|---|
| `PingAdapter` | **Contiguous** — good Phase X-style slice candidate |
| registration/orchestration tail | **Contiguous** — trivial candidate |
| top-level aggregator runtime block | **Contiguous** — but only one half of aggregator subsystem |
| aggregator route-handler cluster | **Contiguous** — second half of aggregator subsystem |
| generated marker blocks | **Contiguous but generator-owned** — not a manual extraction target |
| persistence/NVS core | **Mostly contiguous, but behaviorally scattered** |
| import engine | **Scattered** |
| auth/management subsystem | **Scattered** |
| full aggregator subsystem | **Scattered across two islands** |
| full route/API gateway layer | **Contiguous class, but heavily cross-coupled** |

### 14.5 Final planning note

The removed `Docs/configuring-sensors.md` should be treated as a **known documentation gap**, not as an input dependency for Phase Y planning. Any future refactor plan that relies on current sensor-configuration workflow should instead anchor on:

- `scripts/render_sensor_config.py`
- `scripts/sensor_manifest_lib.py`
- `scripts/provision.sh`
- the generated-count semantics visible in `sensor_history_multi.h`

That is the current authoritative configuration surface.
