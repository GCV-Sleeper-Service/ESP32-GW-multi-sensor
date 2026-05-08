# Phase 7 — Per-Device Persistence Engine (Rewritten Plan)

_Date: 2026-05-07 (rewritten during multi-phase planning session)_
_Supersedes: `Docs/v7.7-implementation-plan.md` (2026-03-19 — stale)_
_Architecture reference: `Docs/v7.7-v7.8-persistence-architecture.md` (memory budget sections need update)_
_Measurement source: `Docs/board-measurement-log-v7.6.10.md`_
_Repo: v7.6.10.4 on `main`_

---

## Goal

Replace the monolithic `SegmentSnapshot` persistence model with a per-device segment engine. When Phase 7 is complete:

1. BUG-082 is resolved — history endpoints use chunked HTTP streaming, no full-CSV-in-RAM
2. A periodic health-check telemetry task logs stack HWM, heap stats, socket usage, NVS stats
3. Each device's history is stored in its own NVS key namespace
4. Adding/removing a device never touches another device's data
5. Per-device delete, export, and import are available
6. Automatic migration from v7.x format preserves recent history
7. Retention is budgeted per device from manifest priority tiers
8. Binary sensors use state-change-only deduplication (EventLog)
9. All existing Playwright tests pass with no behavioral regression

**Key principle:** Build the new engine alongside the old one. Validate with environmental devices first. Remove the old engine only after migration is proven on real hardware.

---

## Why the Original Plan Needed Rewriting

The original plan (`Docs/v7.7-implementation-plan.md`, 2026-03-19) had the right architectural approach but was operationally stale:

- References `dashboard/sensor_history_multi.h` directly 9 times — now a generated artifact from `firmware/core/` (Phase Y, v7.6.6.x)
- References `dashboard/dashboard.js` 5 times — now generated from `dashboard/core/` + `dashboard/components/` (Phase X, v7.6.5.x)
- No auth integration — `authenticate_management_()` and `authFetch()` added in Phases V/VX
- No chunked streaming step — BUG-082 (production crash) not addressed
- No health-check telemetry — BUG-075/076 recommendations unimplemented for 6+ weeks
- No board measurement references — plan predates the 6-board fleet
- Memory budget uses pre-Phase-V estimates, now superseded by measured values
- Existing Phase 7 prompts in `prompts/phase7/` are all stale (reference wrong file paths, no auth)

The architecture doc (`Docs/v7.7-v7.8-persistence-architecture.md`) remains valid for its structural decisions (per-device key scheme, FNV-1a hash, retention budgeting). Section 15 (memory budget) needs measured values substituted.

---

## Version Numbering Convention

- `.0` steps are research/measurement — no codebase changes, no version bump
- `.1+` steps are implementation — version bump, PR, full review pipeline
- Three sub-phases within each minor: v7.7.N.x groups related work

---

## Phase 7 Step Table

| Step | Version | Content | Type | Risk | Est. Sessions |
|---|---|---|---|---|---|
| 0a | v7.7.0.0 | ESPHome component defaults audit | Research | Low | 1 |
| 0b | v7.7.1.0 | Health-check telemetry task + measurement baseline | Implementation | Medium | 2 |
| 1 | v7.7.1.1 | Chunked HTTP streaming for `/history/` endpoints | Implementation | High | 2–3 |
| 2 | v7.7.1.2 | Per-device structs, key scheme, hash function | Implementation | Low | 1–2 |
| 3 | v7.7.1.3 | Per-device persist engine (write path) | Implementation | Medium | 2–3 |
| 4 | v7.7.1.4 | Per-device restore engine (boot path) + retention budget | Implementation | High | 3–4 |
| 5 | v7.7.2.1 | Wire new engine, storage stats v2, switchover | Implementation | High | 2–3 |
| 6 | v7.7.2.2 | v7→v8 one-time migration | Implementation | High | 2–3 |
| 7 | v7.7.2.3 | Per-device delete API + dashboard UI | Implementation | Medium | 1–2 |
| 8 | v7.7.3.1 | Per-device export/import | Implementation | Medium | 2 |
| 9 | v7.7.3.2 | Multi-device bundle export/import | Implementation | Medium | 2 |
| 10 | v7.7.3.3 | Full regression, old engine removal, phase closure | Closure | Low | 1 |

**Post-Phase 7 optimization sprint (v7.7.5.x):**

| Step | Version | Content | Type |
|---|---|---|---|
| Opt-1 | v7.7.5.0 | NVS deduplication study: value-dictionary approach for environmental sensors | Research |
| Opt-2 | v7.7.5.1 | RAM window reduction: 2h for non-PSRAM, 24h for PSRAM boards | Implementation |
| Opt-3 | v7.7.5.2 | BinaryDeviceSegment (Option B) + deduplication optimizations if study warrants | Implementation |

---

## Step Details

### v7.7.0.0 — ESPHome Component Defaults Audit (Research)

**Scope:** Audit ESPHome 2026.4.1 component source code for hardcoded defaults that could surprise the project (like the 4 KB httpd stack in BUG-075). No code changes. Output is a document listing defaults, risk assessment, and recommended overrides.

**Target areas:**
- Web server component: stack sizes, buffer sizes, connection limits
- WiFi component: scan intervals, reconnect behavior
- BLE component: scan windows, advertisement processing
- NVS component: page sizes, entry limits, commit behavior
- OTA component: buffer sizes, timeout values

**Output:** `Docs/esphome-component-defaults-audit.md`

**No version bump.** No PR with code changes. Research deliverable only.

**Acceptance:** Document produced, reviewed, any critical findings promoted to GitHub Issues.

---

### v7.7.1.0 — Health-Check Telemetry Task

**Scope:** Add a periodic FreeRTOS task that logs runtime health metrics. Implements the BUG-075/076 postmortem recommendation that has been unimplemented for 6+ weeks.

**New file:** `firmware/core/health-check.h` (new fragment)

**Task behavior:**
- Period: every 60 seconds (configurable via `HEALTH_CHECK_INTERVAL_S`)
- Logs via `ESP_LOGI`:
  - `free_heap` (internal), `min_free_heap` (internal), `free_heap_total`
  - httpd stack watermark (`uxTaskGetStackHighWaterMark`)
  - NVS stats via `nvs_get_stats()`: used entries, free entries, total entries, namespace count
  - Uptime seconds
- Task stack: 4096 bytes (health-check does no NVS writes, only reads)
- Conditional compilation: always enabled (lightweight, pure logging)

**Files modified:**
- `firmware/core/health-check.h` — NEW fragment
- `scripts/assemble-sensor-history.sh` — add new fragment to assembly order
- `firmware/esp32-c3-multi-sensor.yaml` — add `xTaskCreate` for health-check in `on_boot:` lambda
- `scripts/preflight.sh` — add check for health-check fragment existence
- `Docs/changelog.md` — v7.7.1.0 entry
- `CURRENT-STATE.md` — update "What Just Shipped", move recommendation to "implemented"
- Version bump: ALL locations to `7.7.1.0`

**Acceptance criteria:**
- Health-check task runs and logs every 60s (visible in ESPHome logs)
- `nvs_get_stats()` reports for history partition
- Stack watermark reported for httpd task
- `assemble-sensor-history.sh --check` passes with new fragment
- All Playwright tests pass
- Preflight passes
- Device test: flash C3, observe health-check log output via `esphome logs`

**Device testing required:** YES — verify log output on physical board.

---

### v7.7.1.1 — Chunked HTTP Streaming for History Endpoints (BUG-082 Fix)

**Scope:** Replace single-response CSV building with `Transfer-Encoding: chunked` streaming. Stream NVS segments directly to the HTTP response without building a full `std::string` in RAM. Fixes BUG-082 / issue #139.

**Critical context:** This step works against the EXISTING `seg_NNN` key scheme. It does NOT depend on per-device persistence. The history handlers (`handle_history_()` at line ~1454, `handle_api_v2_history_()` at line ~516 of `firmware/core/web-handler.h`) read `seg_NNN` keys directly via `make_segment_key_()`.

**Implementation approach:**
1. Replace `httpd_resp_sendstr()` with chunked response using `httpd_resp_send_chunk()`
2. Iterate NVS segments one at a time, format CSV lines for each segment's entries, send as a chunk
3. Each chunk is ~100-500 bytes (one segment's CSV lines). Peak heap usage: ~600 bytes vs. current ~40 KB.
4. Send final empty chunk to signal end of response
5. Dashboard history loader: verify `fetch()` handles chunked responses (it should — browsers handle `Transfer-Encoding: chunked` transparently)

**Files modified:**
- `firmware/core/web-handler.h` — rewrite `handle_history_()` and `handle_api_v2_history_()` to use chunked streaming
- `firmware/core/web-handler.h` — rewrite the aggregator proxy history endpoint if it builds CSV in RAM
- `dashboard/core/history.js` — verify chunked response handling (likely no changes needed)
- `Docs/changelog.md` — v7.7.1.1 entry
- `CURRENT-STATE.md` — move BUG-082 to resolved
- Version bump: ALL locations to `7.7.1.1`

**Acceptance criteria:**
- `/history/{id}/temp` streams response in chunks (verify with `curl -v`)
- `/api/v2/history/{id}/{metric}` streams response in chunks
- WROOM board with 500+ segments does NOT crash on history load
- C3 board with 1000+ segments does NOT crash on history load
- Dashboard renders history charts correctly from streamed response
- Memory: peak heap usage during history serve < 5 KB (verify via health-check telemetry)
- All Playwright tests pass
- `scripts/stress-test-httpd-stack.sh` passes on at least C3 and WROOM

**Device testing required:** YES — CRITICAL. This is the BUG-082 fix. Must verify on WROOM (tightest heap) with maximum NVS history.

**Risk:** High. Chunked HTTP streaming in ESPHome's `AsyncWebHandler` framework needs careful implementation. The `AsyncWebServerRequest` API may not directly support `httpd_resp_send_chunk()` — may need to drop to raw ESP-IDF httpd APIs for these handlers.

---

### v7.7.1.2 — Per-Device Structs, Key Scheme, Hash Function

**Scope:** Add `DeviceHistoryMeta`, `DeviceSegmentHeader`, `DeviceSegment` structs. Implement FNV-1a hash and NVS key helpers. Extend manifest schema for `persist` blocks. No runtime behavior changes.

**Target file:** `firmware/core/data-model.h` (structs), `firmware/core/nvs-persistence.h` (key helpers)

**Architecture reference:** `Docs/v7.7-v7.8-persistence-architecture.md` §5-6

**Key differences from original plan:**
- File target is `firmware/core/data-model.h`, NOT `dashboard/sensor_history_multi.h`
- Generator output goes through `assemble-sensor-history.sh`
- Must include `EventLog` struct for binary sensor metrics (state-change deduplication)

**Acceptance criteria:**
- `DeviceHistoryMeta`, `DeviceSegment` structs compile cleanly
- `EventLog` struct for binary metrics compiles cleanly
- `device_id_hash_()` produces consistent 32-bit FNV-1a hashes
- `make_device_meta_key_()` keys ≤ 11 chars (`dm_HHHHHHHH`)
- `make_device_segment_key_()` keys ≤ 15 chars (`ds_HHHHHHHH_NNN`)
- Old `SegmentSnapshot` code untouched
- All Playwright tests pass

---

### v7.7.1.3 — Per-Device Persist Engine (Write Path)

**Scope:** Implement `persist_device_segment_()` and `persist_all_devices_v2()`. Wire into hourly interval lambda alongside (not replacing) old persist.

**Target file:** `firmware/core/nvs-persistence.h`

**Key requirements:**
- All new endpoints use `authenticate_management_()` (Phase V requirement)
- NVS operations use deferred task pattern (Critical Rule 40)
- `maybe_yield_nvs_scan_()` called between device persists (Critical Rule 61)
- `external_components` block verified in board YAML (Critical Rule 42)
- Binary sensors use `EventLog` persist path (state-change only)

**Device testing required:** YES — verify both old and new blobs written.

---

### v7.7.1.4 — Per-Device Restore Engine + Retention Budget

**Scope:** Implement per-device restore from NVS on boot. Implement retention budget calculator using partition size and priority tiers.

**Target file:** `firmware/core/nvs-persistence.h`

**Retention budget uses measured partition sizes:**
- 640 KB (4 MB standard boards): ~508 slots/device for 4 devices = ~21 days
- 480 KB (C6 4 MB binary satellite): ~292 slots/device for 6 binary sensors = ~12 days (effectively months with deduplication)
- 1 MB (8 MB boards): ~812 slots/device for 4 devices = ~34 days
- 4 MB (16 MB boards): ~3,248 slots/device for 4 devices = ~135 days

**Device testing required:** YES — CRITICAL. Boot restore is the critical path.

---

### v7.7.2.1 — Wire New Engine, Storage Stats v2, Switchover

**Scope:** Make v2 engine primary. Update `/api/storage-stats` for per-device breakdown. Keep old engine read-only.

**Dashboard integration:** All new fetch calls use `authFetch()` from `dashboard/core/auth.js`.

---

### v7.7.2.2 — v7→v8 Migration

**Scope:** One-time automatic migration from monolithic `SegmentSnapshot` to per-device `DeviceSegment`. See architecture doc §13.

---

### v7.7.2.3 — Per-Device Delete API + Dashboard UI

**Scope:** `DELETE /api/v2/history/{device_id}`. Dashboard settings panel delete button per device.

**New endpoint requires:** `authenticate_management_()`, deferred task pattern, `authFetch()` in dashboard.

---

### v7.7.3.1 — Per-Device Export/Import

**Scope:** Per-device CSV export/import with v2 format headers.

---

### v7.7.3.2 — Multi-Device Bundle Export/Import

**Scope:** "Export All" produces multi-device CSV with `# device_id:` section headers. Round-trip verified.

---

### v7.7.3.3 — Full Regression, Old Engine Removal, Phase Closure

**Scope:** Remove old `persist_hourly_segment()` from write path. Full Playwright regression. Phase 7 closure documentation. Run httpd stack stress test on all boards.

**Acceptance includes:**
- `bash scripts/stress-test-httpd-stack.sh` on C3, WROOM, S3 — minimum watermark ≥ 2,000 B
- All Playwright tests pass (Chromium + Firefox)
- `CURRENT-STATE.md` updated for Phase 7 completion
- Phase 7 milestone closed

---

### v7.7.5.x — Post-Phase 7 Optimization Sprint

**v7.7.5.0 — NVS Deduplication Study (Research)**

Study whether a value-dictionary approach can reduce NVS usage for environmental sensors. Concept: temperature sensors produce values from -40.0°C to +60.0°C at 0.1° resolution = 1,000 distinct values. Instead of storing `float` per reading, store a `uint16_t` index into a known value table. Savings: 4 bytes → 2 bytes per reading (50% reduction).

Questions to answer:
- Does the NVS per-entry overhead (header, alignment) dominate the payload size, making value compression irrelevant?
- Is the complexity of a value dictionary worth the savings given current partition utilization?
- Can the compression be applied transparently (decode on read) or does it require dashboard changes?

**v7.7.5.1 — RAM Window Reduction**

Reduce `HistoryBuffer` from 24h (96 entries, 768 B) to 2h (8 entries, 64 B) on non-PSRAM boards. PSRAM boards keep 24h. Board-profile setting: `ram_window_hours`. Depends on chunked streaming (v7.7.1.1) being complete — dashboard loads older data from NVS via the streaming API.

Savings: ~4,200 B for 6 metrics, ~8,400 B for 12 metrics.

**v7.7.5.2 — BinaryDeviceSegment + Deduplication (Conditional)**

If v7.7.5.0 study shows value compression is worthwhile, implement `BinaryDeviceSegment` (Option B) and/or value-dictionary compression for environmental segments. Otherwise, skip — Option A from Phase 7 core is sufficient.

---

## Partition Table Changes

Phase 7 introduces four partition layouts:

| Layout | Flash | OTA Slots | History NVS | Boards | File |
|---|---|---|---|---|---|
| 4 MB standard | 4 MB | 2 × 1,664 KB | 640 KB | C3, WROOM, S3 SuperMini | `partitions/esp32-c3-multi-partitions.csv` (updated) |
| 4 MB C6-binary | 4 MB | 2 × 1,728 KB | 480 KB | C6 SuperMini 4 MB | `partitions/esp32-c6-multi-partitions.csv` (updated) |
| 8 MB | 8 MB | 2 × 3,072 KB | 1,024 KB | C6 8 MB, C5 | `partitions/esp32-c5-multi-partitions.csv` (keep) |
| 16 MB | 16 MB | 2 × 3,072 KB | 4,096 KB | S3 DevKitC | `partitions/esp32-s3-multi-partitions.csv` (keep) |

**Note:** Partition changes require full reflash (not OTA). Plan this for a device maintenance window during Phase 7 Step v7.7.1.4 (when restore engine is ready to validate the new layout).

---

## Critical Rules Additions (Proposed)

| # | Rule | Source |
|---|---|---|
| 65 | All new HTTP endpoints must include `authenticate_management_()` for write/management operations and `authFetch()` in dashboard fetch calls | Phase 7 planning review |
| 66 | After adding new HTTP handlers, run `scripts/stress-test-httpd-stack.sh` on at least one board per architecture. Minimum watermark ≥ 2,000 B. | Phase 7 planning review |
| 67 | Binary sensor metrics use `EventLog` (state-change-only deduplication), not `HistoryBuffer` (periodic readings) | PLAN-002 |

---

## Dependencies and Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Chunked streaming not supported by ESPHome's AsyncWebHandler | High | Drop to raw ESP-IDF httpd for history handlers; keep AsyncWebHandler for other endpoints |
| Migration corrupts existing history | High | Pre-migration CSV export via chunked streaming (Step v7.7.1.1); old keys preserved for rollback |
| C6 4 MB binary exceeds OTA partition with Phase 7 code | Medium | C6 4 MB uses smaller history partition (480 KB); monitor binary size |
| Per-device scheme reduces retention vs. monolithic | Medium | 640 KB partition (was 512 KB); binary deduplication for binary sensors |
| New FreeRTOS tasks compete for heap | Medium | Health-check task (4 KB stack) runs first; validates headroom before persistence tasks added |

---

## Consolidated Audit Template

Phase 7 uses the same consolidated audit template as Phase V:

```
prompts/phase7/consolidated-audit-template-phase7.md
```

Template structure (from Phase V pattern):
- §1: PR metadata (number, branch, step version, agent, reviewers)
- §2: Findings by severity (Critical / High / Medium / Low / Info)
- §3: Agent autonomous decisions (any deviations from prompt)
- §4: Prompt quality score (1-5, with justification)
- §5: Acceptance criteria checklist (each criterion: pass/fail/waived)
- §6: Device test results (if applicable)
- §7: Recommendations for next step

The template is produced during prompt production (not this planning session).

---

_End of Phase 7 rewritten plan._
