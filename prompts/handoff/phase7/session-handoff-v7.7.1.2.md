# Session Handoff — v7.7.1.2: Per-Device Structs, Key Scheme, Hash Function

_Date: 2026-05-08_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.7.1.1 on `main`. Chunked HTTP streaming deployed. BUG-082 resolved._

---

## Project State Summary

**v7.7.1.1 is complete.** History endpoints now stream CSV via `httpd_resp_send_chunk()`. BUG-082 is resolved — dashboards work on all boards regardless of NVS history size. Heap improvements on C3: `min_free` up 18 KB.

**This step is purely additive.** No runtime behavior changes. Define the structs and helpers that v7.7.1.3 and v7.7.1.4 will use for the per-device persistence engine.

### v7.7.1.1 device validation snapshot (C3)

| Metric | v7.7.1.0 baseline | v7.7.1.1 observed | Delta |
|---|---|---|---|
| `heap_free` | 39,704 B | 52,080 B | +12,376 B |
| `min_free` | 29,776 B | 48,096 B | +18,320 B |
| `httpd_stack_wm` | 12,932 B | 11,976 B | -956 B |
| `hc_stack_wm` | 2,176 B | 2,308 B | +132 B |

### Open issues entering v7.7.1.2

| Issue | Severity | Notes |
|---|---|---|
| BUG-084 | High | Non-PSRAM boards crash under 8 concurrent HTTP connections. |
| #137 | Low | Board-type SVG diagrams. Cosmetic. |
| A-004 | Medium | C5 WROOM-1U BLE non-functional. |
| C6 flash | Medium | C6 4MB uses 91.6% OTA partition. |

No new issues discovered during v7.7.1.1 that affect this step.

---

## Phase 7 Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.7.0.0 | ESPHome component defaults audit (research) | Complete |
| v7.7.1.0 | Health-check telemetry task | Complete (PR #225) |
| v7.7.1.1 | Chunked HTTP streaming (BUG-082 fix) | Complete (PR #226) |
| **v7.7.1.2** | **Per-device structs, key scheme, hash function** | **⬅️ Current** |
| v7.7.1.3 | Per-device persist engine (write path) | Pending |
| v7.7.1.4 | Per-device restore engine + retention budget | Pending |

---

## v7.7.1.2 Scope

### What this step does

1. Adds `DeviceHistoryMeta` struct to `firmware/core/data-model.h` (36 bytes — per-device ring buffer state)
2. Adds `DeviceSegmentHeader` + `DeviceSegment` structs (226 bytes — per-device hourly segment)
3. Adds `EventLog` class + `EventEntry` struct for binary sensors (168 bytes — state-change dedup, Rule 67)
4. Adds `device_id_hash_()` FNV-1a hash function to `firmware/core/nvs-persistence.h`
5. Adds `make_device_meta_key_()` and `make_device_segment_key_()` NVS key helpers

### What this step does NOT do

- No runtime wiring — no persist calls, no restore calls, no dashboard integration
- No new firmware fragments (count stays at 9)
- No new HTTP endpoints
- No changes to web-handler.h (chunked streaming untouched)
- No changes to the old SegmentSnapshot engine
- No changes to the C3 YAML template
- No device testing needed (no runtime changes to test)

### Architecture references

- `Docs/v7.7-v7.8-persistence-architecture.md` §5 — struct definitions
- `Docs/v7.7-v7.8-persistence-architecture.md` §6 — NVS key scheme, FNV-1a hash
- `Docs/phase-V-capacity-study.md` §6 — EventLog design
- Decision PLAN-002 — binary sensors use EventLog, not HistoryBuffer

### Files modified

- `firmware/core/data-model.h` — new structs and EventLog class
- `firmware/core/nvs-persistence.h` — new key helper functions
- `Docs/changelog.md` — v7.7.1.2 entry
- `CURRENT-STATE.md` — version, "What Just Shipped", "What's Next"
- `VERSION` + bump-version.sh artifacts
- Session log `Docs/session-log-<DATE>-v7.7.1.2.md`
- Consolidated audit `prompts/phase7/v7.7.1.2-PR<NN>-consolidated-audit-and-lessons.md`

---

## Codebase state entering v7.7.1.2

### Board fleet (verified from CURRENT-STATE.md)

| Board | IP | Chip | Role |
|-------|-----|------|------|
| C3 SuperMini | 192.168.120.189 | ESP32-C3 | Satellite (production) |
| WROOM-32D | 192.168.120.170 | ESP32 | Satellite (production) |
| S3 DevKitC N16R8 | 192.168.120.191 | ESP32-S3 | Aggregator (production) |

Credentials: `ESPadmin` / `ESPpass100`

### Logger level (do not revert)

`firmware/esp32-c3-multi-sensor.yaml` has `logger.level: INFO` with per-tag suppressors. This is intentional for HEALTH: telemetry.

### Fragment count

Assembly pipeline expects **9 fragments**. This step adds NO new fragments.

### Key design decisions for this step

| ID | Decision | Source |
|----|----------|--------|
| ARCH-001 | Per-device persistence replaces monolithic SegmentSnapshot | Architecture doc §1-4 |
| ARCH-002 | FNV-1a hash for NVS keys, 15-char limit | Architecture doc §6 |
| PLAN-002 | Binary sensors use EventLog (state-change dedup) | Planning session Point 3 |

---

## Pre-merge Checklist for v7.7.1.2

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates (A, B) verified
- [ ] All acceptance criteria in §7 met
- [ ] ⛔ PRE-PR GATE in §8 passes
- [ ] **In-PR deliverables (all committed to branch before marking ready):**
  - [ ] CURRENT-STATE.md updated (mandatory — version, What Just Shipped)
  - [ ] Changelog entry added
  - [ ] Session log created (Rule 63)
  - [ ] Consolidated audit produced
- [ ] PR body references Phase 7 step tracking issue for v7.7.1.2

---

## Critical Rules Relevant to v7.7.1.2

| # | Rule | Why Relevant |
|---|------|-------------|
| 2 | Use bump-version.sh | Version bump |
| 58 | Edit fragments, not assembled artifact | data-model.h and nvs-persistence.h are fragments |
| 62 | Assembly order unchanged | No new fragments |
| 63 | Session log is pre-merge acceptance criterion | Mandatory |
| 64 | Checkpoint greps mechanically derived | All greps from code blocks |
| 67 | Binary sensors use EventLog, not HistoryBuffer | EventLog struct added |

---

## Risk: LOW — additive definitions only

**Primary risk:** Struct size mismatch with architecture doc. Mitigated by explicit sizeof comments and compilation verification.

**Secondary risk:** FNV-1a hash collisions for current device IDs. Mitigated by collision probability analysis in architecture doc §6 (5 × 10⁻⁸ for 20 devices). The `DeviceHistoryMeta` also stores the full device_id for collision detection at restore time.

**No device testing needed.** This step adds definitions only — no runtime behavior to test.

---

## Context That Carries Forward to v7.7.1.3

- `DeviceHistoryMeta`, `DeviceSegment`, `EventLog` structs are defined and compile-verified
- `device_id_hash_()`, `make_device_meta_key_()`, `make_device_segment_key_()` are available
- The old SegmentSnapshot engine is untouched and continues operating
- v7.7.1.3 will implement `persist_device_segment_()` and `persist_all_devices_v2()` using these definitions
- Fragment count is 9 — no new fragments added
- Logger level is INFO with per-tag suppressors — must be maintained
- All in-PR deliverables pattern established — consolidated audit and session log are IN the PR

---

_End of session handoff document._
