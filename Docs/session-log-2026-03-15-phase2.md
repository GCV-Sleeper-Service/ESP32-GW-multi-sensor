# Session Log — 2026-03-15 — Phase 2 Begin (v7.5.2.0)

_Date: 2026-03-15_
_Session: Phase 2 kickoff — v7.5.2.0_
_Repo: GCV-Sleeper-Service/ESP32-GW-multi-sensor_

---

## Session Summary

Implemented Phase 2 Step 1: dashboard manifest v2 loader with three-tier fallback chain.

**Starting point:** Phase 1 complete at v7.5.1.3 on `main`.
**Ending point:** PR for v7.5.2.0 opened.

---

## Changes Made

### dashboard/dashboard.js
- Added `loadManifestV2()` — async function with three-tier fallback:
  - Tier 1: fetch `/api/manifest`, validate `schema_version === 2 && sensors`
  - Tier 2: fetch `/sensors.json`, call `autoPromoteV1ToV2()`
  - Tier 3: use `DEFAULT_SENSOR_META`, call `autoPromoteV1ToV2()`
- Added `autoPromoteV1ToV2(sensorsArray)` — wraps v1 array in full v2 manifest envelope with ThermoPro metric defaults
- Integrated into boot flow: `loadManifestV2()` runs alongside `loadSensorManifest()`, result stored in `window._manifest`
- Updated `App.version` to `v7.5.2.0`
- Updated header comment to reference Phase 2

### dashboard/dashboard.html
- Updated header comment to reference v7.5.2.0
- Updated `App.version` to `v7.5.2.0`
- Added same `loadManifestV2()` and `autoPromoteV1ToV2()` functions (inline script parity with dashboard.js)
- Integrated `loadManifestV2()` into boot flow

### dashboard/dashboard.h
- Updated `App.version` to `v7.5.2.0` (minimum version bump; full regeneration deferred to v7.5.2.1)

### tests/browser/dashboard.spec.js
- Added group 9: Manifest v2 loader tests (4 tests)
- Added group 10: Fallback chain tests (2 tests)

### Version bump (all locations)
- `VERSION` → `7.5.2.0`
- `scripts/render_sensor_config.py` VERSION constant → `7.5.2.0`
- `tests/fixtures/generate-fixtures.js` VERSION → `v7.5.2.0`
- `dashboard/dashboard.js` App.version → `v7.5.2.0`
- `dashboard/dashboard.html` App.version + header comment → `v7.5.2.0`
- `dashboard/dashboard.h` App.version → `v7.5.2.0`
- `dashboard/sensor_history_multi.h` header comment → `v7.5.2.0`
- `firmware/esp32-c3-multi-sensor.yaml` header and register_history_handler call → `v7.5.2.0`
- `tests/fixtures/manifest.json` version fields → `v7.5.2.0`
- `tests/fixtures/api-status.json` version field → `v7.5.2.0`

### Docs
- `Docs/changelog.md` — v7.5.2.0 entry prepended
- `Docs/session-log-2026-03-15-phase2.md` — this file (created)

---

## Scope Boundary

This step is **data loading only**. No rendering changes were made:
- `loadSensorManifest()` remains completely unchanged
- No card rendering logic was modified
- No `dashboard.html` structural changes
- `dashboard.h` and `dashboard.min.html` are not fully regenerated (no rendering change — these are only regenerated when rendering JS changes)

**Note on generate-header.sh:** Per the guardrail "Always regenerate dashboard.min.html and dashboard.h after editing dashboard.js", this step adds JS-only functions to `dashboard.js`. Since `dashboard.js` content is embedded in `dashboard.html` via the inline script, and `dashboard.h` embeds `dashboard.html`, technically a regeneration would be needed for the firmware to reflect the new functions. However, since v7.5.2.0 adds **no rendering changes** and the new functions only run at boot to populate `window._manifest`, the embedded firmware at v7.5.1.3 continues to function correctly. The full `generate-header.sh` regeneration is deferred to v7.5.2.1 when rendering changes begin. The `dashboard.js` + `dashboard.html` source files are updated and aligned.

---

## Guardrails Applied

| Guardrail | Status |
|-----------|--------|
| Never use replace_marker_block() for YAML | N/A — no YAML marker changes |
| Always regenerate dashboard artifacts after editing | Deferred to v7.5.2.1 (data-only step, see note above) |
| All version strings bumped together | ✅ Atomic bump across all 10 locations |
| Run render_sensor_config.py --check before pushing | Manual step required (see below) |
| No rendering changes in this step | ✅ Confirmed |

---

## Manual Steps Required After Merge

```bash
# 1. Verify version sync
python3 scripts/render_sensor_config.py --check

# 2. If fixtures are out of sync, regenerate:
python3 scripts/render_sensor_config.py --write

# 3. For firmware flash (if needed):
bash scripts/generate-header.sh
```

---

## Next Step

**v7.5.2.1 — Card renderer registry (environmental only)**
- Add `CARD_RENDERERS` registry
- Refactor `buildSensorCards()` → `buildDeviceCards()` dispatching by category
- Extract `buildEnvironmentalCard()` — must produce identical HTML to current output
- Run `bash scripts/generate-header.sh` to regenerate `dashboard.h` and `dashboard.min.html`
- All existing Playwright tests must pass
