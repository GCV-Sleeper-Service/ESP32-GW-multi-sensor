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
