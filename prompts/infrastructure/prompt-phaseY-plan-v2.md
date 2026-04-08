You are helping plan a Phase Y architecture refactor for the following repository:
https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

## Your Task

Produce a detailed architecture and refactor plan document named:
`phase-Y-architecture-and-refactor-plan-sensor-history.md`

This document should be written to the same standard and format as
`Docs/phase-X-architecture-and-refactor-plan-dashboard.md` and should be comparable in quality and detail.

Save the final document to:
`Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`

Commit directly to `main` with message:
`docs: produce Phase Y architecture and refactor plan for sensor_history_multi.h`

This is a **planning/documentation task only**.
Do **not** implement the refactor.

---

## Phase Y Goal

Split the 4,325-line `dashboard/sensor_history_multi.h` monolith into focused responsibility-oriented modules in a new `firmware/core/` directory (or similar — you may propose an alternative directory name if justified) so that:

1. A coding agent working on one feature area no longer has to read the entire file (~30K tokens)
2. Each subsystem has clear ownership boundaries
3. The generated-vs-hand-maintained seam is explicit and enforced
4. Future feature work (Phase 7 per-device persistence, Phase 8 cloud, captive portal) operates on targeted modules instead of a monolith

**Phase Y is structural only. No behavior changes.**

---

## What Phase Y Does NOT Include

The following are explicitly out of scope for Phase Y. Do not plan steps for them:

- YAML slimming (moving lambdas to .h files) — separate future effort after Phase Y
- New board templates (C5, C6, S3-2MB) — post-Phase Y
- Sensor/device addition/removal workflow — post-Phase Y
- Dashboard bug fixes (#136, #137, #138, #143, #144) — post-Phase Y
- Per-device persistence engine (Phase 7) — depends on Phase Y completion
- Documentation reorganization (Issue #140) — handled by a separate prompt

However, Phase Y **does include one pre-step** (v7.6.6.0):
- `provision.sh` full pipeline automation (currently only runs step 0 of 8, printing the rest for manual execution)
- This directly reduces error risk during Phase Y device testing and is a prerequisite for reliable iterative firmware work

---

## Context You Must Read First (in this exact order)

### 1. Primary planning inputs

Read these first — they define the problem space:

1. `Docs/phase-Y-current-state-inventory-sensor-history-v2.md`
   — **this is your primary reference**; 835-line inventory of current file state, subsystem boundaries, contiguous/scattered analysis, and delta from v1

2. `dashboard/sensor_history_multi.h`
   — **full read required**; the primary subject (4,325 lines at HEAD)

3. `Docs/phase-X-context-for-phase-Y.md`
   — Phase X methodology carryover, Phase Y differences, and open questions

4. `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`
   — **format reference and methodology source**; this is the quality bar for your output

### 2. Phase X results (methodology precedent)

5. `prompts/handoff/phaseX-results.md`
   — Phase X delivery summary, lessons, component model, and architecture metrics

6. `prompts/handoff/phaseX-results-quality-check.md`
   — Phase X quality check; shows the review standard Phase Y will also face

### 3. Generator and build system

7. `scripts/render_sensor_config.py`
   — generated sections, output ownership, marker-block handling, board profile support

8. `scripts/sensor_manifest_lib.py`
   — manifest/config contracts

9. `scripts/provision.sh`
   — current board-switching workflow; currently auto-runs only `render_sensor_config.py --write` then prints remaining 7 steps

10. `scripts/preflight.sh`
    — 68 architectural guardrails; your plan must not break any of them

### 4. Firmware integration

11. `firmware/esp32-c3-multi-sensor.yaml`
    — include order, `on_boot` wiring, intervals, web server registration

12. `firmware/boards/esp32-c3-supermini.yaml`
    — board profile example (3 profiles exist: C3, S3, WROOM)

### 5. Generated dependencies

13. `src/gateway_manifest.h`
    — generated manifest consumed by the header

14. `src/aggregator_config.h`
    — generated aggregator configuration

### 6. Dashboard contract surface (post-Phase X)

15. `dashboard/core/config.js`
    — API endpoint definitions and boot sequence

16. `dashboard/core/history.js`
    — history-fetch logic and endpoint consumption

17. `dashboard/components/gateway-panel/index.js`
    — aggregator/satellite management UI consumption

### 7. Test contract surface (post-Phase X)

18. `tests/browser/boot-structure.spec.js`
19. `tests/browser/history-charts.spec.js`
20. `tests/browser/aggregator.spec.js`
21. `tests/browser/satellite-management.spec.js`
22. `tests/browser/test-helpers.js`
23. `tests/mock-server/server.js`
24. `tests/fixtures/generate-fixtures.js`

### 8. Local HTTP stack

25. `firmware/local_components/web_server_idf/web_server_idf.cpp`
26. `scripts/patch-esphome-httpd-stack.sh`

### 9. Lessons and constraints

27. `Docs/lessons/index.md`
28. `Docs/lessons/firmware.md`
29. `Docs/lessons/dashboard.md`
30. `Docs/lessons/operations.md`
31. `Docs/lessons/build-pipeline.md`

Pay special attention to these bug clusters:
- BUG-043 (history scan / scheduling / yield safeguards)
- BUG-045, BUG-046, BUG-048 (persistence schema / NUM_SENSORS family)
- BUG-075, BUG-076, BUG-077, BUG-078 (httpd stack / ESP-IDF types / status codes)
- BUG-079, BUG-080, BUG-081 (Phase D satellite management)

### 10. Existing Phase 7 plan (downstream consumer)

32. `Docs/v7.7-implementation-plan.md`
    — Phase 7 will add per-device persistence to whatever module structure Phase Y creates; understanding this helps you plan the split

33. `Docs/v7.7-v7.8-persistence-architecture.md`
    — persistence architecture that Phase 7 implements; affects which modules need extension points

After reading all files, proceed to produce the plan.

---

## Critical Methodology Constraints

### Identity gate adaptation for C++

Phase X used SHA-256 identity gates on `dashboard.js` (concatenation reproduces original byte-for-byte). For C++ in ESPHome/ESP-IDF:

- The C preprocessor's `#include` mechanism handles assembly, unlike bash `cat` concatenation
- ESPHome compilation includes timestamps and non-deterministic elements that prevent binary identity comparison
- **The plan must define a feasible verification strategy** for each step. Options to evaluate:
  1. Preprocessor output comparison (`gcc -E` or equivalent)
  2. Compile-and-compare object files (stripping timestamps)
  3. Functional equivalence via device testing + all Playwright tests passing
  4. Source-level identity: the assembled `#include` chain must produce the same preprocessor output as the original monolith

Pick the most practical approach and justify it. Do not assume binary identity is achievable.

### Contiguous-slice viability

The v2 inventory (§9) identifies which subsystems are contiguous vs scattered in the current file. **This is a hard planning constraint:**

- **Contiguous blocks** (PingAdapter ~1951–2235, aggregator runtime ~2236–3290, aggregator routes ~4041–4295, registration tail ~4296–4325) can potentially use Phase X-style extraction
- **Scattered subsystems** (import engine, auth/management, full aggregator) cannot be extracted as single contiguous slices — the plan must describe a different strategy for these

**The plan must verify all line ranges against the actual file before finalizing module boundaries.** The inventory's line ranges are analysis estimates, not compiler anchors. This is a lesson from Phase X where logical affinity groupings did not match physical positions.

### Generator strategy

The plan must explicitly address how `render_sensor_config.py` interacts with the split:
- Do generated marker blocks stay in a single file? Move to a dedicated generated header?
- Does the generator need to learn about new file paths?
- What is the migration path for the generator during the split?

### ESPHome YAML includes

After splitting, the YAML `includes:` list must reference all fragment files in the correct order. The plan must specify:
- Exact include order
- Whether `render_sensor_config.py` generates the include list or it is hand-maintained
- How board profiles are affected

---

## Document Requirements

The plan document must include all of the following sections.

### §1. Current State Analysis

Summarize the problem concisely (reference the v2 inventory, don't duplicate it):
- Current file size, responsibility count, token burden
- Why the current structure is expensive for coding-agent work
- Which Phase 7 / future features will make it worse if left unsplit
- Current context-window cost estimate for a typical firmware task

### §2. Proposed Directory Structure

Show before/after directory tree for the final target state.

Example (adjust based on analysis):
```
firmware/core/           ← new directory for split modules
  data-model.h           ← structs, constants, generated topology
  history-store.h        ← persistence/NVS/restore/migrate
  history-buffer.h       ← RAM ring buffer primitives
  import-engine.h        ← CSV import state machine
  auth-management.h      ← auth, lockout, deferred management tasks
  ping-adapter.h         ← PingAdapter class
  aggregator-runtime.h   ← cache, polling, NVS satellites, deferred tasks
  route-handlers.h       ← HistoryWebHandler with endpoint dispatch
  orchestration.h        ← boot registration, startup wiring
dashboard/
  sensor_history_multi.h ← becomes thin include-assembly file (or removed)
```

The plan may propose a different decomposition — the above is illustrative. **Justify every module boundary decision** with reference to the v2 inventory's contiguous/scattered analysis and the Phase Y goals.

### §3. Versioned Steps

Break into numbered sub-steps matching version pattern `v7.6.6.0`–`v7.6.6.x`.

**v7.6.6.0 must be the pre-step:**
- `provision.sh` full pipeline automation (execute all 8 steps, not just step 0)
- Add `--dry-run` option to preview what would be executed
- Update documentation for the new workflow

For each subsequent step:
- Version number
- Exact files created/modified/moved
- Acceptance criteria as checklist items `- [ ]`
- Risk rating (Low / Medium / High)
- Estimated effort (sessions)
- Identity/verification gate for that step
- Explicit gate conditions: Playwright tests pass, preflight passes, `esphome config` validates

Use as many sub-steps as necessary. Do not force an artificially small number.

### §4. Build / Generation / Integration Pipeline Changes

For each Level or step that changes the pipeline:
- How `render_sensor_config.py` must change
- Whether generated blocks move to separate headers
- YAML `includes:` changes
- Preflight changes needed
- `provision.sh` changes (if any beyond v7.6.6.0)
- Whether the local `web_server_idf` override needs coordination

### §5. Migration Safety Rules

Explicit constraints for every Phase Y step:
1. No behavior changes — structural reorganization only
2. All existing Playwright tests must pass after each sub-step
3. All existing preflight checks must pass after each sub-step
4. `esphome config` / compile must remain valid after each sub-step
5. Endpoint contracts unchanged (paths, methods, auth, payload shape)
6. Persisted-history schema and NVS compatibility unchanged
7. Each step independently revertable
8. Phase Y must preserve all endpoint shapes and behaviors assumed by the post-Phase X dashboard architecture, tests, and build guardrails
9. Generated artifacts must remain valid after each step
10. Deferred-task patterns must survive the split (httpd stack constraint)
11. Mutex/lock scope must survive the split
12. Scheduler-yield safeguards (`maybe_yield_nvs_scan_`) must survive the split

### §6. Coding Agent Task Size Analysis

Estimate:
- Current baseline: tokens required for a typical firmware task against the monolith
- After each Level: tokens required for the same task against the split modules
- Final state: expected typical task context window

Use the same format as Phase X results (§Architecture Metrics table).

### §7. Rollout Order

- Which Level first and why
- Gate conditions between Levels
- Where device testing is required vs where compile-only gates suffice
- Safest sequencing for a firmware-critical refactor

### §8. Risks and Mitigations

Table format matching Phase X plan style. Must include risks specific to:
- NVS schema breakage during file moves
- `#include` order violations (forward declarations, symbol visibility)
- Generator marker ownership confusion during split
- YAML `includes:` breakage
- Mutex/lock visibility across split files
- Deferred-task function visibility across files
- Static buffer ownership ambiguity after split
- Aggregator two-island problem (runtime block + route handlers in different files need shared state)
- `web_server_idf` handler registration changes
- Binary size / compilation changes from include reorganization

### §9. Open Questions

List any decisions that require operator input before implementation can proceed. Reference the open questions from `phase-X-context-for-phase-Y.md` §7 and note which ones your plan resolves vs which remain open.

---

## Additional Requirements Specific to This Header

### A. Persistence-Schema Safety

The plan must explicitly state how Phase Y avoids breaking:
- retained history (NVS blobs from before the split must remain readable after)
- NVS restore behavior
- slot indexing
- import compatibility
- `NUM_SENSORS` / `NUM_ENV_SENSORS` count semantics

### B. Generated-Block Ownership

The plan must decide and justify:
- Do generated marker blocks stay in a single file, move to a dedicated generated header, or split across module files?
- How is the generator updated?
- What prevents drift after the split?

### C. HTTP Route Ownership

The plan must:
- Inventory current routes (reference v2 inventory §5)
- Propose target ownership model (which routes live in which module)
- Address the `canHandle()`/`handleRequest()` dispatch pattern (does it stay monolithic or split?)

### D. Aggregator Two-Island Problem

The v2 inventory identifies the aggregator as spanning two non-contiguous regions (~2236–3290 and ~4041–4295). The plan must explicitly address:
- Are both islands extracted together or separately?
- How is shared state (mutex, caches, config generation counter) accessible from both?
- Does the split change the deferred-task visibility?

### E. Task / Mutex / Deferred-Work Safety

The plan must account for:
- 4 deferred-task pairs (all must remain callable from their trigger context)
- `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` (must be visible wherever aggregator state is accessed)
- `satellite_config_generation` counter (shared between poll task and mutation handlers)
- `maybe_yield_nvs_scan_()` (must remain callable from all NVS-scanning loops)

### F. Test and Guardrail Surface

The plan must:
- Identify which current tests guard Phase Y correctness
- Propose new preflight checks if the split introduces new invariants
- Determine whether new tests are needed or existing coverage suffices

---

## Versioning Convention

- Phase D = `v7.6.0.x`
- Phase X = `v7.6.4.0` + `v7.6.5.x`
- Phase Y = `v7.6.6.x`

Use as many sub-steps as necessary.

---

## Format Requirements

- Same markdown structure and quality bar as `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`
- Tables for file lists, risk summaries, version mapping, subsystem ownership
- Code blocks for directory trees and pipeline changes
- Acceptance criteria as checklists `- [ ]`
- No prose padding — every sentence must carry information
- Document length: as long as needed, no artificial limit

---

## Pre-Implementation Verification Gate

Before finalizing the plan, verify:

- [ ] Every proposed module boundary is justified by the v2 inventory's contiguous/scattered analysis
- [ ] Line ranges in the plan have been verified against the actual file, not just copied from the inventory
- [ ] The generator strategy is explicit: which files the generator writes into, which markers move or stay
- [ ] The YAML `includes:` strategy is explicit with proposed include order
- [ ] All 4 deferred-task pairs have an explicit home in the proposed module structure
- [ ] The mutex/lock visibility strategy is explicit
- [ ] The identity/verification gate for each step is defined and feasible
- [ ] The `provision.sh` pre-step (v7.6.6.0) is fully specified
- [ ] Phase 7 compatibility is addressed: the split creates clean extension points for per-device persistence
- [ ] The aggregator two-island problem has an explicit resolution

---

## Output Expectations

When done:
1. Save to `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`
2. Commit directly to `main`
3. Commit message: `docs: produce Phase Y architecture and refactor plan for sensor_history_multi.h`
