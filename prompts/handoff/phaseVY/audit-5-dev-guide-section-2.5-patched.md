# Patched §2.5 — Drop-in Replacement for `Docs/development-process-guide.md` §2.5

_This file is a candidate replacement, not yet applied. Original `Docs/development-process-guide.md` §2.5 is unchanged._
_Apply during Phase 7 Step 0 (B4 in `audit-4-priorities.md`)._

---

### 2.5 Step Deliverables (in-PR, before merge)

The PR is the single source of truth for a step. A step is not "done" until the
PR contains all of its deliverables. Reviewers and the merge gate verify the
list below. Post-merge work is limited to mechanical bookkeeping that depends
on the merge commit SHA (e.g., final tag, follow-up issue creation).

#### 2.5.1 In-PR mandatory deliverables (merge gate)

Before a PR may be marked "Ready to merge," the branch MUST contain:

1. **Code changes** — the actual implementation, with all checkpoints satisfied
   (or a checkpoint-failure comment posted and accepted by the operator).
2. **`CURRENT-STATE.md` update** — at minimum: bump "Last verified" date, append
   to "What Just Shipped," update "What's Next," add/remove "Open Issues" and
   "Unimplemented Recommendations." If `health-check-log.jsonl` rolled over a
   week boundary, update "Health Check Latest."
3. **Changelog entry** — `Docs/changelog.md` entry under the new version.
4. **Consolidated audit file** — for non-trivial steps. Templates in
   `prompts/<phase>/consolidated-audit-template-<phase>.md`. Includes:
   - All review findings with severity (Blocking / High / Medium / Low / Cosmetic)
   - Agent autonomous decisions (helpful / harmful / neutral)
   - Prompt Quality Score (KPI fields per `Docs/kpi-log.csv`)
5. **Next-step session handoff updates** — `prompts/handoff/<phase>/session-handoff-<next>.md`
   updated to reflect anything the next step's prompts must change. If the next
   step's agent or two-step prompts also need updates, edit them in this PR.
6. **Labels applied** — `phase/N`, `type/*`, `risk/*`. Linked to phase milestone.
7. **Operating point declared** — header of the PR description states the
   operating point chosen at planning time (Stabilization / Steady / Sprint).
8. **Recommendation routing audit** — if this step produced new recommendations
   (postmortem-style or closure-style), each one is recorded in CURRENT-STATE.md
   "Unimplemented Recommendations" OR opened as a GitHub Issue. **No third option.**

#### 2.5.2 Merge gate checklist (paste into PR description)

```
- [ ] Code passes preflight (`bash scripts/preflight.sh`)
- [ ] All checkpoints satisfied or failure comments accepted
- [ ] CURRENT-STATE.md updated and "Last verified" bumped
- [ ] Changelog entry added
- [ ] Consolidated audit committed (or N/A for trivial step — justify in PR)
- [ ] Next-step handoff/prompts updated (or N/A)
- [ ] Labels + milestone applied
- [ ] Operating point declared in PR header
- [ ] All new recommendations routed (issues opened or state file updated)
- [ ] KPI row appended to `Docs/kpi-log.csv`
```

#### 2.5.3 Post-merge mechanical work (bookkeeping only)

After merge:
- Tag the release if this step is a version increment (`scripts/bump-version.sh`).
- Close any GitHub Issues that this PR resolves (linked via "Fixes #N").
- Move the milestone progress bar (automatic if PRs are linked).

Anything that is not strictly post-merge bookkeeping is a sign the deliverable
should have been in the PR. If you find yourself opening "documentation update"
PRs the day after a merge, that's the drift this rule prevents.

#### 2.5.4 Rationale

This section was patched in Phase VY (post-audit). Prior to the patch,
deliverables 2–5 above were "post-merge mandatory," which produced consistent
documentation drift between merge and the next step's start. Operator proposal
documented in `prompts/phaseVY/Redisingning-development-locally.txt`:
*"The consolidated audit files, update of next step handoff and agent prompts
should be posted in the PR itself and PR should be merged when all goals of the
step has been accomplished and it is ready to be merged with all deliverables."*
