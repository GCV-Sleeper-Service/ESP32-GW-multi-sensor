# Phase Y — Architecture and Refactor Plan for `sensor_history_multi.h`

_Planned version range: `v7.6.6.0`–`v7.6.6.7`_  
_Primary subject: `dashboard/sensor_history_multi.h`_  
_Output filename: `Docs/phase-Y-architecture-and-refactor-plan-sensor-history-GP.md`_  
_Status: planning only — no implementation in this phase_  
_Depends on: Phase X complete on `main`; current baseline observed at `v7.6.5.8`_

---

## 0. Scope, intent, and resolved planning decisions

Phase Y is a **structural refactor only**. Its job is to split the current 4,325-line firmware header monolith into responsibility-oriented modules without changing firmware behavior, endpoint contracts, persisted-history schema, YAML semantics, or dashboard expectations.

This plan explicitly **does not** include:

- YAML slimming / moving lambdas into separate headers beyond what is necessary to keep the build wired
- new board templates
- sensor addition/removal workflow changes
- dashboard bug fixes
- Phase 7 per-device persistence implementation
- documentation reorganization outside the Phase Y planning artifact itself

This plan **does** include the required pre-step:

- `v7.6.6.0` — convert `scripts/provision.sh` from a partial helper into a full local regeneration pipeline entry point with `--dry-run`

### 0.1 Key planning decisions

| Decision area | Decision | Why |
|---|---|---|
| Target directory | Use `firmware/core/history/` | Keeps the firmware split clearly outside `dashboard/`, matches future Phase 7 ownership, and avoids implying that the firmware runtime lives in the browser layer. |
| Generated-vs-hand-maintained seam | Move generated topology content into a dedicated generated header: `firmware/core/history/generated_sensor_topology.h` | The current marker blocks are embedded in the monolith. Phase Y should make generated ownership explicit instead of scattering markers across hand-maintained modules. |
| Transitional assembly | Keep `dashboard/sensor_history_multi.h` temporarily as a thin compatibility assembly shim during intermediate steps; final target is direct YAML inclusion of the split headers | This minimizes disruption while the split is staged, then removes the “monolith as primary surface” once the split is stable. |
| Identity gate | Use **normalized preprocessor output comparison** as the primary structural identity gate, backed by compile/tests/device validation | Binary identity is not practical in ESPHome/ESP-IDF builds. Preprocessor output is the closest feasible analogue to Phase X byte-for-byte assembly checks. |
| Aggregator split strategy | Extract aggregator into **shared state + runtime + route-handler implementation** rather than trying to force the two physical islands into one contiguous file move | The aggregator currently spans a top-level runtime island and a `HistoryWebHandler` route island. Treating it as one contiguous slice would be artificial and brittle. |
| Route ownership | Keep one `HistoryWebHandler` class, but split its implementation into core and aggregator implementation headers | This preserves the current dispatch model and avoids changing route registration semantics while still shrinking task scope. |
| YAML include ownership | Hand-maintained in YAML during early transition; generator-owned final ordered include block by the end of Phase Y | Early steps need minimal churn; final state should stop relying on manual synchronization once the include chain stabilizes. |
| Phase 7 compatibility | Create clean extension points now for persistence schema/runtime and generated topology | Phase 7’s per-device persistence engine should extend targeted modules rather than re-entering a monolith. |

---

## §1. Current State Analysis

The current `dashboard/sensor_history_multi.h` is a **4,325-line monolith** that mixes multiple distinct firmware responsibilities into one include surface. The Phase Y inventory identifies roughly a dozen responsibility zones packed into a single file, including:

- core types and constants
- generated topology and metric definitions
- RAM history buffers
- persisted-history schema and NVS restore/persist logic
- import/export helpers
- management auth and deferred management tasks
- `PingAdapter`
- aggregator cache/state/polling/NVS helpers
- all HTTP endpoint dispatch and handler implementations
- registration/orchestration tail

### 1.1 Why the current structure is expensive

For a coding agent, the current file imposes three costs:

1. **Context burden**  
   A task in one subsystem frequently requires loading most or all of a ~30K-token header to safely edit a 100–250 line area.

2. **Boundary ambiguity**  
   Ownership is implicit rather than enforced. For example, aggregator logic lives partly in top-level helpers and partly inside `HistoryWebHandler`, while persistence logic is partly top-level and partly route-facing.

3. **Generated/manual seam ambiguity**  
   The current generated marker blocks are embedded inside hand-maintained code. This makes it too easy for an implementation step to drift generator output, hand edits, and YAML includes at the same time.

### 1.2 Why Phase 7 and later work make this worse if left unsplit

If the file remains monolithic, the next major roadmap items amplify the problem:

- **Phase 7 per-device persistence** will add new persistence structs, key builders, restore/persist paths, migration helpers, and storage-stats changes to the same file that already owns v7 persistence and route dispatch.
- **Phase 8 cloud / upstream sync** will likely add new transport and state-management surfaces adjacent to already-dense aggregator runtime code.
- **Captive portal / onboarding** will add more HTTP/state/config workflow around a handler class that is already the firmware’s main accretion point.

Without Phase Y, future work continues to raise regression risk because every change touches the same monolith and the same include boundary.

### 1.3 Current task-size estimate

The current monolith means a “typical firmware task” has to over-read:

| Task type | Current likely context needed |
|---|---:|
| Persist/restore bugfix | 18K–30K tokens |
| Aggregator runtime change | 20K–30K tokens |
| Management endpoint change | 15K–28K tokens |
| Route registration / auth fix | 12K–25K tokens |
| Ping-only work | 10K–20K tokens |

In practice, a safe change often requires reading the file nearly end-to-end because line-local edits can affect generated sections, shared statics, macros, route dispatch, or YAML include expectations.

---

## §2. Proposed Directory Structure

### 2.1 Before

```text
dashboard/
  dashboard.h
  dashboard.html
  dashboard.js
  sensor_history_multi.h      ← 4,325-line firmware monolith

firmware/
  esp32-c3-multi-sensor.yaml
  boards/
  local_components/

src/
  gateway_manifest.h
  aggregator_config.h
```

### 2.2 After (final Phase Y target)

```text
dashboard/
  dashboard.h
  dashboard.html
  dashboard.js
  sensor_history_multi.h                 ← temporary thin compatibility shim, then optional deprecated wrapper

firmware/
  esp32-c3-multi-sensor.yaml
  boards/
  local_components/
  core/
    history/
      history_common.h
      generated_sensor_topology.h        ← generator-owned
      persistence_schema.h
      persistence_runtime.h
      management_tasks.h
      ping_adapter.h
      aggregator_state.h
      aggregator_runtime.h
      history_web_handler.h
      history_web_handler_core_impl.h
      history_web_handler_aggregator_impl.h
      orchestration.h

src/
  gateway_manifest.h
  aggregator_config.h
```

### 2.3 Module boundary rationale

| Target module | Owns | Why this boundary is correct |
|---|---|---|
| `history_common.h` | common includes, constants, small shared types/macros that are not generator-owned | Creates a stable foundation and reduces duplicated include-order coupling. |
| `generated_sensor_topology.h` | generated counts, metric defs, device arrays, sensor/entity constants, ping constants, generated static buffers currently emitted into the monolith | Makes the generated seam explicit and drift-resistant. |
| `persistence_schema.h` | `HistoryMeta`, `SegmentSnapshotHeader`, `SegmentSnapshot`, schema-level constants, size/static_assert guards if added later | Separates “what is persisted” from “how it is restored/served”. Critical for Phase 7 extension. |
| `persistence_runtime.h` | RAM history helpers, NVS restore/persist/import/export helpers, `maybe_yield_nvs_scan_()` | This subsystem is mostly contiguous and is the main downstream extension point for Phase 7. |
| `management_tasks.h` | deferred reboot/delete-data task helpers, auth-adjacent management task glue that is not aggregator-specific | Pulls non-aggregator deferred work out of the route class without changing behavior. |
| `ping_adapter.h` | `PingAdapter` class and its helper functions | Inventory identified this as a contiguous slice and isolated feature area. |
| `aggregator_state.h` | shared structs, caches, mutex, macros, generation counter, shared constants | Explicitly solves the aggregator two-island problem by centralizing shared state instead of leaving it implicit in one island. |
| `aggregator_runtime.h` | polling task, fetch/probe helpers, NVS load/save helpers, runtime mutators | Keeps non-route aggregator logic together and visible to future Phase 8 work. |
| `history_web_handler.h` | `HistoryWebHandler` class declaration, method declarations only | Preserves the existing dispatch model while making implementation split possible. |
| `history_web_handler_core_impl.h` | non-aggregator route implementations: manifest, live, history, import, storage-stats, status, auth helpers, reboot/delete-data, dashboard/download/static helpers | These are the core firmware route surfaces the post-Phase X dashboard depends on. |
| `history_web_handler_aggregator_impl.h` | aggregator route implementations and aggregator-specific route predicates | Keeps aggregator route ownership explicit while preserving one handler and one dispatch entry point. |
| `orchestration.h` | `register_history_handler(...)`, boot registration glue, restore-on-register choreography | Small, contiguous registration tail; keeps startup wiring obvious. |

### 2.4 Why not other decompositions

#### Why not keep generated markers split across multiple files?
Because the current generator already treats the monolith as its output target. Splitting markers across multiple hand-maintained files would multiply drift surfaces during a structural-only phase and make preflight harder to reason about.

#### Why not extract the full aggregator as one file?
Because it is not physically contiguous. The runtime island and the route-handler island share mutex/state/generation-counter/deferred-task concerns. A single-file extraction would either require artificial reassembly or a behavior-changing route rewrite. Phase Y should avoid both.

#### Why keep one `HistoryWebHandler` class?
Because the current `canHandle()` / `handleRequest()` pattern is part of the live contract. Splitting into multiple handler classes is possible later, but it is not the lowest-risk structural-only move for Phase Y.

---

## §3. Versioned Steps

## v7.6.6.0 — `provision.sh` full pipeline automation prerequisite

**Goal:** Make local iterative firmware work reliable before the structural split starts.

### Files modified
- `scripts/provision.sh`
- `Docs/aggregator-setup.md` or equivalent operator workflow doc if that is the current canonical workflow reference
- `Docs/changelog.md`
- this Phase Y plan doc may reference the behavior, but no other code files should change

### Planned changes
- Convert `scripts/provision.sh` from “switch config + run render + print remaining steps” to “switch config + execute the full 8-step regeneration pipeline”.
- Add `--dry-run` to preview exactly what commands would run without mutating files.
- Preserve the current `status`, `aggregator`, `satellite`, `wroom` target semantics.
- Preserve the CI-safe warning and “switch back to satellite before push” guidance.
- Fail fast if any pipeline command fails.

### Acceptance criteria
- [ ] `bash scripts/provision.sh aggregator` executes the full 8-step regeneration pipeline after switching config
- [ ] `bash scripts/provision.sh satellite` does the same for the CI-safe C3 path
- [ ] `bash scripts/provision.sh --dry-run aggregator` prints the exact commands in order without mutating files
- [ ] pipeline output clearly distinguishes switch/validation/build phases
- [ ] `bash scripts/preflight.sh` still passes after a no-op `satellite` switch on a clean tree
- [ ] operator docs reflect the new workflow and no longer describe manual post-switch execution as the primary path

**Risk:** Low  
**Estimated effort:** 1 session

### Identity / verification gate
- Structural diff only for `provision.sh`
- `bash scripts/preflight.sh`
- `esphome config firmware/esp32-c3-multi-sensor.yaml`

### Gate conditions
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] no firmware/runtime files changed outside intended workflow/docs surfaces

---

## v7.6.6.1 — Establish the assembly seam and structural identity gate

**Goal:** Create a safe staging point for extraction without changing behavior.

### Files created/modified
- `dashboard/sensor_history_multi.h` (converted to explicit assembly wrapper, but still compiling the exact existing content)
- `firmware/core/history/history_common.h` (minimal starter file)
- `scripts/check_sensor_history_assembly.py` (or similarly named verification script)
- `scripts/preflight.sh`
- `Docs/changelog.md`

### Planned changes
- Introduce a **formal assembly strategy** for the firmware header split.
- In this step, the actual code can still remain effectively monolithic, but the file should be restructured so the split will happen through includes rather than ad-hoc copy/paste in later steps.
- Add a verification tool that compares the normalized preprocessor output of the new include-assembled form against the current baseline output.
- The normalization step should strip line markers and other preprocessor noise that would otherwise make comparisons unstable.

### Acceptance criteria
- [ ] `dashboard/sensor_history_multi.h` becomes an intentional assembly surface, not an opaque monolith
- [ ] a repeatable script exists that verifies normalized preprocessor output equivalence against the pre-step baseline
- [ ] preflight fails if the assembly-equivalence gate fails
- [ ] no route strings, schema constants, or generated marker output move yet except what is required to create the seam
- [ ] device behavior is unchanged

**Risk:** Medium  
**Estimated effort:** 1–2 sessions

### Identity / verification gate
Primary gate for this step:
1. run the assembly check script
2. compare normalized preprocessor output against baseline
3. then run normal compile/test checks

### Gate conditions
- [ ] normalized preprocessor output matches baseline
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] existing Playwright suites still pass

### Why this step exists
Phase X proved that “identity first, then extraction” reduces refactor risk. For C++ in ESPHome, the closest feasible equivalent is **preprocessor-output identity**, not binary identity.

---

## v7.6.6.2 — Extract generated topology and foundational common surfaces

**Goal:** Move generator-owned topology out of the hand-maintained implementation body.

### Files created/modified
- `firmware/core/history/generated_sensor_topology.h`
- `firmware/core/history/history_common.h`
- `dashboard/sensor_history_multi.h`
- `scripts/render_sensor_config.py`
- `scripts/preflight.sh`
- `firmware/esp32-c3-multi-sensor.yaml` (only if early include addition is needed in this step)
- `Docs/changelog.md`

### Planned changes
- Retarget `render_sensor_config.py` so the current header marker output moves from `dashboard/sensor_history_multi.h` into `firmware/core/history/generated_sensor_topology.h`.
- Keep **all generated marker blocks together in one generated file**.
- `dashboard/sensor_history_multi.h` assembly wrapper includes `history_common.h` and `generated_sensor_topology.h`, then still includes the remaining implementation body as needed.
- Update preflight so generated-header checks point to `generated_sensor_topology.h` for:
  - `NUM_ENV_SENSORS`
  - `NUM_SENSORS = NUM_ENV_SENSORS`
  - generated entity/version markers where appropriate

### Acceptance criteria
- [ ] generator no longer writes marker blocks into hand-maintained implementation code
- [ ] generated topology is isolated in one dedicated generated header
- [ ] preflight validates the new generated file directly
- [ ] `gateway_manifest.h` and `aggregator_config.h` include expectations remain unchanged
- [ ] normalized preprocessor output still matches the v7.6.6.1 baseline

**Risk:** Medium  
**Estimated effort:** 1–2 sessions

### Identity / verification gate
- normalized preprocessor output comparison must still pass
- generator `--write` then `--check` must be clean

### Gate conditions
- [ ] `python3 scripts/render_sensor_config.py --write` succeeds
- [ ] `python3 scripts/render_sensor_config.py --check` succeeds
- [ ] normalized preprocessor output matches baseline
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] existing Playwright suites still pass

### Generator strategy decision locked in here
Generated marker blocks **stay together** in **one dedicated generated header**. They do **not** remain scattered across split modules.

---

## v7.6.6.3 — Extract persistence schema/runtime, management deferred tasks, and `PingAdapter`

**Goal:** Pull out the largest contiguous non-aggregator foundations first.

### Files created/modified
- `firmware/core/history/persistence_schema.h`
- `firmware/core/history/persistence_runtime.h`
- `firmware/core/history/management_tasks.h`
- `firmware/core/history/ping_adapter.h`
- `dashboard/sensor_history_multi.h`
- `scripts/preflight.sh`
- `Docs/changelog.md`

### Planned changes
- Move schema structs/constants to `persistence_schema.h`
- Move persistence/runtime helpers to `persistence_runtime.h`
- Keep `maybe_yield_nvs_scan_()` in `persistence_runtime.h`
- Move reboot/delete-data deferred-task helpers into `management_tasks.h`
- Move the contiguous `PingAdapter` region into `ping_adapter.h`
- Keep include assembly in a way that preserves current symbol visibility and route behavior

### Acceptance criteria
- [ ] `HistoryMeta`, `SegmentSnapshotHeader`, `SegmentSnapshot`, and related persistence constants live in `persistence_schema.h`
- [ ] NVS restore/persist/import/export helpers live in `persistence_runtime.h`
- [ ] `maybe_yield_nvs_scan_()` remains callable from every NVS scan loop
- [ ] reboot/delete-data deferred tasks live outside the route implementation file
- [ ] `PingAdapter` compiles from its own module
- [ ] normalized preprocessor output still matches baseline

**Risk:** Medium  
**Estimated effort:** 2 sessions

### Identity / verification gate
- normalized preprocessor output comparison remains the primary structural gate for this extraction step

### Gate conditions
- [ ] normalized preprocessor output matches baseline
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] existing Playwright suites still pass
- [ ] C3 compile smoke on device path recommended because this step moves `PingAdapter` and NVS helpers

### Why this sequence is safest
This step extracts mostly contiguous, non-aggregator foundations before touching the more coupled route/aggregator surfaces.

---

## v7.6.6.4 — Resolve the aggregator two-island problem with explicit shared state + runtime extraction

**Goal:** Split aggregator internals without changing route behavior.

### Files created/modified
- `firmware/core/history/aggregator_state.h`
- `firmware/core/history/aggregator_runtime.h`
- `dashboard/sensor_history_multi.h`
- `scripts/preflight.sh`
- `Docs/changelog.md`

### Planned changes
- Create `aggregator_state.h` containing:
  - shared structs
  - cache arrays
  - `s_cache_mutex`
  - `AGG_LOCK` / `AGG_UNLOCK`
  - `satellite_config_generation`
  - other shared aggregator constants
- Create `aggregator_runtime.h` containing:
  - poll task
  - fetch/probe helpers
  - satellite NVS load/save helpers
  - runtime mutation helpers
  - deferred reset/save task helpers
  - `start_aggregator_task()`
- Preserve all current deferred-task patterns and generation-counter semantics

### Acceptance criteria
- [ ] shared aggregator state is no longer implicit in a monolithic file
- [ ] `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` are visible anywhere aggregator state is accessed
- [ ] `satellite_config_generation` remains shared between poll task and mutation handlers
- [ ] deferred task helpers remain callable from their existing trigger contexts
- [ ] no aggregator routes move yet except what is necessary to compile against the new runtime/state headers
- [ ] normalized preprocessor output still matches baseline

**Risk:** High  
**Estimated effort:** 2–3 sessions

### Identity / verification gate
- normalized preprocessor output comparison
- targeted aggregator Playwright coverage becomes particularly important in this step

### Gate conditions
- [ ] normalized preprocessor output matches baseline
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] `tests/browser/aggregator.spec.js` passes
- [ ] `tests/browser/satellite-management.spec.js` passes
- [ ] device test on aggregator hardware strongly recommended before proceeding

### Explicit resolution of the aggregator two-island problem
The two islands are **not** extracted as one fake contiguous slice. They are split into:

1. **shared state layer** — stable ownership of mutex/caches/counters
2. **runtime layer** — polling, fetch, NVS, deferred work
3. route layer — moved in the next steps

That is the lowest-risk structural-only approach.

---

## v7.6.6.5 — Extract `HistoryWebHandler` declaration and core route implementations

**Goal:** Reduce the handler monolith while preserving one dispatch surface.

### Files created/modified
- `firmware/core/history/history_web_handler.h`
- `firmware/core/history/history_web_handler_core_impl.h`
- `dashboard/sensor_history_multi.h`
- `scripts/preflight.sh`
- `Docs/changelog.md`

### Planned changes
- Move the `HistoryWebHandler` class declaration into `history_web_handler.h`
- Move **core non-aggregator** method implementations into `history_web_handler_core_impl.h`
- This includes:
  - route predicates not exclusive to aggregator
  - dashboard/static/download helpers
  - manifest/live/history/storage/status handlers
  - import handlers
  - auth helpers
  - reboot/delete-data helpers
  - any management POST/body helpers that belong to the core handler contract

### Acceptance criteria
- [ ] the project still uses one `HistoryWebHandler` class
- [ ] core route implementations no longer live in the assembly shim/monolith
- [ ] endpoint paths, auth policies, response shapes, and methods are unchanged
- [ ] the dispatch order in `canHandle()` / `handleRequest()` remains behaviorally identical
- [ ] normalized preprocessor output still matches baseline

**Risk:** High  
**Estimated effort:** 2–3 sessions

### Identity / verification gate
- normalized preprocessor output comparison
- route-presence preflight checks should now target the implementation assembly or the new core impl file instead of assuming the monolith path

### Gate conditions
- [ ] normalized preprocessor output matches baseline
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] `tests/browser/boot-structure.spec.js` passes
- [ ] `tests/browser/history-charts.spec.js` passes
- [ ] device smoke on C3 is recommended because this step moves most route code

---

## v7.6.6.6 — Extract aggregator route implementations and registration tail

**Goal:** Complete the handler split and finish the route-side aggregator ownership model.

### Files created/modified
- `firmware/core/history/history_web_handler_aggregator_impl.h`
- `firmware/core/history/orchestration.h`
- `dashboard/sensor_history_multi.h`
- `scripts/preflight.sh`
- `Docs/changelog.md`

### Planned changes
- Move aggregator route methods into `history_web_handler_aggregator_impl.h`
- Move `register_history_handler(...)` and the registration tail into `orchestration.h`
- Keep route dispatch model unchanged: one handler instance, same route predicates, same `canHandle()` / `handleRequest()` behavior

### Acceptance criteria
- [ ] aggregator routes have explicit module ownership
- [ ] registration tail no longer lives at the end of a monolithic implementation body
- [ ] all aggregator endpoints still behave identically
- [ ] normalized preprocessor output still matches baseline
- [ ] route strings used by dashboard/tests remain unchanged

**Risk:** High  
**Estimated effort:** 2 sessions

### Identity / verification gate
- final normalized preprocessor output identity check for the temporary assembly-based phase
- then full compile/test/device validation

### Gate conditions
- [ ] normalized preprocessor output matches baseline
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] `tests/browser/aggregator.spec.js` passes
- [ ] `tests/browser/satellite-management.spec.js` passes
- [ ] device testing on aggregator hardware required before finalizing this step

---

## v7.6.6.7 — Final YAML include migration, preflight modernization, and shim deprecation

**Goal:** Switch the primary compile surface from the monolith wrapper to the split module chain.

### Files created/modified
- `firmware/esp32-c3-multi-sensor.yaml`
- board-specific generated YAML templates or generator paths affected by `render_sensor_config.py`
- `scripts/render_sensor_config.py`
- `scripts/preflight.sh`
- `dashboard/sensor_history_multi.h` (reduced to deprecated wrapper or removed from primary path)
- `Docs/changelog.md`

### Planned changes
- Update the YAML `includes:` strategy to point directly at the split module chain in the correct order.
- Stop relying on `dashboard/sensor_history_multi.h` as the primary include surface.
- Update preflight checks to validate:
  - YAML include order
  - generated topology file presence
  - assembly/module route surfaces in their new locations
  - aggregator shared-state invariants
- Keep the wrapper header only as a deprecated compatibility surface if there is still value in retaining it for one version window.

### Final proposed YAML include order

```yaml
includes:
  - ../dashboard/dashboard.h
  - ../src/gateway_manifest.h
  - ../src/aggregator_config.h
  - ../firmware/core/history/history_common.h
  - ../firmware/core/history/generated_sensor_topology.h
  - ../firmware/core/history/persistence_schema.h
  - ../firmware/core/history/persistence_runtime.h
  - ../firmware/core/history/management_tasks.h
  - ../firmware/core/history/ping_adapter.h
  - ../firmware/core/history/aggregator_state.h
  - ../firmware/core/history/aggregator_runtime.h
  - ../firmware/core/history/history_web_handler.h
  - ../firmware/core/history/history_web_handler_core_impl.h
  - ../firmware/core/history/history_web_handler_aggregator_impl.h
  - ../firmware/core/history/orchestration.h
```

### Acceptance criteria
- [ ] YAML includes the full split module chain in the documented order
- [ ] `render_sensor_config.py` knows the final generated-header path
- [ ] preflight validates split-architecture invariants instead of monolith-specific assumptions
- [ ] compile/test/device validation all pass
- [ ] `dashboard/sensor_history_multi.h` is no longer the primary build surface

**Risk:** Medium-High  
**Estimated effort:** 1–2 sessions

### Identity / verification gate
At this final step, the identity gate transitions from “temporary assembly equivalence to original monolith” to “stable split architecture validation”. The required gate becomes:

1. `bash scripts/preflight.sh`
2. `esphome config firmware/esp32-c3-multi-sensor.yaml`
3. full relevant Playwright suites
4. targeted real-device smoke on C3 and aggregator paths

### Gate conditions
- [ ] `bash scripts/preflight.sh` passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` passes
- [ ] all existing Playwright suites pass
- [ ] C3 smoke test passes
- [ ] aggregator smoke test passes
- [ ] generated files are clean and reproducible after `render_sensor_config.py --write`

---

## §4. Build / Generation / Integration Pipeline Changes

### 4.1 Generator changes by step

| Step | Generator change | Reason |
|---|---|---|
| `v7.6.6.0` | none to `render_sensor_config.py`; `provision.sh` pipeline automation only | prerequisite reliability |
| `v7.6.6.1` | none or minimal if the identity check script needs generator awareness | seam setup only |
| `v7.6.6.2` | **required**: `render_sensor_config.py` writes generated topology to `firmware/core/history/generated_sensor_topology.h` instead of injecting marker blocks into `dashboard/sensor_history_multi.h` | explicit generated/manual seam |
| `v7.6.6.3`–`v7.6.6.6` | generator path remains stable; no new marker ownership expansion | avoid multiplying generated surfaces during structural refactor |
| `v7.6.6.7` | generator may additionally own the final YAML include block if the project wants that ordering to be generated rather than hand-maintained | reduce future drift |

### 4.2 Generated-block ownership strategy

**Decision:** Keep all generated topology marker blocks in a **single dedicated generated header**.

#### Files generator should continue to own
- `src/gateway_manifest.h`
- `src/aggregator_config.h`
- `firmware/core/history/generated_sensor_topology.h`
- generated YAMLs for non-default boards, as currently produced

#### Files generator should not begin owning in Phase Y
- hand-maintained persistence/runtime headers
- route implementation headers
- aggregator runtime/state headers

#### Why this is the right split
Phase Y is structural-only. It should reduce ownership ambiguity, not create a more complex generator graph.

### 4.3 YAML `includes:` strategy

#### Early transition
During the middle steps, YAML can continue to include the wrapper if that reduces churn while the extraction lands.

#### Final state
By `v7.6.6.7`, YAML should include the final split headers directly in the order listed above.

### 4.4 Exact include-order rationale

| Order block | Why it comes there |
|---|---|
| `dashboard.h` | independent embedded asset header |
| `gateway_manifest.h`, `aggregator_config.h` | generated headers consumed by the history runtime/handler surfaces |
| `history_common.h` | foundational includes/macros |
| `generated_sensor_topology.h` | provides generated device/metric/buffer definitions used by persistence/runtime and ping |
| `persistence_schema.h` | schema before runtime |
| `persistence_runtime.h` | uses generated topology + schema |
| `management_tasks.h` | depends on common/runtime helpers, but should be available before handler impls |
| `ping_adapter.h` | depends on generated topology/common surfaces |
| `aggregator_state.h` | shared aggregator ownership layer |
| `aggregator_runtime.h` | depends on shared aggregator state |
| `history_web_handler.h` | declares class before impl headers |
| `history_web_handler_core_impl.h` | core methods |
| `history_web_handler_aggregator_impl.h` | aggregator methods depend on state/runtime |
| `orchestration.h` | registration tail last |

### 4.5 Preflight changes required

Current preflight assumes monolith-specific paths and string locations. Phase Y should update preflight in phases.

#### New or updated checks needed
- `sensor_history_assembly_identity` — for transitional steps using normalized preprocessor output comparison
- `generated_sensor_topology_exists`
- `generated_sensor_topology_num_env_sensors_present`
- `generated_sensor_topology_num_sensors_aliases_env_sensors`
- `yaml_includes_split_history_chain`
- `yaml_includes_generated_sensor_topology`
- `aggregator_state_has_mutex_and_generation_counter`
- `nvs_yield_present_in_persistence_runtime`
- route-presence checks should target the new handler implementation surfaces rather than hardcoding the monolith file path

#### Checks that should stop being monolith-specific by the end
- route string presence checks tied to `dashboard/sensor_history_multi.h`
- `gateway_manifest_h_included` and `aggregator_config_h_included` should allow the final split include graph rather than only the monolith wrapper path
- `history_header_version_matches` should evolve into a split-architecture version/marker check, not a monolith filename comment check

### 4.6 `provision.sh` beyond the pre-step

After `v7.6.6.0`, `provision.sh` should remain the operator entry point and should not need Phase Y-specific behavioral changes except:
- updating any printed file paths if the generated topology path changes
- optionally adding an architecture-smoke subcommand if the project wants a local “run structural gates only” helper

### 4.7 Local `web_server_idf` override coordination

Phase Y does **not** change the local component’s purpose, but the split must preserve:
- DELETE route viability
- response-code mapping expectations
- deferred-task assumptions
- handler registration timing assumptions

No direct `web_server_idf` implementation changes are planned in Phase Y. The risk is indirect: route registration and method handling must remain compatible with the existing patched component behavior.

---

## §5. Migration Safety Rules

Every Phase Y implementation step must obey all of the following:

1. **No behavior changes** — structural reorganization only.
2. **All existing Playwright tests must pass after each sub-step.**
3. **All existing preflight checks must pass after each sub-step**, updated only as needed to reflect the new architecture.
4. **`esphome config` and compile validity must remain intact after each sub-step.**
5. **Endpoint contracts remain unchanged** — same paths, methods, auth requirements, and payload shapes.
6. **Persisted-history schema and NVS compatibility remain unchanged** — `HistoryMeta`, `SegmentSnapshot`, slot indexing, and import compatibility are preserved.
7. **Each step must be independently revertable.**
8. **Phase Y must preserve all endpoint shapes and behaviors assumed by the post-Phase X dashboard architecture, tests, and build guardrails.**
9. **Generated artifacts must remain valid after each step.**
10. **Deferred-task patterns must survive the split** — especially under the local `web_server_idf` constraints from BUG-075/076/078/079.
11. **Mutex/lock scope must survive the split** — `s_cache_mutex`, `AGG_LOCK`, `AGG_UNLOCK` remain visible wherever aggregator state is touched.
12. **Scheduler-yield safeguards must survive the split** — `maybe_yield_nvs_scan_()` must remain callable from all NVS-scanning loops.

### 5.1 Additional header-specific safety rules

#### Persistence-schema safety
- `NUM_SENSORS` must remain `NUM_ENV_SENSORS`
- retained history blobs written before Phase Y must remain readable after Phase Y
- restore path logic must remain unchanged
- slot indexing semantics must remain unchanged
- import/export behavior must remain unchanged

#### Route-surface safety
- `/api/manifest`, `/api/v2/live`, `/api/v2/history/*`, `/api/ingest/*`, `/api/storage-stats`, `/api/status`, and all aggregator endpoints must remain behaviorally identical
- `canHandle()` / `handleRequest()` ordering must not change in a way that alters which handler path wins

#### Deferred-task safety
Phase Y must preserve all current deferred-task pairs:
- reboot trigger ↔ reboot task
- delete-data trigger ↔ delete-data deferred task
- reset-satellites trigger ↔ reset-satellites deferred task
- save-satellites snapshot scheduling ↔ deferred NVS-save task

---

## §6. Coding Agent Task Size Analysis

This section uses the same intent as the Phase X architecture metrics: estimate how much context a coding agent needs for a typical change before and after the split.

### 6.1 Baseline

| Task area | Baseline current context needed |
|---|---:|
| Persistence bugfix | 18K–30K tokens |
| Aggregator runtime/polling change | 20K–30K tokens |
| Aggregator route change | 18K–28K tokens |
| Management/auth/delete-data change | 15K–28K tokens |
| Ping-only work | 10K–20K tokens |
| Registration/startup wiring | 10K–18K tokens |

### 6.2 After each level

| Phase Y level | Typical persistence task | Typical aggregator runtime task | Typical route task | Typical ping task |
|---|---:|---:|---:|---:|
| Baseline monolith | 18K–30K | 20K–30K | 15K–28K | 10K–20K |
| After `v7.6.6.2` | 12K–20K | 20K–28K | 15K–25K | 8K–15K |
| After `v7.6.6.3` | 6K–12K | 18K–26K | 12K–22K | 2K–6K |
| After `v7.6.6.4` | 6K–10K | 6K–14K | 12K–22K | 2K–6K |
| After `v7.6.6.5` | 6K–10K | 6K–14K | 6K–14K | 2K–6K |
| Final target (`v7.6.6.7`) | 4K–8K | 5K–10K | 5K–10K | 2K–5K |

### 6.3 Final-state expectation

Final-state task scope should look like this:

| Final module | Typical task context |
|---|---:|
| `persistence_schema.h` + `persistence_runtime.h` | 4K–8K |
| `aggregator_state.h` + `aggregator_runtime.h` | 5K–10K |
| `history_web_handler_core_impl.h` | 5K–10K |
| `history_web_handler_aggregator_impl.h` | 5K–10K |
| `ping_adapter.h` | 2K–5K |
| `orchestration.h` | 1K–3K |

That is the main payoff of Phase Y: targeted future work no longer requires dragging the entire firmware header into the context window.

---

## §7. Rollout Order

### 7.1 Recommended sequence

1. `v7.6.6.0` — pipeline automation prerequisite
2. `v7.6.6.1` — assembly seam + identity gate
3. `v7.6.6.2` — generated topology extraction
4. `v7.6.6.3` — persistence/management/ping extraction
5. `v7.6.6.4` — aggregator state/runtime extraction
6. `v7.6.6.5` — core route extraction
7. `v7.6.6.6` — aggregator route extraction + orchestration
8. `v7.6.6.7` — final YAML include migration and preflight cleanup

### 7.2 Why this order is safest

- It extracts the **least-coupled and most contiguous** pieces first.
- It delays the most coupled handler and aggregator-route work until shared state/runtime are explicit.
- It preserves a temporary identity gate as long as practical.
- It makes the generated/manual seam explicit early, which reduces drift during the rest of the split.
- It leaves the final YAML include migration for last, after the module graph is stable.

### 7.3 Gate conditions between levels

| Between steps | Minimum gate |
|---|---|
| `6.0 → 6.1` | preflight + `esphome config` |
| `6.1 → 6.2` | assembly identity + preflight + `esphome config` |
| `6.2 → 6.3` | generator `--check` + assembly identity + preflight + `esphome config` |
| `6.3 → 6.4` | above + C3 smoke strongly recommended |
| `6.4 → 6.5` | above + aggregator Playwright coverage + aggregator device smoke strongly recommended |
| `6.5 → 6.6` | above + history/core dashboard Playwright coverage |
| `6.6 → 6.7` | above + explicit aggregator route/device validation |
| Final closure | full relevant Playwright suite + preflight + `esphome config` + targeted device smoke |

### 7.4 Where device testing is required

#### Compile-only acceptable
- `v7.6.6.0`
- most of `v7.6.6.1`
- most of `v7.6.6.2`

#### Device smoke strongly recommended
- `v7.6.6.3` — persistence/ping extraction
- `v7.6.6.4` — aggregator runtime/state extraction
- `v7.6.6.5` — core route extraction
- `v7.6.6.6` — aggregator route extraction
- `v7.6.6.7` — final YAML include chain switch

---

## §8. Risks and Mitigations

| Risk | Why it is real in this codebase | Mitigation |
|---|---|---|
| NVS schema breakage during file moves | Persistence structs/constants are fragile (`NUM_SENSORS`, `HistoryMeta`, `SegmentSnapshot`); BUG-045/046/048 showed how easy it is to break compatibility | Isolate schema into `persistence_schema.h`; never change schema definitions during Phase Y; keep explicit preflight checks for `NUM_ENV_SENSORS` / `NUM_SENSORS`; preserve `maybe_yield_nvs_scan_()` call sites. |
| `#include` order violations | ESPHome header assembly depends on symbol visibility and order; YAML includes are part of compile behavior | Delay final YAML migration until the module graph is stable; document exact final include order; add preflight checks for split include chain. |
| Generator marker ownership confusion | Current generator writes directly into the monolith | Move all generator output to `generated_sensor_topology.h` in one step; avoid splitting markers across multiple files. |
| YAML `includes:` breakage | ESPHome only copies included headers into build context | Update YAML deliberately and atomically; add preflight checks for required split headers; retain compatibility wrapper during transition. |
| Mutex/lock visibility loss | Aggregator state is currently implicit and shared across runtime and route islands | Create `aggregator_state.h` as the single home for `s_cache_mutex`, `AGG_LOCK`, `AGG_UNLOCK`, and shared caches. |
| Deferred-task function visibility across files | BUG-075/076/101-class issues depend on deferred-task patterns surviving | Give each deferred-task pair an explicit module home; avoid turning task helpers into anonymous local implementation details hidden from trigger paths. |
| Static buffer ownership ambiguity | Generated topology currently defines important static arrays/buffers inside the monolith | Centralize them in `generated_sensor_topology.h`; do not duplicate definitions across modules. |
| Aggregator two-island coupling | Runtime island and route-handler island both need shared state and generation-counter logic | Explicit shared-state header + separate runtime and route impl headers; do not fake a contiguous extraction. |
| `web_server_idf` handler registration changes | Local component override behavior is sensitive; route registration order matters | Keep one `HistoryWebHandler` and one registration flow during Phase Y; do not introduce multiple handler classes or reorder registration semantics. |
| Binary size / compile drift from include reorganization | Header refactors can change compile surfaces, warnings, and codegen | Use preprocessor identity during transitional steps, then rely on compile/tests/device validation; avoid behavior changes masquerading as “cleanup”. |
| Route dispatch regression in `canHandle()` / `handleRequest()` | Small dispatch-order changes can alter which method/path gets handled, especially for DELETE and POST management routes | Preserve one handler class and current dispatch order; use existing Playwright and mock-server contract coverage as hard gates. |
| Preflight blind spots during transition | Current preflight still assumes monolith paths | Update preflight incrementally with architecture-aware checks before removing monolith-specific assumptions. |

---

## §9. Open Questions

This section resolves the questions from the Phase X carryover context where possible and identifies what still needs operator confirmation.

### 9.1 Resolved by this plan

| Question | Resolution |
|---|---|
| What is the practical identity gate for C++/ESPHome? | Normalized preprocessor output comparison is the primary structural gate during extraction; binary identity is not practical. |
| How should generated marker blocks be handled? | Consolidate them into one generated header: `generated_sensor_topology.h`. |
| How should the aggregator two-island problem be handled? | Use shared state + runtime + route implementation modules, not a fake contiguous extraction. |
| Should Phase Y preserve one handler or split into many? | Preserve one `HistoryWebHandler` class during Phase Y; split implementation only. |
| What YAML include strategy should be used? | Transitional wrapper early; final direct split-header include chain by `v7.6.6.7`. |
| How should Phase 7 compatibility be handled? | Create clean persistence schema/runtime extension points now. |

### 9.2 Remaining operator-input questions

1. **Wrapper retention window**  
   Should `dashboard/sensor_history_multi.h` remain as a deprecated compatibility wrapper for one extra release after `v7.6.6.7`, or should the project switch immediately to the split YAML include chain with no wrapper retention?

2. **Generator-owned YAML include block**  
   Does the operator want the final YAML split-header include list to be generator-owned, or hand-maintained once established?  
   _Recommendation:_ generator-owned if the project expects future board-template growth; hand-maintained is acceptable if the list stays stable.

3. **Device-test minimum bar per extraction step**  
   Is the expected device gate “quick smoke on one board per high-risk step” or “both C3 and aggregator hardware for every high-risk step”?  
   _Recommendation:_ both boards for `v7.6.6.4` onward.

4. **Monolith path naming convention**  
   Should the deprecated wrapper keep the current name for continuity, or should the project explicitly rename it to something like `sensor_history_multi_compat.h` after the split stabilizes?  
   _Recommendation:_ keep current name during Phase Y, rename only in a future cleanup if still desired.

---

## Additional Requirements Specific to This Header

### A. Persistence-Schema Safety

Phase Y avoids persistence breakage by **not changing**:

- retained-history blob layout
- `HistoryMeta` semantics
- `SegmentSnapshot` semantics
- restore logic semantics
- slot indexing behavior
- import compatibility behavior
- `NUM_SENSORS` / `NUM_ENV_SENSORS` meaning

The split explicitly places schema and runtime ownership into dedicated headers so that future changes in Phase 7 are deliberate rather than incidental.

### B. Generated-Block Ownership

**Decision:** Generated marker blocks move to `firmware/core/history/generated_sensor_topology.h`.

#### Why not keep them in the wrapper?
Because that preserves the worst seam ambiguity: generator-owned code embedded in a hand-maintained assembly/compatibility layer.

#### What prevents drift after the split?
- one generated file
- preflight checks target that file directly
- `render_sensor_config.py --check` still validates generator sync
- optional final YAML include block generation if desired

### C. HTTP Route Ownership

#### Current route inventory categories
- static/dashboard/download routes
- manifest/live/history routes
- v2 history routes
- ingest/import routes
- management routes (reboot, delete-data)
- storage/status routes
- aggregator discovery/live/proxy routes
- aggregator add/test/delete/reset routes

#### Target ownership model
| Route family | Target module |
|---|---|
| dashboard/static/download | `history_web_handler_core_impl.h` |
| `/api/manifest`, `/api/v2/live`, `/history/*`, `/api/v2/history/*`, `/api/ingest/*`, `/api/storage-stats`, `/api/status` | `history_web_handler_core_impl.h` |
| `/api/reboot`, `/api/delete-data` route triggers | `history_web_handler_core_impl.h` using `management_tasks.h` |
| `/api/aggregator/gateways`, `/api/aggregator/live`, `/api/aggregator/proxy/*`, `/api/aggregator/add-satellite`, `/api/aggregator/test-satellite`, `DELETE /api/aggregator/satellite/*`, `/api/system/reset-satellites` | `history_web_handler_aggregator_impl.h` using `aggregator_runtime.h` + `aggregator_state.h` |

#### `canHandle()` / `handleRequest()` dispatch pattern
It should **stay as one handler-class dispatch surface** during Phase Y. That preserves:
- current route precedence
- local component integration assumptions
- minimal behavior change risk

### D. Aggregator Two-Island Problem

#### Are both islands extracted together or separately?
Separately, but with an explicit shared-state layer.

#### How is shared state accessed?
Via `aggregator_state.h`, which owns:
- cache structs/arrays
- `s_cache_mutex`
- `AGG_LOCK` / `AGG_UNLOCK`
- `satellite_config_generation`
- other shared counters/constants

#### Does the split change deferred-task visibility?
No. Deferred-task helpers move into aggregator runtime ownership, but remain callable from the same trigger contexts through declarations visible to the route implementation layer.

### E. Task / Mutex / Deferred-Work Safety

Phase Y must preserve the following explicit homes:

| Concern | Explicit module home |
|---|---|
| reboot deferred trigger/task | `management_tasks.h` |
| delete-data deferred trigger/task | `management_tasks.h` |
| reset-satellites deferred trigger/task | `aggregator_runtime.h` |
| save-satellites snapshot + deferred NVS-save task | `aggregator_runtime.h` |
| `s_cache_mutex` / `AGG_LOCK` / `AGG_UNLOCK` | `aggregator_state.h` |
| `satellite_config_generation` | `aggregator_state.h` |
| `maybe_yield_nvs_scan_()` | `persistence_runtime.h` |

### F. Test and Guardrail Surface

#### Existing tests that already guard Phase Y correctness
- `tests/browser/boot-structure.spec.js`
- `tests/browser/history-charts.spec.js`
- `tests/browser/aggregator.spec.js`
- `tests/browser/satellite-management.spec.js`
- `tests/mock-server/server.js`
- current `scripts/preflight.sh`
- `esphome config` gate

#### New checks recommended
- structural assembly identity check during transition
- split include-chain check
- generated topology presence + count alias checks in new path
- aggregator shared-state invariants check
- route-string checks updated to new impl locations

#### Are new browser tests required?
Not necessarily for Phase Y itself. Existing contract tests are already strong. The main need is **preflight modernization**, not new user-facing behavior tests.

---

## Version Mapping Summary

| Version | Purpose | Primary output |
|---|---|---|
| `v7.6.6.0` | prerequisite workflow safety | full `provision.sh` pipeline automation |
| `v7.6.6.1` | assembly seam + identity gate | safe extraction baseline |
| `v7.6.6.2` | generated seam extraction | `generated_sensor_topology.h` |
| `v7.6.6.3` | persistence/management/ping extraction | clear foundational modules |
| `v7.6.6.4` | aggregator state/runtime extraction | solves two-island shared-state problem |
| `v7.6.6.5` | core route extraction | non-aggregator handler implementation split |
| `v7.6.6.6` | aggregator route + orchestration extraction | completes handler-side split |
| `v7.6.6.7` | final YAML include migration | split architecture becomes primary |

---

## Pre-Implementation Verification Gate

Before Phase Y implementation begins, this plan should be considered complete only if all of the following are true:

- [x] Every proposed module boundary is justified by contiguous/scattered analysis rather than assumed affinity alone.
- [x] The plan treats inventory line numbers as analysis estimates, not compiler anchors, and requires verification against the actual file during implementation.
- [x] The generator strategy is explicit: generated topology moves to one dedicated generated header.
- [x] The YAML `includes:` strategy is explicit with a proposed final include order.
- [x] All four deferred-task pairs have an explicit home in the proposed structure.
- [x] Mutex/lock visibility strategy is explicit through `aggregator_state.h`.
- [x] The identity/verification gate for each step is defined and feasible.
- [x] The `provision.sh` pre-step (`v7.6.6.0`) is fully specified.
- [x] Phase 7 compatibility is explicitly addressed through `persistence_schema.h` / `persistence_runtime.h`.
- [x] The aggregator two-island problem has an explicit resolution.

---

## Phase 7 Compatibility Summary

Phase Y should leave Phase 7 with these extension points:

| Future Phase 7 concern | Phase Y module that should own it |
|---|---|
| new per-device persistence structs | `persistence_schema.h` |
| new per-device persist/restore runtime | `persistence_runtime.h` |
| generated persistence metadata / topology | `generated_sensor_topology.h` |
| updated storage stats route behavior | `history_web_handler_core_impl.h` |
| aggregator-side persistence coordination if needed later | `aggregator_runtime.h` |

This is the main downstream value of Phase Y: Phase 7 stops being “add another major subsystem to a monolith” and becomes “extend the persistence modules intentionally”.

---

_End of document._
