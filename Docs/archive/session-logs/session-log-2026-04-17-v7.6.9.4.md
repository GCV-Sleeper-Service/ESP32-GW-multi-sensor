# Session Log - 2026-04-17 - v7.6.9.4

PR: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/193
Branch: codex/v7.6.9.4-adaptive-cap-boot-gate-20260417
Scope: heap-adaptive history reserve cap + status-gated initial history boot (#139 partial)

## Checkpoint A

- `grep -c csv.reserve(std::min(est_bytes, adaptive_cap)) firmware/core/web-handler.h` -> `2`
- `grep -c csv.reserve(std::min(est_bytes, (size_t)60000)) firmware/core/web-handler.h` -> `0`
- `grep -c esp_get_free_heap_size() firmware/core/web-handler.h` -> `3`
- `grep -c adaptive_cap firmware/core/web-handler.h` -> `8`
- `git diff firmware/core/web-handler.h | grep -c '^+'` -> `24`
- `git diff --name-only firmware/` -> `firmware/core/web-handler.h`

## Checkpoint B

Updated prompt re-read from `origin/main` before rerun.

- `grep -c _v7_9_4_kickHistoryOnce dashboard/core/boot.js` -> `3`
- `grep -c _v7_9_4_historyKicked dashboard/core/boot.js` -> `3`
- `grep historyBootstrapTimerId = setTimeout dashboard/core/boot.js` -> `historyBootstrapTimerId = setTimeout(_v7_9_4_kickHistoryOnce, 15000);`
- `grep -c loadStatusSnapshot().then dashboard/core/boot.js` -> `1`
- `grep -c historyBootstrapTimerId = setTimeout dashboard/core/boot.js` -> `1`
- `git diff dashboard/core/boot.js | grep -c ^-.*historyBootstrapTimerId` -> `1`
- `git diff dashboard/core/boot.js | grep -c ^-.*10000` -> `1`
- `grep -c 15000 dashboard/core/boot.js` -> `2`

Note: the last count includes an unrelated existing `pollV2Live` 15 s interval in the same file. The boot-gate fallback line itself is present exactly once.

## Pipeline and Preflight

- `bash scripts/assemble-sensor-history.sh --write` -> PASS
- `python3 scripts/render_sensor_config.py --check` -> PASS
- `bash scripts/assemble-sensor-history.sh --check` -> PASS
- `bash scripts/preflight.sh` -> PASS

## Playwright

Initial 3sensor Chromium run exposed a real bug in the literal prompt block:
- `_v7_9_4_kickHistoryOnce()` called `loadHistory().catch(...)`
- `loadHistory()` returns `undefined` on the normal happy path
- fix applied: `Promise.resolve(loadHistory()).catch(function(){})`

Final sequential matrix after the fix:

| Fixture set | Command shape | Pass | Fail | Skip |
|---|---|---:|---:|---:|
| 3sensor (chromium) | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | 102 | 0 | 47 |
| 3sensor (firefox) | `FIXTURE_SET=3sensor npx playwright test --project=firefox` | 102 | 0 | 47 |
| mixed (chromium) | `FIXTURE_SET=mixed npx playwright test --grep Mixed --project=chromium` | 8 | 0 | 0 |
| system (chromium) | `FIXTURE_SET=system npx playwright test --grep System --project=chromium` | 9 | 0 | 0 |
| aggregator (chromium) | `FIXTURE_SET=aggregator npx playwright test --grep Aggregator --project=chromium` | 11 | 0 | 1 |

## Device verification

Hardware flashing and smoke tests were not completed in this session.
Operator explicitly requested to skip flashing after an OTA run appeared to hang.

| Check | C3 (189) | WROOM (190) | S3 (191) |
|---|---|---|---|
| Firmware flashed in this session | Skipped by operator | Skipped by operator | Skipped by operator |
| `curl /history/office/temp` returns 200 | Not run | Not run | Not run |
| Response CSV size (bytes) | Not run | Not run | Not run |
| Dashboard history charts render within 15 s | Not run | Not run | Not run |
| `/api/status/full` -> free_heap | Not run | Not run | Not run |
| `/api/status/full` -> httpd_stack_watermark_bytes | Not run | Not run | Not run |
| `/api/status/full` -> min_free_heap | Not run | Not run | Not run |
| `/api/status` still returns only `{ok, role, id}` | Not run | Not run | Not run |
| No crash/reboot on 3 consecutive history fetches | Not run | Not run | Not run |
| Dashboard SRAM / Flash / PSRAM fields populate | Not run | Not run | Not run |
| Dashboard Free Heap / Uptime populate in both modes | Not run | Not run | Not run |

## Compile notes

- `esphome compile firmware/esp32-c3-multi-sensor.yaml` -> PASS
- `esphome run firmware/esp32-c3-multi-sensor.yaml` initially blocked on ESPHome's interactive upload chooser in the non-interactive session
- a follow-up explicit-device OTA attempt was interrupted by the operator before completion

## Scope notes

- No changes to `handle_status_`
- No changes to `handle_status_full_`
- No SEC-ADR file changes
- No partition file changes
- Branch remains draft because the mandatory three-board device gate is incomplete
