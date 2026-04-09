# Phase 4 — First Non-Climate Sensor Category (Network / Ping Probe)

_Implementation Plan for v7.5.4.x_  
_Date: 2026-03-16_  
_Prerequisite: Phase 3 Complete (v7.5.3.7 on `main`)_  
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Goal

Prove the generalized SensorEntity model works with a real second device category by adding a network ping probe. When Phase 4 is complete, the dashboard will show ThermoPro climate cards **and** a WAN latency card side by side, all driven from the v2 manifest. The environmental cards must be completely unaffected.

**Key principle:** This is the validation phase. If the abstraction designed in Phases 1–3 is correct, adding a ping probe should require: one manifest entry, one RTOS task (the adapter), one dashboard card renderer, and zero changes to the core data model or persistence engine.

---

## Architecture Reference

See `Docs/v7.5-v7.6-architecture-plan.md`:
- Section 6.4 — Adapter integration (ping probe example)
- Section 7.2 — Card renderer registry (network renderer slot)
- Section 10.2 — New metric categories: RAM-only initially
- Phase 4 task list (Section 11)
- `config/sensors.v2.example.json` — example mixed-category manifest (created in Phase 3)

---

## Phased Steps

### v7.5.4.0 — Add ping probe device to manifest and generator

**Scope:** Add a `wan_ping` device entry to `config/sensors.json` (v2 schema upgrade) and extend the generator to produce SensorEntity arrays for non-environmental devices. No firmware adapter yet — the device is defined but produces no data.

**Files modified:**
- `config/sensors.json` — upgrade to v2 schema with `wan_ping` device added
- `scripts/sensor_manifest_lib.py` — extend validation to support v2 schema with mixed device types (non-BLE devices have no `mac` field)
- `scripts/render_sensor_config.py` — extend SensorEntity generation for non-ThermoPro devices; generate separate `MetricDef` arrays per device category
- `dashboard/sensor_history_multi.h` — regenerated with 4th SensorEntity (ping probe, RAM-only history)
- `src/gateway_manifest.h` — regenerated with `wan_ping` device in manifest
- `tests/fixtures/manifest.json` — regenerated
- `tests/fixtures/generate-fixtures.js` — extend for mixed-category fixtures
- `Docs/changelog.md` — v7.5.4.0 entry
- Version bump: ALL locations to `7.5.4.0`

**Implementation — manifest upgrade:**

`config/sensors.json` becomes a v2 manifest:
```json
{
  "schema_version": 2,
  "sensors": [
    {
      "id": "office",
      "name": "Office",
      "mac": "DB:06:2C:58:8A:59",
      "category": "environmental",
      "adapter": "thermopro_ble"
    },
    {
      "id": "first_floor",
      "name": "First Floor",
      "mac": "D5:D8:4C:25:06:49",
      "category": "environmental",
      "adapter": "thermopro_ble"
    },
    {
      "id": "outside",
      "name": "Outside",
      "mac": "DF:EB:DE:19:11:6C",
      "category": "environmental",
      "adapter": "thermopro_ble"
    },
    {
      "id": "wan_ping",
      "name": "WAN Latency",
      "category": "network",
      "adapter": "icmp_ping",
      "source": { "target": "8.8.8.8" }
    }
  ]
}
```

**Implementation — generator changes:**

The generator must detect device category and produce the correct MetricDef arrays:
- `environmental` + `thermopro_ble` → `metrics_thermopro[]` (temp, hum, batt, rssi)
- `network` + `icmp_ping` → `metrics_ping[]` (ping_ms, success_pct)

For ping probe metrics, `history_enabled = true` but history buffers are RAM-only (no flash persistence):
```cpp
static const MetricDef metrics_ping[] = {
  {"ping_ms",     "Latency", "ms", 0, true},
  {"success_pct", "Success", "%",  0, true}
};

static HistoryBuffer entity_hbuf_wan_ping_latency;
static HistoryBuffer entity_hbuf_wan_ping_success;
```

**Implementation — manifest lib changes:**

`sensor_manifest_lib.py` validation must be relaxed for non-BLE devices:
- `mac` field is required only when `adapter` is `thermopro_ble`
- `source.target` is required when `adapter` is `icmp_ping`
- `category` must be one of: `environmental`, `network`, `system`
- `id` slug validation still applies (lowercase, underscores)
- `name` length limit still applies (15 chars)

The existing `canonicalize_sensors()` function needs updating:
```python
def canonicalize_sensors(sensors):
    # ... existing id/name validation ...
    for sensor in sensors:
        adapter = sensor.get("adapter", "thermopro_ble")
        if adapter == "thermopro_ble":
            # mac is required for BLE devices
            mac = normalize_mac(sensor.get("mac", ""))
            if not mac or not MAC_RE.match(mac):
                raise ManifestError(...)
        elif adapter == "icmp_ping":
            # source.target is required for ping devices
            source = sensor.get("source", {})
            if not source.get("target"):
                raise ManifestError(f'Ping device "{name}" requires source.target')
```

**Acceptance criteria:**
- [ ] `config/sensors.json` upgraded to v2 with 3 ThermoPro + 1 ping device
- [ ] Generator produces `SensorEntity devices[4]` with correct metric arrays
- [ ] `NUM_DEVICES = 4`, `NUM_ENV_SENSORS = 3`, `NUM_SENSORS = NUM_ENV_SENSORS` in generated header
- [ ] `NUM_DEVICES` and persisted environmental sensor count remain separate constants — generator must never alias `NUM_SENSORS = NUM_DEVICES` in mixed-category firmware
- [ ] Existing retained ThermoPro history remains schema-compatible after flashing (`meta->num_sensors == NUM_SENSORS` evaluates to `3 == 3`)
- [ ] Manifest fixture includes `wan_ping` device with `category: network`
- [ ] Firmware compiles (ping device exists in data model but produces no data)
- [ ] All existing Playwright tests pass (environmental rendering unchanged)
- [ ] Version is `7.5.4.0` everywhere

**Risk:** Medium. Manifest validation changes must not break existing ThermoPro-only configs. The v1→v2 schema migration path needs careful handling.  
**Estimated effort:** 2 sessions.

**Device testing required:** YES — compile and verify the ping device appears in `/api/manifest` and `/api/v2/live` (with null values).

---

### v7.5.4.1 — Implement ICMP ping adapter

**Scope:** Add the `icmp_ping` adapter as a periodic RTOS task in the firmware. It pings the configured target every 60 seconds, computes average RTT and success rate, and calls `devices[n].add_sample()`.

**Files modified:**
- `dashboard/sensor_history_multi.h` — add `PingAdapter` class with RTOS task, ICMP socket, and result callback
- `firmware/esp32-c3-multi-sensor.yaml` — add ping adapter initialization in `setup:` lambda
- `scripts/render_sensor_config.py` — generate ping adapter init code for devices with `adapter: icmp_ping`
- `Docs/changelog.md` — v7.5.4.1 entry
- Version bump: ALL locations to `7.5.4.1`

**Implementation details — ICMP ping on ESP-IDF:**

ESP-IDF provides `lwip/icmp_echo.h` or raw sockets for ICMP. The simplest approach:

```cpp
#include <lwip/ip_addr.h>
#include <lwip/inet_chksum.h>
#include <lwip/sockets.h>
#include <lwip/netdb.h>
#include <ping/ping_sock.h>

class PingAdapter {
  const char* target_host;
  int device_index;
  uint32_t interval_ms;
  
  // Called by RTOS timer every interval_ms
  static void ping_task(void* arg) {
    auto* self = static_cast<PingAdapter*>(arg);
    // Send 3 pings, compute avg RTT and success rate
    float total_ms = 0;
    int success_count = 0;
    for (int i = 0; i < 3; i++) {
      float rtt = self->send_single_ping();
      if (rtt >= 0) {
        total_ms += rtt;
        success_count++;
      }
      vTaskDelay(pdMS_TO_TICKS(200));
    }
    float avg_rtt = success_count > 0 ? total_ms / success_count : NAN;
    float success_pct = (success_count / 3.0f) * 100.0f;
    
    devices[self->device_index].add_sample(0, avg_rtt);        // ping_ms
    devices[self->device_index].add_sample(1, success_pct);    // success_pct
    devices[self->device_index].mark_seen(::time(nullptr));
  }
};
```

**Critical notes:**
- Use ESP-IDF's `ping` component if available, or raw ICMP sockets
- The ping task runs on the main core (ESP32-C3 is single-core) — keep execution brief
- 3 pings per cycle × 200ms spacing = ~600ms per cycle, well under the 60s interval
- Handle DNS resolution for hostname targets (not just IP addresses)
- Handle network-down gracefully (mark metrics as invalid, don't crash)

**Acceptance criteria:**
- [ ] Ping adapter runs every 60 seconds
- [ ] `devices[wan_ping_index].metric_states[0]` (ping_ms) receives valid data
- [ ] `devices[wan_ping_index].metric_states[1]` (success_pct) receives valid data
- [ ] `/api/v2/live` shows ping metrics
- [ ] Environmental sensors completely unaffected
- [ ] Heap usage increase is modest (<2KB)
- [ ] Version is `7.5.4.1` everywhere

**Risk:** Medium-High. New RTOS task, ICMP socket management, DNS resolution. The adapter is isolated from the BLE path, but bugs could affect system stability.  
**Estimated effort:** 2–3 sessions.

**Device testing required:** YES — critical:
```bash
# Verify ping data appears
curl http://192.168.120.189/api/v2/live | jq '.devices.wan_ping'

# Verify environmental data is unaffected
curl http://192.168.120.189/api/v2/live | jq '.devices.office'

# Verify history accumulates (wait 15+ minutes)
curl http://192.168.120.189/api/v2/history/wan_ping/ping_ms

# Check heap
curl http://192.168.120.189/api/status | jq '.free_heap'
```

---

### v7.5.4.2 — Add `CARD_RENDERERS.network` to dashboard

**Scope:** Implement the network card renderer for the dashboard. Shows current latency, success rate, and target host. Environmental cards must be unchanged.

**Files modified:**
- `dashboard/dashboard.js` — add `CARD_RENDERERS.network` function, add `METRIC_FORMATTERS.ping_latency` and `METRIC_FORMATTERS.success_rate`
- `dashboard/dashboard.html` — add network card CSS styles if needed
- `dashboard/dashboard.min.html` — regenerated
- `dashboard/dashboard.h` — regenerated
- `Docs/changelog.md` — v7.5.4.2 entry
- Version bump: ALL locations to `7.5.4.2`

**Implementation details:**

```javascript
CARD_RENDERERS.network = function(device, manifest) {
  return buildNetworkCard(device, manifest);
};

function buildNetworkCard(s, manifest) {
  return (
    '<div class="sensor-card network-card">' +
      '<div class="sensor-card-header">' +
        '<input class="sensor-color-picker" id="picker-' + s.id + '" type="color" value="' + (s.color || '#4FC3F7') + '" data-sensor-color="' + s.id + '">' +
        s.name +
      '</div>' +
      '<div class="sensor-readings">' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Latency</div>' +
          '<div class="reading-value waiting" id="val-ping-' + s.id + '" style="color:' + (s.color || '#4FC3F7') + '">&mdash;</div>' +
        '</div>' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Success Rate</div>' +
          '<div class="reading-value waiting" id="val-success-' + s.id + '">&mdash;</div>' +
        '</div>' +
        '<div class="sensor-reading">' +
          '<div class="reading-label">Target</div>' +
          '<div class="reading-value" id="val-target-' + s.id + '">8.8.8.8</div>' +
        '</div>' +
      '</div>' +
    '</div>'
  );
}

METRIC_FORMATTERS.ping_latency = function(value) {
  return value.toFixed(0) + ' ms';
};

METRIC_FORMATTERS.success_rate = function(value) {
  return value.toFixed(0) + '%';
};
```

**Dashboard data path for network cards:**
- `handleState()` needs to recognize non-environmental sensor state updates
- `loadHistory()` needs to handle network device history (uses `fetchDeviceHistory()` which is already manifest-driven — should work with no changes)
- Chart rendering needs to handle network metrics (axis labels, colors)

**Acceptance criteria:**
- [ ] Network card renders for `wan_ping` device
- [ ] Environmental cards are pixel-identical to pre-Phase-4
- [ ] Network card shows current latency and success rate
- [ ] Chart renders for ping history (if history is available)
- [ ] All existing Playwright tests pass (regression gate)
- [ ] Version is `7.5.4.2` everywhere

**Risk:** Medium. New card renderer and metric formatters. Must not break environmental rendering.  
**Estimated effort:** 2 sessions.

---

### v7.5.4.3 — Mixed-category test fixtures and Playwright tests

**Scope:** Create test fixtures for mixed environmental + network device sets. Add Playwright tests for network card rendering.

**Files modified:**
- `tests/fixtures/variants/mixed/` — new: fixture set with 2 ThermoPro + 1 ping probe
- `tests/fixtures/generate-fixtures.js` — extend for mixed-category variant generation
- `tests/mock-server/server.js` — extend to serve mixed-category fixture data, including ping history
- `tests/browser/dashboard.spec.js` — add Group 16: mixed-category rendering tests
- `playwright.config.js` — add mixed variant project if needed
- `Docs/changelog.md` — v7.5.4.3 entry
- Version bump: ALL locations to `7.5.4.3`

**New Playwright tests (Group 16 — Mixed Category Rendering):**
1. Dashboard renders both environmental and network cards
2. Environmental cards have full structure (temp, hum, minmax, batt, rssi)
3. Network card has latency and success rate fields
4. `CARD_RENDERERS` dispatches environmental and network renderers correctly
5. History chart renders for both environmental and network devices
6. `/api/v2/live` returns data for both device categories
7. Network card uses correct metric formatters

**Acceptance criteria:**
- [ ] Mixed-category fixture set exists and is served by mock server
- [ ] All new Group 16 tests pass
- [ ] All existing tests pass (regression gate)
- [ ] Version is `7.5.4.3` everywhere

**Risk:** Low-Medium. Test fixture generation for mixed categories.  
**Estimated effort:** 1–2 sessions.

---

### v7.5.4.4 — Full regression + Phase 4 closure

**Scope:** Final validation, documentation update, phase closure.

**Files modified:**
- `Docs/changelog.md` — v7.5.4.4 entry with Phase 4 Complete callout
- `Docs/v7.5-v7.6-architecture-plan.md` — Phase 4 Status: COMPLETE
- `Docs/session-log-2026-XX-XX-v7.5.4.4.md` — session log
- `Docs/bugs-and-lessons-learned.md` — new entries if bugs found
- Version bump: ALL locations to `7.5.4.4`

**Acceptance criteria:**
- [ ] All Playwright tests pass (existing + new)
- [ ] Architecture plan updated with Phase 4 COMPLETE
- [ ] Changelog has Phase 4 Complete callout
- [ ] Session log created
- [ ] Version is `7.5.4.4` everywhere

**Risk:** Low.  
**Estimated effort:** 1 session.

---

## Flash Persistence: What Changes and What Doesn't

**DOES NOT CHANGE:**
- `SegmentSnapshot` format (temp/hum arrays)
- NVS key naming scheme
- Environmental device persistence to flash
- CSV export/import for environmental devices

**NEW for network devices:**
- RAM-only history (HistoryBuffer ring buffers, no NVS persistence)
- History is lost on reboot (acceptable for operational metrics)
- No CSV export/import for network metrics initially

This is per architecture plan Section 10.2: "Non-environmental metrics use RAM ring buffers only."

---

## Version Bump Checklist

Use `bash scripts/bump-version.sh <version>` (fixed in Phase 3 to include `dashboard.html`).

---

_End of Phase 4 Implementation Plan._
