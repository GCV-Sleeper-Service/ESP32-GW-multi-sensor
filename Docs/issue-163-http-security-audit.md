# Issue #163 — HTTP Endpoint Access-Control Audit and Hardening

**Labels:** `security` `authentication` `aggregator` `firmware`  
**Dependencies:** Issue #164 (ingest auth), Issue #139 (HTTPS/TLS)

_Audit performed against: `firmware/core/web-handler.h`, `firmware/core/aggregator-runtime.h`,
`firmware/core/data-model.h`, `firmware/esp32-c3-multi-sensor.yaml` — firmware version v7.6.6.8._

---

## Threat Model

**Deployment context** (`Docs/architecture-overview.md`): The gateway operates on a local LAN,
accessible at `http://<hostname>:80`. There is no TLS, no VPN requirement, and no firewall
between LAN hosts and the gateway. HTTPS is explicitly deferred to Phase E (`v8.0.x`). The
aggregator (ESP32-S3) polls satellite gateways (ESP32-C3, WROOM) using unauthenticated
`HTTP/1.0 GET` requests (`aggregator-runtime.h` line 184).

**In-scope threat actors:**

- **LAN-adjacent attacker:** Any device on the same WiFi network (guest WiFi, VLAN-less home
  networks, corporate flat LAN). No authentication is needed to reach port 80.
- **Compromised IoT device on same segment:** Any smart TV, thermostat, or printer with shell
  access.
- **Passive LAN sniffer:** Any device capturing WiFi frames can read Basic Auth credentials
  since the transport is plain HTTP.
- **SSRF pivot via `add-satellite`:** The aggregator endpoint accepts attacker-controlled URLs
  and makes outbound TCP connections — a LAN recon vector.

**Out of scope (current phase):** Internet-exposed deployments (addressed in Phase E / #139).

**Authentication constants** (`firmware/core/data-model.h` lines 24–27):

| Constant | Value | Effect |
|---|---|---|
| `AUTH_FAILURE_DELAY_MS` | 900 ms | httpd task sleeps 0.9 s on each wrong password |
| `AUTH_LOCKOUT_MS` | 30,000 ms | 30 s lockout after `AUTH_MAX_FAILURES` failures |
| `AUTH_MAX_FAILURES` | 3 | Three wrong attempts trigger lockout |

---

## Complete Endpoint Audit

All endpoints are served on **port 80, plain HTTP, no TLS**. The `web_server:` block in
`firmware/esp32-c3-multi-sensor.yaml` (lines 232–258) configures no `auth:` block; the
custom `HistoryWebHandler` (registered at line 56 of the YAML) manages its own auth via
`authenticate_management_()` (`web-handler.h` line 361).

**CORS note:** `add_common_headers_()` (`web-handler.h` lines 319–323) adds
`Access-Control-Allow-Methods` and `Access-Control-Allow-Headers` but **no
`Access-Control-Allow-Origin`**. This prevents cross-origin browser requests but provides
no protection against non-browser clients (curl, Python, etc.).

### Standard endpoints (both satellite and aggregator builds)

| # | Path | Method | Handler | Auth required | Destructive / side-effects | Sensitive data exposed | Risk |
|---|------|--------|---------|:---:|---|---|:---:|
| 1 | `/favicon.ico` | GET | inline → 204 | — | None | None | LOW |
| 2 | `/dashboard`, `/dashboard.html` | GET | `handle_dashboard_(false)` | — | None | Dashboard HTML (no credentials) | LOW |
| 3 | `/dashboard-download` | GET | `handle_dashboard_(true)` | — | None | Same, as `Content-Disposition: attachment` | LOW |
| 4 | `/sensors.json` | GET | `handle_manifest_()` | — | None | Device IDs and friendly names | MEDIUM |
| 5 | `/api/manifest` | GET | `handle_api_manifest_()` | — | None | Gateway manifest: hardware model, all sensor IDs and names | MEDIUM |
| 6 | `/api/status` | GET | `handle_status_()` | — | None | Firmware version, uptime, free heap (internal + total), all device IDs/names/categories | MEDIUM |
| 7 | `/api/storage-stats` | GET | `handle_storage_stats_()` | — | NVS read | Partition layout, NVS entry counts, segment occupancy, `last_persist_epoch` | MEDIUM |
| 8 | `/api/v2/live` | GET | `handle_api_v2_live_()` | — | None | All current sensor readings and `last_seen` timestamps | MEDIUM |
| 9 | `/api/v2/history/{device}/{metric}` | GET | `handle_api_v2_history_()` | — | NVS read + large heap alloc (up to ~22 KB) | Full CSV history for every device and metric | MEDIUM |
| 10 | `/history/{id}/temp`, `/history/{id}/hum` | GET | `handle_history_()` | — | NVS read + large heap alloc (up to ~22 KB) | Full persistent + RAM sensor history CSV | MEDIUM |
| 11 | `/api/ingest/{device_id}/{metric_key}` | POST | `handle_api_ingest_()` | **NONE** | Writes live sensor state + history ring buffer | None directly; injects false readings | **HIGH** |
| 12 | `/api/reboot` | POST | `handle_reboot_()` | ✅ Basic Auth | Reboots device (deferred task) | None | CRITICAL if unauthenticated |
| 13 | `/api/delete-data` | POST | `handle_delete_data_()` | ✅ Basic Auth | Erases entire history NVS partition (deferred task) | None | CRITICAL if unauthenticated |
| 14 | `/api/import/begin` | POST | `handle_import_begin_(false, -1)` | ✅ Basic Auth | Erases all NVS history; allocates large heap buffer | None | HIGH |
| 15 | `/api/import/begin/single/{sensor}` | POST | `handle_import_begin_(true, idx)` | ✅ Basic Auth | Scans NVS (read); allocates epoch-map heap buffer | None | HIGH |
| 16 | `/api/import/d/{data}` | POST | `handle_import_data_(false)` | ✅ Basic Auth | Writes to in-memory snapshot buffer | None | HIGH |
| 17 | `/api/import/w/{data}` | POST | `handle_import_data_(true)` | ✅ Basic Auth | NVS blob write per call | None | HIGH |
| 18 | `/api/import/finish` | POST | `handle_import_finish_()` | ✅ Basic Auth | NVS metadata write; restores RAM from NVS | None | HIGH |
| 19 | `OPTIONS <any POST/DELETE route>` | OPTIONS | `handle_options_()` | — | None | None | LOW |

### Aggregator-only endpoints (`#if AGGREGATOR_ENABLED`, ESP32-S3 only)

| # | Path | Method | Handler | Auth required | Destructive / side-effects | Sensitive data exposed | Risk |
|---|------|--------|---------|:---:|---|---|:---:|
| 20 | `/api/aggregator/gateways` | GET | `handle_aggregator_gateways_()` | **NONE** | None | All satellite `base_url` (internal IPs), firmware versions, free heap values, full manifest JSON per satellite | **HIGH** |
| 21 | `/api/aggregator/live` | GET | `handle_aggregator_live_()` | — | None | All satellite sensor readings | MEDIUM |
| 22 | `/api/aggregator/proxy/{gw_id}/history/{device}/{metric}` | GET | `handle_aggregator_proxy_()` | **NONE** | Triggers live outbound TCP fetch; allocates `s_proxy_tmp` (32 KB static); blocks httpd task up to 5 s | History data from a satellite | **HIGH** |
| 23 | `/api/aggregator/add-satellite` | POST | `handle_add_satellite_()` | **NONE** (intentional — see line 1663) | NVS write; outbound TCP probe to attacker-supplied URL (SSRF); increments `runtime_satellite_count` | None directly | **CRITICAL** |
| 24 | `/api/aggregator/test-satellite` | POST | `handle_test_satellite_()` | ✅ Basic Auth | Outbound TCP probe to supplied URL (SSRF; no side-effects on pass) | Satellite manifest contents in response | MEDIUM |
| 25 | `/api/aggregator/satellite/{id}` | DELETE | `handle_delete_satellite_()` | ✅ Basic Auth | Removes satellite from runtime list; deferred NVS rewrite | None | HIGH |
| 26 | `/api/system/reset-satellites` | POST | `handle_reset_satellites_()` | ✅ Basic Auth | Erases `agg_sats` NVS namespace; reloads compile-time defaults | None | HIGH |

---

## Endpoints Crashable / Severely Impacted by Unauthenticated `curl`

| # | Command | Impact |
|---|---------|--------|
| A | `curl -X POST "http://<gw>/api/aggregator/add-satellite?url=http://192.168.1.254/"` | Triggers outbound TCP probe to attacker-supplied host (`s_proxy_tmp`, 32 KB); NVS write; adds hostile entry to satellite list; aggregator polls attacker host every 30 s (LAN recon). Repeatable to fill all `MAX_SATELLITES` slots (HTTP 409 from then on). |
| B | `curl -X POST "http://<gw>/api/ingest/office_temp/temperature?val=99.9"` | Injects false temperature reading into live state and history ring buffer. Any in-range float is accepted (`firmware/core/web-handler.h` lines 908–911). |
| C | `curl "http://<gw>/api/aggregator/proxy/sat1/history/sensor_id/temperature"` | Blocks the single-threaded httpd task for up to 5 s (`SO_RCVTIMEO=5`, `aggregator-runtime.h` line 173); allocates 32 KB `s_proxy_tmp`. Serial repetition DoSes all other HTTP clients. |
| D | Rapid flood of `curl "http://<gw>/history/sensor_id/temp"` | Each call triggers NVS scan + up to ~22 KB `std::string csv` heap allocation. Combined with an active SSE `/events` connection and TCP socket buffers, this can exhaust the C3's ~55 KB free heap. Observed crash pattern documented in BUG-043. |
| E | `for i in 1 2 3; do curl -u bad:pass -X POST "http://<gw>/api/reboot" -d a=1; done` | Three wrong-password attempts trigger `AUTH_LOCKOUT_MS = 30 s` lockout. Each attempt blocks the httpd task for `AUTH_FAILURE_DELAY_MS = 900 ms` before the lock (`web-handler.h` line 386) — ~2.7 s of httpd stall before lockout engages. Repeated attack permanently locks out the legitimate admin (lockout only resets on a successful authentication). |

---

## HTTP Basic Auth Memory Cost on ESP32-C3 (~55 KB Free Heap)

**Call path per authenticated request:**
`authenticate_management_()` (`web-handler.h:361`)
→ `request->get_header("Authorization")`
→ `trim_copy_()` (line 271)
→ `extract_basic_auth_()` (line 345)
→ `base64_decode_()` (line 288)

All allocations are `std::string` RAII objects, freed before the handler returns.

### Per-call heap allocations (short credentials, e.g., `admin:secret`)

| Object | Typical size | Notes |
|---|---|---|
| `auth_header` string copy in `trim_copy_()` | ~36 B (`Basic YWRtaW46c2VjcmV0`) | Temporary |
| `encoded` in `extract_basic_auth_()` | ~24 B (Base64 payload) | Temporary |
| `decoded` in `base64_decode_()` | ~13 B (`admin:secret`) | Temporary |
| `username` and `password` strings | ~5–6 B each | Stack-local to `authenticate_management_()` |
| `std::string` SSO overhead (libstdc++) | ~32 B per string | May be fully stack-allocated for short strings |
| **Total heap delta** | **~120–250 B** | All freed before handler returns |

### Stack depth

The YAML comment (`firmware/esp32-c3-multi-sensor.yaml` lines 92–98) documents the
httpd task stack was raised to 8,192 bytes specifically because the auth call chain
combined with large response generation exceeded the default 4,096-byte stack. The auth
chain itself adds approximately 400–600 bytes of stack frame depth.

### Summary table — cost of adding auth to currently-open endpoints

| Endpoint | Heap delta per call | Stack delta | Call frequency (C3) | Verdict |
|---|---|---|---|---|
| `POST /api/ingest/` | ~250 B (freed on return) | ~500 B | ~6× per hour per sensor | **Negligible** |
| `GET /api/aggregator/gateways` | ~250 B | ~500 B | On dashboard open | Negligible |
| `GET /api/aggregator/proxy/…` | ~250 B | ~500 B | On chart fetch | Negligible |
| `POST /api/aggregator/add-satellite` | ~250 B | ~500 B | Manual (rare) | Negligible |
| All `/history/` and `/api/v2/history/` reads | ~250 B | ~500 B | On dashboard open | Negligible vs. ~22 KB CSV alloc |

**Conclusion:** Adding Basic Auth to all currently-unauthenticated endpoints costs at most
~400 bytes of peak heap per request — less than 1% of the 55 KB C3 baseline. The real
memory threats are the history CSV `std::string` allocation (up to ~22 KB) and the
aggregator `s_proxy_tmp` static buffer (32 KB, aggregator / S3 build only). Auth overhead
is not the bottleneck and is safe to add on the C3.

---

## Ranked Vulnerabilities

| Rank | ID | Endpoint | Severity | Description |
|------|----|----------|:---:|---------|
| 1 | V-01 | `POST /api/aggregator/add-satellite` | **CRITICAL** | Unauthenticated NVS write + SSRF via attacker-supplied URL. Deliberate exception documented at `web-handler.h` lines 1663–1668; `LESSON-OPS-089` deferred this issue. |
| 2 | V-02 | `POST /api/ingest/{device}/{metric}` | **HIGH** | Unauthenticated sensor data injection; any valid float in range is accepted. Tracked in #164. |
| 3 | V-03 | `GET /api/aggregator/gateways` | **HIGH** | Exposes all satellite internal IPs, firmware versions, and free heap without auth (`web-handler.h` line 1431). |
| 4 | V-04 | `GET /api/aggregator/proxy/…` | **HIGH** | Unauthenticated; blocks httpd task up to 5 s; triggers 32 KB heap pressure on each call. |
| 5 | V-05 | All HTTP traffic | **HIGH** | No TLS — Basic Auth credentials are visible in plaintext to any LAN sniffer. Tracked in #139. |
| 6 | V-06 | `GET /api/status` | MEDIUM | Exposes firmware version, uptime, and free heap without auth; aids targeted exploitation (`web-handler.h` line 1233). |
| 7 | V-07 | Auth lockout DoS | MEDIUM | Three wrong-password attempts lock out all admin access for 30 s; `AUTH_FAILURE_DELAY_MS = 900 ms` blocks the httpd task during each attempt (`data-model.h` lines 24–26, `web-handler.h` line 386). |
| 8 | V-08 | `/history/…`, `/api/v2/history/…` | MEDIUM | Unauthenticated reads trigger large NVS scan + heap alloc; repeated calls can exhaust C3 heap (BUG-043). |
| 9 | V-09 | Missing `Access-Control-Allow-Origin` | LOW | Prevents cross-origin browser attacks but is not a substitute for authentication (`add_common_headers_()`, `web-handler.h` line 319). |

---

## Three-Tier Fix Plan

### Tier 1 — Immediate (no architecture change, low risk)

**T1-A: Add auth to `POST /api/aggregator/add-satellite`** *(resolves V-01)*

- Call `authenticate_management_(request)` at the top of `handle_add_satellite_()`
  (`web-handler.h` line 1657), before the URL parameter check.
- Remove the `LESSON-OPS-089` deferral comment (lines 1663–1668).
- Add the route to `is_management_post_route_()` (line 13) so the
  "Non-empty body required" pre-check also applies.
- Dashboard JavaScript for the add-satellite UI must supply Basic Auth credentials
  (same pattern already used for delete / reset-satellites).

**T1-B: Add URL allowlist validation before satellite probe** *(reduces SSRF severity for V-01 and T2-B)*

- Before calling `probe_satellite_manifest_()`, reject URLs whose host is a loopback
  address (`127.x.x.x`) or link-local address (`169.254.x.x`).
- Optional: compile-time `SATELLITE_ALLOWED_SUBNET` constant to restrict probes to a
  specific LAN prefix.
- Affects both `handle_add_satellite_()` and `handle_test_satellite_()`.

**T1-C: Add auth to `GET /api/aggregator/gateways`** *(resolves V-03)*

- Call `authenticate_management_(request)` at the top of `handle_aggregator_gateways_()`
  (`web-handler.h` line 1431). The dashboard settings panel already handles the
  401/credentials flow for other management endpoints.

**T1-D: Add auth to `GET /api/aggregator/proxy/…`** *(resolves V-04)*

- Call `authenticate_management_(request)` at the top of `handle_aggregator_proxy_()`
  (`web-handler.h` line 1557). The proxy is only consumed by the dashboard chart panel;
  the same credentials flow applies.

### Tier 2 — Short-term (requires cross-component coordination)

**T2-A: Add authentication to `POST /api/ingest/`** *(resolves V-02; tracked in #164)*

- The ingest endpoint is called by external push sources (Home Assistant automations,
  shell scripts). Requiring auth means all callers must be updated.
- **Option A:** Reuse the same Basic Auth credentials already in `secrets.yaml`.
- **Option B:** A separate per-device ingest token stored in NVS (`ingest_token` key),
  supplied as `Authorization: Bearer <token>`.
- Memory cost per ingest auth call: ~250 B heap delta (see table above — well within C3 budget).
- Cross-cutting dependency: blocked on #164 for the API contract and caller update plan.

**T2-B: Non-blocking auth failure delay** *(mitigates V-07 httpd stall)*

- `AUTH_FAILURE_DELAY_MS = 900` currently calls `vTaskDelay()` from within the httpd
  task (`web-handler.h` line 386), blocking all other HTTP requests for 0.9 s per failure.
- Replace with a timestamp-based approach: record the failure timestamp in
  `lockout_until_ms_` logic; return HTTP 429 immediately if fewer than 900 ms have
  elapsed since the last failure. This enforces the same rate limit without blocking the
  httpd task.

**T2-C: Rate-limit unauthenticated history endpoints** *(mitigates V-08 DoS)*

- Track `last_history_response_ms` globally; return 429 if a new history request arrives
  within 1 s of the previous one.
- Alternative: require auth for all `/history/` and `/api/v2/history/` endpoints
  (dashboard can provide credentials). Cost per read: ~250 B heap, negligible.

### Tier 3 — Strategic (Phase E and beyond)

**T3-A: TLS / HTTPS** *(resolves V-05; tracked in #139)*

- Without TLS, Basic Auth credentials are visible to any LAN sniffer.
- Phase E (`v8.0.x`) adds captive portal and WiFi config. TLS should accompany this phase.
- Self-signed certificate stored in flash; mDNS `.local` name as SubjectAltName.

**T3-B: Mutual authentication for aggregator → satellite polling**

- Currently the aggregator polls satellites with anonymous `HTTP/1.0 GET` requests
  (`aggregator-runtime.h` line 184).
- A compromised or spoofed satellite can serve arbitrary JSON to the aggregator's cache.
- Add a shared HMAC-SHA256 token (stored in NVS on both sides) as an `X-Auth-Token`
  request header. Memory cost: ~512 B stack for HMAC-SHA256 context; acceptable on the
  S3 aggregator (PSRAM available).

**T3-C: Add `Content-Security-Policy` and `X-Frame-Options` headers to dashboard responses**

- Mitigates drive-by browser attacks if the user visits a malicious page while on the
  same LAN and the gateway's IP is predictable.

---

## Acceptance Criteria

- [ ] `POST /api/aggregator/add-satellite` returns HTTP 401 without a valid
  `Authorization: Basic …` header (resolves V-01).
- [ ] `GET /api/aggregator/gateways` returns HTTP 401 without credentials (resolves V-03).
- [ ] `GET /api/aggregator/proxy/…` returns HTTP 401 without credentials (resolves V-04).
- [ ] `probe_satellite_manifest_()` rejects loopback (`127.x.x.x`) and link-local
  (`169.254.x.x`) destination IPs before making the TCP connection (T1-B).
- [ ] Dashboard settings panel can still add, test, and delete satellites using the
  existing credentials flow.
- [ ] All 402 existing Playwright browser tests pass.
- [ ] Preflight passes all 68 checks.
- [ ] `POST /api/ingest/` auth-guarding is explicitly deferred to #164 with a blocking
  dependency noted in this issue.
- [ ] TLS hardening is explicitly deferred to #139.

---

## Dependencies

| Issue | Relationship |
|-------|-------------|
| **#164** | Ingest endpoint authentication (T2-A) — defines the token/credential scheme before `/api/ingest/` can be hardened. Does **not** block Tier 1 work in this issue. |
| **#139** | HTTPS / TLS (T3-A) — required before Basic Auth credentials are safe from LAN sniffing. Until #139 is resolved, Tier 1 fixes reduce authorization gaps but credentials remain sniffable over HTTP. |

---

## Out of Scope

- Internet-exposed deployments (Phase E / #139).
- Changes to the `SegmentSnapshot` binary layout or NVS key scheme.
- Aggregator mutual-auth implementation (T3-B) in the current phase.
- ESPHome native API authentication (separate component, separate issue).
- CORS policy changes beyond what is required by browser clients.

---

_End of document._
