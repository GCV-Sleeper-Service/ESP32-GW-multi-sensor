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

## Additional Codex Review And Device Follow-Up

### Additional Codex review assessment

The later `chatgpt-codex-connector` review on PR #226 was warranted.

Review claim:

- switching `/api/v2/history` to chunked transfer breaks aggregator proxy
  because `handle_aggregator_proxy_()` reads upstream responses through
  `fetch_to_buffer()`, which previously copied raw body bytes and did not
  decode HTTP chunk framing

Why this was correct:

- `handle_aggregator_proxy_()` serves proxied history from
  `firmware/core/aggregator-runtime.h`
- `fetch_to_buffer()` issued raw socket HTTP requests and returned the body as
  received
- once satellites started returning `Transfer-Encoding: chunked` for
  `/api/v2/history`, aggregator mode could ingest chunk-size framing instead of
  plain `epoch,value` CSV lines

### Additional code changes

Applied follow-up fixes:

- `firmware/core/aggregator-runtime.h`
  - added `recv_exact_()`
  - added `recv_crlf_line_()`
  - added `read_chunked_body_()`
  - updated `fetch_to_buffer()` to detect
    `Transfer-Encoding: chunked` and dechunk upstream history responses before
    handing them to proxy consumers
- `firmware/core/web-handler.h`
  - `finalize_chunked_response_()` now accepts the prior send error
  - suppresses the second warning when both the body send and the terminating
    zero-length chunk fail with `ESP_ERR_HTTPD_RESP_SEND` after client abort
- `scripts/render_sensor_config.py`
  - now emits a generated `on_boot` step that starts
    `start_health_check_task_()` for production board YAML output
- `firmware/boards/esp32-wroom-32d.yaml`
  - removed `logger.baud_rate: 0` so serial-gated validation is not suppressed
    at the board-profile source

### HEALTH log requirement conclusion

Yes. NI-002 requires a `HEALTH:` line to appear in logs, so the earlier WROOM
operator evidence did **not** satisfy the step.

What was needed to make `HEALTH:` appear reliably:

- the generated board YAML must start `start_health_check_task_()` in `on_boot`
- the flashed board/profile must not suppress UART serial output when serial
  capture is part of the gate
- logs must be captured long enough to pass the 60-second health interval

This session validated that after the generated `on_boot` health hook was added
and WROOM serial suppression was removed at the board-profile source, `HEALTH:`
appears on both production targets.

### WROOM evidence after fix

Provision/flash path:

- `bash scripts/provision.sh wroom`
- `esphome clean firmware/esp32-wroom-32d-gw.yaml`
- `esphome compile firmware/esp32-wroom-32d-gw.yaml`
- `esphome upload firmware/esp32-wroom-32d-gw.yaml --device=/dev/ttyUSB0`

Generated-config confirmation:

- `firmware/esp32-wroom-32d-gw.yaml` contains `start_health_check_task_();`
- generated WROOM YAML no longer suppresses UART with `baud_rate: 0`

Observed WROOM log evidence:

- `Health-check task started (interval=60s, stack=4096B)`
- `HEALTH: heap_free=31396 heap_free_total=31396 min_free=51776 min_free_total=27908 uptime=0h00m`
- `HEALTH: httpd_stack_wm=15444 hc_stack_wm=3596`
- `HEALTH: nvs_used=10394 nvs_free=5734 nvs_total=16128 nvs_ns_count=1`

Observed WROOM endpoint evidence:

- `curl -s http://192.168.120.170/history/office/temp | head -20` -> CSV data
- `curl -s http://192.168.120.170/api/v2/history/office/temp | head -20` -> CSV data
- `curl -si -u ESPadmin:ESPpass100 http://192.168.120.170/api/status/full`
  -> `HTTP/1.1 200 OK`, `version":"v7.7.1.1"`,
  `httpd_stack_watermark_bytes":12260`

### C3 evidence after flash

To keep the repo CI-safe after WROOM validation, WROOM was provisioned/flashed
first and the repo was then returned to satellite mode before C3 flash.

C3 flash path:

- `bash scripts/provision.sh satellite`
- `esphome clean firmware/esp32-c3-multi-sensor.yaml`
- `esphome compile firmware/esp32-c3-multi-sensor.yaml`
- `esphome upload firmware/esp32-c3-multi-sensor.yaml --device=/dev/ttyACM0`

Observed C3 log evidence:

- `Health-check task started (interval=60s, stack=4096B)`
- `HEALTH: heap_free=52080 heap_free_total=59836 min_free=48096 min_free_total=48096 uptime=0h02m`
- `HEALTH: httpd_stack_wm=11976 hc_stack_wm=2308`
- `HEALTH: nvs_used=5344 nvs_free=10784 nvs_total=16128 nvs_ns_count=1`

Observed C3 endpoint evidence:

- `curl -s http://192.168.120.189/history/office/temp | head -20` -> CSV data
- `curl -s http://192.168.120.189/api/v2/history/office/temp | head -20` -> CSV data
- `curl -si -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full`
  -> `HTTP/1.1 200 OK`, `version":"v7.7.1.1"`,
  `httpd_stack_watermark_bytes":11976`

### `ESP_ERR_HTTPD_RESP_SEND` warning assessment

These warnings are real but, in the supplied operator scenario, they are
expected.

Why they appear:

- the history endpoints were queried as `curl ... | head -20`
- `head -20` terminates the client side after receiving enough lines
- the server is still streaming later CSV chunks and receives a disconnected
  peer
- `httpd_resp_send_chunk()` therefore returns `ESP_ERR_HTTPD_RESP_SEND`

What was incorrect before this follow-up:

- after the first send failure, the server also logged a second
  `History stream final chunk failed: ESP_ERR_HTTPD_RESP_SEND`
- that second line was redundant noise for the same client-abort event

What was changed:

- the initial send-failure warning is retained because it reflects a real
  socket-send failure
- the duplicate final-chunk warning is now suppressed when it is just the same
  `ESP_ERR_HTTPD_RESP_SEND` caused by the same disconnected client

Post-fix confirmation:

- WROOM and C3 logs still show the primary
  `Chunked send failed at segment ...: ESP_ERR_HTTPD_RESP_SEND` warning during
  `curl ... | head -20`
- the extra `History stream final chunk failed: ESP_ERR_HTTPD_RESP_SEND` line
  no longer appears in the reproduced device logs

### Aggregator live verification note

Direct live aggregator verification from this container remained blocked during
this follow-up:

- `curl http://192.168.120.191/...` returned `No route to host`

So the aggregator compatibility fix was validated by code-path inspection and
local repo tests, but not by a successful live `.191` proxy request from this
environment.

### Baseline comparison required by the Phase 7 prompt

The prompt explicitly required recording the C3 `HEALTH:` values against the
v7.7.1.0 baseline after confirming the fix.

Observed C3 `HEALTH:` values for v7.7.1.1:

- `heap_free=52080`
- `min_free=48096`
- `httpd_stack_wm=11976`
- `hc_stack_wm=2308`

Comparison table:

| Metric | v7.7.1.0 baseline (C3) | v7.7.1.1 observed (C3) | Delta |
|---|---|---|---|
| `heap_free` | 39,704 B | 52,080 B | +12,376 B |
| `min_free` | 29,776 B | 48,096 B | +18,320 B |
| `httpd_stack_wm` | 12,932 B | 11,976 B | -956 B |
| `hc_stack_wm` | 2,176 B | 2,308 B | +132 B |

Interpretation:

- heap headroom improved materially relative to the v7.7.1.0 baseline
- the httpd task still retains >11 KB watermark on C3 after the chunked
  history rewrite
- the health-check task watermark is effectively unchanged in practical terms

### Late review sweep after device validation

Reviewed:

- Gemini review `#pullrequestreview-4253471511`
- issue comment `#issuecomment-4407769375`
- issue comment `#issuecomment-4407788908`

Assessment:

- Warranted:
  - Gemini's snapshot-allocation logging comment was valid. The chunked
    history path could skip persisted history under allocation failure without
    leaving an explicit log record.
- Not warranted:
  - Gemini's `NaN` wire-format comment was incorrect for this repo. The
    pre-chunking implementation in `append_snapshot_series_csv_()` already
    emitted `epoch,` for `NaN`, so the current chunked code did not introduce a
    wire-format regression.
  - Gemini's case-insensitive `Transfer-Encoding` search suggestion was a
    robustness improvement, not a demonstrated branch-tip defect, because the
    only upstream producer in this path is the project's own firmware with a
    stable header format.
- Not actionable:
  - issue comments `4407769375` and `4407788908` were review summaries
    concluding the PR was ready; they did not request additional changes.

Additional fix applied from that sweep:

- `firmware/core/web-handler.h`
  - now logs `History stream: failed to allocate snapshot buffer` when the
    persisted-history chunked stream cannot allocate the snapshot buffer

### Final review sweep after `.191` became reachable

Reviewed issue comment:

- `#issuecomment-4411237439`

Assessment:

- Warranted:
  - case-sensitive/exact `Transfer-Encoding: chunked` detection in
    `fetch_to_buffer()` was a real robustness gap in the autonomous
    aggregator-compatibility fix, even though it was not failing against the
    in-repo upstream producer at the time of review
  - returning success immediately when the fixed caller buffer filled mid-chunk
    without draining the remainder of the chunked response was also a valid
    behavior note; it worked with the current close-on-return model, but it was
    brittle and left avoidable partial-read semantics on the upstream socket
- Acceptable / documented:
  - the 96-byte CSV line buffer limit is acceptable for the environmental and
    ping-domain metrics in this repo; a clarifying comment was added
- Already addressed by prior docs:
  - the prompt-scope expansion concerns were already documented in this session
    log and prior PR follow-up comments

Additional fixes applied from this final sweep:

- `firmware/core/aggregator-runtime.h`
  - added case-insensitive token-based `Transfer-Encoding` parsing
  - changed chunked-body truncation handling to drain the remainder of the
    current chunk and the rest of the chunked body before returning success
- `firmware/core/web-handler.h`
  - added an explicit comment documenting that the 96-byte CSV line buffer is
    deliberate headroom for short `epoch,%.2f\n` / `epoch,\n` rows

### Live aggregator verification completed

Once `.191` became reachable again, live aggregator verification was rerun
after flashing the aggregator to branch-tip `v7.7.1.1`.

Provision / flash path:

- `bash scripts/provision.sh aggregator`
- `esphome clean firmware/esp32-s3-devkitc1-n16r8-gw.yaml`
- `esphome compile firmware/esp32-s3-devkitc1-n16r8-gw.yaml`
- `esphome upload firmware/esp32-s3-devkitc1-n16r8-gw.yaml --device=192.168.120.191`

Observed aggregator evidence after flash:

- `curl -si -u ESPadmin:ESPpass100 http://192.168.120.191/api/status/full`
  returned `HTTP/1.1 200 OK` with `version":"v7.7.1.1"`
- `curl -s -u ESPadmin:ESPpass100 http://192.168.120.191/api/aggregator/gateways`
  showed gateway `gw-main` reachable with upstream firmware `v7.7.1.1`
- `curl -si -u ESPadmin:ESPpass100 http://192.168.120.191/api/aggregator/proxy/gw-main/history/office/temp`
  returned `HTTP/1.1 200 OK`, `Content-Type: text/plain`, `Content-Length: 1632`
- `curl -s -u ESPadmin:ESPpass100 http://192.168.120.191/api/aggregator/proxy/gw-main/history/office/temp | head -20`
  returned plain CSV rows from the chunked C3 upstream history endpoint

Conclusion:

- the aggregator compatibility follow-up is now validated both by code-path
  inspection and by a successful live `.191` proxy request against the chunked
  `v7.7.1.1` C3 upstream
