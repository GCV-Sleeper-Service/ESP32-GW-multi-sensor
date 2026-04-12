# Issue #163 — Security Hardening: Endpoint Auth Gap, Data Injection, and Topology Disclosure

**Labels:** `security` `firmware` `aggregator` `satellite`  
**Milestone:** v7.7.x  
**Depends on:** #164 (heap budget), #139 (history crash)  
**Blocked by:** #165 (heap recovery — confirms C3 budget headroom before auth work begins)

_Audit performed against: `firmware/core/web-handler.h`, `firmware/core/aggregator-runtime.h`,
`firmware/core/data-model.h`, `firmware/esp32-c3-multi-sensor.yaml` — firmware version v7.6.6.8._

---

## Threat Model

**Deployment context** (`Docs/architecture-overview.md`): The gateway operates on a local LAN,
accessible at `http://<hostname>:80`. There is no TLS, no VPN requirement, and no firewall
between LAN hosts and the gateway. HTTPS is explicitly deferred to Phase E (`v8.0.x`). The
aggregator (ESP32-S3) polls satellite gateways (ESP32-C3, WROOM) using unauthenticated
`HTTP/1.0 GET` requests (`aggregator-runtime.h` line 184).

**Realistic attacker:** A device on the same LAN segment as the gateway (home network user,
IoT device compromise, or Cloudflare Tunnel misconfiguration exposing the aggregator
externally). NOT an internet attacker — no ports are forwarded and the firmware has no
HTTPS/TLS capability at current heap budgets.

**Attack surface:** Port 80 on every gateway device. All requests are plain HTTP. Credentials
sent via Basic Auth are base64-encoded and trivially readable if traffic is observed.

**In-scope threat actors:**

- **LAN-adjacent attacker:** Any device on the same WiFi network (guest WiFi, VLAN-less home
  networks, corporate flat LAN). No authentication is needed to reach port 80.
- **Compromised IoT device on same segment:** Any smart TV, thermostat, or printer with shell access.
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
| 9 | `/api/v2/history/{device}/{metric}` | GET | `handle_api_v2_history_()` | — | RAM ring buffer read only — **bounded ~2 KB max alloc** (96 points × 20 B/line); no NVS scan | Full in-RAM CSV history for one metric | MEDIUM |
| 10 | `/history/{id}/temp`, `/history/{id}/hum` (legacy) | GET | `handle_history_()` | — | **NVS scan + unbounded heap alloc up to ~86 KB** (1080 segments × 80 B/line, pre-reserved `std::string`); deterministic crash when SSE active on C3 | Full persistent + RAM sensor history CSV | **HIGH** |
| 11 | `/api/ingest/{device_id}/{metric_key}` | POST | `handle_api_ingest_()` | **NONE** | Writes live sensor state + history ring buffer; **if persist task runs while ring buffer contains injected data, fake value is committed to NVS and survives reboot** | None directly; injects false readings | **CRITICAL** |
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
| 22 | `/api/aggregator/proxy/{gw_id}/history/{device}/{metric}` | GET | `handle_aggregator_proxy_()` | **NONE** | Triggers live outbound TCP fetch; allocates `s_proxy_tmp` (32 KB static); blocks httpd task up to 5 s | Proxied satellite history CSV | **HIGH** |
| 23 | `/api/aggregator/add-satellite` | POST | `handle_add_satellite_()` | **NONE** (intentional — see line 1663, LESSON-OPS-089) | NVS write; outbound TCP probe to attacker-supplied URL (SSRF); persists rogue satellite across reboots | None directly | **CRITICAL** |
| 24 | `/api/aggregator/test-satellite` | POST | `handle_test_satellite_()` | ✅ Basic Auth | Outbound TCP probe to supplied URL (SSRF; no side-effects on pass) | Satellite manifest contents in response | HIGH |
| 25 | `/api/aggregator/satellite/{id}` | DELETE | `handle_delete_satellite_()` | ✅ Basic Auth | Removes satellite from runtime list; deferred NVS rewrite | None | HIGH |
| 26 | `/api/system/reset-satellites` | POST | `handle_reset_satellites_()` | ✅ Basic Auth | Erases `agg_sats` NVS namespace; reloads compile-time defaults | None | HIGH |

---

## History Endpoint Heap Risk Clarification

**These two endpoint families have fundamentally different risk profiles and must not be grouped:**

| Endpoint | Heap source | Max alloc | Crash risk |
|---|---|---|---|
| `GET /api/v2/history/{device}/{metric}` | RAM ring buffer only (`HistoryBuffer`, 96 points) | ~2 KB (96 × 20 B/line + overhead) | **None** — bounded at compile time |
| `GET /history/{id}/temp` (legacy) | NVS scan — reads all `PERSIST_SLOTS=1080` segments | **Up to ~86 KB** (1080 × 80 B/line, pre-reserved `std::string`) | **Deterministic crash on C3** when SSE is active and free heap is ~55 KB |

The legacy `/history/` path calls `csv.reserve(est_bytes)` (`web-handler.h:1376`) where
`est_bytes = est_points * 20 + 128`. With a full NVS partition at 45-day history:
`1080 segments × 4 points × 20 B = ~86,400 B`. The C3 free heap of ~55 KB cannot satisfy
this allocation when SSE and TCP socket buffers are live. This is the primary mechanism
in the #139 crash. Auth alone does not fix the allocation size; it reduces anonymous
triggering but the real mitigation is tracked in #139.

`/api/v2/history/` is safe: it reads only the in-RAM `HistoryBuffer` (96 points,
pre-allocated static), never touches NVS, and produces at most ~2 KB of CSV. It cannot
crash the C3 regardless of NVS state.

---

## Endpoints Crashable / Severely Impacted by Unauthenticated `curl`

| # | Command | Impact |
|---|---------|--------|
| A | `curl -X POST "http://<gw>/api/aggregator/add-satellite?url=http://192.168.1.254/"` | Triggers outbound TCP probe to attacker-supplied host; NVS write; adds hostile entry to satellite list which survives reboot |
| B | `curl -X POST "http://<gw>/api/ingest/office/temp?val=99.9"` | Injects false temperature reading into live state and history ring buffer. If hourly persist runs while injected data is in the ring buffer, the fake value is committed to NVS and survives reboot |
| C | `curl "http://<gw>/api/aggregator/proxy/sat1/history/sensor_id/temperature"` | Blocks the single-threaded httpd task for up to 5 s (`SO_RCVTIMEO=5`, `aggregator-runtime.h` line 173); allocates 32 KB from `s_proxy_tmp` |
| D | Rapid flood of `curl "http://<gw>/history/sensor_id/temp"` | Each call triggers NVS scan + up to **~86 KB** `std::string csv` pre-reserve. With an active SSE `/events` connection on C3 (~55 KB free heap), the first or second call causes heap exhaustion and crash (#139) |
| E | `for i in 1 2 3; do curl -u bad:pass -X POST "http://<gw>/api/reboot" -d a=1; done` | Three wrong-password attempts trigger `AUTH_LOCKOUT_MS = 30 s` lockout. Each attempt blocks the httpd task for 900 ms (`vTaskDelay`) — all HTTP requests stall during this window |

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
| `auth_header` string copy in `trim_copy_()` | ~36 B | Temporary |
| `encoded` in `extract_basic_auth_()` | ~24 B | Temporary |
| `decoded` in `base64_decode_()` | ~13 B | Temporary |
| `username` and `password` strings | ~5–6 B each | Stack-local to `authenticate_management_()` |
| `std::string` SSO overhead (libstdc++) | ~32 B per string | May be fully stack-allocated for short strings |
| **Total heap delta** | **~120–250 B** | All freed before handler returns |

### Stack depth

The auth chain adds approximately 400–600 bytes of stack frame depth. The httpd task stack
was raised to 16,384 B (BUG-075) to accommodate the full auth + response generation path.

### Summary table — cost of adding auth to currently-open endpoints

| Endpoint | Heap delta per call | Stack delta | Call frequency (C3) | Verdict |
|---|---|---|---|---|
| `POST /api/ingest/` | ~250 B (freed on return) | ~500 B | ~6× per hour per sensor | **Negligible** |
| `GET /api/aggregator/gateways` | ~250 B | ~500 B | On dashboard open | Negligible |
| `GET /api/aggregator/proxy/…` | ~250 B | ~500 B | On chart fetch | Negligible |
| `POST /api/aggregator/add-satellite` | ~250 B | ~500 B | Manual (rare) | Negligible |
| `GET /history/` (legacy) | ~250 B | ~500 B | On dashboard open | Negligible vs. **~86 KB** CSV alloc |
| `GET /api/v2/history/` | ~250 B | ~500 B | On dashboard open | Negligible vs. ~2 KB CSV alloc |

**Conclusion:** Adding Basic Auth to all currently-unauthenticated endpoints costs at most
~250 bytes of peak heap per request — less than 0.5% of the 55 KB C3 baseline. Auth overhead
is not the bottleneck and is safe to add on the C3.

---

## Ranked Vulnerabilities

| Rank | ID | Endpoint | Severity | Description |
|------|----|----------|:---:|---------|
| 1 | SEC-01 | `POST /api/ingest/{device}/{metric}` | **CRITICAL** | Unauthenticated sensor data injection. Any valid float is accepted. If the hourly persist task runs while injected data is in the ring buffer, the fake value is committed to NVS and **survives reboot**. Handler: `handle_api_ingest_()`, `web-handler.h` line 530. |
| 2 | SEC-02 | `POST /api/aggregator/add-satellite` | **CRITICAL** | Unauthenticated NVS write + SSRF via attacker-supplied URL. Rogue satellite entry **persists across reboots**. Aggregator polls attacker-controlled host on every cycle. Deliberate exception documented at `web-handler.h` lines 1663–1668 (LESSON-OPS-089). |
| 3 | SEC-03 | `GET /api/aggregator/gateways` | **HIGH** | Exposes all satellite internal IPs, firmware versions, free heap values, and full manifest JSON without auth. `web-handler.h` line 1431. |
| 4 | SEC-04 | `GET /history/{id}/temp\|hum` (legacy) | **HIGH** | Unauthenticated. Each request allocates up to **~86 KB** `std::string` from heap (NVS-unbounded). **Deterministic crash on C3** (~55 KB free heap) when SSE is active. Primary mechanism in #139. Auth reduces anonymous triggering; allocation cap tracked in #139. |
| 5 | SEC-05 | `GET /api/aggregator/proxy/…` | **HIGH** | Unauthenticated. Blocks httpd task up to 5 s per call; triggers 32 KB `s_proxy_tmp` allocation on every request. `web-handler.h` line 1557. |
| 6 | SEC-06 | All HTTP traffic | MEDIUM | No TLS — Basic Auth credentials visible in plaintext to any LAN sniffer. Tracked in #139. |

**Note on `/api/v2/history/`:** This endpoint is **not** a crash vector. It reads only the
in-RAM `HistoryBuffer` (96 points, ~2 KB max), never scans NVS, and is bounded at compile
time. It does not appear in the vulnerability ranking above.

---

## Aggregator-Satellite Auth Interaction

The aggregator's polling task (`aggregator_poll_task`, `aggregator-runtime.h` line 536)
calls `fetch_to_buffer()` for three satellite endpoints every poll cycle:
- `GET {base_url}/api/v2/live` (line 597)
- `GET {base_url}/api/status` (line 644)
- `GET {base_url}/api/manifest` (line 683)

`fetch_to_buffer()` (line 124) sends a minimal `HTTP/1.0 GET` with `Host` and
`Connection: close` headers only — **no Authorization header**.

**Consequence:** These three satellite endpoints **cannot be auth-guarded** without first
modifying `fetch_to_buffer()` to send credentials. Tier 1 work therefore must **NOT** add
auth to `/api/v2/live`, `/api/status`, or `/api/manifest` on the satellite. These endpoints
remain open read-only endpoints, consistent with the model of "readings are public,
management operations are authenticated."

**When satellite read auth is desired (Tier 3):** Modify `fetch_to_buffer()` to accept an
optional `const char* auth_header` parameter. The aggregator's satellite config (in
`SatelliteCache`) gains `poll_user[32]` + `poll_pass[32]` fields populated from NVS or
compile-time constants. Build the `Authorization: Basic <base64>` header string and inject
into the HTTP request builder at line 183.

---

## Three-Tier Fix Plan

### Tier 1 — Immediate (no architecture change, low risk)

**T1-A: Add auth to `POST /api/aggregator/add-satellite`** *(resolves SEC-02)*

- Call `authenticate_management_(request)` at the top of `handle_add_satellite_()`
  (`web-handler.h` line 1657), before the URL parameter check.
- Remove the `LESSON-OPS-089` deferral comment (lines 1663–1668).
- Dashboard JavaScript for the add-satellite UI must supply Basic Auth credentials
  (same pattern already used for delete / reset-satellites).

**T1-B: Add URL allowlist validation before satellite probe** *(reduces SSRF severity for SEC-02)*

- Before calling `probe_satellite_manifest_()`, reject URLs whose host is a loopback
  address (`127.x.x.x`) or link-local address (`169.254.x.x`).
- Optional: compile-time `SATELLITE_ALLOWED_SUBNET` constant to restrict probes to a
  specific LAN prefix.
- Affects both `handle_add_satellite_()` and `handle_test_satellite_()`.

**T1-C: Add auth to `GET /api/aggregator/gateways`** *(resolves SEC-03)*

- Call `authenticate_management_(request)` at the top of `handle_aggregator_gateways_()`
  (`web-handler.h` line 1431). The dashboard settings panel already handles the
  401/credentials flow for other management endpoints.

**T1-D: Add auth to `GET /api/aggregator/proxy/…`** *(resolves SEC-05)*

- Call `authenticate_management_(request)` at the top of `handle_aggregator_proxy_()`
  (`web-handler.h` line 1557). The proxy is only consumed by the dashboard chart panel;
  the same credentials flow applies.

### Tier 2 — Short-term (requires cross-component coordination)

**T2-A: Add authentication to `POST /api/ingest/`** *(resolves SEC-01)*

- The ingest endpoint is called by external push sources (Home Assistant automations,
  shell scripts). Requiring auth means all callers must be updated.
- **Option A:** Reuse the same Basic Auth credentials already in `secrets.yaml`.
- **Option B:** A separate per-device ingest token stored in NVS (`ingest_token` key),
  supplied as `Authorization: Bearer <token>`.
- Memory cost per ingest auth call: ~250 B heap delta — well within C3 budget.
- Cross-cutting dependency: blocked on #164 for the API contract and caller update plan.

**T2-B: Non-blocking auth failure delay** *(mitigates V-07 httpd stall)*

- `AUTH_FAILURE_DELAY_MS = 900` currently calls `vTaskDelay()` from within the httpd
  task (`web-handler.h` line 386), **blocking all other HTTP requests for 0.9 s per failure**.
  Under the lockout-triggering sequence (3 bad attempts), the httpd task is blocked for
  2.7 s total before the 30 s lockout activates.
- Replace with a timestamp-based approach: record the failure timestamp in
  `lockout_until_ms_` logic; return HTTP 429 immediately if fewer than 900 ms have
  elapsed since the last failure. This enforces the same rate limit without blocking the
  httpd task and without stalling legitimate concurrent requests.
- **File:** `web-handler.h` line 386.

**T2-C: Rate-limit or auth-guard legacy history endpoint** *(mitigates SEC-04 crash vector)*

- Auth guard on `/history/` reduces anonymous triggering but does not fix the allocation
  size. The full fix (allocation cap or chunked streaming) is tracked in #139.
- Interim option: track `last_legacy_history_ms` globally; return 429 if a new `/history/`
  request arrives within 2 s of the previous one.

### Tier 3 — Strategic (Phase E and beyond)

**T3-A: TLS / HTTPS** *(resolves SEC-06; tracked in #139)*

- Without TLS, Basic Auth credentials are visible to any LAN sniffer.
- Phase E (`v8.0.x`) adds captive portal and WiFi config. TLS should accompany this phase.
- Self-signed certificate stored in flash; mDNS `.local` name as SubjectAltName.

**T3-B: Aggregator polls satellites with auth credentials**

- Modify `fetch_to_buffer()` (`aggregator-runtime.h` line 124`) to accept an optional
  `Authorization` header. Add `poll_user[32]` + `poll_pass[32]` to `SatelliteCache`
  populated from NVS. Required before `/api/status`, `/api/v2/live`, `/api/manifest`
  on satellites can be auth-guarded.

**T3-C: Mutual authentication for aggregator → satellite polling**

- Add a shared HMAC-SHA256 token (stored in NVS on both sides) as an `X-Auth-Token`
  request header. Memory cost: ~512 B stack for HMAC-SHA256 context; acceptable on the
  S3 aggregator (PSRAM available).

**T3-D: Add `Content-Security-Policy` and `X-Frame-Options` headers to dashboard responses**

- Mitigates drive-by browser attacks if the user visits a malicious page while on the
  same LAN and the gateway's IP is predictable.

---

## Acceptance Criteria

All of the following must return `HTTP 401` without credentials:
```bash
# SEC-01: Ingest injection rejected
curl -o /dev/null -w "%{http_code}" -X POST "http://<gw>/api/ingest/office/temp?val=25.0"
# Expected: 401

# SEC-02: Satellite add rejected
curl -o /dev/null -w "%{http_code}" -X POST "http://<agg>/api/aggregator/add-satellite?url=http://192.168.1.1"
# Expected: 401

# SEC-03: Gateways topology rejected
curl -o /dev/null -w "%{http_code}" "http://<agg>/api/aggregator/gateways"
# Expected: 401

# SEC-05: Proxy rejected
curl -o /dev/null -w "%{http_code}" "http://<agg>/api/aggregator/proxy/sat1/history/office/temp"
# Expected: 401
```

All authenticated endpoints must continue to return `HTTP 200` with correct credentials:
```bash
# Reboot must still work with auth
curl -o /dev/null -w "%{http_code}" -u "admin:password" -X POST "http://<gw>/api/reboot" -d "a=1"
# Expected: 200

# Aggregator polling must still succeed (satellite read endpoints remain open)
curl -s "http://<sat>/api/v2/live"
# Expected: 200 with JSON sensor data

curl -s "http://<sat>/api/status"
# Expected: 200 with JSON status

curl -s "http://<sat>/api/manifest"
# Expected: 200 with JSON manifest
```

Rate limiting must activate after 3 failures:
```bash
for i in 1 2 3 4; do
  curl -o /dev/null -w "%{http_code}\n" -u "wrong:creds" -X POST "http://<gw>/api/reboot" -d "a=1"
done
# Expected: 401 401 401 429
```

T2-B non-blocking delay: the fourth request above must return within 50 ms (not after a 900 ms `vTaskDelay`):
```bash
time curl -o /dev/null -w "%{http_code}" -u "wrong:creds" -X POST "http://<gw>/api/reboot" -d "a=1"
# Expected: 429, elapsed < 100 ms
```

`probe_satellite_manifest_()` must reject loopback and link-local before TCP connect:
```bash
curl -o /dev/null -w "%{http_code}" -u "admin:password" -X POST \
  "http://<agg>/api/aggregator/add-satellite?url=http://127.0.0.1/"
# Expected: 400 (rejected before probe)
```

---

## Dependencies

| Issue | Relationship |
|-------|-------------|
| **#164** | Heap recovery — confirm C3 free heap ≥ 60 KB before starting Tier 1. Auth adds ≤ 1 KB persistent overhead — this headroom is required. |
| **#165** | Code optimization — ingest endpoint authentication (T2-A) shares the same handler update. Does **not** block Tier 1 work. |
| **#139** | HTTPS / TLS (T3-A) — required before Basic Auth credentials are safe from LAN sniffing. Also tracks the legacy `/history/` allocation cap (SEC-04 full fix). Until #139 is resolved, Tier 1 fixes reduce authorization gaps but credentials remain sniffable on the LAN. |

---

## Out of Scope

- Internet-exposed deployments (Phase E / #139)
- HTTPS/TLS: requires ~60–80 KB peak heap + ~50 KB persistent heap for mbedTLS. C3 budget after #165 is ~68–70 KB total free. TLS would consume the entire budget. **Explicitly deferred until a future phase that brings C3 to ≥100 KB free heap.** S3 aggregator could technically support TLS, but satellite connections would still be plain HTTP — half-TLS deployment offers limited security benefit.
- Changes to the `SegmentSnapshot` binary layout or NVS key scheme
- Aggregator mutual-auth implementation (T3-C) in the current phase
- ESPHome native API authentication (separate component, separate issue)
- CORS policy changes beyond what is required by browser clients
- Captive portal / WiFi reconfiguration auth: tracked as Phase E
- OTA auth hardening: OTA uses ESPHome's native encrypted API — already handled by `api.encryption.key` in the C3 YAML

---

_End of document._