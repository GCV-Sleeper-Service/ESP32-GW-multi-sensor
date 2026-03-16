# Session Log — v7.5.3.3 Phase 3 Step 3: Wire YAML Lambdas to SensorEntity (Dual-Write)

**Date:** 2026-03-16  
**Version:** 7.5.3.2 → 7.5.3.3  
**Branch:** copilot/update-yaml-lambda-generation  
**Status:** ✅ Complete

---

## Objective

Implement v7.5.3.3 from `Docs/phase3-implementation-plan.md`: wire the YAML BLE sensor
lambdas to call `SensorEntity` methods in parallel with the existing `SensorSlot` calls
(dual-write phase). Also call `compute_averages()` in the 15-minute averaging timer.

---

## Scope

- Update `thermopro_block()` in `scripts/render_sensor_config.py` — add dual-write calls to temperature and humidity `on_value` lambdas
- Update `avg_lines()` in `scripts/render_sensor_config.py` — add `devices[i].compute_averages(epoch)` to the averaging timer
- Version bump 7.5.3.2 → 7.5.3.3 across all canonical locations
- Regenerate all artifacts via `bash scripts/bump-version.sh 7.5.3.3`
- Update `Docs/changelog.md` with v7.5.3.3 entry
- Create this session log

---

## Actions Performed

### 1. `scripts/render_sensor_config.py` — dual-write lambda generation

**Updated `thermopro_block()` — temperature lambda:**

```python
# Before
             sensors[{idx}].add_temp(x);
             auto now = id(sntp_time).now();

# After
             sensors[{idx}].add_temp(x);
             devices[{idx}].add_sample(0, x);
             devices[{idx}].mark_seen(::time(nullptr));
             auto now = id(sntp_time).now();
```

**Updated `thermopro_block()` — humidity lambda:**

```python
# Before
             sensors[{idx}].add_hum(x);
             auto now = id(sntp_time).now();

# After
             sensors[{idx}].add_hum(x);
             devices[{idx}].add_sample(1, x);
             devices[{idx}].mark_seen(::time(nullptr));
             auto now = id(sntp_time).now();
```

**Updated `avg_lines()` — averaging timer:**

```python
# Before
        f" sensors[{idx}].compute_and_format(epoch);",

# After
        f" sensors[{idx}].compute_and_format(epoch);",
        f" devices[{idx}].compute_averages(epoch);",
```

### 2. Version bump — `bash scripts/bump-version.sh 7.5.3.3`

Ran the bump script which updated all canonical version locations:
- `VERSION` → `7.5.3.3`
- `scripts/render_sensor_config.py` VERSION constant → `"7.5.3.3"`
- `tests/fixtures/generate-fixtures.js` VERSION constant → `"v7.5.3.3"`
- `dashboard/dashboard.html` App.version → `'v7.5.3.3'`

And regenerated all artifacts:
- `firmware/esp32-c3-multi-sensor.yaml` — YAML lambdas now include dual-write calls
- `dashboard/sensor_history_multi.h` — version comment updated (no structural changes needed)
- `dashboard/dashboard.js` — version string updated
- `tests/fixtures/manifest.json` — version updated
- `tests/fixtures/api-status.json` — version updated
- `src/gateway_manifest.h` — version updated
- `dashboard/dashboard.h` — re-embedded (via `generate-header.sh`)

### 3. `Docs/changelog.md` — v7.5.3.3 entry

Added v7.5.3.3 entry at the top of the changelog.

---

## Generated YAML Output (representative, Office sensor)

### Temperature lambda:
```yaml
on_value:
  then:
    - lambda: |-
        sensors[0].add_temp(x);
        devices[0].add_sample(0, x);
        devices[0].mark_seen(::time(nullptr));
        auto now = id(sntp_time).now();
        if (now.is_valid()) {
          sensors[0].mark_seen(now.timestamp);
          char seen_buf[20];
          snprintf(seen_buf, sizeof(seen_buf), "%02d:%02d:%02d %02d/%02d", now.hour, now.minute, now.second, now.month, now.day_of_month);
          id(last_seen_office).publish_state(seen_buf);
        }
        if (!isnan(x) && x > -50.0f && x < 80.0f) {
          float f = x * 9.0f / 5.0f + 32.0f;
          char buf[32];
          snprintf(buf, sizeof(buf), "%.1f \xC2\xB0" "C / %.1f \xC2\xB0" "F", x, f);
          id(cur_temp_office).publish_state(buf);
        }
```

### Averaging timer (per sensor):
```c
sensors[0].compute_and_format(epoch);
devices[0].compute_averages(epoch);
id(avg_temp_office).publish_state(sensors[0].temp_avg_str);
id(avg_hum_office).publish_state(sensors[0].hum_avg_str);
if (sensors[0].batt_last >= 0) id(battery_office).publish_state(sensors[0].batt_str);
```

---

## Implementation Notes

- **Dual-write design**: Both `SensorSlot` and `SensorEntity` receive identical data. `SensorSlot` calls are never removed in this step.
- **`::time(nullptr)`** used (not `time(nullptr)`) per ESPHome convention and existing `SensorEntity.add_sample()` implementation.
- **`apply_yaml_marker_block()`** used for all YAML marker regions per BUG-035/036 guardrails. `replace_marker_block()` is not used for YAML.
- **`mark_seen()` called immediately** with `::time(nullptr)` for both temp and hum lambdas. The existing `sensors[i].mark_seen(now.timestamp)` call inside the `if (now.is_valid())` block is preserved.
- **Metric indices**: 0 = temperature, 1 = humidity (matches `metrics_thermopro[]` definition order in `sensor_history_multi.h`).
- **Battery lambda**: Not modified — no `devices[i].add_sample()` call for battery in this step (battery uses metric index 2, which has `history = nullptr`; deferred to a later step).

---

## Boundaries Respected

This session implements **only** v7.5.3.3. The following were explicitly NOT done:
- Did not remove `SensorSlot` calls (preserved for dual-write)
- Did not add `/api/v2/live` endpoint (v7.5.3.4)
- Did not add `/api/v2/history/{device}/{metric}` endpoint (later step)
- Did not add persistence shims (later step)
- Did not add battery dual-write (deferred)

---

## Validation Results

### `render_sensor_config.py --check`
```
render_sensor_config: PASS
```

### Preflight (`bash scripts/preflight.sh`, run via bump-version.sh)
All checks passed:
- version_file_present: PASS
- dashboard_js_version_matches: PASS
- dashboard_h_version_matches: PASS
- firmware_version_matches: PASS
- history_header_version_matches: PASS
- history_handler_has_api_manifest_route: PASS
- dashboard_prefers_api_manifest: PASS
- dashboard_legacy_manifest_fallback: PASS
- mock_server_serves_api_manifest: PASS
- fixture_manifest_schema_v2: PASS
- fixture_manifest_sensor_count: PASS
- browser_spec_present: PASS
- no_old_dashboard_version: PASS
- no_old_firmware_version: PASS
- render_sensor_config_py_version_sync: PASS
- fixture_generator_version_sync: PASS
- gateway_manifest_h_included: PASS
- gateway_manifest_json_used: PASS
- gateway_manifest_yaml_includes: PASS
- Manifest v2 schema validation: PASS
- render_sensor_config: PASS
- fixture_baseline_manifest_regenerated: PASS
- esphome not available in sandbox (skipped YAML parse check)

### Playwright Tests
**73 passed (43.9s)** — all tests passing, no regressions

---

## Next Step

**v7.5.3.4** — Add `/api/v2/live` endpoint from SensorEntity.

Add the new `/api/v2/live` endpoint that reads current values from
`SensorEntity.metric_states[]` instead of `SensorSlot`.

---

## Device Testing Required (User Action)

After merging this PR, compile and flash the firmware on the ESPHome LXC container:

```bash
# On the ESPHome LXC container:
cd /config

# 1. Pull the merged changes
git pull

# 2. Parse check (YAML validation)
esphome config firmware/esp32-c3-multi-sensor.yaml

# 3. Full compile (ESP-IDF toolchain)
esphome compile firmware/esp32-c3-multi-sensor.yaml

# 4. OTA flash
esphome run firmware/esp32-c3-multi-sensor.yaml
```

After flashing, verify:

1. Via `/api/v2/live` — confirm BOTH `SensorSlot` AND `SensorEntity` receive data (note: `/api/v2/live` endpoint is added in v7.5.3.4; for this step, check logs or `/api/status`)
2. Via `/api/status` — check heap usage and record a baseline
3. Let the device run for 30+ minutes — verify history accumulation in `SensorEntity` history buffers (confirm via future `/api/v2/history` endpoint)
4. Report all results back

Expected result: clean compile with no errors. `devices[i].add_sample()` and
`devices[i].compute_averages()` calls execute alongside existing `SensorSlot` calls
with no crash or heap anomaly.
