# Development Methodology Audit and Process Blueprint Session

_Purpose: Examine how this project's AI/LLM-driven development works, identify inefficiencies, and produce reusable methodology documents that improve speed, quality, and planning discipline — both for this project and as a blueprint for others._

_Timing: Run this session AFTER Phase VX completes and BEFORE the multi-phase planning session._

---

## Instructions for the Advisor

You are the architectural advisor for the ESP32-GW Multi-Sensor Gateway project. This session is NOT about firmware, dashboards, or board onboarding. It is about **how the development itself works** — the tooling, the workflow, the prompt methodology, the review process, the planning discipline, and the documentation practices.

Your job is to audit the current development process end-to-end, identify what works and what doesn't, and produce methodology documents that serve two purposes:
1. **Operational guide** — make this project's development faster, more reliable, and better planned
2. **Reusable blueprint** — make the methodology transferable to anyone wanting to implement AI/LLM-based software development

### ⚠️ Read Before Responding

```
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor
git checkout main && git pull
```

### Mandatory Reading (read ALL of these before asking questions or producing output)

**Development methodology docs:**
1. `Docs/writing-guide/methodology.md` — prompt writing methodology (the foundation document)
2. `Docs/writing-guide/gap-catalog.md` — failure catalog from Phases 4–6
3. `Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md` — multi-LLM distribution strategy
4. `Docs/writing-guide/prompt-guide-addendum-checkpoints-and-multi-llm-2026-04-09.md` — checkpoint pattern
5. `Docs/writing-guide/review-prompt-quality-rule.md` — review quality constraints

**Phase results (read all — these document what worked and what didn't):**
6. `prompts/handoff/phaseD/phaseD-results.md`
7. `prompts/handoff/phaseX/phaseX-results.md`
8. `prompts/handoff/phaseY/phaseY-results.md`
9. `prompts/handoff/phaseV/phaseV-results.md`

**Workflow and planning docs:**
10. `prompts/prompt-index-and-workflow.md` — step index and workflow instructions
11. `prompts/handoff/multi-phase-planning-prompt.md` — how phases are planned
12. `Docs/architecture-overview.md` — project architecture

**Representative prompt sets (read at least one complete set from Phase V):**
13. `prompts/phaseV/v7.6.9.5-agent-prompt-gpt-codex.md` — agent prompt example
14. `prompts/phaseV/v7.6.9.5-claude-two-step.md` — two-step prompt example
15. `prompts/handoff/phaseV/session-handoff-v7.6.9.5.md` — session handoff example
16. `prompts/phaseV/consolidated-audit-template-phaseV.md` — post-merge audit template

**Scripts (skim for understanding, don't need line-by-line):**
17. `scripts/provision.sh` — board provisioning pipeline
18. `scripts/preflight.sh` — 48-check pre-commit verification
19. `scripts/patch-esphome-httpd-stack.sh` — local component override

**Phase VX prompts (most recent methodology iteration):**
20. `prompts/handoff/phaseVX/phaseVX-board-onboarding-sprint-prompt.md` — sprint scoping prompt
21. `prompts/phaseVX/v7.6.10.0-agent-prompt-gpt-codex.md`
22. `prompts/phaseVX/v7.6.10.0-claude-two-step.md`
23. `prompts/phaseVX/v7.6.10.1-agent-prompt-gpt-codex.md` — board profile creation prompt (infrastructure workload)
24. `prompts/phaseVX/v7.6.10.4-agent-prompt-gpt-codex.md` — dashboard auth refactor prompt (JS-only workload, newest iteration)
25. `prompts/phaseVX/v7.6.10.4-claude-two-step.md` — two-step with auth refactor context
26. `prompts/handoff/phaseVX/phaseVX-results.md` — Phase VX delivery record
27. `Docs/session-log-2026-05-06-v7.6.10.4.md` — v7.6.10.4 session log (contains 10 prompt improvement recommendations)

---

## Operator Questionnaire

_After reading the mandatory files, the advisor should ask these questions. The operator's answers provide the ground truth that the codebase alone cannot reveal._

### A. Current Development Environment

1. **What LLM platforms are you currently using, and what are the concrete limits of each?**
   - Claude (this interface): conversations per day? tokens per conversation? monthly limits?
   - GitHub Copilot: which tier? workspace agent or chat-only? monthly usage?
   - OpenAI Codex / GPT: which tier? API or chat? context window?
   - Kiro: current state? stable enough for execution? auth/connection issues?
   - Perplexity: which tier? GitHub MCP working reliably? three-turn pattern stable?
   - Any other tools (Cursor, Windsurf, Gemini, etc.)?

2. **What is your local development environment?**
   - LXC container for ESPHome — how is it configured? Can it run agents directly?
   - How do you flash boards — serial, OTA, or both? Turnaround time per flash?
   - Playwright tests — how long does a full run take? Can it run in CI?
   - Do you use any CI/CD beyond what GitHub Actions provides?

3. **How much wall-clock time does a typical step take, end to end?**
   - Prompt production (Claude advisory session): ___
   - Agent execution (Copilot/Codex/Kiro): ___
   - Review (Perplexity three-turn + your own review): ___
   - Device testing (flash + measure + record): ___
   - Post-merge deliverables (audit, changelog, session log): ___
   - Total per step: ___
   - How many steps can you do per day? ___

4. **Where do you lose the most time?**
   - Agent fix cycles (how many per step on average)?
   - Context window exhaustion mid-session?
   - Waiting for builds (compile times)?
   - Manual documentation work?
   - Context rebuilding when switching between sessions/tools?
   - Something else?

### B. GitHub Usage

5. **How are you currently using GitHub features?**
   - Issues: created manually? Auto-created by agents? Linked to PRs?
   - Labels: do you use them systematically?
   - Milestones: used at all?
   - Projects (Kanban boards): used?
   - Discussions: used?
   - Wiki: used?
   - Branch protection rules: configured?
   - Required reviewers: configured?
   - GitHub Actions / CI workflows: which ones? Status check enforcement?

6. **What GitHub features would you WANT to use if setup were easy?**
   - Automated issue creation from agent prompts?
   - Milestone-per-phase tracking?
   - Project board with columns per step status?
   - Auto-labeling PRs?
   - CI pipelines for preflight/Playwright?

### C. Quality and Planning

7. **Looking back at all phases, which phase had the smoothest execution? Why?**

8. **Which phase had the most rework? What were the root causes?**

9. **What bugs or tech debt from earlier phases are still haunting you?**
   - BUG-082 (WROOM history export) — still deferred to Phase 7?
   - The Cloudflare polling issue — still open?
   - Others?

10. **When a new phase is planned, what information do you wish you had earlier?**
    - Better measurements before committing to a design?
    - More explicit acceptance criteria?
    - Clearer dependency mapping between steps?
    - Anything else?

11. **Are there steps that could have run in parallel but didn't?**
    - Example: could board profile creation (YAML/CSV) and stress test script development happen simultaneously?
    - Example: could documentation updates run in parallel with code PRs?
    - What prevents parallelism today — dependencies, or just workflow habit?

12. **How do you decide when a phase is "done enough" to close?**
    - Formal closure process (Phase V had one) — was it worth the effort?
    - Do deferred items get tracked reliably?

### D. Documentation and Knowledge Management

13. **Who is the audience for the project documentation?**
    - Just you (operator)?
    - Future contributors?
    - Anyone studying the methodology?
    - All of the above?

14. **Which documents do you actually reference during development?**
    - The prompt index?
    - The session handoffs?
    - The architecture overview?
    - The bugs-and-lessons files?
    - The writing guide?

15. **Which documents feel like overhead that doesn't pay for itself?**

16. **If you were onboarding someone to contribute to this project, what would take the longest to explain?**

---

## Analysis Framework

After the operator answers, the advisor should analyze across these dimensions:

### Dimension 1 — Session Economics
Map the token cost and wall-clock time of each session type (planning, prompt production, agent execution, review, post-merge). Identify where tokens are wasted on context that could be pre-loaded or cached. Identify where human time is spent on tasks that could be automated or templated.

### Dimension 2 — Parallelism Opportunities
Map the dependency graph between steps within a phase. Identify which steps have true sequential dependencies (step B reads step A's output) vs. artificial dependencies (step B just happens to come after step A in the plan). Propose a parallel execution model with explicit merge points.

### Dimension 3 — GitHub Integration
Design a GitHub workflow that uses Issues, Milestones, Labels, and optionally Projects to track phase progress, automate status updates, and create an audit trail that doesn't depend on markdown files in the repo. Consider how agents could auto-create issues and how CI could enforce quality gates.

### Dimension 4 — Bug and Tech Debt Prevention
Analyze the bug history (BUG-043 through BUG-083) and lesson history (LESSON-OPS-001 through LESSON-OPS-128) for patterns. Which categories of bugs recur? Which prevention mechanisms (Critical Rules, preflight checks, checkpoint gates) have been most effective? What's still missing?

### Dimension 5 — Knowledge Architecture
Evaluate the current documentation structure (Docs/, prompts/, writing-guide/). Is information findable? Is there duplication? Are there documents that should exist but don't? Should some information live in GitHub Wiki instead of the repo?

---

## Expected Deliverables

### Document 1: "AI-Driven Development Methodology — Practitioner's Guide"

A comprehensive document covering:
- Development workflow end-to-end (from phase planning through closure)
- Session types and their roles (planning, prompt production, execution, review, measurement)
- LLM distribution strategy (which models for which tasks, fallback chains)
- Quality gates and verification patterns
- GitHub integration recommendations
- Parallelism model
- Documentation discipline
- Lessons from 8 completed phases

This document should be written so that someone unfamiliar with the project could read it and understand how to set up a similar AI-driven development workflow for their own embedded systems project (or any project with similar constraints).

### Document 2: "Project-Specific Workflow Playbook"

A shorter, operational document for this project specifically:
- Concrete GitHub setup recommendations (issue templates, labels, milestones, CI workflows)
- Phase planning checklist (what to do before starting a new phase)
- Step execution checklist (optimized version of current workflow)
- Parallel execution rules (what can run simultaneously, what must be sequential)
- Post-phase review template
- Tech debt tracking system

### Optional Document 3: "Prompt Engineering Patterns for Embedded Systems"

If the analysis reveals patterns specific to embedded/IoT development with LLMs:
- Hardware constraint communication (how to tell an LLM about 34KB free heap)
- Device testing gate patterns (how to structure prompts for physical hardware verification)
- Partition table and memory layout prompting
- Multi-board/multi-architecture considerations

---

## Session Structure

This session should proceed in this order:

1. **Read** all mandatory files (do not skip any)
2. **Ask** the operator questionnaire (all sections)
3. **Analyze** across the five dimensions
4. **Present** findings and recommendations (before writing documents)
5. **Iterate** on recommendations with operator feedback
6. **Produce** the deliverable documents

The advisor should not start writing deliverables before step 5. The operator's feedback on the analysis may significantly change what gets written.

---

_End of session prompt._
