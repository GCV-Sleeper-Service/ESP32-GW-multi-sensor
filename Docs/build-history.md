# Build History

Curated ledger of accepted builds. Raw build logs are in `build-logs/` (local) or GitHub Actions artifacts (cloud).

## v7.4.4.0 — 2026-03-12

- **Change:** Configurable sensor count infrastructure — preflight checks, multi-variant fixtures, sensor-count smoke tests, CI matrix, documentation
- **Preflight:** ~42 checks (up from ~30 at v7.4.3.0; 12 new sensor-count checks)
- **Compile:** Not required — no firmware or C++ logic changes (default 3-sensor build unchanged)
- **Flash:** Unchanged — device still running v7.4.2.0 firmware
- **Browser tests:** 28/28 PASS baseline (3sensor) + sensor-count smoke suite PASS for 1/2/4sensor variants
- **CI:** Matrix browser tests expected PASS on PR
- **Workflow:** Branch `feature/configurable-sensor-count`, merge to `main` via PR
- **Status:** ⏳ Pending device validation (optional — no firmware changed)

---

## v7.4.3.0 — 2026-03-11

- **Change:** Playwright browser regression test suite (test infrastructure only — no firmware change)
- **Preflight:** PASS (26/26 — 3 new checks added: `single_script_tag`, `max_history_range_consistent`, `test_infrastructure`)
- **Compile:** Not required — no firmware or YAML changes
- **Flash:** ~86.8% (unchanged — device still running v7.4.2.0)
- **RAM:** ~15.8% (unchanged)
- **Browser tests:** 28/28 PASS (required 2 CI fix iterations: element ID mismatches → DOM behavior mismatches)
- **CI:** PASS (both `build.yml` and new `browser-tests.yml`)
- **Workflow:** Branch `feature/playwright-tests`, merged to `main` via PR #5, tagged v7.4.3.0
- **Status:** ✅ Accepted, merged to main, tagged v7.4.3.0

---

## v7.4.2.0 — 2026-03-11

- **Change:** Custom Date Range Selector (dashboard-only); BUG-017 fix (MAX_HISTORY_RANGE_HOURS 720→1080); BUG-018 fix (duplicate script tag); BUG-019 fix (availability display)
- **Preflight:** PASS (23/23)
- **Compile:** PASS
- **Flash:** ~86.8% (up from 86.1% at v7.4.1.0 — new feature code net +0.7%)
- **RAM:** ~15.8%
- **CI:** PASS (GitHub Actions)
- **Device test (LAN):** PASS — dashboard loads, Custom button opens dialog, presets apply correctly, calendar navigable, Apply updates charts
- **Workflow:** Branch `feature/custom-date-range`, merged to `main`, tagged v7.4.2.0
- **Status:** ✅ Accepted, merged to main, tagged v7.4.2.0

---

## v7.4.1.0 — 2026-03-10

- **Change:** Dashboard minification pipeline (html-minifier-terser, auto-detect in generate-header.sh, CI integration)
- **Preflight:** PASS (23 checks)
- **Compile:** PASS
- **Flash:** ~86.1% (down from ~88.2% at v7.4.0.2 — ~40KB savings from minification)
- **CI:** PASS (GitHub Actions)
- **Device test (LAN):** PASS — dashboard loads, all sensors display, charts render, theme toggle works, export present
- **Workflow:** Branch `feature/custom-date-range`, merged to `main`, tagged v7.4.1.0
- **Status:** ✅ Accepted, merged to main, tagged v7.4.1.0

---

## v7.4.0.2 — 2026-03-09

- **Change:** Single-sensor non-destructive import (firmware + dashboard)
- **Preflight:** PASS (23 checks)
- **Compile:** Validated as part of v7.4.1.0 build chain
- **Device test (LAN):** Validated as part of v7.4.1.0 — single-sensor import merge confirmed working
- **Device test (Cloudflare):** Validated as part of v7.4.1.0
- **Workflow:** Built on top of v7.4.0 merged codebase; rolled into v7.4.1.0 feature branch
- **Status:** ✅ Accepted (validated through v7.4.1.0 build)

---

## v7.4.0 — 2026-03-09 (merged via PR #2)

- **Change:** Import v1 — CSV import via URL-path transport
- **Preflight:** PASS (23 checks including 4 new import checks)
- **Compile:** PASS
- **RAM:** ~15.8%
- **Flash:** ~88.2%
- **Build time:** ~16.5s (incremental), longer on sdkconfig changes
- **CI:** PASS (GitHub Actions, PR #2)
- **Device test (LAN):** PASS — multi-sensor import: 135 segments, 2988 accepted
- **Device test (Cloudflare):** PASS — import succeeded after stabilization (pacing/retry)
- **Workflow:** Feature branch with multiple fix iterations (transport redesign)
- **Status:** ✅ Merged to main via PR #2

---

## v7.3.5.0 — 2026-03-08

- **Change:** Added `/api/status` endpoint; fixed JSON truncation bug
- **Preflight:** PASS
- **Compile:** PASS
- **CI:** PASS (GitHub Actions, PR #1)
- **Device test:** PASS — complete valid JSON via `curl /api/status`
- **RAM:** ~15.8%
- **Flash:** ~87.5%
- **Status:** ✅ Accepted, merged to main, tagged

---

## v7.3.4.2 — 2026-03-07

- **Change:** Dashboard hotfix + repo normalization
- **Preflight:** PASS
- **Compile:** PASS
- **RAM used:** 51656 / 327680
- **Flash used:** 1547200 / 1769472
- **Build time:** 215.72s
- **Status:** ✅ Accepted, merged, tagged — baseline for GitHub-first workflow

---


