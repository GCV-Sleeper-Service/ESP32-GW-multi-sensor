# Session Log — 2026-03-26 — v7.5.6.1

## Summary
Implemented Phase 6 Step 1 (v7.5.6.1): added system device category support and `external_push` adapter support, generated system `SensorEntity` entries/metrics/history buffers, regenerated artifacts, and updated regression expectations for the new 5-device satellite manifest.

## Changes Made

### 1) Manifest/config updates
- Added `nas01` to `config/sensors.json` after `wan_ping`:
  - `category: "system"`
  - `adapter: "external_push"`
  - `source.description` for ingest origin

### 2) Validation/modeling updates (`scripts/sensor_manifest_lib.py`)
- Kept `VALID_CATEGORIES` with `system` support.
- Added `external_push` adapter branch in `canonicalize_sensors()`:
  - No `mac` required
  - Optional `source.description` accepted and normalized
  - Added explicit invalid-adapter error for unknown adapters
- Increased `MAX_SENSORS` from 4 → 5 for the new default 5-device manifest.
- Added `_SYSTEM_METRICS` definitions:
  - `cpu_pct`, `ram_pct`, `disk_pct` (history enabled)
  - `uptime_hrs` (metadata, no history)
- Extended `manifest_v2()`:
  - System device entries now emit `source` + `measurements` with `/api/v2/history/...` URLs
  - Top-level `metrics` now includes environmental + network + system metric definitions

### 3) Generator updates (`scripts/render_sensor_config.py`)
- Extended `render_entity_block()` to support `external_push` devices:
  - Added `metrics_system[]`
  - Added HistoryBuffers for `cpu_pct`, `ram_pct`, `disk_pct`
  - Added `SensorEntity` emission with `category_id = 1`, `adapter = "external_push"`, `metric_count = 4`
- Verified generated constants in header now show:
  - `NUM_DEVICES = 5`
  - `NUM_ENV_SENSORS = 3`
  - `NUM_SENSORS = NUM_ENV_SENSORS`

### 4) Fixture/mock/test alignment
- Updated `tests/fixtures/generate-fixtures.js`:
  - Added system metric library
  - Added `external_push` manifest sensor mapping
  - Included system metrics in top-level manifest `metrics`
- Updated `tests/mock-server/server.js` `/api/v2/live` stub to return null-valued system metrics for `external_push` devices.
- Updated Playwright expectations:
  - `tests/browser/manifest.spec.js` now accepts expanded metrics and validates dashboard sensor list dynamically from `/api/manifest`.
  - `tests/browser/dashboard.spec.js` updated 3sensor expectations from 4→5 cards where appropriate and category assertions include `system`.

### 5) Tooling/docs updates
- Ran `bash scripts/bump-version.sh 7.5.6.1`.
- Updated preflight guard in `scripts/preflight.sh`:
  - `fixture_manifest_sensor_count` expects 5.
- Updated documentation files listed below.

## Regeneration Sequence (Critical Rule 28)
Executed in order:
1. `python3 scripts/render_sensor_config.py --write`
2. `node tests/fixtures/generate-fixtures.js`
3. `bash scripts/generate-header.sh`
4. `python3 scripts/render_sensor_config.py --check`
5. `grep -q "free_heap" tests/fixtures/api-status.json`

## Validation
- Pre-condition suite run before edits:
  - `FIXTURE_SET=3sensor npx playwright test --project=chromium`
  - `FIXTURE_SET=3sensor npx playwright test --project=firefox`
  - `FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium`
  - `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium`
  - `bash scripts/preflight.sh`
  - `python3 scripts/render_sensor_config.py --check`
- Post-change full suite rerun (same command set + required checks) completed and passing in this session.

## Endpoint audit notes for v7.5.6.1
- `/sensors.json`: environmental-only projection; excludes `nas01`.
- `/api/status`: includes `nas01` with `category: "system"` and omits `temp_valid`/`hum_valid` (environmental-only fields).
- `/api/manifest`: includes `nas01` and system measurements.
- `/api/v2/live`: includes `nas01` (null values before ingest).
- `/history/nas01/temp`: returns 404 (legacy environmental route guard).
- `/api/v2/history/nas01/cpu_pct`: route resolves and returns CSV payload semantics.
- `/api/ingest/nas01/cpu_pct?val=50`: handled by existing v7.5.6.0 ingest endpoint.

## Instruction Compliance Output
- Read implementation prompt file fully before any changes.
- Read all files listed under Required Reading fully before edits.
- Ran required pre-condition checks before modifying files.
- Did not add system card renderer (reserved for v7.5.6.2).
- Did not modify ingest endpoint semantics beyond required integration validation.
- Preserved `NUM_SENSORS = NUM_ENV_SENSORS` invariant.
- Used generators/regeneration flow; no manual fixture JSON edits.
