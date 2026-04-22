# Phase V — Post-Sweep Actions Agent Prompt

_Run this prompt in a fresh coding-agent session after `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` exists on `main`._
_Prerequisites: `issues: write` granted to the repository's workflow token._

---

## What this prompt does

This agent session performs three distinct tasks in order:

1. **Execute all Post-Sweep Actions** — post the recommended keep-open comments and apply label/milestone updates for all 6 open issues, exactly as specified in `prompts/handoff/phaseV/phaseV-issue-sweep-results.md`.
2. **Update the sweep results doc** — tick off each completed action in the Post-Sweep Actions checklist and record the actual GitHub comment URL for each posted comment.
3. **Rebuild the Issues Resolved and Deferred tables in `prompts/handoff/phaseV/phaseV-results.md`** — using the sweep results, the changelog, and the actual closed-issue list from the GitHub API to produce a clean, accurate, fully-referenced record.

All three tasks ship in a single PR against `main`.

---

## Step 0 — Verify prerequisites

Before doing anything else, confirm:

```bash
cat VERSION   # must be 7.6.9.5
gh auth status   # must be authenticated
gh api repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor --jq '.permissions'
# must include "issues": true
```

Read `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` in full. This is the authoritative source for all actions in Task 1. Do NOT rely on memory — re-read each per-issue section before acting on it.

---

## Task 1 — Execute Post-Sweep Actions

### 1A — Create missing labels

The sweep results reference labels that may not exist yet. Before applying labels, ensure all required labels exist. Create any missing ones:

```bash
# Check existing labels
gh label list --limit 100

# Create if missing (use these exact names and colours):
gh label create "feature"      --color "#a2eeef" --description "New feature request"          2>/dev/null || true
gh label create "memory"       --color "#e4e669" --description "Heap / SRAM related"          2>/dev/null || true
gh label create "esp32-c3"     --color "#c2e0c6" --description "ESP32-C3 specific"            2>/dev/null || true
gh label create "optimization" --color "#f9d0c4" --description "Performance / size reduction" 2>/dev/null || true
gh label create "ux"           --color "#d93f0b" --description "User experience"              2>/dev/null || true
```

Existing labels (`bug`, `enhancement`, `dashboard`, `security`) must NOT be recreated.

### 1B — Create missing milestones

The sweep results reference two milestones. Create them if they do not exist:

```bash
gh api repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/milestones --jq '.[].title'

# Create if missing:
gh api repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/milestones \
  -X POST -f title="Phase 7 (v7.7.x)" \
  -f description="Phase 7 — persistence engine, aggregator history, chunked streaming" \
  2>/dev/null || true

gh api repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/milestones \
  -X POST -f title="Phase VX (v7.6.10.x)" \
  -f description="Phase VX — board onboarding sprint and auth refactor" \
  2>/dev/null || true
```

Record the numeric IDs of both milestones; you will need them for the `edit` commands below.

### 1C — Apply label and milestone updates (6 issues)

For each issue, apply exactly the labels and milestone listed in its "Recommended GitHub action" section. Use `gh issue edit`. Do NOT remove labels that already exist on an issue — only add.

```bash
# #137 — add: feature, dashboard; milestone: Phase 7 (v7.7.x)  [DEFERRED_INTENTIONAL]
gh issue edit 137 --add-label "feature,dashboard" --milestone "Phase 7 (v7.7.x)"

# #139 — add: bug, memory, esp32-c3; milestone: Phase 7 (v7.7.x)  [FIXED_PARTIALLY]
gh issue edit 139 --add-label "bug,memory,esp32-c3" --milestone "Phase 7 (v7.7.x)"

# #166 — add: enhancement, dashboard; milestone: Phase 7 (v7.7.x)  [FIXED_PARTIALLY]
gh issue edit 166 --add-label "enhancement,dashboard" --milestone "Phase 7 (v7.7.x)"

# #171 — add: bug, esp32-c3; milestone: Phase 7 (v7.7.x)  [FIXED_PARTIALLY]
gh issue edit 171 --add-label "bug,esp32-c3" --milestone "Phase 7 (v7.7.x)"

# #190 — add: enhancement, dashboard; milestone: Phase VX (v7.6.10.x)  [OUT_OF_SCOPE]
gh issue edit 190 --add-label "enhancement,dashboard" --milestone "Phase VX (v7.6.10.x)"

# #196 — add: enhancement, dashboard, ux, security; milestone: Phase VX (v7.6.10.x) already set
gh issue edit 196 --add-label "enhancement,dashboard,ux,security" --milestone "Phase VX (v7.6.10.x)"
```

Verify each edit succeeded:
```bash
for n in 137 139 166 171 190 196; do
  echo "=== #$n ===" && gh issue view $n --json labels,milestone --jq '{labels:[.labels[].name],milestone:.milestone.title}'
done
```

### 1D — Post keep-open comments (6 issues)

For each issue, post the exact comment text from the "Recommended comment (copy-paste ready)" section in `prompts/handoff/phaseV/phaseV-issue-sweep-results.md`.

**Read the comment text from the file — do NOT paraphrase or abbreviate it.** The comments are the authoritative record.

Implementation approach: extract each comment block to a temp file, then post with `gh issue comment <N> --body-file /tmp/comment_<N>.md`. Parse the comment boundaries from the sweep results doc by finding the triple-backtick code block that follows each "Recommended comment (copy-paste ready):" heading and ends before the next `---` separator.

Record each returned comment URL — you will need them for Task 2.

---

## Task 2 — Update the sweep results doc

Edit `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` to:

1. In the **Post-Sweep Actions** section, replace each `⚠️ MANUAL` marker with `✅ Complete (2026-04-22)`.
2. For each issue in the per-issue section, update the "Recommended GitHub action" checkboxes:
   - Tick `[x]` for every action that was executed.
   - Below the checkbox list, add a line: `_Comment posted: <URL>_` (the URL from Task 1D).
3. Update the **Sweep Quality Self-Check** section checkboxes to all `[x]`.
4. Add a footer line at the very end (before `_End of Phase V Issue Sweep Results._`):

```
_Post-sweep actions executed: 2026-04-22 by GitHub Copilot Coding Agent._
```

---

## Task 3 — Rebuild phaseV-results.md Issue tables

### 3A — Fetch the full closed-issues list

```bash
gh issue list --state closed --limit 200 --json number,title,closedAt,labels,milestone \
  | jq 'sort_by(.number)'
```

Filter to only issues closed during Phase V (closed between 2026-04-14 and 2026-04-22 inclusive), or referenced in `Docs/changelog.md` under the v7.6.7.x–v7.6.9.5 range.

### 3B — Read the Phase V PR map

Read the following files to get the authoritative version → PR mapping:

```
prompts/phaseV/v7.6.7.0-PR176-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.7.1-PR177-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.7.2-PR178-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.8.0-PR180-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.8.1-PR181-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.8.2-PR182-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.9.0-PR183-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.9.1-PR184-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.9.2-PR191-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.9.3-PR192-consolidated-audit-and-lessons.md
prompts/phaseV/v7.6.9.4-agent-prompt-gpt-codex.md   # find PR # in body
prompts/phaseV/v7.6.9.5-agent-prompt-gpt-codex.md   # find PR # in body
```

For v7.6.9.4 and v7.6.9.5, extract the PR number from the agent prompt body or from `prompts/handoff/phaseV/session-handoff-v7.6.9.4.md` and `session-handoff-v7.6.9.5.md`.

Also search `Docs/changelog.md` for the v7.6.7.0–v7.6.9.5 range and note every `Fixed #N`, `Closes #N`, `Related #N` reference.

### 3C — Build the Issues Resolved table

Produce a new **Issues Resolved** table. Include every issue that Phase V touched (FIXED_FULLY, FIXED_PARTIALLY, or SUPERSEDED per the sweep results). Column layout:

```
| Issue | Title | Status | Closed/Touched by PR | Classification | Notes |
```

- Sort by issue number ascending.
- For FIXED_PARTIALLY issues that remain open on GitHub: Status = `Open (partial)`.
- For issues closed on GitHub: Status = `Closed`.
- For FIXED_PARTIALLY: Notes = `Partial — full fix Phase 7 (v7.7.x)`.
- PR references must be in `#N` format (GitHub auto-links).

### 3D — Build the Deferred table

Produce a new **Deferred** table. Include every issue classified DEFERRED_INTENTIONAL, OUT_OF_SCOPE, or NOT_ADDRESSED. Column layout:

```
| Issue | Title | Classification | Target | Rationale |
```

### 3E — Fill in the Delivery Record tables

The existing delivery record rows have `#___` placeholders for most PRs and blank Status/Agent/Key Outcome fields. Fill in all blanks using the PR map from 3B and the audit files.

Known PR map:
- v7.6.7.0 → #176, v7.6.7.1 → #177, v7.6.7.2 → #178
- v7.6.8.0 → #180, v7.6.8.1 → #181, v7.6.8.2 → #182
- v7.6.9.0 → #183, v7.6.9.1 → #184, v7.6.9.2 → #191, v7.6.9.3 → #192
- v7.6.9.4 → #193 (verify), v7.6.9.5 → #195 (verify)

All merged PRs → Status = `Complete`.

### 3F — Write the updated phaseV-results.md

Rewrite `prompts/handoff/phaseV/phaseV-results.md` in place. Rules:
- Set `_Last updated:` to `2026-04-22`.
- Replace the Delivery Record tables with filled-in versions (3E).
- Replace the **Issues Resolved** section with the rebuilt table from 3C.
- Replace the **Deferred** section with the rebuilt table from 3D.
- Do NOT modify: Test Results, Device Test Results, Context for Phase 7, New Critical Rules/Lessons sections.

---

## Output

A single PR against `main` containing:
1. `prompts/handoff/phaseV/phaseV-issue-sweep-results.md` — updated with action completion status and comment URLs.
2. `prompts/handoff/phaseV/phaseV-results.md` — delivery record filled in, issue tables rebuilt.

PR title: `docs: Phase V post-sweep actions and phaseV-results cleanup`

PR body must list:
- Which labels/milestones were created
- Which comments were posted (issue number + comment URL)
- Summary of changes to phaseV-results.md

---

## Quality checks before opening the PR

- [ ] All 6 issues have labels applied — verify with `gh issue view <N> --json labels`
- [ ] All 6 issues have milestones set — verify with `gh issue view <N> --json milestone`
- [ ] All 6 issues have a comment posted — verify with `gh issue view <N> --comments`
- [ ] No comment text is paraphrased — must match sweep results doc verbatim
- [ ] phaseV-results.md has no `#___` placeholders remaining in the delivery record
- [ ] All issue links in phaseV-results.md use `#N` format
- [ ] `_Last updated:` date is `2026-04-22`
- [ ] No sections accidentally deleted from phaseV-results.md

---

_End of Phase V post-sweep actions prompt._