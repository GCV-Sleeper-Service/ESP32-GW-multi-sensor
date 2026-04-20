# Session Log - v7.6.9.5: C3 httpd Stack Watermark Investigation

_Date: 2026-04-19_

## Pre-implementation checks

- `VERSION` = `7.6.9.4` ?
- `bash scripts/preflight.sh` = PASS ?
- Checkpoint A (stress test script) = ?
- Checkpoint B (conditional stack size) = ?
- Checkpoint C (PATCH_INFO) = ?
- Checkpoint D (patch script) = ?
- Checkpoint E (version bump + pipeline) = ?
- Checkpoint F (changelog + lessons) = ?

## Post-implementation verification

- `bash scripts/preflight.sh` = PASS
- `bash scripts/assemble-sensor-history.sh --check` = PASS
- `python3 scripts/render_sensor_config.py --check` = PASS
- Playwright 3sensor chromium: PASS (full suite green)
- Playwright 3sensor firefox: 102 passed / 47 skipped
- Playwright mixed chromium: 8 passed
- Playwright system chromium: 9 passed
- Playwright aggregator chromium: 11 passed / 1 skipped

## Device verification

### Pre-bump baseline (operator: run stress test on CURRENT v7.6.9.4 firmware)

| Measurement | C3 (189) |
|---|---|
| At-rest watermark (v7.6.9.4, from ?0) | 636 |
| Stress test minimum watermark (5 waves) | 404 |

### Post-bump stress test (operator: flash v7.6.9.5, run stress test)

| Measurement | C3 (189) |
|---|---|
| At-rest watermark (v7.6.9.5, 20 KB stack) | 632 |
| Stress test minimum watermark (5 waves) | 632 |
| **Gate: minimum = 2000** | **FAIL** |

### Smoke test - all boards

| Check | C3 (189) | WROOM (190) | S3 (191) |
|---|---|---|---|
| `/api/status/full` returns 200, correct version | | | |
| `httpd_stack_watermark_bytes` | | | |
| `free_heap` | | | |
| `min_free_heap` | | | |
| `/history/office/temp` returns 200 | | | |
| `/api/status` returns only {ok,role,id} | | | |
| No crash/reboot after test | | | |

Build blocker: The generated `firmware/esp32-c3-multi-sensor.yaml` does not include an `external_components` reference to `firmware/local_components/web_server_idf`, and `firmware/.esphome/build/esp32-c3-multi` contains no `20480` stack literal. The flashed v7.6.9.5 binary therefore appears not to include the conditional local-component override.
