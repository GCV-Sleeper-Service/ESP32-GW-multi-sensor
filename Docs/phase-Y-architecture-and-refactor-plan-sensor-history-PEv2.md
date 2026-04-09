# Phase Y — Firmware Architecture and Refactor Plan: `sensor_history_multi.h`

_Unified implementation plan — produced from codebase-verified inventory, Phase X methodology carryover, and 12 Tier 1 reference files._
_Date: 2026-04-08_
_Phase: Phase Y — Post-Phase X firmware architecture refactor_
_Version range: `v7.6.6.0`–`v7.6.6.x`_
_Status: Planning — not yet implemented_
_Prerequisite: Phase X Complete (`v7.6.5.8` on `main`, all Playwright tests green)_
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_

---

## 1. Current State Analysis

### 1.1 Firmware asset metrics (verified at HEAD `main`)

| Artifact | Lines | Role | Problem |
|---|---|---|---|
| `dashboard/sensor_history_multi.h` | **4,325** | C++ monolith — data model, NVS persistence, RAM buffers, import engine, auth, ping, aggregator, HTTP routes, boot registration | Any firmware task requires loading ~30K tokens |
| `scripts/render_sensor_config.py` | 1,414 | Generator — writes marker blocks into `sensor_history_multi.h` (header block + entity block) | Generator couples to single file path; drift possible |
| `firmware/esp32-c3-multi-sensor.yaml` | 969 | Include order, `on_boot` wiring, intervals, web server registration | `includes:` list hand-maintained; any split changes it |
| `scripts/preflight.sh` | 551 | 68 architectural guardrails | Must not be broken; some guards reference file directly |
| `scripts/provision.sh` | 540 | Board-switching + pipeline automation; only step 0 (render) auto-runs today | 7 downstream steps still require manual execution |

### 1.2 Functional responsibility count

`sensor_history_multi.h` owns **11 distinct subsystems** simultaneously:

| # | Subsystem | Approx lines (inventory §9) | Contiguous? |
|---|---|---|---|
| 1 | Data model — structs, constants, generated topology | ~1–500 | Yes (head of file) |
| 2 | Import engine — CSV state machine | ~500–1950 (scattered) | **No** |
| 3 | Auth / management — lockout, deferred management tasks | ~500–1950 (scattered) | **No** |
| 4 | PingAdapter class | ~1951–2235 | **Yes** |
| 5 | Aggregator runtime — cache, polling, NVS satellites, deferred tasks | ~2236–3290 | Yes (island 1) |
| 6 | Full aggregator (shared state + routes) | ~2236–3290 + ~4041–4295 | **No — two islands** |
| 7 | Aggregator routes — HistoryWebHandler dispatch | ~4041–4295 | Yes (island 2) |
| 8 | Registration tail — boot wiring | ~4296–4325 | Yes |
| 9 | RAM ring buffer primitives | embedded in data model | Partially scattered |
| 10 | NVS persistence / restore / migrate | embedded across file | Scattered |
| 11 | HTTP route handlers — all `/api/history*` endpoints | ~3291–4040 (routes) + island 2 | Partially contiguous |

### 1.3 Token burden — current vs. target

| Scenario | Files loaded today | Est. tokens | Target after Phase Y |
|---|---|---|---|
| Any firmware history feature | Full `sensor_history_multi.h` (4,325 lines) | ~30K | 4K–8K (target module) |
| Add Phase 7 per-device struct | Full file + `render_sensor_config.py` | ~40K | `data-model.h` + generator (~8K) |
| Fix aggregator polling bug | Full file | ~30K | `aggregator-runtime.h` (~6K) |
| Fix import state machine bug | Full file | ~30K | `import-engine.h` (~8K) |
| Add new HTTP route | Full file + YAML | ~37K | `route-handlers.h` + YAML (~6K) |
| Boot wiring change | Full file + YAML | ~37K | `orchestration.h` + YAML (~4K) |

### 1.4 What Phase 7+ makes worse

- `v7.7.0.0` adds `DeviceHistoryMeta`, `DeviceSegmentHeader`, `DeviceSegment` structs **and** `persist_device_segment_()`, `restore_device_()`, `calculate_retention_budget_()` — all into `sensor_history_multi.h`, growing it to ~5,000+ lines.
- `v7.7.0.3` adds per-device `/api/storage-stats` handler — another route into the already-crowded route section.
- `v7.7.1.0` migration function — more boot-path code into the file.
- `v7.7.1.1`–`v7.7.2.2` per-device delete, import, export endpoints — more HTTP handlers.
- Without Phase Y, every Phase 7 task requires loading a 5,000+ line file (~35K+ tokens). With Phase Y, each task loads one focused module.

---

## 2. Proposed Directory Structure

### 2.1 Before (current state)

```

dashboard/
sensor_history_multi.h     ← 4,325-line monolith (all 11 subsystems)
firmware/
esp32-c3-multi-sensor.yaml ← includes: [dashboard/sensor_history_multi.h]
src/
aggregator_config.h        ← generated: AGGREGATOR_ENABLED flag
gateway_manifest.h         ← generated: sensor topology

```

### 2.2 After Phase Y (target state)

```

firmware/
core/
data-model.h             ← structs (HistEntry, HistoryBuffer, SegmentSnapshot, SensorEntity,
SensorEnvData, SensorNetData, SensorSysData), constants
(NUM_SENSORS, NUM_ENV_SENSORS, HISTORY_SIZE, etc.),
generated topology block (SENSOR_IDS[], SENSOR_NAMES[],
AGGREGATOR_ENABLED, all render_sensor_config.py marker blocks)
history-buffer.h         ← RAM ring buffer class (HistoryBuffer) + HistEntry + primitives
(push_entry_, get_entry_, maybe_yield_nvs_scan_)
history-store.h          ← NVS persistence: persist_hourly_segment(), restore_from_nvs(),
per-device v2 engine extension points (Phase 7 stubs),
DeviceHistoryMeta / DeviceSegment structs (Phase 7 target)
import-engine.h          ← CSV import state machine: importHistoryData_, parseImportCsv_,
buildImportSegments_, executeImport_, import state vars
auth-management.h        ← auth/lockout state, requestManagementCredentials_, deferred
management tasks (reboot, delete-history), lockout timers
ping-adapter.h           ← PingAdapter class (~1951–2235 contiguous slice)
aggregator-runtime.h     ← aggregator cache, satellite polling, config generation counter,
s_cache_mutex, AGG_LOCK/AGG_UNLOCK macros, NVS satellite
config, deferred aggregator tasks, satellite_config_generation
route-handlers.h         ← HistoryWebHandler class + canHandle()/handleRequest() dispatch,
all /api/history* endpoints, aggregator route island 2
(~4041–4295), storage-stats handler
orchestration.h          ← boot registration, on_boot wiring helpers, startup sequence,
registration tail (~4296–4325)
dashboard/
sensor_history_multi.h     ← thin include-assembly file (9 \#includes in order + nothing else)
OR removed and YAML updated directly
firmware/
esp32-c3-multi-sensor.yaml ← includes: list updated to firmware/core/*.h in order
src/
aggregator_config.h        ← generated (unchanged role)
gateway_manifest.h         ← generated (unchanged role)

```

### 2.3 Module boundary justifications

Each boundary is justified by inventory §9 contiguous/scattered analysis:

| Module | Boundary rationale | Inventory §9 classification |
|---|---|---|
| `data-model.h` | All structs and constants are at the head of the file and must be visible to every downstream include. Generated marker blocks live here so the generator has a single write target. | Head-of-file contiguous block |
| `history-buffer.h` | `HistoryBuffer` and `HistEntry` are pure RAM primitives with no NVS dependency. Separating them from `history-store.h` gives Phase 7 a clean extension point: the store can be replaced without touching the buffer. `maybe_yield_nvs_scan_()` belongs here because it operates on the buffer iteration loop (BUG-043 pattern). | Embedded in data model — extracted by type |
| `history-store.h` | NVS read/write paths are cohesive and Phase-7-targeted. Isolating them means Phase 7 adds `DeviceHistoryMeta`/`DeviceSegment` here without touching any other module. | Scattered across file — grouped by NVS I/O concern |
| `import-engine.h` | Import state machine is the largest scattered subsystem (~500–1950). It has no runtime dependency on auth or aggregator — only on `HistoryBuffer` and `data-model.h`. Isolation prevents the 8-state import machine from contaminating agent context for aggregator tasks. | Scattered — grouped by import concern |
| `auth-management.h` | Auth/lockout and deferred management tasks are interleaved with import state in the ~500–1950 range. They share no data structures with the import engine and can be separated cleanly at function boundaries. Deferred-task pair 1 (reboot) and pair 2 (delete-history) live here. | Scattered — grouped by auth/management concern |
| `ping-adapter.h` | PingAdapter class is the most contiguous block in the file (~1951–2235 per inventory §9). A clean 285-line contiguous slice — ideal Phase X-style extraction. | **Contiguous** — direct extraction |
| `aggregator-runtime.h` | Aggregator runtime island 1 (~2236–3290) is contiguous. It owns `s_cache_mutex`, `AGG_LOCK`/`AGG_UNLOCK`, `satellite_config_generation`, and deferred-task pairs 3 and 4. Route island 2 (~4041–4295) is separated by the route-handlers block. Both islands are extracted into the same module (see §D, Aggregator Two-Island Problem). | **Island 1 contiguous** — island 2 relocated to `route-handlers.h` |
| `route-handlers.h` | `HistoryWebHandler` + all endpoint dispatch is a natural ownership unit. Aggregator route island 2 is co-located here (not in `aggregator-runtime.h`) because routes are the caller, not the runtime. Routes call into `aggregator-runtime.h` functions. This resolves the two-island problem cleanly. | **Aggregator routes contiguous** — ~4041–4295 |
| `orchestration.h` | Registration tail (~4296–4325) + any `on_boot` wiring helpers. Thin module (~30–50 lines). Provides Phase 7 a single extension point for adding `restore_all_devices_v2()` and `migrate_v7_to_v8_()` to the boot sequence. | **Contiguous** — tail of file |

---

## 3. Versioned Steps (v7.6.6.0–v7.6.6.x)

### Version mapping

| Step | Version | Level | Scope |
|---|---|---|---|
| Pre-step | `v7.6.6.0` | Pre-step | `provision.sh` full 8-step automation + `--dry-run` |
| Level 1.0 | `v7.6.6.1` | Contiguous extractions | Extract `ping-adapter.h`, `orchestration.h`, `aggregator-routes` island 2 into stubs |
| Level 1.1 | `v7.6.6.2` | CI + preflight wiring | Wire new include order into preflight + YAML |
| Level 2.0 | `v7.6.6.3` | Data model isolation | Extract `data-model.h` (generated blocks migrate here) |
| Level 2.1 | `v7.6.6.4` | Buffer isolation | Extract `history-buffer.h` |
| Level 3.0 | `v7.6.6.5` | Store isolation | Extract `history-store.h` |
| Level 3.1 | `v7.6.6.6` | Scattered subsystem isolation | Extract `import-engine.h` + `auth-management.h` |
| Level 4.0 | `v7.6.6.7` | Aggregator consolidation | Extract `aggregator-runtime.h` (both islands unified) |
| Level 4.1 | `v7.6.6.8` | Route handler isolation | Extract `route-handlers.h` |
| Closure | `v7.6.6.9` | Thin assembly file + closure | `sensor_history_multi.h` becomes include-only; critical rules + preflight closure |

---

### `v7.6.6.0` — Pre-step: `provision.sh` full 8-step automation + `--dry-run`

**Level:** Pre-step — tooling only, no C++ changes
**Goal:** Automate the full 8-step Phase X pipeline in `provision.sh`. Today only step 0 (render) auto-runs; steps 1–7 are printed for manual execution. This pre-step closes that gap and adds `--dry-run` for safe preview.

#### Scope

- Add `--dry-run` flag to all `provision.sh` commands.
- Automate steps 1–7 in `run_pipeline()` helper (invoked after `run_render()`).
- Print each step before running it (operator visibility).
- `--dry-run` prints all steps without executing them.
- Add `--pipeline-only` mode: run the pipeline without switching board config.
- Update `print_workflow()` to reference the now-automated pipeline.
- Update `Docs/aggregator-setup.md` and `Docs/changelog.md`.

#### Files created/modified

| Action | File |
|---|---|
| MODIFY | `scripts/provision.sh` — add `run_pipeline()`, `--dry-run`, `--pipeline-only` |
| MODIFY | `Docs/aggregator-setup.md` — update pipeline section |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.0` |

#### `run_pipeline()` contract

```bash
run_pipeline() {
  local dry="${DRY_RUN:-0}"
  local steps=(
    "bash scripts/bundle-dashboard.sh --write"
    "python3 scripts/render_sensor_config.py --write"
    "node tests/fixtures/generate-fixtures.js"
    "python3 scripts/render_sensor_config.py --write"
    "bash scripts/build-dashboard.sh --write"
    "bash scripts/minify-dashboard.sh"
    "bash scripts/generate-header.sh"
    "python3 scripts/render_sensor_config.py --check"
  )
  echo "─── Phase X pipeline (8 steps) ───────────────────────"
  for step in "${steps[@]}"; do
    echo "  $step"
    if [[ "$dry" -eq 0 ]]; then
      eval "$step" || { echo "ERROR: Pipeline step failed: $step" >&2; exit 1; }
    fi
  done
  echo "─── Pipeline complete ─────────────────────────────────"
}
```


#### `--dry-run` integration

```bash
# In each command handler (aggregator/satellite/wroom):
DRY_RUN=0
if [[ "${2:-}" == "--dry-run" ]]; then DRY_RUN=1; fi
# ... do config switch ...
run_render      # always skipped if DRY_RUN=1 (print only)
run_pipeline    # respects DRY_RUN
```


#### Acceptance checklist

- [ ] `bash scripts/provision.sh satellite --dry-run` prints all 8 pipeline steps without executing
- [ ] `bash scripts/provision.sh satellite` (no flag) runs all 8 steps and succeeds
- [ ] `bash scripts/provision.sh aggregator --dry-run` prints pipeline + flash instructions without switching config
- [ ] `bash scripts/provision.sh --pipeline-only` runs pipeline without switching board
- [ ] `bash scripts/preflight.sh` passes
- [ ] All Playwright tests pass across all four fixture sets
- [ ] No C++ changes, no YAML changes, no new modules


#### Risk: **Low** — shell script only

#### Effort: 0.5 sessions

#### Verification gate: Preflight + Playwright (no C++ compile needed)


---

### `v7.6.6.1` — Level 1: Contiguous slice extractions

**Level:** Level 1 — Contiguous extractions (Phase X-style)
**Goal:** Extract the three cleanest contiguous blocks from `sensor_history_multi.h` into stub headers: `ping-adapter.h` (~1951–2235), `orchestration.h` (~4296–4325), and the aggregator routes island 2 header stub (~4041–4295). Verify line ranges against actual file. `sensor_history_multi.h` gets `#include` directives for each extracted file.

#### Pre-extraction line range verification

Before finalizing boundaries, the coding agent **must** verify these ranges against the actual file:


| Module | Inventory estimate | Verification method |
| :-- | :-- | :-- |
| PingAdapter class | ~1951–2235 | Search for `class PingAdapter` and closing `};` |
| Aggregator routes island 2 | ~4041–4295 | Search for second block of `case` statements in `handleRequest()` that reference aggregator-only endpoints |
| Registration tail | ~4296–4325 | Search for `setup()` / boot registration calls at EOF |

If ranges differ by more than ±30 lines from inventory estimates, report the actual ranges before proceeding.

#### Scope

- Create `firmware/core/` directory.
- Create `firmware/core/ping-adapter.h` — exact contiguous slice from `sensor_history_multi.h`.
- Create `firmware/core/orchestration.h` — exact contiguous slice from `sensor_history_multi.h`.
- Create `firmware/core/route-handlers-stub.h` — aggregator routes island 2 slice (stub; will be renamed at Level 4.1).
- Replace extracted lines in `sensor_history_multi.h` with `#include "firmware/core/ping-adapter.h"` etc.
- `sensor_history_multi.h` must compile identically after this change.


#### Files created/modified

| Action | File |
| :-- | :-- |
| CREATE dir | `firmware/core/` |
| CREATE | `firmware/core/ping-adapter.h` |
| CREATE | `firmware/core/orchestration.h` |
| CREATE | `firmware/core/route-handlers-stub.h` |
| MODIFY | `dashboard/sensor_history_multi.h` — replace extracted lines with `#include` |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.1` |

#### Identity/verification gate

For C++/ESPHome, SHA-256 byte-for-byte identity is not achievable (timestamps in object files, non-deterministic ESPHome YAML preprocessing). The feasibility analysis of all four strategies is:


| Strategy | Feasibility for Phase Y | Decision |
| :-- | :-- | :-- |
| 1. Preprocessor output (`gcc -E`) | Achievable — produces deterministic text output for pure C++ | **Use for Levels 1–2** |
| 2. Compile + compare object files (strip timestamps) | Partially achievable — object file comparison catches code changes but toolchain flags affect output | Supplementary only |
| 3. Functional equivalence (device test + Playwright) | Always achievable — Playwright suite is the ground truth | **Use for Levels 3–4** |
| 4. Source-level identity (`#include` chain preprocessor output) | Achievable for contiguous slices where no code is reordered | **Use for Level 1** |

**Primary gate for Level 1 (contiguous extractions):** Preprocessor identity.

```bash
# Before extraction:
gcc -E -P -x c++ \
  -I. -I firmware/ \
  dashboard/sensor_history_multi.h \
  -o /tmp/before_preprocess.txt 2>/dev/null

# After extraction:
gcc -E -P -x c++ \
  -I. -I firmware/ \
  dashboard/sensor_history_multi.h \
  -o /tmp/after_preprocess.txt 2>/dev/null

diff /tmp/before_preprocess.txt /tmp/after_preprocess.txt
# Must exit 0
```

If `gcc -E` is not available in the ESPHome build environment, the fallback is: `esphome config firmware/esp32-c3-multi-sensor.yaml` validates without error + all Playwright tests pass.

#### Acceptance checklist

- [ ] `firmware/core/` directory exists
- [ ] `firmware/core/ping-adapter.h` contains PingAdapter class (verified line range)
- [ ] `firmware/core/orchestration.h` contains boot registration tail (verified line range)
- [ ] `firmware/core/route-handlers-stub.h` contains aggregator routes island 2 (verified line range)
- [ ] Preprocessor identity gate passes (diff exits 0) OR `esphome config` validates + Playwright passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates without error
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes (68 guardrails)
- [ ] No behavior change — device functionality unchanged


#### Risk: **Medium** — contiguous extraction is mechanical but header guard ordering and forward declaration dependencies must be verified

#### Effort: 1–2 sessions

#### Verification gate: Preprocessor identity + `esphome config` + Playwright


---

### `v7.6.6.2` — Level 1: CI + preflight wiring

**Level:** Level 1 — Build infrastructure
**Goal:** Wire new include order into preflight. Add `esphome config` validation to CI. Establish include-order guard.

#### Scope

- Add `firmware_core_include_order` preflight check: verifies `firmware/core/*.h` files exist in expected set.
- Add `esphome_config_validates` preflight check (if not already present).
- Add CI step: `esphome config firmware/esp32-c3-multi-sensor.yaml` (compile-only, no flash).
- Update `Docs/aggregator-setup.md` with new `firmware/core/` structure.


#### Files modified

| Action | File |
| :-- | :-- |
| MODIFY | `scripts/preflight.sh` — add `firmware_core_include_order`, `esphome_config_validates` checks |
| MODIFY | `.github/workflows/browser-tests.yml` — add ESPHome config validation step |
| MODIFY | `Docs/aggregator-setup.md` |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.2` |

#### Acceptance checklist

- [ ] `firmware_core_include_order` preflight check passes
- [ ] CI validates ESPHome config without flash
- [ ] Adding a new `firmware/core/*.h` file without updating preflight → preflight WARN (not block)
- [ ] All Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes


#### Risk: **Low** — tooling only

#### Effort: 0.5 sessions

#### Verification gate: Preflight + CI green


---

### `v7.6.6.3` — Level 2: Extract `data-model.h` (generated blocks migrate)

**Level:** Level 2 — Data model isolation
**Goal:** Extract all structs, constants, and generated topology blocks from `sensor_history_multi.h` into `firmware/core/data-model.h`. This is the critical generated-block migration step — the generator's write target moves from `sensor_history_multi.h` to `data-model.h`.

#### Scope

- Extract: `HistEntry`, `HistoryBuffer` struct/class definitions, `SegmentSnapshot`, `SensorEntity`, `SensorEnvData`, `SensorNetData`, `SensorSysData`, `NUM_SENSORS`, `NUM_ENV_SENSORS`, `HISTORY_SIZE`, all `SENSOR_IDS[]`/`SENSOR_NAMES[]` arrays, all `render_sensor_config.py` marker blocks (both header block and entity block).
- Update `render_sensor_config.py`: change `H_PATH` (or equivalent file path constant) to `firmware/core/data-model.h`.
- Add `#include "firmware/core/data-model.h"` at top of `sensor_history_multi.h`.
- Run full `provision.sh` pipeline to verify generator writes correctly to new path.


#### Generator migration — critical detail

`render_sensor_config.py` writes two marker blocks into `sensor_history_multi.h`:

1. **Header block** — `SENSOR_HISTORY_HEADER_BEGIN` / `SENSOR_HISTORY_HEADER_END` (topology: `NUM_SENSORS`, entity arrays)
2. **Entity block** — `SENSOR_HISTORY_ENTITY_BEGIN` / `SENSOR_HISTORY_ENTITY_END` (per-sensor entity initializers)

Both blocks migrate to `data-model.h`. The generator's file path reference must be updated to point to `firmware/core/data-model.h`. No marker content changes — only the file the generator writes to.

**Drift prevention:** `preflight.sh` adds a `generator_markers_in_data_model` check that verifies both marker pairs exist in `firmware/core/data-model.h` and do NOT exist in `dashboard/sensor_history_multi.h`.

#### Files created/modified

| Action | File |
| :-- | :-- |
| CREATE | `firmware/core/data-model.h` |
| MODIFY | `dashboard/sensor_history_multi.h` — replace extracted lines with `#include "firmware/core/data-model.h"` |
| MODIFY | `scripts/render_sensor_config.py` — update `H_PATH` to `firmware/core/data-model.h` |
| MODIFY | `scripts/preflight.sh` — add `generator_markers_in_data_model` check |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.3` |

#### Acceptance checklist

- [ ] `firmware/core/data-model.h` contains all structs, constants, and both generator marker blocks
- [ ] `render_sensor_config.py --write` writes to `firmware/core/data-model.h` (verified by running it and checking file mtime)
- [ ] `render_sensor_config.py --check` passes
- [ ] Generator markers are absent from `dashboard/sensor_history_multi.h`
- [ ] `generator_markers_in_data_model` preflight check passes
- [ ] Preprocessor identity gate passes vs. pre-extraction baseline
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates
- [ ] All Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes


#### Risk: **High** — generator file-path change is the highest-risk single step; if `render_sensor_config.py` writes to the wrong path, generated topology will be stale at next pipeline run

#### Effort: 1.5–2 sessions

#### Verification gate: Generator `--check` + preflight `generator_markers_in_data_model` + `esphome config` + Playwright


---

### `v7.6.6.4` — Level 2: Extract `history-buffer.h`

**Level:** Level 2 — Buffer isolation
**Goal:** Extract `HistoryBuffer` class implementation, `HistEntry` usage helpers, and `maybe_yield_nvs_scan_()` into `firmware/core/history-buffer.h`. This module must include only `data-model.h` — no NVS, no HTTP, no aggregator.

#### Scope

- Extract: `HistoryBuffer` member function implementations (if defined inline in the header), `maybe_yield_nvs_scan_()` function, `HistEntry`-level helpers.
- Dependency rule: `history-buffer.h` may only `#include "firmware/core/data-model.h"` and standard C++ headers. No ESPHome, no NVS, no HTTP.
- This creates the clean RAM-only layer that Phase 7's `DeviceSegment` restore will read from.


#### Files created/modified

| Action | File |
| :-- | :-- |
| CREATE | `firmware/core/history-buffer.h` |
| MODIFY | `dashboard/sensor_history_multi.h` — replace with `#include` |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.4` |

#### Acceptance checklist

- [ ] `firmware/core/history-buffer.h` includes only `data-model.h` and stdlib headers
- [ ] `maybe_yield_nvs_scan_()` is in `history-buffer.h` (BUG-043 pattern preserved)
- [ ] Preprocessor identity gate passes
- [ ] `esphome config` validates
- [ ] All Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes


#### Risk: **Low-Medium** — `maybe_yield_nvs_scan_()` must not be duplicated; single definition in `history-buffer.h`

#### Effort: 1 session

#### Verification gate: Preprocessor identity + `esphome config` + Playwright


---

### `v7.6.6.5` — Level 3: Extract `history-store.h`

**Level:** Level 3 — NVS persistence isolation
**Goal:** Extract the NVS persist/restore engine into `firmware/core/history-store.h`. This module becomes the Phase 7 extension target — all `DeviceHistoryMeta`/`DeviceSegment` additions in v7.7.0.x land here.

#### Scope

- Extract: `persist_hourly_segment()`, `restore_from_nvs()`, NVS open/close wrappers, `HISTORY_PARTITION_LABEL` constant usage, slot indexing logic.
- Add Phase 7 extension point stubs (compile-to-nothing today):

```cpp
// PHASE_7_EXTENSION_POINT: DeviceHistoryMeta, DeviceSegment structs go here
// PHASE_7_EXTENSION_POINT: persist_device_segment_(), restore_device_() go here
// PHASE_7_EXTENSION_POINT: calculate_retention_budget_() goes here
```

- Dependencies: `data-model.h`, `history-buffer.h`, NVS/ESPHome NVS headers.
- NVS schema is preserved byte-for-byte — no key changes, no blob format changes.


#### Persistence-schema safety guarantee

Phase Y makes zero changes to NVS key names, NVS namespace, blob format (`SegmentSnapshot`), slot indexing, or `NUM_SENSORS`/`NUM_ENV_SENSORS` semantics. The only change is which `.h` file contains the code that reads/writes NVS. Existing NVS data is readable after split — the code path is identical, just moved to a new translation unit.

#### Files created/modified

| Action | File |
| :-- | :-- |
| CREATE | `firmware/core/history-store.h` |
| MODIFY | `dashboard/sensor_history_multi.h` — replace with `#include` |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.5` |

#### Acceptance checklist

- [ ] `firmware/core/history-store.h` contains all NVS persist/restore functions
- [ ] Phase 7 extension point stubs present (compile-to-nothing)
- [ ] NVS key names, namespace, and blob format unchanged (verified by inspection)
- [ ] `esphome config` validates
- [ ] Functional equivalence: device test — boot, verify history restores from NVS, verify hourly persist writes
- [ ] All Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes


#### Risk: **High** — NVS read/write path is critical; errors cause history loss on boot. Device test required.

#### Effort: 2 sessions

#### Verification gate: Device test (boot + 1-hour persist cycle) + `esphome config` + Playwright


---

### `v7.6.6.6` — Level 3: Extract `import-engine.h` + `auth-management.h`

**Level:** Level 3 — Scattered subsystem isolation
**Goal:** Extract the CSV import state machine and auth/management subsystems from the ~500–1950 scattered zone. These are the two largest scattered subsystems. Scattered extraction requires function-boundary analysis (not line-range slicing).

#### Scope

**`import-engine.h`:**

- Extract all import state machine functions: `importHistoryData_()`, `parseImportCsv_()`, `buildImportSegments_()`, `executeImport_()`, import state variables (current file handle, segment buffer, progress counters).
- Import suspend/resume guards: `isImportActive()`, references to `import_active_` flag.
- Dependencies: `data-model.h`, `history-buffer.h`, `history-store.h`.

**`auth-management.h`:**

- Extract: auth/lockout state variables, `requestManagementCredentials_()`, deferred-task pairs 1 (reboot) and 2 (delete-history), lockout timer vars.
- Deferred-task visibility: pairs 1 and 2 are defined here; the task callback lambdas reference them from `route-handlers.h` via `#include`. No cross-island reference needed.
- Dependencies: `data-model.h`.


#### Scattered extraction strategy

For scattered subsystems (unlike contiguous slices), the extraction process is:

1. Build a function list for each target module from inventory §9 (not line ranges).
2. For each function, locate it in the actual file and extract it.
3. Verify no function appears in two modules.
4. Verify all callers of each function can resolve it via `#include` chain.
5. Use preprocessor gate (`gcc -E`) as feasibility check before and after.

The scattered zone (~500–1950) is the most complex extraction. The coding agent must not use line ranges mechanically — function boundaries are the extraction unit.

#### Files created/modified

| Action | File |
| :-- | :-- |
| CREATE | `firmware/core/import-engine.h` |
| CREATE | `firmware/core/auth-management.h` |
| MODIFY | `dashboard/sensor_history_multi.h` — replace extracted functions with `#include` directives |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.6` |

#### Acceptance checklist

- [ ] All import state machine functions in `import-engine.h`; none in monolith body
- [ ] All auth/lockout state in `auth-management.h`; none in monolith body
- [ ] Deferred-task pairs 1 and 2 visible from `route-handlers.h` via include chain
- [ ] Import suspend/resume (`isImportActive()`) accessible from aggregator polling path
- [ ] Preprocessor gate passes vs. pre-step baseline
- [ ] `esphome config` validates
- [ ] Functional equivalence: device test — CSV import round-trip, auth lockout behavior
- [ ] All Playwright tests pass
- [ ] `bash scripts/preflight.sh` passes


#### Risk: **High** — scattered extraction; function-boundary errors produce silent ODR violations or link errors

#### Effort: 2–3 sessions

#### Verification gate: Preprocessor gate + device test (import round-trip) + Playwright


---

### `v7.6.6.7` — Level 4: Extract `aggregator-runtime.h`

**Level:** Level 4 — Aggregator consolidation
**Goal:** Extract aggregator runtime island 1 (~2236–3290) into `firmware/core/aggregator-runtime.h`. This module owns the mutex, caches, satellite config counter, and deferred-task pairs 3 and 4. **Aggregator route island 2 is NOT extracted here** — it moves to `route-handlers.h` in the next step.

#### Scope

- Extract: `s_cache_mutex`, `AGG_LOCK`/`AGG_UNLOCK` macro definitions, satellite cache arrays, `satellite_config_generation` counter, satellite NVS config load/save, aggregator polling functions, deferred-task pairs 3 (satellite add) and 4 (satellite remove).
- Aggregator route island 2 (`route-handlers-stub.h` from v7.6.6.1) is kept as a stub for now — it is absorbed into `route-handlers.h` at Level 4.1.
- Mutex visibility: `s_cache_mutex` is defined in `aggregator-runtime.h`. `AGG_LOCK`/`AGG_UNLOCK` macros are defined in the same header and available to all includes downstream. `route-handlers.h` (which calls aggregator functions) includes `aggregator-runtime.h`.
- `satellite_config_generation` counter is defined in `aggregator-runtime.h`; route handlers read it via include.


#### Two-island resolution (see §D)

The two-island problem is resolved by:

- **Island 1** (aggregator runtime, ~2236–3290) → `aggregator-runtime.h`
- **Island 2** (aggregator routes, ~4041–4295) → `route-handlers.h` (Level 4.1)
- Shared state (`s_cache_mutex`, `satellite_config_generation`, cache arrays) is defined in `aggregator-runtime.h` and included by `route-handlers.h`
- No shared state is duplicated; the include chain provides single-definition ownership


#### Files created/modified

| Action | File |
| :-- | :-- |
| CREATE | `firmware/core/aggregator-runtime.h` |
| MODIFY | `dashboard/sensor_history_multi.h` — replace island 1 lines with `#include` |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.7` |

#### Acceptance checklist

- [ ] `s_cache_mutex` defined once, in `aggregator-runtime.h`
- [ ] `AGG_LOCK`/`AGG_UNLOCK` macros defined in `aggregator-runtime.h`; no duplicate definitions
- [ ] `satellite_config_generation` defined once, in `aggregator-runtime.h`
- [ ] Deferred-task pairs 3 and 4 in `aggregator-runtime.h`; callback lambdas still functional
- [ ] `maybe_yield_nvs_scan_()` called from aggregator device iteration (verify in extracted code)
- [ ] Preprocessor gate passes
- [ ] `esphome config` validates (aggregator board profile)
- [ ] Functional equivalence: aggregator device test — satellite polling, cache refresh
- [ ] All Playwright tests pass (aggregator fixture set)
- [ ] `bash scripts/preflight.sh` passes


#### Risk: **High** — mutex and deferred-task visibility across module boundary; any include-order error produces undefined behavior

#### Effort: 2 sessions

#### Verification gate: Preprocessor gate + aggregator device test + Playwright aggregator fixture


---

### `v7.6.6.8` — Level 4: Extract `route-handlers.h` (final route consolidation)

**Level:** Level 4 — Route handler isolation
**Goal:** Extract `HistoryWebHandler` class and all endpoint dispatch into `firmware/core/route-handlers.h`. Absorb aggregator route island 2 from `route-handlers-stub.h`. Remove `route-handlers-stub.h`.

#### Scope

- Extract: `HistoryWebHandler` class declaration + `canHandle()`/`handleRequest()` implementations, all `/api/history*` endpoint handlers, aggregator route island 2 (absorbed from stub), `/api/storage-stats` handler (current), Phase 7 extension point stub for per-device storage stats.
- `canHandle()` and `handleRequest()` dispatch stays monolithic within this module — all routes are in one handler class, not split further. Splitting the dispatch would require ESPHome to register multiple handlers, which increases boot complexity.
- Phase 7 extension point for `DELETE /api/v2/history/{device_id}`, `POST /api/v2/import/{device_id}` lives here.
- Remove `firmware/core/route-handlers-stub.h`.
- Update `firmware/core/orchestration.h` to include `route-handlers.h` (for handler registration).


#### YAML `includes:` order (after this step)

```yaml
includes:
  - firmware/core/data-model.h
  - firmware/core/history-buffer.h
  - firmware/core/history-store.h
  - firmware/core/import-engine.h
  - firmware/core/auth-management.h
  - firmware/core/ping-adapter.h
  - firmware/core/aggregator-runtime.h
  - firmware/core/route-handlers.h
  - firmware/core/orchestration.h
```

This order is **hand-maintained** (not generated). `render_sensor_config.py` does not generate the `includes:` list — it only writes into `data-model.h`. The ordering enforces the dependency DAG: each module only references types from modules listed above it.

#### Files created/modified

| Action | File |
| :-- | :-- |
| CREATE | `firmware/core/route-handlers.h` |
| DELETE | `firmware/core/route-handlers-stub.h` |
| MODIFY | `dashboard/sensor_history_multi.h` — replace route section with `#include` |
| MODIFY | `firmware/core/orchestration.h` — add `#include "firmware/core/route-handlers.h"` |
| MODIFY | `firmware/esp32-c3-multi-sensor.yaml` — update `includes:` to 9-file ordered list |
| UPDATE | `Docs/changelog.md` |
| VERSION BUMP | `v7.6.6.8` |

#### Acceptance checklist

- [ ] `firmware/core/route-handlers.h` contains HistoryWebHandler + all endpoint handlers
- [ ] Aggregator route island 2 absorbed (no longer in stub)
- [ ] `route-handlers-stub.h` deleted
- [ ] YAML `includes:` has all 9 modules in dependency order
- [ ] `canHandle()` and `handleRequest()` both in `route-handlers.h`; no split dispatch
- [ ] Phase 7 extension point stubs present (compile-to-nothing)
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates
- [ ] `esphome config firmware/esp32-s3-devkitc1-n16r8-gw.yaml` validates (aggregator board)
- [ ] Functional equivalence: device test — all `/api/history*` endpoints respond correctly
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes


#### Risk: **Medium** — YAML `includes:` change is a deployment-critical change; wrong order = compile error

#### Effort: 1.5–2 sessions

#### Verification gate: `esphome config` (both boards) + full device test + Playwright


---

### `v7.6.6.9` — Closure: thin assembly file + preflight + critical rules

**Level:** Closure
**Goal:** Reduce `sensor_history_multi.h` to a thin include-assembly file (or remove it). Update critical rules. Add Phase Y-specific preflight guards. Produce Phase Y results document.

#### Scope

**Option A (recommended): thin assembly file**

```cpp
// dashboard/sensor_history_multi.h
// GENERATED — Do not edit. This is an include-assembly shim.
// Source modules live in firmware/core/. See Phase Y plan.
#pragma once
#include "firmware/core/data-model.h"
#include "firmware/core/history-buffer.h"
#include "firmware/core/history-store.h"
#include "firmware/core/import-engine.h"
#include "firmware/core/auth-management.h"
#include "firmware/core/ping-adapter.h"
#include "firmware/core/aggregator-runtime.h"
#include "firmware/core/route-handlers.h"
#include "firmware/core/orchestration.h"
```

This preserves backward compatibility for any board YAML that still includes `dashboard/sensor_history_multi.h` directly. The thin shim means no YAML changes are required — the existing `includes: [dashboard/sensor_history_multi.h]` path remains valid.

**Option B: remove `sensor_history_multi.h`, update YAML directly**
Update all board YAML files to list `firmware/core/*.h` directly. Cleaner but requires YAML changes to all board profiles.

**Decision: Option A.** Reasoning: The thin shim provides backward compatibility for board profiles not yet updated (WROOM, future C5/C6/S3-2MB). A single-file include path is also simpler for operators. The shim is clearly marked as generated.

- Add `firmware_core_module_files` preflight check (all 9 modules exist).
- Add `sensor_history_monolith_absent` preflight check (monolith has ≤ 15 non-blank, non-comment lines).
- Update `prompts/prompt-index-and-workflow.md` — Phase Y complete, new critical rules.
- Produce `prompts/handoff/phaseY-results.md`.


#### New critical rules

| \# | Rule | Source |
| :-- | :-- | :-- |
| 50 | Source modules for `sensor_history_multi.h` live in `firmware/core/`. Never add code to `dashboard/sensor_history_multi.h` directly — it is a thin include shim. | Phase Y v7.6.6.9 |
| 51 | `render_sensor_config.py` writes generated topology blocks into `firmware/core/data-model.h`. Never redirect the generator to any other file. | Phase Y v7.6.6.3 |
| 52 | The YAML `includes:` list is hand-maintained in dependency order. The generator does not produce this list. Do not alphabetize or reorder it. | Phase Y v7.6.6.8 |
| 53 | `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` are defined once in `firmware/core/aggregator-runtime.h`. Never redefine or shadow them. | Phase Y v7.6.6.7 |
| 54 | `maybe_yield_nvs_scan_()` is defined once in `firmware/core/history-buffer.h`. Call it between device iterations in any NVS scan loop. | Phase Y v7.6.6.4 |
| 55 | Phase 7 NVS extension (`DeviceHistoryMeta`, `DeviceSegment`, per-device persist/restore) lands in `firmware/core/history-store.h`. Phase 7 route extensions land in `firmware/core/route-handlers.h`. Phase 7 boot extensions land in `firmware/core/orchestration.h`. | Phase Y v7.6.6.9 |
| 56 | Version bumps are out of scope for documentation-only PRs (carried from Phase X CR56). | Phase X |
| 57 | Before pushing any firmware change, run `bash scripts/provision.sh satellite` then `bash scripts/preflight.sh`. | Phase Y v7.6.6.0 |

#### Acceptance checklist

- [ ] `dashboard/sensor_history_multi.h` is ≤ 15 non-blank, non-comment lines (thin shim only)
- [ ] `firmware_core_module_files` preflight check passes (all 9 modules present)
- [ ] `sensor_history_monolith_absent` preflight check passes
- [ ] `prompts/prompt-index-and-workflow.md` updated with Phase Y complete + Critical Rules 50–57
- [ ] `prompts/handoff/phaseY-results.md` produced
- [ ] All Playwright tests pass across all four fixture sets
- [ ] `bash scripts/preflight.sh` passes (all 68+ guardrails)
- [ ] `esphome config` validates for all board profiles


#### Risk: **Low** — documentation and tooling closure

#### Effort: 1 session

#### Verification gate: Preflight + Playwright + `esphome config`


---

## 4. Build / Generation / Integration Pipeline Changes

### 4.1 Per-step pipeline impact

| Version | `render_sensor_config.py` | Generated block migration | YAML `includes:` | `preflight.sh` | `provision.sh` | `web_server_idf` |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| v7.6.6.0 | No change | No change | No change | No change | **Add `run_pipeline()`, `--dry-run`** | No change |
| v7.6.6.1 | No change | No change | No change | Add `firmware_core_include_order` | No change | No change |
| v7.6.6.2 | No change | No change | No change | Add `esphome_config_validates` | No change | No change |
| v7.6.6.3 | **`H_PATH` → `firmware/core/data-model.h`** | **Both marker blocks move to `data-model.h`** | No change | Add `generator_markers_in_data_model` | Update pipeline docs | No change |
| v7.6.6.4–6 | No change | Already migrated | No change | No new checks | No change | No change |
| v7.6.6.7 | No change | Already migrated | No change | No new checks | No change | Aggregator handler registration unchanged |
| v7.6.6.8 | No change | Already migrated | **Update to 9-file ordered list** | No new checks | No change | Handler registration in `route-handlers.h` — verify `web_server_idf` sees same handler class |
| v7.6.6.9 | No change | Already migrated | No change | Add `firmware_core_module_files`, `sensor_history_monolith_absent` | No change | No change |

### 4.2 Generator strategy — explicit decision

**Single dedicated header for generated blocks.** `render_sensor_config.py` writes all generated marker blocks into `firmware/core/data-model.h` (migrated at v7.6.6.3). No marker blocks in any other `firmware/core/*.h` file.

**What the generator writes:**

- `SENSOR_HISTORY_HEADER_BEGIN` / `SENSOR_HISTORY_HEADER_END` → `firmware/core/data-model.h`
- `SENSOR_HISTORY_ENTITY_BEGIN` / `SENSOR_HISTORY_ENTITY_END` → `firmware/core/data-model.h`
- `DEFAULT_SENSOR_META` (JS) → `dashboard.js` (unchanged — dashboard pipeline)

**What the generator does NOT write:**

- `includes:` list in YAML — hand-maintained
- Any content in `history-store.h`, `route-handlers.h`, etc.

**Drift prevention:** `preflight.sh` `generator_markers_in_data_model` check verifies markers are in `data-model.h` and absent from `sensor_history_multi.h`.

### 4.3 YAML `includes:` strategy

```yaml
# firmware/esp32-c3-multi-sensor.yaml (after v7.6.6.8)
esphome:
  includes:
    - firmware/core/data-model.h        # 1. structs, constants, generated topology
    - firmware/core/history-buffer.h    # 2. RAM ring buffer, maybe_yield_nvs_scan_
    - firmware/core/history-store.h     # 3. NVS persist/restore
    - firmware/core/import-engine.h     # 4. CSV import state machine
    - firmware/core/auth-management.h   # 5. auth, lockout, deferred mgmt tasks
    - firmware/core/ping-adapter.h      # 6. PingAdapter class
    - firmware/core/aggregator-runtime.h # 7. cache, mutex, satellite polling
    - firmware/core/route-handlers.h    # 8. HistoryWebHandler, all /api/* routes
    - firmware/core/orchestration.h     # 9. boot registration
```

**Hand-maintained, not generated.** The dependency DAG is explicit and stable — it should not change unless a new subsystem is added. `render_sensor_config.py` never touches the YAML `includes:` list.

**Board profile impact:** The thin shim `dashboard/sensor_history_multi.h` ensures existing board YAML files (`esp32-wroom-32d-gw.yaml`, future C5/C6) that include the monolith path continue to work without modification. Updating board profiles to use the `firmware/core/` list directly is optional follow-up work, out of scope for Phase Y.

### 4.4 `web_server_idf` coordination

`HistoryWebHandler` is registered with `web_server_idf` via `webServerComponent->addHandler(...)` in `orchestration.h`. The registration call moves from the end of `sensor_history_multi.h` to `orchestration.h` — the handler class definition is in `route-handlers.h`, included before `orchestration.h` in the `includes:` list. No change to `web_server_idf.cpp` is required.

---

## 5. Migration Safety Rules

These rules apply to **every** Phase Y step without exception.

1. **Structural only.** No behavior changes. Same endpoints, same NVS schema, same RAM buffer semantics, same HTTP response formats. If a step reveals a pre-existing bug, the fix is a separate PR before the refactor step.
2. **All existing Playwright tests must pass after each step.** All four fixture sets (`3sensor`, `mixed`, `system`, `aggregator`) must be green. No test may be deleted or disabled.
3. **`esphome config` validates after every step.** Both satellite (`esp32-c3-multi-sensor.yaml`) and aggregator (`esp32-s3-devkitc1-n16r8-gw.yaml`) board profiles must validate without error.
4. **Each step is independently revertable.** Each step is a separate PR. Reverting step N must not break step N-1.
5. **Endpoint contracts unchanged.** All `/api/history*`, `/api/storage-stats`, `/api/satellite*`, and `/api/management*` endpoints must return identical responses. Verified by Playwright mock-server tests.
6. **NVS schema unchanged.** NVS key names, namespace (`history`), blob format (`SegmentSnapshot`), slot indexing, and `NUM_SENSORS`/`NUM_ENV_SENSORS` semantics are frozen for the entirety of Phase Y. Phase 7 extends the schema — Phase Y does not touch it.
7. **Generated artifacts remain valid.** After every step, `render_sensor_config.py --check` must pass. If the generator writes to the wrong file, this check catches it.
8. **Deferred-task patterns survive.** All 4 deferred-task pairs retain their exact callback pattern, timing, and state variable references. No deferred-task callback may be moved without verifying its state variables are still in scope.
9. **Mutex/lock scope survives.** `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` must have a single definition. No include step may produce a duplicate definition. Verify with `grep -r "s_cache_mutex" firmware/core/` after each aggregator-touching step.
10. **`maybe_yield_nvs_scan_()` survives with single definition.** Defined in `history-buffer.h`. Called from NVS scan loops in `history-store.h` and `aggregator-runtime.h`. Not redefined anywhere else.
11. **Post-Phase-X dashboard/test/guardrail compatibility.** Phase Y must not invalidate any Phase X preflight check, Playwright test, or critical rule. Specifically: generator `--check` must still pass for the dashboard JS markers (these are unaffected by Phase Y but must not regress).
12. **`#include` order is the dependency order.** Each module may only reference types, functions, and macros from modules that appear earlier in the YAML `includes:` list. Circular dependencies are forbidden. Verify with preprocessor gate (`gcc -E`) at each extraction step.

---

## 6. Coding Agent Task Size Analysis

### 6.1 Baseline — Today (pre-Phase Y)

| Task type | Files needed | Est. tokens |
| :-- | :-- | :-- |
| Any firmware history feature | `sensor_history_multi.h` (4,325 lines) | ~30K |
| Add Phase 7 per-device struct | `sensor_history_multi.h` + `render_sensor_config.py` | ~40K |
| Fix aggregator polling bug | Full monolith | ~30K |
| Fix import state machine bug | Full monolith | ~30K |
| Add new HTTP route | Full monolith + YAML | ~37K |
| Boot wiring change | Full monolith + YAML | ~37K |

### 6.2 After Level 1 (v7.6.6.1–6.6.2 — contiguous extractions)

| Task type | Files needed | Est. tokens |
| :-- | :-- | :-- |
| PingAdapter bug fix | `firmware/core/ping-adapter.h` (~285 lines) | ~3K |
| Boot registration change | `firmware/core/orchestration.h` (~30 lines) + YAML | ~2K |
| Aggregator route bug | `firmware/core/route-handlers-stub.h` + monolith (still large) | ~25K |
| Other tasks | Monolith (still mostly intact) | ~28K |

### 6.3 After Level 2 (v7.6.6.3–6.6.4 — data model + buffer isolated)

| Task type | Files needed | Est. tokens |
| :-- | :-- | :-- |
| Add Phase 7 struct | `firmware/core/data-model.h` + `render_sensor_config.py` | ~10K |
| Buffer algorithm change | `firmware/core/history-buffer.h` | ~3K |
| PingAdapter + any task | One focused module | ~3K–5K |
| NVS persist bug | Monolith (still present) | ~22K |

### 6.4 After Level 3 (v7.6.6.5–6.6.6 — NVS + import + auth isolated)

| Task type | Files needed | Est. tokens |
| :-- | :-- | :-- |
| Phase 7 NVS engine addition | `firmware/core/history-store.h` (~400 lines est.) | ~5K |
| Import state machine bug | `firmware/core/import-engine.h` (~450 lines est.) | ~5K |
| Auth lockout change | `firmware/core/auth-management.h` (~200 lines est.) | ~3K |
| Aggregator bug | Monolith (aggregator still present) | ~18K |

### 6.5 After Level 4 + Closure (v7.6.6.7–6.6.9 — final state)

| Task type | Files needed | Est. tokens |
| :-- | :-- | :-- |
| Phase 7 NVS engine (v7.7.0.1) | `firmware/core/history-store.h` + `data-model.h` | ~7K |
| Phase 7 boot restore (v7.7.0.2) | `firmware/core/history-store.h` + `orchestration.h` | ~6K |
| Phase 7 per-device route (v7.7.1.1) | `firmware/core/route-handlers.h` | ~8K |
| Phase 7 migration (v7.7.1.0) | `firmware/core/history-store.h` + `orchestration.h` | ~6K |
| Aggregator runtime bug | `firmware/core/aggregator-runtime.h` | ~6K |
| Aggregator route bug | `firmware/core/route-handlers.h` | ~8K |
| Add new sensor type | `firmware/core/data-model.h` + `render_sensor_config.py` | ~10K |
| Full board-switch task | `firmware/core/orchestration.h` + YAML | ~4K |

### 6.6 Architecture metrics summary

| Metric | Before Phase Y | After Phase Y | Improvement |
| :-- | :-- | :-- | :-- |
| Tokens per firmware task | 28K–40K | 3K–10K | **5x–8x reduction** |
| Largest single module | 4,325 lines (monolith) | ~450 lines (`import-engine.h` est.) | **9.6x reduction** |
| Source modules | 1 | 9 `firmware/core/*.h` + thin shim | Modular ownership |
| Generator write targets | 1 (monolith) | 1 (`data-model.h`) | Unchanged count, explicit target |
| Phase 7 token cost | ~40K (full monolith + generator) | ~7K–10K (targeted modules) | **4x–6x reduction** |

### 6.7 Per-step context estimate

| Version | Est. tokens | Notes |
| :-- | :-- | :-- |
| `v7.6.6.0` | ~5K | Shell script only — `provision.sh` |
| `v7.6.6.1` | ~35K | Must read full monolith to identify contiguous slice boundaries |
| `v7.6.6.2` | ~5K | Preflight + CI only |
| `v7.6.6.3` | ~30K | Must read monolith to extract data model + generator migration |
| `v7.6.6.4` | ~15K | Buffer extraction (data model read, buffer section read) |
| `v7.6.6.5` | ~20K | NVS section read + device test |
| `v7.6.6.6` | ~25K | Scattered zone — largest per-step read |
| `v7.6.6.7` | ~20K | Aggregator island 1 + mutex audit |
| `v7.6.6.8` | ~15K | Route handler extraction + YAML update |
| `v7.6.6.9` | ~8K | Closure + docs |


---

## 7. Rollout Order

### 7.1 Sequence rationale

```
v7.6.6.0  Pre-step (tooling)         ← Zero risk; enables safe pipeline automation
v7.6.6.1  Contiguous extractions     ← Easiest wins; proves include-chain mechanics
v7.6.6.2  CI + preflight wiring      ← Lock in guards before scattered work
v7.6.6.3  Data model + generator     ← Critical: generator migration; must be done before
                                         any Phase 7 struct addition
v7.6.6.4  History buffer             ← Clean RAM layer; enables Phase 7 store isolation
v7.6.6.5  NVS store                  ← Phase 7 extension target; highest device-test risk
v7.6.6.6  Import + auth (scattered)  ← Largest scattered extraction; do after stable includes
v7.6.6.7  Aggregator runtime         ← Mutex/deferred-task visibility; do after auth stable
v7.6.6.8  Route handlers             ← YAML change; final integration
v7.6.6.9  Closure                    ← Documentation + thin shim
```

**Why data model before buffer?** The data model defines all structs — buffer, store, import, aggregator all depend on it. It must be isolated first.

**Why store before scattered subsystems?** NVS store is a contiguous-ish block with clear function boundaries. Extracting it before the scattered zone gives the coding agent a simpler extraction before the hardest step.

**Why aggregator runtime before routes?** Routes call into the aggregator runtime; the runtime must be defined before routes can include it.

### 7.2 Gate conditions between levels

| Gate | Condition |
| :-- | :-- |
| Pre-step → Level 1 | v7.6.6.0 merged; `provision.sh --dry-run` verified; no C++ changes |
| Level 1 → Level 2 | v7.6.6.2 merged; preflight passes; preprocessor gate confirmed for ping + orchestration |
| Level 2 → Level 3 | v7.6.6.4 merged; `render_sensor_config.py --check` passes; `generator_markers_in_data_model` preflight passes |
| Level 3 (store) → Level 3 (scattered) | v7.6.6.5 merged; **device test complete** (NVS restore verified on real hardware) |
| Level 3 (scattered) → Level 4 | v7.6.6.6 merged; import round-trip device test complete; preprocessor gate passes |
| Level 4 (runtime) → Level 4 (routes) | v7.6.6.7 merged; aggregator device test complete; mutex audit clean |
| Level 4 → Closure | v7.6.6.8 merged; `esphome config` passes for both boards; full Playwright suite green |

### 7.3 Device testing vs. compile-only gates

| Step | Gate type | Rationale |
| :-- | :-- | :-- |
| v7.6.6.0–6.6.2 | Compile-only (`esphome config`) + Playwright | No runtime-path changes |
| v7.6.6.3 | Compile-only + generator `--check` | Generator path change; no runtime change |
| v7.6.6.4 | Compile-only + Playwright | Buffer primitives; no NVS |
| **v7.6.6.5** | **Device test required** | NVS read/write path; boot restore is critical |
| **v7.6.6.6** | **Device test required** | Import state machine; auth lockout |
| **v7.6.6.7** | **Device test required** | Aggregator mutex; deferred tasks |
| **v7.6.6.8** | **Device test required** | YAML `includes:` change; route handler registration |
| v7.6.6.9 | Compile-only + Playwright | Documentation + thin shim |

### 7.4 Optional early stop

If Phase 7 must start before Phase Y completes:

- **Minimum viable split:** v7.6.6.0–v7.6.6.3 (pre-step + contiguous extractions + data model isolation). Phase 7 can add `DeviceHistoryMeta`/`DeviceSegment` to `firmware/core/data-model.h` without the full split.
- **Full split:** All 10 steps recommended for maximum Phase 7/E benefit.

---

## 8. Risks and Mitigations

| Risk | Severity | Steps affected | Mitigation |
| :-- | :-- | :-- | :-- |
| **NVS schema breakage** — extraction changes code path, corrupts existing blobs | High | v7.6.6.5 | Migration safety rule 6: schema frozen. Device test (boot + restore). Verify `hist_meta` and `seg_NNN` key names unchanged by inspection. |
| **`#include` order violation** — module references type from later-included file | High | All extractions | Migration safety rule 12. Preprocessor gate (`gcc -E`) after each step. Dependency DAG enforced by `includes:` list order. |
| **Generator marker ownership confusion** — `render_sensor_config.py` writes to wrong file after `H_PATH` change | High | v7.6.6.3 | `generator_markers_in_data_model` preflight check. Generator `--check` after every pipeline run. Verify by running `--write` and checking file mtime. |
| **YAML `includes:` order breakage** — wrong order causes compile error | High | v7.6.6.8 | Hand-maintain in dependency order. CI ESPHome config check. Test both satellite and aggregator board profiles. |
| **Mutex/lock visibility across files** — `s_cache_mutex` duplicated or not visible | High | v7.6.6.7 | Single definition in `aggregator-runtime.h`. `grep -r s_cache_mutex firmware/core/` after extraction to verify one definition. Migration rule 9. |
| **Deferred-task visibility** — callback lambda references state var that moved to different module | High | v7.6.6.6–6.6.7 | All 4 deferred-task pairs have explicit module homes (see §E). Include chain verified before step. |
| **Static buffer ownership** — static arrays defined in multiple included headers (ODR violation) | High | v7.6.6.3–6.6.4 | Each static defined once. `#pragma once` on every header. Preprocessor gate catches duplicates. |
| **Aggregator two-island shared state** — island 2 routes reference island 1 state without visibility | High | v7.6.6.7–6.6.8 | Island 2 moved to `route-handlers.h` which includes `aggregator-runtime.h`. Single-ownership resolution (see §D). |
| **`web_server_idf` handler registration** — handler class not visible at registration call site | Medium | v7.6.6.8 | `orchestration.h` includes `route-handlers.h` via `includes:` order. Verify at `esphome config` validate step. |
| **Binary size / compile changes** — header-only C++ with static functions may produce duplicate symbol warnings | Medium | All extractions | Use `inline` or `static` consistently. Preprocessor gate catches unexpected symbol duplication. |
| **`maybe_yield_nvs_scan_()` duplication** — defined in multiple headers after split | Medium | v7.6.6.4–6.6.5 | Single definition rule (migration rule 10). `grep -r maybe_yield_nvs_scan_ firmware/core/` after each step. |
| **Import suspend/resume guard broken** — `isImportActive()` not visible from aggregator polling path | Medium | v7.6.6.6 | `import-engine.h` included before `aggregator-runtime.h` in `includes:` list. Cross-reference at extraction time. |
| **`satellite_config_generation` counter not visible to routes** — counter incremented in runtime, read in routes | Medium | v7.6.6.7–6.6.8 | Defined in `aggregator-runtime.h`, included by `route-handlers.h`. Verified via `#include` chain analysis. |
| **Board profile impact on thin shim** — WROOM / future boards use `sensor_history_multi.h` path | Low | v7.6.6.9 | Thin shim preserves backward compatibility. All board profiles continue to work. |
| **Phase 7 starts before Phase Y gate** — Phase 7 adds structs to monolith, undoing partial split | Low | v7.6.6.3 | Gate condition: Phase 7 does not start until v7.6.6.3 (data model isolated). Generator target established before Phase 7 struct additions. |


---

## 9. Open Questions

Reference: `Docs/phase-X-context-for-phase-Y.md` §7 — seven open questions.


| \# | Question | This plan's resolution | Status |
| :-- | :-- | :-- | :-- |
| Q1 | **What is the feasible verification strategy for C++ identity (no SHA-256)?** | Resolved: Preprocessor output comparison (`gcc -E -P`) for contiguous extractions (Levels 1–2); functional equivalence (device test + Playwright) for scattered extractions (Levels 3–4). Binary identity is not achievable for C++ — preprocessor identity is the highest achievable bar. See §3 identity gate analysis. | **Resolved** |
| Q2 | **Does `sensor_history_multi.h` stay as a thin shim or is it removed entirely?** | Resolved: Option A — thin include-assembly shim. Preserves backward compatibility for WROOM and |  |

