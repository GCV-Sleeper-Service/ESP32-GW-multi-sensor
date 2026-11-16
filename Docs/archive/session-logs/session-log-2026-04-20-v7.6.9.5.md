# Session Log - v7.6.9.5: C3 httpd Stack Override Fix

_Date: 2026-04-20_

## Pre-implementation checks

- `VERSION` = `7.6.9.4` before implementation: PASS
- C3 template missing `external_components`: PASS
- Board-profile path already had `external_components`: PASS
- `firmware/local_components/web_server_idf/web_server_idf.cpp` still had `config.stack_size = 16384`: PASS
- `bash scripts/preflight.sh` on corrected repo state: PASS
- Checkpoint A (C3 template fix only): PASS
- Checkpoint B (preflight guard added): PASS
- Checkpoint C (`scripts/stress-test-httpd-stack.sh` executable): PASS

## Post-implementation verification

- `bash scripts/preflight.sh` = PASS
- `bash scripts/assemble-sensor-history.sh --check` = PASS
- `python3 scripts/render_sensor_config.py --check` = PASS
- Playwright 3sensor chromium: PASS
- Playwright 3sensor firefox: PASS (`102 passed, 47 skipped`)
- Playwright mixed chromium: PASS (`8 passed`)
- Playwright system chromium: PASS (`9 passed`)
- Playwright aggregator chromium: PASS (`11 passed, 1 skipped`)

## Device verification

| Check | C3 (189) | WROOM (190) | S3 (191) |
|---|---|---|---|
| `external_components` in YAML | PASS (added to template) | PASS (existing) | PASS (existing) |
| httpd_stack_watermark_bytes | `12768` | `12964` | `12944` |
| Stress test minimum watermark | `12768` (PASS, `>= 10000`) | N/A | N/A |
| free_heap | `57144` | `36244` | `54420` |
| `/api/status` shape unchanged | PASS | PASS | PASS |

## Notes

- Root cause confirmed: the C3 template YAML was missing top-level `external_components`, so the local `web_server_idf` override never compiled into the C3 build.
- No architecture-conditional stack sizing is needed. Measured C3 watermark with the active 16 KB override is ~12.8 KB at rest and under the scripted 5-wave stress test.
- `git grep` over tracked firmware sources found no `CONFIG_IDF_TARGET_ARCH_RISCV` references. The symbol still appears in generated ESP-IDF build metadata under `firmware/.esphome/build/.../sdkconfig*`, which is expected toolchain output, not repo source.
