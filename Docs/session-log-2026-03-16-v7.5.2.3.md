# Session Log — 2026-03-16 — v7.5.2.3 Generic History Fetching

## Session Summary

Implemented v7.5.2.3: Generic history fetching as specified in
`Docs/phase2-implementation-plan.md`.

---

## Request

Implement v7.5.2.3 scope:
- Refactor history fetching to be driven by manifest measurement definitions instead of hardcoded temp/hum paths
- Use `measurements[].history_url` from manifest when present
- Preserve fallback to legacy `/history/{id}/temp` and `/history/{id}/hum` when manifest data unavailable
- Preserve identical rendered chart behavior/output
- Version bump to 7.5.2.3 in all required locations
- Regenerate all required artifacts
- Add Playwright test group 13 for manifest-driven history URL behavior and fallback behavior
- Update docs (changelog, session handoff log)
- Do not proceed to v7.5.2.4

---

## Understanding

The dashboard had two separate history-fetching call sites:

1. **`fetchSensorHistoryRows(sensor)`** — used by CSV export functions (parallel Promise.all of temp + hum fetches)
2. **`loadHistory()` inline chain** — the sequential per-sensor chart-loading path (chained `.then()` fetching temp then hum one after another)

Both hardcoded `/history/{id}/temp` and `/history/{id}/hum` as the URL patterns.

The v7.5.2.3 refactor introduces `fetchDeviceHistory(sensor, manifest)` as the canonical URL resolver. Both call sites are refactored to delegate to it.

Key constraint: chart rendering output must be identical. The data format (compact CSV lines of `epoch,value`) is unchanged. Only the URL derivation path changes.

Key discovery (inherited from v7.5.2.1/v7.5.2.2): `dashboard/dashboard.html` embeds the full JS
inline (not just a `<script src>`), so it must be manually kept in sync with `dashboard/dashboard.js`.
The version bump script (`bump-version.sh`) updates `App.version` in `dashboard.js` via
`render_sensor_config.py` but does NOT update `dashboard.html`. The `dashboard.html` update must be
done manually after the bump script, followed by a manual `generate-header.sh` run.

Pre-existing note: The console-error tests (`8. Console error guard` and `sensor-count` console errors)
were already failing on main before v7.5.2.3 changes due to `ERR_NAME_NOT_RESOLVED` from the
`FILE_FALLBACK_HOST` (`http://192.168.120.189`) used in the test environment. These are not
regressions introduced by v7.5.2.3.

---

## Implementation

### Files Changed

**`dashboard/dashboard.js`**:
- Added header comment for v7.5.2.3 alongside existing v7.5.2.0 comment
- Added `fetchDeviceHistory(sensor, manifest)`:
  - Looks up `manifest.sensors` for the sensor by id
  - Iterates `measurements[]`, finds metric definitions in `manifest.metrics`
  - Includes only measurements with `metricDef.history === true` and `metricDef.display.chart === true`
  - Derives URL from `m.history_url` if present, otherwise from `'/history/' + sensor.id + '/' + (metricDef.history_suffix || m.key)`
  - Falls back to legacy `[{key:'temp', url:'/history/{id}/temp'}, {key:'hum', url:'/history/{id}/hum'}]` when manifest has no matching sensor or `historyMeasurements` is empty
  - Returns `Promise<Array<{key, raw}>>` where `raw` is the CSV text
- Refactored `fetchSensorHistoryRows(sensor)` to delegate to `fetchDeviceHistory(sensor, window._manifest)`
- Refactored `loadHistory()` inline fetch chain to use `fetchDeviceHistory(s, window._manifest)`:
  - Replaced sequential chained `.then()` with `Promise.all()` inside `fetchDeviceHistory`
  - `loadNext()` still called recursively at the end of each sensor's resolution (sequential per-sensor loading preserved)
  - Temp/hum point extraction, min/max updates, and DOM updates unchanged
- Added `App.API.fetchDeviceHistory = fetchDeviceHistory` to the module export block

**`dashboard/dashboard.html`** (kept in sync manually):
- Same v7.5.2.3 comment added
- `App.version` updated to `'v7.5.2.3'`
- Same `fetchDeviceHistory()` function added before `fetchSensorHistoryRows()`
- Same refactoring of `fetchSensorHistoryRows()` and `loadHistory()` inline chain
- Same `App.API.fetchDeviceHistory` export added

**`dashboard/dashboard.h`** (regenerated):
- Regenerated from `dashboard/dashboard.html` via `bash scripts/generate-header.sh`

**`tests/browser/dashboard.spec.js`**:
- Added Group 13 (5 tests):
  - `fetchDeviceHistory is a callable function`
  - `App.API.fetchDeviceHistory is exported`
  - `fetchDeviceHistory uses history_url from manifest measurements` — uses `page.route()` interception after page load to capture URLs from a direct `fetchDeviceHistory()` call
  - `fetchDeviceHistory falls back to legacy URLs when manifest is null` — passes `null` as manifest
  - `fetchDeviceHistory falls back to legacy URLs when manifest has no matching sensor` — passes empty `{sensors:[], metrics:[]}` manifest

**`Docs/changelog.md`**:
- Added v7.5.2.3 entry

**Version bump files** (via `bash scripts/bump-version.sh 7.5.2.3`):
- `VERSION` — `7.5.2.3`
- `scripts/render_sensor_config.py` — VERSION constant → `7.5.2.3`
- `tests/fixtures/generate-fixtures.js` — VERSION constant → `v7.5.2.3`
- `dashboard/dashboard.js` — `App.version` → `'v7.5.2.3'`
- `dashboard/sensor_history_multi.h` — header comment version
- `firmware/esp32-c3-multi-sensor.yaml` — version references
- `src/gateway_manifest.h` — firmware_version in manifest JSON
- `tests/fixtures/manifest.json` — version + firmware_version
- `tests/fixtures/api-status.json` — version

---

## Validation

### Preflight (`bash scripts/preflight.sh`)

All checks passed:
- `version_file_present: PASS`
- `dashboard_js_version_matches: PASS`
- `dashboard_h_version_matches: PASS`
- `firmware_version_matches: PASS`
- `history_header_version_matches: PASS`
- `history_handler_has_api_manifest_route: PASS`
- `dashboard_prefers_api_manifest: PASS`
- `dashboard_legacy_manifest_fallback: PASS`
- `mock_server_serves_api_manifest: PASS`
- `fixture_manifest_schema_v2: PASS`
- `fixture_manifest_sensor_count: PASS`
- `browser_spec_present: PASS`
- `no_old_dashboard_version: PASS`
- `no_old_firmware_version: PASS`
- `render_sensor_config_py_version_sync: PASS`
- `fixture_generator_version_sync: PASS`
- `gateway_manifest_h_included: PASS`
- `gateway_manifest_json_used: PASS`
- `gateway_manifest_yaml_includes: PASS`
- Manifest v2 schema validation: PASS
- `render_sensor_config: PASS`
- `fixture_baseline_manifest_regenerated: PASS`

### Playwright Tests

63 tests passed, 2 pre-existing failures (not regressions from v7.5.2.3):

**Pre-existing failures (exist on `main` before v7.5.2.3 changes):**
- `8. Console error guard › no unexpected JS errors during normal session startup`
- `sensor-count: status and charts render correctly › no JS console errors on load`

Both fail with `ERR_NAME_NOT_RESOLVED` (3 occurrences) — this is the dashboard attempting to
resolve `FILE_FALLBACK_HOST = 'http://192.168.120.189'` in the Playwright test environment
where that host is unreachable. Not introduced by v7.5.2.3.

**New Group 13 tests (all passed):**
- `fetchDeviceHistory is a callable function` ✓
- `App.API.fetchDeviceHistory is exported` ✓
- `fetchDeviceHistory uses history_url from manifest measurements` ✓
- `fetchDeviceHistory falls back to legacy URLs when manifest is null` ✓
- `fetchDeviceHistory falls back to legacy URLs when manifest has no matching sensor` ✓

---

## Phase 2 Status After This Session

- ✅ v7.5.2.0 — Manifest v2 loader complete
- ✅ v7.5.2.1 — Card renderer registry complete
- ✅ v7.5.2.2 — Metric formatters complete
- ✅ v7.5.2.3 — Generic history fetching complete (this session)
- ⏳ v7.5.2.4 — Full Playwright regression + Phase 2 closure (pending)

---

## Handoff Notes for Next Session (v7.5.2.4)

v7.5.2.4 is Phase 2 closure: final validation, documentation, and marking Phase 2 complete.

Key tasks:
1. Add comprehensive manifest-driven rendering tests (all 8 test cases from the plan)
2. Update `Docs/v7.5-v7.6-architecture-plan.md` — Phase 2 Status: COMPLETE
3. Update `Docs/changelog.md` with v7.5.2.4 entry and Phase 2 Complete callout
4. Create session handoff log for v7.5.2.4
5. Version bump to 7.5.2.4

Pre-existing test failures to note (do not introduce regressions, do not fix unrelated issues):
- `8. Console error guard` and `sensor-count console errors` — already failing due to ERR_NAME_NOT_RESOLVED from unreachable FILE_FALLBACK_HOST in test environment
