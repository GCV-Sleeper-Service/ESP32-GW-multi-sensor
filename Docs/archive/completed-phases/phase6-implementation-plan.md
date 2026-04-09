# Phase 6 — Data Ingest Endpoint and System Metrics

_Implementation Plan for v7.5.6.x_  
_Date: 2026-03-16_  
_Prerequisite: Phase 5 Complete (v7.5.5.5 on `main`)_  
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Goal

Enable external systems to push metrics into the gateway via a simple HTTP endpoint. Add a `system` device category for CPU, RAM, and disk metrics. Provide an example exporter script that runs on a NAS or server.

**Key principle:** The gateway becomes a metrics collector, not just a BLE scanner. External scripts push data in; the gateway stores it in RAM history buffers and displays it on the dashboard alongside environmental and network data.

---

## Architecture Reference

See `Docs/v7.5-v7.6-architecture-plan.md`:
- Section 9.2 — `POST /api/ingest/{device_id}/{metric_key}?val={float}`
- Section 7.2 — `CARD_RENDERERS.system` (CPU gauge, RAM bar, disk bar)
- Section 10.2 — RAM-only history for new metric categories

---

## Phased Steps

### v7.5.6.0 — Implement `POST /api/ingest` endpoint

**Scope:** Add the data ingest endpoint. Validates device ID and metric key against the manifest. Requires the device to be pre-defined in `config/sensors.json`.

**Files modified:**
- `dashboard/sensor_history_multi.h` — add `handle_api_ingest_()` method, route matching for `POST /api/ingest/{device_id}/{metric_key}`
- `scripts/preflight.sh` — add ingest route check
- `Docs/changelog.md` — v7.5.6.0 entry
- Version bump: ALL locations to `7.5.6.0`

**Implementation:**

```cpp
void handle_api_ingest_(AsyncWebServerRequest *request) const {
  // URL: /api/ingest/{device_id}/{metric_key}?val={float}
  String path = request->url();
  // Parse device_id and metric_key from path
  // Validate against manifest
  // Find matching SensorEntity and metric index
  // Call devices[d].add_sample(m, value)
  // Return 200 OK or 404/400 on error
}
```

**URL format:** `POST /api/ingest/{device_id}/{metric_key}?val={float}`

**Validation:**
- `device_id` must match a device in the manifest
- `metric_key` must match a metric in that device's metric definitions
- `val` must be a valid float
- Return 404 for unknown device or metric
- Return 400 for missing/invalid `val`
- Return 200 with `{"ok":true}` on success

**Security note:** No authentication in this initial implementation. The endpoint is reachable by any client on the same network. Authentication (API key or basic auth) should be added in a future hardening pass. Document this limitation explicitly.

**Acceptance criteria:**
- [ ] `POST /api/ingest/nas01/cpu_usage_pct?val=33.2` updates the correct metric
- [ ] Unknown device returns 404
- [ ] Unknown metric returns 404
- [ ] Missing val returns 400
- [ ] `/api/v2/live` reflects ingested values
- [ ] Environmental and network devices unaffected
- [ ] Version is `7.5.6.0` everywhere

**Risk:** Low-Medium. The endpoint is simple (parse URL, validate, call add_sample). Main concern is URL parsing correctness.  
**Estimated effort:** 1–2 sessions.

**Device testing required:** YES:
```bash
# Test ingest (requires a system device in manifest first — see v7.5.6.1)
curl -X POST "http://192.168.120.189/api/ingest/nas01/cpu_pct?val=45.2"
curl http://192.168.120.189/api/v2/live | jq '.devices.nas01'
```

---

### v7.5.6.1 — Add system device category and manifest entries

**Scope:** Add a `system` device type to the manifest for host metrics. Extend the generator to handle system devices.

**Files modified:**
- `config/sensors.json` — add example system device (`nas01`)
- `scripts/sensor_manifest_lib.py` — extend validation for `system` category and `external_push` adapter
- `scripts/render_sensor_config.py` — generate SensorEntity for system devices with RAM-only metrics
- `dashboard/sensor_history_multi.h` — regenerated with system device
- `src/gateway_manifest.h` — regenerated
- `Docs/changelog.md` — v7.5.6.1 entry
- Version bump: ALL locations to `7.5.6.1`

**Manifest entry example:**
```json
{
  "id": "nas01",
  "name": "NAS Health",
  "category": "system",
  "adapter": "external_push",
  "source": { "description": "Pushed via /api/ingest from NAS cron job" },
  "measurements": [
    { "key": "cpu_pct", "label": "CPU Usage", "unit": "%", "class": "analog", "history": true, "history_backend": "ram_only" },
    { "key": "ram_pct", "label": "RAM Usage", "unit": "%", "class": "analog", "history": true, "history_backend": "ram_only" },
    { "key": "disk_pct", "label": "Disk Usage", "unit": "%", "class": "analog", "history": true, "history_backend": "ram_only" },
    { "key": "uptime_hrs", "label": "Uptime", "unit": "hours", "class": "metadata", "history": false }
  ]
}
```

**Generator notes:**
- System devices use `external_push` adapter — no RTOS task, no BLE scanning
- All metrics are RAM-only history (no flash persistence)
- No MAC address (not a BLE device)
- Data arrives via `POST /api/ingest` calls from external scripts

**Acceptance criteria:**
- [ ] System device appears in `/api/manifest`
- [ ] `SensorEntity` generated with correct metrics
- [ ] `/api/v2/live` shows null values for system device (no data pushed yet)
- [ ] Firmware compiles and runs
- [ ] Environmental and network devices unaffected
- [ ] Version is `7.5.6.1` everywhere

**Risk:** Low.  
**Estimated effort:** 1 session.

---

### v7.5.6.2 — Add `CARD_RENDERERS.system` to dashboard

**Scope:** Implement the system card renderer. Shows CPU gauge, RAM bar, disk bar, and uptime.

**Files modified:**
- `dashboard/dashboard.js` — add `CARD_RENDERERS.system`, `buildSystemCard()`, system metric formatters
- `dashboard/dashboard.html` — add system card CSS (gauge/bar styles)
- `dashboard/dashboard.min.html` — regenerated
- `dashboard/dashboard.h` — regenerated
- `Docs/changelog.md` — v7.5.6.2 entry
- Version bump: ALL locations to `7.5.6.2`

**Implementation:**

```javascript
CARD_RENDERERS.system = function(device, manifest) {
  return buildSystemCard(device, manifest);
};

function buildSystemCard(s, manifest) {
  return (
    '<div class="sensor-card system-card">' +
      '<div class="sensor-card-header">' +
        '<input class="sensor-color-picker" id="picker-' + s.id + '" type="color" value="' + (s.color || '#66BB6A') + '" data-sensor-color="' + s.id + '">' +
        s.name +
      '</div>' +
      '<div class="sensor-readings">' +
        buildUsageBar('CPU', 'cpu-' + s.id) +
        buildUsageBar('RAM', 'ram-' + s.id) +
        buildUsageBar('Disk', 'disk-' + s.id) +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Uptime</div>' +
          '<div class="reading-value waiting" id="val-uptime-' + s.id + '">&mdash;</div>' +
        '</div>' +
      '</div>' +
    '</div>'
  );
}

function buildUsageBar(label, id) {
  return (
    '<div class="sensor-reading system-usage-row">' +
      '<div class="reading-label">' + label + '</div>' +
      '<div class="system-usage-bar-bg"><div class="system-usage-bar-fill" id="bar-' + id + '" style="width:0%"></div></div>' +
      '<div class="reading-value waiting" id="val-' + id + '">&mdash;</div>' +
    '</div>'
  );
}

METRIC_FORMATTERS.cpu_usage = function(value) { return value.toFixed(1) + '%'; };
METRIC_FORMATTERS.ram_usage = function(value) { return value.toFixed(1) + '%'; };
METRIC_FORMATTERS.disk_usage = function(value) { return value.toFixed(1) + '%'; };
```

**Acceptance criteria:**
- [ ] System card renders with CPU/RAM/disk usage bars
- [ ] Usage bars fill proportionally to value (0–100%)
- [ ] Color coding: green < 60%, yellow 60–80%, red > 80%
- [ ] Environmental and network cards unchanged
- [ ] Version is `7.5.6.2` everywhere

**Risk:** Low-Medium. New card renderer, new CSS.  
**Estimated effort:** 2 sessions.

---

### v7.5.6.3 — Example exporter script

**Scope:** Create an example script that pushes system metrics to the gateway from an external host.

**Files modified:**
- `scripts/exporters/system-metrics-exporter.sh` — new: bash script for Linux hosts
- `scripts/exporters/system-metrics-exporter.py` — new: Python script (cross-platform)
- `Docs/data-ingest-setup.md` — new: documentation for the ingest workflow
- `Docs/changelog.md` — v7.5.6.3 entry
- Version bump: ALL locations to `7.5.6.3`

**Bash exporter (Linux):**

```bash
#!/usr/bin/env bash
# system-metrics-exporter.sh — Push system metrics to ESP32 gateway
# Usage: add to crontab: * * * * * /path/to/system-metrics-exporter.sh
#
# Configuration
GATEWAY_URL="http://192.168.10.20"
DEVICE_ID="nas01"

# Collect metrics
CPU_PCT=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
RAM_PCT=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100.0}')
DISK_PCT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
UPTIME_HRS=$(awk '{printf "%.1f", $1/3600}' /proc/uptime)

# Push to gateway
curl -s -X POST "${GATEWAY_URL}/api/ingest/${DEVICE_ID}/cpu_pct?val=${CPU_PCT}" > /dev/null
curl -s -X POST "${GATEWAY_URL}/api/ingest/${DEVICE_ID}/ram_pct?val=${RAM_PCT}" > /dev/null
curl -s -X POST "${GATEWAY_URL}/api/ingest/${DEVICE_ID}/disk_pct?val=${DISK_PCT}" > /dev/null
curl -s -X POST "${GATEWAY_URL}/api/ingest/${DEVICE_ID}/uptime_hrs?val=${UPTIME_HRS}" > /dev/null

echo "Pushed: cpu=${CPU_PCT}% ram=${RAM_PCT}% disk=${DISK_PCT}% uptime=${UPTIME_HRS}h"
```

**Acceptance criteria:**
- [ ] Bash exporter runs on Linux and pushes valid data
- [ ] Python exporter runs on Linux/macOS/Windows
- [ ] Documentation explains setup step by step
- [ ] Gateway displays system metrics from external host
- [ ] Version is `7.5.6.3` everywhere

**Risk:** Low.  
**Estimated effort:** 1 session.

---

### v7.5.6.4 — Test fixtures, Playwright tests, and Phase 6 closure ✅ COMPLETE

**Status: COMPLETE** (2026-03-26)

**Scope:** Create test fixtures for system devices, add Playwright tests, close phase.

**Files modified:**
- `tests/fixtures/variants/system/` — new: fixture set with 2 env + 1 network + 1 system = 4 sensors
- `tests/fixtures/variants/mixed/` — updated: added `nas01` system device (LESSON-OPS-079)
- `tests/fixtures/generate-fixtures.js` — added `generateSystemFixtures()`, updated `generateMixedFixtures()` to include nas01
- `tests/mock-server/server.js` — added POST `/api/ingest/:deviceId/:metricKey`, non-null system data in `/api/v2/live` for system fixture
- `tests/browser/dashboard.spec.js` — added Group 20: System Devices and Data Ingest (8 tests), skip guards for system fixture incompatibility, updated Group 18 for 4-sensor mixed variant
- `tests/browser/manifest.spec.js` — skip guard for system fixture
- `dashboard/dashboard.js` + `dashboard/dashboard.html` — BUG-072 fix (`last_seen != null`), BUG-073 fix (`escHtml(target)`)
- `.github/workflows/browser-tests.yml` — added `system` to matrix, added Group 20 CI step
- `Docs/changelog.md` — v7.5.6.4 entry with Phase 6 Complete callout
- `Docs/v7.5-v7.6-architecture-plan.md` — Phase 6 Status: COMPLETE
- `Docs/session-log-2026-03-26-v7.5.6.4.md` — session log
- `Docs/bugs-and-lessons-learned.md` — skip guard documentation
- Version bump: ALL locations to `7.5.6.4`

**Playwright tests (Group 20 — System Devices and Data Ingest):**
1. System fixture renders correct total card count (4)
2. System card renders with usage bar elements
3. Environmental cards have full ThermoPro layout (count: 2)
4. Network card present alongside system card (count: 1)
5. `CARD_RENDERERS.system` is registered
6. `/api/v2/live` returns system device data
7. POST `/api/ingest` returns 200 for valid device/metric
8. POST `/api/ingest` returns 404 for unknown device

**Acceptance criteria:**
- [x] All new tests pass
- [x] All existing tests pass (regression gate)
- [x] Architecture plan updated with Phase 6 COMPLETE
- [x] Phase 6 Complete callout in changelog
- [x] Version is `7.5.6.4` everywhere

---

## Security Considerations

The `POST /api/ingest` endpoint has **no authentication** in this initial implementation. This is acceptable for a home/lab network but not for production deployments.

Future security hardening (out of scope for Phase 6):
- API key authentication via header (`X-API-Key`) validated against secrets file
- Rate limiting per client IP
- Input validation (reject extreme values, enforce metric bounds)
- HTTPS support (requires TLS on ESP32, significant memory cost)

Document these limitations in `Docs/data-ingest-setup.md`.

---

_End of Phase 6 Implementation Plan._
