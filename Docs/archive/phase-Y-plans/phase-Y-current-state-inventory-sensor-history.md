# Phase Y Current-State Inventory — `sensor_history_multi.h`

## 1. Executive Summary

`dashboard/sensor_history_multi.h` is no longer a narrow “history persistence” header.

In its current state, it is a **large multi-role integration unit** that combines:

- flash/NVS history schema definition and migration logic
- 24h RAM history buffering
- runtime device and metric model ownership
- generated sensor/entity/config blocks
- legacy and v2 HTTP/API route handling
- embedded dashboard payload serving
- CSV import/merge/write flows
- management authentication, lockout, and deferred destructive actions
- external-push ingest handling
- network ping adapter runtime
- aggregator polling/cache/NVS runtime
- boot-time registration and orchestration glue

That scope makes it one of the highest-coupled files in the repository. The file is both a **stateful runtime subsystem** and a **public API surface owner**. It also sits at the seam between **generated configuration** and **hand-maintained logic**, which is the central architectural constraint any future Phase Y refactor must preserve.

A later refactor-planning session should treat this file as a **monolith made of several real subsystems that already exist implicitly**, not as a single-purpose history module.

---

## 2. Current File Metrics

The counts below are **approximate** where noted. The file is large enough that precise counts are less important than understanding its shape.

| Metric | Approximate current value | Notes |
|---|---:|---|
| File size | ~2.2K–2.5K lines | Large single-header implementation unit |
| Primary structs | 9 | `HistEntry`, `MetricDef`, `MetricState`, `SensorEntity`, `HistoryMeta`, `SegmentSnapshotHeader`, `SegmentSnapshot`, `SatelliteCache`, `EpochSlotEntry` |
| Primary classes | 3 | `HistoryBuffer`, `PingAdapter`, `HistoryWebHandler` |
| Top-level helper / utility functions | 30+ | Persistence, NVS, snapshot, task, aggregator, registration helpers |
| Endpoint-specific handler methods | ~20 | Mostly methods on `HistoryWebHandler` |
| Deferred-task helper functions | 6 | `reboot_task_`/`schedule_reboot_`, `delete_data_task_`/`schedule_delete_data_`, `reset_satellites_task_`/`schedule_reset_satellites_` |
| Generator marker-delimited regions in this file | 2 | `SENSOR_MANIFEST:HEADER`, `SENSOR_MANIFEST:ENTITY` |
| Compile-time constants / macros | 20+ | History/auth/schema/ping/aggregator/config constants |
| Static shared buffers | Multiple | History snapshots, `s_fetch_tmp`, `s_proxy_tmp`, generated `HistoryBuffer` instances |
| Runtime device count in current generated block | 5 | 3 environmental + 1 network + 1 system |
| Persisted environmental sensor count in current generated block | 3 | Deliberately separated from total device count |

### Observed structural shape

The file has four distinct forms of code mixed together:

1. **Schema/state definitions**  
2. **Long-lived runtime services**  
3. **HTTP dispatch and endpoint implementations**  
4. **Generated topology/model blocks embedded inside hand-maintained code**

That mixed shape is more important than the exact LOC count.

---

## 3. Top-Level Responsibility Map

### Responsibility map

| Responsibility area | What it owns | Ownership | Move risk | Why the move risk is high or low |
|---|---|---|---|---|
| Compile-time constants and schema definitions | History window, retention, auth timing, segment geometry, schema magic/version, aggregator buffer sizing | Hand-maintained, plus generated constants injected nearby | High | These constants dimension persisted structs and gate handler behavior |
| Ring buffer / history buffer primitives | `HistEntry`, `HistoryBuffer`, CSV append/stream helpers | Hand-maintained | Medium | Internally cohesive, but called from persistence and route code |
| Runtime sensor/entity model | `MetricDef`, `MetricState`, `SensorEntity`, runtime state conventions | Mixed | High | Hand code assumes generated metric ordering and category conventions |
| Generated sensor/entity arrays | Metric arrays, `HistoryBuffer` instances, `devices[]`, `NUM_DEVICES`, `NUM_ENV_SENSORS`, `NUM_SENSORS`, ping defines | Generated | High | This is the generator/runtime seam; drift here breaks persistence, routing, dashboard expectations, and tests |
| History persistence / restore / snapshot logic | NVS open/init, meta load/save, snapshot load/save, restore, slot math | Hand-maintained | Very high | This is persisted-data behavior; schema/layout changes can orphan retained history |
| Import/export logic | Import state, epoch-map merge flow, snapshot overlay/write, CSV response generation | Hand-maintained | High | Couples persistence layout, route semantics, auth, and RAM restore |
| Management auth / lockout / action scheduling | Basic auth parsing, lockout counters, management route gate, reboot/delete/reset task scheduling | Hand-maintained | High | Small code surface, but failure here affects destructive-route safety and HTTP-stack stability |
| Ping adapter | `PingAdapter`, FreeRTOS task, lwIP/ESP ping integration, metric feeding | Hand-maintained but generator-index-coupled | Medium | Subsystem boundary is plausible, but currently tied to generated device index/constants |
| Aggregator runtime/cache/NVS/config | `SatelliteCache`, NVS satellite persistence, polling task, shared cache, proxy fetches | Mixed | Very high | Large embedded subsystem with its own tasking, locking, buffers, route ownership, and generated config dependency |
| HTTP route registration / dispatch | `canHandle()`, `handleRequest()`, route family recognition, method gating | Hand-maintained | High | This is the real external contract surface for dashboard/tests/mock server |
| Endpoint implementation groups | Legacy history, manifest, v2 live/history, ingest, import, management, aggregator, dashboard/static | Hand-maintained | High | Behavior is externally consumed by dashboard, fixtures, Playwright, and operator workflows |
| Registration/orchestration entrypoint | `register_history_handler()`, boot restore, web handler registration | Hand-maintained | High | Boot order and registration order are behaviorally significant on this HTTP stack |

### Observations

- The file is a **subsystem host**, not a utility header.
- The **generated entity block** is not isolated from hand logic. The hand-maintained code reaches into generated arrays and indices directly.
- The **aggregator code path** is effectively a nested subsystem inside the same file.
- The **route layer** is broad enough that it functions as an API gateway for the whole firmware.

---

## 4. Generated vs Hand-Maintained Ownership

### Ownership table

| Area / block | Current ownership | Generator / source of truth | Notes |
|---|---|---|---|
| `SENSOR_MANIFEST:HEADER` region | Generated | `scripts/render_sensor_config.py` | Inserts comments/constants guidance around generated topology |
| `SENSOR_MANIFEST:ENTITY` region | Generated | `scripts/render_sensor_config.py` using `scripts/sensor_manifest_lib.py` contracts and `config/sensors*.json` / gateway config | Emits metrics arrays, `HistoryBuffer` statics, `devices[]`, `NUM_*` constants, ping defines |
| `gateway_manifest.h` include target | Generated file dependency | `scripts/render_sensor_config.py` + `scripts/sensor_manifest_lib.py` | `sensor_history_multi.h` serves its JSON directly |
| `aggregator_config.h` include target | Generated file dependency | `scripts/render_sensor_config.py` | Controls `AGGREGATOR_ENABLED`, `MAX_SATELLITES`, compile-time satellite arrays |
| All persistence code | Hand-maintained | N/A | Schema-sensitive and operationally constrained by lessons/bugs |
| All route dispatch and handlers | Hand-maintained | N/A | Public HTTP/API contract owner |
| Import engine | Hand-maintained | N/A | Strongly coupled to environmental-history schema |
| Auth / lockout / deferred task logic | Hand-maintained | N/A | Safety-critical runtime behavior |
| Ping adapter implementation | Hand-maintained | N/A | Depends on generated `PING_DEVICE_INDEX` / `PING_TARGET` |
| Aggregator polling/cache runtime | Hand-maintained | N/A for logic, generated for topology/config | Mixed subsystem: logic is hand code, topology/config is generated |
| Registration/orchestration | Hand-maintained | N/A | Boot-order coupling with YAML and ESPHome stack |

### Marker-delimited generated regions

The generated regions in `sensor_history_multi.h` are explicitly bounded by:

- `// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>` … `END`
- `// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>` … `END`

`render_sensor_config.py` owns those regions directly. It updates them in-place inside an otherwise hand-maintained file.

That ownership model has three consequences:

#### 1. The generated regions are small in area, but large in impact

Those two blocks determine:

- total runtime device count
- persisted environmental sensor count
- device categories
- adapter identities
- metric sets
- metric ordering
- static history-buffer allocation
- device array layout
- ping-device presence/index

Hand-maintained code elsewhere in the file assumes those outputs are valid and stable.

#### 2. Mixed ownership exists around the boundaries, not only inside the markers

The highest drift risk is not the generator block itself. It is the **adjacent hand-written code that depends on generated conventions**, for example:

- persistence code assumes `NUM_SENSORS` means **environmental persisted width**, not all devices
- legacy history handlers assume `metric_states[0]` is temp and `metric_states[1]` is hum for environmental devices
- ping startup assumes generated `PING_DEVICE_INDEX`
- import logic assumes only environmental sensor slots map into persisted snapshots
- route behavior varies by generated category/adaptor fields
- comments and documentation in the hand-maintained file reference generated facts

#### 3. Ownership drift can occur without merge conflicts

A generator change can be locally “correct” while still breaking hand-maintained logic if it changes:

- metric ordering
- category numbering
- device-array membership
- `NUM_*` aliasing
- history-enabled flags
- manifest/history URL conventions

### Drift risks created by this model

| Drift risk | Failure mode |
|---|---|
| Generator changes `NUM_SENSORS` semantics | Persisted schema invalidation or silent NVS incompatibility |
| Generator changes metric ordering | Wrong history series or wrong live metric mapping |
| Generator changes category/adaptor expectations | Existing endpoints become semantically wrong for new device types |
| Generator changes device set without corresponding dashboard/test regeneration | Dashboard boot, fixtures, and tests diverge |
| Hand-maintained code updated without rerunning generator | Repo appears locally valid but generated artifacts no longer match |
| Operator configs present during generation | Commit-bound generated artifacts can leak deployment-specific state |

The current model is workable, but only because `render_sensor_config.py --check`, `preflight.sh`, and the test/fixture suite act as compensating controls.

---

## 5. Endpoint Inventory

The table below inventories the route surface currently owned by `sensor_history_multi.h`.

### A. Legacy history routes

| Route | Method(s) | Functional owner | Auth | Likely consumer | Sensitivity / risk |
|---|---|---|---|---|---|
| `/history/{id}/temp` | GET | Legacy environmental history | None | Dashboard environmental charts; mock server; fixture CSV generation assumptions | High route-compatibility risk; environmental-only legacy surface |
| `/history/{id}/hum` | GET | Legacy environmental history | None | Dashboard environmental charts; mock server; fixtures | Same as above |

Notes:
- These routes intentionally 404 for non-environmental devices.
- They remain part of the compatibility contract even after v2 APIs were added.

### B. Dashboard / static routes

| Route | Method(s) | Functional owner | Auth | Likely consumer | Sensitivity / risk |
|---|---|---|---|---|---|
| `/dashboard` | GET | Embedded dashboard serving | None | Browser users | Medium; redirects not used, handler serves content directly |
| `/dashboard.html` | GET | Embedded dashboard serving | None | Browser users; Playwright; mock server parity | High; boot entrypoint and payload size/stability matter |
| `/dashboard-download` | GET | Embedded dashboard attachment download | None | Operator download workflow | Medium; payload-serving correctness |
| `/favicon.ico` | GET | Null response / suppression path | None | Browsers | Medium; handler-ordering behavior with ESPHome catch-all is historically brittle |

### C. Status / manifest / storage routes

| Route | Method(s) | Functional owner | Auth | Likely consumer | Sensitivity / risk |
|---|---|---|---|---|---|
| `/sensors.json` | GET | Legacy v1 projection | None | Dashboard fallback boot path; manifest tests; fixtures | High backward-compatibility importance |
| `/api/manifest` | GET | Manifest v2 serving via generated `gateway_manifest.h` | None | Dashboard primary boot path; manifest tests; aggregator polling; mock server | Very high; central configuration/bootstrap contract |
| `/api/status` | GET | Status snapshot | None | Dashboard device/about cards; aggregator polling; tests; mock server | High; schema grows over phases and feeds operator diagnostics |
| `/api/storage-stats` | GET | Storage diagnostics | None | Dashboard storage card; mock server | Medium-high; retention and partition figures consumed by UI |

### D. v2 API routes

| Route | Method(s) | Functional owner | Auth | Likely consumer | Sensitivity / risk |
|---|---|---|---|---|---|
| `/api/v2/live` | GET | Unified live-value API | None | Dashboard live updates for non-legacy categories; aggregator polling; mock server | High; mixed-category runtime contract |
| `/api/v2/history/{device}/{metric}` | GET | Manifest-driven history API | None | Dashboard history fetch for ping/system devices; aggregator proxy target; mock server | High; route correctness must track manifest metric definitions |
| `/api/ingest/{device}/{metric}` | POST | External push ingestion | None | External push producers; mock server contract | High; value validation and device/metric existence rules matter |

### E. Import / ingest routes

| Route | Method(s) | Functional owner | Auth | Likely consumer | Sensitivity / risk |
|---|---|---|---|---|---|
| `/api/import/begin` | POST | Multi-sensor import start | Basic auth | Dashboard import UI; operator tooling | High; destructive (erase-first) behavior |
| `/api/import/begin/single/{sensor_id}` | POST | Single-sensor merge import start | Basic auth | Dashboard import UI; operator tooling | Very high; merge semantics depend on slot/hour mapping |
| `/api/import/d/{data}` | POST | Import append without write | Basic auth | Dashboard import chunk flow | High; URL-path encoding contract |
| `/api/import/w/{data}` | POST | Import append and write | Basic auth | Dashboard import chunk flow | High; write-path correctness |
| `/api/import/finish` | POST | Import finalize + metadata persist + RAM restore | Basic auth | Dashboard import completion | Very high; finalization and restore behavior |

### F. Management routes

| Route | Method(s) | Functional owner | Auth | Likely consumer | Sensitivity / risk |
|---|---|---|---|---|---|
| `/api/reboot` | POST | Reboot scheduling | Basic auth + lockout | Dashboard management UI | High; deferred task pattern required |
| `/api/delete-data` | POST | History erase scheduling | Basic auth + lockout | Dashboard management UI | Very high; destructive and NVS-heavy |
| `/api/system/reset-satellites` | POST | Aggregator runtime topology reset | Basic auth + lockout | Aggregator settings UI / future runtime mgmt | Very high; destructive and NVS-heavy |

### G. Aggregator routes

| Route | Method(s) | Functional owner | Auth | Likely consumer | Sensitivity / risk |
|---|---|---|---|---|---|
| `/api/aggregator/gateways` | GET | Aggregator gateway/cache summary | None | Aggregator dashboard | Very high; composed JSON from cached upstream payloads |
| `/api/aggregator/live` | GET | Aggregator unified live cache | None | Aggregator dashboard | High; gateway-aware runtime view |
| `/api/aggregator/proxy/{gw}/history/{device}/{metric}` | GET | On-demand history proxy | None | Aggregator dashboard | Very high; fixed-buffer proxying and truncation risk |
| `/api/aggregator/add-satellite` | POST | Stubbed runtime mgmt placeholder | Basic auth | Reserved for future Phase Y+/v7.6 runtime mgmt | Medium now, high future sensitivity |
| `/api/aggregator/test-satellite` | POST | Stubbed runtime mgmt placeholder | Basic auth | Reserved for future Phase Y+/v7.6 runtime mgmt | Same |
| `/api/aggregator/satellite/{id}` | DELETE | Stubbed runtime mgmt placeholder | Basic auth | Reserved for future Phase Y+/v7.6 runtime mgmt | Same |

### Endpoint-family observations

1. **The file owns both compatibility routes and current routes.**  
   Legacy and v2 contracts coexist in the same dispatcher.

2. **The file owns both local-device and aggregator-device APIs.**  
   This is a major reason it is no longer a narrow history module.

3. **The route surface is the real integration contract.**  
   Dashboard code, mock server, fixtures, Playwright tests, aggregator polling, and operator workflows all depend on it.

---

## 6. Data Model and Persistence Inventory

### Core persisted-history model

| Component | Purpose | Sensitivity |
|---|---|---|
| `HistEntry` | Atomic timestamp/value record | Low individually, but pervasive in ring and snapshot layouts |
| `HistoryBuffer` | 24h RAM ring buffer for recent history | Medium; used by both persistence and route responses |
| `HistoryMeta` | Global persisted-history metadata | Very high; schema/version/count bookkeeping |
| `SegmentSnapshotHeader` | Per-segment schema/layout header | Very high; validates physical compatibility |
| `SegmentSnapshot` | Persisted 1-hour data segment blob | Extreme; physical layout tied to compile-time dimensions |

### Why these pieces are sensitive

#### `HistoryMeta`

`HistoryMeta` is not just metadata. It controls:

- valid segment count
- next circular slot
- last written slot
- last persisted epoch
- expected sensor-count width
- expected points-per-segment width

It also participates in migration behavior:
- stale-but-correctable meta is rewritten
- corrupted/incompatible meta is reset and rewritten

That means it is both **schema guard** and **migration control plane**.

#### `SegmentSnapshotHeader`

This header determines whether a persisted segment can be read at all. It validates:

- magic
- version
- `num_sensors`
- `points_per_series`
- `points_per_segment`

It is the per-blob schema boundary.

#### `SegmentSnapshot`

This is the most structurally dangerous piece in the file.

Its layout contains:

- `temp_counts[NUM_SENSORS]`
- `hum_counts[NUM_SENSORS]`
- `temp[NUM_SENSORS][PERSIST_POINTS_PER_SEGMENT]`
- `hum[NUM_SENSORS][PERSIST_POINTS_PER_SEGMENT]`

That means **compile-time constant changes alter the physical blob size**.

This is exactly the BUG-045/046/048 cluster:

- widening `NUM_SENSORS` changes the physical stored layout
- stale metadata alone is recoverable with rewrite
- stale segment blobs with changed struct size are not transparently recoverable

### Slot / index / ring behavior

The persistence layer uses multiple index models simultaneously:

| Index type | Meaning |
|---|---|
| `HistoryBuffer` logical index | In-RAM 24h rolling sequence |
| `head_` / `count_` | Ring-buffer implementation state |
| `next_slot` | Circular NVS write slot |
| `valid_segments` | Number of readable segments in the persisted ring |
| `oldest_slot` / restore-window math | Derived read window into circular persisted store |
| `last_written_slot` | Most recent persisted slot |
| import epoch-map `{hour_epoch -> slot}` | Merge overlay map for single-sensor import |

Any refactor that touches one indexing model without the others is likely to break restore, import, or response assembly.

### Restore logic inventory

`restore_from_nvs()` currently does all of the following:

- opens history NVS
- loads and potentially migrates meta
- rewrites corrected/default meta when required
- clears runtime histories
- computes restore window
- iterates persisted slots
- yields periodically during NVS scan
- appends restored snapshots back into RAM
- detects unloadable size-mismatch segments
- recalibrates `valid_segments` downward when necessary
- persists recalibrated meta

That is not “read history from NVS”; it is **boot-time recovery, migration, and repair logic**.

### Persistence cadence assumptions

Current cadence assumptions embedded into the file:

- 15-minute averaging buckets
- 24h RAM window
- hourly segment persistence
- persisted history retained for `PERSIST_DAYS`
- newest RAM points are appended after flash history, with duplicate suppression based on `latest_flash_epoch`

These assumptions affect:
- chart correctness
- export correctness
- import merge behavior
- storage-stats reporting
- manifest/history metadata

### Sensor-count and schema compatibility assumptions

The file relies on a critical separation:

- `NUM_DEVICES` = total runtime devices
- `NUM_ENV_SENSORS` = persisted environmental sensors
- `NUM_SENSORS` = alias to `NUM_ENV_SENSORS`

This separation is not optional. It is the current protection against widening the persisted schema when RAM-only or non-environmental devices are added.

### Most dangerous structural refactor targets in the persistence layer

1. **`SegmentSnapshot` physical layout**
2. **`NUM_SENSORS` / `NUM_ENV_SENSORS` semantics**
3. **meta migration and rewrite path**
4. **restore-window slot math**
5. **single-sensor import epoch-map merge path**
6. **assumptions that environmental temp/hum are `metric_states[0/1]`**

These are the areas most likely to cause retained-data loss or silent history corruption if changed structurally without explicit compatibility protection.

---

## 7. Runtime Concurrency / Tasking / Locking Inventory

### Major concurrency-sensitive patterns

| Pattern | Where it appears | Why it matters |
|---|---|---|
| Deferred destructive tasks | reboot, delete-data, reset-satellites | Required because HTTP server task stack is constrained |
| FreeRTOS task creation | ping adapter, reboot task, delete task, aggregator poll task, reset-satellites task | Creates multiple runtime contexts touching shared state |
| Mutex / semaphore usage | aggregator cache mutex, ping semaphore | Defines safe cross-context access patterns |
| Scheduler-yield safeguard | `maybe_yield_nvs_scan_()` | Prevents long NVS loops from starving single-core runtime |
| Shared static buffers | `s_fetch_tmp`, `s_proxy_tmp` | Ownership assumptions matter; accidental cross-context sharing would be dangerous |
| Mutable handler instance state | auth lockout counters, import state | Lives inside web handler and assumes request serialization properties |
| “In progress” flags | delete-data, reset-satellites | Prevent duplicate task launch |
| Monotonic interval tracking | aggregator poll task via `esp_timer_get_time()` | Prevents pre-SNTP timing bugs and retry storms |

### Deferred tasks

Deferred-task pattern is used because management/NVS-heavy work must not run on the httpd stack.

Current deferred task pairs:

- `reboot_task_()` / `schedule_reboot_()`
- `delete_data_task_()` / `schedule_delete_data_()`
- `reset_satellites_task_()` / `schedule_reset_satellites_()`

This pattern is not optional in the current architecture; it is a hard runtime constraint imposed by the HTTP stack behavior.

### FreeRTOS task creation inventory

| Task | Spawn path | Approximate role |
|---|---|---|
| `ping_adapter` | `PingAdapter::start()` | Periodic ICMP probe |
| `hist_reboot` | management reboot route | Delayed restart |
| `hist_delete` | delete-data route | NVS partition erase and RAM clear |
| `agg_poll` | `start_aggregator_task()` | Aggregator polling/cache update |
| `agg_reset_sats` | reset-satellites route | Aggregator topology reset and NVS rewrite |

### Locking / semaphore inventory

#### Aggregator cache mutex

- `s_cache_mutex`
- acquired with `AGG_LOCK()` / `AGG_UNLOCK()`
- protects `satellite_caches[]` reads/writes between:
  - polling task context
  - web-handler context

Important detail: network fetches happen **outside** the lock, then copied into cache **inside** the lock. That is the current anti-stall design.

#### Ping semaphore

- Binary semaphore created by `PingAdapter`
- used to wait for ping completion callback

### Request-context vs task-context buffer ownership

| Buffer / state | Intended owner |
|---|---|
| per-request history CSV `std::string` | Request context only |
| `s_fetch_tmp` | Aggregator polling task only |
| `s_proxy_tmp` | Aggregator proxy handler only |
| `satellite_caches[]` | Shared; mutex-protected |
| import state inside `HistoryWebHandler` | Web-handler context only |

This matters because a future refactor that relocates code without preserving ownership assumptions could create races that do not exist today.

### Scheduler-yield safeguard

`maybe_yield_nvs_scan_()` is applied in long NVS iteration loops. This is a refactor-safety constraint because the current behavior assumes:

- long loops **must** periodically yield
- history serving, restore, and import index-build loops are scheduler-sensitive
- removing or relocating these loops without reintroducing equivalent yielding would regress BUG-043-class behavior

### Why concurrency patterns dominate refactor safety

This file is not only coupled by data; it is coupled by **execution context**.

A structural change can break behavior even when the logic is “the same” if it changes:

- which stack runs the code
- when yields happen
- whether shared buffers remain single-owner
- whether mutex boundaries still cover torn-read risks
- whether boot-time ordering still prevents handler races

---

## 8. Integration Surface Map

The table below lists the files most tightly coupled to `sensor_history_multi.h`.

| File | Dependency type | Current coupling |
|---|---|---|
| `firmware/esp32-c3-multi-sensor.yaml` | Compile-time include dependency; boot/orchestration dependency | Includes `dashboard.h`, `sensor_history_multi.h`, `gateway_manifest.h`, `aggregator_config.h`; calls `register_history_handler()`; starts ping and aggregator tasks |
| `scripts/render_sensor_config.py` | Generated-file dependency; ownership dependency | Owns marker-delimited regions in `sensor_history_multi.h`; regenerates manifest/config/YAML/dashboard fixture artifacts that this file depends on |
| `scripts/sensor_manifest_lib.py` | Contract dependency | Defines manifest/config schema and history-URL conventions consumed by generated blocks and dashboard/tests |
| `scripts/preflight.sh` | Preflight invariant dependency | Encodes architectural assumptions about routes, generated regions, history fetch sequencing, manifest/v2 support, `NUM_SENSORS` aliasing, aggregator support |
| `src/gateway_manifest.h` | Generated-file dependency; API contract dependency | `sensor_history_multi.h` serves `GATEWAY_MANIFEST_JSON` directly from this header |
| `src/aggregator_config.h` | Generated-file dependency; compile-time behavior dependency | Controls whether aggregator code exists, plus compile-time satellite arrays and caps |
| `dashboard/dashboard.js` | HTTP/API contract dependency; runtime contract dependency | Bootstraps from `/api/manifest`, falls back to `/sensors.json`, fetches `/api/status`, `/api/storage-stats`, `/history/*`, `/api/v2/live`, `/api/v2/history/*`, management/import routes, aggregator routes |
| `tests/browser/dashboard.spec.js` | Test/runtime contract dependency | Encodes expected dashboard boot, rendering, history sequencing, mixed-category, and aggregator assumptions tied to file-owned endpoints |
| `tests/browser/manifest.spec.js` | Test/API contract dependency | Validates `/api/manifest` schema, manifest-first boot, and `/sensors.json` fallback contract |
| `tests/mock-server/server.js` | Mock API contract dependency | Reimplements the same route families this file owns so browser tests can run against a contract-faithful mock |
| `tests/fixtures/generate-fixtures.js` | Fixture-generation contract dependency | Generates mock manifests/history/status/storage payloads that mirror the endpoint shapes and manifest/history URL conventions |
| `firmware/local_components/web_server_idf/web_server_idf.cpp` | Local-component behavior dependency | Defines handler ordering behavior, POST-body consumption behavior, stack-size patch location, and request handling semantics that shape what this file can safely do |
| `scripts/patch-esphome-httpd-stack.sh` | Operational dependency | Ensures local HTTP stack override exists and preserves the 16KB patched server stack |
| `Docs/aggregator-setup.md` | Operator workflow dependency | Documents generation pipeline, board/YAML selection, and aggregator expectations that assume this file’s route/runtime behavior |
| `Docs/bugs-and-lessons-learned.md` | Historical guardrail dependency | Records the failure modes that now constrain acceptable changes to this file |

### Missing requested integration document

`Docs/configuring-sensors.md` was requested as an input but is **not present at that path on PR124**. This matters because:

- `sensor_history_multi.h` still references it in comments
- sensor-count / generator workflow is architecturally relevant
- its absence weakens the documentation-side ownership picture for generated sensor topology

No substitute file was assumed here without explicit evidence.

---

## 9. Natural Subsystem Boundaries

This section does **not** propose a refactor plan. It identifies boundaries that already appear to exist implicitly.

### 9.1 History store / persistence subsystem

**Why it is a plausible boundary**

The NVS meta/snapshot/restore/write logic is internally cohesive and already behaves like its own subsystem.

**Likely contents**

- `HistoryMeta`
- `SegmentSnapshotHeader`
- `SegmentSnapshot`
- NVS open/init helpers
- meta load/save/default/migration helpers
- snapshot load/build/append helpers
- restore/write/clear functions
- storage-size helpers

**Current blockers to a clean split**

- direct use of generated `NUM_SENSORS`
- direct reach into `devices[i].metric_states[0/1]`
- route handlers call persistence helpers directly
- import engine is interleaved with persistence internals

### 9.2 Sensor runtime model subsystem

**Why it is a plausible boundary**

`MetricDef`, `MetricState`, `SensorEntity`, generated metric arrays, and `devices[]` form a clear model layer.

**Likely contents**

- runtime device/entity types
- generated metrics arrays
- generated device array
- sensor-category/adaptor conventions
- helper methods like `add_sample`, `compute_averages`, `mark_seen`

**Current blockers**

- persistence layer depends on temp/hum being metric indices 0/1
- route layer reaches directly into `devices[]`
- ping adapter writes directly to generated device indices
- storage/reporting routes assume global `devices[]`

### 9.3 Route-dispatch / API gateway subsystem

**Why it is a plausible boundary**

`HistoryWebHandler` already groups nearly all HTTP ownership into one object.

**Likely contents**

- route matching
- method dispatch
- response helpers
- endpoint family entrypoints

**Current blockers**

- the handler owns import state, auth state, and route logic together
- handlers directly access persistence and aggregator globals
- management, import, and proxy logic are not delegated to subordinate service objects

### 9.4 Auth / management subsystem

**Why it is a plausible boundary**

Basic auth parsing, constant-time compare, lockout, and management-route gating are internally related and safety-critical.

**Likely contents**

- auth-header parsing
- lockout state
- `authenticate_management_()`
- common JSON error responses for management routes
- deferred action scheduling

**Current blockers**

- embedded inside `HistoryWebHandler`
- destructive routes also own business logic
- task scheduling functions are top-level globals, not encapsulated

### 9.5 Import engine subsystem

**Why it is a plausible boundary**

Import behavior has its own state machine and its own data structures.

**Likely contents**

- import state
- single-vs-multi mode behavior
- epoch-map build/lookup
- snapshot overlay/write
- finalize/cleanup flow

**Current blockers**

- tightly coupled to persistence structs and slot math
- embedded inside route handler class
- assumes environmental-history schema directly
- uses route-path transport contract directly

### 9.6 Aggregator runtime subsystem

**Why it is a plausible boundary**

The aggregator code already looks like an embedded subsystem:

- own cache type
- own mutex
- own NVS namespace
- own FreeRTOS task
- own routes
- own proxy/fetch logic

**Likely contents**

- `SatelliteCache`
- cache mutex and shared buffers
- satellite NVS persistence helpers
- polling task
- live/gateways/proxy handlers
- reset task

**Current blockers**

- compiled inside the same file under `#if AGGREGATOR_ENABLED`
- route handlers live in same monolithic `HistoryWebHandler`
- uses global shared helpers and response conventions from the outer file

### 9.7 Ping / network adapter subsystem

**Why it is a plausible boundary**

`PingAdapter` is self-contained task-based device-feeding logic.

**Likely contents**

- ping task
- callback bridge
- device metric feed path

**Current blockers**

- depends on generated `PING_DEVICE_INDEX`
- writes directly into `devices[]`
- startup is wired from generated YAML/on_boot logic

### 9.8 Generated config / topology subsystem

**Why it is a plausible boundary**

Generated topology already has a separate generator of record.

**Likely contents**

- generated header/entity block
- generated manifest header
- generated aggregator config header
- generator-side schemas/contracts

**Current blockers**

- consumed as inline code inside monolithic runtime file
- hand-maintained code assumes exact generated shapes instead of narrower interfaces

---

## 10. High-Risk Refactor Zones

| Area | Why it is risky | What could break | Detecting guards / tests | Risk type |
|---|---|---|---|---|
| `SegmentSnapshot` / `HistoryMeta` layout and semantics | Persisted data compatibility depends on exact dimensions and migration behavior | Retained history loss, unreadable blobs, endless reset loops | Preflight `NUM_SENSORS` alias checks; manual restore testing; lessons BUG-045/046/048 | Schema-risk |
| `NUM_DEVICES` / `NUM_ENV_SENSORS` / `NUM_SENSORS` separation | Runtime vs persisted-width split is a critical invariant | Persisted schema widening, category regressions | Preflight alias checks; storage/history runtime validation | Generator-risk / schema-risk |
| Metric ordering assumptions (`metric_states[0/1]`) | Persistence and legacy routes assume temp/hum fixed positions | Wrong history series, wrong live values, wrong imports | Dashboard tests, manifest/history tests, runtime charts | Runtime-risk / integration-risk |
| `restore_from_nvs()` | Mixes migration, slot math, recalibration, RAM restore | Empty history, repeated boot migrations, stale-segment retries | Device boot validation; storage/history functional tests | Runtime-risk / schema-risk |
| Import engine | Overlay/merge/write behavior touches slots, schema, and auth | Data loss, cross-sensor overwrite, broken import | Import regression testing; operator workflows | Runtime-risk |
| `handle_history_()` | Combines flash + RAM history, duplicate suppression, response building, yields | ESP32 instability, duplicate/missing rows, chart breakage | Preflight no-streaming-history + yield checks; browser tests | Route-risk / runtime-risk |
| Management POST handlers | Current safety depends on deferred-task pattern | Stack overflow, crashes, unsafe destructive actions | Local HTTP stack patch + manual POST testing + lessons BUG-075/076 | Runtime-risk |
| Aggregator cache + polling task | Cross-context state, monotonic timing, truncation handling | Torn reads, retry storms, broken aggregator UI | Aggregator dashboard tests/manual validation | Runtime-risk / integration-risk |
| Aggregator proxy route | Fixed buffer + upstream fetch + composed response | Truncated/corrupt history payloads, 502 behavior regressions | Mock server / browser coverage; BUG-063/074 lessons | Route-risk |
| Manifest and route compatibility surface | Dashboard/tests/mock server depend on exact route families and shape | Boot failure, missing cards, fallback regressions | `manifest.spec.js`, `dashboard.spec.js`, mock server parity | Route-risk / integration-risk |
| Generated marker ownership seam | Logic assumes generated outputs remain aligned | Drift between runtime code and generated topology | `render_sensor_config.py --check`, preflight, fixture regeneration | Generator-risk |
| YAML include / boot registration wiring | Build and runtime depend on exact include order and startup hooks | Missing symbols, wrong boot order, handler registration failure | Preflight, compile, boot validation | Integration-risk |

---

## 11. Guardrails Already Present

### 11.1 Preflight checks

`scripts/preflight.sh` already encodes multiple structural guardrails tied directly to this file, including:

- generated-file sync via `render_sensor_config.py --check`
- route-presence checks for `/api/manifest`, `/api/v2/live`, `/api/v2/history`, `/api/ingest`
- include dependency checks for `gateway_manifest.h` and `aggregator_config.h`
- history-fetch sequencing checks (BUG-043 family)
- required `maybe_yield_nvs_scan_()` usage count
- `NUM_ENV_SENSORS` / `NUM_SENSORS` aliasing guards (BUG-045 family)
- startup polling sequencing guards
- dashboard boot contract checks
- optional Playwright manifest smoke test

These are meaningful architectural guardrails, not just style checks.

### 11.2 Compile / config validation

The project also has build-time validation outside the header itself:

- YAML/config generation validation
- ESPHome config/compile validation in workflow
- generated artifact regeneration pipeline
- board/YAML selection guidance in operator docs

### 11.3 Browser and runtime contract tests

The Playwright suite and mock server guard the real API and dashboard contract by validating:

- manifest-first boot from `/api/manifest`
- `/sensors.json` fallback
- mixed-category dashboard rendering
- history fetch sequencing and in-flight behavior
- aggregator dashboard assumptions
- route availability and schema shape

### 11.4 Mock / fixture generation

`tests/mock-server/server.js` and `tests/fixtures/generate-fixtures.js` act as executable documentation for the HTTP contract.

That is especially important because `sensor_history_multi.h` owns multiple route families with mixed legacy/v2 behavior.

### 11.5 Lessons learned as structural constraints

The bug/lesson record imposes hard constraints, especially:

- sequential history access and NVS yielding
- no `beginResponseStream` for large history payloads
- persistence-width separation (`NUM_SENSORS` vs `NUM_DEVICES`)
- migration/rewrite requirement for stale metadata
- physical incompatibility risk when persisted struct size changes
- category audit requirement when new device categories are added
- aggregator boot must remain a satellite superset
- POST body/content-type constraints on this stack
- HTTP server stack-size and deferred-task constraints

These are effectively architectural rules now.

### 11.6 Local HTTP stack override

The local `web_server_idf` override and patch script are already a major operational guardrail:

- 16KB patched server stack
- custom close behavior
- known POST-body handling constraints
- explicit patch verification path

The override is part of the runtime envelope within which `sensor_history_multi.h` currently works.

### 11.7 Important note on missing requested lessons/docs

Two documentation gaps were observed during this inventory:

1. `Docs/configuring-sensors.md` is missing at the requested path on PR124.
2. Requested lesson IDs `LESSON-OPS-102`, `105`, `106`, `107`, `108`, and `109` were not present in the current `Docs/bugs-and-lessons-learned.md` revision examined here.

Those omissions do not invalidate the inventory, but they do mean the current documentation-side guardrail picture is incomplete.

---

## 12. Missing Guardrails / Weak Spots

This section identifies structural gaps, not refactor proposals.

### 12.1 No explicit route inventory enforcement

There is no single machine-checked inventory asserting that the file still owns exactly the expected route families.

Current checks verify presence of some routes, but not:

- full route coverage
- method coverage
- auth coverage
- legacy-vs-v2 coexistence guarantees

### 12.2 No compile-time guard for persisted struct size stability

The project documents the `SegmentSnapshot` size-compatibility hazard, but there is no explicit automated guard such as:

- expected `sizeof(SegmentSnapshot)` stability assertion per target configuration
- snapshot-layout regression test

This is one of the most dangerous missing guardrails.

### 12.3 No formal ownership assertion around generated/hand seams

The code relies on conventions such as:

- environmental temp/hum at metric indices `0/1`
- category numeric meanings
- `PING_DEVICE_INDEX` validity
- `NUM_SENSORS` environmental-only semantics

Those assumptions are guarded indirectly, not explicitly. A future generator change could violate them without a narrow, targeted failure message.

### 12.4 No structural separation checks inside the monolith

There is no guardrail that enforces boundaries such as:

- route dispatch separate from persistence logic
- import state separate from auth state
- aggregator runtime isolated from base history runtime

That means the file can continue accumulating responsibilities without any automated signal.

### 12.5 Weak documentation-side ownership for sensor-configuration workflow

Because `Docs/configuring-sensors.md` is missing on this branch, there is currently no directly available documentation artifact at the referenced path that explains:

- sensor-count workflow
- generated ownership boundaries
- environmental-vs-runtime count semantics

The header still references that doc, so the documentation contract is currently inconsistent.

### 12.6 Limited direct tests for migration / retained-history compatibility

The project documents BUG-045/046/048 behavior, but there is no obvious automated regression fixture that exercises:

- stale meta rewrite
- unloadable old snapshot blobs
- valid-segment recalibration

Those behaviors appear to be protected mainly by operational lessons and manual care.

### 12.7 Handler-order dependency is documented, but not structurally enforced

The route layer still depends on ESPHome handler registration order and the local HTTP stack’s behavior. That is documented, but there is no enforcement that would fail early if ordering changed upstream.

### 12.8 Aggregator and base-history concerns still share one compile unit

This is not itself a bug, but it is a structural weak spot:

- base satellite history behavior
- aggregator polling/cache runtime
- management runtime
- import engine

all live in one file and one translation unit, making selective reasoning and targeted regression isolation harder than necessary.

---

## 13. Inputs Recommended for the Phase Y Refactor Planning Session

The next planning session should start from these inputs, in this order:

1. `Docs/phase-Y-current-state-inventory-sensor-history.md`  
2. `dashboard/sensor_history_multi.h`  
3. `scripts/render_sensor_config.py`  
4. `scripts/sensor_manifest_lib.py`  
5. `firmware/esp32-c3-multi-sensor.yaml`  
6. `scripts/preflight.sh`  
7. `src/gateway_manifest.h`  
8. `src/aggregator_config.h`  
9. `dashboard/dashboard.js`  
10. `tests/browser/manifest.spec.js` and `tests/browser/dashboard.spec.js`  
11. `tests/mock-server/server.js` and `tests/fixtures/generate-fixtures.js`  
12. `firmware/local_components/web_server_idf/web_server_idf.cpp` and `scripts/patch-esphome-httpd-stack.sh`  
13. `Docs/aggregator-setup.md`  
14. `Docs/bugs-and-lessons-learned.md` with emphasis on BUG-043/045/046/048/075/076 and LESSON-OPS-052/053/054/056/059/060/061/064/074/089/091/099/100/101

The findings from this inventory that should shape the future plan are:

- `sensor_history_multi.h` must be treated as a **multi-subsystem integration unit**, not as “history code”.
- The **generated vs hand-maintained seam** is a first-class architectural constraint.
- The **persisted schema boundary** is the most dangerous structural zone.
- The **route inventory** is the real external contract surface and must be preserved intentionally.
- The **HTTP stack constraints** are not incidental; they shape which work may run on which stack/task.
- The **aggregator runtime** is already a distinct subsystem embedded in the same file.

The following areas should be treated as **no behavior change / structural only** in an initial refactor plan unless the plan explicitly widens scope:

- persisted-history schema, slot math, and migration behavior
- route paths, methods, auth expectations, and payload shapes
- manifest boot contract (`/api/manifest` primary, `/sensors.json` fallback)
- sequential history access and scheduler-yield protections
- deferred-task pattern for destructive management routes
- generator-owned marker regions and their emitted semantics
- aggregator polling cadence/backoff behavior
- local HTTP stack assumptions around POST bodies and handler execution environment

A final planning note: `Docs/configuring-sensors.md` was requested as an input but was not present at that path on PR124 during this inventory. The planning session should either restore that document, identify its moved replacement explicitly, or proceed knowing that part of the documentation-side ownership picture is currently missing.
