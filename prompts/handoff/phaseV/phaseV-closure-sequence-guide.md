# Phase V Closure — Sequence Guide and File Relationships

_Operational guide for closing Phase V at v7.6.9.5._
_Date: 2026-04-20_

---

## Phase V Closure Boundary Change

Phase V was originally planned to close at v7.6.9.6. That step's scope was:
1. Cloudflare polling fix — move `free_heap`/`uptime_seconds` to public `/api/status`
2. SEC-ADR RV-03 amendment

**v7.6.9.6 is dropped.** The Cloudflare polling issue self-resolved:
- BUG-078 (v7.6.0.1) fixed `init_response_()` mapping 401→500. The browser now receives a proper 401 and shows its native Basic Auth dialog.
- The dashboard successfully polls all auth-gated endpoints through Cloudflare Tunnel after the user enters credentials.
- The remaining issue (random mid-session auth dialogs) is a UX enhancement, not a bug. It's deferred to Phase VX as v7.6.10.4.

**Phase V now closes at v7.6.9.5.**

---

## Closure File Pipeline — Execution Order

These five files form a sequential pipeline. Each depends on the output of the previous one.

### Step 1: Issue Sweep
**File:** `prompts/phaseV/phaseV-issue-sweep-prompt.md`
**What it does:** Walks every open GitHub issue, determines whether Phase V addressed it, produces `prompts/handoff/phaseV/phaseV-issue-sweep-results.md`
**Prerequisite:** v7.6.9.5 merged to main, all changelog entries present
**Output:** `phaseV-issue-sweep-results.md` (new file)

**Updates needed before running:**
- Line 4: change "v7.6.9.6" → "v7.6.9.5"
- Line 10: change "v7.6.7.0 through v7.6.9.6" → "v7.6.7.0 through v7.6.9.5"
- Line 22: change prerequisite version check to 7.6.9.5
- Line 37: same version range update
- Line 54: VERSION must be 7.6.9.5

### Step 2: Pre-Closure Readiness Assessment
**File:** `prompts/handoff/phaseV/phaseV-pre-closure-readiness-assessment.md`
**What it does:** Audits documentation gaps, pipeline health, session log completeness. Produces a BLOCKING / SHOULD-FIX / DEFER categorized report.
**Prerequisite:** v7.6.9.5 merged
**Output:** Categorized readiness report (inline, not a separate file). May produce a cleanup PR prompt.

**Updates needed:** Already delivered in this bundle (full rewrite).

### Step 3: Closure Analysis
**File:** `prompts/phaseV/phaseV-closure-analysis-prompt.md`
**What it does:** Deep quantitative analysis (Q1–Q6 + appendix). Produces `Docs/phase-V-closure-analysis.md`.
**Prerequisite:** Issue sweep results exist AND any BLOCKING items from readiness assessment are resolved.
**Output:** `Docs/phase-V-closure-analysis.md` (~300–500 lines)

**Updates needed before running:**
- Line 4: change "v7.6.9.6" → "v7.6.9.5"
- Line 11: change "v7.6.9.6 merged" → "v7.6.9.5 merged"
- Line 27: change "v7.6.9.6 merged and tagged" → "v7.6.9.5 merged and tagged"
- Line 28: update date check accordingly
- Line 40: version range update
- Line 56: VERSION = 7.6.9.5
- Lines 211–213: update the expected bugs list to include BUG-083 (C3 missing external_components) and note v7.6.9.6 was dropped

### Step 4a: Conclusion Assessment (template to fill)
**File:** `prompts/phaseV/phaseV-conclusion-assessment.md`
**What it does:** Empty template. Operator fills with data from the closure analysis (step 3).
**Prerequisite:** Closure analysis complete.

**Updates needed before filling:**
- Line 13: change "4" to appropriate number for V3 steps (4 original + v7.6.9.4 + v7.6.9.5 = 6)
- Line 14: update total planned from 10 to 12 (or however the actual count works)
- Add V4 and V5 rows to the "What Succeeded" tables
- Note v7.6.9.6 under "What Was Deferred" as "Dropped — issue self-resolved"

### Step 4b: Results (template to fill)
**File:** `prompts/handoff/phaseV/phaseV-results.md`
**What it does:** Empty template. Operator fills with PR numbers, status, metrics from the closure analysis.
**Prerequisite:** Closure analysis complete.

**Updates needed:** Add v7.6.9.5 row to the V3 table. Note v7.6.9.6 as dropped. Fill all PR numbers, agent names, key outcomes from actual execution data.

### Relationship Summary

```
Issue Sweep ──→ Closure Analysis ──→ { Conclusion Assessment
    (data)         (analysis)         { Results Template
                                       (both filled from analysis)
Pre-Closure ──→ Cleanup PR (if needed) ──→ re-run Pre-Closure
 Assessment                                  (verify clean)
```

**None of these files supersede each other.** They are sequential pipeline stages with different outputs:
- Issue sweep: per-issue verdicts (close/keep-open)
- Pre-closure: documentation/pipeline health audit
- Closure analysis: quantitative retrospective
- Conclusion + Results: summary templates for project records

---

## `prompts/prompt-index-and-workflow.md` — Why It Wasn't Updated

### Current state

Last updated at Phase Y closure (v7.6.6.8). Header says "Current Phase: Phase V (pending)." Critical Rules table ends at Rule 63. Step index has no Phase V rows.

### Why

Phase V didn't use the traditional per-step `vX.Y.Z-implementation-instructions-for-coding-agent.md` prompt structure. Phase V used:
- Claude advisory sessions producing agent prompts (the two-step pattern)
- Kiro/GPT/Codex executing those prompts
- Perplexity three-turn PR review

The step index section tracks the old prompt naming convention. Phase V prompts live at `prompts/phaseV/` but with different naming (`v7.6.9.5-agent-prompt-gpt-codex.md`, `v7.6.9.5-claude-two-step.md`).

### What should be updated

This update should happen as part of the Phase V closure cleanup PR (identified by the pre-closure readiness assessment):

1. **Header line:** Update "Last updated" date and "Phase V complete" status
2. **Phase V summary paragraph:** Add below the Phase Y paragraph (line ~150), following the same format:
   ```
   Phase V complete (v7.6.7.0–v7.6.9.5, 2026-04-13 to 2026-04-20). Security hardening (auth guards
   on all write endpoints, SEC-ADR-001), dashboard enhancements (device cards, CSV export, manifest),
   heap-adaptive history cap (#139 partial), C3 stack override fix (BUG-083). N bugs fixed (BUG-082–083),
   N new LESSON-OPS entries, Critical Rules 64+ added. Results: `prompts/handoff/phaseV/phaseV-results.md`.
   ```
3. **Critical Rules table:** Add any rules created during Phase V. Check `Docs/changelog.md` v7.6.7.0–v7.6.9.5 entries for "Critical Rule" references. At minimum, LESSON-OPS-126 (checkpoint grep assertions) from v7.6.9.4 should be checked.
4. **Step index:** Add Phase V rows if the format can accommodate the two-step naming convention, or add a note explaining that Phase V prompts use a different structure.

### When to update

During the pre-closure cleanup PR, not after closure. The closure analysis prompt reads this file (line 72) and needs it to be current.

---

## `prompts/handoff/universal-bug-escalation-prompt.md` — Assessment

### Current state

Generic enough to be phase-agnostic. The operator fills in "Current phase" from a list: `[ Phase V | Phase Y | Phase 7 | other ]`.

### Does it need updating?

**Not urgently.** The structure is generic — it doesn't hardcode phase-specific file paths or version numbers. The operator fills those in per-escalation.

**Minor improvements for whenever it's next touched:**
- Add "Phase VX" to the phase list
- Add a note that Phase V used two-step prompts (not the standard `implementation-instructions-for-coding-agent.md` convention), so the "Agent prompt" field may point to `prompts/phaseV/v7.6.X.Y-agent-prompt-gpt-codex.md`
- Add `dashboard/core/auth.js` to the "if dashboard related" file reading list (after auth refactor ships)

These are non-blocking. The escalation prompt works fine as-is for any bug encountered during Phase V or Phase VX.

---

## Updated Phase V Close → Phase 7 Start Sequence

```
Current: main at v7.6.9.5 (PR#195 merged)
  │
  ├─ NOW: Apply this bundle (3 corrected files + SEC-ADR amendment + issue)
  │       Create GitHub issue for dashboard auth refactor
  │
  ├─ NEXT: Run pre-closure readiness assessment
  │        Fix any BLOCKING/SHOULD-FIX items (cleanup PR)
  │        Update prompt-index-and-workflow.md (in cleanup PR)
  │
  ├─ THEN: Run issue sweep prompt (produces issue-sweep-results.md)
  │
  ├─ THEN: Run closure analysis prompt (produces phase-V-closure-analysis.md)
  │
  ├─ THEN: Fill conclusion-assessment.md and phaseV-results.md from analysis
  │
  ├─ Phase V CLOSED
  │
  ├─ Phase VX: Board onboarding sprint (v7.6.10.0–v7.6.10.3)
  │            + Optional: dashboard auth refactor (v7.6.10.4)
  │
  ├─ Phase VY: Multi-phase planning session
  │            (append both supplements to multi-phase-planning-prompt.md)
  │
  └─ Phase 7 START
```

---

_End of Phase V closure sequence guide._
