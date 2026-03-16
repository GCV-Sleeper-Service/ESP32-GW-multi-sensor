# Phase 1 & Phase 2 — Comprehensive Assessment and Remediation Plan

_Date: 2026-03-16_  
_Assessed by: Architecture review session_  
_Baseline: v7.5.2.4 on `main` (commit 3abd539)_  
_Repo: [GCV-Sleeper-Service/ESP32-GW-multi-sensor](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor)_

---

## Executive Summary

Phase 1 and Phase 2 are both **complete and functional**. The dashboard is fully manifest-driven, the fallback chains work, the test coverage is strong (73 Playwright tests, 21 preflight checks), and the architecture plan's goals for these two phases are met. However, the implementation took some pragmatic shortcuts and accumulated a few gaps that should be resolved before Phase 3 begins. None of these gaps are regressions — they are deferred decisions and minor inconsistencies that will create friction if carried forward into the firmware refactor.

**Overall grade: B+** — Solid engineering with good test discipline. The rough Phase 1 initial delivery (7 bugs) was properly recovered and hardened. Phase 2 was cleanly executed.

---

## Phase 1 Assessment — Manifest v2 and `/api/manifest` Endpoint

### What Was Delivered

| Version | PR | Deliverable | Status |
|---|---|---|---|
| v7.5.0.0–v7.5.0.1 | #9 | Initial `/api/manifest` endpoint, dashboard boot migration, runtime fixes | ✅ Merged (7 bugs found and fixed) |
| v7.5.1.0 | #17 | Full v2 schema with `gateway_manifest.h` as compile-time C string | ✅ Merged |
| v7.5.1.1 | #18 | Preflight validates manifest v2 schema structure | ✅ Merged |
| v7.5.1.2 | #19 | ESPHome YAML parse gate in preflight | ✅ Merged |
| v7.5.1.3 | #21 | Atomic version sync, fixture v2 alignment, drift guard | ✅ Merged |

### Strengths

1. **Manifest v2 schema is well-structured.** The `gateway`, `history`, `metrics`, and `sensors` blocks cleanly separate concerns. The shared `metrics` array avoids per-sensor duplication for homogeneous deployments.

2. **`gateway_manifest.h` compile-time approach is correct.** Zero runtime overhead, zero heap allocation, guaranteed JSON validity at build time. Exactly what the architecture plan specified.

3. **v1→v2 auto-promotion is clean.** `sensor_manifest_lib.py` handles v1 manifests transparently. Existing `config/sensors.json` files continue to work without modification.

4. **Preflight coverage is thorough.** 21 checks covering version sync across 6 canonical sources, schema structure validation, YAML parse gate, fixture regeneration, and Playwright spec execution. This is unusually strong for an embedded project.

5. **`bump-version.sh` is a direct lesson-learned implementation.** BUG-041 and BUG-042 exposed that manual version bumps across 6+ files were error-prone. The atomic bump script is the correct fix.

6. **Device validation was performed.** v7.5.0.1 was OTA-flashed and verified on the real ESP32-C3 with `curl` checks against all endpoints.

### Gaps

#### GAP-P1-01: `config/sensors.v2.example.json` was never created

**Architecture plan reference:** Phase 1 Task #1 — "Design `config/sensors.v2.example.json` with two device types (ThermoPro + one non-climate example)"

**Impact:** Low. The v2 schema is documented in the architecture plan and implemented in code. However, operators have no concrete example of what a multi-category v2 config file looks like. This becomes important when Phase 4 adds the ping probe.

**Remediation:** Create `config/sensors.v2.example.json` as part of the Phase 3 prep work. Include one ThermoPro sensor and one ping probe device with full v2 fields.

#### GAP-P1-02: Schema naming diverges from architecture plan

**Architecture plan reference:** Section 5.2 uses `"devices"` as the top-level array name. The implementation uses `"sensors"`.

**Impact:** Medium. The word "sensor" conflates hardware and logical entity (the architecture plan explains this in section 5.2). More importantly, the manifest's `measurements` are lightweight `{key, history_url}` references that defer to the shared top-level `metrics` array. The architecture plan's recommended schema has per-device inline measurements with full definitions (`key`, `label`, `unit`, `class`, `data_type`, `history`, `display`). The current shared-metrics approach works for homogeneous ThermoPro, but a gateway with both ThermoPro and ping probe would need different metric sets per device, breaking the shared-metrics assumption.

**Remediation:** Phase 3 should resolve this before the C++ refactor. Two options:

- **Option A (recommended):** Keep `sensors` naming for backward compatibility but add per-device `measurements` with full metric definitions alongside the shared `metrics` array. The shared `metrics` become defaults; per-device measurements override when present.
- **Option B:** Rename `sensors` → `devices` and restructure to match the architecture plan exactly. This is a breaking change to the v2 schema that requires updating all consumers (dashboard, test fixtures, preflight, session logs).

#### GAP-P1-03: `dashboard/dashboard.html` not covered by `bump-version.sh`

**Impact:** Low-Medium. Session logs for v7.5.2.1, v7.5.2.2, v7.5.2.3, and v7.5.2.4 all note that `dashboard.html` required a manual `sed` update after running `bump-version.sh`. The script updates `dashboard.js` (via `render_sensor_config.py --write`) and regenerates `dashboard.h` (via `generate-header.sh`), but `dashboard.html` has its own `App.version` string that is not in the generator's scope.

**Remediation:** Add `dashboard.html` update to `bump-version.sh`:
```bash
echo "→ Updating dashboard/dashboard.html..."
sed -i "s/App\.version = 'v[0-9.]*'/App.version = 'v${NEW_VER}'/" dashboard/dashboard.html
```
Insert this after the `generate-fixtures.js` update and before `render_sensor_config.py --write`.

---

## Phase 2 Assessment — Dashboard Consumes v2 Manifest

### What Was Delivered

| Version | PR | Deliverable | Status |
|---|---|---|---|
| v7.5.2.0 | #24 | Manifest v2 loader with three-tier fallback chain | ✅ Merged |
| v7.5.2.1 | #27 | `CARD_RENDERERS` registry + `buildDeviceCards()` dispatcher | ✅ Merged |
| v7.5.2.2 | #28 | `METRIC_FORMATTERS` registry + `formatMetricValue()` | ✅ Merged |
| v7.5.2.3 | #29 | `fetchDeviceHistory()` — manifest-driven history URL resolution | ✅ Merged |
| v7.5.2.4 | #30 | Full Playwright regression + Phase 2 closure (8 scenarios) | ✅ Merged |
| (docs) | #26 | Version-drift preflight hardening + `bump-version.sh` | ✅ Merged |

### Strengths

1. **Clean incremental delivery.** Each step had a clear scope, proper test coverage, changelog entry, and session log. No step broke any prior test. This is Phase 2 done right.

2. **Three-tier fallback chain is robust.** `/api/manifest` → `/sensors.json` + auto-promote → `DEFAULT_SENSOR_META` + auto-promote. All three tiers tested in Playwright.

3. **`CARD_RENDERERS` registry is extensible.** Adding `network` or `system` renderers in Phase 4 requires adding one function and one registry entry. The `_default` fallback prevents crashes for unknown categories.

4. **`METRIC_FORMATTERS` registry centralizes formatting.** Temperature's `°C / °F` dual display and humidity's `Math.round()` are properly encapsulated. The `_default` formatter handles unknown metric types gracefully.

5. **`fetchDeviceHistory()` is fully manifest-driven.** History URLs come from `measurements[].history_url` with automatic fallback to legacy `/history/{id}/temp` and `/history/{id}/hum` paths. This means the dashboard works with both v2-aware and legacy firmware.

6. **Compatibility aliases are preserved.** `buildSensorCards()` still works as a wrapper around `buildDeviceCards()`. No external callers are broken.

7. **Test coverage is comprehensive.** 73 tests across 14 groups covering boot, sensor cards, transport, history, charts, custom date range, theme toggle, export, console errors, manifest loading, fallback chain, card renderer dispatch, metric formatting, and Phase 2 closure regression.

### Gaps

#### GAP-P2-01: Boot flow race condition between `loadManifestV2()` and `loadSensorManifest()`

**Impact:** None for Phase 2. Will cause issues in Phase 4.

**Details:** In `App.Boot.start()`, `loadManifestV2()` and `loadSensorManifest()` are launched concurrently (both start immediately, not sequenced). `loadSensorManifest()` resolves and calls `buildSensorCards()` → `buildDeviceCards()`, which reads `window._manifest` for category dispatch. If `loadManifestV2()` hasn't resolved yet, `window._manifest` is null, and all devices default to `'environmental'` category.

For Phase 2 this is harmless — everything is environmental. But when Phase 4 adds a ping probe device, there would be a brief window where the ping device renders with the environmental card renderer before the manifest arrives and triggers a re-render. In practice the window is very small (both fetch from the same mock server), but it's a design gap.

**Remediation:** Before Phase 4, sequence the boot so `loadManifestV2()` completes before `loadSensorManifest()`, or make `buildDeviceCards()` re-render when `window._manifest` arrives. The simplest fix:

```javascript
App.Boot.start = function() {
  // ...
  loadManifestV2().then(function(manifest) {
    window._manifest = manifest;
    return loadSensorManifest();
  }).then(function() {
    buildSensorCards();
    // ... rest of boot
  });
};
```

#### GAP-P2-02: `formatMetricValue` key dispatch mismatch

**Impact:** Low. Cosmetic/consistency issue.

**Details:** `METRIC_FORMATTERS` uses `temperature` and `humidity` as registry keys. The manifest uses `temp` and `hum` as metric keys. Call sites use hardcoded strings (`'temperature'`, `'humidity'`), not manifest keys. This works but couples formatting to hardcoded knowledge of what `temp` means.

**Remediation:** Minor. When Phase 3 generalizes the model, consider:
- Adding `formatter_key` to metric definitions, or
- Aliasing manifest keys in the formatter registry: `METRIC_FORMATTERS.temp = METRIC_FORMATTERS.temperature`
- Or simply documenting the convention

#### GAP-P2-03: `autoPromoteV1ToV2()` hardcodes ThermoPro assumptions

**Impact:** None for Phase 2. Correct by design — v1 manifests are always ThermoPro.

**Details:** The auto-promotion function produces a v2 manifest with `category: 'environmental'`, `adapter: 'thermopro_ble'`, and exactly two measurements (temp, hum) for every sensor. This is correct for v1→v2 migration but means the fallback path can never represent non-environmental devices.

**Remediation:** No action needed. When Phase 4 adds non-environmental devices, they will only exist in v2 manifests. A v1 manifest by definition only contains ThermoPro sensors.

---

## Remediation Priority Summary

| # | Gap | Priority | When to Fix | Effort |
|---|---|---|---|---|
| GAP-P1-03 | `dashboard.html` not in `bump-version.sh` | **High** | Before Phase 3 starts | 5 min (one `sed` line) |
| GAP-P1-02 | Schema naming: `sensors` vs `devices`, shared vs per-device metrics | **High** | Phase 3 planning decision | Design decision, then ~30 min code |
| GAP-P2-01 | Boot flow race condition | **Medium** | Before Phase 4 | 15 min |
| GAP-P1-01 | Missing `sensors.v2.example.json` | **Medium** | Phase 3 prep | 10 min |
| GAP-P2-02 | Formatter key dispatch mismatch | **Low** | Phase 3 or later | 10 min |
| GAP-P2-03 | `autoPromoteV1ToV2` ThermoPro assumptions | **None** | No action needed | — |

**Recommended action:** Fix GAP-P1-03 immediately (add to `bump-version.sh`). Resolve GAP-P1-02 as the first design decision of Phase 3. Address GAP-P2-01 during Phase 3 boot flow changes.

---

_End of assessment._
