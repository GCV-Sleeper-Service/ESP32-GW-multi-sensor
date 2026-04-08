# Phase Y — `sensor_history_multi.h` Architecture and Refactor Plan

_Date: 2026-04-08_
_Phase: Phase Y — Post-Phase X firmware module decomposition_
_Version range: `v7.6.6.0`–`v7.6.6.7` (v7.6.6.0 is a pre-step)_
_Status: Planning — not yet implemented_
_Prerequisite: Phase X Complete (v7.6.5.8 on `main`, all Playwright tests green)_
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Primary inputs: phase-Y-deep-research-brief.md (R1–R8), phase-Y-current-state-inventory-sensor-history-v2.md (§1–§14)_

---

## 1. Current State Analysis

### 1.1 File Metrics (verified at HEAD v7.6.5.8)

| Metric | Value | Notes |
|---|---:|---|
| Exact line count | **4,325** | Confirmed by `wc -l dashboard/sensor_history_multi.h` |
| Named struct types | **10** | 9 top-level + 1 nested (`EpochSlotEntry` inside `HistoryWebHandler`) |
| Classes | **3** | `HistoryBuffer`, `PingAdapter`, `HistoryWebHandler` |
| Top-level helper / free functions | **38** | Outside class bodies |
| Endpoint-specific handler methods | **21** | `HistoryWebHandler` endpoint families only |
| Deferred-task pairs | **4** | Reboot, delete-data, reset-satellites, save-satellites-NVS |
| Generator marker blocks | **2** | `SENSOR_MANIFEST:HEADER` (lines 375–379), `SENSOR_MANIFEST:ENTITY` (lines 381–496) |
| Named compile-time constants / macros | **31** | Includes `#define` and `static constexpr` items |
| Static shared buffers / arrays | **15** | 11 generated `HistoryBuffer` statics + `devices[]` + `satellite_caches[]` + `s_fetch_tmp` + `s_proxy_tmp` |
| Responsibilities | **11** | See §1.2 |

### 1.2 Why the Current Structure Is Expensive

`sensor_history_multi.h` is not a history header. It is a **multi-subsystem integration unit** that hosts 11 distinct logical responsibilities in a single 4,325-line file:

1. Compile-time constants and standard includes (lines 1–95)
2. `HistEntry`, `HistoryBuffer`, `MetricDef`, `MetricState`, `SensorEntity` types (lines 96–369)
3. Generator-owned sensor entity and config blocks (lines 375–496)
4. NVS segment model, NVS core helpers, restore, hourly persist (lines 526–1168)
5. Deferred management tasks: reboot, delete-data (lines 1170–1203)
6. Ping adapter background ICMP probe (`PingAdapter`) (lines 1220–1369)
7. Aggregator runtime: cache structs, mutex, buffers, fetch, probe, NVS satellite persistence, poll task, deferred satellite tasks (lines 1388–2272, guarded by `#if AGGREGATOR_ENABLED`)
8. `HistoryWebHandler` core: route classification, dispatch, auth, dashboard, manifest, status, history, import (lines 2279–3708)
9. Aggregator endpoint handlers inside `HistoryWebHandler` (lines 3709–4283)
10. Handler registration / orchestration (`register_history_handler`, lines 4285–4325)
11. Two generator-owned blocks embedded in the type/entity section

Any task touching a single responsibility currently forces an agent to load the full 4,325-line file — all 11 subsystems — before writing a single line of code.

**Token cost at current state:** approximately 27K–32K tokens for the file alone. Add the YAML file (~6K tokens), the active board config (~2K), relevant lesson files (~8K), and the test spec for the changed route (~4K). A typical single-endpoint task costs **47K–52K tokens** of context before the agent starts writing. This exceeds the practical 30K–40K coding-agent context window.

### 1.3 Why Phase 7 Makes It Worse

Phase 7 (per-device persistence, v7.7.0.x) adds directly to the heaviest modules:

| Module | Phase 7 addition | Delta |
|---|---|---|
| `data-model.h` | `DeviceHistoryMeta`, `DeviceSegmentHeader`, `DeviceSegment` structs + new generator constants | +~100 lines |
| `nvs-persistence.h` | `persist_device_segment_()`, `persist_all_devices_v2()`, `restore_device_()`, `restore_all_devices_v2()`, `load_device_meta_()`, `save_device_meta_()`, `calculate_retention_budget_()`, `migrate_v7_to_v8_()` | +~400 lines |
| `web-handler.h` | Updated `handle_storage_stats_()` for per-device format; new per-device history endpoint (v7.7.1.x) | +~150 lines |
| YAML `on_time` / `on_boot` lambdas | New `persist_all_devices_v2()` and `restore_all_devices_v2()` calls | +~10 lines |

Without the Phase Y split, the file reaches ~5,000 lines before Phase 7 completes. Doing the split first means Phase 7 agents load only the 2–3 modules they actually need, keeping task context at 10K–15K tokens.

### 1.4 Current Context-Window Cost Estimate

| Task type | Modules needed (current) | Token estimate | Modules needed (after Phase Y) | Token estimate (after) |
|---|---|---:|---|---:|
| Fix history-chart endpoint bug | Full monolith + YAML + test | ~50K | `web-handler.h` + `data-model.h` + test | ~12K |
| Add NVS helper function | Full monolith + YAML | ~33K | `nvs-persistence.h` + `data-model.h` | ~8K |
| Ping adapter tuning | Full monolith | ~27K | `ping-adapter.h` + `data-model.h` | ~5K |
| Aggregator poll task change | Full monolith + YAML | ~33K | `aggregator-runtime.h` + `data-model.h` | ~9K |
| New management endpoint | Full monolith + YAML + test | ~50K | `web-handler.h` + `nvs-persistence.h` + test | ~14K |

**Phase Y target:** every routine task fits in a 15K–20K token budget. Reduction factor: **3x–5x**.

---

## 2. Proposed Directory Structure

### 2.1 Current Layout

```
ESP32-GW-multi-sensor/
├── dashboard/
│   └── sensor_history_multi.h          ← 4,325-line monolith (all roles)
├── firmware/
│   └── esp32-c3-multi-sensor.yaml      ← includes: [sensor_history_multi.h]
└── scripts/
    ├── render_sensor_config.py          ← writes into sensor_history_multi.h
    └── provision.sh                     ← prints 8-step pipeline (step 0 only auto-runs)
```

### 2.2 Target Layout (Option B — Assembled Artifact)

```
ESP32-GW-multi-sensor/
├── dashboard/
│   └── sensor_history_multi.h          ← ASSEMBLED ARTIFACT (committed, generated by assemble-firmware-modules.sh)
├── firmware/
│   ├── core/                           ← NEW: fragment source modules
│   │   ├── config.h                    ← lines 1–95 (compile-time constants, standard includes)
│   │   ├── data-model.h                ← lines 96–525 (types + ENTITY marker blocks)
│   │   ├── nvs-persistence.h           ← lines 526–1218 (NVS model, core helpers, restore, persist, deferred mgmt tasks)
│   │   ├── ping-adapter.h              ← lines 1220–1369 (PingAdapter class, guarded by #ifdef PING_DEVICE_INDEX)
│   │   ├── aggregator-runtime.h        ← lines 1388–2272 (aggregator runtime, guarded by #if AGGREGATOR_ENABLED)
│   │   ├── web-handler.h               ← lines 2279–4283 (HistoryWebHandler with ALL endpoint methods)
│   │   └── registration.h              ← lines 4285–4325 (register_history_handler)
│   └── esp32-c3-multi-sensor.yaml      ← UNCHANGED — still includes: [sensor_history_multi.h]
└── scripts/
    ├── assemble-firmware-modules.sh    ← NEW: concatenates firmware/core/*.h → dashboard/sensor_history_multi.h
    ├── render_sensor_config.py         ← UNCHANGED under Option B (writes into assembled artifact)
    └── provision.sh                    ← UPDATED: --auto / pipeline subcommand (v7.6.6.0)
```

### 2.3 Fragment Module Justification

Each fragment is justified by the v2 inventory §9 contiguous/scattered analysis and research brief R1 verified line ranges:

| Fragment | Line range | Contiguous? | Justification |
|---|---|---|---|
| `config.h` | 1–95 | YES | Standard includes, `TAG`, compile-time `#define`/`constexpr` — no consumers, only providers. Zero runtime symbols. Cleanest possible extraction seam. |
| `data-model.h` | 96–525 | YES | `HistEntry`, `HistoryBuffer`, all metric/entity type definitions, and both generator marker blocks. Everything downstream depends on this module; nothing in this block depends on anything downstream. Marker blocks must live here so the generator writes into the assembled artifact's type section. |
| `nvs-persistence.h` | 526–1218 | YES | Contiguous NVS segment model + NVS core helpers + `restore_from_nvs` + `persist_hourly_segment` + deferred management tasks (reboot, delete-data). These tasks are included here because they use `clear_runtime_histories_` from data-model and `open_history_nvs_` from the NVS core — all visible within this fragment. |
| `ping-adapter.h` | 1220–1369 | YES | `PingAdapter` class is a single contiguous block, cleanly guarded by `#ifdef PING_DEVICE_INDEX`. Lowest fan-in/fan-out of all candidates. **Best first-extraction candidate** (research brief R1, v2 inventory §9.2). |
| `aggregator-runtime.h` | 1388–2272 | YES | Entire `#if AGGREGATOR_ENABLED` top-level block: constants, structs, mutex, buffers, `fetch_to_buffer`, `probe_satellite_manifest_`, NVS satellite persistence, `aggregator_poll_task`, deferred satellite tasks, `start_aggregator_task`. One island of the aggregator two-island problem. |
| `web-handler.h` | 2279–4283 | YES | `HistoryWebHandler` class including ALL endpoint methods (both core handlers and aggregator endpoint cluster). The class is a single contiguous block. Aggregator endpoint methods (second aggregator island) remain here because they are class methods — extracting them would require splitting the class body. |
| `registration.h` | 4285–4325 | YES | `register_history_handler` — the 41-line orchestration tail. Tiny and independently meaningful; isolates boot-time wiring. |

### 2.4 Assembly Approach — Why Option B

The plan adopts **Option B (assembled artifact)**: `assemble-firmware-modules.sh` concatenates the fragment files in defined order to produce the committed `dashboard/sensor_history_multi.h`. This choice is made because:

1. **Zero preflight impact** — all 18 existing checks that reference `sensor_history_multi.h` continue to pass without modification, because they check the assembled file content.
2. **Zero generator impact** — `render_sensor_config.py` continues to write into `sensor_history_multi.h` exactly as today.
3. **Zero YAML impact** — `firmware/esp32-c3-multi-sensor.yaml`'s `includes:` list is unchanged.
4. **Zero CI risk** — no checks need rewriting during the split.
5. **Exact analogy to Phase X** — `assemble-firmware-modules.sh` is the firmware equivalent of `bundle-dashboard.sh`.

Under Option B the ESPHome compiler never sees the fragment files directly. `sensor_history_multi.h` remains the single file the compiler includes.

---

## 3. Versioned Steps

### v7.6.6.0 — Pre-Step: `provision.sh` Full Pipeline Automation

**Status:** Pre-step — no fragment extraction, no code changes to `sensor_history_multi.h`

**Problem solved:** `provision.sh` currently auto-runs only `render_sensor_config.py --write` (an incorrectly-positioned step 0). The remaining 7 pipeline steps must be manually run by the operator. This is a Known operational gap (v2 inventory §12.2 and research brief R8). The `assemble-firmware-modules.sh` step must also be insertable into the pipeline before Phase Y fragment work begins.

**Files created / modified:**

| File | Change |
|---|---|
| `scripts/provision.sh` | Add `--auto` flag and `pipeline` subcommand that executes all 8 pipeline steps automatically; add `--dry-run` option; add dependency checks for `node`, `npm`, `python3`, `gzip` |

**New provision.sh behavior:**

```bash
# Existing behavior (unchanged):
provision.sh <target>               # switch config + print pipeline (as before)

# New behavior:
provision.sh <target> --auto        # switch config + execute all 8 steps automatically
provision.sh <target> pipeline      # alias for --auto
provision.sh <target> --dry-run     # print steps without executing
```

**Full auto pipeline executed by `--auto`:**

```bash
# Dependency pre-checks
require_cmd node "node is required for generate-fixtures.js and bundle-dashboard.sh"
require_cmd npm "npm is required to install devDependencies"
require_cmd python3 "python3 is required for render_sensor_config.py"
require_cmd gzip "gzip is required for generate-header.sh"
require_npm_deps   # runs npm install if node_modules missing

# Step 1: Assemble firmware modules → sensor_history_multi.h (Phase Y: no-op until v7.6.6.1+)
# (placeholder for assemble-firmware-modules.sh --write once Phase Y fragments exist)

# Step 2: Bundle dashboard source modules → dashboard.js
bash scripts/bundle-dashboard.sh --write

# Step 3: Re-inject generator markers into dashboard.js (markers erased by bundle step)
python3 scripts/render_sensor_config.py --write

# Step 4: Regenerate test fixtures from current config
node tests/fixtures/generate-fixtures.js

# Step 5: Re-inject again (fixture generation may modify state)
python3 scripts/render_sensor_config.py --write

# Step 6: Build dashboard.html from template + dashboard.js
bash scripts/build-dashboard.sh --write

# Step 7: Minify dashboard.html → dashboard.min.html
bash scripts/minify-dashboard.sh

# Step 8: Generate dashboard.h gzip C header
bash scripts/generate-header.sh

# Step 9: Final verification
python3 scripts/render_sensor_config.py --check
```

**Acceptance criteria:**

- [ ] `provision.sh <target>` (no flag) behavior unchanged — config switch + pipeline instructions printed
- [ ] `provision.sh <target> --auto` executes all 8 steps in order, exits 0 on success
- [ ] `provision.sh <target> --dry-run` prints all steps without executing any
- [ ] `provision.sh --help` documents all flags
- [ ] Dependency pre-checks produce clear errors when `node`, `python3`, or `gzip` missing
- [ ] `npm install` runs automatically if `node_modules` missing
- [ ] All Playwright tests pass after step
- [ ] All preflight checks pass after step
- [ ] Placeholder for `assemble-firmware-modules.sh --write` present in pipeline (no-op until v7.6.6.1+)

**Risk:** Low  
**Estimated effort:** 1 session  
**Identity/verification gate:** `bash scripts/provision.sh --help` succeeds; dry-run output matches expected pipeline steps

---

### v7.6.6.1 — `firmware/core/` Directory + Assembly Script Scaffold

**Status:** First structural step — creates directory and assembly infrastructure; does not yet extract any code

**Files created / modified:**

| File | Change |
|---|---|
| `firmware/core/.keep` | Create directory marker |
| `scripts/assemble-firmware-modules.sh` | New script: concatenates fragment files in defined order → `dashboard/sensor_history_multi.h` |

**`assemble-firmware-modules.sh` specification:**

```bash
#!/usr/bin/env bash
# assemble-firmware-modules.sh — assembles firmware/core/*.h fragments
# into dashboard/sensor_history_multi.h (the ESPHome-compiled assembled artifact).
#
# Usage:
#   --write    Assemble and overwrite dashboard/sensor_history_multi.h
#   --check    Verify that dashboard/sensor_history_multi.h matches assembly output
#   --dry-run  Print assembly order without writing

MODULES=(
  "firmware/core/config.h"
  "firmware/core/data-model.h"
  "firmware/core/nvs-persistence.h"
  "firmware/core/ping-adapter.h"
  "firmware/core/aggregator-runtime.h"
  "firmware/core/web-handler.h"
  "firmware/core/registration.h"
)

OUTPUT="dashboard/sensor_history_multi.h"
```

At v7.6.6.1 the `MODULES` array lists fragment paths that do not yet exist. The script must handle missing fragments gracefully in `--check` mode (skip if file missing) and warn in `--write` mode (assemble only present fragments, warn about missing ones).

**Acceptance criteria:**

- [ ] `firmware/core/` directory exists in repository
- [ ] `scripts/assemble-firmware-modules.sh` exists and is executable
- [ ] `assemble-firmware-modules.sh --check` exits 0 when all listed fragments are absent (no-op pass for empty state)
- [ ] `assemble-firmware-modules.sh --dry-run` prints assembly order
- [ ] `assemble-firmware-modules.sh --write` with no fragments present produces no change to `sensor_history_multi.h`
- [ ] `provision.sh <target> --auto` now calls `assemble-firmware-modules.sh --write` as step 1 (active, not placeholder)
- [ ] All Playwright tests pass after step
- [ ] All preflight checks pass after step

**Risk:** Low  
**Estimated effort:** 0.5 sessions  
**Identity/verification gate:** `sha256sum dashboard/sensor_history_multi.h` unchanged before and after this step

---

### v7.6.6.2 — Extract `config.h` Fragment

**Lines extracted:** 1–95 (compile-time constants, standard includes, `TAG` definition)

**Exact boundary:** Line 1 (`#pragma once`) through line 95 (`static const char *const TAG = "history";`).

**Files created / modified:**

| File | Change |
|---|---|
| `firmware/core/config.h` | New fragment: lines 1–95 of current `sensor_history_multi.h` |
| `dashboard/sensor_history_multi.h` | Regenerated from fragments (config.h present; others still absent — assembler uses existing file lines for missing fragments) |
| `scripts/assemble-firmware-modules.sh` | `config.h` slot is now populated; `--check` verifies this fragment is correct |

**Acceptance criteria:**

- [ ] `firmware/core/config.h` exists and contains lines 1–95 (verified by `grep -n '#pragma once' firmware/core/config.h` → line 1)
- [ ] `firmware/core/config.h` ends with `static const char *const TAG = "history";`
- [ ] `assemble-firmware-modules.sh --check` exits 0 after regeneration
- [ ] SHA-256 of `dashboard/sensor_history_multi.h` is identical to pre-step SHA-256
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates without error (compile-only gate)
- [ ] All Playwright tests pass
- [ ] All preflight checks pass (all 68 checks, including all 18 `sensor_history_multi.h`-content checks)

**Risk:** Low — no symbols defined in config.h are defined elsewhere; this block has no consumers within itself  
**Estimated effort:** 0.5 sessions  
**Identity/verification gate:** SHA-256 of assembled artifact matches SHA-256 of `sensor_history_multi.h` before extraction

---

### v7.6.6.3 — Extract `data-model.h` Fragment (Includes Generated Marker Blocks)

**Lines extracted:** 96–525 (`HistEntry`, `HistoryBuffer`, `MetricDef`, `MetricState`, `SensorEntity` type definitions + both `SENSOR_MANIFEST:HEADER` and `SENSOR_MANIFEST:ENTITY` marker blocks + end-of-generated-block comments)

**Exact boundary:**
- Start: line 96 (`static const char *const TAG = "history";` **already in config.h** — data-model.h starts at the first line after TAG, which is the `HistEntry` struct at ~line 97)
- End: line 525 (end of the "NUM_DEVICES is set in the ENTITY_BEGIN block" comment block that closes the generated section)

> **Critical note on generator markers:** The `SENSOR_MANIFEST:HEADER` (lines 375–379) and `SENSOR_MANIFEST:ENTITY` (lines 381–496) marker blocks live entirely within this fragment. Under Option B, `render_sensor_config.py` continues to write into the **assembled** `dashboard/sensor_history_multi.h`. The generator must run **after** `assemble-firmware-modules.sh --write` in the pipeline, so that the assembled file contains the marker blocks and the generator can find them. This is the same pattern as `bundle-dashboard.sh` → `render_sensor_config.py` in the dashboard pipeline.

**Files created / modified:**

| File | Change |
|---|---|
| `firmware/core/data-model.h` | New fragment: types + marker blocks (lines 96–525) |
| `dashboard/sensor_history_multi.h` | Regenerated by assembler then overwritten by generator |

**Pipeline order after this step:**

```
assemble-firmware-modules.sh --write   ← produces sensor_history_multi.h from fragments
render_sensor_config.py --write        ← writes HEADER and ENTITY blocks into assembled file
```

**Acceptance criteria:**

- [ ] `firmware/core/data-model.h` exists and contains `struct HistEntry`, `class HistoryBuffer`, `struct MetricDef`, `struct MetricState`, `struct SensorEntity`
- [ ] `firmware/core/data-model.h` contains `// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>` (line 375 landmark)
- [ ] `firmware/core/data-model.h` contains `// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>` (line 381 landmark)
- [ ] `render_sensor_config.py --check` passes after `assemble-firmware-modules.sh --write` + `render_sensor_config.py --write`
- [ ] SHA-256 of final assembled+generated `sensor_history_multi.h` matches pre-step SHA-256
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates
- [ ] All Playwright tests pass
- [ ] All preflight checks pass (generator marker checks at lines 319–323 of preflight.sh must still pass)

**Risk:** High — generator seam is in this fragment; any ordering error breaks artifact sync  
**Estimated effort:** 1 session  
**Identity/verification gate:** SHA-256 gate + `render_sensor_config.py --check`

---

### v7.6.6.4 — Extract `nvs-persistence.h` Fragment

**Lines extracted:** 526–1218 (NVS segment model constants and structs, all NVS core helper functions, `restore_from_nvs`, `persist_hourly_segment`, deferred management task pairs: reboot + delete-data)

**Exact boundary:**
- Start: line 526 (NVS segment model comment block header: `// Hourly NVS segment model`)
- End: line 1218 (end of `schedule_delete_data_()` — last function before `#ifdef PING_DEVICE_INDEX`)

**Landmark verification:**
- `struct HistoryMeta {` at line 556 → inside this fragment ✓
- `static bool restore_from_nvs()` at line 1004 → inside this fragment ✓
- `static void persist_hourly_segment(...)` at line 1109 → inside this fragment ✓
- `static void reboot_task_` at line 1170 → inside this fragment ✓
- `#ifdef PING_DEVICE_INDEX` at line 1220 → start of NEXT fragment ✓

**Files created / modified:**

| File | Change |
|---|---|
| `firmware/core/nvs-persistence.h` | New fragment: NVS model + core + restore + persist + deferred management tasks |
| `dashboard/sensor_history_multi.h` | Regenerated by assembler |

**Phase 7 readiness:** Phase 7's new NVS functions (`persist_device_segment_`, `restore_device_`, etc.) will be appended to this fragment. The module boundary is correct for Phase 7 because all Phase 7 NVS helpers use `HistoryBuffer` (from `data-model.h`) and `open_history_nvs_` (in this fragment itself).

**Acceptance criteria:**

- [ ] `firmware/core/nvs-persistence.h` contains `struct HistoryMeta`, `struct SegmentSnapshot`, `restore_from_nvs`, `persist_hourly_segment`, `reboot_task_`, `schedule_reboot_`, `delete_data_task_`, `schedule_delete_data_`
- [ ] `firmware/core/nvs-persistence.h` does **not** contain `#ifdef PING_DEVICE_INDEX` or any PingAdapter code
- [ ] SHA-256 gate passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates
- [ ] All Playwright tests pass
- [ ] All preflight checks pass (NVS-yield check at preflight.sh line 163–168 must find ≥3 calls to `maybe_yield_nvs_scan_` in the assembled `sensor_history_multi.h`)

**Risk:** Very High — NVS schema, migration, and restore logic are the highest-risk refactor zone (v2 inventory §10). No behavioral changes — structural split only.  
**Estimated effort:** 1 session  
**Identity/verification gate:** SHA-256 gate; device smoke test (real hardware) after this step before proceeding

---

### v7.6.6.5 — Extract `ping-adapter.h` Fragment (Lowest Risk)

**Lines extracted:** 1220–1369 (`PingAdapter` class, fully guarded by `#ifdef PING_DEVICE_INDEX` / `#endif  // PING_DEVICE_INDEX`)

**Exact boundary:**
- Start: line 1220 (`#ifdef PING_DEVICE_INDEX`)
- End: line 1369 (`#endif  // PING_DEVICE_INDEX`)

**Why this step is first contiguous-slice extraction after NVS:** `PingAdapter` is the cleanest extraction target in the file — a self-contained class with the smallest cross-module footprint. It accesses `devices[PING_DEVICE_INDEX]` (from `data-model.h`) and uses FreeRTOS types (from `config.h`). Both are available via the assembly include chain. No NVS, no mutex, no web handler dependencies.

**Files created / modified:**

| File | Change |
|---|---|
| `firmware/core/ping-adapter.h` | New fragment: entire `#ifdef PING_DEVICE_INDEX` block |
| `dashboard/sensor_history_multi.h` | Regenerated by assembler |

**Acceptance criteria:**

- [ ] `firmware/core/ping-adapter.h` starts with `#ifdef PING_DEVICE_INDEX` and ends with `#endif  // PING_DEVICE_INDEX`
- [ ] `firmware/core/ping-adapter.h` contains `class PingAdapter` with `start()`, `ping_task_()`, and ping callback
- [ ] No PingAdapter code remains in any other fragment
- [ ] SHA-256 gate passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates
- [ ] All Playwright tests pass
- [ ] All preflight checks pass

**Risk:** Low — cleanly bounded by `#ifdef`, single-class, no NVS or aggregator coupling  
**Estimated effort:** 0.5 sessions  
**Identity/verification gate:** SHA-256 gate

---

### v7.6.6.6 — Extract `aggregator-runtime.h` Fragment

**Lines extracted:** 1388–2272 (entire `#if AGGREGATOR_ENABLED` top-level block)

**Exact boundary:**
- Start: line 1388 (`#if AGGREGATOR_ENABLED`)
- End: line 2272 (`#endif  // AGGREGATOR_ENABLED`)

**Contents of this fragment:**
- `TAG_AGG`, `AGG_MANIFEST_BUF_SIZE` constant
- `SatelliteCache` struct (line 1409)
- `SatelliteNVSSnapshot` struct
- `s_cache_mutex` (line 1479), `AGG_LOCK()` / `AGG_UNLOCK()` macros (lines 1487–1488)
- `s_fetch_tmp[AGG_MANIFEST_BUF_SIZE]` (task-context-only buffer)
- `s_proxy_tmp[32768]` (web-handler-context-only buffer)
- `fetch_to_buffer` (line 1511)
- `probe_satellite_manifest_` (line 1614) — note: uses `s_proxy_tmp`; comment documents MUST be called from web-handler context only
- NVS satellite persistence helpers (lines 1702–1920)
- `aggregator_poll_task` (line 1922)
- Deferred satellite task pairs: `reset_satellites_task_` / `schedule_reset_satellites_`, `save_satellites_nvs_task_` / `schedule_save_satellites_nvs_` (lines 2153–2259)
- `start_aggregator_task` (line 2261)

**Critical note — aggregator two-island problem:** This fragment contains one island of the aggregator subsystem (the top-level runtime block). The second island — aggregator endpoint handler methods — lives inside `HistoryWebHandler` in `web-handler.h`. Under Option B this is not a problem: both islands are present in the assembled `sensor_history_multi.h`, and `web-handler.h` includes `aggregator-runtime.h` implicitly through the assembly order. See §D (Aggregator Two-Island Problem) for full treatment.

**Files created / modified:**

| File | Change |
|---|---|
| `firmware/core/aggregator-runtime.h` | New fragment: entire `#if AGGREGATOR_ENABLED` block |
| `dashboard/sensor_history_multi.h` | Regenerated by assembler |

**Acceptance criteria:**

- [ ] `firmware/core/aggregator-runtime.h` starts with `#if AGGREGATOR_ENABLED` and ends with `#endif  // AGGREGATOR_ENABLED`
- [ ] `firmware/core/aggregator-runtime.h` contains `SatelliteCache`, `s_cache_mutex`, `AGG_LOCK`, `AGG_UNLOCK`, `fetch_to_buffer`, `aggregator_poll_task`, `start_aggregator_task`
- [ ] SHA-256 gate passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates with both `AGGREGATOR_ENABLED 0` (CI-safe default) and with aggregator config enabled
- [ ] All Playwright tests pass
- [ ] All preflight checks pass (aggregator route checks at preflight.sh lines 366–370 must still pass on the assembled file)

**Risk:** High — largest single extracted fragment, complex concurrency model, two-island split  
**Estimated effort:** 1 session  
**Identity/verification gate:** SHA-256 gate; device test with aggregator config enabled

---

### v7.6.6.7 — Extract `web-handler.h` + `registration.h` Fragments

**Lines extracted:**
- `web-handler.h`: lines 2279–4283 (`HistoryWebHandler` class with ALL endpoint methods)
- `registration.h`: lines 4285–4325 (`register_history_handler`)

**Exact boundaries:**
- `web-handler.h` start: line 2279 (`class HistoryWebHandler : public AsyncWebHandler {`)
- `web-handler.h` end: line 4283 (`};` — end of class body)
- `registration.h` start: line 4285 (blank line before registration comment)
- `registration.h` end: line 4325 (end of file)

**Contents of `web-handler.h`:**
- Route classification + `canHandle` + `handleRequest` dispatch (lines 2279–2523)
- Private helpers: `authenticate_management_`, `base64_decode_`, `secure_equals_`, `add_common_headers_`, `send_json_error_` (lines 2525–2680)
- Core endpoint handlers: `handle_dashboard_`, `handle_manifest_`, `handle_api_manifest_`, `handle_api_v2_live_`, `handle_api_v2_history_`, `handle_api_ingest_`, `handle_reboot_`, `handle_delete_data_`, `handle_import_begin_`, `handle_import_data_`, `handle_import_finish_`, `handle_storage_stats_`, `handle_status_`, `handle_history_` (lines 2681–3708)
- Aggregator endpoint handlers: `handle_aggregator_gateways_`, `handle_aggregator_live_`, `handle_aggregator_proxy_`, `handle_add_satellite_`, `handle_delete_satellite_`, `handle_test_satellite_`, `handle_reset_satellites_` (lines 3709–4283)

**Note on Q1 (research brief):** `handle_api_manifest_` at line 2722 is a one-liner that serves `GATEWAY_MANIFEST_JSON`. It remains in `web-handler.h` with all other endpoint handlers — moving it to `data-model.h` would couple the data model to HTTP response logic.

**Note on Q2 (research brief):** `probe_satellite_manifest_` (line 1614) uses `s_proxy_tmp` and is documented as web-handler-context-only. It lives in `aggregator-runtime.h` where it is defined. The existing comment is preserved. No move needed — it is already physically in the aggregator runtime block.

**Note on Q3 (research brief):** `handle_options_` (line 2681, ~3 lines) lives in `web-handler.h` with all other handlers. No special treatment needed.

**Files created / modified:**

| File | Change |
|---|---|
| `firmware/core/web-handler.h` | New fragment: entire `HistoryWebHandler` class |
| `firmware/core/registration.h` | New fragment: `register_history_handler` function |
| `dashboard/sensor_history_multi.h` | Regenerated from all 7 fragments — fully assembled |

**After this step**, `assemble-firmware-modules.sh --check` verifies that all 7 fragments concatenate exactly to the committed `sensor_history_multi.h`.

**Acceptance criteria:**

- [ ] All 7 fragment files exist in `firmware/core/`
- [ ] `firmware/core/web-handler.h` contains all 21 endpoint handler method definitions and all 4 deferred-task callers (`schedule_reboot_`, `schedule_delete_data_`, `schedule_reset_satellites_`, `schedule_save_satellites_nvs_`)
- [ ] `firmware/core/registration.h` contains only `register_history_handler`
- [ ] `assemble-firmware-modules.sh --check` exits 0 (assembled output SHA-256 matches committed file)
- [ ] SHA-256 gate passes
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates
- [ ] All Playwright tests pass (full suite)
- [ ] All 68 preflight checks pass
- [ ] `render_sensor_config.py --check` passes after full pipeline run
- [ ] Device test on physical hardware confirms history endpoints, management endpoints, and aggregator endpoints behave identically to pre-Phase-Y baseline

**Risk:** High — largest refactor surface; entire handler class extracted; any missed line or boundary error breaks the assembled artifact  
**Estimated effort:** 1–2 sessions  
**Identity/verification gate:** SHA-256 gate + `assemble-firmware-modules.sh --check` + full Playwright suite + device smoke test

---

### Version Summary

| Version | Step | Risk | Effort |
|---|---|---|---|
| v7.6.6.0 | provision.sh `--auto` flag + full pipeline automation | Low | 1 session |
| v7.6.6.1 | `firmware/core/` directory + `assemble-firmware-modules.sh` scaffold | Low | 0.5 sessions |
| v7.6.6.2 | Extract `config.h` (lines 1–95) | Low | 0.5 sessions |
| v7.6.6.3 | Extract `data-model.h` (lines 96–525, includes generator marker blocks) | High | 1 session |
| v7.6.6.4 | Extract `nvs-persistence.h` (lines 526–1218) | Very High | 1 session |
| v7.6.6.5 | Extract `ping-adapter.h` (lines 1220–1369) | Low | 0.5 sessions |
| v7.6.6.6 | Extract `aggregator-runtime.h` (lines 1388–2272) | High | 1 session |
| v7.6.6.7 | Extract `web-handler.h` + `registration.h` (lines 2279–4325) | High | 1–2 sessions |

---

## 4. Build / Generation / Integration Pipeline Changes

### 4.1 Generator Strategy — Option B (Unchanged Generator)

Under Option B, `render_sensor_config.py` is **not modified**. It continues to:
1. Open `dashboard/sensor_history_multi.h`
2. Find `// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>` and `// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>`
3. Replace marker block contents with generated sensor topology
4. Write the updated file

This works because `sensor_history_multi.h` remains the committed assembled artifact and the generator operates on the committed file, not on the fragment sources. The generator has no knowledge of fragments.

**Pipeline ordering requirement:** The assembler must run **before** the generator in every pipeline execution:

```
assemble-firmware-modules.sh --write   ← must run FIRST (produces sensor_history_multi.h from fragments)
render_sensor_config.py --write        ← writes generator blocks into assembled file
```

If the generator runs before the assembler, the generator's marker-block injection is overwritten by the assembler on the next run. This is the same ordering constraint as `bundle-dashboard.sh → render_sensor_config.py`.

**Consequence for `data-model.h` fragment:** The fragment source file (`firmware/core/data-model.h`) contains the marker block delimiters but **not** the generated content. The generated content lives only in the committed assembled artifact. This is by design — the fragments are source inputs; `sensor_history_multi.h` is the generated output.

### 4.2 Where Generated Blocks Live After Split

| Block | Lives in fragment source | Lives in assembled artifact | Written by |
|---|---|---|---|
| `SENSOR_MANIFEST:HEADER` (lines 375–379) | `firmware/core/data-model.h` (delimiter lines only) | `dashboard/sensor_history_multi.h` (full generated content) | `render_sensor_config.py --write` |
| `SENSOR_MANIFEST:ENTITY` (lines 381–496) | `firmware/core/data-model.h` (delimiter lines only) | `dashboard/sensor_history_multi.h` (full generated content) | `render_sensor_config.py --write` |
| `src/gateway_manifest.h` | Not in any fragment (separate file) | Not applicable | `render_sensor_config.py --write` |
| `src/aggregator_config.h` | Not in any fragment (separate file) | Not applicable | `render_sensor_config.py --write` |

### 4.3 YAML `includes:` — Unchanged

`firmware/esp32-c3-multi-sensor.yaml` `includes:` list remains:

```yaml
includes:
  - ../dashboard/dashboard.h
  - ../dashboard/sensor_history_multi.h
```

No fragment files are added to the YAML `includes:` list under Option B. The ESPHome compiler sees only `sensor_history_multi.h` (the assembled artifact).

### 4.4 Preflight Changes

**Existing 18 checks (all pass unchanged under Option B):**

| Check | preflight.sh line | Under Option B |
|---|---|---|
| `REQUIRED_FILES` includes `sensor_history_multi.h` | 37 | ✓ passes — assembled artifact still present |
| `history_header_version_matches` | 67 | ✓ passes — version string in assembled artifact header |
| `history_handler_has_api_manifest_route` | 68 | ✓ passes — string in assembled artifact |
| `history_handler_has_api_v2_live_route` | 69 | ✓ passes |
| `history_handler_has_api_v2_history_route` | 70 | ✓ passes |
| `history_handler_has_api_ingest_route` | 71 | ✓ passes |
| `gateway_manifest_h_included` | 125 | ✓ passes |
| `gateway_manifest_json_used` | 131 | ✓ passes |
| `firmware_gzip_content_encoding` | 137 | ✓ passes |
| `no_streaming_history_response` | 156 | ✓ passes |
| `nvs_yield_present` (≥3 calls) | 163–168 | ✓ passes — count over assembled file |
| `num_env_sensors_constant_present` | 319 | ✓ passes |
| `num_sensors_aliases_env_sensors` | 321 | ✓ passes |
| `num_sensors_not_aliased_to_num_devices` | 323 | ✓ passes |
| `aggregator_config_h_included` | 328 | ✓ passes |
| `aggregator_route_gateways` | 366 | ✓ passes |
| `aggregator_route_live` | 368 | ✓ passes |
| `aggregator_route_proxy` | 370 | ✓ passes |

**New checks to add (phased in with the relevant step):**

| New check | Added at step | Purpose |
|---|---|---|
| Fragment files in `REQUIRED_FILES` list | v7.6.6.7 (all fragments present) | Ensures `firmware/core/*.h` files are tracked and not accidentally deleted |
| `assemble-firmware-modules.sh --check` passes | v7.6.6.7 | Verifies assembled artifact matches fragment concatenation; primary identity gate |
| Fragment-level ODR guard (no duplicate static definitions) | v7.6.6.7 | Validates no symbol is defined in more than one fragment |

### 4.5 New Assembly Script Specification

**Script:** `scripts/assemble-firmware-modules.sh`

```
Usage: assemble-firmware-modules.sh [--write | --check | --dry-run]

Options:
  --write    Concatenate MODULES in order → OUTPUT file
  --check    Compute SHA-256 of would-be assembly; compare to SHA-256 of OUTPUT;
             exit 0 if identical, exit 1 with diff summary if not
  --dry-run  Print MODULES list and ORDER without writing

Environment:
  MODULES    Ordered array of fragment file paths (relative to repo root)
  OUTPUT     Target assembled file path (dashboard/sensor_history_multi.h)

Behavior:
  - Missing fragment files in --write mode: warn + skip (partial assembly)
  - Missing fragment files in --check mode: skip (check passes for absent fragments)
  - All fragments present in --check mode: full identity verification

Exit codes:
  0: success (write) or identical (check)
  1: identity mismatch (check) or error (write)
```

### 4.6 Updated Full Pipeline Order (after Phase Y complete)

```
[switch]   provision.sh <target>                        ← copies .bak → active configs
[new]      assemble-firmware-modules.sh --write         ← fragments → sensor_history_multi.h
[1]        bundle-dashboard.sh --write                  ← JS modules → dashboard.js
[2]        render_sensor_config.py --write              ← injects HEADER+ENTITY into sensor_history_multi.h
[3]        generate-fixtures.js                         ← regenerates test fixtures
[4]        render_sensor_config.py --write              ← re-inject after fixture gen
[5]        build-dashboard.sh --write                   ← template + JS → dashboard.html
[6]        minify-dashboard.sh                          ← dashboard.html → dashboard.min.html
[7]        generate-header.sh                           ← dashboard.min.html → dashboard.h
[8]        render_sensor_config.py --check              ← final marker sync verification
[verify]   assemble-firmware-modules.sh --check        ← fragments match assembled artifact
```

---

## 5. Migration Safety Rules

The following 12 rules apply to every sub-step within v7.6.6.0–v7.6.6.7. No exception is permitted without explicit documentation.

1. **No behavior changes.** Every step is structural only. No logic modifications, no constant renaming, no argument reordering, no API surface changes. If a change is discovered that would require a behavioral fix, it is deferred to a separate commit.

2. **All Playwright tests pass after each sub-step.** The full test suite must be green before committing. No partial-pass exceptions.

3. **All 68 preflight checks pass after each sub-step.** Including all 18 checks that reference `sensor_history_multi.h`. No preflight check may be disabled or modified to make a step pass (until new checks are explicitly added in v7.6.6.7).

4. **`esphome config` validates after each sub-step.** Run `esphome config firmware/esp32-c3-multi-sensor.yaml` against the CI-safe default config after each step. Compile failure blocks the step.

5. **Endpoint contracts unchanged.** Route paths, HTTP methods, auth requirements, response shapes, status codes, and error JSON formats are identical before and after Phase Y. Verified by Playwright tests and mock server parity.

6. **Persisted-history schema and NVS compatibility unchanged.** `HistoryMeta`, `SegmentSnapshotHeader`, and `SegmentSnapshot` layouts must not change. `NUM_SENSORS`, `NUM_ENV_SENSORS`, and the `seg_%03d` key scheme must be preserved. NVS namespace `histv631` and partition label `history` must be preserved. Violation breaks retained history on deployed devices.

7. **Each step independently revertable.** If a step introduces a regression, reverting its commit(s) must restore the system to the previous passing state with no other changes required.

8. **Phase Y must preserve all endpoint shapes and behaviors.** This includes legacy `/history/{id}/{temp,hum}` endpoints (must 404 for non-environmental devices), `/sensors.json` (environmental-only), all import modes (multi-sensor erase-first, single-sensor merge-first), and the `add-satellite` unauthenticated exception.

9. **Generated artifacts must remain valid.** After every pipeline run, `render_sensor_config.py --check` must exit 0. `assemble-firmware-modules.sh --check` must exit 0 once fragments are present.

10. **Deferred-task patterns must survive the split.** All four deferred-task pairs (`reboot_task_/schedule_reboot_`, `delete_data_task_/schedule_delete_data_`, `reset_satellites_task_/schedule_reset_satellites_`, `save_satellites_nvs_task_/schedule_save_satellites_nvs_`) must be callable from their handlers. Task-handler cross-calls across fragment boundaries are valid because the assembled artifact is a single translation unit.

11. **Mutex/lock scope must survive the split.** `s_cache_mutex`, `AGG_LOCK()`, and `AGG_UNLOCK()` are defined in `aggregator-runtime.h`. Both the aggregator poll task (also in `aggregator-runtime.h`) and the aggregator endpoint handlers (in `web-handler.h`) use them. In the assembled artifact both fragments are present as contiguous text, so the mutex and macros are in scope for all consumers. Assembly order ensures `aggregator-runtime.h` precedes `web-handler.h`.

12. **Scheduler-yield safeguards (`maybe_yield_nvs_scan_`) must survive the split.** The function is defined in `nvs-persistence.h`. It is called in `restore_from_nvs` (also in `nvs-persistence.h`), `build_import_epoch_map_` (in `web-handler.h`), and `handle_history_` (in `web-handler.h`). Under the assembled artifact model, `nvs-persistence.h` precedes `web-handler.h` in assembly order, so the function is in scope for all callers. Preflight check at line 163–168 verifies ≥3 calls are present in the assembled file.

---

## 6. Coding Agent Task Size Analysis

### 6.1 Current Baseline (Monolith)

| Context component | Tokens |
|---|---:|
| `dashboard/sensor_history_multi.h` (full file) | ~27,000 |
| `firmware/esp32-c3-multi-sensor.yaml` (relevant sections) | ~3,000 |
| Relevant lesson files (`firmware.md`, `build-pipeline.md`) | ~5,000 |
| Domain test spec (e.g., `aggregator.spec.js`) | ~4,000 |
| **Typical task total** | **~39,000–47,000** |

This exceeds the practical 30K–40K coding-agent window for any multi-file task.

### 6.2 Token Reduction by Module

| After step | Module to load | Fragment tokens | Total task tokens | Reduction |
|---|---|---:|---:|---:|
| Baseline (v7.6.5.8) | Full monolith | 27,000 | ~47,000 | — |
| v7.6.6.3 (data-model) | `data-model.h` | ~3,500 | ~11,500 | -76% |
| v7.6.6.4 (nvs-persistence) | `nvs-persistence.h` | ~5,500 | ~13,500 | -71% |
| v7.6.6.5 (ping-adapter) | `ping-adapter.h` | ~1,000 | ~9,000 | -81% |
| v7.6.6.6 (aggregator-runtime) | `aggregator-runtime.h` | ~6,500 | ~14,500 | -69% |
| v7.6.6.7 (web-handler) | `web-handler.h` | ~14,500 | ~22,500 | -52% |

**Note:** Even `web-handler.h` alone (the largest fragment) produces a significant reduction because the agent no longer needs to load data model, NVS persistence, PingAdapter, or aggregator runtime code when working on an HTTP handler.

### 6.3 Representative Task Scenarios After Phase Y

| Task | Modules required | Estimated tokens | Fits in 30K window? |
|---|---|---:|---|
| Add new history endpoint | `web-handler.h` + `data-model.h` | ~18,000 | ✓ Yes |
| Tune NVS restore logic | `nvs-persistence.h` + `data-model.h` | ~9,000 | ✓ Yes |
| Modify ping probe interval | `ping-adapter.h` + `data-model.h` | ~4,500 | ✓ Yes |
| Aggregator poll logic fix | `aggregator-runtime.h` + `data-model.h` | ~10,000 | ✓ Yes |
| Phase 7 new NVS helper | `nvs-persistence.h` + `data-model.h` | ~9,000 | ✓ Yes |
| Phase 7 new storage endpoint | `web-handler.h` + `nvs-persistence.h` + `data-model.h` | ~23,000 | ✓ Yes |

**Final state context window:** Every routine task fits under 25K tokens. Phase 7 cross-module tasks fit under 25K. No task requires loading the full 4,325-line monolith.

---

## 7. Rollout Order

### 7.1 Recommended Extraction Order and Rationale

| Order | Module | Why this order |
|---|---|---|
| 1 | `ping-adapter.h` (v7.6.6.5) | Best first-extraction candidate (v2 inventory §9.2, research brief R1): single contiguous class, smallest fan-out, clean `#ifdef` guard. Low risk. Validates the assembly/check pipeline before tackling harder modules. |
| 2 | `config.h` (v7.6.6.2) | Zero-risk extraction of compile-time config. No symbols consumed by anything outside the file. Can be done before or after ping-adapter. |
| 3 | `data-model.h` (v7.6.6.3) | High value: enables all downstream modules to be loaded without the full monolith. Contains generator marker blocks — must be validated carefully with `render_sensor_config.py --check`. |
| 4 | `nvs-persistence.h` (v7.6.6.4) | Highest-risk refactor zone — done after data-model is verified and the assembly pipeline is exercised. Requires device test gate before proceeding. |
| 5 | `aggregator-runtime.h` (v7.6.6.6) | Guarded by `#if AGGREGATOR_ENABLED`. Can be extracted with CI-safe config (`AGGREGATOR_ENABLED 0`) and verified with aggregator config after. |
| 6 | `web-handler.h` + `registration.h` (v7.6.6.7) | Largest and highest-impact. Saved for last so all preceding fragments have been validated. Final SHA-256 gate verifies entire decomposition. |

**The plan orders steps in the versioned sequence v7.6.6.2–v7.6.6.7 for implementation simplicity (one extraction per version). The validation order above reflects which extraction is safest to attempt first.**

### 7.2 Gate Conditions Between Steps

| Gate | Condition required before next step |
|---|---|
| v7.6.6.0 → v7.6.6.1 | `provision.sh --auto` executes all 8 steps successfully in a clean environment |
| v7.6.6.1 → v7.6.6.2 | `assemble-firmware-modules.sh --check` exits 0 (empty-fragment baseline passes) |
| v7.6.6.2 → v7.6.6.3 | SHA-256 gate passes; `config.h` extraction verified by preflight |
| v7.6.6.3 → v7.6.6.4 | SHA-256 gate passes; `render_sensor_config.py --check` passes after full pipeline; generator marker blocks verified in assembled artifact |
| v7.6.6.4 → v7.6.6.5 | SHA-256 gate passes; **device test required** — NVS restore, history retention, hourly persist verified on physical hardware |
| v7.6.6.5 → v7.6.6.6 | SHA-256 gate passes; all Playwright tests pass |
| v7.6.6.6 → v7.6.6.7 | SHA-256 gate passes; aggregator config device test passes |
| v7.6.6.7 → Phase Y complete | SHA-256 gate; `assemble-firmware-modules.sh --check` exits 0; full Playwright suite green; all 68 preflight checks pass; device test confirms all endpoint families |

### 7.3 Device Testing Requirements

| Step | Device test required? | What to verify |
|---|---|---|
| v7.6.6.0–v7.6.6.2 | No — compile-only gate sufficient | `esphome config` validates |
| v7.6.6.3 | Recommended | Generator markers produce correct `devices[]` topology after assembly + render |
| v7.6.6.4 | **Yes — required gate** | NVS restore loads retained history correctly; hourly persist writes valid segment; boot log shows correct slot count |
| v7.6.6.5 | No — PingAdapter is compile-gated | `esphome config` validates; ping metrics function if PING device configured |
| v7.6.6.6 | Recommended with aggregator config | Aggregator poll task starts; satellite list loads from NVS; cache populated |
| v7.6.6.7 | **Yes — required gate** | Full endpoint smoke test: all 21 handler routes, auth, import, satellite management |

---

## 8. Risks and Mitigations

| Risk | Severity | Probability | Mitigation |
|---|---|---|---|
| **NVS schema breakage during file moves** — `SegmentSnapshot` dimensions embed `NUM_SENSORS`; if the struct layout changes or constants shift order, deployed history becomes unreadable | Critical | Low (contiguous-slice extraction preserves layout) | SHA-256 identity gate ensures no code change during extraction; device test at v7.6.6.4 verifies schema compatibility; `HistoryMeta` magic/version guard catches incompatibility at boot |
| **`#include` order violations** — fragments depend on symbols defined earlier in the assembly; if assembly order changes, symbols may be undefined | High | Low (order is fixed in `assemble-firmware-modules.sh`) | Assembly order is encoded as a named `MODULES` array; `--check` mode verifies the order is unchanged; any `#include` order change is blocked by the SHA-256 gate |
| **Generator marker ownership confusion** — after extraction, `data-model.h` contains marker delimiters but not the generated content; developer edits `data-model.h` and loses the generator injection | High | Medium | `assemble-firmware-modules.sh --check` detects divergence; `render_sensor_config.py --check` detects stale markers; `provision.sh --auto` pipeline runs both checks automatically |
| **YAML includes breakage** — accidental modification of `esp32-c3-multi-sensor.yaml` to include fragment files instead of assembled artifact | Medium | Low (YAML unchanged under Option B) | Preflight check verifies `sensor_history_multi.h` in includes list; Option B explicitly leaves YAML untouched |
| **Mutex/lock visibility across split files** — `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` must be in scope for both aggregator poll task and aggregator handlers | High | Low (assembly order ensures runtime precedes handler) | `aggregator-runtime.h` precedes `web-handler.h` in assembly order; SHA-256 gate prevents reordering; Rule 11 (§5) enforces this invariant |
| **Deferred-task function visibility** — `schedule_reboot_`, `schedule_delete_data_`, etc. called from handlers in `web-handler.h` must be visible; defined in `nvs-persistence.h` | High | Low (correct assembly order provides visibility) | Assembly order: nvs-persistence.h precedes web-handler.h; Rule 10 (§5) enforces; SHA-256 gate prevents reordering |
| **Static buffer ownership ambiguity** — `s_fetch_tmp` (aggregator task only) and `s_proxy_tmp` (web-handler context only) must not be called from wrong contexts | Medium | Low (existing comments document constraints) | Existing "MUST be called from web handler context only" comment on `probe_satellite_manifest_` preserved in extracted fragment; no behavioral change — structural split only |
| **Aggregator two-island problem** — top-level runtime block and endpoint handler cluster are in different fragments; if they become separated at compile time, mutual visibility is broken | High | Low (Option B — both islands in assembled artifact) | Under Option B, both fragments are concatenated into a single translation unit; the aggregator island problem only exists under Option C (include-chain). See §D. |
| **`web_server_idf` handler registration changes** — patched local component expects a specific handler registration pattern; refactoring `register_history_handler` could break registration | Medium | Low (registration.h is a minimal wrapper, no logic change) | `register_history_handler` is extracted verbatim (Rule 1 — no behavior changes); patched `web_server_idf` is not modified; local component tests validate |
| **Binary size / compilation changes** — in theory, splitting a monolithic header could affect compiler optimization decisions; in practice, the preprocessor concatenates the assembled file identically | Low | Very Low (Option B produces identical preprocessor output) | SHA-256 identity gate proves preprocessor input is identical; `esphome config` validates YAML parse |

---

## 9. Open Questions

The following 7 open questions from `phase-X-context-for-phase-Y.md` §7 are addressed below.

| # | Question | Resolution |
|---|---|---|
| Q1 | **Identity gate feasibility** — Can we compare compiled `.o` files or firmware binaries? | **Resolved by Option B.** The assembly `--check` (SHA-256 of assembled text) is the primary identity gate — no build environment required. Functional equivalence (Playwright + device test) is the final acceptance gate. Binary comparison is not needed. |
| Q2 | **Generator strategy** — Fragment files or assembled output? | **Resolved: assembled output (Option B).** Generator writes into `dashboard/sensor_history_multi.h` after assembly, exactly as today. No generator modifications. The pipeline order is assembly → generator (same as bundle → generator for dashboard). |
| Q3 | **Include order** — Is `#include` chain sufficient, or do we need an assembly script? | **Resolved: assembly script required.** `assemble-firmware-modules.sh` is the Phase Y equivalent of `bundle-dashboard.sh`. The C++ preprocessor `#include` chain (Option C) is explicitly rejected because it would break all 18 preflight checks that test assembled-file content. |
| Q4 | **Mutex visibility** — Where do `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` live? | **Resolved: in `aggregator-runtime.h`.** Assembly order ensures they are defined before `web-handler.h` is concatenated. Both islands of the aggregator subsystem see the same definitions through the assembled artifact. See §D and §E. |
| Q5 | **Test strategy** — How do we gate each split step without a unit-test framework? | **Resolved: compile-only + SHA-256 + Playwright + device test (at NVS/web-handler steps).** See §7.3 Device Testing Requirements. The SHA-256 gate provides the identity guarantee; Playwright provides functional coverage; device tests at critical steps (v7.6.6.4, v7.6.6.7) verify physical behavior. |
| Q6 | **Local component coordination** — Does the split require changes to handler registration in `begin()`? | **Resolved: no changes required.** `register_history_handler` (in `registration.h`) calls `base->add_handler(handler)` exactly as today. The patched `web_server_idf` receives the handler object via the same call. No changes to the local component. |
| Q7 | **Phase Y before or after Phase 7?** | **Resolved: Phase Y before Phase 7.** Phase Y fragments make the NVS persistence module and data model independently loadable, which reduces Phase 7 task context by 70%+. Doing Phase Y after Phase 7 would require splitting a larger file. The recommendation from Phase X context stands. |

**Remaining open questions (not fully resolved by this plan):**

- **R-Q-A:** The research brief Q4 (mutex location) and Q5 (test strategy) are resolved above, but the specific question of whether `probe_satellite_manifest_` (line 1614) should be documented with a stronger "DO NOT CALL FROM TASK CONTEXT" comment in the extracted fragment remains a style decision for the implementation agent.
- **R-Q-B:** Phase 7 adds `PERSIST_DEVICE_COUNT` and `PERSIST_DEVICE_IDS[]` to the ENTITY block in `data-model.h`. The exact generator changes needed for Phase 7 are out of Phase Y scope but should be tracked as Phase 7 pre-work.

---

## A. Persistence-Schema Safety

Phase Y must not break retained history on deployed devices. The following invariants are guaranteed by the structural-only constraint:

| Invariant | How Phase Y preserves it |
|---|---|
| `SegmentSnapshot` physical layout | Struct definition moves verbatim to `data-model.h`; no field reordering; identity gate prevents any change |
| `HistoryMeta` magic (`0x48535636`) and version (`1`) | Constants move verbatim to `nvs-persistence.h`; identity gate |
| `NUM_SENSORS = NUM_ENV_SENSORS = 3` | Defined in ENTITY block in `data-model.h`; generator continues to emit this value; preflight checks at lines 319–323 enforce it |
| NVS namespace `histv631` and partition label `history` | String literals move verbatim to `nvs-persistence.h`; identity gate |
| Segment key scheme `seg_%03d` | Format string in `make_segment_key_()` moves verbatim; identity gate |
| `restore_from_nvs()` migration/recalibration logic | Moves verbatim to `nvs-persistence.h`; no logic change |
| Import merge-vs-replace mode behavior | Import state in `HistoryWebHandler` private members moves verbatim to `web-handler.h`; no logic change |
| `PERSIST_SLOTS` = `PERSIST_DAYS * 24` | Constant defined in `data-model.h`/`nvs-persistence.h`; identity gate |
| `RAM_SEGMENTS` | Defined near `PERSIST_SLOTS`; identity gate |

**Device upgrade safety:** Devices running firmware built from Phase Y-split sources will have identical NVS schemas to devices running Phase X firmware, because the assembled `sensor_history_multi.h` is SHA-256 identical. No migration is needed.

---

## B. Generated-Block Ownership

**Decision: Generator marker blocks stay in `data-model.h` fragment; generator writes into assembled artifact.**

| Option | Decision |
|---|---|
| Move markers to a dedicated `generated.h` fragment | Rejected — adds complexity for no benefit; markers belong with the type definitions they surround |
| Move markers to a standalone `entity-block.h` | Rejected — same reason |
| Keep markers in `data-model.h` fragment, generator writes assembled artifact | **Selected (Option B)** |
| Split markers across multiple fragments | Rejected — breaks generator's ability to find both markers in one file search |

**Consequence:** `firmware/core/data-model.h` contains the marker delimiter lines with minimal stub content between them. After each `assemble-firmware-modules.sh --write` + `render_sensor_config.py --write` pipeline run, the assembled `dashboard/sensor_history_multi.h` has the full generated content. The fragment source stays minimal.

**Agent editing guidance:** When editing `firmware/core/data-model.h` to add Phase 7 structs, add them **after** the `SENSOR_MANIFEST:ENTITY_END` delimiter and before the end of the file. The generator will continue to overwrite only the content between the `_BEGIN` and `_END` markers.

---

## C. HTTP Route Ownership

### Current Route Inventory (v2 inventory §5 — 22 routes in 3 families)

#### C.1 Local routes (13 routes)

| Route | Method | Auth | Owner in target | Notes |
|---|---|---|---|---|
| `/history/{id}/temp` | GET | No | `web-handler.h` (`handle_history_`) | 404 for non-environmental devices |
| `/history/{id}/hum` | GET | No | `web-handler.h` (`handle_history_`) | Same |
| `/sensors.json` | GET | No | `web-handler.h` (`handle_manifest_`) | Environmental-only projection |
| `/api/manifest` | GET | No | `web-handler.h` (`handle_api_manifest_`) | Served from `GATEWAY_MANIFEST_JSON` |
| `/dashboard` | GET | No | `web-handler.h` (`handle_dashboard_`) | Gzip dashboard payload |
| `/dashboard.html` | GET | No | `web-handler.h` (`handle_dashboard_`) | Same payload |
| `/dashboard-download` | GET | No | `web-handler.h` (`handle_dashboard_`) | Attachment |
| `/favicon.ico` | GET | No | `web-handler.h` | Suppression path |
| `/api/storage-stats` | GET | No | `web-handler.h` (`handle_storage_stats_`) | Partition sizing, retention estimates |
| `/api/status` | GET | No | `web-handler.h` (`handle_status_`) | Heap, uptime, sensor status |
| `/api/v2/live` | GET | No | `web-handler.h` (`handle_api_v2_live_`) | Unified live view |
| `/api/v2/history/{device}/{metric}` | GET | No | `web-handler.h` (`handle_api_v2_history_`) | Current history API |
| `/api/ingest/{device}/{metric}` | POST | No | `web-handler.h` (`handle_api_ingest_`) | External push |

#### C.2 Management routes (8 routes)

| Route | Method | Auth | Owner in target |
|---|---|---|---|
| `/api/import/begin` | POST | Yes | `web-handler.h` (`handle_import_begin_`) |
| `/api/import/begin/single/{sensor_id}` | POST | Yes | `web-handler.h` (`handle_import_begin_`) |
| `/api/import/d/{data}` | POST | Yes | `web-handler.h` (`handle_import_data_`) |
| `/api/import/w/{data}` | POST | Yes | `web-handler.h` (`handle_import_data_`) |
| `/api/import/finish` | POST | Yes | `web-handler.h` (`handle_import_finish_`) |
| `/api/reboot` | POST | Yes | `web-handler.h` (`handle_reboot_`) |
| `/api/delete-data` | POST | Yes | `web-handler.h` (`handle_delete_data_`) |
| `/api/system/reset-satellites` | POST | Yes | `web-handler.h` (`handle_reset_satellites_`) |

#### C.3 Aggregator routes (6 routes)

| Route | Method | Auth | Owner in target |
|---|---|---|---|
| `/api/aggregator/gateways` | GET | No | `web-handler.h` (`handle_aggregator_gateways_`) |
| `/api/aggregator/live` | GET | No | `web-handler.h` (`handle_aggregator_live_`) |
| `/api/aggregator/proxy/{gw}/history/{device}/{metric}` | GET | No | `web-handler.h` (`handle_aggregator_proxy_`) |
| `/api/aggregator/add-satellite` | POST | No | `web-handler.h` (`handle_add_satellite_`) |
| `/api/aggregator/test-satellite` | POST | Yes | `web-handler.h` (`handle_test_satellite_`) |
| `/api/aggregator/satellite/{id}` | DELETE | Yes | `web-handler.h` (`handle_delete_satellite_`) |

#### C.4 `canHandle`/`handleRequest` Dispatch Pattern

After Phase Y, the dispatch pattern is unchanged:
- `canHandle(method, url)` — route classification lives in `web-handler.h`
- `handleRequest(request)` — dispatch table lives in `web-handler.h`
- Both methods are part of the `HistoryWebHandler` class
- The assembled `sensor_history_multi.h` has no compile-time dispatch changes

All 22 routes remain owned by `HistoryWebHandler` in `web-handler.h`. No route moves to another fragment.

---

## D. Aggregator Two-Island Problem

### D.1 Problem Description

The aggregator subsystem is implemented across two non-contiguous regions of the file:
- **Island 1 (runtime block):** lines 1388–2272 — `SatelliteCache`, mutex, buffers, `fetch_to_buffer`, `probe_satellite_manifest_`, NVS satellite persistence, `aggregator_poll_task`, deferred satellite tasks, `start_aggregator_task`
- **Island 2 (endpoint cluster):** lines 3709–4283 — inside `HistoryWebHandler`: `handle_aggregator_gateways_`, `handle_aggregator_live_`, `handle_aggregator_proxy_`, `handle_add_satellite_`, `handle_delete_satellite_`, `handle_test_satellite_`, `handle_reset_satellites_`

### D.2 Why This Is Not a Problem Under Option B

The two islands are extracted into different fragments (`aggregator-runtime.h` and `web-handler.h` respectively), but under Option B they are assembled into a single text output (`sensor_history_multi.h`) before the C++ compiler sees the file. The compiler processes a single translation unit containing both islands in the correct order.

**Shared state visibility chain:**
```
firmware/core/config.h
firmware/core/data-model.h              ← devices[], NUM_DEVICES, ENTITY block
firmware/core/nvs-persistence.h         ← restore_from_nvs, maybe_yield_nvs_scan_
firmware/core/ping-adapter.h            ← PingAdapter
firmware/core/aggregator-runtime.h     ← s_cache_mutex, AGG_LOCK/AGG_UNLOCK,
                                           satellite_caches[], satellite_config_generation,
                                           s_fetch_tmp, s_proxy_tmp, s_proxy_len,
                                           fetch_to_buffer, probe_satellite_manifest_,
                                           start_aggregator_task
firmware/core/web-handler.h            ← HistoryWebHandler (Island 2 sees all Island 1 symbols)
firmware/core/registration.h           ← register_history_handler
```

Every symbol defined in Island 1 (`aggregator-runtime.h`) is visible to Island 2 (`web-handler.h`) because Island 1 appears earlier in the assembly order.

### D.3 Why Option C Would Be Problematic

Under Option C (include-chain), `sensor_history_multi.h` would contain only `#include` directives. Each fragment would be a separately-parsed header with its own include guards. Cross-fragment symbol visibility would require explicit forward declarations or include directives within fragment files. This creates the risk of circular includes and header-guard conflicts. Option B avoids this entirely.

---

## E. Task / Mutex / Deferred-Work Safety

### E.1 Deferred-Task Pair Visibility

All four deferred-task pairs are callable from their respective handlers after Phase Y:

| Task function | Scheduler | Defined in fragment | Called from fragment | Visibility mechanism |
|---|---|---|---|---|
| `reboot_task_` | `schedule_reboot_` | `nvs-persistence.h` | `web-handler.h` (via `handle_reboot_`) | Assembly order: nvs-persistence.h precedes web-handler.h |
| `delete_data_task_` | `schedule_delete_data_` | `nvs-persistence.h` | `web-handler.h` (via `handle_delete_data_`) | Same |
| `reset_satellites_task_` | `schedule_reset_satellites_` | `aggregator-runtime.h` | `web-handler.h` (via `handle_reset_satellites_`) | Assembly order: aggregator-runtime.h precedes web-handler.h |
| `save_satellites_nvs_task_` | `schedule_save_satellites_nvs_` | `aggregator-runtime.h` | `web-handler.h` (via `handle_delete_satellite_`) | Same |

### E.2 Mutex and Lock Visibility

| Symbol | Defined in | Consumers | Visibility |
|---|---|---|---|
| `s_cache_mutex` (line 1479) | `aggregator-runtime.h` | `aggregator_poll_task`, all aggregator handlers | Assembly order guarantees definition precedes use |
| `AGG_LOCK()` macro (line 1487) | `aggregator-runtime.h` | All aggregator lock sites | Same |
| `AGG_UNLOCK()` macro (line 1488) | `aggregator-runtime.h` | All aggregator unlock sites | Same |
| `PingAdapter::sem_` | `ping-adapter.h` (private member) | `PingAdapter::ping_task_` only | Private — no cross-fragment visibility needed |

### E.3 `satellite_config_generation` Shared State

`satellite_config_generation` (line 1466, `static uint32_t`) is defined in `aggregator-runtime.h`. It is read by `aggregator_poll_task` (same fragment) and incremented by `handle_add_satellite_` and `handle_delete_satellite_` (in `web-handler.h`). Assembly order ensures it is defined before `web-handler.h` uses it.

### E.4 `maybe_yield_nvs_scan_()` Visibility

`maybe_yield_nvs_scan_()` (line 801, in `nvs-persistence.h`) is called from:
- `restore_from_nvs()` — same fragment (`nvs-persistence.h`) ✓
- `build_import_epoch_map_()` — `web-handler.h` (import handler private helper) — visible via assembly order ✓
- `handle_history_()` — `web-handler.h` — visible via assembly order ✓

The preflight check at line 163–168 (`nvs_yield_present`) verifies ≥3 calls are present in the assembled file. This check continues to pass because the assembled file contains all three call sites.

---

## F. Test and Guardrail Surface

### F.1 Tests That Guard Phase Y Correctness

| Test file | What it guards | Covers which fragments |
|---|---|---|
| `tests/browser/boot-structure.spec.js` | `/api/manifest` contract, boot response shape | `web-handler.h`, `data-model.h` |
| `tests/browser/history-charts.spec.js` | `/history/{id}/{temp,hum}`, `/api/v2/history/`, history response format | `web-handler.h`, `nvs-persistence.h` |
| `tests/browser/aggregator.spec.js` | `/api/aggregator/*` cache/proxy/gateway contracts | `web-handler.h`, `aggregator-runtime.h` |
| `tests/browser/satellite-management.spec.js` | Add/delete/test/reset satellite routes, NVS roundtrip behavior | `web-handler.h`, `aggregator-runtime.h` |
| `tests/browser/test-helpers.js` | Shared mock server helpers | All fragments via mock server |
| `tests/mock-server/server.js` | Contract-faithful implementation of all 22 routes | All route families |
| `tests/fixtures/generate-fixtures.js` | API shape expectations via fixture | `data-model.h` (manifest), `web-handler.h` (API responses) |

### F.2 Existing Coverage Sufficiency

The current Playwright suite covers the full HTTP API surface (all 22 routes across 3 families). Because Phase Y makes no behavioral changes, the existing test suite is **sufficient** to verify Phase Y correctness for every step.

No new Playwright tests are required for Phase Y. New tests may be added for Phase 7 features, but that is out of Phase Y scope.

### F.3 New Preflight Checks Needed (v7.6.6.7)

| New check | Command pattern | Purpose |
|---|---|---|
| All 7 fragment files exist | `[[ -f firmware/core/config.h ]]` etc. in `REQUIRED_FILES` | Tracks each fragment as a required artifact |
| Assembly check passes | `bash scripts/assemble-firmware-modules.sh --check` | Primary identity gate — fragments concatenate to committed assembled artifact |
| No ODR violations (duplicate static definitions) | `grep -c 'static.*TAG ' firmware/core/*.h` | Ensures no symbol is defined in more than one fragment |

### F.4 esphome compile Gate

`esphome config firmware/esp32-c3-multi-sensor.yaml` validates YAML parse and ESPHome component resolution without requiring the full build toolchain. This is the minimal compile gate available in CI without ESP-IDF. It should run after each step.

Full `esphome compile` (cross-compile firmware binary) is recommended for v7.6.6.4 and v7.6.6.7 device test gates but is not required for CI automation.

---

_End of Phase Y Architecture and Refactor Plan._
