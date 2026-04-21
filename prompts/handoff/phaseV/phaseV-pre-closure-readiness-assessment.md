# Phase V — Pre-Closure Readiness Assessment

_Run this prompt in a fresh Claude session after v7.6.9.5 merges and before running Phase V closure documents._
_Purpose: catalog accumulated gaps, deferred items, and documentation debt from the v7.6.9.4–5 mitigation sequence. Produce a categorized fix list and determine readiness for formal Phase V closure._

---

## Instructions for the Advisor

You are the architectural advisor for Phase V of the ESP32-GW Multi-Sensor Gateway project. Phase V is about to close. Two mitigation steps (v7.6.9.4, v7.6.9.5) were added after the originally planned Phase V closure at v7.6.9.3. v7.6.9.6 (Cloudflare polling fix) was originally planned but dropped after the issue self-resolved — BUG-078's `init_response_()` status code fix (v7.6.0.1) eliminated the 401→500 mapping, and the browser's native Basic Auth dialog now handles credential prompts. A dashboard authentication UX refactor is deferred to Phase VX. These late additions may have introduced documentation gaps, incomplete tracking, or deferred items that need resolution before formal closure.

Your job: audit the full state and produce a readiness report.

### ⚠️ Read Before Responding

```
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor
git checkout main && git pull
cat VERSION
```

VERSION must read `7.6.9.5` (or higher if additional fixes were applied). If lower, STOP — Phase V closure prerequisites are not met.

### Mandatory Reading (in this order)

**State files:**
1. `Docs/changelog.md` — scan all v7.6.x entries
2. `Docs/phase-V-implementation-plan.md` — the original plan, especially the version table
3. `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` — the addendum that authorised v7.6.9.4/5 (v7.6.9.6 was originally in scope but dropped)
4. `Docs/phase-V-capacity-study.md` — check task stack table is updated with v7.6.9.5 findings (uniform 16 KB, ~3,400 B peak usage)

**Session logs (read for device test results and findings):**
5. `Docs/session-log-*-v7.6.9.4.md`
6. `Docs/session-log-*-v7.6.9.5.md`

**Lessons and bugs:**
7. `Docs/lessons/firmware.md` — check for BUG-082, BUG-083, LESSON-OPS-127, LESSON-OPS-128
8. `Docs/lessons/operations.md` — check for LESSON-OPS-127
9. `Docs/lessons/index.md` — run consistency check against domain files

**Phase V tracking:**
10. `prompts/handoff/phaseV/phaseV-results.md` — check all v7.6.x rows are filled
11. `prompts/phaseV/phaseV-conclusion-assessment.md` — check v7.6.9.4/5 are noted, v7.6.9.6 noted as dropped
12. `prompts/handoff/phaseV/session-handoff-v7.6.9.4.md` — check issue references
13. `prompts/handoff/phaseV/session-handoff-v7.6.9.5.md` — check issue references

**Decision records:**
14. `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` — confirm RV-03 documentation-only note added (BUG-078 resolved the 401→500 mapping; browser Basic Auth dialog handles credentials; auth UX refactor deferred to Phase VX)

**Other docs that may need updating:**
15. `Docs/esp32-board-selection-guide.md` — v7.6.9.5 finding: uniform stack, no architecture-dependent sizing
16. `README.md` — does the phase roadmap reflect the VX/VY sequence?
17. `prompts/prompt-index-and-workflow.md` — needs Phase V summary + any new Critical Rules added during Phase V

---

### Audit Checklist

For each item, determine status: ✅ Done | ⚠️ Gap (describe) | ❌ Missing

**A. Phase V Results Table (`phaseV-results.md`)**
- [ ] Every v7.6.x version has a filled row (PR number, status, fix cycles, agent, key outcome)
- [ ] V4 (v7.6.9.4), V5 (v7.6.9.5) rows are present and complete
- [ ] v7.6.9.6 noted as "Dropped — Cloudflare polling issue self-resolved (BUG-078 fixed 401→500 mapping in v7.6.0.1). Auth UX deferred to Phase VX."
- [ ] Operator measurement results section is filled (if applicable)

**B. Lessons Index Consistency**
```bash
python3 scripts/audit-lessons-index.py
# OR manually: every LESSON-OPS-NNN and BUG-NNN referenced in domain files
# (firmware.md, operations.md, build-pipeline.md) appears in index.md
```

**C. Issue Tracking on GitHub**
Check these issues for correct labels, milestones, and status:
- #139 — should be OPEN with `bug`, `memory` labels; comment referencing v7.6.9.4 PR
- Any issues created during v7.6.9.4–5 execution
- New issue for dashboard auth refactor (Phase VX) — should be OPEN with link to `dashboard-auth-refactor-issue.md`

**D. Session Logs**
- [ ] v7.6.9.4 session log has device test table filled (not "Not run" placeholders)
- [ ] v7.6.9.5 session log has stress test results (minimum watermark value, not placeholders)

**E. Documentation Currency**
- [ ] `Docs/phase-V-capacity-study.md` task stack table updated: uniform 16 KB stack, ~3,400 B peak usage on all architectures (v7.6.9.5 / BUG-083)
- [ ] `Docs/esp32-board-selection-guide.md` — note that stack sizing is uniform (no architecture-dependent differences). If missing, flag as should-fix.
- [ ] `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` RV-03 section: documentation-only amendment noting BUG-078 resolved the HTTP 500 mapping, browser native auth dialog handles credentials, auth UX refactor deferred to Phase VX
- [ ] `firmware/local_components/web_server_idf/PATCH_INFO.md` documents the 16 KB stack override
- [ ] `scripts/patch-esphome-httpd-stack.sh` applies the stack patch correctly

**F. Consolidated Audits**
- [ ] v7.6.9.4 consolidated audit exists
- [ ] v7.6.9.5 consolidated audit exists

**G. Phase V Plan Amendments**
- [ ] `Docs/phase-V-implementation-plan.md` version table includes V4/V5 rows
- [ ] Plan line 44 issue-table entry for #139 updated
- [ ] Plan line 805 V2-E note amended to reference v7.6.9.4

**H. Known Deferred Items**
- [ ] BUG-082 (csv.reserve≠truncate) — documented, tracked for Phase 7 chunked streaming
- [ ] Phase 7 plan gap: no stress test gate for new handlers (flagged by v7.6.9.5)
- [ ] Phase 7 plan gap: no chunked HTTP streaming step (flagged by v7.6.9.5/BUG-082)
- [ ] Dashboard auth UX refactor — documented in issue, deferred to Phase VX as final step

**I. Pipeline Health**
```bash
bash scripts/preflight.sh
bash scripts/assemble-sensor-history.sh --check
python3 scripts/render_sensor_config.py --check
bash scripts/patch-esphome-httpd-stack.sh --check
```

**J. prompt-index-and-workflow.md Currency**
- [ ] "Last updated" line reflects Phase V (currently says "Phase Y closure")
- [ ] Phase V summary paragraph added (matching Phase D/X/Y format)
- [ ] Any new Critical Rules from Phase V added to the table
- [ ] Step index includes Phase V rows (if applicable to the prompt structure used)

---

### Output

Produce a categorized report:

**BLOCKING** — must fix before running closure analysis:
- Broken preflight, inconsistent lessons index, missing session log data, unfilled results rows
- These get a fix PR (single cleanup PR, agent-driven)

**SHOULD-FIX** — cleanup PR before closure:
- Board selection guide update (uniform stack sizing note)
- Incomplete issue labels/milestones on GitHub
- Minor documentation gaps
- `prompt-index-and-workflow.md` Phase V update

**DEFER** — document and hand off:
- BUG-082 → Phase 7
- Phase 7 plan gaps → multi-phase planning session
- Board onboarding → Phase VX
- Dashboard auth UX → Phase VX

**READY / NOT READY** — final verdict:
- If BLOCKING items exist: "NOT READY — fix these N items first, then re-run"
- If only SHOULD-FIX: "CONDITIONALLY READY — fix these items in a cleanup PR, then proceed with closure"
- If clean: "READY — proceed with closure documents"

If there are BLOCKING or SHOULD-FIX items, produce agent prompts to fix them (likely a single cleanup PR with a narrow scope list).

---

_End of Pre-Closure Readiness Assessment prompt._
