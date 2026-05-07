# Prioritized Recommendations — Phase VY Methodology Patch Plan

_Severity reflects risk of repeating a documented failure mode, not document polish._
_Per operator direction (2026-05-07), all items are rolled into Phase 7 (not pre-planning-session)._

## BLOCKING — must be applied during Phase 7 Step 0 / Step -1

| # | Item | Why blocking | Effort |
|---|------|-------------|--------|
| B1 | Reviewer count contradiction (LLM guide §4.2 says 3 default; operator said 5 + automate) | Methodology document directly contradicts operator preference. Future contributors will read the wrong rule. | 5 min |
| B2 | Add Prompt-Production Session Rules (Addition C) | Without this, the assumption-audit gate doesn't apply to the prompts that will drive every Phase 7 step. Same class of gap that caused BUG-075-076. | 30 min |
| B3 | Recommendation routing — verify all current open recs are routed | The "no third option" rule must be applied to the existing backlog before Phase 7 starts merging steps, otherwise the rule starts in violation. | 15 min |
| B4 | Patch dev guide §2.5 "deliverables in PR before merge" (Addition L) | Operator's stated preference is missed; without this, doc drift restarts on PR #1 of Phase 7. | 10 min |

## HIGH — apply during Phase 7 Step 0

| # | Item | Why | Effort |
|---|------|-----|--------|
| H1 | Truth-Seeking discipline elevated to LLM guide §1.4 (Addition B) | Top operator concern; currently buried as one trap among many. | 15 min |
| H2 | Operating Point Selection added (Addition A) | Answers operator's missed hard question on the speed/quality curve. Prevents another month-long stabilization-by-default. | 30 min |
| H3 | Checkpoint failure comment template (Addition D) | Closes the v7.6.10.4 stumble pattern. | 5 min |
| H4 | Pre-mortem and component-defaults audit templates (Additions E, F) | Without templates, the practices erode in 2-3 phases. | 1 hour |
| H5 | CURRENT-STATE.md sections added (Addition I) | Wires Discussions, health-check log, operating point, and recommendation routing into the file every session reads. | 20 min |
| H6 | File-size watchdog in preflight (Addition G) | Cheap insurance against the next context-cliff. | 5 min |
| H7 | Issue mapping note for #166 / #171 (Addition J) | Removes ambiguity at planning time. | 5 min |
| H8 | ESPHome upgrade critical rule (Addition K) | One-line rule prevents the next "defaults changed and we didn't notice." | 5 min |

## MEDIUM — finish before Phase 7 closure

| # | Item | Why | Effort |
|---|------|-----|--------|
| M1 | KPI recording template + first 3 rows backfilled (Addition H) | Without rows, trend analysis is impossible. Backfill from existing phase-results docs. | 1 hour |
| M2 | Review orchestration stub (Addition M) | Operator explicitly asked. Even a half-automated version saves 15-30 min/step. | 1-2 hours |
| M3 | Discussions integration in assumption audit gate | One-line addition; closes Gap 3. | 5 min |
| M4 | Promote postmortems out of `Docs/archive/` until all recs are routed | Location was a contributing factor to BUG-075-076 being forgotten. | 15 min |
| M5 | LLM guide Appendix B expanded with concrete bootstrap commands | Reusability for other projects. | 30 min |

## LOW — opportunistic

| # | Item | Why | Effort |
|---|------|-----|--------|
| L1 | Concrete two-session parallelism walkthrough transcribed from answer-4 | Improves understandability of the parallelism model. | 20 min |
| L2 | "How a step is run end-to-end" walkthrough doc for new contributors | Lowers onboarding time. | 1 hour |
| L3 | Cross-link CURRENT-STATE.md → decision-log.md → ADR docs | Better retrievability. | 15 min |

## Total effort to BLOCKING + HIGH

≈ 3.5 hours of focused work. Fits inside Phase 7 Step 0 / Step -1 alongside the measurement baseline.

## Quality bar reminder

Per the methodology audit's own discipline: each item above corresponds to a **specific quote from the conversation** or a **specific failure mode in repo history**. None are speculative "would be nice."

## Phase 7 integration mapping

| Phase 7 step | Audit items applied here |
|---|---|
| Step -1 (component defaults audit) | H4 (defaults template) — required for the audit itself |
| Step 0 (measurement baseline + health-check task) | B1, B2, B3, B4, H1, H2, H3, H5, H6, H7, H8 |
| Step 1 (chunked streaming / BUG-082) | M3 (assumption audit Discussions row) |
| Phase 7 closure | M1, M2, M4, M5 |
