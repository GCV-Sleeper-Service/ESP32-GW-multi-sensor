# Session handoff - v7.7.1.3 (R6)

_Written 2026-11-24 by the planning session for R6 (PLAN-044, PLAN-046), corrected 2026-11-25 after GPT Astra's audit (PLAN-047), from the template of HowTo v2.3.1 `templates/session-handoff.template.md`. It replaces the May 2026 handoff of this step, which is source material only. Amend it inside any later PR that changes what it says._

## State snapshot this step was written against

| Item | Value | Source |
| --- | --- | --- |
| Version on main | 7.7.1.2 | `VERSION` |
| Commit on main (SHA) | `a33a5cc` (PR #246, tag `v7.7.1.2`) at production; the commit at dispatch is in the gate record | `git rev-parse --short origin/main` |
| Last verified | 2026-11-23: .189 and .170 report v7.7.1.2 | `CURRENT-STATE.md`, line 3 |
| Deployment targets (name → address → deployed version) | `sat-s3-4m-173` → 192.168.120.173 → v7.7.1.2, erased and flashed over USB on 2026-11-24 with the project's partition table; `esp32-c3-multi` → 192.168.120.189 → v7.7.1.2; `sat-esp32-4m-170` → 192.168.120.170 → v7.7.1.2 | `CURRENT-STATE.md`, "Board Fleet"; the operator's `fleet` output of 2026-11-24 |
| Measurements this step depends on | History partition of .189 and .170: `used_entries` 10,804, `free_entries` 5,324, `total_entries` 16,128, old ring 1,080 of 1,080 segments of 232 B (2026-11-24); .173: no history partition before the USB flash (`history_bytes` 0, nvs 446,464 B), `history_bytes` 524,288 after it; .170 `min_free_heap` 2,252 B after 25 hours on v7.7.1.2; .189 `min_free_heap` 28,376 B (fleet, 2026-11-24 morning); later the same day .170 7,332 B and .189 29,456 B: both had restarted, since the value is the lowest since boot (`esp_get_minimum_free_heap_size()`); C3 image of `a33a5cc` 1,435,444 B in the planning session's build (2026-11-24) | The operator's readings of `/api/storage-stats` and `fleet`; the planning session's compile with ESPHome 2026.4.1 |

## What this step does

- Writes, at every hourly persist, one `DeviceSegment` per persistent device into a ring of 24 slots per device (`ds_<8 hex>_<3 hex>`), and updates the device's meta blob (`dm_<8 hex>`) after the segment, beside the old engine (dual-write).
- Skips a device's write when the history partition has fewer than 252 free NVS entries, so the old engine always has room for its hourly overwrite.
- Reports each device's ring under `persist_v2` in `/api/storage-stats`, from RAM.
- Gives the sensor `outside` the MAC of its replacement.
- Tests the write path at compile time (T3) and on the host (H1); bumps to 7.7.1.3; flashes .173 first, then .189 and .170.

## What this step does NOT do

- No read of the new blobs: restore stays on the old engine until v7.7.1.4; the dashboard reads the old engine until v7.7.2.1.
- No retention budget: the ring of 24 slots is provisional; v7.7.1.4 replaces it.
- No EventLog persist: the manifest has no binary metric.
- No change of the old engine, the partition tables, the RAM window (PLAN-011) or the persist minute.

## Risk tier and why

MEDIUM (PLAN-044): the first runtime writes of the per-device engine on three boards. A wrong write cannot corrupt the old engine's blobs (other keys), but a full partition would stop its saves; the guard and the small ring keep it from that.

## Critical rules that apply

| # | Rule | Why here |
| --- | --- | --- |
| 2 | Version bump through `bump-version.sh` | The step bumps to 7.7.1.3 |
| 5, 58 | No hand edit of generated files; code in `firmware/core/` | One fragment gets the write path, one handler the status |
| 11, 61 | NVS loops yield with `maybe_yield_nvs_scan_()` | The device loop of the write path |
| 40 | No NVS operation on the httpd task | `/api/storage-stats` reports from RAM only |
| 62 | Fragment order unchanged | No fragment is added |
| 63 | Session log in the PR | Firmware step |
| 64 | Counts from the prompt's text | The checks count definitions and lines |

## Risks and mitigations

| Risk | Trigger | Mitigation |
| --- | --- | --- |
| The partition fills and the old engine stops saving | `free_entries` near 252, `nvs_low` in `persist_v2` | Ring of 24 slots (about 976 entries for 4 devices); the guard writes nothing below 252 free entries |
| The WROOM runs out of heap | `min_free_heap` of .170 below 1,024 B | The blocks `dev`, `v2` and `wroom24` stop the step (PLAN-046). About 100 new blob keys are about 200 hash-list items of NVS: about 1.0 to 1.5 KB of heap once the rings are full (ESP-IDF 5.5.4 source: 4 bytes per item in blocks of 128 B per page), plus 96 B of static RAM; against 2,252 B, a stop at the 24-hour reading is a real possibility (internal audit of R6, M2) |
| The C3 heap falls | `c3heap`: the higher reading more than 2,048 B below the reading before the upload | The agent stops and reports (PLAN-046) |
| Power loss between the segment and its meta | A segment without a meta update | The meta is written after the segment; the next cycle writes the same slot again; v7.7.1.4 reads only the slots that the meta counts |
| .173 still has no history partition | `v2 192.168.120.173 before` stops | The operator's USB flash before dispatch (operator page) |

## Context that carries forward to the next step

- v7.7.1.4 reads these blobs at boot. Its budget must count the RAM that NVS keeps for each key on boards without PSRAM, not only flash: two hash-list items of 4 bytes per blob key, in blocks of 128 B per page (ESP-IDF 5.5.4 source); per-device hourly blobs multiply the keys by the devices (PLAN-046).
- Restore: with a full ring, a power loss between a segment and its meta leaves a newer segment at `next_slot`, which the meta counts as the oldest; v7.7.1.4 orders the segments by their header epochs and checks magic, version, `metric_count`, `points_per_segment` and `counts[k]` of each before use; it tests an interruption between the segment and the meta at the first fill and at the wrap, and states whether a complete newer segment at `next_slot` is used (GPT Astra's audit of R6, H3; Cowork M01). The rows carry no metric identity, only their position: v7.7.1.4 decides how a change of a device's history metrics is detected, for example a hash of the metric keys in a reserved field (internal audit of R6, L4).
- The blob size: this step writes the full 228-byte `DeviceSegment`; v7.7.1.4 decides whether later blobs hold only the filled rows, with the measurements of this step.
- A meta of another ring size starts a fresh ring in this step; v7.7.1.4 decides how a new budget keeps the old slots. A failed read of a meta that exists writes nothing (`load_device_meta_` returns -1, PLAN-047): the restore path keeps that distinction and never treats a read error as an empty ring.
- The status of each device is copied under a short critical section (`dev_persist_status_get_` and `dev_persist_status_put_` of S2, PLAN-047); a later reader of it uses the same two functions.
- The `persist_v2` object of `/api/storage-stats` is the place for the budget's report (architecture doc §7.5).
- .180 and .184 may run a partition table without a history partition too (plan of record, section 10).
- `handle_storage_stats_()` on `main` opens the history partition through `open_history_nvs_`, on the HTTP task; its recovery, `ensure_history_nvs_ready_`, erases the partition when `nvs_flash_init_partition` reports no free pages or a new NVS version. This step adds no such call and keeps that one (GPT Astra's second re-audit, H07); the read path of v7.7.1.4 reviews it.

## Open questions for the operator (answer before dispatch)

- [x] .173 is erased and flashed with v7.7.1.2 over USB, and its `/api/storage-stats` shows `history_bytes 524288` (operator page, "Before you start"; done 2026-11-24).
- [ ] The operator's latest `fleet` output on the day of dispatch: .173, .189 and .170 report v7.7.1.2.
- [x] `g++` exists on the build host (`/usr/bin/g++`, 2026-11-24).
- [ ] The harness and the model of the coding agent, for the gate record (PLAN-043).
