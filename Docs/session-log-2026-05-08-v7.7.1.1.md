# Session Log - v7.7.1.1: Chunked HTTP Streaming (BUG-082 Fix)

_Date: 2026-05-08_

## Context

This session implemented the Phase 7 BUG-082 fix by rewriting the two history
HTTP handlers to stream CSV data with chunked responses instead of building a
full `std::string` in RAM.

Primary scope:

- `firmware/core/web-handler.h`
- `Docs/changelog.md`
- `CURRENT-STATE.md`
- `VERSION`
- `prompts/prompt-index-and-workflow.md`

Regenerated artifacts and version-source updates were produced by the required
repo pipeline and `bash scripts/bump-version.sh 7.7.1.1`.

No dashboard behavior logic, aggregator proxy logic, `nvs-persistence.h`, or
`data-model.h` history formatting behavior was intentionally changed.

## Functional Changes

### 1. Chunked history helpers

Added two local helpers in `firmware/core/web-handler.h`:

- `send_snapshot_series_chunk_()`
- `send_history_buffer_chunk_()`

Both helpers preserve the existing CSV wire format exactly:

- `epoch,value\n`

### 2. `handle_history_()` rewritten

`handle_history_()` now:

- casts `AsyncWebServerRequest` to raw `httpd_req_t *`
- sets `text/plain` and `Cache-Control: no-store`
- streams each persisted NVS segment with `httpd_resp_send_chunk()`
- keeps `maybe_yield_nvs_scan_()` in the NVS loop
- streams newer RAM buffer entries after flash-backed entries
- terminates with the required empty chunk

### 3. `handle_api_v2_history_()` rewritten

`handle_api_v2_history_()` now streams the RAM buffer directly with
`httpd_resp_send_chunk()` and no longer allocates a full CSV response string.

### 4. Release/documentation sync

- version bumped to `7.7.1.1`
- `CURRENT-STATE.md` advanced to `v7.7.1.1`
- `Docs/changelog.md` updated with the BUG-082 fix entry
- `prompts/prompt-index-and-workflow.md` Phase 7 step table corrected to the
  actual planning sequence from the 2026-05-07 rewrite

## Validation

### Checkpoints

- `grep -c 'send_snapshot_series_chunk_' firmware/core/web-handler.h` -> `2`
- `grep -c 'send_history_buffer_chunk_' firmware/core/web-handler.h` -> `2`
- `grep -c 'httpd_resp_send_chunk' firmware/core/web-handler.h` -> `8`
- `grep -c 'csv\.reserve' firmware/core/web-handler.h` -> `0`
- `grep -c 'httpd_resp_set_type' firmware/core/web-handler.h` -> `2`
- `grep -c 'maybe_yield_nvs_scan_' firmware/core/web-handler.h` -> `2`
- `grep -c 'allocate_snapshot_\|delete snapshot' firmware/core/web-handler.h` -> `6`
- `bash scripts/assemble-sensor-history.sh --check` -> `PASS`

### Pipeline

Completed in repo order:

- `bash scripts/bump-version.sh 7.7.1.1`
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
| Mixed Chromium | `FIXTURE_SET=mixed npx playwright test tests/browser/sensor-cards.spec.js --project=chromium` | `22 passed`, `5 skipped` |
| System Chromium | `FIXTURE_SET=system npx playwright test tests/browser/system-devices.spec.js --project=chromium` | `8 passed` |
| Aggregator Chromium | `FIXTURE_SET=aggregator npx playwright test tests/browser/aggregator.spec.js --project=chromium` | `11 passed` |

### Review Follow-Up Validation

After addressing the PR review comments:

- `bash scripts/assemble-sensor-history.sh --write` -> PASS
- `bash scripts/assemble-sensor-history.sh --check` -> PASS
- `bash scripts/preflight.sh` -> PASS
- `FIXTURE_SET=3sensor npx playwright test --project=chromium` -> `96 passed`, `53 skipped`
- `FIXTURE_SET=3sensor npx playwright test --project=firefox` -> `96 passed`, `53 skipped`
- `FIXTURE_SET=mixed npx playwright test tests/browser/sensor-cards.spec.js --project=chromium` -> `22 passed`, `5 skipped`
- `FIXTURE_SET=system npx playwright test tests/browser/system-devices.spec.js --project=chromium` -> `8 passed`
- `FIXTURE_SET=aggregator npx playwright test tests/browser/aggregator.spec.js --project=chromium` -> `11 passed`

### ESPHome Output

No `esphome compile` was run in this session.

YAML/config validation coverage came from:

- `bash scripts/preflight.sh` -> includes ESPHome config validation

Device flash/test steps remain operator-run post-merge per the Phase 7 prompt.

## Stops And Recoveries

### 1. Checkpoint B stop: assembly check failed before assembled artifact write

Stopped command:

- `bash scripts/assemble-sensor-history.sh --check`

Observed failure:

- `FAIL: Assembly SHA-256 mismatch (non-generated regions differ)`

Cause:

- the prompt required `--check` immediately after fragment edits, but the repo's
  assembly gate compares the committed assembled artifact against current
  fragment content
- once `firmware/core/web-handler.h` changed, `dashboard/sensor_history_multi.h`
  was expected to drift until `bash scripts/assemble-sensor-history.sh --write`
  was run

Fix:

- ran `bash scripts/assemble-sensor-history.sh --write`
- reran `bash scripts/assemble-sensor-history.sh --check`
- result: PASS

Future prevention:

- checkpoint prompts should explicitly pair fragment edits with
  `assemble-sensor-history.sh --write` before the identity `--check`
- when a step edits any `firmware/core/*.h` fragment, treat assembled-header
  regeneration as mandatory, not optional

### 2. Playwright stop: fixture suites were launched in parallel against one local server port

Stopped commands:

- `FIXTURE_SET=3sensor npx playwright test --project=chromium`
- `FIXTURE_SET=3sensor npx playwright test --project=firefox`
- `FIXTURE_SET=mixed npx playwright test tests/mixed.spec.js --project=chromium`
- `FIXTURE_SET=system npx playwright test tests/system.spec.js --project=chromium`
- `FIXTURE_SET=aggregator npx playwright test tests/aggregator.spec.js --project=chromium`

Observed failures:

- `Error: listen EADDRINUSE: address already in use 127.0.0.1:3737`
- `Error: No tests found.`
- `Internal error: step id not found: fixture@44`

Cause:

- the five Playwright runs were started in parallel
- this repo's Playwright config shares one `webServer.port` (`3737`) and one
  shared output directory (`tests/playwright-results`)
- the prompt's `tests/mixed.spec.js`, `tests/system.spec.js`, and
  `tests/aggregator.spec.js` paths were stale relative to the current repo,
  where those specs now live under `tests/browser/`

Fix:

- stopped the parallel run
- verified current spec locations under `tests/browser/`
- cleared collided artifacts with `rm -rf tests/playwright-results tests/playwright-report`
- reran the suites serially with current paths

Serial commands used:

- `FIXTURE_SET=3sensor npx playwright test --project=chromium`
- `FIXTURE_SET=3sensor npx playwright test --project=firefox`
- `FIXTURE_SET=mixed npx playwright test tests/browser/sensor-cards.spec.js --project=chromium`
- `FIXTURE_SET=system npx playwright test tests/browser/system-devices.spec.js --project=chromium`
- `FIXTURE_SET=aggregator npx playwright test tests/browser/aggregator.spec.js --project=chromium`

Future prevention:

- do not run multiple Playwright commands in parallel when they share the same
  configured local web-server port and artifact directory
- Phase 7 prompts should use the current `tests/browser/*` paths instead of the
  pre-split `tests/*.spec.js` paths
- fixture-gate commands should be reviewed against current repo structure before
  prompt publication

### 3. Prompt contradiction: declared scope vs mandatory version-bump side effects

Observed contradiction:

- the prompt's scope section listed only `web-handler.h`, changelog,
  `CURRENT-STATE.md`, and `VERSION` as mutable
- the same prompt also required `bash scripts/bump-version.sh 7.7.1.1`

Cause:

- this repo's canonical version-bump script updates multiple version sources,
  including:
  - `dashboard/core/app-shell.js`
  - `firmware/core/config.h`
  - `firmware/core/data-model.h`
  - `scripts/render_sensor_config.py`
  - `tests/fixtures/generate-fixtures.js`

Fix:

- followed Rule 2 and the canonical repo workflow
- retained the version-only source updates produced by `bump-version.sh`
- documented the contradiction here rather than silently pretending the scope
  list was complete

Future prevention:

- prompts that require `bump-version.sh` should explicitly whitelist all known
  version-source files the script modifies
- PRE-PR scope gates should distinguish logic changes from version-only sync
  updates produced by canonical repo tooling

## Evidence Summary

- Checkpoint A passed after helper insertion and before handler rewrites
- Checkpoint B passed after assembled-artifact regeneration
- `bash scripts/preflight.sh` passed after full regeneration
- all five required Playwright fixture gates passed after serial rerun with
  current spec paths
- no dashboard source modules or firmware fragments outside the intended scope
  were manually edited for logic changes

## Review Follow-Up

### Review assessment

- Warranted:
  - Copilot inline comments on `send_snapshot_series_chunk_()` and
    `send_history_buffer_chunk_()` identified a real dropped-line risk when the
    chunk buffer was nearly full and the next `snprintf()` result was not
    retried after flush.
  - Copilot inline comments on both handlers identified a valid cleanup gap:
    once chunked-response headers had been started, error returns did not
    explicitly attempt to terminate the chunked response.
  - The top-level `openai-code-agent` review comment repeated the same two
    underlying issues and also correctly called out the fragility of the
    original fixed free-space heuristic.
- Not actionable:
  - Gemini's summary review was accurate but did not request code changes.
  - The `chatgpt-codex-connector` comment was connector guidance, not a code
    review finding.

### What changed

- Added `flush_chunk_buffer_()` to centralize buffered chunk flushing.
- Added `append_csv_line_chunk_()` to format each CSV line into a dedicated
  per-line buffer, flush-before-copy when needed, and avoid silent point loss.
- Added `finalize_chunked_response_()` and used it on all started-response
  success/error exits in both history handlers.

### Why this fix was chosen

- It keeps the existing chunked-response design and CSV format intact.
- It removes the silent data-loss path without regressing heap usage back toward
  the old full-string behavior.
- It improves error-path behavior without changing endpoint contracts or
  aggregator proxy behavior.

## Post-Merge Operator Findings

### Prompt/device-test drift identified after WROOM validation

Operator-provided WROOM validation exposed three separate guidance problems that
were not firmware regressions in the chunked-history change itself:

- the active v7.7.1.1 Phase 7 prompt still referenced WROOM IP
  `192.168.120.190`, while the production WROOM is `192.168.120.170`
- the prompt used stale WROOM YAML name
  `firmware/esp32-wroom-32d-multi-sensor.yaml`, while the generated production
  file is `firmware/esp32-wroom-32d-gw.yaml`
- NI-002 treated missing `HEALTH:` output as a capture-window problem only,
  without first verifying that the flashed WROOM config still started the
  health-check task and still exposed serial/INFO logging

### WROOM operator evidence review

Observed from the operator run:

- `bash scripts/stress-test-httpd-stack.sh 192.168.120.170` passed on WROOM
- `curl http://192.168.120.170/history/office/temp` returned CSV data
- `curl http://192.168.120.170/api/v2/history/office/temp` returned CSV data
- `curl http://192.168.120.190/api/v2/history/office/temp` failed to connect,
  confirming the `.190` prompt address was stale
- both the USB serial capture and OTA/API log capture showed no `HEALTH:` line

### NI-002 conclusion

The provided WROOM logs do **not** satisfy NI-002. No `HEALTH:` line appears in
the supplied capture.

The most likely cause is not the capture duration and not the global logger
level:

- the generated WROOM YAML used in the operator run has `logger.level: INFO`
- the same generated WROOM YAML does **not** show a
  `start_health_check_task_()` call in `on_boot`
- the supplied logs also do not contain the startup log line from
  `start_health_check_task_()`

That combination makes the absence of `HEALTH:` output explainable without
claiming a runtime crash in the chunked-history code: the health-check task does
not appear to be started in the flashed WROOM config that was tested.

### Serial-output assessment

The supplied WROOM USB capture shows that serial output was active for this
operator run. This session therefore does **not** support the narrower claim
that WROOM serial output was disabled during the captured validation.

However, branch-tip repo state still justified adding a serial-config gate to
the prompt:

- `firmware/boards/esp32-wroom-32d.yaml` on branch tip still carried
  `logger.baud_rate: 0`, which can suppress UART serial logging
- serial-gated instructions should therefore explicitly verify the generated
  board config before using missing serial output as a product signal

### OTA log warnings during concurrent curl

The OTA/API log stream showed:

- `Chunked send failed at segment ...: ESP_ERR_HTTPD_RESP_SEND`
- `History stream final chunk failed: ESP_ERR_HTTPD_RESP_SEND`

These warnings are consistent with the operator's test method:

- the history requests were issued as `curl ... | head -20`
- `head -20` closes the client connection early once enough lines are read
- the server then sees an expected client-abort while still sending later
  chunks

This should not be interpreted as a BUG-082 regression by itself. It is an
expected artifact of truncated client reads during chunked transfer.

### Remediation applied to repo guidance

To prevent this drift from repeating in later runs, the following docs were
updated in this session:

- `AGENTS.md`
- `CURRENT-STATE.md`
- `prompts/phase7/v7.7.1.1-agent-prompt-gpt-codex.md`
- `prompts/phase7/v7.7.1.1-claude-two-step.md`
- `prompts/phase7/phase7-review-prompts-perplexity.md`
- `prompts/handoff/phase7/session-handoff-v7.7.1.1.md`

The remediation added these rules:

- use WROOM IP `192.168.120.170` for this production satellite
- use `firmware/esp32-wroom-32d-gw.yaml` for WROOM operator validation
- before relying on NI-001/NI-002 serial gates, verify:
  - production IP / YAML target
  - `logger.level: INFO`
  - serial output not disabled for the flashed board/profile
  - `start_health_check_task_()` present in generated WROOM `on_boot`
- treat `ESP_ERR_HTTPD_RESP_SEND` during `curl ... | head -20` as an expected
  client-abort artifact unless accompanied by a reset/crash
