# Writing Effective Prompts for Coding Agents — Methodology

_Extracted from: Writing Effective Prompts for Coding Agents — A Practitioner's Guide_
_Based on real prompt failures and revisions from the ESP32-GW Multi-Sensor Gateway project_

---

## Table of Contents

1. [Why This Document Exists](#1-why-this-document-exists)
2. [The Core Problem](#2-the-core-problem)
3. [Anatomy of a Good Coding Agent Prompt](#3-anatomy-of-a-good-coding-agent-prompt)

---

## 1. Why This Document Exists

> **Doctrinal precedence.** Where this document and `Docs/development-process-guide.md` conflict, **the development-process-guide governs**. This document describes prompt anatomy; the development-process-guide describes execution authority and merge gates.

During Phase 4 (v7.5.4.x) and Phase 5 (v7.5.5.x) of the ESP32-GW Multi-Sensor Gateway project, implementation prompts were written to guide AI coding agents through each development step. These prompts went through three iterations:

1. **Original prompts** — high-level scope and acceptance criteria, written from the implementation plan
2. **First expanded prompts** — added more context, code examples, and explicit file lists
3. **Revised prompts** — fixed after a comprehensive code audit revealed critical gaps that would have caused silent failures

The gap between the second and third iteration is where the most instructive lessons live. The expanded prompts *looked* comprehensive — they had required reading lists, code examples, do-not lists, review checklists, and device testing sections. But they missed things that could only be caught by reading the actual implementation code line by line and tracing the data flow end to end.

Phase 6 (v7.5.6.x) added a second layer of lessons. The Phase 6 prompts were written with the Phase 4/5 lessons already incorporated, and the structural quality was good — zero scope violations, correct data flow tracing in most steps, strong CI-exact pre-conditions. The new failure mode Phase 6 exposed was **the quality of code and specifications within the instructions**: prompt-authored code blocks that contained bugs, mock specifications that omitted validation branches, and reference code patterns that carried latent defects. See `gap-catalog.md` Gaps 14-18 for these lessons.

This document captures both layers as a reusable methodology.

---

## 2. The Core Problem

A coding agent operates without institutional memory. It does not know:

- What a function actually does versus what its name implies
- Which data paths exist versus which data paths the architecture plan *says* should exist
- What assumptions are baked into helper functions written months ago
- Which variables are named differently from what documentation references
- What silent coupling exists between components that the architecture treats as independent

A prompt is the agent's entire understanding of the task. Every gap in the prompt is a potential silent failure — code that compiles, passes lint, maybe even passes some tests, but does the wrong thing at runtime.

The goal of a good prompt is not to be long. It is to be *complete at the boundaries that matter*.

There is a second dimension that is equally important and frequently overlooked: the agent is also operating without knowledge of the CI/test environment, the sequence of prior prompts, or the patterns in adjacent code that it will encounter while implementing the task. Every gap in these areas is also a potential silent failure — tests that pass locally but break in CI, or correct code that gets overwritten by pattern-matching on wrong neighboring examples.

---

## 3. Anatomy of a Good Coding Agent Prompt

A well-structured prompt has these sections, in order:

### 3.1 Repository and Setup
Clone URL. Nothing else. Keep it short.

### 3.2 Required Reading — With Specific Callouts
Not just file names — specific functions, structs, or patterns the agent must understand before touching code. Generic "read the whole file" is insufficient for large files. Call out the exact lines or functions that matter and explain *why* they matter.

**Bad:**
```
5. dashboard/dashboard.js — understand CARD_RENDERERS, handleState(), buildDeviceCards()
```

**Good:**
```
5. dashboard/dashboard.js — Read carefully and understand these specific functions:
   - makeSensorConfig(meta, idx) — builds ThermoPro-specific entity IDs
     (text_sensor-{id}_temperature, etc.). THIS FUNCTION IS THERMOPRO-SHAPED
     and will produce meaningless IDs for network devices.
   - handleState(d) — THERMOPRO-ONLY: matches against s.tempId, s.humId, etc.
     No path exists for network device metric updates.
   - normalizeManifestSensors() — currently filters to category === 'environmental'
     only (line ~589). Network devices are excluded from SENSORS.
```

The difference: the first version tells the agent what to read. The second tells the agent what traps are in the code. The agent will read the function either way — but without the callout, it may not realize that `makeSensorConfig()` generates IDs that only make sense for ThermoPro devices.

### 3.3 Current Status — Including What Was Verified
Not just "previous step merged." Include what was device-tested and confirmed working. This prevents the agent from re-solving already-solved problems or making assumptions about what the previous step did.

### 3.4 Pre-condition Checks

Two categories of pre-conditions are required in every prompt.

#### 3.4a State Validation
Concrete commands to verify the branch is clean and the test baseline passes before any changes. This catches stale branches, failing tests, or missing infrastructure that the prompt assumes is in place.

#### 3.4b CI-Exact Validation (mandatory for any step that touches tests or fixtures)

The test suite is often run differently in CI than in local development. The pre-condition block **must** include the exact commands CI runs — with the same environment variables, the same `--project` flags, and the same `--grep` patterns. A bare local test run is not sufficient.

If the repo has a fixture-set matrix, every matrix cell must be represented.

**Bad** (allows silent CI failures):
```bash
npx playwright test --project=chromium
```

**Good** (matches CI exactly):
```bash
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=3sensor npx playwright test --project=firefox
FIXTURE_SET=1sensor npx playwright test tests/browser/sensor-count.spec.js --project=chromium
FIXTURE_SET=mixed npx playwright test --project=chromium --grep "18\. Mixed"
bash scripts/preflight.sh
```

**The rule:** if running the exact CI command locally would have revealed the problem before the PR was opened, the pre-condition block must include that exact command.

### 3.5 Exact Scope — With Data Flow Tracing
This is the heart of the prompt. The scope must trace the complete data path from source to screen (or from input to output), not just describe the UI or API endpoint.

For a dashboard feature, the data flow is:
```
Data source → Transport → State handler → DOM update → User sees value
```

Every link in that chain needs explicit guidance. If one link is missing, the feature is broken even if every other link is perfect.

### 3.6 Do NOT (Explicit Scope Boundaries)
What the agent must not touch. This prevents scope creep and protects unrelated subsystems.

This section must use **named files and functions**, not just descriptions. An agent cannot argue that modifying `generate-fixtures.js` was within scope when the prompt names it explicitly as prohibited.

**Bad:** "Do not implement CI changes in this step."

**Good:** "Do NOT modify `tests/fixtures/generate-fixtures.js` or any fixture variant directory — that is v7.5.4.3's scope. If you notice fixture gaps, document them in a comment in the PR body but do not implement them."

### 3.7 Critical Rules (Non-Negotiable Constraints)
Project-wide invariants that apply to every step. These come from bugs and lessons learned. They are the institutional knowledge the agent doesn't have.

### 3.8 Documentation Updates
Which docs to update and what to write. Without this, documentation drifts from code.

### 3.9 Review Checklist
A verification list the agent runs before creating a PR. Each item should be a concrete, testable assertion — not a subjective judgment.

### 3.10 Device Testing — Agent-Performed by Default; Operator Items Listed Separately

> See `Docs/development-process-guide.md` §2.3 for the canonical workflow. This methodology section is the **prompt-anatomy** view; the dev-process-guide is the **execution** view. Where these two conflict, the dev-process-guide governs (see §3.X "Doctrinal Precedence" below).

The agent performs device testing by default. The prompt must include device commands for **every board** in the current fleet. Do not omit any board; omitting a board is a silent gap identical to omitting a test case.

**Agent-performed (required in every firmware prompt):**
- Compile: `esphome compile <yaml>` — run after all code changes
- Upload: `esphome upload <yaml> --device=<ip>` — wrapped in `timeout 300`; never use `esphome run`
- Clean before AND after compile to prevent stale artifacts
- Curl smoke tests against `/api/status`, `/api/status/full`, `/api/history`, and any endpoint the step modifies
- Post curl output as PR comment

**Operator-performed (only what the agent cannot do):**
- Visual browser checks (dashboard rendering, chart layout)
- Serial-log inspection when no UART adapter is available
- Final merge approval

Every step that exercises a runtime path must include device commands covering every board in the fleet. Listing only one board while the fleet has three is the gap that issue #228 item A1/A2 found at the produced-prompt layer. The prompt author must enumerate boards explicitly — the agent cannot infer which boards exist.

### 3.11 Test Group Implementation Guardrails (required in every prompt that adds new test groups)

Any prompt that instructs the agent to write new Playwright test groups **must** contain a dedicated guardrails section. This is not optional and is not satisfied by a mention elsewhere in the prompt. Without this section, the agent will pattern-match on neighboring test code and produce tests that look correct but validate the wrong thing.

The section must contain four elements:

**Element 1 — The exact readiness helper signature, with an explicit anti-pattern callout naming the wrong pattern and why it is wrong.**

State the correct signature AND name the incorrect signature the agent is likely to reach for from nearby code, with a specific explanation of why it does not apply here.

Example:
```
All loadDashboard() calls in this group use:
    await loadDashboard(page, { expectedSensorCount: 3 })

DO NOT use { timeout: 30000 }. That pattern appears in Group 13 for Firefox SSE
teardown (BUG-049) and must not be copied to new groups. It does not validate that
cards have rendered — it only prevents a Playwright timeout. Using it here would
allow tests to proceed before cards exist, producing intermittent false passes.
```

**Element 2 — Count assertion format with the vacuous-pass warning.**

Specify hardcoded integer literals AND explicitly prohibit dynamic reads, with the reason:

```
All count assertions must use hardcoded integer literals:
    await expect(cards).toHaveCount(3)   ✅
    await expect(cards).toHaveCount(window._manifest.sensors.length)   ❌

Dynamic reads are prohibited because they pass vacuously when the manifest is
broken. If the manifest returns 0 sensors, toHaveCount(0) passes — the test
reports green while the feature is completely broken. Hardcoded integers fail
loudly in exactly that scenario, which is the correct behaviour.

The fixture contract for this group is: 3 total cards, 2 environmental, 1 network.
Assert those exact integers.
```

**Element 3 — Group number derivation instruction.**

Never hardcode the group number. Instruct the agent to derive it from the source file:

```
Determine the current last group number by reading dashboard.spec.js and finding
the highest numbered test.describe() heading (format: "N. Description").
Your new group is N+1. Do not rely on this prompt's description of how many
groups currently exist — read the file and count.
```

**Element 4 — Pre-commit verification checklist specific to the new group.**

Not the general PR checklist — a checklist the agent runs against the tests it just wrote:

```
Before committing, verify:
[ ] All loadDashboard() calls in this group use { expectedSensorCount: N }
    — not { timeout: T }, not bare loadDashboard(page)
[ ] All count assertions are integer literals — zero window._manifest reads for counts
[ ] No code was copied from Group 13 that includes timeout: 30000 or test.setTimeout(90000)
[ ] Group number is N+1 of the actual last group in the file (verified by reading the file)
[ ] If a new FIXTURE_SET variant was introduced: FIXTURE_SET=<variant> npx playwright test
    (full suite, no --grep) was run and all failures have skip guards with reason strings
```

### 3.12 Mock Contract Fidelity (required in every prompt that adds mock endpoints)

When a prompt asks the agent to create or extend a mock endpoint in the test server, the prompt must include a **contract-lock section**. Without this, mock endpoints default to stub-level implementations that hide the very bugs the test layer should detect.

A contract-lock section has five mandatory elements:

1. **Name the firmware function the mock must mirror.** The agent must read the real handler before writing the mock.
2. **Enumerate all positive and negative validation branches.** Every `if` that returns an error in the firmware must have a corresponding branch in the mock.
3. **Specify exact success and failure response shapes.** JSON key names, HTTP status codes, and error message format.
4. **Require at least one test per branch.** A mock branch without a test is invisible.
5. **Explicitly prohibit stub-level mocking.** State that "device exists → 200" is not acceptable when the firmware also validates metric keys and parameter values.

**Bad:**
```
Add a mock ingest route that returns 200 for valid devices.
```

**Good:**
```
### Contract-Lock: Mock `/api/ingest` Route

Read `handle_api_ingest_()` in `dashboard/sensor_history_multi.h` first.
Mirror all validation branches:

| Condition | HTTP Status | Response |
|---|---|---|
| Device found, metric found, val valid | 200 | `{"ok":true}` |
| Device not found | 404 | `{"ok":false,"message":"Unknown device: {id}","status":404}` |
| Metric not found for device | 404 | `{"ok":false,"message":"Unknown metric: {key}","status":404}` |
| Missing or non-finite val | 400 | `{"ok":false,"message":"Missing or invalid val","status":400}` |

Write one test per row. Do NOT reduce this mock to a "device exists → 200" stub.
```

**Why this matters:** Phase 6.4 showed that a stub-level mock made the test suite green while removing the contract checks the test layer was supposed to defend. Two fix commits were needed after the initial implementation because the prompt only specified happy-path and unknown-device branches.

### 3.13 Prompt-Provided Code Quality Gates (required when a prompt contains code blocks)

If a prompt contains copy-ready code, that code is an upstream artifact in the implementation pipeline. Agents reproduce prompt code faithfully — including bugs. The prompt author must review embedded code with the same discipline as repository code.

**Minimum quality checks before prompt publication:**

**JavaScript:**
- `escHtml()` applied to every config-derived or manifest-derived string inserted into HTML
- Null/undefined guards use explicit checks (`!== undefined && !== null`), never truthy checks on values that could legitimately be `0` or `""`
- `isFinite()` guard on any numeric value before conversion to CSS (width, percentage, etc.)
- No mixed guard styles within a single function body

**Python:**
- All imports at module top level (not inside functions), even in prompt-provided snippets
- `with` context managers for network resources (`urlopen`), file handles, and subprocesses
- Unsupported-platform stub functions return the documented safe default (`0.0`), not a non-zero placeholder
- Docstrings match actual behavior

**Shell (bash):**
- `LC_ALL=C` before any command whose output varies by locale (`top`, `df`, `free`, `date`, `ps`)
- Command-derived numeric values sanitized before URL interpolation (strip non-numeric characters)
- Log messages match true behavior ("Attempted push" if failures are suppressed, not "Pushed successfully")
- Full script in one unbroken code fence

**General:**
- When copying a pattern from existing code, audit the reference code for latent bugs first. Existing code is not automatically correct.
- Comments and docstrings must match the actual implementation behavior, not describe an idealized version.

**Why this matters:** Phase 6 showed that prompt-authored code was the primary defect source across four of five steps. The agents didn't invent bugs — they copied them from the prompt.

---

## 4. The Two-Prompt Pattern (Phase X)

Phase X proved that a single agent prompt is not enough. Every step needs two sessions:

**Session 1 — Agent execution.** The coding agent receives the implementation prompt, reads all required files, implements the change, runs the validation pipeline, and creates a PR.

**Session 2 — Review.** A separate agent (fresh context, no carry-over from Session 1) receives a review prompt targeting that step's exact failure modes. The reviewer verifies acceptance criteria, checks for scope violations, produces the consolidated audit, inspects the next step's handoff and prompt, and confirms post-merge deliverables.

This pattern catches classes of error that self-review misses: confirmation bias ("I just wrote it, so it must match the spec"), context-window pressure (long execution sessions lose early instructions), and scope drift (agents that continue into the next step unbidden).

### 4.1 Implementation Prompt Anatomy (Proven Structure)

The Phase X execution established a refined 10-section prompt structure:

1. **§1 — Imperative reading order.** Numbered, not optional. "Read file X" not "You may want to read file X." Specific callouts for trap functions and boundary conditions.
2. **§2 — Pre-implementation verification gate.** Checks the agent must pass before writing any code. Catches stale branches, wrong baselines, and failed assumptions.
3. **§3 — Scope boundary.** What IS and what IS NOT in scope. Named files and functions, not descriptions.
4. **§4 — Do-NOT list.** Explicit anti-patterns for this step, placed at the point of risk — not gathered at the top of the document.
5. **§5 — Implementation instructions.** Exact files, exact functions, exact changes. Data flow traced end-to-end.
6. **§6 — Acceptance criteria.** Checklist format. Each item is a concrete, testable assertion.
7. **§7 — Pipeline commands.** Full regeneration pipeline as of this step. No shortcuts.
8. **§8 — Verification gate.** Identity/compile/test gate specific to this step's risk profile.
9. **§9 — Post-merge deliverables.** Consolidated audit, changelog entry, session log, instruction compliance table. Demanded explicitly — not left as afterthoughts.
10. **§10 — Domain-specific anti-patterns.** Consolidated reference for patterns that must never appear.

### 4.2 Key Insight: Handoff Documents Alone Are Insufficient

A handoff document provides context — what happened before, what this step delivers, what comes next. But handoff documents do not drive agent completeness. Agents treat handoffs as background reading and skip to "what do I implement?"

Effective prompts require the following at the point of risk (not in a separate document):
- **Imperative numbered reading order** — the agent reads in the order you specify, not the order it prefers
- **Pre-implementation verification gates** — the agent proves it understands the starting state before touching code
- **Inline anti-patterns** — placed next to the instruction they guard, not gathered in a separate section
- **Explicit post-merge deliverable blocks** — demanding the consolidated audit before session close

### 4.3 Chain-Inspection Pattern

From Phase X v7.6.5.1 onward, every step's post-merge deliverables include reviewing and updating the next step's handoff and prompt. This creates a forward-inspection chain: step N's closure verifies that step N+1's assumptions are still valid given what actually happened during step N.

Without this pattern, prompts written at plan time accumulate stale references as earlier steps introduce small deviations from the plan.

### 4.4 Checkpoint Pattern (Phase Y)

Mid-implementation checkpoints (`⛔ CHECKPOINT`) and pre-PR gates (`⛔ PRE-PR GATE`) are mandatory in every implementation prompt. The checkpoint pattern was introduced during Phase Y and validated across 9 steps.

**Placement rules:**
1. Every implementation prompt must contain at least one `⛔ CHECKPOINT` between task groups and one `⛔ PRE-PR GATE` before PR creation.
2. The mid-implementation checkpoint verifies the most critical intermediate state — typically after the riskiest edit but before subsequent edits that depend on it.
3. The pre-PR gate verifies: scope (files changed match expected list), all acceptance criteria, all pipeline steps, all deliverables.

**Checkpoint template:**
```
⛔ CHECKPOINT — [description of what to verify]

Before proceeding, verify:
1. [specific verification command with expected output]
2. [second verification]

If any check fails, STOP and fix before continuing.
```

**Pre-PR gate template:**
```
⛔ PRE-PR GATE

Before creating the PR:
1. `git diff --name-only` — verify ONLY expected files are modified
2. [pipeline commands: assemble, preflight, compile, test]
3. [acceptance criteria verification commands]
4. Session log is complete with: ESPHome output, Playwright fixture table, evidence summary
```

**Evidence from Phase Y:** The v7.6.6.1 checkpoint caught a security defect (lwip_send buffer over-read) during the checkpoint pass rather than at end-of-step validation. Without the checkpoint, 6 subsequent steps would have been built on a vulnerable codebase.

**Full reference:** `Docs/writing-guide/prompt-guide-addendum-checkpoints-and-multi-llm-2026-04-09.md`

### 4.5 Multi-LLM Execution Strategy (Phase Y)

Phase Y validated a multi-LLM workflow where different agents serve different roles:

- **Primary execution:** GitHub Copilot — IDE integration, repo context, PR creation
- **Architectural advisor + prompt producer:** Claude — long-context reasoning, document production
- **Post-execution review (3-turn):** Perplexity — GitHub MCP access, structured review protocol
- **Fallback execution:** GPT, Codex — token constraints on Copilot, alternative reasoning

**Critical constraint (validated by cross-LLM analysis):** Every LLM asked to "optimise" an agent prompt strips safety constraints — the constraints it considers redundant are exactly the ones that prevent the failure modes documented in the lessons database. **Original prompts with the universal multi-LLM execution preamble are the only prompts used for execution.** LLM-specific "optimised" variants are never used.

**Reviewer diversity principle:** Multi-reviewer diversity catches more failure classes than depth on any single reviewer. Phase Y's four-reviewer pattern (Copilot bot + Gemini + GPT/Codex + Perplexity) caught different defect types — the lwip_send security defect was only caught by Gemini; a dry-run bypass was only caught by GPT. No single reviewer caught everything.

**Perplexity three-turn review structure:** Post-Copilot-execution review via GitHub MCP:
- Turn 1: Extract gate checklist from inline context
- Turn 2: Fetch PR diff and compliance table, check each gate item
- Turn 3: Produce structured verdict and fix list

The compliance table in the PR description substitutes for shell command verification when using a non-IDE reviewer.

**Full reference:** `Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md`
