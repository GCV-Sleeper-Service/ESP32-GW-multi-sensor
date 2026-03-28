# Addendum to `Docs/writing-prompts-for-coding-agents-guide.md`
_Date: 2026-03-26_  
_Context: Phase 6 prompt-audit synthesis_

## Purpose

The existing guide is already strong. Phase 6 did **not** prove it wrong.  
What Phase 6 proved is that the guide now needs a second layer of refinements for three recurring problem types:

1. **prompt-authored code defects**
2. **under-specified mocks**
3. **downstream cleanup after fixture/state changes**

This addendum identifies what should be added to the guide, where it should be added, and why.

---

## Executive summary

## What changed in Phase 6 compared with the earlier prompt lessons

Earlier prompt lessons were mostly about:

- missing data-path links
- stale counts
- fixture isolation
- neighboring-code anti-patterns
- shared-array and endpoint audit traps

Phase 6 kept all of those relevant, but added four newer, sharper lessons:

### A. Prompt code blocks themselves are now a primary defect source

In Phase 6, several PR defects were not agent inventions. They were copied directly from the prompt’s own code blocks.

That means the guide now needs a stronger rule:

> If a prompt contains code, that code must be reviewed and linted like production code before the prompt is considered ready.

### B. Mock endpoints need explicit contract-locking

Phase 6.4 showed that a “mostly right” mock is not enough.  
If the real firmware validates device, metric, and value, the mock must validate device, metric, and value too.

The guide currently talks about tests and fixtures well, but it does not yet make **mock-contract parity** a first-class requirement.

### C. Fixture changes require downstream text cleanup

Phase 6.4 showed that changing a fixture’s composition is not complete until the test comments and skip-reason strings that describe that fixture are also updated.

The guide needs a named rule for this.

### D. Script prompts need shell/Python quality gates, not just scope control

Phase 6.3 surfaced a set of script-specific prompt quality needs:

- `LC_ALL=C` for locale-sensitive parsing
- sanitizing command-derived values before URL interpolation
- using `with` context managers for Python network calls
- top-level imports
- unsupported-platform functions returning the documented safe default

The existing guide hints at code quality, but these should now be explicit checklist items.

---

## Recommended additions to the guide

## 1. Add a new section: “Mock Contract Fidelity”

### Recommended location
Add after the current testing/test-group guidance section.

### Why it should be added
Phase 6.4 showed that the test layer can still be dangerously shallow if the mock is underspecified.  
The prompt asked for a mock of `/api/ingest`, but it initially described only:

- happy path
- unknown device

That left out:

- unknown metric
- missing `val`
- invalid `val`
- exact error response shape

This created avoidable review churn and weakened the closure quality until fixed.

### Recommended guide text

## Mock Contract Fidelity

When a prompt asks the agent to mock an existing firmware endpoint, the prompt must include a **contract-lock section**.

That section must:

1. name the real firmware function or handler the mock must mirror
2. enumerate all positive and negative validation branches
3. specify exact success and failure response shapes
4. require at least one test per branch
5. explicitly prohibit stub-level mocking

**Bad**
- “Add a mock ingest route that returns 200 for valid devices.”

**Good**
- “Read `handle_api_ingest_()` first. Mirror device validation, metric validation, and `val` validation. Success must return `{"ok":true}`. Failure branches must return `{"ok":false,"message":"...","status":N}` with the correct HTTP status.”

### Why this matters
A stub-level mock makes the test suite look green while removing the very contract checks the test layer is supposed to defend.

---

## 2. Extend the pre-flight checklist with a “new entity data lifecycle” check

### Recommended location
Add to the pre-flight checklist section.

### Why it should be added
Phase 6.1 repeated the same class of bug previously seen elsewhere: the new entity had input and output paths, but the prompt did not force the author/agent to verify the middle transfer/flush mechanism.

That means the checklist needs a more explicit lifecycle trace.

### Recommended guide text

### Check: New entity data lifecycle (mandatory for any new adapter/category/device type)

For every new entity added by the prompt, trace all of these:

- input path
- accumulation/buffer state
- periodic flush/transfer trigger
- final storage target
- API exposure
- fixture generation
- mock server behavior
- Playwright assertions
- validation ceilings / hard limits

If any one of those links is not explicitly named in the prompt, the prompt is incomplete.

### Why this matters
“Producer + consumer” is not enough. The prompt must also name the mechanism that moves data from one to the other.

---

## 3. Add a stronger rule: prompt code blocks are production code

### Recommended location
Add to the section on anatomy / code examples / prompt quality gates.

### Why it should be added
Phase 6.2 and 6.3 showed that prompt-supplied code can directly propagate bugs into PRs:

- inconsistent null guards
- missing `escHtml()`
- missing `isFinite()`
- wrong placeholder return values
- imports inside functions
- missing context managers
- locale-sensitive shell parsing

### Recommended guide text

## Prompt-provided code is production code

If a prompt contains copy-ready code, that code must be reviewed with the same discipline as repository code.

Minimum expectation before the prompt is considered ready:

- Python code linted for import placement and obvious resource-handling issues
- shell code checked for locale dependence and unsafe interpolation
- JS code checked for escaping and numeric guard correctness
- docstrings/comments checked against actual implementation behavior

Do not assume the agent will “improve” the prompt’s code. In practice, agents often reproduce it faithfully.

### Why this matters
A prompt with buggy code is an upstream bug source, not just an imperfect instruction.

---

## 4. Add shell-script quality gates

### Recommended location
Add to the code-block quality section and the pre-flight checklist.

### Why it should be added
Phase 6.3 surfaced three recurring shell-prompt hazards:

- locale-sensitive parsing
- unsafe URL interpolation
- misleading logging around suppressed failures

### Recommended guide text

### Shell-script quality gates

For any shell script included in a prompt:

- use `LC_ALL=C` for commands whose output varies by locale (`top`, `df`, `free`, `date`, `ps`)
- sanitize command-derived numeric values before placing them into URLs or API calls
- keep the full script inside one unbroken code fence
- make log text match the true behavior (“Attempted push” if failures are suppressed, not “Pushed”)

### Why this matters
Scripts that work on the prompt author’s machine can fail quietly on different locales or command variants.

---

## 5. Add Python network-resource cleanup guidance

### Recommended location
Add to the code-block quality section.

### Why it should be added
Phase 6.3 showed that long-running exporters can leak descriptors if prompt code omits context-manager cleanup.

### Recommended guide text

### Python network/resource cleanup

Any prompt-provided Python code that opens network resources, subprocesses, or files in a loop or interval mode must use deterministic cleanup patterns.

Examples:
- `with urllib.request.urlopen(...) as resp:`
- `with open(...) as f:`
- explicit subprocess result handling

Do not rely on garbage collection for long-running modes.

### Why this matters
A script that is fine in one-shot mode can fail over time in interval mode.

---

## 6. Add a “safe default” rule for unsupported-platform stubs

### Recommended location
Add to the script/code example section.

### Why it should be added
Phase 6.3 had a clear example where an unsupported-platform placeholder returned a non-zero value that produced misleading dashboard output.

### Recommended guide text

### Unsupported-platform stubs must return the documented safe default

When a prompt includes placeholder or unsupported-platform code paths, those paths must return the same safe default the documentation claims they return.

In this project, that often means `0.0`, not a non-zero demo value.

### Why this matters
A placeholder that “looks realistic” is often worse than a neutral fallback because it silently creates false operational signals.

---

## 7. Add a new guardrail for fixture composition changes

### Recommended location
Extend the existing test-group / fixture guidance.

### Why it should be added
Phase 6.4 showed that changing fixture composition without updating skip reasons and group comments leaves stale explanations that make the suite harder to trust.

### Recommended guide text

### After fixture composition changes, update downstream text

If a prompt changes the sensor/device count or composition of a fixture:

- search all `test.skip()` reason strings for references to the old composition
- update any group header comments or fixture descriptions that embed the old count
- verify no stale comments survive in neighboring groups

A fixture update is not complete until both the data and the explanatory text agree.

### Why this matters
Stale reasons/comments make future audits slower and can hide whether a skip is architectural, temporary, or simply outdated.

---

## 8. Add a Playwright fixture-signature hygiene rule

### Recommended location
Extend the test-group guardrails section.

### Why it should be added
Phase 6.4 generated a minor but real review comment because a pure API test destructured `page` and `request` while only using `request`.

This is small, but it is exactly the kind of repeated cleanup that the guide should prevent.

### Recommended guide text

### Test signatures must only destructure used Playwright fixtures

Before finalizing a prompt that adds Playwright tests, include a verification step:

- remove `page` if the test only uses `request`
- remove `request` if the test only uses `page`
- do not create a browser context unless the test actually needs one

### Why this matters
It keeps tests cleaner and avoids unnecessary setup cost.

---

## 9. Expand the guide’s discussion of “copying a pattern” to include latent-bug propagation

### Recommended location
Extend the section on helper assumptions / neighboring anti-patterns.

### Why it should be added
Phase 6.2 showed that the prompt author copied a guard pattern from an existing function, but the reference pattern itself was flawed. The prompt then propagated that flaw.

### Recommended guide text

### Latent-bug propagation from reference patterns

When a prompt says “follow the pattern of X” or copies code from an existing helper, the prompt author must audit X for latent bugs before using it as a template.

Do not assume a nearby function is correct merely because it already exists.

Examples of patterns that must be audited before reuse:
- truthy checks on timestamps or numeric values
- HTML concatenation with unescaped config-derived strings
- numeric-to-CSS conversion without `isFinite()`
- shell parsing that assumes one locale or one tool output variant

### Why this matters
Prompts can reproduce old bugs into new subsystems if the reference pattern is treated as authoritative.

---

## 10. Add a new anti-pattern: under-specifying generator branch points and validation ceilings

### Recommended location
Extend the anti-pattern section.

### Why it should be added
Phase 6.1 showed that prompts can be strong structurally but still miss the exact branch points and hard limits that actually gate the implementation.

### Recommended guide text

### Anti-pattern: Extend validated/generated data without naming the real branch points and ceilings

Bad:
- “Add a new adapter following the ping pattern.”

Good:
- Name the exact generator functions that dispatch on adapter/category.
- Name what the current fallthrough/default behavior does.
- Name the hard limit that must be raised (`MAX_*`, array ceiling, etc.).

### Why this matters
The agent may discover some of these by inspection, but the highest-risk failures happen at exactly these hidden boundaries.

---

## 11. Add a workflow-maintenance note for status-document synchronization

### Recommended location
Extend the prompt-maintenance section.

### Why it should be added
At the end of Phase 6, the architecture plan and changelog correctly showed completion, but the workflow index still listed several Phase 6 steps as pending.

That is a workflow-level defect. The guide currently talks well about prompt updates and cascading decisions, but it does not yet explicitly call out **state-document synchronization** at phase boundaries.

### Recommended guide text

### Phase-boundary state synchronization

When a phase or major step closes, update all operator-facing state documents together:

- workflow index
- phase/architecture status section
- changelog closure entry
- any prompt index or handoff page used as a human control surface

Do not leave one of these behind as “pending” once the others show complete.

### Why this matters
Operators use these documents to decide what to run next. A stale workflow index creates execution risk even when the codebase is correct.

---

## Recommended insertion map

| Suggested addition | Best insertion point |
|---|---|
| Mock Contract Fidelity | New subsection near testing/test-group guidance |
| New entity data lifecycle check | Pre-flight checklist |
| Prompt code is production code | Anatomy / code-example quality section |
| Shell-script quality gates | Code-block quality + checklist |
| Python resource cleanup | Code-block quality section |
| Safe default for unsupported platforms | Script/code example guidance |
| Fixture composition downstream text audit | Test-group / fixture guidance |
| Playwright signature hygiene | Test-group guardrails |
| Latent-bug propagation from reference patterns | Gap / anti-pattern section |
| Generator branch-points and validation ceilings | Anti-pattern section |
| Phase-boundary state synchronization | Prompt maintenance section |

---

## Condensed rationale

If the guide only absorbs one short version of the Phase 6 lessons, it should be this:

> The next maturity step for prompt writing in this repo is to stop treating prompts as “descriptions of work” and start treating them as upstream engineering artifacts. In Phase 6, defects came not only from missing instructions, but from prompt-authored code, under-specified mocks, stale downstream text after fixture changes, and unsynchronized operator workflow docs. The guide should be updated to defend against those exact failure modes.

---

## Final recommendation

Update `Docs/writing-prompts-for-coding-agents-guide.md` before substantial Phase D prompt authoring starts.

That update does not need to rewrite the guide.  
It needs a targeted Phase 6 addendum that strengthens:

- contract-faithful mocking
- code-block review discipline
- script-specific quality gates
- fixture-composition cleanup rules
- status-document synchronization

Those are the changes most likely to reduce Phase D review churn.

---

_End of document._
