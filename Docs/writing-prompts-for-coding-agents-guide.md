# Writing Effective Prompts for Coding Agents — A Practitioner's Guide

_Based on real prompt failures and revisions from the ESP32-GW Multi-Sensor Gateway project_
_Date: 2026-03-18_
_Audience: Anyone creating implementation prompts for AI coding agents (Claude, Copilot, Cursor, etc.)_

---

## Table of Contents

1. [Why This Document Exists](#1-why-this-document-exists)
2. [The Core Problem](#2-the-core-problem)
3. [Anatomy of a Good Coding Agent Prompt](#3-anatomy-of-a-good-coding-agent-prompt)
4. [The Seven Gap Categories](#4-the-seven-gap-categories)
5. [Case Study: v7.5.4.2 — Network Card Renderer](#5-case-study-v7542--network-card-renderer)
6. [Case Study: v7.5.4.1 — ICMP Ping Adapter](#6-case-study-v7541--icmp-ping-adapter)
7. [Case Study: Phase 5 Prompts — Building From Scratch](#7-case-study-phase-5-prompts--building-from-scratch)
8. [The Pre-Flight Checklist for Prompt Authors](#8-the-pre-flight-checklist-for-prompt-authors)
9. [Common Anti-Patterns](#9-common-anti-patterns)
10. [Prompt Maintenance as the Codebase Evolves](#10-prompt-maintenance-as-the-codebase-evolves)
11. [Quick Reference Card](#11-quick-reference-card)

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
Concrete commands the agent runs before changing anything. These catch stale branches, failing tests, or missing infrastructure that the prompt assumes is in place.

### 3.5 Exact Scope — With Data Flow Tracing
This is the heart of the prompt. The scope must trace the complete data path from source to screen (or from input to output), not just describe the UI or API endpoint.

For a dashboard feature, the data flow is:
```
Data source → Transport → State handler → DOM update → User sees value
```

Every link in that chain needs explicit guidance. If one link is missing, the feature is broken even if every other link is perfect.

### 3.6 Do NOT (Explicit Scope Boundaries)
What the agent must not touch. This prevents scope creep and protects unrelated subsystems.

### 3.7 Critical Rules (Non-Negotiable Constraints)
Project-wide invariants that apply to every step. These come from bugs and lessons learned. They are the institutional knowledge the agent doesn't have.

### 3.8 Documentation Updates
Which docs to update and what to write. Without this, documentation drifts from code.

### 3.9 Review Checklist
A verification list the agent runs before creating a PR. Each item should be a concrete, testable assertion — not a subjective judgment.

### 3.10 Device Testing (for Human)
Step-by-step verification the human performs after merge. Includes expected outputs for each command. Any deviation from expected output is a signal.

---

## 4. The Seven Gap Categories

After auditing the original and first-expanded prompts against the actual codebase, every gap fell into one of seven categories:

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

## 7. Case Study: Phase 5 Prompts — Building From Scratch

The Phase 5 (Aggregator MVP) prompts existed only as original versions — no expanded coding agent prompts. Creating them from scratch revealed a different class of problem: gaps that only emerge when you think about platform mechanics.

### 7.1 The `AGGREGATOR_ENABLED` propagation gap

The original v7.5.5.0 prompt says "add a `#define AGGREGATOR_ENABLED 1` flag." But it doesn't specify:

- Where the define lives (generated header? manual define? YAML build flag?)
- How `sensor_history_multi.h` sees it (explicit include? implicit?)
- What happens when `config/aggregator.json` is absent (compile error? silent disable?)
- Whether the header file is always generated or only when aggregator mode is active

The expanded prompt specifies: always generate `src/aggregator_config.h`, with `AGGREGATOR_ENABLED 0` when no aggregator config exists and `AGGREGATOR_ENABLED 1` with satellite arrays when it does. Include it unconditionally from `sensor_history_multi.h`. This means the `#if AGGREGATOR_ENABLED` guards always compile cleanly in both modes.

This is **Gap 6: Conditional Compilation Path Not Specified**.

### 7.2 The runtime vs compile-time mode detection gap

The v7.5.5.3 prompt (aggregator dashboard UI) must answer a fundamental question: how does the dashboard know whether it is running on a satellite or an aggregator?

Option A: Compile-time flag embedded in the dashboard HTML. This requires different dashboard builds for satellite and aggregator — breaks the single-binary approach.

Option B: Runtime API probe. The dashboard fetches `/api/aggregator/gateways`. If it gets 200, it is on an aggregator. If it gets 404, it is on a satellite. This works with the same binary.

The original prompt doesn't specify. The expanded prompt mandates Option B and provides the complete detection function, boot flow modification, and isolation guarantee (satellite mode sees zero aggregator UI elements).

---

## 8. The Pre-Flight Checklist for Prompt Authors

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
- Does it hardcode behavior for a specific use case?
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

---

## 9. Common Anti-Patterns

### Anti-Pattern 1: "Handle gracefully"

**Example:** "ensure `makeSensorConfig()` handles network devices gracefully"

**Problem:** "Gracefully" is subjective. The agent might interpret it as "return null for missing fields," "throw an error," "skip the device," or "generate placeholder IDs." Each interpretation produces different behavior, and most are wrong.

**Fix:** Specify the exact expected behavior. "Create a `makeNetworkSensorConfig()` function that returns `{ id, name, color, category: 'network', restPaths: [] }` — no ThermoPro entity IDs."

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

---

## 10. Prompt Maintenance as the Codebase Evolves

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

This is what LESSON-OPS-057 ("specified tests must be tracked to implementation completion") generalizes: every specified artifact must be tracked to delivery, and every delivery must be checked for cascade effects.

---

## 11. Quick Reference Card

### Before Writing a Prompt

1. Read the implementation code, not just the architecture plan
2. Trace every data path from source to destination
3. Read every function the agent will call — look for hidden assumptions
4. Verify every variable name against the codebase
5. Identify all periodic triggers and flush mechanisms
6. Check conditional compilation paths in all modes

### While Writing a Prompt

7. Use exact function/variable names from the code
8. Specify concrete behavior, not "handle gracefully"
9. Make architectural decisions — don't delegate to the agent
10. Separate unrelated concerns into distinct sections
11. Add parenthetical warnings to required reading items
12. Provide code examples for non-obvious changes

### After Writing a Prompt

13. Walk through the prompt as if you were the agent — can you implement it without guessing?
14. Run the pre-flight checklist (Section 8) against the prompt
15. Check for cascading effects on subsequent step prompts

### After Each Step Completes

16. Audit subsequent prompts for invalidated assumptions
17. Update cascading decisions log
18. Add new lessons to the critical rules section

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

### Appendix B — Gap Types Found Across All Prompts

| Gap Type | Prompt | Consequence If Missed |
|----------|--------|----------------------|
| Missing periodic trigger | v7.5.4.1 — `compute_averages()` | Ping history empty forever |
| Assumed data path | v7.5.4.2 — SSE for ping data | Network card shows "—" permanently |
| Helper function assumptions | v7.5.4.2 — `makeSensorConfig()` | Meaningless entity IDs generated |
| Wrong variable name | v7.5.4.1 (first expanded) — `window._sse` | EventSource not closed in teardown |
| Missing schema naming check | v7.5.4.3 — group numbering | Test group number collision |
| Conditional compilation gap | v7.5.5.0 — `AGGREGATOR_ENABLED` | Satellite build breaks or aggregator code always included |
| Platform divergence | v7.5.5.1 — ESP32-S3 vs C3 | Wrong partition table, missing YAML variant |
| Mode detection mechanism | v7.5.5.3 — runtime vs compile-time | Different dashboard builds needed (breaks single-binary) |
| Multi-fixture mock server | v7.5.5.4 — aggregator fixtures | Tests can't simulate multi-satellite scenarios |

---

_End of document._
