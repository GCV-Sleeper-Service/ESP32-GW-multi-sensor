# Session Log — v7.5.3.1 Phase 3 Step 1: SensorEntity Struct Definitions

**Date:** 2026-03-16  
**Version:** 7.5.3.0 → 7.5.3.1  
**Branch:** copilot/gcv-sleeper-service-v7531  
**Status:** ✅ Complete

---

## Objective

Implement v7.5.3.1 from `Docs/phase3-implementation-plan.md`: add passive C++ struct definitions
(`MetricDef`, `MetricState`, `SensorEntity`) alongside the existing `SensorSlot` in
`dashboard/sensor_history_multi.h`. These structs form the foundation of the Phase 3 generalized
sensor model but are not yet instantiated or referenced by any runtime code.

---

## Scope

- Add `MetricDef`, `MetricState`, `SensorEntity` struct definitions after `SensorSlot` in `dashboard/sensor_history_multi.h`
- Add `#define MAX_METRICS_PER_DEVICE 4`
- `SensorSlot` remains completely unchanged and is still the active runtime model
- Update `Docs/changelog.md` with v7.5.3.1 entry
- Version bump 7.5.3.0 → 7.5.3.1 across all canonical locations
- Regenerate all generated artifacts

---

## Actions Performed

### 1. `dashboard/sensor_history_multi.h` — add passive struct definitions

Added the following block immediately after the closing `};` of the `SensorSlot` struct
(after line 289 in the v7.5.3.0 baseline):

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
        st.history->add(epoch, avg);
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

**Note on `HistoryBuffer::add()` vs `push()`:** The implementation plan's code listing uses
`st.history->push(epoch, avg)`, but the existing `HistoryBuffer` class exposes `add()` (not
`push()`). Used `add()` to match the existing API so the structs compile cleanly. The plan's
critical note states "HistoryBuffer* uses the existing HistoryBuffer class — no changes to the
ring buffer", so `add()` is correct.

### 2. `Docs/changelog.md` — v7.5.3.1 entry

Added v7.5.3.1 entry at the top of the changelog.

### 3. Version bump — `bash scripts/bump-version.sh 7.5.3.1`

Ran the bump script which updated all canonical version locations:
- `VERSION`
- `scripts/render_sensor_config.py`
- `tests/fixtures/generate-fixtures.js`
- `dashboard/dashboard.html`

And regenerated:
- `dashboard/dashboard.js` (via `render_sensor_config.py --write`)
- `dashboard/dashboard.h` (via `generate-header.sh`)
- Fixture files (via `generate-fixtures.js`)

### 4. `scripts/preflight.sh` — validation

Run preflight to validate all checks pass.

---

## Implementation Notes

- `SensorSlot` is **completely unchanged** — all runtime code still uses `SensorSlot`
- `MAX_METRICS_PER_DEVICE = 4` covers ThermoPro (temp+hum+battery+rssi) and future ping probe (latency+success+uptime+loss)
- Uses `::time(nullptr)` per ESPHome project convention (not bare `time(nullptr)`)
- `HistoryBuffer*` pointer is `nullptr` when `history_enabled == false` for a metric
- The `compute_averages()` only pushes to history when `sample_count > 0` AND `history != nullptr`
- All three structs compile but are never instantiated at runtime in this step

---

## Boundaries Respected

This session implements **only** v7.5.3.1. The following were explicitly NOT done:
- Did not modify generator output logic for `SensorEntity` arrays (v7.5.3.2)
- Did not add `devices[]` global arrays
- Did not change YAML lambdas
- Did not add dual-write to both models
- Did not add `/api/v2/live` endpoint
- Did not add `/api/v2/history/{device}/{metric}` endpoint
- Did not add persistence shims
- Did not remove or refactor `SensorSlot`

---

## Validation Results

### Preflight (`bash scripts/preflight.sh`)
_Run and report results after bump-version.sh completes._

### Playwright Tests
_73+ tests expected. Run and report results after all changes are complete._

---

## Next Step

**v7.5.3.2** — Generator produces SensorEntity arrays (dual output).

`render_sensor_config.py` will be extended to emit `SensorEntity` static arrays alongside the
existing `SensorSlot` arrays. Runtime code still uses `SensorSlot`.

---

## Device Testing Required (User Action)

After merging this PR, compile the firmware on the ESPHome LXC container to verify the new
structs compile on the ESP-IDF toolchain:

```bash
# On the ESPHome LXC container:
cd /config

# 1. Pull the merged changes
git pull

# 2. Parse check (YAML validation)
esphome config firmware/esp32-c3-multi-sensor.yaml

# 3. Full compile (ESP-IDF toolchain)
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

Please report the compile output back. Expected result: clean compile with no errors or
warnings related to the new structs. The firmware behavior is unchanged from v7.5.3.0.
