# Multi-Phase Architecture Review and Planning Prompt

_Self-contained prompt for a fresh Claude session within this project._
_Purpose: Review Phase 7 readiness, plan Phases 8/9/10._
_No prior conversation context required._

---

## Instructions for the Advisor

You are the architectural advisor for the **ESP32-GW Multi-Sensor Gateway** project. The operator needs you to review an existing phase plan and produce planning documents for three new phases. This is a scoping and architecture session — no code changes.

### ⚠️ CRITICAL: Read the Codebase First

Your training data and session memory are **stale**. The project has gone through Phases X, Y, V, VX, and possibly more since your last session. You MUST clone the repo and read the actual current state before producing any planning output.

```
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor
```

### Mandatory Reading (in this order)

**Layer 1 — Current State (read completely):**

1. `VERSION` — current firmware version
2. `README.md` — project overview, phase roadmap, architecture summary
3. `Docs/architecture-overview.md` — phase history, active planning documents, system constraints
4. `Docs/changelog.md` — scan the last 10-15 version entries to understand recent changes

**Layer 2 — Architecture Foundations (read completely):**

5. `firmware/core/` — list all files, read `config.h` header comment and `data-model.h` struct definitions to understand the current data model
6. `firmware/esp32-c3-multi-sensor.yaml` — understand the YAML structure, on_boot lambdas, includes, substitutions, sdkconfig_options
7. `firmware/boards/` — read all board profiles to understand supported hardware and capabilities
8. `config/sensors.json` — understand the sensor manifest schema
9. `scripts/provision.sh` — understand the current build/deploy pipeline
10. `scripts/render_sensor_config.py` — understand code generation from config
11. `Docs/lessons/` — read `firmware.md` and `build-pipeline.md` for accumulated constraints

**Layer 3 — Future Phase Context (read completely):**

12. `Docs/v7.7-implementation-plan.md` — Phase 7 step-level plan (per-device persistence)
13. `Docs/v7.7-v7.8-persistence-architecture.md` — Phase 7/8 persistence architecture (especially sections 14-17 on partition layout, memory budget, sensor type catalog, platform extensibility)
14. `Docs/archive/architecture-forward-looking-notes.md` — forward-looking architecture decisions including captive portal vision, PSRAM scaling, NVS budget tracking, factory reset
15. `Docs/phase-V-implementation-plan.md` — scan for roadmap table and any Phase E/7/8 references
16. `Docs/decisions/` — read all ADR documents for accepted architectural decisions

**Layer 4 — Constraint Context:**

17. `prompts/prompt-index-and-workflow.md` — Critical Rules (these constrain all future phases)
18. `Docs/phase-V-capacity-study.md` — memory/flash budget analysis (produced at v7.6.6.8; updated context in v7.6.9.5 supplement)
19. `partitions/` — read all partition table CSVs to understand flash layout constraints
20. `Docs/phase-V-closure-analysis.md` — Phase V retrospective: plan-vs-delivery, review findings, handoff items for Phase 7
21. `prompts/handoff/phaseV/phaseV-results.md` — Phase V delivery record, device test baselines, deferred items, new Critical Rules and lessons

### After Reading

Produce a brief "Current State Summary" (max 1 page) confirming:
- Current version and what phase is active
- Hardware inventory from board profiles (chips, flash, PSRAM, RAM)
- Memory situation (heap measurements if available in recent session logs or status endpoints)
- Flash usage situation
- Partition layout constraints
- How many Playwright tests exist
- What the current phase roadmap looks like

This summary proves you read the codebase and catches any misunderstanding before planning begins.

---

## Deliverable 1: Phase 7 Review

**Goal:** Assess whether the Phase 7 implementation plan (`Docs/v7.7-implementation-plan.md`) and its architecture doc (`Docs/v7.7-v7.8-persistence-architecture.md`) are still accurate against the current codebase.

**Specific questions to answer:**

1. Do the file paths, function names, and struct references in the Phase 7 plan match the actual codebase? (Phase Y refactored `sensor_history_multi.h` into modules under `firmware/core/`. Phase V added auth guards and split `/api/status`.)
2. Are the memory budget assumptions in Section 15 of the architecture doc still valid given the v7.6.7.3 measurement results? (Check session logs for actual heap/stack watermark values.)
3. Does the Phase 7 plan need new steps or modified steps to account for:
   - The module structure (Phase Y created `firmware/core/*.h` fragments assembled by `assemble-sensor-history.sh`)
   - The auth guards (Phase V added `authenticate_management_()` to write endpoints)
   - The status split (`/api/status` is now public with `{ok, role, id}`; `/api/status/full` is auth-gated)
   - The `provision.sh` pipeline (replaces the old manual multi-step pipeline)
4. Are the v7.7.x prompts (if they exist in `prompts/`) still valid, or do they reference stale file paths and APIs?
5. Phase V is closed (v7.6.9.5). Phase VX (board onboarding, v7.6.10.x) may or may not have completed before this session. What adjustments does Phase 7 need based on Phase VX outcomes (or their absence)?

**Output:** A review document with findings, corrections needed, and a go/no-go recommendation for starting Phase 7.

---

## Deliverable 2: Phase 8 — Captive Portal Provisioning Plan

**Goal:** Produce a scoping and architecture document for the captive portal / WiFi provisioning system.

**Context from existing documentation:**

The project roadmap lists "Phase E: Captive portal + WiFi config" at v8.0.x. The `architecture-forward-looking-notes.md` (Section 1) describes the vision:

- First boot: board creates WiFi AP, user connects, captive portal opens
- Portal: enter WiFi credentials, device name, role (satellite or aggregator)
- PSRAM detection gates role selection at runtime
- After WiFi config: sensor discovery wizard, aggregator satellite-add wizard
- Goal: "flash once, configure everything through dashboard"

**What the advisor should research and decide:**

1. **ESP-IDF captive portal options:** ESPHome has a `captive_portal:` component. Is it sufficient, or does this need a custom implementation? What are the limitations?
2. **NVS-based WiFi config:** Currently WiFi credentials are in `secrets.yaml` (compile-time). Moving to NVS means the firmware boots without WiFi, starts AP mode, serves the portal, saves credentials to NVS, then reboots into station mode. What ESP-IDF APIs are needed?
3. **Runtime sensor discovery:** Currently BLE sensor MACs are in `config/sensors.json` (compile-time). Moving to runtime discovery means BLE scanning, presenting discovered devices in the portal UI, and saving selected devices to NVS. How does this interact with `render_sensor_config.py`?
4. **Factory reset:** The `architecture-forward-looking-notes.md` (Section 6) describes a factory reset endpoint. This is tightly coupled with the captive portal — reset should clear WiFi + sensor config and reboot into AP mode.
5. **Partition impact:** Does the captive portal need additional NVS space? Does the portal HTML need its own partition or can it be embedded like the dashboard?
6. **Scope boundaries:** What is the minimum viable captive portal (Phase 8a) vs. the full vision (Phase 8b/c)?

**Output:** A Phase 8 scoping document with architecture decisions, step breakdown, risk assessment, and dependency analysis against Phase 7.

---

## Deliverable 3: Phase 9 — Cloud Storage and Notifications Plan

**Goal:** Produce a scoping and architecture document for cloud data upload and notification support.

**Context:**

The project currently has NO cloud connectivity — the README says "No cloud. No database. No Home Assistant required." This is a deliberate design choice. Phase 9 would add **optional** cloud features that don't compromise the local-first architecture.

The `v7.7-v7.8-persistence-architecture.md` (line 896) explicitly states: "The persist engine writes to local NVS only. If WiFi is down, persistence still works. Network-dependent storage (cloud upload) is a separate concern for future phases."

The `fetch_to_buffer()` function in `aggregator-runtime.h` already uses raw lwIP sockets. Cloud uploads would need TLS — ESP-IDF provides `esp_tls` for this. An earlier conversation confirmed: "When cloud persistence comes, you add TLS wrapping to `fetch_to_buffer()` or write a separate `fetch_to_buffer_tls()` — a contained function-level change."

**What the advisor should research and decide:**

1. **Cloud storage options:** MQTT (lightweight, standard IoT), HTTPS POST to a REST API (flexible, works with any backend), WebSocket (persistent connection). Which fits the ESP32's memory constraints best?
2. **TLS memory cost:** mbedTLS requires significant heap (~40KB for a TLS session). Given the C3's min_free_heap of ~57KB under load, can a satellite even establish a TLS connection? Or is cloud upload aggregator-only?
3. **Notification options:** Email (requires SMTP over TLS), push notifications (requires a cloud relay), webhook (simplest — POST to a URL when a threshold is crossed). Which are feasible on ESP32?
4. **Configuration model:** Where do cloud credentials, endpoint URLs, and notification rules live? NVS? A new config file? Managed via the dashboard?
5. **Data flow architecture:** Upload on a schedule? On every persist cycle? Buffered and batched? What happens when WiFi is down — store-and-forward?
6. **Impact on local-first philosophy:** This must be opt-in, disabled by default, and not affect satellite performance when disabled. How to enforce this architecturally?
7. **Scope boundaries:** What is the minimum viable cloud support (Phase 9a) vs. the full vision?

**Output:** A Phase 9 scoping document with architecture decisions, memory analysis, protocol comparison, step breakdown, and risk assessment.

---

## Deliverable 4: Phase 10 — Standalone Role Plan

**Goal:** Produce a scoping and architecture document for a "standalone" board role — a single device that operates independently without aggregator integration.

**Context:**

Currently there are two roles: **satellite** (local sensors, serves dashboard, can be polled by aggregator) and **aggregator** (polls satellites, serves unified dashboard). Both roles assume a multi-device deployment.

A **standalone** role would be a single board that:
- Has all satellite features (BLE sensors, history, dashboard, CSV export/import)
- Does NOT have aggregator features (no satellite polling, no gateway panel, no proxy endpoints)
- Does NOT need to be discoverable or pollable by an aggregator
- May have simplified auth (single-user, optional)
- May have different partition layout (no need for large aggregator buffers)

**What the advisor should research and decide:**

1. **What code can be removed/disabled?** The aggregator subsystem (`aggregator-runtime.h`, `AGGREGATOR_ENABLED` guards, gateway-panel dashboard component) is already conditionally compiled. But the satellite also includes code paths for being polled by an aggregator (e.g., `/api/aggregator/add-satellite`, certain status fields). Can these be cleanly disabled?
2. **What code must stay?** `/api/ingest/` (external push from NAS/cron), `/api/import/` and `/api/export/` (data management), all history endpoints, dashboard serving.
3. **Memory savings:** How much heap/flash is saved by excluding aggregator code? Is it significant enough to justify a separate role?
4. **Configuration model:** Is standalone a third role in `provision.sh`, a board profile flag, or a sensor config option? How does the captive portal (Phase 8) present it?
5. **Dashboard impact:** The standalone dashboard doesn't need the gateway panel, satellite management, or proxy features. Is it worth creating a stripped dashboard build, or is the code saving negligible?
6. **Phase ordering:** Should standalone come before or after captive portal? Before or after cloud? What are the dependencies?
7. **Complexity assessment:** Is a standalone role worth the maintenance cost, or is a satellite without an aggregator already functionally standalone?

**Output:** A Phase 10 scoping document with analysis of code separation feasibility, memory impact assessment, recommended implementation approach, and a clear recommendation on whether this phase is justified or can be achieved with configuration alone.

---

## Deliverable Format

For each deliverable, produce:

1. **Executive summary** (5-10 sentences) — what the phase does, key decisions, recommended scope
2. **Architecture decisions** — with rationale for each
3. **Step breakdown** — version numbers, scope per step, files modified, acceptance criteria
4. **Risk assessment** — what can go wrong, how to mitigate
5. **Dependency analysis** — what must come before, what this enables
6. **Memory/flash budget impact** — estimated heap and flash cost of the new features
7. **Phase ordering recommendation** — where this fits in the overall roadmap

---

## Phase Ordering Question

After producing all four deliverables, provide a recommended execution order considering:

- Phase V closed at v7.6.9.5 (2026-04-20). Results: `prompts/handoff/phaseV/phaseV-results.md`
- Phase VX (board onboarding sprint, v7.6.10.x) may have completed — check for `Docs/board-measurement-log-v7.6.10.md`
- Phase 7 has detailed plans but hasn't started
- Memory is tight on C3 (free_heap ~57 KB at boot with 16 KB httpd stack; min_free_heap ~29 KB under stress)
- BUG-082 (WROOM history OOM) is open and deferred to Phase 7 chunked streaming — no step for this exists in the current Phase 7 plan
- The operator wants to minimize complexity and avoid scope creep
- Some phases may enable or block others (e.g., captive portal benefits from per-device persistence; cloud needs TLS which needs heap headroom)

---

_End of multi-phase planning prompt._
