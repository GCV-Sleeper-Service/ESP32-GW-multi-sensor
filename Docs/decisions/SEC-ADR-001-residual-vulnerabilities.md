# Security ADR-001 — Known Residual Vulnerabilities

**Status:** Accepted  
**Date:** 2026-04-12  
**Context:** Phase V security hardening (v7.6.8.x)  
**Author:** Phase V planning, informed by issue #163 security audit  

---

## Context

Phase V (v7.6.8.x) adds authentication guards to all write endpoints, strips sensitive fields from the public `/api/status` response, and adds a heap cap on history responses. Despite these improvements, several vulnerabilities cannot be fully resolved within the constraints of the current hardware platform and OTA-only deployment model.

This document records each known residual vulnerability, its risk rating, the partial mitigations in place after V2, and the conditions under which it would be fully resolved.

**Deployment context:** The firmware runs on ESP32-C3 and ESP32-S3 boards. The aggregator is exposed to the internet via Cloudflare Tunnel or port-forward (port 80, plain HTTP). Satellites are LAN-only but may be reachable from a compromised LAN device.

---

## Residual Vulnerabilities

### RV-01 — Basic Auth Credential Eavesdropping

**Risk rating:** MEDIUM  
**Status:** Permanent residual until TLS is added  
**Applies to:** All authenticated endpoints (ingest, import, add/delete satellite, history, gateways, live, proxy)

**Description:**  
HTTP Basic Auth sends `Authorization: Basic <base64(user:pass)>` in cleartext with every request. Any attacker with network visibility (ARP poisoning on LAN, passive capture on the Cloudflare Tunnel egress, or a compromised upstream router) can recover credentials by base64-decoding the header.

**Why TLS cannot be added in Phase V:**  
The ESP32-C3 has approximately 55 KB free heap at boot after Phase V. mbedTLS requires roughly 50–80 KB heap per active TLS session plus approximately 200 KB flash for the mbedTLS library itself. On the C3, this is infeasible — a single HTTPS handshake would exhaust all available heap.

On the ESP32-S3 with 8 MB PSRAM, TLS is technically feasible, but implementing half-TLS (S3 aggregator serving HTTPS while satellites serve HTTP) provides limited security benefit: the satellite-to-aggregator polling traffic remains cleartext, and the mixed-mode code complexity is high.

**Partial mitigations in place after V2:**  
- All write endpoints require credentials (V2-A through V2-C)
- Sensitive heap/version fields stripped from public `/api/status` (V2-D)
- History endpoints are auth-gated (V2-E), reducing data exfiltration risk

**Full resolution path:**  
TLS via mbedTLS integration, targeted for Phase E (v8.0.x) on S3 boards, or a Cloudflare Tunnel mTLS termination layer (external, no firmware change required). Tracked in the Phase E planning document.

---

### RV-02 — TLS Memory Cost (Infeasibility Statement)

**Risk rating:** LOW (documented constraint, not an active attack vector)  
**Status:** Accepted architectural constraint until Phase E  

**Description:**  
For completeness, the cost model for adding TLS to this firmware is documented here so that future planning agents do not re-investigate it:

| Cost component | Size |
|---|---|
| mbedTLS library flash | ~200 KB |
| Heap per TLS session (handshake) | ~50–80 KB |
| Heap per TLS session (steady state) | ~30–40 KB |
| ESP32-C3 free heap at boot (post-V2) | ~55 KB |
| ESP32-S3 PSRAM available | ~7.5 MB (ample) |

**Verdict:** C3 cannot run TLS without PSRAM — the handshake allocation exceeds available heap. S3 with PSRAM can run TLS but would require significant integration work (ESPHome IDF HTTPS server configuration, certificate provisioning, certificate rotation). This is Phase E work.

---

### RV-03 — `/api/status` Public Field Exposure (Partial Mitigation)

**Risk rating:** LOW (post-V2)  
**Status:** Partially mitigated by V2-D  

**Description:**  
Before V2-D, `/api/status` exposes `version`, `free_heap`, `free_heap_internal`, `uptime_s`, `wifi_rssi`, and hardware identifiers in a public (unauthenticated) response. This allows a passive attacker to fingerprint the firmware version, infer board type from heap values, and detect reboots via uptime.

**Mitigation in V2-D:**  
The public `/api/status` response is stripped to include only `{"ok":true,"role":"...","id":"..."}` (non-sensitive fields). The full response is moved to the new `/api/status/full` endpoint, which requires authentication.

**Residual exposure:**  
`role` and `id` still identify the device as an ESP32 firmware node. The `id` field may disclose the satellite's hostname. This is accepted risk for a LAN deployment; for internet exposure, operators should use Cloudflare Access or similar to gate all `/api/` paths behind SSO.

---

### RV-04 — History Endpoint: First-Pass Mitigation Only

**Risk rating:** LOW (post-V2), MEDIUM (pre-V2)  
**Status:** Partially mitigated by V2-E  

**Description:**  
Issue #139 identifies a heap exhaustion crash when `/api/v2/history/` is called on an ESP32-C3 with a large history payload. The full fix (chunked streaming, Phase 7) requires changes to `SegmentSnapshot` and the persistence architecture that are out of scope for Phase V.

**Mitigation in V2-E:**  
`csv.reserve()` in `handle_history_()` is capped at `MIN(estimated_bytes, 60000)`. Auth is added to `/history/` and `/api/v2/history/` so that anonymous callers cannot trigger the allocation. This reduces (but does not eliminate) the risk: an authenticated attacker with valid credentials could still trigger a large allocation.

**Full resolution path:**  
Phase 7 per-device persistence engine with chunked CSV streaming (tracked in #139 and `Docs/v7.7-implementation-plan.md`).

---

### RV-05 — Import Session Timeout Leak (~6.7 KB Held)

**Risk rating:** LOW  
**Status:** Accepted, documented — no code change needed  

**Description:**  
`handle_import_begin_()` allocates `import_snapshot_` (~6,710 B on the heap, the size of `SegmentSnapshot`). This allocation is held until:
- The import completes normally (finish endpoint called), or
- A new `/api/import/begin` is called (which calls `cleanup_import_state_()` first)

If the dashboard user starts an import session and then closes their browser, the buffer is held indefinitely until the next begin call or a reboot.

**Why no code change is needed:**  
The allocation is bounded (~6.7 KB, a single `SegmentSnapshot`). A reboot clears it. An import session timeout could be added (e.g., auto-cleanup after 10 minutes of inactivity) but the complexity outweighs the benefit for this deployment pattern.

**Documentation:**  
A code comment is added at `web-handler.h` ~line 779 in step V1-G to document this for future maintainers (see V1-G in the implementation plan).

---

### RV-06 — `/api/manifest` and `/sensors.json` Topology Disclosure

**Risk rating:** LOW  
**Status:** Accepted risk for LAN deployment  

**Description:**  
`/api/manifest` returns a complete JSON description of the device's sensor topology, including device IDs, metric keys, board type, SRAM/flash sizes (post-V3-A), and hostname. `/sensors.json` returns the compiled sensor configuration.

This is useful information for an attacker performing reconnaissance: it reveals the exact board type, firmware version (pre-V2, via the status endpoint), and all sensor IDs that can be targeted for history exfiltration or ingest injection.

**Why no auth guard is added:**  
The aggregator polling task calls `/api/manifest` without credentials to discover satellite capabilities. Adding auth to `/api/manifest` on satellites would require updating the aggregator polling task to pass credentials, which in turn requires storing per-satellite credentials on the aggregator — a significant scope expansion inappropriate for Phase V.

**Accepted risk statement:**  
For LAN deployment (the intended use case), topology disclosure is low-risk — any LAN device can already ARP-scan and probe the satellite. For internet exposure, the operator should use Cloudflare Access or a reverse proxy with IP allowlisting to gate the entire `/` path.

---

### RV-07 — `/api/v2/live` Remains Unauthenticated

**Risk rating:** LOW  
**Status:** Accepted — required for aggregator polling  

**Description:**  
The aggregator polling task calls `/api/v2/live` on each satellite without credentials to collect current sensor readings. If `/api/v2/live` is auth-gated, the aggregator cannot poll satellites unless each satellite's credentials are stored on the aggregator and passed with each poll request.

**Accepted risk statement:**  
`/api/v2/live` exposes current sensor readings (temperature, humidity, ping latency, etc.) without authentication. For most deployments, this is not sensitive data. An attacker who can reach the satellite's IP can read current sensor values.

For internet exposure, this is accepted until Phase E designs a credential-propagation scheme for the aggregator polling task.

---

## Auth Coverage Table (Post-V2 State)

| Endpoint | Method(s) | Auth required (post-V2) | Residual risk |
|---|---|---|---|
| `/api/ingest/` | POST | ✅ Yes (V2-A) | RV-01 (eavesdropping) |
| `/api/import/begin` | POST | ✅ Yes (pre-existing) | RV-01, RV-05 |
| `/api/import/d/` | POST | ✅ Yes (pre-existing) | RV-01 |
| `/api/import/w/` | POST | ✅ Yes (pre-existing) | RV-01 |
| `/api/import/finish` | POST | ✅ Yes (pre-existing) | RV-01 |
| `/api/import/status` | GET | ❌ Public (intentional) | Dashboard polls during import; read-only boolean flag |
| `/api/aggregator/add-satellite` | POST | ✅ Yes (V2-B) | RV-01 |
| `/api/aggregator/satellite/{id}` | DELETE | ✅ Yes (pre-existing) | RV-01 |
| `/api/aggregator/test-satellite` | POST | ✅ Yes (pre-existing) | RV-01 |
| `/api/aggregator/gateways` | GET | ✅ Yes (V2-C) | RV-01 |
| `/api/aggregator/live` | GET | ✅ Yes (V2-C) | RV-01 |
| `/api/aggregator/proxy/{...}` | GET | ✅ Yes (V2-C) | RV-01 |
| `/history/` | GET | ✅ Yes (V2-E) | RV-01, RV-04 |
| `/api/v2/history/` | GET | ✅ Yes (V2-E) | RV-01, RV-04 |
| `/api/status` | GET | ❌ Public (intentional) | RV-03 (partial) |
| `/api/status/full` | GET | ✅ Yes (V2-D) | RV-01 |
| `/api/v2/live` | GET | ❌ Public (intentional) | RV-07 |
| `/api/manifest` | GET | ❌ Public (intentional) | RV-06 |
| `/sensors.json` | GET | ❌ Public (intentional) | RV-06 |
| `/api/system/reboot` | POST | ✅ Yes (pre-existing) | RV-01 |
| `/api/system/delete-data` | POST | ✅ Yes (pre-existing) | RV-01 |
| `/api/system/storage-stats` | GET | ✅ Yes (pre-existing) | RV-01 |

---

## Decision

All residual vulnerabilities listed above are **accepted** for the v7.6.x release series.

Rationale:
1. The primary deployment model (home LAN, optional Cloudflare Tunnel) does not require perfect security — it requires that an unauthenticated attacker cannot inject data, crash the firmware, or exfiltrate history without valid credentials.
2. TLS is technically infeasible on the ESP32-C3 within the current heap budget and is explicitly deferred to Phase E.
3. The cost of implementing half-measures (e.g., self-signed TLS on S3 only) exceeds the security benefit at the current deployment scale.

---

## Consequences

- Phase V V2 hardening (V2-A through V2-J) is the **complete** security implementation for v7.6.x.
- Any additional hardening for internet exposure requires either Phase E (TLS) or an external proxy layer (Cloudflare Access, nginx, Tailscale).
- This document must be updated when any residual vulnerability is resolved.

---

## Resolution Tracking

| Vulnerability | Resolved by | Target version |
|---|---|---|
| RV-01 Basic Auth eavesdropping | mbedTLS integration (Phase E) | v8.0.x |
| RV-02 TLS infeasibility | Same as RV-01 | v8.0.x |
| RV-03 Status field exposure | V2-D (partial) + Phase E (full) | v7.6.8.0 partial / v8.0.x full |
| RV-04 History heap exhaustion | Phase 7 chunked streaming (#139) | v7.7.x |
| RV-05 Import session timeout | Phase E rewrite or timeout guard | v8.0.x or later |
| RV-06 Manifest topology disclosure | Phase E credential propagation | v8.0.x |
| RV-07 `/api/v2/live` unauthenticated | Phase E credential propagation | v8.0.x |

---

_End of SEC-ADR-001._
