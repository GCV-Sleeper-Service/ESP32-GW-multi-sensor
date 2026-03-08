# Architecture & Technical Reference

_Last updated: 2026-03-08 — v7.3.5.0_

This document covers the software architecture, data flows, retention model, configuration, and design decisions for the ESP32-C3 Multi-Sensor BLE Gateway.

---

## Software Stack

The project runs on [ESPHome](https://esphome.io/) using Espressif's native **ESP-IDF framework** (not Arduino) for better BLE + WiFi coexistence on the single-core ESP32-C3. ESPHome compiles the YAML configuration plus included C++ headers into a single firmware binary.

### Key Components

| Component | Purpose |
|-----------|---------|
| `esp32_ble_tracker` | Passive BLE scanning for sensor advertisements |
| `thermopro_ble` | Decodes ThermoPro TP357 BLE packet format |
| `ble_rssi` | Tracks per-sensor BLE signal strength |
| `web_server` (v3) | Built-in HTTP server with SSE and REST API |
| `sntp` | NTP time sync for wall-clock aligned averaging |
| `sensor_history_multi.h` | SensorSlot structs, RAM history, NVS persistence, HTTP endpoints |
| `dashboard.h` | Embedded HTML dashboard payload (generated from dashboard.html) |
| `api` | Kept for boot stability (required by ESPHome init sequence) |

### SensorSlot Architecture

Each physical sensor is encapsulated in a `SensorSlot` struct:

```
SensorSlot {
  identity:     id, name, mac
  accumulators: temp_sum, temp_count, hum_sum, hum_count
  battery:      batt_last, batt_str
  timing:       last_seen_epoch
  history:      temp_history (HistoryBuffer), hum_history (HistoryBuffer)
  output:       temp_avg_str, hum_avg_str, temp_valid, hum_valid
}
```

A static array of `SensorSlot[NUM_SENSORS]` replaces all per-sensor globals. Adding a sensor means one array entry and one YAML sensor block.

---

## Data Flow

### Live Readings (Real-Time Charts)

```
BLE broadcast → on_value lambda → NaN/range check → SensorSlot.add_temp/add_hum
                                        │
                                        ▼
                                publish to text_sensor
                                        │
                            ┌───────────┴───────────┐
                            ▼                       ▼
                     SSE "state" event       REST GET /text_sensor/...
                     (hosted/LAN mode)       (polling mode, every 15s)
                            │                       │
                            ▼                       ▼
                     handleState() ◄────────────────┘
                            │
                            ▼
                     pushPoint() → Chart.js update
                     updateDewPoint() → dew point recalc
                     updateRSSI() → signal bar update
```

### Averaged Readings (History Charts)

```
Every 15 min (cron) → SensorSlot.compute_and_format(epoch)
                            │
                    ┌───────┴───────┐
                    ▼               ▼
             HistoryBuffer    publish to text_sensor
             .add(epoch,avg)  (SSE/REST → live avg chart points)
                    │               │
                    ▼               ▼
          /history/{id}/temp  updateMinMax() recalculates from chart data
          /history/{id}/hum   (merged persisted history + current RAM day)
```

### History Loading (Page Load)

```
Browser opens /dashboard.html
  → 2s delay
  → fetch /sensors.json (or use built-in defaults)
  → for each sensor (sequential):
      fetch /history/{id}/temp → parseCompactHistory → tempAvgChart dataset
      fetch /history/{id}/hum  → parseCompactHistory → humAvgChart dataset
      updateMinMax() for 24h/7d/30d/45d min/max cards
  → charts updated, badge shows total loaded points
```

---

## Retention Model

The gateway uses a two-tier retention model:

**RAM layer** — The newest 24 hours of 15-minute averages are stored in fixed ring buffers (96 entries per series). Zero heap fragmentation, static BSS allocation.

**NVS persistence layer** — Every hour (at minute :10 by default), the gateway saves a 1-hour segment into a dedicated 512 KiB history partition. Up to 45 days of circular hourly segments are retained.

**Restore on boot** — On startup, the newest valid segments are loaded back into RAM so charts are immediately populated.

**Delivery** — `/history/*` endpoints stream persisted segments first and the current RAM day last, giving the dashboard one continuous history feed.

### Partition Layout

```
nvs         16 KiB    System NVS
otadata      8 KiB    OTA state
phy_init     4 KiB    PHY calibration
ota_0        1.69 MiB Application slot 0
ota_1        1.69 MiB Application slot 1
history    512 KiB    Dedicated history NVS partition
coredump    64 KiB    Core dump storage
```

### Memory Budget

All ring buffer storage uses static BSS allocation — no heap, no `malloc`, no fragmentation.

| Item | Size | Notes |
|------|------|-------|
| Ring buffer per series | 768 B | 96 entries × 8 bytes (epoch + float) |
| Per sensor (2 series) | 1,536 B | temp + humidity |
| 3 sensors total | 4,608 B | Live history RAM |
| SensorSlot overhead | ~240 B | Accumulators, format buffers |
| Measured free heap | ~84 KiB | Typical runtime value |
| RAM usage | ~15.8% | Of available 327 KiB |
| Flash usage | ~87.5% | Of available 1.69 MiB per OTA slot |

---

## Configuration

### Sensor MAC Addresses

Edit the sensor definitions in `dashboard/sensor_history_multi.h`:

```cpp
static SensorSlot sensors[NUM_SENSORS] = {
  { .id = "office",       .name = "Office",       .mac = "XX:XX:XX:XX:XX:XX" },
  { .id = "first_floor",  .name = "First Floor",  .mac = "YY:YY:YY:YY:YY:YY" },
  { .id = "outside",      .name = "Outside",      .mac = "ZZ:ZZ:ZZ:ZZ:ZZ:ZZ" },
};
```

Also update the corresponding `mac_address` entries in the YAML under `thermopro_ble` and `ble_rssi`.

### Finding Your Sensor MACs

Flash a temporary config with just the BLE tracker:

```yaml
esp32_ble_tracker:
  on_ble_advertise:
    then:
      - lambda: |-
          ESP_LOGI("ble", "Found: %s (name: %s)",
                   x.address_str().c_str(),
                   x.get_name().c_str());
```

Look for devices named `TP357` or similar in the logs.

### Secrets

Create `secrets/secrets.yaml` from the example:

```yaml
wifi_ssid: "YourNetworkName"
wifi_password: "YourPassword"
gateway_mgmt_username: "ESPadmin"
gateway_mgmt_password: "StrongPasswordHere"
```

For local compile, symlink into the firmware directory:

```bash
ln -s ../secrets/secrets.yaml firmware/secrets.yaml
```

### Changing Sensor Count

The current default is 3 sensors. To add a 4th or reduce to fewer:

1. Update `NUM_SENSORS` and the `sensors[]` array in `sensor_history_multi.h`
2. Add/remove the corresponding YAML sensor blocks (thermopro_ble, ble_rssi, text_sensor entries)
3. Regenerate the dashboard header: `./scripts/generate-header.sh`

---

## Remote Access via Cloudflare

The dashboard can be accessed over the internet through Cloudflare.

### Transport Behavior

| Access Path | Mode | Transport | Latency |
|-------------|------|-----------|---------|
| `http://<esp-ip>/dashboard.html` | HOSTED | SSE | ~100ms |
| `https://public-fqdn/dashboard.html` (tunnel) | HOSTED | SSE | ~100ms |
| Local file with HTTP fallback | SSE | SSE | ~100ms |
| Local file with HTTPS fallback | POLLING | REST 15s | Up to 15s |

**Note:** Cloudflare's SSE buffering can interfere with real-time updates. A separate REST-polling dashboard variant works around this. When accessed via HTTPS through Cloudflare, the dashboard automatically detects the need for polling mode.

### Cloudflared Tunnel Setup

The recommended approach uses a `cloudflared` tunnel, which requires no router configuration:

1. Install `cloudflared` on a machine with LAN access to the ESP
2. Create a tunnel: `cloudflared tunnel create esp-gateway`
3. Configure the tunnel to route traffic to `http://<esp-ip>:80`
4. Add a DNS CNAME record in Cloudflare pointing to the tunnel

---

## Dashboard Features

The embedded dashboard (`/dashboard.html`) provides:

- Dark/light mode toggle with full chart redraw on switch
- Collapsible sections for all cards
- Device info card with ESP32 specs and GPIO pinout diagram
- Per-sensor cards: live temp (°C/°F), humidity, 15m averages, dew point, comfort estimate, battery bar, RSSI signal bars, and 24h/7d/30d/45d min/max selectors
- Telemetry chart: free heap (left axis) and WiFi signal dBm (right axis)
- Real-time temperature and humidity charts (at BLE broadcast rate)
- 15-minute average charts with up to 45 days of merged history
- Dual-axis temperature: left °C, right °F, blue 0°C/32°F freezing reference
- CSV export per sensor and "Export All" (serialized to avoid request bursts)
- History badge with loaded point count and refresh button
- ESP management section: reboot and delete data (Basic auth protected)
- Documentation links section
- History storage statistics panel
- Debug event log (collapsible)

### Browser-Side Computations

Dew point, min/max calculations, comfort estimates, and CSV assembly are all computed in JavaScript. This is deliberate — zero cost on the ESP32, and the browser has plenty of capacity.

---

## Design Decisions & Limitations

**Why SensorSlot structs instead of globals** — The single-sensor version used 30+ separate global variables. With multiple sensors, `SensorSlot` encapsulates everything and the YAML lambdas just index into the array.

**Why embedded dashboard** — Earlier versions required managing a separate HTML file and configuring `ESP_HOST`. The embedded approach means one flash carries both logic and UI. The HTML lives in flash/rodata (not heap).

**Why ESP-IDF instead of Arduino** — Better BLE + WiFi coexistence and lower memory overhead on the single-core C3.

**Why 13 LWIP sockets** — Required by ESPHome's init sequence for WiFi + BLE/NimBLE + mDNS + SNTP + web server + API + OTA simultaneously.

**Why the API component is required** — Even without Home Assistant, removing `api:` causes boot failures. The ESPHome init sequence depends on it.

**Limited concurrent sessions** — The ESP32-C3 web server has limited sockets. Recommended maximum is 3 concurrent dashboard sessions.

**Why snprintf was split for /api/status** — A 64-byte buffer truncated the JSON output. The fix splits formatting into multiple print calls. This pattern should be followed for any future endpoint additions.

---

## Troubleshooting

**Dashboard shows "connecting..." but never connects** — Verify the ESP is powered and reachable (ping its IP). Check for firewall blocks on port 80. If using Cloudflare, verify the tunnel is running.

**Sensor cards show "—"** — Sensor may be out of range (typical: 5–10m through walls). Verify MAC address matches. Check battery. Look at RSSI bars.

**Charts are empty** — History charts need at least one 15-minute averaging cycle. Check the debug log panel for errors. Verify `/sensors.json` returns valid JSON.

**Min/Max shows "no data"** — Normal shortly after boot. Needs at least one 15-minute average point to populate.

**Export All fails** — Ensure you're on v7.3.4.2+ which serializes export requests to avoid overwhelming the ESP.
