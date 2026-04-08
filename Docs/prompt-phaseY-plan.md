You are helping plan a post-Phase X architecture refactor for the following repository:
https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

## Your Task

Produce a detailed architecture and refactor plan document named:
`phase-Y-architecture-and-refactor-plan-sensor-history.md`

This document should be written to the same standard and format as
`Docs/phase-d-implementation-plan.md` and should be comparable in quality/detail to the dashboard refactor planning work.

The working PR for this work is PR124. 

Save the final document to `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`
on PR124 as additional commit. Do not merge.

This is a **planning/documentation task only**.
Do **not** implement the refactor. This is to create detailed plan for such refactor.

---

## Context You Must Read First (in this exact order)

1. `Docs/phase-d-implementation-plan.md`  
   — format reference and phase naming conventions

2. `Docs/phase-Y-current-state-inventory-sensor-history.md`  
   — detailed current-state inventory and decomposition

3. `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`  
   — dashboard Phase X architecture and build pipeline; defines how the dashboard consumes sensor history endpoints after Phase X

4. `dashboard/sensor_history_multi.h`  
   — the current monolithic firmware/runtime header (full read required)

5. `dashboard/dashboard.js`  
   — generated dashboard runtime bundle that consumes the header’s endpoints and behavior (read for contract, not as a hand-maintained monolith)

6. `firmware/esp32-c3-multi-sensor.yaml`  
   — include order, on_boot wiring, intervals, web server registration, and compile integration

7. `scripts/render_sensor_config.py`  
   — generated blocks, YAML generation, gateway/aggregator config generation, and file ownership

8. `scripts/sensor_manifest_lib.py`  
   — config/manifest contracts used by the generator

9. `scripts/preflight.sh`  
   — current architectural guardrails, regression checks, and required invariants tied to `sensor_history_multi.h`

10. `src/gateway_manifest.h`  
    — generated manifest consumed by the header

11. `src/aggregator_config.h`  
    — generated aggregator configuration consumed by the header

12. `tests/browser/dashboard.spec.js`  
    — browser behavior assumptions tied to header endpoints and payloads

13. `tests/browser/manifest.spec.js`  
    — manifest/boot-path assumptions tied to header behavior

14. `tests/mock-server/server.js`  
    — mock endpoint contracts mirroring header-exposed behavior

15. `tests/fixtures/generate-fixtures.js`  
    — fixture-generation assumptions tied to endpoint/manifest structure

16. `firmware/local_components/web_server_idf/web_server_idf.cpp`  
    — local HTTP stack override that materially affects handler behavior, status code mapping, and method registration

17. `scripts/patch-esphome-httpd-stack.sh`  
    — operational coupling for the local component override

18. `Docs/aggregator-setup.md`  
    — operator-facing workflow and aggregator behavior expectations

19. `Docs/configuring-sensors.md`  
    — sensor-count/schema workflow and persistence expectations

20. `Docs/bugs-and-lessons-learned.md`  
    — especially:
    - `LESSON-OPS-052`
    - `LESSON-OPS-053`
    - `LESSON-OPS-054`
    - `LESSON-OPS-056`
    - `LESSON-OPS-059`
    - `LESSON-OPS-060`
    - `LESSON-OPS-061`
    - `LESSON-OPS-064`
    - `LESSON-OPS-074`
    - `LESSON-OPS-089`
    - `LESSON-OPS-091`
    - `LESSON-OPS-099`
    - `LESSON-OPS-100`
    - `LESSON-OPS-101`
    - `LESSON-OPS-102`
    - `LESSON-OPS-105`
    - `LESSON-OPS-106`
    - `LESSON-OPS-107`
    - `LESSON-OPS-108`
    - `LESSON-OPS-109`

Also pay attention to the bug clusters that materially shape refactor safety:
- `BUG-043`
- `BUG-045`
- `BUG-046`
- `BUG-048`
- `BUG-075`
- `BUG-076`
- `BUG-078`
- `BUG-079`

After reading all files, proceed to produce the plan.

---

## Goals of the Refactor

The plan must address three levels, each as a distinct versioned step.

### Level 1 — Responsibility Split (lower risk, immediate value)
Split `dashboard/sensor_history_multi.h` into focused responsibility-oriented units so a coding agent working on one feature area no longer has to read a ~4K-line monolith.

Examples of responsibility boundaries the plan should evaluate:
- persisted history storage / NVS schema / restore / hourly persistence
- import/export logic
- management auth and management actions
- API/HTTP route handlers
- aggregator polling/cache/runtime
- ping adapter / network probe runtime
- generated sensor/entity/config blocks
- registration/orchestration glue

Goal: any future coding agent task should fit within a practical working context window instead of requiring the entire file.

### Level 2 — Generated vs Hand-Maintained Separation
Move all generated sections and generated-config dependencies out of the hand-maintained runtime file so `sensor_history_multi.h` stops mixing:
- hand-maintained runtime logic
- generated sensor/entity arrays
- generated manifest/config glue
- version-comment churn
- board/config-dependent sections

The plan should identify which pieces should remain generated, which should become thin generated includes, and which should become hand-maintained source files.

Goal: permanently eliminate a whole class of mixed-ownership drift and reduce the chance that generator changes break runtime logic or vice versa.

### Level 3 — Service/Subsytem Architecture
Refactor the runtime into explicit subsystems with narrow ownership and a thin orchestration entry point.

Examples the plan should evaluate:
- `HistoryStore`
- `HistoryImportEngine`
- `ManagementAuth`
- `HistoryApiRoutes`
- `AggregatorRuntime`
- `PingAdapter`
- `SensorRuntimeModel`
- `HistoryWebHandler` split into route-specific handlers or service-backed handlers

Goal: future work should be able to target one subsystem plus a small amount of orchestration code, rather than the full monolith.

---

## Document Requirements

The plan document must include:

1. **Current State Analysis** — concrete description of what exists now:
   - how many lines/functions/structs/classes are in `dashboard/sensor_history_multi.h` today
   - which sections are hand-maintained vs generated
   - which sections are history-store vs import/export vs management/auth vs API-handler vs aggregator vs ping/runtime vs registration/orchestration
   - current endpoint inventory exposed by the header
   - current persistence/NVS schema structs and why they are high-risk to move
   - current coupling to:
     - `render_sensor_config.py`
     - `sensor_manifest_lib.py`
     - YAML includes / on_boot wiring
     - preflight invariants
     - dashboard runtime/tests
     - local `web_server_idf` override
   - why the current structure is costly for coding-agent work and error-prone for maintenance

2. **Proposed File Structure** — before/after directory tree for each Level

3. **Versioned Steps** — each Level broken into numbered sub-steps — as many as necessary — matching a Phase-Y version pattern:
   - assign version numbers in the range `v7.6.6.0`–`v7.6.6.x`
   - exact files modified per step
   - acceptance criteria per step
   - risk rating and estimated effort
   - explicit gate at each step:
     - **do not break existing Playwright tests**
     - **do not break preflight**
     - **do not break firmware compile/config validation**

4. **Build / Generation / Integration Pipeline Changes**
   - exactly how `render_sensor_config.py` must change at each Level
   - whether generated blocks move into separate generated headers
   - whether YAML includes need to change
   - whether `preflight.sh` needs new invariants
   - whether the local `web_server_idf` override or patch workflow needs to change
   - exactly how generated vs hand-maintained ownership should be enforced

5. **Coding Agent Task Size Analysis**
   - estimate current baseline task size/context burden
   - estimate typical task size after each Level
   - compare to today’s monolith

6. **Migration Safety Rules** — explicit constraints:
   - no behavior changes — structural reorganization only
   - all existing Playwright tests must pass after each sub-step
   - all existing preflight checks must pass after each sub-step
   - `esphome config` / compile integration must remain valid after each sub-step
   - endpoint contracts must remain unchanged unless the plan explicitly marks a later intentional cleanup phase
   - persisted-history schema and NVS compatibility must remain unchanged during Phase Y
   - each step must be independently revertable
   - Phase Y must preserve all endpoint shapes and behaviors assumed by the post–Phase X dashboard architecture, tests, and build guardrails (`Docs/phase-X-architecture-and-refactor-plan-dashboard.md`)

7. **Rollout Order**
   - which Level to implement first, why
   - gate conditions before moving to the next Level
   - identify the safest sequencing for a firmware-critical refactor

8. **Context Window Requirement**
   - if possible, estimate how many tokens each refactor step/level would require
   - show how the plan reduces future coding-agent context requirements compared to the current monolith

9. **Risks and Mitigations**
   - table format, same style as the Phase D plan
   - include risks specific to:
     - NVS schema breakage
     - endpoint-contract drift
     - generated/manual ownership confusion
     - YAML/include breakage
     - local-component HTTP behavior coupling
     - aggregator/runtime race regressions
     - import/export regressions
     - lock/mutex and deferred-task regressions

---

## Additional Requirements Specific to This Header

The plan must explicitly analyze and discuss:

### A. Persistence-Schema Safety
`HistoryMeta`, `SegmentSnapshotHeader`, `SegmentSnapshot`, and any schema-coupled constants are especially high-risk.
The plan must state clearly how Phase Y avoids breaking:
- retained history
- NVS restore behavior
- slot indexing
- import compatibility
- count/layout expectations

### B. Generated-Block Ownership
The plan must call out the generated sections now living inside `sensor_history_multi.h` and decide whether they should move into:
- one generated header
- multiple generated headers
- one generated model/config layer plus one hand-maintained runtime layer

### C. HTTP Route Ownership
The plan must explicitly inventory the current routes and propose a target ownership model.

That inventory should include at minimum:
- `/history/...`
- `/sensors.json`
- `/dashboard...`
- `/api/storage-stats`
- `/api/status`
- `/api/manifest`
- `/api/v2/live`
- `/api/v2/history/...`
- `/api/ingest/...`
- management POST routes
- aggregator routes
- DELETE routes

### D. Aggregator Boundary
The plan must explicitly state whether aggregator runtime should remain in the same primary runtime unit or move behind a dedicated subsystem boundary.

### E. Task / Mutex / Deferred-Work Safety
The plan must explicitly account for:
- deferred management tasks
- mutex-guarded cache reads/writes
- config generation counters
- snapshot-based NVS persistence patterns
- the `web_server_idf` override dependency

### F. Test Surface
The plan must identify which current tests/fixtures/mock-server contracts are the effective guardrails for Phase Y and whether additional structural guardrails should be added in preflight.

---

## Versioning Convention

Follow the existing pattern:
- Phase D = `v7.6.0.x`
- Phase X = `v7.6.5.x`
- This refactor = Phase Y  
  Assign version range `v7.6.6.0`–`v7.6.6.x`

Use as many sub-steps as necessary.
Do not force an artificially small number of steps.

---

## Format Requirements

- Same markdown structure and quality bar as `Docs/phase-d-implementation-plan.md`
- Tables for file lists, risk summaries, version mapping, and subsystem ownership
- Code blocks for directory trees and integration/build pipeline changes
- Acceptance criteria as checklists `- [ ]`
- No prose padding — every sentence must carry information
- Document length: as long as needed, no artificial limit

---

## Output Expectations

When you are done:
1. save the document to `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`
2. Use PR124
3. commit the document
4. do not merge

If you find that any file above is missing or has moved, state that clearly in the PR and adapt carefully rather than silently substituting unrelated files.
