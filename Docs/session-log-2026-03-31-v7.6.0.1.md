# Session Log — v7.6.0.1: POST /api/aggregator/add-satellite

**Date:** 2026-03-31
**Branch:** `copilot/v7-6-0-1-add-satellite-api`
**Prerequisite:** v7.6.0.0-fixup-1 merged (NVS satellite persistence layer + httpd stack fix)

---

## Summary

Implemented `POST /api/aggregator/add-satellite` (Phase D Step 1) per the implementation
prompt `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md`.

---

## Changes Made

### `dashboard/sensor_history_multi.h`

1. **Added `probe_satellite_manifest_()` static helper** (after `fetch_to_buffer()`, before
   NVS persistence functions):
   - Fetches `{base_url}/api/manifest` via `fetch_to_buffer()`
   - Uses `s_proxy_tmp` (32 KB, web handler context only — never `s_fetch_tmp`)
   - Extracts `gateway.id` and `gateway.name` via `strstr`-based parsing
   - Returns `false` if unreachable, non-200, or no `"gateway"` block with an `"id"` field
   - Designed for reuse by v7.6.0.3 (`test-satellite`)

2. **Added `handle_add_satellite_()` class method** (before the 501 stub):
   - Validates HTTP method (405 if not POST)
   - Parses `url` (required), `name` (optional), `poll` (optional, default 30, clamped
     10–3600) from query string
   - Validates URL starts with `http://` (400 otherwise)
   - Checks `runtime_satellite_count < MAX_SATELLITES` (409 if full)
   - Checks for duplicate URL in `satellite_caches[0..runtime_satellite_count-1]` (409)
   - Calls `probe_satellite_manifest_()` — 400 on failure
   - Resolves final name: request param > manifest `gateway.name` > `"Satellite N"`
   - Under `AGG_LOCK()`: calls `set_identity()` + `clear_cache()` + increments
     `runtime_satellite_count`
   - Outside mutex: calls `save_single_satellite_to_nvs_(new_idx)` (single-entry NVS write,
     safe on 16 KB httpd stack per local component override)
   - Returns `200 {"ok":true,"satellite":{"id":"...","name":"...","url":"...","poll":N}}`
   - Returns `503 "Mutex timeout"` on `AGG_LOCK()` failure

3. **Updated routing in `handleRequest()`**:
   - Changed `handle_aggregator_stub_501_(request)` → `handle_add_satellite_(request)` for
     the `/api/aggregator/add-satellite` route

### `Docs/changelog.md`
- Added v7.6.0.1 entry.

### Version bump
- Ran `bash scripts/bump-version.sh 7.6.0.1` — updated VERSION, dashboard.js,
  dashboard.html, sensor_history_multi.h header comment, firmware YAML,
  gateway_manifest.h, all fixture files.

---

## Instruction Compliance Output

| # | Instruction | Status | Notes |
|---|-------------|--------|-------|
| 1 | `probe_satellite_manifest_()` helper factored out | ✅ | After `fetch_to_buffer()`, before NVS functions |
| 2 | `handle_add_satellite_()` implemented with full data flow | ✅ | All validation/probe/mutex/NVS steps |
| 3 | Routing updated from stub to real handler | ✅ | `handleRequest()` updated |
| 4 | Uses `s_proxy_tmp` not `s_fetch_tmp` | ✅ | Probe uses `s_proxy_tmp` |
| 5 | Uses `save_single_satellite_to_nvs_()` not bulk | ✅ | Single-entry write only |
| 6 | Mutex held only during cache mutation, not I/O | ✅ | Probe precedes `AGG_LOCK()` |
| 7 | Query string params, not JSON body | ✅ | `request->getParam()` only |
| 8 | No auth on add-satellite | ✅ | Per prompt contract (no auth) |
| 9 | No dashboard changes | ✅ | |
| 10 | No test changes | ✅ | |
| 11 | Version bumped to 7.6.0.1 | ✅ | `bump-version.sh 7.6.0.1` |
| 12 | `render_sensor_config.py --write` | ✅ | No changes needed |
| 13 | `generate-fixtures.js` | ✅ | All fixture variants regenerated |
| 14 | `generate-header.sh` | ✅ | `dashboard.h` regenerated |
| 15 | `render_sensor_config.py --check` | ✅ | PASS |
| 16 | `preflight.sh` | ✅ | All checks PASS |
| 17 | `FIXTURE_SET=3sensor chromium` | ✅ | 99 passed, 26 skipped |
| 18 | `FIXTURE_SET=3sensor firefox` | ✅ | 99 passed, 26 skipped |
| 19 | `FIXTURE_SET=mixed --grep Mixed` | ✅ | 7 passed |
| 20 | `FIXTURE_SET=system --grep System` | ✅ | 8 passed |
| 21 | `FIXTURE_SET=aggregator --grep Aggregator` | ✅ | 11 passed, 1 skipped |
| 22 | `Docs/changelog.md` entry added | ✅ | v7.6.0.1 section |
| 23 | Session log created | ✅ | This file |

---

## API Contract (documented for v7.6.0.5 mock)

| Condition | HTTP Status | Response body |
|-----------|-------------|---------------|
| Valid URL, probe succeeds | 200 | `{"ok":true,"satellite":{"id":"...","name":"...","url":"...","poll":30}}` |
| Missing `url` parameter | 400 | `{"ok":false,"message":"Missing url parameter","status":400}` |
| URL doesn't start with `http://` | 400 | `{"ok":false,"message":"URL must start with http://","status":400}` |
| Satellite list full (`count >= MAX_SATELLITES`) | 409 | `{"ok":false,"message":"Satellite list full","status":409}` |
| Duplicate URL | 409 | `{"ok":false,"message":"URL already configured","status":409}` |
| Probe failed (unreachable or bad manifest) | 400 | `{"ok":false,"message":"Satellite unreachable or invalid manifest","status":400}` |
| Wrong HTTP method | 405 | `{"ok":false,"message":"Method not allowed","status":405}` |
| Mutex timeout | 503 | `{"ok":false,"message":"Mutex timeout","status":503}` |

---

## Runtime Mutation Safety Checklist

- [x] All satellite iteration loops use `runtime_satellite_count`, not `MAX_SATELLITES`
- [x] All cache mutations happen under `s_cache_mutex` (`AGG_LOCK`/`AGG_UNLOCK`)
- [x] No code caches a satellite array index across function calls
- [x] NVS write is outside mutex (NVS operations can be slow)
- [x] `save_single_satellite_to_nvs_()` used (not bulk erase variant)
- [x] Probe uses `s_proxy_tmp` (not `s_fetch_tmp`)

---

## Device Testing (for human post-merge)

See problem statement §11 for full device test sequence (7 tests).
