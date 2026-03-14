# Changelog

## v7.5.0.1 — Phase 1 completed and runtime-validated
Date: 2026-03-14

### Summary
Completed Phase 1 of the v7.5/v7.6 architecture plan on the live ESP32-C3 gateway and validated the result through compile, OTA upload, API checks, and UI checks.

### What changed
- Added new firmware endpoint `GET /api/manifest` that serves schema v2 sensor/metric metadata.
- Preserved legacy compatibility endpoint `GET /sensors.json`.
- Kept `GET /api/status` as the runtime/status source and confirmed it includes `free_heap`, `uptime_seconds`, `sensor_count`, sensor validity state, RAM-history point count, and persisted-days settings.
- Updated dashboard bootstrap to prefer `/api/manifest`, with fallback to `/sensors.json`.
- Restored dashboard display of **Free Heap** and **Uptime** using `/api/status`.
- Restored built-in ESPHome web page diagnostics for **Free Heap**, **Uptime**, and **Loop Time**.
- Re-aligned source and generated dashboard artifacts so `dashboard.html`, `dashboard.min.html`, and `dashboard.h` represent the same runtime behavior.
- Fixed generator drift so `python3 scripts/render_sensor_config.py --write` is idempotent again.
- Fixed YAML indentation handling in generated marker-managed blocks.

### Validation completed
- `python3 scripts/render_sensor_config.py --write` → no changes needed after final fix.
- `bash ./scripts/preflight.sh` → PASS.
- `esphome compile firmware/esp32-c3-multi-sensor.yaml` → PASS.
- `esphome run firmware/esp32-c3-multi-sensor.yaml` → OTA upload PASS.
- Runtime endpoint validation:
  - `/sensors.json` → PASS
  - `/api/status` → PASS
  - `/api/manifest` → PASS
- Dashboard runtime validation:
  - dashboard loads
  - Free Heap visible again
  - Uptime visible again
- Built-in ESPHome web page validation:
  - Free Heap visible again
  - Uptime visible again

### Final baseline after Phase 1
- Version: `v7.5.0.1`
- Board/framework baseline unchanged from current repo/environment.
- Current recommended branch point for next work: Phase 2 start from `v7.5.0.1`.

## v7.5.0.0 — Initial Phase 1 implementation attempt
Date: 2026-03-13

### Summary
Implemented the initial `/api/manifest` endpoint, manifest-first dashboard boot path, test/fixture updates, and doc updates, but local repo application uncovered generator and runtime regressions that were later corrected in `v7.5.0.1`.

### Notable outcomes
- Firmware endpoint and initial dashboard manifest wiring compiled after recovery.
- Local repo patching surfaced brittle patch-script assumptions against compacted one-line files.
- Generator and YAML issues were discovered and fixed during recovery.
- Runtime regression on dashboard/built-in diagnostics was fixed in `v7.5.0.1`.
