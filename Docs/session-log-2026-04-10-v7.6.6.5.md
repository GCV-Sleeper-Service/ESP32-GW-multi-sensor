# Session Log — v7.6.6.5: NVS Persistence Device Integration Test

_Date: 2026-04-10_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_PR: #160_
_Status: COMPLETE — all acceptance criteria met at head commit `1840915`_

---

## Summary

Phase Y v7.6.6.5 records the passing device integration test of v7.6.6.4 firmware on physical
ESP32-C3 hardware, confirming NVS persistence, history serving, live data, and reboot durability.
No firmware source code was modified — this is a version-bump-only release that records test
evidence, updates the changelog, and regenerates all version-stamped artifacts.

---

## Commit Timeline

| SHA | Author | Message |
|-----|--------|---------|
| `96abb3e` | copilot-swe-agent | v7.6.6.5: device integration test PASS — version bump, changelog, artifacts regenerated |
| `1840915` | copilot-swe-agent | docs: clarify v7.6.6.5 changelog — version bump records v7.6.6.4 device test evidence |

---

## Device Test Evidence

**Hardware:** ESP32-C3 (MAC `ac:a7:04:ba:cb:18`, rev0.4, 4MB flash)
**Build:** ESPHome 2026.2.1 / ESP-IDF 5.5.2
**Firmware tested:** v7.6.6.4

### Serial Boot Log (Checkpoint B)

Key lines extracted from serial monitor:

```
Restored 24 persisted hourly segment(s) into RAM
[history] 5 devices registered
setup() finished successfully!
Persisted segment slot 895 (1775839500..1775844000), segments=896, size=232 bytes
```

After `POST /api/reboot`:
```
Restored 24 persisted hourly segment(s) into RAM
```

All expected: NVS restore on first boot, 5 devices registered, clean setup, hourly persist
observed, and segment count preserved across reboot.

---

### HTTP API Test Results

**Test 1 — Storage stats (`GET /api/storage-stats`)**
```json
{
  "ok": true,
  "history": {
    "valid_segments": 895,
    "capacity_segments": 1080,
    "namespace_initialized": true
  }
}
```
✅ PASS — 895 valid segments, NVS healthy

---

**Test 2 — Manifest (`GET /api/manifest`)**
```json
{
  "ok": true,
  "schema_version": 2,
  "version": "v7.6.6.4",
  "sensor_count": 5,
  "metrics": [ ... 8 metrics ... ],
  "sensors": [ ... 5 sensors ... ]
}
```
✅ PASS — schema_version 2, 5 sensors, 8 metrics correct

---

**Test 3 — History stream (`GET /api/v2/history/outside/temp`)**
```
1775757600,
1775758500,
1775759400,
...
```
✅ PASS — CSV stream returns persisted epoch timestamps at 900s intervals

---

**Test 4 — Live endpoint (`GET /api/v2/live`)**
```json
{
  "timestamp": 1775845120.0,
  "devices": {
    "office": { "temp": 21.7, "hum": 30.0, "last_seen": 1775845111 },
    "first_floor": { "temp": 16.8, "hum": 40.0, "last_seen": 1775845081 },
    "outside": { "temp": 15.1, "hum": 44.0, "last_seen": 1775845097 },
    "wan_ping": { "ping_ms": 63.0, "success_pct": 100.0, "last_seen": 1775845091 },
    "nas01": { "cpu_pct": null, "ram_pct": null, "disk_pct": null, "last_seen": 0 }
  }
}
```
✅ PASS — 3 env sensors + wan_ping live; nas01 null (expected — no push source)

---

**Test 5 — Status (`GET /api/status`)**
```json
{
  "ok": true,
  "version": "v7.6.6.4",
  "uptime_seconds": 2225,
  "sensor_count": 5,
  "free_heap": 57740
}
```
✅ PASS — uptime 2225s, all 3 env sensors `temp_valid`/`hum_valid` true, free_heap 57740 bytes

---

**Test 6 — Reboot persistence**

Pre-reboot stats snapshot taken, then `POST /api/reboot` triggered:
```
curl -s -u ESPadmin:ESPpass100 -d 'a=1' -X POST http://192.168.120.189/api/reboot
→ {"ok":true,"message":"Reboot scheduled"}
```

Device pinged back up within ~3s. Post-reboot stats snapshot taken:
```
diff /tmp/pre-reboot-stats.json /tmp/post-reboot-stats.json
(empty diff)
```
✅ PASS — NVS unchanged across reboot; zero segment loss

Post-reboot history stream started at 1775758500 (one 900s interval ahead of pre-reboot 1775757600):
✅ PASS — history scrolled forward exactly one sample interval

---

## Preflight Results

All checks pass at head commit:
- `firmware_core_fragments_exist`: PASS
- `firmware_core_assembly_check`: PASS (SHA-256 identity verified)
- `firmware_core_fragment_line_sum`: PASS (4326 == 4326)
- All other checks: PASS

---

## Test Suite

Playwright: **184 passed**, 90 skipped
CodeQL: **0 alerts**

---

## Post-Merge Review Fixes

Three findings from the gate audit were resolved in follow-up commits:

1. **`dashboard.h` rebuilt from minified source** — Re-ran `minify-dashboard.sh` + `generate-header.sh`; gzip size restored to 37002 bytes (was 54582 bytes due to missing minification step)
2. **`firmware/core/config.h` header comment** — Fixed copy-paste: `sensor_history_multi-v7.6.6.5.h` → `config-v7.6.6.5.h`; also fixed `scripts/bump-version.sh` sed pattern to keep comment correct on future bumps
3. **Session log** — This file
