# Configuring Sensor Count (1–4)

_Last updated: 2026-03-12 — v7.4.4.0_

This document is the **authoritative, step-by-step procedure** for changing the ESP32 gateway from the default 3-sensor build to 1, 2, or 4 sensors. Follow every step in order. Do not skip the preflight and erase steps.

---

## ⚠️ History compatibility warning

Sensor count is a **compile-time constant** that determines the binary layout of the persisted NVS history segments. A firmware compiled for 2 sensors and a firmware compiled for 4 sensors do **not** share the same on-flash data structure.

When you change `NUM_SENSORS` and flash the new firmware:

1. **The new firmware will detect the mismatch** (`meta.num_sensors != NUM_SENSORS`) and refuse to load the old history — you will see no prior data but no corruption either.
2. **You must explicitly delete the old history** using the dashboard or the API before trusting a clean baseline.

Do not assume old history is silently preserved across count changes.

---

## Supported range

| Property | Value |
|----------|-------|
| Compile-time sensor count | **1 to 4** |
| Repository default | **3** |
| Runtime sensor-count change | ❌ Not supported |
| Automatic history migration | ❌ Not supported |

---

## Files that must stay aligned

Every time you change sensor count, keep these files consistent with each other:

| File | What to change |
|------|---------------|
| `dashboard/sensor_history_multi.h` | `NUM_SENSORS` constant + `sensors[]` initializer list |
| `firmware/esp32-c3-multi-sensor.yaml` | `thermopro_ble` blocks, `ble_rssi` blocks, all per-sensor text-sensor IDs |
| `tests/fixtures/sensors.json` | Sensor manifest (must match active count) |
| `dashboard/dashboard.js` | `DEFAULT_SENSOR_META` fallback (must match active count) |

Preflight validates all of these before compile.

---

## Step-by-step procedure

### Step 1 — Decide target count

Pick exactly one of: **1**, **2**, **3**, **4**

### Step 2 — Edit `dashboard/sensor_history_multi.h`

Change `NUM_SENSORS` and the `sensors[]` initializer list to match your target count.

**1 sensor example:**
```cpp
static constexpr int NUM_SENSORS = 1;

static SensorSlot sensors[NUM_SENSORS] = {
  { .id = "office", .name = "Office", .mac = "DB:06:2C:58:8A:59" },
};
```

**2 sensor example:**
```cpp
static constexpr int NUM_SENSORS = 2;

static SensorSlot sensors[NUM_SENSORS] = {
  { .id = "office",      .name = "Office",      .mac = "DB:06:2C:58:8A:59" },
  { .id = "first_floor", .name = "First Floor", .mac = "D5:D8:4C:25:06:49" },
};
```

**3 sensor example (default):**
```cpp
static constexpr int NUM_SENSORS = 3;

static SensorSlot sensors[NUM_SENSORS] = {
  { .id = "office",      .name = "Office",      .mac = "DB:06:2C:58:8A:59" },
  { .id = "first_floor", .name = "First Floor", .mac = "D5:D8:4C:25:06:49" },
  { .id = "outside",     .name = "Outside",     .mac = "DF:EB:DE:19:11:6C" },
};
```

**4 sensor example:**
```cpp
static constexpr int NUM_SENSORS = 4;

static SensorSlot sensors[NUM_SENSORS] = {
  { .id = "office",      .name = "Office",      .mac = "DB:06:2C:58:8A:59" },
  { .id = "first_floor", .name = "First Floor", .mac = "D5:D8:4C:25:06:49" },
  { .id = "outside",     .name = "Outside",     .mac = "DF:EB:DE:19:11:6C" },
  { .id = "garage",      .name = "Garage",      .mac = "XX:XX:XX:XX:XX:XX" },
};
```

Replace MAC addresses with the actual addresses from your physical sensors.

### Step 3 — Edit `firmware/esp32-c3-multi-sensor.yaml`

For each sensor you need matching YAML blocks for:

- One `platform: thermopro_ble` block (BLE receiver with temp/hum/battery callbacks)
- One `platform: ble_rssi` block (RSSI tracker)
- Text sensor IDs: `cur_temp_<id>`, `cur_hum_<id>`, `avg_temp_<id>`, `avg_hum_<id>`, `battery_<id>`, `last_seen_<id>`
- Lambda references: `sensors[N].add_temp(x)`, `sensors[N].add_hum(x)`, `sensors[N].set_battery(x)`, `sensors[N].mark_seen(now.timestamp)`
- `15-minute averaging` cron lambda: one `sensors[N].compute_and_format(epoch)` call per sensor
- RSSI publish: `sensors[N].last_rssi = x`

Copy an existing sensor block and update every occurrence of the sensor index, ID, name, and MAC address.

### Step 4 — Edit `dashboard/dashboard.js` DEFAULT_SENSOR_META

Update the fallback manifest at the top of `dashboard.js` to match your sensor count and IDs:

```javascript
var DEFAULT_SENSOR_META = [
  { id: 'office',      name: 'Office' },
  { id: 'first_floor', name: 'First Floor' },
  // ... one entry per sensor
];
```

This fallback is only used if `/sensors.json` fails to load. It must stay in sync with `NUM_SENSORS`.

### Step 5 — Update baseline test manifest

Edit `tests/fixtures/sensors.json` to match your active count:

```json
[
  { "id": "office",      "name": "Office" },
  { "id": "first_floor", "name": "First Floor" }
]
```

Or run the generator with `--overwrite-baseline`:

```bash
node tests/fixtures/generate-fixtures.js --count 2 --overwrite-baseline
```

### Step 6 — Generate fixture variants

Always regenerate variants after any sensor list change:

```bash
node tests/fixtures/generate-fixtures.js
```

This writes fixture sets under `tests/fixtures/variants/1sensor/`, `.../2sensor/`, `.../3sensor/`, `.../4sensor/`.

### Step 7 — Run preflight

```bash
bash ./scripts/preflight.sh
```

Preflight will fail with a clear message if any count is mismatched. Fix reported mismatches before proceeding.

### Step 8 — Compile

```bash
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

### Step 9 — Flash

```bash
esphome run firmware/esp32-c3-multi-sensor.yaml
```

### Step 10 — Delete retained history ⚠️

**This step is mandatory.** Old history segments from a different count are rejected by the firmware, but they still occupy flash until explicitly deleted.

Via dashboard: Management → Delete Data

Via curl:
```bash
curl -u "<username>:<password>" -X POST http://<esp-ip>/api/delete-data
```

### Step 11 — Validate

Check all of the following:

- Dashboard shows exactly the expected number of sensor cards
- `/api/status` reports `"sensor_count": N`
- No JS console errors
- Per-sensor export buttons match the count
- History accumulates normally after erase

---

## Browser test validation commands

Run these locally to validate all fixture variants without a live device:

```bash
npm ci
npx playwright install --with-deps chromium
node tests/fixtures/generate-fixtures.js

# Full baseline suite (3sensor, 28 tests)
npx playwright test

# Smoke suite per variant
FIXTURE_SET=1sensor npx playwright test tests/browser/sensor-count.spec.js
FIXTURE_SET=2sensor npx playwright test tests/browser/sensor-count.spec.js
FIXTURE_SET=4sensor npx playwright test tests/browser/sensor-count.spec.js
```

---

## Notes

- Keep `main` at the stable 3-sensor default. Use a feature branch when experimenting with counts.
- The repository does not support runtime count changes — it is strictly a compile-time setting.
- Version bump to the next `v7.4.x.y` should happen **after** compile + preflight + browser tests + device validation are complete.
