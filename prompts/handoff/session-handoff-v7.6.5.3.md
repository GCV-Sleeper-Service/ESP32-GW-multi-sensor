# Session Handoff — v7.6.5.3: Make Generated HTML Canonical; Retire Manual Mirror (Phase X Level 2)

_Date: 2026-04-05_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.5.2 COMPLETE. Template and build script proven. Bit-for-bit gate passed. Entering Level 2 closure._

---

## Project State Summary

**v7.6.5.2 is complete.** `dashboard.tmpl.html` exists, `build-dashboard.sh` generates byte-for-byte identical HTML. The build pipeline is proven. `main` is green, 402/0 tests.

### What v7.6.5.2 proved

- Template injection produces output identical to the hand-maintained file
- The `build-dashboard.sh` script works reliably in `--write` and `--check` modes
- No whitespace drift between template+JS injection and the original HTML

### Why v7.6.5.3 is the highest-value single step in Phase X

This step eliminates LESSON-OPS-043 — the requirement to manually mirror every JS change from `dashboard.js` to `dashboard.html`. This failure class has caused multiple bugs (BUG-039 and others) and added overhead to every dashboard PR since Phase 2. After this step, `dashboard.html` is a build artifact. The mirror problem is structurally impossible.

---

## Phase X Progress Table

| Version | Scope | Level | Status |
|---------|-------|-------|--------|
| v7.6.4.0 | Documentation restructuring | Pre-step | ✅ Complete |
| v7.6.5.0 | Module split | Level 1 | ✅ Complete |
| v7.6.5.1 | CI + preflight wiring | Level 1 | ✅ Complete |
| v7.6.5.2 | Template creation | Level 2 | ✅ Complete |
| **v7.6.5.3** | **Retire manual mirror** | **Level 2** | **⬅️ Next** |
| v7.6.5.4–v7.6.5.6 | Component model (Level 3) | Level 3 | Pending |
| v7.6.5.7–v7.6.5.8 | Test split + closure | Test/Closure | Pending |

---

## v7.6.5.3 Scope

Four changes plus device testing:

### 1. Add `build-dashboard.sh` step to CI workflow

In `.github/workflows/browser-tests.yml`, add `bash scripts/build-dashboard.sh --check` after the bundle check and before Playwright.

### 2. Add `<!-- GENERATED -->` header to `dashboard.html`

Modify `build-dashboard.sh` to prepend a generated-file marker to its output:

```html
<!-- GENERATED — Do not edit. Source: dashboard/src/*.js + dashboard.tmpl.html -->
```

After this change, `dashboard.html` has one extra line compared to the v7.6.5.2 output. The acceptance gate shifts from "bit-for-bit match to original" to "`build-dashboard.sh --check` passes."

### 3. Update `scripts/bump-version.sh`

Remove the `sed` command that directly edits `dashboard.html` (~line 66). Replace with pipeline re-run:

```bash
bash scripts/bundle-dashboard.sh --write
python3 scripts/render_sensor_config.py --write
bash scripts/build-dashboard.sh --write
```

The version bump now flows through the pipeline: `bump-version.sh` updates version strings in source modules → bundle → generator → build-html.

### 4. Add `dashboard_html_matches_build` preflight check

Runs `build-dashboard.sh --check` to verify the committed `dashboard.html` matches the build output.

### 5. ⚠️ DEVICE TESTING REQUIRED

**Migration Safety Rule 11:** Before and after this step, load the dashboard on a real device and verify:
- Page loads in the browser
- SSE/polling connects and data flows
- Charts render with live data
- Management actions work (if testing on the aggregator)

This is the point where `dashboard.html` transitions from hand-maintained to generated. Device testing confirms the generated output renders correctly on real hardware.

---

## What This Step Permanently Eliminates

| Before v7.6.5.3 (every dashboard PR) | After v7.6.5.3 |
|---------------------------------------|----------------|
| Edit `dashboard/src/<module>.js` | Edit `dashboard/src/<module>.js` |
| Run `bundle-dashboard.sh --write` | Run `bundle-dashboard.sh --write` |
| **Manually copy JS change to `dashboard.html`** | **(eliminated — `build-dashboard.sh` does this)** |
| Risk: forgot the mirror → fixup commit | Risk: **impossible** — `dashboard.html` is not a source file |

### Updated canonical pipeline (final Level 2 form)

```
1. python3 scripts/render_sensor_config.py --write
2. node tests/fixtures/generate-fixtures.js
3. bash scripts/bundle-dashboard.sh --write
4. python3 scripts/render_sensor_config.py --write   ← re-inject markers
5. bash scripts/build-dashboard.sh --write             ← template + JS → dashboard.html
6. bash scripts/minify-dashboard.sh
7. bash scripts/generate-header.sh
8. python3 scripts/render_sensor_config.py --check
```

---

## Pre-merge Checklist for v7.6.5.3

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] Verify `build-dashboard.sh --check` passes after changes
- [ ] Verify `bump-version.sh` no longer uses `sed` on `dashboard.html`
- [ ] Verify `<!-- GENERATED -->` header appears in `dashboard.html`
- [ ] Verify LESSON-OPS-043 resolution note added to `Docs/lessons/dashboard.md`
- [ ] Run CI-exact Playwright across all fixture sets
- [ ] Run preflight (including new `dashboard_html_matches_build` check)
- [ ] **⚠️ Device testing:** Load dashboard on real device, verify rendering and functionality
- [ ] Confirm no source module content was modified (only pipeline/CI/docs)

---

## Critical Rules Relevant to v7.6.5.3

| # | Rule | Why Relevant |
|---|------|-------------|
| 4 | Preflight must pass | New HTML-matches-build check |
| 5 | CI-exact `FIXTURE_SET=` runs | Full acceptance gate |
| 6 | Mirror JS ↔ HTML | **Being structurally resolved this step** |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 37 | Full regeneration pipeline | Pipeline now canonical with build-dashboard.sh |
| 38 | POST semantics | Preserved through template injection |

---

## Workflow for v7.6.5.3

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR
> for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for
> clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for this step is open. If PR has not been open, **open a NEW coding agent session outside of this chat** and paste the prompt
3. Agent updates CI, build script, bump-version, preflight, and docs
4. Review the PR:
   - `bump-version.sh` no longer has `sed` targeting `dashboard.html`
   - CI workflow has `build-dashboard.sh --check` in the correct position
   - LESSON-OPS-043 resolution documented
5. Merge, tag `v7.6.5.3`
6. **Execute device testing** — load dashboard on real ESP32, verify full functionality
7. Produce consolidated audit and lessons file (see Post-PR Closure section below)
8. Check and update session handoff for v7.6.5.4 if necessary (see Post-PR Closure section below)
9. Check and update agent's prompt for v7.6.5.4 if necessary (see Post-PR Closure section below)
---

## Post-PR Closure Deliverables for v7.6.5.3

### 1. Consolidated Audit
**File:** `prompts/phaseX/v7.6.5.3-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseX/pr-audit-question-template.md`
**Format:** Same structure as `prompts/phaseX/v7.6.4.0-PR131-consolidated-audit-and-lessons.md`

Use stable core questions from `prompts/phaseX/pr-audit-question-template.md`  plus Level-Specific Supplements for Level 2:
- Does `bump-version.sh` now use the pipeline instead of `sed` on `dashboard.html`?
- Did the `<!-- GENERATED -->` header get added?
- Does `build-dashboard.sh --check` pass?
- **Was device testing confirmed?**

### 2. Gate Check: Level 2 → Level 3

After v7.6.5.3 merges and device testing passes, verify the Level 2 → Level 3 gate condition:
- CI green
- Bit-for-bit gate passed (at v7.6.5.2)
- Device testing confirmed
- LESSON-OPS-043 marked as structurally resolved

If all pass, Level 3 (v7.6.5.4) can proceed.

### 3. Optional Early Stop Assessment

v7.6.5.3 is the **minimum viable refactor** endpoint. If the project needs to start Phase 7 urgently, Level 1 + Level 2 already deliver:
- Module-scoped editing (~5K–8K tokens per task instead of ~55K–70K)
- Mirror problem eliminated
- CI enforcement of bundle and build sync

Level 3 adds component-level ownership (self-contained directories, CSS extraction) which scales better for Phase 7/E but is not strictly required. Assess at this point whether to continue to Level 3 or proceed to Phase 7.

### 4. Session Handoff for v7.6.5.4

**File:** `prompts/handoff/session-handoff-v7.6.5.4.md` is already produced,  if this or previous steps reveals something unexpected, provide a patch for this and future step handoff files if necessary.  

### 5. Check Agent's prompt for v7.6.5.4

**File:** `prompts/phaseX/v7.6.5.4-implementation-instructions-for-coding-agent.md` is already produced, provide a patch for this and future step prompts files if necessary.  

---

## Device Testing Protocol

### Hardware

- S3 aggregator at 192.168.120.191 (primary test target — exercises aggregator overlay)
- C3 satellite at 192.168.120.189 (optional — satellite-mode baseline)

### Test sequence

```bash
# 1. Flash the aggregator with post-v7.6.5.3 firmware
# (Only needed if dashboard.h changed — check SHA-256 of dashboard.h before and after)
# If dashboard.h is unchanged, the firmware serves identical content — no reflash needed.

# 2. Load dashboard in browser
open http://192.168.120.191/

# 3. Verify basics
# - Page loads without errors (check browser console)
# - Status bar shows device info
# - Sensor cards appear with data

# 4. Verify SSE/polling
# - Data updates appear (temperature, humidity values change)
# - Charts render with data points

# 5. Verify aggregator features (if on aggregator device)
# - Gateway selector shows satellites
# - Settings panel loads
# - Test/Add/Remove satellite buttons are functional

# 6. Verify management actions
# - Reboot button triggers reboot
# - Device recovers and dashboard reconnects
```

### Expected outcome

All functionality identical to pre-Phase-X behavior. No visual differences. No console errors. This confirms the generated `dashboard.html` serves correctly from the ESP32.

---

_End of session handoff document._
