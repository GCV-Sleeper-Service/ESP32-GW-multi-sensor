# Phase 5 — Aggregator MVP

_Implementation Plan for v7.5.5.x_  
_Date: 2026-03-16_  
_Prerequisite: Phase 4 Complete (v7.5.4.4 on `main`)_  
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Goal

Build a working multi-gateway dashboard. The aggregator polls satellite gateways, caches their manifests and live values, and serves a unified dashboard showing devices from multiple gateways. Satellites require zero changes — they already expose everything needed.

**Key principle:** The aggregator is a separate role, not a satellite extension. It runs on more capable hardware (ESP32-S3 or Raspberry Pi). Keep it simple: poll, cache, serve.

---

## Architecture Reference

See `Docs/v7.5-v7.6-architecture-plan.md`:
- Section 8 — Gateway Aggregation Architecture
- Section 8.2 — Aggregator configuration
- Section 8.3 — Aggregator polling model
- Section 8.4 — Aggregator dashboard
- Section 8.5 — What the satellite must expose
- Section 13.3 — Hardware recommendations

---

## Hardware Decision

Before starting Phase 5, decide the aggregator target platform:

**Option A — ESP32-S3 (recommended for small deployments, ≤5 satellites):**
- More RAM (~512 KB), dual-core
- Same ESPHome/ESP-IDF toolchain as the satellite
- Single firmware codebase with `role` config switch
- Limitation: concurrent HTTP client connections, JSON payload sizes

**Option B — Raspberry Pi / lightweight server (recommended for >5 satellites):**
- Runs Node.js or Python Flask
- No memory constraints for caching
- Separate codebase from satellite firmware
- Most flexible, most capable

This implementation plan assumes **Option A (ESP32-S3)** for the initial MVP because it keeps the codebase unified. Option B can be pursued later as an alternative aggregator implementation.

---

## Phased Steps

### v7.5.5.0 — Aggregator configuration schema and loader

**Scope:** Define `config/aggregator.json` schema. Extend `sensor_manifest_lib.py` to validate it. Add a generated header for aggregator config.

**Files modified:**
- `config/aggregator.json` — new: aggregator configuration file
- `config/aggregator.example.json` — new: example with two satellites
- `scripts/sensor_manifest_lib.py` — add `load_aggregator_config()`, `validate_aggregator_config()`
- `scripts/render_sensor_config.py` — conditionally generate aggregator config header when `config/aggregator.json` exists
- `Docs/changelog.md` — v7.5.5.0 entry
- Version bump: ALL locations to `7.5.5.0`

**Implementation — aggregator config schema:**

```json
{
  "schema_version": 1,
  "role": "aggregator",
  "gateway_id": "gw-aggregator-01",
  "gateway_name": "Central Aggregator",
  "satellites": [
    {
      "id": "gw-bothell-01",
      "name": "Bothell Main",
      "base_url": "http://192.168.10.20",
      "poll_interval_seconds": 30
    },
    {
      "id": "gw-garage-01",
      "name": "Garage Sensors",
      "base_url": "http://192.168.10.21",
      "poll_interval_seconds": 30
    }
  ]
}
```

**Validation rules:**
- `role` must be `"aggregator"`
- Each satellite must have unique `id` and `base_url`
- `base_url` must be a valid HTTP URL (no trailing slash)
- `poll_interval_seconds` must be ≥10 and ≤300

**Acceptance criteria:**
- [ ] `config/aggregator.json` schema defined
- [ ] `config/aggregator.example.json` exists with example content
- [ ] Validation catches invalid configs (duplicate IDs, invalid URLs)
- [ ] Generator skips aggregator output when `config/aggregator.json` doesn't exist (satellites don't need it)
- [ ] Firmware compiles normally for satellite role (no aggregator code activated)
- [ ] Version is `7.5.5.0` everywhere

**Risk:** Low. Configuration schema only, no runtime changes.  
**Estimated effort:** 1 session.

---

### v7.5.5.1 — Aggregator polling task

**Scope:** Implement the background task that polls satellite APIs and caches results in RAM.

**Files modified:**
- `dashboard/sensor_history_multi.h` (or new `src/aggregator.h`) — add `AggregatorTask` class with HTTP client, polling loop, and cache
- `firmware/esp32-c3-multi-sensor.yaml` — conditionally start aggregator task when role is aggregator
- `Docs/changelog.md` — v7.5.5.1 entry
- Version bump: ALL locations to `7.5.5.1`

**Implementation — polling logic:**

The aggregator maintains a `SatelliteCache` per configured satellite:

```cpp
struct SatelliteCache {
  const char* id;
  const char* name;
  const char* base_url;
  uint32_t poll_interval_seconds;
  
  // Cached data
  char manifest_json[4096];     // cached /api/manifest response
  char live_json[2048];         // cached /api/v2/live response
  char status_json[512];        // cached /api/status response
  
  // State
  uint32_t last_manifest_fetch;
  uint32_t last_live_fetch;
  uint32_t last_status_fetch;
  bool reachable;
  uint32_t last_seen_epoch;
  uint8_t consecutive_failures;
};
```

Polling cycle (runs as RTOS task):
1. For each satellite, stagger fetches to avoid burst traffic
2. Fetch `GET /api/manifest` — cached aggressively, refreshed every 5 minutes
3. Fetch `GET /api/status` — every `poll_interval_seconds`
4. Fetch `GET /api/v2/live` — every `poll_interval_seconds`
5. Mark satellite as unreachable after 3 consecutive failures

**Critical notes:**
- Use ESP-IDF's HTTP client (`esp_http_client.h`), not Arduino WiFiClient
- Set connection timeout to 5 seconds per request
- Stagger satellite polling to avoid simultaneous connections
- Total RAM per satellite: ~7KB (4K manifest + 2K live + 512 status + overhead)
- For 5 satellites: ~35KB — feasible on ESP32-S3 (~512KB available)

**Acceptance criteria:**
- [ ] Aggregator task polls configured satellites
- [ ] Cached manifest, status, and live data available in RAM
- [ ] Unreachable satellites handled gracefully (marked offline)
- [ ] Polling is staggered to avoid traffic bursts
- [ ] Satellite firmware (when aggregator.json absent) is completely unaffected
- [ ] Version is `7.5.5.1` everywhere

**Risk:** High. New RTOS task, HTTP client connections, memory management, error handling. This is the core of the aggregator functionality.  
**Estimated effort:** 3–4 sessions.

**Device testing required:** YES — requires two ESP32 devices (one satellite, one aggregator) on the same network:
```bash
# Verify aggregator polls satellite
# Check aggregator /api/status shows aggregator role
# Check satellite appears in cached data
# Disconnect satellite, verify graceful degradation
```

---

### v7.5.5.2 — Aggregator API endpoints

**Scope:** Expose aggregator-specific API endpoints that serve cached satellite data.

**Files modified:**
- `dashboard/sensor_history_multi.h` — add aggregator endpoint handlers
- `scripts/preflight.sh` — add aggregator route checks (conditional)
- `Docs/changelog.md` — v7.5.5.2 entry
- Version bump: ALL locations to `7.5.5.2`

**New endpoints:**

`GET /api/aggregator/gateways` — list of satellites with status:
```json
{
  "gateways": [
    {
      "id": "gw-bothell-01",
      "name": "Bothell Main",
      "reachable": true,
      "last_seen": 1710264000,
      "firmware_version": "v7.5.4.4",
      "device_count": 4,
      "manifest": { /* cached v2 manifest */ }
    }
  ]
}
```

`GET /api/aggregator/live` — unified live values from all satellites:
```json
{
  "timestamp": 1710264000,
  "gateways": {
    "gw-bothell-01": {
      "reachable": true,
      "devices": {
        "office": { "temp": 23.4, "hum": 45.2, ... },
        "wan_ping": { "ping_ms": 12, "success_pct": 100 }
      }
    },
    "gw-garage-01": {
      "reachable": false,
      "last_seen": 1710260000,
      "devices": {}
    }
  }
}
```

`GET /api/aggregator/proxy/{gateway_id}/history/{device}/{metric}` — proxied history request to a specific satellite. The aggregator fetches from the satellite on-demand and passes through the response.

**Acceptance criteria:**
- [ ] `/api/aggregator/gateways` returns cached satellite list with status
- [ ] `/api/aggregator/live` returns unified live values
- [ ] `/api/aggregator/proxy/...` proxies history requests to correct satellite
- [ ] 404 for unknown gateway IDs
- [ ] Stale data includes `last_seen` timestamp
- [ ] Version is `7.5.5.2` everywhere

**Risk:** Medium.  
**Estimated effort:** 2 sessions.

---

### v7.5.5.3 — Aggregator dashboard with gateway selector

**Scope:** Extend the dashboard with multi-gateway UI. Add gateway selector (tabs or dropdown), gateway health cards, stale indicators, and namespaced device rendering.

**Files modified:**
- `dashboard/dashboard.js` — add aggregator boot flow, gateway selector UI, namespaced device rendering
- `dashboard/dashboard.html` — add gateway selector DOM elements, gateway health card section
- `dashboard/dashboard.min.html` — regenerated
- `dashboard/dashboard.h` — regenerated
- `Docs/changelog.md` — v7.5.5.3 entry
- Version bump: ALL locations to `7.5.5.3`

**Implementation details:**

The dashboard detects aggregator mode by checking `/api/aggregator/gateways`. If it returns 404, the dashboard operates in satellite mode (existing behavior). If it returns data, the dashboard switches to aggregator mode.

Aggregator mode adds:
1. **Gateway selector bar** — tabs or dropdown showing each satellite by name
2. **"All Gateways" summary view** — health overview with online/offline status per satellite
3. **Per-gateway view** — shows devices from one selected satellite, rendered with existing card renderers
4. **Stale indicators** — unreachable satellites show grayed-out cards with "Last seen: X minutes ago"
5. **Namespaced device IDs** — `gw-bothell-01.office` to avoid collisions between gateways that have devices with the same ID

**Acceptance criteria:**
- [ ] Dashboard detects aggregator mode automatically
- [ ] Gateway selector shows all satellites
- [ ] Selecting a gateway shows its devices
- [ ] "All Gateways" view shows health overview
- [ ] Unreachable satellites show stale indicators
- [ ] Satellite-mode dashboard is completely unaffected
- [ ] Version is `7.5.5.3` everywhere

**Risk:** Medium-High. Significant dashboard changes. Must not break satellite-mode rendering.  
**Estimated effort:** 3–4 sessions.

---

### v7.5.5.4 — Aggregator test fixtures and Playwright tests

**Scope:** Create test fixtures and Playwright tests for aggregator mode.

**Files modified:**
- `tests/fixtures/variants/aggregator/` — new: aggregator fixture set with mock satellite data
- `tests/mock-server/server.js` — add aggregator endpoint mocking
- `tests/browser/dashboard.spec.js` — add Group 17: aggregator mode tests
- `Docs/changelog.md` — v7.5.5.4 entry
- Version bump: ALL locations to `7.5.5.4`

**New Playwright tests (Group 17 — Aggregator Mode):**
1. Dashboard detects aggregator mode from `/api/aggregator/gateways`
2. Gateway selector renders with correct satellite names
3. Selecting a gateway shows its devices
4. "All Gateways" view shows health overview
5. Stale satellite shows "unreachable" indicator
6. History chart loads through aggregator proxy
7. Satellite mode still works when aggregator endpoints return 404

**Estimated effort:** 2 sessions.

---

### v7.5.5.5 — Documentation and Phase 5 closure

**Scope:** Create aggregator setup guide, update architecture plan, close phase.

**Files modified:**
- `Docs/aggregator-setup.md` — new: aggregator deployment guide
- `Docs/changelog.md` — v7.5.5.5 entry with Phase 5 Complete callout
- `Docs/v7.5-v7.6-architecture-plan.md` — Phase 5 Status: COMPLETE
- `Docs/session-log-2026-XX-XX-v7.5.5.5.md` — session log
- `Docs/bugs-and-lessons-learned.md` — new entries if bugs found
- Version bump: ALL locations to `7.5.5.5`

**`Docs/aggregator-setup.md` contents:**
- Hardware requirements (ESP32-S3 recommended)
- Configuration file (`config/aggregator.json`)
- Network requirements (aggregator must reach all satellite IPs)
- Dashboard access
- Troubleshooting (satellite unreachable, stale data)

**Estimated effort:** 1 session.

---

## Memory Budget

| Component | Per satellite | 5 satellites |
|---|---|---|
| SatelliteCache struct | ~7 KB | ~35 KB |
| HTTP client buffers | ~4 KB | ~4 KB (shared) |
| Dashboard payload increase | ~2 KB | ~10 KB |
| **Total aggregator overhead** | | **~49 KB** |

ESP32-S3 available RAM: ~512 KB. Aggregator overhead: ~49 KB for 5 satellites. Feasible.

ESP32-C3 available RAM: ~320 KB. Not recommended for aggregation (per architecture plan).

---

_End of Phase 5 Implementation Plan._
