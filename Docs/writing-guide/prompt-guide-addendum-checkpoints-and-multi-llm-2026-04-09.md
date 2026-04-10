# Addendum to Prompt Writing Guide — Inline Verification Gates and Multi-LLM Execution

_Date: 2026-04-09_
_Context: Phase Y prompt innovation — reduces PR fix cycles from 2-6 to 0-2_
_Applies to: `Docs/writing-guide/methodology.md` — insert after §4.2 (Key Insight)_

---

## §4.4 — Inline Verification Gates (Checkpoints)

### What they are

A checkpoint is a concrete verification block inserted between task groups within §5 (Implementation Instructions). Each checkpoint forces the agent to verify its intermediate state before continuing.

### Why they exist

Without checkpoints, the prompt says "do steps 1-13, then validate." An error at step 3 isn't discovered until step 12. By then, 9 steps are built on a broken foundation. Fixing step 3 requires redoing steps 4-12. With a checkpoint after step 3, the agent catches and fixes only that step.

Root cause analysis from Phases D and X shows that 55% of PR fix cycles (scope violations + missed validation) are preventable with mid-implementation verification.

### Rules for placing checkpoints

**Rule 1:** One checkpoint per logical task group, never more than 4-5 implementation sub-steps apart.

A "logical task group" is a set of related changes that together produce a verifiable state:
- "Extract 8 fragments" → checkpoint: line count sum
- "Add preflight checks" → checkpoint: `preflight.sh` passes
- "Flash and test device" → checkpoint: board responds

**Rule 2:** Every checkpoint must be a concrete shell command with an expected result, not a subjective judgment.

Good: `wc -l firmware/core/*.h | tail -1 — expected: 4325`
Bad: "Verify the extraction looks correct"

**Rule 3:** Every checkpoint must include a STOP instruction if it fails.

The agent must not proceed past a failing checkpoint. Errors compound.

**Rule 4:** The final checkpoint before PR creation is always a scope-and-completeness gate.

This pre-PR gate checks: only allowed files changed, all validations pass, all deliverables present.

### Checkpoint template

```
---
⛔ CHECKPOINT [letter] (after [description]):
Run:
  [command 1] — expected: [result]
  [command 2] — expected: [result]
If ANY check fails: STOP. Fix the issue before continuing to the next step group.
Do NOT proceed with a failing checkpoint — errors compound.
---
```

### Pre-PR gate template

```
---
⛔ PRE-PR GATE (before creating PR):
Run:
  git diff --name-only — verify ONLY allowed files appear
  bash scripts/preflight.sh — all checks pass
  Playwright across all 4 fixture sets — all green
  [step-specific checks]
If ANY check fails: fix before creating PR.
---
```

### How many checkpoints per step

- Simple steps (v7.6.6.2, v7.6.6.4): 1 mid-implementation + 1 pre-PR = 2 total
- Medium steps (v7.6.6.0, v7.6.6.3): 2-3 mid-implementation + 1 pre-PR = 3-4 total
- Complex steps (v7.6.6.1, v7.6.6.6): 3-4 mid-implementation + 1 pre-PR = 4-5 total
- Device test steps (v7.6.6.5, v7.6.6.6): include "board alive" checkpoint after flash

### Token cost

Each checkpoint costs 100-150 tokens. A step with 4 checkpoints adds ~500 tokens to the prompt. This is a 3-5% increase in prompt size that prevents 30-50% of fix cycles.

---

## §4.5 — Multi-LLM Execution

### When this applies

When capacity constraints require distributing work across multiple LLMs — for example, using Copilot for agent execution and Perplexity for PR review when Claude's token budget is exhausted.

### The constraint-preservation rule

> **No prompt optimization may remove a safety constraint from the point-of-risk location.**

A constraint is "at point of risk" when it appears inline in the task step where the mistake would be made. Moving it to a preamble, a worker reading list, or a separate document adds a failure mode. If a constraint prevents hardware damage, data corruption, or CI breakage, it must appear literally in the step where the agent would make the mistake.

This rule exists because cross-LLM analysis showed that every LLM asked to "optimize" a prompt stripped safety constraints by moving them to worker delegation or compressed summaries. The agents then missed those constraints and produced implementations requiring more fix cycles than the originals.

### The universal preamble

When running an agent prompt on a non-primary LLM (e.g., GPT or Codex instead of Claude Code or Copilot), prepend this preamble:

```
═══════════════════════════════════════════════════════════════════
MULTI-LLM EXECUTION PREAMBLE
═══════════════════════════════════════════════════════════════════

You are executing an implementation prompt designed for a coding agent with
file system access and shell command execution. Follow the instructions
literally. Do NOT compress, summarize, or skip any reading steps.

CRITICAL RULES:
1. Read every file in §1 COMPLETELY and IN ORDER before changes.
2. Do NOT reorganize implementation steps. The order is deliberate.
3. When you hit a ⛔ CHECKPOINT, STOP and run every command listed.
   If any fails, fix it before continuing. Do NOT skip checkpoints.
4. "Do NOT" instructions are absolute — from real bugs that caused
   hardware damage or broke CI.
5. All POST: curl -d 'a=1' -X POST [url]. NEVER JSON content type.
6. S3 board: use GENERATED YAML, never committed C3 template.
7. After aggregator testing: run provision.sh satellite before PR.
8. Produce ALL §9 deliverables before closing session.
═══════════════════════════════════════════════════════════════════
```

### Do not produce LLM-specific prompt variants for agent execution

Use the original prompt + universal preamble. LLM-specific "optimized" variants strip safety constraints and create more fix cycles than they save in tokens.

LLM-specific variants ARE acceptable for review prompts (where the worst case is a less thorough review, not a broken implementation).

### Role distribution

| Role | Primary | Fallback | Why |
|---|---|---|---|
| Planning & prompt production | Claude | — | Project memory, lesson continuity |
| Agent execution | Copilot | GPT/Codex + preamble | File system, shell access |
| PR review | Copilot (deep-research) | Perplexity (three-turn) | Evidence collection |
| Post-merge audit | Claude | — | Cross-phase knowledge |

---

_End of addendum._
