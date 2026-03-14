# Session Log — 2026-03-13 — v7.5.0.0 Phase 1 Manifest Implementation

## Request
Implement Phase 1 of the manifest architecture for the ESP32 BLE gateway repo.

## Request understanding
The requested scope for this session was:
1. add `/api/manifest` in firmware
2. update dashboard boot to consume the new endpoint
3. retain durable session-log coverage during the work
4. add tests / preflight guardrails for the new contract
5. update changelog / bugs / architecture / fresh-start notes
6. package the result as a repo-root overwrite bundle with explicit run instructions

## Constraints / assumptions used
- compatibility mattered more than aggressive cleanup
- `/sensors.json` was already depended on by multiple parts of the repo/tooling
- therefore Phase 1 was implemented as **add new v2 endpoint + keep legacy endpoint** rather than a hard replacement
- the canonical sensor manifest in `config/sensors.json` remains the source of truth for configured sensors

## Baseline observed before implementation
- current repo default was v7.4.5.1
- firmware already served `/sensors.json`, `/api/status`, `/api/storage-stats`, `/history/*`, and import endpoints
- dashboard boot still fetched `/sensors.json`
- test fixtures only had the legacy manifest shape

## Actions performed

### 1. Defined the Phase 1 contract shape
Added a manifest-v2 structure with:
- top-level schema metadata
- shared metric metadata for `temp` and `hum`
- per-sensor metadata with stable id/name and metric-specific history paths

### 2. Preserved backward compatibility explicitly
Rather than reusing `/sensors.json` for the richer contract, `/api/manifest` was introduced as the new preferred endpoint and `/sensors.json` was retained as a compatibility projection.

### 3. Updated the dashboard boot contract
Dashboard boot logic now follows:
1. `/api/manifest`
2. `/sensors.json`
3. built-in defaults

This reduces breakage risk during mixed-version development (new repo UI against older flashed firmware, or test fixtures lagging behind the runtime contract).

### 4. Extended the mock / fixture layer
The fixture generator now emits:
- `tests/fixtures/sensors.json` (legacy array)
- `tests/fixtures/manifest.json` (schema-v2 object)
- `tests/fixtures/api-status.json` aligned with the same active sensor list

### 5. Added browser/API coverage
A new Playwright spec validates:
- `/api/manifest` returns schema v2
- dashboard boots normally from `/api/manifest`
- dashboard still boots when `/api/manifest` is unavailable but `/sensors.json` is still present

### 6. Added preflight guardrails
Preflight now checks for:
- firmware route presence for `/api/manifest`
- dashboard preference for `/api/manifest`
- dashboard fallback to `/sensors.json`
- presence of fixture schema-v2 baseline
- ability to regenerate manifest fixtures from `config/sensors.json`
- manifest browser spec execution when Playwright is installed

## Bugs / risks identified during implementation

### Risk: replacing `/sensors.json` outright would have been too disruptive
That route was already part of the browser/mock/helper ecosystem. The safer move was additive migration.

### Risk: tests could still pass while the new payload shape drifted
Without a dedicated `manifest.json` fixture and a spec for schema-v2 boot, the new contract would have been much easier to regress silently.

## Durable design notes intentionally carried forward

### Single-sensor import merge design
This was already implemented previously but is important enough to record again because it influences future history-facing changes:
- on single-sensor import begin, the firmware builds an epoch-to-slot map from retained history
- on each write batch, it reuses the existing slot for that hour when present
- it overlays only the target sensor arrays into the existing segment
- it writes the merged segment back to the same slot
- new hours allocate new slots
- temporary overhead remains roughly ~7 KiB

This detail was explicitly added here because earlier sessions showed that important internal design reasoning can otherwise remain trapped in chat and fail to make it into durable repo documents.

## Deliverables in this bundle
- `VERSION`
- `scripts/apply_phase1_manifest_patch.py`
- `scripts/render_sensor_config.py`
- `scripts/sensor_manifest_lib.py`
- `scripts/preflight.sh`
- `scripts/test-local.sh`
- `tests/mock-server/server.js`
- `tests/fixtures/generate-fixtures.js`
- `tests/fixtures/sensors.json`
- `tests/fixtures/manifest.json`
- `tests/fixtures/api-status.json`
- `tests/browser/manifest.spec.js`
- updated architecture / changelog / bugs / fresh-start docs

## What still needs real-device validation
- compile after patch application
- embedded dashboard boot on flashed firmware
- actual `/api/manifest` response from ESP firmware
- no regression in export/import/history flows on device
- no regression in dashboard embedded-header generation flow

## Recommended next-step order for the operator
1. unzip bundle at repo root
2. run `python3 scripts/apply_phase1_manifest_patch.py`
3. run `python3 scripts/render_sensor_config.py --write`
4. regenerate minified dashboard/header
5. run preflight
6. compile
7. flash and test on the actual gateway

## Suggested next development phase after validation
Once this build is validated on hardware, the next discussion should be whether the project wants:
- to keep `/sensors.json` indefinitely as a stable compatibility surface, or
- to treat it as transitional only and gradually migrate helper tooling fully to the v2 manifest model
