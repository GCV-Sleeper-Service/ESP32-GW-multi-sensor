# Phase V — Closure Analysis Prompt

_Run this prompt in a fresh Claude session AFTER `phaseV-issue-sweep-prompt.md` has been executed and its output exists at `prompts/handoff/phaseV/phaseV-issue-sweep-results.md`._
_Purpose: produce a deep, quantitative closure analysis of Phase V (v7.6.7.0 through v7.6.9.5) modelled on Phase Y's closure analysis (`prompts/handoff/phaseY/phaseY-closure-analysis.md`)._

---

## When to Use

Run this prompt after:
1. v7.6.9.5 merged to `main` and tagged
2. `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` exists and has been reviewed by the operator
3. Any issue closures / label updates recommended by the sweep have been applied
4. `prompts/handoff/phaseV/phaseV-results.md` may still be EMPTY — this closure analysis feeds it, not the other way around

Do NOT run this prompt before the issue sweep. The sweep produces the data Q5 needs.

Do NOT run this prompt before Phase 7 planning starts — this analysis IS the input to Phase 7 planning.

---

## Prerequisites

Before starting, the operator must confirm:

- [ ] v7.6.9.5 merged and tagged on `main`
- [ ] `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` exists and is dated after v7.6.9.5 merge
- [ ] All Phase V consolidated audits exist: `prompts/phaseV/v7.6.7.0-PR<NN>-consolidated-audit-and-lessons.md` through v7.6.9.5 (one per step; v7.6.8.3 telemetry step had no consolidated audit — that's expected)
- [ ] All Phase V session logs exist in `Docs/`: `session-log-*-v7.6.7.*.md` through `session-log-*-v7.6.9.*.md`
- [ ] Phase Y closure analysis (`prompts/handoff/phaseY/phaseY-closure-analysis.md`) is readable as the structural template

---

## Template

---

**Phase V Closure Analysis**

You are producing a comprehensive closure analysis for Phase V (v7.6.7.0 through v7.6.9.5) of the ESP32-GW Multi-Sensor Gateway project.

Repo: `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`

Your output document `Docs/phase-V-closure-analysis.md` must match the depth, tone, and structure of `prompts/handoff/phaseY/phaseY-closure-analysis.md` (which was Copilot-deep-research's output for Phase Y). That reference is ~430 lines of dense quantitative analysis with per-step tables and a reviewer-comment appendix. Your Phase V output should be similar.

### ⚠️ Read Before Responding

Your training data is stale on specifics. You MUST read actual current files. Rely on nothing from memory.

1. **Clone and sync:**
   ```
   git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
   cd ESP32-GW-multi-sensor
   git checkout main && git pull
   cat VERSION   # 7.6.9.5
   ```

2. **Read in this order (mandatory — do not skip):**
   - `Docs/phase-V-implementation-plan.md` — the plan
   - `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` — the mid-phase deviation
   - `Docs/phase-V-capacity-study.md` — capacity inputs for Phase 7 handoff
   - `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` — V2 security outcomes
   - `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` — V3 aggregator decision (if exists)
   - `prompts/handoff/phaseV/phaseV-results.md` — may be mostly empty; read to see what the template expects
   - `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` — your Q5 data source
   - `prompts/handoff/phaseY/phaseY-closure-analysis.md` — your structural template
   - `Docs/changelog.md` — every v7.6.7.x, v7.6.8.x, v7.6.9.x entry
   - Every Phase V consolidated audit: `prompts/phaseV/v7.6.*.*-PR*-consolidated-audit-and-lessons.md`
   - Every Phase V session log: `Docs/session-log-*-v7.6.*.md`
   - `Docs/lessons/` — all six lessons files, checking for Phase V-era additions
   - `prompts/prompt-index-and-workflow.md` — Critical Rules current state

3. **Also fetch via git for per-step metadata:**
   ```
   git log --oneline main --grep="v7.6.7\.\|v7.6.8\.\|v7.6.9\."
   git log --all --merges --grep="Phase V"   # for merge commit timestamps
   git tag -l 'v7.6.*' --sort=creatordate
   ```
   Record for each Phase V version: merge commit SHA, merge timestamp, PR number, commit count since previous Phase V version.

---

### Required Output Structure

Produce `Docs/phase-V-closure-analysis.md` with **exactly these six question sections plus an appendix**, in this order. Phase Y's file is the structural reference. Your depth should match.

---

## Q1 — Plan vs Delivery

Start with a one-sentence **Overall verdict** in bold.

Then produce:

### Version coverage table
| Planned version | Sub-phase | Actual merge SHA | Merge date | PR # | Match? |
|---|---|---|---|---|---|

Include every Phase V version from v7.6.7.0 to v7.6.9.5. Mark any deviations with ⚠️ in the Match column and explain immediately below the table. Examples of deviations: versions skipped, versions merged out of order, scope creep in a given version, partial deliveries.

### Sub-phase deliverable tables
For each of V1/V2/V3/V4/V5/V6, produce:

**Plan (from `Docs/phase-V-implementation-plan.md` §<relevant section>):**  
`<Short quote of the plan's stated deliverables for this sub-phase>`

**Delivered:** ✅ or ⚠️ with specifics

Use the same prose-followed-by-table pattern Phase Y uses at lines 10–69.

### Addendum fidelity
A full paragraph on `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md`. Did v7.6.9.4 stay within the addendum's narrow scope? Did the two new carve-outs (v7.6.9.5 stack investigation, v7.6.9.5 SEC-ADR amendment) emerge cleanly from the v7.6.9.4 device testing or did they drift in scope? Quote the addendum's "What this does NOT deliver" section and check whether any of that leaked into Phase V anyway.

### Closure deliverables table
Modelled on Phase Y closure analysis lines 55–68:

| Deliverable | Plan | Status | Evidence |
|---|---|---|---|

Include: every consolidated audit, every session log, every SEC-ADR update, every LESSON-OPS entry, Critical Rules added, `phaseV-results.md` filled in, `phaseV-conclusion-assessment.md` filled in, `phaseV-issue-sweep-results.md` exists.

---

## Q2 — Implementation Quality

### Auth coverage table — post-V2 actual state vs SEC-ADR-001
Produce the full endpoint table. Compare the actual routing in `firmware/core/web-handler.h` `handleRequest()` to the table claimed in `SEC-ADR-001`. Note any mismatches. Phase Y didn't have this equivalent (Phase Y was architectural, not security), but Phase V's V2 sub-phase demands it.

### History-endpoint mitigation trajectory
A paragraph tracing the mitigation timeline for issue #139:
- v7.6.8.1: fixed 60 KB cap (safety net)
- v7.6.9.0 hotfix 1+2: auth removed from history GET (Copilot-reviewed trade-off)
- v7.6.9.4: adaptive cap + boot sequencing
- Full fix deferred to Phase 7

Evaluate whether each step was additive (no regression) or whether any step unwound a previous mitigation. The v7.6.9.0 auth removal is the sensitive one — did v7.6.9.4 restore auth? Did v7.6.9.5 change it again? If the current state differs from what SEC-ADR-001 and SEC-ADR-002 (if created) describe, flag it as a documentation bug.

### Dashboard pipeline fidelity
Phase V made heavy use of the dashboard regeneration pipeline. For every step that modified dashboard sources, verify:
- Source file edited, not generated artifact (Rule 47)
- `dashboard.tmpl.html` edited, not the assembled `dashboard.html` (Rule 48)
- `dashboard/sensor_history_multi.h` never hand-edited (Rule 58)
- Full pipeline ran in the canonical order

Produce a table of any Rule 47/48/58 near-misses caught in review across the whole phase.

### Hotfix pattern — v7.6.9.0 went through 2 hotfixes post-merge-intent
This is a notable process pattern. Analyse:
- How many pre-merge fix cycles did v7.6.9.0 go through?
- How many post-merge hotfix commits to the same branch before merge?
- Did the hotfixes cleanly layer or did any hotfix revert a previous hotfix?
- Was the v7.6.9.0 hotfix sequence captured in `session-log-*-v7.6.9.0.md` such that the delivery is reproducible?

Compare to Phase Y's fix-cycle count from its closure analysis Q6 table.

### Test coverage evolution
Playwright test count per sub-phase — show the growth:

| Sub-phase | Fixture sets | Tests total | New tests added |
|---|---|---|---|

Pull numbers from the session logs' Playwright fixture tables. Phase V started with the Phase Y baseline of ~402 tests; report the end-state.

---

## Q3 — Documentation Quality

### Consolidated audits
Every Phase V step SHOULD have a consolidated audit except v7.6.8.3 (single-step telemetry addition per operator practice). Enumerate:
- Which audits exist, link to each
- Which are missing and should exist
- Which are present but thin (< 50 lines) and should be backfilled

### Session logs
Same pattern as audits. Phase Y closure analysis flagged a missing v7.6.6.8 session log as blocking. Check every Phase V version has one.

### Changelog quality
Pull the raw v7.6.7.0–v7.6.9.5 entries from `Docs/changelog.md`. For each version:
- Is there a Fixed / Changed / Added / Deprecated section?
- Is every issue number cited?
- Is every behavioural change visible to end-users noted?
- Are known limitations called out explicitly (especially for v7.6.9.0 polling-mode limitation)?

### Lessons categorisation
`Docs/lessons/` has six category files (build-pipeline, dashboard, firmware, index, operations, testing). Verify every Phase V LESSON-OPS entry lands in the correct file. The index file (`Docs/lessons/index.md`) should cross-reference all Phase V lessons by number.

### Critical Rules
List every Critical Rule added during Phase V. For each, confirm:
- Present in `prompts/prompt-index-and-workflow.md`
- Referenced by at least one Phase V agent prompt
- Numbering is sequential (no gaps, no duplicates)

Compare against Phase Y which added Critical Rules 58–62. Phase V should have added fewer — V2's LESSON-OPS-110 ("Auth policy in code blocks") was elevated to Critical Rule territory; confirm this happened or flag the gap.

### Plan fidelity — amendments actually applied
The v7.6.9.4 addendum specified four line-level amendments to `Docs/phase-V-implementation-plan.md` (lines ~44, 805, 1223, 1241). Verify each was applied. If any are missing, the plan document is in a stale state and needs patching before Phase 7 reads it.

---

## Q4 — Bugs, Lessons, Rules

### Bugs discovered during Phase V
A table of every BUG-xxx identified during Phase V execution:

| BUG ID | Phase V version surfaced | Root cause | Fixed in | Documented in |
|---|---|---|---|---|

Phase V is likely to have surfaced:
- v7.6.9.0 ESPHome template text_sensor `update_interval: never` publishes empty state
- v7.6.9.0 `/api/status/full` requires auth that browser can't provide over Cloudflare Tunnel
- v7.6.9.0 C3 `httpd_stack_watermark_bytes: 644` (near-overflow risk)
- v7.6.9.0 WROOM history endpoint OOM on large history
- v7.6.9.x pre-existing regression from v7.6.8.0 SEC-04 field split (heap/uptime on /api/status stripped, polling mode silently broken)

Capture each. Note which were caught by pre-merge review vs post-merge device testing vs in-production operator reporting.

### LESSON-OPS entries added
Table:
| LESSON-OPS # | Topic | Source version | Lessons file |
|---|---|---|---|

Cross-reference against `Docs/lessons/*.md` to ensure every entry is findable.

### Critical Rules added
Table (same format as Phase Y Q4):
| Rule # | Description | Source |
|---|---|---|

---

## Q5 — Outstanding Issues

This section is where `phaseV-issue-sweep-results.md` becomes authoritative. Your job in Q5 is to **summarise** the sweep's findings, not redo them.

### Sweep summary
Copy the "Summary" table from `phaseV-issue-sweep-results.md`. Verify counts sum to the open-issue total.

### FIXED_PARTIALLY issues — full specification of what Phase 7 inherits
For each issue classified FIXED_PARTIALLY by the sweep, pull the tick-list of remaining work and restate here. These rows become the seed of Phase 7's scope.

### DEFERRED_INTENTIONAL — full specification
Same treatment. Each deferred issue must have:
- Target phase (Phase 7, Phase E, etc.)
- Rationale (quoted from Phase V plan or addendum)
- Any preconditions the deferral imposed on Phase 7

### Issues Phase 7 MUST address before its own closure
Sub-list of FIXED_PARTIALLY + DEFERRED_INTENTIONAL where the rationale explicitly ties to Phase 7. This becomes the Phase 7 plan's non-negotiable scope.

### Issues Phase 7 SHOULD address but may defer further
Sub-list where the rationale allows deferral past Phase 7 (e.g. #137 SVG generation).

### Post-Phase-V issues opened during execution
If the sweep identified any issues opened after plan finalisation that are still open, list them here with a recommendation: is each new issue a candidate for Phase 7 inclusion, or should it wait?

### Are any outstanding issues blockers for Phase 7?
Mirror Phase Y's Q5 "Are any outstanding issues blockers for Phase 7?" paragraph at line 289. Answer specifically and with evidence.

---

## Q6 — Meta-Level Lessons

This is the prompt-engineering and process retrospective. Mirror Phase Y's Q6 at lines 322–398 in depth.

### Process and prompt-engineering lessons from the full Phase V arc
Enumerate 5–10 specific lessons drawn from Phase V execution. For each:
- Concrete observation (with step/PR reference)
- The underlying pattern
- The specific fix for future prompt authoring

Candidate lesson domains to consider:
- Hotfix cycle discipline (v7.6.9.0 went through two hotfixes)
- Pre-merge device testing (v7.6.9.4 made device testing a pre-merge gate — how did that work?)
- ADR amendments vs new ADRs (SEC-ADR-001 was amended by v7.6.9.5 rather than having SEC-ADR-002 created — was that the right call?)
- Plan addendum pattern (the v7.6.9.4 addendum was a novel artifact — did it work?)
- Multi-LLM scope discipline (did the v7.6.9.4 prompt's "no Phase 7 work" invariant hold?)
- Issue #139 incremental mitigation (cap → auth-remove → adaptive cap across three versions — did this layering pattern work or did it confuse reviewers?)
- Cloudflare Tunnel as environmental variable (dashboard auth architecture broke silently over Cloudflare; how should future plans account for deployment environments?)

### What should change for Phase 7 prompts
Mirror Phase Y's recommendations section (lines 362–378). Produce:
- Always include: <list>
- Never include: <list>
- Prompt structure changes: <list>

### Agent behaviour patterns — summary
Table (Phase Y line 381):
| Problem pattern | Frequency | Guardrail that worked |
|---|---|---|

Pull data from every Phase V PR's review history. Examples to look for:
- Scope violations (changes to files outside allowed diff)
- Stale line number references
- Missing session log deliverable
- Direct edits to generated artifacts
- Checkpoint-skipping under time pressure

### Guardrails that worked reliably
Bullet list. What caught issues consistently? Preflight checks? Playwright fixtures? Specific reviewer models?

### Meta-lesson (highest leverage)
One paragraph. The single biggest takeaway for future phase planning.

---

## Appendix — Per-PR Review Comment Summary

Phase Y's appendix (lines 400–428) is a table mapping every PR review comment to its resolution status. Do the same for Phase V — but aggregated across the 10+ Phase V PRs rather than a single PR.

Produce a table:
| PR # | Source | Comment summary | Severity | Fixed? | Current state |
|---|---|---|---|---|---|

If producing the full appendix would exceed context limits, produce it per sub-phase (one table for V1, one for V2, etc.) and clearly mark section boundaries.

At the end of the appendix, produce a **severity distribution table**:

| Severity | Raised | Fixed | Deferred | Accepted as trade-off |
|---|---|---|---|---|
| Blocking | | | | |
| High | | | | |
| Medium | | | | |
| Low | | | | |
| Cosmetic | | | | |

---

## Closure Analysis Quality Self-Check

Before publishing the document, the analyst confirms:

- [ ] Length is 300–500 lines (Phase Y is 432; Phase V has more sub-phases and will likely be longer, not shorter)
- [ ] Every Q1–Q6 section has actual tables with real data, not empty templates
- [ ] Every claim of "fixed in vX.Y.Z" has a cited PR number and changelog reference
- [ ] Every "still open" claim cross-references the issue sweep document
- [ ] No section says "TBD" or "to be filled" — if you don't have data, either fetch it or say so explicitly
- [ ] The "What Phase 7 inherits" section is concrete enough that Phase 7 plan authors can cut-and-paste directly
- [ ] The appendix PR review comment table has resolution status for every comment, not just the easy ones
- [ ] Tone matches Phase Y's — matter-of-fact, technical, no self-congratulation, no hedging

### Handoff to Phase 7 planning

The final section of your output document should be a short "Handoff to Phase 7" block. Phase 7 plan authors will read this first. Keep it to one page:

- Top 3 Phase V outcomes Phase 7 must build on
- Top 3 unresolved items Phase 7 must address
- Top 3 process changes Phase 7 should adopt

This mirrors the intent of Phase Y's final recommendations but concentrates it for the Phase 7 reader.

---

**Output:** `Docs/phase-V-closure-analysis.md`

**After completion:** the operator reads the analysis, applies any label/milestone updates the analysis recommends, fills in `prompts/handoff/phaseV/phaseV-results.md` and `prompts/phaseV/phaseV-conclusion-assessment.md` using the analysis as source-of-truth, then signals Phase 7 planning can begin.

---

_End of Phase V closure analysis prompt._
