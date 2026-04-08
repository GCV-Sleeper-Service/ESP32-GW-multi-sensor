# Phase Y — Sensor History Architecture and Refactor Plan (GPv2)

_Unified implementation plan for splitting `dashboard/sensor_history_multi.h` into focused firmware modules while preserving behavior._
_Date: 2026-04-08_
_Phase: Phase Y — Post-Phase X firmware architecture refactor_
_Version range: `v7.6.6.0`–`v7.6.6.7` (`v7.6.6.0` is the provisioning/pipeline pre-step)_
_Status: Planning — not yet implemented_
_Prerequisite: Phase X complete on `main`; current firmware baseline stable; all existing Playwright / preflight / ESPHome config gates green_
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_

---

## 1. Goal

Refactor the firmware-side history/HTTP monolith so that:

1. A coding agent working on one firmware feature area no longer has to load a 4,325-line mixed-responsibility header (~30K tokens once the surrounding YAML/generator/guardrails are included).
2. The split creates explicit ownership boundaries for persistence, route handling, aggregator runtime, deferred tasks, ping, and orchestration.
3. The generated-vs-hand-maintained seam is explicit and enforceable.
4. Phase 7 per-device persistence, later cloud support, and captive portal work land on targeted modules instead of extending one monolith.
5. No runtime behavior, endpoint contract, persisted-history schema, or auth behavior changes during Phase Y.

**This phase is structural only. It is not a feature phase.**

### Out of scope

Phase Y does **not** include:

- YAML slimming (moving ESPHome lambdas into additional C++ files)
- New board templates (C5, C6, S3-2MB)
- Sensor/device add-remove UX workflow changes
- Dashboard bug fixes #136, #137, #138, #143, #144
- Phase 7 per-device persistence implementation
- Documentation reorganization tracked under Issue #140

### Included prerequisite pre-step

`v7.6.6.0` is intentionally included even though it is not part of the header split itself:

- `scripts/provision.sh` must automate the **entire** local regeneration pipeline instead of running only `render_sensor_config.py --write` and printing the remaining steps.
- This reduces operator error during repeated satellite / aggregator device-testing loops and is a direct prerequisite for safe iterative firmware refactor work.

---

## 2. Architecture Decisions (Resolved)

These decisions were open or ambiguous in the Phase X carryover context. They are resolved here and apply to all Phase Y steps.

### 2.1 Final module root

**Decision: use `firmware/core/` as the hand-maintained module root, with `firmware/core/generated/` for generator-owned files.**

Rationale:

- `dashboard/` should no longer host a growing body of non-dashboard firmware logic.
- The split is firmware architecture work, not dashboard work.
- A dedicated `generated/` subdirectory makes ownership boundaries explicit and reviewable.
- Future Phase 7 / cloud work will naturally extend `firmware/core/`, not `dashboard/`.

### 2.2 Fate of `dashboard/sensor_history_multi.h`

**Decision: retain it during Phase Y as a thin compatibility shim / assembly file, then remove it from primary YAML include lists in the final Phase Y step.**

Rationale:

- Current generator, preflight, documentation, and developer muscle memory all point at `dashboard/sensor_history_multi.h`.
- Removing the path in the first extraction step would increase blast radius without reducing risk.
- Keeping a thin shim early gives a reversible migration path and an obvious assembly checkpoint for the identity gate.
- Final target state uses explicit YAML includes for `firmware/core/*` in deterministic order, but the shim can remain as a compatibility wrapper until the closure step proves the direct include order stable.

### 2.3 Generator ownership model

**Decision: move both generated marker blocks into a single dedicated generated header: `firmware/core/generated/sensor_topology.generated.h`.**

That file becomes the sole generator-owned Phase Y firmware fragment. It contains:

- generated `MetricDef` arrays
- generated `HistoryBuffer` statics
- generated device count constants (`NUM_DEVICES`, `NUM_ENV_SENSORS`, `NUM_SENSORS`)
- generated `PING_DEVICE_INDEX` / `PING_TARGET`
- generated `devices[]` topology array
- the explanatory comments currently emitted into the header block

Rationale:

- The current generator already treats the two marker blocks as one coupled logical unit.
- `NUM_SENSORS` semantics, device array shape, and ping macros must stay coherent; splitting generator output across multiple hand-maintained files would increase drift risk.
- A single generated file is the cleanest “generated vs. hand-maintained” seam and the smallest practical generator change.

### 2.4 Identity / verification gate

**Decision: Phase Y uses a repo-local source-identity gate, not binary identity.**

The practical gate is:

1. Maintain an ordered fragment manifest for the split (`scripts/assemble-sensor-history.py` or equivalent).
2. Assemble the fragments into a normalized synthetic monolith.
3. Compare that synthetic output against a normalized baseline snapshot of the pre-split `sensor_history_multi.h`.
4. Backstop the source-identity check with:
   - `python3 scripts/render_sensor_config.py --check`
   - `bash scripts/preflight.sh`
   - `esphome config firmware/esp32-c3-multi-sensor.yaml`
   - targeted Playwright suites
   - device smoke tests where the moved code touches boot flow, persistence, import, or aggregator runtime

Why this and not binary/object comparison:

- ESPHome / ESP-IDF builds contain non-deterministic elements and are not a realistic byte-for-byte identity target.
- Direct compiler-preprocessor comparison is harder to make portable because the firmware includes ESPHome / ESP-IDF headers not uniformly available in every repo-only environment.
- A repo-local assembly identity gate is deterministic, reviewable, and directly enforces the “structural only” rule during the extraction steps.
- Compile/test/device gates still catch include-order, symbol-visibility, and runtime regressions that assembly identity alone cannot catch.

### 2.5 Dispatcher strategy

**Decision: keep `HistoryWebHandler::canHandle()` and `HistoryWebHandler::handleRequest()` centralized. Split endpoint implementations behind that dispatcher.**

Rationale:

- The route-family match logic is already the most failure-prone contract surface.
- Splitting the dispatcher too early would increase risk of silent endpoint loss or auth/OPTIONS drift.
- Keeping route selection centralized while moving handler bodies into route-family fragments preserves behavior and gives explicit ownership without duplicating dispatch rules.

### 2.6 Aggregator two-island resolution

**Decision: split aggregator code into an explicit shared-state surface plus two consumers:**
- `aggregator_state.h` / `aggregator_shared.h` — shared state, mutex, macros, flags, buffers, structs
- `aggregator_runtime.h` — polling, HTTP fetch/probe, NVS load/save, deferred satellite tasks
- `history_web_handler_aggregator.inc` (or equivalent) — HTTP endpoint methods inside the handler class

Rationale:

- The aggregator is not one contiguous slice. It spans a top-level runtime island plus a route-handler island.
- Treating it as one “logical module” without an explicit shared-state surface would preserve the hidden coupling that makes the monolith hard to change.
- An explicit shared-state header is the smallest safe way to resolve the two-island problem without changing behavior.

### 2.7 Phase Y before Phase 7

**Decision: Phase Y should land before Phase 7 implementation.**

Rationale:

- Phase 7 wants clean extension points around history-store code, per-device restore/persist, import/export, and storage stats.
- Adding per-device persistence directly into the current monolith would make the later split much harder and increase regression risk.
- Phase Y is pure structural work; it reduces the context burden of Phase 7 without requiring any Phase 7 design changes.

---

## 3. Current State Analysis

### 3.1 Firmware asset metrics (verified at current `main`)

| Artifact | Size / role | Why it matters |
|---|---:|---|
| `dashboard/sensor_history_multi.h` | **4,325 lines** | Primary Phase Y target; mixed runtime + HTTP + persistence + generator seam |
| `scripts/render_sensor_config.py` | **1,414 lines** | Writes generator-owned firmware blocks and board YAML include lists |
| `firmware/esp32-c3-multi-sensor.yaml` | **969 lines** | Current include order, `on_boot`, intervals, route registration |
| `scripts/preflight.sh` | **551 lines**, **68 checks** | Current guardrail surface Phase Y must preserve and extend |
| `scripts/provision.sh` | **540 lines** | Current board-switch / render helper; incomplete pipeline automation |
| `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` | **835 lines** | Pre-digested subsystem map and risk inventory |
| `Docs/v7.7-implementation-plan.md` | Phase 7 plan | Downstream pressure on history-store boundaries |
| `Docs/v7.7-v7.8-persistence-architecture.md` | Phase 7 architecture | Makes the persistence seam requirement explicit |

### 3.2 Responsibility count inside the monolith

The current header mixes all of the following in one file:

| Area | Current role | Structural issue |
|---|---|---|
| Base types / constants / `HistoryBuffer` | shared substrate | mixed with unrelated runtime code |
| Generated topology seam | device arrays, counts, ping macros | generator-owned code embedded inside hand-maintained monolith |
| Persisted history schema + NVS core | `HistoryMeta`, `SegmentSnapshot`, restore/persist, CSV/history helpers | Phase 7 wants to replace/extend this area directly |
| Deferred task helpers | reboot, delete-data | currently hidden between unrelated subsystems |
| Ping adapter | dedicated ICMP runtime | contiguous and independently understandable, but trapped in monolith |
| Aggregator runtime core | polling, fetch, NVS satellite persistence, shared buffers | one half of a two-island subsystem |
| HTTP route gateway | `HistoryWebHandler` dispatch and helpers | single class owns many domains |
| Import engine | state machine + merge helpers + import routes | behaviorally distinct but embedded in the handler |
| Aggregator route handlers | gateway/live/proxy/satellite mutation endpoints | second half of the aggregator subsystem |
| Registration / orchestration | `register_history_handler()` | coupled to many prior symbols |

The v2 inventory counts the current surface as roughly:

- 10 named struct types
- 3 classes (`HistoryBuffer`, `PingAdapter`, `HistoryWebHandler`)
- 38 top-level helper / free functions
- 21 endpoint-specific handler methods
- 4 deferred-task helper pairs
- 2 generator marker blocks
- 31 compile-time constants / macros
- 15 static shared buffers / arrays

That is not a “large header”; it is a mixed firmware subsystem bundle.

### 3.3 Why the current structure is expensive for coding-agent work

A typical firmware task today must often load:

- the full 4,325-line header
- the generator
- the YAML include / boot / interval wiring
- the preflight checks touching the changed surface
- the downstream dashboard or test assumptions for route shape

That produces a practical task context around **28K–35K tokens**, even before the agent starts writing. Small tasks still inherit whole-file risk:

- “change one route payload” still requires loading persistence, ping, aggregator runtime, and import code to avoid breaking symbols.
- “change one NVS helper” still requires reading handler methods because import/history paths share restore helpers and yield guards.
- “change one aggregator endpoint” still requires reading both aggregator runtime islands and global route dispatch.

This is exactly the type of whole-file cognitive load Phase X was designed to remove on the dashboard side.

### 3.4 Why Phase 7 and later features make this worse if left unsplit

Phase 7 per-device persistence will add new structures, key schemes, restore/persist flows, storage stats, migration logic, delete paths, and import/export changes. The current monolith would force that work into the same file that already contains:

- old monolithic persisted-history schema
- route dispatch
- import state machine
- aggregator polling
- ping logic
- deferred management tasks

That is a direct continuation of the BUG-045 / BUG-046 / BUG-048 class of risk: too many unrelated concerns in one place, with compile-time assumptions leaking across domains.

Later phases increase pressure further:

- cloud support wants targeted aggregator/runtime extension points
- captive portal wants cleaner orchestration and registration seams
- future boards / roles want deterministic include ownership rather than one giant header side-loaded into YAML

### 3.5 Current context-window cost estimate

| Task type | Files usually required today | Est. tokens |
|---|---|---:|
| Persistence / NVS change | full header + YAML + generator + preflight + history tests/consumers | ~30K–35K |
| Aggregator runtime change | full header + YAML + tests/docs + preflight | ~28K–34K |
| Route payload / auth change | full header + dashboard/test consumers + preflight | ~26K–32K |
| Ping-only change | full header + YAML + generator + preflight | ~24K–28K |

This is inside the “possible but inefficient” range, not the “comfortable and safe” range.

---

## 4. Proposed File Structure

### 4.1 Before

```text
dashboard/
  sensor_history_multi.h              ← 4,325-line mixed-responsibility firmware monolith
firmware/
  esp32-c3-multi-sensor.yaml          ← includes monolith + generated headers
src/
  gateway_manifest.h                  ← generated
  aggregator_config.h                 ← generated
scripts/
  render_sensor_config.py             ← writes into sensor_history_multi.h marker blocks
  preflight.sh
  provision.sh
```

### 4.2 Final target state

```text
firmware/
  core/
    history_base.h                    ← shared includes, constants, base structs, HistoryBuffer,
                                        SensorEntity/metric base declarations
    generated/
      sensor_topology.generated.h     ← ONLY generator-owned Phase Y firmware file:
                                        MetricDefs, generated buffers, NUM_* counts, ping macros, devices[]
    history_store.h                   ← HistoryMeta, SegmentSnapshot*, restore/persist, CSV/history helpers,
                                        maybe_yield_nvs_scan_(), partition / NVS utilities
    management_tasks.h                ← reboot/delete-data deferred tasks and flags
    ping_adapter.h                    ← PingAdapter class and its task wiring
    aggregator_state.h                ← SatelliteCache, SatelliteNVSSnapshot, mutex/macros, flags,
                                        shared buffers, config-generation counter
    aggregator_runtime.h              ← HTTP fetch/probe, satellite NVS load/save, init, poll task,
                                        reset/save deferred satellite tasks, start_aggregator_task()
    history_web_handler.h             ← HistoryWebHandler declaration, central dispatcher,
                                        auth/common helpers, includes route-family impl fragments
    history_web_handler_local.inc     ← dashboard/manifest/live/history/storage/status/ingest methods
    history_web_handler_import.inc    ← import state machine helpers + import begin/data/finish methods
    history_web_handler_management.inc← reboot/delete-data/reset-satellites handler methods if kept separate
    history_web_handler_aggregator.inc← aggregator endpoint methods (gateways/live/proxy/add/delete/test/reset)
    orchestration.h                   ← register_history_handler()
dashboard/
  sensor_history_multi.h              ← thin compatibility shim / assembly file during transition;
                                        optionally retained as compatibility wrapper after final cutover
firmware/
  esp32-c3-multi-sensor.yaml          ← final Phase Y target uses explicit ordered includes for core modules
src/
  gateway_manifest.h                  ← generated (unchanged ownership)
  aggregator_config.h                 ← generated (unchanged ownership)
scripts/
  assemble-sensor-history.py          ← NEW source-identity verification tool
```

### 4.3 Why these boundaries

| Module | Why it is a good boundary | Contiguous / scattered rationale |
|---|---|---|
| `history_base.h` | gathers the stable substrate every other module needs | verified contiguous top-of-file substrate plus shared declarations |
| `sensor_topology.generated.h` | isolates generator-owned topology from hand-maintained code | both current marker blocks are generator-coupled and should stay together |
| `history_store.h` | gives Phase 7 a direct seam for persistence replacement/extension | mostly contiguous persisted-history/NVS block with scattered consumers, so extract the core block first and keep consumers referencing it |
| `management_tasks.h` | groups the non-aggregator deferred-task pairs | contiguous helper block immediately before PingAdapter; no reason to keep it hidden in the monolith |
| `ping_adapter.h` | already a self-contained subsystem | contiguous block; ideal early extraction target |
| `aggregator_state.h` | resolves the two-island coupling explicitly | aggregator is scattered across runtime + handler-route islands; shared state must become first-class |
| `aggregator_runtime.h` | isolates top-level runtime logic from HTTP-route logic | contiguous runtime island; natural extraction target |
| `history_web_handler*.inc` | route-family ownership without splitting the dispatcher | handler class is contiguous but multi-domain; split method bodies by domain, keep dispatch centralized |
| `orchestration.h` | isolates boot registration and route installation | contiguous tail block; independent closure point |

### 4.4 Why Phase Y does **not** try to force everything into contiguous top-level headers

The v2 inventory correctly distinguishes **contiguous blocks** from **logical subsystems**. Phase Y uses two different extraction patterns:

#### Pattern A — contiguous-slice extraction
Used where the current file already has a coherent physical block:

- `PingAdapter`
- top-level aggregator runtime
- registration/orchestration
- most of the persisted-history / NVS core
- deferred reboot/delete helpers

#### Pattern B — declaration + domain-implementation split
Used where logical ownership exists but code is embedded inside `HistoryWebHandler` or spread across islands:

- import engine
- management/auth route methods
- aggregator route methods
- full aggregator subsystem (runtime + routes)
- route-family-specific helper methods

That hybrid strategy is mandatory. Trying to make the full aggregator or import engine look like one contiguous top-level slice would either fail the identity gate or require behavior-changing reorderings.

---

## 5. Module Ownership Model

### 5.1 Shared firmware substrate

| Module | Owns |
|---|---|
| `history_base.h` | compile-time constants/macros that are not generator-owned, base structs (`HistEntry`, metric state/base declarations), `HistoryBuffer`, stable shared helper declarations |
| `sensor_topology.generated.h` | generated device topology and count semantics; all generator output in one place |

### 5.2 Persistence / history domain

| Module | Owns |
|---|---|
| `history_store.h` | `HistoryMeta`, `SegmentSnapshotHeader`, `SegmentSnapshot`, snapshot alloc/load/save helpers, partition detection, NVS open/load/save helpers, restore/persist flow, export/stream helpers, `maybe_yield_nvs_scan_()` |

### 5.3 Task / device-runtime domain

| Module | Owns |
|---|---|
| `management_tasks.h` | `reboot_task_()`, `schedule_reboot_()`, `delete_data_task_()`, `schedule_delete_data_()`, `s_delete_data_in_progress` |
| `ping_adapter.h` | `PingAdapter` class and all ping task/callback logic |
| `aggregator_state.h` | all aggregator shared structs, globals, mutex/macros, flags, temp buffers, config-generation counter |
| `aggregator_runtime.h` | fetch/probe/init/poll/start flow, satellite NVS load/save, reset/save deferred tasks |

### 5.4 HTTP route / handler domain

| Module | Owns |
|---|---|
| `history_web_handler.h` | class declaration, route matching, `canHandle()`, `handleRequest()`, auth/common header helpers, handler-private state layout |
| `history_web_handler_local.inc` | dashboard assets, manifest, v2 live/history, ingest, storage stats, status, legacy history |
| `history_web_handler_import.inc` | import helper state machine and import begin/data/finish methods |
| `history_web_handler_management.inc` | reboot/delete-data and other non-aggregator management POST handlers if split separately |
| `history_web_handler_aggregator.inc` | aggregator gateways/live/proxy/add/delete/test/reset handlers |

### 5.5 Boot / registration domain

| Module | Owns |
|---|---|
| `orchestration.h` | `register_history_handler()` and any helper registration glue |

---

## 6. Exact YAML Include Strategy

### 6.1 Final include order

Phase Y’s final target for `esphome.includes:` is:

```yaml
includes:
  - ../dashboard/dashboard.h
  - ../src/gateway_manifest.h
  - ../src/aggregator_config.h
  - ../firmware/core/history_base.h
  - ../firmware/core/generated/sensor_topology.generated.h
  - ../firmware/core/history_store.h
  - ../firmware/core/management_tasks.h
  - ../firmware/core/ping_adapter.h
  - ../firmware/core/aggregator_state.h
  - ../firmware/core/aggregator_runtime.h
  - ../firmware/core/history_web_handler.h
  - ../firmware/core/orchestration.h
```

### 6.2 Why this order

| Include | Must come before | Reason |
|---|---|---|
| `dashboard.h` | handler/orchestration | `handle_dashboard_()` serves `DASHBOARD_HTML_GZ` |
| `gateway_manifest.h` | handler methods | manifest routes reference `GATEWAY_MANIFEST_JSON` |
| `aggregator_config.h` | aggregator modules + handler aggregator routes | `AGGREGATOR_ENABLED`, `MAX_SATELLITES`, poll intervals |
| `history_base.h` | everything else | base types and shared declarations |
| `sensor_topology.generated.h` | ping, history_store consumers, handler methods | generated `devices[]`, counts, ping macros |
| `history_store.h` | management tasks, handler methods | delete-data and route handlers call persistence helpers |
| `management_tasks.h` | handler methods | route handlers schedule these tasks |
| `ping_adapter.h` | YAML `on_boot` ping init / orchestration | ping class must exist before use |
| `aggregator_state.h` | aggregator runtime + aggregator route methods | shared state surface |
| `aggregator_runtime.h` | handler aggregator methods + orchestration | route methods call runtime helpers |
| `history_web_handler.h` | orchestration | orchestration instantiates/registers the handler |
| `orchestration.h` | final | closure point only |

### 6.3 Hand-maintained vs. generated include list

**Decision: the include list is hand-maintained in checked-in YAML, with generator support only for fully generated alternate board YAMLs.**

That means:

- `firmware/esp32-c3-multi-sensor.yaml` gets a hand-maintained canonical include block.
- `scripts/render_sensor_config.py::generate_board_yaml()` uses the same canonical ordered list when it emits generated non-default board YAMLs.
- `scripts/preflight.sh` adds an include-order check so the hand-maintained C3 YAML and generated board YAMLs cannot drift.

This avoids trying to make `render_sensor_config.py` dynamically rewrite the C3 YAML include block while still keeping all board outputs aligned.

---

## 7. Generated-Block Ownership Strategy

### 7.1 Current state

Today `render_sensor_config.py` writes directly into `dashboard/sensor_history_multi.h`:

- `SENSOR_MANIFEST:HEADER_*`
- `SENSOR_MANIFEST:ENTITY_*`

That couples generator-owned topology to a hand-maintained monolith.

### 7.2 Final target

After Phase Y:

- `render_sensor_config.py` stops targeting `dashboard/sensor_history_multi.h`.
- It writes **one fully owned file**:

```text
firmware/core/generated/sensor_topology.generated.h
```

- The file is fully generated, not marker-edited by hand.
- No generator markers remain in hand-maintained modules.

### 7.3 Why a single generated file is safer than split generated fragments

| Option | Decision | Why |
|---|---|---|
| Keep markers in one hand-maintained file | No | still mixes ownership and keeps drift risk |
| Split generator output across multiple module files | No | makes regeneration order and ownership harder to reason about |
| One dedicated generated header | **Yes** | smallest blast radius, clearest seam, easiest preflight guard |

### 7.4 Drift prevention

Phase Y should add explicit guardrails:

- `render_sensor_config.py --check` must verify the generated header is in sync.
- `scripts/preflight.sh` must verify that **no** `SENSOR_MANIFEST:*` markers remain in hand-maintained firmware/core files.
- `scripts/preflight.sh` must verify the generated header contains:
  - `NUM_DEVICES`
  - `NUM_ENV_SENSORS`
  - `NUM_SENSORS = NUM_ENV_SENSORS`
  - `devices[]`
  - `PING_*` macros when ping devices exist
- the assembly/identity script must include the generated header in the canonical fragment list

---

## 8. HTTP Route Ownership Model

### 8.1 Current route inventory (reference surface)

The current header owns the following route families:

| Route family | Current examples |
|---|---|
| dashboard asset routes | `/dashboard`, `/dashboard.html`, `/dashboard-download`, `/favicon.ico` |
| manifest routes | `/sensors.json`, `/api/manifest` |
| live/history routes | `/api/v2/live`, `/api/v2/history/...`, legacy `/history/...` |
| ingest route | `/api/ingest/...` |
| status/storage routes | `/api/status`, `/api/storage-stats` |
| management routes | `/api/reboot`, `/api/delete-data`, `/api/system/reset-satellites` |
| import routes | `/api/import/begin`, `/api/import/begin/single/...`, `/api/import/d/...`, `/api/import/w/...`, `/api/import/finish` |
| aggregator routes | `/api/aggregator/gateways`, `/api/aggregator/live`, `/api/aggregator/proxy/...`, `/api/aggregator/add-satellite`, `/api/aggregator/test-satellite`, `/api/aggregator/satellite/{id}` |

Phase Y does **not** change any path, method, auth requirement, or payload shape.

### 8.2 Target ownership model

| Module | Route families owned |
|---|---|
| `history_web_handler_local.inc` | dashboard assets, manifest, v2 live/history, ingest, storage stats, status, legacy history |
| `history_web_handler_import.inc` | import begin/data/finish and all import helper methods/state transitions |
| `history_web_handler_management.inc` | reboot/delete-data and other non-aggregator management route methods if split separately |
| `history_web_handler_aggregator.inc` | aggregator gateways/live/proxy/add/delete/test/reset handlers |

### 8.3 Dispatcher contract

`canHandle()` / `handleRequest()` remain centralized in `history_web_handler.h`.

That file continues to own:

- method / path classification
- OPTIONS and POST gating
- auth preconditions
- route-family dispatch
- final fallback / error behavior

The split only moves handler implementations, not route selection policy.

### 8.4 Why this is safer than one-handler-per-route-class

A deeper OO split (separate web handler classes per domain) would require changing:

- handler registration strategy
- `canHandle()` interaction with the patched `web_server_idf`
- auth/header helper duplication
- route ordering assumptions

That is unnecessary for a structural-only phase. One central handler with domain-scoped method fragments keeps behavior stable.

---

## 9. Persistence-Schema Safety (Phase Y-specific)

Phase Y must preserve all current persisted-history behavior. That means:

### 9.1 Must remain unchanged

- `HISTORY_NAMESPACE`
- partition label / partition lookup behavior
- `HistoryMeta` blob structure
- `SegmentSnapshotHeader` / `SegmentSnapshot` layout
- slot numbering (`seg_%03d`)
- restore order and ring-buffer semantics
- import compatibility
- `NUM_ENV_SENSORS` / `NUM_SENSORS` semantics
- the current distinction between persisted environmental sensors and RAM-only device types

### 9.2 Explicit rule for count semantics

The generated topology module must continue to emit:

```cpp
static constexpr int NUM_ENV_SENSORS = ...;
static constexpr int NUM_SENSORS = NUM_ENV_SENSORS;  // backward compat alias
```

It must **not** collapse to `NUM_DEVICES`.

This is non-negotiable because Phase Y is structural only and BUG-045/046/048 established that persisted schema width is tied to environmental-sensor count semantics, not total device count.

### 9.3 Phase 7 extension point

`history_store.h` is the module that Phase 7 will later extend/replace with:

- `DeviceHistoryMeta`
- `DeviceSegment`
- hash-key helpers
- per-device restore/persist
- migration logic
- per-device delete / storage stats / import/export

Phase Y’s job is to create that seam without changing the current schema.

---

## 10. Aggregator Two-Island Plan

### 10.1 Current structural reality

Aggregator logic is currently split across two physical regions:

1. a top-level runtime island (shared structs, mutex, fetch/poll/NVS helpers, deferred tasks)
2. a route-handler island inside `HistoryWebHandler`

The subsystem is logically one thing but physically two things.

### 10.2 Final resolution

Phase Y resolves this with three pieces:

```text
firmware/core/aggregator_state.h
firmware/core/aggregator_runtime.h
firmware/core/history_web_handler_aggregator.inc
```

### 10.3 Shared state surface

`aggregator_state.h` owns and exposes:

- `SatelliteCache`
- `SatelliteNVSSnapshot`
- `satellite_caches[]`
- `runtime_satellite_count`
- `satellite_config_generation`
- `s_cache_mutex`
- `AGG_LOCK` / `AGG_UNLOCK`
- `s_fetch_tmp`
- `s_proxy_tmp`
- `s_proxy_len`
- `s_reset_satellites_in_progress`
- `s_nvs_save_in_progress`

This makes the hidden coupling explicit.

### 10.4 Runtime / routes relationship

- `aggregator_runtime.h` mutates and reads shared aggregator state.
- `history_web_handler_aggregator.inc` reads and mutates that same state through the explicit shared surface.
- `satellite_config_generation` stays shared so mutation handlers and the poll task continue to coordinate exactly as they do today.
- Deferred-task visibility is preserved because the route methods still call the same scheduler functions; they just live in `aggregator_runtime.h` instead of the monolith.

### 10.5 Why the two islands should not be extracted “together” into one file

Keeping runtime and routes in one new file would technically reduce file count, but it would also preserve the current hidden coupling and fail the main architectural value of Phase Y. The right split is not “one aggregator file”; it is:

- shared state surface
- runtime implementation
- route implementation

That is the smallest split that creates true ownership boundaries without behavior change.

---

## 11. Task / Mutex / Deferred-Work Safety

### 11.1 Deferred-task pairs and their target homes

| Pair | Target home |
|---|---|
| `reboot_task_()` / `schedule_reboot_()` | `management_tasks.h` |
| `delete_data_task_()` / `schedule_delete_data_()` | `management_tasks.h` |
| `reset_satellites_task_()` / `schedule_reset_satellites_()` | `aggregator_runtime.h` |
| `save_satellites_nvs_task_()` / `schedule_save_satellites_nvs_()` | `aggregator_runtime.h` |

### 11.2 Mutex / flag visibility

Phase Y must preserve visibility for:

- `s_cache_mutex`
- `AGG_LOCK` / `AGG_UNLOCK`
- `satellite_config_generation`
- `s_delete_data_in_progress`
- `s_reset_satellites_in_progress`
- `s_nvs_save_in_progress`

The split must not silently convert any of those into duplicated statics hidden in different fragments.

### 11.3 Yield safety

`maybe_yield_nvs_scan_()` must remain reachable from every NVS-heavy scan loop that currently uses it, including:

- restore-from-NVS paths
- history export/history scan paths
- import map-building paths
- any new future loops added within the same history-store surface

That helper belongs in `history_store.h`, not in a route module, because it is part of the persistence safety contract rather than one route family.

### 11.4 Static buffer ownership

The split must preserve clear ownership of:

- generated `HistoryBuffer` statics → generated topology file
- `devices[]` → generated topology file
- aggregator buffers (`s_fetch_tmp`, `s_proxy_tmp`, `s_proxy_len`) → `aggregator_state.h`

No buffer should move into a route fragment if it is also used by runtime code.

---

## 12. Test and Guardrail Surface

### 12.1 Existing test coverage that already guards Phase Y

Phase Y correctness is already partially protected by existing tests and checks:

| Surface | Current guard |
|---|---|
| route presence / basic payload contracts | `scripts/preflight.sh` grep checks and manifest checks |
| dashboard boot and live/history behavior | `tests/browser/boot-structure.spec.js`, `history-charts.spec.js` |
| aggregator UI assumptions | `tests/browser/aggregator.spec.js`, `satellite-management.spec.js` |
| mock route expectations | `tests/mock-server/server.js` |
| YAML validity | `esphome config` in preflight when ESPHome is installed |
| generator sync | `python3 scripts/render_sensor_config.py --check` |

### 12.2 New preflight checks Phase Y should add

| Check | Purpose |
|---|---|
| `sensor_history_fragment_manifest_sync` | fragment assembly script matches canonical file list/order |
| `sensor_history_shim_is_thin` | if shim retained, it only includes fragments / compatibility comments, not runtime logic |
| `sensor_topology_generated_sync` | generated topology header is in sync |
| `sensor_topology_markers_not_in_hand_files` | no `SENSOR_MANIFEST:*` markers remain outside generated header |
| `phase_y_yaml_include_order` | YAML include order matches canonical list |
| `aggregator_state_single_owner` | shared aggregator state symbols exist in exactly one module |
| `deferred_task_homes_present` | all four deferred-task pairs present in expected modules |
| `yield_guard_still_present` | `maybe_yield_nvs_scan_()` still referenced in the expected loops |
| `num_sensors_alias_guard` | existing BUG-045 regression guard survives generator move |

### 12.3 Need for new tests

**Decision: existing browser tests plus stronger preflight are sufficient for Phase Y.**

New firmware-specific tests are not required for the split itself because:

- Phase Y is structural only
- existing Playwright suites already cover the downstream contracts that must not change
- the higher-value additions are preflight architecture guards plus device smoke tests in the steps that touch boot/runtime wiring

---

## 13. Migration Safety Rules

These rules apply to **every** Phase Y step without exception.

1. **No behavior changes.** Structural reorganization only.
2. **All existing Playwright tests must pass after each step.**
3. **All existing preflight checks must pass after each step.**
4. **`esphome config firmware/esp32-c3-multi-sensor.yaml` must remain valid after each step.**
5. **Endpoint contracts are unchanged.** Same paths, methods, auth requirements, payload shapes, and fallback behavior.
6. **Persisted-history schema and NVS compatibility are unchanged.**
7. **Each step is independently revertable.**
8. **Phase Y preserves all post-Phase X dashboard/test/build assumptions.**
9. **Generated artifacts remain valid after each step.**
10. **Deferred-task patterns survive unchanged.**
11. **Mutex / lock scope survives unchanged.**
12. **`maybe_yield_nvs_scan_()` survives unchanged in all current scan paths.**
13. **`NUM_ENV_SENSORS` / `NUM_SENSORS` semantics remain unchanged.**
14. **Aggregator shared state is single-owner.** No duplicated `satellite_config_generation`, mutex, or temp buffers.
15. **Route dispatch stays centralized unless a later explicit phase changes it.**

---

## 14. Versioned Implementation Steps

### `v7.6.6.0` — `provision.sh` full-pipeline automation pre-step

**Level:** Pre-step — tooling / workflow only  
**Goal:** Make `scripts/provision.sh` execute the full local regeneration pipeline instead of only running `render_sensor_config.py --write` and printing the rest. Add `--dry-run`. Update workflow docs.

#### Scope

- add a pipeline runner function that can execute all current local steps in order
- support `--dry-run` to preview commands without mutating files
- keep `status`, `aggregator`, `satellite`, `wroom` semantics unchanged
- preserve the “return to CI-safe satellite before push” guidance
- update docs and prompt-index references to the new provisioning behavior

#### Files modified

| Action | File |
|---|---|
| MODIFY | `scripts/provision.sh` |
| MODIFY | `prompts/prompt-index-and-workflow.md` |
| MODIFY | `Docs/lessons/build-pipeline.md` |
| MODIFY | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.0` |

#### Acceptance criteria

- [ ] `bash scripts/provision.sh satellite` runs the full local pipeline from config switch through final `render_sensor_config.py --check`
- [ ] `bash scripts/provision.sh aggregator` and `... wroom` do the same
- [ ] `bash scripts/provision.sh <mode> --dry-run` prints the exact commands in order and performs no writes
- [ ] `status` remains non-mutating
- [ ] existing validation messages about CI-safe satellite mode are preserved
- [ ] `bash scripts/preflight.sh` passes
- [ ] no firmware/runtime behavior changes

#### Risk: **Low**
#### Estimated effort: 0.5–1 session
#### Identity / verification gate

- command-plan identity: dry-run output must match the actual execution order
- `bash scripts/preflight.sh`
- `python3 scripts/render_sensor_config.py --check`

#### Gate conditions to proceed

- [ ] local full-pipeline automation works in all three modes
- [ ] no repo-generated artifact drift after provision runs
- [ ] no code files outside the intended pipeline outputs change unexpectedly

---

### `v7.6.6.1` — establish assembly verifier and generated topology seam

**Level:** Foundation  
**Goal:** Create the Phase Y verification scaffold and extract the generator-owned topology into `firmware/core/generated/sensor_topology.generated.h` without changing behavior.

#### Scope

- create `firmware/core/` and `firmware/core/generated/`
- create `scripts/assemble-sensor-history.py` (or equivalent) with `--check` / `--write-baseline`
- move the generator-owned marker output out of `dashboard/sensor_history_multi.h` and into the dedicated generated header
- convert `dashboard/sensor_history_multi.h` into a thin assembly wrapper that includes:
  - existing generated headers
  - new core modules as they appear
  - the new generated topology header
- keep YAML include list unchanged in this step (still referencing the shim) to limit blast radius

#### Files modified / created

| Action | File |
|---|---|
| CREATE dir | `firmware/core/` |
| CREATE dir | `firmware/core/generated/` |
| CREATE | `firmware/core/history_base.h` (initial substrate extraction / declarations only) |
| CREATE | `firmware/core/generated/sensor_topology.generated.h` |
| CREATE | `scripts/assemble-sensor-history.py` |
| MODIFY | `scripts/render_sensor_config.py` |
| MODIFY | `dashboard/sensor_history_multi.h` |
| MODIFY | `scripts/preflight.sh` |
| MODIFY | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.1` |

#### Acceptance criteria

- [ ] generator no longer writes marker blocks into hand-maintained files
- [ ] generator writes only `firmware/core/generated/sensor_topology.generated.h` for Phase Y topology content
- [ ] `dashboard/sensor_history_multi.h` becomes a thin assembly wrapper with no generator markers
- [ ] assembly verifier can reconstruct a normalized monolith and compare it to the saved baseline
- [ ] `NUM_ENV_SENSORS` / `NUM_SENSORS` regression guards remain intact
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] all existing Playwright tests pass

#### Risk: **Medium**
Generator retargeting is the most sensitive ownership change in Phase Y.

#### Estimated effort: 1–2 sessions

#### Identity / verification gate

- source-identity gate: assembled normalized output matches baseline normalized monolith
- `python3 scripts/render_sensor_config.py --check`
- `bash scripts/preflight.sh`
- `esphome config firmware/esp32-c3-multi-sensor.yaml`

#### Gate conditions to proceed

- [ ] generated topology seam is explicit and stable
- [ ] no `SENSOR_MANIFEST:*` markers remain in hand-maintained firmware files
- [ ] assembly verifier is green on clean tree

---

### `v7.6.6.2` — extract history substrate and persisted-history core

**Level:** Core extraction  
**Goal:** Move the top-of-file substrate and the persisted-history/NVS core into `history_base.h` and `history_store.h`.

#### Scope

- move shared non-generated declarations and `HistoryBuffer` into `history_base.h`
- move `HistoryMeta`, `SegmentSnapshot*`, NVS helpers, restore/persist, stream/export helpers, and `maybe_yield_nvs_scan_()` into `history_store.h`
- keep external symbol names and call sites unchanged
- keep shim/YAML includeing through the wrapper to reduce simultaneous churn

#### Files modified / created

| Action | File |
|---|---|
| EXPAND | `firmware/core/history_base.h` |
| CREATE | `firmware/core/history_store.h` |
| MODIFY | `dashboard/sensor_history_multi.h` |
| MODIFY | `scripts/assemble-sensor-history.py` |
| MODIFY | `scripts/preflight.sh` |
| MODIFY | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.2` |

#### Acceptance criteria

- [ ] `history_base.h` owns shared firmware substrate declarations and `HistoryBuffer`
- [ ] `history_store.h` owns persisted-history structs and core NVS/persist/restore helpers
- [ ] `maybe_yield_nvs_scan_()` lives in `history_store.h`
- [ ] `restore_from_nvs()` and `persist_hourly_segment()` signatures/behavior unchanged
- [ ] all existing BUG-043 / BUG-045 regression guards still pass
- [ ] source-identity gate passes
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] all existing Playwright tests pass

#### Risk: **Medium**
This step touches the persistence core that later phases depend on.

#### Estimated effort: 1–2 sessions

#### Identity / verification gate

- source-identity gate: assembled normalized output matches baseline
- compile/config gate: `esphome config`
- behavioral gate: Playwright suites + one satellite-mode device smoke test covering boot + history display

#### Gate conditions to proceed

- [ ] persistence schema unchanged
- [ ] history restore after reboot still works on real device
- [ ] no new preflight drift on route or NVS guards

---

### `v7.6.6.3` — extract management deferred tasks, PingAdapter, and orchestration tail

**Level:** Contiguous block extraction  
**Goal:** Remove the three easiest remaining contiguous blocks from the wrapper: management deferred tasks, `PingAdapter`, and `register_history_handler()`.

#### Scope

- move reboot/delete-data deferred tasks into `management_tasks.h`
- move `PingAdapter` into `ping_adapter.h`
- move `register_history_handler()` into `orchestration.h`
- keep `on_boot` YAML behavior unchanged

#### Files modified / created

| Action | File |
|---|---|
| CREATE | `firmware/core/management_tasks.h` |
| CREATE | `firmware/core/ping_adapter.h` |
| CREATE | `firmware/core/orchestration.h` |
| MODIFY | `dashboard/sensor_history_multi.h` |
| MODIFY | `scripts/assemble-sensor-history.py` |
| MODIFY | `scripts/preflight.sh` |
| MODIFY | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.3` |

#### Acceptance criteria

- [ ] `management_tasks.h` owns reboot/delete-data deferred tasks and related flags
- [ ] `ping_adapter.h` owns all ping adapter code
- [ ] `orchestration.h` owns `register_history_handler()`
- [ ] YAML `on_boot` behavior unchanged
- [ ] ping initialization still works when ping devices exist
- [ ] source-identity gate passes
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] all existing Playwright tests pass

#### Risk: **Low–Medium**
These are structurally clean blocks, but PingAdapter touches task startup and generated ping macros.

#### Estimated effort: 1 session

#### Identity / verification gate

- source-identity gate
- `esphome config`
- targeted device smoke:
  - ping-enabled build boots
  - dashboard route still registers
  - reboot/delete-data endpoints still reachable/auth-protected

#### Gate conditions to proceed

- [ ] ping boot path stable
- [ ] management task scheduling stable
- [ ] route registration unchanged

---

### `v7.6.6.4` — extract aggregator shared state and runtime island

**Level:** Aggregator runtime extraction  
**Goal:** Pull the top-level aggregator runtime island out of the shim and make the shared aggregator surface explicit.

#### Scope

- create `aggregator_state.h` for shared structs/globals/mutex/macros/flags/buffers
- create `aggregator_runtime.h` for fetch/probe/load/save/init/poll/start and the two aggregator deferred-task pairs
- leave aggregator route methods in the handler for now, but switch them to consume the explicit shared/runtime headers

#### Files modified / created

| Action | File |
|---|---|
| CREATE | `firmware/core/aggregator_state.h` |
| CREATE | `firmware/core/aggregator_runtime.h` |
| MODIFY | `dashboard/sensor_history_multi.h` |
| MODIFY | `scripts/assemble-sensor-history.py` |
| MODIFY | `scripts/preflight.sh` |
| MODIFY | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.4` |

#### Acceptance criteria

- [ ] `aggregator_state.h` is the sole owner of shared aggregator state symbols
- [ ] `aggregator_runtime.h` owns polling/fetch/NVS/runtime helpers and deferred satellite tasks
- [ ] `satellite_config_generation` remains single-owner and visible to both runtime and route layers
- [ ] `AGG_LOCK` / `AGG_UNLOCK` remain available wherever aggregator state is accessed
- [ ] source-identity gate passes
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] aggregator Playwright suites pass

#### Risk: **High**
This is the first step that materially changes the aggregator’s hidden coupling shape.

#### Estimated effort: 1–2 sessions

#### Identity / verification gate

- source-identity gate
- `esphome config`
- targeted Playwright:
  - `aggregator.spec.js`
  - `satellite-management.spec.js`
- device smoke in aggregator mode:
  - poll task starts
  - `/api/aggregator/gateways`
  - `/api/aggregator/live`
  - `/api/aggregator/proxy/...`

#### Gate conditions to proceed

- [ ] aggregator runtime stable on real hardware
- [ ] no duplicated shared-state symbols
- [ ] NVS load/save for satellites still behaves identically

---

### `v7.6.6.5` — split `HistoryWebHandler` into route-family fragments (local/import/management)

**Level:** Handler decomposition  
**Goal:** Keep `HistoryWebHandler` as one class but split its implementation by domain.

#### Scope

- create `history_web_handler.h` with:
  - class declaration
  - central dispatcher
  - auth/common helpers
  - includes of implementation fragments
- move non-aggregator route implementations into:
  - `history_web_handler_local.inc`
  - `history_web_handler_import.inc`
  - optionally `history_web_handler_management.inc`
- keep aggregator handler methods in the wrapper or a dedicated fragment for the next step

#### Files modified / created

| Action | File |
|---|---|
| CREATE | `firmware/core/history_web_handler.h` |
| CREATE | `firmware/core/history_web_handler_local.inc` |
| CREATE | `firmware/core/history_web_handler_import.inc` |
| CREATE | `firmware/core/history_web_handler_management.inc` (if needed) |
| MODIFY | `dashboard/sensor_history_multi.h` |
| MODIFY | `scripts/assemble-sensor-history.py` |
| MODIFY | `scripts/preflight.sh` |
| MODIFY | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.5` |

#### Acceptance criteria

- [ ] `canHandle()` and `handleRequest()` remain centralized
- [ ] local/dashboard/manifest/live/history/storage/status/ingest methods move behind the central dispatcher
- [ ] import helper state machine and routes move into the import fragment
- [ ] management route methods move without changing auth behavior
- [ ] source-identity gate passes
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] full Playwright suite passes

#### Risk: **High**
The handler class is the highest-traffic contract surface in the file.

#### Estimated effort: 2 sessions

#### Identity / verification gate

- source-identity gate
- `esphome config`
- full Playwright suite
- device smoke:
  - dashboard assets load
  - import begin/data/finish still work
  - reboot/delete-data auth prompts still map to the same firmware behavior

#### Gate conditions to proceed

- [ ] all route families still dispatch correctly
- [ ] import state machine unchanged in behavior
- [ ] no auth/header regressions

---

### `v7.6.6.6` — extract aggregator route fragment and complete the two-island split

**Level:** Aggregator route extraction  
**Goal:** Move the aggregator route-handler island into its dedicated fragment and complete the explicit runtime/state/routes split.

#### Scope

- create `history_web_handler_aggregator.inc`
- move:
  - `handle_aggregator_gateways_()`
  - `handle_aggregator_live_()`
  - `handle_aggregator_proxy_()`
  - `handle_add_satellite_()`
  - `handle_delete_satellite_()`
  - `handle_test_satellite_()`
  - `handle_reset_satellites_()`
- keep central dispatcher unchanged, but point it at the extracted fragment methods

#### Files modified / created

| Action | File |
|---|---|
| CREATE | `firmware/core/history_web_handler_aggregator.inc` |
| MODIFY | `firmware/core/history_web_handler.h` |
| MODIFY | `dashboard/sensor_history_multi.h` |
| MODIFY | `scripts/assemble-sensor-history.py` |
| MODIFY | `scripts/preflight.sh` |
| MODIFY | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.6` |

#### Acceptance criteria

- [ ] aggregator route methods move into their dedicated fragment
- [ ] runtime/routes/shared-state split is complete
- [ ] `satellite_config_generation` still coordinates mutation handlers and poll task
- [ ] deferred satellite tasks remain callable from their trigger contexts
- [ ] source-identity gate passes
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] aggregator Playwright suites pass
- [ ] full Playwright suite passes

#### Risk: **High**
This is the most cross-coupled extraction step in the plan.

#### Estimated effort: 1–2 sessions

#### Identity / verification gate

- source-identity gate
- `esphome config`
- targeted + full Playwright suites
- device smoke in aggregator mode, including add/test/delete/reset satellite flows

#### Gate conditions to proceed

- [ ] aggregator two-island split proven stable
- [ ] no route or mutation regressions
- [ ] no mutex / shared-state visibility regressions

---

### `v7.6.6.7` — switch YAML to explicit core includes, retire wrapper from primary path, close Phase Y

**Level:** Closure / integration cutover  
**Goal:** Make explicit ordered `firmware/core/*` includes the canonical build path. Keep `dashboard/sensor_history_multi.h` only as a compatibility wrapper if still needed.

#### Scope

- update `firmware/esp32-c3-multi-sensor.yaml` include list to the canonical Phase Y order
- update `render_sensor_config.py::generate_board_yaml()` to emit the same list for generated board YAMLs
- add preflight checks for include order and wrapper thinness
- update documentation / prompt-index / lessons for the new module architecture
- optionally retain `dashboard/sensor_history_multi.h` as a compatibility wrapper with an explicit “do not edit” note

#### Files modified

| Action | File |
|---|---|
| MODIFY | `firmware/esp32-c3-multi-sensor.yaml` |
| MODIFY | `scripts/render_sensor_config.py` |
| MODIFY | `scripts/preflight.sh` |
| MODIFY | `dashboard/sensor_history_multi.h` (final thin wrapper, or delete from primary path) |
| MODIFY | `README.md` |
| MODIFY | `prompts/prompt-index-and-workflow.md` |
| MODIFY | `Docs/lessons/firmware.md` |
| MODIFY | `Docs/lessons/build-pipeline.md` |
| MODIFY | `Docs/changelog.md` |
| CREATE | `prompts/handoff/phaseY-results.md` (closure deliverable) |
| VERSION BUMP | `v7.6.6.7` |

#### Acceptance criteria

- [ ] canonical C3 YAML include list uses the explicit Phase Y module order
- [ ] generated board YAMLs emit the same canonical include order
- [ ] preflight verifies include order and wrapper thinness
- [ ] `dashboard/sensor_history_multi.h` is no longer the primary build path
- [ ] all existing Playwright suites pass
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] satellite and aggregator device smoke tests pass
- [ ] Phase Y results/handoff document produced

#### Risk: **Medium**
The code split is already complete by this point; the main risk is include-order integration drift.

#### Estimated effort: 1 session

#### Identity / verification gate

- canonical include-order gate in preflight
- assembly/source-identity gate remains green
- `esphome config`
- full Playwright suite
- satellite + aggregator device smoke

---

## 15. Build / Generation / Integration Pipeline Changes Summary

### 15.1 Current firmware-side arrangement

```text
render_sensor_config.py
  ├─ edits dashboard/sensor_history_multi.h marker blocks
  ├─ edits dashboard/dashboard.js markers
  └─ edits firmware YAML marker blocks / generated board YAMLs
```

### 15.2 After `v7.6.6.1`

```text
render_sensor_config.py
  ├─ edits firmware/core/generated/sensor_topology.generated.h
  ├─ edits dashboard/dashboard.js markers
  └─ edits firmware YAML marker blocks / generated board YAMLs
```

### 15.3 After `v7.6.6.7`

```text
render_sensor_config.py
  ├─ edits firmware/core/generated/sensor_topology.generated.h
  ├─ emits canonical Phase Y include list for generated board YAMLs
  ├─ edits dashboard/dashboard.js markers
  └─ preserves existing YAML marker responsibilities (averaging / ThermoPro / RSSI / text sensors / ping boot)
```

### 15.4 Pipeline changes by step

| Step | Pipeline impact |
|---|---|
| `v7.6.6.0` | `provision.sh` executes full local pipeline; adds `--dry-run` |
| `v7.6.6.1` | generator target path changes for firmware topology output; adds assembly verifier |
| `v7.6.6.2`–`v7.6.6.6` | assembly verifier fragment list expands as code leaves wrapper |
| `v7.6.6.7` | canonical YAML include order changes to explicit module list |

### 15.5 Coordination with `web_server_idf`

Phase Y does **not** change the patched `web_server_idf` local component or its registration model.

The only explicit requirement is:

- route registration must remain compatible with the current single-handler model
- `register_history_handler()` still installs the handler through the same mechanism
- no Phase Y step should require changes to `firmware/local_components/web_server_idf/web_server_idf.cpp` unless the implementation discovers a compile-only include-path issue; that would be treated as a narrowly scoped integration fix, not a design goal

---

## 16. Coding Agent Task Size Analysis

### 16.1 Baseline — today

| Task type | Files needed | Est. tokens |
|---|---|---:|
| Persistence / history task | full monolith + generator + YAML + preflight | ~30K–35K |
| Aggregator task | full monolith + YAML + tests/docs + preflight | ~28K–34K |
| Route/API task | full monolith + dashboard/test consumers + preflight | ~26K–32K |
| Ping-only task | full monolith + YAML + generator | ~24K–28K |

### 16.2 After each Phase Y level

| Version | Typical files needed for a focused task | Est. tokens | Improvement |
|---|---|---:|---:|
| `v7.6.6.0` | unchanged code layout | ~30K–35K | workflow-only |
| `v7.6.6.1` | generated topology + wrapper + generator + preflight | ~24K–28K | ownership seam becomes explicit |
| `v7.6.6.2` | `history_store.h` + `history_base.h` + YAML/preflight | ~18K–22K | persistence tasks no longer load ping/aggregator/handler bulk |
| `v7.6.6.3` | ping or management task module + YAML/preflight | ~10K–14K | contiguous subsystems now isolated |
| `v7.6.6.4` | `aggregator_state.h` + `aggregator_runtime.h` + aggregator tests | ~14K–18K | runtime tasks stop loading local/import/history code |
| `v7.6.6.5` | one handler fragment + handler declaration + tests | ~12K–16K | route-family work becomes domain-scoped |
| `v7.6.6.6` | aggregator handler fragment + aggregator runtime/state + tests | ~12K–16K | full aggregator work now targeted |
| `v7.6.6.7` | explicit final modules only | ~8K–12K | steady-state target |

### 16.3 Final-state task examples

| Task type after Phase Y | Likely files | Est. tokens |
|---|---|---:|
| Phase 7 persist/restore change | `history_store.h`, generated topology header, YAML interval wiring, preflight | ~10K–12K |
| Aggregator route payload change | `history_web_handler_aggregator.inc`, `aggregator_state.h`, `aggregator_runtime.h`, aggregator tests | ~12K–15K |
| Ping behavior change | `ping_adapter.h`, YAML `on_boot`, preflight | ~8K–10K |
| Import bug fix | `history_web_handler_import.inc`, `history_store.h`, tests/mock route assumptions | ~10K–14K |

**Target achieved:** common firmware tasks fall under ~12K–16K tokens instead of ~30K–35K.

---

## 17. Rollout Order and Gate Conditions

### 17.1 Recommended order

1. `v7.6.6.0` — fix the provisioning workflow first
2. `v7.6.6.1` — make the generated seam explicit before moving hand code
3. `v7.6.6.2` — extract the persistence core early because Phase 7 depends on it
4. `v7.6.6.3` — remove the easy contiguous blocks (management, ping, orchestration)
5. `v7.6.6.4` — extract aggregator runtime/shared state
6. `v7.6.6.5` — split non-aggregator handler routes
7. `v7.6.6.6` — split aggregator route island
8. `v7.6.6.7` — switch YAML to explicit includes and close the phase

### 17.2 Why this order is safest

- It handles workflow risk before code-structure risk.
- It makes generator ownership explicit before moving major hand-maintained slices.
- It extracts the clean contiguous blocks before the more coupled handler work.
- It resolves aggregator shared state before splitting aggregator routes.
- It delays the primary YAML include change until the code split is already proven stable.

### 17.3 Where compile-only gates are enough vs. where device testing is required

| Step | Compile-only acceptable? | Device testing required? | Why |
|---|---|---|---|
| `v7.6.6.0` | Yes | No | workflow-only |
| `v7.6.6.1` | Mostly yes | No | seam + generator path, no runtime wiring change |
| `v7.6.6.2` | No | **Yes** | persistence restore/persist moved |
| `v7.6.6.3` | No | **Yes** | ping boot path + management tasks + registration |
| `v7.6.6.4` | No | **Yes** | aggregator runtime / poll / NVS behavior |
| `v7.6.6.5` | No | **Yes** | handler route families + import |
| `v7.6.6.6` | No | **Yes** | aggregator mutation and proxy routes |
| `v7.6.6.7` | No | **Yes** | primary include order changes |

### 17.4 Gate conditions between levels

| Gate | Condition |
|---|---|
| `v7.6.6.0` → `v7.6.6.1` | provisioning full-pipeline automation stable |
| `v7.6.6.1` → `v7.6.6.2` | generated seam explicit; assembly verifier green |
| `v7.6.6.2` → `v7.6.6.3` | persistence boot/history device smoke green |
| `v7.6.6.3` → `v7.6.6.4` | ping + management + registration stable |
| `v7.6.6.4` → `v7.6.6.5` | aggregator runtime shared-state split green |
| `v7.6.6.5` → `v7.6.6.6` | local/import/management routes green |
| `v7.6.6.6` → `v7.6.6.7` | full aggregator split green on tests and hardware |
| Phase Y complete | explicit YAML includes green; wrapper no longer primary path |

---

## 18. Risks and Mitigations

| Risk | Level | Mitigation |
|---|---|---|
| NVS schema breakage during file moves | High | structural-only rule; no field/layout edits; preflight schema guards; device restore smoke after `v7.6.6.2` |
| `#include` order violation causes symbol visibility errors | High | explicit canonical include order; assembly verifier; `esphome config`; delay YAML cutover until `v7.6.6.7` |
| generator marker ownership confusion during split | High | one dedicated generated header; no markers allowed in hand-maintained modules; preflight guard |
| YAML `includes:` drift between C3 and generated board YAMLs | Medium | canonical ordered include list; shared Python constant; preflight include-order check |
| mutex / lock visibility regression across split files | High | explicit `aggregator_state.h` owner; no duplicated statics; dedicated preflight owner check |
| deferred-task function visibility lost after extraction | Medium | explicit target homes and dedicated preflight presence check |
| static buffer ownership ambiguity after split | High | generated topology owns device/history buffers; aggregator_state owns shared aggregator buffers; document ownership in comments and preflight |
| aggregator runtime/routes still coupled through hidden globals | High | `aggregator_state.h` explicit surface; no direct hidden state in route fragment |
| `web_server_idf` registration assumptions break | Medium | keep single `HistoryWebHandler`; do not change registration model; test route install after orchestration extraction |
| binary size / compile changes from include reorganization | Medium | `esphome config` every step; compile smoke on critical steps; no semantic code changes |
| import engine split accidentally changes state-machine behavior | High | keep dispatcher centralized; move import helpers intact; targeted import smoke test |
| wrapper path removal too early breaks docs / tooling | Medium | wrapper retained through most of Phase Y; YAML switch delayed to closure |

---

## 19. Open Questions

The Phase X carryover document listed seven open questions. This plan resolves most of them.

| # | Question from Phase X context | Resolved here? | Resolution |
|---|---|---|---|
| 1 | Identity gate feasibility | **Yes** | use repo-local source-identity assembly gate + compile/test/device gates |
| 2 | Generator strategy | **Yes** | one dedicated generated header under `firmware/core/generated/` |
| 3 | Include order / need for assembly script | **Yes** | explicit canonical YAML include order + assembly verifier script |
| 4 | Mutex visibility placement | **Yes** | `aggregator_state.h` owns mutex/macros/shared state |
| 5 | Test strategy | **Yes** | existing Playwright + stronger preflight + targeted device smoke on runtime-touching steps |
| 6 | Local component coordination | **Mostly** | no design change to `web_server_idf`; preserve single-handler registration model |
| 7 | Phase Y before or after Phase 7 | **Yes** | before Phase 7 |

### Remaining operator-input questions

These are the only choices that may still need operator confirmation before implementation starts:

1. **Compatibility shim retention after `v7.6.6.7`:**  
   Keep `dashboard/sensor_history_multi.h` indefinitely as a compatibility wrapper, or delete it once all YAMLs and docs are updated?  
   **Recommendation:** retain as a thin wrapper for one cycle, then remove in a later cleanup PR.

2. **Exact naming of handler implementation fragments:**  
   `.inc` files are the cleanest fit for route-family method bodies included from `history_web_handler.h`, but `.h` fragments are also possible.  
   **Recommendation:** use `.inc` to make “included implementation fragment” explicit.

3. **Whether to keep `history_web_handler_management.inc` separate:**  
   Reboot/delete-data management routes can live in `history_web_handler_local.inc` if the team prefers fewer files.  
   **Recommendation:** keep separate only if the implementation shows auth/management methods materially clutter the local route fragment.

---

## 20. Phase 7 Compatibility Statement

Phase Y is specifically designed to create clean extension points for Phase 7.

### 20.1 Phase 7 work lands primarily in:

- `firmware/core/history_store.h`
- `firmware/core/generated/sensor_topology.generated.h`
- `firmware/core/history_web_handler_local.inc` / import fragment
- `firmware/esp32-c3-multi-sensor.yaml` interval and boot wiring

### 20.2 Phase 7 work no longer needs to load:

- PingAdapter
- aggregator runtime / route code
- reboot/delete-data deferred task code
- orchestration tail
- generator marker plumbing inside one giant monolith

### 20.3 Why this matters

Phase 7 per-device persistence introduces:

- new history structs and key schemes
- new restore/persist flows
- new migration logic
- per-device delete / storage stats / import-export behavior

Those belong in a dedicated history-store seam. Phase Y creates that seam before the feature phase starts.

---

## 21. Pre-Implementation Verification Checklist

This plan is complete only if the following stay true during implementation:

- [x] Every proposed module boundary is justified by contiguous/scattered analysis
- [x] The plan uses current-file-verified structural ordering, not just abstract logical grouping
- [x] The generator strategy is explicit: one dedicated generated topology header
- [x] The YAML include strategy is explicit with canonical final order
- [x] All 4 deferred-task pairs have explicit target homes
- [x] The mutex / lock visibility strategy is explicit
- [x] The identity / verification gate is defined and feasible
- [x] The `provision.sh` pre-step is fully specified
- [x] Phase 7 compatibility is explicitly addressed
- [x] The aggregator two-island problem has an explicit resolution

**Implementation note:** before the first extraction PR, the executing agent should run `nl -ba dashboard/sensor_history_multi.h` and snapshot exact slice boundaries for the current HEAD. The ranges in the inventory are accurate planning ranges, but the implementation step should treat line-number capture as part of its opening verification, not rely on stale estimates.

---

## 22. Version Number Mapping

| Phase | Version range | Description |
|---|---|---|
| Phase D | `v7.6.0.0`–`v7.6.0.5` | Runtime satellite management |
| Phase X | `v7.6.4.0` + `v7.6.5.0`–`v7.6.5.8` | Dashboard architecture refactor |
| **Phase Y** | **`v7.6.6.0`–`v7.6.6.7`** | **Sensor history / firmware architecture refactor** |
| Phase 7 | `v7.7.0.0`–`v7.7.2.x` | Per-device persistence engine |
| Later | post-`v7.7` | cloud / captive portal / board expansion follow-on work |

---

## 23. Implementation Prompt Structure for Phase Y

Each implementation prompt for `v7.6.6.x` should require, at minimum:

1. current baseline and prerequisite commit/version
2. exact file list for that step
3. do-NOT list (no behavior changes, no bug fixes unless scoped as structural integration)
4. canonical verification gates:
   - assembly/source-identity check
   - `render_sensor_config.py --check`
   - `preflight.sh`
   - `esphome config`
   - targeted Playwright suites
   - device smoke where applicable
5. explicit reminder of:
   - `NUM_SENSORS = NUM_ENV_SENSORS`
   - single-owner aggregator state
   - centralized route dispatcher
   - no generator markers outside the dedicated generated header
6. post-step docs / lessons / prompt-index updates where applicable

---

_End of Phase Y Sensor History Architecture and Refactor Plan (GPv2)._
