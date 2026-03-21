# Writing Effective Prompts for Coding Agents — A Practitioner's Guide

_Based on real prompt failures and revisions from the ESP32-GW Multi-Sensor Gateway project_
_Date: 2026-03-21 (revised post-Phase-4 review)_
_Audience: Anyone creating implementation prompts for AI coding agents (Claude, Copilot, Cursor, etc.)_

---

## Table of Contents

1. [Why This Document Exists](#1-why-this-document-exists)
2. [The Core Problem](#2-the-core-problem)
3. [Anatomy of a Good Coding Agent Prompt](#3-anatomy-of-a-good-coding-agent-prompt)
4. [The Gap Categories](#4-the-gap-categories)
5. [Case Study: v7.5.4.2 — Network Card Renderer](#5-case-study-v7542--network-card-renderer)
6. [Case Study: v7.5.4.1 — ICMP Ping Adapter](#6-case-study-v7541--icmp-ping-adapter)
7. [Case Study: v7.5.4.3 — Mixed-Category Test Fixtures](#7-case-study-v7543--mixed-category-test-fixtures)
8. [Case Study: Phase 5 Prompts — Building From Scratch](#8-case-study-phase-5-prompts--building-from-scratch)
9. [The Pre-Flight Checklist for Prompt Authors](#9-the-pre-flight-checklist-for-prompt-authors)
10. [Common Anti-Patterns](#10-common-anti-patterns)
11. [Prompt Maintenance as the Codebase Evolves](#11-prompt-maintenance-as-the-codebase-evolves)
12. [Quick Reference Card](#12-quick-reference-card)
13. [Lessons Learned from Phase 4 Implementation Analysis](#13-lessons-learned-from-phase-4-implementation-analysis)

---

## 1. Why This Document Exists

During Phase 4 (v7.5.4.x) and Phase 5 (v7.5.5.x) of the ESP32-GW Multi-Sensor Gateway project, implementation prompts were written to guide AI coding agents through each development step. These prompts went through three iterations:

1. **Original prompts** — high-level scope and acceptance criteria, written from the implementation plan
2. **First expanded prompts** — added more context, code examples, and explicit file lists
3. **Revised prompts** — fixed after a comprehensive code audit revealed critical gaps that would have caused silent failures

The gap between the second and third iteration is where the most instructive lessons live. The expanded prompts *looked* comprehensive — they had required reading lists, code examples, do-not lists, review checklists, and device testing sections. But they missed things that could only be caught by reading the actual implementation code line by line and tracing the data flow end to end.

This document captures those lessons as a reusable methodology.

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

### 3.10 Device Testing (for Human)
Step-by-step verification the human performs after merge. Includes expected outputs for each command. Any deviation from expected output is a signal.

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

---

## 4. The Gap Categories

After auditing the original and first-expanded prompts against the actual codebase, every gap fell into one of ten categories:

### Gap 1: Assumed Data Path That Doesn't Exist

The prompt says "update `handleState()` to handle network device updates" but doesn't realize that `handleState()` matches against ESPHome text_sensor entity IDs that the ping device doesn't publish. The data simply never arrives through that path.

**How to catch it:** Trace the full data flow from the source (where does the data originate?) to the destination (where does it appear on screen?). If any link in the chain is broken or nonexistent, the prompt must provide the alternative path.

### Gap 2: Helper Function Has Hidden Assumptions

The prompt says "include network devices in SENSORS" but doesn't realize that `makeSensorConfig()` generates ThermoPro-specific entity IDs like `text_sensor-{id}_temperature`. Calling this function for a ping device produces IDs that map to nothing.

**How to catch it:** For every function the agent will call or modify, read its implementation and ask: "What assumptions does this function make about its input?" If the new use case violates any assumption, the prompt must specify an alternative.

### Gap 3: Missing Periodic Trigger

The prompt describes a data producer (the ping adapter calls `add_sample()`) and a data consumer (the HistoryBuffer) but doesn't realize that a third component — the interval averaging lambda — is what actually moves data from the accumulator to the buffer. Without explicitly calling `compute_averages()` for the ping device, the buffer stays empty.

**How to catch it:** For any system with accumulation and periodic flushing, trace the flush trigger. Ask: "What code calls the function that transfers accumulated data to its final destination? Does that code know about the new entity?"

### Gap 4: Variable/Function Named Differently Than Expected

The prompt references `window._sse` for EventSource cleanup, but the actual variable is named `evtSource`. The prompt's suggested code would silently do nothing.

**How to catch it:** Before including any code that references a global variable or function, search the codebase for the exact name. Do not assume naming conventions — verify them.

### Gap 5: Schema/Naming Divergence Between Documentation and Code

The architecture plan uses `"devices"` as the manifest array key; the implementation uses `"sensors"`. The architecture plan defines `MetricDef.key` as `"temp_c"` and `"humidity_pct"`; the implementation uses `"temp"` and `"hum"`. Prompts that quote the architecture plan verbatim will mismatch the code.

**How to catch it:** Cross-reference every identifier mentioned in the prompt against the actual generated code and runtime JSON. The source of truth is the code, not the plan.

### Gap 6: Conditional Compilation Path Not Specified

The prompt says "add aggregator code" but doesn't specify whether it's conditionally compiled, how the condition propagates through the build system, or what the satellite firmware sees. An agent might add aggregator code unconditionally, breaking the satellite build.

**How to catch it:** For any feature that exists in one mode but not another, specify the exact mechanism (preprocessor guards, runtime detection, build-time generation) and verify that the "off" path compiles and behaves identically to before.

### Gap 7: Test Infrastructure Assumptions

The prompt says "update tests for new card count" but doesn't realize that the test helper `waitForDashboardReady()` asserts that card count equals sensor count, which changes when network devices are added to SENSORS. The existing tests may fail not because the code is wrong but because the test infrastructure has a cascading assertion.

**How to catch it:** When the scope changes a data structure that tests depend on (like the SENSORS array), trace all test assertions that reference that structure. List them explicitly in the prompt.

There is a second, equally dangerous form of this gap: **adding a new fixture variant without auditing existing tests for compatibility with that variant.** When a step introduces a new `FIXTURE_SET` value (e.g., `mixed`, `aggregator`), every existing test that runs under that variant must be checked. Tests that assert fixture-specific counts, device names, or card structures will fail or pass vacuously unless they are either made variant-aware or explicitly skipped.

Every prompt that introduces a new `FIXTURE_SET` variant **must** include:

```bash
FIXTURE_SET=<new_variant> npx playwright test   # full suite, no --grep
```

Any test that fails needs a skip guard:
```javascript
test.skip(process.env.FIXTURE_SET === 'new_variant',
    'Reason: this test asserts a 3sensor-specific count of 3; not applicable to new_variant');
```

The reason string must explain the specific incompatibility — not just "n/a." This ensures future readers can distinguish architectural skips (always correct to skip) from technical debt (should eventually be made variant-aware). Failure to run this audit reproduces BUG-051.

### Gap 8: Stale Factual State — Prompt Embeds a Count or Label That Has Changed

The prompt hardcodes a sequential count or label that was correct when the prompt was written but had changed by the time the agent ran it. Example: "As of v7.5.4.2, groups 1–16 exist. Your new tests go in Group 17" — when another step had already added Group 17, making the correct group number 18.

This is particularly dangerous because the prompt is not wrong about the codebase in general — it is wrong about one specific current-state fact. The agent often cannot tell whether the hardcoded value is a constraint (must be this number) or a description (was this number when I wrote this). If the agent reads the source file and disagrees with the prompt, it faces an unresolvable conflict.

**How to catch it:** Never hardcode a value that is derived by counting existing artifacts (test groups, version tags, sensor counts, port numbers). Instead, instruct the agent to read the source of truth and derive the value:

**Bad:** `"Your new tests go in Group 17"`

**Good:** `"Determine the current last group number by reading dashboard.spec.js and finding the highest numbered test.describe() heading. Your new group is N+1."`

For any hardcoded number in a prompt, ask: "Will this number still be correct if someone adds to the codebase between now and when this prompt is used?"

### Gap 9: Pattern Imitation from Neighboring Code Overrides the Specification

The agent performs local pattern-matching rather than spec adherence. It sees that `Group 13` uses `{ timeout: 30000 }` and applies that pattern to the new group, even though the prompt specifies `{ expectedSensorCount: 3 }`. It sees that Groups 9, 13, 14, and 15 use dynamic manifest reads and applies that pattern to count assertions, even though the prompt specifies hardcoded integers.

This is a known and predictable weakness of LLM coding agents: they are strong at style and pattern consistency. When the instruction says "do X" and the neighbouring code consistently does "do Y," the agent tends to drift toward Y — especially when Y appears more "defensive" or "generalised" (as dynamic counts do vs hardcoded ones, or as timeout-based readiness guards do vs count-based ones).

**How to catch it:** Before writing the specification for any new code, look at the code immediately surrounding the insertion point. Ask: "Is there a pattern here that looks like it solves the same problem as my instruction, but actually doesn't?" If yes, the prompt must name that pattern explicitly, explain why it does not apply here, and state the correct alternative. The correct behaviour alone is not sufficient — the wrong behaviour must also be named and prohibited.

### Gap 10: Missing "Why" Allows the Agent to Prefer a Plausible Alternative

The instruction specifies `{ expectedSensorCount: 3 }` but does not explain why it differs from `{ timeout: 30000 }`. The agent sees two options that appear to solve the same problem (making the test wait for the dashboard to be ready) and selects the one that matches an existing group. Without understanding the semantic difference between the two options, the agent cannot evaluate which is correct for the new context.

**How to catch it:** For any instruction where the agent might encounter a plausible-looking alternative in the codebase, add an inline rationale that explains the functional difference. The rationale anchors the agent's choice against the alternative.

**Bad:** `"Use { expectedSensorCount: 3 }"`

**Good:** `"Use { expectedSensorCount: 3 } — NOT { timeout: 30000 }. The expectedSensorCount option causes waitForDashboardReady() to gate on exactly 3 cards being rendered, which is the correct readiness signal for this fixture. The timeout pattern is BUG-049-specific to Firefox SSE teardown and must not be copied to new groups."`

The rationale does not need to be long. It needs to close the door on the alternative the agent will most plausibly reach for.

### Gap 11: Expanding a Shared Array Without Auditing All Index-Based Consumers

The prompt says "include network devices in SENSORS" (correct for the card rendering pipeline) but doesn't audit every place in the codebase that uses the SENSORS array index as a positional key into another data structure. Chart datasets are created with `SENSORS.map()` and accessed with `datasets[idx]` — when SENSORS grows from 3 to 4 entries, the 4th dataset slot is created for a network device that has no business being on a temperature chart.

This is particularly insidious because the feature *appears* to work: the network device shows up on the dashboard card grid (correct), the environmental cards render correctly (correct), but the temperature and humidity charts silently include a flat line at ~5°C (actually ping latency in ms) and ~100% humidity (actually success rate).

**How to catch it:** When a prompt expands a shared collection (SENSORS, devices[], etc.), search the entire codebase for every place that iterates over that collection with index-based access. For each consumer, ask: "Does this consumer make assumptions about what kind of entity occupies each index?" If the consumer is category-specific (temperature charts only make sense for environmental sensors), the prompt must specify how to filter or skip non-applicable entries.

**Concrete example from BUG-056:**

The v7.5.4.2 prompt correctly expanded SENSORS to include all categories. But it did not audit:
- `mkDS()` — creates one chart dataset per SENSORS entry → network device gets a dataset slot on temp/hum charts
- `applyHistoryRange()` — writes history data to `datasets[idx]` → ping history written to temp chart
- `handleState()` — pushes real-time data to `datasets[idx]` → would push ping data to temp chart if SSE carried it
- `loadHistory()` — fetches history for every SENSORS entry → fetches `/history/wan_ping/temp` which the firmware incorrectly serves

The fix required a `chartIdx` mapping: environmental sensors get sequential indices (0, 1, 2), non-environmental get -1, and all chart code uses `s.chartIdx` instead of the raw SENSORS array index.

### Gap 12: Adding a New Entity Category Without Auditing Existing Endpoints

The prompt adds a new device category (network/ping) and focuses on the new code paths (adapter, card renderer, tests) but does not audit existing endpoints for category assumptions. Endpoints written before the category system existed silently output incorrect data for the new category.

**How to catch it:** When a prompt introduces a new device category or changes the device list composition, include an explicit "Endpoint Audit Checklist" that names every existing endpoint and its expected behavior for the new category:

```
### Endpoint Audit Checklist (MANDATORY when adding a device category)

For each endpoint below, verify the response is correct for the new device category:

| Endpoint | Expected behavior for new category |
|---|---|
| `/sensors.json` | v1 projection: MUST include only environmental devices |
| `/api/status` | per-device fields must be category-appropriate |
| `/api/v2/live` | verify non-environmental devices have correct metric keys |
| `/history/{id}/temp` and `/history/{id}/hum` | MUST return 404 for non-environmental devices |
| `/api/storage-stats` | counts must reference environmental persistence only |
```

Without this checklist, the agent has no instruction to modify endpoints it wasn't told to touch. Coding agents will not proactively audit code outside their stated scope.

**Concrete example from BUG-052 and BUG-053:**

Phase 4 prompts focused on: manifest entry → generator → adapter → card renderer → tests. None mentioned `/sensors.json` or `/api/status`. Result:
- `/sensors.json` returned `wan_ping` in the v1 projection (violating the architecture plan's backward compatibility contract)
- `/api/status` output `temp_valid: false, hum_valid: false` for the ping device (semantically meaningless)

### Gap 13: Build Pipeline Intermediate Artifacts Going Stale on Version Bumps

The build pipeline has a chain: `dashboard.html` → `dashboard.min.html` → `dashboard.h`. The version bump script updates `dashboard.html` but does not re-derive `dashboard.min.html`. Since `generate-header.sh` auto-selects `.min.html` when it exists, the generated header embeds the old version. Preflight catches this — but only after the developer has already run the full bump sequence and is confused by the failure.

**How to catch it:** For any build pipeline with intermediate artifacts, trace the full derivation chain. Ask: "If the source changes (version bump, code edit), does every intermediate artifact get re-derived before the final output is produced?" If any step is manual or conditional, the prompt must either automate it or document the manual step explicitly.

This gap applies beyond version bumps — any time a prompt instructs the agent to modify a source file that has generated intermediates, the prompt must include the regeneration commands for the full chain.

---

## 5. Case Study: v7.5.4.2 — Network Card Renderer

This step had the highest density of critical gaps. It is the best teaching example.

### 5.1 What the original prompt said

The original v7.5.4.2 prompt (85 lines) gave this guidance for the state update path:

> **4. Update `handleState()` / state update flow** to recognize non-environmental polling state updates for the network device. The existing SSE/polling flow may need adjustment to handle the ping device's state updates.

That is the entire instruction. Two sentences. The phrase "may need adjustment" is doing enormous work.

### 5.2 What the first expanded prompt said

The expanded version (297 lines) added more detail:

> **4d. Update state handling**
>
> Update `handleState()` or the state update flow to recognize non-environmental polling state updates for the network device. The existing SSE/polling flow carries state events with entity IDs — the ping device's metrics (`ping_ms`, `success_pct`) need DOM update handlers similar to how ThermoPro temp/hum updates work.
>
> Specifically:
> - When a state event arrives for a ping metric, find the DOM element by id and update its text
> - Handle the `last_seen` field for staleness indication

This is more specific, but it contains a fundamental false assumption: "When a state event arrives for a ping metric." State events for ping metrics *never arrive* through the SSE/polling path. Here is why.

### 5.3 What the code actually does

The ESPHome SSE event stream carries state updates for entities defined in the YAML configuration. For ThermoPro, the YAML defines text_sensors like `raw_temp_office`, `avg_temp_office`, `battery_office`, etc. Each of these publishes state changes via SSE:

```
event: state
data: {"id": "text_sensor-office_temperature", "state": "23.4 °C / 74.1 °F"}
```

The `handleState()` function in `dashboard.js` iterates over `SENSORS` and matches `d.id` against ThermoPro-specific entity IDs:

```javascript
SENSORS.forEach(function(s, idx) {
    if (eid === s.tempId) { /* update temp DOM */ }
    if (eid === s.humId) { /* update humidity DOM */ }
    if (eid === s.battId) { /* update battery DOM */ }
    if (eid === s.rssiId) { /* update RSSI DOM */ }
    // ... etc
});
```

The `tempId` values are generated by `makeSensorConfig()`:

```javascript
function makeSensorConfig(meta, idx) {
  return {
    tempId: 'text_sensor-' + id + '_temperature',
    humId: 'text_sensor-' + id + '_humidity',
    // ...
  };
}
```

The ping adapter is a FreeRTOS task that calls `devices[3].add_sample(0, avg_rtt)`. It does NOT publish ESPHome text_sensor entities. It does NOT generate SSE events. There is no YAML text_sensor for `wan_ping_latency`. The SSE stream simply never carries ping data.

The actual data path for the ping device is:

```
PingAdapter → add_sample() → MetricState accumulator → (on 15-min cycle) compute_averages() → HistoryBuffer
                          ↘ MetricState.current_value (updated immediately)
                              ↘ /api/v2/live endpoint reads current_value → JSON response
```

The dashboard can only get ping data by polling `/api/v2/live`. Not SSE. Not REST entity polling.

### 5.4 What the revised prompt says

The revised prompt (Section 5e) explicitly describes the correct data path:

> **5e. ⚠️ CRITICAL: Network device data path — `/api/v2/live` polling**
>
> The ping device data does NOT come through ESPHome SSE state events. The `handleState()` function processes SSE events by matching ThermoPro entity IDs (`s.tempId`, `s.humId`, etc.). The ping device has no such entities.
>
> Instead, the network card gets live data from the `/api/v2/live` endpoint. You need to add a periodic polling function that:
> 1. Fetches `/api/v2/live` on the same interval as the existing polling cycle
> 2. Extracts network device values from the response
> 3. Updates network card DOM elements

It then provides concrete implementation code for `updateNetworkCards()` and `pollV2Live()` with an in-flight guard.

### 5.5 What would have happened without the fix

The coding agent would have:

1. Added `CARD_RENDERERS.network` and `buildNetworkCard()` — renders the card HTML correctly
2. Modified `handleState()` to look for entity IDs like `text_sensor-wan_ping_latency` — entity that doesn't exist
3. Run Playwright tests — they would pass because the mock server doesn't simulate SSE state events for individual metrics
4. The PR would be merged
5. On the real device, the network card would show "—" (the waiting placeholder) permanently
6. The card HTML exists, the CSS renders, the chart infrastructure might even work for history — but the live values never update because the data path is fundamentally wrong
7. You would only discover this during device testing, and debugging it would require tracing the entire SSE event flow to understand why ping events never arrive

This is the canonical example of **Gap 1: Assumed Data Path That Doesn't Exist**.

### 5.6 The second critical gap in the same prompt

The expanded prompt also said:

> **4f. Handle network devices in SENSORS filtering**
>
> Option (A) is cleaner and matches the architecture plan. If you go this route, ensure:
> - `makeSensorConfig()` handles network devices gracefully (doesn't try to build ThermoPro-specific IDs)

"Handles gracefully" is not an instruction. It is a hope. The function generates IDs like `text_sensor-{id}_temperature` — what does "gracefully" mean for a ping device? Generate `text_sensor-wan_ping_temperature`? That's an entity that doesn't exist. Return `null` for those fields? Then `handleState()` will never match anything.

The revised prompt provides a concrete solution: create `makeNetworkSensorConfig()` that returns a config object with `category: 'network'` and no ThermoPro entity IDs. The `applySensorMeta()` function dispatches between `makeSensorConfig()` (for environmental) and `makeNetworkSensorConfig()` (for network) based on category.

This is **Gap 2: Helper Function Has Hidden Assumptions**.

---

## 6. Case Study: v7.5.4.1 — ICMP Ping Adapter

### 6.1 The missing `compute_averages()` call

The original and first-expanded prompts both describe:
- The ping adapter calling `add_sample()` to record each ping result
- The HistoryBuffer accumulating 15-minute averages
- The `/api/v2/history/wan_ping/ping_ms` endpoint serving history data

What neither prompt mentions: the mechanism that *transfers data from the accumulator to the HistoryBuffer*.

In the firmware, `add_sample()` updates the MetricState accumulator:

```cpp
void add_sample(uint8_t metric_index, float value) {
    auto& st = metric_states[metric_index];
    st.current_value = value;
    st.accumulator += value;
    st.sample_count++;
}
```

The accumulator is a running sum. Every 15 minutes, a separate function — `compute_averages()` or `compute_and_format()` — divides the sum by the count, writes the average to the HistoryBuffer, and resets the accumulator:

```cpp
void compute_averages(uint32_t epoch) {
    for (uint8_t i = 0; i < metric_count; i++) {
        auto& st = metric_states[i];
        if (st.sample_count > 0 && st.history != nullptr) {
            float avg = st.accumulator / st.sample_count;
            st.history->add(epoch, avg);
        }
        st.accumulator = 0;
        st.sample_count = 0;
    }
}
```

This function is called from the YAML `interval:` lambda, which is generated by `render_sensor_config.py`. The generator's `render_yaml_averaging()` function produces averaging code — but only for ThermoPro devices:

```python
def render_yaml_averaging(sensors: List[Dict[str, str]]) -> str:
    lines = [YAML_AVG_BEGIN]
    for idx, sensor in enumerate(sensors):
        lines.extend(avg_lines(sensor, idx))  # avg_lines calls compute_and_format()
    # ... only ThermoPro sensors passed in
```

The ping device is never passed to this function. Its `compute_averages()` is never called. The accumulator grows forever but never flushes to the HistoryBuffer. The history endpoint returns empty data. Indefinitely.

### 6.2 Why neither prompt caught it

Both prompt authors understood the architecture plan's description: "the adapter calls `add_sample()`, the history buffer records 15-minute averages." This is correct at the conceptual level. But neither author traced the actual code path that triggers the averaging. They assumed that `add_sample()` → HistoryBuffer was automatic. It is not. There is a manual trigger in between.

### 6.3 The fix

The revised prompt adds Section 5c ("⚠️ CRITICAL: Add `compute_averages()` call for ping device in YAML interval lambda") with concrete guidance on modifying `render_yaml_averaging()` to include non-ThermoPro devices and the exact code change needed.

This is **Gap 3: Missing Periodic Trigger**.

---

## 7. Case Study: v7.5.4.3 — Mixed-Category Test Fixtures

This is the richest example of Gaps 8, 9, and 10 operating together in a single PR. It produced the most remediation work of any step in Phase 4.

### 7.1 What the prompt said (and what was wrong about it)

The v7.5.4.3 prompt specified three things that each caused a distinct failure:

1. **"As of v7.5.4.2, groups 1–16 exist. Your new tests go in Group 17."**
   — Group 17 had already been created by the v7.5.4.2 step. The agent correctly read `dashboard.spec.js`, found the actual last group, and used Group 18. This was not an agent error — it was a **stale factual count in the prompt** (Gap 8). The agent's result was correct. The prompt was wrong.

2. **"All `loadDashboard()` calls must use `{ expectedSensorCount: 3 }`"**
   — The agent used `{ timeout: 30000 }` instead. The reason: Group 13 in the existing test file uses this pattern for Firefox SSE teardown, and the agent pattern-matched on the neighbouring code rather than following the explicit instruction. The prompt specified the correct behaviour but **did not name and prohibit the wrong behaviour visible in Group 13** (Gaps 9 and 10). The agent's result was wrong. The prompt was incomplete.

3. **"Assertions must use hardcoded integer literals"**
   — The agent used `window._manifest.sensors.length` instead of `3`. The reason: this appeared to be a more "fixture-agnostic" and "defensive" implementation. The prompt specified hardcoded integers but **did not explain why dynamic reads are dangerous** (Gap 10). Without the vacuous-pass explanation, the agent optimised for what appeared to be the more robust option. The agent's result was wrong. The prompt was incomplete.

### 7.2 The vacuous-pass failure mode explained

A dynamic count assertion like:
```javascript
await expect(cards).toHaveCount(window._manifest.sensors.length)
```

passes when `window._manifest.sensors.length` is 0 and there are 0 cards rendered. If the manifest is broken and returns no sensors, the test reports green while the entire feature is non-functional. This is a **false pass** — the test proves nothing while appearing to verify something.

A hardcoded assertion:
```javascript
await expect(cards).toHaveCount(3)
```

fails loudly if 0 cards are rendered. That is the correct behaviour for a test that is meant to verify the feature works with a specific fixture.

Tests in a fixture-specific group are *intentionally* encoding the fixture's exact shape. Making them "fixture-agnostic" defeats their purpose and eliminates their signal value.

### 7.3 What the revised prompt needed to say

For issue 2, the revised prompt needed to explicitly close the door on Group 13's pattern:

> All `loadDashboard()` calls in this group use:
> ```javascript
> await loadDashboard(page, { expectedSensorCount: 3 })
> ```
> DO NOT use `{ timeout: 30000 }`. That pattern appears in Group 13 only, for a Firefox SSE teardown issue (BUG-049). It is not a general readiness pattern and must not be copied. If you see `{ timeout: 30000 }` in Group 13, treat it as an anomaly with a known reason, not as a template.

For issue 3, the revised prompt needed to name the vacuous-pass risk:

> Count assertions must use hardcoded integer literals:
> ```javascript
> await expect(cards).toHaveCount(3)   // ✅
> await expect(cards).toHaveCount(window._manifest.sensors.length)   // ❌
> ```
> Dynamic reads are prohibited because they pass vacuously when the manifest is broken. A dynamic `toHaveCount(0)` passes silently when the manifest returns 0 sensors — the test reports green while the feature is completely broken.

### 7.4 What would have prevented all three issues

A single **Test Group Implementation Guardrails** section (see §3.11) placed at the top of the test-writing instructions, containing: the correct `loadDashboard()` signature, the name of the wrong alternative and why it doesn't apply, the hardcoded-integer rule with the vacuous-pass warning, and the group-number derivation instruction. This section was absent from the v7.5.4.3 prompt entirely.

---

## 8. Case Study: Phase 5 Prompts — Building From Scratch

The Phase 5 (Aggregator MVP) prompts existed only as original versions — no expanded coding agent prompts. Creating them from scratch revealed a different class of problem: gaps that only emerge when you think about platform mechanics.

### 8.1 The `AGGREGATOR_ENABLED` propagation gap

The original v7.5.5.0 prompt says "add a `#define AGGREGATOR_ENABLED 1` flag." But it doesn't specify:

- Where the define lives (generated header? manual define? YAML build flag?)
- How `sensor_history_multi.h` sees it (explicit include? implicit?)
- What happens when `config/aggregator.json` is absent (compile error? silent disable?)
- Whether the header file is always generated or only when aggregator mode is active

The expanded prompt specifies: always generate `src/aggregator_config.h`, with `AGGREGATOR_ENABLED 0` when no aggregator config exists and `AGGREGATOR_ENABLED 1` with satellite arrays when it does. Include it unconditionally from `sensor_history_multi.h`. This means the `#if AGGREGATOR_ENABLED` guards always compile cleanly in both modes.

This is **Gap 6: Conditional Compilation Path Not Specified**.

### 8.2 The runtime vs compile-time mode detection gap

The v7.5.5.3 prompt (aggregator dashboard UI) must answer a fundamental question: how does the dashboard know whether it is running on a satellite or an aggregator?

Option A: Compile-time flag embedded in the dashboard HTML. This requires different dashboard builds for satellite and aggregator — breaks the single-binary approach.

Option B: Runtime API probe. The dashboard fetches `/api/aggregator/gateways`. If it gets 200, it is on an aggregator. If it gets 404, it is on a satellite. This works with the same binary.

The original prompt doesn't specify. The expanded prompt mandates Option B and provides the complete detection function, boot flow modification, and isolation guarantee (satellite mode sees zero aggregator UI elements).

### 8.3 The new-fixture existing-test audit gap

The v7.5.5.4 prompt introduces a new `aggregator` fixture variant and adds it to CI, but contains no instruction to run the full suite under `FIXTURE_SET=aggregator` to audit for existing test breakage. This is the identical structural gap that produced BUG-051 in Phase 4 (v7.5.4.3, `mixed` fixture variant) and required three remediation PRs to resolve.

Without the audit instruction, the agent will add the new CI job but will not add skip guards to the existing tests that are incompatible with the aggregator fixture. The `browser-tests (aggregator)` CI job will fail on tests that assert 4-sensor counts, or `outside` device names, or other 3sensor-fixture-specific values.

The fix is the mandatory new-fixture audit step described in Gap 7.

---

## 9. The Pre-Flight Checklist for Prompt Authors

Before finalizing any coding agent prompt, walk through these checks:

### Check 1: Trace every data path end-to-end

For each feature in the scope:

- Where does the data originate? (sensor, API, timer, user input)
- How does it get transported? (SSE event, REST poll, function call, shared variable)
- What transforms it along the way? (accumulator → average, raw → formatted string)
- What triggers each transformation? (timer, interval lambda, user action)
- Where does it arrive? (DOM element, API response, NVS storage)
- Does the agent need to create or modify anything at *every* link?

If any link is assumed to "just work," verify that assumption against the code.

### Check 2: Read every function the agent will call or modify

For each function mentioned in the scope:

- What does the function signature accept?
- What assumptions does the implementation make about its arguments?
- Does it hardcode behaviour for a specific use case?
- If the agent calls it with new arguments (e.g., a network device instead of a ThermoPro device), will it produce correct output?

If the answer is "no" or "unclear," the prompt must specify an alternative or a modification.

### Check 3: Verify every variable and function name against the codebase

Do not assume naming conventions. Search the codebase for:

- The exact global variable names the prompt references
- The exact function names
- The exact DOM element IDs

A single wrong name means the code silently does nothing.

### Check 4: Cross-reference documentation identifiers against code

Check for divergence between:

- Architecture plan terminology and implementation terminology
- Schema field names in documentation vs. generated JSON
- Struct member names in documentation vs. header files

The code is the source of truth. Update the prompt to use code identifiers.

### Check 5: Trace test infrastructure dependencies

When the scope changes a data structure that tests rely on:

- Which test helpers reference it?
- Which assertions will break?
- What needs to be updated in the test infrastructure (not just the tests)?

List these explicitly.

Additionally: are there patterns in code **neighbouring** the agent's implementation target that look similar to what the agent is being asked to write, but behave differently? If yes, the prompt must name those patterns explicitly and explain why they do not apply. Pay particular attention to:
- Timeout-based readiness guards vs. count-based readiness guards
- Dynamic vs. hardcoded assertion values
- Error-suppressing patterns that look defensive but actually hide failures (vacuous passes)

### Check 6: Verify conditional paths compile in all modes

For any feature with multiple modes (satellite/aggregator, enabled/disabled):

- Does the "off" path compile without errors?
- Does the "off" path behave identically to the previous version?
- Is the switching mechanism explicit (preprocessor, runtime probe, build flag)?

### Check 7: Search for periodic triggers and flush mechanisms

For any system with accumulation and deferred processing:

- What triggers the flush/transfer/send?
- Does the trigger code know about the new entity?
- If the trigger only runs for a specific category of entities, does the prompt specify extending it?

### Check 8: Validate new sequential artifacts against current state

Before hardcoding any value that depends on "how many X currently exist," read the source file directly. Do not rely on what the previous prompt said would be there.

Applies to:
- Test group numbers (count groups in the spec file — do not hardcode "next is N")
- Version numbers (read the VERSION file)
- Sensor/device counts used in test assertions (read the fixture, not the plan)
- "Currently N tests passing" claims in Current Status sections

For each such value in the prompt:
1. Read the source of truth in the codebase
2. Record the current value
3. In the prompt, instruct the agent to derive the value from the same source of truth rather than treating the prompt's value as authoritative

**Exception:** values that the prompt itself is *defining* (e.g., "the new version will be 7.5.4.3") are not stale-state facts — they are instructions. These are fine to hardcode.

### Check 9: Verify the CI-exact pre-condition block covers every fixture matrix cell

If the repo has a fixture-set CI matrix, every cell must have a corresponding command in the pre-condition block. A bare `npx playwright test` is never sufficient as the sole pre-condition.

### Check 10: If a new fixture variant is introduced, require the full-suite cross-variant audit

If the step adds a new `FIXTURE_SET` value to CI, the prompt **must** include the instruction:

```bash
FIXTURE_SET=<new_variant> npx playwright test   # full suite, no --grep
```

Any test that fails gets a skip guard with a reason string explaining the specific incompatibility. This step must be completed before the PR is opened — not as a follow-up.

---

## 10. Common Anti-Patterns

### Anti-Pattern 1: "Handle gracefully"

**Example:** "ensure `makeSensorConfig()` handles network devices gracefully"

**Problem:** "Gracefully" is subjective. The agent might interpret it as "return null for missing fields," "throw an error," "skip the device," or "generate placeholder IDs." Each interpretation produces different behaviour, and most are wrong.

**Fix:** Specify the exact expected behaviour. "Create a `makeNetworkSensorConfig()` function that returns `{ id, name, color, category: 'network', restPaths: [] }` — no ThermoPro entity IDs."

### Anti-Pattern 2: "May need adjustment"

**Example:** "The existing SSE/polling flow may need adjustment to handle the ping device's state updates."

**Problem:** "May need" signals uncertainty from the prompt author. The agent inherits that uncertainty and must guess. Guesses are often wrong because the agent lacks the domain context to evaluate alternatives.

**Fix:** Either specify the exact adjustment, or explicitly state that the existing path does NOT work for the new use case and provide the alternative path.

### Anti-Pattern 3: Listing files to read without explaining what to look for

**Example:** "`dashboard/dashboard.js` — understand `CARD_RENDERERS`, `handleState()`, `buildDeviceCards()`"

**Problem:** The agent will read the functions but may not identify the hidden assumptions (ThermoPro-shaped IDs, environmental-only filtering, SSE-specific data paths). Reading code is not the same as understanding its constraints.

**Fix:** Add parenthetical warnings: "`handleState()` — THERMOPRO-ONLY: matches against s.tempId, s.humId, etc. No path exists for network device metric updates."

### Anti-Pattern 4: Offering architectural decisions without resolving them

**Example:** "You need to decide whether to (A) include network devices in SENSORS or (B) keep SENSORS environmental-only."

**Problem:** The agent must make an architectural decision it isn't qualified to make. It lacks context about downstream test impacts, future phase dependencies, and the human's preferences.

**Fix:** Make the decision in the prompt. "Use Option A: Include network devices in SENSORS. This requires the following specific changes: ..."

### Anti-Pattern 5: Bundling unrelated concerns into one step

**Example:** v7.5.4.1 originally bundled "implement ICMP ping adapter" with "fix Firefox Playwright regressions from PR #51."

**Problem:** Two independent failure modes in one PR. If the Firefox fix breaks something, it blocks the adapter. Debugging becomes harder because changes are interleaved.

**Fix:** If the concerns are truly independent, separate them. If they must be bundled (e.g., due to test infrastructure dependencies), clearly separate them within the prompt with their own sections, checklists, and verification steps.

### Anti-Pattern 6: Trusting the architecture plan over the implementation

**Example:** The architecture plan says the v2 manifest uses `"devices"` as the array key. The implementation uses `"sensors"`. A prompt that quotes the plan's terminology will confuse the agent.

**Problem:** Architecture plans are aspirational. Code is actual. When they diverge, the code wins.

**Fix:** Always verify plan terminology against implementation before writing prompts. Note divergences explicitly: "The architecture plan uses 'devices' but the implementation uses 'sensors' for backward compatibility."

### Anti-Pattern 7: Scope Creep by Omission — Next Step's Work Pre-Empted Without Its Structural Requirement

**Example:** The v7.5.4.2 prompt scoped test fixture work for a future step (v7.5.4.3). The agent, noticing that fixtures were broken for the new network device, pre-emptively fixed `generate-fixtures.js` in v7.5.4.2. The fix was well-intentioned but it seeded BUG-051 because the agent fixed the fixture generation without also implementing the CI isolation that the v7.5.4.3 prompt was going to require. The fix was half-complete.

**Problem:** The agent's partial forward implementation satisfied the obvious gap but missed the structural requirement that accompanied it. The result required multiple remediation PRs to stabilise.

**Fix:** The "Do NOT" section must explicitly prohibit next-step work by naming the files involved:

**Bad:** "Do not implement CI changes in this step."

**Good:** "Do NOT modify `tests/fixtures/generate-fixtures.js` or the fixture variant directories — that is v7.5.4.3's scope. If you notice fixture gaps, document them in a comment in the PR body but do not implement them."

The explicit file names are the key. The agent cannot argue that modifying `generate-fixtures.js` was within scope when the prompt names it as explicitly prohibited.

### Anti-Pattern 8: The Right Behaviour Is Stated But the Wrong Behaviour Is Not Prohibited

**Example:** The v7.5.4.3 prompt said "All `loadDashboard()` calls must use `{ expectedSensorCount: 3 }`." The agent used `{ timeout: 30000 }` instead — the pattern it saw in the neighbouring Group 13 code for Firefox SSE teardown.

**Problem:** The prompt told the agent what to do. It did not tell the agent what NOT to do. When nearby code showed a different pattern that appeared to solve the same problem, the agent chose the nearby pattern over the prompt's instruction. This is a predictable agent behaviour: pattern-matching on code context frequently overrides textual instructions unless the instruction explicitly addresses the wrong pattern the agent is looking at.

**Fix:** When a correct behaviour is specified AND there is a plausible incorrect behaviour visible in nearby code, the prompt must add a negative prohibition that names the incorrect pattern and explains precisely why it is wrong in this context:

**Bad:** `"All loadDashboard() calls must use { expectedSensorCount: 3 }"`

**Good:** `"All loadDashboard() calls must use { expectedSensorCount: 3 }. DO NOT use { timeout: 30000 } — that is the BUG-049 Firefox SSE teardown workaround, visible in Group 13 only. It does not validate that the dashboard has finished loading; it only prevents a Playwright timeout. Using it here would allow the test to proceed before cards are rendered, producing intermittent false passes."`

The format: state the correct behaviour → name the incorrect behaviour the agent might reach for → explain precisely why the incorrect behaviour is wrong.

Additionally, for count assertions specifically: when prohibiting dynamic reads, always state the **vacuous-pass failure mode**. Without it, the agent will choose dynamic reads as the apparently more robust option. With it, the agent understands that the "robust" option is actually the dangerous one.

---

## 11. Prompt Maintenance as the Codebase Evolves

### Prompts are living documents

A prompt written for step N assumes the codebase state after step N−1. If step N−1 changes the API, renames a function, or restructures the test infrastructure, the prompt for step N becomes stale.

**Rule:** After completing each step, audit the prompts for subsequent steps. Check whether any assumption has been invalidated by the work just completed.

### Track decisions that cascade

When a step makes an architectural decision (e.g., "include network devices in SENSORS"), every subsequent prompt that references SENSORS must be updated. Maintain a "cascading decisions" log:

| Step | Decision | Prompts Affected |
|------|----------|-----------------|
| v7.5.4.2 | SENSORS includes all categories | v7.5.4.3 (fixture card counts), v7.5.4.4 (test audit), v7.5.5.3 (aggregator dashboard) |
| v7.5.4.2 | Network data from /api/v2/live polling | v7.5.4.3 (mock server), v7.5.5.3 (aggregator live polling) |

### Post-step audits

After each step merges, run a structured audit:

1. **Did any function signatures change?** If yes, update prompts that reference those functions.
2. **Did any test helpers change?** If yes, update prompts that describe test patterns.
3. **Did the data model change?** If yes, update prompts that reference struct fields, array sizes, or JSON shapes.
4. **Were any new bugs discovered?** If yes, add the lesson to the prompt template's critical rules section.
5. **Was a new fixture variant introduced?** If yes, immediately run `FIXTURE_SET=<new_variant> npx playwright test` (full suite) and record which existing tests require skip guards. Add those skip guards and the reason strings before the PR merges — not as a follow-up. If this step is deferred, it becomes BUG-051.
6. **Did any prompt hardcode a count or sequential number that this step changed?** If yes, update the subsequent prompts to instruct the agent to derive that value from the source of truth rather than using the now-stale hardcoded value.

This is what LESSON-OPS-057 ("specified tests must be tracked to implementation completion") generalises: every specified artifact must be tracked to delivery, and every delivery must be checked for cascade effects.

---

## 12. Quick Reference Card

### Before Writing a Prompt

1. Read the implementation code, not just the architecture plan
2. Trace every data path from source to destination
3. Read every function the agent will call — look for hidden assumptions
4. Verify every variable name against the codebase
5. Identify all periodic triggers and flush mechanisms
6. Check conditional compilation paths in all modes
7. Verify all sequential counts (test groups, versions, sensor counts) against the actual source files
8. Look at the code surrounding the agent's insertion point — identify any neighbouring patterns that look similar to the target behaviour but aren't

### While Writing a Prompt

9. Use exact function/variable names from the code
10. Specify concrete behaviour, not "handle gracefully"
11. Make architectural decisions — don't delegate to the agent
12. Separate unrelated concerns into distinct sections
13. Add parenthetical warnings to required reading items
14. Provide code examples for non-obvious changes
15. For every correct behaviour specified: name the wrong alternative the agent might reach for, and explain why it doesn't apply here
16. For every count assertion: include the vacuous-pass prohibition and explain why dynamic reads are dangerous, not robust
17. Use CI-exact commands in pre-condition blocks — never bare `npx playwright test`
18. If the step adds new test groups: include a Test Group Implementation Guardrails section (§3.11)
19. If the step adds a new fixture variant: include the full-suite cross-variant audit instruction

### After Writing a Prompt

20. Walk through the prompt as if you were the agent — can you implement it without guessing?
21. Run the pre-flight checklist (Section 9) against the prompt
22. Check for cascading effects on subsequent step prompts

### After Each Step Completes

23. Audit subsequent prompts for invalidated assumptions
24. Update cascading decisions log
25. Add new lessons to the critical rules section
26. If a new fixture variant was introduced: run full-suite audit immediately, add skip guards before next step begins
27. If any sequential count changed: update downstream prompts to derive rather than hardcode

---

## 13. Lessons Learned from Phase 4 Implementation Analysis

This section documents specific case studies from the Phase 4 post-implementation review (2026-03-21), including findings from four independent third-party analyses. Each case study shows: what the original prompt said, what happened as a result, where the gap was, and how the prompt needed to be written to get the right outcome.

### 13.1 Case Study: PR #57 — The Three-Way Test Failure

**Context:** v7.5.4.3 required adding mixed-category Playwright tests (Group 18) for a new `mixed` fixture variant (2 environmental + 1 network = 3 total sensors).

**What the prompt said:**
- "All `loadDashboard()` calls use `{ expectedSensorCount: 3 }`"
- "As of v7.5.4.2, groups 1–16 exist. Your new tests go in Group 17."
- Count assertions should use the known fixture values (3 total, 2 environmental)

**What the agent produced:**
1. Used `{ timeout: 30000 }` instead of `{ expectedSensorCount: 3 }` — copied from Group 13
2. Used `window._manifest.sensors.length` instead of hardcoded `3` — "more robust"
3. Used Group 18 (correct in practice — Group 17 already existed from v7.5.4.2)

**Root cause analysis (from four independent reviews):**

| Issue | Root cause | Prompt or Agent? |
|---|---|---|
| `{ timeout: 30000 }` substitution | Agent pattern-matched Group 13's BUG-049 workaround | Agent compliance failure, but prompt lacked explicit prohibition |
| Dynamic count assertions | Agent preferred "defensive" coding over fixture-specific testing | Partial prompt gap — no vacuous-pass warning |
| Group number mismatch | Prompt stated "groups 1–16" but Group 17 existed | Prompt defect — stale count |
| No CI matrix update | Prompt treated CI as read-only context | Prompt gap — no instruction to modify `browser-tests.yml` |
| No existing-test audit for `mixed` fixture | Prompt required CI-exact commands but not full-suite audit under new variant | Prompt gap |

**What the prompt needed to say:**

```markdown
### Test Group Implementation Guardrails

All loadDashboard() calls in this group use:
    await loadDashboard(page, { expectedSensorCount: 3 })

DO NOT use { timeout: 30000 }. That pattern appears in Group 13 for Firefox SSE 
teardown (BUG-049) and must not be copied. It does not validate that cards have 
rendered — it only prevents a Playwright timeout.

All count assertions must use hardcoded integer literals:
    await expect(cards).toHaveCount(3)   ✅
    await expect(cards).toHaveCount(window._manifest.sensors.length)   ❌

Dynamic reads pass vacuously when the manifest is broken. If the manifest returns 
0 sensors, toHaveCount(0) passes — the test reports green while the feature is 
completely broken.

Determine the current last group number by reading dashboard.spec.js. Your new 
group is N+1. Do not rely on this prompt's description of how many groups exist.

### CI Integration (MANDATORY)

You MUST add 'mixed' to the fixture_set matrix in .github/workflows/browser-tests.yml.
You MUST add skip guards to Group N tests: test.beforeEach skip when FIXTURE_SET !== 'mixed'.
After creating the mixed fixture, run: FIXTURE_SET=mixed npx playwright test (full suite).
Any existing test that fails needs: test.skip(process.env.FIXTURE_SET === 'mixed', '<reason>').
```

**Impact of the gap:** Three remediation PRs (#58, #59, #60) were needed after the initial implementation. The Phase 4 timeline extended by ~2 days of corrective work.

---

### 13.2 Case Study: BUG-056 — WAN Latency on Temperature Charts

**Context:** v7.5.4.2 correctly expanded SENSORS to include all device categories. But temperature and humidity charts used the SENSORS array index as the chart dataset index.

**What the prompt said:**
- "Include network devices in SENSORS" ✅
- "Chart rendering excluded for network device (no chart canvas in network card)" ✅
- No mention of existing environmental charts that iterate over SENSORS

**What happened:**
A five-link failure chain:
1. `mkDS()` created 4 chart datasets (one per SENSORS entry) — `wan_ping` got dataset index 3
2. `loadHistory()` fetched history for all SENSORS including `wan_ping`
3. `fetchDeviceHistory()` fallback fetched `/history/wan_ping/temp` (wrong data path)
4. Firmware's legacy handler returned ping latency data as if it were temperature
5. `applyHistoryRange()` plotted the data on the temperature chart

**Why the prompt missed it:**
The prompt correctly prohibited adding chart canvases to network cards. But it did not consider that the *existing* temperature/humidity charts already iterate over ALL of SENSORS. The prompt's mental model was "network card = new code" but the bug was in "environmental chart = old code now broken by new data."

**What the prompt needed to say:**

```markdown
### ⚠️ CRITICAL: Expanding SENSORS affects ALL index-based consumers

SENSORS now includes network devices. The following existing code iterates SENSORS 
with index-based dataset access and MUST be updated:

- mkDS() — creates chart datasets for ALL SENSORS entries. Network devices must be 
  EXCLUDED from temperature/humidity chart datasets.
- applyHistoryRange() — writes history data to datasets[idx]. Must skip non-environmental.
- handleState() — pushes real-time data to datasets[idx]. Must guard with category check.
- loadHistory() — fetches history for every SENSORS entry. Must skip non-environmental.

Solution: Add a chartIdx property to each sensor config:
- Environmental sensors: chartIdx = 0, 1, 2, ... (sequential)
- Non-environmental: chartIdx = -1
All chart code uses s.chartIdx instead of the SENSORS array index.
```

---

### 13.3 Case Study: BUG-052/053 — Existing Endpoints Returning Wrong Data

**Context:** Phase 4 added `wan_ping` as the 4th device. Existing endpoints (`/sensors.json`, `/api/status`) were written when all devices were environmental.

**What the prompt said:**
- "Keep `/sensors.json` as a v1 compatibility shim" (architecture plan)
- No instruction to modify `/sensors.json` handler or `/api/status` handler

**What happened:**
- `/sensors.json` returned 4 entries including `wan_ping` (should be environmental-only per architecture plan Section 5.3)
- `/api/status` output `temp_valid: false, hum_valid: false` for `wan_ping` (semantically meaningless)

**Why the prompt missed it:**
The Phase 4 prompts focused entirely on new code paths (adapter, card renderer, tests). None included an "endpoint audit" step. The coding agent had no instruction to touch these handlers and correctly stayed within scope — but scope was incomplete.

**What the prompt needed:**
An "Endpoint Audit Checklist" section (see Gap 12 above) naming every existing endpoint and its expected behavior for the new device category.

---

### 13.4 Case Study: BUG-055 — Stale Build Intermediate

**Context:** `bump-version.sh` updates `dashboard.html` but not `dashboard.min.html`. `generate-header.sh` auto-selects `.min.html` when it exists.

**What happened:** Version bump completed successfully, but preflight failed because `dashboard.h` contained the old version from the stale `.min.html`.

**Why it wasn't in any prompt:** This is a build tooling gap, not a feature implementation gap. No Phase 4 prompt touched `bump-version.sh`. The gap existed from the day the minification pipeline was added.

**Lesson for prompt authors:** When auditing a prompt, trace the full build chain for every artifact the prompt modifies. If the chain has intermediate steps that are conditional or manual, verify that the version bump script handles them. If it doesn't, add the fix to the prompt scope or document it as a known prerequisite.

---

### 13.5 Summary: The Five Third-Party Reviews Agreed On

All four independent analyses (GP, GE, Codex, SO) plus the hands-on review session converged on these findings:

**Areas of unanimous agreement:**
1. Phase 4 was architecturally successful — the SensorEntity model was validated
2. PR #57 (v7.5.4.3) was the weakest step, requiring 3 remediation PRs
3. The agent's pattern-matching behavior is predictable and must be explicitly countered
4. Fixture-specific tests need a three-part contract: skip guard, CI job, full-suite audit
5. Prompts must trace data paths, not just describe features

**The single most actionable insight:**
> When an instruction says "do X" and neighboring code consistently does "do Y," the agent drifts toward Y — especially when Y appears more "defensive" or "generalized." The prompt must name Y explicitly, explain why it doesn't apply, and close the door.

**The single most dangerous recurring gap:**
> Adding a new fixture variant without auditing existing tests for compatibility with that variant. This produced BUG-051 in Phase 4 and will reproduce in any future phase that introduces a new fixture unless the full-suite audit is mandatory in the prompt.

---

## Appendix A — Comparison Table: Original vs. Expanded vs. Revised

Using v7.5.4.2 (Network Card Renderer) as the example:

| Aspect | Original (85 lines) | First Expanded (297 lines) | Revised (380 lines) |
|--------|---------------------|---------------------------|---------------------|
| Data path for network card values | "Update handleState()" | "SSE/polling flow carries state events for ping metrics" (incorrect) | "Ping data does NOT come through SSE. Use /api/v2/live polling." (correct) |
| makeSensorConfig() handling | Not mentioned | "Handles network devices gracefully" | Concrete `makeNetworkSensorConfig()` function with exact return shape |
| SENSORS filtering decision | Not mentioned | "You need to decide A or B" | "Use Option A" with explicit consequences |
| Chart rendering | "Don't add chart rendering" | "Don't add chart rendering" | "Don't add chart rendering. Also: ensure buildDeviceCards() skips chart init for network devices." |
| DOM element IDs | Not specified | `val-ping-{id}-latency` | `net-ping-{id}` (consistent pattern, no ambiguity) |
| Concrete polling implementation | Not provided | Not provided | Full `updateNetworkCards()` + `pollV2Live()` with in-flight guard |
| Test count cascade | Not mentioned | "May need to expect 4 cards" | Explicit list of which tests need card count updates |

---

### Appendix B — Gap Types Found Across All Prompts

| Gap Type | Prompt | Consequence If Missed |
|----------|--------|-----------------------|
| Missing periodic trigger | v7.5.4.1 — `compute_averages()` | Ping history empty forever |
| Assumed data path | v7.5.4.2 — SSE for ping data | Network card shows "—" permanently |
| Helper function assumptions | v7.5.4.2 — `makeSensorConfig()` | Meaningless entity IDs generated |
| Wrong variable name | v7.5.4.1 (first expanded) — `window._sse` | EventSource not closed in teardown |
| Missing schema naming check | v7.5.4.3 — group numbering | Test group number collision |
| Conditional compilation gap | v7.5.5.0 — `AGGREGATOR_ENABLED` | Satellite build breaks or aggregator code always included |
| Platform divergence | v7.5.5.1 — ESP32-S3 vs C3 | Wrong partition table, missing YAML variant |
| Mode detection mechanism | v7.5.5.3 — runtime vs compile-time | Different dashboard builds needed (breaks single-binary) |
| Multi-fixture mock server | v7.5.5.4 — aggregator fixtures | Tests can't simulate multi-satellite scenarios |
| CI-exact command missing from pre-conditions | v7.5.4.1, v7.5.4.2 — bare `npx playwright test` | Fixture isolation failures pass locally, break in CI |
| Stale group/count hardcoded in prompt | v7.5.4.3 — "groups 1–16 exist" | Agent uses wrong group number; review ambiguity about compliance |
| New fixture variant, no existing-test audit | v7.5.4.3 (`mixed`), v7.5.5.4 (`aggregator`) | BUG-051 reproduced: existing tests break under new FIXTURE_SET |
| Wrong pattern from neighbouring code, no negative prohibition | v7.5.4.3 — `{ timeout: 30000 }` vs `{ expectedSensorCount: 3 }` | Test proceeds before cards render; intermittent false passes |
| Dynamic count assertion, no vacuous-pass warning | v7.5.4.3 — `window._manifest.sensors.length` | Test passes silently when manifest is broken and returns 0 sensors |
| Next step pre-empted without its structural requirement | v7.5.4.2 — fixture generation without CI isolation | Half-complete forward implementation requires remediation PRs |
| Missing live config file (only example created) | v7.5.5.0 — `aggregator.json` not created | v7.5.5.1 pre-condition generates `AGGREGATOR_ENABLED 0`; step fails |
| Missing mutex for shared cache | v7.5.5.1 — `SatelliteCache` reads/writes | Data corruption under concurrent web handler and polling task access |
| No `window._aggregatorReady` signal | v7.5.5.3 | v7.5.5.4 test infrastructure broken; `waitForDashboardReady()` times out in aggregator mode |
| Expanding shared array without auditing index-based consumers | v7.5.4.2 — SENSORS expanded, `mkDS()`/`applyHistoryRange()` not updated | Ping latency plotted on temperature chart (BUG-056) |
| New device category without endpoint audit | v7.5.4.0–v7.5.4.4 — no audit of `/sensors.json`, `/api/status` | v1 endpoint returns non-environmental devices; status has meaningless fields (BUG-052, BUG-053) |
| Legacy endpoint serves wrong data for new category | v7.5.4.x — `/history/wan_ping/temp` returns ping HistoryBuffer | Temperature chart shows ping latency as temperature values (BUG-056 chain link 4) |
| Build pipeline intermediate artifact not re-derived | `bump-version.sh` — `dashboard.min.html` stale | `dashboard.h` embeds old version; preflight fails (BUG-055) |

---

_End of document._