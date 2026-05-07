# Concrete Methodology Additions — Bounded, No Scope Explosion

_All additions below are ≤1 page each, target a specific gap, and reuse existing files where possible._
_Each is intended as a NEW file or a clearly-delimited NEW section — no in-place rewrites of the four Phase VY deliverables._

## Addition A — Operating Point Selection (LLM guide new section)

Insert as LLM guide §2.0 (before "Phase Architecture"):

> Each phase declares an operating point at planning time:
>
> | Mode | Reviewers | Closure ceremony | Acceptable bug rate | Use when |
> |---|---|---|---|---|
> | Stabilization | 5 | Full (closure analysis + sweep) | 0 critical at exit | Recovering from incidents, refactor-only phases |
> | Steady | 3-5 | Standard | ≤1 medium at exit | Default for feature phases |
> | Sprint | 2-3 | Minimal (PR description suffices) | ≤2 medium, no critical | Cosmetic, docs, isolated bug fixes |
>
> The mode choice is recorded in the phase plan and visible in CURRENT-STATE.md. Mid-phase mode escalation (Sprint → Steady) is allowed; de-escalation is not.

Closes Gap 4.

## Addition B — Truth-Seeking Discipline (LLM guide §1.4)

Promote from §6.1 trap to a top-level discipline. Four rules, each one sentence with one example.

Closes Gap 9.

## Addition C — Prompt-Production Session Rules

New file: `Docs/writing-guide/prompt-production-rules.md` (~80 lines).

Mandatory pre-prompt-production checklist (mirrors the planning assumption audit but for prompt-production sessions):

```
⛔ PROMPT-PRODUCTION GATE
Before producing any agent / two-step / handoff prompt:

1. Read CURRENT-STATE.md "Last verified" date. If > 1 step old, abort and refresh.
2. For every file path the prompt will reference, run: ls/grep to confirm existence.
3. Choose the operating point (Stabilization / Steady / Sprint) for this step.
4. Confirm the prompt includes:
   [ ] CURRENT-STATE.md as first mandatory read
   [ ] Checkpoints use queries (grep/curl/ls), not line numbers
   [ ] Each checkpoint has the standard failure-comment template
   [ ] §3 Scope Boundary lists files MAY/MUST NOT modify
   [ ] §10 Post-merge deliverables: CURRENT-STATE update, changelog, audit, next handoff
   [ ] Flash/test commands use `esphome upload`, never `run`
   [ ] Labels and milestone to apply (phase/N, type/*, risk/*)
5. State the operating point in the agent prompt header.
```

Closes Gap 5.

## Addition D — Checkpoint Failure Comment Template (dev guide §3.2 patch)

```
⛔ CHECKPOINT FAILED — <name>
Expected: <expected value or condition>
Actual:   <command output>
Command:  <verbatim command>
Action:   STOPPING. NO code changes made. Awaiting operator decision.
```

Closes Gap 7.

## Addition E — Pre-Mortem Template

New file: `Docs/templates/pre-mortem.md` (~40 lines).

```
# Pre-Mortem — Phase <N>

## Premise
"It is now 6 months after Phase <N> shipped. The feature is in production failure mode.
Working backward, list the top 5 plausible failure scenarios."

## Failure scenarios
| # | Failure | Early signal | Prevention added to plan? |
|---|---------|--------------|---------------------------|

## Measurements that would catch each scenario
| Failure # | Measurement | Where instrumented |
|-----------|-------------|--------------------|

## Each prevention measure becomes:
- A step in this phase, OR
- A monitoring/health-check item in CURRENT-STATE.md
- (No third option.)
```

Closes Gap 8 (pre-mortem half).

## Addition F — Component Defaults Audit Template

New file: `Docs/templates/component-defaults-audit.md` (~50 lines).

Stable schema: component name, default value, project-relevant min/max, override location (if any), risk if default is wrong, last verified date / ESPHome version. Diffable across upgrades.

Closes Gap 8 (defaults half).

## Addition G — File-Size Watchdog (preflight check, 4 lines)

Add to `scripts/preflight.sh`:
```bash
# Watchdog: warn if any source file exceeds context-window-friendly size
find firmware/core dashboard/core dashboard/components -type f \( -name '*.h' -o -name '*.js' \) \
  | xargs wc -l 2>/dev/null | awk '$1 > 1500 && $2 != "total" {print "WARN: large file:", $0}'
```
Threshold 1,500 lines = early warning at ~75% of the 2,000-line refactor trigger.

Closes Gap 1 (file-size enforcement).

## Addition H — KPI Recording Template

New file: `Docs/kpi-log.csv` (or table appended to CURRENT-STATE.md).

```
phase,step,version,operating_point,fix_cycles,checkpoint_saves,preventable_findings,wall_clock_h,reviewers,bugs_introduced,bugs_resolved,notes
VX,v7.6.10.0,7.6.10.0,Steady,1,0,2,3,5,0,0,
```

Update is a post-merge deliverable. Trend analysis at phase closure.

Closes Gap 1 (KPI enforcement).

## Addition I — CURRENT-STATE.md Sections Added (4 new rows)

```
## Open Discussions Awaiting Routing
| Thread | Topic | Decision (Issue / State entry / Dismiss) | Date |

## Health Check Latest
| Board | Uptime (d) | min_free_heap | Status |
| (auto from health-check-log.jsonl, last entry) |

## Operating Point — Active Phase
Phase 7: Stabilization (BUG-082 in production, refactor risk high)

## Recommendation Routing Audit
| Source (postmortem / closure) | Recommendation count | Routed to issues | Routed to state | Dismissed | Unrouted (BLOCKING) |
```

Closes Gaps 3, 10.

## Addition J — Issue Mapping Note (planning supplement, 3 lines)

> Issue #137 — cosmetic, deferred indefinitely. Issue #139 — addressed by Phase 7 Step 1.
> Issue #166 — fully superseded by Phase 7 export v2; close on merge of v7.7.x export step.
> Issue #171 — already delivered in Phase VX V1-D; close on merge of Phase VX closure PR.

Closes Gap 11.

## Addition K — ESPHome Upgrade Critical Rule

Add to `prompts/prompt-index-and-workflow.md` Critical Rules:
> **Any ESPHome version bump requires re-running the component defaults audit and committing the diff. PR is blocked until the diff is reviewed and accepted.**

Closes Gap 12.

## Addition L — "Deliverables in PR before merge" rule

Patch dev guide §2.5 — see `audit-5-dev-guide-section-2.5-patched.md` for drop-in replacement.

Closes Gap 2.

## Addition M — Review Orchestration Stub

New file: `scripts/orchestrate-pr-reviews.sh` (~40 lines): when a PR is marked Ready for review, post comments containing the structured external-review prompt for each external reviewer (GPT, Codex). Operator pastes the comment text into the relevant web portal — eliminates the per-step "rewrite the review prompt" overhead. Full automation (API-driven posting) deferred until reviewer APIs stabilize.

Also: one-line correction to LLM guide §4.2 — change "3 reviewers as default, expand to 5 for high-risk" to "5 reviewers, automated where possible; reduce only when phase declares Sprint operating point."

Closes Gap 6.
