# ESPHome 2026.4.1 Component Defaults Audit

_Date: 2026-05-08_
_ESPHome version: 2026.4.1 (ESP-IDF 5.5.4)_
_Auditor: Codex_

## Summary

Audited five target areas: ESP-IDF httpd via ESPHome web server, WiFi, BLE tracker, ESP32 preferences/NVS, and ESPHome OTA. One HIGH finding was identified: the patched web server still inherits ESP-IDF's seven-open-socket default, which exceeds this project's measured non-PSRAM safe limit. No new CRITICAL finding was found; the known 4 KB httpd stack default is already mitigated by the local `web_server_idf` override.

## Findings

### Web Server / ESP-IDF httpd

| Setting | Default Value | Source File:Line | Risk | Impact on This Project | Recommendation |
|---------|--------------|------------------|------|------------------------|----------------|
| `stack_size` | ESP-IDF: 4096; stock ESPHome: 4352; project override: 16384 | `esp_http_server.h:53-56`; `web_server_idf.cpp:126-127`; `firmware/local_components/web_server_idf/web_server_idf.cpp:125-126` | INFO | ALREADY MITIGATED. BUG-075/076 showed 4 KB crashes under non-trivial handlers; local component sets 16 KB. | Keep Rules 38-42 and `scripts/patch-esphome-httpd-stack.sh --check` mandatory after ESPHome upgrades. |
| `CONFIG_HTTPD_STACK_SIZE` | Dead config for ESPHome web server runtime | `esp_http_server.h:53-56`; `prompts/prompt-index-and-workflow.md:323` | INFO | ALREADY MITIGATED by Rule 41. Setting sdkconfig does not change the `HTTPD_DEFAULT_CONFIG()` runtime value used by ESPHome. | Keep documenting as dead config; do not use it for board profiles. |
| `max_open_sockets` | 7 | `esp_http_server.h:62` | HIGH | BUG-084 records C3/WROOM crashes under 8 concurrent HTTP connections; safe observed limit is 4. ESPHome enables LRU purge but does not lower this cap. | Track and validate a board-safe override before Phase 7 completes. Filed #224. |
| `backlog_conn` | 5 | `esp_http_server.h:65` | MEDIUM | Allows queued connection bursts behind the seven active sockets. This can still create pressure during browser refreshes or multiple dashboard clients. | Evaluate together with `max_open_sockets`; document measured values per board class. |
| `lru_purge_enable` | ESP-IDF default false; ESPHome sets true | `esp_http_server.h:66`; `web_server_idf.cpp:130-134`; `firmware/local_components/web_server_idf/web_server_idf.cpp:129-133` | LOW | LRU purging mitigates socket exhaustion symptoms, but it is not a concurrency cap. | Keep enabled; do not treat it as sufficient for BUG-084. |
| `max_uri_handlers` | 8 | `esp_http_server.h:63`; `web_server_idf.cpp:137-160` | INFO | ESPHome's IDF adapter registers catch-all GET, POST, and OPTIONS handlers; project endpoint count lives behind `AsyncWebServer` handlers, not separate IDF URI slots. | No action unless the local component starts registering individual IDF URI handlers. |
| `max_resp_headers` | 8 | `esp_http_server.h:64`; `web_server_base.h:99-102` | LOW | ESPHome adds one default CORS header; project responses are not near the limit. | Monitor if more default/security headers are added. |
| `recv_wait_timeout` / `send_wait_timeout` | 5 s / 5 s | `esp_http_server.h:67-68` | LOW | Reasonable for dashboard API traffic; long NVS work is governed by Rule 40 rather than socket timeout tuning. | No Phase 7 override recommended. |
| `max_req_hdr_len` / `max_uri_len` | 1024 / 512 | `esp_http_server.h:58-59`; `esp_http_server/Kconfig:4-17` | LOW | Dashboard URLs and Basic Auth headers are comfortably below these defaults. | No action unless URLs or auth payloads grow substantially. |

### WiFi Component

| Setting | Default Value | Source File:Line | Risk | Impact on This Project | Recommendation |
|---------|--------------|------------------|------|------------------------|----------------|
| `power_save_mode` on ESP32 | `LIGHT` (`WIFI_PS_MIN_MODEM`) | `wifi/__init__.py:380-388`; `wifi_component_esp_idf.cpp:271-285` | MEDIUM | Gateway boards serve HTTP, BLE, and OTA continuously. Modem sleep may add latency or jitter under dashboard load, though ESPHome can temporarily disable it for high-performance consumers. | Consider explicit board-profile policy after telemetry exists; do not change as part of this research step. |
| Connect retries | 2 attempts per scanned BSSID; 1 per hidden SSID/AP | `wifi_component.cpp:347-405` | LOW | Retry behavior is explicit and bounded. It should not surprise Phase 7, but poor RF can still cause reconnect churn. | Document as acceptable; correlate with future health-check WiFi metrics. |
| Cooldown after failed attempt | 500 ms; 30 s while AP/captive portal active | `wifi_component.cpp:362-369`; `wifi_component.cpp:754-772` | LOW | Normal reconnect cadence is aggressive but bounded. AP/captive portal mode correctly backs off to avoid disrupting provisioning clients. | No action. |
| Scan timeout | 31 s fallback | `wifi_component.cpp:371-384` | LOW | Timeout is a failure fallback, not routine scan frequency. Normal scans complete by callback. | No action. |
| Connection timeout | 46 s fallback | `wifi_component.cpp:376-384` | LOW | Long enough to avoid false failure on slow platforms; may delay failure recognition only when callbacks do not arrive. | No action. |
| Post-connect roaming | Enabled by default | `wifi/__init__.py:409-412`; `wifi_component.cpp:796-806` | LOW | Stationary gateways may scan for better APs when RSSI is poor. Could add transient RF work, but bounded by ESPHome's state machine. | Keep default unless field telemetry shows roaming churn. |
| `WIFI_INIT_CONFIG_DEFAULT()` buffer counts | Static RX 10, dynamic RX 32, dynamic TX 32 by ESP-IDF defaults | `esp_wifi.h:308-325`; `esp_wifi/Kconfig:26-46`; `esp_wifi/Kconfig:61-123` | MEDIUM | Defaults are conservative for non-PSRAM boards. ESPHome only raises buffers when high-performance networking is enabled. | Revisit if Phase 7 adds sustained upload/export traffic from non-PSRAM boards. |
| AMPDU BA windows | TX 6, RX 6 without PSRAM; RX 16 with PSRAM allocation | `esp_wifi/Kconfig:175-206` | LOW | Throughput/performance tuning rather than stability risk for current dashboard/API load. | No Phase 7 override recommended. |

### BLE Tracker

| Setting | Default Value | Source File:Line | Risk | Impact on This Project | Recommendation |
|---------|--------------|------------------|------|------------------------|----------------|
| Scan duration | 5 min | `esp32_ble_tracker/__init__.py:182-187`; `esp32_ble_tracker.cpp:279` | LOW | Long continuous scans are expected for BLE sensor gateways. OTA listener stops scanning during OTA start. | Keep default unless telemetry shows WiFi/httpd starvation. |
| Scan interval / window | 320 ms interval, 30 ms window | `esp32_ble_tracker/__init__.py:188-193`; `esp32_ble_tracker.cpp:262-267` | LOW | About 9.4% scan duty cycle. Reasonable for passive gateway use and unlikely to dominate httpd. | No action. |
| Active scanning | `true` | `esp32_ble_tracker/__init__.py:194`; `esp32_ble_tracker.cpp:262` | MEDIUM | Active scan sends scan requests and can increase BLE/WiFi coexistence pressure. Production gateways depend on BLE discovery, so this is a performance tradeoff rather than a defect. | Consider passive scan experiments only if health telemetry shows coexistence pressure. |
| Continuous scanning | `true` | `esp32_ble_tracker/__init__.py:195`; `esp32_ble_tracker.cpp:198-200` | LOW | Expected for BLE gateways. Scan restart state machine is explicit. | No action. |
| BTU task stack | 8192 | `esp32_ble_tracker/__init__.py:321-325` | LOW | Already raised to Arduino-compatible size by ESPHome. No project override required. | Document as acceptable. |
| Max BLE connections | 3 default; IDF max 9; config writes host/controller limits | `esp32_ble/__init__.py:252-259`; `esp32_ble/__init__.py:342-344`; `esp32_ble/__init__.py:523-532` | LOW | Current gateway use is scanner/listener oriented, not many GATT clients. Default is conservative. | No action unless adding multiple active BLE clients. |
| Advertisement parsing allocation | Parsed device stores vectors for service/manufacturer data | `esp32_ble_tracker.h:98-137` | MEDIUM | Many advertisements can create heap churn if automations parse every packet. Current project should monitor heap during BLE-heavy deployments. | Use Phase 7 health-check heap/min-heap telemetry to validate. |

### NVS / Preferences

| Setting | Default Value | Source File:Line | Risk | Impact on This Project | Recommendation |
|---------|--------------|------------------|------|------------------------|----------------|
| ESPHome preferences namespace | Single namespace `esphome` | `preferences.cpp:76-87` | LOW | Project history uses its own NVS paths; ESPHome preferences are isolated from the history partition design. | No action. |
| Pending preference writes | Coalesced in RAM until `sync()` | `preferences.cpp:23-37`; `preferences.cpp:101-150` | LOW | Avoids repeated writes for unchanged preferences. Not directly involved in history persistence. | No action. |
| Change detection before write | Reads current blob and skips unchanged data | `preferences.cpp:153-171` | LOW | Reduces unnecessary NVS writes for preferences. | No action. |
| Page size / entries | 4096 byte page; 32 byte entry; 126 entries/page | `nvs_page.cpp:18`; `nvs_constants.h:21-24`; `nvs_page.hpp:37-43` | INFO | Matches current project capacity math. Phase 7 per-device storage should continue budgeting by entries, not only bytes. | Keep entry-budget calculations in Phase 7 design. |
| Reserved free page | `available_entries = free_entries - 126` when possible | `nvs_pagemanager.cpp:240-246` | MEDIUM | Usable entry count is lower than raw partition entries by one reserved page. This matters for retention projections. | Include reserved-page subtraction in Phase 7 capacity calculations. |
| Namespace/key max length | 15 usable chars plus null | `nvs.h:60-62`; `nvs.h:139-140` | MEDIUM | Per-device keys must stay compact. Long sensor IDs cannot be used directly as NVS key names. | Continue hashed/short key scheme for Phase 7. |
| Namespace count | Stored as `mNamespaces.size()`; practical ceiling is entry/page capacity and 8-bit namespace index | `nvs_storage.cpp:1015-1018`; `nvs_constants.h:30-31` | LOW | Project does not need hundreds of namespaces; per-device data should avoid namespace-per-sensor sprawl. | Prefer compact keys in a small number of namespaces. |
| Encryption | Disabled unless `CONFIG_NVS_ENCRYPTION` enabled by secure flash/HMAC config | `nvs_flash/Kconfig:3-11`; `nvs_api.cpp:136-160` | INFO | Current gateway history is not encrypted by default. This is not new, but it should be explicit if sensitive data is later stored. | No Phase 7 override unless threat model changes. |

### OTA Component

| Setting | Default Value | Source File:Line | Risk | Impact on This Project | Recommendation |
|---------|--------------|------------------|------|------------------------|----------------|
| Listen backlog | 1 OTA client | `ota_esphome.cpp:63` | LOW | Good for constrained boards; OTA is intentionally single-client. | No action. |
| Handshake timeout | 20 s | `ota_esphome.cpp:28`; `ota_esphome.cpp:130-135` | LOW | Reasonable; port scans should time out without entering update state. | No action. |
| Data transfer timeout | 90 s per read/write-all operation | `ota_esphome.cpp:29`; `ota_esphome.cpp:418-425`; `ota_esphome.cpp:448-455` | LOW | Allows slow OTA links. During OTA, BLE scan is stopped by OTA state listener. | No action. |
| OTA receive buffer | 1024 bytes | `ota_esphome.cpp:26-27`; `ota_esphome.cpp:271-333` | LOW | Small stack buffer; safe for non-PSRAM boards. | No action. |
| OTA block acknowledgment | 8192 bytes | `ota_esphome.cpp:26`; `ota_esphome.cpp:354-358` | INFO | Protocol-level chunk acknowledgment; not a RAM allocation. | No action. |
| OTA data processing task | Runs in main component loop; data phase is blocking | `ota_esphome.h:17-28`; `ota_esphome.cpp:234-239` | MEDIUM | OTA competes with normal loop work during update, but this is expected maintenance behavior. BLE tracker stops scanning at OTA start. | Avoid simultaneous dashboard stress during OTA; keep device-testing OTA procedure serial. |
| Flash preparation WDT timeout | Temporarily 15 s around `esp_ota_begin()` when configured WDT is lower | `ota_backend_esp_idf.cpp:31-52` | LOW | Explicitly mitigates long flash-lock operation. | No action. |

## Risk Classification

- **CRITICAL** — Default will cause crashes, data loss, or security holes in production. Requires immediate action.
- **HIGH** — Default limits functionality or causes degraded performance under normal load. Action recommended before Phase 7 completes.
- **MEDIUM** — Default is suboptimal but unlikely to cause failures. Address opportunistically.
- **LOW** — Default is fine for this project's use case. Document and move on.
- **INFO** — Interesting but no action needed.

## Critical Findings Requiring GitHub Issues

No CRITICAL findings were found.

HIGH:

- #224 — Constrain ESP-IDF httpd open socket capacity for non-PSRAM boards
  - Finding: ESP-IDF defaults to `max_open_sockets = 7` and `backlog_conn = 5`; ESPHome enables LRU purge but does not lower the active socket cap.
  - Impact: BUG-084 records crashes on non-PSRAM boards under 8 concurrent HTTP connections, with safe observed limit 4.
  - Recommendation: Evaluate a board-safe local `web_server_idf` override during Phase 7.

## Recommendations for Phase 7

1. Treat #224 as the only required follow-up from this audit before Phase 7 completes.
2. Include ESP-IDF's reserved NVS page behavior in per-device retention calculations.
3. Keep NVS key names short and hashed; do not use raw sensor/device IDs as NVS keys.
4. Use Phase 7 health-check telemetry to validate WiFi power-save impact, BLE advertisement heap churn, and socket pressure before adding more overrides.
5. Preserve the existing httpd stack mitigation and re-check it after every ESPHome upgrade.
