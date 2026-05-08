# Current Project State

_Last verified: 2026-05-08 — v7.7.1.1 validation complete_
_Next action: Phase 7 Step v7.7.1.2 — per-device structs, key scheme, and hash function_

---

## Version and Phase

- **Current version:** 7.7.1.1
- **Active phase:** Phase 7 implementation underway
- **Last completed phase:** Phase VX (board onboarding + auth refactor, 4 steps, 3 PRs)
- **Next implementation phase:** Phase 7 (per-device persistence engine)
- **ESPHome version:** 2026.4.1 (ESP-IDF 5.5.4, upgraded in Phase VX v7.6.10.0)

## What Just Shipped (last 3 steps)

| Step | PR | Summary |
|---|---|---|
| v7.7.1.1 | #226 | History endpoints now stream CSV with `httpd_resp_send_chunk()`, fixing BUG-082 heap exhaustion on larger retained history sets; follow-up preserved aggregator proxy compatibility and restored NI-002 `HEALTH:` evidence on WROOM/C3 |
| v7.7.1.0 | #225 | Health-check telemetry task added as a ninth firmware fragment; boot startup, assembly, and preflight updated for periodic heap/NVS/stack telemetry |
| v7.6.10.4 | #202 | Dashboard auth refactor: `authFetch()` wrapper, auth modal, eliminated browser native auth dialogs |

## What's Next

1. **Phase 7 Step v7.7.1.2** — Per-device structs, key scheme, hash function.
2. **Phase 7 Step v7.7.1.3** — Per-device persist engine (write path).
3. **Phase 7 Step v7.7.1.4** — Per-device restore engine (boot path) + retention budget.
4. **Phase 7 Steps v7.7.2.1–v7.7.3.3** — Engine switchover, migration, export/import, and closure.
5. **Phase 7 optimization sprint v7.7.5.x** — NVS dedup study, RAM window reduction.

## Open Issues (by severity)

| Issue | Severity | Description | Target |
|---|---|---|---|
| BUG-084 | High | Non-PSRAM boards crash under 8 concurrent HTTP connections. Safe limit: 4 concurrent. | Phase 7 (socket limit config) |
| #137 | Low | Board-type SVG diagrams for documentation. Cosmetic. | Phase 7+ or standalone |
| A-004 | Medium | C5 WROOM-1U BLE non-functional — external IPEX antenna not attached. Re-test pending. | Before Phase 7 |
| C6 flash | Medium | C6 SuperMini uses 91.6% of OTA partition on 4MB flash. Phase 7 firmware growth may exceed. | Phase 7 planning |

## Recently Resolved

| Issue | Version | Resolution |
|---|---|---|
| #139 / BUG-082 | v7.7.1.1 | Replaced full-CSV-in-RAM history responses with chunked HTTP streaming in `handle_history_()` and `handle_api_v2_history_()`, kept aggregator proxy compatibility by dechunking upstream `/api/v2/history`, and restored NI-002 `HEALTH:` validation coverage on WROOM/C3. |

## Phase 7 Device Validation Snapshot

_Observed on 2026-05-08 after flashing v7.7.1.1 production builds._

| Metric | v7.7.1.0 baseline (C3) | v7.7.1.1 (C3 observed) | Delta |
|---|---|---|---|
| `heap_free` | 39,704 B | 52,080 B | +12,376 B |
| `min_free` | 29,776 B | 48,096 B | +18,320 B |
| `httpd_stack_wm` | 12,932 B | 11,976 B | -956 B |
| `hc_stack_wm` | 2,176 B | 2,308 B | +132 B |

## Board Fleet and Measurements

_Source: `Docs/board-measurement-log-v7.6.10.md` (2026-05-05)_

| Board | IP | Chip | PSRAM | free_heap (boot) | min_free_heap | httpd_wm | Role |
|---|---|---|---|---|---|---|---|
| C3 SuperMini | .189 | ESP32-C3 | None | 58,456 | 47,616 | 12,924 | Satellite (production) |
| WROOM-32D | .170 | ESP32 | None | 38,760 | 15,936 | 13,188 | Satellite (production) |
| S3 DevKitC N16R8 | .191 | ESP32-S3 | 8 MB | 53,432 | 8,398,704 | 10,036 | Aggregator (production) |
| S3 SuperMini | .173 | ESP32-S3 | 2 MB | 123,156 | 2,209,636 | 12,512 | Test (marginal aggregator) |
| C6 SuperMini | .184 | ESP32-C6 | None | 150,332 | 152,820 | 12,820 | Test (flash-constrained) |
| C5 WROOM-1U | .180 | ESP32-C5 | 8 MB | 32,908 | 8,420,784 | 12,728 | Test (BLE pending A-004) |

Credentials: `ESPadmin` / `ESPpass100`

## Unimplemented Recommendations

_Items from postmortems or phase closures that have NOT been acted on._

| Source | Recommendation | Status |
|---|---|---|
| BUG-075-076 postmortem | Add periodic health-check task logging stack HWM, heap stats, socket usage, NVS stats | **Partially implemented in v7.7.1.0** — heap, stack HWM, NVS stats, and uptime now logged; socket counters remain deferred |
| BUG-075-076 postmortem | Monitor `nvs_get_stats()` for partition pressure | **Implemented in v7.7.1.0** |
| BUG-075-076 postmortem | Monitor socket exhaustion under load via lwIP counters | **Not implemented** |
| BUG-075-076 postmortem | Audit ESPHome component defaults for hardcoded-too-small values | **Not implemented** — proposed as Phase 7 Step -1 |
| Phase V closure | Show `min_free_heap` instead of `free_heap` on dashboard | **Not implemented** — deferred post-v7.6.9.0 |
| v7.6.10.4 session log | 10 prompt recommendations for writing guide | **Not implemented** — pending Phase VY |

## Stale Documents Requiring Update Before Use

| Document | Written | Issue |
|---|---|---|
| `Docs/v7.7-implementation-plan.md` | 2026-03-19 | **Superseded** by `Docs/phase-7-review-and-rewrite.md` (2026-05-07). Keep for historical reference. |
| `Docs/v7.7-v7.8-persistence-architecture.md` | 2026-03-19 | Architecture decisions still valid. Memory budget (§15) needs measured values from board-measurement-log. Update during Phase 7 prompt production. |


## Architecture Quick Reference

- **Firmware:** 9 C++ fragments in `firmware/core/`, assembled by `scripts/assemble-sensor-history.sh` → `dashboard/sensor_history_multi.h` (generated, never edit directly)
- **Dashboard:** 12 core modules in `dashboard/core/`, 9 component directories in `dashboard/components/`, built by `scripts/bundle-dashboard.sh` → `dashboard/dashboard.js` and `dashboard/dashboard.html` (generated, never edit directly)
- **Pipeline:** `provision.sh <role>` → `assemble-sensor-history.sh` → `render_sensor_config.py` → `bundle-dashboard.sh` → `build-dashboard.sh` → `minify-dashboard.sh` → `generate-header.sh` → `esphome compile` → `esphome upload`
- **Auth:** Application-level via `dashboard/core/auth.js` with `authFetch()` wrapper. Management endpoints require Basic Auth. `/api/status` is public.
- **Tests:** ~370+ Playwright tests across 12 spec files, 4 fixture sets (3sensor, mixed, system, aggregator)
- **Httpd stack:** Uniform 16 KB via local component override in `firmware/local_components/web_server_idf/`. Must re-apply after ESPHome upgrades via `scripts/patch-esphome-httpd-stack.sh`.


## Planning Documents (2026-05-07 Multi-Phase Session)

| Document | Purpose |
|---|---|
| `Docs/phase-7-review-and-rewrite.md` | Rewritten Phase 7 plan (supersedes v7.7-implementation-plan.md) |
| `Docs/phase-E-captive-portal-plan.md` | Phase E scoping — WiFi provisioning, sensor discovery |
| `Docs/phase-8-notifications-plan.md` | Phase 8 scoping — Telegram, ntfy.sh, threshold alerts |
| `Docs/phase-9-cloud-upload-plan.md` | Phase 9 scoping — InfluxDB, MQTT, store-and-forward |
| `Docs/phase-10-dashboard-ui-plan.md` | Phase 10 scoping — responsive UI, i18n |
| `Docs/board-selection-guide-expansion.md` | Board capability matrix with Phase 7 retention numbers |
| `Docs/multi-phase-planning-session-summary.md` | Full session record including operator feedback incorporation |


## KPI Baselines (for tracking)

| Metric | Phase Y | Phase V | Phase VX |
|---|---|---|---|
| Steps in phase | 9 | 10 (5 planned + 5 mitigation) | 4 |
| Fix cycles per step (avg) | 0.3 | 0.5 | 1.0 |
| Wall-clock per step (est.) | ~2h | ~2.5h | ~3h |
| New bugs discovered | 3 | 5 | 2 |
| New critical rules added | 12 | 8 | 4 |

---

_This file is updated after every merge as a mandatory post-merge deliverable._
_If the "Last verified" date is more than 1 step old, run verification checks before trusting values._
