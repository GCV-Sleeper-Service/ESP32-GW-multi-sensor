# ESP32 Gateway Fresh-Start Handoff

_Last updated: 2026-03-14 — v7.5.0.1_

This document is the durable restart point for future sessions. Read it first before touching any code.

---

## 1. Project identity

**Repo:** https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor  
**Current version:** `v7.5.0.1`  
**Current branch:** `main` (Phase 1 merged via PR #9)  
**Suggested next branch:** `phase2-from-v7.5.0.1`  
**Hardware:** ESP32-C3 SuperMini running ESPHome on ESP-IDF (not Arduino)  
**Sensors:** 3 × ThermoPro TP357 BLE (configurable 1–4)

---

## 2. Current development stage

**Phase 1 — complete and device-validated.**

Phase 1 of the v7.5/v7.6 architecture plan (see `Docs/v7.5-v7.6-architecture-plan.md`) has been implemented, debugged, and validated on the real device. The key deliverable was introducing a manifest endpoint that allows the dashboard — and eventually an aggregator — to discover what sensors a gateway has and how to render them, without hardcoded ThermoPro assumptions.

**What Phase 1 delivered:**
- `GET /api/manifest` — new endpoint serving schema v2 JSON with global metric metadata and per-sensor history paths
- Dashboard boot now prefers `/api/manifest`, falls back to `/sensors.json`, falls back to built-in defaults
- Free Heap and Uptime restored to custom dashboard via `GET /api/status`
- Free Heap, Uptime, and Loop Time restored to built-in ESPHome diagnostics page
- Generator idempotence and YAML indentation handling fixed
- All three endpoints device-validated: `/api/manifest`, `/api/status`, `/sensors.json`

**What Phase 1 did NOT do (scope boundaries):**
- The `/api/manifest` response is a pragmatic partial v2 — it lacks the `gateway` identity block, per-measurement `class`/`data_type`/`display` hints, and `history` retention policy block specified in the full plan. These are required inputs for Phase 2.
- The C++ data model (`SensorSlot`) was not changed. The `SensorEntity` / `MetricDef` / `MetricState` refactor is Phase 3.
- No `CARD_RENDERERS` registry in the dashboard. `buildSensorCards()` is still a monolith. That refactor is Phase 2.
- No `tests/fixtures/manifest-v2.json` aligned to the full v2 schema from the plan.

**Phase 2 is the next work.** See section 7.

---

## 3. Boot contract — critical context for all future sessions

The dashboard boot sequence is now:
1. `fetch('/api/manifest')` → parse schema v2, extract sensor list and metric metadata
2. If (1) fails → `fetch('/sensors.json')` → parse legacy v1 array, auto-promote to internal format
3. If (2) also fails → use `DEFAULT_SENSOR_META` array built into `dashboard.js`

This priority order is a design decision, not an accident. `/sensors.json` remains present intentionally for backward compatibility with older firmware and external tools. If a future session changes this order, it should be treated as an explicit design decision and documented.

---

## 4. Single-sensor import merge model — carry forward every time

When importing a single-sensor CSV:
- The firmware scans retained NVS segments during `POST /api/import/begin/single/<id>`
- It builds an epoch-to-slot map of existing hourly segments
- Each write batch checks whether that hour already exists
- If it exists, the firmware reads that segment, overlays only the target sensor arrays, and writes the merged segment back to the same slot
- Only brand-new hours allocate a new slot
- Temporary overhead is roughly ~7 KiB during the merge path

This behavior must not be accidentally broken by future history/import/manifest changes.

---

## 5. Key files — most relevant to current and next work

### Core runtime
| File | Purpose |
|---|---|
| `dashboard/sensor_history_multi.h` | All C++ firmware logic — data model, NVS persistence, HTTP endpoints |
| `dashboard/dashboard.js` | Dashboard JavaScript — manifest loading, card rendering, history fetching |
| `dashboard/dashboard.html` | Dashboard HTML source of truth — edit this, then regenerate min/header |
| `dashboard/dashboard.h` | Generated embedded payload — do not edit directly |
| `firmware/esp32-c3-multi-sensor.yaml` | ESPHome YAML — BLE trackers, lambdas, web server, diagnostics sensors |

### Generator / config
| File | Purpose |
|---|---|
| `config/sensors.json` | Canonical sensor manifest — single source of truth for id/name/MAC |
| `scripts/sensor_manifest_lib.py` | Manifest loading, validation, canonicalization |
| `scripts/render_sensor_config.py` | Generates all dependent files from `config/sensors.json` |

### Test layer
| File | Purpose |
|---|---|
| `tests/mock-server/server.js` | Mock ESP32 API server for Playwright |
| `tests/fixtures/sensors.json` | Legacy v1 fixture manifest |
| `tests/fixtures/manifest.json` | Schema v2 fixture manifest (partial — needs full v2 schema for Phase 2) |
| `tests/fixtures/api-status.json` | Status endpoint fixture |
| `tests/browser/dashboard.spec.js` | 28-test regression suite |
| `tests/browser/manifest.spec.js` | Manifest boot and fallback tests |

### Durable docs
| File | Purpose |
|---|---|
| `Docs/v7.5-v7.6-architecture-plan.md` | Full architecture plan — the north star document |
| `Docs/changelog.md` | Release history |
| `Docs/bugs-and-lessons-learned.md` | Bug and lessons registry |
| `Docs/v7.5.x-documentation.md` | Phase 1 reference and Phase 2 scope |
| `Docs/session-log-2026-03-13-14-phase1-consolidated.md` | Full Phase 1 session history |

---

## 6. Workflow — every session

Before any code changes:
```bash
python3 scripts/render_sensor_config.py --write
bash ./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

After dashboard source changes (`dashboard.html`):
```bash
bash ./scripts/minify-dashboard.sh
bash ./scripts/generate-header.sh dashboard/dashboard.min.html dashboard/dashboard.h
bash ./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

Before committing:
- Bump version strings in all six locations (VERSION, YAML header comment, `register_history_handler()` string, `dashboard_link` publish-state text, `App.version` in `dashboard.js`, version comment in `dashboard.html`)
- Run `npm run test:browser` to verify Playwright suite
- Verify CI is green after push

Runtime smoke check on device:
```bash
curl -s http://<esp-ip>/sensors.json | jq
curl -s http://<esp-ip>/api/status | jq
curl -s http://<esp-ip>/api/manifest | jq
```

Also verify the built-in ESPHome web page at `http://<esp-ip>/` shows Free Heap, Uptime, and Loop Time.

---

## 7. Phase 2 — what comes next

Phase 2 is "Dashboard Consumes v2 Manifest" — teaching the dashboard to render from manifest metadata instead of hardcoded ThermoPro assumptions.

**Prerequisite (Phase 1 completion item):**  
Upgrade the `/api/manifest` firmware response to include the full v2 schema: `gateway` block, `history` retention block, and per-measurement `class`/`data_type`/`display` hints as specified in `Docs/v7.5-v7.6-architecture-plan.md` section 5.2.

**Phase 2 tasks in sequence:**
1. Upgrade `/api/manifest` to full v2 schema (firmware)
2. Extend `normalizeManifestSensors()` in dashboard to capture `category`, measurement `class`, and `display` policy
3. Introduce `CARD_RENDERERS` registry with `environmental` as first and only renderer (wrapping current `buildSensorCards()` logic)
4. Refactor `buildSensorCards()` → `buildDeviceCards()` that dispatches via `CARD_RENDERERS[device.category]`
5. Add `_default` fallback renderer for unknown categories
6. Add `METRIC_FORMATTERS` registry
7. Refactor `fetchSensorHistoryRows()` to be manifest-driven (reads chartable metrics from manifest)
8. Update mock server to serve full v2 manifest fixture
9. Add Playwright tests: manifest-driven rendering, fallback behavior
10. Full regression: ThermoPro rendering must be pixel-identical to current behavior

**Risk:** Medium. The card rendering refactor touches many functions. The Playwright regression suite is the safety net. Upgrade firmware manifest first so dashboard tests have a real response to validate against.

---

## 8. Critical guardrails — do not re-learn these

- **Never use `replace_marker_block()` for YAML sections.** Use `apply_yaml_marker_block()` for all YAML marker regions. See BUG-035, BUG-036.
- **Never use raw string in `re.sub()` for generated content with backslashes.** Use lambda replacement. See BUG-034.
- **Never patch against compacted one-line C++ blocks.** Use function-anchor or regex-based insertion. See BUG-033.
- **Always regenerate `dashboard.min.html` and `dashboard.h` after editing `dashboard.html`.** `dashboard.html` is the source of truth. See BUG-039.
- **Always validate both the custom dashboard AND the built-in ESPHome web page after YAML changes.** See BUG-037.
- **Always bump all six version string locations together.** See LESSON-OPS-009.
- **Always run `python3 scripts/render_sensor_config.py --write` before preflight.** Generator drift is a frequent source of false-pass preflight.
- **CSV timestamps in fixture files must be epoch seconds, not milliseconds.** See BUG-025.
- **`data-history-range` attribute values are in hours (24, 168, 720, 1080), not display labels.** See LESSON-OPS-026.
- **Preflight does not validate ESPHome YAML structure.** Run `esphome config firmware/esp32-c3-multi-sensor.yaml` separately when generator changes are involved. See ISSUE-004.
