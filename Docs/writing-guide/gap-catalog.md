# Writing Effective Prompts for Coding Agents — Gap Catalog

_Extracted from: Writing Effective Prompts for Coding Agents — A Practitioner's Guide_
_Based on real prompt failures and revisions from the ESP32-GW Multi-Sensor Gateway project_

---

## Table of Contents

- [Gap 1: Assumed Data Path That Doesn't Exist](#gap-1-assumed-data-path-that-doesnt-exist)
- [Gap 2: Helper Function Has Hidden Assumptions](#gap-2-helper-function-has-hidden-assumptions)
- [Gap 3: Missing Periodic Trigger](#gap-3-missing-periodic-trigger)
- [Gap 4: Variable/Function Named Differently Than Expected](#gap-4-variablefunction-named-differently-than-expected)
- [Gap 5: Schema/Naming Divergence Between Documentation and Code](#gap-5-schemanaming-divergence-between-documentation-and-code)
- [Gap 6: Conditional Compilation Path Not Specified](#gap-6-conditional-compilation-path-not-specified)
- [Gap 7: Test Infrastructure Assumptions](#gap-7-test-infrastructure-assumptions)
- [Gap 8: Stale Factual State](#gap-8-stale-factual-state--prompt-embeds-a-count-or-label-that-has-changed)
- [Gap 9: Pattern Imitation from Neighboring Code](#gap-9-pattern-imitation-from-neighboring-code-overrides-the-specification)
- [Gap 10: Missing "Why" Allows Agent to Prefer Plausible Alternative](#gap-10-missing-why-allows-the-agent-to-prefer-a-plausible-alternative)
- [Gap 11: Expanding a Shared Array Without Auditing Index-Based Consumers](#gap-11-expanding-a-shared-array-without-auditing-all-index-based-consumers)
- [Gap 12: Adding New Entity Category Without Auditing Endpoints](#gap-12-adding-a-new-entity-category-without-auditing-existing-endpoints)
- [Gap 13: Build Pipeline Intermediate Artifacts Going Stale](#gap-13-build-pipeline-intermediate-artifacts-going-stale-on-version-bumps)
- [Gap 14: Inconsistent Guard Style in Prompt Snippets](#gap-14-inconsistent-guard-style-in-prompt-snippets)
- [Gap 15: Prompt-Seeded Security Sink](#gap-15-prompt-seeded-security-sink)
- [Gap 16: Numeric-to-CSS Without Finite Guard](#gap-16-numeric-to-css-without-finite-guard)
- [Gap 17: Under-Specified Contract Mocks](#gap-17-under-specified-contract-mocks)
- [Gap 18: Fixture Composition Ripple Omissions](#gap-18-fixture-composition-ripple-omissions)

---

## The Gap Categories

After auditing the original and first-expanded prompts against the actual codebase, every gap fell into one of eighteen categories:

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

### Gap 14: Inconsistent Guard Style in Prompt Snippets

The prompt provides code with mixed value-presence checks within a single function: one line uses explicit `!== undefined && !== null`, another uses a truthy check on a field that could legitimately be `0`. The agent copies both patterns faithfully, and the truthy check silently skips valid zero values.

**How to catch it:** Before publishing a prompt with code blocks, audit all value-presence guards for consistency. The project standard for optional numeric and timestamp fields is `value !== undefined && value !== null` (never truthy). Apply this consistently within each function body.

**Concrete example from Phase 6.2 (BUG-072):** The prompt provided `if (seenEl && devData.last_seen)` — a truthy check that fails when `last_seen === 0`. Two lines above, the prompt correctly used `!== undefined && !== null` for `uptime_hrs`. The inconsistency was copied from the reference `updateNetworkCards()` function, which has the same latent bug.

### Gap 15: Prompt-Seeded Security Sink

The prompt provides HTML-building code that concatenates config-derived or manifest-derived strings directly into HTML output without escaping. On an embedded LAN device the practical risk is low, but it is inconsistent with the project's existing `escHtml()` helper and creates an XSS vector that propagates into every future copy of the pattern.

**How to catch it:** For every prompt-provided code block that builds HTML, list each text insertion point and verify it uses `escHtml()` (or the equivalent sanitizer) for any value that originates from config, manifest, or user input. The agent will not add escaping that the prompt's code omits.

### Gap 16: Numeric-to-CSS Without Finite Guard

The prompt provides code that converts a numeric value to a CSS property (e.g., `width: ${value}%`) without checking `isFinite(value)` first. If the value is `NaN` or `Infinity` — which happens when the source metric has no data yet — the resulting CSS is `width: NaN%`, which browsers ignore silently.

**How to catch it:** Any function in a prompt that maps a numeric input to a CSS or DOM geometry property must include an `isFinite()` early-return or default. This is a mechanical check: search the prompt's code blocks for string templates that embed numeric variables into style attributes.

### Gap 17: Under-Specified Contract Mocks

The prompt asks the agent to mock an existing firmware endpoint but describes only the happy path and one error case. The firmware's actual handler has three or more validation branches. The resulting mock passes tests that should fail, because the mock silently accepts requests the firmware would reject.

**How to catch it:** See §3.12 (Mock Contract Fidelity). Every mock endpoint prompt must include a contract-lock section. Before writing the contract-lock, read the firmware handler and enumerate every branch.

**Concrete example from Phase 6.4:** The prompt specified "known device → 200, unknown device → 404" for the ingest mock. The firmware also validates metric key existence and `val` parameter presence/finiteness. Two fix commits were required.

### Gap 18: Fixture Composition Ripple Omissions

The prompt changes a fixture's sensor/device count or composition but does not instruct the agent to update the skip-reason strings, group comments, and helper expectations that reference the old composition. The fixture data is correct; the explanatory text is stale.

**How to catch it:** After any fixture composition change in a prompt, include an explicit instruction: "Search all `test.skip()` reason strings for references to the old composition. Update any group header comments or fixture descriptions that embed the old count. Verify no stale comments survive in neighboring groups."

---

### Gap 19: Identity Gate Verification Skipped or Self-Waived

The prompt specifies an identity gate (SHA-256 before vs. after), but the agent either skips the verification or self-waives it with a plausible rationalization ("the version bump changed 2 bytes, so byte-identity is impossible"). The gate exists to catch unintended structural changes — the agent must not decide unilaterally that a mismatch is acceptable.

**How to catch it:** Make the identity gate a mandatory pre-PR check with explicit "STOP and report" language if it fails. Add Critical Rule 54: agents must never self-waive acceptance criteria. If a criterion is contradicted by another requirement, the agent escalates to the operator.

**Phase X example (v7.6.5.6):** The CSS extraction step specified "output-identity gate" but byte-identity was impossible due to CSS interleaving. The agent self-waived rather than reporting. This became CR 54.

### Gap 20: Contiguous-Slice Assumption Violated

The prompt plans to concatenate multiple modules into a single component but does not verify that all source modules are physically adjacent in the file. Non-contiguous modules cannot be concatenated without reordering, which breaks the identity gate.

**How to catch it:** Before any concatenation plan, verify adjacency: `grep -n` the first and last line of each candidate module and confirm no intervening modules exist. If they do, the module must remain a separate component.

**Phase X example (v7.6.5.4):** `src/13-import.js` could not be concatenated into `settings-panel` because modules 11 and 12 sat between 10 and 13. This became the 9th component (`import-panel`) and led to CR 50.

### Gap 21: Generated Artifact Pipeline Ordering Wrong

The prompt includes the regeneration pipeline but specifies steps in the wrong order. Example: running the generator before the assembler, so the generator writes into a stale file that the assembler then overwrites.

**How to catch it:** Trace the pipeline's data flow: which step produces each intermediate file, and which step consumes it? The consumer must come after the producer. Draw the dependency graph if necessary. In particular, assembly steps must precede generator steps when both write to the same target file.
