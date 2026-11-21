# Development Process Guide — ESP32-GW Multi-Sensor Gateway

_Version 1.0 — 2026-05-06 (Phase VY)_
_This document governs how development is executed on this project._
_Method of record: [HowTo-LLM-Assisted-Workflow-v2](https://github.com/GCV-Sleeper-Service/HowTo-LLM-Assisted-Workflow-v2) at tag `v2.3.1` (commit `450c446`) (PLAN-017). The HowTo governs the method; this guide governs project bindings (commands, paths, boards, reviewers, risk-tier assignments). On a question of method the HowTo wins; on a project fact this guide and `CURRENT-STATE.md` win. Coding agents do not read the HowTo: anything binding on them is in their prompt or `AGENTS.md`._

---

## Table of Contents

- [1. Process Overview](#1-process-overview)
- [2. Step Execution Workflow](#2-step-execution-workflow)
  - [2.1 Pre-Step Checklist](#21-pre-step-checklist)
  - [2.2 Agent Execution](#22-agent-execution)
  - [2.3 Device Testing (When Applicable)](#23-device-testing-when-applicable)
  - [2.4 Review Pipeline](#24-review-pipeline)
  - [2.5 Step Deliverables — **(CRITICAL — merge gate)**](#25-step-deliverables-in-pr-before-merge)
- [3. Prompt Production](#3-prompt-production)
  - [3.1 Prompt Bundle Structure](#31-prompt-bundle-structure)
  - [3.2 Checkpoint Authoring Rules](#32-checkpoint-authoring-rules)
  - [3.3 Scope Guards](#33-scope-guards)
- [4. Planning Sessions](#4-planning-sessions)
  - [4.1 Assumption Audit Gate](#41-assumption-audit-gate)
  - [4.2 Phase Sizing](#42-phase-sizing)
  - [4.3 Phase Closure](#43-phase-closure)
- [5. Knowledge Architecture](#5-knowledge-architecture)
- [6. Quality Measurement](#6-quality-measurement)
- [7. CI and Automation](#7-ci-and-automation)

---

## 1. Process Overview

> **Doctrinal precedence.** Where this document and `Docs/writing-guide/methodology.md` conflict, **this document governs**. Methodology describes prompt anatomy; this document describes execution authority and merge gates.

Development follows a phased sprint model where each phase is a self-contained scope of work (feature, refactor, or stabilization) broken into numbered steps. Each step produces a PR that is reviewed, tested, and merged before the next step begins (with parallelism exceptions noted below).

The process has five layers, each with its own document ecosystem:

| Layer | Purpose | Key Documents |
|---|---|---|
| **Planning** | Phase scoping, architecture decisions | Phase implementation plans, architecture docs, `CURRENT-STATE.md` |
| **Prompt Production** | Agent prompts, review checklists, handoffs | `prompts/producer-contract.md`; agent prompts with their check files, review files, session handoffs |
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

5. After a pause of more than two weeks, run the restart checklist first (HowTo v2 `templates/restart-checklist.md`): environment, repository, documents, last conversation, then one documentation-only housekeeping PR. Re-validate every unapplied fix against the current tree before applying it; code and script fixes go in their own PR with the normal reviews.
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and for a HIGH step compiles any embedded code on a scratch branch. Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.

### 2.2 Agent Execution

The operator gives the agent two things:

**A) Setup instructions:**
```
1) Confirm the checkout has no unrelated work (`git -C /root/config/ESP32-GW-multi-sensor status --short` prints nothing), then sync latest main and branch; stop on any failure:
   git -C /root/config/ESP32-GW-multi-sensor fetch origin main
   git -C /root/config/ESP32-GW-multi-sensor checkout -b <feature-branch> origin/main
2) Create empty bootstrap commit, push branch, open DRAFT PR to main
3) Post PR URL immediately
4) Read required files in order, run pre-implementation gates, start edits
5) Commit only to that branch, never to main
6) When done: gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor
7) Update PR description (use PR176-178 as reference)
8) Apply every edit with your file-edit tool; never with a script that parses the prompt
9) If one of your own commands fails, repair it and repeat the step; run no checkpoint while an edit before it is missing
10) Run one test command at a time: no second preflight, Playwright run or mock server while one is running
11) After `gh pr ready`: post the comment `/gemini review` on the PR; wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini; then assess each finding, fix what is warranted, and post one comment with your assessment that names any reviewer that did not post. Never merge, approve or start an external review
12) Stops: a known tooling defect with a recovery written in the prompt gets that recovery once, with the result posted, and a second failure stops; a value you would have to ask for is in the prompt; a real mismatch (a missing anchor, a different value, a path out of scope, a test failing twice) always stops with the checkpoint-failure comment of §3.2
13) Run every gate and checkpoint from the check file that the prompt names, exactly as the prompt says; never type a check by hand
```

Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance. Item 13 holds from R5 on (PLAN-031): the planning session hands over every check in one check file with its SHA-256.

**B) The agent prompt** — word for word, from the step's bundle (`prompts/producer-contract.md` §6).

### 2.3 Device Testing (When Applicable)

For steps modifying firmware behavior, the agent (or operator) runs:

```bash
# Satellite C3
bash scripts/provision.sh satellite
esphome clean   firmware/esp32-c3-multi-sensor.yaml
esphome compile firmware/esp32-c3-multi-sensor.yaml
timeout 300 esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189
esphome clean   firmware/esp32-c3-multi-sensor.yaml

# Smoke test (wait 30s after upload)
curl -s http://192.168.120.189/api/status | python3 -m json.tool
curl -s -u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full | python3 -m json.tool
```

**Rules:**
- Never use `esphome run` (hangs on log output) — always `upload`
- Wrap upload in `timeout 300` for safety
- Clean before AND after compile to prevent stale artifacts
- Post curl output as PR comment

### 2.4 Review Pipeline

Three inline reviews, then the external reviews: reviews A and C side by side, then review B by the review runner, always last (PLAN-022, PLAN-023). Review C is required on MEDIUM and HIGH firmware steps. It is optional on every other step: a MEDIUM or HIGH step that changes no firmware, a LOW step, a documentation PR (PLAN-036). The round summary says which reviews ran.

| # | Reviewer | Where | Type |
|---|---|---|---|
| 1 | Copilot | GitHub inline | Inline code review |
| 2 | Codex | GitHub inline | Inline code review |
| 3 | Gemini | GitHub inline | Inline code review |
| 4 | Claude (external review A); a GPT model when Claude Code coded the step (PLAN-026) | Its own session, apart from planning and from the coding agent | Whole-PR review: findings by severity, each acceptance criterion checked |
| 5 | Meta Muse, Spark or Wonder (external review C) | Its own session | Whole-PR review by a fourth model family |
| 6 | The review runner (external review B): Gemini on Agent Platform, through `.github/workflows/external-review.yml` | GitHub Actions; the operator starts it from the Actions tab on `main` | The three turns of `Docs/templates/external-review-template.md`; one comment by `github-actions[bot]` |

After the inline reviews the agent addresses the findings by itself (§2.2 item 11, PLAN-027). After each external round the operator pastes the same line to the agent:
```
Please analyze the code reviews and comments for the PR. Assess if they are warranted,
if yes, implement necessary fixes. Post a comment summarizing your assessment.
```

Reviews A and C get the common part and their own part of the step's review file. Review B gets the step's agent prompt and review file as inputs of the runner; its comment prints their SHA-256, which the operator compares with the gate record. `Docs/operator/R5r-review-runner.md` says how to start it. No external reviewer comes from the coding agent's vendor. Each external reviewer posts one PR comment, or the operator pastes its output into the PR. A reviewer never pushes, merges or approves.

If the runner cannot run, the step waits for it; the operator may instead run review B as a Muse session in three turns, and the consolidated audit names the change (PLAN-023). Gemini on the web is no fallback, because it cannot post the comment. The runner cannot review the pull request that installs it. A pull request that changes the runner is reviewed by the runner on `main`, which reads the change as data.

Claude Code is the fallback coding agent (PLAN-026). The agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout.

When Copilot posts no complete review, the agent's assessment says so, and the step goes on with the other inline reviews and the external reviews; the operator decides at the merge (PLAN-032).

### 2.5 Step Deliverables (in-PR, before merge)

> ⚠️ **MERGE GATE** — This section defines the in-PR deliverables required before any PR may be marked "Ready for Review". A PR that ships without these has merged a defect by definition. Reviewers MUST verify each item explicitly.

The PR is the single source of truth for a step. A step is not "done" until the PR contains all of its deliverables. Post-merge work is limited to mechanical bookkeeping that depends on the merge commit SHA.

**In-PR mandatory deliverables (merge gate):**

Before a PR may be marked "Ready to merge," the branch MUST contain:

1. **Code changes** — the actual implementation, with all checkpoints satisfied (or a checkpoint-failure comment posted and accepted by the operator).
2. **`CURRENT-STATE.md` update** — bump "Last verified" date, append to "What Just Shipped," update "What's Next," add/remove "Open Issues" and "Unimplemented Recommendations." Mark the step's row in the ladder of `Docs/plan-of-record.md` and move its "You are here" line (PLAN-024).
3. **Changelog entry** — `Docs/changelog.md` entry under the new version.
4. **Consolidated audit file** — required for any **non-trivial** step. A step is non-trivial if any of the following is true:
   - It introduces a new firmware feature
   - It modifies a runtime data path
   - It modifies the dashboard
   - It modifies a build script
   - It aggregates ≥3 sub-fixes

   The minimum consolidated audit must contain:
   - **(a)** Review findings grouped by severity
   - **(b)** Agent autonomous decisions taken without human input
   - **(c)** Prompt quality metrics per §6.2 — fix cycles, checkpoint saves, preventable review findings, and agent autonomous decisions (each classified as helpful / harmful / neutral). Include a one-line summary judgment.
   - **(d)** A list of unimplemented recommendations and where each was routed (issue # / `CURRENT-STATE.md` entry / explicitly closed-as-wontfix with reason)
5. **Next-step session handoff updates** — if the next step's prompts need changes based on what this step discovered, edit them in this PR.
6. **Recommendation routing** — if this step produced new recommendations, each one is recorded in CURRENT-STATE.md "Unimplemented Recommendations" OR opened as a GitHub Issue. No third option.

**Post-merge bookkeeping only:**

- Tag the release if this step is a version increment
- Close resolved GitHub Issues (linked via "Fixes #N")
- Move milestone progress bar (automatic if PRs are linked)

If you find yourself opening "documentation update" PRs the day after a merge, that is the drift this rule prevents.

**Prompt lint enforcement:**
Every PR that touches `prompts/**` is automatically checked by `.github/workflows/prompt-lint.yml`,
which invokes `scripts/lint-prompts.sh --baseline` against the PR's changed files. ERROR-level violations
(L1–L5, L7: stale IPs, wrong filenames, forbidden section titles, cross-prompt references; L8: a Rule 61
delay that differs from the live value in `maybe_yield_nvs_scan_()`; L9: a step agent prompt without a
closing line `Fixes #N`; L10: an agent prompt that runs `git checkout main` or `git switch main` in a code
block; L11: a login literal after `-u`, `--user` or `Authorization: Basic`) fail the PR. A violation that
the base of the PR already has is reported as EXISTING and does not block. WARN-level findings (L6:
pipeline-ordering advisory) are reported without blocking. The same workflow runs the passing and the
failing fixture of each rule from L8 on (`tests/lint-prompts/run-fixtures.sh`) and the two scope-gate
cases (`tests/scope-gate/run-tests.sh`). The workflow `pr-body-check.yml` fails a PR that touches
`prompts/**` and has no "Pre-Implementation Verification" heading in its body.
Run `bash scripts/lint-prompts.sh` locally before pushing to catch violations before CI does.

---

## 3. Prompt Production

### 3.1 Prompt Bundle Structure

The files of a step's bundle, their names and the rules that each must meet are in `prompts/producer-contract.md` (PLAN-038): the agent prompt and its check file, the review file, the operator page, the setup block of §2.2 and the supplied files; for a MEDIUM or HIGH step the audit file; for a firmware step the session handoff. The agent prompt follows the skeleton of the HowTo agent-prompt template: a header and preamble, the lessons of the step, and §1 to §9. A firmware step has no two-step prompt: its review file takes that place (PLAN-023). The coding agent writes the record of the step in the PR (§2.5 item 4). A batch of Phase 7 steps is produced with `prompts/handoff/phase7-batch-production-prompt-v3.md`.

**Risk tiers (PLAN-017).** Set per step at planning time and written in the prompt header. The tier sets the producer-side audit and the prompt style. It does not change the review pipeline of §2.4, except that review C is required on MEDIUM and HIGH firmware steps (PLAN-023) and optional on every other step (PLAN-036). Documentation-only PRs run the three inline reviewers; external reviewers are optional, and the round summary says which ran.

| Tier | Phase 7 steps | Producer audit before dispatch | Prompt style |
|---|---|---|---|
| LOW | v7.7.1.2 | Lint | Intent and acceptance criteria |
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037) | Intent and acceptance criteria; prescribe only interface contracts |
| HIGH | v7.7.1.4, v7.7.2.2, v7.7.3.3 | Lint + an internal audit (PLAN-040), then two auditors from different model families (PLAN-037, PLAN-041), reconciled in one file; embedded code compiled on a scratch branch before dispatch | Prescriptive allowed |

Transition (PLAN-017): the Batch 2 prompts of May 2026 (v7.7.1.2-v7.7.1.4) are not dispatched. They are re-produced under the method of record and audited at their tier before dispatch; the compile of v7.7.1.4's embedded code runs once v7.7.1.3 is on `main`.

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
Action:   STOPPING. No further edits or commits.
Changes already made: <none, or the files and task groups completed before this checkpoint>
Working tree: <verbatim output of git status --short>
Last completed checkpoint: <name, or none>
Awaiting operator decision.
```

Agents that "explain away" a checkpoint failure instead of posting this template are exhibiting the plausible-narrative trap. The comment forces structured reporting.

A checkpoint tests whether the repository matches what the prompt assumed, and the agent never fixes a failing checkpoint. A failing test inside a task group is ordinary work: fix it within the §3 scope and record the fix in the session log (HowTo v2 §4.3).

### 3.3 Scope Guards

Every agent prompt includes explicit scope boundaries:

```
## §3 — Scope Boundary
Files you MAY modify: [exact list]
Files you MUST NOT modify: [exact list]
You MUST NOT: [list of forbidden actions]
```

This prevents agent sprawl — the pattern where agents "helpfully" fix things outside the step's scope, breaking other steps' assumptions.

> **Self-containedness rule.** Every agent prompt must be independently executable. If a prompt's §3 (Scope) references another prompt for scope or constraint information, that is a blocking defect. Inline the full list. The CI prompt-lint rule **L3** detects this class of cross-prompt reference automatically.

---

## 4. Planning Sessions

### 4.1 Assumption Audit Gate

Before producing any phase plan or prompt set, run the assumption audit (documented in `prompts/handoff/methodology-audit-findings-for-planning.md`). Key questions:

- What are we assuming is true that we haven't verified since the last phase?
- What did the last postmortem recommend that hasn't been implemented?
- What is the simplest thing that could go wrong, and have we checked for it?
- What happens to this feature after 3 weeks of continuous operation?

> **Required output — Pre-Batch Assumption Audit.** Before producing prompts, the prompt producer MUST commit a file `prompts/handoff/<phase>/<phase>-batch<N>-assumption-audit.md` containing answers to:
>
> 1. **Unverified assumptions** — list each assumption (board IPs, file paths, function signatures, partition layouts) made while drafting the prompts, with the source-of-truth file each was checked against.
> 2. **Unimplemented postmortem items** — list every recommendation from the previous batch's consolidated audit, and for each: implemented / deferred-to-issue-#N / explicitly-rejected (with reason).
> 3. **Simplest thing that could go wrong** — name the single failure mode most likely to surface during execution and how the prompt's checkpoints would catch it.
> 4. **3-week continuous-operation impact** — if this batch's changes ran for 3 weeks unattended on the fleet, what would degrade (memory, NVS wear, partition fill, log volume)?
> 5. **Platform capabilities** — every hardware, framework or library capability the batch relies on, with its exact version, the documentation URL and the date checked (HowTo v2 `templates/planning-assumption-audit.md` §7). A step that rests on an unsupported or unverified capability is a research step with a decision gate, not an implementation step.
> 6. **Decision changes** — a plan or calendar that changes a logged decision writes the superseding row in `Docs/decisions/decision-log.md` before anything else.

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
7. Early-warning numbers — verification:production session ratio (red flag above 2:1), fix cycles per step trend, days since `Last verified` in `CURRENT-STATE.md`
8. Method check — compare this phase's batch process metrics with the previous phase and record keep or adjust as a decision-log row

---

## 5. Knowledge Architecture

### 5.1 Document Layers

| Layer | Documents | Token Budget | Who Reads |
|---|---|---|---|
| 1 — Current State | `CURRENT-STATE.md` | ~2K | Every session |
| 2 — Decision Index | `Docs/decisions/decision-log.md` | ~3K | Planning sessions |
| 2 — Plan of Record | `Docs/plan-of-record.md`; planners enter at `Docs/planner-start-here.md` | ~8K | Planning sessions |
| 3 — Methodology | `prompts/producer-contract.md` (binding); `Docs/writing-guide/` (reference) | ~15K | Prompt production only |
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

> _The audit deliverable in §2.5 item 4(c) feeds these KPIs. Every consolidated audit must record all four metrics below._

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

The CI workflow (`.github/workflows/ci.yml`) runs its `preflight-and-compile` job on every pull request to `main`, documentation-only ones too: branch protection requires that check, and a required check that a path filter skips blocks the merge (PLAN-020). On a push to `main` the workflow still runs only for changes to code, config, scripts and build files.

The job takes a fast path for documentation (PLAN-028). Its step "List changed paths" reads the paths that the pull request changes. When every path is under `Docs/` or `prompts/`, or is `README.md`, `CURRENT-STATE.md`, `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` or a file `.github/instructions/*.instructions.md`, the job runs preflight only: it skips the ESPHome install, the dashboard minify, the header and the compile. Any other path, an empty diff, a push to `main` and a manual run take the full job.

Every workflow runs on `ubuntu-24.04`, not `ubuntu-latest`, so the operating system of a job changes only through a pull request (PLAN-034). `ci.yml`, `browser-tests.yml` and `prompt-lint.yml` can also be started by hand from the Actions tab (`workflow_dispatch`); `pr-body-check.yml` cannot, because it checks a pull request. A manual run of `prompt-lint.yml` lints every prompt without a baseline, so it fails while old prompts hold violations.

### 7.2 Agent Instructions Files

`AGENTS.md` is the one source of rules for coding agents and reviewers. The other files point to it and repeat a rule only where their reader needs it. Each file stays under 200 lines, and a PR that changes a rule changes every file that states it (PLAN-029).

| File | Who loads it by itself (vendors' documentation, checked 2026-11-16) |
|---|---|
| `AGENTS.md` | Codex; GitHub Copilot (code review and cloud agent on GitHub, VS Code chat, CLI); Claude Code through the import line in `CLAUDE.md` |
| `CLAUDE.md` | Claude Code; GitHub Copilot (code review and cloud agent on GitHub, CLI). Not Codex |
| `.github/copilot-instructions.md` | GitHub Copilot only, in every Copilot feature |
| `.github/instructions/*.instructions.md` | GitHub Copilot only (code review and cloud agent on GitHub, VS Code chat, CLI); `applyTo` names the paths |
| `.gemini/styleguide.md` | The Gemini inline reviewer on GitHub (Google's documentation, checked 2026-11-21) |

The Gemini inline reviewer loads none of the other four files. Its file `.gemini/styleguide.md` copies the table of generated files, the section "Critical Rules", the review checklist and the severities of `AGENTS.md` word for word, so a PR that changes one of these parts of `AGENTS.md` changes that file too (PLAN-039). Copilot's code review reads the instruction files from the head branch of the PR, so a PR that edits one of them changes its own Copilot review: the review file of such a step tells reviewers A and B to read that diff by hand.

### 7.3 Verifying Agents Follow Rules

To confirm agents are consuming the instruction files:

1. **Copilot inline review:** On the next PR, check if review comments reference project-specific rules (deferred task pattern, generated file warnings). If Copilot flags a generated file edit or mentions `authFetch()`, the instructions are working.
2. **Agent execution in VSC:** Ask the agent "What files should you never edit directly?" It should list the generated artifacts.
3. **CI on pull requests:** Submit a docs-only PR. The `preflight-and-compile` check must start; if it does not, the merge stays blocked (PLAN-020).
4. **Path-specific instructions:** Submit a PR touching `firmware/core/`. If Copilot mentions assembly script or deferred task pattern, the firmware-specific instructions are being consumed.

If any of these checks fail, verify the instruction files are committed, correctly named, and in the right locations.

---

_This document is updated at every phase closure to reflect process improvements._
