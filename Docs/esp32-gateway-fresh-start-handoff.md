# ESP32 Gateway Fresh-Start Handoff

_Last updated: 2026-03-13 — v7.5.0.0_

This document is the durable restart point for future sessions.

---

## 1. Current repo state

Current intended repo version after this bundle is **v7.5.0.0**.

The repo now has:
- canonical sensor manifest workflow (`config/sensors.json` + renderer)
- retained-history export/import tooling
- configurable 1–4 sensor support
- browser regression infrastructure with mock server + fixtures
- **Phase 1 manifest boot contract**:
  - firmware serves `GET /api/manifest`
  - firmware still serves `GET /sensors.json` for compatibility
  - dashboard prefers `/api/manifest`, falls back to `/sensors.json`, then to built-in defaults

---

## 2. Why Phase 1 was implemented this way

The architecture direction is richer manifest-driven boot, but the existing repo already had multiple downstream consumers of the old array contract.

So the implementation rule for this phase is:
- **additive first**
- **non-breaking by default**
- **remove old contract only later, if ever, after all consumers are migrated**

That is why `/sensors.json` remains present even after `/api/manifest` is introduced.

---

## 3. Important design context to remember in future sessions

### Single-sensor import merge model
When importing a single-sensor CSV:
- the firmware scans retained NVS segments during `/api/import/begin/single/<id>`
- it builds an epoch-to-slot map of existing hourly segments
- each write batch checks whether that hour already exists
- if it exists, the firmware reads that segment, overlays only the target sensor arrays, and writes the merged segment back to the same slot
- only brand-new hours allocate a new slot
- temporary overhead is roughly ~7 KiB during the merge path

This is important because future features touching history/import/manifest logic should not accidentally regress that behavior.

### Frontend/backend manifest contract
Current boot contract priority is:
1. `/api/manifest`
2. `/sensors.json`
3. built-in defaults in `dashboard/dashboard.js`

If a future session changes this order, it should be treated as an explicit design decision and documented.

---

## 4. Files most relevant to current manifest phase

### Core runtime
- `dashboard/sensor_history_multi.h`
- `dashboard/dashboard.js`
- `firmware/esp32-c3-multi-sensor.yaml`

### Generator / config alignment
- `config/sensors.json`
- `scripts/sensor_manifest_lib.py`
- `scripts/render_sensor_config.py`

### Test layer
- `tests/mock-server/server.js`
- `tests/fixtures/generate-fixtures.js`
- `tests/fixtures/sensors.json`
- `tests/fixtures/manifest.json`
- `tests/browser/manifest.spec.js`

### Durable docs
- `Docs/changelog.md`
- `Docs/bugs-and-lessons-learned.md`
- `Docs/architecture.md`
- `Docs/session-log-2026-03-13-v7.5.0.0-phase1-manifest.md`

---

## 5. Expected local workflow after applying this bundle

From repo root:

```bash
python3 scripts/apply_phase1_manifest_patch.py
python3 scripts/render_sensor_config.py --write
bash ./scripts/minify-dashboard.sh
bash ./scripts/generate-header.sh dashboard/dashboard.min.html dashboard/dashboard.h
bash ./scripts/preflight.sh
esphome compile firmware/esp32-c3-multi-sensor.yaml
```

If compile passes, then flash/test on device.

---

## 6. What to verify on the real device

### Firmware/API
- `GET /api/manifest` returns schema v2 JSON
- `GET /sensors.json` still returns the legacy array
- `GET /api/status` and `GET /api/storage-stats` still work
- history/export/import behavior remains unchanged

### Dashboard
- dashboard loads normally from the embedded firmware page
- sensor cards/charts render without relying on hardcoded count
- dashboard still works if `/api/manifest` is missing but `/sensors.json` is present
- no regression in export/import/history UI

---

## 7. Likely next phases after this one

After Phase 1, logical next work is:
- broader cleanup of legacy manifest usage in helper tools if desired
- decide whether future metric expansion is real or whether temp/hum remain the only supported metric pair
- only then consider whether `/sensors.json` should remain indefinitely as a stable compatibility surface or be retired
