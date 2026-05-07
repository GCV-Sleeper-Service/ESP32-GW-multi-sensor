# Current Project State

_Last verified: 2026-05-07 — Phase VY complete (review incorporation done)_
_Next action: Multi-phase planning session → Phase 7_

---

## Version and Phase

- **Current version:** 7.6.10.4
- **Active phase:** Phase VY (methodology audit — in progress)
- **Last completed phase:** Phase VX (board onboarding + auth refactor, 4 steps, 3 PRs)
- **Next implementation phase:** Phase 7 (per-device persistence engine)
- **ESPHome version:** 2026.4.1 (ESP-IDF 5.5.4, upgraded in Phase VX v7.6.10.0)

## What Just Shipped (last 3 steps)

| Step | PR | Summary |
|---|---|---|
| v7.6.10.4 | #202 | Dashboard auth refactor: `authFetch()` wrapper, auth modal, eliminated browser native auth dialogs |
| v7.6.10.1 | #201 | Board profiles for S3 SuperMini, C6 SuperMini, C5 WROOM-1U; partition tables for all 6 boards |
| v7.6.10.0 | #200 | ESPHome 2026.4.1 upgrade; local component override re-applied; measurement protocol |

## What's Next

1. **Multi-phase planning session** — Rewrites Phase 7 plan against current codebase, scopes Phases 8-10. Reads planning supplement, feature roadmap, CURRENT-STATE.md.
2. **Phase 7 Step -1** — ESPHome component defaults audit (new template to be created).
3. **Phase 7 Step 0** — Measurement baseline + health-check telemetry task (BUG-075-076 recommendation, never implemented). Also: file-size watchdog, KPI log schema, PR template, prompt-production rules.
4. **Phase 7 Step 1** — Chunked HTTP streaming for history (fixes BUG-082 / issue #139).
5. **Phase 7 Steps 2+** — Per-device persistence engine (rewritten plan, original from 2026-03-19 is stale).

## Open Issues (by severity)

| Issue | Severity | Description | Target |
|---|---|---|---|
| #139 / BUG-082 | **Critical** | History export crashes C3 and WROOM after ~3 weeks of data. `csv.reserve()` doesn't truncate; NVS scan grows string past cap. Both boards' dashboards unusable when history is large. | Phase 7 Step 1 |
| BUG-084 | High | Non-PSRAM boards crash under 8 concurrent HTTP connections. Safe limit: 4 concurrent. | Phase 7 (socket limit config) |
| #137 | Low | Board-type SVG diagrams for documentation. Cosmetic. | Phase 7+ or standalone |
| A-004 | Medium | C5 WROOM-1U BLE non-functional — external IPEX antenna not attached. Re-test pending. | Before Phase 7 |
| C6 flash | Medium | C6 SuperMini uses 91.6% of OTA partition on 4MB flash. Phase 7 firmware growth may exceed. | Phase 7 planning |

## Board Fleet and Measurements

_Source: `Docs/board-measurement-log-v7.6.10.md` (2026-05-05)_

| Board | IP | Chip | PSRAM | free_heap (boot) | min_free_heap | httpd_wm | Role |
|---|---|---|---|---|---|---|---|
| C3 SuperMini | .189 | ESP32-C3 | None | 58,456 | 47,616 | 12,924 | Satellite (production) |
| WROOM-32D | .190 | ESP32 | None | 38,760 | 15,936 | 13,188 | Satellite (production) |
| S3 DevKitC N16R8 | .191 | ESP32-S3 | 8 MB | 53,432 | 8,398,704 | 10,036 | Aggregator (production) |
| S3 SuperMini | .173 | ESP32-S3 | 2 MB | 123,156 | 2,209,636 | 12,512 | Test (marginal aggregator) |
| C6 SuperMini | .184 | ESP32-C6 | None | 150,332 | 152,820 | 12,820 | Test (flash-constrained) |
| C5 WROOM-1U | .180 | ESP32-C5 | 8 MB | 32,908 | 8,420,784 | 12,728 | Test (BLE pending A-004) |

Credentials: `ESPadmin` / `ESPpass100`

## Unimplemented Recommendations

_Items from postmortems or phase closures that have NOT been acted on._

| Source | Recommendation | Status |
|---|---|---|
| BUG-075-076 postmortem | Add periodic health-check task logging stack HWM, heap stats, socket usage, NVS stats | **Not implemented** — promote to Phase 7 Step 0 |
| BUG-075-076 postmortem | Monitor `nvs_get_stats()` for partition pressure | **Not implemented** |
| BUG-075-076 postmortem | Monitor socket exhaustion under load via lwIP counters | **Not implemented** |
| BUG-075-076 postmortem | Audit ESPHome component defaults for hardcoded-too-small values | **Not implemented** — proposed as Phase 7 Step -1 |
| Phase V closure | Show `min_free_heap` instead of `free_heap` on dashboard | **Not implemented** — deferred post-v7.6.9.0 |
| v7.6.10.4 session log | 10 prompt recommendations for writing guide | **Not implemented** — pending Phase VY |

## Stale Documents Requiring Update Before Use

| Document | Written | Issue |
|---|---|---|
| `Docs/v7.7-implementation-plan.md` | 2026-03-19 | References `dashboard/sensor_history_multi.h` directly (now generated artifact). References `dashboard/dashboard.js` (now generated). Does not know about `firmware/core/` fragments, `authFetch()`, 6-board fleet, `external_components` requirement. **Must be rewritten before Phase 7.** |
| `Docs/v7.7-v7.8-persistence-architecture.md` | 2026-03-19 | Memory budget uses pre-Phase-V estimates. Struct sizes may need recalculation against current data model. |
| Feature roadmap (`future-plans.md`) | 2026-03-12 | Not in repo. v7.4-7.6 items are complete. Needs reconciliation with current phase numbering. |

## Architecture Quick Reference

- **Firmware:** 8 C++ fragments in `firmware/core/`, assembled by `scripts/assemble-sensor-history.sh` → `dashboard/sensor_history_multi.h` (generated, never edit directly)
- **Dashboard:** 12 core modules in `dashboard/core/`, 9 component directories in `dashboard/components/`, built by `scripts/bundle-dashboard.sh` → `dashboard/dashboard.js` and `dashboard/dashboard.html` (generated, never edit directly)
- **Pipeline:** `provision.sh <role>` → `assemble-sensor-history.sh` → `render_sensor_config.py` → `bundle-dashboard.sh` → `build-dashboard.sh` → `minify-dashboard.sh` → `generate-header.sh` → `esphome compile` → `esphome upload`
- **Auth:** Application-level via `dashboard/core/auth.js` with `authFetch()` wrapper. Management endpoints require Basic Auth. `/api/status` is public.
- **Tests:** ~370+ Playwright tests across 12 spec files, 4 fixture sets (3sensor, mixed, system, aggregator)
- **Httpd stack:** Uniform 16 KB via local component override in `firmware/local_components/web_server_idf/`. Must re-apply after ESPHome upgrades via `scripts/patch-esphome-httpd-stack.sh`.

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
