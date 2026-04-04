# Bugs Fixed & Lessons Learned

_Last updated: 2026-04-04 — v7.6.0.4 fixup (PR #128 follow-up — R1/R2/R3 Copilot review items)._

This file tracks significant bugs, root causes, fixes, and operational lessons.
It is also the place where project guardrails are recorded so they are not re-learned in later sessions.

Both sections are in **reverse chronological order** — most recent entry first.

## Bug Fixes

### BUG-081 — Auth dialog resolves but no status update or network request fires (v7.6.0.4 fixup)

**Symptom:** After clicking Test in the satellite configuration panel and entering valid
management credentials in the auth dialog, the dialog dismissed correctly but nothing
further happened — no "Testing..." message, no success/failure result, no network
request visible in DevTools.

**Root cause:** `_handleTestSatellite(urlInput, statusEl)` used `statusEl` (a DOM element
reference captured at click time) inside `.then()` callbacks of
`requestManagementCredentials()`. If `pollAggregatorLive()` fired during the async wait
(auth modal open or network fetch in progress), `renderSettingsPanel()` replaced the
settings panel's `innerHTML`, detaching the original element. Assignments to a detached
element succeed in JavaScript but have zero visible effect on the rendered page.

**Fix (PR #128):** Renamed the URL input read to `capturedUrl` (a plain string), and
renamed `statusEl` to `capturedStatusEl` (a snapshot reference) to make the synchronous
capture intent explicit.

**Follow-up fix (PR #128 Copilot R1):** Replaced `capturedStatusEl` with fresh
`document.getElementById('sat-add-status')` re-queries at every write point inside the
async callbacks. If `pollAggregatorLive()` has rebuilt the panel in the meantime, the
new element in the live document is used — ensuring the status message is always
visible regardless of how many poll cycles have fired.

**Files changed:** `dashboard/dashboard.js`, `dashboard/dashboard.html`, `dashboard/dashboard.h`

Related: BUG-080, LESSON-OPS-043, LESSON-OPS-111

---

### BUG-080 — Input fields cleared when clicking Test or Add in satellite configuration panel (v7.6.0.4 fixup)

**Symptom:** Typing a URL and friendly name into the satellite configuration inputs, then
clicking Test or Add, wiped both fields before the handler ran. The only workaround was to
click a neutral area of the page first to "commit" the focus, then click the button.

**Root cause:** The regression was caused by the satellite Settings panel being rebuilt
while a button-initiated workflow was still in progress, not by a fallthrough in the global
`document.addEventListener('click', ...)` router in `bindEvents()`. The panel already had an
existing re-render path via the aggregator live-poll watcher (`pollAggregatorLive()` →
`renderSettingsPanel()`), and the Settings tab's own click handling was therefore operating
against DOM that could be replaced underneath it. When `renderSettingsPanel()` rebuilt the
panel with fresh `innerHTML`, the active URL/name input elements were destroyed and
recreated, so the in-progress interaction observed cleared fields before the async
credential prompt could resolve.

**Fix (PR #128):** Added `e.stopPropagation()` as the very first statement in the `click`
event listeners for `sat-test-btn`, `sat-add-btn`, and each `.settings-btn-remove` button
inside `renderSettingsPanel()`. This prevents the click event from reaching the global
`bindEvents()` router, which addresses the immediate click-interaction case.

**Follow-up fix (PR #128 Copilot R2):** Added guards to the `pollAggregatorLive()` →
`renderSettingsPanel()` call path: the settings panel is now skipped when
`_satTestInFlight === true` (a satellite test is actively in progress) or when either
`sat-url-input` / `sat-name-input` has keyboard focus (the user is actively typing). This
addresses the 15-second periodic re-render case that `stopPropagation()` alone cannot
prevent.

**Files changed:** `dashboard/dashboard.js`, `dashboard/dashboard.html`, `dashboard/dashboard.h`

Related: BUG-081, LESSON-OPS-043, LESSON-OPS-111

---

### BUG-079 — DELETE requests rejected by httpd layer with 405 before reaching handler (v7.6.0.2 fixup)

**Symptom:** Every `curl -X DELETE` to `/api/aggregator/satellite/{id}` returned HTTP 405
with plain-text `"Specified method is invalid for this resource"`. All device test DELETE
cases (T1-T4, T10) failed. GET and POST to the same URL correctly returned JSON 405 from
the handler.

**Root cause:** `firmware/local_components/web_server_idf/web_server_idf.cpp`,
function `AsyncWebServer::begin()`. The local component (introduced in PR #105 as the
BUG-075/076 stack-size fix) copied stock ESPHome's `begin()` which registers URI handlers
only for `HTTP_GET`, `HTTP_POST`, and `HTTP_OPTIONS`. No `HTTP_DELETE` handler was ever
registered. When a DELETE request arrives, ESP-IDF httpd finds no registered handler for
that method and immediately returns its built-in plain-text 405 — before calling any
`canHandle()` or `handleRequest()` on our handler objects. The `canHandle()` and
`handleRequest()` routing in `dashboard/sensor_history_multi.h` was correct; they were
simply never reached for DELETE requests.

**Diagnostic signature:** A plain-text 405 (not JSON) means the request never reached
our handler at all. Our handler's `send_json_error_()` always returns `application/json`.
GET and POST returning JSON 405 (method-not-allowed from our handler) confirmed the
transport layer was selectively blocking only DELETE.

**Fix:** Added `HTTP_DELETE` URI handler registration in `AsyncWebServer::begin()` in
`firmware/local_components/web_server_idf/web_server_idf.cpp`, after the existing OPTIONS
handler. DELETE requests have no body, so they use the same `request_handler` path as GET.
Also updated `scripts/patch-esphome-httpd-stack.sh` to apply this patch automatically
when re-running after an ESPHome upgrade.

**Introduced by:** PR #105 (BUG-075/076 fix) — the local component was created without
registering a DELETE handler. Present throughout v7.6.0.0 and v7.6.0.1; first exposed by
the DELETE satellite endpoint added in PR #110 (v7.6.0.2).

**Fixed by:** PR #114. See LESSON-OPS-108, LESSON-OPS-109.

---

### BUG-078 — Local component `init_response_()` maps all non-200/404/409 status codes to HTTP 500 (v7.6.0.1 fixup)

**Symptom:** Device testing of `POST /api/aggregator/add-satellite` error paths
showed correct JSON body (`"status":400`) but curl reported HTTP 500 for every
error response. Only 200, 404, and 409 responses had correct HTTP status codes.

**Root cause:** `firmware/local_components/web_server_idf/web_server_idf.cpp`,
function `AsyncWebServerRequest::init_response_()`. The `switch(code)` block
created during the BUG-075/076 local component override only had cases for
200, 404, and 409. The `default` branch mapped to `HTTPD_500`. This is actually
a pre-existing bug in stock ESPHome's `web_server_idf.cpp` — the local override
inherited it, and we are the first to use 400/401/405 from handlers.

**Impact:** Every `send_json_error_(request, 400, ...)` call across the entire
codebase returned HTTP 500 to clients. Authentication failures (401), method
rejections (405), rate limiting (429), and stub endpoints (501) were all affected.
The JSON body was always correct — only the HTTP status line was wrong.

**Fix:** Expanded the switch to cover 200, 204, 301, 302, 400, 401, 403, 404,
405, 408, 409, 429, 500, 501, 503, with a `snprintf` fallback for any
unrecognized code. Also updated `scripts/patch-esphome-httpd-stack.sh` awareness:
after re-running the script on ESPHome upgrade, verify the status code switch
is still intact (the script copies upstream and re-applies only the stack patch).

**Introduced by:** PR #105 (BUG-075/076 fix). Present in stock ESPHome.
Codified as Critical Rule 43, LESSON-OPS-103.

### BUG-077 — `handle_add_satellite_()` uses Arduino `String` type — ESP-IDF build failure (v7.6.0.1)

**Symptom:** After merging PR #108 and pulling locally, `esphome compile` fails
at `sensor_history_multi.h` line 3622 (line number varies by local state):
`error: 'String' was not declared in this scope`.

**Root cause:** The coding agent generated `String url_param = request->getParam("url")->value();`
using the Arduino `String` type. ESPHome's IDF build target does not have Arduino
compatibility — only `std::string` is available. The agent's CI sandbox runs
Playwright/preflight tests but does not perform actual ESP-IDF compilation, so
the Arduino-ism passed CI.

**Secondary issue:** A first manual fix changed `String` to bare `string` (no
namespace qualifier), which also fails because the codebase has no
`using namespace std;` directive.

**Fix:** `std::string url_param = request->getParam("url")->value();`

**Introduced by:** PR #108 (v7.6.0.1).
Codified as Critical Rule 44, LESSON-OPS-104.

### BUG-076 — POST requests with any body crash S3 aggregator (v7.6.0.0 fixup)

**Symptom:** Same crash as BUG-075 (`StoreProhibited` / `vPortYieldFromInt`).
All POST requests with a body crash the board — `application/x-www-form-urlencoded`,
`application/json`, any content type, any non-zero body size.

**Root cause:** BUG-075 (httpd task stack overflow). The body presence is not
the cause — it is what triggers our handler code, which then overflows the stack.

**Secondary issue:** `dashboard.js` and `dashboard.html` sent
`Content-Type: application/json` with `body: '{}'`. ESPHome's
`request_post_handler` does not consume JSON POST bodies — it falls through to
the GET handler path without reading the socket, corrupting socket state for
subsequent responses. This is a secondary crash vector layered on top of BUG-075.

**Fix:** (1) BUG-075 deferred task fix resolves the primary crash.
(2) Dashboard POST calls changed to `Content-Type: application/x-www-form-urlencoded`
with `body: 'a=1'` to use the only body type ESPHome actually consumes.

**Prevention:** See LESSON-OPS-099, LESSON-OPS-100, LESSON-OPS-101.
Critical Rules 38–41.

### BUG-075 — httpd task stack overflow on S3 aggregator — management POST handlers (v7.6.0.0 fixup)

**Symptom:** Every POST request with a body to any management endpoint
(`/api/system/reset-satellites`, `/api/delete-data`) crashes the S3 aggregator
with `StoreProhibited` in `vPortYieldFromInt`, `EXCVADDR: 0xfffffec0`, fully
corrupted backtrace. 100% reproducible, independent of satellite polling state.

**Root cause:** ESP-IDF's `HTTPD_DEFAULT_CONFIG()` macro hardcodes
`.stack_size = 4096` as a literal integer. ESPHome's `web_server_idf.cpp`
(confirmed at build path `src/esphome/components/web_server_idf/web_server_idf.cpp`,
lines 123–133) calls `httpd_start()` with `HTTPD_DEFAULT_CONFIG()` and never
overrides `stack_size`. The httpd task therefore runs at 4 KB regardless of any
`CONFIG_HTTPD_STACK_SIZE` sdkconfig setting — that setting is dead code.
`handle_reset_satellites_()` performed two full NVS open/write/commit cycles,
AGG_LOCK/UNLOCK, a satellite loop with string copies, and save_satellites_to_nvs_() —
far exceeding 4 KB. `handle_delete_data_()` called `nvs_flash_erase_partition()` —
same overflow.

**Non-fixes attempted:**
- `CONFIG_HTTPD_STACK_SIZE: "24576"` in board profiles → no effect
- `CONFIG_HTTPD_STACK_SIZE: "65536"` → same crash
- Stopping satellite polling → same crash (race condition ruled out)

**Fix (primary):** Local ESPHome component override. The `web_server_idf`
component is copied into `firmware/local_components/web_server_idf/` and patched
to set `config.stack_size = 16384` after `HTTPD_DEFAULT_CONFIG()`. Board profiles
reference this via `external_components`. Managed by
`scripts/patch-esphome-httpd-stack.sh`; re-run after every ESPHome upgrade.

**Fix (secondary):** Deferred task pattern. `handle_reset_satellites_()` and
`handle_delete_data_()` authenticate + send HTTP response immediately + spawn a
dedicated `xTaskCreate` task (8192-byte stack) for NVS work. Even with the
16 KB httpd stack, NVS operations should not run on the httpd task. Pattern
mirrors the existing `schedule_reboot_()` implementation.

**Note:** Testing proved that the deferred task pattern alone is NOT sufficient.
Even the lightest handler (unauthenticated request → `send_json_error_(401)`)
overflows the 4 KB stack. The component override is mandatory.

**Prevention:** See LESSON-OPS-100, LESSON-OPS-101, and LESSON-OPS-102.

### BUG-074 — Aggregator manifest buffer truncation produces broken JSON (v7.5.7.0)

**Symptom:** `/api/aggregator/gateways` returns invalid JSON when a satellite has a manifest exceeding 4095 bytes. The dashboard fails to render the gateway's device list.

**Root cause:** `SatelliteCache.manifest_json` was a 4096-byte buffer. `fetch_to_buffer()` silently truncates responses exceeding `buf_size - 1`. The truncated (invalid) JSON was embedded verbatim in the `/api/aggregator/gateways` response, breaking the entire JSON document.

**Detection:** The truncation was invisible — no log message, no error return. The only symptom was dashboard malfunction when a satellite with 5+ sensors was polled.

**Fix:** (1) Increased `manifest_json` and `s_fetch_tmp` to 8192 bytes via `AGG_MANIFEST_BUF_SIZE` constant. (2) Added truncation detection guard in `handle_aggregator_gateways_()`: if `manifest_len >= AGG_MANIFEST_BUF_SIZE - 1`, emit `"manifest":null` and log a warning instead of embedding the truncated JSON.

**Prevention:** LESSON-OPS-085: When embedding fetched content into a composed JSON response, always validate that the content was not truncated before embedding. Buffer-size assumptions are especially dangerous for variable-length content like manifests that grow as sensors are added.

## BUG-073 — `buildNetworkCard()` XSS via unescaped `target` string (fixed v7.5.6.4)

### Symptom

The `source.target` field from the manifest (e.g. `"8.8.8.8"`) was inserted into
the network card HTML without HTML escaping. A malicious manifest could inject
HTML/script tags via this field.

### Root Cause

`buildNetworkCard()` used `target` directly in the innerHTML string without calling
`escHtml()`. The `description` in `buildSystemCard()` already used `escHtml()`
(correct), but `target` in the network card did not.

### Fix (v7.5.6.4)

Changed `'>' + target + '</div>'` to `'>' + escHtml(target) + '</div>'`.
Mirrored in both `dashboard.js` and `dashboard.html`.

## BUG-072 — `updateNetworkCards()` truthy check on `last_seen` (fixed v7.5.6.4)

### Symptom

When `last_seen` is `0` (epoch 0, valid timestamp), the last-seen display in the
network card would silently remain as `last: —` instead of showing the timestamp.

### Root Cause

`updateNetworkCards()` used a truthy check: `if (seenEl && devData.last_seen)`.
A `last_seen` value of `0` is falsy in JavaScript, so the display was not updated.

### Fix (v7.5.6.4)

Changed to strict null check: `if (seenEl && devData.last_seen != null)`.
Mirrored in both `dashboard.js` and `dashboard.html`.

### BUG-071 — Aggregator `aggregator-live.json` used JSON string for `live` field (2026-03-25)

**Severity:** Test authoring error (caught in development)
**Introduced in:** v7.5.5.4 initial fixture draft (following prompt example literally)
**Fixed in:** v7.5.5.4

**Symptoms:** `_populateGatewayDeviceLive()` returned early without populating live values; environmental and network cards stayed in "waiting" state.

**Root cause:** The prompt example showed `"live": "{\"timestamp\":...,\"devices\":{...}}"` (JSON string). The actual code checks `gwLive.live.devices` directly — it does NOT parse a JSON string. A JSON string has `.devices === undefined`, causing the early return guard to trigger.

**Fix:** Changed `aggregator-live.json` fixture to use `"live": { "timestamp": ..., "devices": {...} }` (JSON object, not string).

### BUG-070 — Aggregator fixture `manifest.sensors` format mismatch (2026-03-25)

**Severity:** Test authoring error (caught in development)
**Introduced in:** v7.5.5.4 initial fixture draft
**Fixed in:** v7.5.5.4

**Symptoms:** `renderGatewayDevices()` showed "No device data available" despite fixture containing gateway manifest data.

**Root cause:** The `aggregator-gateways.json` fixture used `"devices": {}` (object format) for the nested gateway manifest, but `renderGatewayDevices()` checks `manifest.sensors` (array). The satellite manifest v2 format uses a `sensors` array, not a `devices` object.

**Fix:** Changed `aggregator-gateways.json` fixture to use `"sensors": [...]` array format matching the actual v2 manifest schema.

### BUG-069 — Environmental chart sections visible with no environmental sensors (2026-03-25)

**Severity:** UX confusion
**Introduced in:** Dashboard design (always present)
**Fixed in:** v7.5.5.3 hotfix-2

**Symptoms:** On the S3 aggregator with only WAN ping as a local sensor, the Temperature Real Time, Humidity Real Time, Temperature 15M Avg, and Humidity 15M Avg chart sections all displayed with "waiting for sensor data..." forever. These charts only make sense when environmental sensors (ThermoPro) are configured locally.

**Root cause:** The chart sections are hardcoded in `dashboard.html` and always visible. `initCharts()` creates the chart objects unconditionally. No check exists for whether any environmental sensors are present.

**Fix:** After `initCharts()` in the boot path, check `SENSORS.some(s => s.category === 'environmental')`. If false, hide `#hdr-realtime`, `#body-realtime`, `#divider-charts`, `#hdr-averages`, `#body-averages`. Added `id` attributes to these HTML sections to enable targeting.

### BUG-068 — Manifest `gateway.hardware` hardcoded to "ESP32-C3" regardless of board (2026-03-25)

**Severity:** Functional — breaks board-aware About card (BUG-067 fix depends on this)
**Introduced in:** `sensor_manifest_lib.py` `manifest_v2()` defaults
**Fixed in:** v7.5.5.3 hotfix-2

**Symptoms:** `curl /api/manifest` on the S3 aggregator returned `"hardware": "ESP32-C3"`. The `updateBoardInfo()` function (BUG-067 fix) checks this field to hide C3-specific content. With the wrong hardware string, C3 About card title, GPIO pinout, and description were still visible on the S3.

**Root cause:** `manifest_v2()` in `sensor_manifest_lib.py` has a hardcoded default `gateway_meta` with `"hardware": "ESP32-C3"`. Neither `generate_gateway_manifest_h()` nor the fixture generation in `render_sensor_config.py` passed a board-aware `gateway_meta`. The board profile's `chip_variant` field (e.g., `"esp32s3"`) was never mapped to the manifest.

**Fix:** `render_sensor_config.py` now builds `gateway_meta` from the board profile (`chip_variant` → human-readable hardware string via lookup table), gateway config (`friendly_name`, `esphome_name`), and aggregator config (`role`). This `gateway_meta` is passed to both `manifest_v2()` and `generate_gateway_manifest_h()`.

**Prevention:** When adding a new generated field that varies by deployment, verify it flows from the config source (board profile, gateway.json) through the generator to the output artifact. Hardcoded defaults should only apply when no config is present.

### BUG-067 — C3-specific content displayed on non-C3 boards (2026-03-25)

**Severity:** Cosmetic / design principle violation
**Introduced in:** v7.5.5.3 (incomplete `updateBoardInfo()`)
**Fixed in:** v7.5.5.3 hotfix

**Symptoms:** On the S3 aggregator, the About card showed "ESP32-C3 SuperMini Gateway" as the title, displayed the C3 board SVG photo, the C3 GPIO pinout table, and the ThermoPro-specific description paragraph. All of this content is irrelevant to an ESP32-S3 device.

**Root cause:** `updateBoardInfo()` only hid the C3 SVG pinout image (`#pinoutDiagram`). The title text, GPIO pinout card, and description paragraph had no `id` attributes and were not conditionally hidden.

**Fix:** Added `id` attributes (`gpioCard`, `aboutCardTitle`, `c3DescriptionBlock`) to the hardcoded C3 content in `dashboard.html`. Extended `updateBoardInfo()` to hide the GPIO card and description, and replace the title with the board's actual name from the manifest.

**Prevention:** LESSON-OPS-074. Principle 4: Board content correctness — the dashboard must never show information from a different board.

### BUG-066 — Remote satellite cards show "calculating..." for history min/max (2026-03-25)

**Severity:** Cosmetic / confusing UX
**Introduced in:** v7.5.5.3
**Fixed in:** v7.5.5.3 hotfix

**Symptoms:** When viewing a per-gateway satellite tab on the aggregator dashboard, environmental sensor cards showed "temp: calculating... / hum: calculating..." in the min/max sections, forever.

**Root cause:** The environmental card renderer includes min/max placeholders that are populated by `loadHistory()`, which fetches from local endpoints only. No proxy history fetch exists for remote satellite data. The placeholders were never updated.

**Fix:** After rendering remote satellite cards in `renderGatewayDevices()`, replace all `.minmax-line .waiting` elements with "—" and hide the range toggle buttons. Proxy history fetch is a planned future feature.

### BUG-065 — Gateway cards rendered inside SENSORS section (2026-03-25)

**Severity:** Layout / architecture violation
**Introduced in:** v7.5.5.3
**Fixed in:** v7.5.5.3 hotfix

**Symptoms:** On the aggregator, gateway selector tabs and satellite device cards appeared inside the "SENSORS" collapsible section, mixed with local sensor cards. The SENSORS heading was visible above gateway content. Per the design principles, the Gateways section should be separate from and above the local Sensors section.

**Root cause:** `renderGatewaySelector()` inserted the tab bar before `#sensorGrid` using `insertAdjacentHTML('beforebegin')`. All aggregator render functions (`renderAllGatewaysSummary`, `renderGatewayDevices`, `renderSettingsPanel`) wrote to `sensorGrid.innerHTML`, overwriting local sensor content.

**Fix:** Added a new Gateways collapsible section (`#hdr-gateways` / `#body-gateways`) above the SENSORS section in `dashboard.html`, hidden by default. Contains `#gwSelectorContainer` for the tab bar and `#gwGrid` for gateway content. All aggregator render functions now target the new elements. `initAggregatorDashboard()` unhides the section. SENSORS section is reserved for local sensors only.

### BUG-064 — Aggregator boot path skips satellite pipeline entirely (2026-03-25)

**Severity:** Critical — all local functionality broken on aggregator
**Introduced in:** v7.5.5.3
**Fixed in:** v7.5.5.3 hotfix

**Symptoms:** Aggregator dashboard showed: (1) red "connecting" dot in upper right, (2) "loading..." on History Storage, (3) "waiting for telemetry..." on Telemetry chart, (4) no local sensor cards (WAN ping not rendered), (5) Real-Time Charts stuck on "waiting for sensor data..."

**Root cause:** `App.Boot.start()` had a forked if/else structure. The aggregator path only called `loadManifestV2()` → `updateBoardInfo()` → `initAggregatorDashboard()`. It skipped ALL satellite functions: no `buildSensorCards()`, no `initCharts()`, no `connectSSE()` / `startPolling()`, no `loadStorageStats()`, no `loadStatusSnapshot()`, no `loadHistory()`, no `pollV2Live()`. The code comment explicitly said "Local device cards are NOT rendered here."

This directly violated **Principle 1** from the design document: "An aggregator is a satellite with aggregation enabled. Every satellite capability is available to an aggregator. The `AGGREGATOR_ENABLED` flag adds aggregator capabilities; it never subtracts satellite capabilities."

**Fix:** Unified boot path — removed the if/else fork. Both satellite and aggregator run the identical pipeline (manifest → sensor load → cards → charts → SSE/polling → status → storage stats → history). At the end, if `isAggregator` is true, `initAggregatorDashboard()` overlays the Gateways section.

**Prevention:** LESSON-OPS-074.

### BUG-063 — Proxy endpoint served truncated history as HTTP 200 (2026-03-24)

**Severity:** Data corruption (silent truncation)
**Introduced in:** v7.5.5.2 initial commit
**Fixed in:** v7.5.5.2 review fix

**Symptoms:** When a satellite's history response exceeded 32KB (the
`s_proxy_tmp` buffer size), `fetch_to_buffer()` filled the buffer and
stopped reading. The proxy returned the truncated data as HTTP 200,
causing dashboard charts to display incomplete datasets.

**Root cause:** No truncation detection after `fetch_to_buffer()`. The
function silently stops reading at the buffer limit.

**Fix:** Check `s_proxy_len >= sizeof(s_proxy_tmp) - 1` after fetch.
If true, return 502 with `{"error":"upstream_response_too_large","max_bytes":32768}`.

**Prevention:** Any proxy/relay endpoint that uses a fixed-size buffer
must check for truncation before serving the response.

### BUG-062 — `/api/status` reports PSRAM as `free_heap` on S3, misleading monitoring (2026-03-23)

**Severity:** Misleading diagnostics (not a crash)
**Introduced in:** v7.5.5.1 (first S3 deployment)
**Fixed in:** Pending (documented, fix planned for pre-v7.5.5.2 infrastructure commit)

**Symptoms:** `curl /api/status` on the S3 aggregator reports `free_heap: 8847360` (8.4 MB). This is the PSRAM-inclusive value. The ESPHome debug sensor shows ~32 KB (internal SRAM only). Monitoring scripts or dashboards that compare heap values across C3 and S3 get wildly different numbers that aren't comparable.

**Root cause:** `esp_get_free_heap_size()` returns total free heap including PSRAM on boards that have it. On the C3 (no PSRAM), this is internal SRAM only (~70 KB). On the S3 (8 MB PSRAM), this includes PSRAM (~8.4 MB). The values are not comparable across board types.

**Fix (planned):** Report both values in `/api/status`:
```json
{
  "free_heap": 32768,
  "free_heap_internal": 32768,
  "free_heap_total": 8847360
}
```
`free_heap` stays as internal-only for backward compatibility. `free_heap_total` is additive. Use `esp_get_free_internal_heap_size()` for the internal value.

**Prevention:** LESSON-OPS-072.

### BUG-061 — S3 partition table placed ota_0 at wrong offset, bricking the board (2026-03-23)

**Severity:** Board-bricking (requires serial recovery)
**Introduced in:** Multi-board infrastructure (PR #66)
**Fixed in:** a024cac (corrected partition table committed)

**Symptoms:** S3 board entered boot loop after flashing. PlatformIO wrote the firmware to 0x10000 (its default app offset), but the partition table had ota_0 at 0x20000 (after oversized NVS). The bootloader looked for the app at 0x20000, found nothing, and reset.

**Root cause:** The S3 partition table used a larger NVS (0x5000 = 20KB), which pushed phy_init to 0x10000 and ota_0 to 0x20000. PlatformIO ignores the partition table's ota_0 offset when writing — it always flashes to 0x10000.

**Fix:** Corrected the S3 partition table to use NVS at 0x4000 (16KB, matching C3 and WROOM), placing ota_0 at 0x10000. Added documentation comments to the partition CSV explaining the 0x10000 requirement.

**Prevention:** LESSON-OPS-070. Preflight must validate ota_0 offset in all partition CSVs (check not yet implemented — planned for pre-v7.5.5.2 infrastructure commit).

### BUG-060 — PyYAML `import yaml` at module level breaks satellite workflow without pip install (2026-03-23)

**Severity:** Build-breaking (preflight crash)
**Introduced in:** Multi-board infrastructure (PR #66)
**Fixed in:** eeb1a13 (lazy import inside `load_board_profile()`)

**Symptoms:** `bash scripts/preflight.sh` crashes with `ModuleNotFoundError: No module named 'yaml'` even on the C3 satellite path that never uses board profiles.

**Root cause:** `import yaml` at the top level of `sensor_manifest_lib.py`. The satellite workflow never calls `load_board_profile()` but the import fails before any function is called. PyYAML is available in the ESPHome environment but not guaranteed on all systems.

**Fix:** Moved `import yaml` inside `load_board_profile()` as a lazy import. The module only loads when board profiles are actually needed.

**Prevention:** LESSON-OPS-071.

### BUG-059 — Validator accepts `https://` satellite URLs that firmware cannot fetch (2026-03-23)

**Severity:** Config-time silent failure → runtime permanent unreachable
**Introduced in:** v7.5.5.0 (aggregator config validator)
**Fixed in:** v7.5.5.1 post-merge patch

**Symptoms:** Aggregator config with `"base_url": "https://192.168.x.x"` passes `validate_aggregator_config()` but the satellite is permanently marked unreachable at runtime because `fetch_to_buffer()` only supports `http://`.

**Root cause:** The Python validator accepted both `http://` and `https://` prefixes, but the C++ HTTP client (`fetch_to_buffer()`) uses raw lwIP sockets without TLS — it rejects any URL not starting with `http://`.

**Fix:** Reject `https://` URLs in the validator with a clear error message explaining that HTTPS satellite polling is not currently supported.

**Prevention:** Config validators must only accept URL schemes that the firmware can actually handle. When adding TLS support in the future, update both the validator AND the firmware simultaneously.

### BUG-058 — Aggregator backoff never activates for satellites that were never reachable (2026-03-23)

**Severity:** Performance degradation (C3 single-core stall)
**Introduced in:** v7.5.5.1 (aggregator polling task)
**Fixed in:** v7.5.5.1 post-merge patch

**Symptoms:** When an aggregator boots with an offline satellite, the polling task retries all three endpoints (live, status, manifest) every 5 seconds instead of backing off to 300 seconds. Each failed `fetch_to_buffer()` blocks for the 5-second socket timeout, causing 15 seconds of blocking per loop on the single-core C3.

**Root cause:** The "due" check uses `(sat.last_live_fetch == 0)` to detect "never fetched" and force an immediate attempt. But on failure, `last_live_fetch` is never updated from `0`, so the check is always true on the next iteration. The `effective_interval` of 300 seconds is computed but never consulted because the `== 0` clause short-circuits it.

**Fix:** When a satellite is declared unreachable (3+ consecutive failures), seed any still-zero `last_*_fetch` timestamps to `now` so the 300s backoff interval starts counting. The seeding is deliberately NOT applied on failures 1-2, which allows the normal retry frequency to handle transient boot-order races where the satellite comes up seconds after the aggregator. Additionally, the interval tracking was switched from wall-clock (`::time(nullptr)`) to monotonic uptime (`esp_timer_get_time() / 1000000ULL`) because wall-clock returns 0 before SNTP synchronization, which would make the seeding a no-op and leave the backoff broken during the pre-SNTP window.

**Prevention:** LESSON-OPS-069.

### BUG-057 — lwIP BSD socket aliases collide with `esphome::socket` namespace (2026-03-22)

**Date:** 2026-03-22
**Version observed:** v7.5.5.1
**Status:** FIXED (v7.5.5.1, same PR)

**Symptoms:** CI compilation fails with `error: reference to 'socket' is ambiguous`. The compiler cannot distinguish between lwIP's `int socket(int, int, int)` function and ESPHome's `namespace esphome::socket`.

**Root cause:** The `fetch_to_buffer()` function used BSD-compatible socket function names (`socket()`, `connect()`, `send()`, `recv()`, `close()`, `setsockopt()`). These are inline convenience aliases defined in `lwip/sockets.h` that wrap the real lwIP functions. ESPHome defines a C++ namespace `esphome::socket` (in `esphome/components/socket/headers.h`) which creates a name collision.

**Fix:** Replace all BSD socket aliases with their `lwip_*` prefixed equivalents (`lwip_socket()`, `lwip_connect()`, `lwip_send()`, `lwip_recv()`, `lwip_close()`, `lwip_setsockopt()`). These are the actual lwIP function names with no namespace collision.

**Prevention:** LESSON-OPS-068.

### BUG-056 — WAN Latency ping data appears on Temperature/Humidity charts (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.4
**Status:** FIXED (v7.5.4.5)

**Symptom:** The WAN Latency device appeared as a flat line on both the real-time and
15-minute average Temperature and Humidity charts. Ping latency (~5ms) plotted as ~5°C,
success rate (100%) plotted as 100% humidity.

**Root cause — multi-layer failure across dashboard and firmware:**

1. **`mkDS()` created chart datasets for ALL sensors.** `SENSORS.map()` generated one dataset
   per entry in SENSORS, including the `wan_ping` network device (dataset index 3). The
   temperature/humidity charts are environmental-only — network devices should not have datasets.

2. **`applyHistoryRange()` used SENSORS array index as dataset index.** With SENSORS containing
   `[office(0), first_floor(1), outside(2), wan_ping(3)]`, `wan_ping` at `idx=3` would write
   to `datasets[3]` which was the dataset created in step 1.

3. **`fetchDeviceHistory()` fallback fetched wrong data.** The manifest's global `metrics[]`
   only defines `temp` and `hum`. When looking up `wan_ping`'s measurements (`ping_ms`,
   `success_pct`) against global metrics, no match was found → `historyMeasurements` was empty
   → the fallback triggered: `[{key:'temp', url:'/history/wan_ping/temp'}, {key:'hum', url:'/history/wan_ping/hum'}]`.

4. **Firmware legacy `/history/{id}/temp` handler returned ping data.** `handle_history_()`
   matched `wan_ping` by device ID, then mapped `temp` → `metric_states[0]` (the ping_ms
   HistoryBuffer) and `hum` → `metric_states[1]` (the success_pct HistoryBuffer). These
   buffers contained real ping data, which was returned as if it were temperature/humidity.

5. **`loadHistory()` stored this data as temp/hum.** The received CSV was stored in
   `ensureHistoryStore('wan_ping').temp` and `.hum`, which `applyHistoryRange()` then
   plotted on the environmental charts.

**Fix — six changes across three files:**

| File | Change |
|------|--------|
| `dashboard/dashboard.js` + `.html` | `applySensorMeta()`: assign `s.chartIdx` (0,1,2,... for environmental, -1 for others) |
| `dashboard/dashboard.js` + `.html` | `mkDS()`: filter to `s.chartIdx >= 0` before creating datasets |
| `dashboard/dashboard.js` + `.html` | `handleState()`: guard chart push with `s.chartIdx >= 0`, use `s.chartIdx` not `idx` |
| `dashboard/dashboard.js` + `.html` | `applyHistoryRange()`: skip `s.chartIdx < 0`, use `s.chartIdx` not `idx` |
| `dashboard/dashboard.js` + `.html` | `loadHistory()`: skip non-environmental sensors entirely |
| `sensor_history_multi.h` | `handle_history_()`: 404 for non-environmental devices on legacy `/history/{id}/temp\|hum` |

**Why not caught in Phase 4:**
- The v7.5.4.2 prompt (network card renderer) correctly identified that network devices need
  a separate data path (`/api/v2/live` polling). But it did not address the chart side — it
  stated "chart support comes in a later step" and "chart rendering excluded for network device."
  This prevented chart *canvases* from being added to network cards, but did not prevent the
  existing environmental charts from including network device datasets.
- The v7.5.4.3 prompt (tests) tested that chart canvases exist for environmental devices but
  did not assert that chart datasets exclude non-environmental sensors.
- The v7.5.4.2 change to include all categories in SENSORS (removing the environmental-only
  filter) was the correct architectural direction, but the chart code was not updated to
  account for the expanded SENSORS array.

**Prevention:** LESSON-OPS-064 (endpoint audit) applies here to chart code as well.
When expanding SENSORS to include non-environmental devices, audit ALL code that iterates
SENSORS with index-based dataset access.

---

### BUG-055 — `bump-version.sh` produces stale `dashboard.h` when `dashboard.min.html` exists (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.5 (during deployment)
**Status:** FIXED (v7.5.4.5)

**Symptom:** `bash scripts/bump-version.sh 7.5.4.5` completes but `preflight.sh` reports
`dashboard_h_version_matches: FAIL`. The generated `dashboard.h` still contains the old version.

**Root cause:** `generate-header.sh` auto-detects `dashboard/dashboard.min.html` and prefers it
over `dashboard.html`. `bump-version.sh` updates `dashboard.html` (via `sed`) and calls
`render_sensor_config.py --write` (updates `dashboard.js`), but never re-minifies. The stale
`.min.html` from the prior build still contains the old `App.version`, and `generate-header.sh`
embeds that stale content into `dashboard.h`.

**Fix:** `bump-version.sh` now checks for a stale `.min.html` after `render_sensor_config.py`.
If `html-minifier-terser` is installed, it re-runs `minify-dashboard.sh`. If the minifier is
not available, it removes the stale `.min.html` so `generate-header.sh` falls back to the
freshly-updated `dashboard.html`.

**Prevention:** LESSON-OPS-066.

---

### BUG-054 — Calendar date picker dark/light mode CSS issues (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.4
**Status:** FIXED (v7.5.4.5)

**Symptom — dark mode:** Native browser date picker calendar popup (triggered by clicking the calendar icon on `<input type=date>`) rendered with a white background. Time `<select>` dropdowns also had browser-default white backgrounds.

**Symptom — light mode:** From/To date input fields and time select dropdowns had hardcoded dark backgrounds (`rgba(15,23,42,.5)`) making text unreadable. Modal buttons also dark.

**Root cause:** The CSS for `.cr-time-row input[type=date]` and `.cr-time-row select` used hardcoded dark-theme colors with no `color-scheme` property and no `:root.light` overrides. The `color-scheme` CSS property tells the browser to render native widgets (date pickers, selects) in light or dark mode — without it, browsers default to their light variant regardless of page theme.

**Fix:** Added `color-scheme:dark` to date/select inputs in default (dark) theme. Added `:root.light` CSS overrides that set white backgrounds, appropriate text colors, and `color-scheme:light`.

---

### BUG-053 — `/api/status` outputs ThermoPro-specific fields for all device categories (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.4
**Status:** FIXED (v7.5.4.5)

**Symptom:** `curl /api/status` returned `temp_valid: false, hum_valid: false` for the `wan_ping` device. These fields are semantically meaningless for a network ping probe.

**Root cause:** `handle_status_()` was written before the SensorEntity model existed. It iterated all `NUM_DEVICES` and unconditionally emitted `temp_valid`/`hum_valid` for every entry. Phase 3 (SensorEntity refactor) and Phase 4 (ping adapter) did not scope this handler for updates.

**Fix:** Added `category` field to each sensor entry in the status JSON. `temp_valid`/`hum_valid` are now only emitted for environmental devices (`category_id == 0`).

**Prevention:** LESSON-OPS-064.

---

### BUG-052 — `/sensors.json` v1 projection includes non-environmental devices (2026-03-21)

**Date:** 2026-03-21
**Version observed:** v7.5.4.4
**Status:** FIXED (v7.5.4.5)

**Symptom:** `curl /sensors.json` returned 4 entries including `wan_ping`. The architecture plan (Section 5.3) specifies `/sensors.json` as a v1 compatibility projection containing only environmental sensors.

**Root cause:** `handle_manifest_()` (which serves `/sensors.json`) iterated `NUM_DEVICES` without filtering by category. When `wan_ping` was added in v7.5.4.0, `NUM_DEVICES` became 4 but the handler was not updated. The dashboard's fallback path (`/sensors.json` → auto-promote to v2 with ThermoPro defaults) would incorrectly treat `wan_ping` as a ThermoPro sensor.

**Why not caught:** Phase 4 prompts focused on the new code (adapter, card renderer, tests) but did not include a checkpoint for existing endpoints like `/sensors.json`. The Playwright test fixture for `sensors.json` already had only 3 entries (correct), so tests passed even though the real firmware returned 4.

**Fix:** `handle_manifest_()` now skips devices with `category_id != 0` (non-environmental).

**Prevention:** LESSON-OPS-064.

---

### BUG-051 — 11 Playwright tests fail when running full suite with FIXTURE_SET=mixed (2026-03-20)

**Date:** 2026-03-20
**Version observed:** v7.5.4.3 (post-PR #59)
**Status:** FIXED

**Symptom:** Running `FIXTURE_SET=mixed npx playwright test --project=chromium` (full suite) fails
with 11 test failures across `tests/browser/dashboard.spec.js` and `tests/browser/manifest.spec.js`:
- Tests asserting exactly 4 sensor cards (`3 environmental + 1 network`) time out or fail on count
- Tests asserting sensor name `'Outside'` fail because the mixed fixture has no `outside` sensor
- Tests expecting `sensors.json` to contain `['office', 'first_floor', 'outside']` fail because
  the mixed `sensors.json` only has 2 entries (`office`, `first_floor`)
- Tests using `loadDashboard(page, { expectedSensorCount: 4 })` time out (mixed has 3 sensors)

The 11 affected tests span:
- `manifest.spec.js`: `dashboard boots from /api/manifest`, `dashboard falls back to /sensors.json`
- `dashboard.spec.js Group 2`: `four sensor cards are rendered`, `sensor card headers contain expected sensor names`
- `dashboard.spec.js Group 11`: `environmental renderer dispatches correctly and produces sensor cards`
- `dashboard.spec.js Group 14`: scenarios 1, 2, and 4
- `dashboard.spec.js Group 15`: `dashboard renders identically with new endpoints`
- `dashboard.spec.js Group 17`: `environmental cards have full ThermoPro layout`, `SENSORS includes network device`

**Root cause:** These tests were written for the `3sensor` fixture (3 env + 1 network = 4 total,
including `outside`). The `mixed` fixture intentionally has a different shape (2 env + 1 network = 3
total, no `outside`). When a developer runs the full suite locally with `FIXTURE_SET=mixed`, none of
these tests had a skip guard, so they all fail. In CI, the `mixed` matrix job only runs Group 18
via `--grep`, so CI never exposed the problem — it was only visible in full local runs.

**Fix:** Added `test.skip(process.env.FIXTURE_SET === 'mixed', '<reason>')` at the start of each
of the 11 affected tests. The skip reason includes the specific counts/names that are
`3sensor`-specific, making the incompatibility self-documenting.

**Why not caught earlier:**
- CI matrix runs `mixed` fixture exclusively with `--grep "18\. Mixed-Category Rendering"`, so
  only Group 18 runs in CI with `FIXTURE_SET=mixed`. All other groups are never exercised with
  that fixture in CI.
- Human reviewers focused on Group 18 correctness and did not run the full suite with
  `FIXTURE_SET=mixed` locally.
- BUG-050 was about Group 18 tests *within* CI breaking the `3sensor` job; this bug is the
  inverse: running the full suite under the `mixed` fixture breaks non-Group-18 tests.

**Prevention:** LESSON-OPS-063 — any fixture-specific test must carry a skip guard.
When adding a new fixture variant to the CI matrix, verify that running the full suite locally
under that fixture does not produce unexpected failures in existing test groups.

Related: BUG-050, PR-057, LESSON-OPS-063

---

### PR-057 — Group 18 tests used wrong `loadDashboard()` signature and dynamic count assertions (2026-03-20)

**Date:** 2026-03-20
**Version observed:** v7.5.4.3 (PR #57 before correction, `copilot/implement-phase4-step-v7543`)
**Status:** FIXED before merge

**Symptom:** Code review of PR #57 (Mixed-Category Rendering — Group 18 Playwright tests) found
two classes of implementation deviation from the specified test template in the coding agent prompt:

1. `loadDashboard()` was called as `loadDashboard(page, { timeout: 30000 })` in all 6 Group-18
   tests instead of the specified `loadDashboard(page, { expectedSensorCount: 3 })`.
2. Count assertions (`toHaveCount()`) used dynamic `window._manifest.sensors` lookups instead of
   hardcoded fixture-specific integers (`3` total, `2` environmental).

**Root cause — Issue 1 (`timeout` vs `expectedSensorCount`):**
The coding agent saw Group 13 using `{ timeout: 30000 }` (BUG-049 fix) and pattern-matched that
style to the new group. It did not distinguish *why* Group 13 uses a raw timeout (Firefox SSE
teardown headroom) versus what the new mixed fixture needs (a count-gated readiness check).
`expectedSensorCount` causes `waitForDashboardReady()` to actively wait until exactly N sensor
cards are present before proceeding — a stronger signal than a raw timeout. A raw timeout can pass
vacuously if the page loads fewer cards than expected.

**Root cause — Issue 2 (dynamic counts):**
The coding agent made tests "fixture-agnostic" by reading counts from `window._manifest` at
runtime rather than hardcoding the known fixture values. This is an anti-pattern for
fixture-specific tests: if the manifest itself is broken and returns 0 sensors, `toHaveCount(0)`
passes vacuously, providing no regression protection.

**Fix:**
- All 6 Group-18 `loadDashboard()` calls changed to `{ expectedSensorCount: 3 }`.
- All dynamic count assertions replaced with hardcoded literals: `3` (total), `2` (environmental).

**Prevention:** LESSON-OPS-063 (see Operational Lessons).

Related: BUG-050, LESSON-OPS-063

---

### BUG-050 — Group 18 Playwright tests fail in CI: `expectedSensorCount` mismatch with `3sensor` fixture (2026-03-20)

**Date:** 2026-03-20
**Version observed:** v7.5.4.3 (PR #57, `copilot/implement-phase4-step-v7543`)
**Status:** FIXED

**Symptom:** `browser-tests (3sensor)` CI job fails with `TimeoutError: page.waitForFunction: Timeout 15000ms exceeded`
in 6 of the 7 Group 18 (`18. Mixed-Category Rendering`) Playwright tests. All other CI jobs
(`1sensor`, `2sensor`, `4sensor`) pass. Failure occurs in `waitForDashboardReady` at the
`sensors.length !== expected` guard.

**Root cause:** Group 18 tests were written for the `mixed` fixture variant (2 environmental
sensors + 1 `wan_ping` network device = 3 sensors total). Every test calls
`loadDashboard(page, { expectedSensorCount: 3 })`, which makes `waitForDashboardReady` wait
until `App.State.getSensors().length === 3`. However, the CI `browser-tests` workflow runs
the full `dashboard.spec.js` suite only under `FIXTURE_SET=3sensor`. The `3sensor` fixture
has 4 sensors (3 BLE environmental + 1 `wan_ping`). With 4 sensors loaded, the condition
`sensors.length === 3` is never satisfied, causing the default 15-second timeout to expire.

**The original v7.5.4.3 PR (before correction)** used `{ timeout: 30000 }` and dynamic
`window._manifest` count reads — both identified as incorrect by post-merge review:
`{ timeout: 30000 }` is a BUG-049 Firefox workaround reserved for Group 13 only, and dynamic
manifest reads allow vacuous passes when the manifest is broken. The corrected tests properly
use `{ expectedSensorCount: 3 }` and hardcoded counts, but this exposed the fixture mismatch.

**Fix:**
1. `tests/browser/dashboard.spec.js` — Group 18 `test.describe()`: added `test.beforeEach`
   with `testInfo.skip()` when `process.env.FIXTURE_SET !== 'mixed'`. Group 18 is skipped
   in all CI jobs except the dedicated `mixed` job.
2. `.github/workflows/browser-tests.yml` — CI matrix: added `mixed` fixture set; added step
   `Run mixed-category suite (mixed — Group 18)` that runs only Group 18 with
   `--grep "18\. Mixed-Category Rendering"` and `FIXTURE_SET=mixed`; updated
   sensor-count smoke step to skip `mixed` (uses `!= '3sensor' && != 'mixed'`).
3. `tests/fixtures/generate-fixtures.js` — added `buildPingCsvLines()` + `generateMixedFixtures()`;
   `main()` now calls `generateMixedFixtures()` to produce `tests/fixtures/variants/mixed/`.
4. `tests/mock-server/server.js` — `icmp_ping` devices now return `ping_ms: 12.5,
   success_pct: 100.0` instead of `null`, so live-value assertions in Group 18 pass.

**Why not detected before merge:**
- The coding agent ran tests locally with `FIXTURE_SET=3sensor` where Group 18 tests were
  originally fixture-agnostic (dynamic counts) and happened to produce a passing result.
- After the post-merge review identified issues #2/#3, the corrected PR used `expectedSensorCount: 3`
  but was not re-validated against the CI fixture matrix (`3sensor` = 4 sensors).
- Human review focused on test logic correctness, not CI fixture compatibility.

**Prevention:** LESSON-OPS-063 (see below).

Related: BUG-049, LESSON-OPS-063

---

### BUG-049 — Firefox Playwright Group 13 tests fail: SSE teardown timeout + slow boot (2026-03-19)

**Date:** 2026-03-19
**Version observed:** v7.5.4.0
**Status:** FIXED

**Symptom:** Two Firefox-only failures in Group 13 (Manifest-driven history fetching):
- Test 137 (`fetchDeviceHistory is a callable function`): All assertions pass. Failure occurs in
  teardown — `browserContext.close()` hangs for 48.9s waiting for the SSE `EventSource` TCP
  connection to close, exceeding the 30s test timeout.
- Test 138 (`App.API.fetchDeviceHistory is exported`): `waitForDashboardReady()` times out at
  15s waiting for `.sensor-card` to become visible. Firefox's slower event loop means the
  dashboard boot sequence (manifest fetch → card render → DOM paint) takes longer than Chromium.

**Root cause:** Firefox's Gecko engine holds SSE TCP connections open during `browserContext.close()`
if EventSource callbacks (`onopen`, `onerror`, `onmessage`) are still attached. The existing
`stopDashboardNetwork()` called `evtSource.close()` but did not null out the callbacks first.
Additionally, Group 13 used the default 15s `loadDashboard()` timeout, insufficient for Firefox's
slower rendering pipeline.

**Fix:**
- `stopDashboardNetwork()` in `dashboard.spec.js`: null out `onopen`, `onerror`, `onmessage`
  before calling `.close()` on `EventSource`.
- `suspendDashboardNetworkActivity()` in `dashboard.js` and `dashboard.html`: same callback-
  nulling pattern applied to production code (LESSON-OPS-043 mirror).
- Group 13 `test.describe()`: added `test.setTimeout(90000)` for Firefox SSE teardown headroom.
- All Group 13 `loadDashboard()` calls: increased timeout to `{ timeout: 30000 }`.

**Prevention:** LESSON-OPS-062 (see below).

Related: LESSON-OPS-062, LESSON-OPS-043

---

### BUG-048 — NVS `SegmentSnapshot` blobs from `NUM_SENSORS=4` period physically incompatible with corrected firmware (2026-03-19)

**Date:** 2026-03-19
**Version observed:** v7.5.4.0 (post-BUG-046 fix — history loads only 36 points instead of full retained history)
**Status:** FIXED

**Symptom:** After merging the BUG-046 meta migration fix (PR #53), the dashboard loads history
but only shows ~36 data points (approximately 9 hours of new data collected since the fix).
Previously retained 45-day ThermoPro history is missing. The firmware no longer logs the
"schema mismatch — resetting" loop, but the full history is not recovered.

**Root cause:** The BUG-046 fix correctly migrated the `HistoryMeta` blob (correcting `num_sensors`
from 4 to 3 and persisting it). However, the individual `SegmentSnapshot` blobs written to NVS
during the buggy `NUM_SENSORS=4` period have a **physically different byte size** because the
struct contains fixed-size arrays dimensioned by `NUM_SENSORS` at compile time:

```
// With NUM_SENSORS=4: sizeof(SegmentSnapshot) ≈ 298 bytes
HistEntry temp[4][PERSIST_POINTS_PER_SEGMENT]
HistEntry hum[4][PERSIST_POINTS_PER_SEGMENT]
uint16_t temp_counts[4]
uint16_t hum_counts[4]

// With NUM_SENSORS=3: sizeof(SegmentSnapshot) ≈ 230 bytes
HistEntry temp[3][PERSIST_POINTS_PER_SEGMENT]
HistEntry hum[3][PERSIST_POINTS_PER_SEGMENT]
uint16_t temp_counts[3]
uint16_t hum_counts[3]
```

When `nvs_get_blob()` tries to read a 298-byte blob into a 230-byte buffer, ESP-IDF returns
`ESP_ERR_NVS_INVALID_LENGTH`. The blob is never read, and `load_snapshot_from_handle_()` returned
`false` silently — no log message indicated the real failure mode.

The restore loop in `restore_from_nvs()` attempted to load all `meta.valid_segments` slots
(which included ghost references to the incompatible blobs), skipped them all, and only found the
few new segments written after the fix. The meta was never recalibrated to reflect the reduced
valid segment count, so every subsequent boot repeated the same futile load attempts.

**Fix:**
- `load_snapshot_from_handle_()`: added diagnostic logging when `nvs_get_blob()` returns
  `ESP_ERR_NVS_INVALID_LENGTH`, identifying the stored-vs-expected byte size and referencing
  BUG-048.
- `restore_from_nvs()`: after the restore loop, if `skipped_size_mismatch > 0` and
  `restored < restore_segments`, recalibrate `meta.valid_segments` to match only the
  actually-restorable segment count. Persist the recalibrated meta back to NVS so that:
  - Subsequent boots don't waste time retrying unloadable slots
  - The restore window targets only readable segments
  - Future `persist_hourly_segment()` calls correctly grow `valid_segments` from the
    recalibrated baseline as new compatible segments are written

**Impact:** The history lost during the `NUM_SENSORS=4` period is **unrecoverable** — the blobs
are physically a different size and cannot be deserialized into the current struct layout without
a complex cross-schema converter. The recalibration ensures the system recovers cleanly and
begins accumulating new history from a known-good baseline. Users who need the old data should
use the CSV export they took before the v7.5.4.0 flash (if available) and re-import via the
single-sensor merge import.

**Prevention:** LESSON-OPS-061 (see below). Also: the v7.5.4.0 implementation prompt now includes
an explicit acceptance criterion verifying that `sizeof(SegmentSnapshot)` has not changed.

Related: BUG-046, BUG-045, LESSON-OPS-061, LESSON-OPS-060

---

### BUG-046 — Stale NVS `HistoryMeta` never overwritten after `num_sensors` schema correction (2026-03-19)

**Date:** 2026-03-19
**Version observed:** v7.5.4.0 (devices that received the temporary `NUM_SENSORS=4` build)
**Status:** FIXED

**Symptom:** Devices that were flashed with the temporary bad `NUM_SENSORS=4` build
(BUG-045) continued to log on every boot:

```
[W][history:674][httpd]: history meta invalid or schema mismatch — resetting
```

Even after the BUG-045 code fix restored `NUM_SENSORS = NUM_ENV_SENSORS = 3`, devices
with stale `hist_meta` NVS blobs (written with `num_sensors=4`) never recovered. Dashboard
history remained empty indefinitely unless the user manually erased history.

**Root cause:** `load_history_meta_()` detected the `num_sensors` mismatch and reset the
in-memory `HistoryMeta` to defaults, but never persisted the corrected metadata back to NVS.
`restore_from_nvs()` opened NVS read-only and exited early when `load_history_meta_()` returned
false, so the stale blob was never overwritten. The mismatch repeated on every boot.

**Fix:**
- Modify `load_history_meta_()` to distinguish recoverable stale `num_sensors` mismatch from
  true corruption. When `magic`, `version`, `points_per_series`, and `points_per_segment` all
  match current expectations, only `num_sensors` differs — this is the known recoverable case
  from BUG-045. Correct `num_sensors` in-place and preserve valid segment bookkeeping.
- Add a `bool *needs_nvs_persist` output parameter so callers know the corrected meta must be
  saved back to NVS.
- In `restore_from_nvs()`, after loading meta, check `needs_nvs_persist`. If true, close the
  read-only handle, reopen read-write, save the corrected metadata, and close. Then reopen
  read-only for the snapshot restore loop.
- For true corruption, also persist the default metadata to break the stale-meta loop.
- Add explicit log messages distinguishing migration from corruption from successful persistence.
- Dashboard: add per-sensor catch in `fetchAllSensorHistoryRowsSequentially` and guard
  `buildMergedSensorCsv` against undefined/null row entries to prevent uncaught errors when
  history is temporarily empty after migration.

**Prevention:** LESSON-OPS-060 (see below).

Related: BUG-045, LESSON-OPS-060

---

### BUG-045 — Mixed-category device count accidentally changed persisted history schema (2026-03-18)

**Date:** 2026-03-18 (discovered post-flash via ESPHome logs)
**Version observed:** v7.5.4.0
**Status:** FIXED

**Symptom:** After flashing v7.5.4.0 firmware, ESPHome output repeatedly logged:

```
[W][history:672][httpd]: history meta invalid or schema mismatch — resetting
```

All history cards on the dashboard showed no data. Previously retained ThermoPro temperature and
humidity history was silently discarded on every boot.

**Root cause:** `scripts/render_sensor_config.py` `render_entity_block()` aliased
`NUM_SENSORS = NUM_DEVICES`. Adding the RAM-only `wan_ping` network device increased
`NUM_DEVICES` from 3 to 4, which propagated to `NUM_SENSORS`. The persistence validation code
in `sensor_history_multi.h` checks `meta->num_sensors == NUM_SENSORS` (and likewise for
`SegmentSnapshotHeader`). A retained 3-sensor schema would fail `3 == 4`, triggering a full
history reset on every boot.

**Fix:**
- In `render_entity_block()`, generate a separate `NUM_ENV_SENSORS` constant equal to the count
  of environmental (ThermoPro/BLE) devices, and alias `NUM_SENSORS = NUM_ENV_SENSORS` instead
  of `NUM_DEVICES`. This keeps persisted schema 3-wide regardless of how many RAM-only devices
  are added.
- Update `render_header_block()` comments to clearly distinguish `NUM_DEVICES` (all runtime
  devices) from `NUM_SENSORS` (persisted environmental count).
- Update the static comment in `sensor_history_multi.h` to reflect the corrected aliasing.
- Add 3 preflight regression guards to `scripts/preflight.sh`:
  - `num_env_sensors_constant_present` — generated header must contain `NUM_ENV_SENSORS =`
  - `num_sensors_aliases_env_sensors` — `NUM_SENSORS` must alias `NUM_ENV_SENSORS`
  - `num_sensors_not_aliased_to_num_devices` — `NUM_SENSORS = NUM_DEVICES` must not appear

**Prevention:** LESSON-OPS-059 (see below). Preflight guards prevent this class of regression.

Related: LESSON-OPS-059

---

### BUG-044 — BUG-043 preflight enhancements and browser regression tests specified but never implemented (2026-03-18)

**Date:** 2026-03-18 (discovered during post-Phase-3 codebase audit)
**Version observed:** v7.5.3.9
**Status:** FIXED

**Symptom:** Two instruction documents existed — `Docs/BUG-043-preflight-enhancement-instructions.md` (5 preflight checks) and `Docs/BUG-043-browser-test-implementation-instructions.md` (8 browser regression tests) — but neither was implemented. The codebase had zero of the specified checks or tests.

**Root cause:** The documents were created as part of BUG-043 resolution planning but the implementation work was never scheduled as a tracked step. The Phase 3 implementation plan (v7.5.3.4/v7.5.3.5) addressed the BUG-043 firmware and dashboard fixes but did not include these supplementary test/check deliverables as gated steps.

**Fix:**
- Added 5 preflight checks to `scripts/preflight.sh`: `no_streaming_history_response`, `nvs_yield_present`, `inflight_guard_{_statusInFlight,_storageStatsInFlight,_historyInFlight}`, `generate_header_uses_gzip`
- Added 8 browser regression tests as Group 16 in `tests/browser/dashboard.spec.js`: manifest dedup, history sequential fetch, loadHistory in-flight guard, guard reset after failure, SSE ping/onopen no-status-fetch, no favicon.ico, manifest-first boot order, loadStorageStats guard
- Added 50ms delay to mock server history endpoints to make concurrency observable in Playwright

**Prevention:**
- Specified implementations must be tracked in a step index with explicit "Status: Pending/Complete" tracking (LESSON-OPS-057)
- Post-phase audits should verify that all referenced instruction documents have corresponding implementations

Related: BUG-043, LESSON-OPS-057

---

### Fix (final — gzip dashboard + pre-reserved history response)

Post-PR#41 device validation showed the ESP32-C3 still crashed on dashboard open and F5 despite all request scheduling fixes. Two firmware-level root causes:

**RC-GZIP: 190KB uncompressed dashboard HTML blocked HTTP task 2–4s per page load.**
Every `GET /dashboard.html` transferred 194,533 bytes of raw HTML. On the single-core ESP32-C3, this monopolized the HTTP server task, starving BLE/WiFi/API and causing watchdog resets.

**Fix:** Gzip-compress dashboard in build pipeline (194KB → 45KB, 77% reduction). Serve with `Content-Encoding: gzip`. Added inline favicon (`<link rel="icon" href="data:,">`) to eliminate browser `/favicon.ico` request.

**RC-HEAPALLOC: `beginResponseStream` reallocation cascade in `handle_history_()` caused heap exhaustion.**
With 336 NVS segments, the response string grew through 128→256→…→16K→32K via `resp->print()`. At the 16K→32K transition, both old (16K) and new (32K) buffers exist simultaneously = 48KB. With SSE/polling holding ~12KB of buffers, total exceeded available ~60KB free heap.

**Fix:** Pre-reserved `std::string` with `csv.reserve(estimated_bytes)` — single allocation, zero reallocations. Sent via zero-copy `beginResponse(200, type, data, len)` instead of `beginResponseStream`. Added string-based CSV builders `append_csv_to()` and `append_snapshot_series_csv_()`. Increased NVS yield from 1ms/4-reads to 5ms/2-reads.

### Updated Prevention rules

Add to the existing Prevention section:
- **Gzip-compress all large embedded responses** — the ESP32-C3 HTTP task blocks proportionally to response size. Any response >50KB should be gzip-compressed at build time (LESSON-OPS-055)
- **Never use `beginResponseStream` for responses that grow beyond ~10KB** — the std::string reallocation doubles peak heap temporarily. Use pre-reserved `std::string` + zero-copy `beginResponse(200, type, data, len)` instead (LESSON-OPS-056)
- **Preflight must guard dashboard.h size** — a size threshold check catches accidental regression to uncompressed format (LESSON-OPS-055)

Related: LESSON-OPS-055, LESSON-OPS-056

---

## BUG-044 — Fixture/test drift after manifest metric expansion

### Symptom

After adding system-device metrics to manifest v2, preflight failed in the
Playwright manifest check and `render_sensor_config.py --check` reported fixture
drift. The failures appeared as stale expectations (`['temp','hum']`) and
out-of-sync baseline fixture manifest content.

### Root Cause

The system-device metric expansion changed the top-level manifest `metrics`
payload and added `external_push` measurement entries, but test expectations and
fixture-generation paths still assumed env-only top-level metrics.

### Fix

- Updated fixture generator (`tests/fixtures/generate-fixtures.js`) to emit
  system metrics and `external_push` measurement mappings.
- Updated Playwright assertions to validate manifest metrics via
  `arrayContaining(...)` and to derive expected sensor lists from `/api/manifest`
  for satellite-mode boot checks.
- Regenerated baseline + variants via required generators.

### Prevention

Any manifest schema/metrics change must include:
- fixture generator update,
- baseline + variant regeneration,
- Playwright expectation audit for fixed cardinality assumptions.


## BUG-043 — Dashboard request fanout / polling destabilizes ESP32-C3 (CONFIRMED)

**Date:** 2026-03-16 / continued 2026-03-17 / firmware fix 2026-03-17 / dashboard hardening 2026-03-17
**Version observed:** `v7.5.3.3` post-merge validation; crash persists through `v7.5.3.4`, partial mitigation in `v7.5.3.5`
**Status:** FIXED — firmware NVS yield (PR #40) + dashboard hardening (PR2, this PR). Post-merge device validation still required.
**Remediation:** `Docs/dashboard-stability-remediation-plan.md`, `Docs/BUG-043-continued-fix-plan.md`
**Fix PRs:** PRs #36–#38 (v7.5.3.3-hotfix); v7.5.3.5 (PR #39); firmware NVS yield (PR #40); dashboard hardening (this PR)

### Symptom (continued, post-hotfix)
Despite the v7.5.3.3-hotfix implementing all 8 remediation steps, the ESP32-C3 still crashed when the dashboard was opened in SSE or polling mode:

- **SSE mode**: Dashboard loads ~1 minute then crashes during history loading. Device logs show a 2-second component blocking warning followed by API disconnect.
- **Polling mode**: Initial crash on open, then stabilization with oscillating heap (53K–73K).
- **F5 refresh** after 3 min uptime crashes again.
- **Untouched**: Device runs stable at 72.1 KB free heap — confirms crash is dashboard-triggered.
- **No `httpd_accept_conn: error in accept (23)`** — socket exhaustion (the original root cause) is fixed; new root causes identified below.

### Continued root causes (v7.5.3.5)

#### RC1: Concurrent temp+hum history fetches block the HTTP server task (PRIMARY)
`fetchDeviceHistory()` used `Promise.all` for all history measurements. Each `/history/{id}/temp` or `/history/{id}/hum` request triggers a **synchronous NVS scan loop** in `sensor_history_multi.h` that reads up to 1080 NVS blobs without yielding. With `Promise.all`, both requests fire simultaneously, doubling the blocking window to 1–4 seconds. During that window, BLE scanning, WiFi, the ESPHome API, and the task watchdog are all starved.

#### RC2: Double manifest fetch at boot
`loadManifestV2()` fetches `/api/manifest`, then `loadSensorManifest()` fetches it again. 2 redundant HTTP requests during the most constrained startup window. Introduced in v7.5.2.0 when `loadManifestV2()` was added alongside `loadSensorManifest()` without consolidating them.

#### RC3: Polling mode initial burst fires 33+ paths immediately
`startPolling()` fired `pollAll(POLL_DEVICE.concat(livePaths))` with no initial defer, concurrent with `loadStatusSnapshot()` — 5 concurrent connections in the first 120ms.

#### RC4: No in-flight guard on loadHistory()
Unlike `loadStatusSnapshot()` and `loadStorageStats()` (which got in-flight guards in the hotfix), `loadHistory()` had no guard — rapid close/reopen or F5 during boot could run two history chains in parallel.

#### RC5: History bootstrap timer too short (5s)
Storage stats deferred to t+3s and the initial poll taking ~3.5s total meant history could start before both completed.

### Original root causes (v7.5.3.3-hotfix)
The dashboard JavaScript overwhelmed the ESP32-C3 HTTP server through six independent issues:

1. **SSE `ping` handler fires `loadStatusSnapshot()` on every ping** — 10-20+ redundant `/api/status` requests per minute.
2. **SSE `onopen` handler fires `loadStatusSnapshot()`** — duplicate `/api/status` at boot.
3. **Double status polling in polling mode** — 15s interval + 30s interval firing simultaneously.
4. **No in-flight guard on `loadStatusSnapshot()`** — concurrent calls stack up when ESP is slow.
5. **No in-flight guard on `loadStorageStats()`** — same stacking, compounded by retry logic.
6. **Startup request burst with no staggering** — 8-12+ HTTP requests within ~2 seconds of boot.

**Combined effect (original):** Peak concurrent connections at boot: 8-12+. Caused `httpd_accept_conn: error in accept (23)` followed by panic/reboot.

### Fix (continued — v7.5.3.5)
See `Docs/BUG-043-continued-fix-plan.md`:
1. `fetchDeviceHistory()` now fetches metrics **sequentially** with 300ms gap (replaces `Promise.all`)
2. `loadHistory()` has `_historyInFlight` in-flight guard
3. `App.Boot.start()` reuses `window._manifest.sensors` — eliminates second `/api/manifest` fetch
4. `startPolling()` defers initial poll by 1s, uses batch size 2, handles `loadStatusSnapshot()` internally
5. History bootstrap timer increased from 5s to 8s
6. `no_concurrent_history_fetch` preflight check added

**Note:** v7.5.3.5 mitigated dashboard-side concurrency but did **not** eliminate firmware-side blocking. Even a single serialized history request can block the HTTP task long enough to starve BLE/WiFi/API/watchdog work when history is large. The firmware-side root cause is addressed in the split follow-up PR below.

### Fix (firmware root-cause — NVS yield)
Implements the "Future Work" item from `Docs/BUG-043-continued-fix-plan.md`. Split-PR strategy: firmware-only fix first, dashboard hardening in a separate follow-up PR.

1. Added `maybe_yield_nvs_scan_(int iteration)` static helper in `dashboard/sensor_history_multi.h`
   - Calls `vTaskDelay(pdMS_TO_TICKS(1))` every 4 NVS blob reads (`NVS_SCAN_YIELD_INTERVAL = 4`)
   - Gives FreeRTOS scheduler a timeslice between blob reads without per-blob overhead
2. Applied yield to **all three** long NVS iteration loops:
   - `restore_from_nvs()` — boot-time RAM restore (up to RAM_SEGMENTS blobs)
   - `build_import_epoch_map_()` — import epoch-map scan (up to PERSIST_SLOTS blobs)
   - `handle_history_()` — per-request history streaming loop (up to `meta.valid_segments` blobs, max 1080)
3. No dashboard JS changes in this PR — dashboard request-scheduling hardening is a separate follow-up PR

### Fix (dashboard hardening — PR2)
Completes BUG-043 resolution by fully serializing the startup request schedule:

1. **SSE startup**: `connectSSE()` fires first; `loadStatusSnapshot()` deferred 2s. SSE state events carry initial state; immediate status fetch was unnecessary overhead during the fragile SSE-open window.
2. **Polling startup**: Initial `pollAll` changed from batch=2/120ms to **batch=1/200ms** (fully sequential, one request at a time).
3. **History inter-sensor gap**: `loadHistory()` waits **500ms** between sensors instead of chaining immediately — lets ESP32-C3 complete BLE/WiFi work between NVS scan loops.
4. **Storage stats defer**: Deferred from 3s → 5s to avoid overlapping with the sequential poll still in flight.
5. **History bootstrap defer**: Deferred from 8s → 10s to ensure sequential poll and storage stats both complete before NVS-heavy history starts.
6. `startup_poll_sequential` preflight regression guard added.
7. `dashboard/dashboard.h` regenerated.

**Favicon/routing note**: `/favicon.ico` returns HTTP 500 on real devices despite correct 204 handling in `sensor_history_multi.h`. Root cause: ESPHome's `web_server` component registers its catch-all `AsyncWebHandler` during component `setup()` (before our `on_boot` lambda runs), so it intercepts `/favicon.ico` first and returns 500 for unrecognized routes. The fix requires changing when `register_history_handler()` is called (from `on_boot` to a hook that executes before ESPHome's web_server setup). This is a separate, larger change documented in LESSON-OPS-054.

### Fix (original — v7.5.3.3-hotfix)
See `Docs/dashboard-stability-remediation-plan.md`:
1. In-flight guard on `loadStatusSnapshot()`
2. In-flight guard on `loadStorageStats()`
3. Remove `loadStatusSnapshot()` from SSE `ping` handler
4. Remove `loadStatusSnapshot()` from SSE `onopen` handler
5. Make 30s `statusSnapshotIntervalId` conditional — polling mode only
6. Remove `loadStatusSnapshot()` from `startPolling()` 15s interval
7. Stagger startup requests over 5s
8. Increase storage stats interval to 120s

### Rule
When debugging real-device crashes involving the dashboard:
1. Isolate single-endpoint behavior from full dashboard behavior
2. Inspect the browser Network tab before blaming one route
3. Check for duplicate interval creation and startup request storms
4. Count concurrent connections at boot — must not exceed ~4
5. Check for blocking firmware operations triggered by HTTP requests (e.g., NVS scans)
6. **Even a single serialized history request can block the HTTP task** if the firmware loops over many NVS blobs without yielding — always add `vTaskDelay` in long NVS scan loops
7. **SSE mode**: connect the stream first, then defer non-critical status fetches — the stream open is the most fragile moment

### Prevention
- **In-flight guards are mandatory** on all interval-driven fetch functions (LESSON-OPS-050)
- **History fetches must be sequential** — never use `Promise.all` for history endpoints (LESSON-OPS-052)
- **Startup polling must be batch=1** — fully sequential initial poll is mandatory for ESP32-C3 stability (LESSON-OPS-054)
- Never fire HTTP requests from SSE event handlers (`ping`, `onopen`)
- Only one polling interval per endpoint category
- Stagger startup requests: SSE status 2s, storage stats 5s, history 10s
- **Real-device validation with dashboard open** required before merge (LESSON-OPS-051)
- **NVS scan loops must yield** — any loop over persisted segments must call `vTaskDelay(pdMS_TO_TICKS(1))` periodically (LESSON-OPS-053)
- **ESPHome handler ordering**: `HistoryWebHandler` must be registered before ESPHome's web_server handler or it will never be reached for routes the catch-all intercepts (LESSON-OPS-054)

Related: LESSON-OPS-050, LESSON-OPS-051, LESSON-OPS-052, LESSON-OPS-053, LESSON-OPS-054

---

### BUG-042: `dashboard/dashboard.h` version check fails due to minification (post-v7.5.2.0)

**Symptom:** PR #25 added `dashboard_h_version_matches` to `scripts/preflight.sh` and CI failed with `dashboard_h_version_matches: FAIL` even though `dashboard.js` and `dashboard.html` had the correct version string `App.version = 'v7.5.2.0'`.

**Root cause:** CI runs `minify-dashboard.sh` then `generate-header.sh` before `preflight.sh`. The minifier (terser) converts `App.version = 'v7.5.2.0'` to `App.version="v7.5.2.0"` (removes spaces, converts single quotes to double quotes). The original `dashboard_h_version_matches` check used `grep -Fq "App.version = '${VER_TAG}'"` (fixed-string with spaces and single quotes), which never matches the minified form in the regenerated `dashboard.h`. The committed `dashboard.h` had the unminified form but is discarded when CI regenerates it.

**Fix:** Changed `dashboard_h_version_matches` to use `grep -Eq` with a regex pattern `App\.version[[:space:]]*=[[:space:]]*['\"]${VER_TAG}['\"]` that matches both the unminified source form and the minified generated form. Added `check_contains_regex()` helper to `scripts/preflight.sh` for future regex-based checks.

**Lesson:** See LESSON-OPS-048.

---

### BUG-041: Fixture generator VERSION bumped independently from canonical VERSION file (v7.5.1.3)

**Symptom:** CI preflight failed with "Generated files are out of sync with config/sensors.json." The diff showed `manifest.json` containing `v7.5.1.3` while the Python generator (using VERSION from `render_sensor_config.py`) expected `v7.5.1.0`.

**Root cause:** PR #20 changed `tests/fixtures/generate-fixtures.js` VERSION from `v7.5.1.0` to `v7.5.1.3` and regenerated the fixture files with the new version string, but did not update the canonical VERSION sources (`VERSION` file, `render_sensor_config.py` VERSION constant). The Python generator (`render_sensor_config.py --check`) regenerates expected fixtures from the canonical VERSION and compares against on-disk fixtures — since JS fixtures said `v7.5.1.3` but Python expected `v7.5.1.0`, the check failed.

**Fix:** Bumped all version references atomically to `7.5.1.3`: `VERSION` file, `render_sensor_config.py` VERSION constant, `generate-fixtures.js` VERSION constant, `dashboard.js` App.version, `dashboard.html` App.version, `sensor_history_multi.h` header comment, YAML header comment, and `register_history_handler()` string. Regenerated all artifacts via `python3 scripts/render_sensor_config.py --write` and `bash scripts/generate-header.sh`. Added a preflight check (`fixture_generator_version_sync`) to catch future drift.

**Lesson:** See LESSON-OPS-047.

---

### BUG-040: No automated validation of manifest v2 schema (v7.5.1.1)

**Symptom:** Generator could produce malformed JSON or missing required fields without detection until runtime or manual inspection.

**Root cause:** Preflight only validated that `src/gateway_manifest.h` existed, was included, and that the generator sync check passed. It did not verify the content of the generated manifest against the v2 schema contract.

**Fix:** Added preflight checks that validate `gateway_manifest.h` contains all required v2 schema fields: top-level fields, `gateway` block fields, `history` block fields, `metrics` array fields, and that `schema_version` is exactly `2`.

**Lesson:** See LESSON-OPS-046.

---

### BUG-039: Dashboard source and generated artifacts drifted after Phase 1 work (v7.5.0.1)

**Symptom:** `dashboard.html` was updated during Phase 1 manifest work but `dashboard.min.html` and `dashboard.h` were not regenerated. The embedded firmware payload still ran stale client logic — manifest-first boot and `/api/status` hydration were absent from what actually flashed.

**Root cause:** The workflow assumed edits to `dashboard.html` would propagate automatically. They do not — the minification and header-embedding steps must be run explicitly after every source edit.

**Fix:** Patched `dashboard/dashboard.html` directly as the source of truth, then regenerated `dashboard.min.html` and `dashboard.h` from that corrected source. Kept `dashboard.js` aligned to the same runtime logic.

**Lesson:** See LESSON-OPS-043.

---

### BUG-038: Dashboard Free Heap and Uptime showed "loading…" after Phase 1 OTA (v7.5.0.1)

**Symptom:** After flashing Phase 1 firmware, `/api/manifest` and `/api/status` both responded correctly, but the dashboard displayed `loading...` indefinitely for Free Heap and Uptime.

**Root cause:** The dashboard still expected `/sensor/Free Heap` and `/sensor/Uptime` — legacy entity-polling paths that the firmware no longer provided as ESPHome entities. The authoritative data was already available from `GET /api/status` but the dashboard code was not reading from it.

**Fix:** Switched all dashboard device-status widget hydration to `GET /api/status`. Removed dependency on legacy entity-polling paths for those values.

**Lesson:** See LESSON-OPS-042.

---

### BUG-037: Built-in ESPHome diagnostics disappeared from the built-in web page after Phase 1 (v7.5.0.1)

**Symptom:** The ESPHome built-in web page no longer showed Free Heap, Uptime, or Loop Time after Phase 1 firmware changes.

**Root cause:** The `debug.free`, `debug.loop_time`, and `uptime` sensor blocks were removed or were missing from `firmware/esp32-c3-multi-sensor.yaml` during Phase 1 YAML changes.

**Fix:** Restored `debug.free`, `debug.loop_time`, and `uptime: type: seconds` blocks in the YAML. Confirmed both the custom dashboard and the built-in ESPHome page show all three diagnostics after reflash.

**Lesson:** See LESSON-OPS-044.

---

### BUG-036: YAML generator reintroduced broken indentation after hotfix — preflight passed but compile failed (v7.5.0.1)

**Symptom:** After the initial YAML indentation fix, running `python3 scripts/render_sensor_config.py --write` again silently reintroduced bad indentation into the YAML. `bash ./scripts/preflight.sh` passed. `esphome compile` failed near the averaging block with `expected <block end>`.

**Root cause:** The hotfix had corrected one call site but `render_yaml_file()` still routed some YAML marker regions through `replace_marker_block()` instead of `apply_yaml_marker_block()`. Those paths produced correct YAML body content but inserted it without preserving the indentation level from the marker location.

**Fix:** Switched all YAML marker replacements in `render_sensor_config.py` to `apply_yaml_marker_block()`. Confirmed idempotence by running `--write` twice.

**Lesson:** See LESSON-OPS-041.

---

### BUG-035: YAML generator produced invalid indentation in ESPHome block scalars (v7.5.0.0)

**Symptom:** `esphome compile firmware/esp32-c3-multi-sensor.yaml` failed immediately after `render_sensor_config.py --write` with `expected <block end>, but found '<scalar>'` near line 135.

**Root cause:** The YAML generation path reinserted block content without preserving the indentation level of the marker location. The content was semantically correct but structurally invalid YAML inside lambda block scalar sections, `web_server.sorting_groups`, `sensor`, and `text_sensor` blocks.

**Fix:** Routed all YAML marker replacements through `apply_yaml_marker_block()`, which captures the indentation column of the marker line and re-applies it to every inserted line.

**Lesson:** See LESSON-OPS-040.

---

### BUG-034: `render_sensor_config.py` crashed with `re.PatternError: bad escape \x` on generated content (v7.5.0.0)

**Symptom:** Running `python3 scripts/render_sensor_config.py --write` raised `re.PatternError: bad escape \x at position N` during the replacement phase for generated strings containing Unicode escape sequences like `\xC2\xB0` (the degree symbol).

**Root cause:** Generated replacement text was passed directly to `re.sub()` in string replacement mode. Python's `re.sub` interprets backslash sequences in the replacement string as regex back-references or escapes. `\xC2\xB0` was not a valid regex escape, causing the error.

**Fix:** Changed all `re.sub()` calls for generated content to use lambda/function replacements. In lambda mode, the replacement value is treated as a literal string, so backslash sequences in generated output are not interpreted.

**Lesson:** See LESSON-OPS-039.

---

### BUG-033: Phase 1 patch script failed against compacted one-line source blocks (v7.5.0.0)

**Symptom:** `scripts/apply_phase1_manifest_patch.py` failed repeatedly when targeting `dashboard/sensor_history_multi.h`. Exact-string matches could not find their targets, even when the content appeared visually correct.

**Root cause:** The header file uses compacted one-line formatting for several function bodies and handler blocks. Patch scripts that matched on long multi-line strings or comment text failed when those strings had been compacted into a single line.

**Fix:** Rewrote the patch approach to use function-anchor detection, regex-based matching, and brace-aware block insertion rather than exact long-string matching. Going forward, this is a known constraint of the codebase.

**Lesson:** See LESSON-OPS-039.

---

### BUG-032: Multi-sensor CLI restore could erase retained history without an explicit confirmation prompt (v7.4.5.1)

The first v7.4.5.0 CLI backup/restore helper correctly routed merged CSVs through the existing erase-first `/api/import/begin` path, but it did so without an explicit operator confirmation.

**Fix:** `scripts/history_backup.py import` now prompts before erase-first multi-sensor import unless `--yes` is provided, and it also supports `--single-sensor <id>` to intentionally force the merge route from a merged CSV.

---

### BUG-031: `change_sensor_number.py` rollback messaging was too optimistic for structural renderer failures (v7.4.5.1)

The initial rollback path restored `config/sensors.json` and attempted a best-effort re-render, but it could still leave the operator uncertain if recovery was incomplete.

**Fix:** rollback now preserves the backup file on failure, prints manual recovery commands, and surfaces restore/re-render errors explicitly instead of assuming a clean rollback.

---

### BUG-030: Manifest validation normalized MACs by mutating caller data in place (v7.4.5.1)

The original validation helper silently normalized MAC addresses inside the caller-provided list.

**Fix:** manifest validation is now side-effect free. Canonicalization is explicit through `canonicalize_sensors()`, and save/load/render flows use normalized copies rather than mutating input objects.

---

### BUG-029: Session-level import design details were not propagated into the durable docs (v7.4.5.0)

**Symptom:** The repo behavior for single-sensor merge import existed in firmware and dashboard logic, but the high-value explanation — epoch-to-slot mapping, overlay of one sensor into an existing segment, reuse of the same slot when possible, and ~7 KB temporary overhead — was not consistently carried into changelog and handoff documentation.

**Root cause:** Documentation captured the user-visible feature but not enough of the internal design rationale.

**Fix:** Expanded changelog, `Docs/configuring-sensors.md`, and the per-session handoff to explicitly describe the merge-first single-sensor import model and how it differs from full multi-sensor replacement.

**Lesson:** See LESSON-OPS-036.

---

### BUG-028: Sensor-count changes depended on four-file manual edits, creating configuration drift risk (v7.4.5.0)

**Symptom:** Changing sensor count or replacing a sensor required hand-editing `sensor_history_multi.h`, the firmware YAML, `dashboard.js`, and `tests/fixtures/sensors.json`. It was easy to update three files and miss the fourth, which produced confusing preflight failures or worse — a compile-valid repo whose dashboard fallback / test fixtures no longer matched the active firmware configuration.

**Root cause:** The repo had no canonical source of truth for configured sensors. The same facts (sensor id, display name, MAC, count) were duplicated in multiple files.

**Fix:** Introduced a canonical manifest (`config/sensors.json`) plus a generator (`scripts/render_sensor_config.py`) and an interactive manager (`scripts/change_sensor_number.py`). The renderer now drives generated sections in the header, firmware YAML, dashboard fallback metadata, and baseline fixture manifest.

**Guardrail:** `scripts/preflight.sh` now runs `python3 scripts/render_sensor_config.py --check` so generated-file drift is caught before compile.

**Lesson:** See LESSON-OPS-037.

---

### BUG-027: Chromium missing shared libraries in ESPHome container — libnspr4.so not found (v7.4.4.0)

**Symptom:** All Playwright tests fail with `error while loading shared libraries: libnspr4.so: cannot open shared object file`. The binary exists and `--no-sandbox` is in the launch args, but the process crashes at the dynamic linker stage.

**Root cause:** `npx playwright install chromium` downloads the Chromium binary but does NOT install the required OS-level shared libraries. The ESPHome Docker container does not include them by default.

**Fix:** Use `npx playwright install --with-deps chromium`. This installs both the binary and all required system packages via `apt`.

**Lesson:** See LESSON-OPS-034.

---

### BUG-026: Chromium crashes silently in ESPHome/Docker containers — sandbox kernel feature missing (v7.4.4.0)

**Symptom:** All Playwright tests fail immediately with `browserType.launch: Target page, context or browser has been closed` — even after a successful install. The browser binary exists but the process crashes on startup.

**Root cause:** Chromium's default sandbox uses Linux user namespaces, which are disabled in many container environments including the ESPHome Docker container.

**Fix:** Add `launchOptions: { args: ['--no-sandbox', '--disable-setuid-sandbox'] }` to the `use` block in `playwright.config.js`.

**Lesson:** See LESSON-OPS-033.

---

### BUG-025: Fixture generate-fixtures.js used milliseconds for CSV timestamps (v7.4.4.0)

**Symptom:** Sensor-count variant fixtures would render completely empty charts. No error — just no data points.

**Root cause:** `Date.UTC()` returns epoch milliseconds. The dashboard's chart renderer calls `new Date(epoch * 1000)` — interpreting the value as seconds. A millisecond timestamp gets multiplied by 1000, producing dates in year ~58000, which fall outside any time range filter and are silently dropped.

**Fix:** Use epoch seconds throughout `generate-fixtures.js`. Anchor to `ANCHOR_EPOCH_SEC = 1741694400`.

**Lesson:** See LESSON-OPS-029.

---

### BUG-024: Second round of browser test failures — DOM behavior mismatches (v7.4.3.0 CI)

**Symptom:** 4 of 28 tests failed on second CI run after element ID fixes.

**Root causes — three distinct issues:**
1. Canvas selector wrong container — chart canvases live inside `.chart-card` divs, not `.sensor-card`
2. Theme class applied to `document.documentElement` (`<html>`), not `document.body`
3. `_onPreset()` calls `_applyAndClose()` directly — clicking Apply after a preset attempts to click an already-dismissed modal

**Fixes:** Assert named chart IDs with `toBeAttached()`; change theme assertions to `page.locator('html')`; remove the Apply click after preset.

**Lesson:** See LESSON-OPS-028.

---

### BUG-023: Output bundle file naming caused confusion about destination paths (v7.4.3.0)

**Fix:** Files renamed and placed in correct locations after clarification.

**Lesson:** See LESSON-OPS-025.

---

### BUG-022: `package-lock.json` not committed — CI failed on `npm ci` (v7.4.3.0)

**Symptom:** Browser CI job failed immediately: `Dependencies lock file is not found`.

**Fix:** `npm install` on device, then `git add package-lock.json && git commit`.

**Lesson:** See LESSON-OPS-024.

---

### BUG-021: `browser-tests.yml` committed to wrong branch — workflow never appeared in CI (v7.4.3.0)

**Symptom:** GitHub Actions showed no "Browser Tests" workflow.

**Root cause:** Workflow file was committed on the wrong feature branch. GitHub only registers workflow files from the default branch.

**Fix:** `git log --oneline --all -- .github/workflows/browser-tests.yml` identified the commit. `git checkout <sha> -- .github/workflows/browser-tests.yml` recovered and committed it to the correct branch.

**Lesson:** See LESSON-OPS-023.

---

### BUG-020: Browser test suite used wrong element IDs throughout — 14 of 28 tests failed (v7.4.3.0)

**Root cause:** Tests were written against assumed element IDs without verifying the actual dashboard HTML. Six distinct mismatches:

| Used in test | Actual ID in HTML |
|---|---|
| `#themeToggle` | `#themeBtn` |
| `#crApply` | `#customRangeApply` |
| `#crCancel` | `#customRangeCancel` |
| `.card-title` | `.sensor-card-header` |
| `data-history-range="7d"` | `data-history-range="168"` |
| `button[hasText=Export]` count | `[data-export-all]` + `[data-export-sensor]` attributes |

**Fix:** Audited all element IDs against the actual HTML before writing tests.

**Lesson:** See LESSON-OPS-022.

---

### BUG-019: "Data available: unknown" in custom range dialog on freshly-flashed device (v7.4.2.0)

**Fix:** Three-state availability display: both bounds non-zero → range shown; only newest non-zero → "up to [newest]"; both zero → "No persisted history yet."

---

### BUG-018: Duplicate `<script>` tag caused `Unexpected token '<'` dashboard failure (v7.4.2.0)

**Fix:** `sed -i '859d' dashboard/dashboard.html`. Prevention: use `head -n $((SCRIPT_LINE - 1))`, not `head -n $SCRIPT_LINE`. Verify with `grep -c '^<script>$' dashboard/dashboard.html` — must return `1`.

---

### BUG-017: `MAX_HISTORY_RANGE_HOURS` was 720, silently truncating 45d history display (v7.4.2.0)

**Fix:** `MAX_HISTORY_RANGE_HOURS = 1080`.

---

### BUG-016: `html-minifier-terser` CLI flags wrong (v7.4.1.0)

**Fix:** Use positional input plus `--output`.

---

### BUG-015: Single-sensor import "Unknown sensor ID" — off-by-one in URL path parsing (v7.4.0.2)

**Fix:** Corrected prefix length comparison and pointer offset. Prefer `sizeof("literal") - 1` over hand-counted lengths.

---

### BUG-014: Single-sensor import erased all flash data (v7.4.0.2)

**Fix:** Added `POST /api/import/begin/single/<id>` and merge-first behavior.

---

### BUG-013: Import over Cloudflare returned HTTP 502 (v7.4.0.1)

**Fix:** Suspend non-essential background activity during import and add pacing/backoff.

---

### BUG-012: Single-sensor export schema mismatch (v7.4.0.1)

**Fix:** Standardized on prefixed column headers for all export formats.

---

### BUG-011: Non-JSON server response crashed import error handling (v7.4.0)

**Fix:** Added safer text-first JSON response handling.

---

### BUG-010: `time()` ambiguous in ESPHome context (v7.4.0)

**Fix:** Use `::time(nullptr)`.

---

### BUG-009: Import POST body never delivered (v7.4.0)

**Fix:** Moved import payload transport into the URL path. **URL path is the reliable data channel** on this stack.

---

### Earlier important fixes

- **BUG-008:** Switched dashboard serving away from `beginResponseStream()` panic path
- **BUG-007:** Abandoned LittleFS-hosted dashboard in favor of embedded payload
- **BUG-006:** Fixed dashboard startup / event-binding ordering issue
- **BUG-005:** Theme switch now forces chart redraw
- **BUG-004:** 15-minute markers normalized to the intended visual size
- **BUG-003:** Chart markers now follow recolor changes
- **BUG-002:** Export All serialized to avoid socket-pool overload
- **BUG-001:** `/api/status` JSON truncation fixed by splitting output formatting

---

## Operational Lessons

### LESSON-OPS-114 — When stubbing `window.requestManagementCredentials` in Playwright tests, stub before the click (2026-04-04)

**Context:** PR #129 Round 2 fix for the delete regression test (test 19). The original test
structure was:
1. Click the Remove button
2. `page.evaluate(() => window.requestManagementCredentials = ...)` to stub the function

This ordering failed because `dashboard.js` may invoke `requestManagementCredentials` synchronously
on the click event — before the `evaluate` promise resolves. The function stub never took effect,
the auth dialog was shown instead, the test timed out.

**Fix:** Stub `window.requestManagementCredentials` with `page.evaluate()` **before** triggering
any click that could invoke it. The correct sequence is:
1. `await page.evaluate(() => { window.requestManagementCredentials = ... })`
2. `page.on('dialog', handler)` if a browser dialog may also appear
3. Click the button

**Rule:** Any Playwright test that needs to stub a JS function called in response to a user
interaction must complete the stub BEFORE the interaction. Async evaluation (`page.evaluate`)
is not instantaneous — the click handler may fire between the click and the evaluate completing.
Stub-then-click is the only ordering that is deterministically safe.

**Applies to:** All Playwright tests that stub `window.requestManagementCredentials`,
`window.confirm`, or any other synchronously-invoked window function in `dashboard.js`.

---

### LESSON-OPS-113 — `page.waitForResponse()` with URL predicate is always preferable to `waitForTimeout()` for network-triggered state changes (2026-04-04)

**Context:** PR #129 initial implementation used `waitForTimeout(2000)` to wait for a poll cycle
to rerender the Settings panel. Round 1 review replaced it with `waitForTimeout(2000)` on the
grounds of simplicity. Round 2 review then correctly replaced all `waitForTimeout` calls with
`page.waitForResponse(url => url.includes('/api/aggregator/gateways'))` because:

1. The timeout is arbitrary — it may pass vacuously on fast CI or fail spuriously on slow CI.
2. The `waitForResponse()` call guarantees the network round-trip has completed, meaning the
   dashboard has received the response and had the opportunity to update state.
3. `waitForResponse()` is no more complex to write and is self-documenting about what event the
   test is actually waiting for.

**Rule:** Never use `waitForTimeout(N)` as a proxy for "wait for a network response to arrive."
Use `page.waitForResponse(urlPredicate)` instead. `waitForTimeout` is only appropriate when:
- testing that something does NOT happen within a time window
- adding intentional breathing room between user-input actions that are not network-gated

**Exception:** `waitForTimeout` may be used in regression tests that verify timing behavior
(e.g., confirming an action does not fire prematurely), but must be accompanied by a comment
explaining why a response-based wait is not sufficient.

---

### LESSON-OPS-112 — Response shape mismatch between mock and firmware contract (2026-04-04)

**Context:** PR #129 Round 2 — Mock `POST /api/aggregator/add-satellite` returned nested
`{ok, satellite:{id,name,url,poll}}`. The firmware handler's `httpd_resp_sendstr` payload is flat:
`{ok, id, name, satellite_count}`. Three test assertions also expected the wrong shape. The
mismatch survived all four review passes before being caught in the Round 2 review.

**Rule:** When implementing a mock endpoint, always locate the firmware handler's literal
`httpd_resp_sendstr(...)` call and copy the response JSON from there — not from the prompt
description, not from a prior audit table, not from memory. If any prompt example differs from
the live firmware string, the **firmware wins**. Verify both the field names and the nesting level
(flat vs nested). Tests that assert only status codes without checking response body shape will
miss this class of mismatch entirely.

**Scope:** Applies to all mock implementations in `tests/mock-server/server.js` and any future
mock infrastructure added in Phase 7.

---

### LESSON-OPS-111 — Captured DOM references become stale across innerHTML re-renders (2026-04-04)

**Date:** 2026-04-04
**Scope:** Dashboard JS — async handlers, settings panel
**Trigger:** PR #128 Copilot review comments r3034831162, r3034831171

**Lesson:**
Capturing a DOM element reference before an async operation (e.g.,
`var el = document.getElementById(...)`) is unsafe if any code path can replace the
containing element's `innerHTML` before the async callbacks fire. The captured reference
remains a valid JS object but is detached from the live document; writes to `.textContent`
or `.classList` succeed silently with no visible effect.

**Rule:** In async callbacks that update UI status, always re-query by stable `id` at
write time:
```js
var liveEl = document.getElementById('known-stable-id');
if (liveEl) liveEl.textContent = '...';
```

**Companion rule:** Any periodic re-render (timer, poll loop) that replaces `innerHTML`
must guard against active user interaction (focused inputs, in-flight async state) before
tearing down the DOM:
```js
var urlInput  = document.getElementById('sat-url-input');
var nameInput = document.getElementById('sat-name-input');
var inputFocused = (document.activeElement === urlInput ||
                    document.activeElement === nameInput);
if (!_satTestInFlight && !_satAddInFlight && !_satRemoveInFlight && !inputFocused) {
  renderSettingsPanel(data.gateways);
}
```
See BUG-080/BUG-081 and the PR #128 follow-up for the full guard pattern.

---

### LESSON-OPS-104: Always use `std::string`, never Arduino `String` or bare `string`, in ESP-IDF code (2026-04-01)

The coding agent's sandbox does not perform ESP-IDF compilation — it runs
Playwright tests and preflight checks only. Arduino-isms like `String` (capital S)
pass all CI checks but break the real build. When manually fixing, bare `string`
(no namespace) also fails because this codebase has no `using namespace std;`.

**Rule:** In all `.h`/`.cpp` files compiled under ESP-IDF: always use `std::string`,
`std::vector`, etc. Never rely on `using namespace std`. Treat any capital-S
`String` in agent-generated code as a review red flag during PR review.
Codified as Critical Rule 44.

---

### LESSON-OPS-103: Local component `init_response_()` must map all HTTP status codes used by handlers (2026-04-01)

The `web_server_idf` local component override (`firmware/local_components/web_server_idf/`)
contains a `switch(code)` in `init_response_()` that maps integer status codes to
`httpd_resp_set_status()` strings. If a handler uses a status code not in the switch,
the response silently becomes HTTP 500 regardless of the JSON body content.

**Rule:** After running `scripts/patch-esphome-httpd-stack.sh` (which copies
upstream and re-applies only the stack patch), manually verify that
`init_response_()` still contains the expanded status code switch with the
`snprintf` fallback. The upstream copy may overwrite the expanded switch.
Consider adding a verification step to the patch script.
Codified as Critical Rule 43.

---

### LESSON-OPS-102


### LESSON-OPS-102: ESPHome httpd stack must be patched via local component override (2026-03-31)

Because `CONFIG_HTTPD_STACK_SIZE` is inert (LESSON-OPS-100), the only way to
increase the httpd task stack is to override ESPHome's `web_server_idf` component
locally. The script `scripts/patch-esphome-httpd-stack.sh` copies the upstream
component into `firmware/local_components/web_server_idf/` and patches
`config.stack_size = 16384` into `AsyncWebServer::begin()`. Board profiles must
include an `external_components` block pointing to `local_components`. The script
must be re-run after every ESPHome version upgrade. Use `--check` to verify.
Codified as Critical Rule 42.

---

### LESSON-OPS-101: Deferred task pattern for NVS-heavy HTTP handlers (2026-03-30)

HTTP request handlers share the httpd task's 4 KB stack. Any handler performing
NVS operations, mutex acquisition, or substantial string work will overflow it.
Use the deferred task pattern: handler authenticates, sends HTTP response, then
calls `xTaskCreate` to spawn a task (minimum 8192 bytes for NVS work) that does
the heavy lifting. The spawned task must call `vTaskDelete(nullptr)` when done.
This is the pattern already used by `schedule_reboot_()` / `reboot_task_`.
Minimum task stack for NVS operations: 8192 bytes. Add
`uxTaskGetStackHighWaterMark()` logging before release to confirm sizing.

---

### LESSON-OPS-100: ESPHome httpd task stack is hardcoded at 4 KB — CONFIG_HTTPD_STACK_SIZE has no effect (2026-03-30)

`HTTPD_DEFAULT_CONFIG()` in ESP-IDF hardcodes `.stack_size = 4096` as a literal.
ESPHome's `web_server_idf.cpp` never overrides this. `CONFIG_HTTPD_STACK_SIZE` in
`sdkconfig_options` is completely inert — do not add it to any board profile.
The only way to increase the httpd stack is via a local ESPHome component override
(see LESSON-OPS-102). NVS-heavy handlers must additionally use the deferred task
pattern (see LESSON-OPS-101). Codified as Critical Rules 40, 41, and 42.

---

### LESSON-OPS-099: ESPHome IDF httpd only consumes x-www-form-urlencoded POST bodies (2026-03-30)

ESPHome's `web_server_idf` component only reads POST body bytes for
`Content-Type: application/x-www-form-urlencoded` and `multipart/form-data`.
For `application/json`, it logs "Unsupported content type for POST" and routes
to the GET handler path without consuming body bytes. Unconsumed bytes corrupt
socket state when the response is sent. All dashboard POST calls and curl POST
commands must use `Content-Type: application/x-www-form-urlencoded` with
`body: 'a=1'`. Codified as Critical Rules 38 and 39.

---

### LESSON-OPS-098: `sdkconfig_options` must be updated in board profiles, not only templates (2026-03-30)

For multi-board builds, generated YAMLs inherit `sdkconfig_options` from `firmware/boards/*.yaml`. Updating only a template YAML can appear to fix one local build while leaving other board builds unchanged. Apply socket/stack changes to all relevant board profiles and verify generated outputs before release testing.

---

### LESSON-OPS-097: Never commit generated artifacts while operator configs are present (2026-03-30)

When local operator config files (`config/gateway.json`, `config/aggregator.json`) are present, running `render_sensor_config.py --write` can produce environment-specific generated files that diverge from CI defaults. Move operator configs aside before generating commit-bound artifacts to prevent accidental local-state leakage.

---

## LESSON-OPS-096 — Boot-time init vs runtime mutation mutex ordering (v7.6.0.0)

**Context:** `init_satellite_caches_()` in v7.6.0.0 runs without acquiring `s_cache_mutex`. The ESPHome startup sequence guarantees `aggregator_poll_task()` init completes before the web server accepts connections, so the current implementation is safe. However, the absence of a mutex creates technical debt if startup ordering ever changes.

**Status:** Accepted as technical debt for v7.6.0.0. For v7.6.0.1+, any code added during init must be verified to run before web handlers can fire. Future consideration: wrap init in the same mutex for defense-in-depth once runtime mutators are active.

Any significant dashboard or data-path modification should re-check:

- Startup ordering
- Event binding
- Theme redraw
- Chart marker/background/border consistency
- History/min-max calculations
- Export All concurrency behavior
- SSE and polling behavior
- Import over LAN
- Import over Cloudflare
- Browser compatibility across the major test targets
- Dashboard manifest boot sequence (primary `/api/manifest`, fallback `/sensors.json`, fallback built-in defaults)
- Both custom dashboard and built-in ESPHome web page diagnostics (Free Heap, Uptime, Loop Time)

---

## LESSON-OPS-095 — All-or-nothing NVS array load must be explicit in prompt (v7.6.0.0)

**Context:** v7.6.0.0 prompt said `load_satellites_from_nvs_()` "returns 0 if NVS is empty or corrupt" but did not define what "corrupt" means for partial reads within a counted array. The agent used `break` on per-entry NVS read failure, silently truncating the satellite list at the first bad entry.

**Fix (PR #99):** On any per-entry read failure, the function now closes the NVS handle and returns 0, triggering full fallback to compile-time defaults.

**Rule:** Prompts for NVS array loading must specify: "On any per-entry read failure (`nvs_get_str`, `nvs_get_u16` returning non-`ESP_OK`), close the NVS handle and return 0. Partial loads are worse than no load — they create invisible topology shrink."

---

## LESSON-OPS-094 — NVS seeding on first boot must be explicit in prompt (v7.6.0.0)

**Context:** v7.6.0.0 prompt said "if NVS count key is absent, populate from compile-time arrays" but did not say "and write them to NVS." The agent loaded compile-time defaults into the cache but did not persist them to NVS. The first runtime mutation (add/remove) would write only the delta; on reboot, all compile-time defaults were lost.

**Fix (PR #99):** `init_satellite_caches_()` now calls `save_satellites_to_nvs_()` after loading compile-time defaults as fallback.

**Rule:** When NVS is the single source of truth for runtime data that starts from compile-time defaults, prompts must explicitly state: "After loading compile-time defaults into the cache, call `save_satellites_to_nvs_()` to seed NVS. This prevents the first runtime mutation from orphaning the defaults."

---

## LESSON-OPS-093 — Management endpoints must have explicit auth requirement in prompt (v7.6.0.0)

**Context:** v7.6.0.0 prompt added `POST /api/system/reset-satellites` without specifying that it must call `authenticate_management_()`. The agent implemented the endpoint without authentication. The Copilot reviewer caught it during PR review; fixed in PR #99.

**Root cause:** Security conventions from neighbouring code are not inherited by the coding agent. Every other management endpoint in the codebase calls `authenticate_management_()`, but the agent did not infer this pattern.

**Rule:** Every prompt that adds a destructive or persistent-state-mutating endpoint must explicitly state: "This endpoint MUST call `authenticate_management_()` as the first action." For non-destructive endpoints (e.g. add-satellite), the prompt must explicitly state whether auth is required or not, with a rationale.

---

## LESSON-OPS-092 — NVS key buffer sizing must be explicit in prompts (v7.6.0.0)

**Context:** v7.6.0.0 prompt specified the NVS key scheme (`s{i}_id`, `s{i}_name`, etc.) but not buffer sizes for key construction variables. The coding agent chose `char key_*[8]`, which overflows for satellite indices ≥ 10 (e.g. `s10_name` = 8 chars + NUL = 9 bytes).

**Fix (PR #99):** All NVS key buffers changed to `char key_*[16]`. NVS max key length is 15 chars + NUL = 16 bytes.

**Rule:** When a prompt specifies an indexed NVS key scheme, it must explicitly state the buffer size for key construction. Use `char key_*[16]` for all NVS key buffers and state this in prompt code blocks.

---

## LESSON-OPS-091 — Regeneration pipeline must include dashboard minification before header generation (v7.6.0.0)

**Context:** The regeneration pipeline documented in prompts and `Docs/aggregator-setup.md` listed four steps: `render_sensor_config.py --write`, `generate-fixtures.js`, `generate-header.sh`, and `render_sensor_config.py --check`. The `minify-dashboard.sh` step was absent from all references.

**Root cause:** `generate-header.sh` auto-detects `dashboard.min.html` and uses it if present, falling back to unminified `dashboard.html` otherwise. This "silent fallback" masked the missing step — the build succeeds either way, but produces a larger firmware payload without minification. More dangerously, if a stale `dashboard.min.html` exists from a previous run, the header embeds the outdated minified copy instead of the current source.

**Fix:** Added `bash scripts/minify-dashboard.sh` as Step 3 in the regeneration pipeline (after fixture generation, before header generation) in `Docs/aggregator-setup.md` Sections 7.1 and 15, and in all Phase D prompt device testing sections.

**Rule:** The canonical regeneration pipeline is five steps in this exact order:

1. `python3 scripts/render_sensor_config.py --write`
2. `node tests/fixtures/generate-fixtures.js`
3. `bash scripts/minify-dashboard.sh`
4. `bash scripts/generate-header.sh`
5. `python3 scripts/render_sensor_config.py --check`

Any prompt or documentation that references "the regeneration pipeline" must include all five steps. Omitting the minification step risks stale embedded dashboard content.

**Critical Rule 37 added.**

---

## LESSON-OPS-090 — Device testing sections must reference the correct generated YAML for the target board (v7.6.0.0)

**Context:** All six Phase D prompt device testing sections (v7.6.0.0 through v7.6.0.5) contained `esphome clean firmware/esp32-c3-multi-sensor.yaml` and `esphome run firmware/esp32-c3-multi-sensor.yaml` in the aggregator build instructions. This is the committed C3 satellite template — it does not produce aggregator firmware and targets the wrong chip architecture for S3 boards.

**Root cause:** The prompt author wrote the device testing section by copying the C3 compile command (the only committed YAML) without accounting for the fact that non-C3 boards use **generated** YAML files that only exist after `render_sensor_config.py --write`. The generated S3 YAML is `firmware/esp32-s3-devkitc1-n16r8-gw.yaml` — it is gitignored and not visible in the repo file listing.

**Impact:** The operator compiled C3 satellite firmware and flashed it to the S3 aggregator. The device booted as a satellite with all local sensors displayed instead of as an aggregator with the Gateways card. Device testing could not proceed.

**Fix:** Corrected all Phase D prompts to reference `firmware/esp32-s3-devkitc1-n16r8-gw.yaml` for aggregator builds. Added Section 7.2 "Which YAML Do I Compile?" decision table to `Docs/aggregator-setup.md`.

**Rule:** Prompt device testing sections must use the exact YAML path that the generator produces for the target board. For non-C3 boards, this is always a **generated** gitignored file — never the committed C3 template. The correct path can be determined from the `get_yaml_output_path()` function in `render_sensor_config.py` or from the output of `render_sensor_config.py --write`.

**Critical Rule 36 added.**

---

## LESSON-OPS-089 — Unauthenticated constructive mutation endpoints need explicit rationale (2026-03-31)

**Context:** v7.6.0.1 `POST /api/aggregator/add-satellite` does not call `authenticate_management_()`,
unlike neighboring destructive endpoints.

**Policy decision:** Constructive mutation (adding a new satellite) is deliberately unauthenticated
in v7.6.0.1. An attacker on the LAN could add a rogue satellite and redirect polling, but cannot
delete or corrupt existing data. This is an acceptable risk for a LAN-only device in the current
deployment model.

**Required action before any internet-facing deployment:** Add auth to all runtime-management
mutation endpoints (add/delete/test-satellite) in Phase E or a dedicated security hardening step.

**Prevention:** Any future endpoint that mutates runtime/NVS state must explicitly declare in a
code comment whether auth is required and why. If omitted, auth is assumed required.

---

## LESSON-OPS-089-LEGACY — Preflight checks must be environment-aware

**Context:** Historically (before PR #96), `scripts/preflight.sh` hardcoded `check_contains "fixture_manifest_sensor_count" tests/fixtures/manifest.json '"sensor_count": 5'`. This was correct for the C3 satellite profile (3 ThermoPro + wan_ping + nas01 = 5 sensors) but broke when `config/gateway.json` pointed to the S3 aggregator sensor file (`config/sensors-agg-s3-16m-1.json`) which has only 1 sensor (wan_ping).

**Root cause:** The preflight check assumed all deployments had the same sensor count. When multi-board support was added (v7.5.5.0), the check was not updated to handle board-specific sensor manifests.

**Fix (PR #96):** Replaced the hardcoded value with a Python snippet that uses `sensor_manifest_lib.load_gateway_config()` and `load_manifest()` to dynamically compute the expected count — the exact same resolution logic as `render_sensor_config.py`. Errors fail loudly (no silent fallback). The `# Do NOT re-hardcode` comment guards against regression.

**Rule:** Preflight validation checks that depend on configuration-derived values (sensor count, device names, gateway metadata) must compute expected values dynamically using the same library functions as the generators. Never hardcode values that vary by board profile, sensor manifest, or deployment configuration.

---

## LESSON-OPS-088 — Mandatory deliverable tables should be templated with placeholder rows (v7.5.7.0)

**Version:** v7.5.7.0
**Source:** PR #93 — prompt required Instruction Compliance Output table (§8b) but the agent omitted it from the session log entirely.

When a prompt requires a specific table as a deliverable (e.g., Instruction Compliance Output), include a template with placeholder rows in the session log section. An empty template is harder to overlook than a prose instruction to "provide a table."

**Rule:** The session log section of any prompt that requires a compliance table must include a template with at least one placeholder row, not just the table header.

---

## LESSON-OPS-087 — Prompt-provided code blocks must apply the same constant policy as the target codebase (v7.5.7.0)

**Version:** v7.5.7.0
**Source:** PR #93 — prompt introduced C++ named constant `AGG_MANIFEST_BUF_SIZE` but provided Python code with bare literal `8192`.

When a prompt introduces a named constant in one language (C++ `AGG_MANIFEST_BUF_SIZE`), the corresponding value in prompt-provided code for another language (Python) should also use a named constant, not a bare literal. The agent copies prompt code faithfully — including inconsistencies. The Gemini reviewer caught the mismatch and it was fixed in the fixup commit by extracting `SATELLITE_CAP_PSRAM = 8` and `AGG_MANIFEST_BUF_SIZE_BYTES = 8192` as module-level constants.

**Rule:** Before publishing a prompt that contains code blocks in multiple languages, verify that each named constant defined in language A has a corresponding named constant (not a literal) in language B.

---

## LESSON-OPS-086 — Prompt Do-NOT lists must exclude expected regeneration side-effects (v7.5.7.0)

**Version:** v7.5.7.0
**Source:** PR #93 — Do-NOT list said "no dashboard JS/HTML changes" but `bump-version.sh` necessarily updates `App.version` in those files.

When a prompt says "Do NOT change file X" but also requires a version bump or regeneration pipeline that necessarily touches file X, the prompt contains an internal contradiction. The agent correctly ran the bump (version churn is expected), but the Do-NOT list was technically violated.

**Rule:** Future prompts should qualify: "No *functional* changes to file X; version bump and regeneration churn is expected and does not violate this rule."

---

### LESSON-OPS-085: Validate fetched content wasn't truncated before embedding in composed JSON responses (2026-03-28)

When composing a JSON response from cached or proxied upstream payloads, never assume a fixed-size fetch buffer captured a complete document. If `fetch_to_buffer()` (or equivalent) reaches `buf_size - 1`, treat the payload as likely truncated and do not embed it verbatim.

For aggregator manifests specifically, guard with `manifest_len >= AGG_MANIFEST_BUF_SIZE - 1` and emit `"manifest":null` plus a warning log. This preserves valid top-level JSON and prevents one oversized satellite payload from breaking the entire `/api/aggregator/gateways` response.

---

## LESSON-OPS-083 — Playwright test signatures must not include unused fixture arguments (v7.5.6.4)

**Version:** v7.5.6.4
**Source:** PR #87 review comment (Gemini r2997248086) — test `/api/v2/live returns system device data` destructured `{ page, request }` but only used `request`.

When writing a Playwright test that only uses the `request` fixture (e.g., a pure API test), do not include `page` in the destructured argument list. Including `page` forces Playwright to create a browser context even when it is not needed, wasting ~1–2 s per test run.

**Rule:** Every test function signature must destructure only the fixtures it actually uses. Before merging, scan all new tests for unused Playwright fixture arguments.

---

## LESSON-OPS-082 — Fixture composition changes require downstream text audit (v7.5.6.4)

**Version:** v7.5.6.4
**Source:** PR #87 — mixed fixture gained `nas01` (3 → 4 sensors) but skip-reason strings referencing "3 sensors" remained in multiple locations.

When a prompt changes a fixture's sensor count or composition:
1. The prompt MUST include an explicit instruction: "After updating the fixture, search all `test.skip()` reason strings in `dashboard.spec.js` for references to the old sensor count and update them."
2. The prompt MUST also flag any group header comments that describe the fixture by composition.

A fixture change is not complete until all downstream text references to that fixture's old composition are updated.

---

## LESSON-OPS-081 — Mock endpoint prompts must enumerate all firmware validation branches (v7.5.6.4)

**Version:** v7.5.6.4
**Source:** PR #87 — mock `/api/ingest` required 2 fix commits because the prompt only specified device validation, not metric/val validation.

When a prompt asks the agent to create a mock endpoint for an existing firmware API, the prompt MUST:
1. Name the firmware function to read (e.g., `handle_api_ingest_()`)
2. Enumerate all positive and negative validation branches
3. Specify exact response shapes for success (`{"ok":true}`) and failure (`{"ok":false,"message":"...","status":N}`)
4. Require one test per branch
5. Explicitly prohibit stub-level mocking: "Do NOT reduce this mock to a 'device exists → 200' stub"

A mock that only validates device existence is a stub, not a contract-faithful implementation. It hides client-side bugs and causes merge-blocking review comments.

---

## LESSON-OPS-080 — System fixture skip guards (v7.5.6.4)

**Version:** v7.5.6.4
**Symptom:** After adding the `system` fixture variant (2 env + 1 net + 1 sys = 4 sensors),
7 existing tests failed because they assumed the 3sensor-specific sensor list
(`office`, `first_floor`, `outside`) or expected exactly 3 env sensors.

**Skip guards added (v7.5.6.4):**
- `2. Sensor cards / sensor card headers contain expected sensor names` — 'Outside' absent from system fixture
- `14. Phase 2 Closure / scenario 1` — 'Outside' name check is 3sensor-specific
- `14. Phase 2 Closure / scenario 2` — sensors.json fallback count (3) is 3sensor-specific; system has 2 env entries
- `14. Phase 2 Closure / scenario 4` — `envSensors.length === 3` is 3sensor-specific; system has 2 env sensors
- `15. Phase 3 Closure / dashboard renders identically` — 'Outside' name check is 3sensor-specific
- `17. Phase 4 Step 2 / environmental cards have full ThermoPro layout` — `.sensor-card:not(.network-card)` includes system card which lacks `.sensor-env-grid`
- `manifest.spec.js / dashboard falls back to /sensors.json` — fallback sensor list is 3sensor-specific

**Prevention:** When adding a new fixture variant, always run `FIXTURE_SET=<new> npx playwright test --project=chromium` (full suite, no `--grep`) to discover incompatibilities before merging.

---

### LESSON-OPS-079 — Fixture variants must include all device categories (deferred to v7.5.6.4)

**Version:** v7.5.6.1
**Symptom:** Fixture variants (3sensor, mixed, 4sensor) include system metrics in the
top-level `metrics` array but do not include an `external_push` device in `sensors`.
The system device manifest/measurement/history-stub code paths are only exercised
by the baseline fixture, not by any Playwright test variant.
**Root cause:** v7.5.6.1 scope was limited to firmware/manifest side. Test fixture
variant updates are deferred to v7.5.6.4 (Phase 6 closure).
**Fix:** v7.5.6.4 must add `nas01` to at least the `mixed` variant sensor list and
add Playwright assertions for system device presence in manifest + v2/live shape.

---

### LESSON-OPS-078: Keep manifest tests shape-aware, not hard-coded to old metric sets

When categories/metrics are expected to grow over phases, assertions should verify
required subsets and invariants (e.g., environmental metrics must still exist)
instead of strict full-array equality to legacy values.

---

### LESSON-OPS-077: api-status.json fixture requires generator-produced free_heap fields — never manually edit (2026-03-25)

**Context:** The root fixture `tests/fixtures/api-status.json` must contain `free_heap`,
`free_heap_internal`, and `free_heap_total` fields. These fields are produced by
`render_sensor_config.py --write` (template at line ~1228) and validated by `--check`.
The variant fixture generator (`generate-fixtures.js`) was missing these fields until
this fix.

**Failure pattern:** Across PRs #68, #69, #70, #72, and #73, coding agents either
manually edited `api-status.json` (stripping the fields) or ran `--write` in an
environment where the output differed from CI expectations. Each occurrence required
fix-up commits, making this the single most expensive recurring regression in Phase 5.

**Root cause:** Two generators produce `api-status.json` files:
- `render_sensor_config.py` produces the root fixture — included `free_heap` in template
- `generate-fixtures.js` produces variant fixtures — did NOT include `free_heap`

When agents ran `generate-fixtures.js --overwrite-baseline`, it would overwrite the root
fixture without `free_heap`, breaking `--check`. Conversely, when agents manually edited
the root fixture for version bumps instead of running `--write`, they often dropped fields.

**Fix (v7.5.5.5-hotfix):**
1. Added `free_heap` fields to `generate-fixtures.js` api-status template
2. Added preflight guards: `fixture_api_status_has_free_heap`, `_internal`, `_total`
3. Established Critical Rule 28: version bumps require both generators + verification

**Rule:** NEVER manually edit `tests/fixtures/api-status.json` or any variant fixture.
Always use the generators:
```bash
python3 scripts/render_sensor_config.py --write    # root fixtures
node tests/fixtures/generate-fixtures.js           # variant fixtures
python3 scripts/render_sensor_config.py --check    # verify
grep -q "free_heap" tests/fixtures/api-status.json # sanity check
```

**Detection:** `render_sensor_config.py --check` fails. Preflight guards
`fixture_api_status_has_free_heap*` fail.

Related: BUG-062, LESSON-OPS-072

**Context:** The v7.5.5.4 prompt example showed `"live": "{...JSON string...}"` in
`aggregator-live.json`. This is the actual wire format from the firmware (the satellite's
cached `/api/v2/live` response is stored as a raw string in `SatelliteCache`).

**Rule:** When the mock server serves `aggregator-live.json`, the test sees `gwLive.live`
as whatever JSON value the file contains. The dashboard's `_populateGatewayDeviceLive()`
checks `gwLive.live.devices` directly — it does NOT call `JSON.parse()` on the live field.
Therefore the fixture MUST use a JSON object `{ "devices": {...} }`, not a JSON string.

If the firmware ever changes to ship a pre-parsed object in the aggregator live endpoint,
this remains correct. If the API changes to ship a string, the fixture and/or code must
both change together.

**Detection:** Tests 7 and 8 (env + network live values) stay in "—"/waiting state if
the live field is a string instead of an object.

---

### LESSON-OPS-076: Aggregator fixture `manifest` block must use `sensors` array (v2 format) (2026-03-25)

**Context:** The v7.5.5.4 prompt example showed `"devices": {}` (object) inside the
cached gateway manifest in `aggregator-gateways.json`. The satellite manifest v2 format
uses a `sensors: [...]` array. `renderGatewayDevices()` checks `manifest.sensors` and
returns "No device data available" if it's absent or empty.

**Rule:** Embedded gateway manifests in `aggregator-gateways.json` must use the standard
v2 manifest format: `"sensors": [{ "id": ..., "name": ..., "category": ... }]`.

**Detection:** "No device data available" displayed in gateway device view despite fixture
containing manifest data.

---

### LESSON-OPS-074: Aggregator boot must be a superset of satellite boot, never a fork (2026-03-25)

**Context:** The v7.5.5.3 aggregator boot path was implemented as an if/else branch that replaced the satellite pipeline entirely. The aggregator loaded the manifest and called `initAggregatorDashboard()` but skipped local sensor cards, SSE/polling, storage stats, telemetry, and history. This broke every local feature on the aggregator device.

**Rule:** Per Principle 1 ("roles are capability tiers"), the aggregator boot path must be: run the full satellite pipeline first, then overlay aggregator UI at the end. Never fork the boot path into separate branches where one skips the other's functionality. The aggregator is a satellite with aggregation ON TOP, not a different product.

**Pattern:**
```javascript
// CORRECT: unified pipeline + overlay
detectAggregatorMode().then(function(isAgg) {
  // ... full satellite pipeline (manifest, cards, charts, SSE, stats, history) ...
  if (isAgg) initAggregatorDashboard(); // overlay at the end
});

// WRONG: forked pipeline
if (isAgg) { /* aggregator-only path — skips satellite */ }
else { /* satellite-only path */ }
```

**Applies to:** All future dashboard boot flow changes, any new role additions.

Related: BUG-064, BUG-065


### LESSON-OPS-073: LXC USB passthrough requires chmod after every device reconnect (2026-03-23)

**Context:** In unprivileged Proxmox LXC containers, bind-mounted USB devices (`/dev/ttyACM0`) lose permissions when the device disconnects and reconnects — which happens when entering download mode, after board reset, or after flashing. The host creates a fresh device node with default permissions that the container's unprivileged user cannot access.

**Rule:** Either install a udev rule on the Proxmox host that sets `MODE="0666"` for ESP32 vendor IDs (`303a:1001` for S3 USB-JTAG, `10c4:ea60` for CP2102, `1a86:7523` for CH340), or flash directly from the host by navigating to the container's rootfs path. The udev rule is the permanent fix; manual `chmod 0666 /dev/ttyACM0` is the per-flash workaround.

**Applies to:** Any LXC-based ESPHome setup with USB-connected boards.

Related: BUG-061

---

### LESSON-OPS-072: `esp_get_free_heap_size()` includes PSRAM on boards that have it (2026-03-23)

**Context:** The S3 aggregator reported 8.4 MB free heap via `/api/status`, which is correct (it includes PSRAM) but misleading when compared to C3 values (~70 KB, internal SRAM only). Monitoring dashboards and health checks that threshold on free heap will behave differently across board types.

**Rule:** Always report both internal and total heap separately. Use `esp_get_free_internal_heap_size()` for internal SRAM (comparable across all boards) and `esp_get_free_heap_size()` for total (includes PSRAM where available). The `/api/status` endpoint should expose `free_heap` (internal, backward-compatible), `free_heap_internal`, and `free_heap_total`.

Related: BUG-062

---

### LESSON-OPS-071: Module-level imports for optional dependencies must be lazy (2026-03-23)

**Context:** `import yaml` at the top of `sensor_manifest_lib.py` crashed the satellite workflow on systems without PyYAML, even though PyYAML was only needed for the `load_board_profile()` function which satellites never call.

**Rule:** If a Python module is only needed by one function (e.g., `yaml` for `load_board_profile()`), import it inside that function, not at the top of the file. Top-level imports break all callers of the module, even those that never use the optional dependency. This is especially important in ESPHome containers where pip packages beyond the standard library are not guaranteed.

Related: BUG-060

---

### LESSON-OPS-070: All ESP32 partition tables must have ota_0 at 0x10000 (2026-03-23)

**Context:** PlatformIO/esptool writes the application binary to offset 0x10000 regardless of what the partition table says. The S3 partition table had ota_0 at 0x20000 (due to oversized NVS), which meant the bootloader looked for the app at the wrong address.

**Rule:** In every partition table for any ESP32 variant (C3, S3, C5, C6, WROOM), `ota_0` must start at `0x10000`. This is non-negotiable. The fixed items (NVS at 0x9000/0x4000, otadata at 0xD000/0x2000, phy_init at 0xF000/0x1000) must fit before 0x10000 with no overlap. Preflight must validate: `grep ota_0 partitions/*.csv` → offset must be `0x10000` for every file.

**Applies to:** All current and future partition tables.

Related: BUG-061

**Date:** 2026-03-22

When creating a new generated header file (e.g., `src/aggregator_config.h`) that is `#include`d
from an existing ESPHome-managed header (`sensor_history_multi.h`), the new file must ALSO be
added to the `includes:` list in `firmware/esp32-c3-multi-sensor.yaml`. ESPHome only copies
files listed in `includes:` into its build directory — without this entry, the compiler cannot
find the header even though the `#include` directive is syntactically correct.

**Discovered during:** v7.5.5.0 implementation. The first commit added `#include "aggregator_config.h"`
to `sensor_history_multi.h` and generated `src/aggregator_config.h`, but did not add
`../src/aggregator_config.h` to the YAML `includes:`. CI compilation failed. A second commit
was required to fix it.

**Rule:** When any implementation step creates a new header file under `src/` or `dashboard/`,
immediately check `firmware/esp32-c3-multi-sensor.yaml` `includes:` and add the new file path
there. Treat the YAML includes list as part of the same atomic change as the `#include` directive.

**Prevention:** Add a preflight check in a future step that cross-references all `#include` directives
in ESPHome-managed headers against the YAML `includes:` list.

Related: v7.5.5.0 PR #62

---

### LESSON-OPS-069: Interval-based "due" checks must handle the never-succeeded case (2026-03-23)

**Context:** A common pattern for periodic tasks is `bool due = (last_run == 0) || (now - last_run >= interval)`. The `== 0` clause handles the "first run" case. But if the first run FAILS and `last_run` is never set, the task retries on every loop iteration regardless of the interval — the backoff is dead code.

**Rule:** When a periodic operation fails and the timestamp was never set (still 0), set it to `now` so the interval starts counting — but only after the failure threshold is crossed. Seeding too early (on first failure) prevents legitimate retries during transient conditions like boot-order races. The seeding should be coupled with the state transition (e.g., "declared unreachable"), not with every individual failure. Additionally, interval tracking should use monotonic time (e.g., `esp_timer_get_time()`), not wall-clock time (`::time(nullptr)`), because wall-clock may be 0 before SNTP sync — making any `== 0` sentinel check unreliable. This applies to any pattern where:
1. A timestamp field starts at 0 (meaning "never done")
2. The timestamp is only updated on success
3. A backoff/interval check uses the timestamp

**Applies to:** Aggregator polling task, any future periodic fetch/sync operations.

Related: BUG-058

---

### LESSON-OPS-068: Use lwip_*() prefixed functions, not BSD socket aliases, in ESPHome C++ code (2026-03-22)

**Context:** ESPHome defines `namespace esphome::socket` which collides with lwIP's BSD-compatible inline wrappers (`socket()`, `connect()`, `close()` etc.). This is not visible when reading lwIP documentation because the aliases work fine in standalone ESP-IDF projects — the collision only appears inside the ESPHome build environment.

**Rule:** In any C++ code that runs inside ESPHome (headers included via YAML `includes:`), always use the `lwip_*` prefixed function names for socket operations:
- `lwip_socket()` not `socket()`
- `lwip_connect()` not `connect()`
- `lwip_send()` not `send()`
- `lwip_recv()` not `recv()`
- `lwip_close()` not `close()`
- `lwip_setsockopt()` not `setsockopt()`
- `lwip_getaddrinfo()` not `getaddrinfo()` (already used by PingAdapter)
- `lwip_freeaddrinfo()` not `freeaddrinfo()` (already used by PingAdapter)

**Applies to:** All current and future code that uses lwIP sockets — aggregator polling, history proxy, any future HTTP client code.

Related: BUG-057, PR #64

---

### LESSON-OPS-066: Build pipelines with intermediate artifacts must re-derive them on version bumps (2026-03-21)

**Date:** 2026-03-21

When a build pipeline has a chain like `source.html → minified.min.html → header.h`, a version
bump that only updates `source.html` leaves `minified.min.html` stale. If the next step
(`generate-header.sh`) auto-selects the minified file, it embeds the old version.

**Rule:** Any script that bumps version strings must re-derive ALL intermediate build artifacts
in the chain before generating final outputs. If a tool in the chain is optional (e.g.,
`html-minifier-terser` may not be installed), the script must either re-run the tool or
delete the stale intermediate so downstream scripts fall back to the updated source.

Related: BUG-055

---

### LESSON-OPS-065: CSS for native browser widgets (`<input type=date>`, `<select>`) needs `color-scheme` (2026-03-21)

**Date:** 2026-03-21

Native HTML form elements like date pickers and select dropdowns are rendered by the browser,
not by your CSS. Setting `background` and `color` on them changes the input field appearance
but does NOT change the popup calendar or dropdown list appearance. The `color-scheme: dark`
CSS property tells the browser to render these native widgets in dark mode.

**Rule:** When building dark-mode UIs, always add `color-scheme: dark` to `<input type=date>`,
`<select>`, and other native form elements. Add `:root.light` overrides with `color-scheme: light`.

Related: BUG-054

---

### LESSON-OPS-064: Adding a new device category requires an endpoint audit (2026-03-21)

**Date:** 2026-03-21

When a new device category is added to the system (e.g., Phase 4 added `network` alongside
`environmental`), ALL existing endpoints must be audited for category assumptions. Endpoints
written before the category system existed will silently output incorrect data for new
categories.

**Specific endpoints that need audit when adding a category:**
- `/sensors.json` — v1 projection: should only include environmental devices
- `/api/status` — per-device fields must be category-appropriate (no `temp_valid` for ping devices)
- `/api/v2/live` — verify non-environmental devices have correct metric keys
- `/history/{id}/{metric}` — verify 404 for non-environmental history paths
- `/api/storage-stats` — verify counts only reference environmental persistence

**Rule for phase prompts:** When a prompt introduces a new device category, include an
"Endpoint Audit Checklist" section that lists every existing endpoint and its expected
behavior for the new category. Coding agents will not proactively check endpoints they
were not told to modify.

Related: BUG-052, BUG-053

---

### LESSON-OPS-062: Firefox requires EventSource callbacks nulled before `.close()` to release the TCP connection (2026-03-19)

**Date:** 2026-03-19

Firefox's Gecko engine keeps SSE TCP connections alive during `browserContext.close()` if
EventSource event callbacks (`onopen`, `onerror`, `onmessage`) are still attached when
`.close()` is called. Chromium and WebKit release the connection immediately regardless.

**Rule:** Always null out all EventSource callbacks before calling `.close()`:

```javascript
evtSource.onopen = null;
evtSource.onerror = null;
evtSource.onmessage = null;
evtSource.close();
evtSource = null;
```

This applies to both production dashboard code (`suspendDashboardNetworkActivity()`) and
test teardown helpers (`stopDashboardNetwork()` in Playwright specs).

**Corollary:** Firefox-specific timing issues in Playwright are common. When tests fail only
on Firefox, check: (1) SSE/WebSocket teardown, (2) DOM rendering timing (Firefox's event loop
is slower — use larger `loadDashboard()` timeouts in test groups that exercise async boot
sequences), (3) test timeouts (add `test.setTimeout()` with headroom for Firefox teardown).

Related: BUG-049, LESSON-OPS-043

---

### LESSON-OPS-063: Fixture-specific Playwright test groups require a dedicated CI fixture job and a skip guard (2026-03-20)

**Date:** 2026-03-20

When a Playwright test group is written for a specific fixture variant (e.g., `mixed` with
2 environmental + 1 network sensor = 3 total), it **must not run** under a different fixture
variant in CI (e.g., `3sensor` with 4 sensors), because:
- `loadDashboard(page, { expectedSensorCount: N })` gates on exactly N sensor cards being
  rendered. If the active fixture has a different count, the wait never resolves and the
  test times out.
- Hardcoded `toHaveCount(N)` assertions are correct by design but will fail vacuously when
  the wrong fixture is served.

**Rule — three-part contract for every fixture-specific test group:**

1. **Skip guard in the test file:** The `test.describe` block must include a `test.beforeEach`
   that calls `testInfo.skip()` when `process.env.FIXTURE_SET` is not the expected value.
   This prevents accidental execution under the wrong fixture in both CI and local runs.

   ```javascript
   test.describe('N. My Fixture-Specific Group', () => {
     test.beforeEach(async ({}, testInfo) => {
       if (process.env.FIXTURE_SET !== 'myfixture') testInfo.skip();
     });
     // ...
   });
   ```

2. **Dedicated CI matrix job:** Add the fixture variant to the `fixture_set` matrix in
   `browser-tests.yml` and add a step that runs only the group-specific tests:

   ```yaml
   - name: Run my-fixture suite (myfixture — Group N)
     if: matrix.fixture_set == 'myfixture'
     env:
       CI: true
       FIXTURE_SET: myfixture
     run: npx playwright test tests/browser/dashboard.spec.js --grep "N\. My Fixture-Specific Group"
   ```

3. **Correct `loadDashboard` signature:** Use `{ expectedSensorCount: N }` (not `{ timeout: T }`).
   `{ timeout: T }` is a BUG-049 Firefox-SSE workaround limited to Group 13. Never copy it
   to new groups. `expectedSensorCount` gates on the exact number of sensor cards rendered,
   which is the correct readiness signal for fixture-specific tests.
   Use hardcoded integer literals in `toHaveCount()` — never read counts dynamically from
   `window._manifest`, as dynamic reads pass vacuously when the manifest is broken or empty.

**Anti-patterns:**
- `loadDashboard(page, { timeout: 30000 })` — wrong; does not gate on sensor count
- `await expect(cards).toHaveCount(await page.evaluate(() => window._manifest.sensors.length))` — wrong; vacuous if manifest broken
- Omitting the `FIXTURE_SET` skip guard — wrong; test runs under wrong fixture in CI

Related: BUG-050, BUG-049

---

### LESSON-OPS-062: Firefox requires EventSource callbacks nulled before `.close()` to release the TCP connection (2026-03-19)

**Date:** 2026-03-19

When a compile-time constant (e.g., `NUM_SENSORS`) is used to size arrays inside a
struct that is written to NVS as a blob (e.g., `SegmentSnapshot`), changing that constant
changes the struct's `sizeof()`. All existing blobs become a different byte length than
the new struct layout. `nvs_get_blob()` returns `ESP_ERR_NVS_INVALID_LENGTH` — the data
is not just schema-invalid, it is **physically unreadable** without a cross-schema deserializer.

This is worse than a schema mismatch in a metadata header (which BUG-046/LESSON-OPS-060
addressed). Metadata can be corrected in-place because the struct layout didn't change.
Data blobs with array dimensions baked in cannot.

**Rule:**
1. Never change a compile-time constant that dimensions a persisted struct without a migration
   plan that accounts for the blob size change.
2. The restore loop (`restore_from_nvs()`) must detect `ESP_ERR_NVS_INVALID_LENGTH` and
   recalibrate `meta.valid_segments` to exclude unloadable ghost slots. The recalibrated
   meta must be persisted back to NVS so subsequent boots don't repeat futile load attempts.
3. Preflight should assert `sizeof(SegmentSnapshot)` hasn't changed when `NUM_SENSORS` is
   expected to remain constant. Any prompt that touches sensor count constants must include
   an explicit "verify `sizeof(SegmentSnapshot)` is unchanged" acceptance criterion.
4. Data in incompatible blobs is unrecoverable without a dedicated cross-schema converter.
   Users should be advised to CSV-export before any firmware update that might change
   persistence-related constants.

Related: BUG-048, BUG-046, BUG-045, LESSON-OPS-060

---

### LESSON-OPS-060: Compile-time NVS schema constant changes require a firmware migration/re-save path (2026-03-19)

**Date:** 2026-03-19

When a compile-time constant used in an NVS-persisted struct (e.g., `NUM_SENSORS` in
`HistoryMeta`) changes between firmware versions, validation code that compares the persisted
value against the new constant will reject the stored blob. If the rejection only resets the
in-memory copy without writing the corrected value back to NVS, the rejection repeats on every
boot — an infinite stale-meta loop.

**Rule:** Any validation function that detects a schema mismatch in a persisted NVS blob must
either:
1. Persist the corrected/default metadata back to NVS before returning, or
2. Signal to its caller (e.g., via an output flag) that the corrected metadata needs to be
   persisted, and the caller must do so before proceeding.

Simply resetting the struct in RAM is never sufficient — the stale blob survives reboots.

**Corollary:** When persisting corrected metadata, be careful about NVS handle open modes.
`NVS_READONLY` handles cannot write. The migration path must obtain a `NVS_READWRITE` handle
(either by reopening or by opening writable from the start), save, and close it cleanly on
all code paths.

Related: BUG-046, BUG-045

---

### LESSON-OPS-059: Runtime device count and persisted-history count are different concepts in mixed-category firmware (2026-03-18)

**Date:** 2026-03-18

In mixed-category firmware (environmental BLE sensors + RAM-only network probes), the total
number of runtime `SensorEntity` devices (`NUM_DEVICES`) is not the same as the number of
devices whose history is written to flash (`NUM_SENSORS`). Aliasing `NUM_SENSORS = NUM_DEVICES`
appears harmless until a second device category is introduced — at that point the persisted
schema widens and all previously retained environmental history fails schema validation.

**Rule:** `NUM_SENSORS` (or any constant used to dimension flash-backed arrays) must always equal
the count of *environmentally persisted* devices only. A separate `NUM_ENV_SENSORS` constant
must be generated for this count. `NUM_SENSORS = NUM_ENV_SENSORS` must be the alias. Adding a
RAM-only device to the manifest must never silently widen the persisted schema.

**Preflight enforcement:** `scripts/preflight.sh` must contain:
- `num_env_sensors_constant_present` — `NUM_ENV_SENSORS =` present in generated header
- `num_sensors_aliases_env_sensors` — `NUM_SENSORS = NUM_ENV_SENSORS;` present in generated header
- `num_sensors_not_aliased_to_num_devices` — `NUM_SENSORS = NUM_DEVICES;` must **not** appear

Related: BUG-045

---

### LESSON-OPS-058: Prompt template device testing sections must include full local workflow (2026-03-18)

**Date:** 2026-03-18

Phase 3 prompt templates (e.g., v7.5.3.7) included device testing commands like `curl -s http://192.168.120.189/api/v2/history/office/temp` but did not include the prerequisite steps: pulling the repo, compiling, and flashing. An operator starting from scratch would not know the full workflow.

**Rule:** Every prompt's device testing section must include the complete sequence: (1) pull latest from main, (2) compile, (3) OTA flash, (4) verification commands, (5) expected output descriptions. Assume the operator is starting from a fresh terminal. Use the v7.5.3.7 instructions as the quality bar for detail level.

Related: BUG-044

---

### LESSON-OPS-057: Specified tests and checks must be tracked to implementation completion (2026-03-18)

**Date:** 2026-03-18

Two instruction documents (`BUG-043-preflight-enhancement-instructions.md` and `BUG-043-browser-test-implementation-instructions.md`) were written during BUG-043 resolution but never implemented. They fell through the cracks because they were not listed in the step index with explicit completion tracking.

**Rule:** Any instruction document that specifies code to be written must appear in a tracked step index (e.g., `phase3-prompt-templates-updated.md`) with a "Status: Pending/Complete" field. Untracked specifications become dead documents. Post-phase audits should verify all referenced instruction documents have corresponding implementations.

Related: BUG-044

---

### LESSON-OPS-056: Never use beginResponseStream for large HTTP responses on ESP32-C3

**Date:** 2026-03-17

`AsyncWebServer::beginResponseStream()` builds the response in an internal `std::string` that grows through repeated `print()` calls. Each `std::string` reallocation temporarily holds both old and new buffers. For a 24KB response (typical for 336 NVS segments × 4 points × 20 bytes/line), the growth from 16KB→32KB requires 48KB of simultaneous heap — nearly the entire free heap when SSE/polling connections are active.

**Rule:** Any HTTP response that could exceed ~10KB must use pre-reserved `std::string` with `csv.reserve(estimated_size)` followed by zero-copy `beginResponse(200, content_type, reinterpret_cast<const uint8_t*>(str.data()), str.size())`. This pattern makes a single heap allocation at the estimated final size, avoiding the reallocation cascade.

---

### LESSON-OPS-055: Gzip-compress large embedded responses; preflight must guard compressed format

**Date:** 2026-03-17

The ESP32-C3 HTTP server task blocks proportionally to response transfer size. The 190KB uncompressed `dashboard.html` blocked the task for 2–4 seconds per page load, starving BLE/WiFi/API/watchdog on the single-core device. Gzip compression (194KB → 45KB) reduced blocking to <1 second.

**Rules:**
1. `scripts/generate-header.sh` must gzip-compress the dashboard HTML and output a C `uint8_t[]` byte array (not a raw string literal)
2. `sensor_history_multi.h` must serve the dashboard with `Content-Encoding: gzip`
3. `scripts/preflight.sh` must verify: (a) `dashboard.h` contains `DASHBOARD_HTML_GZ` (gzip format), (b) does NOT contain `R"DASH64(` (raw literal), (c) file size is below 400KB threshold
4. `dashboard.html` must contain `<link rel="icon" href="data:,">` to prevent browser `/favicon.ico` requests (which return 500 due to ESPHome handler ordering)

---

### LESSON-OPS-054: Dashboard startup polling must be fully sequential (batch=1); ESPHome handler ordering affects custom routes (dashboard hardening PR2)

#### Part A: Startup polling must be fully sequential

The `pollAll()` function uses `Promise.all(batch.map(pollEntity))` to run each batch. With batch size > 1, multiple requests fire simultaneously. On the ESP32-C3, even 2 concurrent connections during the critical startup window (SSE open, fresh reboot, or F5) can trigger API disconnects or 502 errors.

**Rule:** The **initial poll in `startPolling()`** must always use `batchSize=1`. `Promise.all` with a single-element array is a sequential call, so this reuses the existing batching infrastructure without adding new code paths.

**Current values:**
- `pollAll(paths, 1, 200)` — initial startup poll, fully sequential, 200ms between requests
- `pollAll(livePaths)` — periodic live poll (uses default batch=4), which is acceptable for steady-state (device is stable and not in boot window)

**Preflight regression guard:** `scripts/preflight.sh` includes a `startup_poll_sequential` check that fails if `pollAll(POLL_DEVICE.concat(livePaths), 1` does not appear in both `dashboard.js` and `dashboard.html`.

#### Part B: ESPHome `AsyncWebHandler` registration order determines which handler answers a request

The `AsyncWebServer` (used by ESPHome's `web_server` component) iterates handlers in registration order and returns the first one where `canHandle()` returns `true`. ESPHome's built-in `web_server` (version 3) acts as a catch-all handler — its `canHandle()` returns `true` for any request it doesn't recognize, and its `handleRequest()` returns HTTP 500 for those routes.

The `HistoryWebHandler` is registered in an `on_boot` lambda (which runs after all component `setup()` calls). ESPHome's `web_server` component registers its handler during its own `setup()`. Therefore ESPHome's handler is at position 0 in the handler list and `HistoryWebHandler` is at position 1.

**Consequence:** For any route that ESPHome's handler intercepts (including `/favicon.ico`), `HistoryWebHandler::handleRequest()` is never called. Our `HistoryWebHandler` can only handle routes that ESPHome's handler does NOT claim.

**The observed symptom:** `/favicon.ico` returns HTTP 500 even though `HistoryWebHandler::canHandle()` returns `true` and `handleRequest()` would return 204 — ESPHome's catch-all gets there first.

**The fix (not yet implemented):** Change `register_history_handler()` to run before ESPHome's web_server setup — e.g., by creating a custom `esphome::Component` with a `setup_priority` that fires between `web_server_base::setup()` and `web_server::setup()`. This is a larger change requiring firmware/YAML modifications beyond the scope of this dashboard-hardening PR.

Related: BUG-043

---

### LESSON-OPS-053: NVS scan loops in firmware must yield to the FreeRTOS scheduler (firmware root-cause fix)

Any firmware loop that iterates over persisted NVS segment blobs (e.g., by calling `nvs_get_blob()` in a `for` loop) blocks the calling task for the full duration of the scan. On the ESP32-C3, this means the HTTP server task can block for 0.5–2 seconds (or more with large history), starving:

- BLE scanning / BLE task
- WiFi stack
- ESPHome API heartbeat (causes "unexpected disconnect" in ESPHome logs)
- FreeRTOS task watchdog (causes `component took a long time` warnings and eventually resets)

**Rule:** Any loop in `sensor_history_multi.h` (or any other firmware file) that reads more than a handful of NVS blobs must call `vTaskDelay(pdMS_TO_TICKS(1))` periodically to yield to the scheduler.

**Pattern to follow:**
```cpp
// In sensor_history_multi.h — apply to all NVS segment iteration loops.
static void maybe_yield_nvs_scan_(int iteration) {
  if (iteration > 0 && (iteration % NVS_SCAN_YIELD_INTERVAL == 0)) {
    vTaskDelay(pdMS_TO_TICKS(1));
  }
}

// Usage inside loop:
for (int n = 0; n < meta.valid_segments; n++) {
  maybe_yield_nvs_scan_(n);  // BUG-043: yield every 4 blobs
  int slot = ...;
  load_snapshot_from_handle_(handle, slot, snapshot);
  ...
}
```

The yield interval of 4 is a balance between low overhead and meaningful CPU relief. A 1ms yield every 4 blobs adds at most ~270ms of voluntary sleep over a 1080-blob scan, which is modest compared to the NVS read time itself.

This applies to **all** NVS iteration loops in the project, not just the three fixed in the BUG-043 follow-up:
- `restore_from_nvs()` — now fixed
- `build_import_epoch_map_()` — now fixed
- `handle_history_()` — now fixed
- Any future NVS iteration loop must follow the same pattern

Related: BUG-043

---

### LESSON-OPS-052: History endpoint NVS scan is a blocking operation — dashboard must never fetch history metrics concurrently (v7.5.3.5)

Each `/history/{id}/temp` or `/history/{id}/hum` request in the firmware (`sensor_history_multi.h`) triggers a **synchronous NVS scan loop** that reads up to 1080 NVS blobs without yielding to other tasks. This blocks the HTTP server task for 0.5–2 seconds per request.

Using `Promise.all` in `fetchDeviceHistory()` caused both temp and hum requests to fire simultaneously, doubling the blocking window to 1–4 seconds per sensor. During that window, BLE scanning, WiFi, the ESPHome API, and the FreeRTOS task watchdog are all starved — causing the crash.

**Mandatory rules for dashboard code:**
1. **`fetchDeviceHistory()` must fetch metrics sequentially**, never via `Promise.all`. Use a promise chain with a 300ms delay between each request to give the firmware breathing room.
2. **`loadHistory()` must have an in-flight guard** (`_historyInFlight`) to prevent concurrent history load chains from F5 refresh or button click during boot.
3. **History loading must be deferred long enough** for all other boot requests to complete first. The bootstrap timer must be ≥10s (sequential poll finishes ~t+8s, storage stats at t+5s, both must finish before history begins).
4. **Firmware fix (implemented):** `maybe_yield_nvs_scan_()` in `sensor_history_multi.h` calls `vTaskDelay(pdMS_TO_TICKS(1))` every 4 blob reads, yielding the CPU between batch reads. This eliminates the firmware root cause.
5. **Preflight enforces this rule:** `scripts/preflight.sh` includes a `no_concurrent_history_fetch` check that fails if `Promise.all(.*historyMeasurements` appears in either `dashboard.js` or `dashboard.html`.

Related: BUG-043

---

### LESSON-OPS-051: Dashboard code changes that affect network behavior require real-device validation with dashboard open (v7.5.3.3-hotfix)

Playwright tests validate rendering and data flow against a mock server with unlimited HTTP capacity. They do **NOT** validate HTTP connection pressure on a real ESP32-C3 (~4-7 concurrent connections). BUG-037 passed all 73 Playwright tests but crashed the real device within seconds of opening the dashboard.

**Rule:** Any dashboard change that modifies `setInterval()` / `setTimeout()` scheduling, `fetch()` call sites, SSE event handlers, boot sequence request ordering, or polling/refresh cadence **must** be validated on a real device with the dashboard open before the PR is merged.

**Real-device validation checklist:**
1. Open local dashboard — no crash for 5+ minutes
2. Close and reopen — no crash
3. Open remote dashboard (polling mode) — no crash for 3+ polling cycles
4. Check browser Network tab — no request storms or duplicate fetches
5. Check device logs — no `httpd_accept_conn: error in accept` warnings

Related: BUG-043

---

### LESSON-OPS-050: Dashboard HTTP request budgeting — ESP32-C3 has strict concurrent connection limits (v7.5.3.3-hotfix)

The ESP32-C3 HTTP server (ESP-IDF `httpd`) supports approximately 4-7 concurrent connections. Dashboard JavaScript must respect this constraint at all times.

**Rules for dashboard network code:**
1. **In-flight guards are mandatory** — every `fetch()` function that runs on an interval or event handler must have a module-level boolean guard preventing concurrent invocations. Pattern: set flag before fetch, clear in both `.then()` success and `.catch()` error paths.
2. **Never trigger HTTP fetches from SSE event handlers** — SSE `ping` and `onopen` should only update UI status indicators, never fire additional HTTP requests. SSE already delivers data via `state` events.
3. **Stagger startup requests** — boot sequence must not fire more than 2-3 concurrent requests. Use `setTimeout()` to spread non-critical fetches (storage stats, history) across 3-5 seconds.
4. **One polling interval per endpoint category** — never create two `setInterval()` calls that both invoke the same fetch function.
5. **Polling cadence should match data change rate** — storage stats change hourly (poll every 120s max), status changes every ~15 minutes (poll every 30s max).
6. **Verify with browser DevTools Network tab** — before any dashboard PR is merged, verify the request pattern. There should be no request storms, no duplicate concurrent fetches, and no unbounded request stacking.

Related: BUG-043

---

### LESSON-OPS-049: `dashboard.html` must be kept in sync with `dashboard.js` for all code changes — `bump-version.sh` now handles the version string automatically (v7.5.2.1/v7.5.2.2; **fixed in v7.5.3.0**)

`dashboard/dashboard.html` embeds all dashboard JavaScript inline (no `<script src>`). It is
the source of truth that `generate-header.sh` uses to produce `dashboard/dashboard.h` (the
embedded firmware payload). Prior to v7.5.3.0, `bump-version.sh` and `render_sensor_config.py --write`
only updated `dashboard/dashboard.js` — they did **not** touch `dashboard.html`.

**✅ Fixed in v7.5.3.0:** `bump-version.sh` now runs `sed -i "s/App\.version = 'v[0-9.]*'/..."` on
`dashboard/dashboard.html` immediately after updating `tests/fixtures/generate-fixtures.js`. The
`App.version` string is now updated atomically by the bump script.

**Remaining manual requirement:** Code changes to `App.Boot.start()` or any other JS logic in
`dashboard.js` must still be manually mirrored to `dashboard.html`. There is no automated tool that
propagates non-version JS edits from `dashboard.js` → `dashboard.html`. After any such edit:
1. Apply identical code changes to `dashboard/dashboard.html`.
2. Run `bash scripts/generate-header.sh` to regenerate `dashboard/dashboard.h`.
3. Confirm `bash scripts/preflight.sh` passes.

**Historical workaround (v7.5.2.x, no longer needed for version bumps):**
1. Run `bash scripts/bump-version.sh <new-version>` (will fail at preflight if dashboard.html is stale — that is expected).
2. Manually update `App.version` in `dashboard/dashboard.html` to the new version.
3. Apply the same code changes to `dashboard/dashboard.html` that were applied to `dashboard/dashboard.js`.
4. Run `bash scripts/generate-header.sh dashboard/dashboard.html dashboard/dashboard.h` (pass the html source explicitly to bypass the stale min.html).
5. Confirm `bash scripts/preflight.sh` passes.

---

### LESSON-OPS-048: Use `bump-version.sh` for all version bumps — never update version sources partially (post-v7.5.2.0)

Version drift occurs when the developer updates some canonical sources but misses others, or forgets to regenerate dependent artifacts. The version surfaces in at least eight places in this repo (VERSION, render_sensor_config.py, generate-fixtures.js, dashboard.html, dashboard.js, sensor_history_multi.h, firmware YAML, and the generated dashboard.h). Manually tracking all of them is error-prone.

**Rule:** Use `bash scripts/bump-version.sh <new-version>` for all version bumps. This script updates all four canonical sources atomically, runs `render_sensor_config.py --write` to regenerate all derived artifacts, runs `generate-header.sh` to regenerate `dashboard.h`, and then runs `preflight.sh` to verify sync. Do not manually edit individual version strings.

**Enforcement:** Preflight now includes `dashboard_h_version_matches` (detects missing `generate-header.sh`; uses regex to match both minified and non-minified forms) and `render_sensor_config_py_version_sync` (detects missing `render_sensor_config.py` VERSION update) in addition to the existing `fixture_generator_version_sync` and `render_sensor_config --check`.

**Version bump sources of truth (all updated by bump-version.sh):**
1. `VERSION` file (canonical root)
2. `scripts/render_sensor_config.py` VERSION constant
3. `tests/fixtures/generate-fixtures.js` VERSION constant
4. `dashboard/dashboard.html` App.version (**added in v7.5.3.0** — see LESSON-OPS-049)

**Derived artifacts (all regenerated by bump-version.sh):**
- `dashboard/dashboard.js` (App.version — via render_sensor_config.py --write)
- `dashboard/sensor_history_multi.h` (header comment — via render_sensor_config.py --write)
- `firmware/esp32-c3-multi-sensor.yaml` (header + register_history_handler — via render_sensor_config.py --write)
- `src/gateway_manifest.h` (firmware_version — via render_sensor_config.py --write)
- `tests/fixtures/manifest.json` and `api-status.json` (version fields — via render_sensor_config.py --write)
- `dashboard/dashboard.h` (embedded App.version — via generate-header.sh)

Related: BUG-042

---

### LESSON-OPS-047: Version strings in test fixture generators must match the canonical VERSION file (v7.5.1.3)

The fixture generator (`tests/fixtures/generate-fixtures.js`) embeds a VERSION constant that is stamped into generated fixture JSON files. The Python generator (`render_sensor_config.py --check`) independently derives the expected version from the canonical `VERSION` file and its own VERSION constant. If these two sources drift, the `--check` comparison will fail even though the generated fixture files are otherwise valid.

**Rule:** All version references must be bumped atomically in a single commit: `VERSION` file, `render_sensor_config.py` VERSION constant, `generate-fixtures.js` VERSION constant, `dashboard.js` App.version, `dashboard.html` App.version, `sensor_history_multi.h` header comments, YAML header comment, and `register_history_handler()` string. Never bump the fixture generator VERSION independently.

**Enforcement:** Preflight checks `fixture_generator_version_sync` that the VERSION extracted from `generate-fixtures.js` matches the canonical `VERSION` file. If they differ, preflight fails immediately.

Related: BUG-041

---

### LESSON-OPS-046: Generated artifacts with structured schemas need compile-time validation (v7.5.1.1)

For any generated file with a required schema (JSON, YAML, etc.), preflight must validate structure, not just existence. A generator bug or incomplete update can produce syntactically valid but semantically broken output — for example, a JSON file that parses correctly but is missing required fields. Existence checks and generator sync checks (`--check`) do not catch this class of failure.

Add field-level validation for every generated artifact that has a documented schema contract. This catches regressions early and prevents malformed output from reaching `main`.

Related: BUG-040

---

### LESSON-OPS-045: Preflight must include a YAML/ESPHome parse gate, not just generated-file sync checks (v7.5.0.1)

The existing preflight catches version drift and generator sync failures. It does not catch structurally invalid YAML that passes the sync check because the generator produced syntactically invalid output. Add a step that runs `esphome config firmware/esp32-c3-multi-sensor.yaml` (or equivalent YAML parse) to block bad YAML from reaching the compile stage.

Without this gate, a generator bug can produce invalid YAML that passes preflight, passes `--check`, and only fails at `esphome compile`. The gap between "preflight green" and "compile fails" wastes time and creates false confidence.

**Implementation**: v7.5.1.2 — preflight runs `esphome config firmware/esp32-c3-multi-sensor.yaml`

---

### LESSON-OPS-044: Runtime validation must cover both the custom dashboard and the built-in ESPHome web page (v7.5.0.1)

Dashboard-only runtime checks can mask regressions in the built-in ESPHome diagnostics page. After any YAML change, verify:
1. The custom dashboard loads correctly and all status fields hydrate
2. The ESPHome built-in web page at `/` shows Free Heap, Uptime, and Loop Time

These are served from different code paths. One can regress without the other showing symptoms.

---

### LESSON-OPS-043: `dashboard.html` is the source of truth — regenerate artifacts after every edit (v7.5.0.1)

Edit order must always be:
1. Edit `dashboard/dashboard.html` (source of truth)
2. Run `bash ./scripts/minify-dashboard.sh` → produces `dashboard.min.html`
3. Run `bash ./scripts/generate-header.sh dashboard/dashboard.min.html dashboard/dashboard.h`

Editing `dashboard.js` alone is not sufficient. The script block inside `dashboard.html` must also be updated, and both the minified intermediate and the embedded header must be regenerated. A preflight rule should verify that `dashboard.h` reflects the current state of `dashboard.html`.

---

### LESSON-OPS-042: Dashboard device-status widgets should hydrate from `GET /api/status`, not entity polling (v7.5.0.1)

Do not rely on `/sensor/<entity-name>` paths for dashboard status fields. The firmware already exposes authoritative status data — version, uptime, free heap, sensor validity, storage settings — from `GET /api/status`. Entity-polling paths are implementation details of ESPHome's built-in web interface and may not be stable across firmware changes.

---

### LESSON-OPS-041: YAML generator correctness requires both idempotent marker replacement and indentation preservation (v7.5.0.1)

YAML generation that passes content-only sync checks can still produce invalid YAML if indentation context is lost during marker replacement. Two properties must both hold:
1. Running `--write` twice produces no diff (idempotence)
2. Inserted block content inherits the indentation column of the marker line

`replace_marker_block()` satisfies (1) but not (2). Use `apply_yaml_marker_block()` for all YAML-targeted marker regions.

---

### LESSON-OPS-040: YAML generator must use indentation-aware insertion for all block scalar sections (v7.5.0.0)

When generating content for YAML files that contain block scalars (lambda bodies, sorting_groups, nested sensor blocks), the generator must preserve the indentation level of the target marker location. Content-correct YAML with wrong indentation is not valid YAML — ESPHome will reject it at parse time, not compile time.

---

### LESSON-OPS-039: Use lambda replacements in `re.sub()` when generated content may contain backslashes (v7.5.0.0)

Generated text that contains escape sequences like `\xC2\xB0`, `\n`, or `\t` is unsafe as a raw string argument to `re.sub()`. Use a lambda function as the replacement instead: `re.sub(pattern, lambda m: generated_text, source)`.

Also: do not use brittle exact-string patching against compacted one-line C++ source blocks. Use function-anchor detection, regex-based matching, or brace-aware insertion instead.

---

### LESSON-OPS-038: Safety prompts belong on destructive CLI paths, not only in prose documentation (v7.4.5.1)

Documenting that a path is destructive is not enough. If a CLI command can erase retained state, the operator should have to acknowledge that at runtime or opt into bypassing the prompt deliberately.

---

### LESSON-OPS-037: Design-level behavior needs to be documented, not just shipped (v7.4.5.0)

When a feature has a non-obvious internal model, preserve that model in durable documentation. The single-sensor import path is a good example: the useful fact is not only that it is "non-destructive," but *how* it works — epoch-to-slot scan, segment overlay, same-slot rewrite, new-slot allocation only for missing hours, and temporary memory overhead.

**Carry forward:** When a feature changes retained-history semantics, endpoint contract, or state-management design, record the internal mechanism in the changelog and session handoff, not only the user-facing label.

---

### LESSON-OPS-036: Repeated configuration belongs in one canonical manifest (v7.4.5.0)

If the same sensor facts appear in multiple repo files, manual editing will eventually drift. Move those facts into one canonical manifest and generate the dependent files from it.

**Carry forward:** `config/sensors.json` is the source of truth. Future sensor-related changes should flow through the manifest and renderer first.

---

### LESSON-OPS-035: Preflight checks that depend on npm packages must skip when node_modules is absent (v7.4.4.0)

The build CI (`ci.yml`) runs preflight before `npm ci` — `node_modules` does not exist at that point. Any preflight check that requires an npm package must guard with `[[ -d "node_modules/@playwright" ]]` and emit `SKIP` rather than `FAIL` when the guard is not met.

---

### LESSON-OPS-034: Always use --with-deps when installing Playwright in containers (v7.4.4.0)

`npx playwright install chromium` downloads the binary only. `npx playwright install --with-deps chromium` also installs the required OS shared libraries via apt. In any container or fresh Linux environment, always use `--with-deps`. See BUG-027.

---

### LESSON-OPS-033: Playwright in Docker/ESPHome containers requires --no-sandbox (v7.4.4.0)

Always add `launchOptions: { args: ['--no-sandbox', '--disable-setuid-sandbox'] }` to `playwright.config.js` when running in a container. The error `Target page, context or browser has been closed` immediately after browser launch is the signature of a sandbox crash. See BUG-026.

---

### LESSON-OPS-032: NVS count-mismatch protection is already in place — no new C++ guard needed (v7.4.4.0)

The `meta.num_sensors == NUM_SENSORS` check in the NVS restore path already rejects history segments from a different sensor count cleanly. The correct response to a count change is: load nothing from the old segments, require an explicit history delete, and document the procedure.

---

### LESSON-OPS-031: DEFAULT_SENSOR_META in dashboard.js is a required consistency target (v7.4.4.0)

The `DEFAULT_SENSOR_META` array in `dashboard.js` is a fallback used when `/sensors.json` fails to load. It must match `NUM_SENSORS`. Preflight checks this explicitly.

---

### LESSON-OPS-030: Preflight sensor-count checks belong in Node.js, not bash regex (v7.4.4.0)

Counting occurrences of patterns in YAML and C++ using bash `grep -c` and `sed` is fragile. Inline Node.js scripting within the bash preflight is more readable, reliable, and straightforward to extend.

---

### LESSON-OPS-029: CSV fixture timestamps must be epoch seconds (v7.4.4.0)

The dashboard's history chart pipeline uses `new Date(epoch * 1000)` — it expects epoch **seconds** as integers from CSV files. `Date.UTC()` and `Date.now()` return **milliseconds** and must not be used directly as CSV timestamp values. See BUG-025.

---

### LESSON-OPS-028: Verify DOM behavior, not just element IDs (v7.4.3.0)

Verifying element IDs with `grep` is necessary but not sufficient. Three categories require runtime understanding:

1. **CSS class targets** — `toggleTheme()` applies `light` to `document.documentElement` (`<html>`), not `document.body`.
2. **Interaction side-effects** — `_onPreset()` calls `_applyAndClose()` immediately. A preset click closes the modal; there is no confirmation step.
3. **Container relationships** — chart canvases are in `.chart-card` divs, not inside `.sensor-card`.

Rule: before writing any Playwright assertion, read both the HTML and the JS handler for that element.

---

### LESSON-OPS-027: New GitHub Actions workflows only appear after merging to main

GitHub registers workflow files from the default branch only. A new `.github/workflows/*.yml` file on a feature branch will not appear in the Actions sidebar until it is merged to `main`.

---

### LESSON-OPS-026: `data-history-range` button values are in hours, not human-readable labels

| Label | Attribute value |
|-------|----------------|
| 24h | `24` |
| 7d | `168` |
| 30d | `720` |
| 45d | `1080` |
| Custom | `custom` |

---

### LESSON-OPS-025: Output bundle files must clearly indicate their destination path

When delivering files that belong in subdirectories, document the full destination path explicitly in session notes or in the delivery message.

---

### LESSON-OPS-024: Commit `package-lock.json` in the same commit as `package.json`

Any time `package.json` is introduced or changed, commit `package-lock.json` in the same commit. `npm ci` requires the lockfile and will not generate one.

---

### LESSON-OPS-023: Verify new workflow files are committed to the correct branch and appear in git log

After committing a new workflow file: `git show --name-only HEAD | grep workflow`. Do not assume file-system presence equals committed state.

---

### LESSON-OPS-022: Always `grep` the actual HTML for element IDs before writing Playwright selectors

Never assume an ID from a variable name, comment, or context.

Specific gotchas in this codebase:
- Range button values are **hours**, not labels: 24, 168, 720, 1080, custom
- Export buttons use `data-export-all` and `data-export-sensor` attributes, not text matching
- Sensor names are raw text nodes inside `.sensor-card-header` — there is no `.card-title` class
- Export and sensor card elements are built dynamically — use `waitForFunction` before asserting them

---

### LESSON-OPS-021: Zero return values from API need explicit handling distinct from fetch errors

Do not conflate a successful API response containing `0` with a missing/failed response.

---

### LESSON-OPS-020: "Data available: unknown" is expected on a freshly-flashed device

The first NVS history persist runs at 2:10 AM. Until then, `retention_oldest_epoch` returns 0. This is not a bug or a fetch failure.

---

### LESSON-OPS-019: Minification savings are a correctness signal

After running `minify-dashboard.sh`, expected savings are ~30–35% of source size. If savings are below 10%, the script block was almost certainly doubled (embedded twice).

---

### LESSON-OPS-018: Script block sync must use N-1, not N, for `head` cut

When syncing `dashboard.js` into the `<script>` block of `dashboard.html`, use `head -n $((SCRIPT_LINE - 1))`, not `head -n $SCRIPT_LINE`. After every sync, verify: `grep -c '^<script>$' dashboard/dashboard.html` must return `1`.

---

### LESSON-OPS-017: Code and docs should be normalized in the same pass when possible

If a comment/header is clearly stale, normalize it during the same session that fixes the related documentation drift.

---

### LESSON-OPS-016: Every substantial development session should leave continuity breadcrumbs

For meaningful sessions, update: a session log, the fresh-start handoff, and any changed roadmap/implementation-plan docs.

---

### LESSON-OPS-015: Documentation must distinguish current behavior from planned behavior

- `README.md` = current shipped behavior only
- `architecture.md` = current architecture only
- `future-plans.md` / implementation plans = planned behavior

Do not advertise a roadmap item as if it is already merged.

---

### LESSON-OPS-014: `dashboard.h` shrinkage is the easiest signal that minification is active

If the generated header barely changed, the minified intermediate may not have been used.

---

### LESSON-OPS-013: `git pull` can fail after a broken or partial prior pull

If Git says local changes would be overwritten and the changes are unwanted, reset the affected file(s) before retrying.

---

### LESSON-OPS-012: Script execute permissions may be lost

After a fresh clone or after pulling new scripts, run `chmod +x scripts/*.sh`.

---

### LESSON-OPS-011: `html-minifier-terser` uses positional input plus `--output`

Do not script imaginary flags. Test the exact command in a shell first.

---

### LESSON-OPS-010: Cached builds may not reflect header-only changes clearly

If behavior looks stale after header or generated-file changes, use `esphome compile --clean`.

---

### LESSON-OPS-009: Version strings live in six places

1. `VERSION`
2. YAML header comment
3. `register_history_handler()` version string
4. `dashboard_link` publish-state text
5. `App.version` in `dashboard.js`
6. Version comment/header in `dashboard.html`

When a version bump happens, update all six together.

---

### LESSON-OPS-008: `CONFIG_HTTPD_MAX_REQ_HDR_LEN` is a RAM multiplier

Increasing it increases per-connection cost. On this device class, overly large header buffers can create new failures.

---

### LESSON-OPS-007: ESPHome ESP-IDF data-channel constraints matter

- POST body: not reliable for this use case
- Query params: not reliable in this path
- Headers: too limited once proxies add overhead
- **URL path: reliable**

---

### LESSON-OPS-006: Prefer local CLI or editor-driven updates over ad hoc web editing

This reduces accidental truncation, missing execute bits, and inconsistent file state.

---

### LESSON-OPS-108 — handleRequest() GET fallthrough has no method guard (2026-04-02)

**Context:** In AsyncWebServer handlers, `handleRequest()` typically has a series of early-return
method guards (`if (request->method() == HTTP_DELETE) { ... return; }`), followed by a "fallthrough"
section that assumes the method is GET. If any DELETE/POST/OPTIONS check is missing from `canHandle()`,
the request falls through to the GET section, which sends a generic 404 or attempts to serve a GET
resource, producing confusing behavior.

**Rule:** Every `handleRequest()` method should have explicit method guards for ALL supported methods
before the GET fallthrough section. If a method is checked in `canHandle()` but the corresponding
dispatch is missing or out-of-order in `handleRequest()`, the request will reach the GET fallthrough
and produce incorrect responses.

**Diagnostic signature:** Plain-text 405 responses (not JSON) indicate `canHandle()` returned false,
so the request never reached the handler. See LESSON-OPS-109.

---

### LESSON-OPS-109 — Plain-text 405 = canHandle() returned false (2026-04-02)

**Observation:** ESPAsyncWebServer (built on ESP-IDF httpd layer) sends plain-text 405 responses when
NO registered handler returns `true` from `canHandle()` for a given {method, path} combination. If the
handler sends JSON 405, it means `canHandle()` returned true but `handleRequest()` explicitly rejected
the method. If the handler sends **plain-text** 405, it means `canHandle()` returned false and the
request never reached the handler at all.

**Diagnostic rule:**
- **Plain-text 405:** Bug is in `canHandle()` (method/path check missing or incorrect)
- **JSON 405:** Bug is in `handleRequest()` (method dispatch logic)

**Example:** BUG-079 — DELETE to `/api/aggregator/satellite/{id}` returned plain-text 405 because
the `canHandle()` HTTP_DELETE check was missing, even though `handleRequest()` had proper DELETE
dispatch code.

---

### LESSON-OPS-105 — Snapshot-based deferred NVS persistence (2026-04-02)

**Context:** v7.6.0.2 DELETE endpoint needs to persist satellite config to NVS after
array compaction, but NVS write is too slow for the HTTP handler stack (Critical Rule 40).
The initial implementation called `save_satellites_to_nvs_()` directly from a deferred
FreeRTOS task, which reads global state (`satellite_caches[]`, `runtime_satellite_count`)
without holding the mutex — creating a torn-read race condition.

**Solution:** Capture a `SatelliteNVSSnapshot` struct under `AGG_LOCK()` in the caller
(HTTP handler context), then pass the heap-allocated snapshot to the deferred task as
`pvParameters`. The task writes the snapshot to NVS and frees it. No lock needed during
the slow flash write.

**Pattern:** snapshot-under-lock → heap-allocate → pass to task → write → free → delete task.
Applicable anywhere a slow I/O operation needs a consistent view of mutex-protected state.

---

### LESSON-OPS-106 — Config-generation counter for poll-task safety (2026-04-02)

**Context:** `aggregator_poll_task()` iterates `satellite_caches[]` by index, performs
HTTP fetches (slow, outside lock), then writes results back under `AGG_LOCK()`. If a
delete compacts the array during the fetch, the poll task writes data to the wrong slot
(index shifted) or a removed satellite.

**Solution:** Added `satellite_config_generation` counter (incremented under `AGG_LOCK()`
on every add/delete/reset). The poll task snapshots `{id, base_url, generation}` under
lock before fetching. After fetch, re-acquires lock and verifies generation matches before
writing results. If generation changed, discards fetched data (logs warning) and re-reads
on next cycle.

**Trade-off:** Discards one poll cycle of data on config change. Acceptable because config
changes (add/delete) are rare human-initiated operations, not high-frequency events.

---

### LESSON-OPS-107 — NVS save failure after delete is a known limitation (2026-04-02)

**Context:** After DELETE compacts the satellite array and decrements
`runtime_satellite_count`, the deferred NVS save may fail (flash error, task creation
failure). If NVS is not updated, the deleted satellite reappears after reboot (NVS still
has the old config).

**Status:** Accepted known limitation for v7.6.0.2. Rollback after compaction is
impractical — would require re-inserting the deleted entry at its original position and
re-expanding the array. The deferred snapshot pattern minimizes but cannot eliminate this
window. A future improvement could retry NVS writes or add a "dirty" flag checked at boot.

---

### LESSON-OPS-110 — Prompt code snippets for endpoint handlers must include explicit auth policy (2026-04-03)

**Observation:** When a prompt replaces an existing stub handler with a new implementation,
omitting `authenticate_management_()` from the prompt's code block is a prompt defect that
coding agents will faithfully reproduce. The replaced stub's auth call is the authoritative
reference — if the replacement prompt omits it, the agent will drop it.

**Root cause (v7.6.0.3):** The `handle_test_satellite_()` prompt snippet did not include an
explicit auth decision. The agent produced an unauthenticated handler. Auth was added
during the Copilot review pass (`b43340c`), but the defect originated in the prompt.

**Rule:** From v7.6.0.4 onward, every endpoint handler code block in a prompt must include
an explicit auth decision in one of these forms:
```
Auth: REQUIRED — call authenticate_management_() before any logic
Auth: NOT REQUIRED — [one-sentence rationale]
```

**Corollary:** Destructive or topology-revealing management endpoints require auth.
Add/discovery endpoints may be open with documented rationale.

---

### LESSON-OPS-005: Raw logs and curated docs stay separate

- Raw logs → `build-logs/` (gitignored)
- Durable documentation → `Docs/`

---

### LESSON-OPS-004: Hidden build directories break GitHub Actions artifact collection

Stage artifacts explicitly into known output directories.

---

### LESSON-OPS-003: Cloud CI and local compile need different secret handling

Local uses the symlinked real secrets file. CI uses temporary dummy secrets.

---

### LESSON-OPS-002: Comments in YAML do not affect ESPHome behavior

Only actual configuration matters.

---

### LESSON-OPS-001: File renames must update internal references

Preflight should catch cross-reference drift, but docs should still be reviewed after any rename.


## Known Open Issues

### ISSUE-001: Export still causes a noticeable heap drop

The current export path remains acceptable for the present dataset sizes, but it is still not the most memory-efficient design for worst-case full-retention exports.

### ISSUE-002: Multi-sensor import remains erase-first

Single-sensor import is now safe/merge-based, but multi-sensor import still clears existing history before writing.

### ISSUE-003: `/api/manifest` response is a partial v2 schema

The endpoint was implemented as Phase 1, but the response does not yet include the full v2 schema as specified in `Docs/v7.5-v7.6-architecture-plan.md` — specifically: the `gateway` identity block, the `history` retention policy block, and per-measurement `class`, `data_type`, and `display` hints. These are required before Phase 2 (dashboard consuming full manifest) can be fully implemented.

### ISSUE-004: ✅ RESOLVED (v7.5.1.2) — Preflight does not gate on ESPHome YAML validity

`preflight.sh` validates version strings, generator sync, and fixture alignment but does not run `esphome config` to verify YAML parse. A generator bug can produce structurally invalid YAML that passes all preflight checks. See LESSON-OPS-045.

**Resolution**: Preflight now runs `esphome config` to validate YAML structure before allowing merge
