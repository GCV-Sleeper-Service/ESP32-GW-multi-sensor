# Development Process Guide — ESP32-GW Multi-Sensor Gateway

_Version 1.0 — 2026-05-06 (Phase VY)_
_This document governs how development is executed on this project._

---

## 1. Process Overview

Development follows a phased sprint model where each phase is a self-contained scope of work (feature, refactor, or stabilization) broken into numbered steps. Each step produces a PR that is reviewed, tested, and merged before the next step begins (with parallelism exceptions noted below).

The process has five layers, each with its own document ecosystem:

| Layer | Purpose | Key Documents |
|---|---|---|
| **Planning** | Phase scoping, architecture decisions | Phase implementation plans, architecture docs, `CURRENT-STATE.md` |
| **Prompt Production** | Agent prompts, review checklists, handoffs | Agent prompts, two-step Claude prompts, session handoffs |
| **Execution** | Code implementation by AI agents | PR commits, agent session output |
| **Review** | Multi-reviewer quality assurance | Inline reviews, external reviews, consolidated audits |
| **Closure** | Phase assessment, lessons, KPIs | Phase results, closure analysis, writing guide updates |

---

## 2. Step Execution Workflow

### 2.1 Pre-Step Checklist

Before starting any step:

1. Read `CURRENT-STATE.md` — confirm you're working from accurate state
2. Pull latest main: `git fetch origin main && git checkout main && git pull`
3. Check "Unimplemented Recommendations" — any items that should be this step's Step 0?
4. Verify the agent prompt's file paths and checkpoints against current code:
   - `grep -n 'function_name' firmware/core/target-file.h`
   - Don't trust line numbers from the prompt — they decay with every merge

### 2.2 Agent Execution

The operator gives the agent two things:

**A) Setup instructions:**
```
1) Sync latest main and branch:
   git -C /root/config/ESP32-GW-multi-sensor fetch origin main
   git -C /root/config/ESP32-GW-multi-sensor checkout -b <feature-branch> origin/main
2) Create empty bootstrap commit, push branch, open DRAFT PR to main
3) Post PR URL immediately
4) Read required files in order, run pre-implementation gates, start edits
5) Commit only to that branch, never to main
6) When done: gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor
7) Update PR description (use PR176-178 as reference)
```

**B) The agent prompt** — copy the agent section from the Claude two-step prompt.

### 2.3 Device Testing (When Applicable)

For steps modifying firmware behavior, the agent (or operator) runs:

```bash
# Satellite C3
bash scripts/provision.sh satellite
esphome clean   firmware/esp32-c3-multi-sensor.yaml
esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome upload  firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189
esphome clean   firmware/esp32-c3-multi-sensor.yaml

# Smoke test (wait 30s after upload)
curl -s http://192.168.120.189/api/status | python3 -m json.tool
curl -s -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full | python3 -m json.tool
```

**Rules:**
- Never use `esphome run` (hangs on log output) — always `upload`
- Wrap upload in `timeout 300` for safety
- Clean before AND after compile to prevent stale artifacts
- Post curl output as PR comment

### 2.4 Review Pipeline

Five reviews in this order:

| # | Reviewer | Platform | Type |
|---|---|---|---|
| 1 | Copilot | GitHub inline | Inline code review |
| 2 | Codex | GitHub inline | Inline code review |
| 3 | Gemini | GitHub inline | Inline code review |
| 4 | GPT/ChatGPT | Web portal (external) | Comprehensive PR analysis |
| 5 | Codex (external) | Web portal | Comprehensive PR analysis |

After inline reviews complete, agent addresses findings:
```
Please analyze the code reviews and comments for the PR. Assess if they are warranted,
if yes, implement necessary fixes. Post a comment summarizing your assessment.
```

External reviewers get a structured prompt (see prompt templates) that asks them to classify findings by severity and check acceptance criteria.

Perplexity runs the structured three-turn review protocol as the final quality gate when MCP cooperates. When MCP fails, operator downloads the review output manually.

### 2.5 Step Deliverables (in-PR, before merge)

The PR is the single source of truth for a step. A step is not "done" until the PR contains all of its deliverables. Post-merge work is limited to mechanical bookkeeping that depends on the merge commit SHA.

**In-PR mandatory deliverables (merge gate):**

Before a PR may be marked "Ready to merge," the branch MUST contain:

1. **Code changes** — the actual implementation, with all checkpoints satisfied (or a checkpoint-failure comment posted and accepted by the operator).
2. **`CURRENT-STATE.md` update** — bump "Last verified" date, append to "What Just Shipped," update "What's Next," add/remove "Open Issues" and "Unimplemented Recommendations."
3. **Changelog entry** — `Docs/changelog.md` entry under the new version.
4. **Consolidated audit file** — for non-trivial steps. Includes all review findings with severity, agent autonomous decisions, and prompt quality score.
5. **Next-step session handoff updates** — if the next step's prompts need changes based on what this step discovered, edit them in this PR.
6. **Recommendation routing** — if this step produced new recommendations, each one is recorded in CURRENT-STATE.md "Unimplemented Recommendations" OR opened as a GitHub Issue. No third option.

**Post-merge bookkeeping only:**

- Tag the release if this step is a version increment
- Close resolved GitHub Issues (linked via "Fixes #N")
- Move milestone progress bar (automatic if PRs are linked)

If you find yourself opening "documentation update" PRs the day after a merge, that is the drift this rule prevents.

---

## 3. Prompt Production

### 3.1 Prompt Bundle Structure

Each step requires three prompts:

1. **Agent prompt** (`prompts/phaseN/vX.Y.Z.W-agent-prompt-gpt-codex.md`) — Detailed implementation instructions with checkpoints, scope boundaries, and acceptance criteria. Follows the 10-section structure from the writing guide.

2. **Two-step Claude prompt** (`prompts/phaseN/vX.Y.Z.W-claude-two-step.md`) — Contains the agent section (for copy-paste to the agent) plus the reviewer checklist (for the structured review).

3. **Session handoff** (`prompts/handoff/phaseN/session-handoff-vX.Y.Z.W.md`) — What this step does, risk level, deliverables, and whether next step prompts need updating.

### 3.2 Checkpoint Authoring Rules

Checkpoints prevent agent drift. Rules for writing them:

- **Use queries, not assertions:** `grep -c 'authFetch' dashboard/core/history.js` is stable. "Line 47 should contain authFetch" breaks after every merge.
- **Use function/identifier anchors:** "Find the loop in `handle_aggregator_gateways_` that iterates `satellite_caches[]`" is stable. "Line ~1431" is not.
- **Stop-don't-fix semantics:** "If this check fails, STOP and post actual vs expected values as a PR comment. Do NOT modify code to pass the checkpoint."
- **Verify current state before applying:** If a checkpoint says "file X should contain Y," the agent must `grep` first, not assume.

**When a checkpoint fails, the agent posts this exact comment:**

```
⛔ CHECKPOINT FAILED — <checkpoint name>
Expected: <expected value or condition>
Actual:   <command output>
Command:  <verbatim command>
Action:   STOPPING. NO code changes made. Awaiting operator decision.
```

Agents that "explain away" a checkpoint failure instead of posting this template are exhibiting the plausible-narrative trap. The comment forces structured reporting.

### 3.3 Scope Guards

Every agent prompt includes explicit scope boundaries:

```
## §3 — Scope Boundary
Files you MAY modify: [exact list]
Files you MUST NOT modify: [exact list]
You MUST NOT: [list of forbidden actions]
```

This prevents agent sprawl — the pattern where agents "helpfully" fix things outside the step's scope, breaking other steps' assumptions.

---

## 4. Planning Sessions

### 4.1 Assumption Audit Gate

Before producing any phase plan or prompt set, run the assumption audit (documented in `prompts/handoff/methodology-audit-findings-for-planning.md`). Key questions:

- What are we assuming is true that we haven't verified since the last phase?
- What did the last postmortem recommend that hasn't been implemented?
- What is the simplest thing that could go wrong, and have we checked for it?
- What happens to this feature after 3 weeks of continuous operation?

### 4.2 Phase Sizing

Target metrics per phase:

| Metric | Target | Red Flag |
|---|---|---|
| Steps per phase | 6-8 | >12 means scope is too large |
| Fix cycles per step | 0 (low risk), ≤1 (medium), ≤2 (high) | >3 means prompt quality issue |
| Wall-clock per step | ≤2 hours | >4 hours consistently means process bottleneck |
| Steps per day (good day) | 3-4 | <2 means review orchestration overhead |

### 4.3 Phase Closure

Every phase ends with:

1. Issue sweep — check all open issues, classify as resolved/deferred/new
2. Closure analysis — plan vs delivery comparison, review findings summary
3. Phase results — deliverables list, device test baselines, new critical rules
4. Writing guide update — new gap categories and checkpoint learnings
5. `CURRENT-STATE.md` update — reflect new baseline
6. Recommendation tracking — every recommendation becomes an issue or CURRENT-STATE entry

---

## 5. Knowledge Architecture

### 5.1 Document Layers

| Layer | Documents | Token Budget | Who Reads |
|---|---|---|---|
| 1 — Current State | `CURRENT-STATE.md` | ~2K | Every session |
| 2 — Decision Index | `Docs/decisions/decision-log.md` | ~3K | Planning sessions |
| 3 — Methodology | `Docs/writing-guide/` | ~15K | Prompt production only |
| 4 — Phase Context | Agent prompt + handoff + critical rules subset | ~10-20K | Execution sessions |
| 5 — Historical | Lessons, postmortems, gap catalog, old phase results | ~100K+ | Investigation only |

**Rule:** Each session type has a reading budget. Don't load Layer 5 into an execution session. Don't skip Layer 1 in any session.

### 5.2 Recommendation Tracking

Every postmortem, phase closure, or session that produces a recommendation must route it to one of two destinations:

- **GitHub Issue** — for implementation-ready items with clear scope
- **`CURRENT-STATE.md` "Unimplemented Recommendations"** — for items needing further analysis

There is no third option. Recommendations archived without tracking are recommendations forgotten (proven by BUG-075-076 → BUG-083 gap).

---

## 6. Quality Measurement

### 6.1 KPIs

Track per phase:

1. **Steps-per-feature ratio** — total steps / features delivered. Target: ≤8 for a feature phase.
2. **Fix cycles per step** — times a PR needed additional commits after review. Track average.
3. **Wall-clock hours per step** — from agent start to PR merge. Track average.
4. **Checkpoint save count** — checkpoints that caught errors before they became PR findings. Higher = prompt had bugs the checkpoints caught.
5. **Preventable review findings** — review findings that the prompt should have prevented. Higher = prompt gaps.

### 6.2 Prompt Quality Score

For each consolidated audit, record:

```
Prompt Quality Score:
- Fix cycles: N
- Checkpoint saves: N  
- Preventable review findings: N
- Agent autonomous decisions: N (classify: helpful / harmful / neutral)
```

---

## 7. CI and Automation

### 7.1 CI Path Filtering

The CI workflow (`.github/workflows/ci.yml`) only runs on changes to code, config, scripts, and build files. Documentation-only PRs, prompts, images, and tags do not trigger CI.

Manual trigger via `workflow_dispatch` is always available.

### 7.2 Agent Instructions Files

- `.github/copilot-instructions.md` — top 10 review rules, consumed by Copilot inline review (4,000 char limit)
- `.github/instructions/*.instructions.md` — path-specific rules for firmware, dashboard, and Playwright files
- `AGENTS.md` — comprehensive agent instructions, consumed by multiple AI agents (Copilot, Claude, Gemini)

### 7.3 Verifying Agents Follow Rules

To confirm agents are consuming the instruction files:

1. **Copilot inline review:** On the next PR, check if review comments reference project-specific rules (deferred task pattern, generated file warnings). If Copilot flags a generated file edit or mentions `authFetch()`, the instructions are working.
2. **Agent execution in VSC:** Ask the agent "What files should you never edit directly?" It should list the generated artifacts.
3. **CI path filtering:** Submit a docs-only PR. If CI doesn't trigger, path filtering is working.
4. **Path-specific instructions:** Submit a PR touching `firmware/core/`. If Copilot mentions assembly script or deferred task pattern, the firmware-specific instructions are being consumed.

If any of these checks fail, verify the instruction files are committed, correctly named, and in the right locations.

---

_This document is updated at every phase closure to reflect process improvements._
