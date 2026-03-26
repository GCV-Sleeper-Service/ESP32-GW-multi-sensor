# Data Ingest Setup Guide

## 1. Overview

The data ingest endpoint allows external systems (NAS, server, mini PC, Raspberry Pi)
to push system metrics into the ESP32 gateway so they appear in the dashboard system card.

Ingest path:

- `POST /api/ingest/{device_id}/{metric_key}?val={float}`

Typical uses:

- NAS health reporting (CPU, RAM, disk, uptime)
- Host health metrics from always-on Linux/macOS systems
- External scripts publishing operational metrics to the gateway

## 2. Prerequisites

Before using ingest, confirm:

1. Gateway firmware is `v7.5.6.0` or newer.
2. A `system` device exists in `config/sensors.json` with adapter `external_push`.
3. Generated artifacts were refreshed (full regeneration sequence):
   - `python3 scripts/render_sensor_config.py --write`
   - `node tests/fixtures/generate-fixtures.js`
   - `bash scripts/generate-header.sh`
   - `python3 scripts/render_sensor_config.py --check`
   - `grep -q "free_heap" tests/fixtures/api-status.json`
4. Gateway is reachable on LAN (`http://<gateway-ip>`).

## 3. Adding a System Device

If no system device exists yet, add one to `config/sensors.json`:

- `category`: `system`
- `adapter`: `external_push`
- measurements: `cpu_pct`, `ram_pct`, `disk_pct`, `uptime_hrs`

Then regenerate and flash:

```bash
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
```

Compile/flash as normal for your board profile.

## 4. Using the Bash Exporter (Linux)

File: `scripts/exporters/system-metrics-exporter.sh`

Run once:

```bash
bash scripts/exporters/system-metrics-exporter.sh http://192.168.120.189 nas01
```

Cron every minute:

```bash
* * * * * /path/to/scripts/exporters/system-metrics-exporter.sh http://192.168.120.189 nas01
```

Notes:

- Script is intentionally cron-friendly.
- Failures are non-fatal for looped metric pushes.
- CPU metric falls back to `0` when `top` output is incompatible.

## 5. Using the Python Exporter (cross-platform)

File: `scripts/exporters/system-metrics-exporter.py`

Run once:

```bash
python3 scripts/exporters/system-metrics-exporter.py --gateway http://192.168.120.189 --device nas01
```

Continuous mode:

```bash
python3 scripts/exporters/system-metrics-exporter.py --gateway http://192.168.120.189 --device nas01 --interval 60
```

Design constraints:

- Standard library only (no pip dependencies).
- Linux/macOS metric collection paths included.
- Windows runs, but unsupported metrics safely return `0.0`.

## 6. Custom Exporters (API Contract)

### Endpoint

- `POST /api/ingest/{device_id}/{metric_key}?val={float}`

### Success response

- HTTP `200`
- Body: `{"ok":true}`

### Error response format (exact firmware format)

All ingest errors are returned by `send_json_error_()` in
`dashboard/sensor_history_multi.h` as:

- Body: `{"ok":false,"message":"<message>","status":<code>}`

Common ingest errors:

- `405` — method not POST (`"Method not allowed"`)
- `400` — missing metric key (`"Missing metric key"`)
- `400` — empty device ID (`"Empty device ID"`)
- `400` — empty metric key (`"Empty metric key"`)
- `404` — unknown device (`"Unknown device"`)
- `404` — unknown metric (`"Unknown metric"`)
- `400` — missing `val` (`"Missing val parameter"`)
- `400` — invalid `val` (`"Invalid value"`)

### Example

```bash
curl -X POST "http://192.168.120.189/api/ingest/nas01/cpu_pct?val=42.7"
```

## 7. Monitoring Ingested Values

Use live API to confirm ingestion:

```bash
curl -s "http://192.168.120.189/api/v2/live"
```

Then verify dashboard:

- Open `http://<gateway-ip>/`
- Locate system card for your device (e.g., `nas01` / NAS Health)
- Confirm CPU/RAM/Disk bars and uptime update from pushed values

## 8. Troubleshooting

### Unknown device

- Cause: `device_id` does not match manifest.
- Fix: use exact ID from `/api/manifest`.

### Unknown metric

- Cause: key mismatch (`cpu_pct` vs another name).
- Fix: use measurement keys defined for that system device.

### Missing/invalid val

- Cause: `val` absent or not parseable as finite float.
- Fix: pass `?val=<number>` (example: `?val=55.1`).

### Gateway unreachable

- Cause: network path/firewall/incorrect URL.
- Fix: `curl http://<gateway-ip>/api/status` from exporter host.

### Dashboard card not updating

- Cause: no successful pushes yet or wrong device key names.
- Fix: verify with `/api/v2/live`, then inspect exporter output.

## 9. Security

In `v7.5.6.x`, ingest is intentionally unauthenticated.

Implications:

- Any client on the same network can POST to `/api/ingest`.
- Use trusted LAN segments / VLAN isolation.
- Do not expose ingest endpoints directly to public internet.

Authentication hardening is out of scope for this phase.
