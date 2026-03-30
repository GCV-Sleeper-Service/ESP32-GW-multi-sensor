# Session Log — 2026-03-30 — v7.6.0.0 Post-Merge HTTPD POST Stabilization

## Scope

Apply a practical fix for POST-triggered HTTPD instability on aggregator builds, align board-profile `sdkconfig_options`, and document the fix in project docs.

## Changes Implemented

1. **Dashboard POST request-shape hardening**
   - Updated management/import POST calls in:
     - `dashboard/dashboard.js`
     - `dashboard/dashboard.html`
   - Added:
     - `Content-Type: application/json`
     - `body: '{}'`
   - Rationale: avoid zero-length POST request shape and make POST contract explicit.

2. **Firmware-side defensive route guard**
   - Updated `HistoryWebHandler::canHandle()` in `dashboard/sensor_history_multi.h`:
     - split `HTTP_OPTIONS` and `HTTP_POST` handling branches
     - reject zero-length POST route acceptance using `request->contentLength() == 0`
   - Rationale: prevent unsafe zero-length POST requests from entering custom POST handler paths.

3. **Board profile sdkconfig alignment**
   - `firmware/boards/esp32-s3-devkitc1-n16r8.yaml`
     - `CONFIG_LWIP_MAX_SOCKETS: "24"`
     - `CONFIG_HTTPD_STACK_SIZE: "16384"`
   - `firmware/boards/esp32-c3-supermini.yaml`
     - `CONFIG_LWIP_MAX_SOCKETS: "18"`
     - `CONFIG_HTTPD_STACK_SIZE: "8192"`
   - `firmware/boards/esp32-wroom-32d.yaml`
     - `CONFIG_LWIP_MAX_SOCKETS: "18"`
     - `CONFIG_HTTPD_STACK_SIZE: "8192"`

4. **Documentation updates**
   - `Docs/changelog.md`
     - added v7.6.0.0 post-merge stabilization entry (BUG-075/BUG-076)
   - `Docs/bugs-and-lessons-learned.md`
     - added BUG-075 and BUG-076 entries
     - added LESSON-OPS-097 and LESSON-OPS-098 entries
     - updated "Last updated" header

## Validation Notes

- This commit focuses on code+config+documentation changes.
- Device runtime validation is expected on hardware (S3 aggregator) using controlled POST-shape test matrix.

