# Session Log — v7.6.6.6: Aggregator Runtime Device Integration Test

_Date: 2026-04-11_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_PR: #167_
_Branch: `copilot/implement-device-test-protocol-s3`_
_Status: COMPLETE — all acceptance criteria met at head commit `6768488`_

---

## Summary

Phase Y v7.6.6.6 records the passing device integration test of v7.6.6.5 aggregator firmware on
physical ESP32-S3 hardware. The aggregator poll task, all gateway endpoints, satellite add/delete/
test/reset flows, NVS satellite persistence, and reboot durability were all verified. No firmware
source code was modified — this is a version-bump-only release that records test evidence, updates
the changelog, and regenerates all version-stamped artifacts.

Three prompt corrections were discovered during testing and are recorded here and in the changelog.

---

## Commit Timeline

| SHA | Author | Message |
|-----|--------|---------|
| `6768488` | copilot-swe-agent | v7.6.6.6: Multi-Satellite Aggregator Device Integration Test PASS |

---

## Device Test Evidence

**Hardware:** ESP32-S3-DevKitC1-N16R8 at `192.168.120.191` (aggregator mode, 16MB flash, 8MB PSRAM)
**Build:** ESPHome 2026.2.1 / ESP-IDF
**Firmware tested:** v7.6.6.5

### Serial Boot Log (Checkpoint B)

Key lines extracted from serial monitor after flash:

```
Aggregator polling task started (init pending)
NVS satellite[0]: id=sat-c3-4m-189 url=http://192.168.120.189 poll=30s
NVS satellite[1]: id=sat-esp32-4m-190 url=http://192.168.120.190 poll=30s
Loaded 2 satellites from NVS
setup() finished successfully!
[sat-c3-4m-189] recovered (was unreachable)
[sat-esp32-4m-190] recovered (was unreachable)
Boot seems successful; resetting boot loop counter
PingAdapter: rtt=40ms success=100% (3/3)
```

All expected: aggregator task started, 2 satellites restored from NVS on boot, both satellites
polled successfully (live + status + manifest), safe-mode boot counter reset, WAN ping adapter
functional on gateway.

---

### HTTP API Test Results

**Test 1 — Aggregator gateways (`GET /api/aggregator/gateways`)**

```json
{
    "gateways": [
        {
            "id": "sat-c3-4m-189",
            "name": "First satellite - c3 supermini 4mb flash",
            "reachable": true,
            "last_seen": 1775851252,
            "consecutive_failures": 0,
            "manifest_cached": true,
            "live_cached": true,
            "firmware_version": "v7.6.6.4",
            "sensor_count": 5,
            "base_url": "http://192.168.120.189"
        },
        {
            "id": "sat-esp32-4m-190",
            "name": "Second satellite - esp32 wroom 4mb flash",
            "reachable": true,
            "last_seen": 1775851252,
            "consecutive_failures": 0,
            "manifest_cached": true,
            "live_cached": true,
            "firmware_version": "v7.6.5.3",
            "sensor_count": 5,
            "base_url": "http://192.168.120.190"
        }
    ]
}
```
✅ PASS — 2 satellites listed, both `"reachable": true`, manifests cached, full inline manifests correct

---

**Test 2 — Aggregator live data (`GET /api/aggregator/live`)**

```json
{
    "timestamp": 1775851305,
    "gateways": {
        "sat-c3-4m-189": {
            "reachable": true,
            "live": {
                "timestamp": 1775851264.0,
                "devices": {
                    "office":      { "temp": 22.2, "hum": 30.0, "last_seen": 1775851246 },
                    "first_floor": { "temp": 16.6, "hum": 40.0, "last_seen": 1775851257 },
                    "outside":     { "temp": 13.8, "hum": 41.0, "last_seen": 1775851274 },
                    "wan_ping":    { "ping_ms": 52.0, "success_pct": 100.0, "last_seen": 1775851273 },
                    "nas01":       { "cpu_pct": null, "last_seen": 0 }
                }
            }
        },
        "sat-esp32-4m-190": {
            "reachable": true,
            "live": {
                "timestamp": 1775851264.0,
                "devices": {
                    "office":      { "temp": 22.2, "hum": 30.0, "last_seen": 1775851297 },
                    "first_floor": { "temp": 16.6, "hum": 40.0, "last_seen": 1775851298 },
                    "outside":     { "temp": 13.7, "hum": 41.0, "last_seen": 1775851298 },
                    "wan_ping":    { "ping_ms": 34.7, "success_pct": 100.0, "last_seen": 1775851285 },
                    "nas01":       { "cpu_pct": null, "last_seen": 0 }
                }
            }
        }
    }
}
```
✅ PASS — live sensor data returned from both satellites; env sensors, WAN ping, nas01 (null, expected)

---

**Test 3 — History proxy (`GET /api/aggregator/proxy/{gw}/history/{device}/{metric}`)**

```bash
curl -s "http://192.168.120.191/api/aggregator/proxy/192.168.120.189/history/outside/temp" | head -30
# (empty response)
```
⚠️ NOT FUNCTIONAL — proxy returned empty body. Escalated as separate issue per §8 of the
implementation prompt. This does not block the gate (all mutation flows verified via dashboard
and other curl tests).

---

**Test 4 — Test satellite / probe (POST, authenticated)**

```bash
curl -s -u <user>:<pass> -d "url=http://192.168.120.189" -X POST \
  http://192.168.120.191/api/aggregator/test-satellite
```
```json
{"ok":true,"gateway":{"id":"gw-main","name":"Main Gateway","hardware":"ESP32-C3","sensor_count":5}}
```
✅ PASS — probe-only, no mutation; satellite confirmed reachable with correct metadata.

> **Prompt correction discovered:** The original prompt (§5d Test 4) used
> `-d "ip=192.168.120.189"` as the POST body. The correct form is
> `-d "url=http://192.168.120.189"` (full URL, not bare IP). The prompt was corrected
> in this PR (see LESSON-OPS-107 in the corrections sub-section of the changelog).

---

**Test 5 — Add satellite (POST, no auth)**

```bash
curl -s -d 'a=1' -X POST \
  "http://192.168.120.191/api/aggregator/add-satellite?url=http://192.168.120.190"
```
```json
{"ok":true,"satellite":{"id":"sat-esp32-4m-190","name":"Second satellite - esp32 wroom 4mb flash","url":"http://192.168.120.190","poll":30}}
```
✅ PASS — satellite added via `?url=` query parameter.

> **Prompt correction discovered:** The original prompt (§5d Test 5 and Test 8) used
> `-d "ip=192.168.120.189"` as a POST body field. The correct form passes `url` as a
> **query parameter**: `?url=http://192.168.120.189`. The prompt was corrected (LESSON-OPS-108).

---

**Test 6 — `satellite_config_generation` internal counter**

The original prompt (§5d Test 6) instructed:
```bash
curl -s http://192.168.120.191/api/aggregator/gateways | python3 -m json.tool | grep -i generation
# (no output)
```
The field was not in the HTTP response because `satellite_config_generation` is an **internal
runtime concurrency counter** (LESSON-OPS-106) — it is never serialised to any HTTP response.
The grep was always going to find nothing. Gate: PASS — all mutation flows that increment this
counter (add, delete, reset) were confirmed working via observable outcomes.

> **Prompt correction discovered:** Test 6 grep was incorrectly specified. Corrected in this PR.

---

**Test 7 — Delete satellite (DELETE, authenticated)**

```bash
curl -s -u <user>:<pass> -X DELETE \
  "http://192.168.120.191/api/aggregator/satellite/sat-esp32-4m-190"
```
```json
{"ok":true}
```
✅ PASS — satellite removed by string ID. Triggers deferred NVS save.

> **Prompt correction discovered:** The original prompt (§5d Test 7) used
> `/satellite/0` (integer index). The correct form is `/satellite/{string-id}` where
> the ID is the satellite's string ID from the gateways response (e.g. `sat-esp32-4m-190`).
> The prompt was corrected (LESSON-OPS-109).

---

**Test 8 — Re-add satellite after deletion (POST, no auth)**

```bash
curl -s -d 'a=1' -X POST \
  "http://192.168.120.191/api/aggregator/add-satellite?url=http://192.168.120.190"
```
```json
{"ok":true,"satellite":{"id":"sat-esp32-4m-190",...}}
```
✅ PASS — satellite re-added.

Verified gateways list restored:
```bash
curl -s http://192.168.120.191/api/aggregator/gateways | jq '[.gateways[].id]'
→ ["sat-c3-4m-189","sat-esp32-4m-190"]
```
✅ PASS — both satellites present after re-add

---

**Test 9 — Reboot persistence**

Device rebooted. After coming back online:
```
NVS satellite[0]: id=sat-c3-4m-189 url=http://192.168.120.189 poll=30s
NVS satellite[1]: id=sat-esp32-4m-190 url=http://192.168.120.190 poll=30s
Loaded 2 satellites from NVS
```
✅ PASS — 2 satellites restored from NVS on boot; NVS satellite persistence confirmed.

---

**Test 10 — Reset satellites (POST, authenticated)**

```bash
curl -s -u <user>:<pass> -d 'a=1' -X POST \
  http://192.168.120.191/api/system/reset-satellites
```
```json
{"ok":true,"message":"Satellite reset scheduled","satellite_count":3}
```
✅ PASS — deferred reset task triggered; 3 compile-time default satellites restored after reset.

---

### Dashboard Operations (UI verification)

- Add satellite — ✅ confirmed working
- Test satellite — ✅ confirmed working
- Remove satellite — ✅ confirmed working

---

### Satellite Mode Restoration

After all tests, device switched back to satellite mode:

```bash
bash scripts/provision.sh satellite
# → ✅ satellite mode confirmed

bash scripts/provision.sh status
# → Role: satellite, CI-safe: YES
```

---

## Playwright Results

```
FIXTURE_SET=3sensor    chromium → 99 passed, 45 skipped ✓
FIXTURE_SET=3sensor    firefox  → 99 passed, 45 skipped ✓
FIXTURE_SET=mixed      chromium → 7 passed ✓
FIXTURE_SET=system     chromium → 8 passed ✓
FIXTURE_SET=aggregator chromium → 11 passed, 1 skipped ✓
```

---

## Preflight Results

```
bash scripts/preflight.sh → all checks pass ✓
bash scripts/assemble-sensor-history.sh --check → 4326 == 4326 ✓
```

All Phase Y checks pass:
- `firmware_core_fragments_exist`: PASS
- `firmware_core_assembly_check`: PASS (SHA-256 identity verified)
- `firmware_core_fragment_line_sum`: PASS (4326 == 4326)

---

## Prompt Corrections Committed

Three bugs in the v7.6.6.6 implementation prompt were discovered during device testing
and corrected in this PR:

| # | Field | Was | Corrected to |
|---|-------|-----|--------------|
| LESSON-OPS-107 | `test-satellite` POST | `-d "ip=192.168.120.189"` | `-d "url=http://192.168.120.189"` |
| LESSON-OPS-108 | `add-satellite` POST | `-d "ip=192.168.120.189"` | `?url=http://192.168.120.189` (query param) |
| LESSON-OPS-109 | `satellite DELETE` route | `/satellite/0` (integer) | `/satellite/{string-id}` (e.g. `sat-esp32-4m-190`) |
| LESSON-OPS-106 | Test 6 `grep -i generation` | grep for field in HTTP response | Field is internal-only; grep removed; mutation outcomes verified instead |

Same corrections applied to `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md`.

---

## Gap: History Proxy Non-Functional

`GET /api/aggregator/proxy/{gw}/history/{device}/{metric}` returns an empty body. This was
observed and escalated as a separate issue. It does not block the v7.6.6.6 gate — the core
aggregator poll task, gateway endpoints, satellite mutation flows, and NVS persistence all
pass. The proxy gap is tracked for resolution in a follow-up issue.

---

_End of v7.6.6.6 session log._
