# Phase VY — Methodology Gap Analysis

_What the conversation raised that the four deliverables do not adequately solve._

## Gap 1 — Process rules without enforcement (medium-impact, broad)

Several rules are stated but lack a mechanism that prevents their violation. The BUG-075-076 → BUG-083 gap was caused by exactly this pattern (recommendation existed, mechanism didn't), so this is not a stylistic complaint.

| Rule | Where stated | Missing mechanism |
|---|---|---|
| Track file sizes; plan refactor at 2,000 lines | LLM guide §6.3 | No preflight check or CI gate. A 5-line bash addition to `scripts/preflight.sh` would close this. |
| KPIs per step (fix cycles, wall-clock, checkpoint saves) | Dev guide §6 | No template/script captures them. CURRENT-STATE.md table is manually filled. |
| Update CURRENT-STATE.md after every merge | Dev guide §2.5 | No CI check that the file's "Last verified" date is within the last merge. |
| Update writing guide at every phase closure | Dev guide §4.3 | No closure checklist line item that *blocks* phase closure if the writing guide is unchanged. |
| Postmortems route recommendations → issue OR state file (no third option) | Dev guide §5.2 | No template wraps a postmortem so the recommendations are forced into one of those slots. |

## Gap 2 — "Deliverables in PR before merge" (operator proposal #2 — missed)

Operator's `Redisingning-development-locally.txt` proposed: *"The consolidated audit files, update of next step handoff and agent prompts should be posted in the PR itself and PR should be merged when all goals of the step has been accomplished and it is ready to be merged with all deliverables."*

The dev guide §2.5 still treats these as **post-merge** mandatory deliverables. That keeps the documentation drift problem alive — when the next step starts, the previous step's audit might still be in flight.

**Fix:** Move CURRENT-STATE update, consolidated audit, and next-step handoff edits into the PR. Merge gate = all four exist on the branch. See `audit-5-dev-guide-section-2.5-patched.md` for drop-in replacement.

## Gap 3 — GitHub Discussions ignored

Operator answered (Q/A-1): *"You should also check Discussions section in repo where I started to put questions/ideas to document them instead of having them only in the architectural documents."*

None of the four deliverables mentions Discussions. CURRENT-STATE.md has no "Open discussion threads" pointer. The assumption-audit gate doesn't include "scan recent Discussions."

**Fix:** Add to the assumption-audit gate: "List the 3 most recent Discussions threads. For each, decide: become an Issue / become a CURRENT-STATE entry / dismiss with rationale." Add a row to CURRENT-STATE.md template: "Open Discussions awaiting routing."

## Gap 4 — Hard Q: "Where on the speed-quality-documentation curve do I want to be?"

Raised explicitly in answer-2 and acknowledged by operator in Q/A-2. The deliverables only address LLM tier cost (which model for which job). They do not give the operator a framework for deciding *whether* to spend a month on Phase V/Y/VX-style stabilization vs. accept some bug risk for faster feature shipping.

**Fix:** Add a section to the LLM guide ("Operating Point Selection") that defines three modes — Stabilization, Steady, Sprint — with explicit reviewer counts, doc requirements, and acceptable bug-discovery rates per mode. Each phase declares its mode at planning time.

## Gap 5 — No meta-prompt for prompt-production sessions

Operator's answer-3 contains the strongest statement of this gap: *"when producing prompts, these prompt producing prompt should have its own rules/checkpoints that would make sure than in prompt will go section that would update documentation."*

The methodology audit gate exists for *planning* sessions. There is **no equivalent for prompt-production sessions**. This means future Claude sessions producing the agent/two-step/handoff bundle for v7.7.0.x can skip:
- "Verify CURRENT-STATE.md is current"
- "Run the assumption audit"
- "Confirm post-merge deliverables include CURRENT-STATE update"
- "Confirm the prompt's checkpoints use queries not line numbers"
- "Confirm the prompt's failure-handling text says STOP, not FIX"

**Fix:** Add `Docs/writing-guide/prompt-production-session-rules.md` (or extend `methodology.md` §X) with the meta-prompt template every prompt-production session reads first.

## Gap 6 — Review orchestration automation not delivered

Operator (Q/A-3): *"Drop to 3 reviewers from 5. — No, there were number of cases when one from three reviewers found something that others could not. ... I just need to have means automate GPT/Codex reviews."*

Both guides describe automation as the "highest-leverage time optimization" but neither ships:
- A GitHub Action that triggers GPT/Codex reviews when a PR moves to "Ready for review."
- A shell script that collates the 5 review outputs into a consolidated audit file.

The LLM guide §4.2 still recommends 3 reviewers as default. This is the one place the deliverables contradict operator preference.

**Fix:** (a) Correct LLM guide §4.2 to "5 reviewers, automated where possible." (b) Add `scripts/orchestrate-pr-reviews.sh` skeleton that comments on the PR with instructions for each external reviewer (or, where APIs allow, posts the prompt directly).

## Gap 7 — Checkpoint failure handling — agent comment template missing

Operator (Q/A-3): *"in v7.6.10.4 agent stumbled on checkpoints several times. How this can be thought after?"*

Answered with: queries-not-assertions + stop-don't-fix semantics. Both correct but insufficient. Agents need an *exact comment template* to post when a checkpoint fails — otherwise some agents still try to "explain away" the discrepancy.

**Fix:** Add to dev guide §3.2:

```
⛔ CHECKPOINT FAILED — <checkpoint name>
Expected: <expected>
Actual:   <command output>
Command:  <verbatim command>
Action:   STOPPING. NO code changes made. Awaiting operator decision.
```

## Gap 8 — Pre-mortem and ESPHome-defaults templates absent

Both Phase 7 Step -1 (defaults audit) and pre-mortem analysis are referenced as practices but neither has a template. Without templates, the first execution will be ad-hoc, the second will diverge, and the practice will erode within 2-3 phases — exactly the failure pattern of BUG-075-076.

**Fix:** Two short templates (~50 lines each) under `Docs/templates/`: `pre-mortem.md` and `component-defaults-audit.md`.

## Gap 9 — Truth-seeking not elevated to a named discipline

Operator's hard-questions text: *"YOUR PRIMARY OBJECTIVE MUST BE TRUTH SEEKING. Before moving to more complex explanations, ALL simpler explanation need to be eliminated first."*

This appears as one of several traps in LLM guide §6. Given the operator's strong framing and the multi-day cost of the C3 incident, it deserves a top-level section, not a sub-section of "pitfalls."

**Fix:** Promote to LLM guide §1.4 "The Truth-Seeking Discipline" with the four rules:
1. Confirm WHAT before hypothesizing WHY.
2. Eliminate the simplest explanation first.
3. State assumptions and verify each one.
4. When evidence and narrative diverge, evidence wins — even when the narrative is yours.

## Gap 10 — CURRENT-STATE.md not wired to health-check log

Operator (Q/A-3): *"can this script be part of above mentioned CURRENT-STATE.md that needs to be updated if something has been up and running something like >1 week."*

The planning supplement ships the cron script and writes to `Docs/health-check-log.jsonl`. CURRENT-STATE.md has no section that ingests this log. The "if min_free_heap < 15,000, flag it" rule has no mechanism.

**Fix:** Add to CURRENT-STATE.md a "Health Check Latest" row sourced from the last entry of `health-check-log.jsonl`, with a one-line rule: "If oldest board uptime > 14 days and min_free_heap < threshold, raise to Open Issues."

## Gap 11 — Issues #166 and #171 not individually mapped to Phase 7

Issue #137 (cosmetic) and #139 (BUG-082) are addressed. #166 (manifest-driven CSV columns) and #171 (import crash fix) appear only as a passing note in answer-3's table. The planning supplement does not state explicitly whether Phase 7 v2 export/import supersedes them or whether they need standalone tasks.

**Fix:** One-paragraph addendum in the planning supplement under "Phase 7 Reordering": explicit statement that #171 is delivered (close on merge of Phase VX) and #166 partial → fully replaced by Phase 7 export v2.

## Gap 12 — Component defaults audit lacks "rerun on upgrade" rule

Operator (Q/A-3) suggested: *"if ESPhome version needs to be updated, then re-run discovery."*

The Phase 7 Step -1 audit is one-shot. No rule binds the next ESPHome upgrade to a defaults re-audit.

**Fix:** Add a critical rule to `prompts/prompt-index-and-workflow.md`: "Any ESPHome version bump requires diffing the component defaults audit against the prior version. PR is blocked until diff is reviewed."
