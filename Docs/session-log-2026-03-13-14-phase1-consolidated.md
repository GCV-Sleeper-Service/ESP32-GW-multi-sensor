# Session Log — Phase 1: Manifest Endpoint Implementation (v7.5.0.0 → v7.5.0.1)

_Dates: 2026-03-13 and 2026-03-14_  
_Final baseline: v7.5.0.1_  
_Closed by commit: bd20a1d_

---

## Request

Implement Phase 1 of the v7.5/v7.6 architecture plan for the ESP32-GW-multi-sensor repo.

Phase 1 scope:
1. Add `GET /api/manifest` endpoint to firmware
2. Update dashboard boot to prefer `/api/manifest` with fallback to `/sensors.json`, then built-in defaults
3. Add tests and preflight guardrails for the new contract
4. Update changelog, bugs/lessons, architecture docs, and fresh-start handoff
5. Validate on the real device

---

## Request Understanding

The architecture plan (`Docs/v7.5-v7.6-architecture-plan.md`) defines Phase 1 as: "Introduce the new data contract without changing runtime behavior." The manifest endpoint serves as the foundation for everything that follows — dashboard rendering, aggregation, and CLI tools.

Key constraints applied to this phase:
- **Additive first, non-breaking by default.** `/sensors.json` was already consumed by multiple parts of the repo/tooling. `/api/manifest` was introduced alongside it, not as a replacement.
- **Backward compatibility is non-negotiable.** Any existing consumer (older firmware, external scripts, test fixtures) must continue to work.
- **The canonical sensor manifest `config/sensors.json` remains the single source of truth** for configured sensors.

---

## Findings

### Baseline state at Phase 1 start (v7.4.5.1)
- Firmware served: `/sensors.json`, `/api/status`, `/api/storage-stats`, `/history/*`, and all import endpoints
- Dashboard boot: fetched `/sensors.json` only, with `DEFAULT_SENSOR_META` as fallback
- Test fixtures: legacy v1 manifest shape only
- No `/api/manifest` endpoint, no schema v2 contract, no manifest-driven dashboard boot

### Phase 0 context
Phase 0 (doc alignment and baseline verification, commit 86e6c78) had already been completed. The architecture plan was in the repo (`Docs/v7.5-v7.6-architecture-plan.md`) and `main` was green with all preflight and Playwright checks passing.

---

## Actions and Changes Performed

### 1. Defined Phase 1 manifest contract shape

Added a manifest-v2 response structure to the firmware:
- Top-level `schema_version: 2` and firmware source metadata
- `sensor_count` field
- Shared `metrics` array with `key`, `name`, `unit`, `unit_symbol`, `bounds`, and `history_suffix` per metric
- Per-sensor entries with stable `id`/`name` and metric-specific history URL paths

This is a pragmatic Phase 1 v2 — not the full schema from the plan (which includes `gateway` identity block, `history` retention policy, and per-measurement `class`/`data_type`/`display` hints). Those fields are the Phase 2 prerequisite. See ISSUE-003.

### 2. Added `/api/manifest` handler in `sensor_history_multi.h`

Implemented as an inline `handle_api_manifest_()` method in the existing web request handler class. The response is built from runtime structs using `resp->print()` calls. The architectural plan specified a generated `gateway_manifest.h` C string literal — this was deferred for Phase 1 in favour of the simpler inline approach that gets the endpoint working and device-validated.

Endpoint added to both `canHandle()` and `handleRequest()` dispatch paths alongside existing routes. `/sensors.json` compatibility endpoint preserved unchanged.

### 3. Updated dashboard boot sequence

`loadSensorManifest()` in `dashboard.js` now:
1. Fetches `GET /api/manifest` — on success, calls `normalizeManifestSensors(payload)` which extracts `sensors[]` array from the v2 response
2. On failure → fetches `GET /sensors.json` — extracts the legacy array directly
3. On both failing → uses `DEFAULT_SENSOR_META` built-in fallback

`normalizeManifestSensors()` handles both v1 array and v2 object payloads, normalizing to the internal `{id, name, metrics[]}` shape used by the rest of the dashboard.

### 4. Extended test and fixture layer

- `tests/fixtures/manifest.json` — new schema v2 fixture for mock server and Playwright tests
- `tests/fixtures/api-status.json` — aligned to match active sensor list
- `tests/mock-server/server.js` — updated to serve `GET /api/manifest` from the fixture
- `tests/fixtures/generate-fixtures.js` — updated to emit the v2 manifest fixture alongside legacy fixtures
- `tests/browser/manifest.spec.js` — new Playwright spec validating:
  - `/api/manifest` returns schema v2
  - Dashboard boots normally from `/api/manifest`
  - Dashboard still boots when `/api/manifest` is unavailable but `/sensors.json` is present

### 5. Extended preflight

`scripts/preflight.sh` extended with manifest-related checks:
- Firmware route presence for `/api/manifest` in `canHandle()` and `handleRequest()` paths
- Dashboard preference for `/api/manifest` in `loadSensorManifest()`
- Dashboard fallback to `/sensors.json` presence
- Fixture schema v2 baseline existence
- Ability to regenerate manifest fixtures from `config/sensors.json`
- Manifest browser spec execution when Playwright is installed

### 6. Generator and YAML recovery (multiple iterations)

The initial delivery triggered three separate recovery cycles before achieving a stable, device-validated state:

**Recovery 1 — Patch script brittleness (BUG-033):**  
`apply_phase1_manifest_patch.py` failed repeatedly against `sensor_history_multi.h` because the header uses compacted one-line formatting for handler blocks. Exact-string matching against long multi-line strings failed. Fix: rewrote the patch approach to use function anchors and regex-based block insertion.

**Recovery 2 — Generator regex crash (BUG-034):**  
`render_sensor_config.py --write` crashed with `re.PatternError: bad escape \x` when processing generated strings containing `\xC2\xB0` (degree symbol Unicode escape). Fix: changed all `re.sub()` calls for generated content to lambda-based replacement.

**Recovery 3 — YAML indentation regression (BUG-035 and BUG-036):**  
After the regex fix, `esphome compile` failed with `expected <block end>` near line 135. Root cause: `render_yaml_file()` was routing YAML marker regions through `replace_marker_block()` instead of `apply_yaml_marker_block()`. The content was correct but indentation relative to the marker location was lost. A hotfix corrected one call site but another survived, requiring a second pass. Fix: all YAML marker replacements in `render_sensor_config.py` switched to `apply_yaml_marker_block()`. Confirmed idempotent by running `--write` twice.

### 7. Runtime dashboard fixes (v7.5.0.1)

After OTA flashing, two runtime regressions appeared:

**Fix 1 — Free Heap and Uptime showed "loading…" (BUG-038):**  
Dashboard expected `/sensor/Free Heap` and `/sensor/Uptime` — legacy entity-polling paths. The authoritative data was already in `GET /api/status`. Fix: switched all device-status widget hydration to `GET /api/status`.

**Fix 2 — Built-in ESPHome web page lost diagnostics (BUG-037):**  
`debug.free`, `debug.loop_time`, and `uptime` sensor blocks were missing from YAML after Phase 1 changes. Fix: restored all three blocks. Confirmed both the custom dashboard and the built-in page show all diagnostics.

### 8. Dashboard source/artifact alignment (BUG-039)

After the runtime fixes were applied, `dashboard.html` had been patched but `dashboard.min.html` and `dashboard.h` had not been regenerated. The embedded firmware payload was still running stale client logic. Fix: regenerated `dashboard.min.html` and `dashboard.h` from the corrected `dashboard.html` source.

---

## Final Validation Results

All validation completed on the live ESP32-C3 device running v7.5.0.1:

| Check | Result |
|---|---|
| `python3 scripts/render_sensor_config.py --write` | No changes needed (idempotent) |
| `bash ./scripts/preflight.sh` | PASS |
| `esphome compile firmware/esp32-c3-multi-sensor.yaml` | PASS |
| `esphome run firmware/esp32-c3-multi-sensor.yaml` | OTA PASS |
| `GET /sensors.json` | Returns 3-sensor legacy array ✓ |
| `GET /api/status` | Returns version, uptime, heap, sensor validity ✓ |
| `GET /api/manifest` | Returns schema v2 response ✓ |
| Dashboard load | Sensor cards render ✓ |
| Dashboard Free Heap | Visible and updating ✓ |
| Dashboard Uptime | Visible and updating ✓ |
| Built-in ESP page Free Heap | Visible ✓ |
| Built-in ESP page Uptime | Visible ✓ |
| Built-in ESP page Loop Time | Visible ✓ |

---

## Bugs and Lessons Learned

All bugs and lessons from this phase are recorded in `Docs/bugs-and-lessons-learned.md`.

**New bugs this phase:**
- BUG-033: Phase 1 patch script failed against compacted one-line source blocks
- BUG-034: Generator crashed with `re.PatternError: bad escape \x` on generated content
- BUG-035: YAML generator produced invalid indentation in ESPHome block scalars
- BUG-036: YAML generator reintroduced broken indentation after hotfix — preflight passed but compile failed
- BUG-037: Built-in ESPHome diagnostics disappeared from the built-in web page after Phase 1
- BUG-038: Dashboard Free Heap and Uptime showed "loading…" after Phase 1 OTA
- BUG-039: Dashboard source and generated artifacts drifted after Phase 1 work

**New lessons this phase:**
- LESSON-OPS-039: Use lambda replacements in `re.sub()` when generated content may contain backslashes
- LESSON-OPS-040: YAML generator must use indentation-aware insertion for all block scalar sections
- LESSON-OPS-041: YAML generator correctness requires both idempotent marker replacement and indentation preservation
- LESSON-OPS-042: Dashboard device-status widgets should hydrate from `GET /api/status`, not entity polling
- LESSON-OPS-043: `dashboard.html` is the source of truth — regenerate artifacts after every edit
- LESSON-OPS-044: Runtime validation must cover both the custom dashboard and the built-in ESPHome web page
- LESSON-OPS-045: Preflight must include a YAML/ESPHome parse gate, not just generated-file sync checks

---

## Open Items for Phase 2

The following items were scoped out of Phase 1 and are required inputs for Phase 2:

1. **Upgrade `/api/manifest` to full v2 schema.** Add `gateway` identity block, `history` retention policy block, and per-measurement `class`/`data_type`/`display` hints. See ISSUE-003 and `Docs/v7.5-v7.6-architecture-plan.md` section 5.2.
2. **Add ESPHome YAML parse gate to preflight.** `esphome config firmware/esp32-c3-multi-sensor.yaml` should be a preflight step. See ISSUE-004 and LESSON-OPS-045.
3. **Align `tests/fixtures/manifest.json` to the full v2 schema.** Currently this is a partial schema sufficient for Phase 1 tests only.
4. **Phase 2 dashboard work.** See `Docs/esp32-gateway-fresh-start-handoff.md` section 7 for the full Phase 2 task sequence.

---

## Suggested Branch for Next Work

```bash
git checkout main
git pull
git checkout -b phase2-from-v7.5.0.1
```
