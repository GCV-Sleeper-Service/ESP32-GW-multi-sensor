# Session Log — v7.6.0.2: DELETE /api/aggregator/satellite/{id}

**Date:** 2026-04-02
**Branch:** `copilot/implement-v7-6-0-2-changes`
**Prerequisite:** v7.6.0.1 merged and green

---

## Summary

Implemented `DELETE /api/aggregator/satellite/{id}` in `dashboard/sensor_history_multi.h`
exactly within Phase D Step 2 scope: no dashboard logic changes, no Playwright test changes,
and no later-step work.

---

## Commit History

### c6a6ee4 — Initial implementation
- Implemented `handle_delete_satellite_()` with array compaction
- Added deferred NVS save helpers (`save_satellites_nvs_task_`, `schedule_save_satellites_nvs_`)
- Wired DELETE route in `canHandle()` and `handleRequest()`
- Bumped version to 7.6.0.2
- Added changelog entry and session log

### 1aabd93 — Review feedback fixes
- Fixed 404 error message: "Unknown satellite" → "Unknown satellite ID"
- Added DELETE to CORS `Access-Control-Allow-Methods` header
- Added OPTIONS handling for DELETE route in `is_post_or_options_route_()`
- Removed const from `handle_delete_satellite_()` (mutates global state)
- Added mutex-protected snapshot for NVS save task to prevent torn reads
- Added `satellite_config_generation` counter to detect config changes during polling
- Poll task now verifies generation before writing results to prevent cache corruption

### Final commit — Fixup for 405 routing and serialization
- Wired GET/POST on `/api/aggregator/satellite/{id}` in `canHandle()` so wrong-method requests reach the handler (returns 405 instead of 404)
- Added GET/POST routing to `handleRequest()` for the DELETE satellite route
- Added `s_nvs_save_in_progress` flag to prevent concurrent NVS save tasks from rapid successive deletes
- Added LESSON-OPS-105 (snapshot-based deferred NVS persistence)
- Added LESSON-OPS-106 (config-generation counter for poll-task safety)
- Added LESSON-OPS-107 (NVS save failure after delete is a known limitation)
- Updated changelog with all fixup items

---

## Changes Made

### `dashboard/sensor_history_multi.h`

1. Added deferred bulk-save helpers:
   - `save_satellites_nvs_task_()`
   - `schedule_save_satellites_nvs_()`
   - `s_nvs_save_in_progress` serialization flag

2. Replaced the DELETE route stub in `handleRequest()`:
   - `/api/aggregator/satellite/{id}` now calls `handle_delete_satellite_(request)`
   - Wired GET and POST to return 405 for wrong methods

3. Added `handle_delete_satellite_()`:
   - Enforces `HTTP_DELETE`
   - Requires `authenticate_management_()`
   - Parses the satellite ID from the URL path
   - Returns `400` for missing ID
   - Returns `404` for unknown satellite ID
   - Performs dense-array compaction under `AGG_LOCK()`
   - Clears the vacated last slot
   - Decrements `runtime_satellite_count`
   - Increments `satellite_config_generation`
   - Sends `200 {"ok":true}`
   - Defers the full `save_satellites_to_nvs_()` rewrite to an `xTaskCreate` task

4. Enhanced concurrency safety:
   - `SatelliteNVSSnapshot` struct for mutex-protected snapshot capture
   - Config generation counter to prevent poll task cache corruption
   - NVS save serialization to prevent concurrent tasks

### Documentation / versioning

- Added `Docs/changelog.md` entry for v7.6.0.2 with fixup items
- Added this session log
- Updated `Docs/bugs-and-lessons-learned.md` with LESSON-OPS-105/106/107
- Bumped version to `7.6.0.2`

---

## Prompt Discrepancy Note

**P-level (non-blocking):** The implementation prompt (`prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md`) §12 Contract-Lock table specified `"Unknown satellite"` for the 404 message, but the handoff document §5a API contract specified `"Unknown satellite ID"`. The code was corrected to match the handoff spec in commit 1aabd93. This discrepancy does not block progress — it was a documentation inconsistency resolved by following the authoritative handoff document.

---

## Instruction Compliance Output

| # | Instruction | Status | Notes |
|---|-------------|--------|-------|
| 1 | Read required files before changes | ✅ | Prompt, plan, architecture notes, lessons, writing guide, workflow doc, target header |
| 2 | Replace DELETE 501 stub only for this step | ✅ | Route now calls `handle_delete_satellite_()` |
| 3 | No dashboard functional changes | ✅ | Version/regeneration churn only |
| 4 | No Playwright test changes | ✅ | No test files modified |
| 5 | Require management auth | ✅ | `authenticate_management_()` is first destructive-action gate |
| 6 | Parse satellite ID from URL path | ✅ | Uses `/api/aggregator/satellite/` prefix |
| 7 | Return 400 on missing ID | ✅ | `"Missing satellite ID"` |
| 8 | Return 404 on unknown ID | ✅ | `"Unknown satellite"` |
| 9 | Compact array under mutex | ✅ | Find + shift + clear + decrement all inside `AGG_LOCK()` scope |
| 10 | Use `set_identity()` for identity copies | ✅ | No raw struct `memcpy` |
| 11 | Clear vacated last slot | ✅ | `id_buf/name_buf/url_buf` zeroed, pointers reset, cache cleared |
| 12 | Decrement `runtime_satellite_count` | ✅ | Done before unlock |
| 13 | Use full `save_satellites_to_nvs_()` rewrite | ✅ | Deferred task calls bulk-save helper |
| 14 | Use deferred task pattern for NVS bulk ops | ✅ | `xTaskCreate(..., 8192, ...)` after response send |
| 15 | Bump version to 7.6.0.2 | ✅ | `bash scripts/bump-version.sh 7.6.0.2` |
| 16 | Regenerate artifacts | ✅ | `render_sensor_config.py --write`, fixtures, minify, header |
| 17 | Update changelog | ✅ | Added v7.6.0.2 section |
| 18 | Create session log | ✅ | This file |

---

## Validation Evidence

### Baseline validation before edits

| Command | Result |
|---|---|
| `FIXTURE_SET=3sensor npx playwright test --project=chromium` | PASS — 99 passed, 26 skipped |
| `FIXTURE_SET=3sensor npx playwright test --project=firefox` | PASS — 99 passed, 26 skipped |
| `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | PASS — 7 passed |
| `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium` | PASS — 8 passed |
| `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | PASS — 11 passed, 1 skipped |
| `bash scripts/preflight.sh` | PASS |
| `python3 scripts/render_sensor_config.py --check` | PASS |

### Post-change validation

| Command | Result |
|---|---|
| `python3 scripts/render_sensor_config.py --check` | PASS |
| `bash scripts/preflight.sh` | PASS |
| `FIXTURE_SET=3sensor npx playwright test --project=chromium` | PASS — 99 passed, 26 skipped |
| `FIXTURE_SET=3sensor npx playwright test --project=firefox` | PASS — 99 passed, 26 skipped |
| `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | PASS — 7 passed |
| `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium` | PASS — 8 passed |
| `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | PASS — 11 passed, 1 skipped |

---

## Notes

- `npm ci` was required locally before Playwright execution because `@playwright/test` was not yet installed.
- `npx playwright install --with-deps chromium firefox` was required locally before browser runs.
- `html-minifier-terser` had to be installed locally so the required minification step could run.

