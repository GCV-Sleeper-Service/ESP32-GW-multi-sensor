# Build History

Curated ledger of accepted builds. Only milestone and accepted builds are recorded here. Raw build logs are in `build-logs/` (local) or GitHub Actions artifacts (cloud).

---

## v7.3.5.0 — 2026-03-08

- **Change:** Added `/api/status` endpoint; fixed JSON truncation bug
- **Preflight:** PASS (all checks including new `status_endpoint_present`)
- **Compile:** PASS
- **CI:** PASS (GitHub Actions, PR #1)
- **Device test:** PASS — complete valid JSON via `curl /api/status`
- **RAM:** ~15.8%
- **Flash:** ~87.5%
- **Workflow:** First PR through branch protection + CI gate
- **Status:** Accepted, merged to main

---

## v7.3.4.2 — 2026-03-07

- **Change:** Dashboard hotfix (Export All, recolor, markers, theme redraw) + repo normalization
- **Preflight:** PASS
- **Compile:** PASS
- **RAM used:** 51656 / 327680
- **Flash used:** 1547200 / 1769472
- **Build time:** 215.72s
- **Notes:** Repo normalization validated; canonical build paths confirmed; GitHub Actions CI established
- **Status:** Accepted — baseline for GitHub-first workflow
