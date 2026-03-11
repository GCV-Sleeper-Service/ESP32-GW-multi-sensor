# Build History

Curated ledger of accepted builds. Raw build logs are in `build-logs/` (local) or GitHub Actions artifacts (cloud).

---

## v7.4.1.0 — 2026-03-10

- **Change:** Dashboard minification pipeline (html-minifier-terser, auto-detect in generate-header.sh, CI integration)
- **Preflight:** PASS (23 checks)
- **Compile:** PASS
- **Flash:** ~86% (down from ~88.2% at v7.4.0.2 — ~40KB savings from minification)
- **CI:** PASS (GitHub Actions)
- **Device test (LAN):** PASS — dashboard loads, all sensors display, charts render, theme toggle works, export present
- **Workflow:** Branch `feature/custom-date-range`, merged to `main`
- **Status:** Accepted, merged to main, tagged v7.4.1.0

---

## v7.4.0.2 — 2026-03-09 (pending build/test)

- **Change:** Single-sensor non-destructive import (firmware + dashboard)
- **Preflight:** PASS (23 checks)
- **Compile:** PENDING
- **Device test (LAN):** PENDING — single-sensor import merge, multi-sensor import regression
- **Device test (Cloudflare):** PENDING
- **Workflow:** Built on top of v7.4.0 merged codebase
- **Status:** Code complete, awaiting compile + device validation

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
- **Status:** Merged to main via PR #2

---

## v7.3.5.0 — 2026-03-08

- **Change:** Added `/api/status` endpoint; fixed JSON truncation bug
- **Preflight:** PASS
- **Compile:** PASS
- **CI:** PASS (GitHub Actions, PR #1)
- **Device test:** PASS — complete valid JSON via `curl /api/status`
- **RAM:** ~15.8%
- **Flash:** ~87.5%
- **Status:** Accepted, merged to main, tagged

---

## v7.3.4.2 — 2026-03-07

- **Change:** Dashboard hotfix + repo normalization
- **Preflight:** PASS
- **Compile:** PASS
- **RAM used:** 51656 / 327680
- **Flash used:** 1547200 / 1769472
- **Build time:** 215.72s
- **Status:** Accepted, merged, tagged — baseline for GitHub-first workflow
