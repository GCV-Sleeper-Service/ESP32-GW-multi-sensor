# Session Log — v7.6.6.7: Full Endpoint Smoke Test — PASS

_Date: 2026-04-11_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Branch: `copilot/implement-comprehensive-endpoint-test`_
_Status: COMPLETE — Phase A (satellite) + Phase B (aggregator) + Phase C (cleanup + playwright) passed_

---

## Summary

v7.6.6.7 records the full endpoint smoke test for the Phase Y firmware. The C3 satellite (Phase A,
13 local GET endpoints + auth gate + management endpoints) and S3 aggregator (Phase B, 6
aggregator-specific endpoints) were tested on physical hardware. Cleanup and Playwright gate
(Phase C) also completed. All Playwright test suites pass. The pipeline is clean in satellite mode.
Version bumped to v7.6.6.7. No functional firmware logic changed — devices under test were running
the v7.6.6.6 binary at time of testing; this PR records the v7.6.6.7 version-stamp release.

Two known deferred gaps are documented below:
- History proxy (`GET /api/aggregator/proxy/{gw}/history/{device}/{metric}`) — non-functional, carried from v7.6.6.6.
- Import/export cycle (`/api/import/begin`, `/api/import/d/`, `/api/import/w/`, `/api/import/finish`) — crashes the board on execution; deferred for bug fix post-Phase Y.

---

## Commit Timeline

| SHA | Author | Message |
|-----|--------|---------|
| *(this PR)* | copilot-swe-agent | v7.6.6.7: Full Endpoint Smoke Test PASS |

---

## Device Test Evidence

**C3 Satellite:** ESP32-C3 SuperMini at `192.168.120.189` (satellite mode, firmware v7.6.6.6)
**S3 Aggregator:** ESP32-S3-DevKitC1-N16R8 at `192.168.120.191` (aggregator mode)
**Satellites known to aggregator:** sat-c3-4m-189 (ESP32-C3, v7.6.6.6, 192.168.120.189), sat-esp32-4m-190 (ESP32, v7.6.5.3, 192.168.120.190)

---

### Phase A — C3 Satellite Endpoint Tests (192.168.120.189)

**Endpoint 1 — `GET /history/0/temp` (no auth)**

```bash
curl -s http://192.168.120.189/history/0/temp | head -20
```
✅ PASS — CSV history stream returned (epoch timestamps at 900s intervals).

---

**Endpoint 2 — `GET /history/0/hum` (no auth)**

```bash
curl -s http://192.168.120.189/history/0/hum | head -20
```
✅ PASS — CSV history stream returned.

---

**Endpoint 3 — `GET /sensors.json` (no auth)**

```bash
curl -s http://192.168.120.189/sensors.json | jq
```
✅ PASS — JSON sensor projection returned.

---

**Endpoint 4 — `GET /api/manifest` (no auth)**

```bash
curl -s http://192.168.120.189/api/manifest | jq
```
✅ PASS — schema_version 2, version v7.6.6.6, 5 sensors, 8 metrics.

---

**Endpoint 5 — `GET /dashboard` (no auth)**

```bash
curl -s -o /dev/null -w "%{http_code} %{size_download}" http://192.168.120.189/dashboard
```
✅ PASS — 200, 37 kB gzip-compressed dashboard.

---

**Endpoint 6 — `GET /dashboard.html` (no auth)**

```bash
curl -s -o /dev/null -w "%{http_code} %{size_download}" http://192.168.120.189/dashboard.html
```
✅ PASS — 200, same payload as `/dashboard`.

---

**Endpoint 7 — `GET /dashboard-download` (no auth)**

```bash
curl -s -o /dev/null -w "%{http_code} %{content_type}" http://192.168.120.189/dashboard-download
```
✅ PASS — 200, attachment content-disposition.

---

**Endpoint 8 — `GET /favicon.ico` (no auth)**

```bash
curl -s -o /dev/null -w "%{http_code}" http://192.168.120.189/favicon.ico
```
✅ PASS — 200 (suppression path).

---

**Endpoint 9 — `GET /api/storage-stats` (no auth)**

```bash
curl -s http://192.168.120.189/api/storage-stats | jq
```
✅ PASS — valid_segments, capacity, NVS healthy.

---

**Endpoint 10 — `GET /api/status` (no auth)**

```bash
curl -s http://192.168.120.189/api/status | jq
```
✅ PASS — free_heap present, version v7.6.6.6, uptime, sensor_count 5.

---

**Endpoint 11 — `GET /api/v2/live` (no auth)**

```bash
curl -s http://192.168.120.189/api/v2/live | jq
```
✅ PASS — office/first_floor/outside/wan_ping live; nas01 null (expected — no ingest source).

---

**Endpoint 12 — `GET /api/v2/history/outside/temperature` (no auth)**

```bash
curl -s "http://192.168.120.189/api/v2/history/outside/temperature" | jq | head -20
```
✅ PASS — JSON history array with epoch timestamps at 900s intervals.

---

**Endpoint 13 — `POST /api/ingest/0/temperature` (no auth)**

```bash
curl -s -d 'a=1' -X POST "http://192.168.120.189/api/ingest/0/temperature"
```
✅ PASS — endpoint responded (value validation result OK).

---

### Phase A — Auth Gate

**Unauthenticated request (expected: 401)**

```bash
curl -s -d 'a=1' -X POST http://192.168.120.189/api/reboot | jq
```
```json
{
  "ok": false,
  "message": "Management authentication required",
  "status": 401
}
```
✅ PASS — 401 Unauthorized returned without credentials.

**Authenticated request (expected: 200)**

```bash
curl -s -u <user>:<pass> -d 'a=1' -X POST http://192.168.120.189/api/reboot | jq
```
```json
{
  "ok": true,
  "message": "Reboot scheduled"
}
```
✅ PASS — 200 OK returned with valid credentials. Device rebooted and came back online.

---

### Phase A — Management Endpoints

**Endpoint 19 — `POST /api/reboot` (authenticated)**

Tested via auth gate above. ✅ PASS.

---

**Endpoint 20 — `POST /api/delete-data` (authenticated)**

```bash
curl -s -u <user>:<pass> -d 'a=1' -X POST http://192.168.120.189/api/delete-data
```
✅ PASS — 200, deferred deletion initiated.

---

**Endpoint 21 — `POST /api/system/reset-satellites` (authenticated)**

```bash
curl -s -u <user>:<pass> -d 'a=1' -X POST http://192.168.120.189/api/system/reset-satellites
```
✅ PASS — 200, no-op on satellite (no aggregator context); returned success.

---

### Phase A — Import/Export Cycle (DEFERRED — Known Bug)

**Status: ⚠️ DEFERRED — board crashes on import/export endpoint execution**

The import/export endpoints (`/api/import/begin`, `/api/import/d/{data}`,
`/api/import/w/{data}`, `/api/import/finish`) were not tested in this session
because executing them crashes the board. This is a pre-existing firmware bug
that is unrelated to Phase Y scope.

**Impact:** These endpoints (endpoints 14–18) are deferred for a dedicated
bug-fix step post-Phase Y. They do not block the Phase Y gate.

| # | Endpoint | Method | Auth | Status |
|---|----------|--------|------|--------|
| 14 | `/api/import/begin` | POST | Yes | ⚠️ Deferred — board crash bug |
| 15 | `/api/import/begin/single/{id}` | POST | Yes | ⚠️ Deferred — board crash bug |
| 16 | `/api/import/d/{data}` | POST | Yes | ⚠️ Deferred — board crash bug |
| 17 | `/api/import/w/{data}` | POST | Yes | ⚠️ Deferred — board crash bug |
| 18 | `/api/import/finish` | POST | Yes | ⚠️ Deferred — board crash bug |

---

### Phase A — Complete Endpoint Summary

| # | Endpoint | Method | Auth | Board | Result |
|---|----------|--------|------|-------|--------|
| 1 | `/history/{id}/temp` | GET | No | C3 (189) | ✅ 200 — CSV history stream |
| 2 | `/history/{id}/hum` | GET | No | C3 (189) | ✅ 200 — CSV history stream |
| 3 | `/sensors.json` | GET | No | C3 (189) | ✅ 200 — JSON sensor projection |
| 4 | `/api/manifest` | GET | No | C3 (189) | ✅ 200 — schema_version 2, v7.6.6.6 |
| 5 | `/dashboard` | GET | No | C3 (189) | ✅ 200 — 37 kB gzip dashboard |
| 6 | `/dashboard.html` | GET | No | C3 (189) | ✅ 200 — same as `/dashboard` |
| 7 | `/dashboard-download` | GET | No | C3 (189) | ✅ 200 — attachment disposition |
| 8 | `/favicon.ico` | GET | No | C3 (189) | ✅ 200 — suppression path |
| 9 | `/api/storage-stats` | GET | No | C3 (189) | ✅ 200 — NVS stats healthy |
| 10 | `/api/status` | GET | No | C3 (189) | ✅ 200 — free_heap, uptime, sensor_count 5 |
| 11 | `/api/v2/live` | GET | No | C3 (189) | ✅ 200 — 4 live sensors |
| 12 | `/api/v2/history/{device}/{metric}` | GET | No | C3 (189) | ✅ 200 — JSON history |
| 13 | `/api/ingest/{device}/{metric}` | POST | No | C3 (189) | ✅ 200 — endpoint responded |
| 14 | `/api/import/begin` | POST | Yes | C3 (189) | ⚠️ Deferred — board crash bug |
| 15 | `/api/import/begin/single/{id}` | POST | Yes | C3 (189) | ⚠️ Deferred — board crash bug |
| 16 | `/api/import/d/{data}` | POST | Yes | C3 (189) | ⚠️ Deferred — board crash bug |
| 17 | `/api/import/w/{data}` | POST | Yes | C3 (189) | ⚠️ Deferred — board crash bug |
| 18 | `/api/import/finish` | POST | Yes | C3 (189) | ⚠️ Deferred — board crash bug |
| 19 | `/api/reboot` | POST | Yes | C3 (189) | ✅ 200 (auth gate verified) |
| 20 | `/api/delete-data` | POST | Yes | C3 (189) | ✅ 200 — deferred deletion |
| 21 | `/api/system/reset-satellites` | POST | Yes | C3 (189) | ✅ 200 — no-op on satellite |
| B1 | `/api/aggregator/gateways` | GET | No | S3 (191) | ✅ 200 — 2 satellites, manifests cached |
| B2 | `/api/aggregator/live` | GET | No | S3 (191) | ✅ 200 — live data both satellites |
| B3 | `/api/aggregator/proxy/…` | GET | No | S3 (191) | ⚠️ Empty — deferred bug |
| B4 | `/api/aggregator/add-satellite` | POST | No | S3 (191) | ✅ 200 ok:true |
| B5 | `/api/aggregator/test-satellite` | POST | Yes | S3 (191) | ✅ 200 ok:true |
| B6 | `/api/aggregator/satellite/{id}` | DELETE | Yes | S3 (191) | ✅ 200 ok:true |

---

### Phase B — Aggregator Endpoint Tests (192.168.120.191)

**Endpoint 1 — `GET /api/aggregator/gateways` (no auth)**

```json
{
  "gateways": [
    {
      "id": "sat-c3-4m-189",
      "name": "First satellite - c3 supermini 4mb flash",
      "reachable": true,
      "last_seen": 1775943229,
      "consecutive_failures": 0,
      "manifest_cached": true,
      "live_cached": true,
      "firmware_version": "v7.6.6.6",
      "sensor_count": 5,
      "base_url": "http://192.168.120.189",
      "manifest": { "ok": true, "schema_version": 2, "source": "active-manifest", ... }
    },
    {
      "id": "sat-esp32-4m-190",
      "name": "Second satellite - esp32 wroom 4mb flash",
      "reachable": true,
      "last_seen": 1775943229,
      "consecutive_failures": 0,
      "manifest_cached": true,
      "live_cached": true,
      "firmware_version": "v7.6.5.3",
      "sensor_count": 5,
      "base_url": "http://192.168.120.190",
      "manifest": { "ok": true, "schema_version": 2, "source": "active-manifest", ... }
    }
  ]
}
```
✅ PASS — 2 satellites, both reachable, manifests cached and embedded inline. Mixed firmware
versions (v7.6.6.6 / v7.6.5.3) handled correctly.

---

**Endpoint 2 — `GET /api/aggregator/live` (no auth)**

```json
{
  "timestamp": 1775943281,
  "gateways": {
    "sat-c3-4m-189": {
      "reachable": true,
      "live": {
        "timestamp": 1775943296.000000,
        "devices": {
          "office":      { "temp": 20.5, "hum": 30.0, "batt": null, "rssi": null, "last_seen": 1775943239 },
          "first_floor": { "temp": 15.6, "hum": 40.0, "batt": null, "rssi": null, "last_seen": 1775943244 },
          "outside":     { "temp": 9.1,  "hum": 45.0, "batt": null, "rssi": null, "last_seen": 1775943238 },
          "wan_ping":    { "ping_ms": 59.7, "success_pct": 100.0, "last_seen": 1775943216 },
          "nas01":       { "cpu_pct": null, "ram_pct": null, "disk_pct": null, "uptime_hrs": null, "last_seen": 0 }
        }
      }
    },
    "sat-esp32-4m-190": {
      "reachable": true,
      "live": {
        "timestamp": 1775943296.000000,
        "devices": {
          "office":      { "temp": 20.5, "hum": 30.0, "batt": null, "rssi": null, "last_seen": 1775943275 },
          "first_floor": { "temp": 15.7, "hum": 40.0, "batt": null, "rssi": null, "last_seen": 1775943275 },
          "outside":     { "temp": 9.2,  "hum": 45.0, "batt": null, "rssi": null, "last_seen": 1775943272 },
          "wan_ping":    { "ping_ms": 77.3, "success_pct": 100.0, "last_seen": 1775943238 },
          "nas01":       { "cpu_pct": null, "ram_pct": null, "disk_pct": null, "uptime_hrs": null, "last_seen": 0 }
        }
      }
    }
  }
}
```
✅ PASS — live data from both satellites; env sensors, WAN ping, nas01 (null, expected — no ingest source).

---

**Endpoint 3 — `GET /api/aggregator/proxy/{gw}/history/{device}/{metric}` (no auth)**

```bash
curl -s "http://192.168.120.191/api/aggregator/proxy/192.168.120.190/history/outside/temperature" | jq | head -20
# (empty response)
```
⚠️ NOT FUNCTIONAL — proxy returned empty body. Documented deferred bug carried from v7.6.6.6.
Does not block gate.

---

**Endpoint 4 — `POST /api/aggregator/add-satellite?url=http://192.168.120.190` (no auth)**

```bash
curl -s -d 'a=1' -X POST "http://192.168.120.191/api/aggregator/add-satellite?url=http://192.168.120.190"
```
```json
{"ok":true,"satellite":{"id":"sat-esp32-4m-190","name":"Second satellite - esp32 wroom 4mb flash","url":"http://192.168.120.190","poll":30}}
```
✅ PASS — satellite added via `?url=` query parameter (LESSON-OPS-108).

---

**Endpoint 5 — `POST /api/aggregator/test-satellite` (authenticated)**

```bash
curl -s -u <user>:<pass> -d "url=http://192.168.120.189" -X POST http://192.168.120.191/api/aggregator/test-satellite
```
```json
{
  "ok": true,
  "gateway": {
    "id": "gw-main",
    "name": "Main Gateway",
    "hardware": "ESP32-C3",
    "sensor_count": 5
  }
}
```
✅ PASS — probe-only, no mutation; satellite confirmed reachable with correct metadata.

---

**Endpoint 6 — `DELETE /api/aggregator/satellite/sat-c3-4m-189` (authenticated)**

```bash
curl -s -u <user>:<pass> -X DELETE "http://192.168.120.191/api/aggregator/satellite/sat-c3-4m-189"
```
```json
{"ok":true}
```
✅ PASS — satellite removed by string ID (LESSON-OPS-109).

---

### Phase B Aggregator Endpoint Summary

| # | Endpoint | Method | Auth | Result |
|---|----------|--------|------|--------|
| B1 | `/api/aggregator/gateways` | GET | No | ✅ 200 — 2 satellites, manifests cached |
| B2 | `/api/aggregator/live` | GET | No | ✅ 200 — live data from both satellites |
| B3 | `/api/aggregator/proxy/{gw}/history/{device}/{metric}` | GET | No | ⚠️ Empty — documented bug |
| B4 | `/api/aggregator/add-satellite` | POST | No | ✅ 200 ok:true |
| B5 | `/api/aggregator/test-satellite` | POST | Yes | ✅ 200 ok:true, gateway metadata correct |
| B6 | `/api/aggregator/satellite/{id}` | DELETE | Yes | ✅ 200 ok:true |

---

### Phase C — Cleanup and Verification

**Switch back to satellite mode:**

```
bash scripts/provision.sh satellite
```

Full 9-step pipeline output:
```
Step 0: bash scripts/assemble-sensor-history.sh --write
  Assembled 8 fragments → dashboard/sensor_history_multi.h (4326 lines)
Step 1: bash scripts/bundle-dashboard.sh --write
  Bundled 18 modules → dashboard/dashboard.js (173046 bytes)
Step 2: python3 scripts/render_sensor_config.py --write
  No generated-file changes were needed.
Step 3: node tests/fixtures/generate-fixtures.js
  generated variants: 1sensor, 2sensor, 3sensor, 4sensor, mixed, system ✓
Step 4: python3 scripts/render_sensor_config.py --write
  No generated-file changes were needed.
Step 5: bash scripts/build-dashboard.sh --write
  Built dashboard.html (239626 bytes)
Step 6: bash scripts/minify-dashboard.sh
  Minified: 239626 bytes → 151515 bytes (saved 88111 bytes, 36%)
Step 7: bash scripts/generate-header.sh
  Generated dashboard/dashboard.h  (Raw: 151515 → Gzip: 37001 bytes, saved 75%)
Step 8: python3 scripts/render_sensor_config.py --check
  render_sensor_config: PASS
Pipeline complete — all steps succeeded ✓
```

**Provision status after switch:**
```
Role: satellite | Device: C3 SuperMini (default) | CI-safe: YES ✓
```

---

### Phase C — Playwright Test Results

```
FIXTURE_SET=3sensor    chromium  →  99 passed, 45 skipped  ✓
FIXTURE_SET=3sensor    firefox   →  99 passed, 45 skipped  ✓
FIXTURE_SET=mixed      chromium  →   7 passed              ✓
FIXTURE_SET=system     chromium  →   8 passed              ✓
FIXTURE_SET=aggregator chromium  →  11 passed,  1 skipped  ✓
```

---

## Preflight Results (v7.6.6.7)

```
bash scripts/preflight.sh → all checks pass ✓
bash scripts/assemble-sensor-history.sh --check → 4326 == 4326 ✓
```

All Phase Y checks pass:
- `firmware_core_fragments_exist`: PASS
- `firmware_core_assembly_check`: PASS (SHA-256 identity verified)
- `firmware_core_fragment_line_sum`: PASS (4326 == 4326)

---

## Known Deferred Gaps

### Gap 1: History Proxy Non-Functional

`GET /api/aggregator/proxy/{gw}/history/{device}/{metric}` returns an empty body.
First observed in v7.6.6.6, confirmed again in this session. Non-blocking — all other
aggregator read/mutation flows pass. Tracked for resolution post-Phase Y.

### Gap 2: Import/Export Cycle Crashes Board

The import/export endpoint sequence (`/api/import/begin` → `/api/import/d/` →
`/api/import/w/` → `/api/import/finish`) crashes the ESP32-C3 board on execution.
This is a pre-existing firmware bug. Endpoints 14–18 are deferred and are excluded
from the Phase Y smoke test gate. A dedicated bug-fix step is required post-Phase Y
before these endpoints can be validated on hardware.

---

_End of v7.6.6.7 session log._
