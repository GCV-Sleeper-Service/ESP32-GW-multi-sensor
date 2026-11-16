# Multi-Phase Planning — Revision 2 (Operator Feedback Incorporated)

_Generated: 2026-05-07_
_Input: Operator feedback on Revision 1 (15 points + process questions)_
_Status: Supersedes Revision 1 where they conflict_

---

## Point 1: Retention Calculation Correction

### What I Got Wrong

My Rev 1 stated: "With 47 metrics and 512 KB history, each metric gets ~10 KB of NVS ≈ ~4 days retention." This was mathematically correct for a 47-metric scenario but deeply misleading — nobody deploys 47 persistent metrics on a C3. It was an unchecked theoretical edge case presented as if it were a practical limitation.

### What the Dashboard Screenshots Show

**WROOM (192.168.120.190):**
- 515 / 1080 hourly segments (~21.5 days of data)
- NVS entry usage: 5,154 / 16,128 (32.0%)
- Retained payload estimate: 117 KiB
- Payload free estimate: 395 KiB
- Segment size: 232 B (monolithic, 3 sensors)

**C3 (192.168.120.189):**
- 1,021 / 1080 hourly segments (~42.5 days of data)
- NVS entry usage: 10,214 / 16,128 (63.3%)
- Retained payload estimate: 231 KiB
- Payload free estimate: 281 KiB
- Segment size: 232 B (monolithic, 3 sensors)

These screenshots demonstrate that the current 512 KB partition stores 45 days of 3-sensor data using only ~63% of NVS entries at maximum capacity. The partition is far from full.

### Corrected Per-Device Retention Analysis

The per-device scheme stores each device's data separately. This uses more total NVS entries but gains flexibility (add/remove devices without data loss). Here are the **realistic** scenarios:

**On 640 KB partition (planned for 4 MB boards):**

| Devices | Metrics | Slots/device | Days/device | Notes |
|---|---|---|---|---|
| 4 (3T + 1P) | 8 | 508 | 21.2 | Current production config |
| 6 (4T + 1P + 1W) | 14 | 338 | 14.1 | Adding a weather station |
| 8 | 16-18 | 254 | 10.6 | Heavy deployment |

**On 480 KB partition (planned for C6 4MB binary-sensor satellite):**

| Devices | Metrics | Slots/device | Days/device | Notes |
|---|---|---|---|---|
| 6 binary sensors | 6 | 292 | 12.2 | With deduplication (Point 3), effective retention is far longer |
| 10 binary sensors | 10 | 175 | 7.3 | Same — deduplication makes this months of effective history |

**On 1 MB+ partition (8 MB and 16 MB boards):**

Retention exceeds 30 days per device for any realistic sensor count. Not a constraint.

### Key Insight

The per-device scheme trades ~50% retention vs. the monolithic scheme for the same partition size. This is the architectural cost of device independence. The planned partition increase from 512 KB to 640 KB (4 MB boards) partially compensates. For binary sensors, the deduplication scheme (Point 3) dramatically increases effective retention.

**Updated capacity study note:** My Rev 1 board selection guide should replace the "~19 days" retention column with per-device-scheme numbers using 640 KB partitions, not 512 KB.

---

## Point 2: Board Inventory and Partition Plan Update

### Updated Board Inventory

| Board | Flash | PSRAM | Role | Partition Plan |
|---|---|---|---|---|
| C3 SuperMini | 4 MB | None | Satellite (production) | 640 KB history NVS |
| WROOM-32D | 4 MB | None | Satellite (production) | 640 KB history NVS |
| S3 DevKitC N16R8 | 16 MB | 8 MB OPI | Aggregator (production) | 4 MB+ history NVS |
| S3 SuperMini | 4 MB | 2 MB quad | Satellite / light aggregator | 640 KB history NVS |
| **C6 SuperMini (4 MB)** | **4 MB** | None | **Binary-sensor satellite** | **480 KB history NVS** |
| **C6 (8 MB)** | **8 MB** | None | **Standard satellite** | **1 MB history NVS** |
| C5 WROOM-1U | 8 MB | 8 MB quad | Satellite (BLE+Zigbee) | 1 MB history NVS |

The C6 8 MB board is the intended "standard satellite" for multi-sensor/mixed deployments alongside the S3 SuperMini. The C6 4 MB board is specifically for binary-sensor deployments where the smaller partition and deduplication combine to provide months of effective retention.

### Updated Partition Table Plan

Four distinct partition layouts needed:

| Layout | Flash | OTA Slots | History NVS | Boards |
|---|---|---|---|---|
| 4 MB standard | 4 MB | 2 × 1,664 KB | 640 KB | C3, WROOM, S3 SuperMini |
| 4 MB C6-binary | 4 MB | 2 × 1,728 KB | 480 KB | C6 SuperMini (4 MB) |
| 8 MB | 8 MB | 2 × 3,072 KB | 1,024 KB | C6 (8 MB), C5 |
| 16 MB | 16 MB | 2 × 3,072 KB | 4,096 KB | S3 DevKitC |

The 4 MB standard layout trades 64 KB from each OTA slot (1,728 KB → 1,664 KB) to grow history from 512 KB to 640 KB. OTA headroom drops from ~299 KB to ~235 KB on C3 — still comfortable.

The C6 4 MB binary layout keeps the current OTA slot size (1,728 KB) but reduces history to 480 KB. This gives the C6 maximum OTA headroom (145 KB currently, unchanged) because its WiFi 6 binary is larger.

---

## Point 3: Binary Sensor Deduplication Storage Design

### Design: State-Change-Only Persistence

Binary sensors (leak, door/window, switch) should NOT persist periodic readings. A sensor reporting "no leak" every 5 seconds for 4 months generates 2+ million identical readings. Instead, persist only **state transitions**:

```
EventEntry {
  uint32_t epoch;       // when the state changed
  uint8_t  new_state;   // 0 or 1
  uint8_t  padding[3];  // alignment
}
// sizeof = 8 bytes (same as HistEntry)
```

**Storage model:** An `EventLog` replaces `HistoryBuffer` for binary metrics. Instead of a time-series ring buffer (96 entries × 8 B = 768 B), the event log stores up to N state transitions.

**Example — leak sensor from January to May:**

| Entry | Epoch | State | Meaning |
|---|---|---|---|
| 0 | Jan 1 00:00 | 0 | Initial state: no leak |
| 1 | May 1 14:32 | 1 | Leak detected |
| 2 | May 1 14:37 | 0 | Leak cleared |

Three entries = 24 bytes. A `HistoryBuffer` with hourly persistence would have used 2,880 entries (120 days × 24h) = 23,040 bytes for the same information.

**NVS persistence:** Binary device segments are much smaller than environmental device segments. A `DeviceSegment` for a single binary metric with deduplication needs only the event list, not the fixed-size `data[MAX_METRICS][POINTS_PER_SEGMENT]` arrays. This could be:

- Option A: Reuse `DeviceSegment` struct with `PERSIST_POINTS_PER_SEGMENT=1` for binary devices (wastes some header space but keeps code unified)
- Option B: Separate `BinaryDeviceSegment` struct optimized for state-change storage

**Recommendation:** Option A for Phase 7 (simplicity), with a note that Option B is a future optimization. The priority-tier retention budgeting already gives binary sensors a "normal" tier (fewer slots), and with deduplication, even a small number of slots provides months of effective history.

**Dashboard visualization:** The chart for a binary sensor shows a step function — horizontal lines at 0 or 1 with vertical transitions at state-change epochs. The business logic infers the state at any point in time by finding the most recent state-change before that timestamp.

**RAM cost saving:** A binary metric with `EventLog` instead of `HistoryBuffer`:
- `HistoryBuffer`: 768 B (96 entries × 8 B)
- `EventLog` (capacity 32 events): 256 B (32 × 8 B)
- Savings: 512 B per binary metric

With 6 binary sensors: 6 × 512 = 3,072 B saved. Meaningful on the C6 4 MB satellite where these sensors are intended.

---

## Point 4: RAM Window Reduction (24h → 2h) — Trade-off Analysis

### Current State

Each persistent metric has a `HistoryBuffer` with 96 entries (24h at 15-min intervals). Each entry is 8 bytes. Total: 768 bytes per metric.

### Proposed: Reduce to 2h (8 entries = 64 bytes)

| Metric | 24h (current) | 2h (proposed) | Savings |
|---|---|---|---|
| Per metric | 768 B | 64 B | 704 B |
| 6 metrics (3T + 1P) | 4,608 B | 384 B | 4,224 B |
| 12 metrics | 9,216 B | 768 B | 8,448 B |

### Advantages

1. **Significant RAM savings.** 4-8 KB freed on every board. On the WROOM (38 KB free heap), recovering 4 KB is ~11% of available heap. On the C3 (58 KB), it's ~7%.
2. **Scales better with sensor count.** Adding sensors costs 64 B each instead of 768 B. The "max persistent metrics" ceiling increases dramatically.
3. **NVS becomes the primary history store** — consistent mental model rather than the current RAM/NVS merge.

### Disadvantages

1. **Dashboard must load from NVS for anything older than 2h.** Currently the dashboard gets 24h of data entirely from RAM (fast, no NVS reads). With 2h RAM, showing 24h requires reading ~22h of NVS segments.
2. **NVS reads on every dashboard load.** Each page load or refresh triggers NVS reads. Currently the dashboard only reads NVS for the full history view, not the default 24h chart.
3. **Latency increase.** NVS reads are slow (~2-5 ms per segment). Loading 22 segments = ~50-100 ms. Not terrible but noticeable vs. instant RAM access.
4. **Flash wear.** More NVS reads per dashboard visit. NVS reads don't wear flash (only writes do), so this is actually not a concern. Correction: no disadvantage here.
5. **Increased vulnerability to BUG-082 pattern.** More NVS reads means more potential for large CSV construction in RAM. BUT — this is exactly what chunked streaming (Phase 7 Step v7.7.1.1) solves. After chunked streaming is implemented, this risk disappears.

### Dependency

The 2h reduction **requires chunked streaming to be implemented first**. Without chunked streaming, reducing the RAM window means the dashboard must build CSV from NVS on every load — triggering BUG-082 on boards with large history.

### Recommendation

Defer the RAM window reduction to a step AFTER chunked streaming (v7.7.1.1) is merged. Then implement it as an optional board-profile setting:

```yaml
# In board profile
history:
  ram_window_hours: 2    # default: 24
```

Non-PSRAM boards benefit most and should default to 2h. PSRAM boards can keep 24h since RAM isn't their bottleneck. This could be Phase 7 Step v7.7.2.x or a post-Phase 7 optimization.

---

## Point 5: BUG-082 Fix Priority — Export/Import First

Confirmed and already reflected in my recommended step order. The BUG-082 fix (chunked HTTP streaming for `/history/` endpoints) is Phase 7 Step v7.7.1.1 — the first implementation step after the measurement/research steps. This ensures existing history data can be exported from C3/WROOM boards before any persistence engine changes risk data format incompatibility.

The sequence is: export existing data via working chunked streaming → then implement the new per-device engine → then import data in the new format.

---

## Point 6: Unimplemented Recommendations → GitHub Issues

The 6 unimplemented recommendations in `CURRENT-STATE.md` need to be tracked as GitHub Issues:

| Recommendation | Proposed Issue Title | Labels |
|---|---|---|
| Health-check telemetry task (BUG-075/076) | "Add periodic health-check task logging stack HWM, heap, sockets, NVS stats" | `phase/7`, `type/firmware`, `risk/medium` |
| Monitor `nvs_get_stats()` for partition pressure | "Add NVS partition pressure monitoring to health-check task" | `phase/7`, `type/firmware`, `risk/low` |
| Monitor socket exhaustion via lwIP counters | "Add lwIP socket monitoring to health-check task" | `phase/7`, `type/firmware`, `risk/low` |
| ESPHome component defaults audit | "Audit ESPHome component defaults for hardcoded-too-small values" | `phase/7`, `type/firmware`, `risk/medium` |
| Show `min_free_heap` on dashboard | "Display min_free_heap instead of free_heap on dashboard" | `phase/7`, `type/dashboard`, `risk/low` |
| 10 prompt writing guide recommendations | "Implement 10 prompt production recommendations from v7.6.10.4 session" | `type/docs`, `risk/low` |

The first 4 issues map to Phase 7 Steps v7.7.0.0 and v7.7.1.0. The 5th maps to a Phase 7 dashboard step. The 6th is independent of Phase 7.

**Stale documents:** Each stale document needing rewrite should also get an issue:

| Document | Proposed Issue Title | Labels |
|---|---|---|
| `Docs/v7.7-implementation-plan.md` | "Rewrite Phase 7 implementation plan against current codebase" | `phase/7`, `type/docs`, `risk/high` |
| `Docs/v7.7-v7.8-persistence-architecture.md` | "Update Phase 7/8 architecture doc with measured values and current code structure" | `phase/7`, `type/docs`, `risk/medium` |

These issues get created during the post-session actions (see the big questions section below).

---

## Point 7: Version Numbering Update

Accepted. The operator's numbering convention:
- `.0` steps are research/measurement (no codebase changes, may not need version bump)
- Implementation steps start from `.1`
- Three sub-phases: v7.7.0.x (research), v7.7.1.x (core engine), v7.7.2.x (wire + migrate), v7.7.3.x (export/import + closure)

### Updated Phase 7 Step Table

| Step | Version | Content | Type | Rationale |
|---|---|---|---|---|
| Step 0a | v7.7.0.0 | ESPHome component defaults audit | Research | Proactive measurement, no code changes |
| Step 0b | v7.7.1.0 | Health-check telemetry task + measurement baseline | Implementation | Implements BUG-075/076 recommendations |
| Step 1 | v7.7.1.1 | Chunked HTTP streaming for `/history/` endpoints | Implementation | Fixes BUG-082 / #139 — production crash |
| Step 2 | v7.7.1.2 | Define per-device structs, key scheme, hash function | Implementation | Foundation — compile-time only |
| Step 3 | v7.7.1.3 | Per-device persist engine (write path) | Implementation | First NVS write path for new format |
| Step 4 | v7.7.1.4 | Per-device restore engine (boot path) + retention budget | Implementation | Boot restore is critical path |
| Step 5 | v7.7.2.1 | Wire new engine, storage stats v2, switchover | Implementation | Highest-risk moment — engine swap |
| Step 6 | v7.7.2.2 | v7→v8 one-time migration | Implementation | One-shot data migration |
| Step 7 | v7.7.2.3 | Per-device delete API + dashboard UI | Implementation | New endpoint + dashboard component |
| Step 8 | v7.7.3.1 | Per-device export/import | Implementation | New CSV format |
| Step 9 | v7.7.3.2 | Multi-device bundle export/import | Implementation | Round-trip data management |
| Step 10 | v7.7.3.3 | Full regression, old engine removal, phase closure | Closure | Cleanup and documentation |

Notes:
- v7.7.0.0 is research — no version bump needed, no PR with code changes
- v7.7.1.0 through v7.7.1.4 are the core engine sub-phase
- v7.7.2.1 through v7.7.2.3 are the integration sub-phase
- v7.7.3.1 through v7.7.3.3 are the export/import + closure sub-phase

---

## Point 8: Zigbee Sensor Discovery in Phase E

Updated. Phase E-b (sensor discovery) needs to cover both BLE and Zigbee:

**BLE discovery:** Passive scanning for ThermoPro advertisement packets. Filter by manufacturer data prefix. Present discovered MACs + signal strength.

**Zigbee discovery:** 802.15.4 network scan. The C6 and C5 have native Zigbee/Thread support via ESP-IDF's `esp_zigbee` stack. Zigbee device discovery uses the Zigbee coordinator joining process — the gateway opens the network for joining, Zigbee devices send association requests, and discovered devices are presented for selection.

Key difference: BLE sensors are passive (the gateway just listens to broadcasts), while Zigbee sensors require active pairing (the gateway must be a Zigbee coordinator or router). This means Zigbee discovery in Phase E-b is significantly more complex than BLE discovery.

**Updated Phase E-b scope:**

| Step | Scope |
|---|---|
| E-b.0 | BLE scan during portal: discover ThermoPro/BLE sensors, present MAC list |
| E-b.1 | Zigbee coordinator mode: open network for joining, discover Zigbee devices |
| E-b.2 | User selects sensors (BLE and/or Zigbee) from discovered list, saved to NVS |
| E-b.3 | Boot: read sensor config from NVS, generate runtime manifest |

---

## Point 9: Research Steps — No Version Bump

Confirmed. Steps designated as `.0` (research/measurement) do not bump the version number. They produce documentation and analysis only. The first version bump happens at the first implementation step.

Updated Phase E-a:

| Step | Version | Scope | Version bump? |
|---|---|---|---|
| E-a.0 | — | Research: ESPHome captive_portal internals | No |
| E-a.1 | v8.0.0.1 | NVS WiFi credential storage, AP mode boot check | Yes |
| E-a.2 | v8.0.0.2 | Portal HTML: WiFi form, device name, role selector | Yes |
| E-a.3 | v8.0.0.3 | Reboot-to-station after portal submission | Yes |
| E-a.4 | v8.0.0.4 | Factory reset endpoint | Yes |

---

## Point 10: TLS/Notifications — Board Capability Update

TLS (and therefore notifications) should be enabled **only** on PSRAM boards and C6.

### Updated Notification Capability Matrix

| Board | free_heap | TLS viable? | Notifications? | Rationale |
|---|---|---|---|---|
| C3 SuperMini | 58 KB | ❌ | No | 58 - 40 = 18 KB remaining (below WiFi minimum) |
| WROOM-32D | 38 KB | ❌ | No | Physically impossible (38 < 40) |
| C6 SuperMini (4 MB) | 150 KB | ✅ | **Yes** | 150 - 40 = 110 KB remaining |
| C6 (8 MB) | ~150 KB (est.) | ✅ | **Yes** | Same chip, more flash headroom |
| S3 DevKitC | 53 KB int + 8 MB PSRAM | ✅ | **Yes** | TLS from PSRAM |
| S3 SuperMini | 123 KB int + 2 MB PSRAM | ✅ | **Yes** | TLS from PSRAM |
| C5 WROOM-1U | 33 KB int + 8 MB PSRAM | ✅ | **Yes** | TLS from PSRAM (if BLE resolved) |

Compile-time guard: `#if defined(NOTIFICATIONS_ENABLED) && NOTIFICATIONS_ENABLED`. Only boards with sufficient resources get this flag set in their board profile. C3 and WROOM board profiles explicitly set `NOTIFICATIONS_ENABLED=0`.

---

## Point 11: MQTT Included in Phase 9

Confirmed. MQTT bridge is part of Phase 9 scope (not deferred). Updated step table:

| Step | Version | Scope | Version bump? |
|---|---|---|---|
| 9.0 | — | Research: InfluxDB line protocol, MQTT + ESPHome coexistence, esp_tls heap measurement | No |
| 9.1 | v9.0.0.1 | Cloud settings NVS schema + dashboard config UI | Yes |
| 9.2 | v9.0.0.2 | InfluxDB upload: esp_tls POST, hourly upload task | Yes |
| 9.3 | v9.0.1.1 | Store-and-forward: ring buffer for unsent segments | Yes |
| 9.4 | v9.0.2.1 | MQTT bridge: ESPHome MQTT component integration | Yes |
| 9.5 | v9.0.3.1 | Dashboard cloud status indicator, upload history | Yes |

---

## Point 14: Phase E Timing

Confirmed: Phase E comes after Phase 7. The captive portal doesn't depend on per-device persistence for its MVP (WiFi provisioning), but sensor discovery (E-b) does need the per-device NVS infrastructure. Running E after 7 also means the portal can immediately offer the new storage stats and per-device management features.

---

## The Big Questions

### Q1: Are the phases/steps aligned with Docs/development-process-guide.md?

Yes, with specific mappings:

| Process Guide Requirement | How This Planning Output Aligns |
|---|---|
| §2.1 Pre-step checklist (read CURRENT-STATE.md) | Every step's agent prompt will include CURRENT-STATE.md as first mandatory read |
| §2.2 Agent execution (branch + draft PR) | Steps produce PRs linked to Phase 7 milestone |
| §2.3 Device testing (upload + curl smoke) | Steps modifying firmware include device test gates |
| §2.4 Review pipeline (5 reviewers) | Each step's PR goes through the review pipeline |
| §2.5 Step deliverables (CURRENT-STATE.md update, changelog, audit) | Included in every step's acceptance criteria |
| §3 Prompt production (agent prompt + two-step + handoff) | The prompt-production session after this planning session produces these |
| §3.2 Checkpoint authoring (grep queries, stop-don't-fix) | Agent prompts use function/identifier anchors, not line numbers |

**One gap:** The development process guide specifies "recommendation routing" — every recommendation becomes either a GitHub Issue or a CURRENT-STATE.md entry. My Rev 1 planning output produced recommendations but didn't route them. This revision (Point 6) adds the issue creation plan.

### Q2: Where do these planning documents live?

Per `Docs/multi-phase-session-run-instructions.md` §4.1:

```
Docs/phase-7-review-and-rewrite.md          (Deliverable 1 — Phase 7 review + rewritten step table)
Docs/phase-E-captive-portal-plan.md          (Deliverable 2 — captive portal scoping)
Docs/phase-8-notifications-plan.md           (Deliverable 3a — notifications)
Docs/phase-9-cloud-upload-plan.md            (Deliverable 3b — cloud)
Docs/phase-10-dashboard-ui-plan.md           (Deliverable 4 — dashboard enhancements)
Docs/board-selection-guide-expansion.md      (Board capability matrix — supplements existing guide)
```

Architectural decisions from this session get added to `Docs/decisions/decision-log.md`:

| Date | ID | Decision | Rationale Link |
|---|---|---|---|
| 2026-05-07 | PLAN-001 | Phase 7 reordering: chunked streaming before persistence engine (BUG-082 priority) | `Docs/phase-7-review-and-rewrite.md` |
| 2026-05-07 | PLAN-002 | Binary sensor deduplication: state-change-only persistence | `Docs/phase-7-review-and-rewrite.md` §binary-sensors |
| 2026-05-07 | PLAN-003 | TLS/notifications only on PSRAM + C6 boards | `Docs/phase-8-notifications-plan.md` |
| 2026-05-07 | PLAN-004 | Four partition table layouts (4MB std, 4MB C6, 8MB, 16MB) | `Docs/phase-7-review-and-rewrite.md` §partitions |
| 2026-05-07 | PLAN-005 | Phase ordering: 7 → E → 8 → 9 → 10 | `Docs/phase-7-review-and-rewrite.md` §ordering |
| 2026-05-07 | PLAN-006 | Version numbering: .0 = research (no bump), .1+ = implementation | `Docs/phase-7-review-and-rewrite.md` §versioning |
| 2026-05-07 | PLAN-007 | MQTT bridge included in Phase 9 (not deferred) | `Docs/phase-9-cloud-upload-plan.md` |

### Q3: GitHub Issues, Milestones, and Discussions Tracking

Here's the full tracking plan. This should be executed as a post-session action (the prompt for it is in Q5 below).

**Milestones to create:**

```bash
gh milestone create "Phase 7 — Per-Device Persistence" \
  --description "Chunked streaming (BUG-082), health-check telemetry, per-device NVS, export/import v2" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor

gh milestone create "Phase E — Captive Portal" \
  --description "WiFi provisioning, runtime role detection, sensor discovery" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor

gh milestone create "Phase 8 — Notifications" \
  --description "Telegram, ntfy.sh, threshold-based alerts" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor

gh milestone create "Phase 9 — Cloud Upload" \
  --description "InfluxDB Cloud, MQTT bridge, store-and-forward" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor
```

**Labels to create** (if not already present):

```bash
for label in "phase/7" "phase/E" "phase/8" "phase/9" "phase/10" \
  "type/firmware" "type/dashboard" "type/docs" "type/tests" "type/infra" \
  "type/planning" "risk/high" "risk/medium" "risk/low" \
  "status/review-in-progress" "status/device-test-needed" "status/blocked"; do
  gh label create "$label" --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor 2>/dev/null
done
```

**Issues to create for unimplemented recommendations (Point 6):**

8 issues total — 6 from unimplemented recommendations + 2 for stale documents. See the table in Point 6 above for titles and labels.

**Issues to create for Phase 7 steps** (one per step, linked to milestone):

Each Phase 7 step gets a tracking issue at planning time. The issue is closed when the step's PR merges. This gives the milestone progress bar meaning.

**GitHub Discussion for this planning session:**

Create a Discussion (category: "Planning") titled "Multi-Phase Planning Session Output — 2026-05-07" containing:
- Link to the committed planning documents
- Summary of operator decisions (Points 1-15)
- Link to Phase 7 milestone
- Status: "Planning complete. Next: prompt production for v7.7.0.0."

### Q4: Prompt Production Deliverable

Yes — one of the key outputs of this planning session is a **prompt-production prompt** for a fresh Claude session. That session reads the planning output and produces agent prompt bundles for Phase 7 steps.

The prompt-production session would read:
1. `CURRENT-STATE.md` (updated after this session's docs are committed)
2. `Docs/phase-7-review-and-rewrite.md` (the rewritten Phase 7 plan from this session)
3. `Docs/writing-guide/methodology.md`
4. `Docs/development-process-guide.md` (§3 — prompt production)
5. `prompts/handoff/methodology-audit-findings-for-planning.md`

And produces for the first batch (Steps v7.7.0.0 and v7.7.1.0):
- `prompts/phase7/v7.7.0.0-agent-prompt.md` (research — component defaults audit)
- `prompts/phase7/v7.7.1.0-agent-prompt-gpt-codex.md` (health-check telemetry task)
- `prompts/phase7/v7.7.1.0-claude-two-step.md` (agent section + reviewer checklist)
- `prompts/handoff/phase7/session-handoff-v7.7.1.0.md`

I can produce the prompt-production prompt as part of this session's deliverables.

### Q5: Troubleshooting Checklist Verification

Checking my output against the troubleshooting items in `Docs/multi-phase-session-run-instructions.md` §5:

| Check | Status | Evidence |
|---|---|---|
| **Stale analysis?** (references `dashboard/sensor_history_multi.h` as source, missing `authFetch()`, pre-Phase-V heap) | ✅ Clear | My Rev 1 correctly identifies `firmware/core/` as the source, references `authFetch()` throughout, uses measured heap values from board-measurement-log |
| **Output limit mid-deliverable?** | ✅ Clear | Full output delivered in one response |
| **Context window saturation?** (later deliverables less detailed) | ⚠️ Partially applicable | Deliverable 4b (standalone role / Phase 10) was intentionally lighter because the analysis concluded it's not worth a full phase. Phase 9 and Phase 10 scoping is less detailed than Phase 7/E/8 — acceptable given their lower priority |
| **Measurement data mismatch?** | ✅ Clear | All heap numbers match `board-measurement-log-v7.6.10.md` exactly |
| **Decision log contradiction?** | ✅ Clear | No recommendations contradict existing decision log entries. POST body handling, deferred task pattern, generated file rules — all respected |

**One issue I should flag:** My Rev 1 retention calculation ("4 days for 47 metrics") was an unchecked assumption that failed the reality check against your dashboard screenshots. This is exactly the class of error the assumption audit gate was designed to catch. I should have run the numbers against the current NVS utilization data rather than projecting from a theoretical maximum. The corrected analysis in Point 1 above uses your actual measurements as the baseline.

---

## Deliverable: Post-Session Action Prompt

This prompt is designed to be run by the operator (or pasted to a lightweight agent) to create the GitHub infrastructure:

```bash
#!/bin/bash
# post-planning-session.sh — Run after committing planning documents
# Creates milestones, labels, issues, and discussion

REPO="GCV-Sleeper-Service/ESP32-GW-multi-sensor"

# === Milestones ===
gh milestone create "Phase 7 — Per-Device Persistence" \
  --description "v7.7.0.0–v7.7.3.3: Chunked streaming (BUG-082), health-check telemetry, per-device NVS engine, export/import v2" \
  --repo "$REPO"

gh milestone create "Phase E — Captive Portal" \
  --description "v8.0.x: WiFi provisioning, runtime role detection, BLE+Zigbee sensor discovery" \
  --repo "$REPO"

gh milestone create "Phase 8 — Notifications" \
  --description "v8.1.x: Telegram, ntfy.sh, threshold-based alerts (PSRAM + C6 boards only)" \
  --repo "$REPO"

gh milestone create "Phase 9 — Cloud Upload" \
  --description "v9.0.x: InfluxDB Cloud, MQTT bridge, store-and-forward" \
  --repo "$REPO"

# === Labels ===
for label in "phase/7" "phase/E" "phase/8" "phase/9" "phase/10" \
  "type/firmware" "type/dashboard" "type/docs" "type/tests" "type/infra" \
  "type/planning" "risk/high" "risk/medium" "risk/low" \
  "status/review-in-progress" "status/device-test-needed" "status/blocked"; do
  gh label create "$label" --repo "$REPO" 2>/dev/null || true
done

# === Issues: Unimplemented recommendations ===
gh issue create --title "Add periodic health-check task (BUG-075/076 recommendation)" \
  --body "From BUG-075/076 postmortem. Log stack HWM, heap stats, socket usage, NVS stats periodically. Target: Phase 7 Step v7.7.1.0." \
  --label "phase/7,type/firmware,risk/medium" --milestone "Phase 7 — Per-Device Persistence" --repo "$REPO"

gh issue create --title "Monitor nvs_get_stats() for partition pressure" \
  --body "From BUG-075/076 postmortem. Add to health-check task. Target: Phase 7 Step v7.7.1.0." \
  --label "phase/7,type/firmware,risk/low" --milestone "Phase 7 — Per-Device Persistence" --repo "$REPO"

gh issue create --title "Monitor socket exhaustion via lwIP counters" \
  --body "From BUG-075/076 postmortem. Add to health-check task. Target: Phase 7 Step v7.7.1.0." \
  --label "phase/7,type/firmware,risk/low" --milestone "Phase 7 — Per-Device Persistence" --repo "$REPO"

gh issue create --title "Audit ESPHome component defaults for hardcoded values" \
  --body "From BUG-075/076 postmortem. Proactive measurement before Phase 7 implementation. Target: Phase 7 Step v7.7.0.0." \
  --label "phase/7,type/firmware,risk/medium" --milestone "Phase 7 — Per-Device Persistence" --repo "$REPO"

gh issue create --title "Display min_free_heap instead of free_heap on dashboard" \
  --body "From Phase V closure. Deferred post-v7.6.9.0. Target: Phase 7 dashboard step." \
  --label "phase/7,type/dashboard,risk/low" --milestone "Phase 7 — Per-Device Persistence" --repo "$REPO"

gh issue create --title "Implement 10 prompt production recommendations from v7.6.10.4" \
  --body "From v7.6.10.4 session log. Writing guide updates." \
  --label "type/docs,risk/low" --repo "$REPO"

# === Issues: Stale documents ===
gh issue create --title "Rewrite Phase 7 implementation plan against current codebase" \
  --body "Docs/v7.7-implementation-plan.md is from 2026-03-19. References stale paths 19+ times. Must be rewritten before Phase 7 execution. Produced during prompt-production session." \
  --label "phase/7,type/docs,risk/high" --milestone "Phase 7 — Per-Device Persistence" --repo "$REPO"

gh issue create --title "Update Phase 7/8 architecture doc with measured values" \
  --body "Docs/v7.7-v7.8-persistence-architecture.md Section 15 uses pre-Phase-V estimates. Current measured values in board-measurement-log-v7.6.10.md supersede." \
  --label "phase/7,type/docs,risk/medium" --milestone "Phase 7 — Per-Device Persistence" --repo "$REPO"

# === Issues: Phase 7 steps ===
for step in "v7.7.0.0: ESPHome component defaults audit (research)" \
  "v7.7.1.0: Health-check telemetry task + measurement baseline" \
  "v7.7.1.1: Chunked HTTP streaming for history endpoints (BUG-082)" \
  "v7.7.1.2: Per-device structs, key scheme, hash function" \
  "v7.7.1.3: Per-device persist engine (write path)" \
  "v7.7.1.4: Per-device restore engine (boot path) + retention budget" \
  "v7.7.2.1: Wire new engine, storage stats v2, switchover" \
  "v7.7.2.2: v7-to-v8 one-time migration" \
  "v7.7.2.3: Per-device delete API + dashboard UI" \
  "v7.7.3.1: Per-device export/import" \
  "v7.7.3.2: Multi-device bundle export/import" \
  "v7.7.3.3: Full regression, old engine removal, phase closure"; do
  gh issue create --title "Phase 7: $step" \
    --label "phase/7,type/firmware" --milestone "Phase 7 — Per-Device Persistence" --repo "$REPO"
done

echo "Done. Created milestones, labels, and issues."
echo "Next: commit planning documents and create Discussion."
```

---

## Deliverable: Prompt-Production Prompt (for Fresh Session)

This prompt is pasted into a fresh Claude Opus session to produce the Phase 7 agent prompts:

```markdown
# Phase 7 Prompt Production Session

You are the prompt producer for the ESP32-GW Multi-Sensor Gateway project.
Your job is to read the planning output and produce agent prompt bundles for
Phase 7 steps v7.7.0.0 and v7.7.1.0.

## Instructions

1. Clone the repo: `git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`
2. Read these files in order:
   - `CURRENT-STATE.md`
   - `Docs/phase-7-review-and-rewrite.md` (the rewritten Phase 7 plan)
   - `Docs/development-process-guide.md` (§2-3 for execution and prompt format)
   - `Docs/writing-guide/methodology.md` (the 10-section prompt anatomy)
   - `prompts/handoff/methodology-audit-findings-for-planning.md`
   - `prompts/prompt-index-and-workflow.md` (Critical Rules table)
   - `firmware/core/config.h`, `firmware/core/data-model.h` (for code context)

3. Produce for v7.7.0.0 (ESPHome component defaults audit — research step):
   - Agent prompt: `prompts/phase7/v7.7.0.0-research-prompt.md`
   - This is a research step (no code changes). The agent audits ESPHome
     component source for hardcoded defaults that could surprise the project.
   - Output: a document listing defaults, risk assessment, recommended overrides.

4. Produce for v7.7.1.0 (health-check telemetry task):
   - Agent prompt: `prompts/phase7/v7.7.1.0-agent-prompt-gpt-codex.md`
   - Two-step prompt: `prompts/phase7/v7.7.1.0-claude-two-step.md`
   - Session handoff: `prompts/handoff/phase7/session-handoff-v7.7.1.0.md`
   - This step adds a periodic FreeRTOS task that logs:
     stack HWM, heap stats (free, min_free, internal), socket usage, NVS stats
   - Target: `firmware/core/health-check.h` (new fragment)
   - Must update `assemble-sensor-history.sh` to include the new fragment
   - Must follow the 10-section prompt anatomy from the writing guide

5. If context allows, also produce for v7.7.1.1 (chunked HTTP streaming — BUG-082 fix).
   This is the highest-priority implementation step.

## Constraints
- All file paths must be verified against the cloned repo (grep, not memory)
- Checkpoints use queries, not assertions (grep -c, not "line N should contain")
- Acceptance criteria include CURRENT-STATE.md update and changelog entry
- The prompt-production session does NOT produce code — it produces prompts
  that coding agents will execute
```

This prompt goes into a fresh Claude session after the planning documents are committed to the repo.

---

_End of Revision 2._
