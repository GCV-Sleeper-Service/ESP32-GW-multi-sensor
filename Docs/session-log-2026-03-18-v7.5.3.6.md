# Session Log — 2026-03-18 — v7.5.3.6

## Goal

Add `/api/v2/live` endpoint from `SensorEntity` (Phase 3, step v7.5.3.6).

## Starting state

- v7.5.3.5 complete and merged
- main is green
- All preflight checks pass

## Changes made

### 1. `dashboard/sensor_history_multi.h`

- Added `/api/v2/live` to `canHandle()` GET routes
- Added dispatch in `handleRequest()` to call `handle_api_v2_live_()`
- Added `handle_api_v2_live_()` method:
  - Uses `beginResponseStream("application/json")` + `add_common_headers_()`
  - Iterates `devices[0..NUM_DEVICES-1]`
  - For each device: emits all metrics from `metric_defs[]/metric_states[]`
  - Invalid metrics (`valid == false`) emit `null`
  - Includes `last_seen` epoch per device
  - Uses `::time(nullptr)` for timestamp (ESPHome convention)

### 2. `scripts/preflight.sh`

- Added `history_handler_has_api_v2_live_route` check

### 3. Version bump

- `7.5.3.5` → `7.5.3.6` via `bump-version.sh`
- All canonical and generated files updated

### 4. Documentation

- `Docs/changelog.md` — added v7.5.3.6 entry
- Created this session log

## Verification

- All preflight checks pass (including new `/api/v2/live` route check)
- No dashboard JS changes (as specified)
- SensorSlot unchanged
- Existing endpoints unchanged

## Next step

v7.5.3.7 — Add `/api/v2/history/{device}/{metric}` endpoint
