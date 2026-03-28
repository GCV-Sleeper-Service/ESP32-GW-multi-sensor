# Architecture Forward-Looking Notes

_Date: 2026-03-27_
_Context: Post-Phase-6 analysis, pre-Phase-D preparation_
_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_

---

## Purpose

This document captures architectural decisions, constraints, and forward-looking risks identified during the Phase 6 closure analysis. These are not Phase D requirements — they are design considerations that Phase D, Phase 7, and Phase 8 must be aware of to avoid creating problems that are expensive to fix later.

This document supplements `Docs/v7.5-v7.6-architecture-plan.md` and should be read alongside `Docs/phase-d-implementation-plan.md`.

---

## 1. Aggregator Role Restricted to PSRAM-Equipped Boards

### Decision

Devices without PSRAM should be restricted to the satellite role only. The aggregator role requires PSRAM for safe operation at scale.

### Rationale

The `SatelliteCache` struct consumes ~10.8KB per satellite slot (after the v7.5.7.0 buffer increase). With `MAX_SATELLITES=8`, that's ~86KB for cache structs alone, plus `s_fetch_tmp` (8KB) and `s_proxy_tmp` (32KB). Total aggregator infrastructure overhead is ~128KB before any sensor history.

On a C3 with 320KB total RAM and no PSRAM, 128KB is 40% of available memory — not viable alongside sensor history, dashboard serving, and WiFi/BLE stacks. Even the WROOM-32D with 520KB internal RAM would be operating at the margin.

### Scaling Rules

| PSRAM | Max Satellites | Board Examples |
|---|---|---|
| None | Satellite role only | ESP32-C3 SuperMini, ESP32-WROOM-32D, ESP32-S3 without PSRAM |
| 2MB | Up to 4 satellites | Future boards with limited PSRAM |
| ≥ 4MB | Up to 8 satellites | ESP32-S3-DevKitC-1 N16R8 |

### Future Implementation

In the Phase E captive provisioning portal, the role selection screen should inspect board resources at runtime:
- If PSRAM is detected: offer both "Satellite" and "Aggregator" roles
- If no PSRAM: offer "Satellite" role only, with an explanation ("This board does not have enough memory for the aggregator role")
- PSRAM size should determine the `MAX_SATELLITES` ceiling shown in the aggregator configuration UI

Research needed: the ESP-IDF provides `esp_psram_get_size()` (or equivalent) for runtime PSRAM detection. The ESPHome framework may expose this through a different API. The exact detection mechanism should be validated before Phase E prompt authoring.

### Build-Time Enforcement (v7.5.7.0)

Since v7.5.7.0, `render_sensor_config.py` enforces this decision at build time: if `aggregator.json` exists but the board profile has `capabilities.psram: false`, the generator emits `AGGREGATOR_ENABLED 0` with a build-time warning. This allows the same `config/` directory to be shared across multiple boards — the C3 satellite and S3 aggregator can share a repo checkout, and each build gets the correct configuration.

### Boot-Time Heap Warning (Phase D)

Phase D should emit a boot-time log warning if free internal heap drops below a configurable threshold (recommended: 40KB) after aggregator initialization. This catches edge cases where a PSRAM board is under memory pressure from a combination of large satellite count, sensor history, and WiFi/BLE stacks. The warning should include the current heap values and a suggestion to reduce `MAX_SATELLITES`.

---

## 2. Manifest Serving Separation (Future Refactor)

### Current State

The `/api/aggregator/gateways` endpoint builds a single JSON response that embeds every satellite's full manifest inline:

```json
{
  "gateways": [
    {
      "id": "sat-c3-4m-189",
      "reachable": true,
      "manifest": { /* full satellite manifest, potentially 4-8KB */ }
    },
    ...
  ]
}
```

With 8 satellites × 8KB manifests, this response can exceed 64KB — built as a `std::string` in a single heap allocation.

### Problem

This design scales linearly with satellite count × manifest size. As system devices, notification config, and future sensor types get added to manifests, the per-manifest size grows. Eventually this response will exceed what can be safely built in a single string on any ESP32 variant.

### Recommended Future Architecture

Serve manifests separately:

```
GET /api/aggregator/gateways          → lightweight metadata only
GET /api/aggregator/gateway/{id}/manifest  → full manifest for one satellite
```

The gateways endpoint would return only:
```json
{
  "gateways": [
    { "id": "sat-c3-4m-189", "reachable": true, "name": "...", "sensor_count": 4 }
  ]
}
```

The dashboard would fetch individual manifests on demand (when the user selects a gateway or when rendering per-gateway device cards).

### Timeline

This is not a Phase D change. The current design is adequate through Phase D and Phase 7. It should be evaluated as a Phase 8 prerequisite if manifest sizes continue to grow.

### Phase D Consideration

Phase D must not make this refactor harder. Specifically: do not add logic that depends on manifests being available synchronously in the gateways response. The dashboard should tolerate manifests arriving separately.

---

## 3. NVS Entry Budget Tracking

### Current NVS Usage (default partition)

| Consumer | Entries | Notes |
|---|---|---|
| ESPHome platform | ~20-30 | WiFi credentials, component state |
| History persistence (Phase 7) | Up to 60 | `MAX_PERSIST_METRICS=6` × ~10 segments each |
| Phase D satellite config | Up to 33 | 8 satellites × 4 keys + 1 count key |
| **Estimated total** | **~123** | |

### NVS Capacity

The default NVS partition (typically 20KB–24KB) supports roughly 400-500 entries depending on key/value sizes and page fragmentation. Current projected usage is ~25-30% of capacity.

### Future Pressure

Phase 8 notification rules could add 10-50+ entries depending on rule complexity. Per-device export/import metadata could add more. The budget should be monitored at each phase boundary.

### Recommendation

Add a `/api/storage-stats` field (or extend the existing one) that reports NVS usage: entries used, entries available, namespace breakdown. This provides operational visibility without requiring firmware-level debugging.

---

## 4. `sensor_history_multi.h` File Split Plan

### Current State

`sensor_history_multi.h` is a 3,200+ line monolith containing:
- `SatelliteCache` struct and related types
- Aggregator polling task
- All aggregator API endpoint handlers
- Proxy logic
- Init functions
- Data ingest handler
- System metrics support
- All under `#if AGGREGATOR_ENABLED` guards

### Problem

Coding agents have context window limits. Reading this file consumes significant context budget, leaving less room for the actual implementation work. As Phase D adds NVS persistence, runtime mutation, and management endpoints, the file will approach 4,000-5,000 lines.

### Recommended Split (Phase 8 Prerequisite)

| New File | Contents |
|---|---|
| `aggregator_types.h` | `SatelliteCache` struct, constants, forward declarations |
| `aggregator_polling.h` | Polling task, `fetch_to_buffer()`, satellite health tracking |
| `aggregator_endpoints.h` | All `/api/aggregator/*` handlers |
| `aggregator_nvs.h` | NVS satellite persistence (Phase D) |
| `aggregator_proxy.h` | History/live proxy handlers |
| `data_ingest.h` | `/api/ingest` handler and system metric support |

### Constraint

All files must remain header-only (ESPHome YAML `lambda` includes don't support separate compilation units). The split is organizational, not architectural — it uses `#include` to compose the pieces.

### Phase D Consideration

Phase D should write new code (NVS functions, management endpoints) in a style that would survive this split — group related functions together, use consistent naming prefixes, and avoid implicit dependencies on function ordering within the file.

---

## 5. Dense Array Compaction After Delete

### The Problem

Phase D introduces `DELETE /api/aggregator/satellite/{id}`, which removes a satellite from `satellite_caches[]` and shifts remaining entries down to fill the gap. After deletion, every satellite at an index > the deleted slot gets a new index.

### The Invariant

**No code anywhere in the system may cache a satellite's array index and assume it remains stable across add/delete operations.**

### Current Safety

- The dashboard uses satellite IDs (strings), not indices — browser side is safe
- The polling task iterates `for (int i = 0; i < runtime_satellite_count; i++)` on each cycle — indices are re-derived each iteration
- API handlers similarly iterate fresh each request

### Audit Checklist for Phase D Prompts

Every Phase D prompt must verify:

1. No variable stores a satellite index that persists across function calls
2. No NVS key scheme depends on stable indices (the `s0_`, `s1_` keys are positional and must be fully rewritten on delete)
3. No log message caches an index for later correlation
4. The settings panel re-fetches the gateway list after any mutation (no client-side index caching)
5. The proxy handler resolves satellite by ID, not by index

### Alternative Considered

Using a stable slot assignment (mark-as-empty rather than compact) would avoid the compaction problem but introduces "holes" — every loop must skip empty slots, the NVS representation becomes sparse, and `runtime_satellite_count` no longer equals the number of valid entries. The dense-array approach is simpler and correct as long as the "no cached indices" invariant holds.

---

## 6. Factory Reset Endpoint

### Requirement

Phase D should include a reset-to-defaults mechanism for the aggregator satellite config:

```
POST /api/system/reset-satellites
```

Behavior:
1. Clear the `agg_sats` NVS namespace entirely
2. Reload from compile-time defaults
3. Restart the polling task with the compile-time satellite list
4. Return `200 {"ok": true, "message": "Reset to compile-time defaults", "satellite_count": N}`

### Why This Matters

NVS data survives normal firmware flashing (`esptool.py write_flash`). If a user corrupts their satellite config (adds invalid entries, fills the list, triggers a bug), the only current recovery is `esptool.py erase_flash` — which wipes WiFi credentials, history, and everything else.

A targeted reset endpoint allows recovery without full erasure.

### Implementation Note

This can be extended in Phase 7 to clear history namespaces, and in Phase 8 to clear notification rules. The endpoint design should accommodate namespace-specific resets:

```
POST /api/system/reset-satellites    → clear agg_sats only
POST /api/system/reset-history       → clear history namespaces (Phase 7)
POST /api/system/factory-reset       → clear everything (Phase 8)
```

---

## 7. Dashboard JS/HTML Unification

### Current State

`dashboard.js` and `dashboard.html` must be kept in sync manually (LESSON-OPS-043). Every dashboard feature change requires editing both files. The mirroring is a known source of bugs and review burden.

### Recommended Approach (Phase 8)

Collapse to a single source file (`dashboard.js`) and use a build step to generate `dashboard.html`:

1. `dashboard.js` is the single source of truth for all JS logic
2. A build script injects the JS into an HTML template to produce `dashboard.html`
3. `generate-header.sh` then compresses `dashboard.html` to produce `dashboard.h`

### Phase D Consideration

Phase D adds the most complex dashboard JS yet (forms, buttons, dynamic list updates, confirmation dialogs). Write this code in `dashboard.js` first, then mirror to `dashboard.html` as today. The Phase 8 unification should not require rewriting Phase D's code — it should be a mechanical extraction.

---

## 8. Aggregator Code Volume and the Overlay Model

### Current Model

LESSON-OPS-074 established that aggregator boot must be "satellite boot + overlay," not a fork. The `#if AGGREGATOR_ENABLED` guards implement this cleanly.

### Trajectory

Phase D adds ~500-800 lines of aggregator-only code (NVS, management endpoints, runtime mutation). Phase 7 is mostly shared (persistence applies to both roles). Phase 8 notification rules may add another 500+ lines.

By Phase 8, the aggregator-only code volume may approach or exceed the satellite code volume. At that point, the "overlay" mental model becomes misleading — it's effectively two applications sharing a core library.

### Recommendation

Monitor the code ratio at each phase boundary. If aggregator-only code exceeds 60% of total `sensor_history_multi.h` logic, re-evaluate the organizational model. The file split (§4) helps regardless of the model.

The "satellite is a subset of aggregator" principle remains correct regardless of code volume — a satellite should always be able to run on the aggregator's firmware with the aggregator features simply dormant. This is a compatibility guarantee, not an organizational constraint.

---

_End of document._
