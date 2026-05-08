# Phase 7 — GitHub Tracking & Documentation Supplement

_Amendments to Batch 1 prompts and standing instructions for Phase 7 issue/doc management._
_Date: 2026-05-07_

---

## 1. Pre-Phase 7 Setup (Operator — One Time)

Before executing the first Phase 7 step, run:

```bash
# Create Phase 7 milestone
gh milestone create "Phase 7 — Per-Device Persistence" \
  --description "Chunked streaming, health-check telemetry, per-device NVS, migration, export/import" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor

# Create Phase 7 label
gh label create "phase/7" --color "0052CC" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor 2>/dev/null

# Update existing issues with Phase 7 milestone
gh issue edit 139 --milestone "Phase 7 — Per-Device Persistence" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor

gh issue edit 137 --milestone "Phase 7 — Per-Device Persistence" \
  --add-label "phase/7" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor
```

### Critical Rules 65-67

The Phase 7 plan proposes three new Critical Rules. These should be committed to `prompts/prompt-index-and-workflow.md` as part of the **first implementation step** (v7.7.1.0). Add them to the agent prompt's scope:

| # | Rule | Source |
|---|------|--------|
| 65 | All new HTTP endpoints must include `authenticate_management_()` for write/management operations and `authFetch()` in dashboard fetch calls | Phase 7 planning review |
| 66 | After adding new HTTP handlers, run `scripts/stress-test-httpd-stack.sh` on at least one board per architecture. Minimum watermark ≥ 2,000 B. | Phase 7 planning review |
| 67 | Binary sensor metrics use `EventLog` (state-change-only deduplication), not `HistoryBuffer` (periodic readings) | PLAN-002 |

---

## 2. Amendments to Batch 1 Prompts

**All amendments listed in this section have been applied directly to the source prompt files.** This section is retained for traceability only — the prompts themselves are the source of truth.

- v7.7.0.0: Session summary added to §1, issue tracking added to §4
- v7.7.1.0: Session summary added to §1, Critical Rules 65-67 in scope (§3) and implementation (Step 5.5b), issue tracking (Step 5.7), CURRENT-STATE.md marked MANDATORY (Step 5.6), acceptance criteria updated
- v7.7.1.1: Session summary added to §1, `Fixes #139` in implementation (Step 4.6b), CURRENT-STATE.md marked MANDATORY (Step 4.6), acceptance criteria updated
- Both two-step prompts: reviewer checklists updated with issue tracking items
- Both handoffs: pre-merge checklists updated with issue tracking items
- Consolidated audit template: GitHub issue tracking section added to §7
- Batch production prompt: codebase verification strengthened, future phase pattern added

---

## 3. Standing GitHub Tracking Rules for Phase 7

These apply to every step from v7.7.1.0 onward:

### Issue Resolution in PRs

When a step resolves a known GitHub issue:
- PR body includes `Fixes #NNN` (auto-closes on merge)
- CURRENT-STATE.md moves the issue from "Open Issues" to resolved
- Consolidated audit records the closure

### New Issue Creation

When a step discovers a new problem that is out of scope:
- Agent (or operator) creates a GitHub issue:
  ```bash
  gh issue create \
    --title "[BUG-NNN] Description" \
    --label "phase/7" \
    --milestone "Phase 7 — Per-Device Persistence" \
    --body "Discovered during v7.7.X.Y. Details: ..."
    --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor
  ```
- CURRENT-STATE.md adds the issue to "Open Issues"
- Issue number recorded in the consolidated audit §2

### Decision Log Updates

When a step makes a new architectural decision:
- Add entry to `Docs/decisions/decision-log.md`
- Reference the PR or session log as rationale source
- Format: `| YYYY-MM-DD | [ID] | [one-line decision] | [link] |`

### LESSON-OPS and BUG-NNN Entries

When a step reveals a new lesson or bug pattern:
- Add to `Docs/lessons/firmware.md` (firmware) or `Docs/lessons/dashboard.md` (dashboard)
- Number sequentially from the current highest
- Consolidated audit §7 lists candidates; operator assigns final numbers

### Phase 7 Issue Sweep (v7.7.3.3)

The closure step must include an issue sweep equivalent to Phase V's:
- List all open issues with `phase/7` label
- Classify each: RESOLVED / DEFERRED / NEW
- Update milestones for deferred issues
- Close resolved issues not auto-closed by PRs
- Produce `prompts/handoff/phase7/phase7-issue-sweep-results.md`

---

## 4. Documentation Lifecycle

| Document | When Updated | Who Updates |
|----------|-------------|-------------|
| `CURRENT-STATE.md` | Every step (mandatory post-merge) | Agent (in PR) |
| `Docs/changelog.md` | Every implementation step | Agent (in PR) |
| `Docs/decisions/decision-log.md` | When new arch decisions made | Agent or operator |
| `prompts/prompt-index-and-workflow.md` | When new Critical Rules added | Agent (in PR) |
| `Docs/lessons/firmware.md` | When new bugs/lessons documented | Agent (in PR) or operator |
| `Docs/board-measurement-log-v7.6.10.md` | After device testing reveals new baselines | Operator (post-merge) |
| `Docs/phase-7-review-and-rewrite.md` | Only if plan needs revision | Operator (planning session) |
| GitHub Issues / Milestone | Every step (as needed) | Agent (`Fixes #N`) or operator (`gh issue`) |

### When to Update `board-measurement-log`

The board measurement log should be updated (or a new version created) when:
- v7.7.1.0 health-check provides runtime baselines different from boot-time measurements
- v7.7.1.1 chunked streaming changes peak heap during history serve
- v7.7.1.4 partition table changes affect available NVS space
- v7.7.3.3 closure establishes the Phase 7 endpoint baselines

The operator creates `Docs/board-measurement-log-v7.7.md` during or after the first device test that shows significantly different values.

---

_End of GitHub tracking supplement._
