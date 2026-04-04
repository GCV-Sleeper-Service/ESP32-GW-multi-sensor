# Phase D — Runtime Satellite Management

**Status: COMPLETE** (v7.6.0.5, 2026-04-04). All 6 steps shipped. See changelog for details.

_Implementation Plan for v7.6.0.x_
_Date: 2026-03-25_
_Prerequisite: Phase 6 Complete (v7.5.6.4 on `main`)_
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Goal

Replace the compile-time satellite list with a runtime-configurable system. When Phase D is complete:

1. Satellites are persisted in NVS on the aggregator — surviving reboots without reflashing
2. The dashboard Settings panel has add/remove/test controls
3. Auto-discovery via `/api/manifest` probes candidate URLs before committing
4. The compile-time satellite list from `aggregator_config.h` serves as the bootstrap default — overridden once the NVS list is populated
5. All existing dashboard, polling, and proxy functionality works identically
6. The 501 stub endpoints are replaced with working implementations

**Key principle:** This phase turns the aggregator from a developer-configured tool into an operator-configured product. After Phase D, adding a satellite to the aggregator requires only a browser — no YAML editing, no regeneration, no reflashing.

---

## Architecture Reference

- `Docs/v7.5-v7.6-architecture-plan.md` — Section 11 Phase D references
- `Docs/architecture-revision-and-action-plan.md` — Section 6 Phase D scope
- `Docs/aggregator-satellite-gateway-principles.txt` — user design principles
- `dashboard/sensor_history_multi.h` — current `SatelliteCache`, `SATELLITE_IDS[]`, polling task, stub endpoints

---

## Current State (What Exists)

### Compile-time satellite configuration

`aggregator_config.h` (generated from `config/aggregator.json`) defines:
```cpp
#define MAX_SATELLITES 2
static const char* SATELLITE_IDS[] = {"sat-s3-4m-189", "sat-esp32-4m-190"};
static const char* SATELLITE_NAMES[] = {"First satellite...", "Second satellite..."};
static const char* SATELLITE_URLS[] = {"http://192.168.120.189", "http://192.168.120.190"};
static const int SATELLITE_POLL_INTERVALS[] = {30, 30};
```

### SatelliteCache struct (runtime state)

Each satellite has a `SatelliteCache` with:
- `id`, `name`, `base_url`, `poll_interval_seconds` (initialized from compile-time arrays)
- `manifest_json[4096]`, `live_json[2048]`, `status_json[512]` (cached responses)
- `reachable`, `consecutive_failures`, `last_seen_epoch` (health state)

### Stub endpoints (return 501 today)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `POST /api/aggregator/add-satellite` | POST | Add a satellite to the list |
| `DELETE /api/aggregator/satellite/{id}` | DELETE | Remove a satellite |
| `POST /api/aggregator/test-satellite` | POST | Probe a URL for manifest |

### Dashboard Settings panel

Read-only display showing configured satellites with status dots, URLs, firmware versions, device counts. Has placeholder text: "runtime management coming in a future update."

---

## Constraints

1. **NVS key length limit:** 15 characters max. Satellite IDs can be longer — use a hash or index scheme.
2. **Static buffer sizes:** `SatelliteCache` uses fixed arrays. `MAX_SATELLITES` is compile-time. Phase D can raise the cap (e.g., 8) but cannot make it dynamic without redesigning the struct.
3. **Thread safety:** The polling task runs on a separate RTOS thread. All cache mutations must hold `s_cache_mutex`.
4. **PSRAM required for aggregator role:** Devices without PSRAM are satellite-only (enforced at build time by `render_sensor_config.py` since v7.5.7.0). The aggregator code (`SatelliteCache` array, polling task, management endpoints) is compiled only when `AGGREGATOR_ENABLED 1`, which requires PSRAM. Phase D code runs exclusively on PSRAM-equipped boards. NVS satellite config uses the default NVS partition, not heap-allocated structures.
5. **Backward compatibility:** Aggregators flashed with Phase 5 firmware must boot correctly after Phase D flash. If the NVS satellite namespace is empty, fall back to the compile-time list.

---

## NVS Storage Design

### Namespace

Use a dedicated NVS namespace `"agg_sats"` (10 chars, under 15-char limit) in the default NVS partition (not the history partition).

### Key scheme

| Key | Type | Content |
|-----|------|---------|
| `count` | `u8` | Number of satellites (0–MAX_SATELLITES) |
| `s0_id` | `str` | Satellite 0 ID (max 31 chars) |
| `s0_name` | `str` | Satellite 0 friendly name (max 63 chars) |
| `s0_url` | `str` | Satellite 0 base URL (max 127 chars) |
| `s0_poll` | `u16` | Satellite 0 poll interval in seconds |
| `s1_id` | `str` | Satellite 1 ID |
| ... | ... | Pattern repeats for each satellite index |

Keys use index-based naming (`s0_`, `s1_`, ...) to stay under the 15-character NVS key limit while allowing up to 10 satellites (`s9_*`).

### Boot sequence

```
1. Read NVS "agg_sats" namespace
2. If "count" key exists and value > 0:
     → Load satellites from NVS keys (s0_id, s0_name, s0_url, s0_poll, ...)
     → Populate satellite_caches[] from NVS data
     → Set runtime_satellite_count = NVS count
3. Else (first boot or NVS empty):
     → Populate satellite_caches[] from compile-time arrays (SATELLITE_IDS[], etc.)
     → Set runtime_satellite_count = MAX_SATELLITES (compile-time default)
     → Optionally: write compile-time list to NVS (so future edits persist)
4. Start polling task with runtime_satellite_count
```

---

## Phased Steps

### v7.6.0.0 — NVS Satellite Persistence Layer

**Scope:** Add NVS read/write functions for the satellite list. Boot loads from NVS with compile-time fallback. No API changes yet — the satellite list is loaded from NVS but still configured at compile time for initial population.

**Files modified:**
- `dashboard/sensor_history_multi.h` — add `load_satellites_from_nvs_()`, `save_satellites_to_nvs_()`, `save_single_satellite_to_nvs_()`, modify `init_aggregator_satellites()` to try NVS first
- `scripts/preflight.sh` — add NVS satellite check if applicable
- `Docs/changelog.md` — v7.6.0.0 entry
- Version bump: ALL locations to `7.6.0.0`

**Implementation details:**

The current `init_aggregator_satellites()` (line ~1510) copies compile-time arrays into `satellite_caches[]`. Modify to:
1. Call `load_satellites_from_nvs_()` first
2. If NVS has entries, use them (set `runtime_satellite_count`)
3. If NVS is empty, fall back to compile-time arrays and optionally seed NVS
4. Introduce `static int runtime_satellite_count` to replace hardcoded `MAX_SATELLITES` in loop bounds

The polling task loop (`for (int i = 0; i < MAX_SATELLITES; i++)`) becomes `for (int i = 0; i < runtime_satellite_count; i++)`. Similarly for all aggregator endpoint handlers.

**Key design decision:** `MAX_SATELLITES` remains a compile-time upper bound for static array sizing (e.g., `SatelliteCache satellite_caches[MAX_SATELLITES]`). Raise from 2 to 8 to allow growth. `runtime_satellite_count` tracks the actual count at runtime.

**Acceptance criteria:**
- [ ] Aggregator boots with NVS satellite list when present
- [ ] Aggregator falls back to compile-time list when NVS is empty
- [ ] `runtime_satellite_count` used instead of `MAX_SATELLITES` in all loop bounds
- [ ] `save_satellites_to_nvs_()` can write the current satellite list
- [ ] NVS read/write errors logged but do not crash
- [ ] All existing Playwright tests pass
- [ ] Device testing: boot, verify satellites load, reboot, verify satellites survive

**Risk:** Low-Medium. NVS APIs are well-understood from history persistence.
**Estimated effort:** 1–2 sessions.

---

### v7.6.0.1 — POST /api/aggregator/add-satellite

**Scope:** Replace the 501 stub with a working implementation that validates, probes, and persists a new satellite.

**Files modified:**
- `dashboard/sensor_history_multi.h` — implement `handle_add_satellite_()`
- `Docs/changelog.md`
- Version bump

**API contract:**

```
POST /api/aggregator/add-satellite
Content-Type: application/json

{
  "url": "http://192.168.120.191",
  "name": "Kitchen Satellite",        // optional — auto-derived from manifest if absent
  "poll_interval": 30                  // optional — default 30
}
```

**Processing steps:**
1. Parse JSON body (use `ArduinoJson` or manual parsing — check what's available in ESPHome IDF)
2. Validate URL format (must start with `http://`)
3. Check `runtime_satellite_count < MAX_SATELLITES` (reject with 409 if full)
4. Check for duplicate URL (reject with 409 if already configured)
5. **Probe the candidate:** `fetch_to_buffer(url + "/api/manifest", ...)` 
6. Parse probe response — extract `gateway.id` and `gateway.name` from manifest
7. If probe fails → return `400 {"ok":false,"message":"Satellite unreachable or invalid manifest"}`
8. If name not provided in request, use `gateway.name` from manifest
9. Derive satellite ID from manifest's `gateway.id` or generate from URL
10. Add to `satellite_caches[runtime_satellite_count]` under mutex
11. Increment `runtime_satellite_count`
12. Call `save_satellites_to_nvs_()`
13. Return `200 {"ok":true,"satellite":{"id":"...","name":"...","url":"..."}}`

**Error responses:**
- `400` — invalid JSON, missing URL, probe failed
- `409` — satellite list full, or URL already configured
- `405` — wrong method

**⚠️ Body parsing on ESP32:** `AsyncWebServerRequest` does not natively parse JSON POST bodies in the ESPHome IDF environment. The `handleBody()` callback is Arduino-only. Options:
- Use query string parameters instead of JSON body: `POST /api/aggregator/add-satellite?url=...&name=...&poll=30`
- Or use `request->hasParam("url", true)` which reads POST form data

**Recommendation:** Use query string parameters for simplicity and consistency with `/api/ingest`. Document the query-string contract.

**Acceptance criteria:**
- [ ] Valid satellite URL is probed, added, and persisted to NVS
- [ ] Duplicate URL rejected with 409
- [ ] Full list rejected with 409
- [ ] Unreachable URL rejected with 400
- [ ] New satellite appears in polling cycle immediately
- [ ] New satellite appears in Settings panel on next poll
- [ ] Reboot preserves the new satellite

**Risk:** Medium. Body parsing and manifest probing add complexity.
**Estimated effort:** 1–2 sessions.

---

### v7.6.0.2 — DELETE /api/aggregator/satellite/{id}

**Scope:** Replace the 501 stub. Remove a satellite by ID, persist the change.

**Files modified:**
- `dashboard/sensor_history_multi.h` — implement `handle_delete_satellite_()`
- `Docs/changelog.md`
- Version bump

**API contract:**

```
DELETE /api/aggregator/satellite/{id}
```

**Processing steps:**
1. Parse satellite ID from URL path (after `/api/aggregator/satellite/`)
2. Find matching satellite in `satellite_caches[]`
3. If not found → `404 {"ok":false,"message":"Unknown satellite"}`
4. Under mutex: shift remaining satellites down to fill the gap
5. Decrement `runtime_satellite_count`
6. Clear the vacated `SatelliteCache` slot
7. Call `save_satellites_to_nvs_()`
8. Return `200 {"ok":true}`

**Compaction:** When satellite at index 2 of 5 is removed, satellites 3 and 4 shift to indices 2 and 3. The NVS is rewritten with the new list. This keeps the array dense — no "holes" in `satellite_caches[]`.

**Acceptance criteria:**
- [ ] Valid satellite ID removed and NVS updated
- [ ] Unknown ID returns 404
- [ ] Polling task stops polling the removed satellite
- [ ] Settings panel reflects removal on next poll
- [ ] Reboot confirms satellite is gone

**Risk:** Low. Array compaction is straightforward.
**Estimated effort:** 1 session.

---

### v7.6.0.3 — POST /api/aggregator/test-satellite

**Scope:** Replace the 501 stub. Probe a URL without adding it — for the dashboard "Test" button.

**Files modified:**
- `dashboard/sensor_history_multi.h` — implement `handle_test_satellite_()`
- `Docs/changelog.md`
- Version bump

**API contract:**

```
POST /api/aggregator/test-satellite?url=http://192.168.120.191
```

**Response:**
- `200 {"ok":true,"gateway":{"id":"...","name":"...","hardware":"...","sensor_count":N}}` — probe succeeded
- `400 {"ok":false,"message":"Unreachable or invalid manifest"}` — probe failed
- `400 {"ok":false,"message":"Missing url parameter"}` — no URL

**Implementation:** Reuse the same probe logic from v7.6.0.1 but without adding to the list.

**Acceptance criteria:**
- [ ] Valid satellite URL returns manifest summary
- [ ] Unreachable URL returns 400
- [ ] No side effects (satellite NOT added)

**Risk:** Low. Reuses existing probe code.
**Estimated effort:** 0.5 sessions.

---

### v7.6.0.4 — Dashboard Add/Remove/Test UI

**Scope:** Replace the read-only Settings panel with interactive controls.

**Files modified:**
- `dashboard/dashboard.js` — new UI in `renderSettingsPanel()`
- `dashboard/dashboard.html` — mirror all JS changes (LESSON-OPS-043)
- `dashboard/dashboard.h` — regenerated
- `Docs/changelog.md`
- Version bump

**UI design:**

The Settings panel gets three new elements:

1. **Add Satellite form:** URL input + optional name + "Test" button + "Add" button
   - "Test" calls `POST /api/aggregator/test-satellite?url=...` and shows result
   - "Add" calls `POST /api/aggregator/add-satellite?url=...&name=...`
   - Success: satellite appears in the list immediately (re-fetch gateways)
   - Error: show error message inline

2. **Per-satellite remove button:** Each satellite card gets a "Remove" button
   - Calls `DELETE /api/aggregator/satellite/{id}`
   - Confirmation prompt before deletion
   - Success: satellite disappears from list (re-fetch gateways)

3. **Status display improvements:**
   - Show "NVS-persisted" or "Compile-time default" indicator per satellite
   - Show last-seen timestamp
   - Show consecutive failure count if > 0

**Acceptance criteria:**
- [ ] Add form validates URL, shows test result, adds satellite
- [ ] Remove button with confirmation deletes satellite
- [ ] UI updates immediately after add/remove (re-poll)
- [ ] Works in dark and light mode
- [ ] All JS changes mirrored to dashboard.html
- [ ] dashboard.h regenerated
- [ ] Environmental/network/system cards pixel-identical

**Risk:** Medium. Dashboard JS changes are always the highest-risk due to the mirroring requirement.
**Estimated effort:** 2 sessions.

### v7.6.0.5 — Playwright Tests + Phase D Closure ✅ COMPLETE

**Delivered:** PR #129, branch `claude/add-new-validation-tests`, 2026-04-04

**Scope:** Test fixtures and Playwright tests for satellite management. Phase D closure documentation.

**Files modified:**
- `tests/browser/dashboard.spec.js` — new Test Group 21: Satellite Management (19 tests)
- `tests/mock-server/server.js` — stateful mock routes for add/delete/test/reset endpoints
- `tests/fixtures/variants/aggregator/` — updated fixtures if needed
- `.github/workflows/browser-tests.yml` — CI matrix update if needed
- `Docs/v7.5-v7.6-architecture-plan.md` — Phase D COMPLETE status
- `Docs/changelog.md` — Phase D closure entry
- `Docs/aggregator-setup.md` — update with runtime management workflow
- Version bump

**Deliverables:**
- Stateful mock server routes: `POST /api/aggregator/add-satellite`, `DELETE /api/aggregator/satellite/{id}`, `POST /api/aggregator/test-satellite`, `POST /api/system/reset-satellites`
- Test Group 21: 19 tests (12 API contract + 2 UI rendering + 5 PR #128 regression guards)
- Full validation branch coverage: body guard, auth, method 405, poll clamping, empty ID, monotonic IDs
- All four fixture sets green: 3sensor, mixed, system, aggregator
- PR #128 regression guards: BUG-080 / BUG-081 / LESSON-OPS-111 locked down

**Closure gate:**
- [x] All management endpoints functional
- [x] NVS persistence survives reboot
- [x] Dashboard add/remove/test UI operational (v7.6.0.4 = PR #126 + PR #128)
- [x] All CI-exact Playwright runs pass (402 tests passed, 0 failed)
- [x] Aggregator-setup.md updated with runtime management workflow
- [x] **Phase D complete**

**Risk:** Low. Standard test infrastructure work.
**Estimated effort:** 1–2 sessions.

---

## Version Number Mapping

| Phase | Version Range | Description |
|-------|--------------|-------------|
| Phase 6 | v7.5.6.0–v7.5.6.4 | Data Ingest + System Metrics |
| **Phase D** | **v7.6.0.0–v7.6.0.5** | **Runtime Satellite Management** |
| Phase 7 | v7.7.0.0–v7.7.2.3 | Per-Device Persistence Engine |
| Phase E | v8.0.x | Captive Portal Setup + WiFi Config |

---

## What This Changes for the Operator

| Operation | Before Phase D | After Phase D |
|-----------|---------------|---------------|
| Add a satellite | Edit `config/aggregator.json`, run generator, reflash | Dashboard → Settings → paste URL → "Add" |
| Remove a satellite | Edit JSON, regenerate, reflash | Dashboard → Settings → "Remove" → confirm |
| Test connectivity | `curl` from command line | Dashboard → Settings → paste URL → "Test" |
| Configuration survives reboot | Yes (compiled in) | Yes (NVS-persisted) |
| Maximum satellites | Compile-time (currently 2) | Compile-time cap (8), runtime variable |

---

## Dependencies and Prerequisites

1. **Phase 6 must be complete** — system device and ingest endpoint provide the test infrastructure patterns needed for Phase D testing.
2. **ArduinoJson or manual parsing** — determine JSON body parsing strategy before v7.6.0.1 (recommendation: use query strings).
3. **NVS partition space** — verify the default NVS partition has enough free entries for 8 satellites × 4 keys = 32 additional NVS entries. The history partition is separate and unaffected.

---

## Risk Summary

| Step | Risk | Mitigation |
|------|------|------------|
| v7.6.0.0 NVS layer | Low-Medium | Pattern copied from history persistence |
| v7.6.0.1 Add satellite | Medium | Probe logic reuses `fetch_to_buffer()` |
| v7.6.0.2 Delete satellite | Low | Simple array compaction |
| v7.6.0.3 Test satellite | Low | Subset of add logic |
| v7.6.0.4 Dashboard UI | Medium | JS mirroring is always risky |
| v7.6.0.5 Tests + closure | Low | Standard test infrastructure |

**Total estimated effort: 6–9 sessions across the phase.**

---

_End of Phase D implementation plan._
