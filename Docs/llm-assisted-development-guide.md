# LLM-Assisted Development: A Practitioner's Guide

_Based on 10+ phases of real-world AI-driven embedded firmware and dashboard development._
_Source project: ESP32-GW Multi-Sensor Gateway (2026)_

---

## Preface

This guide is extracted from two months of daily LLM-assisted development on an ESP32 embedded firmware project. During that time, the project went through 10+ phases, 50+ steps, 200+ PRs, and involved 6 different LLM platforms in various roles. Every recommendation here is backed by a specific experience — a bug that was caught, a failure pattern that repeated, or a process that measurably improved outcomes.

The guide is organized around the development lifecycle: Plan → Prompt → Execute → Review → Close. Each section covers what works, what fails, and why.

---

## 1. The Fundamental Reality of LLM-Assisted Development

### 1.1 What LLMs Are Good At

LLMs excel at: translating well-specified intent into code, applying known patterns consistently across files, generating boilerplate with correct structure, finding bugs when given focused review criteria, and producing documentation that matches actual code.

### 1.2 What LLMs Are Bad At

LLMs fail at: maintaining state across sessions, verifying their own assumptions, recognizing when they don't have enough information, resisting plausible-sounding-but-wrong explanations, and remembering recommendations from previous sessions.

### 1.3 The Core Insight

LLM-assisted development is not "AI writes code for you." It is **operator-directed development where AI amplifies the operator's intent** — but only if the operator provides accurate context, specific instructions, and verification gates. Without these, LLMs produce confident, plausible, wrong output.

The methodology's entire purpose is to provide these three things reliably.

### 1.4 The Truth-Seeking Discipline

The most expensive failures in this project's history came from accepting plausible explanations without verification. Truth-seeking is the primary objective of every advisory, planning, and debugging session. Four rules:

1. **Confirm WHAT before hypothesizing WHY.** Run a single diagnostic command before accepting any explanation for unexpected behavior. The C3 httpd stack investigation (BUG-083) cost days; one `grep` would have solved it in seconds.
2. **Eliminate the simplest explanation first.** Sophisticated theories are satisfying. Simple checks are faster. If an explanation sounds elegant, that is the signal to run the basic diagnostic first.
3. **State assumptions explicitly and verify each one.** "I assume X because Y" — then test X with a command. If verification is impossible, label it `UNVERIFIED ASSUMPTION`.
4. **When evidence and narrative diverge, evidence wins** — even when the narrative is yours.

When classifying evidence, direct measurements (curl output, compiler logs, device telemetry) outweigh source inspection (grep results), which outweigh current documentation, which outweigh historical documentation, which outweigh human memory, which outweigh model inference. Production-impacting decisions require measurement or source inspection. Model inference is hypothesis, not fact.

---

## 2. Planning Phase

### 2.1 Phase Architecture

Break work into phases. Each phase has a single theme (one feature, one refactor, one stabilization effort). Mixing themes within a phase leads to scope creep and agent confusion.

Each phase is broken into numbered steps. Each step is one PR with a clearly bounded scope. Target: 6-8 steps per feature phase.

**Lesson learned:** Two full phases (one month) were spent on refactoring because the original code grew past what LLM agents could handle in a single context window. If files exceed ~800 lines, agents can't reliably edit them. Plan refactoring proactively when files cross ~2,000 lines, not reactively when agents start failing.

### 2.2 The Assumption Audit

Before planning any phase, ask:

1. What are we assuming is true that we haven't verified recently?
2. What did the last postmortem recommend that hasn't been done?
3. What is the simplest thing that could go wrong?
4. What happens after 3 weeks of continuous operation?
5. What system measurements do we need before committing to this design?

These questions are not philosophical — each one corresponds to a real bug that cost days to investigate because the question wasn't asked.

### 2.3 Pre-Mortem Thinking

When designing a feature, ask: "If this fails in production six months from now, what will the failure look like?" Then work backward to add the measurement or guard that would catch it early.

Example from real experience: A postmortem recommended adding health-check logging for stack watermarks and heap stats. The recommendation was documented but never implemented. Six weeks later, the exact failure it would have caught (httpd stack exhaustion on a specific board) required a three-day investigation.

**Rule: Every recommendation becomes either an issue or an entry in a tracked list. No third option.**

### 2.4 Current State Document

Maintain a single `CURRENT-STATE.md` file that contains: current version, recent changes, what's next, open issues, current measurements, unimplemented recommendations, and stale documents. This file is the universal "read this first" for every session.

Update it after every merge. If it's stale, every session built on it is built on wrong assumptions.

### 2.5 Source-of-Truth Hierarchy

When sources disagree, resolve by this order:

1. Live code on `main`
2. Build output, test results, telemetry, and device measurements
3. `CURRENT-STATE.md`
4. Decision log
5. Current phase implementation plan
6. Current step prompt and handoff
7. Changelog and recent phase closure
8. Historical postmortems and archived handoffs
9. Model memory or conversational memory

Archived documents are evidence, not instructions. Any plan older than the last refactoring phase must be treated as stale until verified. Generated artifacts are never the source of truth when source fragments exist.

---

## 3. Prompt Engineering

### 3.1 The Three-Prompt Bundle

Each implementation step needs three prompts:

1. **Agent prompt** — detailed implementation instructions with checkpoints, scope boundaries, and acceptance criteria
2. **Review prompt** — specific questions for reviewers keyed to what this step changed
3. **Handoff document** — what this step does, risk level, and what the next step needs to know

Producing these is the most expensive part of the process (in LLM tokens and operator time), but it's where quality is determined. A precise prompt produces a first-attempt-merge; a vague prompt produces 3-6 fix cycles.

### 3.2 Prompt Anatomy

A complete agent prompt has these sections:

1. **Required reading** — exact files the agent must read before starting, in order
2. **Pre-implementation verification** — checkpoints that confirm assumptions match reality
3. **Scope boundary** — files the agent MAY and MUST NOT modify
4. **Critical rules** — project-specific constraints relevant to this step
5. **Do-NOT list** — explicit prohibitions based on past failures
6. **Implementation steps** — numbered, specific, with inline verification
7. **Acceptance criteria** — checkable conditions for completion
8. **Pipeline commands** — exact build/test commands to run
9. **Post-implementation verification** — final checks before marking PR ready
10. **"Step deliverables (in-PR)** — documentation updates, state file updates

### 3.3 Checkpoint Design

Checkpoints are the highest-ROI innovation in the methodology. They reduced fix cycles from 2-6 per step to 0-1.

**Rules for effective checkpoints:**

- Use queries, not assertions: `grep -c 'function_name' file.h` is stable across commits. "Line 47 should contain X" breaks with every merge.
- Use identifier anchors: "Find the loop in `handle_gateways_` that iterates `caches[]`" survives refactors. "Line ~1431" does not.
- Stop-don't-fix semantics: When a checkpoint fails, the agent should REPORT, not silently "fix" it. Fixing a checkpoint to make it pass defeats its purpose.
- Verify before modifying: The agent must check current state before applying changes. "If line 47 has X, change it to Y" — but first confirm line 47 actually has X.

When a checkpoint fails, the agent must post a structured comment — not explain away the discrepancy:

```
⛔ CHECKPOINT FAILED — <checkpoint name>
Expected: <expected value or condition>
Actual:   <command output>
Command:  <verbatim command>
Action:   STOPPING. NO code changes made. Awaiting operator decision.
```

### 3.4 The Stale Prompt Problem

Prompts reference file paths, function names, line numbers, and version strings. All of these change with every merge. A prompt written for Step 3 references the codebase as of Step 2's merge. By Step 5, half the references may be wrong.

**Mitigations:**

- Prefer function/identifier anchors over line numbers
- Tag line numbers with their date: "line ~1431 (as of 2026-04-13)"
- Read the live codebase before every response — never rely on memory
- Consider a script that greps for key anchors and patches the prompt immediately before execution

---

## 4. Multi-LLM Workflow

### 4.1 Role Assignment

Different LLMs have different strengths. Assign roles based on capability:

| Role | Best fit | Why |
|---|---|---|
| Architecture advisor + prompt producer | High-capability model (Claude Opus, GPT-5.4+) | Needs deep reasoning, full project context |
| Agent execution | Mid-tier with tool access (Copilot, Codex) | Needs file access, git operations, terminal |
| Inline code review | Multiple reviewers (Copilot, Codex, Gemini) | Different models catch different defect types |
| External PR review | Different model from execution agent | Fresh perspective, no confirmation bias from having written the code |
| Structured review / audit | Model with web/MCP access (Perplexity) | Needs to access GitHub PRs, post comments |

### 4.2 Why Multiple Reviewers Matter

In practice, different LLM reviewers catch different defect categories. A security-focused model catches auth gaps; a systems-focused model catches resource leaks; a code-quality model catches maintainability issues.

One reviewer catches ~60% of defects. Three catch ~85%. Five catch ~92%. The incremental value of reviewer 4 and 5 is small but non-zero, and occasionally critical (example: one reviewer found a socket function security defect that all others missed).

**Recommendation:** Use 5 reviewers as default, automated where possible. Reduce to 2-3 only when the phase declares a Sprint operating point (docs-only, cosmetic, isolated fixes). The optimization target is review orchestration automation, not reviewer reduction.

### 4.3 The "Optimized Prompt" Trap

When an LLM is asked to "optimize" a prompt for another LLM, it consistently strips safety constraints, scope guards, and checkpoint language — the very elements that prevent hardware damage and CI failures. Cross-LLM analysis across 4 different models confirmed this pattern.

**Rule: Never use LLM-optimized variants of agent prompts for execution.** The prompt author (human or advisor LLM) produces the prompt. It is used as-is.

### 4.4 Cost Optimization

LLM costs are a real constraint. Strategies:

- Use the most expensive model (Opus, GPT-5.4+) only for planning and prompt production — these consume the most context but happen least frequently
- Use mid-tier models for execution — they need tool access more than reasoning depth
- Use the cheapest capable model for reviews — the review prompt does the heavy lifting, not the model's reasoning
- Size phase scopes so prompt production fits within a single session allocation
- Investigate non-profit / educational discounts — significant savings are available

---

## 5. Execution and Review

### 5.1 Agent Setup Protocol

Before the agent starts coding:

1. Sync latest main, create feature branch
2. Create bootstrap commit, push, open draft PR
3. Read required files in order specified by the prompt
4. Run pre-implementation verification gates
5. Only then start editing

This protocol prevents the agent from working on stale code and ensures the PR exists before any commits.

### 5.2 Review Orchestration

After agent execution:

1. Mark PR ready for review
2. Trigger inline reviews (5 reviewers — 3 inline simultaneously, 2 external)
3. Agent addresses inline findings (new commit)
4. External reviewers analyze the full PR
5. Operator posts device testing results (if applicable)
6. Final structured review produces consolidated audit

The entire review cycle takes 30-60 minutes. The main time sink is manual orchestration — triggering each reviewer, collecting results, correlating findings. Automating this (via GitHub Actions or a shell script) is the highest-leverage time optimization.

### 5.3 Device Testing

For embedded projects, device testing is irreplaceable. No amount of code review catches a heap exhaustion that only manifests after 3 weeks of data accumulation.

**Automated device tests in agent prompts:**
- Flash firmware via OTA (never interactive `run`, always `upload`)
- Wait for boot (30 seconds)
- Run curl commands against known endpoints
- Parse responses for expected values
- Post results to PR comment

**Manual device tests by operator:**
- Visual dashboard inspection
- Long-duration stability observation
- Edge case testing (concurrent connections, large data sets)
- Any test that requires physical interaction with hardware

---

## 6. Pitfall Patterns and Early Recognition

### 6.1 The Plausible Narrative Trap

**Pattern:** An LLM generates a technically plausible explanation for an unexpected observation, and the operator accepts it without verification.

**Example:** An ESP32-C3 board showed unexpected stack watermark values. The LLM hypothesized an architecture-conditional stack sizing difference (RISC-V vs Xtensa). This was wrong — a single `grep` would have shown the board was missing a configuration block. The plausible explanation cost days; the simple check would have taken seconds.

**Recognition:** If an explanation sounds sophisticated and satisfying, that's a signal to verify it with the simplest possible diagnostic before accepting it.

**Prevention:** Add to planning prompts: "Before hypothesizing WHY something behaves unexpectedly, confirm WHAT is happening with a single diagnostic command."

### 6.2 The Forgotten Recommendation

**Pattern:** A postmortem or review produces actionable recommendations. They are documented in an archive directory and never referenced again. Weeks later, the exact failure they would have prevented occurs.

**Prevention:** Every recommendation routes to a tracked location (issue tracker or state file). No archiving without tracking.

### 6.3 The Context Window Cliff

**Pattern:** Source files grow past what an LLM agent can hold in context. The agent starts making partial edits, missing cross-references, or introducing inconsistencies. The operator doesn't recognize this as a context problem and instead increases prompt specificity, which consumes even more context.

**Recognition:** If fix cycles per step suddenly increase from 0-1 to 3+, check whether the target files have grown past ~800 lines since the last smooth phase.

**Prevention:** Track file sizes. Plan refactoring when any source file crosses ~2,000 lines. The refactoring is an investment — it pays back in every subsequent phase.

### 6.4 The Documentation Drift

**Pattern:** Planning documents reference file paths, function names, and architectural assumptions. The codebase evolves through multiple phases. The planning documents are never updated. When a new phase starts using these documents, agents follow stale instructions.

**Recognition:** Check the "Last updated" date of any planning document. If it predates the most recent refactoring phase, it's stale.

**Prevention:** Maintain `CURRENT-STATE.md` with a "Stale Documents" section that flags outdated plans. The planning session's first task is to verify and update stale references.

### 6.5 The Over-Documentation Trap

**Pattern:** The project accumulates extensive documentation — lessons, postmortems, gap catalogs, critical rules, audit files. But retrieving the right piece of information at the right time becomes harder than creating it. Documentation volume increases but defect rates don't decrease proportionally.

**Recognition:** If you can't find a specific lesson or recommendation within 30 seconds, the documentation is organized for writing, not for reading.

**Prevention:** Layer the documentation by access frequency (see Knowledge Architecture). The most-accessed documents are the shortest. Historical reference is for investigation, not for daily reading.

---

## 7. Continuous Improvement

### 7.1 Phase Closure Protocol

Every phase ends with:

1. Plan vs delivery comparison — did we deliver what we planned?
2. Review findings summary — what did reviewers catch that prompts should have prevented?
3. New lessons and critical rules
4. Writing guide update — new patterns, new gap categories
5. Recommendation tracking — every action item has a destination
6. KPI recording — steps, fix cycles, wall-clock time
7. Model/tool recording — which models were used for planning, execution, and review; any notable behavior changes or drift observed during the phase
8. `CURRENT-STATE.md` validation — confirm the "Last verified" date, open issues, stale documents list, and unimplemented recommendations are all current. If `CURRENT-STATE.md` is stale at phase closure, the next phase starts on wrong assumptions. Treat a stale state file with the same urgency as a failing test.

### 7.2 Process KPIs

| KPI | What it measures | Target |
|---|---|---|
| Fix cycles per step | Prompt quality | ≤1 (medium risk) |
| Steps per feature | Phase scoping accuracy | ≤8 |
| Wall-clock per step | Execution efficiency | ≤2 hours |
| Checkpoint saves | Checkpoint effectiveness | >0 (checkpoints are catching things) |
| Preventable findings | Prompt gap rate | Decreasing over phases |

### 7.3 Iterating on the Process

This methodology itself is subject to improvement. The rule: every phase closure is an opportunity to update the process guide. But updates must be driven by evidence (a measured improvement or a documented failure), not by speculation about what "should" work better.

The writing guide, prompt templates, and review checklists are living documents. They grow with each phase — but they must also be pruned. When the writing guide exceeds what fits in a single planning session's context, split it into core (always-read) and reference (search-when-needed) sections.

**Tool and dependency changes:** Any ESPHome version bump requires re-running the component defaults audit and committing the diff. Model behavior also changes over time — if fix cycles suddenly increase without codebase explanation, check whether the execution or review model changed behavior.

**Operator load:** The methodology depends on a human operator to write prompts, judge findings, and maintain continuity. Prompt quality degrades under fatigue. Avoid writing high-risk prompts during long uninterrupted planning blocks, and defer major process changes when multiple context-heavy tasks are active.

---

## Appendix A: Glossary

| Term | Definition |
|---|---|
| **Phase** | A self-contained scope of work (feature, refactor, stabilization) with 6-12 steps |
| **Step** | One PR's worth of work, with its own prompt bundle |
| **Prompt bundle** | Agent prompt + review prompt + session handoff for one step |
| **Checkpoint** | A verification query embedded in a prompt that confirms assumptions match reality |
| **Scope guard** | Explicit list of files the agent may and must not modify |
| **Fix cycle** | An additional commit required after review findings |
| **Consolidated audit** | Summary of all review findings for one step, with severity classifications |
| **CURRENT-STATE.md** | Universal session context file, updated after every merge |
| **Decision log** | One-line index of architectural decisions with links to source documents |

## Appendix B: Template Checklist for Starting a New LLM-Assisted Project

1. Create `CURRENT-STATE.md` at repo root
2. Create `.github/copilot-instructions.md` with top 10 project rules
3. Create `AGENTS.md` with comprehensive agent instructions
4. Create `Docs/decisions/decision-log.md`
5. Set up CI with path filtering (skip docs-only changes)
6. Define the first phase with ≤8 steps
7. Produce the first prompt bundle (agent + review + handoff)
8. Execute, review, and close — then retrospect before Phase 2

---

_This guide is a living document. Update it when evidence shows a better approach._
