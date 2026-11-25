# Phase 7 Batch 2 — assumption audit and live-extract table

_Written 2026-11-22 by the planning session for R5b (`Docs/development-process-guide.md` §4.1; `prompts/producer-contract.md` rule 2.2; PLAN-044)._
_Batch 2 is produced rolling (PLAN-044): this file covers v7.7.1.2. The planning session adds a section for v7.7.1.3 after R4 merges and one for v7.7.1.4 after R6 merges, in the pull request that carries each bundle._

## 1. Live-extract table for v7.7.1.2

Read on 2026-11-22 from `origin/main` at `1c95906` (PR #244), unless the source says otherwise.

| Value | Live value | Source |
|---|---|---|
| `VERSION` | 7.7.1.1 | `git show origin/main:VERSION` |
| Commit of `origin/main` | `1c95906` | `git rev-parse --short origin/main` |
| Fragments | 9 | `ls firmware/core/*.h \| wc -l` |
| Critical Rules | 67 rows | `grep -c '^\| [0-9]' prompts/prompt-index-and-workflow.md` |
| Rule 61 delay in `maybe_yield_nvs_scan_()` | `pdMS_TO_TICKS(5)` | `grep -A6 '^static void maybe_yield_nvs_scan_(' firmware/core/nvs-persistence.h` |
| Board .189 | `esp32-c3-multi`, ESP32-C3 SuperMini, production satellite, profile `esp32-c3-supermini`, `firmware/esp32-c3-multi-sensor.yaml`, v7.7.1.1 (2026-11-14) | `CURRENT-STATE.md`, "Board Fleet"; `AGENTS.md`, "Device Testing" |
| Board .170 | `sat-esp32-4m-170`, ESP32 dev board (WROOM-32D), production satellite, profile `esp32-wroom-32d`, `firmware/esp32-wroom-32d-gw.yaml` written by `bash scripts/provision.sh wroom` from `config/gateway-sat-esp32-4m-170.json.bak`, v7.7.1.1 (2026-11-14) | `CURRENT-STATE.md`; `scripts/provision.sh`; `.gitignore` (`firmware/*-gw.yaml`) |
| The operator's latest `fleet` output | 2026-11-14 | `CURRENT-STATE.md`, line 3. The pre-dispatch gate of R4 needs the output of its day |
| Anchor in `data-model.h` | last line `static const char *const HISTORY_PARTITION_LABEL = "history";`; one line `// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>` | `tail -n 1`, `grep -cxF` |
| Anchors in `nvs-persistence.h` | `static void make_segment_key_(int slot, char *key, size_t key_len) {` and `static void clear_runtime_histories_() {`, once each | `grep -cxF` |
| Anchor in the generator | `def render_entity_block(sensors: List[Dict]) -> str:`, once | `grep -cxF scripts/render_sensor_config.py` |
| `HistEntry` | `uint32_t epoch; float value;` | `firmware/core/data-model.h` |
| `PERSIST_POINTS_PER_SEGMENT` | 4 (`(PERSIST_SEGMENT_HOURS * 60) / HISTORY_INTERVAL_MINUTES`, 1 h and 15 min) | `firmware/core/data-model.h` |
| `MetricDef` | `history_enabled` true: `temp` and `hum` (ThermoPro), `ping_ms` and `success_pct` (ping); none for `external_push` | `render_entity_block()` |
| Categories and ids | `VALID_CATEGORIES = {"environmental", "network", "system"}`; `ID_RE = ^[a-z0-9_]{1,32}$` | `scripts/sensor_manifest_lib.py` |
| `config/sensors.json` | office, first_floor, outside (environmental), wan_ping (network), nas01 (system) | the file |
| Generated block | identical in `firmware/core/data-model.h` and `dashboard/sensor_history_multi.h` between the ENTITY markers | a Python compare, recorded in the gate record of R5b |
| `/api/status/full` fields | `version`, `uptime_seconds`, `free_heap`, `min_free_heap` | `handle_status_full_()` in `firmware/core/web-handler.h` |
| OTA slot, C3 and WROOM | `ota_0` 0x1B0000 = 1,769,472 B | `partitions/esp32-c3-multi-partitions.csv`, `partitions/esp32-wroom-multi-partitions.csv` |
| History partitions | 0x80000 (C3, WROOM, C6, S3 4 MB), 0x100000 (C5), 0x400000 (S3 16 MB) | `partitions/*.csv` |
| C3 image at `1c95906` | `firmware.bin` 1,435,840 B, 81.1 % of the slot; RAM 60,436 B of 327,680 B | the planning session's compile with ESPHome 2026.4.1, 2026-11-22 |
| Side effects of `bump-version.sh 7.7.1.2` and the pipeline | `VERSION`, `dashboard/core/app-shell.js`, `dashboard/dashboard.h`, `dashboard/dashboard.html`, `dashboard/dashboard.js`, `dashboard/sensor_history_multi.h`, `firmware/core/config.h`, `firmware/core/data-model.h`, `firmware/esp32-c3-multi-sensor.yaml`, `scripts/render_sensor_config.py`, `src/gateway_manifest.h`, `tests/fixtures/generate-fixtures.js`, `tests/fixtures/manifest.json`, `tests/fixtures/variants/{1sensor,2sensor,3sensor,4sensor,mixed,system}/manifest.json` | the rehearsal of R5b, a run on a scratch worktree |
| Playwright specs | 12 files in `tests/browser/`; CI runs 7 fixture jobs | `find tests -name '*.spec.js'`; `.github/workflows/browser-tests.yml` |

## 2. The six answers (process guide §4.1)

**1. Unverified assumptions.** Each value above was read live. Three are not verified by the planning session, and the step checks them itself: the boards' versions on the day of dispatch (the operator's `fleet` output and the block `dev`); the Xtensa layout of the structs (the WROOM compile of item 5.2 runs the size assertions); the C3 heap (`c3heap`). The status of WROOM NI-001 (an `IllegalInstruction` reboot after the v7.7.1.0 flash, `prompts/phase7/v7.7.1.0-PR225-consolidated-audit-and-lessons.md` §6) was not found in `CURRENT-STATE.md` or an open issue; the 24-hour reading of .170 (`wroom24`) shows a reboot as a boot time that differs from the one that `dev` printed after the upload.

**2. Unimplemented postmortem items.**

| Item | Source | Disposition |
|---|---|---|
| Version from `/api/status/full`, not `/api/status` | plan of record, R5b | Implemented: the block `dev` reads `/api/status/full` |
| `Fixes #214` as closing line | plan of record, R5b; contract 4.5 | Implemented: §8 of the prompt |
| No pre-filled struct size (#228 A5, PR #233 M-1) | contract 3.2 | Implemented: the block `measure` prints the sizes from the compiler; the prompt and the changelog hold none |
| Line numbers as anchors (PR #233 M-2) | contract 3.1 | Implemented: quoted text and symbols only |
| Branch check in place of `git checkout main` | contract 4.4 | Implemented: §2 checks the branch and its base |
| Test board first | plan of record, R5b | Not applicable: v7.7.1.2 adds no runtime code; .173 first is the rule of v7.7.1.4. v7.7.1.3 names .189, .170 and .173 |
| No login literal (SEC-003) | contract 4.3 | Implemented: `dev` and `wroom24` read the login inside python3 |
| `dashboard/dashboard.h` in the regenerated outputs | plan of record, R5b | Implemented: §3 lists it from the rehearsal |
| `.bin` size against the OTA slot | plan of record, R5b; `CURRENT-STATE.md` | Implemented early: CHECKPOINT D prints the C3 image against its slot |
| WROOM `min_free_heap` after a fresh boot and a day later | plan of record, R5b | Implemented: `dev` and `wroom24` (PLAN-044) |
| H-1, declaration order (PR #233) | v7.7.1.4 | Deferred to the bundle of v7.7.1.4, produced after R6 |
| L-1, boot test on both satellites (PR #233) | v7.7.1.4 | Deferred to the bundle of v7.7.1.4 |
| v7.7.1.1 lessons 8.1.4 (side effects listed), 8.1.5 (`--write` before `--check`), 8.1.6 (current spec paths), 8.1.7 (IP and YAML in the device section) | `prompts/phase7/v7.7.1.1-PR226-consolidated-audit-and-lessons.md` §8 | Implemented in the prompt of v7.7.1.2 |
| Slot cap of the key format (999 against about 3,248 planned on 16 MB) | found in this production | Resolved by PLAN-044: hex slot suffix, 4,096 slots |
| Device id length (15 in the architecture doc against 32 in the manifest) | found in this production | Resolved by PLAN-044: a 33-byte field |

**3. Simplest thing that could go wrong.** The agent types the generated block into the fragment and then runs `assemble --write` in the wrong order, which drops it (the rehearsal hit this; item 3.2 now fixes the order). CHECKPOINT C compares the two generated blocks and stops.

**4. Three weeks of continuous operation.** No change at runtime: nothing reads or writes the new definitions; the arrays of generated constants live in flash. The image grows by the code of the new definitions; the C3 image was 81.1 % of its slot at `1c95906`. The 24-hour WROOM reading tests the one open heap question (`CURRENT-STATE.md`, "WROOM heap").

**5. Platform capabilities.**

| Capability | Version | Source, read 2026-11-22 |
|---|---|---|
| NVS key length at most 15 characters; blob at most 508,000 B or 97.6 % of the partition minus 4,000 B | ESP-IDF v5.5 | https://docs.espressif.com/projects/esp-idf/en/v5.5/esp32/api-reference/storage/nvs_flash.html |
| C++ default `-std=gnu++23` | ESP-IDF v5.5 | https://docs.espressif.com/projects/esp-idf/en/v5.5/esp32/api-guides/cplusplus.html |
| GCC 14.2.0 toolchains (`esp-14.2.0_20241119` archives) | ESP-IDF v5.5 | https://docs.espressif.com/projects/esp-idf/en/v5.5/esp32/api-guides/tools/idf-tools.html |
| `riscv32-esp` toolchain 14.2.0+20260121 used by the C3 build; constexpr tests T1 and T2 compile; GCC prints "the comparison reduces to '(N == 1)'" for a failed size assertion | ESPHome 2026.4.1 (PLAN-016) | the planning session's compile on 2026-11-22 |
| ESP-IDF version of ESPHome 2026.4.x | 5.5.4 per `CURRENT-STATE.md`; the ESPHome changelog of 2026.4.0 maps 5.5.4 and 6.0.0 (esphome#15241) without naming the default in what was read | https://esphome.io/changelog/2026.4.0/ |
| FNV-1a 32-bit: offset basis 0x811c9dc5, prime 0x01000193 | — | `Docs/v7.7-v7.8-persistence-architecture.md` §6.2; the values of T2 were computed in Python |

**6. Decision changes.** PLAN-044 (R5b) records the rolling production of Batch 2 and the design decisions of v7.7.1.2; it changes the R5b block of the plan of record and the key format of the architecture doc §6.3.

## 4. v7.7.1.3 (R6): live-extract table and the six answers

_Written 2026-11-24 by the planning session for R6 (PLAN-044, PLAN-046). Read from `origin/main` at `a33a5cc` (PR #246), unless the source says otherwise._

| Value | Live value | Source |
|---|---|---|
| `VERSION` | 7.7.1.2 | `git show origin/main:VERSION` |
| Commit of `origin/main` | `a33a5cc`; tag `v7.7.1.2` on it | `git rev-parse --short origin/main` |
| Fragments | 9 | `ls firmware/core/*.h \| wc -l` |
| Rule 61 delay in `maybe_yield_nvs_scan_()` | `pdMS_TO_TICKS(5)`, every 2 iterations (`NVS_SCAN_YIELD_INTERVAL`) | `firmware/core/nvs-persistence.h` |
| The last function of `nvs-persistence.h` | `persist_hourly_segment(uint32_t saved_at_epoch = 0)`; the file ends with its `}` and one empty line | `tail -n 2` |
| The persist call | `persist_hourly_segment(now.timestamp);` in the lambda at `minutes: ${persist_minute}` (`persist_minute: "10"`) of `firmware/esp32-c3-multi-sensor.yaml`, and the same line in `generate_board_yaml()` of `scripts/render_sensor_config.py` | `grep -n` |
| Generated persist constants | `PERSIST_DEVICE_COUNT` 4: `office`, `first_floor`, `outside`, `wan_ping`; `PERSIST_METRIC_COUNTS` {2, 2, 2, 2}; `PERSIST_DEVICE_ARRAY_LEN` | `firmware/core/data-model.h` |
| `devices[]` order | office, first_floor, outside, wan_ping, nas01 (system) | `firmware/core/data-model.h`, the generated block |
| Phase 7 model | `DeviceHistoryMeta` 60 B, `DeviceSegmentHeader` 24 B, `DeviceSegment` 228 B (6 rows × 4 points), `MAX_DEVICE_SLOTS` 4,096, `DEVICE_ID_MAX_LEN` 32 | the size assertions of `firmware/core/data-model.h` |
| Old engine | `SegmentSnapshot` 232 B, `PERSIST_SLOTS` 1,080 (45 days × 24) | `/api/storage-stats` of .189 and .170; `firmware/core/data-model.h` |
| History partition, .189 and .170 | 0x80000; `used_entries` 10,804, `free_entries` 5,324, `total_entries` 16,128; old ring 1,080 of 1,080 | the operator's reading of `/api/storage-stats`, 2026-11-24 |
| .173 | `layout.nvs_bytes` 446,464, `ota_0`, `ota_1`, `history`, `coredump` 0 bytes: an older ESPHome default partition table; `nvs_stats.available` false; `free_heap` 126,504 B, `min_free_heap` 2,213,076 B (with PSRAM), v7.6.10.1, uptime 292,050 s | the operator's readings of `/api/storage-stats` and `/api/status/full`, 2026-11-24 |
| `/api/storage-stats` | public (no login); fields `layout.history_bytes`, `nvs_stats.{available, used_entries, free_entries, total_entries}`, `history.{valid_segments, last_persist_epoch}`; the format string `"\"last_persist_epoch\":%u,\"namespace_initialized\":%s}}",` closes the answer | `handle_storage_stats_()` in `firmware/core/web-handler.h` |
| Sensor `outside` | old MAC in `config/sensors.json` and four `config/sensors-sat-*.json.bak`; new MAC from the operator, 2026-11-24 | `git grep` |
| Builds | C3 `firmware/esp32-c3-multi-sensor.yaml`; WROOM `firmware/esp32-wroom-32d-gw.yaml` from `bash scripts/provision.sh wroom`; S3 `firmware/esp32-s3-supermini-4m-gw.yaml` from `config/gateway-sat-s3-4m-173.json.bak` copied to `config/gateway.json` and the renderer | the planning session's rehearsal |
| OTA slots | `ota_0` 0x1B0000 = 1,769,472 B on the C3, WROOM and S3 4 MB tables | `partitions/*.csv` |
| Images at `a33a5cc` with the reference write path | C3 RAM 60,532 B, flash 1,438,054 B; WROOM RAM 72,256 B, flash 1,284,567 B; S3 RAM 66,844 B, flash 1,309,987 B (`main` alone: C3 RAM 60,436 B, flash 1,435,444 B) | the planning session's compiles with ESPHome 2026.4.1, 2026-11-24 |
| Playwright specs | 12 files; CI runs 7 fixture jobs | `find tests -name '*.spec.js'`; `.github/workflows/browser-tests.yml` |

**1. Exact current state.** Above. R4's structs, keys and generated constants are on `main`; nothing uses them.

**2. What the step changes.** One fragment gets the write path (S2, eight functions, T3); one handler gets the object `persist_v2`; the hourly lambda of the C3 YAML and of the generator gets one call; five config files get one MAC; the version and its regenerated files.

**3. Simplest thing that could go wrong.** The new rings fill the history partition and the old engine stops saving: the May plan's 360 slots would do it in about 5 days. The ring of 24 slots and the guard of 252 free entries prevent it, and the block `v2` reads the counts on each board.

**4. Three weeks of continuous operation.** After 24 hours each device's ring is full and wraps; its NVS entries stay at about 244 per device. The RAM that NVS keeps for the about 100 new blob keys stays: about 200 hash-list items, about 1.0 to 1.5 KB of heap (ESP-IDF 5.5.4 source; the page's figure of 5.5 KB for 1,000 keys counts one hash-list item per key, and a blob key has two). The WROOM's heap is the open risk; the floor of 1,024 B stops the step, and the operator watches `fleet` for a few days.

**5. Platform capabilities.**

| Capability | Version | Source, read 2026-11-24 |
|---|---|---|
| 126 entries of 32 B per page; a blob is a blob index entry and data chunks of 32 B entries; one empty page is kept for garbage collection; an overwrite adds the new pair first; "each 1000 keys consumes 5.5 KB of RAM" | ESP-IDF v5.5 | https://docs.espressif.com/projects/esp-idf/en/v5.5/esp32/api-reference/storage/nvs_flash.html |
| A 232-byte blob takes 10 entries (8 data, 2 overhead): confirmed by 1,080 × 10 + 4 = 10,804 used entries on .189 and .170 | — | the planning session's computation from the page above, and the operator's reading |
| ESPHome 2026.4.1's default ESP-IDF partition table: `app0`, `app1`, `nvs` 0x70000, no history partition; a serial upload writes the bootloader, the partition table and the image | ESPHome 2026.4.1 | `esphome/components/esp32/__init__.py` (`get_partition_csv`) and `esphome/__main__.py` (`upload_using_esptool`) of the 2026.4.1 wheel |
| `esptool --port <port> erase-flash`; "Flash memory erased successfully" | esptool 5.2.0 | `esptool erase-flash --help` and `esptool/cmds.py` of the version that ESPHome 2026.4.1 installs |

**6. Decision changes.** PLAN-046 records the operator's decisions of 2026-11-24 and the planning session's design of this step; it changes the R6 block of the plan of record, process guide §2.2 item 14 and §2.4, and producer contract rules 7.13 and 8.3.

| Leftover | Source | Disposition |
|---|---|---|
| Test board first | plan of record, R5b | Implemented: .173 first, after its USB flash; .189 and .170 only after `v2` passed on .173 |
| `.bin` size against the OTA slot | plan of record, R5b | Implemented: CHECKPOINT E (C3) and the block `image` (S3, WROOM) |
| WROOM `min_free_heap` after a fresh boot and a day later | plan of record, R5b | Implemented with the floor of PLAN-046: `dev ... floor`, `v2` and `wroom24` |
| PR #246 review A Q3, Q4 | `CURRENT-STATE.md`, Unimplemented Recommendations | Implemented: row k is the k-th metric with a history buffer; a device is found by its full id |
| PR #246 review A Q5 | the same | Decided: the full `DeviceSegment` in this step; the blob size and the EventLog format return in v7.7.1.4 |
| The C3 baseline of 52,080 B | PR #246, operator decision 7088682835 | Replaced by the reading before the upload (PLAN-046) |
| H-1, declaration order; L-1, boot test on both satellites (PR #233) | v7.7.1.4 | Still deferred to the bundle of v7.7.1.4 |
