# Phase Y — Sensor History Architecture and Refactor Plan

_Implementation plan for splitting `dashboard/sensor_history_multi.h` into focused firmware modules._
_Date: 2026-04-08_
_Phase: Phase Y — Post-Phase X firmware architecture refactor_
_Version range: `v7.6.6.0`–`v7.6.6.8`_
_Status: Planning — not yet implemented_
_Prerequisite: Phase X complete (`v7.6.5.8` on `main`); all 402 Playwright tests green; all 68 preflight checks pass_
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_

---

## §1. Current State Analysis

### 1.1 The problem

`dashboard/sensor_history_multi.h` is a 4,325-line C++ header that owns ten distinct subsystems. A coding agent assigned any firmware task — even a single-endpoint bug fix — must load the entire file (~30K tokens) plus its surrounding YAML, generator, and guardrail context (~15K tokens more). That 45K-token minimum exceeds the practical context window for coding agents.

The file's responsibility surface at HEAD (`v7.6.5.8`):

| Area | Approximate scope | Token cost (alone) |
|------|------------------|--------------------|
| Compile-time config + base types | 95 lines | ~700 |
| Runtime data model + generated topology | 460 lines | ~3,200 |
| NVS persistence (schema, helpers, restore, persist) | 614 lines | ~4,300 |
| Deferred management tasks | 50 lines | ~350 |
| PingAdapter | 168 lines | ~1,200 |
| Aggregator runtime (cache, poll, NVS, probe, deferred) | 891 lines | ~6,200 |
| HistoryWebHandler class (dispatch, auth, 21 handlers) | 2,006 lines | ~14,000 |
| Registration / boot orchestration | 41 lines | ~290 |
| **Total** | **4,325 lines** | **~30,000** |

### 1.2 Why this gets worse if left unsplit

Phase 7 (per-device persistence, `v7.7.0.x`) will add ~600–800 lines of new NVS structs, hash functions, per-device persist/restore engines, migration logic, and storage-stats handlers — all targeted at `sensor_history_multi.h`. Without a split, the file will exceed 5,000 lines (~35K tokens alone).

Future features (captive portal, cloud sync, factory reset endpoint) add further accumulation pressure. The `HistoryWebHandler` class is the default sink for every new endpoint.

### 1.3 Context cost for a typical firmware task (current)

A coding agent working on, say, a persistence fix currently needs:

| File | Lines | Tokens (est.) |
|------|------:|----------:|
| `dashboard/sensor_history_multi.h` (full) | 4,325 | ~30,000 |
| `firmware/esp32-c3-multi-sensor.yaml` (relevant sections) | ~200 | ~1,400 |
| `scripts/render_sensor_config.py` (marker handling) | ~100 | ~700 |
| `Docs/lessons/firmware.md` (domain constraints) | ~600 | ~4,200 |
| `scripts/preflight.sh` (guardrail awareness) | ~100 | ~700 |
| **Total** | **~5,325** | **~37,000** |

After Phase Y, the same persistence fix would need only `03-nvs-core.h` (614 lines) + `02-data-model.h` (460 lines) + domain lessons — roughly 10K–12K tokens. That is a **3x reduction**.

---

## §2. Proposed Directory Structure

### 2.1 Architecture decision: assembled artifact (Option B)

Phase Y retains `dashboard/sensor_history_multi.h` as a **committed, assembled artifact** — the same pattern Phase X established for `dashboard.js`. Fragment files are the hand-edited sources; a new assembly script concatenates them into the monolith. The generator, YAML `includes:`, and all 18 content-based preflight checks remain unchanged.

**Rationale:**

- Zero generator changes. `render_sensor_config.py` continues writing into `dashboard/sensor_history_multi.h` at its existing `HEADER_PATH`.
- Zero YAML `includes:` changes. The firmware build still sees only `sensor_history_multi.h`.
- All 18 preflight content checks pass without modification (they check the assembled file).
- Matches the Phase X methodology: bundle-first → generate into assembled output → verify.
- Each step is independently revertable: if a fragment extraction fails, restore the monolith from the previous commit.

**Why not Option C (include-chain / `#include` assembly)?**

The C preprocessor would work as an assembler, but it requires forward declarations for cross-fragment symbol references, breaks all 18 content-based preflight checks (they grep the monolith, not fragments), and prevents a clean source-level identity gate. Option C would also require generator changes (markers must live in fragments, not the assembly file).

### 2.2 Fragment directory

Fragments live in `dashboard/firmware_modules/`. The directory name is deliberate: it co-locates fragments with the assembled artifact they produce, follows the `dashboard/src/` → `dashboard/core/` + `dashboard/components/` precedent from Phase X, and avoids creating a new top-level directory until the broader firmware layout question (Issue #140 scope) is resolved.

### 2.3 Before / after directory tree

**Before (current):**

```
dashboard/
  sensor_history_multi.h          ← 4,325-line monolith (hand-maintained + generator)
  dashboard.h                     ← gzip C header (generated)
  core/                           ← dashboard JS modules (Phase X)
  components/                     ← dashboard components (Phase X)
```

**After (Phase Y target state):**

```
dashboard/
  sensor_history_multi.h          ← ASSEMBLED ARTIFACT (committed, marked generated)
  firmware_modules/               ← NEW: hand-maintained fragment sources
    01-config.h                   ← includes, compile-time constants (95 lines)
    02-data-model.h               ← HistEntry, HistoryBuffer, structs, generated blocks (460 lines)
    03-nvs-core.h                 ← NVS model, helpers, restore, persist (614 lines)
    04-deferred-mgmt.h            ← reboot/delete deferred tasks (50 lines)
    05-ping-adapter.h             ← PingAdapter class (168 lines)
    06-aggregator-runtime.h       ← aggregator runtime block (891 lines)
    07-web-handler-core.h         ← class open, route classification, dispatch, helpers (402 lines)
    08-web-handler-local.h        ← core endpoint handlers (1,016 lines)
    09-web-handler-aggregator.h   ← aggregator endpoint handlers + class close (588 lines)
    10-registration.h             ← register_history_handler (41 lines)
  dashboard.h
  core/
  components/
scripts/
  assemble-sensor-history.sh      ← NEW: concatenation assembly with --write and --check modes
```

### 2.4 Fragment manifest (verified against HEAD)

Every fragment is a **contiguous byte-slice** of the current `sensor_history_multi.h`. The assembly script concatenates them in numeric order to reproduce the monolith byte-for-byte.

| Fragment | File | Lines | Range | Size | Primary responsibility |
|----------|------|------:|-------|-----:|----------------------|
| 01 | `01-config.h` | 1–95 | `#pragma once` through last `#define` | 95 | Standard includes, compile-time constants |
| 02 | `02-data-model.h` | 96–555 | `TAG` through sensor count guide | 460 | `HistEntry`, `HistoryBuffer`, `MetricDef`, `MetricState`, `SensorEntity`, generated HEADER + ENTITY blocks |
| 03 | `03-nvs-core.h` | 556–1169 | `HistoryMeta` through `persist_hourly_segment` end | 614 | NVS segment model, all persistence helpers, restore, persist |
| 04 | `04-deferred-mgmt.h` | 1170–1219 | `reboot_task_` through `schedule_delete_data_` end | 50 | Deferred reboot + delete-data task pairs |
| 05 | `05-ping-adapter.h` | 1220–1387 | `#ifdef PING_DEVICE_INDEX` through post-class code | 168 | `PingAdapter` class, ping callbacks, ping task |
| 06 | `06-aggregator-runtime.h` | 1388–2278 | `#if AGGREGATOR_ENABLED` through post-`#endif` blanks | 891 | `SatelliteCache`, mutex, fetch, probe, satellite NVS, poll task, deferred satellite tasks, `start_aggregator_task` |
| 07 | `07-web-handler-core.h` | 2279–2680 | `class HistoryWebHandler` through auth/helper methods | 402 | Class declaration, `canHandle`, `handleRequest` dispatch, auth, Base64, response helpers |
| 08 | `08-web-handler-local.h` | 2681–3696 | `handle_options_` through `handle_history_` end | 1,016 | Dashboard, manifest, v2 live/history, ingest, reboot, delete-data, import, storage-stats, status, legacy history |
| 09 | `09-web-handler-aggregator.h` | 3697–4284 | `#if AGGREGATOR_ENABLED` through class `};` | 588 | Aggregator gateways, live, proxy, add/delete/test/reset satellite handlers, class close |
| 10 | `10-registration.h` | 4285–4325 | Comment block through end of file | 41 | `register_history_handler()`, boot orchestration |

**Verification sum:** 95 + 460 + 614 + 50 + 168 + 891 + 402 + 1,016 + 588 + 41 = **4,325** ✓

### 2.5 Module boundary justification

Every boundary aligns with the v2 inventory §9 contiguous/scattered analysis and the deep research brief §R1 verified line ranges:

| Boundary | Justification |
|----------|--------------|
| 01↔02 at line 96 | `TAG` definition starts the runtime symbol space; everything before is pure preprocessor/includes |
| 02↔03 at line 556 | `HistoryMeta` struct begins the NVS persistence model; everything before is runtime data model |
| 03↔04 at line 1170 | `reboot_task_` is the first deferred-task function; everything before is persistence core |
| 04↔05 at line 1220 | `#ifdef PING_DEVICE_INDEX` opens the PingAdapter guard; clean compile-guard boundary |
| 05↔06 at line 1388 | `#if AGGREGATOR_ENABLED` opens the aggregator block; clean compile-guard boundary |
| 06↔07 at line 2279 | `class HistoryWebHandler` opens the handler class; everything before is top-level functions |
| 07↔08 at line 2681 | `handle_options_` is the first actual endpoint handler method; everything before is dispatch/helpers |
| 08↔09 at line 3697 | `#if AGGREGATOR_ENABLED` opens the aggregator endpoint cluster; clean compile-guard boundary |
| 09↔10 at line 4285 | Class `};` closes at 4283; 4285 starts the standalone registration function |

---

## §3. Versioned Steps

### v7.6.6.0 — Pre-step: `provision.sh` full pipeline automation

**Scope:** Automate the entire 8-step regeneration pipeline in `provision.sh` so operators no longer run 7 manual steps after every board switch. Add `--dry-run` support for previewing what would execute.

**Current state:** `provision.sh <target>` runs only `render_sensor_config.py --write` (step 0), then prints the remaining 8 steps as text for manual execution. This is error-prone during iterative firmware testing.

**Files modified:**

| File | Change |
|------|--------|
| `scripts/provision.sh` | Add `run_full_pipeline()` function; add `--dry-run` flag; add node/npm dependency checks; auto-run all 8 steps after board switch |
| `Docs/changelog.md` | v7.6.6.0 entry |
| `Docs/lessons/operations.md` | Document full-pipeline automation |
| `VERSION` | Bump to `7.6.6.0` |

**Implementation details:**

```bash
run_full_pipeline() {
  local dry_run="${1:-false}"
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
  for step in "${steps[@]}"; do
    if [[ "$dry_run" == "true" ]]; then
      echo "  [DRY-RUN] $step"
    else
      echo "  Running: $step"
      eval "$step" || { echo "ERROR: Pipeline failed at: $step" >&2; exit 1; }
    fi
  done
}
```

Pre-checks before pipeline execution:
- `require_node()` — verifies `node` is in PATH
- `require_npm_deps()` — verifies `node_modules` directory exists (for `html-minifier-terser`)
- If dependencies are missing, print install instructions and exit with a clear error

**Acceptance criteria:**

- [ ] `bash scripts/provision.sh aggregator` runs all 8 pipeline steps automatically
- [ ] `bash scripts/provision.sh satellite` runs all 8 pipeline steps automatically
- [ ] `bash scripts/provision.sh aggregator --dry-run` prints all steps without executing
- [ ] Missing `node` produces a clear error with install instructions
- [ ] Missing npm dependencies produce a clear error with `npm install` instructions
- [ ] Pipeline failure at any step halts execution and reports which step failed
- [ ] `render_sensor_config.py --check` passes at the end of automated pipeline
- [ ] Existing `provision.sh status` command unchanged
- [ ] All Playwright tests pass
- [ ] Preflight passes
- [ ] Version is `7.6.6.0` everywhere

**Risk rating:** Low
**Estimated effort:** 1 session
**Verification gate:** Preflight passes; `provision.sh satellite` + `provision.sh aggregator` round-trip succeeds; `render_sensor_config.py --check` passes after each

---

### v7.6.6.1 — Level 1: Create assembly infrastructure and extract first fragments

**Scope:** Create the `dashboard/firmware_modules/` directory, the assembly script (`scripts/assemble-sensor-history.sh`), and extract the first four low-risk contiguous fragments (01-config, 04-deferred-mgmt, 05-ping-adapter, 10-registration). These are the smallest, most self-contained slices.

**Files created:**

| File | Content |
|------|---------|
| `scripts/assemble-sensor-history.sh` | Assembly script with `--write`, `--check`, and `--list` modes |
| `dashboard/firmware_modules/01-config.h` | Lines 1–95 of `sensor_history_multi.h` |
| `dashboard/firmware_modules/04-deferred-mgmt.h` | Lines 1170–1219 |
| `dashboard/firmware_modules/05-ping-adapter.h` | Lines 1220–1387 |
| `dashboard/firmware_modules/10-registration.h` | Lines 4285–4325 |

**Files modified:**

| File | Change |
|------|--------|
| `scripts/preflight.sh` | Add `sensor_history_assembly_check` — runs `assemble-sensor-history.sh --check` |
| `scripts/preflight.sh` | Add `firmware_module_files_exist` — verify all expected fragment files exist |
| `Docs/changelog.md` | v7.6.6.1 entry |
| `VERSION` | Bump to `7.6.6.1` |

**Assembly script design:**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULES_DIR="$ROOT/dashboard/firmware_modules"
OUTPUT="$ROOT/dashboard/sensor_history_multi.h"

# Ordered fragment manifest — MUST match numeric prefix order
FRAGMENTS=(
  "01-config.h"
  "02-data-model.h"
  "03-nvs-core.h"
  "04-deferred-mgmt.h"
  "05-ping-adapter.h"
  "06-aggregator-runtime.h"
  "07-web-handler-core.h"
  "08-web-handler-local.h"
  "09-web-handler-aggregator.h"
  "10-registration.h"
)

case "${1:-}" in
  --write)
    # Concatenate fragments into assembled output
    cat "${FRAGMENTS[@]/#/$MODULES_DIR/}" > "$OUTPUT"
    echo "Assembled ${#FRAGMENTS[@]} fragments → $OUTPUT ($(wc -l < "$OUTPUT") lines)"
    ;;
  --check)
    # Verify assembled output matches fragments
    ASSEMBLED=$(cat "${FRAGMENTS[@]/#/$MODULES_DIR/}" | sha256sum | cut -d' ' -f1)
    COMMITTED=$(sha256sum "$OUTPUT" | cut -d' ' -f1)
    if [[ "$ASSEMBLED" == "$COMMITTED" ]]; then
      echo "Assembly check PASSED (SHA-256: ${ASSEMBLED:0:16}...)"
    else
      echo "Assembly check FAILED" >&2
      echo "  Fragments SHA-256: $ASSEMBLED" >&2
      echo "  Committed SHA-256: $COMMITTED" >&2
      exit 1
    fi
    ;;
  --list)
    for f in "${FRAGMENTS[@]}"; do
      echo "  $MODULES_DIR/$f ($(wc -l < "$MODULES_DIR/$f") lines)"
    done
    ;;
  *)
    echo "Usage: $0 [--write|--check|--list]"
    exit 1
    ;;
esac
```

**Identity gate:** At this step, only 4 of 10 fragments exist as files. The remaining 6 lines (fragments 02, 03, 06, 07, 08, 09) remain as "residual" content inside the monolith that the assembly script has not yet extracted. The assembly script uses a temporary strategy: fragments that have been extracted are read from `firmware_modules/`; lines not yet extracted are read from the monolith as a single "remainder" block. After all 10 fragments are extracted, the assembly becomes a pure concatenation.

**Alternative (simpler):** Extract all 10 fragments at once in this step, making the identity gate a straightforward SHA-256 comparison from the start. The downside is a larger blast radius per step. This plan splits extractions across steps to keep each PR small and reviewable.

**Extraction procedure for each fragment:**

1. `head -n {end} sensor_history_multi.h | tail -n +{start} > firmware_modules/{fragment}.h`
2. Verify: `diff <(cat firmware_modules/01-config.h) <(head -95 sensor_history_multi.h)` — must be empty
3. After all 4 fragments extracted: `assemble-sensor-history.sh --check` must pass

**Acceptance criteria:**

- [ ] `dashboard/firmware_modules/` directory exists with 4 fragment files
- [ ] `assemble-sensor-history.sh --check` passes (SHA-256 identity)
- [ ] `assemble-sensor-history.sh --write` reproduces `sensor_history_multi.h` byte-for-byte
- [ ] `render_sensor_config.py --check` passes
- [ ] New preflight checks pass: `sensor_history_assembly_check`, `firmware_module_files_exist`
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates
- [ ] All Playwright tests pass
- [ ] Preflight passes (all checks)
- [ ] Version is `7.6.6.1` everywhere

**Risk rating:** Low — no behavioral change; monolith content is unchanged
**Estimated effort:** 1 session
**Verification gate:** Assembly `--check` passes; preflight passes; `esphome config` validates

---

### v7.6.6.2 — Level 1: Extract data model and NVS core fragments

**Scope:** Extract fragments 02 (data-model) and 03 (nvs-core) — the two largest non-handler modules. These contain the generated topology blocks and the persistence engine.

**Files created:**

| File | Content |
|------|---------|
| `dashboard/firmware_modules/02-data-model.h` | Lines 96–555 of `sensor_history_multi.h` |
| `dashboard/firmware_modules/03-nvs-core.h` | Lines 556–1169 |

**Files modified:**

| File | Change |
|------|--------|
| `Docs/changelog.md` | v7.6.6.2 entry |
| `VERSION` | Bump to `7.6.6.2` |

**Generator impact:** None. The generator's `HEADER_PATH` still points to `dashboard/sensor_history_multi.h`. After extraction, the HEADER and ENTITY marker blocks live in `02-data-model.h`. The generator writes into the assembled file; the assembly script overwrites the assembled file from fragments. The canonical pipeline order is:

```
assemble-sensor-history.sh --write → bundle-dashboard.sh --write →
render_sensor_config.py --write → ... → render_sensor_config.py --check
```

After the generator writes markers into the assembled file, the assembly `--check` will **fail** (because the assembled file now differs from the fragments). This is expected. The operator must then **reverse-sync** the generator's changes back into the fragment:

```bash
head -555 dashboard/sensor_history_multi.h | tail -n +96 > dashboard/firmware_modules/02-data-model.h
```

This reverse-sync is the same pattern as Phase X: `bundle-dashboard.sh` assembled `dashboard.js` from modules, then the generator wrote into `dashboard.js`, and the operator had to accept that `dashboard.js` was the authoritative version post-generation. For Phase Y, the authoritative source is the **assembled file after generation**, and fragments must be re-extracted from it.

**Critical rule:** After running the full pipeline (which includes `render_sensor_config.py --write`), always re-extract the data-model fragment from the assembled file before committing. The pipeline order becomes:

```
assemble-sensor-history.sh --write → [full pipeline] →
re-extract 02-data-model.h from assembled file →
assemble-sensor-history.sh --check (must pass)
```

**Acceptance criteria:**

- [ ] `dashboard/firmware_modules/02-data-model.h` exists (460 lines)
- [ ] `dashboard/firmware_modules/03-nvs-core.h` exists (614 lines)
- [ ] `assemble-sensor-history.sh --check` passes
- [ ] `render_sensor_config.py --check` passes
- [ ] `esphome config` validates
- [ ] All Playwright tests pass
- [ ] Preflight passes
- [ ] Version is `7.6.6.2` everywhere

**Risk rating:** Medium — the generator/fragment reverse-sync pattern is new and requires operator discipline
**Estimated effort:** 1 session
**Verification gate:** Assembly `--check` passes; `render_sensor_config.py --check` passes

---

### v7.6.6.3 — Level 1: Extract aggregator runtime fragment

**Scope:** Extract fragment 06 (aggregator-runtime) — the largest single subsystem block (891 lines). This is the aggregator runtime's "first island."

**Files created:**

| File | Content |
|------|---------|
| `dashboard/firmware_modules/06-aggregator-runtime.h` | Lines 1388–2278 |

**Files modified:**

| File | Change |
|------|--------|
| `Docs/changelog.md` | v7.6.6.3 entry |
| `VERSION` | Bump to `7.6.6.3` |

**Acceptance criteria:**

- [ ] `dashboard/firmware_modules/06-aggregator-runtime.h` exists (891 lines)
- [ ] `assemble-sensor-history.sh --check` passes
- [ ] `esphome config` validates
- [ ] All Playwright tests pass
- [ ] Preflight passes
- [ ] Version is `7.6.6.3` everywhere

**Risk rating:** Low — contiguous extraction, no behavioral change
**Estimated effort:** 1 session
**Verification gate:** Assembly `--check` passes

---

### v7.6.6.4 — Level 2: Extract HistoryWebHandler fragments (core + local + aggregator)

**Scope:** Extract fragments 07, 08, and 09 — the three sub-slices of the `HistoryWebHandler` class. This is the largest extraction step but the fragments are contiguous slices within the class body.

**Files created:**

| File | Content |
|------|---------|
| `dashboard/firmware_modules/07-web-handler-core.h` | Lines 2279–2680 |
| `dashboard/firmware_modules/08-web-handler-local.h` | Lines 2681–3696 |
| `dashboard/firmware_modules/09-web-handler-aggregator.h` | Lines 3697–4284 |

**Files modified:**

| File | Change |
|------|--------|
| `Docs/changelog.md` | v7.6.6.4 entry |
| `VERSION` | Bump to `7.6.6.4` |

**Note on class continuity:** Fragments 07–09 together form a single C++ class body. Fragment 07 opens the class (`class HistoryWebHandler : public AsyncWebHandler {`); fragment 09 closes it (`};`). None of these fragments is independently compilable. They are valid only when concatenated in order — which is exactly how the assembly script produces `sensor_history_multi.h`.

**Acceptance criteria:**

- [ ] All three web-handler fragments exist with correct line counts
- [ ] `assemble-sensor-history.sh --check` passes (all 10 fragments now extracted)
- [ ] `esphome config` validates
- [ ] All Playwright tests pass
- [ ] Preflight passes
- [ ] Version is `7.6.6.4` everywhere

**Risk rating:** Medium — class-spanning fragments are syntactically unusual; careful boundary verification needed
**Estimated effort:** 1 session
**Verification gate:** Assembly `--check` passes; all 10 fragments produce the monolith byte-for-byte

---

### v7.6.6.5 — Level 2: Pipeline integration and CI wiring

**Scope:** Integrate the assembly script into the canonical pipeline and CI workflow. Add the assembly step to `provision.sh`. Update `bump-version.sh` to handle fragment-based version bumping.

**Files modified:**

| File | Change |
|------|--------|
| `scripts/provision.sh` | Insert `assemble-sensor-history.sh --write` as first pipeline step (before `bundle-dashboard.sh`) |
| `scripts/bump-version.sh` | Add version bump in `01-config.h` (header comment) and reverse-sync after render |
| `.github/workflows/browser-tests.yml` | Add `assemble-sensor-history.sh --check` to CI checks |
| `scripts/preflight.sh` | Add `sensor_history_fragment_count` check (verify exactly 10 fragments sum to 4,325 lines) |
| `Docs/changelog.md` | v7.6.6.5 entry |
| `Docs/lessons/build-pipeline.md` | Document assembly step and pipeline position |
| `VERSION` | Bump to `7.6.6.5` |

**Updated canonical pipeline (Critical Rule 37 expansion):**

```
[0] assemble-sensor-history.sh --write     ← NEW
[1] bundle-dashboard.sh --write
[2] render_sensor_config.py --write
[3] generate-fixtures.js
[4] render_sensor_config.py --write
[5] build-dashboard.sh --write
[6] minify-dashboard.sh
[7] generate-header.sh
[8] render_sensor_config.py --check
[9] assemble-sensor-history.sh --check     ← NEW (verify round-trip)
```

Step 9 verifies that the generator's marker-block writes (step 2/4) did not drift the assembled file from its fragment sources. If it fails, the operator must reverse-sync the data-model fragment.

**Acceptance criteria:**

- [ ] `provision.sh aggregator` runs assembly step before bundle step
- [ ] `provision.sh satellite` runs assembly step before bundle step
- [ ] CI runs `assemble-sensor-history.sh --check`
- [ ] `bump-version.sh` updates version in `01-config.h` header comment
- [ ] Full pipeline round-trip: assemble → pipeline → re-extract → assembly check passes
- [ ] All Playwright tests pass
- [ ] Preflight passes (including new fragment count check)
- [ ] Version is `7.6.6.5` everywhere

**Risk rating:** Medium — pipeline ordering is sensitive; incorrect order causes cascading failures
**Estimated effort:** 1–2 sessions
**Verification gate:** CI green; `provision.sh satellite` + `provision.sh aggregator` round-trip succeeds

---

### v7.6.6.6 — Level 3: Mark assembled artifact as generated, update documentation

**Scope:** Add `GENERATED` header comment to assembled `sensor_history_multi.h`. Update `README.md` with firmware module architecture section. Update all prompt/handoff/workflow documentation to reference fragments as the editing targets.

**Files modified:**

| File | Change |
|------|--------|
| `scripts/assemble-sensor-history.sh` | Insert `// GENERATED — Do not edit directly. Source: dashboard/firmware_modules/*.h` header into assembled output |
| `README.md` | Add "Firmware Module Architecture" section |
| `prompts/prompt-index-and-workflow.md` | Add Critical Rules 58–60 for firmware module discipline |
| `Docs/lessons/firmware.md` | Document Phase Y lessons |
| `Docs/writing-guide/checklists/firmware.md` | Create firmware-domain checklist if not present; add module-scoped prompt patterns |
| `Docs/changelog.md` | v7.6.6.6 entry |
| `VERSION` | Bump to `7.6.6.6` |

**New Critical Rules:**

| # | Rule | Source |
|---|------|--------|
| 58 | Fragment sources live in `dashboard/firmware_modules/`. `sensor_history_multi.h` is generated — never edit directly. | Phase Y v7.6.6.6 |
| 59 | After any fragment edit, run the full pipeline starting with `assemble-sensor-history.sh --write`. After `render_sensor_config.py --write`, reverse-sync `02-data-model.h` from the assembled file. | Phase Y v7.6.6.5 |
| 60 | `assemble-sensor-history.sh --check` must pass before every commit that touches firmware modules or generated artifacts. | Phase Y v7.6.6.5 |

**Acceptance criteria:**

- [ ] Assembled `sensor_history_multi.h` starts with `// GENERATED` header
- [ ] README documents firmware module architecture
- [ ] Critical Rules 58–60 in prompt index
- [ ] Firmware lessons updated
- [ ] All Playwright tests pass
- [ ] Preflight passes
- [ ] Version is `7.6.6.6` everywhere

**Risk rating:** Low — documentation only
**Estimated effort:** 1 session
**Verification gate:** Preflight passes; assembly `--check` passes

---

### v7.6.6.7 — Level 3: Device testing and compilation verification

**Scope:** Compile the firmware for all three board profiles (C3 SuperMini, WROOM satellite, S3 aggregator), flash each device, and verify operational behavior. This step produces no code changes — it is the functional equivalence gate.

**Testing matrix:**

| Board | Role | IP | Test |
|-------|------|----|------|
| ESP32-C3 SuperMini | Satellite (CI-safe) | 192.168.120.189 | `esphome run` + serial log verification + dashboard load |
| WROOM-32D | Satellite | 192.168.120.190 | `esphome run` + serial log verification + dashboard load |
| ESP32-S3-DevKitC1 | Aggregator | 192.168.120.191 | `esphome run` + serial log + aggregator polling + satellite management |

**Per-device verification checklist:**

- [ ] `esphome config {board-yaml}` validates without warnings
- [ ] `esphome compile {board-yaml}` succeeds
- [ ] Flash succeeds via serial
- [ ] Serial log shows `handler registered` with correct device count
- [ ] Dashboard loads at `http://{ip}/dashboard`
- [ ] `/api/manifest` returns valid JSON
- [ ] `/api/v2/live` returns sensor data
- [ ] `/api/status` returns version `7.6.6.7`
- [ ] History charts populate within 15 minutes
- [ ] (Aggregator only) `/api/aggregator/gateways` returns satellite list
- [ ] (Aggregator only) Satellite management operations work (add/test/delete)

**Files modified:**

| File | Change |
|------|--------|
| `Docs/changelog.md` | v7.6.6.7 entry with device testing results |
| `VERSION` | Bump to `7.6.6.7` |

**Risk rating:** Medium — first time the split firmware runs on real hardware
**Estimated effort:** 1–2 sessions
**Verification gate:** All 3 devices boot, serve dashboard, and pass behavioral checks

---

### v7.6.6.8 — Phase Y closure

**Scope:** Final Playwright regression across all four fixture sets. Produce Phase Y results document. Tag the release. Update prompt index.

**Files modified:**

| File | Change |
|------|--------|
| `prompts/handoff/phaseY-results.md` | Phase Y delivery summary |
| `prompts/prompt-index-and-workflow.md` | Mark all Phase Y steps complete |
| `Docs/changelog.md` | v7.6.6.8 entry with Phase Y Complete callout |
| `VERSION` | Bump to `7.6.6.8` |

**Acceptance criteria:**

- [ ] Full Playwright suite: 3sensor (99+ passed), mixed (7+), system (8+), aggregator (11+)
- [ ] Preflight passes (all checks including new assembly/fragment checks)
- [ ] `assemble-sensor-history.sh --check` passes
- [ ] `render_sensor_config.py --check` passes
- [ ] Git tag `v7.6.6.8` created
- [ ] Phase Y results document produced
- [ ] All Phase Y steps marked complete in prompt index
- [ ] Version is `7.6.6.8` everywhere

**Risk rating:** Low — closure and documentation
**Estimated effort:** 1 session
**Verification gate:** All tests green; all preflight checks pass; tag created

---

## §4. Build / Generation / Integration Pipeline Changes

### 4.1 Assembly script introduction (v7.6.6.1)

New script `scripts/assemble-sensor-history.sh` concatenates fragments into `dashboard/sensor_history_multi.h`. Modes: `--write` (produce), `--check` (verify SHA-256), `--list` (show manifest).

### 4.2 Pipeline position (v7.6.6.5)

The assembly step runs **first** in the canonical pipeline, before `bundle-dashboard.sh`. The final step is an assembly `--check` to verify round-trip integrity after generation.

| Step | Command | When added |
|------|---------|-----------|
| 0 | `assemble-sensor-history.sh --write` | v7.6.6.5 |
| 1 | `bundle-dashboard.sh --write` | Phase X |
| 2 | `render_sensor_config.py --write` | Phase X |
| 3 | `generate-fixtures.js` | Phase X |
| 4 | `render_sensor_config.py --write` | Phase X |
| 5 | `build-dashboard.sh --write` | Phase X |
| 6 | `minify-dashboard.sh` | Phase X |
| 7 | `generate-header.sh` | Phase X |
| 8 | `render_sensor_config.py --check` | Phase X |
| 9 | `assemble-sensor-history.sh --check` | v7.6.6.5 |

### 4.3 Generator interaction

`render_sensor_config.py` requires **zero changes**. It continues to:
- Read/write `HEADER_PATH = ROOT / "dashboard" / "sensor_history_multi.h"`
- Replace `SENSOR_MANIFEST:HEADER_BEGIN/END` markers (lines 375–379 in assembled file)
- Replace `SENSOR_MANIFEST:ENTITY_BEGIN/END` markers (lines 381–496 in assembled file)

After the generator writes, the assembled file's `02-data-model.h` region has been updated. The operator must reverse-sync this region back to the fragment file before the final assembly `--check` passes.

### 4.4 YAML `includes:` — no changes

The YAML continues to reference only `../dashboard/sensor_history_multi.h` (the assembled artifact). Fragment files are never directly included by the YAML. This is the key advantage of the assembled-artifact approach.

### 4.5 `provision.sh` changes

| Version | Change |
|---------|--------|
| v7.6.6.0 | Full pipeline automation (8 steps) |
| v7.6.6.5 | Add assembly step at pipeline start + assembly check at pipeline end |

### 4.6 Local `web_server_idf` override

No changes required. The local component at `firmware/local_components/web_server_idf/` is unaffected by the header split — it operates at the httpd layer, which is below the handler-registration layer.

### 4.7 Preflight changes

| Version | New check | Purpose |
|---------|-----------|---------|
| v7.6.6.1 | `sensor_history_assembly_check` | Run `assemble-sensor-history.sh --check` |
| v7.6.6.1 | `firmware_module_files_exist` | Verify all expected fragment files exist |
| v7.6.6.5 | `sensor_history_fragment_count` | Verify exactly 10 fragments, sum to expected line count |

---

## §5. Migration Safety Rules

Every Phase Y step must satisfy all of the following:

| # | Rule | Verification |
|---|------|-------------|
| 1 | No behavior changes — structural reorganization only | Assembly identity gate; no new logic in any fragment |
| 2 | All existing Playwright tests pass after each step | Full test suite run per step (4 fixture sets) |
| 3 | All existing preflight checks pass after each step | `bash scripts/preflight.sh` |
| 4 | `esphome config` / compile must remain valid | `esphome config firmware/esp32-c3-multi-sensor.yaml` per step |
| 5 | Endpoint contracts unchanged (paths, methods, auth, payload shape) | Playwright tests + mock server parity |
| 6 | Persisted-history schema and NVS compatibility unchanged | No struct layout or NVS key changes; `HistoryMeta`/`SegmentSnapshot` byte-identical |
| 7 | Each step independently revertable | Git revert of one PR restores the previous state |
| 8 | Phase Y preserves all endpoint shapes assumed by post-Phase X dashboard, tests, and build guardrails | Preflight route checks + Playwright route coverage |
| 9 | Generated artifacts remain valid after each step | `render_sensor_config.py --check` passes |
| 10 | Deferred-task patterns survive the split | All 4 task/scheduler pairs remain callable from their trigger context (httpd task for schedulers, FreeRTOS task for executors) |
| 11 | Mutex/lock scope survives the split | `s_cache_mutex`, `AGG_LOCK`/`AGG_UNLOCK` visible in all fragments that access `satellite_caches[]` (06, 09) |
| 12 | Scheduler-yield safeguards survive the split | `maybe_yield_nvs_scan_()` defined in 03, called from 03 (restore/persist) and 08 (import handlers) — visible via include order |

---

## §6. Coding Agent Task Size Analysis

### 6.1 Current baseline

| Task type | Files needed | Lines | Tokens (est.) |
|-----------|-------------|------:|----------:|
| Persistence bug fix | `sensor_history_multi.h` (full) + YAML + lessons | ~5,300 | ~37,000 |
| New API endpoint | Same | ~5,300 | ~37,000 |
| Aggregator feature | Same | ~5,300 | ~37,000 |
| Import engine fix | Same | ~5,300 | ~37,000 |

### 6.2 After Phase Y (v7.6.6.8)

| Task type | Fragments needed | Lines | Tokens (est.) | Reduction |
|-----------|-----------------|------:|----------:|--------:|
| Persistence bug fix | 02 + 03 + lessons | ~1,674 | ~12,000 | 3.1x |
| New API endpoint (local) | 02 + 07 + 08 + lessons | ~2,078 | ~14,500 | 2.6x |
| Aggregator feature | 02 + 06 + 09 + lessons | ~1,939 | ~13,600 | 2.7x |
| Import engine fix | 02 + 03 + 08 + lessons | ~2,090 | ~14,600 | 2.5x |
| PingAdapter change | 02 + 05 + lessons | ~1,228 | ~8,600 | 4.3x |
| Status/storage endpoint | 02 + 08 + lessons | ~2,076 | ~14,500 | 2.6x |

**Average improvement: 3x context reduction.** The largest remaining module (08 at 1,016 lines) can be further split in a future phase if needed.

### 6.3 Phase 7 impact

With the split in place, Phase 7 per-device persistence work targets primarily `02-data-model.h` (new structs) and `03-nvs-core.h` (new persist/restore engines). The agent needs ~1,674 lines instead of ~5,000+ lines of a post-Phase-7 monolith.

---

## §7. Rollout Order

### 7.1 Sequencing rationale

| Order | Version | What | Why this order |
|-------|---------|------|----------------|
| 1st | v7.6.6.0 | Pipeline automation | Reduces error risk for all subsequent steps |
| 2nd | v7.6.6.1 | Infrastructure + first 4 fragments | Establishes assembly script and identity gate; extracts smallest, lowest-risk slices |
| 3rd | v7.6.6.2 | Data model + NVS core | Extracts the generator-coupled and persistence-critical modules early to expose any generator-sync issues |
| 4th | v7.6.6.3 | Aggregator runtime | Extracts the largest standalone subsystem |
| 5th | v7.6.6.4 | Web handler fragments | Extracts the remaining class body — the highest cross-coupling risk |
| 6th | v7.6.6.5 | Pipeline + CI wiring | Integrates assembly into CI now that all fragments exist |
| 7th | v7.6.6.6 | Documentation | Only after the split is stable |
| 8th | v7.6.6.7 | Device testing | Hardware verification of the complete split |
| 9th | v7.6.6.8 | Closure | Tag and release |

### 7.2 Gate conditions between levels

| Gate | Condition |
|------|-----------|
| v7.6.6.0 → v7.6.6.1 | Pipeline automation merged; provision.sh round-trip confirmed |
| v7.6.6.1 → v7.6.6.2 | Assembly script operational; first 4 fragments pass identity gate |
| v7.6.6.2 → v7.6.6.3 | Generator reverse-sync pattern proven (02-data-model survives render cycle) |
| v7.6.6.3 → v7.6.6.4 | All non-handler fragments extracted; `esphome config` validates |
| v7.6.6.4 → v7.6.6.5 | All 10 fragments extracted; full assembly identity gate passes |
| v7.6.6.5 → v7.6.6.6 | CI green with assembly checks; pipeline round-trip confirmed |
| v7.6.6.6 → v7.6.6.7 | Documentation complete; all CI gates green |
| v7.6.6.7 → v7.6.6.8 | All 3 devices tested and operational; Playwright full regression green |

### 7.3 Device testing requirements

| Step | Device testing required? | Rationale |
|------|------------------------|-----------|
| v7.6.6.0 | No | Pipeline tooling only |
| v7.6.6.1–v7.6.6.4 | No — compile gate suffices | Identity gate guarantees code-identical output; `esphome config` validates |
| v7.6.6.5 | No — CI gate suffices | Pipeline integration, no code change |
| v7.6.6.6 | No | Documentation only |
| v7.6.6.7 | **YES — mandatory** | First compilation and execution of split firmware on hardware |
| v7.6.6.8 | No | Closure only |

---

## §8. Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|-----------|
| R1 | Fragment boundary off-by-one breaks identity gate | Medium | Low | Assembly `--check` catches immediately; verified line ranges from deep research brief |
| R2 | Generator marker-block drift after reverse-sync | Medium | Medium | Pipeline ends with `assemble-sensor-history.sh --check`; any drift blocks commit |
| R3 | `#include` order violation after future refactoring | Low | High | Fragments are concatenated, not compiled independently; include order is the fragment manifest |
| R4 | Mutex/lock visibility across fragments | Low | High | `s_cache_mutex` defined in 06-aggregator-runtime.h; consumed in 09-web-handler-aggregator.h; visible via assembly concatenation order |
| R5 | Deferred-task function visibility across fragments | Low | High | Task functions in 04/06; schedulers called from handlers in 08/09; visible via concatenation order |
| R6 | Generator writes to wrong position after file move | Very Low | High | Generator path `HEADER_PATH` unchanged — still `dashboard/sensor_history_multi.h` |
| R7 | YAML `includes:` breaks | Very Low | Critical | YAML unchanged — still references only `sensor_history_multi.h` |
| R8 | NVS schema breakage | Very Low | Critical | No struct layout changes; identity gate guarantees byte-identical compiled types |
| R9 | Aggregator two-island shared state becomes invisible | Low | High | Both islands (06 and 09) access `satellite_caches[]` and `s_cache_mutex` via concatenation order; 06 defines them before 09 uses them |
| R10 | Static buffer ownership ambiguity | Low | Medium | `s_fetch_tmp` (aggregator-task-only) stays in 06; `s_proxy_tmp` (web-handler-only) stays in 06 but documented as handler-context; Phase Y does not change ownership |
| R11 | `web_server_idf` handler registration changes needed | Very Low | Medium | Handler registration in 10-registration.h is unchanged; local component override unaffected |
| R12 | Binary size / compilation changes | Very Low | Low | Assembly produces byte-identical source; no #include changes; no new symbols |
| R13 | `bump-version.sh` fails to update fragment header | Medium | Low | v7.6.6.5 updates bump script; tested in pipeline round-trip |

---

## §9. Open Questions

### 9.1 Resolution of Phase X carryover questions

The 7 open questions from `Docs/phase-X-context-for-phase-Y.md` §7:

| # | Question | Resolution |
|---|---------|-----------|
| Q1 | Identity gate feasibility | **Resolved.** Source-level identity gate (SHA-256 of assembled output == concatenation of fragments). No binary comparison needed. Functional equivalence confirmed by device testing at v7.6.6.7. |
| Q2 | Generator strategy | **Resolved.** Generator unchanged. Writes into assembled `sensor_history_multi.h`. Operator reverse-syncs data-model fragment after generation. |
| Q3 | Include order | **Resolved.** Not applicable — fragments are concatenated, not `#include`d. The C preprocessor never sees fragment files directly. |
| Q4 | Mutex visibility | **Resolved.** `s_cache_mutex` defined in 06-aggregator-runtime.h (line 1479); consumed by handlers in 09-web-handler-aggregator.h. Visible via concatenation order (06 precedes 09). `AGG_LOCK`/`AGG_UNLOCK` macros (line 1487–1488) in the same fragment. |
| Q5 | Test strategy | **Resolved.** Compile gate (`esphome config`) for extraction steps; device testing at v7.6.6.7; full Playwright regression at v7.6.6.8. |
| Q6 | Local component coordination | **Resolved.** No changes to `firmware/local_components/web_server_idf/`. Handler registration (fragment 10) is unchanged. |
| Q7 | Phase Y before or after Phase 7? | **Resolved.** Phase Y before Phase 7. The split creates clean extension points for Phase 7's per-device persistence structs (in 02-data-model.h) and new persist/restore engines (in 03-nvs-core.h). |

### 9.2 Deep research brief open questions

| # | Question | Resolution |
|---|---------|-----------|
| Q1 | Should `handle_api_manifest_` live in web-handler or data-model? | **Web-handler (08).** It is a method of `HistoryWebHandler` and must remain inside the class body. The inline definition at line 2722 stays in 08-web-handler-local.h. |
| Q2 | Should `probe_satellite_manifest_()` live in aggregator-runtime or aggregator-handlers? | **Aggregator-runtime (06).** It is a top-level function at line 1614, inside the `#if AGGREGATOR_ENABLED` block. It uses `s_proxy_tmp` which is also defined in 06. The "web-handler context only" comment is a usage note, not a placement constraint. |
| Q3 | Where does `handle_options_` belong? | **08-web-handler-local.h.** It is the first endpoint handler method (line 2681), beginning the local-handlers fragment. |
| Q4 | Option B or C? | **Option B (assembled artifact).** Zero generator changes, zero preflight changes, zero YAML changes. |
| Q5 | Which fragment owns `#include "gateway_manifest.h"` and `#include "aggregator_config.h"`? | **01-config.h.** These `#include` directives are at lines 93–94, inside the includes section. |
| Q6 | YAML `includes:` unchanged or fragment-listed? | **Unchanged.** YAML continues to list only `sensor_history_multi.h`. |

### 9.3 Remaining open questions requiring operator input

| # | Question | Impact | Default if no input |
|---|---------|--------|-------------------|
| O1 | Should the assembly script be Python (consistent with `render_sensor_config.py`) or bash (consistent with `bundle-dashboard.sh`)? | Script language choice | Bash — matches `bundle-dashboard.sh` precedent |
| O2 | Should `02-data-model.h` reverse-sync be automated in `provision.sh` or remain a manual operator step? | Pipeline ergonomics | Automate in v7.6.6.5 — add a `reverse-sync-data-model` function to `provision.sh` |
| O3 | Is `dashboard/firmware_modules/` the right long-term directory, or should fragments move to `firmware/core/` in a follow-on? | Directory naming | Keep `dashboard/firmware_modules/` for Phase Y; evaluate `firmware/core/` as part of Issue #140 documentation reorganization |

---

## Appendix A: Persistence-Schema Safety

Phase Y makes **zero changes** to:

| Item | Location (fragment) | Guarantee |
|------|-------------------|-----------|
| `HistoryMeta` struct layout | 03-nvs-core.h | Byte-identical source via identity gate |
| `SegmentSnapshotHeader` layout | 03-nvs-core.h | Same |
| `SegmentSnapshot` layout | 03-nvs-core.h | Same |
| NVS namespace `histv631` | 03-nvs-core.h | Same |
| NVS key scheme `seg_%03d`, `hist_meta` | 03-nvs-core.h | Same |
| `NUM_SENSORS` / `NUM_ENV_SENSORS` semantics | 02-data-model.h (ENTITY block) | Same |
| Slot indexing in restore/persist | 03-nvs-core.h | Same |
| Import compatibility | 08-web-handler-local.h (import handlers) | Same |

Retained NVS blobs written before Phase Y remain readable after Phase Y. No migration is needed.

---

## Appendix B: Generated-Block Ownership

**Decision:** Both generator marker blocks remain in the assembled `sensor_history_multi.h` as the generator's write target. The fragment source for this content is `02-data-model.h`.

**Drift prevention:**
1. Pipeline ends with `assemble-sensor-history.sh --check` — catches any drift between fragments and assembled file.
2. `render_sensor_config.py --check` — catches any drift between generated content and committed file.
3. Operator must reverse-sync `02-data-model.h` from the assembled file after any `render_sensor_config.py --write` run.

**Generator update path:** None during Phase Y. If a future phase moves fragments to `firmware/core/`, the generator's `HEADER_PATH` would need updating at that time.

---

## Appendix C: HTTP Route Ownership

### Route-to-fragment mapping

| Route family | Handler method(s) | Fragment |
|-------------|-------------------|---------|
| `GET /dashboard`, `GET /dashboard.html`, `GET /dashboard-download`, `GET /favicon.ico` | `handle_dashboard_` | 08 |
| `GET /sensors.json` | `handle_manifest_` | 08 |
| `GET /api/manifest` | `handle_api_manifest_` | 08 |
| `GET /api/v2/live` | `handle_api_v2_live_` | 08 |
| `GET /api/v2/history/{device}/{metric}` | `handle_api_v2_history_` | 08 |
| `POST /api/ingest/{device}/{metric}` | `handle_api_ingest_` | 08 |
| `POST /api/reboot` | `handle_reboot_` | 08 |
| `POST /api/delete-data` | `handle_delete_data_` | 08 |
| `POST /api/import/*` | `handle_import_begin_`, `handle_import_data_`, `handle_import_finish_` | 08 |
| `GET /api/storage-stats` | `handle_storage_stats_` | 08 |
| `GET /api/status` | `handle_status_` | 08 |
| `GET /history/{id}/{metric}` | `handle_history_` | 08 |
| `GET /api/aggregator/gateways` | `handle_aggregator_gateways_` | 09 |
| `GET /api/aggregator/live` | `handle_aggregator_live_` | 09 |
| `GET /api/aggregator/proxy/*` | `handle_aggregator_proxy_` | 09 |
| `POST /api/aggregator/add-satellite` | `handle_add_satellite_` | 09 |
| `DELETE /api/aggregator/satellite/{id}` | `handle_delete_satellite_` | 09 |
| `POST /api/aggregator/test-satellite` | `handle_test_satellite_` | 09 |
| `POST /api/system/reset-satellites` | `handle_reset_satellites_` | 09 |

**Dispatch:** `canHandle()` and `handleRequest()` remain in 07-web-handler-core.h. They are the single entry point for all requests. The dispatch logic is unchanged — it calls handler methods that now live in fragments 08 and 09.

---

## Appendix D: Aggregator Two-Island Problem

The aggregator subsystem spans two non-contiguous regions:

| Island | Fragment | Lines | Content |
|--------|---------|------:|---------|
| Runtime island | 06-aggregator-runtime.h | 1388–2278 | `SatelliteCache`, mutex, fetch, probe, satellite NVS persistence, poll task, deferred tasks, `start_aggregator_task` |
| Handler island | 09-web-handler-aggregator.h | 3697–4284 | `handle_aggregator_gateways_`, `handle_aggregator_live_`, `handle_aggregator_proxy_`, `handle_add/delete/test/reset_satellite_` |

**Shared state accessed by both islands:**

| Symbol | Defined in | Used in |
|--------|-----------|---------|
| `s_cache_mutex` | 06 (line 1479) | 06 (poll task) + 09 (all handlers) |
| `AGG_LOCK()` / `AGG_UNLOCK()` | 06 (lines 1487–1488) | 06 + 09 |
| `satellite_caches[]` | 06 (line 1464) | 06 + 09 |
| `runtime_satellite_count` | 06 (line 1465) | 06 + 09 |
| `satellite_config_generation` | 06 (line 1466) | 06 (poll task) + 09 (add/delete/reset handlers) |
| `s_fetch_tmp` | 06 (line 1495) | 06 only (aggregator-task context) |
| `s_proxy_tmp` | 06 (line 1500) | 06 (`probe_satellite_manifest_`) + 09 (proxy/test handlers) |
| `fetch_to_buffer()` | 06 (line 1511) | 06 (poll) + 09 (proxy/test) |
| `probe_satellite_manifest_()` | 06 (line 1614) | 09 (add/test handlers) |
| `save_single_satellite_to_nvs_()` | 06 (line 1870) | 09 (add handler) |
| `schedule_reset_satellites_()` | 06 (line 2201) | 09 (reset handler) |
| `schedule_save_satellites_nvs_()` | 06 (line 2219) | 09 (delete handler) |

**Resolution:** Both islands are extracted as separate fragments (06 and 09), maintaining their physical positions. Shared state visibility is guaranteed by concatenation order: fragment 06 appears before fragment 09 in the assembly manifest. All symbols defined in 06 are visible to 09 because the C++ compiler processes the assembled file top-to-bottom.

No forward declarations are needed. No additional headers are needed. The key guarantee is that the assembly script's fragment order is immutable and matches the original monolith's top-to-bottom layout.

---

## Appendix E: Task / Mutex / Deferred-Work Safety

### Deferred-task pair locations after split

| Task function | Fragment | Scheduler function | Fragment | Called from |
|--------------|---------|-------------------|---------|------------|
| `reboot_task_` | 04 | `schedule_reboot_` | 04 | `handle_reboot_` in 08 |
| `delete_data_task_` | 04 | `schedule_delete_data_` | 04 | `handle_delete_data_` in 08 |
| `reset_satellites_task_` | 06 | `schedule_reset_satellites_` | 06 | `handle_reset_satellites_` in 09 |
| `save_satellites_nvs_task_` | 06 | `schedule_save_satellites_nvs_` | 06 | `handle_delete_satellite_` in 09 |

**Visibility guarantee:** Every scheduler function (in 04 or 06) is defined **before** the handler that calls it (in 08 or 09), because the fragment numeric order matches the original top-to-bottom order of the monolith.

### Mutex visibility

`s_cache_mutex` is defined in 06 (line 1479). All consumers in fragments 06 and 09 see it via concatenation order. No additional locking primitives are introduced.

### Yield safeguards

`maybe_yield_nvs_scan_()` is defined in 03-nvs-core.h (lines 800–804). It is called from:
- `restore_from_nvs` in 03 (same fragment)
- `build_import_epoch_map_` in 08 (via concatenation order, 03 precedes 08)
- `handle_history_` in 08 (same reasoning)

---

## Appendix F: Test and Guardrail Surface

### Existing tests that guard Phase Y correctness

| Test file | Groups | What it guards |
|-----------|--------|---------------|
| `boot-structure.spec.js` | 1–2 | Manifest boot, app shell — verifies `/api/manifest` contract |
| `history-charts.spec.js` | 6–7 | Chart rendering, history fetch — verifies `/history/{id}/{metric}` and `/api/v2/history` |
| `aggregator.spec.js` | 17, 21 | Aggregator UI — verifies `/api/aggregator/*` routes |
| `satellite-management.spec.js` | 21 | Add/delete/test satellite — verifies POST body handling (LESSON-OPS-099) |
| `regression.spec.js` | 11–16 | BUG-043, BUG-044 regressions — verifies history serving behavior |
| `sensor-cards.spec.js` | 3–5 | Environmental card rendering — verifies `/api/v2/live` data shape |
| `system-devices.spec.js` | 20 | System device cards — verifies `/api/ingest` and `/api/v2/live` for system devices |
| `theme-export.spec.js` | 8–9 | CSV export/import — verifies import endpoint contracts |
| `manifest.spec.js` | 18–19 | Manifest v2 schema — verifies `/api/manifest` response shape |

**Coverage assessment:** All 21 endpoint families have test coverage via the existing Playwright suite. No new tests are required for Phase Y because the split produces byte-identical compiled output.

### New preflight checks added by Phase Y

| Check | Added in | Purpose |
|-------|---------|---------|
| `sensor_history_assembly_check` | v7.6.6.1 | Assembly `--check` passes |
| `firmware_module_files_exist` | v7.6.6.1 | All 10 fragment files exist |
| `sensor_history_fragment_count` | v7.6.6.5 | 10 fragments sum to expected line count |

### Existing checks that continue to work unchanged

All 18 content-based checks in `scripts/preflight.sh` that grep `sensor_history_multi.h` continue to work because they check the assembled artifact, not fragments.

---

## Version Number Mapping

| Phase | Version Range | Description |
|-------|--------------|-------------|
| Phase D | v7.6.0.0–v7.6.0.5 | Runtime Satellite Management |
| Phase X | v7.6.4.0 + v7.6.5.0–v7.6.5.8 | Dashboard Architecture Refactor |
| **Phase Y** | **v7.6.6.0–v7.6.6.8** | **Firmware Architecture Refactor** |
| Phase 7 | v7.7.0.0–v7.7.2.x | Per-Device Persistence Engine |
| Phase E | v8.0.x | Captive Portal + WiFi Config |

---

## Pre-Implementation Verification Gate

Before implementation begins, verify:

- [x] Every proposed module boundary is justified by the v2 inventory §9 and the deep research brief §R1
- [x] Line ranges verified against actual file (`grep -n` confirms all 10 boundaries)
- [x] Generator strategy explicit: writes into assembled `sensor_history_multi.h`; markers stay in `02-data-model.h` region; reverse-sync pattern documented
- [x] YAML `includes:` strategy explicit: unchanged (assembled artifact path)
- [x] All 4 deferred-task pairs have explicit homes: reboot/delete in 04; reset-satellites/save-satellites-nvs in 06
- [x] Mutex/lock visibility strategy explicit: defined in 06, visible to 09 via concatenation order
- [x] Identity/verification gate defined for each step: assembly `--check` SHA-256
- [x] `provision.sh` pre-step fully specified (v7.6.6.0)
- [x] Phase 7 compatibility addressed: structs extend 02, engines extend 03, handlers extend 08
- [x] Aggregator two-island problem explicitly resolved (Appendix D)

---

_End of Phase Y Architecture and Refactor Plan._
