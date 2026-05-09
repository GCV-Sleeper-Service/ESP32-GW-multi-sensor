# Multi-LLM Prompt Strategy — Design Patterns, Distribution, and Pre-Mortem Analysis

_Date: 2026-04-09_
_Addendum to: `Docs/writing-guide/methodology.md`_
_Location: `prompts/handoff/phaseY/multi-llm-prompt-optimization-analysis-2026-04-09.md`_

---

## Purpose

This document establishes the multi-LLM distribution strategy for this project. It covers: how to design prompts that work across LLMs without quality loss, how to distribute work when capacity constraints force multi-LLM usage, where errors originate and how to prevent them, and a pre-mortem analysis of failure modes for common optimization shortcuts.

It also evaluates the Phase Y cross-LLM prompt analysis performed by GPT, Perplexity, Codex, and Copilot.

---

## Part 1 — The Operator's Constraints and Goals

**Capacity reality:** Claude (planning/prompt production) has per-conversation and weekly token limits. Copilot (agent execution) has similar periodic limits. When both are exhausted, GPT and Codex are fallback execution environments.

**Quality goal:** Reduce PR fix cycles from 2-6 per step to 0-2. Reduce per-step wall-clock time from several hours to under one hour. Maintain zero regressions on the 402-test Playwright suite and all preflight checks.

**Non-negotiable:** Execution correctness cannot be traded for token efficiency. The project's history (Phases 4–6, D, X) proves that incomplete context causes more damage than context overload. Every "read this file fully" instruction exists because an agent once failed by not reading it.

---

## Part 2 — Where Fix Cycles Come From (Root Cause Analysis)

Based on audit documents from Phases D and X, PR fix cycles break down into five categories:

### Category 1: Scope violations (30% of rework)
The agent edits files outside the allowed scope. Typical: modifying test files when the prompt says "do NOT modify tests," or touching `sensor_history_multi.h` when only fragments should be edited. Root cause: the agent reads the do-not list but loses it from active attention by the time it reaches the relevant implementation step.

**Prevention:** Inline verification gate after implementation steps. `git diff --name-only` compared against allowed-file list. If any unauthorized file appears, agent stops and reverts before continuing.

### Category 2: Missed validation steps (25% of rework)
The agent skips Playwright fixture sets, doesn't run preflight, or forgets the assembly identity check. Root cause: validation instructions appear at the end of a long prompt (§7/§8), far from the implementation steps (§5) where errors are introduced. By the time the agent reaches validation, its context window has accumulated enough that late instructions get lower attention.

**Prevention:** Mid-implementation checkpoints that run critical validations between task groups, not just at the end.

### Category 3: Project-specific anti-pattern violations (20% of rework)
Using `application/json` POST content type (corrupts httpd socket state), using the wrong board YAML (Critical Rule 36), forgetting to restore satellite mode before PR. Root cause: these constraints are project-specific and not obvious from the code. An agent pattern-matching from general knowledge will use JSON POST bodies because that's the standard practice elsewhere.

**Prevention:** Place the anti-pattern warning inline at the exact implementation step where the mistake would be made. Not in a preamble, not in a separate section — at the point of risk.

### Category 4: Pipeline ordering errors (15% of rework)
Running the regeneration pipeline in the wrong order, or skipping a step. Root cause: the pipeline is 8-9 steps and agents sometimes reorder them based on what seems logical.

**Prevention:** The pipeline is a copy-paste block, not a description. The agent runs it as-is, doesn't reconstruct it.

### Category 5: Documentation and deliverable omissions (10% of rework)
Missing changelog entry, no session log, no instruction compliance table, no post-merge audit. Root cause: these are the last items in the prompt and agents treat them as optional.

**Prevention:** Pre-PR self-review gate that checks for all required deliverables before the PR is created.

---

## Part 3 — The Inline Verification Gate Pattern

This is the single highest-impact innovation for reducing fix cycles.

### What it is

A checkpoint inserted between task groups within §5 (Implementation Instructions) that forces the agent to verify its work before continuing. Each checkpoint is:
- A concrete shell command with an expected result
- A clear STOP instruction if the check fails
- Placed at the natural boundary between task groups where errors compound

### Why it works

Without checkpoints, a scope violation at step 3 isn't discovered until step 12 (the final validation). By then, the agent has built 9 more steps on top of the broken foundation. Fixing step 3 often means redoing steps 4-12. With a checkpoint after step 3, the agent catches the error immediately and fixes only step 3.

The math: if the probability of an error at any step is p, and the cost of fixing it grows linearly with the number of subsequent steps, then a checkpoint after every N steps reduces expected rework cost by a factor of roughly N.

### How to place checkpoints

**Rule: One checkpoint per logical task group, never more than 4-5 implementation sub-steps apart.**

A "logical task group" is a set of related changes that together produce a verifiable state. For example:
- "Extract 8 fragments" is a task group → checkpoint: verify line count sum
- "Create assembly script" is a task group → checkpoint: `--check` passes
- "Update pipeline and preflight" is a task group → checkpoint: `preflight.sh` passes

**Rule: Every checkpoint must be a concrete command, not a subjective judgment.**

Good: `bash scripts/assemble-sensor-history.sh --check` — exits 0 or non-zero.
Bad: "Verify the assembly looks correct" — the agent will always say yes.

**Rule: The final checkpoint before PR creation is a scope-and-completeness gate.**

```
BEFORE creating PR:
- git diff --name-only — verify ONLY allowed files appear
- bash scripts/preflight.sh — all checks pass
- Playwright across all 4 fixture sets — all green
- Changelog entry present — grep v7.6.6.X Docs/changelog.md
- If this step requires satellite mode restoration — verify provision.sh satellite was run
```

### Checkpoint template

```
---
⛔ CHECKPOINT (after step group [N]): [description]
Run:
  [command 1] — expected: [result]
  [command 2] — expected: [result]
If ANY check fails: STOP. Fix the issue before continuing to the next step group.
Do NOT proceed with a failing checkpoint — errors compound.
---
```

---

## Part 4 — Multi-LLM Distribution Strategy

### Role assignment by LLM capability

| Role | Primary LLM | Fallback LLM | Why |
|---|---|---|---|
| Planning & prompt production | Claude (this chat) | — | Deep project memory, architectural context, prompt chain history |
| Agent execution (implementation) | Copilot | GPT / Codex | Native file system, shell access, iterative REPL |
| PR review | Copilot (deep-research) | Perplexity | Structured evidence collection, diff-first review |
| Post-merge audit synthesis | Claude (this chat) | — | Requires cross-phase knowledge, lesson/bug numbering continuity |

### How to run the original prompts on non-Claude agents

The original prompts are written in plain imperative English. There is nothing Claude-specific in the instructions. "Read this file, then do X, verify Y" works on any agent with file system access.

**Do NOT use the "optimized" prompt variants (GPT-Optimized, Codex-Optimized) for execution.** They strip safety constraints. Use the original prompts with a universal preamble instead.

### The Universal Multi-LLM Execution Preamble

Paste this at the top of any agent prompt when running on GPT, Codex, or any non-Claude agent:

```
═══════════════════════════════════════════════════════════════════
MULTI-LLM EXECUTION PREAMBLE
═══════════════════════════════════════════════════════════════════

You are executing an implementation prompt designed for a coding agent with
file system access and shell command execution. These prompts were authored by
Claude for this project's specific context. They apply identically to your
environment. Follow them literally.

CRITICAL RULES:
1. Do NOT compress, summarize, or skip any reading steps. The reading order
   exists because prior agents failed when they skipped files. Read every
   file listed in §1 COMPLETELY and IN ORDER before making any changes.

2. Do NOT reorganize the implementation steps. The order is deliberate.
   Steps build on each other and checkpoints between them verify intermediate
   state.

3. When you encounter a ⛔ CHECKPOINT block, STOP and run every command
   listed. If any check fails, fix the issue before continuing. Do NOT
   proceed past a failing checkpoint.

4. When you encounter a "Do NOT" instruction, treat it as absolute. These
   constraints come from real bugs that caused hardware damage, corrupted
   device state, or broke CI in prior phases. They are not suggestions.

5. All HTTP POST commands in this project MUST use:
     curl -d 'a=1' -X POST [url]
   NEVER use -H "Content-Type: application/json" — the ESPHome httpd
   stack does not support JSON POST bodies and will corrupt socket state.

6. All device testing on the S3 aggregator board MUST use the GENERATED
   YAML file (esp32-s3-devkitc1-n16r8-gw.yaml), NEVER the committed
   C3 template (esp32-c3-multi-sensor.yaml).

7. If the step involves aggregator testing, you MUST run
   `bash scripts/provision.sh satellite` before creating the PR to
   restore the repository to CI-safe state.

8. Produce ALL deliverables listed in §9 before closing the session.
   These are mandatory, not optional.

═══════════════════════════════════════════════════════════════════
```

This preamble costs ~350 tokens. It prevents the five most common cross-LLM failure modes without restructuring the prompt.

---

## Part 5 — Pre-Mortem: What Fails When You Cut Corners

### Scenario A: "Move safety constraints to a worker/sub-agent"

**What GPT and Codex proposed:** Delegate file reading to workers, have workers extract constraints, coordinator acts on summaries.

**What would fail:** The worker reads the handoff doc and extracts "must use `-d 'a=1'` for POST." But the worker's output is capped at 600 tokens and the constraint competes with 15 other extracted items for attention. The coordinator receives a compressed brief and the curl syntax rule gets summarized as "use correct POST format" — which the coordinator interprets as JSON POST because that's the universal standard. The S3 board's httpd socket state is corrupted, the agent can't diagnose it, and you lose 45 minutes reflashing.

**Probability of this failure:** High. It happened in Phase D (BUG-075) even WITH the constraint explicitly inline. Moving it to worker extraction adds another failure mode.

**Pre-mortem verdict:** Do not delegate safety constraints. Keep them inline at the point of risk.

### Scenario B: "Skip the full reading list — just read the files you'll edit"

**What Perplexity proposed:** Deferred targeted reads — only open files at the moment of editing.

**What would fail:** The agent skips reading `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` because it's not a file being edited. But that document contains the exact `run_full_pipeline()` contract, the fragment manifest with boundary line numbers, and the assembly script specification. Without reading it, the agent implements from the handoff summary which is a condensed version and may miss edge cases. The agent produces `run_full_pipeline()` with 7 steps instead of 8, or gets the assembly script `--check` behavior wrong.

**Probability:** Medium-high for implementation steps, low for validation-only steps.

**Pre-mortem verdict:** For implementation steps (v7.6.6.0, v7.6.6.1, v7.6.6.2, v7.6.6.8), the full reading list is non-negotiable. For validation-only steps (v7.6.6.3, v7.6.6.4, v7.6.6.5, v7.6.6.6, v7.6.6.7), targeted reads are acceptable because the agent isn't writing new code — it's running commands and capturing evidence.

### Scenario C: "Compress late-step prompts because they follow the same pattern"

**What Codex proposed:** Steps v7.6.6.4+ reduced to 2-3 lines of instruction.

**What would fail:** v7.6.6.6 is the aggregator device test. Codex's prompt says "implement required runtime path changes, gather required device-test evidence." An agent receiving this doesn't know: which board YAML to use, which endpoints to test, the curl syntax constraint, the satellite mode restoration requirement, or the config_generation increment check. It would use the wrong YAML, skip half the endpoints, use JSON POST, and forget to restore satellite mode. The PR would need 4-5 fix cycles minimum.

**Probability:** Near-certain for device test and closure steps.

**Pre-mortem verdict:** Never compress steps that involve hardware interaction or cross-file documentation updates. These are exactly the steps where project-specific knowledge matters most and where generic patterns produce the worst results.

### Scenario D: "Run validation only at the end, not mid-implementation"

**What the original prompts do (current state).**

**What fails today:** The agent completes all 13 implementation sub-steps, then runs Playwright and discovers a scope violation from step 3. It reverts step 3, but steps 4-13 were built on the broken assumption from step 3. Rework cascade. Two additional fix cycles.

**Pre-mortem verdict:** This is the gap that inline verification gates close. Adding 3-4 checkpoints per step costs ~200-300 tokens but prevents the cascade failure that causes most multi-cycle PRs.

### Scenario E: "Let each LLM rewrite prompts for its own architecture"

**What we tested in this analysis.**

**What fails:** Each LLM optimizes for its own execution model and inadvertently strips constraints that are critical for this project but don't look important from a general prompt-engineering perspective. GPT strips inline anti-patterns to reduce coordinator context. Codex strips entire task specifications to reduce prompt body size. Perplexity strips shell commands because it can't execute them.

**Pre-mortem verdict:** LLM self-optimization is useful for REVIEW prompts (where the output is analysis, not code) but dangerous for AGENT prompts (where the output is implementation). For agent prompts: use the original with the universal preamble. For review prompts: LLM-specific variants are acceptable because the worst case is a less thorough review, not a broken implementation.

---

## Part 6 — Making It Repeatable

### The workflow for each Phase Y step

1. **Claude (this chat):** Produce implementation instructions and two-session prompts with inline checkpoints. Produce handoff documents. This is the planning/prompt-production session.

2. **Copilot (primary agent):** Receive the agent prompt (Step 1 from two-session prompts), execute the implementation, run checkpoints, create the PR. If Copilot is at capacity, switch to GPT or Codex with the universal preamble prepended to the same prompt.

3. **Copilot or Perplexity (reviewer):** Receive the review prompt (Step 2). If using Copilot: use the Copilot-optimized deep-research review prompts. If using Perplexity: use Perplexity's three-turn review prompts.

4. **Claude (this chat):** Post-merge audit synthesis, next-step handoff inspection, lesson/bug documentation. This requires cross-phase knowledge that only Claude's project memory provides.

### The constraint-preservation rule

> **No prompt optimization may remove a safety constraint from the point-of-risk location.** A constraint is "at point of risk" when it appears inline in the task step where the mistake would be made. Moving it to a preamble, a worker reading list, or a separate document adds a failure mode. If a constraint prevents hardware damage, data corruption, or CI breakage, it must appear literally in the step where the agent would make the mistake.

### The checkpoint completeness rule

> **Every implementation prompt must contain at least one mid-implementation checkpoint and one pre-PR self-review gate.** The mid-implementation checkpoint verifies the most critical intermediate state (scope compliance, identity gate, or pipeline correctness). The pre-PR gate verifies scope, all validations, and all deliverables.

### When to produce LLM-specific prompt variants

- **Agent prompts:** Never. Use the original + universal preamble.
- **Review prompts:** Yes, when the review will run on a specific non-Claude platform. Copilot gets deep-research delegation. Perplexity gets three-turn structure.
- **Planning prompts:** Never. Planning stays in Claude.

---

## Part 7 — Evaluation of Cross-LLM Prompt Analyses

### GPT — Analysis 8/10, Prompts 7/10

**Analysis strengths:** Architecturally coherent coordinator/worker model. Six optimization rules are well-reasoned. Token estimates are directionally plausible.

**Analysis valid?** Yes, with a caveat: the analysis assumes GPT can run parallel bounded workers, which depends on the execution environment. In standard ChatGPT, workers don't exist — the protocol collapses into sequential passes.

**Prompt quality:** Good for v7.6.6.0–v7.6.6.3, increasingly thin for v7.6.6.5+. The worker scopes for later steps are too vague to execute. Critical project-specific constraints (curl syntax, board YAML, satellite mode) are delegated to worker extraction where they can be dropped.

**Verdict:** The GPT-optimized prompts should NOT be used for agent execution. The analysis is useful as a reference for understanding context pressure.

### Perplexity — Analysis 9/10, Prompts 8.5/10

**Analysis strengths:** Most technically honest. Correctly identifies its own architectural mismatch. Best token methodology (separates input/output, accounts for file loading). Three-turn session structure is the best innovation across all four.

**Analysis valid?** Yes. The capability table, degradation explanation, and savings methodology are all correct.

**Prompt quality:** Excellent for review. The inline context headers and `⛔ Do NOT` blocks at prompt top are a genuine improvement. Cannot be used for agent execution (no shell, no file creation).

**Verdict:** Use Perplexity's review prompts for review sessions. Do not use for agent execution. The three-turn structure and inline context header pattern should be adopted as a general principle.

### Codex — Analysis 4/10, Prompts 3/10

**Analysis strengths:** Correctly identifies the pattern of separating immutable policy from per-step deltas.

**Analysis flaws:** Measured prompt body tokens (the instruction text) instead of total working set (instructions + files). The "45-85% savings" claim is measuring the wrong thing. The analysis is too thin (89 lines) to be useful as a decision-making reference.

**Prompt quality:** Steps v7.6.6.4–v7.6.6.8 are dangerously under-specified. An agent cannot execute "summarize endpoint smoke-test scope" when the scope involves 21 endpoints across two boards with specific curl syntax and mandatory mode restoration.

**Verdict:** Do not use. The Codex-optimized prompts would produce incomplete implementations requiring more fix cycles than the originals.

### Copilot — Analysis N/A, Prompts 7.5/10

**No analysis produced.** Copilot only optimized review prompts.

**Prompt quality:** The 4-step deep-research review structure is operationally sound and well-suited to Copilot's capabilities. Gate checklists are comprehensive. In-PR deliverables are preserved, and §9 remains post-merge bookkeeping only (tag/close).

**Verdict:** Use for review sessions in Copilot. The deep-research delegation pattern genuinely reduces reviewer context pressure while maintaining gate coverage.

---

## Part 8 — Can Perplexity's Three-Turn Review Prompts Be Used After Copilot Agent Execution?

**Yes, with one modification.**

Perplexity's review prompts reference the PR number and expect to access the PR diff via GitHub MCP. After Copilot creates the PR, the PR number is known, and Perplexity can inspect the diff, read changed files, and check evidence.

**The modification needed:** Perplexity cannot run shell commands, so review gates like "does `assemble-sensor-history.sh --check` exit 0?" must be verified by reading the agent's session log or CI output rather than running the command. The agent session must produce a compliance table in the PR description (which the Phase Y implementation instructions already require). Perplexity's review then cross-references the compliance table against the gate checklist.

**The workflow:**
1. Copilot (agent) runs the implementation, creates PR with compliance table in description
2. Perplexity (reviewer) receives the Perplexity-optimized review prompt with `<PR_NUMBER>` filled in
3. Perplexity Turn 1: extracts gate checklist from review prompt's inline context
4. Perplexity Turn 2: fetches PR diff and compliance table via MCP, checks each gate
5. Perplexity Turn 3: produces structured verdict and fix list

This works because the review side doesn't need shell access — it needs file inspection and logical reasoning, which Perplexity handles well.

**Limitation:** Perplexity cannot run shell commands, so it can't replace the implementation agent for PR-side gates that require command output. It can still review the diff and produce a consolidated audit.

---

## Appendix A — Token Estimate Methodology Critique

All four LLMs produced token estimates with incomparable methodologies:

| LLM | What was measured | What was excluded | Reliability |
|---|---|---|---|
| GPT | Coordinator-session context | Worker-session costs | Medium — useful for understanding coordinator pressure |
| Perplexity | Total input + output tokens | Sub-agent costs (noted) | Good — most comprehensive |
| Codex | Prompt body text only | All file reads, all outputs | Misleading — excludes the dominant cost |
| Copilot | Not provided | — | N/A |

**Standard for future estimates:** Total context = prompt text + all files loaded into context + generated output. Always specify whether worker/sub-agent costs are included. Always specify the context window size assumed.

---

## Appendix B — The Universal Multi-LLM Execution Preamble

See Part 4 above. This preamble should be prepended to any agent prompt when running on a non-Claude coding agent. It costs ~350 tokens and prevents the five most common cross-LLM failure modes.

The preamble is NOT needed when running on Claude Code or Copilot (which natively follows the prompt style). It IS needed for GPT, Codex, or any other agent that might be tempted to "optimize" the reading list or reorder implementation steps.

---

_End of multi-LLM prompt strategy document._
