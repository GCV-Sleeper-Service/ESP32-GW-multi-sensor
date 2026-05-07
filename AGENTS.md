# AGENTS.md — ESP32-GW Multi-Sensor Gateway

_Instructions for AI coding agents working on this repository._

---

## Project Overview

This is an ESPHome/ESP-IDF firmware project with a JavaScript dashboard for ESP32 BLE sensor gateways. The codebase has a manifest-driven code generation pipeline, 8 firmware C++ fragments, a modular dashboard with 9 components, and a Playwright test suite with ~370 tests.

**Read `CURRENT-STATE.md` first.** It contains the current version, open issues, board measurements, unimplemented recommendations, and stale documents.

## Architecture — What NOT to Edit

### Generated Files (NEVER edit directly)

| Generated File | Source | Build Command |
|---|---|---|
| `dashboard/sensor_history_multi.h` | `firmware/core/*.h` (8 fragments) | `bash scripts/assemble-sensor-history.sh` |
| `dashboard/dashboard.js` | `dashboard/core/` + `dashboard/components/` | `bash scripts/bundle-dashboard.sh --write` |
| `dashboard/dashboard.html` | `dashboard/dashboard.tmpl.html` + JS/CSS | `bash scripts/build-dashboard.sh --write` |
| `dashboard/dashboard.h` | `dashboard/dashboard.html` (minified) | `bash scripts/generate-header.sh` |
| `src/gateway_manifest.h` | `config/sensors.json` | `python3 scripts/render_sensor_config.py --write` |

**Editing generated files instead of sources is a blocking defect.**

### Firmware Fragment Structure

```
firmware/core/
├── config.h              # compile-time constants, version, board detection
├── data-model.h          # HistoryBuffer, HistEntry, SensorEntity structs
├── nvs-persistence.h     # NVS read/write, segment management, history metadata
├── deferred-management.h # xTaskCreate wrappers for heavy operations
├── web-handler.h         # HTTP endpoint handlers (GET/POST/DELETE)
├── registration.h        # ESPHome component registration, endpoint wiring
├── ping-adapter.h        # Network ping probe device adapter
└── aggregator-runtime.h  # Satellite polling, gateway panel data (aggregator-only)
```

### Dashboard Module Structure

```
dashboard/core/           # 12 core modules (auth, boot, history, manifest, etc.)
dashboard/components/     # 9 UI components (auth-modal, charts, sensor-cards, etc.)
```

## Critical Rules

### Rule 40 — Deferred Task Pattern (MANDATORY)

Any HTTP handler performing NVS operations MUST:
1. Authenticate the request
2. Send the HTTP response immediately
3. Spawn a FreeRTOS task via `xTaskCreate` with 8192-byte stack for the heavy work

NVS operations must NEVER run on the httpd task. Existing examples: `schedule_reboot_()`, `schedule_reset_satellites_()`, `schedule_delete_data_()`.

### POST Content-Type

All dashboard `fetch()` POST calls: `Content-Type: application/x-www-form-urlencoded` with `body: 'a=1'`.
All `curl` POST commands: `-d 'a=1'`.
**Never use `application/json`** — ESPHome's fallback doesn't consume the body.

### Auth Pattern

All auth-gated dashboard fetches use `authFetch()` from `dashboard/core/auth.js`.
Public endpoints (`/api/status`, SSE streams): use plain `fetch()`.
Management endpoints (`/api/status/full`, all POST/DELETE): use `authFetch()`.

### external_components Block

Every board YAML **must** include:
```yaml
external_components:
  - source:
      type: local
      path: ../local_components
    components: [web_server_idf]
```
Without this, the 16KB httpd stack override is not compiled. The board runs on 4KB default and will crash under load.

### Pipeline

After ANY code change, verify the full pipeline:
```bash
bash scripts/provision.sh satellite
bash scripts/assemble-sensor-history.sh --check
python3 scripts/render_sensor_config.py --check
bash scripts/bundle-dashboard.sh --write
bash scripts/build-dashboard.sh --write
bash scripts/minify-dashboard.sh
bash scripts/generate-header.sh
bash scripts/preflight.sh
```

Single command for compile-test: `bash scripts/provision.sh satellite && esphome compile firmware/esp32-c3-multi-sensor.yaml`

### CI Safety

Never commit while operator configs are present:
```bash
# Before any commit:
ls config/gateway.json config/aggregator.json 2>/dev/null && echo "STOP: operator configs present"
bash scripts/provision.sh satellite
```

### csv.reserve() Bug (BUG-082)

`std::string::reserve(N)` does NOT truncate. Code building CSV from NVS loops MUST enforce explicit size checks. The full fix (chunked streaming) is Phase 7.

### Version Bumps

Use `bash scripts/bump-version.sh <version>`. Verify it updates VERSION, YAML, dashboard JS, and HTML.

## Device Testing

Production boards:
- C3 satellite: `192.168.120.189`
- WROOM satellite: `192.168.120.190`  
- S3 aggregator: `192.168.120.191`

Flash via OTA (never use `esphome run`, use `esphome upload --device=IP`):
```bash
esphome clean firmware/esp32-c3-multi-sensor.yaml
esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189
```

Smoke test after flash:
```bash
sleep 30
curl -s http://192.168.120.189/api/status | python3 -m json.tool
curl -s -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full | python3 -m json.tool
```

## Code Review Checklist

When reviewing PRs, check:
1. No generated files edited directly (skip their diffs)
2. NVS operations use deferred task pattern
3. POST calls use correct content-type
4. Auth-gated fetches use `authFetch()`
5. Board YAMLs have `external_components` block
6. Version consistency across all locations
7. Pipeline ordering preserved
8. Preflight passes
9. New endpoints registered with correct HTTP method
10. No `esphome run` in any script (use `upload` or `compile` only)

## Severity Classification

- **Blocking:** Generated file edited, NVS on httpd stack, missing external_components, data corruption risk
- **High:** Wrong POST content-type, missing authFetch, version mismatch, pipeline ordering broken
- **Medium:** Missing error handling, incomplete acceptance criteria, test gaps
- **Low:** Style, naming conventions, documentation formatting
- **Cosmetic:** Whitespace, comment formatting

## PR Description Standards

Use PRs #176-178 as reference for description format. Include:
- What changed and why
- Files modified (source files, not generated)
- Device testing results (curl outputs)
- Acceptance criteria checklist
- Known limitations or deferred items
