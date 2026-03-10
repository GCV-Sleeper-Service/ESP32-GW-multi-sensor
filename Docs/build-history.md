# Build History

Curated ledger of accepted builds. Raw build logs are in `build-logs/` (local) or GitHub Actions artifacts (cloud).

---

## v7.4.0 — 2026-03-09 (pending merge)

- **Change:** Import v1 — CSV import via URL-path transport
- **Preflight:** PASS (23 checks including 4 new import checks)
- **Compile:** PASS
- **RAM:** ~15.8%
- **Flash:** ~88.2%
- **Build time:** ~16.5s (incremental), longer on sdkconfig changes
- **CI:** PASS (GitHub Actions, PR #2)
- **Device test (LAN):** PASS — multi-sensor import: 135 segments, 2988 accepted
- **Device test (Cloudflare):** PENDING — path-based transport untested through tunnel
- **Workflow:** Feature branch with multiple fix iterations (transport redesign)
- **Status:** Pending final Cloudflare tunnel test before merge

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
