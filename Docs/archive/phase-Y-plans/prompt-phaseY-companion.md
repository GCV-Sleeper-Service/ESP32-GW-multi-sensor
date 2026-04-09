You are helping prepare a Phase Y architecture refactor for the following repository:
https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

## Your Task

Produce a detailed current-state inventory and decomposition document named:
`phase-Y-current-state-inventory-sensor-history.md`

This document is **not** the refactor plan.
It is a preparatory architecture inventory document that will be used as an input to a later Phase Y refactor-planning session.

Save the final document to:
`Docs/phase-Y-current-state-inventory-sensor-history.md`

on PR124 as additional commit. Do not merge.

This is a **planning/analysis/documentation task only**.
Do **not** implement a refactor.

---

## Context You Must Read First (in this exact order)

1. `Docs/phase-d-implementation-plan.md`
   — format/quality reference for structure and rigor

2. `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`
   — Phase X dashboard architecture and build-pipeline reference

3. `dashboard/sensor_history_multi.h`
   — full read required; this is the primary subject

4. `firmware/esp32-c3-multi-sensor.yaml`
   — include order, registration wiring, interval/on_boot integration

5. `scripts/render_sensor_config.py`
   — generated sections, output ownership, and integration points

6. `scripts/sensor_manifest_lib.py`
   — manifest/config contracts used by the generator

7. `scripts/preflight.sh`
   — architectural guardrails and invariants tied to `sensor_history_multi.h`

8. `src/gateway_manifest.h`
   — generated manifest dependency

9. `src/aggregator_config.h`
   — generated aggregator-config dependency

10. `dashboard/dashboard.js`
    — generated dashboard runtime bundle that consumes the header’s endpoints and behavior (read as the canonical browser-side contract)

11. `tests/browser/dashboard.spec.js`
    — browser/runtime contract assumptions

12. `tests/browser/manifest.spec.js`
    — manifest/bootstrap contract assumptions

13. `tests/mock-server/server.js`
    — mock API contract assumptions

14. `tests/fixtures/generate-fixtures.js`
    — fixture-generation assumptions tied to endpoint shape

15. `firmware/local_components/web_server_idf/web_server_idf.cpp`
    — local HTTP stack override relevant to route behavior

16. `scripts/patch-esphome-httpd-stack.sh`
    — operational dependency for the local component behavior

17. `Docs/aggregator-setup.md`
    — aggregator workflow and operator expectations

18. `Docs/configuring-sensors.md`
    — generator/schema/sensor-count workflow expectations

19. `Docs/bugs-and-lessons-learned.md`
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

Also pay special attention to these bug clusters:
- `BUG-043`
- `BUG-045`
- `BUG-046`
- `BUG-048`
- `BUG-075`
- `BUG-076`
- `BUG-078`
- `BUG-079`

After reading all files, produce the inventory document.

---

## Goal of This Document

Produce a precise, concrete, engineering-grade inventory of the current state of `dashboard/sensor_history_multi.h` and its surrounding integration surface so that a later Phase Y refactor-planning session can work from an explicit decomposition instead of rediscovering the structure.

This document should answer:

- What responsibilities currently live in this file?
- Which parts are generated vs hand-maintained?
- Which parts are tightly coupled and high-risk?
- Which parts are natural subsystem boundaries?
- Which files and tests form the real integration surface?
- Which constraints will dominate any future refactor?

---

## Document Requirements

The document must include all of the following sections.

### 1. Executive Summary
A compact summary of what `sensor_history_multi.h` currently is.

This summary must explicitly state that the file is not “just history persistence” anymore and identify its major roles, such as:
- persistence/NVS schema
- runtime sensor model
- import/export
- management auth/actions
- API/HTTP route handling
- dashboard payload serving
- aggregator runtime/cache/polling
- ping adapter
- registration/orchestration glue
- generated sensor/entity/config blocks

### 2. Current File Metrics
Provide concrete size/shape metrics for `dashboard/sensor_history_multi.h`, including as many of the following as practical:

- approximate line count
- number of major structs
- number of classes
- number of top-level helper functions
- number of route handlers / endpoint-specific methods
- number of deferred-task helpers
- number of generator marker blocks
- number of compile-time configuration constants/macros

If counts are approximate, say so clearly.

### 3. Top-Level Responsibility Map
Break the file into responsibility areas.

For each area, provide:
- section name
- what it owns
- whether it is hand-maintained or generated
- why it is high-risk or low-risk to move

At minimum include these areas if they exist:

- compile-time constants and schema definitions
- ring buffer / history buffer primitives
- runtime sensor/entity model
- generated sensor/entity arrays
- history persistence / restore / snapshot logic
- import/export logic
- management auth / lockout / action scheduling
- ping adapter
- aggregator runtime/cache/NVS/config
- HTTP route registration / dispatch
- endpoint implementation groups
- registration/orchestration entrypoint

### 4. Generated vs Hand-Maintained Ownership
Produce a table that identifies:

- which blocks are generated today
- which files generate them
- which blocks are hand-maintained
- where mixed ownership currently exists
- what drift risks exist because of that ownership model

This section must explicitly analyze the marker-delimited generated regions and their interaction with `render_sensor_config.py`.

### 5. Endpoint Inventory
Provide a complete route inventory currently owned by `sensor_history_multi.h`.

For each route or route family, include:
- route path / pattern
- method(s)
- functional owner
- auth requirement
- likely dashboard/test consumer
- notes on sensitivity/risk

Group them into categories such as:
- legacy history routes
- dashboard/static routes
- status/manifest/storage routes
- v2 API routes
- ingest/import routes
- management routes
- aggregator routes

### 6. Data Model and Persistence Inventory
Document the current persistence-related model and why it is sensitive.

At minimum cover:
- `HistEntry`
- `HistoryBuffer`
- `HistoryMeta`
- `SegmentSnapshotHeader`
- `SegmentSnapshot`
- slot/index logic
- restore logic
- persistence cadence assumptions
- sensor-count/schema compatibility assumptions

Explicitly identify which pieces are most dangerous to refactor structurally.

### 7. Runtime Concurrency / Tasking / Locking Inventory
Document all major concurrency-sensitive patterns, including:
- deferred tasks
- FreeRTOS task creation
- semaphores/mutexes
- config generation counters
- cache access patterns
- request-context vs task-context buffer usage
- any scheduler-yield safeguards

Explain why these patterns matter to refactor safety.

### 8. Integration Surface Map
Produce a table of the files most tightly coupled to `sensor_history_multi.h`.

For each file, explain the dependency type:
- compile-time include dependency
- generated-file dependency
- runtime contract dependency
- HTTP/API contract dependency
- test/fixture dependency
- preflight invariant dependency
- local-component behavior dependency

This section must include at minimum:
- `firmware/esp32-c3-multi-sensor.yaml`
- `scripts/render_sensor_config.py`
- `scripts/sensor_manifest_lib.py`
- `scripts/preflight.sh`
- `src/gateway_manifest.h`
- `src/aggregator_config.h`
- `dashboard/dashboard.js`
- relevant tests/fixtures/mock server
- `firmware/local_components/web_server_idf/web_server_idf.cpp`

### 9. Natural Subsystem Boundaries
Without yet proposing a refactor plan, identify the subsystem boundaries that already seem to exist implicitly.

Examples to evaluate:
- history-store
- import engine
- auth/management layer
- route-dispatch layer
- aggregator runtime
- sensor runtime model
- ping/network adapter
- generated config/model layer

For each candidate subsystem, explain:
- why it is a plausible boundary
- which code likely belongs inside it
- what coupling currently blocks a clean split

### 10. High-Risk Refactor Zones
Create a table of the most dangerous areas for a future Phase Y refactor.

Include:
- area
- why it is risky
- what could break
- what tests/guards would detect breakage
- whether the risk is schema-risk, runtime-risk, route-risk, generator-risk, or integration-risk

### 11. Guardrails Already Present
Summarize the architectural and operational guardrails that already exist.

This should include:
- preflight checks
- compile/config validation
- Playwright/browser tests
- mock/fixture generation
- lessons learned that impose structural constraints
- local HTTP stack overrides that shape behavior

### 12. Missing Guardrails / Weak Spots
Identify where the current project lacks explicit structural guardrails for this file.

Do not propose the full refactor here.
Instead identify gaps such as:
- missing ownership assertions
- missing generated-file sync checks
- missing route inventory enforcement
- missing schema-preservation checks
- missing compile-time separation checks

### 13. Suggested Inputs for the Future Phase Y Planning Session
End with a short section titled exactly:

`Inputs Recommended for the Phase Y Refactor Planning Session`

That section must list:
- which documents/files the next planning session must read first
- which findings from this inventory should shape the future plan
- which areas must be treated as “no behavior change / structural only”

---

## Format Requirements

- Use the same quality bar and discipline as `Docs/phase-d-implementation-plan.md`
- Tables wherever they improve clarity
- No prose padding
- No implementation plan yet
- No speculative code changes
- Be concrete and specific
- Document length: as long as needed

---

## Output Expectations

When done:
1. save the document to `Docs/phase-Y-current-state-inventory-sensor-history.md`
2. Use PR124
3. commit the document
4. do not merge


If any requested file is missing or moved, say so clearly in the PR and adapt carefully rather than substituting loosely related files.
