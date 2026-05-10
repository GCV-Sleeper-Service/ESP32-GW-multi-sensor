# Session Handoff — v7.7.1.3: Per-Device Persist Engine (Write Path)

_Date: 2026-05-08_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.7.1.2 on `main`. Per-device structs and key helpers defined._

---

## Project State Summary

**v7.7.1.2 is complete.** `DeviceHistoryMeta`, `DeviceSegment`, `EventLog` structs and FNV-1a key helpers are defined. No runtime wiring yet.

**This step implements the write path.** Per-device segments are written to NVS alongside the old persist engine (dual-write). The old engine continues to be the restore source until v7.7.1.4.

### Open issues entering v7.7.1.3

| Issue | Severity | Notes |
|---|---|---|
| BUG-084 | High | Non-PSRAM boards crash under 8 concurrent HTTP connections. |
| #137 | Low | Board-type SVG diagrams. Cosmetic. |

---

## Phase 7 Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.7.0.0 | ESPHome component defaults audit | Complete |
| v7.7.1.0 | Health-check telemetry task | Complete (PR #225) |
| v7.7.1.1 | Chunked HTTP streaming (BUG-082 fix) | Complete (PR #226) |
| v7.7.1.2 | Per-device structs, key scheme, hash | Complete |
| **v7.7.1.3** | **Per-device persist engine (write path)** | **⬅️ Current** |
| v7.7.1.4 | Per-device restore engine + retention budget | Pending |

---

## Workflow

**Prerequisites:** v7.7.1.2 must be merged to `main` before starting this step.
**Successor:** v7.7.1.4 (restore engine + retention budget) depends on the NVS blobs written by
this step — test that v7.7.1.4 can actually read them before closing out v7.7.1.4.

Per `Docs/writing-guide/methodology.md` §4.3, the agent must confirm the chain:
- v7.7.1.2 structs and key helpers compiled and tested ✓ (prerequisite, already on `main`)
- v7.7.1.3 writes blobs in the format that v7.7.1.4 restore expects
- The consolidated audit for this step must note any format deviations that would break restore

Chain-inspection responsibility: before marking this PR ready, the agent must confirm
`DeviceHistoryMeta` initialisation uses `DEV_HIST_MAGIC` + `DEV_HIST_VERSION` constants so
v7.7.1.4's restore validation checks can pass.

---

## v7.7.1.3 Scope

### What this step does
1. Adds `persist_device_segment_()`, `persist_all_devices_v2()`, `load_device_meta_()`, `save_device_meta_()` to nvs-persistence.h
2. Wires `persist_all_devices_v2()` into the hourly persist lambda alongside `persist_hourly_segment()` (dual-write)
3. Uses provisional slot limit of 360 (~15 days) until budget calculator (v7.7.1.4)

### What this step does NOT do
- No restore from per-device NVS (v7.7.1.4)
- No retention budget calculation (v7.7.1.4)
- No new HTTP endpoints
- No old engine removal
- No EventLog persist path yet (binary sensors not in current manifest)

### Files modified
- `firmware/core/nvs-persistence.h` — new persist functions
- `firmware/esp32-c3-multi-sensor.yaml` — dual-write call
- `Docs/changelog.md`, `CURRENT-STATE.md`, session log, consolidated audit

### Device testing required
YES — verify board boots cleanly with dual-write. Hourly persist produces "V2 persist complete" in serial logs.

### Board fleet (from CURRENT-STATE.md)

| Board | IP | Role |
|-------|-----|------|
| C3 SuperMini | 192.168.120.189 | Satellite (production) |
| WROOM-32D | 192.168.120.170 | Satellite (production) |
| S3 DevKitC N16R8 | 192.168.120.191 | Aggregator (production) |

---

## Architecture References

- `Docs/v7.7-v7.8-persistence-architecture.md` §5 — `DeviceHistoryMeta`, `DeviceSegment` struct definitions
- `Docs/v7.7-v7.8-persistence-architecture.md` §6 — NVS key scheme, FNV-1a hash (key helpers from v7.7.1.2)
- `Docs/v7.7-v7.8-persistence-architecture.md` §10 — persist flow (write path design)
- `Docs/v7.7-v7.8-persistence-architecture.md` §8 — write path sequence and dedup guard logic

---

## Critical Rules in Force at v7.7.1.3 Entry

| # | Rule | Why Relevant |
|---|------|-------------|
| 2 | Use `bash scripts/bump-version.sh 7.7.1.3` | Version bump must be step 1 of §6, before compile |
| 11 | NVS scan loops must yield (`vTaskDelay` every N blobs) — general principle, source: LESSON-OPS-053 | Pre-existing requirement: any NVS iteration loop MUST yield to FreeRTOS scheduler. Scope: ALL NVS loop patterns across the entire codebase. Does NOT prescribe the helper function or delay value — only that yielding must occur. |
| 40 | Deferred task for HTTP handlers with NVS | NOT applicable: persist runs from hourly lambda (main loop), not httpd. Only applicable if adding an HTTP-triggered persist endpoint (not planned for this step). |
| 58 | Edit fragments, not assembled artifact | `nvs-persistence.h` is a fragment; `sensor_history_multi.h` is generated |
| 61 | Use `maybe_yield_nvs_scan_()` (defined once in `firmware/core/nvs-persistence.h`) in every NVS scan loop — specific implementation, source: Phase Y v7.6.6.5 + BUG-043 rev2 | Scope: THIS codebase only. Prescribes the specific helper function (NOT a custom `vTaskDelay` call). The helper uses `vTaskDelay(pdMS_TO_TICKS(5))` at every 2 iterations (NVS_SCAN_YIELD_INTERVAL). BUG-043 rev2 established 5ms — 1ms proved insufficient for ESP32-C3 single-core stability. Verified: `firmware/core/nvs-persistence.h:248`. |
| 62 | Assembly fragment order unchanged | No new fragments — count stays at 9 |
| 63 | Session log is pre-merge acceptance criterion | Mandatory — committed to branch before marking ready |
| 64 | Checkpoint greps mechanically derived | All greps from code blocks in the agent prompt |
| 67 | Binary sensors use EventLog | EventLog persist NOT in this step; no binary sensors in current manifest |

New rule added during v7.7.1.2 closure: **Rule 61 yield** — `vTaskDelay(pdMS_TO_TICKS(5))` in
NVS scan loops is mandatory on single-core ESP32-C3 (BUG-043 rev2 — 1ms proved insufficient;
verified against `firmware/core/nvs-persistence.h:248`). Omitting it causes watchdog resets under
multi-device iteration.

---

## Risk Profile

**Risk level: MEDIUM** — first runtime use of per-device NVS writes.

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **NVS flash wear** | Medium | Hourly writes per device. At 1 write/hour × 6 devices × 360 slots = 2,160 write cycles before wrap. NVS has ~100,000 erase cycles per page. Conservative by design. |
| **Mid-write power loss** | High | `DeviceHistoryMeta` is written AFTER the segment blob. If power fails between the segment write and the meta update, the segment exists but `valid_segments` is not incremented. On next boot, v7.7.1.4 restore reads `valid_segments` from meta and will simply miss the un-incremented segment — no corruption, just one missed segment. |
| **Key collision (FNV-1a)** | Low | Probability 5 × 10⁻⁸ for 20 devices (architecture doc §6). The `DeviceHistoryMeta.device_id` field stores the full ID string for collision detection at restore time. |

---

## Pre-merge Checklist

- [ ] All checkpoints pass
- [ ] ESPHome compiles
- [ ] Board boots and responds
- [ ] **In-PR deliverables committed (per `Docs/development-process-guide.md` §2.5):**
  - [ ] CURRENT-STATE.md updated
  - [ ] Changelog entry
  - [ ] Session log (Rule 63)
  - [ ] Consolidated audit

---

## Context That Carries Forward to v7.7.1.4

- Per-device segments are being written to NVS alongside old engine (dual-write verified)
- `DeviceHistoryMeta` is initialized with `DEV_PERSIST_PROVISIONAL_SLOTS = 360`
- v7.7.1.4 replaces the provisional slot limit with the retention budget calculator
- v7.7.1.4 implements `restore_device_history_v2_()` that reads the per-device segments written by this step
- Fragment count is 9
- All in-PR deliverables pattern: consolidated audit and session log committed to branch

---

_End of session handoff document._
