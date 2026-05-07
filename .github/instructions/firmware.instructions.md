---
applyTo: "firmware/core/**"
---
## Firmware Fragment Rules

These C++ header files are assembled into `dashboard/sensor_history_multi.h` by `scripts/assemble-sensor-history.sh`. Never edit the assembled output directly.

Key constraints:
- HTTP handlers performing NVS operations MUST use the deferred task pattern (xTaskCreate with 8192-byte stack)
- All string building from NVS loops must enforce explicit size limits (csv.reserve does NOT truncate)
- Use `lwip_*()` prefixed socket functions, not `esp_http_client` (not available in ESPHome IDF builds)
- Guard aggregator-only code with `#ifdef AGGREGATOR_ENABLED`
- After editing any fragment, run `bash scripts/assemble-sensor-history.sh --check`
