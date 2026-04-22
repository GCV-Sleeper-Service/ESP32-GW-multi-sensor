# Phase <X> Closure Analysis — Deep Research Agent Prompt Template
<!--
USAGE: Copy this file. Replace every <placeholder> before running.
Run in a fresh session AFTER:
  1. Final phase version is merged and tagged on `main`
  2. `prompts/handoff/phase<X>/phase<X>-issue-sweep-results.md` exists and is reviewed
  3. Any issue closures / label updates recommended by the sweep have been applied

OUTPUT: `Docs/phase-<X>-closure-analysis.md`
-->

---

## Context

**Project:** ESP32-GW Multi-Sensor Gateway  
**Repo:** `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`  
**Phase:** Phase `<X>` — v`<start-version>` through v`<end-version>`  
**Phase focus:** `<one-line description, e.g. "Security hardening + aggregator satellite history">`  
**Previous phase closure analysis (structural template):** `prompts/handoff/phase<PREV>/phase<PREV>-closure-analysis.md`

---

## ⚠️ Read Before Responding — Mandatory File List

Your training data is stale on specifics. You MUST read actual current files. Rely on nothing from memory.

### Planning & Architecture Documents
1. `Docs/phase-<X>-implementation-plan.md`
2. `Docs/phase-<X>-implementation-plan-addendum-*.md` _(if any mid-phase deviation documents exist)_
3. `Docs/phase-<X>-capacity-study.md` _(if exists)_
4. `Docs/decisions/` — all ADRs touched or created during Phase `<X>`

### Handoff Documents
5. `prompts/handoff/phase<X>/phase<X>-results.md`
6. `prompts/handoff/phase<X>/phase<X>-issue-sweep-results.md` ← **authoritative for Q5**
7. `prompts/handoff/phase<PREV>/phase<PREV>-closure-analysis.md` ← **structural template**

### Changelog & Version History
8. `Docs/changelog.md` — all v`<start-version>` through v`<end-version>` entries

### Consolidated Audits
9. Every file matching `prompts/phase<X>/v<start>.*.*-PR*-consolidated-audit-and-lessons.md`
   _(list `prompts/phase<X>/` directory first to discover all audit files)_

### Session Logs
10. Every file matching `Docs/session-log-*-v<range>.*.md` for Phase `<X>` versions

### Lessons & Rules
11. `Docs/lessons/build-pipeline.md`
12. `Docs/lessons/dashboard.md`
13. `Docs/lessons/firmware.md`
14. `Docs/lessons/index.md`
15. `Docs/lessons/operations.md`
16. `Docs/lessons/testing.md`
17. `prompts/prompt-index-and-workflow.md` — Critical Rules current state

### Firmware Source _(for Q2 auth coverage table)_
18. `firmware/core/web-handler.h` — specifically `handleRequest()` routing

### Git Metadata to Collect
19. All `v<range>` tags in chronological order
20. For each phase version: merge commit SHA, merge date, PR number _(from changelog + session logs)_

---

## Required Output Structure

Produce `Docs/phase-<X>-closure-analysis.md` with **exactly these sections in order**.

---

### Header Block
```
# Phase <X> Comprehensive Closure Analysis
_Generated: <YYYY-MM-DD>_
_Repository: GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Phase: Phase <X> — v<start-version>–v<end-version> (<one-line focus>)_
_PR under review: #<final-PR-number> (<branch-name>)_
```

---

## Q1 — Plan vs Delivery

**Overall verdict:** _(one sentence in bold)_

### Version Coverage Table
| Planned version | Sub-phase | Actual merge SHA | Merge date | PR # | Match? |
|---|---|---|---|---|---|

_Include every planned version. Mark deviations ⚠️ and explain immediately below the table._

### Sub-phase Deliverable Tables
_For each sub-phase `<X>1` through `<X>N`:_

**Plan (from `Docs/phase-<X>-implementation-plan.md` §`<section>`):**
`<short quote of stated deliverables>`

**Delivered:** ✅ or ⚠️ with specifics.

### Addendum Fidelity _(if any addendum exists)_
_Full paragraph: did the addendum-gated versions stay within the addendum's narrow scope? Were carve-outs resolved as described?_

### Closure Deliverables Table
| Deliverable | Plan | Status | Evidence |
|---|---|---|---|

_Include: every consolidated audit, every session log, ADR updates, LESSON-OPS entries, Critical Rules added, results file filled in, changelog entries._

---

## Q2 — Implementation Quality

### Auth Coverage Table — Actual State vs `SEC-ADR-001`
| Endpoint | Method | Auth required? (plan) | Auth in code? | Match? |
|---|---|---|---|---|

_Compare actual `handleRequest()` routing to SEC-ADR-001 claims. Note mismatches._

### Key Issue Mitigation Trajectory _(replace with phase's primary tracked issue)_
_Paragraph tracing the incremental mitigation of issue `#<N>` across each phase step:_
- _`v<A>`: `<what changed>`_
- _`v<B>`: `<what changed>` — evaluate additive vs regressive_
- _Full fix deferred to Phase `<next>`: `<rationale>`_

### Dashboard Pipeline Fidelity
_For every step touching dashboard sources, verify:_
- _Source file edited, not generated artifact (Rule 47)_
- _`dashboard.tmpl.html` edited, not `dashboard.html` (Rule 48)_
- _`dashboard/sensor_history_multi.h` never hand-edited (Rule 58)_

| Step | Rule 47 violation? | Rule 48 violation? | Rule 58 violation? | Caught by? |
|---|---|---|---|---|

### Hotfix Pattern Analysis _(for any version that went through post-merge-intent hotfixes)_
- _How many pre-merge fix cycles?_
- _How many post-merge hotfix commits before final merge?_
- _Did hotfixes cleanly layer or did any revert a previous one?_
- _Was the sequence reproducible from session logs?_
- _Compare to previous phase's fix-cycle count._

### Test Coverage Evolution
| Sub-phase | Fixture sets | Tests total | New tests added |
|---|---|---|---|

_Pull from session logs' Playwright fixture tables. Report starting baseline and end-state._

---

## Q3 — Documentation Quality

### Consolidated Audits
_Enumerate every phase step:_
- _Which audits exist (link each)_
- _Which are missing and should exist (flag as Required)_
- _Which are thin (< 50 lines) and should be backfilled_
- _Note any steps legitimately exempt from audit per operator practice_

### Session Logs
_Same pattern as audits. Flag missing session logs as Required with blocking status._

### Changelog Quality
_For each version `v<start>` through `v<end>`:_
- _Fixed / Changed / Added / Deprecated sections present?_
- _Every issue number cited?_
- _Known limitations called out?_

### Lessons Categorisation
_Verify every Phase `<X>` LESSON-OPS entry lands in the correct file in `Docs/lessons/`. The index file must reference all of them._

### Critical Rules Added During Phase `<X>`
| Rule # | Description | Source version |
|---|---|---|

_Confirm each is in `prompts/prompt-index-and-workflow.md`. Confirm sequential numbering (no gaps, no duplicates). Compare count to previous phase._

### Plan Fidelity — Amendments Applied _(if addendum exists)_
_The addendum specified `<N>` line-level amendments to `Docs/phase-<X>-implementation-plan.md`. Verify each was applied._

---

## Q4 — Bugs, Lessons, Rules

### Bugs Discovered During Phase `<X>`
| BUG ID | Version surfaced | Root cause | Fixed in | Documented in |
|---|---|---|---|---|

_Note catch method: pre-merge review / post-merge device testing / in-production operator reporting._

### LESSON-OPS Entries Added
| LESSON-OPS # | Topic | Source version | Lessons file |
|---|---|---|---|

_Cross-reference against `Docs/lessons/*.md` to confirm each is findable._

### Critical Rules Added
_(Same table as Q3 — kept here for Q4 self-contained completeness.)_

---

## Q5 — Outstanding Issues

_**This section is authoritative from `prompts/handoff/phase<X>/phase<X>-issue-sweep-results.md`.** Summarise sweep findings; do not redo them._

### Sweep Summary
_Copy the Summary table from `phase<X>-issue-sweep-results.md`. Verify counts sum to total open issues._

### FIXED_PARTIALLY Issues — What Phase `<next>` Inherits
_For each FIXED_PARTIALLY issue: tick-list of remaining work → these become Phase `<next>`'s seed scope._

### DEFERRED_INTENTIONAL — Full Specification
_For each: target phase, rationale (quoted from plan or addendum), preconditions imposed on Phase `<next>`._

### Issues Phase `<next>` MUST Address Before Its Own Closure

### Issues Phase `<next>` SHOULD Address But May Defer Further

### Post-Phase-`<X>` Issues Opened During Execution
_Issues opened after plan finalisation that are still open: Phase `<next>` candidate or wait?_

### Are Any Outstanding Issues Blockers for Phase `<next>`?
_Answer specifically with evidence. Mirror previous phase closure analysis Q5 final paragraph._

---

## Q6 — Meta-Level Lessons

### Process and Prompt-Engineering Lessons from the Full Phase `<X>` Arc
_5–10 specific lessons. For each:_
- _Concrete observation (with step/PR reference)_
- _The underlying pattern_
- _The specific fix for future prompt authoring_

_Candidate domains to consider for every phase:_
- _Hotfix cycle discipline_
- _Pre-merge device testing gate effectiveness_
- _ADR amendments vs new ADRs — was the right call made?_
- _Plan addendum / deviation document pattern — did it work?_
- _Multi-LLM scope discipline — did "no Phase `<next>` work" invariant hold?_
- _Incremental mitigation layering — did it confuse reviewers?_
- _Environmental variables not in plan (e.g. Cloudflare Tunnel, board variant differences)_

### What Should Change for Phase `<next>` Prompts
**Always include:**
- `<list>`

**Never include:**
- `<list>`

**Prompt structure changes:**
- `<list>`

### Agent Behaviour Patterns — Summary
| Problem pattern | Frequency | Guardrail that worked |
|---|---|---|

_Pull from every phase PR's review history. Look for: scope violations, stale line number references, missing session log deliverable, direct edits to generated artifacts, checkpoint-skipping under time pressure._

### Guardrails That Worked Reliably
_Bullet list._

### Meta-Lesson (Highest Leverage)
_One paragraph. Single biggest takeaway for future phase planning._

---

## Appendix — Per-PR Review Comment Summary

_Aggregated across all Phase `<X>` PRs._

| PR # | Source | Comment summary | Severity | Fixed? | Current state |
|---|---|---|---|---|---|

_If full appendix would exceed context, produce per sub-phase with clear section boundaries._

**Severity Distribution Table:**
| Severity | Raised | Fixed | Deferred | Accepted as trade-off |
|---|---|---|---|---|
| Blocking | | | | |
| High | | | | |
| Medium | | | | |
| Low | | | | |
| Cosmetic | | | | |

---

## Handoff to Phase `<next>`

_One-page summary for Phase `<next>` plan authors (they read this first):_

- **Top 3 Phase `<X>` outcomes Phase `<next>` must build on:**
  1.
  2.
  3.

- **Top 3 unresolved items Phase `<next>` must address:**
  1.
  2.
  3.

- **Top 3 process changes Phase `<next>` should adopt:**
  1.
  2.
  3.

---

## Closure Analysis Quality Self-Check

Before publishing, confirm:

- [ ] Length matches or exceeds previous phase closure analysis (target: previous length + ~10% per additional sub-phase)
- [ ] Every Q1–Q6 section has actual tables with real data — no empty templates, no TBDs
- [ ] Every "fixed in vX.Y.Z" claim has a cited PR number and changelog reference
- [ ] Every "still open" claim cross-references the issue sweep document
- [ ] No section says "TBD" or "to be filled" — if data is absent, state so explicitly
- [ ] "What Phase `<next>` inherits" section is concrete enough to cut-and-paste into Phase `<next>` plan
- [ ] Appendix PR review comment table has resolution status for every comment, not just easy ones
- [ ] Tone: matter-of-fact, technical — no self-congratulation, no hedging

---

_End of Phase `<X>` closure analysis prompt template._