---
applyTo: "firmware/core/**"
---
## Firmware Fragment Rules

These C++ header files are assembled into `dashboard/sensor_history_multi.h` by `scripts/assemble-sensor-history.sh`. Never edit the assembled output directly.

Key constraints:
- HTTP handlers performing NVS operations MUST use the deferred task pattern (xTaskCreate with 8192-byte stack)
- Never build a full CSV response in RAM: stream NVS-backed data with `httpd_resp_send_chunk()`, as the history endpoints do (BUG-082, resolved in v7.7.1.1; see `AGENTS.md`)
- Use `lwip_*()` prefixed socket functions, not `esp_http_client` (not available in ESPHome IDF builds)
- Guard aggregator-only code with `#ifdef AGGREGATOR_ENABLED`
- After editing any fragment, run `bash scripts/assemble-sensor-history.sh --check`
