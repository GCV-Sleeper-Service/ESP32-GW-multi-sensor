# Session log addendum — v7.5.0.1 runtime/UI source-truth fix

## Scope
Fix the post-Phase-1 runtime regressions where:
- `/api/manifest` and `/api/status` worked, but the dashboard still showed **Free Heap** and **Uptime** as `loading...`
- the ESPHome built-in web page no longer showed **Free Heap** / **Uptime**
- `dashboard.html` had drifted behind the embedded artifacts (`dashboard.min.html`, `dashboard.h`)

## Fixes applied
- Patched `dashboard/dashboard.html` directly as the source of truth.
- Regenerated `dashboard/dashboard.min.html` and `dashboard/dashboard.h` from the patched source.
- Kept `dashboard/dashboard.js` aligned with the same runtime logic.
- Restored built-in diagnostic sensors in `firmware/esp32-c3-multi-sensor.yaml`:
  - `debug.free`
  - `debug.loop_time`
  - `uptime` (`type: seconds`)
- Switched dashboard runtime hydration for `Free Heap` and `Uptime` to `GET /api/status`.
- Bumped version strings to `v7.5.0.1`.

## Validation to run on user side
1. `python3 scripts/render_sensor_config.py --write`
2. `bash ./scripts/minify-dashboard.sh`
3. `bash ./scripts/generate-header.sh dashboard/dashboard.min.html dashboard/dashboard.h`
4. `bash ./scripts/preflight.sh`
5. `esphome compile firmware/esp32-c3-multi-sensor.yaml`
6. Flash/update and verify:
   - `/api/manifest`
   - `/sensors.json`
   - `/api/status`
   - built-in ESP web page diagnostics
   - dashboard `Free Heap` / `Uptime`
