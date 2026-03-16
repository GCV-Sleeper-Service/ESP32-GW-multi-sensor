# Phase 3 — C++ SensorEntity Model (ThermoPro Only)

_Implementation Plan for v7.5.3.x_  
_Date: 2026-03-16_  
_Prerequisite: Phase 2 Complete (v7.5.2.4 on `main`); v7.5.3.0 pre-Phase 3 cleanup complete_  
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Goal

Replace the hardcoded `SensorSlot` C++ struct with the generalized `SensorEntity` + `MetricDef` + `MetricState` model described in `Docs/v7.5-v7.6-architecture-plan.md` Section 6. **ThermoPro remains the only active device category.** The goal is to prove the new model produces identical external behavior — same API responses, same dashboard rendering, same flash persistence — while the internal code structure becomes extensible.

**Key principle:** Zero user-visible changes. The firmware looks and behaves identically from the outside. The refactor changes the internal data model, not the output.

---

## Architecture Reference

See `Docs/v7.5-v7.6-architecture-plan.md`:
- Section 6 — Firmware Model: From SensorSlot to SensorEntity
- Section 6.2 — Proposed model (MetricDef, MetricState, SensorEntity structs)
- Section 6.3 — Generated code example
- Section 6.4 — Adapter integration
- Section 9 — API Contract Design (new v2 endpoints)
- Section 10 — History and Persistence Strategy

See also:
- `Docs/phase1-phase2-assessment-and-remediation.md` — GAP-P1-02 (schema naming decision required)
- `Docs/bugs-and-lessons-learned.md` — critical guardrails

---

## Pre-Phase 3 Remediation (v7.5.3.0)

Before the C++ refactor starts, resolve the gaps identified in the Phase 1/2 assessment. This step is small but important — it clears the technical debt so Phase 3 starts clean.

### v7.5.3.0 — Pre-Phase 3 cleanup and schema decision

**Scope:** Fix `bump-version.sh` gap, create v2 example config, resolve schema naming decision, fix boot flow sequencing.

**Files modified:**
- `scripts/bump-version.sh` — add `dashboard.html` version update
- `config/sensors.v2.example.json` — new: example v2 config with ThermoPro + ping probe device
- `dashboard/dashboard.js` — sequence `loadManifestV2()` before `loadSensorManifest()` in boot flow
- `dashboard/dashboard.html` — no changes beyond version bump
- `dashboard/dashboard.min.html` — regenerated
- `dashboard/dashboard.h` — regenerated
- `tests/browser/dashboard.spec.js` — update boot test if needed
- `Docs/changelog.md` — v7.5.3.0 entry
- Version bump: ALL locations to `7.5.3.0`

**Implementation details:**

1. **Fix `bump-version.sh`** — Add after the `generate-fixtures.js` update:
   ```bash
   echo "→ Updating dashboard/dashboard.html..."
   sed -i "s/App\.version = 'v[0-9.]*'/App.version = 'v${NEW_VER}'/" dashboard/dashboard.html
   ```

2. **Create `config/sensors.v2.example.json`** — Reference config showing mixed device types:
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
         "id": "wan_ping",
         "name": "WAN Latency",
         "category": "network",
         "adapter": "icmp_ping",
         "source": { "target": "8.8.8.8" }
       }
     ]
   }
   ```
   This file is documentation only — the generator still reads from `config/sensors.json`.

3. **Schema naming decision** — Keep `sensors` naming in the manifest for now (backward compatibility). The architecture plan's `devices` naming is aspirational — renaming at this point would break test fixtures, preflight checks, and the manifest loader. Add a comment in `sensor_manifest_lib.py` documenting the decision:
   ```python
   # NOTE: The architecture plan uses "devices" but the implementation uses "sensors"
   # for backward compatibility. The names are functionally equivalent. Migration to
   # "devices" is deferred to a future major version if needed.
   ```

4. **Fix boot flow sequencing** — In `App.Boot.start()`, sequence `loadManifestV2()` to complete before `loadSensorManifest()`:
   ```javascript
   App.Boot.start = function() {
     var modeStr = TRANSPORT === 'sse' ? (ESP_HOST === '' ? 'HOSTED' : 'SSE') : 'POLLING';
     document.getElementById('modeLabel').textContent = '[' + modeStr + ' mode]';
     
     // v7.5.3.0: sequence manifest v2 load before sensor manifest load
     // to ensure window._manifest is available when buildDeviceCards() runs
     loadManifestV2().then(function(manifest) {
       window._manifest = manifest;
       dlog('[manifest] v2 manifest stored (source: ' + (manifest.source || 'unknown') + ')', 'ok');
     }).catch(function(e) {
       dlog('[manifest] loadManifestV2 failed: ' + e.message, 'err');
       window._manifest = null;
     }).then(function() {
       return loadSensorManifest();
     }).then(function() {
       // ... existing boot sequence unchanged from here
     });
   };
   ```

**Acceptance criteria:**
- [x] `bump-version.sh` updates `dashboard.html` automatically
- [x] `config/sensors.v2.example.json` exists with mixed-category example
- [x] Boot flow loads manifest v2 before sensor manifest
- [x] All 73 Playwright tests pass
- [x] Preflight passes
- [x] Version is `7.5.3.0` everywhere

**Status: ✅ Complete (merged in PR #31, 2026-03-16)**

**Risk:** Low. Cleanup step — no new features, no firmware changes.  
**Estimated effort:** 1 session.

---

### v7.5.3.1 — Define SensorEntity, MetricDef, MetricState structs

**Scope:** Add the new C++ struct definitions alongside the existing `SensorSlot`. Do not replace `SensorSlot` yet — both models coexist in this step.

**Files modified:**
- `dashboard/sensor_history_multi.h` — add `MetricDef`, `MetricState`, `SensorEntity` struct definitions after existing `SensorSlot`
- `Docs/changelog.md` — v7.5.3.1 entry
- Version bump: ALL locations to `7.5.3.1`

**Implementation details:**

Add the following structs after the existing `SensorSlot` definition (approximately line 260 in `sensor_history_multi.h`). These are passive definitions — nothing references them yet.

```cpp
// ── Phase 3: Generalized sensor model (v7.5.3.1) ──────────────────────
// These structs coexist with SensorSlot during the migration.
// SensorSlot will be removed once SensorEntity is fully wired.

#define MAX_METRICS_PER_DEVICE 4

struct MetricDef {
  const char* key;         // "temp_c", "humidity_pct", "ping_ms"
  const char* label;       // "Temperature", "Humidity"
  const char* unit;        // "°C", "%", "ms"
  uint8_t class_id;        // 0=analog, 1=binary, 2=counter, 3=metadata
  bool history_enabled;    // whether this metric has a HistoryBuffer
};

struct MetricState {
  float current_value;     // latest value or NAN
  float accumulator;       // for rolling average
  int sample_count;        // samples since last average
  bool valid;              // whether current_value is trustworthy
  uint32_t last_update_epoch;
  HistoryBuffer* history;  // nullptr if history_enabled == false
};

struct SensorEntity {
  // Identity (from manifest)
  const char* id;
  const char* name;
  uint8_t category_id;        // 0=environmental, 1=system, 2=network
  const char* adapter;         // "thermopro_ble", "icmp_ping"

  // Metrics (generated static arrays)
  const MetricDef* metric_defs;
  MetricState metric_states[MAX_METRICS_PER_DEVICE];
  uint8_t metric_count;       // actual metrics for this device (≤ MAX)

  // Adapter-specific fields
  const char* mac;             // non-null only for BLE devices
  int8_t last_rssi;
  uint32_t last_seen_epoch;

  // Generic methods
  void add_sample(uint8_t metric_index, float value) {
    if (metric_index >= metric_count) return;
    auto& st = metric_states[metric_index];
    st.current_value = value;
    st.accumulator += value;
    st.sample_count++;
    st.valid = true;
    st.last_update_epoch = ::time(nullptr);
  }

  void compute_averages(uint32_t epoch) {
    for (uint8_t i = 0; i < metric_count; i++) {
      auto& st = metric_states[i];
      if (st.sample_count > 0 && st.history != nullptr) {
        float avg = st.accumulator / st.sample_count;
        st.history->push(epoch, avg);
      }
      st.accumulator = 0;
      st.sample_count = 0;
    }
  }

  void mark_seen(uint32_t epoch) {
    last_seen_epoch = epoch;
  }
};
```

**Critical notes:**
- Use `::time(nullptr)` not `time(nullptr)` in ESPHome context (per project rules)
- `HistoryBuffer*` uses the existing `HistoryBuffer` class — no changes to the ring buffer
- `MAX_METRICS_PER_DEVICE = 4` covers ThermoPro (temp + hum + battery + rssi) and ping (latency + success + uptime + loss)
- The structs compile but are not instantiated or referenced by any runtime code yet

**Acceptance criteria:**
- [ ] `MetricDef`, `MetricState`, `SensorEntity` structs compile without errors
- [ ] Existing `SensorSlot` is unchanged and still used by all runtime code
- [ ] All 73 Playwright tests pass (no behavior change)
- [ ] Version is `7.5.3.1` everywhere

**Risk:** Low. Passive struct definitions — no runtime impact.  
**Estimated effort:** 1 session.

**Device testing required:** YES — after this step, compile the firmware on the ESPHome LXC container to verify the new structs compile on the ESP-IDF toolchain:
```bash
# On the ESPHome LXC container:
cd /config
esphome config firmware/esp32-c3-multi-sensor.yaml   # parse check
esphome compile firmware/esp32-c3-multi-sensor.yaml   # full compile
```

---

### v7.5.3.2 — Generator produces SensorEntity arrays (dual output)

**Scope:** Extend `render_sensor_config.py` to generate `SensorEntity` arrays alongside the existing `SensorSlot` arrays. Both are present in `sensor_history_multi.h`. Runtime code still uses `SensorSlot`.

**Files modified:**
- `scripts/render_sensor_config.py` — add `render_entity_block()` that produces `SensorEntity` arrays
- `scripts/sensor_manifest_lib.py` — add helper functions for metric definition generation
- `dashboard/sensor_history_multi.h` — now contains both `SensorSlot sensors[]` and `SensorEntity devices[]` (generated)
- `Docs/changelog.md` — v7.5.3.2 entry
- Version bump: ALL locations to `7.5.3.2`

**Implementation details:**

The generator should produce a block like this for ThermoPro sensors:

```cpp
// ── Generated SensorEntity arrays (Phase 3) ──────────────────────────
// Generated by render_sensor_config.py from config/sensors.json
// COEXISTS with SensorSlot arrays during migration

static const MetricDef metrics_thermopro[] = {
  {"temp",  "Temperature", "\xC2\xB0""C", 0, true},
  {"hum",   "Humidity",    "%",            0, true},
  {"batt",  "Battery",     "%",            3, false},
  {"rssi",  "RSSI",        "dBm",          3, false}
};

static HistoryBuffer entity_hbuf_office_temp;
static HistoryBuffer entity_hbuf_office_hum;
static HistoryBuffer entity_hbuf_first_floor_temp;
static HistoryBuffer entity_hbuf_first_floor_hum;
static HistoryBuffer entity_hbuf_outside_temp;
static HistoryBuffer entity_hbuf_outside_hum;

static constexpr int NUM_DEVICES = 3;

static SensorEntity devices[NUM_DEVICES] = {
  {
    .id = "office", .name = "Office",
    .category_id = 0, .adapter = "thermopro_ble",
    .metric_defs = metrics_thermopro,
    .metric_states = {
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_office_temp},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_office_hum},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}
    },
    .metric_count = 4,
    .mac = "DB:06:2C:58:8A:59",
    .last_rssi = 0, .last_seen_epoch = 0
  },
  // ... similar for first_floor and outside
};
```

**Critical notes:**
- History buffer variable names must not collide with existing `SensorSlot` history buffers. Prefix with `entity_hbuf_` to avoid name conflicts.
- Use `NAN` (from `<cmath>`) for initial float values, not `0.0`
- The `metrics_thermopro` array is shared across all ThermoPro devices (they all have the same metrics)
- The degree symbol `°` must be encoded as `\xC2\xB0` in C++ string literals (UTF-8 bytes)

**Acceptance criteria:**
- [ ] `render_sensor_config.py --write` generates both `SensorSlot sensors[]` and `SensorEntity devices[]` in `sensor_history_multi.h`
- [ ] `render_sensor_config.py --check` passes
- [ ] Firmware compiles with both arrays present
- [ ] All 73 Playwright tests pass (no behavior change — `SensorEntity` is not used at runtime yet)
- [ ] Version is `7.5.3.2` everywhere

**Risk:** Medium. Generator changes must produce valid C++ that compiles on ESP-IDF. The dual-output approach mitigates risk — if `SensorEntity` arrays have issues, `SensorSlot` is still the active runtime model.  
**Estimated effort:** 2 sessions.

**Device testing required:** YES — compile on ESPHome LXC container after this step.

---

### v7.5.3.3 — Wire YAML lambdas to SensorEntity.add_sample()

**Scope:** Change the YAML BLE sensor lambdas from calling `sensors[i].add_temp(value)` / `sensors[i].add_hum(value)` to calling `devices[i].add_sample(0, value)` / `devices[i].add_sample(1, value)`. The `SensorSlot` arrays remain but are no longer updated by BLE callbacks.

**Files modified:**
- `scripts/render_sensor_config.py` — update YAML lambda generation to use `devices[i].add_sample()` instead of `sensors[i].add_temp()` / `sensors[i].add_hum()`
- `firmware/esp32-c3-multi-sensor.yaml` — regenerated with new lambda calls
- `dashboard/sensor_history_multi.h` — update `compute_and_format()` timer lambda to call `devices[i].compute_averages()` alongside existing `sensors[i].compute_and_format()`
- `Docs/changelog.md` — v7.5.3.3 entry
- Version bump: ALL locations to `7.5.3.3`

**Implementation details:**

Current YAML lambda pattern (for ThermoPro office sensor temperature):
```yaml
on_value:
  then:
    - lambda: |-
        sensors[0].add_temp(x);
```

New YAML lambda pattern:
```yaml
on_value:
  then:
    - lambda: |-
        devices[0].add_sample(0, x);
        devices[0].mark_seen(::time(nullptr));
```

Where:
- `devices[0]` is the SensorEntity for this sensor (index matches sensor order in manifest)
- `add_sample(0, x)` → metric index 0 = temperature
- `add_sample(1, x)` → metric index 1 = humidity
- `mark_seen()` updates `last_seen_epoch`

**Critical dual-write phase:** During this step, the lambda should update BOTH models:
```yaml
on_value:
  then:
    - lambda: |-
        sensors[0].add_temp(x);
        devices[0].add_sample(0, x);
        devices[0].mark_seen(::time(nullptr));
```

This dual-write ensures the existing dashboard polling (which reads from `SensorSlot`) continues to work while the new model accumulates data in parallel. The `SensorSlot` calls will be removed in a later step.

**YAML generation guardrails:**
- Use `apply_yaml_marker_block()` for all YAML replacements (per BUG-035/036)
- Never use `replace_marker_block()` for YAML
- Run `esphome config` after generation to validate

**Acceptance criteria:**
- [ ] YAML lambdas call both `sensors[i].add_temp/hum()` and `devices[i].add_sample()` (dual-write)
- [ ] `SensorEntity.compute_averages()` is called in the 15-minute averaging timer
- [ ] Firmware compiles and runs on real device
- [ ] Both `SensorSlot` and `SensorEntity` receive identical data
- [ ] All 73 Playwright tests pass
- [ ] Version is `7.5.3.3` everywhere

**Risk:** High. This is the first step where `SensorEntity` receives real data. Bugs here could cause silent data loss if the dual-write is incorrect.  
**Estimated effort:** 2 sessions.

**Device testing required:** YES — OTA flash and verify:
1. Both `SensorSlot` and `SensorEntity` history buffers contain data
2. Dashboard displays correct readings (still using `SensorSlot` data path)
3. No heap anomalies (check via `/api/status`)

---

### v7.5.3.4 — Add `/api/v2/live` endpoint from SensorEntity

**Scope:** Add the new `/api/v2/live` endpoint that reads current values from `SensorEntity.metric_states[]` instead of `SensorSlot`.

**Files modified:**
- `dashboard/sensor_history_multi.h` — add `handle_api_v2_live_()` method, add route to `canHandle()` and `handleRequest()`
- `scripts/preflight.sh` — add check for `/api/v2/live` route
- `Docs/changelog.md` — v7.5.3.4 entry
- Version bump: ALL locations to `7.5.3.4`

**Implementation details:**

The endpoint returns:
```json
{
  "timestamp": 1710264000,
  "devices": {
    "office": {
      "temp": 23.4,
      "hum": 45.2,
      "batt": 87,
      "rssi": -62,
      "last_seen": 1710263985
    },
    "first_floor": { ... },
    "outside": { ... }
  }
}
```

Implementation in `sensor_history_multi.h`:
```cpp
void handle_api_v2_live_(AsyncWebServerRequest *request) const {
  auto *resp = request->beginResponseStream("application/json");
  add_common_headers_(resp);
  resp->print("{\"timestamp\":");
  resp->print((unsigned long)::time(nullptr));
  resp->print(",\"devices\":{");
  for (int d = 0; d < NUM_DEVICES; d++) {
    if (d > 0) resp->print(",");
    resp->printf("\"%s\":{", devices[d].id);
    for (int m = 0; m < devices[d].metric_count; m++) {
      if (m > 0) resp->print(",");
      resp->printf("\"%s\":", devices[d].metric_defs[m].key);
      if (devices[d].metric_states[m].valid) {
        resp->printf("%.1f", devices[d].metric_states[m].current_value);
      } else {
        resp->print("null");
      }
    }
    resp->printf(",\"last_seen\":%lu", (unsigned long)devices[d].last_seen_epoch);
    resp->print("}");
  }
  resp->print("}}");
  request->send(resp);
}
```

**Acceptance criteria:**
- [ ] `GET /api/v2/live` returns current values from `SensorEntity.metric_states[]`
- [ ] All existing endpoints unchanged
- [ ] Preflight includes `/api/v2/live` route check
- [ ] Firmware compiles and runs
- [ ] All 73 Playwright tests pass
- [ ] Version is `7.5.3.4` everywhere

**Risk:** Low-Medium. New endpoint only, reads from `SensorEntity` which is already receiving data via dual-write.  
**Estimated effort:** 1 session.

**Device testing required:** YES — `curl http://192.168.120.189/api/v2/live` should return valid JSON with current sensor values.

---

### v7.5.3.5 — Add `/api/v2/history/{device}/{metric}` endpoint

**Scope:** Add the per-device per-metric history endpoint that reads from `SensorEntity` history buffers.

**Files modified:**
- `dashboard/sensor_history_multi.h` — add `handle_api_v2_history_()` method, add route
- `scripts/preflight.sh` — add route check
- `Docs/changelog.md` — v7.5.3.5 entry
- Version bump: ALL locations to `7.5.3.5`

**Implementation details:**

The endpoint returns the same CSV format as existing `/history/{id}/temp`:
```
epoch,value
1710260000,23.4
1710263600,23.2
...
```

Route matching: `GET /api/v2/history/{device_id}/{metric_key}`

Implementation reads from `SensorEntity.metric_states[metric_index].history` ring buffer, producing the same `epoch,value\n` format the dashboard already parses.

For ThermoPro sensors, the response from `/api/v2/history/office/temp` should be byte-identical to `/history/office/temp` since both read from equivalent history buffers (during dual-write, both `SensorSlot.temp_history` and `SensorEntity.metric_states[0].history` accumulate the same averages).

**Acceptance criteria:**
- [ ] `GET /api/v2/history/office/temp` returns same data as `GET /history/office/temp`
- [ ] `GET /api/v2/history/office/hum` returns same data as `GET /history/office/hum`
- [ ] 404 for non-existent device or metric
- [ ] Legacy endpoints still work unchanged
- [ ] Version is `7.5.3.5` everywhere

**Risk:** Low-Medium. Reads from the same HistoryBuffer ring buffer.  
**Estimated effort:** 1 session.

**Device testing required:** YES — verify both endpoints return identical data:
```bash
diff <(curl -s http://192.168.120.189/history/office/temp) <(curl -s http://192.168.120.189/api/v2/history/office/temp)
```

---

### v7.5.3.6 — Remove SensorSlot, switch all paths to SensorEntity

**Scope:** Remove the dual-write. `SensorSlot` arrays are deleted. All runtime code uses `SensorEntity`. Flash persistence shims bridge `SensorEntity` to the existing `SegmentSnapshot` format.

**Files modified:**
- `dashboard/sensor_history_multi.h` — remove `SensorSlot` struct and `sensors[]` array; update all API handlers to read from `devices[]`; persistence shims for NVS read/write
- `scripts/render_sensor_config.py` — stop generating `SensorSlot` arrays, only generate `SensorEntity` arrays
- `firmware/esp32-c3-multi-sensor.yaml` — remove `sensors[i].add_temp/hum()` calls from lambdas
- `dashboard/dashboard.js` — no changes (already reads from manifest-driven endpoints)
- `Docs/changelog.md` — v7.5.3.6 entry
- Version bump: ALL locations to `7.5.3.6`

**Implementation details — persistence shims:**

The existing `SegmentSnapshot` stores `float temp[NUM_SENSORS][POINTS_PER_SEGMENT]` and `float hum[NUM_SENSORS][POINTS_PER_SEGMENT]`. This format MUST remain unchanged (per architecture plan Section 10.1: "For v7.5–v7.6, do not change this").

The persistence shim bridges `SensorEntity` metric_states to `SegmentSnapshot`:

```cpp
// Write: SensorEntity → SegmentSnapshot
void write_segment_from_entities(SegmentSnapshot& snap, int segment_index) {
  for (int d = 0; d < NUM_DEVICES; d++) {
    if (devices[d].category_id != 0) continue;  // only environmental
    // metric_states[0] is temp, metric_states[1] is hum (for ThermoPro)
    snap.temp[d][segment_index] = devices[d].metric_states[0].history->get(segment_index);
    snap.hum[d][segment_index]  = devices[d].metric_states[1].history->get(segment_index);
  }
}

// Read: SegmentSnapshot → SensorEntity (on boot restore)
void restore_entities_from_segment(const SegmentSnapshot& snap, int segment_index) {
  for (int d = 0; d < NUM_DEVICES; d++) {
    if (devices[d].category_id != 0) continue;
    if (devices[d].metric_states[0].history)
      devices[d].metric_states[0].history->set(segment_index, snap.temp[d][segment_index]);
    if (devices[d].metric_states[1].history)
      devices[d].metric_states[1].history->set(segment_index, snap.hum[d][segment_index]);
  }
}
```

**This is the highest-risk step in Phase 3.** The persistence layer is the most sensitive code in the codebase. The shim must:
- Map SensorEntity device index to SegmentSnapshot sensor index correctly
- Handle NAN values properly (existing NVS code uses sentinel values)
- Preserve NVS key naming scheme
- Maintain boot restore logic
- Keep import/export paths working

**Acceptance criteria:**
- [ ] `SensorSlot` struct and `sensors[]` array are removed
- [ ] All API endpoints read from `SensorEntity devices[]`
- [ ] Flash persistence writes from `SensorEntity` → `SegmentSnapshot`
- [ ] Boot restore reads `SegmentSnapshot` → `SensorEntity`
- [ ] CSV export produces identical output to pre-refactor
- [ ] CSV import (both multi-sensor and single-sensor merge) works correctly
- [ ] All 73 Playwright tests pass
- [ ] Free heap is within acceptable range (compare with pre-refactor baseline)
- [ ] Version is `7.5.3.6` everywhere

**Risk:** HIGH. This is the deepest firmware change. Flash persistence, boot restore, import/merge, export, and all API handlers must all work correctly. Device testing is mandatory.  
**Estimated effort:** 3–4 sessions.

**Device testing required:** YES — comprehensive:
```bash
# 1. Compile and OTA flash
esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml

# 2. Verify API responses
curl http://192.168.120.189/sensors.json          # v1 compat
curl http://192.168.120.189/api/manifest           # v2 manifest
curl http://192.168.120.189/api/status             # health
curl http://192.168.120.189/api/v2/live            # live values
curl http://192.168.120.189/history/office/temp    # legacy history
curl http://192.168.120.189/api/v2/history/office/temp  # v2 history

# 3. Verify dashboard renders correctly via browser
# 4. Verify CSV export produces valid files
# 5. Check free heap via /api/status — compare with pre-refactor baseline
# 6. Let it run for 30+ minutes and verify history accumulation
# 7. Reboot device and verify NVS restore loads history
```

---

### v7.5.3.7 — Full Playwright regression + Phase 3 closure

**Scope:** Final validation, comprehensive test coverage for the new model, documentation update, phase closure.

**Files modified:**
- `tests/browser/dashboard.spec.js` — add Group 15: Phase 3 closure tests
- `tests/mock-server/server.js` — add `/api/v2/live` and `/api/v2/history/{device}/{metric}` mock routes
- `Docs/changelog.md` — v7.5.3.7 entry with Phase 3 Complete callout
- `Docs/v7.5-v7.6-architecture-plan.md` — Phase 3 Status: COMPLETE
- `Docs/session-log-2026-XX-XX-v7.5.3.7.md` — session log (created)
- `Docs/bugs-and-lessons-learned.md` — new entries if bugs found
- Version bump: ALL locations to `7.5.3.7`

**New Playwright tests (Group 15):**
1. `/api/v2/live` returns valid JSON with all device IDs from manifest
2. `/api/v2/live` returns metric keys matching manifest metric definitions
3. `/api/v2/history/{device}/{metric}` returns CSV data
4. Legacy `/history/{id}/temp` still works (backward compat)
5. Legacy `/sensors.json` still works (backward compat)
6. Dashboard renders identically with new endpoints
7. All 73 existing tests still pass (regression gate)

**Acceptance criteria:**
- [ ] All new Phase 3 tests pass
- [ ] All existing tests pass (zero regression)
- [ ] Architecture plan updated with Phase 3 COMPLETE
- [ ] Changelog has Phase 3 Complete callout
- [ ] Session log created
- [ ] Version is `7.5.3.7` everywhere

**Risk:** Low. Validation and documentation only.  
**Estimated effort:** 1 session.

---

## Phase 1–2 Lessons Applied to Phase 3

| # | Lesson | How Applied in Phase 3 |
|---|---|---|
| 1 | BUG-035/036: YAML indentation | All YAML changes go through `apply_yaml_marker_block()`. Generator runs `esphome config` post-write. |
| 2 | BUG-034: regex escapes | Use lambda replacements in `re.sub()` for generated content. |
| 3 | BUG-039: Dashboard artifact regen | After editing `dashboard.js` or `dashboard.html`, always run `generate-header.sh`. |
| 4 | BUG-041: Version drift | Use `bump-version.sh` for all version bumps. |
| 5 | BUG-042: Minified version check | Preflight uses regex-based version check for `dashboard.h`. |
| 6 | LESSON-OPS-043: Source of truth | `dashboard.html` is the HTML source of truth. `dashboard.h` is generated. |
| 7 | LESSON-OPS-044: Dual validation | Device testing covers both custom dashboard and built-in ESPHome web page. |
| 8 | LESSON-OPS-045: YAML parse gate | `esphome config` preflight check runs on every PR. |
| 9 | Phase 2 execution pattern | Each step is a separate PR, tested independently, merged sequentially. |

---

## Version Bump Checklist (apply to every v7.5.3.x step)

Use `bash scripts/bump-version.sh <version>` which handles:
- `VERSION` file
- `scripts/render_sensor_config.py` VERSION constant
- `tests/fixtures/generate-fixtures.js` VERSION constant
- `dashboard/dashboard.html` App.version (**newly added in v7.5.3.0**)
- `python3 scripts/render_sensor_config.py --write` → regenerates dashboard.js, sensor_history_multi.h, YAML, gateway_manifest.h, fixtures
- `bash scripts/generate-header.sh` → regenerates dashboard.min.html, dashboard.h
- `bash scripts/preflight.sh` → verifies everything is in sync

---

## File Inventory

| File | Change type | Step |
|---|---|---|
| `scripts/bump-version.sh` | Fix: add dashboard.html update | 7.5.3.0 |
| `config/sensors.v2.example.json` | New: mixed-category v2 example | 7.5.3.0 |
| `dashboard/dashboard.js` | Boot flow sequencing fix | 7.5.3.0 |
| `dashboard/sensor_history_multi.h` | Major: struct definitions, new endpoints, SensorSlot removal, persistence shims | 7.5.3.1–7.5.3.6 |
| `scripts/render_sensor_config.py` | Major: SensorEntity array generation, SensorSlot removal | 7.5.3.2, 7.5.3.6 |
| `scripts/sensor_manifest_lib.py` | Minor: metric generation helpers | 7.5.3.2 |
| `firmware/esp32-c3-multi-sensor.yaml` | Moderate: lambda rewiring | 7.5.3.3, 7.5.3.6 |
| `scripts/preflight.sh` | Extend: v2 endpoint checks | 7.5.3.4–7.5.3.5 |
| `tests/mock-server/server.js` | Extend: v2 endpoint mocking | 7.5.3.7 |
| `tests/browser/dashboard.spec.js` | Extend: Phase 3 closure tests | 7.5.3.7 |
| `Docs/changelog.md` | Update per step | All |
| `Docs/v7.5-v7.6-architecture-plan.md` | Phase 3 status update | 7.5.3.7 |
| `Docs/bugs-and-lessons-learned.md` | New entries if bugs found | As needed |

---

_End of Phase 3 Implementation Plan._
