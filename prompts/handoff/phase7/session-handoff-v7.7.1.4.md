# Session Handoff — v7.7.1.4: Per-Device Restore Engine + Retention Budget

_Date: 2026-05-08_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.7.1.3 on `main`. Per-device persist engine writing to NVS (dual-write alongside old engine)._

---

## Project State Summary

**v7.7.1.3 is complete.** `persist_device_segment_()` and `persist_all_devices_v2()` are writing per-device segments to NVS every hour alongside the old `persist_hourly_segment()`. Dual-write verified on C3 — "V2 persist complete" in serial logs. Meta stored with `DEV_PERSIST_PROVISIONAL_SLOTS = 360` (provisional, replaced by budget in this step).

**This step completes the per-device persistence engine.** After this step, the full write→restore→budget pipeline is operational. The old engine continues to run alongside (dual-write + dual-restore) until the migration step in v7.7.2.x removes it.

### Open issues entering v7.7.1.4

| Issue | Severity | Notes |
|---|---|---|
| BUG-084 | High | Non-PSRAM boards crash under 8 concurrent HTTP connections. |
| #137 | Low | Board-type SVG diagrams. Cosmetic. |
| A-004 | Medium | C5 WROOM-1U BLE non-functional. |
| C6 flash | Medium | C6 4MB uses 91.6% OTA partition. |

No new issues discovered during v7.7.1.3 that affect this step.

---

## Phase 7 Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.7.0.0 | ESPHome component defaults audit | Complete |
| v7.7.1.0 | Health-check telemetry task | Complete (PR #225) |
| v7.7.1.1 | Chunked HTTP streaming (BUG-082 fix) | Complete (PR #226) |
| v7.7.1.2 | Per-device structs, key scheme, hash | Complete |
| v7.7.1.3 | Per-device persist engine (write path) | Complete |
| **v7.7.1.4** | **Per-device restore engine + retention budget** | **⬅️ Current** |

---

## v7.7.1.4 Scope

### What this step does

1. Adds `RetentionBudget` struct and `calculate_retention_budgets_()` function to `nvs-persistence.h`
   - Priority tiers: high (70%), normal (20%), low (10%)
   - Uses `find_partition_size_bytes_()` for partition size discovery
   - 30% space reserved for old engine coexistence during dual-write phase
   - Slot cap at 999 (3-digit NVS key suffix limit)
   - Tier redistribution when a tier has no devices
2. Adds `restore_device_history_v2_()` to `nvs-persistence.h`
   - Reads per-device segments written by v7.7.1.3's persist functions
   - Restores into RAM `HistoryBuffer` (the same buffer the old engine uses)
   - Chronological restore order (oldest segment first)
   - Hash collision detection via `device_id` comparison
   - Budget change handling: `meta.max_slots` updated, `valid_segments` capped
   - `maybe_yield_nvs_scan_()` between device restores AND between segment reads (Rule 61)
3. Updates `persist_device_segment_()` to use calculated budgets instead of `DEV_PERSIST_PROVISIONAL_SLOTS`
4. Wires `restore_device_history_v2_()` into `on_boot` lambda (dual-restore alongside old `restore_from_nvs()`)

### What this step does NOT do

- No removal of old SegmentSnapshot engine (v7.7.2.x migration)
- No new HTTP endpoints (storage-stats endpoint is a later step)
- No changes to web-handler.h (chunked streaming untouched)
- No new firmware fragments (count stays at 9)
- No changes to dashboard code
- No changes to data-model.h structs (only bump-version.sh comment update)
- No EventLog persist/restore (binary sensors not in current manifest)
- No import/export v2

### Architecture references

- `Docs/v7.7-v7.8-persistence-architecture.md` §7 — retention budgeting, priority tiers, scenarios
- `Docs/v7.7-v7.8-persistence-architecture.md` §9 — boot restore flow
- `Docs/multi-phase-planning-session-summary.md` Point 1 — corrected retention numbers for 640 KB partition

### Files modified

- `firmware/core/nvs-persistence.h` — budget calculator, v2 restore, persist budget integration
- `firmware/esp32-c3-multi-sensor.yaml` — `on_boot` lambda wiring for dual-restore
- `Docs/changelog.md` — v7.7.1.4 entry
- `CURRENT-STATE.md` — version, "What Just Shipped", "What's Next"
- `VERSION` + bump-version.sh artifacts
- Session log `Docs/session-log-<DATE>-v7.7.1.4.md`
- Consolidated audit `prompts/phase7/v7.7.1.4-PR<NN>-consolidated-audit-and-lessons.md`

### Device testing required

**YES — CRITICAL.** This step modifies the boot path. `restore_device_history_v2_()` runs during `on_boot`. A crash here bricks the board until reflash.

Minimum device testing:
- Flash C3 SuperMini (192.168.120.189)
- Verify board boots (responds to `/api/status` within 120s)
- Verify `/api/status/full` returns version 7.7.1.4
- Verify `/history/office/temp` returns CSV data (chunked streaming still works)
- If board doesn't respond within 120s: capture serial log and STOP

---

## Codebase state entering v7.7.1.4

### Board fleet (verified from CURRENT-STATE.md)

| Board | IP | Chip | Role |
|-------|-----|------|------|
| C3 SuperMini | 192.168.120.189 | ESP32-C3 | Satellite (production) |
| WROOM-32D | 192.168.120.170 | ESP32 | Satellite (production) |
| S3 DevKitC N16R8 | 192.168.120.191 | ESP32-S3 | Aggregator (production) |

Credentials: `ESPadmin` / `ESPpass100`

### Functions available from prior steps

From v7.7.1.2:
- `device_id_hash_()` — FNV-1a hash of device ID string
- `make_device_meta_key_()` — produces `dm_HHHHHHHH` (≤11 chars)
- `make_device_segment_key_()` — produces `ds_HHHHHHHH_NNN` (≤15 chars)
- `DeviceHistoryMeta`, `DeviceSegmentHeader`, `DeviceSegment` structs
- `EventLog`, `EventEntry` for binary sensors

From v7.7.1.3:
- `persist_device_segment_()` — writes one `DeviceSegment` blob to NVS
- `persist_all_devices_v2()` — iterates all devices, persists segments, dual-write with old engine
- `load_device_meta_()` / `save_device_meta_()` — read/write `DeviceHistoryMeta`
- `DEV_PERSIST_PROVISIONAL_SLOTS = 360` — provisional slot limit (replaced by budget in this step)

Already existing:
- `find_partition_size_bytes_()` — reads partition size from partition table
- `restore_from_nvs()` — old restore function (untouched, dual-restore alongside v2)
- `maybe_yield_nvs_scan_()` — yield between NVS operations (Rule 61)
- `HISTORY_PARTITION_LABEL` — partition label constant

### Fragment count

Assembly pipeline expects **9 fragments**. This step adds NO new fragments.

### Key design decisions for this step

| ID | Decision | Source |
|----|----------|--------|
| PLAN-001 | Priority tiers: high/normal/low with 70/20/10 default shares | Architecture doc §7.2 |
| PLAN-003 | 30% space reserved for old engine during dual-write coexistence | Planning session Point 1 |
| PLAN-005 | Slot cap at 999 (3-digit NVS key suffix) | Architecture doc §6 |
| ARCH-001 | Per-device persistence replaces monolithic SegmentSnapshot | Architecture doc §1-4 |

---

## Pre-merge Checklist for v7.7.1.4

- [ ] Read the agent prompt completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates (A, B) verified
- [ ] All acceptance criteria in §7 met
- [ ] ⛔ PRE-PR GATE in §8 passes
- [ ] **Device testing performed and board responds (CRITICAL)**
- [ ] **In-PR deliverables (all committed to branch before marking ready):**
  - [ ] CURRENT-STATE.md updated (mandatory — version, What Just Shipped)
  - [ ] Changelog entry added
  - [ ] Session log created with device test curl output (Rule 63)
  - [ ] Consolidated audit produced
- [ ] PR body references Phase 7 step tracking issue for v7.7.1.4

---

## Critical Rules Relevant to v7.7.1.4

| # | Rule | Why Relevant |
|---|------|-------------|
| 2 | Use bump-version.sh | Version bump |
| 11 | maybe_yield_nvs_scan_ in loops | Restore loop reads many segments |
| 40 | Deferred task for HTTP handlers | NOT applicable: restore runs from on_boot, not httpd. But budget recalculation during persist IS on main loop, not httpd. |
| 58 | Edit fragments, not assembled artifact | nvs-persistence.h is a fragment |
| 61 | maybe_yield between NVS operations | Called between device restores and between segment reads |
| 62 | Assembly order unchanged | No new fragments |
| 63 | Session log is pre-merge acceptance criterion | Mandatory — with device test evidence |
| 64 | Checkpoint greps mechanically derived | All greps from code blocks |
| 67 | Binary sensors use EventLog | EventLog persist/restore NOT in this step (no binary sensors in manifest) |

---

## Risk: HIGH — boot-path restore, budget affects data lifetime

**Primary risk:** Boot crash. `restore_device_history_v2_()` runs during `on_boot`. If the restore reads a corrupted NVS blob, dereferences null, or exceeds stack, the board crashes on every boot until reflashed. Mitigated by defensive checks on `nvs_get_blob` return values, `meta.magic` validation, and `meta.valid_segments <= max_slots` capping.

**Secondary risk:** Budget miscalculation. If the budget calculator produces 0 slots for a device, that device's history becomes write-only (persisted but never restored). If it produces too many slots, NVS fills up and other devices lose space. Mitigated by the architecture doc's scenario tables (verified math) and by the 999-slot cap.

**Tertiary risk:** Hash collision. Two device IDs with the same FNV-1a hash would share NVS key space. The `strncmp(meta.device_id, devices[d].id)` check in restore prevents silent data corruption — a hash collision is detected and the segment is skipped. Collision probability for 20 devices: 5 × 10⁻⁸ (negligible).

**Device testing is MANDATORY.** Agent must flash and verify boot before marking PR ready.

---

## Context That Carries Forward to v7.7.2.x

- Per-device persistence engine is fully operational (write + restore + budget)
- Old SegmentSnapshot engine continues running alongside (dual-write + dual-restore)
- v7.7.2.x implements the migration step: old engine removal, data migration from `seg_NNN` keys to `ds_HHHHHHHH_NNN` keys
- The `/api/storage-stats` endpoint (architecture doc §7.5) is NOT implemented yet — deferred to a later step
- `DEV_PERSIST_PROVISIONAL_SLOTS` constant remains but is no longer the primary allocation (budget calculator overrides it)
- Fragment count is 9 — no new fragments added
- All in-PR deliverables pattern: consolidated audit and session log committed to branch
- Logger level is INFO with per-tag suppressors — must be maintained

---

_End of session handoff document._
