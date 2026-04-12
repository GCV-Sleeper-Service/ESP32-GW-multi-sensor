# Phase V — Bug Fixing, Optimization & Security Hardening
## Master Prompt: Deep Research + Implementation Plan Generation

**Target versions:** v7.6.7.x · v7.6.8.x · v7.6.9.x  
**Date authored:** 2026-04-12  
**Prerequisite state:** Phase Y complete (v7.6.6.8 on `main`), Phase D complete (v7.6.0.5)

---

## Purpose of This Document

This is the **master research-and-planning prompt** for Phase V. Feed it to a deep-research agent to produce:

1. A detailed, sequenced implementation plan split across three sub-phases (V1 / V2 / V3)
2. Issue title normalisation proposals for all open issues
3. The memory/flash capacity research study (per board type, per sensor type)
4. Input sufficient for a subsequent agent to generate: agent prompts, review checklists, handoff documents, PR audit templates, and a plan conclusion assessment — matching the artefact set produced for Phase Y

---

## Part 0 — Pre-Research: Issue Title Normalisation

Before generating the plan, the agent must analyse every open issue and propose normalised titles following this taxonomy.

### Title taxonomy (five types only)

| Prefix | When to use | Example |
|--------|-------------|---------|
| `Bug:` | Confirmed misbehaviour — something that worked and broke, or never worked correctly | `Bug: Aggregator history proxy silently returns 502 — no diagnostic` |
| `Feature:` | New user-visible capability that does not exist yet | `Feature: Manifest-driven export for non-environmental sensors` |
| `Enhancement:` | Improvement to existing working functionality (UX, performance, correctness, code quality) | `Enhancement: Version badge in dashboard footer` |
| `Decision:` | Architectural or design choice that must be recorded before implementation can proceed | `Decision: Aggregator satellite history storage — proxy vs local copy` |
| `Tech-debt:` | Known shortcut, dead code, hardcoded value, or missing guard that must be cleaned up | `Tech-debt: Hardcoded C3 SRAM/flash values in dashboard template` |

### Rules

- Every issue title must start with exactly one of these five prefixes followed by a colon and a space.
- The description after the colon should be a complete, specific noun phrase — not a verb phrase.
- Include the version tag `(vX.Y.Z.W)` only when the issue was first observed in a specific version.
- Do NOT include issue numbers in the title — GitHub provides those.
- Security issues should use `Bug:` if a confirmed vulnerability, `Feature:` if a new hardening capability.

### Current open issues requiring normalisation

| # | Current title | Proposed normalised title |
|---|---------------|--------------------------|
| 136 | Hardcoded C3 values in dashboard | `Tech-debt: Hardcoded C3 SRAM/flash values in dashboard template` |
| 137 | Generate SVG files for each board type | `Feature: Board-type SVG diagrams for documentation and device-info card` |
| 138 | The gateway card does not show actual information about PSRAM or flash size | `Enhancement: Gateway card PSRAM and flash size from runtime sensors` |
| 139 | History loading serialization for C3 boards | `Bug: History loading heap exhaustion on ESP32-C3 (v7.5.x)` |
| 143 | No visible version badge on dashboard page | `Enhancement: Version badge in dashboard footer` |
| 144 | Update gateway card | `Enhancement: Gateway card — device name, firmware version, MAC removal` |
| 161 | Bug: Aggregator history proxy silently returns 502 — no diagnostic (v7.6.6.6) | `Bug: Aggregator history proxy silently returns 502 — no diagnostic (v7.6.6.6)` ✓ already correct |
| 162 | type: decision - how to get and keep satellite's sensor/device history to aggregator | `Decision: Aggregator satellite history storage — proxy vs local copy` |
| 163 | Security hardening | `Feature: Security hardening — endpoint auth, injection prevention, topology disclosure` |
| 164 | Memory footprint on satellites | `Bug: ESP32-C3 satellite heap regression >20 KB (v7.5.x–v7.6.0.x)` |
| 165 | Code optimization | `Tech-debt: ESP32-C3 SRAM reduction — seven targeted optimisations (v7.7.x)` |
| 166 | Fix data export format from boards | `Enhancement: CSV export — role column, satellite prefix, manifest-driven metrics` |
| 170 | Rework satellite gateway display card | `Enhancement: Satellite gateway card — hostname, IP address display` |
| 171 | Data export logic | `Bug: Import POST endpoints crash ESP32-C3 (Rule 40 violation); export is client-side only` |

The agent must apply these normalisations as part of the plan output and include issue-update instructions for each.

---

## Part 1 — Source Material to Read Before Planning

The agent must read all of the following before writing a single plan step.

### Architecture and reference plans (read in full)

- `Docs/phase-d-implementation-plan.md` — Phase D reference (runtime satellite management) — **use as structural template** for plan step format
- `Docs/phase-X-architecture-and-refactor-plan-dashboard.md` — dashboard module split (Phase X) — structural ref
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — fragment split (Phase Y) — structural ref
- `Docs/v7.7-implementation-plan.md` — Phase 7 per-device persistence engine — **do not schedule Phase 7 work in Phase V; but Phase V must not conflict with or preclude Phase 7**
- `Docs/v7.7-v7.8-persistence-architecture.md` — full persistence architecture — read §5, §12, §14, §15, §16 carefully

### Lessons database (constraints — must not violate)

- `Docs/lessons/build-pipeline.md` — all LESSON-OPS-* and LESSON-BUILD-* entries
- `Docs/lessons/firmware-rules.md` — all Critical Rules (Rule 8, 24, 27, 38, 39, 40, 41, 47, 48, 58, 62)
- `Docs/lessons/testing.md` — Playwright test patterns
- `Docs/lessons/security.md` — LESSON-SEC-* entries (if present)

### Active open issues (read bodies, not just titles)

Read the full body of each:

- #136 — Hardcoded C3 values in dashboard
- #137 — SVG files for board types
- #138 — PSRAM/flash size in gateway card
- #139 — History loading serialization for C3
- #143 — Version badge
- #144 — Update gateway card
- #161 — Proxy 502 bug
- #162 — Aggregator history decision
- #163 — Security hardening
- #164 — Memory footprint / heap regression
- #165 — Code optimisation
- #166 — Export format
- #170 — Satellite gateway display card
- #171 — Data export logic / import crash

### Firmware source fragments (read key sections)

- `firmware/core/web-handler.h` — focus on: `handle_aggregator_proxy_()`, `handle_api_ingest_()`, `handle_import_begin_()`, `handle_history_()`, `handle_add_satellite_()`
- `firmware/core/data-model.h` — focus on: `MetricDef`, `HistoryBuffer`, `SensorEntity`, `devices[]`, `metrics_system[]`, static globals
- `firmware/core/nvs-persistence.h` — focus on: `restore_from_nvs_()`, `persist_hourly_segment_()`, `stream_snapshot_series_()`, `HistoryBuffer::stream_to()`
- `firmware/core/ping-adapter.h` — focus on: `xTaskCreate` call, `ping_task_()`
- `firmware/core/aggregator-runtime.h` — focus on: `probe_satellite_manifest_()`, `fetch_to_buffer()`, polling task
- `firmware/esp32-c3-multi-sensor.yaml` — `CONFIG_LWIP_MAX_SOCKETS`, logger level
- `firmware/local_components/web_server_idf/web_server_idf.cpp` — httpd stack size
- `dashboard/core/history.js` — `fetchSensorHistoryRows()`, `buildSingleSensorCsv()`, `buildMergedSensorCsv()`
- `dashboard/core/sensor-defs.js` — `EXPORT_SENSOR_SUFFIXES`, `EXPORT_SHARED_COLUMNS`
- `dashboard/components/gateway-panel/index.js` — `renderAllGatewaysSummary()`, `renderGatewaySelector()`, `renderSettingsPanel()`
- `scripts/patch-esphome-httpd-stack.sh` — httpd stack patch script
- `scripts/preflight.sh` — current preflight checks

---

## Part 2 — Phase V Scope and Constraints

### What Phase V is

Phase V is a **three-sub-phase remediation and hardening cycle** targeting the open issues left by Phases X, Y, and D. It delivers:

- **V1 (v7.6.7.x):** Critical bug fixes and zero-gate optimisations — things that can ship immediately with no new on-device measurement required
- **V2 (v7.6.8.x):** Security hardening — auth extension, topology disclosure prevention, internet-exposure hardening
- **V3 (v7.6.9.x):** Dashboard enhancements, gated optimisations (after V1 watermark measurements), export/import correctness

### What Phase V is NOT

- **Not Phase 7.** The per-device persistence engine (v7.7.0.x) begins after Phase V closes. Phase V must not change `SegmentSnapshot`, `HistoryMeta`, `PERSIST_SLOTS`, `HISTORY_HOURS`, or `HISTORY_INTERVAL_MINUTES`.
- **Not a flash partition resize.** The 640 KB NVS partition increase (Item 7 in the request) is scheduled but is explicitly a **Phase 7 pre-step** (v7.7.0.0 or a preparatory PR). Phase V must not change partition tables — OTA-only constraint applies.
- **Not a sensor type expansion.** New sensor types (weather station, power meter, binary sensor) are documented in the capacity study (Part 4) for Phase 7 planning, not implemented in Phase V.

### Hard constraints inherited from prior phases

All Critical Rules from `Docs/lessons/firmware-rules.md` apply. Key ones for Phase V:

| Rule | Constraint |
|------|-----------|
| Rule 8 | Never use `beginResponseStream` for any response body — use pre-reserved `std::string` + `beginResponse()` |
| Rule 24 | Always report `free_heap_internal` and `free_heap_total` separately; they differ on S3 (PSRAM) |
| Rule 27 | All socket calls in ESPHome IDF context must use `lwip_*` prefix |
| Rule 38 | All POST `fetch()` calls from dashboard JS must use `Content-Type: application/x-www-form-urlencoded` |
| Rule 39 | All curl POST test commands must use `-d 'a=1'` (not `--data-raw`) |
| Rule 40 | NVS work longer than ~5 ms must be deferred to an `xTaskCreate` task with ≥ 8192 B stack |
| Rule 41 | The httpd task must never block on NVS I/O for more than one blob read/write |
| Rule 47 | Never edit `dashboard/dashboard.js` or `dashboard/dashboard.html` directly |
| Rule 48 | Never edit `dashboard/dashboard.tmpl.html` — edit source modules and regenerate |
| Rule 58 | Never edit `dashboard/sensor_history_multi.h` directly — edit fragments and run `assemble-sensor-history.sh --write` |
| Rule 62 | Fragment boundary changes require explicit sign-off — Phase V must not reorganise the 8-fragment split |

### Fragment boundary (Rule 62 reminder)

The 8 fragments are: `config.h`, `data-model.h`, `nvs-persistence.h`, `aggregator-runtime.h`, `web-handler.h`, `ping-adapter.h`, `deferred-management.h`, `registration.h`. All firmware changes in Phase V must edit the fragment files under `firmware/core/`, then run `bash scripts/assemble-sensor-history.sh --write` and `bash scripts/preflight.sh`.

---

## Part 3 — Implementation Plan Requirements

### Sub-phase V1 (v7.6.7.x) — Critical fixes and zero-gate optimisations

**Why first:** These items have no measurement gates, no design decisions pending, and directly unblock the dashboard for real use.

**Must include (all mandatory):**

#### V1-A — Bug #161: Proxy 502 diagnostic and timeout fix
- File: `firmware/core/web-handler.h` → `handle_aggregator_proxy_()`
- Add `ESP_LOGW` when `fetch_to_buffer` returns false
- Return `{\"error\":\"upstream_fetch_failed\",\"url\":\"...\"}` JSON body on 502 instead of empty
- Return HTTP 200 with empty body (not 502) when fetch succeeds but satellite has no history
- Add `timeout_s` parameter to `fetch_to_buffer()` (default 5, proxy passes 15)
- Add optional `out_status` int parameter to capture HTTP status code from satellite
- Update all existing call sites with the new signature
- Acceptance: `curl -v http://{agg_ip}/api/aggregator/proxy/{gw_id}/history/office/temp` returns 200+CSV when satellite has data; 200+empty when satellite has no history; 502+JSON when satellite unreachable

#### V1-B — Tech-debt #165 OPT-02: Disable NAS history buffers (static SRAM, no gate)
- File: `firmware/core/data-model.h` (edit the fragment, not the assembled file)
- Set `history_enabled = false` for all three `metrics_system[]` entries (cpu_pct, ram_pct, disk_pct)
- Delete `entity_hbuf_nas01_cpu_pct`, `entity_hbuf_nas01_ram_pct`, `entity_hbuf_nas01_disk_pct` static globals
- Update `devices[4]` metric_states to set `history = nullptr` for metrics 0–2
- Reassemble and run preflight
- Expected gain: ~2,328 B static SRAM
- Acceptance: `esphome compile firmware/esp32-c3-multi-sensor.yaml` clean; `/api/v2/history/nas01/cpu_pct` returns 404; free heap at boot increases by ~2.3 KB

#### V1-C — Tech-debt #165 OPT-05: Logger level INFO → WARN (no gate)
- File: `firmware/esp32-c3-multi-sensor.yaml`
- Change `logger: level: INFO` → `level: WARN`; change `wifi: WARN` → `wifi: ERROR`; change `api: WARN` → `api: ERROR`
- Expected gain: ~512–1,024 B
- This is a single-line YAML change — safe to ship in the same PR as OPT-02

#### V1-D — Bug #171 import crash fix (Rule 40 violation)
- File: `firmware/core/web-handler.h` (edit fragment, not assembled file)
- `handle_import_begin_()` must not call `build_import_epoch_map_()` synchronously on the httpd task
- Implement deferred task pattern: `xTaskCreate` task with ≥ 8192 B stack
- Respond immediately with `{\"ok\":true,\"status\":\"queued\"}` to the POST
- Add an atomic `s_import_ready` flag; `/api/import/d/` and `/api/import/w/` gate on this flag
- The deferred task sets `s_import_ready = true` after `build_import_epoch_map_()` completes
- Add `/api/import/status` endpoint returning `{\"ready\":true/false}` for dashboard polling
- Dashboard JS must poll `/api/import/status` before sending data chunks
- Acceptance: `POST /api/import/begin` does not crash or watchdog-reset ESP32-C3; confirmed with `free_heap` before and after; full import sequence (begin → d/ × N → finish) completes on C3

#### V1-E — Enhancement #143: Version badge in dashboard footer
- Edit `dashboard/dashboard.tmpl.html`: add `<span id=\"versionBadge\" style=\"opacity:0.55;font-size:.65rem\"></span>` between `pointCount` and `lastUpdate` spans
- Edit `dashboard/core/app-shell.js`: populate `versionBadge` as the **first** action in `App.Boot.start()`
- Add preflight check: `check_contains \"dashboard_has_version_badge\" dashboard/dashboard.html 'id=\"versionBadge\"'`
- Rebuild pipeline: `bundle-dashboard.sh --write`, `build-dashboard.sh`, `generate-header.sh`, `preflight.sh`
- Acceptance: badge shows `App.version` before SSE connects; visible in footer; survives OTA reload

#### V1-F — Tech-debt #165 OPT-06: Delete dead stream functions (after grep confirmation)
- Run `grep -rn \"stream_snapshot_series_\|->stream_to(\" firmware/` — must return zero call sites
- Delete `firmware/core/nvs-persistence.h:381–411` (`stream_snapshot_series_()`)
- Delete `firmware/core/data-model.h:88–107` (`HistoryBuffer::stream_to()`)
- Delete the comment at `nvs-persistence.h:413–414` referencing the deleted function
- Reassemble; compile; preflight
- Acceptance: grep returns zero results; compile clean

**V1 add instrumentation steps (do not ship — these are measurement-only PRs or manual steps):**

The plan must describe the on-device measurement protocol from #164 Steps 1–7 as a **human operator task** to be completed between V1 and V2. The plan must NOT try to automate or ship the measurement instrumentation — it is temporary `ESP_LOGI` code added manually and removed before the next PR. The measurement results feed the gates for V2 OPT-01, OPT-03, OPT-04.

**V1 version sequence:** v7.6.7.0 (V1-A+B+C), v7.6.7.1 (V1-D), v7.6.7.2 (V1-E+F)

---

### Sub-phase V2 (v7.6.8.x) — Security hardening

**Why second:** Security is the highest-priority non-crash concern. The internet-exposure requirement (both satellites and aggregators must be hardenable for internet access via polling mode) drives this entire sub-phase.

**Security threat model (must be stated in the plan):**

The plan must open with a threat model section for V2 that covers:
1. **Realistic attacker scope:** LAN attacker (shared WiFi, ARP poisoning, IoT device compromise) AND internet attacker (Cloudflare Tunnel or port-forward exposing the aggregator)
2. **Attack surface:** Port 80, plain HTTP only (TLS is memory-prohibitive at current heap budgets — document this explicitly as a residual risk)
3. **Key attack vectors:** data injection via `/api/ingest/`, rogue satellite SSRF via `/api/aggregator/add-satellite`, topology disclosure via `/api/aggregator/gateways` and `/api/status`, history heap exhaustion via `/history/`, DoS via blocking probe in `handle_add_satellite_()`
4. **What cannot be fixed without TLS:** Credential eavesdropping on Basic Auth. This must be explicitly documented as a **known residual vulnerability** in a `Docs/decisions/` ADR file.

**Must include:**

#### V2-A — Bug #163 SEC-01: Auth guard on `/api/ingest/`
- File: `firmware/core/web-handler.h` → `handle_api_ingest_()`
- Add `if (!authenticate_management_(request)) return;` as the first line
- Memory cost: ~250 B transient per request
- All callers (external push scripts, ESPHome sensors) must add `Authorization: Basic <base64>` header
- Update any existing curl test scripts for ingest to include `-u user:pass`
- Document in `Docs/lessons/build-pipeline.md` under a new LESSON-SEC-001 entry

#### V2-B — Bug #163 SEC-02: Auth guard on `/api/aggregator/add-satellite`
- File: `firmware/core/web-handler.h` → `handle_add_satellite_()`
- Add auth guard before URL parse (before line ~1671)
- Remove the LESSON-OPS-089 exception comment (the exception is now resolved)
- Update `Docs/lessons/build-pipeline.md` to mark LESSON-OPS-089 as resolved

#### V2-C — Bug #163 SEC-03: Auth guard on `/api/aggregator/gateways`
- Auth guard on `handle_aggregator_gateways_()`
- Auth guard on `handle_aggregator_live_()`
- Auth guard on `handle_aggregator_proxy_()`
- Note: dashboard handles 401 prompts for these — no JS changes required

#### V2-D — Bug #163 SEC-04 option (b): Strip sensitive fields from public `/api/status`
- Do NOT add auth guard to `/api/status` (aggregator polling task fetches this without credentials)
- Instead: remove `version`, `free_heap`, `free_heap_internal` from the public response
- Add a new auth-gated `/api/status/full` endpoint that returns the complete response (for dashboard and operator use)
- Update aggregator polling task to call `/api/status/full` with credentials
- This approach requires updating `fetch_to_buffer()` to optionally send Basic Auth headers
- The plan must describe the `fetch_to_buffer_authed()` helper or a `credentials` parameter

#### V2-E — Bug #163 SEC-05: History endpoint heap cap (partial mitigation)
- File: `firmware/core/web-handler.h` → `handle_history_()`
- Cap `csv.reserve()` to `MIN(est_bytes, 60000)` on all boards at C3 heap budget
- Add auth guard to `/history/` and `/api/v2/history/` — these are large-allocation endpoints
- Note: full fix (chunked streaming) is tracked in #139 for Phase 7 pre-work, not Phase V
- The cap is a safety net, not a complete fix; document this in the issue

#### V2-F — Bug #163 SEC-02 add-satellite DoS mitigation (per-IP cooldown)
- After adding auth (V2-B), add a per-satellite-URL cooldown: once a URL has been probed and failed, do not re-probe the same URL for 60 seconds
- Implement as a static `s_last_probe_epoch[MAX_SATELLITES]` array checked before `probe_satellite_manifest_()`
- This limits the httpd-blocking DoS impact even from authenticated attackers

#### V2-G — ADR: Known residual vulnerabilities
- Create `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`
- Must document:
  - Basic Auth credential eavesdropping (cleartext HTTP) — rated MEDIUM, permanent until TLS
  - TLS memory cost: estimated ~50–80 KB heap + ~200 KB flash — not feasible at current C3 budget; feasible on S3 with PSRAM but requires mbedTLS integration
  - `/api/status` public fields reduction (V2-D) as a partial mitigation for fingerprinting
  - History endpoint auth as a first-pass mitigation for #139 crash vector
  - Import session timeout leak (~6.7 KB held until next `/begin`) — documented, no code change
- This document is a permanent fixture — it must be updated when residual risks are resolved

**Internet-exposure hardening requirements (mandatory for V2):**

The plan must explicitly address what is required for safe internet exposure:

1. All write endpoints (ingest, import, add-satellite, delete, reboot, delete-data) must be auth-gated ✓ (V2-A through V2-C covers most; verify completeness against the #163 table)
2. All topology-disclosure endpoints (gateways, status with sensitive fields, manifest, storage-stats) must be either auth-gated or field-stripped
3. `/api/manifest` and `/sensors.json` — assess: these expose sensor topology. For internet exposure, add auth guard OR add to `Docs/decisions/SEC-ADR-001` as accepted risk
4. The plan must produce a final **auth coverage table** showing every endpoint, its method, current auth state after V2, and the residual risk rating

**V2 gated optimisations (from #165, executed in V2 after V1 measurements):**

These require the #164 on-device watermark results from Steps 6 and 7. The plan must gate them explicitly:

#### V2-H — Tech-debt #165 OPT-04: `CONFIG_LWIP_MAX_SOCKETS` 18 → 15 (gate: real-device validation per LESSON-OPS-051)
- File: `firmware/esp32-c3-multi-sensor.yaml`
- Change `CONFIG_LWIP_MAX_SOCKETS: \"18\"` → \"15\"`
- Mandatory validation: open dashboard in SSE mode from one tab AND polling mode from second tab simultaneously; monitor logs for 5 minutes; zero `httpd_accept_conn: error in accept (23)` messages required
- Never reduce below \"13\" under any circumstances
- Expected gain: ~1,800–2,400 B

#### V2-I — Tech-debt #165 OPT-03: Reduce `ping_adapter` stack (gate: Step 7 watermark ≥ 512 B headroom)
- File: `firmware/core/ping-adapter.h` (edit fragment)
- `xTaskCreate(ping_task_, \"ping_adapter\", 2048, ...)` — only if Step 7 watermark confirms ≥ 512 B headroom
- Document result (changed or not changed, with watermark value) in the issue

#### V2-J — Tech-debt #165 OPT-01: Right-size httpd task stack (gate: Step 6 watermark)
- File: `firmware/local_components/web_server_idf/web_server_idf.cpp`
- Apply the decision table from #165:
  - ≥ 6 KB headroom → 10,240 B (saves 6 KB)
  - ≥ 4 KB headroom → 12,288 B (saves 4 KB)
  - ≥ 2 KB headroom → 14,336 B (saves 2 KB)
  - < 2 KB headroom → no change
- Hard rule: never set below `measured_peak + 2,048 B`
- Also update `scripts/patch-esphome-httpd-stack.sh` to apply the new value when re-run after an ESPHome upgrade
- Document watermark result (value and action taken) in both #164 and #165

**V2 version sequence:** v7.6.8.0 (V2-A through V2-D), v7.6.8.1 (V2-E through V2-G + auth coverage table), v7.6.8.2 (V2-H through V2-J, gated — ship only if all gates pass)

---

### Sub-phase V3 (v7.6.9.x) — Dashboard enhancements and export/import correctness

**Why third:** Dashboard changes require the security work from V2 to be landed first (some endpoints need auth before the dashboard can reliably call them). Export correctness depends on V1-D (import crash fix) being stable.

**Must include:**

#### V3-A — Enhancement #143 + #144 + #136: Dashboard device card cleanup (combined PR)
- **#144**: Replace MAC row with Device Name row; add Firmware Version row; move Framework/ESPHome to Documentation card; update `DEVICE_INFO_MAP` in `status-snapshot.js`; populate `di-device-name` and `di-firmware-version` from `/api/manifest` in `manifest.js`; update card title dynamically
- **#136**: Add `di-flash` and `di-sram` IDs to device card template; add ESPHome `text_sensor` entities for Flash and SRAM to both C3 and S3 YAML configs; add `DEVICE_INFO_MAP` entries
- **#138**: Add ESPHome `sensor` or `text_sensor` for PSRAM total and free using `esp_psram_get_size()` and `heap_caps_get_free_size(MALLOC_CAP_SPIRAM)`; for C3 (no PSRAM), emit \"None\"; add to `DEVICE_INFO_MAP`
- All three are dashboard + YAML changes — one PR covering all three is correct (they all touch the same template and map)
- Rebuild pipeline required: `bundle-dashboard.sh --write`, `build-dashboard.sh`, `generate-header.sh`, `preflight.sh`

#### V3-B — Enhancement #170: Satellite gateway card — hostname and IP
- File: `firmware/core/web-handler.h` → `handle_aggregator_gateways_()`
- Extract `hostname` from `sat.manifest_json` (search within \"gateway\": object only to avoid false matches in sensor names)
- Extract `ip` from `sat.base_url` (strip `http://` prefix)
- Emit `,\"hostname\":\"...\"` and `,\"ip\":\"...\"` fields in the gateways JSON response
- File: `dashboard/components/gateway-panel/index.js`
- Update `renderAllGatewaysSummary()`: use `gw.hostname || gw.name` as display name; add IP row before Last Seen
- Update `renderGatewaySelector()`: use `hostname || name` as tab label
- Update `renderSettingsPanel()`: add hostname and IP to satellite settings cards
- Rebuild pipeline required

#### V3-C — Enhancement #166: CSV export — role column and satellite prefix
- This is the **dashboard-only quick win** from #166 — does NOT require the manifest-driven full fix
- File: `dashboard/core/sensor-defs.js`: add `role` to `EXPORT_SHARED_COLUMNS`; add `getExportRole()` function
- File: `dashboard/core/history.js`: add `role` column to `buildSingleSensorCsv()` and `buildMergedSensorCsv()`; apply `sensorSlug(satellite_name) + '_'` prefix to satellite sensor columns in aggregator export
- Acceptance criteria: single-sensor export has `role` column; aggregator export has `{sat_slug}_{sensor_id}_{metric_key}` columns; Playwright tests cover both

#### V3-D — Feature #166 + #171 (Phase V portion): Manifest-driven metrics in export
- This requires V1-D (import crash fix) to be stable and deployed
- File: `dashboard/core/history.js`: replace `key === 'temp'` / `key === 'hum'` hardcoding in `fetchSensorHistoryRows()` with iteration over all manifest metrics that have `history: true`
- File: `dashboard/core/sensor-defs.js`: replace `EXPORT_SENSOR_SUFFIXES` static array with `getMetricColumnsForSensor(sensor, manifest)` that reads `sensor.measurements[]`
- This enables ping (`ping_ms`, `success_pct`) and system (`cpu_pct`, `ram_pct`, `disk_pct`) metrics to appear in exports
- Acceptance: ping device CSV export has `wan_ping_ping_ms` and `wan_ping_success_pct` columns (not blank)

#### V3-E — Enhancement #161/#162: Aggregator history proxy — final state decision
- By V3, the proxy bug (#161) is fixed (V1-A). This step records the **architectural decision** (#162) as an ADR.
- Create `Docs/decisions/AGG-ADR-001-satellite-history-storage.md`
- Document: Option 1 (proxy, current) vs Option 2 (local copy) with the constraints from #162
- Record the **decision**: Option 1 (proxy) is confirmed as the v7.6.x short-term path; Option 2 is Phase 7 pre-work (v7.7.1.x)
- Include the open questions from #162 as unresolved items that Phase 7 must answer
- Close #162 once ADR is committed

#### V3-F — Tech-debt #165 OPT-07: Struct padding audit (conditional — only if V1+V2 gains insufficient)
- Gate: only execute if post-V2 `free_heap_internal` at boot is < 65 KB
- Audit `SensorEntity` struct for unused `MetricState` slots (`wan_ping` uses 2/4, wastes ~56 B)
- Audit `char temp_avg_str[32]`, `hum_avg_str[16]`, `batt_str[16]` on non-env devices (~128 B waste)
- If audit confirms gain < 300 B: document as v8 data model consideration and close with no code change
- Document result in #165 regardless

**V3 version sequence:** v7.6.9.0 (V3-A), v7.6.9.1 (V3-B + V3-C), v7.6.9.2 (V3-D + V3-E), v7.6.9.3 (V3-F if triggered; phase closure)

---

## Part 4 — Memory and Flash Capacity Research Study

**This is a separate research deliverable** — not a plan step, but a document to be produced alongside the plan. It will inform Phase 7 (per-device persistence, partition sizing, sensor expansion).

The agent must produce `Docs/phase-V-capacity-study.md` with the following structure:

### Study scope

For each of the following **board types**:
- **ESP32-C3 SuperMini** — 400 KB SRAM, no PSRAM, 4 MB flash (current satellite)
- **ESP32-S3 DevKitC1-N16R8** — ~512 KB internal SRAM, 8 MB PSRAM, 16 MB flash (current aggregator)
- **ESP32 WROOM-32D (generic 4 MB)** — 520 KB SRAM, no PSRAM, 4 MB flash (potential future satellite)
- **ESP32 with 8 MB flash** — same SRAM as WROOM-32D, larger flash
- **ESP32 with 16 MB flash** — same SRAM, maximum current flash size

For each of the following **sensor/device types**:

| Type | Metrics | History? | Notes |
|------|---------|---------|-------|
| Binary sensor | 1 (on/off) | Optional | e.g. leak detector, motion, light switch |
| Environmental sensor | 2 (temp + humidity) | Yes | Current production type |
| Network ping sensor | 2 (ping_ms + success_pct) | Yes | Current production type |
| System health sensor (NAS/Linux) | 4 (cpu_pct, ram_pct, disk_pct, uptime_hrs) | Partial (3/4) | Current production type |
| Weather station | 6 (temp, humidity, pressure, wind_speed, wind_gust, illumination) + 1 (rain_period) = 7 | Yes (all) | Future type |
| Power measurement sensor | 4 core (amps, volts, watts, energy_kwh) + 3 extended (energy_24h, energy_session, energy_tariff) = up to 7 | Yes (core) | Future type |

### Per-metric cost model

The study must establish and document the cost model for each metric:

```
Static SRAM cost per persistent metric:
  sizeof(HistoryBuffer) = 776 B  (HISTORY_POINTS_PER_SERIES=96, 8 bytes/point)
  sizeof(MetricState)  = ~28 B   (pointer + current value + validity flags)
  Total per persistent metric: ~804 B static

NVS flash cost per metric per segment:
  sizeof(SegmentSnapshot) ÷ NUM_METRICS_THAT_SEGMENT (current monolithic model)
  Under Phase 7 DeviceSegment model: ~226 B + overhead per segment per device
  At 1080 segments per device: 1080 × ~226 B = ~244 KB per device (NVS flash)

Task stack costs (one-time per task, not per metric):
  httpd task: 16,384 B (patched)
  ping_adapter task: 4,096 B (current), 2,048 B (post-OPT-03)
  agg_poll task: 10,240 B (AGGREGATOR_ENABLED only)
  hist_delete task: 8,192 B (on-demand transient)
```

### What the study must answer

For each board type, with a **mixed realistic deployment**:

1. **How many metrics of each type can be safely supported as persistent (history-enabled)?**
   - \"Safely\" = boot heap ≥ 65 KB on C3, ≥ 100 KB on S3/WROOM after all static allocations
   - With the Phase 7 partition size increase (640 KB NVS for 4 MB boards, proportionally larger for 8/16 MB boards)

2. **How many metrics can be supported as live-only (no history buffer)?**
   - Live-only metrics cost only `sizeof(MetricState)` per metric (~28 B) — no `HistoryBuffer`
   - This is the correct model for binary sensors (on/off state — no 96-point ring buffer needed)

3. **What is the NVS flash footprint for different retention periods?**
   - Current: 1080 segments × 15-minute intervals = 45 days × 24 hours = 1080 segments
   - Proposed: 640 KB NVS partition (4 MB board) — how many segments per device?
   - For a weather station with 7 persistent metrics: what retention is achievable?
   - For a mixed deployment (1 env + 1 ping + 1 system + 1 weather station): total NVS budget

4. **What is the maximum number of sensors a satellite can safely support (by mix)?**
   - Express as a table: N environmental + M ping + P system + Q weather at a given SRAM budget
   - Separate rows for C3 (400 KB SRAM), WROOM-32D (520 KB SRAM), S3 with PSRAM (8 MB PSRAM)

5. **What is the aggregator's capacity for satellite history storage?**
   - S3 with 16 MB flash and Phase 7 aggregator partition: how many satellites' full history can be stored locally?
   - At what point does the aggregator run out of NVS flash (not SRAM)?

6. **Binary sensor specifics:**
   - A binary sensor (leak, motion, on/off) has 1 metric with only two values
   - Is a 96-point ring buffer (`HistoryBuffer`) the right model? Or is an event log (timestamp + state change) more appropriate and efficient?
   - What would a compact binary event log cost vs a full `HistoryBuffer`?
   - Recommendation for Phase 7 on whether binary sensors should use `HistoryBuffer` or a new `EventLog` type

7. **Residual risks to document:**
   - Any metric count or sensor combination that approaches the heap floor and must be explicitly prohibited
   - Any combination that would require PSRAM to function (aggregator-only scenarios)

### Study format

The study must be structured as `Docs/phase-V-capacity-study.md` with:
- Executive summary table: board type × sensor mix → max safe metrics
- Cost model derivation (show the arithmetic)
- Per-board analysis sections
- Partition size recommendations for Phase 7 (for 4 MB, 8 MB, 16 MB boards)
- Binary sensor event log recommendation
- Constraints for Phase 7 implementation (what the per-device persistence engine must honour)

---

## Part 5 — Artefact Requirements

The plan must produce or specify the production of the following artefacts, matching the Phase Y artefact set:

### 5.1 Plan documents

| File | Content |
|------|---------|
| `Docs/phase-V-implementation-plan.md` | The full plan (sub-phases V1, V2, V3 with all steps, acceptance criteria, file lists, risk ratings, effort estimates) |
| `Docs/phase-V-capacity-study.md` | The memory/flash capacity study (Part 4) |
| `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` | Security ADR — known residual vulnerabilities |
| `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` | Aggregator history ADR — proxy vs local copy decision |

### 5.2 Prompt artefacts (to be produced after the plan is approved)

These are NOT produced by the research agent — they are produced by a subsequent agent given the plan. The plan must include a specification of what each prompt must cover:

| File | Produced by | Coverage required |
|------|-------------|-------------------|
| `prompts/phaseV/phaseV-v1-agent-prompt.md` | Post-plan agent | V1-A through V1-F; file list; Critical Rules checklist; acceptance criteria |
| `prompts/phaseV/phaseV-v2-agent-prompt.md` | Post-plan agent | V2-A through V2-J; threat model summary; auth coverage table template; gate conditions |
| `prompts/phaseV/phaseV-v3-agent-prompt.md` | Post-plan agent | V3-A through V3-F; dashboard rebuild pipeline; Playwright test requirements |
| `prompts/phaseV/phaseV-review-checklist.md` | Post-plan agent | PR review checklist for all three sub-phases; security-specific checks |
| `prompts/phaseV/phaseV-handoff.md` | Post-plan agent | Handoff document: what V changes to pass to Phase 7 planner |
| `prompts/phaseV/phaseV-pr-audit-template.md` | Post-plan agent | PR audit template matching Phase Y format |
| `prompts/phaseV/phaseV-conclusion-assessment.md` | After V3 complete | Plan conclusion assessment (what succeeded, what deferred, what Phase 7 inherits) |

### 5.3 Issue updates required

The plan must include explicit instructions for updating each open issue:
- Apply normalised title (Part 0)
- Add correct label(s) from the taxonomy: `bug`, `enhancement`, `feature`, `decision`, `tech-debt`, `security`, `memory`, `esp32-c3`, `dashboard`, `optimization`
- Add milestone: `v7.6.7.x` (V1), `v7.6.8.x` (V2), or `v7.6.9.x` (V3)
- Update acceptance criteria to match the plan steps
- Mark issues that will be closed by V1/V2/V3 with the closing PR reference

---

## Part 6 — Ordering Rationale (for the plan preamble)

The plan must include a **Why This Order** section explaining:

1. **V1 before V2:** Crashes (import, proxy) and zero-gate memory wins must ship first — they are the lowest risk, highest safety-margin items. A crashing import endpoint and a blind 502 proxy undermine confidence in the entire system. The SRAM gains from OPT-02 and OPT-05 actually *improve* the safety margin before security work adds auth overhead (~250 B/request).

2. **Security in V2, not V1:** Security hardening requires the proxy to be working (V1-A) and the import crash to be fixed (V1-D) before auth can be added to those endpoints. Adding auth to a crashing endpoint creates a false sense of security.

3. **Gated optimisations (OPT-01, OPT-03, OPT-04) in V2, not V1:** These require on-device watermark measurements from #164 Steps 6–7 that cannot be automated. The operator must run these measurements manually between V1 and V2. The plan must provide the exact measurement protocol and result-to-decision table.

4. **Dashboard in V3:** Dashboard enhancements (gateway card, export format, satellite card) depend on both the firmware changes from V2 (auth on gateways endpoint, new hostname/IP fields) and the export fix from V1-D (non-env metrics). They are lowest priority from a stability perspective and highest value from a usability perspective.

5. **Capacity study alongside V1:** The study does not block any implementation but must be complete before Phase 7 planning begins. Running it in parallel with V1 is efficient.

6. **Export format (#166 + #171) split across V1 and V3:** The import crash fix (V1-D) is a safety/correctness item that ships in V1. The export manifest-driven fix (V3-D) depends on V1-D being stable and is a usability enhancement — it ships in V3.

7. **No backward compatibility required for export CSV:** The requirement explicitly states that as long as existing CSV data can be re-imported (either directly or via a conversion tool), the format can change. The `role` column addition in V3-C inserts at position 3 — any existing positional parser will break. This is acceptable because no machine-readable pipeline currently consumes the export CSV. Document this breakage explicitly in the V3-C step.

8. **Flash partition resize deferred to Phase 7:** Partition table changes require a re-flash (not OTA-safe). Phase V is OTA-safe by design. The 640 KB partition plan is documented in the capacity study but executed as a Phase 7 pre-step.

---

## Part 7 — Acceptance Criteria for the Plan Itself

Before the plan is considered complete and ready for implementation, it must satisfy:

- [ ] All 14 open issues have normalised titles (Part 0) with correct type prefixes
- [ ] Every issue is assigned to a sub-phase (V1, V2, V3) or explicitly deferred to Phase 7
- [ ] Every plan step has: file list, specific line references where known, acceptance criteria, risk rating (LOW/MEDIUM/HIGH), effort estimate (session count), Critical Rules checklist
- [ ] The security threat model covers both LAN and internet attackers
- [ ] The auth coverage table is complete (all endpoints with post-V2 auth state)
- [ ] The two ADR documents are drafted (SEC-ADR-001, AGG-ADR-001)
- [ ] The capacity study covers all 5 board types and all 6 sensor types
- [ ] The capacity study produces partition size recommendations for 4 MB, 8 MB, 16 MB boards
- [ ] The binary sensor event log recommendation is present
- [ ] V1, V2, V3 version sequences are specified (v7.6.7.x, v7.6.8.x, v7.6.9.x)
- [ ] No Phase 7 work is scheduled in Phase V
- [ ] No fragment boundary changes (Rule 62) are in scope
- [ ] No `sensor_history_multi.h` direct edits (Rule 58) are in scope
- [ ] All dashboard changes go through `bundle-dashboard.sh --write` → `build-dashboard.sh` → `generate-header.sh` → `preflight.sh`
- [ ] The plan specifies the 7 prompt artefacts to be produced after plan approval (§5.2)
- [ ] The gated optimisation protocol (on-device measurement between V1 and V2) is described in detail
- [ ] The import session timeout (~6.7 KB OPT-08 from #165) is documented as a comment-only change with no code change needed, and is assigned to a specific step in V1 or V2

---

## Part 8 — Instructions to the Research Agent

You are the deep-research agent. Your job is to:

1. Read all source material listed in Part 1
2. Verify that the plan steps in Parts 3–4 are implementable given the actual code state — flag any step where your reading of the source shows the plan description is incorrect or incomplete
3. Produce the following output files in the repository under the `Docs/` directory:
   - `Docs/phase-V-implementation-plan.md` — the full plan (Parts 3 + ordering rationale + acceptance criteria + issue update instructions)
   - `Docs/phase-V-capacity-study.md` — the capacity study (Part 4)
   - `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`
   - `Docs/decisions/AGG-ADR-001-satellite-history-storage.md`
4. Do NOT produce the prompt artefacts (§5.2) — those are produced by a subsequent agent given the plan
5. Do NOT make any code changes — this is a research and planning output only
6. Flag any ambiguity or conflict between the plan and the Critical Rules or existing architecture as a **CONFLICT NOTE** in the relevant plan section

### Conflict resolution priority

If you find a conflict between this prompt and the source material:
1. Critical Rules win over this prompt
2. The lessons database wins over this prompt
3. This prompt wins over the issue bodies (the issue bodies are inputs, not constraints)
4. Use the Phase D plan format as the structural template for plan step presentation

### Output quality bar

Each plan step must be at the level of detail where a coding agent can execute it with no additional research — specific file names, specific function names, specific line ranges (approximate), specific variable names, specific acceptance criteria expressible as curl commands or `grep` patterns.