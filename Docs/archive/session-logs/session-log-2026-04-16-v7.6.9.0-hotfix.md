# Session Log — v7.6.9.0 Hotfix
Date: 2026-04-16
Branch: codex/v7.6.9.0-device-card-cleanup (PR #183 branch)

## Scope
- Fix 1: Revert broken polling additions in `dashboard/core/status-snapshot.js`.
- Fix 2: Make Flash/SRAM static silicon constants and stop emitting `esp_flash_compat.h` include in generated YAMLs.
- Fix 3: Document C3 `httpd_stack_watermark_bytes` investigation plan (measurement-only, no code change).

## Commands Run
1. Pre-implementation verification gate commands from prompt §2.
2. Checkpoint A commands for `POLL_SHARED` + `loadStatusSnapshot` references.
3. Checkpoint B commands for source-level runtime-call removal and helper presence.
4. Sensor YAML verification and Checkpoint C count checks.
5. Rebuild pipeline sequence:
   - `bash scripts/bundle-dashboard.sh --write`
   - `python3 scripts/render_sensor_config.py --write`
   - `node tests/fixtures/generate-fixtures.js`
   - `python3 scripts/render_sensor_config.py --write`
   - `bash scripts/build-dashboard.sh --write`
   - `bash scripts/minify-dashboard.sh`
   - `bash scripts/generate-header.sh`
   - `python3 scripts/render_sensor_config.py --check`
6. `bash scripts/preflight.sh`
7. Playwright sequence (sequential):
   - `FIXTURE_SET=3sensor npx playwright test --project=chromium`
   - `FIXTURE_SET=3sensor npx playwright test --project=firefox`
   - `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium`
   - `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium`
   - `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium`

## Checkpoint Outputs

### Checkpoint A
- `POLL_SHARED` now exactly:
  - `var POLL_SHARED = ['/text_sensor/Current%20Time', '/sensor/WiFi%20Signal'];`
- `grep -c "Free%20Heap\|/sensor/Uptime" dashboard/core/status-snapshot.js` => `0`
- `loadStatusSnapshot` references total across target files => `7`
- `git diff dashboard/core/status-snapshot.js` => one-line change in `POLL_SHARED`

### Checkpoint B
- `grep -c "esp_flash_get_size\|heap_caps_get_total_size(MALLOC_CAP_INTERNAL)" scripts/render_sensor_config.py` => `0`
- `grep -c "heap_caps_get_total_size(MALLOC_CAP_SPIRAM)" scripts/render_sensor_config.py` => `1`
- `grep -c "SRAM_KB_BY_CHIP\|_flash_size_to_kb_string\|_sram_size_for_chip" scripts/render_sensor_config.py` => `8`
- `grep "esp_flash_compat.h" scripts/render_sensor_config.py` => no match
- `ls firmware/esp_flash_compat.h` => file exists

### Checkpoint C
Note: repository uses `*-gw.yaml` filenames for WROOM/S3.
- `grep -c 'return std::string("400 KB")' firmware/esp32-c3-multi-sensor.yaml` => `1`
- `grep -c 'return std::string("4096 KB")' firmware/esp32-c3-multi-sensor.yaml` => `1`
- `grep -c 'return std::string("520 KB")' firmware/esp32-wroom-32d-gw.yaml` => `1`
- `grep -c 'return std::string("512 KB")' firmware/esp32-s3-devkitc1-n16r8-gw.yaml` => `1`
- `grep -c 'return std::string("16384 KB")' firmware/esp32-s3-devkitc1-n16r8-gw.yaml` => `1`
- `grep -c 'esp_flash_compat.h' firmware/*.yaml` => all `0`
- `grep -c "heap_caps_get_total_size(MALLOC_CAP_SPIRAM)" firmware/esp32-s3-devkitc1-n16r8-gw.yaml` => `1`

## Build/Test Results
- `python3 scripts/render_sensor_config.py --check` => PASS
- `bash scripts/preflight.sh` => PASS (full suite)

### Playwright Fixture Matrix
| Fixture set | Command | Result |
|---|---|---|
| 3sensor (chromium) | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | 99 passed, 45 skipped |
| 3sensor (firefox) | `FIXTURE_SET=3sensor npx playwright test --project=firefox` | 99 passed, 45 skipped |
| mixed (chromium) | `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | 7 passed |
| system (chromium) | `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium` | 8 passed |
| aggregator (chromium) | `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | 11 passed, 1 skipped |

## Fix 3 — httpd_stack_watermark_bytes investigation

### Baseline (pre-hotfix, v7.6.9.0 @ 9b761ec)
From operator's curl output captured 2026-04-16 ~01:20 PDT:
- C3 (192.168.120.189):  httpd_stack_watermark_bytes: 636,   min_free_heap: 5612
- WROOM (192.168.120.190): httpd_stack_watermark_bytes: 13236, min_free_heap: 22016
- S3 (192.168.120.191):   httpd_stack_watermark_bytes: 12704, min_free_heap: 8395704

Observation: WROOM and S3 are healthy (>12 KB stack free). C3 at 636 bytes is
alarming — one deeper call chain from stack overflow. The 16 KB patched httpd
stack (LESSON-OPS-097) is nearly exhausted on the C3 only.

### Comparison targets
To determine whether v7.6.9.0 regressed C3 stack usage, we need baselines from
the most recent pre-Phase-V release.

Operator actions:
1. Flash C3 at tag `v7.6.8.2` (last known-good).
2. Let it run = 10 minutes, exercise dashboard via SSE + polling + history.
3. Capture: `curl -s -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full | jq '.httpd_stack_watermark_bytes, .min_free_heap, .free_heap'`
4. Flash C3 at the hotfix commit (this session, after §5 Fixes 1+2 merged).
5. Repeat step 2–3.

### Decision table

| v7.6.8.2 C3 watermark | v7.6.9.0-hotfix C3 watermark | Action |
|-----------------------|------------------------------|--------|
| = 4000                | = 4000                       | Healthy; merge PR. No further work. |
| = 4000                | < 2000                       | v7.6.9.0 introduced a regression. File BUG-xxx. Do NOT merge until root-caused. |
| < 2000                | < 2000 (similar value)       | Pre-existing issue, not caused by this PR. File BUG-xxx for follow-up. Merge PR with note in release. |
| < 2000                | much lower than 8.2          | Regression on top of pre-existing issue. Root-cause before merge. |

### Results

_Operator fills this in after re-flashing both versions:_

| Build             | httpd_stack_watermark_bytes | min_free_heap | free_heap | Uptime when measured |
|-------------------|-----------------------------|---------------|-----------|---------------------|
| v7.6.8.2          |                             |               |           |                     |
| v7.6.9.0-hotfix   |                             |               |           |                     |

### Decision

_Operator records which row of the decision table applies and the chosen action._

## Hotfix 2 - SRAM/Flash publish + /api/status/full polling

### Pre-Implementation Verification Gate (updated checks)
- `grep -cE '"free_heap"|"uptime_seconds"' firmware/core/web-handler.h` => `2`
- `awk '/void handle_status_\(AsyncWebServerRequest/,/^  }$/' firmware/core/web-handler.h | grep -cE '"free_heap"|"uptime_seconds"'` => `0`
- `bash scripts/preflight.sh` => PASS

### Checkpoint A (Fix 1)
- `grep -c '"    update_interval: never"' scripts/render_sensor_config.py` => `4` (this count includes unrelated existing `never` entries outside Flash/SRAM blocks)
- `grep -B 6 '"    update_interval: 60s"' scripts/render_sensor_config.py | grep -c 'name: "Flash Size"'` => `1`
- `grep -B 6 '"    update_interval: 60s"' scripts/render_sensor_config.py | grep -c 'name: "SRAM Size"'` => `1`
- `grep -c 'heap_caps_get_total_size(MALLOC_CAP_SPIRAM)' scripts/render_sensor_config.py` => `1`

### Checkpoint B (Fix 2)
- `grep "fetch(ESP_HOST" dashboard/core/status-snapshot.js` => `return fetch(ESP_HOST + '/api/status/full', {cache:'no-store', credentials:'same-origin'})`
- `grep -c "/api/status'" dashboard/core/status-snapshot.js` => `0`
- `grep -c "/api/status/full" dashboard/core/status-snapshot.js` => `1`

### Pipeline Outputs
- `bash scripts/bundle-dashboard.sh --write` => PASS
- `python3 scripts/render_sensor_config.py --write` => PASS
- `node tests/fixtures/generate-fixtures.js` => PASS
- `python3 scripts/render_sensor_config.py --write` => PASS
- `bash scripts/build-dashboard.sh --write` => PASS
- `bash scripts/minify-dashboard.sh` => PASS
- `bash scripts/generate-header.sh` => PASS
- `python3 scripts/render_sensor_config.py --check` => PASS
- `bash scripts/preflight.sh` => PASS

### Playwright Fixture Matrix (Hotfix 2)
| Fixture set | Command | Result |
|---|---|---|
| 3sensor (chromium) | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | 99 passed, 45 skipped |
| 3sensor (firefox) | `FIXTURE_SET=3sensor npx playwright test --project=firefox` | 99 passed, 45 skipped |
| mixed (chromium) | `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | 7 passed |
| system (chromium) | `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium` | 8 passed |
| aggregator (chromium) | `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | 11 passed, 1 skipped |

### Device Verification Table (operator fills after flashing)
| Check | C3 (189) | WROOM (190) | S3 (191) |
|---|---|---|---|
| Dashboard SSE: SRAM shows 400 / 520 / 512 KB (not blank) | | | |
| Dashboard SSE: Flash shows 4096 / 4096 / 16384 KB (not blank) | | | |
| Dashboard SSE: PSRAM shows None / None / value | | | |
| Dashboard SSE: Free Heap populates | | | |
| Dashboard SSE: Uptime populates | | | |
| Dashboard Polling: Free Heap populates within 30 s | | | |
| Dashboard Polling: Uptime populates within 30 s | | | |
| Dashboard Polling: no 500 errors in event log | | | |
| Dashboard Polling: no new errors in browser console | | | |
| `curl /api/status` returns only {ok,role,id} (SEC-ADR still honored) | | | |
| `curl /api/status/full -u user:pass` returns enriched body | | | |
| `curl /history/office/temp` (no auth) still returns 200 | | | WROOM: expected unstable - see #139 |
