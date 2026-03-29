# Session Prompt — Post-Phase-D Completion: Assessment, Phase 7 Preparation, and Documentation Overhaul

_Date created: 2026-03-28_
_To be used: After Phase D (v7.6.0.0–v7.6.0.5) is fully merged to `main`_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_

---

## Your Role

You are the architectural advisor and prompt producer for this ESP32-GW Multi-Sensor BLE Gateway project. The project owner has been executing Phase D (v7.6.0.x — runtime satellite management via NVS) using coding agent prompts that you produced in a previous session. Phase D should now be complete, and the owner is returning for you to:

1. **Verify Phase D completion** — audit what actually shipped
2. **Prepare the ground for Phase 7** — update prompts, documentation, architecture docs
3. **Perform a comprehensive project health check** — catch anything that drifted during the 6-step execution run
4. **Ask the right questions** — surface things the owner should tell you about

---

## Step 0: Clone and Orient

```
Clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
```

Read these files **completely** before doing anything else:

1. `Docs/changelog.md` — scan for v7.6.0.0 through v7.6.0.5 entries. If any are missing, Phase D is not complete.
2. `Docs/bugs-and-lessons-learned.md` — read ALL entries. Look for new LESSON-OPS entries added during Phase D (should be ≥ LESSON-OPS-089+). Count them.
3. `prompts/prompt-index-and-workflow.md` — check Phase D section. All 6 steps should be ✅ Complete with dates.
4. `prompts/phaseD/` — look for PR audit documents (`v7.6.0.x-PR<NN>-consolidated-audit-and-lessons.md`). There should be one per step.
5. `Docs/phase-d-implementation-plan.md` — check if it's been marked complete.
6. `Docs/architecture-forward-looking-notes.md` — check for Phase D updates.
7. `Docs/writing-prompts-for-coding-agents-guide.md` — check for any Phase D additions.
8. `Docs/session-log-archive-v7.5.x.md` or individual session logs — check for v7.6.0.x entries.
9. `VERSION` file — should read a v7.6.0.5 or later version.
10. `dashboard/sensor_history_multi.h` — verify the key Phase D artifacts exist:
    - `runtime_satellite_count` variable
    - `load_satellites_from_nvs_()` function
    - `save_satellites_to_nvs_()` function
    - `save_single_satellite_to_nvs_()` function
    - `init_satellite_caches_()` function (extracted from aggregator_poll_task)
    - `set_identity()` member function on SatelliteCache
    - `handle_reset_satellites_()` handler
    - Working `handle_add_satellite_()` (not 501 stub)
    - Working `handle_delete_satellite_()` (not 501 stub)
    - Working `handle_test_satellite_()` (not 501 stub)
    - All `for` loops using `runtime_satellite_count` instead of `MAX_SATELLITES` (except array declaration)
11. `dashboard/dashboard.js` and `dashboard/dashboard.html` — verify satellite management UI exists (add/remove/test controls in Settings panel)
12. `tests/browser/dashboard.spec.js` — look for Phase D test group(s) covering satellite management endpoints
13. `prompts/phase7/` — read all existing Phase 7 prompts to understand their current state
14. `Docs/v7.7-implementation-plan.md` and `Docs/v7.7-v7.8-persistence-architecture.md` — Phase 7 plan context

---

## Step 1: Phase D Completion Audit

### 1a. Scope Verification

For each v7.6.0.x step, verify the expected deliverables actually shipped:

| Step | Expected Deliverable | How to Verify |
|------|---------------------|---------------|
| v7.6.0.0 | NVS satellite persistence, `runtime_satellite_count`, reset endpoint | `grep -n "runtime_satellite_count" dashboard/sensor_history_multi.h` should show 8+ occurrences. `grep -n "load_satellites_from_nvs_" dashboard/sensor_history_multi.h` should find the function. `grep "reset-satellites" dashboard/sensor_history_multi.h` should find the handler. |
| v7.6.0.1 | Working `POST /api/aggregator/add-satellite` | `grep -n "handle_add_satellite_" dashboard/sensor_history_multi.h` — should be a real implementation, not a 501 stub |
| v7.6.0.2 | Working `DELETE /api/aggregator/satellite/{id}` with array compaction | `grep -n "handle_delete_satellite_\|handle_remove_satellite_" dashboard/sensor_history_multi.h` — real implementation |
| v7.6.0.3 | Working `POST /api/aggregator/test-satellite` with no side effects | `grep -n "handle_test_satellite_\|probe_satellite" dashboard/sensor_history_multi.h` |
| v7.6.0.4 | Dashboard UI for add/remove/test | Search `dashboard/dashboard.js` for satellite management functions — add form, remove button handler, test probe |
| v7.6.0.5 | Playwright tests for satellite management + Phase D closure docs | Check `tests/browser/dashboard.spec.js` for satellite management test group |

### 1b. Regression Check

```bash
# These should all pass — run mentally or ask the owner for results
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=mixed npx playwright test --grep "Mixed" --project=chromium
FIXTURE_SET=system npx playwright test --grep "System" --project=chromium
FIXTURE_SET=aggregator npx playwright test --grep "Aggregator" --project=chromium
bash scripts/preflight.sh
python3 scripts/render_sensor_config.py --check
```

### 1c. Documentation Completeness

Check that each step produced:
- [ ] Session log (`Docs/session-log-*-v7.6.0.x.md` or archived)
- [ ] Changelog entry in `Docs/changelog.md`
- [ ] PR audit document in `prompts/phaseD/`
- [ ] Any new bugs/lessons in `Docs/bugs-and-lessons-learned.md`
- [ ] `prompts/prompt-index-and-workflow.md` updated per step

### 1d. Architecture Contract Verification

Verify these design decisions were respected (they were settled before Phase D):
- [ ] `MAX_SATELLITES` only used for array sizing — not in any loop bound
- [ ] NVS namespace is `"agg_sats"` (not merged with history namespace)
- [ ] Add-satellite uses query parameters, not JSON body
- [ ] Test-satellite has no side effects (no NVS write, no cache mutation)
- [ ] Delete-satellite is by ID, not by index
- [ ] Array compaction happens after delete (no gaps in satellite_caches[])
- [ ] Boot path is still satellite + aggregator overlay (LESSON-OPS-074)
- [ ] `POST /api/system/reset-satellites` endpoint exists and works

---

## Step 2: Questions to Ask the Owner

Before proceeding with Phase 7 preparation, ask the owner these questions:

### Execution Quality Questions
1. **How many fixup commits were needed across Phase D?** (Per step — this indicates prompt quality. v7.5.7.0 needed 1 fixup out of 5 commits. Phase D target: ≤1 fixup per step.)
2. **Were there any steps where the coding agent significantly deviated from the prompt?** If so, which step and what happened?
3. **Did any Phase D step require changes to a subsequent prompt?** (Corrections that cascaded forward — this tells us about prompt interdependency.)
4. **Were there any new bugs discovered during device testing?** (BUG-075+?)
5. **Did the dashboard UI (v7.6.0.4) require any manual touch-up after the agent delivered?** (Dashboard steps historically need the most fixing.)
6. **What are the current heap values** on the S3 aggregator after Phase D? (Compare to pre-Phase-D baseline — NVS operations and runtime satellite management add RAM pressure.)

### Device Testing Questions
7. **Was reboot persistence verified for add and delete operations?** (The critical invariant: satellites survive power cycles.)
8. **Was the factory reset endpoint (`POST /api/system/reset-satellites`) tested?** And did it properly restore compile-time defaults?
9. **Were error cases tested?** (Duplicate URL → 409, unreachable URL → 400, unknown ID → 404)
10. **How many satellites were tested simultaneously?** (The cap is 8 on PSRAM boards.)

### Forward-Looking Questions
11. **Any new architectural concerns that surfaced during Phase D?** (NVS wear, mutex contention, UI responsiveness, etc.)
12. **Is Phase 7 still the planned next phase, or has the roadmap changed?**
13. **Are there any new devices in the hardware inventory?** (Beyond the S3 at .191 and C3 at .189)
14. **Does Issue #85 need to be closed?** (It tracked BUG-071, resolved by v7.5.7.0. Should already be closed but verify.)
15. **Any new GitHub issues opened during Phase D?**

---

## Step 3: Phase D Closure Assessment Report

Produce a comprehensive Phase D assessment document. Use `prompts/phase6/v7.5.7.0-PR93-consolidated-audit-and-lessons.md` as a format reference but expand to cover all 6 steps.

### Report Structure

```
# Phase D Completion Assessment

## 1. Executive Summary
- Overall execution quality (HIGH / MEDIUM / LOW)
- Total PRs, commits, fixup rounds
- New bugs discovered, new lessons documented
- Comparison to Phase 6 execution quality

## 2. Per-Step Audit Summary
For each v7.6.0.x step:
- PR number, commit count, files changed
- Prompt-vs-implementation fidelity
- Defects found and root cause (prompt fault vs agent fault)
- Review comment resolution

## 3. Prompt Quality Assessment
- Which Phase D prompts worked best? Why?
- Which caused the most trouble? Why?
- Were the v7.5.7.0 audit corrections (LESSON-OPS-086/087/088) effective?
- Were the expanded device testing sections useful?
- Did the curl -H "Content-Length: 0" fix prevent issues?

## 4. New Lessons Learned
- Compile all new LESSON-OPS entries from Phase D
- Identify patterns (are certain defect types recurring?)

## 5. Codebase Health Check
- sensor_history_multi.h size (it was already flagged as a scaling risk — Phase 8 split)
- Test coverage assessment
- Documentation completeness
- Any technical debt accumulated

## 6. Phase 7 Readiness Assessment
- Are the existing Phase 7 prompts still accurate?
- What needs updating based on Phase D changes?
- Are there new lessons that should be applied to Phase 7 prompts?
```

Save as: `prompts/phaseD/phase-d-completion-assessment.md`

---

## Step 4: Phase 7 Preparation

### 4a. Phase 7 Prompt Audit

The existing Phase 7 prompts were written before Phase D shipped. They need to be checked against the actual post-Phase-D codebase state:

**For each Phase 7 prompt (v7.7.0.0, v7.7.0.1, v7.7.1.0):**

1. **Required Reading section** — verify file paths, function names, line numbers are still accurate
2. **§2 item references to sensor_history_multi.h** — line numbers will have shifted after Phase D added 500+ lines
3. **Struct references** — `SatelliteCache` now has `id_buf`, `name_buf`, `url_buf`, `set_identity()`. Phase 7's `PerDevicePersist` struct references may need context updates.
4. **Pre-condition checks** — verify the Playwright commands still work with the current fixture set structure
5. **Do-NOT lists** — apply LESSON-OPS-086 (regeneration churn exclusion)
6. **Compliance tables** — apply LESSON-OPS-088 (placeholder rows)
7. **Device testing sections** — should already have `esphome clean` + regeneration pipeline (applied in 2026-03-28 delivery) but verify
8. **Critical Rules count** — should reference "all 35 critical rules" (may need updating if Phase D added new ones)

### 4b. Phase 7 Prompts Not Yet Created

Per `prompts/prompt-index-and-workflow.md`, the following Phase 7 prompts don't exist yet:

- v7.7.0.2 — Per-device restore (boot) + retention budget
- v7.7.0.3 — Wire new engine, storage-stats v2
- v7.7.1.1 — Per-device delete API
- v7.7.1.2 — Dashboard per-device storage UI
- v7.7.2.0 — Per-device CSV export
- v7.7.2.1 — Per-device CSV import (merge)
- v7.7.2.2 — Multi-device bundle export/import
- v7.7.2.3 — Full regression + Phase 7 closure

**These need to be created.** Read `Docs/v7.7-implementation-plan.md` and `Docs/v7.7-v7.8-persistence-architecture.md` for scope definitions, then produce prompts following the patterns established in the existing Phase 7 and Phase D prompts.

### 4c. Phase 7 Session Handoff

Produce `prompts/handoff/session-handoff-v7.7.0.0.md` following the established format:
- Project state summary (Phase D complete, entering Phase 7)
- Pre-merge checklist for v7.7.0.0
- What to read before v7.7.0.0
- Key design decisions for Phase 7
- Phase D lessons relevant to Phase 7
- Workflow section
- Post-PR Closure Deliverables section

---

## Step 5: Documentation Consolidation

### 5a. Session Log Archival

If individual v7.6.0.x session logs exist in `Docs/`, consolidate them into `Docs/session-log-archive-v7.5.x.md` (rename to `session-log-archive.md` since it now spans v7.5.x–v7.6.x) or create a new `Docs/session-log-archive-v7.6.x.md`.

### 5b. Phase D Audit Files

Check `prompts/phaseD/` for PR audit documents. If they contain lessons already incorporated into `Docs/bugs-and-lessons-learned.md` and the writing guide, note them but don't delete — they serve as audit trail for each PR.

### 5c. Writing Prompts Guide Update

Check if Phase D produced any new prompt-quality lessons that should be added to `Docs/writing-prompts-for-coding-agents-guide.md`. Potential areas:
- NVS-specific testing patterns (namespace isolation, erase-and-reload)
- Runtime state mutation under mutex — prompt patterns for thread-safe code
- Dashboard JS changes that need LESSON-OPS-043 mirror verification
- Mock stateful endpoints (Phase D add/delete changes server state)

### 5d. Architecture Documents

- `Docs/architecture-forward-looking-notes.md` — update with any Phase D architectural decisions that were confirmed or changed
- `Docs/phase-d-implementation-plan.md` — mark as COMPLETE
- Check if `sensor_history_multi.h` file split (Phase 8 item) is now more urgent after Phase D growth

### 5e. prompt-index-and-workflow.md

- All Phase D steps should be ✅ Complete
- Phase 7 prompts should be linked (existing ones + newly created ones)
- Any new critical rules from Phase D should be added to the Critical Rules table
- Revision history entry for this session

### 5f. README.md

Check if `README.md` needs updating to reflect runtime satellite management as a feature.

---

## Step 6: Deliverables

Package everything as a zip with directory structure matching the repo layout:

1. **Phase D completion assessment** (`prompts/phaseD/phase-d-completion-assessment.md`)
2. **Updated Phase 7 prompts** (v7.7.0.0, v7.7.0.1, v7.7.1.0 — corrected for post-Phase-D state)
3. **New Phase 7 prompts** (v7.7.0.2 through v7.7.2.3 — as many as can be accurately produced)
4. **Phase 7 session handoff** (`prompts/handoff/session-handoff-v7.7.0.0.md`)
5. **Updated documentation** (bugs-and-lessons, writing guide, architecture docs, prompt index)
6. **Session log consolidation** (if individual v7.6.0.x logs exist)
7. **Delivery manifest** with exact application instructions

---

## Reference: Key Project Facts

These are stable facts that should still be true when this prompt is used:

- **Hardware:** ESP32-C3 SuperMini at 192.168.120.189 (satellite), ESP32-S3-DevKitC1-N16R8 at 192.168.120.191 (aggregator, PSRAM-equipped)
- **Build system:** ESPHome (IDF build), no `esp_http_client` available (use `fetch_to_buffer()` with `lwip_*()`)
- **Generators:** `render_sensor_config.py` (Python), `generate-fixtures.js` (Node), `generate-header.sh` (HTML→C++ header)
- **Version scheme:** `<major>.<minor>.<phase>.<step>` — Phase 7 = v7.7.x.x
- **Coding agent:** GitHub Copilot, executes prompts against the repo
- **Key architectural invariant:** `ota_0` at `0x10000` in all partition tables (BUG-061)
- **Key timing invariant:** `esp_timer_get_time()` for intervals, wall-clock only for display (LESSON-OPS-069)
- **Key NVS invariant:** history endpoint NVS scan is blocking — dashboard JS must never fire concurrent requests (LESSON-OPS-052)
- **File split risk:** `sensor_history_multi.h` is a monolith (~3500+ lines after Phase D). Phase 8 split is planned but not yet scoped.
- **Naming debt:** sensors-vs-devices naming inconsistency deferred to a future major version

---

## Reference: What Phase D Should Have Changed

Use this as a checklist — if any of these didn't happen, something went wrong:

- [ ] `runtime_satellite_count` exists and replaces `MAX_SATELLITES` in all loop bounds
- [ ] NVS persistence: satellites survive reboots without reflashing
- [ ] Three working API endpoints: add-satellite (POST), delete-satellite (DELETE), test-satellite (POST)
- [ ] Factory reset endpoint: `POST /api/system/reset-satellites`
- [ ] Dashboard UI: add/remove/test controls in Settings panel
- [ ] Playwright tests covering satellite management
- [ ] `SatelliteCache` has owned string storage (`id_buf`, `name_buf`, `url_buf`)
- [ ] Compile-time satellite arrays still work as first-boot fallback
- [ ] No regression in existing tests (3sensor, mixed, system, aggregator fixture sets)
- [ ] Version is v7.6.0.5 or later
- [ ] All 6 steps have changelog entries, session logs, and PR audit documents

---

_End of session prompt._
