```issue-163-security-hardening
## Security Hardening: Endpoint Auth Gap, Data Injection, and Topology Disclosure

**Labels:** security, firmware, aggregator, satellite  
**Depends on:** #164 (heap budget), #139 (history crash), #14–#18 (endpoint crashes)  
**Blocked by:** #165 (heap recovery — confirms C3 budget headroom before auth work begins)

---

### Threat Model

**Realistic attacker:** A device on the same LAN segment as the gateway (home network user, IoT device compromise, or Cloudflare Tunnel misconfiguration exposing the aggregator externally). NOT an internet attacker — no ports are forwarded and the firmware has no HTTPS/TLS capability at current heap budgets.

**Attack surface:** Port 80 on every gateway device. All requests are plain HTTP. Credentials sent via Basic Auth are base64-encoded and trivially readable if traffic is observed (ARP poisoning, passive WiFi sniff on a shared 2.4 GHz network).

**Realistic attacks:**
1. Any LAN device injects fake sensor readings into a satellite → false data drives incorrect automations or alerts
2. Any LAN device adds a rogue satellite to the aggregator → aggregator polls attacker-controlled host (SSRF), leaking polling timing; rogue satellite survives reboot via NVS persistence
3. Any LAN device reads `/api/aggregator/gateways` → learns all internal satellite IPs, firmware versions, heap states, and sensor topology without authentication
4. Any LAN device reads `/api/status` → learns exact firmware version and heap state for targeted exploit development
5. Any LAN device repeatedly probes `/api/aggregator/add-satellite` with unreachable URLs → blocks httpd task for up to 15 seconds per probe, denying all HTTP access

---

### Current State: Endpoint Auth Audit

| Path | Method | Board | Handler fn | Auth? | Risk |
|------|--------|-------|-----------|-------|------|
| `/api/ingest/<device>/<metric>` | POST | Both | `handle_api_ingest_()` | ❌ None | CRITICAL — data injection |
| `/api/aggregator/add-satellite` | POST | S3 | `handle_add_satellite_()` | ❌ None (intentional: LESSON-OPS-089) | CRITICAL — SSRF + NVS persist + httpd DoS |
| `/history/<id>/<temp\|hum>` | GET | Both | `handle_history_()` | ❌ None | HIGH — large heap alloc (#139 crash vector) |
| `/api/v2/history/<device>/<metric>` | GET | Both | `handle_api_v2_history_()` | ❌ None | HIGH — history access |
| `/api/status` | GET | Both | `handle_status_()` | ❌ None | HIGH — firmware ver, heap, sensor topology |
| `/api/aggregator/gateways` | GET | S3 | `handle_aggregator_gateways_()` | ❌ None | HIGH — full LAN topology, satellite IPs |
| `/api/aggregator/live` | GET | S3 | `handle_aggregator_live_()` | ❌ None | MEDIUM — aggregated sensor readings |
| `/api/aggregator/proxy/<gw_id>/…` | GET | S3 | `handle_aggregator_proxy_()` | ❌ None | MEDIUM — proxy to satellite |
| `/api/storage-stats` | GET | Both | `handle_storage_stats_()` | ❌ None | MEDIUM — partition layout |
| `/api/manifest` | GET | Both | `handle_api_manifest_()` | ❌ None | MEDIUM — sensor/gateway topology |
| `/api/v2/live` | GET | Both | `handle_api_v2_live_()` | ❌ None | MEDIUM — live readings |
| `/sensors.json` | GET | Both | `handle_manifest_()` | ❌ None | LOW — sensor names/IDs |
| `/dashboard`, `/dashboard.html`, `/dashboard-download` | GET | Both | `handle_dashboard_()` | ❌ None | LOW — static HTML |
| `/api/reboot` | POST | Both | `handle_reboot_()` | ✅ YES | Guarded |
| `/api/delete-data` | POST | Both | `handle_delete_data_()` | ✅ YES | Guarded |
| `/api/import/*` | POST | Both | `handle_import_*()` | ✅ YES | Guarded |
| `/api/aggregator/test-satellite` | POST | S3 | `handle_test_satellite_()` | ✅ YES | Guarded |
| `/api/system/reset-satellites` | POST | S3 | `handle_reset_satellites_()` | ✅ YES | Guarded |
| `/api/aggregator/satellite/<id>` | DELETE | S3 | `handle_delete_satellite_()` | ✅ YES | Guarded |

---

### Specific Vulnerabilities (Ranked by Severity)

#### SEC-01 — Unauthenticated sensor data injection via `/api/ingest/`
- **Severity:** CRITICAL
- **Path:** `POST /api/ingest/<device>/<metric>?val=<float>`
- **Handler fn:** `handle_api_ingest_()` — `firmware/core/web-handler.h` line 530
- **Curl:** `curl -X POST "http://<gw-ip>/api/ingest/office/temp?val=25.3"`
- **Impact:** Any LAN device can overwrite any sensor's live reading with an arbitrary float. Value is validated (strtof + isfinite) but no caller auth. If the periodic persist task runs while fake data is in the ring buffer, the fake reading is committed to NVS and survives reboot.
- **Mitigation:** Call `authenticate_management_()` as first line of `handle_api_ingest_()`. Callers (external push scripts, ESPHome sensors) must include `Authorization: Basic <base64>` header. Memory cost: ~250 B transient per request.

#### SEC-02 — Unauthenticated satellite add + SSRF + httpd DoS via `/api/aggregator/add-satellite`
- **Severity:** CRITICAL (S3 only)
- **Path:** `POST /api/aggregator/add-satellite?url=<url>&name=<name>`
- **Handler fn:** `handle_add_satellite_()` — line 1657
- **Curl (SSRF):** `curl -X POST "http://<agg-ip>/api/aggregator/add-satellite?url=http://192.168.1.1"`
- **Curl (DoS):** `for i in $(seq 50); do curl -X POST "http://<agg-ip>/api/aggregator/add-satellite?url=http://10.0.255.254" & done`
- **Impact (SSRF):** Aggregator makes outbound HTTP GET to any LAN IP. Rogue satellite persists in NVS (survives reboot). Aggregator begins polling attacker host every N seconds, sending timing signals. Combined with `/api/aggregator/proxy/`, attacker can proxy through the aggregator to reach other LAN devices.
- **Impact (DoS):** Each probe call in `probe_satellite_manifest_()` (aggregator-runtime.h line 235) uses 3 blocking socket ops each with 5-second timeouts (lines 172–173). A probe to an unreachable host blocks the httpd task for up to 15 seconds per request, preventing all HTTP access.
- **Intentional decision documented:** LESSON-OPS-089 in `Docs/lessons/build-pipeline.md` line 432 records that no-auth on add-satellite was deliberate for v7.6.0.1, with explicit requirement to address in a security hardening phase.
- **Mitigation:** Add `if (!authenticate_management_(request)) return;` at top of `handle_add_satellite_()` (before the URL parse at line 1671). Memory cost: same as SEC-01.

#### SEC-03 — LAN topology disclosure via `/api/aggregator/gateways`
- **Severity:** HIGH (S3 only)
- **Path:** `GET /api/aggregator/gateways`
- **Handler fn:** `handle_aggregator_gateways_()` — line 1431
- **Curl:** `curl -s "http://<agg-ip>/api/aggregator/gateways"`
- **Impact:** Response includes every satellite's `base_url` (internal IP:port), firmware version, free heap value, sensor count, reachability/failure count, and full cached manifest JSON (sensor IDs, metric keys, device names).
- **Mitigation:** Add auth guard. This endpoint is called by the dashboard which already handles 401 prompts for guarded management actions. Satellite polling is server-side and unaffected.

#### SEC-04 — Device fingerprinting via `/api/status`
- **Severity:** HIGH (both boards)
- **Path:** `GET /api/status`
- **Handler fn:** `handle_status_()` — line 1233
- **Curl:** `curl -s "http://<gw-ip>/api/status"`
- **Response includes:** `version`, `uptime_seconds`, `sensor_count`, sensor `id`/`name`/`category`/`last_seen`, `temp_valid`/`hum_valid`, `free_heap`, `free_heap_internal`
- **Impact:** Exact firmware version enables targeted exploit selection. Free heap confirms whether device is in vulnerable low-memory state. Sensor names reveal home layout.
- **Note:** The aggregator polling task fetches `/api/status` from each satellite (aggregator-runtime.h line 644). If auth is added here, `fetch_to_buffer()` must be updated to send credentials (see Tier 3).
- **Mitigation options:** Either (a) add auth (requires aggregator polling fix), or (b) strip sensitive fields (version, free_heap) from the public response and serve a reduced status. Option (b) has no memory cost and no aggregator impact.

#### SEC-05 — History endpoint as crash vector via heap exhaustion
- **Severity:** HIGH (both boards, interacts with #139)
- **Path:** `GET /history/<id>/<temp|hum>`
- **Handler fn:** `handle_history_()` — line 1303
- **Curl:** `curl "http://<gw-ip>/history/sensor1/temp"` (repeated rapidly or during active SSE)
- **Impact:** Line 1376 computes `est_bytes = est_points * 20 + 128`. With a full 45-day history at default persistence settings: up to ~86 KB single `std::string::reserve()` call. C3 free heap is ~55 KB at boot → the `reserve()` will fail, returning an empty or undersized string, or trigger `bad_alloc`. With SSE active (10–15 KB consumed), the failure is deterministic. This is the primary mechanism in the #139 crash.
- **Mitigation:** Auth alone does not fix the allocation size. Auth reduces anonymous triggering but the real mitigation is chunked streaming (separate from this issue). Tracked as overlap with #139. Input: add auth as a first-pass mitigation; fix allocation in #139.

#### SEC-06 — HTTP Basic Auth credentials transmitted in cleartext
- **Severity:** MEDIUM (systemic)
- **All authenticated endpoints**
- **Impact:** Credentials are base64-encoded (not encrypted). Any passive WiFi observer or ARP-poisoner on the same segment can read the username and password from a single authenticated request.
- **Mitigation:** HTTPS/TLS is memory-prohibitive at current budgets (see Memory Cost table). Interim mitigation: use a randomly-generated long token as the password (high entropy compensates for in-transit exposure — an observed token is still a secret if not reused across sessions, but this is not a real fix). Full fix requires TLS or digest auth (see Tier 3).

---

### Proposed Fixes

#### Tier 1 — Auth Extension Quick Wins (in-place, minimal code changes)

These require adding a single `if (!authenticate_management_(request)) return;` call at the top of the named handler. Memory cost for each: ~250 B transient heap per request, ~350 B additional stack depth.

| Handler fn | File:line | Change | Notes | Memory cost |
|-----------|-----------|--------|-------|-------------|
| `handle_api_ingest_()` | web-handler.h:530 | Add auth guard at top | Callers must add `Authorization` header | ~250 B transient |
| `handle_add_satellite_()` | web-handler.h:1657 | Add auth guard (remove LESSON-OPS-089 exception) | Closes SSRF + DoS | ~250 B transient |
| `handle_aggregator_gateways_()` | web-handler.h:1431 | Add auth guard | Dashboard already handles 401 | ~250 B transient |
| `handle_aggregator_live_()` | web-handler.h:1523 | Add auth guard | Dashboard live data, handled | ~250 B transient |
| `handle_aggregator_proxy_()` | web-handler.h:1556 | Add auth guard | Proxy should be auth-gated | ~250 B transient |

**Endpoints NOT recommended for auth guard without additional changes:**
- `/api/status` — aggregator polls this from satellites without credentials; requires Tier 3 change first, OR strip sensitive fields approach
- `/history/*` and `/api/v2/history/*` — legitimate use case for monitoring scripts; auth guard is correct but must be paired with Tier 2 allocation fix
- `/api/v2/live` — polling task fetches from satellites without credentials; same issue as /api/status

#### Tier 2 — Input Validation and Crash Prevention

| Issue | Handler fn | Specific validation needed | Overlap |
|-------|-----------|--------------------------|---------|
| History response heap exhaustion | `handle_history_()` | Cap `csv.reserve()` to `MIN(est_bytes, 60000)` on C3; or stream response in chunks to avoid single large allocation | #139, #164 Step 6 watermark gate |
| History v2 response heap | `handle_api_v2_history_()` | Same as above — line 520 `csv.reserve(buf->count() * 20 + 64)` is bounded by RAM buffer but add assert | #139 |
| Add-satellite probe DoS | `handle_add_satellite_()` | (After adding auth) — still validate URL points to LAN-range IP before probing; add per-satellite cooldown to prevent rapid re-probe of same IP | #14-18 endpoint stability |
| Ingest val parameter | `handle_api_ingest_()` | `val_str` length is unbounded before `strtof()` — add `if (val_str.size() > 32) { send_json_error_(…, 400, "val too long"); return; }` at line 588 | Low risk but defensive |
| Import path data length | `handle_import_data_()` | Line 867: `line[80]` is bounded, but no total path-data length limit — add check `if (strlen(path_data) > 4096) { send_json_error_(400, …); return; }` | Low risk, defensive |
| Aggregator gateways response size | `handle_aggregator_gateways_()` | Pre-reserve calculation (lines 1438-1443) is correct but add `cap` if satellite count × manifest size exceeds available heap | #164 budget |

#### Tier 3 — Longer-Term Architectural

| Item | Feasibility | Memory cost | Notes |
|------|-------------|-------------|-------|
| **HTTPS/TLS** | Not feasible at current budget | mbedTLS requires ~50-80 KB heap + ~10-15 KB stack. C3 target free heap after #165 is 68-70 KB — TLS would consume the entire budget and leave no room for history operations | **Out of scope** until a dedicated memory optimization brings C3 to ≥100 KB free |
| **Aggregator polls with auth credentials** | Feasible | ~100 B static string for Base64(user:pass), ~100 B stack in fetch_to_buffer | Add `Authorization: Basic <base64>` header in `fetch_to_buffer()` (aggregator-runtime.h line 183). Credentials compiled as constants or stored in NVS `agg_sats` namespace as `poll_cred`. Required before adding auth to `/api/status`, `/api/v2/live`, `/api/manifest` on satellites. |
| **Digest auth** | Feasible (no TLS needed) | MD5 HMAC: ~1-2 KB stack, negligible heap | Protects against credential sniffing without TLS. More complex implementation. Lower priority than Tier 1/2. |
| **Per-satellite polling credentials** | Medium complexity | ~64 B per satellite in NVS, ~64 B in SatelliteCache struct | Add `poll_user[32]` + `poll_pass[32]` to `SatelliteCache`; extend `save_single_satellite_to_nvs_()` and `load_satellites_from_nvs_()`. Aggregator sends per-satellite credentials during polling. |
| **Rate limiting on all endpoints** | Feasible | Negligible — one counter per IP connection | Currently only management auth has rate limiting. Add connection-level rate limiting for `/api/ingest/` to prevent spam injection. |

---

### Memory Cost Summary (cross-referenced with #164)

| Change | Heap cost (transient) | Heap cost (persistent) | Stack depth added | Notes |
|--------|----------------------|----------------------|-------------------|-------|
| Auth guard on ingest | ~250 B / request | 0 | ~350 B | Only during request |
| Auth guard on add-satellite | ~250 B / request | 0 | ~350 B | Replaces probe-time allocation |
| Auth guard on aggregator GET endpoints (3) | ~250 B / request | 0 | ~350 B | Dashboard-called |
| Strip free_heap from /api/status | 0 | 0 | 0 | No auth needed if field removed |
| History response cap (Tier 2) | Reduces peak by ~20-40 KB | 0 | 0 | Directly addresses #139 crash |
| Aggregator polling credentials | ~100 B | 30 B (static) | ~100 B | Required before satellite read auth |
| **HTTPS/TLS** | **~60-80 KB peak** | **~50 KB persistent** | **~15 KB** | **OUT OF SCOPE — exceeds C3 budget** |

**All Tier 1 + Tier 2 changes combined: < 1 KB persistent heap impact, < 1 KB stack increase.** None of these changes threaten the C3 heap budget or the #164 Step 6 watermark gate.

---

### Aggregator-Satellite Auth Interaction

The aggregator's polling task (`aggregator_poll_task` in `aggregator-runtime.h` line 536) calls `fetch_to_buffer()` for three satellite endpoints every poll cycle:
- `GET {base_url}/api/v2/live` (line 597)
- `GET {base_url}/api/status` (line 644)
- `GET {base_url}/api/manifest` (line 683)

`fetch_to_buffer()` (line 124) sends a minimal HTTP/1.0 GET with `Host` and `Connection: close` headers only — **no Authorization header**.

**Consequence:** These three satellite endpoints cannot be auth-guarded without modifying `fetch_to_buffer()` to send credentials. Tier 1 work therefore should NOT add auth to `/api/v2/live`, `/api/status`, or `/api/manifest` on the satellite. These endpoints remain open read-only endpoints, consistent with the model of "readings are public, management operations are authenticated."

**When satellite read auth is desired (Tier 3):** Modify `fetch_to_buffer()` to accept an optional `const char* auth_header` parameter. The aggregator's satellite config (in `SatelliteCache`) gains `poll_user[32]` + `poll_pass[32]` fields populated from NVS or compile-time constants. Build the `Authorization: Basic <base64>` header string and inject into the HTTP request builder at line 183.

---

### Acceptance Criteria

All of the following must return `HTTP 401` without credentials:
```bash
# SEC-01: Ingest injection rejected
curl -o /dev/null -w "%{http_code}" -X POST "http://<gw>/api/ingest/sensor1/temp?val=25.0"
# Expected: 401

# SEC-02: Satellite add rejected
curl -o /dev/null -w "%{http_code}" -X POST "http://<agg>/api/aggregator/add-satellite?url=http://192.168.1.1"
# Expected: 401

# SEC-03: Gateways topology rejected
curl -o /dev/null -w "%{http_code}" "http://<agg>/api/aggregator/gateways"
# Expected: 401

# SEC-04 (if strip approach): /api/status must NOT contain "version" or "free_heap" fields
curl -s "http://<gw>/api/status" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'version' not in d and 'free_heap' not in d"
# Expected: no assertion error
```

All authenticated endpoints must continue to return `HTTP 200` with correct credentials:
```bash
# Reboot must still work with auth
curl -o /dev/null -w "%{http_code}" -u "admin:password" -X POST "http://<gw>/api/reboot" -d "a=1"
# Expected: 200

# Aggregator polling must still succeed (satellite read endpoints remain open)
curl -s "http://<sat>/api/v2/live"
# Expected: 200 with JSON sensor data
```

Rate limiting must activate after 3 failures:
```bash
for i in 1 2 3 4; do
  curl -o /dev/null -w "%{http_code}\n" -u "wrong:creds" -X POST "http://<gw>/api/reboot" -d "a=1"
done
# Expected: 401 401 401 429 (with Retry-After header on 4th)
```

---

### Dependencies
- **#164** (heap budget / #165 recovery): Confirm C3 free heap ≥ 60 KB before starting Tier 1. Auth adds ≤ 1 KB persistent overhead — this headroom is required.
- **#139** (history crash): Tier 2 history allocation cap shares the same handler (`handle_history_()`). Coordinate changes.
- **#14–#18** (endpoint stability): Add-satellite probe DoS (SEC-02) is related to endpoint stability crashes. Fixing add-satellite auth removes one crash vector from that group.

### Out of Scope
- **HTTPS/TLS:** Requires ~60–80 KB peak heap + ~50 KB persistent heap for mbedTLS. C3 budget after #165 is ~68–70 KB total free. TLS would consume the entire budget. **Explicitly deferred until a future phase that brings C3 to ≥100 KB free heap.** S3 aggregator (512 KB RAM + 8 MB PSRAM) could technically support TLS, but satellite connections would still be plain HTTP — half-TLS deployment offers limited security benefit.
- **Captive portal / WiFi reconfiguration auth:** Tracked as Phase E.
- **OTA auth hardening:** OTA uses ESPHome's native encrypted API — already handled by the `api.encryption.key` in the C3 YAML (line 144–146).
```