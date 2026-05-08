# Session Log - v7.7.1.0: Health-Check Telemetry Task

_Date: 2026-05-07_

## Context

This session implemented the first Phase 7 firmware step: a periodic health-check
task that logs runtime telemetry without adding new HTTP endpoints or NVS writes.

Scope included:

- new firmware fragment `firmware/core/health-check.h`
- assembly manifest update for the ninth fragment
- `on_boot` startup hook for the health-check task
- preflight coverage for the new fragment
- version bump and required release/documentation updates

No existing firmware fragment logic was modified beyond version-source updates made
by `bash scripts/bump-version.sh 7.7.1.0`.

## Functional Changes

### 1. New health-check firmware fragment

Added `firmware/core/health-check.h` with:

- `health_check_task_()`
- `start_health_check_task_()`
- 30-second boot stabilization delay
- 60-second recurring telemetry interval

The task logs:

- internal free heap
- total free heap
- internal minimum free heap
- total minimum free heap
- `httpd` stack watermark
- health-check task stack watermark
- history partition `nvs_get_stats()` output
- uptime

### 2. Assembly pipeline update

Added `firmware/core/health-check.h` to `scripts/assemble-sensor-history.sh`
between `nvs-persistence.h` and `deferred-management.h`, increasing the firmware
assembly from 8 fragments to 9.

### 3. Boot startup wiring

Added a new `on_boot` priority-600 entry in `firmware/esp32-c3-multi-sensor.yaml`
that calls `start_health_check_task_()` after WiFi and SNTP are available.

### 4. Preflight coverage

Added `firmware/core/health-check.h` existence validation to `scripts/preflight.sh`
and updated the explicit fragment lists/counts used by the Phase Y assembly checks
so the ninth fragment is treated as canonical instead of drift.

## Validation

### Checkpoints

- `grep -c 'xTaskCreate.*health_check' firmware/core/health-check.h` -> `1`
- `grep -c 'nvs_get_stats' firmware/core/health-check.h` -> `2`
- `grep -c 'esp_get_free_internal_heap_size' firmware/core/health-check.h` -> `1`
- `grep -c 'heap_caps_get_minimum_free_size' firmware/core/health-check.h` -> `1`
- `grep -c 'uxTaskGetStackHighWaterMark' firmware/core/health-check.h` -> `2`
- `grep -c 'HEALTH_CHECK_INTERVAL_S' firmware/core/health-check.h` -> `4`
- `ls firmware/core/*.h | wc -l` -> `9`
- `grep -c 'health-check.h' scripts/assemble-sensor-history.sh` -> `1`
- `bash scripts/assemble-sensor-history.sh --list | grep -c 'health-check'` -> `1`
- `bash scripts/assemble-sensor-history.sh --check` -> `PASS`

### Pipeline

Completed in required order:

- `bash scripts/assemble-sensor-history.sh --write`
- `bash scripts/bundle-dashboard.sh --write`
- `python3 scripts/render_sensor_config.py --write`
- `node tests/fixtures/generate-fixtures.js`
- `python3 scripts/render_sensor_config.py --write`
- `bash scripts/build-dashboard.sh --write`
- `bash scripts/minify-dashboard.sh`
- `bash scripts/generate-header.sh`
- `python3 scripts/render_sensor_config.py --check`

### Gates

- `bash scripts/preflight.sh` -> PASS
- `bash scripts/assemble-sensor-history.sh --check` -> PASS

### Playwright Fixture Table

| Fixture Set | Command | Result |
|---|---|---|
| 3sensor Chromium | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | `96 passed`, `53 skipped` |
| 3sensor Firefox | `FIXTURE_SET=3sensor npx playwright test --project=firefox` | `96 passed`, `53 skipped` |
| Mixed Chromium | `FIXTURE_SET=mixed npx playwright test tests/browser/sensor-cards.spec.js tests/browser/theme-export.spec.js --grep "Mixed" --project=chromium` | `8 passed` |
| System Chromium | `FIXTURE_SET=system npx playwright test tests/browser/system-devices.spec.js --project=chromium` | `8 passed` |
| Aggregator Chromium | `FIXTURE_SET=aggregator npx playwright test tests/browser/aggregator.spec.js --project=chromium` | `11 passed` |

### ESPHome Output

No `esphome compile` was run in this session. YAML validation was covered by:

- `esphome config firmware/esp32-c3-multi-sensor.yaml` -> PASS via `bash scripts/preflight.sh`

Compile/device testing remains a post-merge operator step per the Phase 7 prompt.

## Stops And Recoveries

### 1. Pre-implementation prompt gate used a stale grep

The literal gate from the prompt was:

- `grep -c '\.h"' scripts/assemble-sensor-history.sh`

Observed result before any edits:

- `9`

Prompt expectation:

- `8`

Cause:

- the grep matched the 8 module entries plus one additional non-module `.h"` string
  in the script, so the gate was broader than the condition it intended to verify

Recovery:

- stopped at the gate and reported the mismatch
- resumed only after operator approval to continue
- documented the issue here for future prompt authors

Future prevention:

- use an anchored module-line check such as
  `grep -c '^  "firmware/core/.*\.h"$' scripts/assemble-sensor-history.sh`
- or use `bash scripts/assemble-sensor-history.sh --list | grep -c 'firmware/core/'`
- derive checkpoint greps mechanically from the target block so they count only the
  intended lines

### 2. System fixture Playwright grep matched an unrelated generic test

The literal fixture command from the prompt was:

- `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium`

Observed result:

- `1 failed`, `9 passed`
- failing test: `tests/browser/sensor-cards.spec.js` / `five sensor cards are rendered`

Cause:

- the broad `"System"` grep matched the intended `tests/browser/system-devices.spec.js`
  tests plus an unrelated generic sensor-card test name, so the command was no longer
  scoped to the system fixture suite

Recovery:

- reran the intended suite directly with
  `FIXTURE_SET=system npx playwright test tests/browser/system-devices.spec.js --project=chromium`
- result: `8 passed`

Future prevention:

- use spec-file targeting for fixture-specific gates when the fixture name is a common
  word
- if grep is required, anchor it to the suite prefix instead of a single broad token

### 3. Parallel Playwright suite launch caused local web server port collision

Observed failure while rerunning narrowed suites:

- `Error: listen EADDRINUSE: address already in use 127.0.0.1:3737`

Cause:

- the system and aggregator Playwright runs were started in parallel and both attempted
  to launch the shared test web server on port `3737`

Recovery:

- allowed the aggregator suite to finish
- reran the system suite by itself

Future prevention:

- do not run Playwright commands in parallel when they share the same configured local
  web server port
- keep fixture suite execution serialized unless the harness is explicitly isolated per
  process

## Review Follow-Up

### Review assessment

- Warranted:
  - Gemini: `uxTaskGetStackHighWaterMark()` in this ESP-IDF returns bytes, so the
    `* sizeof(StackType_t)` conversion in `firmware/core/health-check.h` was wrong
  - Copilot: the `ESP_LOGI` health output was not guaranteed to appear with
    `logger.level: WARN`
- Not warranted:
  - Copilot: `xTaskCreate()` stack sizing was already correct for this ESP-IDF fork,
    which documents stack depth in bytes rather than words
  - Copilot: renaming `start_health_check_task_()` was style-only and not a defect
  - Copilot: moving the preflight existence check into a different block was style-only
  - Copilot: changelog "4096 bytes" concern depended on the incorrect stack-depth claim
  - Gemini: adding extra self-contained includes inside the fragment was unnecessary in
    this assembled-fragment architecture

### What changed

- `firmware/core/health-check.h`
  - removed the incorrect `sizeof(StackType_t)` multiplication from
    `httpd_stack_wm` and `hc_stack_wm` logging so reported values stay in ESP-IDF
    byte units
- `firmware/esp32-c3-multi-sensor.yaml`
  - raised global `logger.level` from `WARN` to `INFO`
  - kept noisy subsystems constrained with `wifi: ERROR` and `api: ERROR`
  - this preserves visibility of `HEALTH:` telemetry without reopening the general
    Wi-Fi/API log noise that `WARN` had been suppressing

### Recovery note

An intermediate logger attempt failed validation:

- command: `esphome config firmware/esp32-c3-multi-sensor.yaml`
- error: `The configured log level for history (INFO) must not be less severe than the global log level (WARN).`

Cause:

- ESPHome does not allow a per-tag log level to be more verbose than the global level

Recovery:

- changed the global level to `INFO` instead of trying to override only the `history`
  tag

Future prevention:

- when a review asks for specific log visibility, validate against ESPHome's global vs
  tag-level severity rule before assuming a per-tag override is legal

## Section 10 Device Testing

Per operator request, §10 was executed on the C3 satellite before merge to capture
actual baseline values.

### Commands run

- `bash scripts/provision.sh satellite`
- `esphome clean firmware/esp32-c3-multi-sensor.yaml`
- `esphome compile firmware/esp32-c3-multi-sensor.yaml`
- `timeout 300 esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189`
- `esphome clean firmware/esp32-c3-multi-sensor.yaml`
- `sleep 90`
- `curl -s http://192.168.120.189/api/status | python3 -m json.tool`
- `curl -s -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full | python3 -m json.tool`
- `esphome logs firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189`

### Results

- Compile: PASS
- OTA upload to `192.168.120.189`: PASS
- `/api/status`: PASS
- `/api/status/full`: PASS
- `HEALTH:` log capture: PASS

### Captured runtime values

- `/api/status/full`
  - `version`: `v7.7.1.0`
  - `uptime_seconds`: `98`
  - `free_heap`: `51696`
  - `free_heap_internal`: `51696`
  - `free_heap_total`: `59452`
  - `min_free_heap`: `43228`
  - `httpd_stack_watermark_bytes`: `12932`
  - `ping_stack_watermark_bytes`: `1552`
- serial `HEALTH:` output at `23:59:11`
  - `heap_free=39704`
  - `heap_free_total=47460`
  - `min_free=29776`
  - `min_free_total=29776`
  - `httpd_stack_wm=12932`
  - `hc_stack_wm=2176`
  - `nvs_used=5274`
  - `nvs_free=10854`
  - `nvs_total=16128`
  - `nvs_ns_count=1`

### Interpretation

- the new `HEALTH:` task is live on-device and reporting all expected telemetry groups:
  heap, stack watermarks, and NVS stats
- `httpd_stack_wm=12932` matches the expected C3 baseline band from the prompt
- `nvs_used`, `nvs_free`, and `nvs_total` are all non-zero and sane
- `hc_stack_wm=2176` indicates comfortable remaining headroom inside the 4096-byte
  task stack
