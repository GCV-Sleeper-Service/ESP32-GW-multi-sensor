You are producing the complete implementation prompt package for Phase Y of the following repository:
https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

## Your Task

Produce the full set of prompts, handoffs, and supporting documents needed to execute Phase Y (v7.6.6.x — firmware refactor of `sensor_history_multi.h`).

All deliverables should be saved into the repo and committed to `main`.

This is a **prompt production and documentation task only**. Do **not** implement the refactor.

---

## Prerequisites

Before running this prompt, the following must already be committed to `main`:
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — the Phase Y plan (produced by a prior session)
- Documentation reorganization from Issue #140 must be complete (C1 prompt already executed)

If either is missing, **stop and report the gap** rather than proceeding with stale references.

---

## Context: Reading List

Read in this exact order:

### Primary inputs
1. `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`
   — **the Phase Y plan**; this defines every step, module boundary, acceptance criterion, and gate condition. All prompts derive from this document.

2. `Docs/phase-Y-current-state-inventory-sensor-history-v2.md`
   — the v2 inventory; provides the file-level detail prompts must reference

3. `Docs/phase-X-architecture-and-refactor-plan-dashboard.md`
   — Phase X plan; format reference for how step-level detail maps to prompts

### Methodology and patterns
4. `prompts/handoff/phaseX/phase-x-two-session-prompts.md`
   — **the proven two-prompt pattern**: one agent execution prompt + one review prompt per step. Replicate this pattern for Phase Y.

5. `prompts/handoff/phaseX-results.md`
   — Phase X lessons on prompt anatomy: imperative numbered reading order, pre-implementation verification gates, inline anti-patterns at point of risk, explicit post-merge deliverable blocks

6. `prompts/prompt-index-and-workflow.md`
   — current prompt index and critical rules (post-C1 reorganization)

### Writing guide
7. `Docs/writing-guide/methodology.md`
   — prompt writing methodology

8. `Docs/writing-guide/gap-catalog.md`
   — known prompt failure patterns

9. `Docs/writing-guide/checklists/firmware.md`
   — firmware-specific checklist

10. `Docs/writing-guide/checklists/dashboard.md`
    — dashboard checklist (for Phase X pattern reference)

### Firmware reference
11. `dashboard/sensor_history_multi.h`
    — the file being split; prompts must reference exact function names, line ranges, and include patterns

12. `scripts/render_sensor_config.py`
    — generator that prompts must account for

13. `scripts/provision.sh`
    — pipeline entry point; v7.6.6.0 prompt modifies this

14. `scripts/preflight.sh`
    — guardrails that all steps must preserve

15. `firmware/esp32-c3-multi-sensor.yaml`
    — YAML include wiring that later steps modify

### Lessons
16. `Docs/lessons/firmware.md`
    — firmware-domain constraints that must appear as inline anti-patterns in prompts

17. `Docs/lessons/build-pipeline.md`
    — pipeline constraints

---

## Deliverables

### A. Writing Guide Update

Before producing prompts, update the writing guide with Phase X and Phase Y lessons:

**`Docs/writing-guide/methodology.md`:**
- Add Phase X prompt anatomy lessons (the two-prompt pattern, imperative reading order, pre-implementation gates, inline anti-patterns, post-merge deliverable demands)
- Add the key insight: "handoff documents alone are insufficient to drive agent completeness"

**`Docs/writing-guide/gap-catalog.md`:**
- Add any new gap patterns from Phase X execution (identity gate verification, contiguous-slice validation, generated artifact pipeline ordering)

**`Docs/writing-guide/checklists/firmware.md`:**
- Add C++ split-specific checklist items: `#include` order verification, forward declaration needs, mutex/lock visibility across files, deferred-task accessibility, `static` keyword scope implications, ESPHome YAML `includes:` ordering
- Add Phase Y verification strategies (compile gate, preprocessor output comparison if applicable)

### B. Session Handoffs

Produce one session handoff per Phase Y step. Each handoff must follow the established format and include:

- Current state (what's on `main` when this step starts)
- What this step delivers
- Pre-conditions (gate checks before starting)
- Key files to read
- Critical constraints and anti-patterns for this specific step
- Workfolow as it was outlined in the phaseX session prompts. IMPORTANT: Refer to existing session handoffs from phaseX for structure and outline, for example use the document prompts/handoff/phaseX/session-handoff-v7.6.5.7.md 
- Post-merge deliverables (inspection of next step's handoff, consolidated audit), check phaseX handoff document  prompts/handoff/phaseX/session-handoff-v7.6.5.7.md for reference
- Pipeline commands to run

Save to: `prompts/handoff/phaseY/session-handoff-v7.6.6.{N}.md` for each step defined in the Phase Y plan.

**Special requirement:** Each handoff from v7.6.6.1 onward must include a requirement that post-PR closure deliverables include inspecting and updating the next step's handoff and prompt (the chain-inspection pattern from Phase X v7.6.5.1–v7.6.5.8).

### C. Agent Implementation Prompts

Produce one agent implementation prompt per Phase Y step. Each prompt must include:

1. **§1 — Imperative reading order** (numbered, not optional)
2. **§2 — Pre-implementation verification gate** (checks the agent must pass before writing any code)
3. **§3 — Scope boundary** (what IS and what IS NOT in scope for this step)
4. **§4 — Do-NOT list** (explicit anti-patterns for this step, placed at point of risk)
5. **§5 — Implementation instructions** (exact files, exact functions, exact changes)
6. **§6 — Acceptance criteria** (checklist format)
7. **§7 — Pipeline commands** (full regeneration pipeline as of this step)
8. **§8 — Verification gate** (identity/compile/test gate for this step)
9. **§9 — Post-merge deliverables** (consolidated audit, changelog entry, session log, instruction compliance table)
10. **§10 — Anti-patterns and inline warnings** (C++-specific: `#include` order, `static` scope, forward declarations, mutex visibility, deferred-task accessibility)

Save to: `prompts/phaseY/v7.6.6.{N}-implementation-instructions-for-coding-agent.md` for each step.

**C++ specific anti-patterns that must appear in every prompt:**
- `#include` order matters: forward declarations may be needed when splitting
- `static` functions/variables in a header have file-level scope — when the header is included, `static` means per-translation-unit, not global. Verify `static` usage is intentional after split.
- Mutex variables must be declared in a header included by all consumers
- Deferred-task functions must be visible (declared or defined) before the scheduling call site
- ESPHome YAML `includes:` order determines compilation order — verify no forward-reference violations
- `render_sensor_config.py` marker blocks must remain in exactly one file and the generator must be updated if that file changes
- `application/x-www-form-urlencoded` POST body requirement still applies after split
- `maybe_yield_nvs_scan_()` must remain accessible from all NVS-scanning loop sites

### D. Review Prompts

Produce one review prompt per Phase Y step. Each review prompt must include:

1. Step-specific review checklist targeting that step's exact failure modes
2. Acceptance criteria verification (cross-reference against agent prompt §6)
3. Migration safety rule verification (all 12 rules)
4. Pipeline verification (all checks pass)
5. Documentation completeness check
6. Instruction compliance output table requirement

Save to: `prompts/phaseY/v7.6.6.{N}-review-prompt.md` for each step.

### E. Combined Two-Session Prompts File

Produce a single file containing all agent + review prompt pairs, organized by step. This is the consolidated reference matching the Phase X pattern.

Save to: `prompts/handoff/phaseY/phase-y-two-session-prompts.md`

### F. PR Audit Question Template

Produce a Phase Y-specific PR audit question template. Structure:

**Stable core (apply to every PR):**
1. Does the PR match the scope defined in the step prompt?
2. Are all acceptance criteria met?
3. Do all Playwright tests pass (all 4 fixture sets)?
4. Does preflight pass?
5. Does `esphome config` validate?
6. Were any files modified outside the declared scope?
7. Is the changelog entry present and accurate?
8. Is the consolidated audit document produced?
9. Was the next step's handoff inspected and updated if needed?

**Phase Y supplements (C++ split-specific):**
10. Does the `#include` order in the assembly file match the plan's specified order?
11. Are all `static` declarations intentional and correctly scoped after the split?
12. Are mutex/lock primitives visible from all files that access shared state?
13. Are deferred-task functions visible from their scheduling call sites?
14. Did `render_sensor_config.py --check` pass after the split?
15. Is the YAML `includes:` list correct for the current step's file structure?
16. Was the verification gate (compile/preprocessor/device test) executed and documented?
17. What prompt change would have prevented any failures encountered?

Save to: `prompts/phaseY/pr-audit-question-template-phaseY.md`

### G. Bug/Problem Escalation Prompt

Produce a self-contained prompt that the operator can use to consult an architectural advisor (Claude) mid-phase when a bug or problem is encountered during Phase Y execution. The prompt should:

1. Be self-contained (no dependency on prior conversation context)
2. Include structured fields the operator fills in:
   - Current version/step (e.g., "v7.6.6.3")
   - Error description (what happened)
   - What was attempted (what the agent or operator tried)
   - Relevant files (list of files involved)
   - Error output (logs, compiler errors, test failures)
   - Agent prompt used (reference to which prompt was being executed)
3. Instruct the advisor to:
   - Clone the repo and read the Phase Y plan + inventory + relevant lessons
   - Diagnose the root cause
   - Produce a resolution package (same format as the Phase X v7.6.5.4 PR #145 resolution)
   - Check if the bug reveals a prompt defect that needs fixing for remaining steps
   - Produce updated prompt/handoff edits if needed
4. Reference the Phase Y plan, v2 inventory, and lessons as mandatory reading
5. Include a checklist of common Phase Y failure modes:
   - `#include` order violation (symbol not found / incomplete type)
   - `static` scoping issue (duplicate symbol / missing symbol)
   - Mutex not visible across files
   - Deferred-task function not visible from scheduling site
   - Generator marker block in wrong file after split
   - YAML `includes:` order wrong
   - Preflight check fails on moved file
   - Compile succeeds but Playwright tests fail (behavior regression)

Save to: `prompts/phaseY/phase-y-bug-escalation-prompt.md`

### H. Prompt Index Update

Update `prompts/prompt-index-and-workflow.md`:
- Add Phase Y step table with all version numbers, prompt file paths, and "Pending" status
- Add references to the new Phase Y deliverables (plan, inventory v2, audit template, escalation prompt)
- Add any new critical rules if the Phase Y plan introduces them

---

## Commit Strategy

Package all deliverables and commit to `main`:

Commit message: `docs: produce Phase Y implementation prompt package (handoffs, agent prompts, review prompts, audit template, escalation prompt, writing guide update)`

Or if multiple commits are cleaner:
1. `docs: update writing guide with Phase X/Y lessons`
2. `docs: produce Phase Y handoffs and agent/review prompts`
3. `docs: produce Phase Y audit template and escalation prompt`
4. `docs: update prompt-index for Phase Y`

---

## Verification Checklist

Before committing:

- [ ] One handoff per Phase Y step exists in `prompts/handoff/phaseY/`
- [ ] One agent prompt per step exists in `prompts/phaseY/`
- [ ] One review prompt per step exists in `prompts/phaseY/`
- [ ] Combined two-session prompts file exists
- [ ] PR audit template exists with both stable core and Phase Y supplements
- [ ] Bug escalation prompt exists and is self-contained
- [ ] Writing guide updated (methodology, gap catalog, firmware checklist)
- [ ] Prompt index updated with Phase Y step table
- [ ] Every prompt references exact file paths (post-C1 reorganization paths)
- [ ] Every prompt includes the full regeneration pipeline as of that step
- [ ] Every prompt includes C++ split anti-patterns at the point of risk
- [ ] Every handoff includes the chain-inspection requirement
- [ ] No prompt references archived or deleted files
- [ ] Provision.sh pre-step (v7.6.6.0) prompt accounts for the pipeline automation scope

---

## Quality Standard

The prompt package must match or exceed the quality of the Phase X prompt package. Key quality markers:

- **Imperative, not advisory.** "Read file X" not "You may want to read file X"
- **Inline anti-patterns at point of risk.** Don't list all anti-patterns at the top — place each one next to the instruction it guards
- **Explicit post-merge demands.** The agent must produce the consolidated audit before the session closes, not as an afterthought
- **Chain-inspection requirement.** Each step's closure includes verifying the next step's handoff is still accurate
- **Step-specific review checklists.** Each review prompt targets that step's exact failure modes, not a generic checklist
- **Self-contained escalation.** The bug prompt must work without any prior conversation context
