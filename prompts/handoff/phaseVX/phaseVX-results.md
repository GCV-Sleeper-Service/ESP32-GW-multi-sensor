# Phase VX Results — Board Onboarding Sprint

_Phase: VX (v7.6.10.0–v7.6.10.4)_
_Duration: 2026-04-22 to 2026-05-06_
_Status: ✅ Complete_

---

## Summary

Phase VX was an infrastructure sprint between Phase V closure and Phase 7 start. It onboarded 3 new ESP32 board variants into the provisioning pipeline, upgraded the ESPHome toolchain, collected the project's first comprehensive 6-board measurement dataset, updated capacity/selection documentation with measured data, and unified the dashboard authentication flow.

## Steps Completed

| Step | Version | Scope | PR | Key Outcome |
|---|---|---|---|---|
| Step 0 | v7.6.10.0 | ESPHome 2026.2.1 → 2026.4.1 upgrade | PR #200 | Local component override refreshed, 3 existing boards verified |
| Step 1 | v7.6.10.1 | Board profiles + partitions for 3 new boards | PR #201 | S3 SuperMini, C6 SuperMini, C5 WROOM-1U added to pipeline |
| Step 2 | v7.6.10.2 | Flash, measure, document | Operator-driven | 6-board measurement dataset in board-measurement-log-v7.6.10.md |
| Step 3 | v7.6.10.3 | Documentation update | Advisory session | Board selection guide, capacity study expanded with measured data |
| Step 4 | v7.6.10.4 | Dashboard auth refactor | PR #202 | authFetch() replaces browser-managed credentials |

## Key Findings

### BUG-084: Heap exhaustion under concurrent HTTP connections
Non-PSRAM boards (C3, WROOM, C6) crash under 8 concurrent HTTP connections via heap exhaustion — not stack overflow. Stack watermarks remain healthy. Safe concurrent limit: 4 for non-PSRAM, 8 for PSRAM-equipped boards. This is the central operational finding of Phase VX and changes recommendations for all non-PSRAM board deployments.

### S3 SuperMini: Best-value satellite
The S3 SuperMini with 2 MB PSRAM measured 123,156 B free heap — 2× the C3 — and passes 8-concurrent stress tests. At $4–6, it eliminates heap crash risk for a modest cost increase over the C3's $2–4.

### C6 flash constraint
WiFi 6 + 802.15.4 radio stacks add ~192 KB to the binary. The C6 with 4 MB flash uses 91.6% of its OTA partition — only 145 KB headroom. An 8 MB C6 variant is available and resolves this.

### C5 BLE antenna issue
The C5 WROOM-1U compiled and booted successfully but did not receive BLE sensor data. Root cause: the external IPEX antenna was not attached during testing. Re-test with antenna pending. A C5 SuperMini (integrated antenna) is being procured for independent verification.

### S3 DevKitC watermark regression
The S3 aggregator's httpd stack watermark dropped from 12,528 B (v7.6.9.5) to 10,036 B (v7.6.10.0) after the ESPHome upgrade. Caused by new SSE internals. Still above the 10,000 B threshold but should be monitored on future upgrades.

### Dashboard auth refactor
Application-level credential management via `auth.js` core module eliminates browser native auth dialogs. All auth-gated fetch calls now use `authFetch()` with explicit `Authorization` header. The existing auth-modal component was extended for universal dashboard use. No firmware changes required.

## Lessons Learned

| ID | Summary |
|---|---|
| LESSON-OPS-129 | Agent prompts must distinguish directly-modified files from pipeline-regenerated files |
| LESSON-OPS-130 | patch-esphome-httpd-stack.sh --check drift warning is expected with project-specific fixes |
| LESSON-OPS-131 | sram1_as_iram is counterproductive when heap is the bottleneck |
| LESSON-OPS-132 | WiFi 6 + 802.15.4 radio stacks add ~192 KB to firmware binary |
| LESSON-OPS-133 | C6 min_free_heap reporting inverts with free_heap when non-internal memory exists |
| LESSON-OPS-134 | C5 WROOM-1U requires external IPEX antenna for BLE reception |

## Documents Produced / Updated

| Document | What changed |
|---|---|
| `Docs/board-measurement-log-v7.6.10.md` | Created and fully populated with 6-board data |
| `Docs/esp32-board-selection-guide.md` | Expanded from 3 boards to 6, measured data, BLE-disable analysis |
| `Docs/phase-V-capacity-study.md` | §10–§14 added: 6-board table, PSRAM impact, BUG-084 constraints |
| `Docs/board-measurement-protocol-v7.6.10.md` | Created with per-board measurement procedures |
| `Docs/lessons/firmware.md` | BUG-084, LESSON-OPS-129 through 134 |
| `Docs/architecture-overview.md` | Updated with 6 boards, Phase VX status |
| `prompts/handoff/multi-phase-planning-supplement-post-vx.md` | Measurement table populated |
| `dashboard/core/auth.js` | New auth module |

## Board Fleet After Phase VX

| Board | IP | Role | Status |
|---|---|---|---|
| ESP32-C3 SuperMini | .189 | Satellite | Production |
| ESP32-WROOM-32D | .170 | Satellite | Production |
| ESP32-S3 DevKitC N16R8 | .191 | Aggregator | Production |
| ESP32-S3 SuperMini | .173 | Satellite | Verified (v7.6.10.1) |
| ESP32-C6 SuperMini | .184 | Satellite | Verified (v7.6.10.1) |
| ESP32-C5 WROOM-1U | .180 | Satellite | ⚠️ BLE re-test needed |

## Prompt Methodology Notes

Phase VX validated the Phase V prompt pattern (Claude advisory → agent prompt → Perplexity review) across both firmware infrastructure (v7.6.10.0/1) and dashboard-only (v7.6.10.4) workloads. The v7.6.10.4 session log documented 10 recommended prompt additions based on failure modes encountered. These feed directly into the Phase VY methodology audit.

---

_End of Phase VX results._
