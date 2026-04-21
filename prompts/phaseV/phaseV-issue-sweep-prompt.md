# Phase V — Issue Sweep Prompt

_Run this prompt in a fresh Claude session AFTER v7.6.9.5 merges, BEFORE running `phaseV-closure-analysis-prompt.md`._
_Purpose: walk every open GitHub issue, determine whether Phase V addressed it, produce a per-issue closure verdict with a ready-to-paste GitHub comment or a "keep open" rationale with specific remaining work._

---

## When to Use

Run this prompt after all Phase V steps (v7.6.7.0 through v7.6.9.5) have merged to `main`. The sweep produces the data that feeds `phaseV-closure-analysis-prompt.md`'s Q5 (Outstanding Issues) section and that populates `prompts/handoff/phaseV/phaseV-results.md`'s "Issues Resolved" table.

Do NOT run this prompt while Phase V steps are still in flight — the sweep's verdicts depend on the full delivery being observable on `main`.

Do NOT run this prompt before checking that GitHub API rate limits are not exhausted for the session — the sweep pulls one issue body per open issue plus the full changelog, which is a measurable API cost.

---

## Prerequisites

Before starting, the operator must confirm:

- [ ] v7.6.9.5 has been merged to `main` and tagged
- [ ] `Docs/changelog.md` contains entries for every Phase V step (v7.6.7.0 through v7.6.9.5)
- [ ] All Phase V PR numbers are known (operator has them in `phaseV-results.md` or in notes)
- [ ] GitHub authentication is available (either gh CLI token or the session has an MCP GitHub connector)
- [ ] No Phase 7 work has started yet — main is at the Phase V closure state, not later

---

## Template

---

**Phase V Issue Sweep**

You are performing an issue-closure audit for Phase V (v7.6.7.0 through v7.6.9.5) of the ESP32-GW Multi-Sensor Gateway project.

Repo: `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`

Your job is to walk every currently-open GitHub issue, determine whether Phase V shipped a fix, and for each issue produce EITHER:
- A **closure verdict** with a ready-to-paste GitHub comment and the recommended close action, OR
- A **keep-open verdict** with specific remaining work, target phase or version, and the rationale for not closing now

### ⚠️ Read Before Responding

Your training data may be stale. You MUST read the actual current state of the repo and issues — do NOT rely on memory of previous sessions. Specifically:

1. **Clone and check out `main`:**
   ```
   git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
   cd ESP32-GW-multi-sensor
   git checkout main
   git pull
   cat VERSION   # must be 7.6.9.5
   git tag -l | grep v7.6.9   # must include v7.6.9.0 through v7.6.9.5
   ```

2. **Read the full Phase V changelog:** `Docs/changelog.md` — from the first v7.6.7.0 entry through the v7.6.9.5 entry. Note every issue number cited in "Fixed", "Added", "Changed", or "Related" sub-sections.

3. **Read the Phase V plan and the addendum:**
   - `Docs/phase-V-implementation-plan.md` — Part 0 issue table at line ~39 lists the 14 originally-tracked issues with their planned disposition and milestones
   - `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` — carve-out for #139 partial fix

4. **Fetch the current open-issues list** (do NOT assume the Plan Part 0 table is current — new issues may have been opened since plan finalisation):
   ```
   gh issue list --state open --limit 100 --json number,title,labels,milestone,createdAt,updatedAt
   ```
   Or via GitHub API:
   ```
   curl -s "https://api.github.com/repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues?state=open&per_page=100"
   ```
   Filter out pull requests (the issues endpoint returns both — drop any item with a `pull_request` field).

5. **Fetch each open issue's full body and comment thread:**
   ```
   curl -s "https://api.github.com/repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/<N>"
   curl -s "https://api.github.com/repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/issues/<N>/comments"
   ```
   Read them. Do NOT rely on the title alone — operators update the body with "resolved by" or "partial fix shipped in" notes that the title never reflects.

---

### Per-Issue Protocol

For each open issue, execute this protocol in order. Do NOT skip steps.

**Step 1 — Locate the Phase V plan's stated disposition**

Search `Docs/phase-V-implementation-plan.md` for the issue number. Every issue in Part 0's table (lines 39–54) has a planned milestone. Record:
- Planned milestone (e.g. `v7.6.9.x`, `Deferred (Phase 7+)`, `Partial v7.6.8.x, full Phase 7`)
- Planned sub-phase (V1, V2, V3, V4, V5, V6) if the issue appears in a step's "Files modified" or "Issues closed" block
- If the issue is NOT in the Plan Part 0 table, note it as "Post-plan issue — opened after plan finalisation"

**Step 2 — Find all changelog references**

```
grep -n "#<N>\b" Docs/changelog.md
```

Record every changelog line that references the issue number. Note the version each reference sits under.

**Step 3 — Find all PR references**

```
gh pr list --state merged --search "#<N>" --limit 20
```
Or search commit messages:
```
git log --oneline --all --grep="#<N>"
```

Record every merged PR that cites the issue.

**Step 4 — Read the issue body and comments**

Fetch the full issue JSON per the instructions above. Read:
- The current body — does it describe the symptom, the acceptance criteria, or the root cause?
- Every comment — especially any comments from the owner saying "still urgent", "worse than we thought", or "fix landed in PR #X"
- Labels and milestone — are they current?

**Step 5 — Classify the issue's current state**

Pick ONE classification from this list:

| Classification | Meaning |
|---|---|
| FIXED_FULLY | Phase V shipped a complete fix. Issue can be closed. |
| FIXED_PARTIALLY | Phase V shipped a partial fix. Acceptance criteria not fully met. Keep open with a tick-list of remaining work. |
| NOT_ADDRESSED | Phase V made no attempt. Remains as originally scoped. |
| SUPERSEDED | Phase V or downstream work made the issue moot (e.g. a subsystem was removed). Close with a superseded-by comment. |
| DEFERRED_INTENTIONAL | Plan explicitly deferred to a later phase. Keep open with the target phase named. |
| OUT_OF_SCOPE | Issue is real but not what Phase V was designed to address. Keep open with a target phase recommendation. |
| STALE | Symptom no longer reproduces; root cause not actually fixed by Phase V, but the bug appears to have resolved itself (e.g. dependency update). Close with a verify-on-next-release comment. |

If the issue body mentions a specific reproducer, run it against current `main` where possible (for firmware issues: correlate with v7.6.9.5 device test results in session logs). Do not mark FIXED_FULLY without evidence the reproducer no longer triggers.

**Step 6 — Draft the closure or keep-open comment**

For FIXED_FULLY:
```
Fixed in Phase V <sub-phase> (<version>), PR #<NN>.

Summary of fix: <one-paragraph description tied to the issue's acceptance criteria>.

Verification:
- <specific command, test, or device measurement from a session log>
- <link to the relevant session log or audit>

Closing.
```

For FIXED_PARTIALLY:
```
Partial fix landed in Phase V <sub-phase> (<version>), PR #<NN>.

What was addressed:
- <specific>
- <specific>

What remains:
- [ ] <specific remaining work>
- [ ] <specific remaining work>

Target for full fix: <phase or version>.

Leaving open.
```

For DEFERRED_INTENTIONAL:
```
Deferred from Phase V per plan (<link to `Docs/phase-V-implementation-plan.md` section or line>).

Reason: <one-sentence rationale from the plan>.

Target phase: <Phase 7 / Phase E / etc>.

Will be addressed in: <version range if known>.

Leaving open.
```

For STALE:
```
Symptom no longer reproduces as of v7.6.9.5 (verified <date>) via <specific command or test>.

Root cause was not explicitly fixed by Phase V; the failure mode appears to have resolved via <dependency update / configuration change / side effect of unrelated work>.

Closing provisionally. Please reopen if the symptom returns.
```

For NOT_ADDRESSED, SUPERSEDED, OUT_OF_SCOPE: tailor similarly — be specific about why.

**Step 7 — Check labels and milestone**

For issues left open, verify the labels match the Plan Part 0 table (`bug`/`enhancement`/`feature`/`decision`/`tech-debt`/`security`/`memory`/`esp32-c3`/`dashboard`/`optimization`). Note any label discrepancies and include a label update recommendation in the output.

---

### Output Format

Produce a single markdown document at `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` with the following structure:

```markdown
# Phase V Issue Sweep Results

_Sweep date: <ISO date>_
_Swept at commit: <main SHA>_
_VERSION at sweep: <value of VERSION file>_
_Sweeper: <LLM / model used>_

---

## Summary

| Classification | Count | Issues |
|---|---|---|
| FIXED_FULLY | N | #N1, #N2, ... |
| FIXED_PARTIALLY | N | #N, #N |
| NOT_ADDRESSED | N | #N, #N |
| SUPERSEDED | N | #N |
| DEFERRED_INTENTIONAL | N | #N, #N |
| OUT_OF_SCOPE | N | #N |
| STALE | N | #N |
| **Total open at sweep** | **N** | |

**Recommended closures this session:** N issues
**Recommended keep-open with updated comment:** N issues
**Flagged for phaseV-closure-analysis review (anything not cleanly classifiable):** N issues

---

## Per-Issue Results

### #<N> — <Title>

**Classification:** FIXED_FULLY | FIXED_PARTIALLY | NOT_ADDRESSED | SUPERSEDED | DEFERRED_INTENTIONAL | OUT_OF_SCOPE | STALE

**Planned in:** <sub-phase and version from Plan Part 0, or "Post-plan"> 
**Actually touched by:** <list of PR numbers from Step 3, or "None">
**Changelog references:** <list of versions from Step 2, or "None">

**Analysis:**
<2-4 sentences tying the issue's acceptance criteria to what actually shipped. Cite specific files, functions, or test results.>

**Recommended GitHub action:**
- [ ] Close with comment below
- [ ] Keep open with comment below
- [ ] Keep open, update labels: <list>
- [ ] Keep open, update milestone: <value>

**Recommended comment (copy-paste ready):**
```
<draft comment text>
```

---

(Repeat for every open issue.)

---

## Issues Not in Phase V Plan's Part 0 Table

Issues opened after plan finalisation but still open at sweep time. Each should have an explicit classification and target phase.

### #<N> — <Title>
<Same per-issue structure as above.>

---

## Post-Sweep Actions

Actions for the operator to execute AFTER reviewing this document:

1. **Apply recommended closures** (N issues): paste each comment, close issue, reference the sweep document
2. **Apply recommended label/milestone updates** (N issues): per per-issue recommendations
3. **Input for phaseV-closure-analysis-prompt.md Q5:** deferred and FIXED_PARTIALLY sections enumerate what Phase V did NOT complete — closure analysis uses this to answer "What Phase 7 inherits"
4. **Input for phaseV-results.md:** the "Issues Resolved" table is populated from the FIXED_FULLY + FIXED_PARTIALLY + SUPERSEDED classifications; the "Deferred" table is populated from DEFERRED_INTENTIONAL + OUT_OF_SCOPE + NOT_ADDRESSED

---

## Sweep Quality Self-Check

Before submitting the sweep document, the reviewer confirms:

- [ ] Every open issue on GitHub at sweep time is covered in the per-issue section (no omissions)
- [ ] No issue is classified FIXED_FULLY without a specific PR number and a changelog entry
- [ ] No issue is classified FIXED_PARTIALLY without a specific tick-list of remaining work
- [ ] Every DEFERRED_INTENTIONAL classification cites a specific line of `Docs/phase-V-implementation-plan.md` or the addendum
- [ ] Every STALE classification includes a concrete reproducer attempt and its result
- [ ] Comments are phrased in a tone consistent with existing repo issue comments (matter-of-fact, technical, no hype)
- [ ] No comment promises a specific Phase 7 delivery date (use "planned for Phase 7 / v7.7.x" not "will ship in <date>")
- [ ] Label recommendations match the Plan Part 0 taxonomy
- [ ] Sweep date, commit SHA, and VERSION are recorded at the top

---

_End of Phase V Issue Sweep Results._
```

---

## Interaction notes for the advisor running this prompt

- **Expect ~15–25 open issues at sweep time.** The Plan Part 0 table has 14; a few more will have been opened during execution. Don't be surprised by slightly more.
- **Several issues will resist clean classification.** That's normal. Flag them explicitly in the summary count as "ambiguous — see closure analysis" rather than forcing a category. The closure analysis prompt will revisit them.
- **Do not close issues yourself.** Produce the draft comments and recommended actions. Actual GitHub state changes are operator-executed so the sweep output can be reviewed first.
- **Check the aggregator issues carefully.** Aggregator-related issues (#161, #162, #170) often have subtle state. #162 was closed via an ADR commit, not a code fix — that's still FIXED_FULLY but the fix-type is documentation, not code. Be explicit about this in the analysis.
- **Carry forward #139 disposition carefully.** #139 is FIXED_PARTIALLY (Phase V addendum says so). The full fix is Phase 7. The remaining-work tick-list should match the addendum's text verbatim: chunked streaming, paged loader, per-device storage.
- **Use timing signals.** If an issue has a comment from 2026-04+ saying "getting urgent" and Phase V landed a mitigation, the classification is FIXED_PARTIALLY; if Phase V made no attempt despite the urgency signal, that's a NOT_ADDRESSED and belongs in the closure analysis as a process failure worth flagging.

---

_End of Phase V issue sweep prompt._
