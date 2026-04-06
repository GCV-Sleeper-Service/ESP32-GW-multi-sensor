# Session Log — v7.6.5.1: Wire Bundle into CI and Preflight

**Date:** 2026-04-06
**Version:** v7.6.5.1
**Scope:** Phase X Level 1 — CI integration of dashboard bundle sync check
**Status:** ✅ Complete

---

## Instruction Compliance Output

| # | Instruction | Code Location | Status |
|---|-------------|---------------|--------|
| 5a | Add `dashboard_js_bundle_sync()` function to `scripts/preflight.sh` | `scripts/preflight.sh:461-468` | ✅ Complete |
| 5a | Function uses `bash scripts/bundle-dashboard.sh --check` | `scripts/preflight.sh:463` | ✅ Complete |
| 5a | Function uses `pass` and `fail` per existing pattern | `scripts/preflight.sh:464,466` | ✅ Complete |
| 5a | Add function call to main check sequence | `scripts/preflight.sh:470` | ✅ Complete |
| 5b | Add `Verify dashboard bundle sync` step to CI workflow | `.github/workflows/browser-tests.yml:51-52` | ✅ Complete |
| 5b | Step runs `bash scripts/bundle-dashboard.sh --check` | `.github/workflows/browser-tests.yml:52` | ✅ Complete |
| 5b | Step positioned after fixture generation, before Playwright | `.github/workflows/browser-tests.yml:51` (after line 49) | ✅ Complete |
| 5c | Update LESSON-OPS-091 in `Docs/lessons/build-pipeline.md` | `Docs/lessons/build-pipeline.md:448-469` | ✅ Complete |
| 5c | Pipeline includes bundle step as Step 1 | `Docs/lessons/build-pipeline.md:460` | ✅ Complete |
| 5c | Pipeline is now six steps | `Docs/lessons/build-pipeline.md:458-465` | ✅ Complete |
| 5d | Update `Docs/aggregator-setup.md` Section 7.1 | `Docs/aggregator-setup.md:113-133` | ✅ Complete |
| 5d | Update fixture regeneration section | `Docs/aggregator-setup.md:325-334` | ✅ Complete |
| 8 | Update `Docs/changelog.md` — add v7.6.5.1 entry | `Docs/changelog.md:5-33` | ✅ Complete |
| N/A | Version bump to v7.6.5.1 | `VERSION`, `scripts/render_sensor_config.py`, `tests/fixtures/generate-fixtures.js`, `dashboard/src/00-app-shell.js` | ✅ Complete |
| N/A | Full regeneration pipeline | Executed | ✅ Complete |
| N/A | Negative case verification | Tested and passed | ✅ Complete |

---

## Pre-condition Checks

All pre-condition checks passed before making changes:

```bash
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=3sensor npx playwright test --project=firefox
FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium
FIXTURE_SET=system npx playwright test --grep "System" --project=chromium
FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
bash scripts/preflight.sh
python3 scripts/render_sensor_config.py --check
bash scripts/bundle-dashboard.sh --check
```

All tests and checks passed on the baseline (`main` at commit 96a061c).

---

## Implementation Summary

### 1. Added `dashboard_js_bundle_sync()` Function

**File:** `scripts/preflight.sh:461-468`

```bash
dashboard_js_bundle_sync() {
  echo "Checking dashboard.js bundle sync..."
  if bash scripts/bundle-dashboard.sh --check; then
    pass "dashboard.js matches source modules"
  else
    fail "dashboard.js is out of sync with source modules — run: bash scripts/bundle-dashboard.sh --write"
  fi
}
```

Function call added at line 470, before the existing Playwright check.

### 2. Added CI Bundle Check Step

**File:** `.github/workflows/browser-tests.yml:51-52`

```yaml
- name: Verify dashboard bundle sync
  run: bash scripts/bundle-dashboard.sh --check
```

Positioned after `Generate fixture variants` (line 49) and before the Playwright browser cache step (line 54).

### 3. Updated LESSON-OPS-091

**File:** `Docs/lessons/build-pipeline.md:448-469`

Updated lesson to reflect the canonical six-step pipeline with bundle as Step 1. Documented the rationale: running the bundler first avoids wiping generator markers.

### 4. Updated Aggregator Setup Documentation

**Files:**
- `Docs/aggregator-setup.md:113-133` — Section 7.1 Full Regeneration Pipeline
- `Docs/aggregator-setup.md:325-334` — Fixture regeneration on version bumps

Both sections now include `bash scripts/bundle-dashboard.sh --write` as Step 1, with explanatory notes about why the bundle step matters.

### 5. Version Bump

Updated version to v7.6.5.1 in:
- `VERSION`
- `scripts/render_sensor_config.py` (line 82)
- `tests/fixtures/generate-fixtures.js` (line 3)
- `dashboard/src/00-app-shell.js` (line 42) — source module updated manually after initial bump

### 6. Changelog Update

**File:** `Docs/changelog.md:5-33`

Added v7.6.5.1 entry with:
- Summary of changes
- Canonical regeneration pipeline (six steps)
- Acceptance criteria checklist

---

## Validation Evidence

### Canonical Regeneration Pipeline

Executed the full six-step pipeline:

```bash
bash scripts/bundle-dashboard.sh --write
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/minify-dashboard.sh
bash scripts/generate-header.sh
python3 scripts/render_sensor_config.py --check
```

**Result:** All steps completed successfully. `render_sensor_config: PASS`

### Negative Case Test

Verified that editing a source module without rebundling triggers preflight failure:

```bash
$ echo "// test" >> dashboard/src/00-app-shell.js
$ bash scripts/bundle-dashboard.sh --check
FAIL: dashboard.js is out of sync with source modules
83d82
< // test

$ git checkout dashboard/src/00-app-shell.js
Updated 1 path from the index
```

✅ **Result:** Check correctly fails when module is edited. After revert, check passes.

### Preflight Output

```
Checking dashboard.js bundle sync...
OK: dashboard.js matches source modules
dashboard.js matches source modules: PASS
```

All 66 preflight checks passed, including the new `dashboard_js_bundle_sync` check.

### Playwright Test Results

Executed CI-exact commands across all four fixture sets:

| Fixture Set | Browser | Command | Result |
|-------------|---------|---------|--------|
| 3sensor | chromium | `FIXTURE_SET=3sensor npx playwright test --project=chromium` | 45 skipped, 99 passed (44.8s) |
| 3sensor | firefox | `FIXTURE_SET=3sensor npx playwright test --project=firefox` | 45 skipped, 99 passed (1.1m) |
| mixed | chromium | `FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium` | 7 passed (3.2s) |
| system | chromium | `FIXTURE_SET=system npx playwright test --grep "System" --project=chromium` | 8 passed (3.1s) |
| aggregator | chromium | `FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium` | 1 skipped, 11 passed (4.5s) |

**Total:** 224 tests passed, 91 skipped, 0 failed

---

## Files Modified

### Code Changes
- `.github/workflows/browser-tests.yml` — Added bundle check step
- `scripts/preflight.sh` — Added `dashboard_js_bundle_sync()` function and call

### Documentation Updates
- `Docs/lessons/build-pipeline.md` — Updated LESSON-OPS-091
- `Docs/aggregator-setup.md` — Updated Sections 7.1 and fixture regeneration
- `Docs/changelog.md` — Added v7.6.5.1 entry

### Version Bump
- `VERSION`
- `scripts/render_sensor_config.py`
- `tests/fixtures/generate-fixtures.js`
- `dashboard/src/00-app-shell.js`

### Generated Artifacts (from pipeline)
- `dashboard/dashboard.js` (bundled from source modules)
- `dashboard/dashboard.html`
- `dashboard/dashboard.h`
- `dashboard/sensor_history_multi.h`
- `firmware/esp32-c3-multi-sensor.yaml`
- `src/gateway_manifest.h`
- `tests/fixtures/*.json` (all fixture variants)

---

## Acceptance Criteria

- [x] CI workflow includes bundle check before Playwright
- [x] `dashboard_js_bundle_sync` preflight check passes on clean tree
- [x] Editing a module without rebundling → preflight FAIL (verified with negative test)
- [x] All 224 Playwright tests pass across all four fixture sets
- [x] `bash scripts/preflight.sh` passes (66/66 checks)

---

## Critical Rules Verified

- **Rule 4:** Preflight must pass — ✅ All checks pass
- **Rule 5:** CI-exact `FIXTURE_SET=` runs — ✅ All four sets tested
- **Rule 20:** Session log mandatory — ✅ This document
- **Rule 21:** Instruction Compliance Output — ✅ Table provided above
- **Rule 37:** Full regeneration pipeline — ✅ Updated in documentation and executed

---

## Post-Implementation Notes

### Key Learning

The version bump script (`bump-version.sh`) updates `dashboard.js` via `render_sensor_config.py --write`, but this happens **after** bundling. With the new module structure, the version must be updated in the **source module** (`dashboard/src/00-app-shell.js`) and then rebundled.

**Correct sequence after version bump:**
1. Run `bash scripts/bump-version.sh 7.6.5.1`
2. Manually update `dashboard/src/00-app-shell.js` with the new version
3. Run `bash scripts/bundle-dashboard.sh --write`
4. Continue with full pipeline

This will be addressed in a future step (likely v7.6.5.2+) when the bundle step is integrated into `bump-version.sh`.

### Pipeline Consolidation

The canonical pipeline is now:

```bash
bash scripts/bundle-dashboard.sh --write          # Step 1 (NEW)
python3 scripts/render_sensor_config.py --write   # Step 2
node tests/fixtures/generate-fixtures.js          # Step 3
bash scripts/minify-dashboard.sh                  # Step 4
bash scripts/generate-header.sh                   # Step 5
python3 scripts/render_sensor_config.py --check   # Step 6
```

Running the bundler first ensures source module changes are reflected before the generator injects markers.

---

## Closure

v7.6.5.1 is complete. All acceptance criteria met. All tests pass. Preflight green. CI integration verified.

**Next step:** v7.6.5.2 — Create `dashboard.tmpl.html` and `build-dashboard.sh` (Phase X Level 2).

---

_End of session log._
