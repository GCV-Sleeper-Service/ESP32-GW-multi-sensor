# Phase V — Bug Fixing, Optimization & Security Hardening

**Status:** PLANNED — ready for implementation  

_Implementation Plan for v7.6.7.x · v7.6.8.x · v7.6.9.x_  
_Date: 2026-04-12_  
_Prerequisite: Phase Y complete (v7.6.6.8 on `main`), Phase D complete (v7.6.0.5)_  
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Goal

Phase V is a three-sub-phase remediation and hardening cycle targeting the open issues left by Phases X, Y, and D. It delivers:

- **V1 (v7.6.7.x):** Critical bug fixes and zero-gate optimisations — things that can ship immediately with no new on-device measurement required
- **V2 (v7.6.8.x):** Security hardening — auth extension, topology disclosure prevention, internet-exposure hardening
- **V3 (v7.6.9.x):** Dashboard enhancements, gated optimisations (after V1 watermark measurements), export/import correctness

**Key principle:** Phase V must not conflict with or preclude Phase 7. No `SegmentSnapshot`, `HistoryMeta`, `PERSIST_SLOTS`, `HISTORY_HOURS`, or `HISTORY_INTERVAL_MINUTES` changes are permitted in Phase V. No partition table changes. No fragment boundary reorganisation (Rule 62).

---

## Architecture Reference

- `Docs/phase-d-implementation-plan.md` — Phase D reference (structural template)
- `Docs/v7.7-implementation-plan.md` — Phase 7 per-device persistence engine (do not schedule Phase 7 work in Phase V)
- `Docs/v7.7-v7.8-persistence-architecture.md` — §5, §12, §14–16 (persistence architecture)
- `Docs/phase-V-capacity-study.md` — Memory/flash capacity study (companion document)
- `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` — Security ADR
- `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` — Aggregator history ADR

---

## Part 0 — Issue Title Normalisation

The following 14 open issues must have their titles updated before or during Phase V. Apply these normalised titles and labels when updating each issue.

| # | Current title | Normalised title | Labels | Milestone |
|---|---|---|---|---|
| 136 | Hardcoded C3 values in dashboard | `Tech-debt: Hardcoded C3 SRAM/flash values in dashboard template` | `tech-debt`, `dashboard`, `esp32-c3` | v7.6.9.x |
| 137 | Generate SVG files for each board type | `Feature: Board-type SVG diagrams for documentation and device-info card` | `feature`, `dashboard` | Deferred (Phase 7+) |
| 138 | The gateway card does not show actual information about PSRAM or flash size | `Enhancement: Gateway card PSRAM and flash size from runtime sensors` | `enhancement`, `dashboard` | v7.6.9.x |
| 139 | History loading serialization for C3 boards | `Bug: History loading heap exhaustion on ESP32-C3 (v7.5.x)` | `bug`, `memory`, `esp32-c3` | Partial v7.6.8.x (auth cap), full fix Phase 7 |
| 143 | No visible version badge on dashboard page | `Enhancement: Version badge in dashboard footer` | `enhancement`, `dashboard` | v7.6.7.x |
| 144 | Update gateway card | `Enhancement: Gateway card — device name, firmware version, MAC removal` | `enhancement`, `dashboard` | v7.6.9.x |
| 161 | Bug: Aggregator history proxy silently returns 502 — no diagnostic (v7.6.6.6) | Already correct ✓ | `bug` | v7.6.7.x |
| 162 | type: decision - how to get and keep satellite's sensor/device history to aggregator | `Decision: Aggregator satellite history storage — proxy vs local copy` | `decision` | v7.6.9.x (ADR) |
| 163 | Security hardening | `Feature: Security hardening — endpoint auth, injection prevention, topology disclosure` | `feature`, `security` | v7.6.8.x |
| 164 | Memory footprint on satellites | `Bug: ESP32-C3 satellite heap regression >20 KB (v7.5.x–v7.6.0.x)` | `bug`, `memory`, `esp32-c3` | v7.6.7.x (measurement), v7.6.8.x (gated fixes) |
| 165 | Code optimization | `Tech-debt: ESP32-C3 SRAM reduction — seven targeted optimisations (v7.7.x)` | `tech-debt`, `optimization`, `memory`, `esp32-c3` | v7.6.7.x (OPT-02/05/06), v7.6.8.x (OPT-01/03/04) |
| 166 | Fix data export format from boards | `Enhancement: CSV export — role column, satellite prefix, manifest-driven metrics` | `enhancement`, `dashboard` | v7.6.9.x |
| 170 | Rework satellite gateway display card | `Enhancement: Satellite gateway card — hostname, IP address display` | `enhancement`, `dashboard` | v7.6.9.x |
| 171 | Data export logic | `Bug: Import POST endpoints crash ESP32-C3 (Rule 40 violation); export is client-side only` | `bug`, `esp32-c3` | v7.6.7.x (crash fix), v7.6.9.x (manifest-driven export) |

### Issue update instructions

For each issue:
1. Edit the title to the normalised form in the table above
2. Add the labels from the `Labels` column (create labels if they don't exist, using the taxonomy: `bug`, `enhancement`, `feature`, `decision`, `tech-debt`, `security`, `memory`, `esp32-c3`, `dashboard`, `optimization`)
3. Add the milestone from the `Milestone` column
4. Update the issue body's acceptance criteria to reference the relevant plan step (V1-A, V2-C, etc.)
5. Mark issues as closed with the PR reference when the implementing PR merges

---

## Why This Order

1. **V1 before V2 — crashes and zero-gate wins first.** Crashes (import crash on C3 — Rule 40 violation; proxy 502 with no body) and zero-gate memory wins (NAS history buffers, logger level, dead code) must ship first. They are the lowest risk, highest safety-margin items. A crashing import endpoint and a blind 502 proxy undermine confidence in the entire system. The SRAM gains from OPT-02 and OPT-05 actually *improve* the safety margin before security work adds auth overhead (~250 B/request transient).

2. **Security in V2, not V1 — proxy and import must work before auth.** Security hardening requires the proxy to be working (V1-A fixed) and the import crash to be resolved (V1-D) before auth can be added to those endpoints. Adding auth to a crashing endpoint creates a false sense of security.

3. **Gated optimisations in V2 — require on-device measurements.** OPT-01 (httpd stack right-sizing), OPT-03 (ping_adapter stack reduction), and OPT-04 (LWIP socket count reduction) require on-device watermark measurements from #164 Steps 6–7. These cannot be automated. The operator runs the measurements between V1 and V2; results feed the V2-H/I/J decision table.

4. **Dashboard in V3 — depends on V2 firmware changes.** Dashboard enhancements (gateway card, export format, satellite card) depend on V2 firmware (auth on gateways endpoint, new hostname/IP fields from V3-B). They are the lowest priority from a stability perspective and highest value from a usability perspective.

5. **Capacity study alongside V1.** The study does not block any implementation but must be complete before Phase 7 planning begins. It runs in parallel with V1.

6. **Export format (#166 + #171) split across V1 and V3.** The import crash fix (V1-D) is a safety/correctness item that ships in V1. The export manifest-driven fix (V3-D) depends on V1-D being stable and is a usability enhancement — it ships in V3.

7. **No backward compatibility required for export CSV.** The `role` column addition in V3-C inserts at position 3. Any existing positional parser will break. This is acceptable because no machine-readable pipeline currently consumes the export CSV. This breakage is documented explicitly in V3-C.

8. **Flash partition resize deferred to Phase 7.** Partition table changes require a re-flash (not OTA-safe). Phase V is OTA-safe by design. The 640 KB partition plan is documented in the capacity study but executed as a Phase 7 pre-step.

---

## Hard Constraints

All Critical Rules from `Docs/lessons/firmware.md` apply. Key rules for Phase V:

| Rule | Constraint |
|---|---|
| **Rule 8** | Never use `beginResponseStream` for any response body — use pre-reserved `std::string` + `beginResponse()` |
| **Rule 24** | Always report `free_heap_internal` and `free_heap_total` separately; they differ on S3 (PSRAM) |
| **Rule 27** | All socket calls in ESPHome IDF context must use `lwip_*` prefix (e.g., `lwip_socket`, `lwip_connect`, `lwip_send`) |
| **Rule 38** | All POST `fetch()` calls from dashboard JS must use `Content-Type: application/x-www-form-urlencoded` |
| **Rule 39** | All curl POST test commands must use `-d 'a=1'` (not `--data-raw`) |
| **Rule 40** | NVS work longer than ~5 ms must be deferred to an `xTaskCreate` task with ≥ 8192 B stack |
| **Rule 41** | The httpd task must never block on NVS I/O for more than one blob read/write |
| **Rule 47** | Never edit `dashboard/dashboard.js` or `dashboard/dashboard.html` directly — these are generated artifacts |
| **Rule 48** | Never edit `dashboard/dashboard.tmpl.html` — edit source modules and run `bundle-dashboard.sh --write` |
| **Rule 58** | Never edit `dashboard/sensor_history_multi.h` directly — edit fragments under `firmware/core/` and run `assemble-sensor-history.sh --write` |
| **Rule 62** | Fragment boundary changes require explicit sign-off — Phase V must not reorganise the 8-fragment split |

### Fragment boundary reminder (Rule 62)

The 8 fragments are: `config.h`, `data-model.h`, `nvs-persistence.h`, `aggregator-runtime.h`, `web-handler.h`, `ping-adapter.h`, `deferred-management.h`, `registration.h`. All firmware changes in Phase V must edit the fragment files under `firmware/core/`, then run:
```bash
bash scripts/assemble-sensor-history.sh --write
bash scripts/preflight.sh
```

---

## Sub-phase V1 (v7.6.7.x) — Critical Fixes and Zero-Gate Optimisations

**Version sequence:** v7.6.7.0 (V1-A + V1-B + V1-C), v7.6.7.1 (V1-D), v7.6.7.2 (V1-E + V1-F + V1-G)

---

### V1-A — Bug #161: Proxy 502 Diagnostic and Timeout Fix

**Issue:** #161  
**Risk:** MEDIUM  
**Effort:** 1–2 sessions  
**Version:** v7.6.7.0

**Files modified:**
- `firmware/core/aggregator-runtime.h` — modify `fetch_to_buffer()` signature
- `firmware/core/web-handler.h` — modify `handle_aggregator_proxy_()`

**Implementation — `fetch_to_buffer()` signature change:**

Current signature (line ~124 of `aggregator-runtime.h`):
```cpp
static bool fetch_to_buffer(const char* url, char* buf, uint16_t buf_size, uint16_t* out_len)
```

New signature (add `timeout_s` and `out_http_status` parameters):
```cpp
static bool fetch_to_buffer(const char* url, char* buf, uint16_t buf_size, uint16_t* out_len,
                            int timeout_s = 5, int* out_http_status = nullptr)
```

Changes inside `fetch_to_buffer()`:
- Apply `timeout_s` to the `lwip_setsockopt()` call for `SO_RCVTIMEO` and `SO_SNDTIMEO`
- Parse the HTTP status line from the response and write to `*out_http_status` if non-null
- Return `false` if HTTP status is not 200 (non-200 responses from satellite should propagate)

Update all existing call sites in `aggregator-runtime.h` (lines ~246, ~599, ~646, ~685) to use the new signature with default parameters — no behaviour change for existing callers.

**Implementation — `handle_aggregator_proxy_()` changes:**

Current code (lines ~1628–1653 of `web-handler.h`) calls `fetch_to_buffer()` and:
- Returns bare `502` with no body on failure
- Returns `502` when `s_proxy_len == 0` (satellite has no history)

New behaviour:
```cpp
int satellite_http_status = 0;
if (!fetch_to_buffer(url, s_proxy_tmp,
                     static_cast<uint16_t>(sizeof(s_proxy_tmp)),
                     &s_proxy_len,
                     15,                  // proxy passes 15s timeout
                     &satellite_http_status)) {
  // Satellite unreachable — log and return 502 with JSON body
  ESP_LOGW(TAG, "Proxy fetch failed for %s (HTTP %d)", url, satellite_http_status);
  char err_body[192];
  snprintf(err_body, sizeof(err_body),
           "{\"error\":\"upstream_fetch_failed\",\"url\":\"%s\"}", url);
  auto *resp = request->beginResponse(502, "application/json", err_body);
  add_common_headers_(resp);
  request->send(resp);
  return;
}
// Satellite returned 200 but has no history — return 200 with empty body (not 502)
if (s_proxy_len == 0) {
  auto *resp = request->beginResponse(200, "text/plain", "");
  add_common_headers_(resp);
  request->send(resp);
  return;
}
```

**Acceptance criteria:**
- `curl -v http://{agg_ip}/api/aggregator/proxy/{gw_id}/history/office/temp` returns `200` + CSV when satellite has data
- Same URL returns `200` with empty body when satellite has no history (not 502)
- Same URL returns `502` + `{"error":"upstream_fetch_failed","url":"..."}` JSON when satellite is unreachable
- Serial log shows `ESP_LOGW` when a fetch fails (visible in `esphome logs`)
- Existing proxy call sites (`probe_satellite_manifest_()`, status fetch, etc.) continue to work without modification (default parameters)

**Critical Rules checklist:**
- [ ] Rule 8: No `beginResponseStream` — uses `beginResponse()` ✓
- [ ] Rule 27: `lwip_setsockopt` (not `setsockopt`) for timeout ✓
- [ ] Rule 39: curl test uses `-d 'a=1'` (N/A for GET) ✓

---

### V1-B — Tech-debt #165 OPT-02: Disable NAS History Buffers

**Issue:** #165  
**Risk:** LOW  
**Effort:** 0.5 sessions  
**Version:** v7.6.7.0 (same PR as V1-A + V1-C)

**Files modified:**
- `firmware/core/data-model.h` (edit fragment, not assembled file)

**Expected gain:** ~2,328 B static SRAM (3 × 776 B HistoryBuffer)

**Implementation:**

In `firmware/core/data-model.h`, section `metrics_system[]` (line ~303):
```cpp
static const MetricDef metrics_system[] = {
  {"cpu_pct",  "CPU %",  METRIC_GAUGE, false},  // was: true — disable history
  {"ram_pct",  "RAM %",  METRIC_GAUGE, false},  // was: true — disable history
  {"disk_pct", "Disk %", METRIC_GAUGE, false},  // was: true — disable history
  {"uptime_hrs","Uptime", METRIC_GAUGE, false},
};
```

Delete the three static global HistoryBuffer definitions (lines ~318–320):
```cpp
// DELETE these three lines:
static HistoryBuffer entity_hbuf_nas01_cpu_pct;
static HistoryBuffer entity_hbuf_nas01_ram_pct;
static HistoryBuffer entity_hbuf_nas01_disk_pct;
```

Update `devices[4]` metric_states (lines ~391–393) to set `history = nullptr`:
```cpp
{.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
{.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
{.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
```

After edits: `bash scripts/assemble-sensor-history.sh --write && bash scripts/preflight.sh`

**Acceptance criteria:**
- `esphome compile firmware/esp32-c3-multi-sensor.yaml` compiles clean
- `curl http://{sat_ip}/api/v2/history/nas01/cpu_pct` returns `404` (no history endpoint for disabled metric)
- Boot log shows free heap increased by ~2.3 KB vs v7.6.6.8 baseline
- `curl http://{sat_ip}/api/v2/live` still returns NAS01 cpu/ram/disk current values

---

### V1-C — Tech-debt #165 OPT-05: Logger Level INFO → WARN

**Issue:** #165  
**Risk:** NONE  
**Effort:** 0.25 sessions  
**Version:** v7.6.7.0 (same PR as V1-A + V1-B)

**Files modified:**
- `firmware/esp32-c3-multi-sensor.yaml`

**Expected gain:** ~512–1,024 B static SRAM (logger format string table reduction)

**Implementation:**

Current (lines ~116–119 of `esp32-c3-multi-sensor.yaml`):
```yaml
logger:
  level: INFO
```

Change to:
```yaml
logger:
  level: WARN
  logs:
    wifi: ERROR
    api: ERROR
```

**Acceptance criteria:**
- Compile clean
- Serial output is quieter (no INFO-level periodic logs)
- Warnings and errors still appear (WiFi reconnect warnings, etc.)

---

### V1-D — Bug #171: Import Crash Fix (Rule 40 Violation)

**Issue:** #171  
**Risk:** MEDIUM-HIGH  
**Effort:** 2 sessions  
**Version:** v7.6.7.1

**Files modified:**
- `firmware/core/web-handler.h` (edit fragment, not assembled file)

**Problem:** `handle_import_begin_()` at line ~791 calls `build_import_epoch_map_()` synchronously on the httpd task. `build_import_epoch_map_()` reads NVS blobs (potentially many segments), which takes far more than 5 ms on C3 (violates Rule 40). This causes a watchdog reset on C3.

Additionally, line ~817 uses `beginResponseStream` (violates Rule 8).

**CONFLICT NOTE:** The current `handle_import_begin_()` at line ~817 uses `beginResponseStream`. This is a pre-existing Rule 8 violation that must be fixed as part of V1-D. The fix below uses `beginResponse()` instead.

**Implementation:**

1. Add atomic flag `s_import_ready` at file scope (near other `s_import_*` state variables):
```cpp
static volatile bool s_import_ready = false;
```

2. Add an import deferred task:
```cpp
static void import_epoch_map_task_(void *arg) {
  auto *handler = reinterpret_cast<HistoryWebHandler*>(arg);
  handler->build_import_epoch_map_deferred_();
  vTaskDelete(nullptr);
}
```

3. Modify `handle_import_begin_()` for the single-sensor path:
```cpp
// OLD (synchronous, violates Rule 40):
if (!build_import_epoch_map_()) { ... }

// NEW (deferred to task):
s_import_ready = false;
BaseType_t created = xTaskCreate(import_epoch_map_task_, "imp_epoch_map",
                                 8192, this, 5, nullptr);
if (created != pdPASS) {
  cleanup_import_state_();
  send_json_error_(request, 500, "Failed to create import task");
  return;
}
// Respond immediately
std::string body = "{\"ok\":true,\"status\":\"queued\"}";
auto *resp = request->beginResponse(200, "application/json", body);
add_common_headers_(resp);
request->send(resp);
return;
```

4. For the multi-sensor path (clears history), the existing `clear_persisted_history_()` call also needs evaluation. If it takes > 5 ms, defer similarly. Mark with a `// TODO(V1-D): measure on C3` comment if unsure — the issue body (#171) should include measurement results.

5. Add `/api/import/status` endpoint:
```cpp
// In canHandle() and handleRequest():
if (strcmp(p, "/api/import/status") == 0) {
  std::string body = s_import_ready ? "{\"ready\":true}" : "{\"ready\":false}";
  auto *resp = request->beginResponse(200, "application/json", body);
  add_common_headers_(resp);
  request->send(resp);
  return;
}
```

6. Gate `/api/import/d/` and `/api/import/w/` on `s_import_ready`:
```cpp
void handle_import_data_(...) {
  if (!authenticate_management_(request)) return;
  if (!s_import_ready) {
    send_json_error_(request, 409, "Import not ready — wait for /api/import/status");
    return;
  }
  // ... existing logic ...
}
```

7. Dashboard JS must poll `/api/import/status` before sending data chunks. Add polling loop in the dashboard import flow (file: `dashboard/core/app-shell.js` or relevant import component).

After edits: `bash scripts/assemble-sensor-history.sh --write && bash scripts/preflight.sh`

**Acceptance criteria:**
- `POST /api/import/begin` returns `{"ok":true,"status":"queued"}` immediately — no delay > 100 ms on C3
- `GET /api/import/status` returns `{"ready":false}` then `{"ready":true}` after task completes
- Full import sequence (begin → poll status → d/ × N → finish) completes on C3 without watchdog reset
- Free heap before and after import begin must not drop below 65 KB on C3 (task stack is on heap: -8,192 B during task)
- Existing Playwright tests for import pass (or are updated to poll status)

**Critical Rules checklist:**
- [ ] Rule 8: No `beginResponseStream` — uses `beginResponse()` ✓
- [ ] Rule 40: `build_import_epoch_map_()` deferred to xTaskCreate with ≥ 8192 B stack ✓
- [ ] Rule 41: httpd task does not block on NVS ✓

---

### V1-E — Enhancement #143: Version Badge in Dashboard Footer

**Issue:** #143  
**Risk:** LOW  
**Effort:** 0.5 sessions  
**Version:** v7.6.7.2

**Files modified:**
- `dashboard/dashboard.tmpl.html` — add badge span
- `dashboard/core/app-shell.js` — populate badge
- `scripts/preflight.sh` — add presence check
- Generated artifacts: `dashboard/dashboard.js`, `dashboard/dashboard.html`, `dashboard/dashboard.h`

**Implementation:**

1. Edit `dashboard/dashboard.tmpl.html`:
   - Find the footer area near `id="pointCount"` and `id="lastUpdate"` spans
   - Add `<span id="versionBadge" style="opacity:0.55;font-size:.65rem"></span>` between them

2. Edit `dashboard/core/app-shell.js`:
   - In `App.Boot.start()`, as the **first** action (before SSE setup):
   ```javascript
   const badge = document.getElementById('versionBadge');
   if (badge) badge.textContent = 'v' + App.version;
   ```

3. Add preflight check in `scripts/preflight.sh`:
   ```bash
   check_contains "dashboard_has_version_badge" "dashboard/dashboard.html" 'id="versionBadge"'
   ```

4. Rebuild pipeline:
   ```bash
   bash scripts/bundle-dashboard.sh --write
   bash scripts/build-dashboard.sh
   bash scripts/generate-header.sh
   bash scripts/preflight.sh
   ```

**Acceptance criteria:**
- Version badge shows `App.version` (e.g., `v7.6.7.2`) in the dashboard footer before SSE connects
- Badge visible in both light and dark mode
- Badge survives OTA reload (populated from JS, not from network)
- `grep 'id="versionBadge"' dashboard/dashboard.html` returns a result
- Preflight passes

**Critical Rules checklist:**
- [ ] Rule 47: Never edited `dashboard/dashboard.js` or `dashboard/dashboard.html` directly ✓
- [ ] Rule 48: Edited `dashboard/dashboard.tmpl.html` source, not the generated file ✓

---

### V1-F — Tech-debt #165 OPT-06: Delete Dead Stream Functions

**Issue:** #165  
**Risk:** NONE  
**Effort:** 0.25 sessions  
**Version:** v7.6.7.2 (same PR as V1-E + V1-G)

**Files modified:**
- `firmware/core/nvs-persistence.h` (edit fragment)
- `firmware/core/data-model.h` (edit fragment)

**Pre-condition:** Run `grep -rn "stream_snapshot_series_\|->stream_to(" firmware/` and confirm zero call sites before deleting.

**Implementation:**

1. Delete from `firmware/core/nvs-persistence.h` (lines ~381–411):
   - Delete `stream_snapshot_series_()` function body
   - Delete the comment at lines ~413–414 referencing this function

2. Delete from `firmware/core/data-model.h` (lines ~88–107):
   - Delete `HistoryBuffer::stream_to()` method

After edits: `bash scripts/assemble-sensor-history.sh --write && esphome compile firmware/esp32-c3-multi-sensor.yaml`

**Acceptance criteria:**
- `grep -rn "stream_snapshot_series_\|->stream_to(" firmware/` returns zero results
- `esphome compile firmware/esp32-c3-multi-sensor.yaml` compiles clean
- Preflight passes

---

### V1-G — Tech-debt #165 OPT-08: Import Session Timeout Comment

**Issue:** #165  
**Risk:** NONE  
**Effort:** 0.1 sessions  
**Version:** v7.6.7.2 (same PR as V1-E + V1-F)

**Files modified:**
- `firmware/core/web-handler.h` (edit fragment)

**Implementation:**

At `web-handler.h` ~line 779 (the start of `handle_import_begin_()`), add the following comment:
```cpp
// LESSON-OPS-NNN: import_snapshot_ (~6,710 B = sizeof(SegmentSnapshot)) is allocated
// on first call to handle_import_begin_() and held until cleanup_import_state_() is
// called. If the import session is abandoned (browser closed), this allocation is held
// until the next /api/import/begin call or a reboot. This is accepted behaviour —
// the allocation is bounded and a single session at a time is the expected pattern.
// See Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md RV-05 for rationale.
```

This is documentation only — no code change.

---

### V1 Operator Measurement Protocol (Between V1 and V2)

**This is NOT shipped code.** Before beginning V2, the operator must perform these measurements on a physical ESP32-C3 satellite running v7.6.7.2. Results feed the gate conditions for V2-H, V2-I, and V2-J.

**Step 1 — Baseline heap measurement at boot**

Add temporarily to `setup()` in `firmware/esp32-c3-multi-sensor.yaml` (or equivalent boot hook):
```cpp
ESP_LOGI("MEASURE", "=== HEAP BASELINE ===");
ESP_LOGI("MEASURE", "free_heap_total=%u", esp_get_free_heap_size());
ESP_LOGI("MEASURE", "free_heap_internal=%u", heap_caps_get_free_size(MALLOC_CAP_INTERNAL));
ESP_LOGI("MEASURE", "min_free_heap=%u", esp_get_minimum_free_heap_size());
```

**Step 2 — Heap after WiFi connects and sensors stabilise (~30 seconds post-boot)**

```cpp
ESP_LOGI("MEASURE", "=== HEAP AFTER WIFI + SENSORS STABLE ===");
ESP_LOGI("MEASURE", "free_heap_total=%u", esp_get_free_heap_size());
ESP_LOGI("MEASURE", "free_heap_internal=%u", heap_caps_get_free_size(MALLOC_CAP_INTERNAL));
```

**Step 3 — Heap under load (history endpoint hit)**

```bash
curl http://{sat_ip}/api/v2/history/office/temp
```

Capture free heap immediately after with Step 2 instrumentation.

**Step 4 — Heap during import session**

```bash
curl -u user:pass -d 'a=1' http://{sat_ip}/api/import/begin
```

Capture free heap during the import epoch map task.

**Step 5 — Heap during history export under HTTPS (Cloudflare Tunnel)**

If Cloudflare Tunnel is configured, hit the history endpoint through the tunnel and capture heap.

**Step 6 — httpd task stack watermark**

```cpp
// Add to any httpd request handler (temporarily, during a busy test period):
UBaseType_t httpd_watermark = uxTaskGetStackHighWaterMark(nullptr);
ESP_LOGI("MEASURE", "httpd_stack_watermark=%u words (%u bytes)",
         (unsigned)httpd_watermark, (unsigned)(httpd_watermark * 4));
```

**Step 7 — ping_adapter task stack watermark**

In `firmware/core/ping-adapter.h`, add to `ping_task_()`:
```cpp
UBaseType_t ping_watermark = uxTaskGetStackHighWaterMark(nullptr);
ESP_LOGI("MEASURE", "ping_adapter_stack_watermark=%u words (%u bytes)",
         (unsigned)ping_watermark, (unsigned)(ping_watermark * 4));
```

**Report results as this table before starting V2:**

| Measurement | Value | Gate |
|---|---|---|
| Free heap at boot (total) | ___ KB | > 65 KB required |
| Free heap at boot (internal) | ___ KB | > 65 KB required |
| Free heap under load (total) | ___ KB | > 55 KB required |
| httpd stack peak usage (bytes) | ___ B | Used for OPT-01 |
| httpd stack headroom (16384 - peak) | ___ B | ≥ 6144 → set 10240; ≥ 4096 → set 12288; ≥ 2048 → set 14336; < 2048 → no change |
| ping_adapter stack watermark (bytes) | ___ B | ≥ 512 headroom over 4096 → set 2048 |

---

## Sub-phase V2 (v7.6.8.x) — Security Hardening

**Version sequence:** v7.6.8.0 (V2-A + V2-B + V2-C + V2-D), v7.6.8.1 (V2-E + V2-F + V2-G), v7.6.8.2 (V2-H + V2-I + V2-J — gated, ship only if all gates pass)

### V2 Threat Model

Phase V V2 addresses the following threat landscape:

**Realistic attacker scope:**
- **LAN attacker:** A device on the same WiFi network (e.g., a compromised IoT device, a guest network bridge, ARP poisoning). Can reach all devices at their LAN IP addresses.
- **Internet attacker:** Any internet host reaching the aggregator via Cloudflare Tunnel or port-forward. Port 80, plain HTTP only.

**Attack surface:**
- Port 80, HTTP/1.1, no TLS. All traffic is cleartext.
- Basic Auth credentials transmitted with every authenticated request — visible to network observers.

**Key attack vectors:**
1. **Data injection via `/api/ingest/`** — An unauthenticated attacker can POST arbitrary sensor data, corrupting history and current readings. (Mitigated by V2-A)
2. **Rogue satellite SSRF via `/api/aggregator/add-satellite`** — An attacker can add a satellite pointing to an internal server (e.g., `http://192.168.0.1`), causing the aggregator to probe internal hosts. (Mitigated by V2-B + V2-F)
3. **Topology disclosure via `/api/aggregator/gateways` and `/api/status`** — Exposes all satellite IDs, URLs, and firmware versions without authentication. (Mitigated by V2-C + V2-D)
4. **History heap exhaustion via `/history/`** — Large history requests can exhaust C3 heap; issue #139. (Mitigated by V2-E)
5. **DoS via blocking probe in `handle_add_satellite_()`** — Repeated add-satellite requests cause blocking DNS/TCP probes on the httpd task. (Mitigated by V2-F)

**What cannot be fixed without TLS:**
Basic Auth credential eavesdropping. This is documented as a permanent residual vulnerability in `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` (RV-01).

---

### V2-A — Bug #163 SEC-01: Auth Guard on `/api/ingest/`

**Issue:** #163  
**Risk:** LOW (auth guard pattern is well-established)  
**Effort:** 0.25 sessions  
**Version:** v7.6.8.0

**Files modified:**
- `firmware/core/web-handler.h` → `handle_api_ingest_()`

**Implementation:**

In `handle_api_ingest_()`, add auth guard as the absolute first line:
```cpp
void handle_api_ingest_(AsyncWebServerRequest *request, ...) {
  if (!authenticate_management_(request)) return;
  // ... existing logic unchanged ...
}
```

Memory cost: ~250 B transient heap per request for Basic Auth header parsing.

Update all external push scripts and ESPHome sensors that POST to `/api/ingest/` to include `Authorization: Basic <base64(user:pass)>` header.

Add to `Docs/lessons/build-pipeline.md` as `LESSON-SEC-001`:
> All write endpoints (ingest, import, add/delete satellite, reboot, delete-data) are auth-gated. External callers must include `Authorization: Basic <base64>` header.

**Acceptance criteria:**
- `curl -d 'a=1' http://{sat_ip}/api/ingest/office/temp` returns `401`
- `curl -u user:pass -d 'sensor=office&metric=temp&value=21.5' http://{sat_ip}/api/ingest/office/temp` returns `200`

**Critical Rules checklist:**
- [ ] Rule 39: curl test uses `-d 'a=1'` ✓

---

### V2-B — Bug #163 SEC-02: Auth Guard on `/api/aggregator/add-satellite`

**Issue:** #163  
**Risk:** LOW  
**Effort:** 0.25 sessions  
**Version:** v7.6.8.0

**Files modified:**
- `firmware/core/web-handler.h` → `handle_add_satellite_()`

**Current state:** `handle_add_satellite_()` at line ~1657 has a comment at line ~1663:
```cpp
// NOTE: add-satellite intentionally does NOT require authenticate_management_().
// See LESSON-OPS-089.
```

**Implementation:**

Remove the LESSON-OPS-089 exception comment and add auth guard before URL validation:
```cpp
void handle_add_satellite_(AsyncWebServerRequest *request) const {
  if (!authenticate_management_(request)) return;  // SEC-02
  if (request->method() != HTTP_POST) { ... }
  // ... existing logic ...
}
```

Update `Docs/lessons/build-pipeline.md` to mark LESSON-OPS-089 as resolved:
> LESSON-OPS-089 [RESOLVED v7.6.8.0]: add-satellite now requires authentication. The exception has been removed.

**Acceptance criteria:**
- `curl -d 'a=1' http://{agg_ip}/api/aggregator/add-satellite` returns `401`
- `curl -u user:pass -d 'url=http://192.168.0.100' http://{agg_ip}/api/aggregator/add-satellite` proceeds to URL validation

---

### V2-C — Bug #163 SEC-03: Auth Guard on Aggregator Read Endpoints

**Issue:** #163  
**Risk:** LOW  
**Effort:** 0.5 sessions  
**Version:** v7.6.8.0

**Files modified:**
- `firmware/core/web-handler.h` → `handle_aggregator_gateways_()`, `handle_aggregator_live_()`, `handle_aggregator_proxy_()`

**Implementation:**

Add `if (!authenticate_management_(request)) return;` as the first line of each:
- `handle_aggregator_gateways_()` — topology disclosure prevention
- `handle_aggregator_live_()` — live sensor reading protection for aggregator view
- `handle_aggregator_proxy_()` — proxy history protection

Note: Dashboard JS already handles `401` responses with a credentials prompt (existing auth pattern). No JS changes required.

**Acceptance criteria:**
- `curl http://{agg_ip}/api/aggregator/gateways` returns `401`
- `curl -u user:pass http://{agg_ip}/api/aggregator/gateways` returns `200` + JSON
- Dashboard Settings panel continues to work (handles 401 prompt)

---

### V2-D — Bug #163 SEC-04: Strip Sensitive Fields from Public `/api/status`

**Issue:** #163  
**Risk:** MEDIUM (aggregator polling must be updated)  
**Effort:** 1 session  
**Version:** v7.6.8.0

**Files modified:**
- `firmware/core/web-handler.h` → `/api/status` handler and new `/api/status/full` endpoint
- `firmware/core/aggregator-runtime.h` → aggregator status polling code (calls `/api/status` on satellites)

**Implementation:**

1. Change public `/api/status` to return only non-sensitive fields:
```json
{"ok":true,"role":"satellite","id":"sat-c3-001"}
```
Remove: `version`, `free_heap`, `free_heap_internal`, `uptime_s`, `wifi_rssi`, `hardware`.

2. Add new `/api/status/full` endpoint (auth-gated):
```json
{
  "ok":true,
  "role":"satellite",
  "id":"sat-c3-001",
  "version":"7.6.8.0",
  "free_heap":58240,
  "free_heap_internal":58240,
  "uptime_s":3600,
  "wifi_rssi":-65
}
```

3. Add `fetch_to_buffer_authed()` helper or add `credentials` parameter to `fetch_to_buffer()`:
```cpp
static bool fetch_to_buffer(const char* url, char* buf, uint16_t buf_size, uint16_t* out_len,
                            int timeout_s = 5, int* out_http_status = nullptr,
                            const char* basic_auth = nullptr)
```

4. Update aggregator polling task (`agg_poll_task_()` in `aggregator-runtime.h`) to call `/api/status/full` with credentials for satellites where credentials are configured.

**Acceptance criteria:**
- `curl http://{sat_ip}/api/status` returns `{"ok":true,"role":"satellite","id":"..."}` only
- `curl http://{sat_ip}/api/status/full` returns `401`
- `curl -u user:pass http://{sat_ip}/api/status/full` returns full status JSON
- Aggregator dashboard still shows satellite heap/version info (via `/api/status/full`)

**Critical Rules checklist:**
- [ ] Rule 8: No `beginResponseStream` ✓
- [ ] Rule 24: `free_heap_internal` and `free_heap_total` reported separately in `/api/status/full` ✓

---

### V2-E — Bug #163 SEC-05: History Endpoint Heap Cap

**Issue:** #163, #139  
**Risk:** LOW  
**Effort:** 0.5 sessions  
**Version:** v7.6.8.1

**Files modified:**
- `firmware/core/web-handler.h` → `handle_history_()` and `handle_api_v2_history_()`

**Implementation:**

1. Add auth guard to both history endpoints:
```cpp
void handle_history_(AsyncWebServerRequest *request, ...) {
  if (!authenticate_management_(request)) return;
  ...
}
```

2. Cap `csv.reserve()`:
```cpp
size_t est_bytes = /* existing estimate */;
csv.reserve(std::min(est_bytes, (size_t)60000));
```

Note: 60,000 B is chosen as it fits within C3's safe heap margin (55–65 KB free) with ~5 KB remaining for other allocations. This is a safety net — the full fix (chunked streaming) is tracked in #139 for Phase 7.

**Acceptance criteria:**
- `curl http://{sat_ip}/api/v2/history/office/temp` returns `401`
- `curl -u user:pass http://{sat_ip}/api/v2/history/office/temp` returns `200` + CSV
- Large history request (many segments) does not crash C3 — heap stays ≥ 50 KB

---

### V2-F — Bug #163 SEC-02: add-satellite DoS Mitigation

**Issue:** #163  
**Risk:** LOW  
**Effort:** 0.5 sessions  
**Version:** v7.6.8.1

**Files modified:**
- `firmware/core/aggregator-runtime.h` or `web-handler.h` — add per-URL cooldown

**Implementation:**

Add a static probe cooldown map (keyed by URL hash) to limit repeated probes of the same failed URL:
```cpp
static uint32_t s_last_probe_fail_epoch[MAX_SATELLITES] = {};
static char s_last_probe_fail_url[MAX_SATELLITES][128] = {};
```

Before calling `probe_satellite_manifest_()`, check if the URL failed within the last 60 seconds:
```cpp
uint32_t now = sntp_get_current_timestamp();
for (int i = 0; i < MAX_SATELLITES; i++) {
  if (strcmp(s_last_probe_fail_url[i], url) == 0 &&
      now - s_last_probe_fail_epoch[i] < 60) {
    send_json_error_(request, 429, "Too many requests for this URL — retry after 60s");
    return;
  }
}
```

On probe failure, store the URL and epoch in the cooldown array.

**Acceptance criteria:**
- Two rapid `POST /api/aggregator/add-satellite?url=http://192.168.0.1` requests — second returns `429`
- After 60 seconds, request succeeds (proceeds to probe)

---

### V2-G — ADR: Known Residual Vulnerabilities

**Issue:** #163  
**Risk:** NONE (documentation only)  
**Effort:** 0.25 sessions (document already created)  
**Version:** v7.6.8.1

`Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` has been created alongside this plan. Commit it as part of V2-G.

---

### V2-H — Tech-debt #165 OPT-04: CONFIG_LWIP_MAX_SOCKETS 18 → 15 (Gated)

**Issue:** #165  
**Gate:** Real-device validation per LESSON-OPS-051 required before shipping  
**Risk:** MEDIUM if gate skipped; LOW if gate passes  
**Effort:** 0.5 sessions  
**Version:** v7.6.8.2

**Files modified:**
- `firmware/esp32-c3-multi-sensor.yaml`

**Implementation:**

Change line ~113:
```yaml
CONFIG_LWIP_MAX_SOCKETS: "18"
```
to:
```yaml
CONFIG_LWIP_MAX_SOCKETS: "15"
```

**Mandatory validation (gate condition):**
1. Flash updated firmware to C3 satellite
2. Open dashboard in SSE mode from **one browser tab**
3. Open dashboard in polling mode from **a second browser tab** simultaneously
4. Monitor serial logs for 5 minutes
5. **Required:** Zero `httpd_accept_conn: error in accept (23)` messages
6. If any ENFILE errors appear → revert to 18, document in #165 as OPT-04 blocked

**Never reduce below 13** (per LESSON-OPS-051 in lessons database).

Expected gain: ~1,800–2,400 B SRAM.

**Acceptance criteria:**
- Gate passes: 5-minute test with two tabs, zero ENFILE errors
- Document result (changed or not) in issue #165

---

### V2-I — Tech-debt #165 OPT-03: Reduce ping_adapter Stack (Gated)

**Issue:** #165  
**Gate:** Step 7 watermark ≥ 512 B headroom (4096 - peak ≥ 512)  
**Risk:** HIGH if gate skipped; LOW if gate passes  
**Effort:** 0.25 sessions  
**Version:** v7.6.8.2

**Files modified:**
- `firmware/core/ping-adapter.h` (edit fragment)

**Implementation:**

Find `xTaskCreate(ping_task_, "ping_adapter", 4096, ...)` (approximate line in ping-adapter.h) and change stack to 2048 only if Step 7 watermark shows ≥ 512 B headroom:
```cpp
xTaskCreate(ping_task_, "ping_adapter", 2048, ...);
```

If watermark shows < 512 B headroom: no change. Document result in #165.

After edits: `bash scripts/assemble-sensor-history.sh --write`

**Acceptance criteria:**
- Gate passes: watermark shows 4096 - peak_usage ≥ 512 B
- Ping sensor continues to report correctly after stack reduction
- No stack overflow panics in 30-minute test

---

### V2-J — Tech-debt #165 OPT-01: Right-Size httpd Task Stack (Gated)

**Issue:** #165  
**Gate:** Step 6 watermark result (see V1 measurement protocol)  
**Risk:** HIGH if gate skipped; LOW if gate passes  
**Effort:** 0.5 sessions  
**Version:** v7.6.8.2

**Files modified:**
- `firmware/local_components/web_server_idf/web_server_idf.cpp` — line ~124 (`config.stack_size = 16384`)
- `scripts/patch-esphome-httpd-stack.sh` — update the patched value for future ESPHome upgrades

**Decision table from Step 6 watermark:**

| Headroom (16384 - peak) | New stack size | Saving |
|---|---|---|
| ≥ 6,144 B | 10,240 B | 6,144 B |
| ≥ 4,096 B | 12,288 B | 4,096 B |
| ≥ 2,048 B | 14,336 B | 2,048 B |
| < 2,048 B | 16,384 B (no change) | 0 B |

**Hard rule:** Never set stack below `measured_peak + 2,048 B`.

Also update `scripts/patch-esphome-httpd-stack.sh` to apply the new value when re-run after an ESPHome upgrade.

**Acceptance criteria:**
- Stack size changed per decision table
- Dashboard operations (history load, export, SSE, auth) work correctly under new stack
- `patch-esphome-httpd-stack.sh` updated to reflect new patched value
- Document watermark result and action taken in #164 and #165

---

### V2 Auth Coverage Table (Post-V2 State)

See `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` — Auth Coverage Table section for the complete post-V2 state of all endpoints.

---

## Sub-phase V3 (v7.6.9.x) — Dashboard Enhancements and Export/Import

**Version sequence:** v7.6.9.0 (V3-A), v7.6.9.1 (V3-B + V3-C), v7.6.9.2 (V3-D + V3-E), v7.6.9.3 (V3-F if triggered; phase closure)

---

### V3-A — Enhancements #143 + #144 + #136: Dashboard Device Card Cleanup (Combined PR)

**Issues:** #143, #144, #136  
**Risk:** MEDIUM (dashboard JS + YAML changes in one PR)  
**Effort:** 2 sessions  
**Version:** v7.6.9.0

**Why combined:** All three issues touch the same device info card template, `DEVICE_INFO_MAP`, and both YAML configs. Splitting them would require three consecutive dashboard rebuilds with high merge-conflict risk.

**Files modified:**
- `dashboard/components/status-snapshot/index.js` — `DEVICE_INFO_MAP` updates
- `dashboard/components/manifest/index.js` (or `manifest.js`) — populate new fields
- `dashboard/dashboard.tmpl.html` — add new device info row IDs
- `firmware/esp32-c3-multi-sensor.yaml` — add flash/SRAM/PSRAM text_sensors
- `firmware/esp32-s3-multi-sensor.yaml` (or equivalent S3 YAML) — add PSRAM sensors
- Generated artifacts: `dashboard/dashboard.js`, `dashboard/dashboard.html`, `dashboard/dashboard.h`
- `scripts/preflight.sh` — add presence checks for new IDs

**Issue #144 (Gateway card cleanup):**
- Replace MAC address row with Device Name row using `di-device-name` ID
- Add Firmware Version row using `di-firmware-version` ID
- Move Framework/ESPHome info to Documentation card (not device card)
- Update `DEVICE_INFO_MAP` in `status-snapshot/index.js` with new field mappings
- Populate `di-device-name` and `di-firmware-version` from `/api/manifest` gateway object in `manifest/index.js`
- Update card title dynamically from manifest data

**Issue #136 (Hardcoded C3 values):**
- Add `di-flash` and `di-sram` IDs to device card template
- Add ESPHome `text_sensor` entities in YAML for Flash and SRAM using ESPHome template sensors
- Add `DEVICE_INFO_MAP` entries for `di-flash` and `di-sram`

**Issue #138 (PSRAM runtime sensor):**
- For S3: add ESPHome `sensor` entities for PSRAM total (`esp_psram_get_size()`) and PSRAM free (`heap_caps_get_free_size(MALLOC_CAP_SPIRAM)`)
- For C3 (no PSRAM): populate PSRAM field with `"None"` text
- Add `di-psram-total` and `di-psram-free` to `DEVICE_INFO_MAP`

**Rebuild pipeline:**
```bash
bash scripts/bundle-dashboard.sh --write
bash scripts/build-dashboard.sh
bash scripts/generate-header.sh
bash scripts/preflight.sh
```

**Acceptance criteria:**
- Device card shows Device Name and Firmware Version (not MAC)
- Device card shows Flash and SRAM sizes (from runtime text sensors, not hardcoded)
- S3 device card shows PSRAM total and free; C3 shows "None"
- All existing Playwright tests pass
- No regression in env/ping/system card rendering

**Critical Rules checklist:**
- [ ] Rule 47: No direct edits to `dashboard/dashboard.js` or `.html` ✓
- [ ] Rule 48: Edit `dashboard.tmpl.html` source, not generated file ✓
- [ ] Rule 58: No direct edit to `dashboard/sensor_history_multi.h` ✓

---

### V3-B — Enhancement #170: Satellite Gateway Card — Hostname and IP

**Issue:** #170  
**Risk:** MEDIUM  
**Effort:** 1 session  
**Version:** v7.6.9.1

**Files modified:**
- `firmware/core/web-handler.h` → `handle_aggregator_gateways_()`
- `dashboard/components/gateway-panel/index.js` — `renderAllGatewaysSummary()`, `renderGatewaySelector()`, `renderSettingsPanel()`
- Generated artifacts: rebuild pipeline

**Firmware changes:**

In `handle_aggregator_gateways_()`, after extracting `base_url` for each satellite:
1. Extract `hostname` from `sat.manifest_json`: search within the `"gateway":{` object only (to avoid false matches in sensor names)
2. Extract `ip` from `sat.base_url`: strip `http://` prefix, take the host portion
3. Emit `,\"hostname\":\"...\"` and `,\"ip\":\"...\"` in the gateways JSON response

**Dashboard changes:**

In `gateway-panel/index.js`:
- `renderAllGatewaysSummary()`: use `gw.hostname || gw.name` as display name; add IP row before Last Seen
- `renderGatewaySelector()`: use `hostname || name` as tab label
- `renderSettingsPanel()`: add hostname and IP to satellite settings cards

Rebuild pipeline after all JS changes.

**Acceptance criteria:**
- `curl -u user:pass http://{agg_ip}/api/aggregator/gateways` returns JSON with `hostname` and `ip` fields
- Dashboard gateway card shows hostname (e.g., `sat-c3-001.local`) and IP address
- Fallback to `name` if `hostname` not available in manifest

---

### V3-C — Enhancement #166: CSV Export — Role Column and Satellite Prefix

**Issue:** #166  
**Risk:** LOW-MEDIUM (CSV format change — backward-compatibility break documented)  
**Effort:** 1 session  
**Version:** v7.6.9.1 (same PR as V3-B)

**Files modified:**
- `dashboard/core/sensor-defs.js` — add `role` to `EXPORT_SHARED_COLUMNS`, add `getExportRole()`
- `dashboard/core/history.js` — update `buildSingleSensorCsv()` and `buildMergedSensorCsv()`
- Generated artifacts: rebuild pipeline

**⚠️ Breaking change:** The `role` column is inserted at position 3 (after `timestamp`, `sensor_id`, and before `metric_key`). Any existing positional CSV parser will break. This is accepted (see ordering rationale #7).

**Implementation:**

In `sensor-defs.js`:
```javascript
export const EXPORT_SHARED_COLUMNS = ['timestamp', 'sensor_id', 'role', 'metric_key', 'value', 'unit'];

export function getExportRole(sensor, manifest) {
  if (!manifest || !manifest.gateway) return 'unknown';
  return manifest.gateway.role || 'satellite';
}
```

In `history.js` `buildMergedSensorCsv()`:
- Apply `sensorSlug(satellite_name) + '_'` prefix to satellite sensor columns in aggregator export
- Column name format: `{sat_slug}_{sensor_id}_{metric_key}`

In `history.js` `buildSingleSensorCsv()`:
- Add `role` column populated by `getExportRole()`

**Acceptance criteria:**
- Single-sensor export CSV has `role` column (e.g., `satellite`)
- Aggregator merged export has `{sat_slug}_{sensor_id}_{metric_key}` column names
- Playwright tests cover both single and merged export formats

---

### V3-D — Feature #166 + #171: Manifest-Driven Metrics in Export

**Issues:** #166, #171  
**Gate:** V1-D (import crash fix) must be stable in production  
**Risk:** MEDIUM  
**Effort:** 1.5 sessions  
**Version:** v7.6.9.2

**Files modified:**
- `dashboard/core/history.js` — `fetchSensorHistoryRows()`
- `dashboard/core/sensor-defs.js` — replace `EXPORT_SENSOR_SUFFIXES` with `getMetricColumnsForSensor()`
- Generated artifacts: rebuild pipeline

**Implementation:**

Replace hardcoded `key === 'temp' || key === 'hum'` checks in `fetchSensorHistoryRows()` with iteration over all manifest metrics that have `history: true` in the sensor definition.

Replace `EXPORT_SENSOR_SUFFIXES` static array with:
```javascript
export function getMetricColumnsForSensor(sensor, manifest) {
  if (!manifest) return ['temp', 'hum']; // fallback for backward compat
  const sensorDef = manifest.sensors?.find(s => s.id === sensor.id);
  if (!sensorDef || !sensorDef.measurements) return [];
  return sensorDef.measurements
    .filter(m => m.history === true)
    .map(m => m.key);
}
```

This enables ping (`ping_ms`, `success_pct`) and system (`cpu_pct`, `ram_pct`, `disk_pct`) metrics to appear in exports — currently they appear as blank columns.

**Acceptance criteria:**
- Ping device CSV export has `wan_ping_ping_ms` and `wan_ping_success_pct` columns populated (not blank)
- System device CSV export has `nas01_cpu_pct`, `nas01_ram_pct`, `nas01_disk_pct` columns populated
- Environmental sensor export is unchanged (backward compatible)
- Playwright tests cover ping and system export formats

---

### V3-E — Enhancement #161/#162: Aggregator History Proxy — Final State Decision

**Issues:** #161, #162  
**Risk:** NONE (documentation only)  
**Effort:** 0.1 sessions  
**Version:** v7.6.9.2 (same PR as V3-D)

`Docs/decisions/AGG-ADR-001-satellite-history-storage.md` has been created alongside this plan. Commit it as part of V3-E, and close issue #162.

After committing the ADR:
- Close issue #161 with reference to the V1-A PR
- Close issue #162 with reference to the V3-E PR (ADR committed)

---

### V3-F — Tech-debt #165 OPT-07: Struct Padding Audit (Conditional)

**Issue:** #165  
**Gate:** Only execute if post-V2 `free_heap_internal` at boot is < 65 KB  
**Risk:** MEDIUM (struct change could affect serialisation)  
**Effort:** 1 session  
**Version:** v7.6.9.3 (if triggered; otherwise skip and close with no-change note)

**Condition for executing:**

Measure `free_heap_internal` at boot on C3 after all V2 changes are deployed. If result is ≥ 65 KB: **skip V3-F**, close with a comment documenting the measured heap and confirming the floor is safe.

**If executed:**

Audit `SensorEntity` struct for unused `MetricState` slots:
- `wan_ping` device uses 2 of `MAX_METRICS_PER_DEVICE=4` slots — the other 2 are wasted ~56 B
- `char temp_avg_str[32]`, `hum_avg_str[16]`, `batt_str[16]` on non-env devices — ~128 B waste

If audit confirms total gain < 300 B: document as v8 data model consideration and close with no code change. If gain ≥ 300 B: implement the struct changes.

**⚠️ Warning:** Any change to `SensorEntity` struct layout affects NVS serialisation compatibility. Verify that no NVS-persisted fields reference struct member offsets before making changes.

---

## §5.2 — Prompt Artefacts Specification

The following 7 prompt artefacts are to be produced by a **subsequent agent** after this plan is approved. They are NOT produced here. The subsequent agent must produce each file as a standalone executable prompt for a coding agent.

| File | Content required |
|---|---|
| `prompts/phaseV/phaseV-v1-agent-prompt.md` | Complete instructions for V1-A through V1-G. Must include: specific file paths, function names, line ranges (from this plan), exact code snippets for all changes, acceptance criteria as curl commands, Critical Rules checklist (Rules 8, 27, 38, 39, 40, 41, 47, 48, 58, 62), operator measurement protocol for #164 Steps 1–7, version sequence v7.6.7.0/7.1/7.2. Must NOT include V2 or V3 work. |
| `prompts/phaseV/phaseV-v2-agent-prompt.md` | Complete instructions for V2-A through V2-J. Must include: threat model summary, auth guard code snippets for each endpoint, `fetch_to_buffer()` signature change, `/api/status/full` new endpoint spec, SEC-ADR-001 commit instruction, gate conditions for V2-H/I/J, decision table for OPT-01, LESSON-OPS-051 reminder for OPT-04. Must state explicitly that V2-H/I/J ship ONLY if gates pass. |
| `prompts/phaseV/phaseV-v3-agent-prompt.md` | Complete instructions for V3-A through V3-F. Must include: dashboard rebuild pipeline commands, Playwright test requirements for each change, V3-C breaking-change documentation, V3-D manifest-driven metrics implementation, V3-F gate condition and no-change path, AGG-ADR-001 commit instruction. |
| `prompts/phaseV/phaseV-review-checklist.md` | PR review checklist for all three sub-phases. Must include: security-specific checks (no new unauthenticated write endpoints, no new `beginResponseStream`, no new `setsockopt` without `lwip_` prefix), dashboard rebuild verification, fragment assembly verification, Rule compliance check per rule, heap measurement verification for gated steps. |
| `prompts/phaseV/phaseV-handoff.md` | Handoff document from Phase V to Phase 7 planner. Must include: what Phase V changed (auth state, endpoint list, struct state), what Phase 7 inherits (open questions from AGG-ADR-001, binary sensor EventLog design, partition table change requirements), measurements from V1 operator protocol and V2 gate results. |
| `prompts/phaseV/phaseV-pr-audit-template.md` | PR audit template matching Phase Y format. Must include: PR metadata fields (title, version, issues closed), file change checklist, acceptance criteria verification commands, Critical Rules compliance grid, heap measurement table (pre/post for C3). |
| `prompts/phaseV/phaseV-conclusion-assessment.md` | Template for post-V3 conclusion assessment. Sections: plan vs actual (each step: shipped/deferred/changed), heap measurements at V1/V2/V3 closure, issues closed, issues deferred to Phase 7, lessons learned. To be completed after V3 merges. |

---

## Acceptance Criteria for This Plan

- [x] All 14 open issues have normalised titles (Part 0) with correct type prefixes
- [x] Every issue is assigned to a sub-phase (V1, V2, V3) or explicitly deferred to Phase 7
- [x] Every plan step has: file list, specific line references where known, acceptance criteria, risk rating (LOW/MEDIUM/HIGH), effort estimate (session count), Critical Rules checklist
- [x] The security threat model covers both LAN and internet attackers (V2 threat model section)
- [x] The auth coverage table is complete (all endpoints with post-V2 auth state) — see SEC-ADR-001
- [x] The two ADR documents are drafted (SEC-ADR-001, AGG-ADR-001)
- [x] The capacity study covers all 5 board types and all 6 sensor types — see `Docs/phase-V-capacity-study.md`
- [x] The capacity study produces partition size recommendations for 4 MB, 8 MB, 16 MB boards
- [x] The binary sensor event log recommendation is present — see capacity study §6
- [x] V1, V2, V3 version sequences are specified (v7.6.7.x, v7.6.8.x, v7.6.9.x)
- [x] No Phase 7 work is scheduled in Phase V
- [x] No fragment boundary changes (Rule 62) are in scope
- [x] No `sensor_history_multi.h` direct edits (Rule 58) are in scope
- [x] All dashboard changes go through `bundle-dashboard.sh --write` → `build-dashboard.sh` → `generate-header.sh` → `preflight.sh`
- [x] The plan specifies the 7 prompt artefacts to be produced after plan approval (§5.2)
- [x] The gated optimisation protocol (on-device measurement between V1 and V2) is described in detail (V1 operator measurement protocol section)
- [x] The import session timeout (~6.7 KB OPT-08 from #165) is documented as a comment-only change in V1-G

---

## Version Number Mapping

| Sub-phase | Version range | Description |
|---|---|---|
| Phase Y | v7.6.6.0–v7.6.6.8 | Sensor history fragment split |
| Phase D | v7.6.0.0–v7.6.0.5 | Runtime satellite management |
| **Phase V — V1** | **v7.6.7.0–v7.6.7.2** | **Critical fixes + zero-gate optimisations** |
| **Phase V — V2** | **v7.6.8.0–v7.6.8.2** | **Security hardening** |
| **Phase V — V3** | **v7.6.9.0–v7.6.9.3** | **Dashboard enhancements + export/import** |
| Phase 7 | v7.7.0.0–v7.7.2.3 | Per-device persistence engine |
| Phase E | v8.0.x | Captive portal setup + WiFi config |

---

## Risk Summary

| Step | Risk | Mitigation |
|---|---|---|
| V1-A Proxy 502 fix | MEDIUM | Signature change affects all `fetch_to_buffer` call sites — verify all callers |
| V1-B NAS history disable | LOW | Standard data-model change — no NVS format change |
| V1-C Logger level | NONE | Single YAML line change |
| V1-D Import crash fix | MEDIUM-HIGH | Task creation + flag + polling — complex state machine; test on C3 hardware |
| V1-E Version badge | LOW | Minimal JS + template change |
| V1-F Dead code deletion | NONE | Grep confirms zero call sites before deleting |
| V1-G Import comment | NONE | Documentation only |
| V2-A–C Auth guards | LOW | Well-established pattern; existing authenticate_management_() function |
| V2-D Status field strip | MEDIUM | Aggregator polling must be updated simultaneously |
| V2-E History auth + cap | LOW | Standard pattern |
| V2-F DoS cooldown | LOW | Static array, no heap allocation |
| V2-G ADR document | NONE | Documentation only |
| V2-H OPT-04 sockets | MEDIUM (if gate skipped) | Gate: 5-min two-tab test required |
| V2-I OPT-03 ping stack | HIGH (if gate skipped) | Gate: Step 7 watermark required |
| V2-J OPT-01 httpd stack | HIGH (if gate skipped) | Gate: Step 6 watermark required |
| V3-A Device card cleanup | MEDIUM | Multiple issues combined in one PR; dashboard rebuild required |
| V3-B Satellite hostname | MEDIUM | Firmware + dashboard change |
| V3-C CSV role column | LOW-MEDIUM | Breaking change documented |
| V3-D Manifest-driven export | MEDIUM | Replaces hardcoded column logic |
| V3-E ADR commit | NONE | Documentation only |
| V3-F Struct audit | MEDIUM | Only if gate triggers; struct change affects serialisation |

**Total estimated effort: 14–18 sessions across the three sub-phases.**

---

_End of Phase V implementation plan._
