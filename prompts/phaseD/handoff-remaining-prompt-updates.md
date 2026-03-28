# Handoff: Phase D Prompt Updates v7.6.0.2–v7.6.0.5

_Date: 2026-03-27_
_Context: v7.6.0.0-CL and v7.6.0.1-CL have been updated. The remaining four CL prompts need the same mechanical fixes plus step-specific content imports._

---

## Decision Record

**The CL prompts are the canonical execution set for Phase D.** Not the base prompts, not the updated prompts.

The comparison report (`phaseD-prompt-comparison-report.md`) recommended base prompts as canonical with selective CL imports. That recommendation is reversed after analysis. The reasoning:

1. **The updated prompts are outlines** (150–163 lines) that tell an agent *what* to do without specifying *how*. Phase 6's primary lesson (Rule 29 / LESSON-OPS-084) was that underspecified prompts cause implementation bugs — agents faithfully implement what prompts don't tell them by guessing.

2. **The CL prompts are implementation instructions** (450–690 lines) with complete code blocks, data flow traces, pointer ownership analysis, buffer safety warnings, and line-number-specific audit tables. This is the level of specificity that prevents the class of bugs Phase 6 experienced.

3. **The CL prompts' structural non-conformance is trivially fixable** (section names, rule count references). The updated prompts' missing implementation content is not.

4. **The report's evaluation axes favored form over function.** "Conformance to required section names/order" and "references 35 critical rules" are 5-minute fixes. Complete NVS function implementations, loop audit tables, and thread safety analysis are not.

---

## Mechanical Fixes (apply to all four prompts)

These are identical to what was done for v7.6.0.0-CL and v7.6.0.1-CL:

### Fix 1: Critical Rules count
Find: `All 28 Critical Rules` or `28 Critical Rules`
Replace: `All 35 Critical Rules`

Also find: `Critical Rules 1–28` or `Rules 1–28`
Replace: `Critical Rules 1–35` or `Rules 1–35`

### Fix 2: Add rules 29–35 to Critical Rules table
After the last row in the Critical Rules table (typically Rule 28), add:

```
| 29 | Prompt code = production code | Code blocks in this prompt reviewed; copy faithfully but report issues |
| 30 | Mock endpoints mirror all firmware branches | <context-specific note> |
| 31 | Fixture composition changes need downstream text audit | <if adding fixtures this step> |
| 32 | Playwright signatures only destructure used fixtures | <if adding tests this step> |
| 33 | Stub functions return documented safe default | Any new platform stubs return `0.0` |
```

For rules 34 (LC_ALL=C) and 35 (Python context managers): add only if the step involves shell or Python code.

### Fix 3: Phase 6 lesson references
In the Required Reading section, after existing LESSON-OPS entries, add:

```
   - **LESSON-OPS-081** — mock endpoints must mirror all firmware validation branches
   - **LESSON-OPS-082** — fixture composition changes require downstream text audit
   - **LESSON-OPS-083** — Playwright test signatures must only destructure used fixtures
   - **LESSON-OPS-084** — prompt-provided code must be reviewed as production code
```

### Fix 4: PSRAM satellite-only
Search for any reference to "no PSRAM → MAX_SATELLITES=2" or "non-PSRAM boards get MAX_SATELLITES 2."
Replace with: "non-PSRAM boards are satellite-only (AGGREGATOR_ENABLED 0 since v7.5.7.0)"

### Fix 5: Revision date
Update the date line to include revision note:
```
_Date: 2026-03-27 (revised 2026-03-27 — critical rules 29–35, Phase 6 lessons, PSRAM satellite-only context)_
```

---

## Per-Step Content Notes

### v7.6.0.2-CL (DELETE /api/aggregator/satellite/{id})

**Check:** Does the CL prompt already specify `save_satellites_to_nvs_()` full rewrite after compaction? The base/updated prompt explicitly says "full rewrite after compaction." If CL doesn't have this, add it — after a delete+compact operation, the NVS keys are positional (`s0_`, `s1_`, ...) and must be entirely rewritten. `save_single_satellite_to_nvs_()` is NOT appropriate after a delete.

**Check:** The pointer-aliasing warning for compaction. CL should already have this (the comparison report flagged it as "CL better"). Verify that the compaction code uses `set_identity()` to copy fields rather than raw `memcpy` of the struct, because `memcpy` would copy the `const char*` pointers which would still point to the source slot's buffers — a use-after-move bug.

**Contract-lock:** Add the validation branch table for the mock in v7.6.0.5:

| Condition | HTTP Status | Response |
|-----------|-------------|----------|
| Valid ID, satellite found | 200 | `{"ok":true,"removed":"<id>","satellite_count":<n>}` |
| Missing or empty ID | 400 | `{"ok":false,"message":"Missing satellite ID","status":400}` |
| ID not found | 404 | `{"ok":false,"message":"Unknown satellite: <id>","status":404}` |
| Wrong HTTP method | 405 | `{"ok":false,"message":"Method not allowed","status":405}` |

### v7.6.0.3-CL (POST /api/aggregator/test-satellite)

**Check:** Does CL specify reusing `probe_satellite_manifest_()` from v7.6.0.1? It should — the whole point of factoring that out was reuse.

**Check:** The "no side effects" contract — test-satellite must NOT add the satellite, must NOT write NVS, must NOT modify `satellite_caches[]`. This should be explicitly stated.

**Check:** Response shape — the success response should return the probed manifest data (id, name, sensor_count, hardware) so the dashboard can show a preview before the user commits to adding.

**Contract-lock:**

| Condition | HTTP Status | Response |
|-----------|-------------|----------|
| Valid URL, probe succeeds | 200 | `{"ok":true,"gateway":{"id":"...","name":"...","sensor_count":N,"hardware":"..."}}` |
| Missing `url` parameter | 400 | `{"ok":false,"message":"Missing url parameter","status":400}` |
| URL format invalid | 400 | `{"ok":false,"message":"URL must start with http://","status":400}` |
| Probe failed | 400 | `{"ok":false,"message":"Satellite unreachable or invalid manifest","status":400}` |
| Wrong HTTP method | 405 | `{"ok":false,"message":"Method not allowed","status":405}` |

### v7.6.0.4-CL (Dashboard add/remove/test UI)

**This is the highest-risk prompt in Phase D.** Dashboard JS changes trigger LESSON-OPS-043 (mirror to HTML) and the Phase 6 escaping lessons.

**Critical additions:**

1. **`escHtml()` on ALL user-provided or manifest-derived strings** inserted into HTML (satellite names, URLs, IDs). This is Rule 29 territory — Phase 6.2 had exactly this class of bug (BUG-073).

2. **`isFinite()` guard** on any numeric value before conversion to CSS (if rendering progress bars, health indicators, etc.). Phase 6.2 had this too (Gap 16).

3. **Dark/light mode styling** — `color-scheme` CSS property for any native widgets (Rule 16 / LESSON-OPS-065). Phase 4 had this bug with the date picker.

4. **Event delegation, not per-element handlers** — if the satellite list is dynamically updated, event listeners attached to individual list items will break when the list is re-rendered. Use event delegation on a parent container.

5. **Confirmation dialog before delete** — destructive operations need user confirmation. The prompt should specify this.

6. **LESSON-OPS-043 mirror** — every `dashboard.js` change must be mirrored to `dashboard.html`. The prompt must list this explicitly and include it in the review checklist.

### v7.6.0.5-CL (Playwright + Phase D closure)

**This step needs the most Phase 6 lesson integration:**

1. **`system` fixture set in CI matrix** — Phase 6 added this. The CI matrix for v7.6.0.5 must include all four variant-specific test runs (3sensor, mixed, aggregator, system) plus sensor-count smoke tests.

2. **Contract-lock tables for ALL three management endpoints** (add, delete, test). Each needs:
   - Firmware function name to mirror
   - All validation branches
   - Exact response shapes
   - One test per branch
   - Explicit stub prohibition

3. **Group number derivation** — derive from reading `dashboard.spec.js`, not from hardcoding in the prompt. Phase 6 lesson showed this works well.

4. **Skip guards** — tests that depend on the aggregator fixture must skip gracefully on non-aggregator fixture sets. Use the existing skip guard pattern from Group 19/20.

5. **Stateful mock** — the add/delete endpoints modify satellite state. The mock must track state across requests within a test. The CL prompt should specify whether to use a stateful mock (recommended) or reset state between tests.

6. **Phase D closure documentation** — the prompt should require updating `Docs/phase-d-implementation-plan.md` to mark Phase D complete, plus a closure section in the changelog.

---

## Execution Order

1. Apply mechanical fixes (Fix 1–5) to all four CL files
2. Review each CL file against the per-step content notes above
3. Import any missing content from the corresponding base/updated prompt (only if the CL version is genuinely missing something the base has)
4. Package as zip with all six corrected CL files renamed without the `-CL` suffix (they become the canonical prompts)

---

## File Naming Decision

After updating, the CL files should be renamed to become the canonical prompts. Recommended approach:

```bash
# In prompts/phaseD/:
# Keep originals for reference (they're already committed)
# The corrected CL versions become the execution set
# Option A: rename CL to replace base
cp v7.6.0.0-implementation-instructions-for-coding-agent-CL.md v7.6.0.0-implementation-instructions-for-coding-agent.md
# Option B: keep all three and document which to use
# (messier, but preserves history)
```

Recommendation: Option A is cleaner. The prompt-index-and-workflow.md already has file paths — they should point to the canonical names without `-CL` suffix.

---

_End of handoff document._
