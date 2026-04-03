# Phase X — Dashboard Dashboard Refactor Draft Comparison

_Last updated: 2026-04-03_

**Scope:** Compare the two existing Phase X dashboard refactor plans, identify their strong and weak points, call out gaps each plan leaves unaddressed on its own, and capture shared assumptions that must be preserved in the reconciled plan.

**Inputs reviewed:**

- `Docs/phase-d-implementation-plan.md` — Phase D implementation and versioning pattern.[cite:1]
- `Docs/bugs-and-lessons-learned.md` — especially LESSON-OPS-043, -052, -065, -074, -099 and related BUG entries.[cite:2]
- `Docs/approach-towards-modular-architecture-PR.md` — initial three-level modularization analysis (Levels 1–3).[cite:4]
- `Docs/phase-X-architecture-and-refactor-plan-dashboard-GP.md` — Draft A.[cite:3]
- `Docs/phase-X-architecture-and-refactor-plan-dashboard-PR.md` — Draft B.[cite:5]

---

## 1. Shared intent and constraints

Both drafts share the same high-level intent:

- Refactor the dashboard into a structure that fits typical coding-agent tasks into a safe context window (≈6K–20K tokens instead of 40K–70K).
- Eliminate the manual JS/HTML mirroring requirement that produced LESSON-OPS-043 and BUG-039 ("dashboard.html is the source of truth" drift).[cite:2][cite:3][cite:5]
- Preserve existing runtime behavior (no endpoint, DOM, or transport changes) while restructuring source files.
- Keep `dashboard.h` as the committed, gzip-compressed payload used by firmware, with a deterministic build pipeline.[cite:1][cite:3][cite:5]
- Rely on existing Playwright coverage as a hard gate: all existing groups and fixture variants must remain green after each refactor step.[cite:2][cite:3][cite:5]

Both also adopt the same three structural levels originally described in the modular-architecture background note:[cite:4]

1. **Level 1 — Module split**: break the JS monolith into smaller modules but keep HTML workflow as-is.
2. **Level 2 — Generated HTML**: make `dashboard.html` a build product rather than a hand-edited mirror.
3. **Level 3 — Component model**: move toward per-panel component directories with their own JS/HTML/CSS.

---

## 2. Draft A (GP) — strengths, weaknesses, gaps

### 2.1 Strengths

1. **Deep current-state analysis**  
   - Provides a detailed breakdown of the monolithic `dashboard.js` into shared, satellite-only, and aggregator-only functional groups, including approximate line counts per area.[cite:3]
   - Maps major CSS selector families (e.g., `.sensor-*`, `.network-card`, `.gw-*`) to functional regions of the UI, which is directly helpful when defining Level 3 components.[cite:3]

2. **Clear three-level framing**  
   - Articulates Levels 1–3 with an emphasis on why each level exists and why the order (L1 → L2 → L3) matters.[cite:3][cite:4]
   - Explicitly calls out that Level 2 is the structural fix for LESSON-OPS-043 and that Level 3 is a scalability layer for Phase E and beyond.[cite:3][cite:4]

3. **Concise version mapping and high-level steps**  
   - Defines a compact version range `v7.6.5.0–v7.6.5.5` with one version per conceptual move (bundle scaffold, module split, template introduction, template canonicalization, component assembler, component migration).[cite:3]
   - Associates each step with clear goals, risk ratings, and approximate token budgets per step.[cite:3]

4. **Refactor principles**  
   - States non-negotiable rules: single source of truth, file boundaries aligned to real feature ownership, deterministic builds, and no reliance on “trust the refactor” without Playwright gates.[cite:3]
   - Emphasizes keeping generated artifacts reviewable and committed (HTML and header) even after the source-of-truth shift.[cite:3]

5. **Context-window centric reasoning**  
   - Quantifies expected per-task working-context sizes before and after each level, making the benefits for coding agents explicit.[cite:3]

### 2.2 Weak points

1. **Less concrete file-level prescriptions**  
   - Uses `dashboard/src/*.js` and generic script names (`build-dashboard-js.sh`, `build-dashboard-html.sh`) but does not enumerate exact module files or directory trees the way Draft B does.[cite:3][cite:5]
   - Leaves some details of CI integration and preflight checks to implication rather than specifying file edits and check names.

2. **Coarser step granularity at Level 3**  
   - Collapses the component work into two steps (`v7.6.5.4` and `v7.6.5.5`), without separating template extraction, CSS extraction, and closure/test work into distinct, reversible versions.[cite:3]
   - This makes Level 3 higher-risk to land in one shot compared to Draft B’s smaller, more incremental steps.

3. **Less explicit linkage to existing regeneration pipeline**  
   - Acknowledges the need to integrate with `minify-dashboard.sh` and `generate-header.sh`, but does not fully restate the five-step regeneration pipeline codified in LESSON-OPS-091 (render → fixtures → minify → header → check).[cite:2][cite:3]

4. **Device-testing and operational checklists mostly implicit**  
   - Leans heavily on "no behavior change" plus Playwright gates but does not explicitly reference LESSON-OPS-051 (real-device dashboard validation) or restate concrete device-testing steps in the Phase X context.[cite:2][cite:3]

### 2.3 Gaps

In the sense of "areas where Draft A alone is not yet a complete implementation plan":

1. **Missing CI and preflight wiring details**  
   - Does not specify how CI workflows and `preflight.sh` will enforce that bundled JS and generated HTML are up to date, only that such enforcement is desirable.[cite:3][cite:5]

2. **No explicit plan for phased test additions**  
   - Mentions that Playwright must remain green, but does not include a dedicated closure step that adds new Phase-X-specific smoke tests for the build pipeline itself.[cite:3]

3. **Limited discussion of version bump script implications**  
   - Refers generally to keeping generated artifacts in sync but does not detail how `bump-version.sh` should change once `dashboard.html` is generated.[cite:2][cite:3][cite:5]

4. **Aggregator-specific validation mostly indirect**  
   - Reaffirms LESSON-OPS-074 at a high level (aggregator as overlay) but does not identify specific aggregator-related regression checks beyond "no behavior change" and existing tests.[cite:2][cite:3]

---

## 3. Draft B (PR) — strengths, weaknesses, gaps

### 3.1 Strengths

1. **More concrete, file-by-file implementation plan**  
   - Enumerates specific module names under `dashboard/modules/*.js` (e.g., `util.js`, `config.js`, `state.js`, `manifest.js`, `history.js`, `export.js`, `import.js`, etc.) and shows the intended grouping by concern.[cite:5]
   - Provides exact before/after directory trees for all three levels, including component/core split and script names (`bundle-dashboard.sh`, `build-dashboard.sh`).[cite:5]

2. **Richer, versioned step breakdown**  
   - Extends the version range to `v7.6.5.0–v7.6.5.7`, separating concerns such as module skeleton, CI integration, template creation, removal of hand-maintained HTML, component scaffolding, template extraction, CSS extraction, and closure/tests.[cite:5]
   - Associates each version with precise file actions (CREATE/MOVE/MODIFY/DELETE) and explicit acceptance criteria checklists.[cite:5]

3. **Tight integration with existing tooling and lessons**  
   - Explicitly updates the canonical regeneration pipeline to insert bundling and HTML build steps alongside `render_sensor_config.py`, fixture generation, minification, and header generation, in direct alignment with LESSON-OPS-091.[cite:2][cite:5]
   - Plans concrete preflight checks (e.g., `dashboard_js_is_up_to_date`, `dashboard_tmpl_has_placeholder`, `dashboard_html_not_committed`) and ties them to specific failure modes seen in prior bugs.[cite:2][cite:5]

4. **Bit-for-bit identity gates**  
   - Requires SHA-256 identity between the bundled `dashboard.js` body and the pre-split monolith, and later between generated vs. hand-maintained `dashboard.html`, and finally between pre- and post-refactor `dashboard.h`.[cite:5]
   - These gates strongly reduce the risk of subtle behavioral drift during restructuring.

5. **Playwright and preflight closure step**  
   - Introduces a final `v7.6.5.7` closure step with new Playwright build-pipeline tests and additional preflight guards for component existence and pipeline integrity.[cite:5]

6. **Fine-grained risk and token-budget analysis**  
   - Provides per-step estimates of working-context size and enumerates risk/mitigation pairs for each level (e.g., reference-before-definition risk in module bundling, whitespace/encoding drift in template injection, CSS cascade issues during extraction).[cite:5]

### 3.2 Weak points

1. **Less emphasis on the high-level component/CSS mapping**  
   - Contains fewer details about how CSS blocks and DOM regions conceptually map to visual panels compared to Draft A’s CSS partition analysis.[cite:3][cite:5]
   - This makes the intended component boundaries slightly less obvious to future readers than in Draft A.

2. **Assumes `dashboard.html` will be gitignored**  
   - Proposes deleting `dashboard/dashboard.html` from version control and adding a `dashboard_html_not_committed` preflight gate after Level 2.[cite:5]
   - This conflicts with the "generated outputs stay reviewable and committed" principle articulated in Draft A and used elsewhere in the repo (e.g., committed `dashboard.h`).[cite:3][cite:5]

3. **Some redundancy with approach note**  
   - Repeats much of the three-level argument from the earlier modular-architecture background document without always cross-referencing it, which can make the narrative feel more verbose than necessary.[cite:4][cite:5]

4. **Complexity of step numbering**  
   - Extending to `v7.6.5.7` yields many small steps. While individually safer, this can feel heavy for operators reading the plan, and reviewers must keep more version numbers in their head.[cite:5]

### 3.3 Gaps

Again, "gaps" here means "points where Draft B alone is not yet fully complete or aligned with other architectural docs":

1. **Tension with the desire to keep generated artifacts reviewable**  
   - The proposal to gitignore `dashboard.html` simplifies drift enforcement but abandons the convenience of reviewing the assembled HTML in diffs, which Draft A explicitly values.[cite:3][cite:5]

2. **Aggregator-specific constraints mostly inherited, not restated**  
   - While it respects "no behavior change" and keeps the aggregator logic within the same runtime, it does not explicitly reiterate LESSON-OPS-074’s "aggregator is an overlay, not a forked boot path" or detail aggregator-specific checks for Phase X.[cite:2][cite:5]

3. **Device-testing and manual operator validation implied, not spelled out**  
   - Similar to Draft A, it leans heavily on Playwright and preflight gates, but does not restate LESSON-OPS-051’s requirement for real-device dashboard validation in the context of Phase X refactors.[cite:2][cite:5]

---

## 4. Areas of strong alignment between drafts

Draft A and Draft B are broadly aligned in their core decisions:

1. **Three-level architecture**  
   - Both adopt Level 1 (module split), Level 2 (generated HTML), and Level 3 (component model), and both insist that Level 1 must land before Level 2, and Level 2 before Level 3.[cite:3][cite:4][cite:5]

2. **Versioning range and phase mapping**  
   - Both tie Phase X to the `v7.6.5.x` range between Phase D (v7.6.0.x) and Phase E (v8.0.x), and avoid overlapping the Phase D version span that was already used for runtime satellite management.[cite:1][cite:3][cite:5]

3. **No behavior changes, only structure**  
   - Both repeatedly state that each sub-step must preserve dashboard runtime behavior; any functional bug fixes must be handled in separate PRs, not hidden in refactor churn.[cite:3][cite:5]

4. **`dashboard.h` remains the firmware contract**  
   - Both treat the embedded, gzipped header as the authoritative firmware payload and require deterministic generation of `dashboard.h` through the new pipeline.[cite:1][cite:3][cite:5]

5. **Playwright as the non-negotiable gate**  
   - Both insist that all existing Playwright groups across all fixture variants (1sensor, 2sensor, 3sensor, 4sensor, mixed, system) must remain green at each Phase X step, consistent with the repo’s existing lessons around fixture-specific guards and test gating.[cite:2][cite:3][cite:5]

6. **Context-window-aware design**  
   - Both estimate per-step token footprints and aim to bring typical future tasks (e.g., new card type, settings-panel change) into the ≈6K–15K token band.[cite:3][cite:5]

---

## 5. Combined gaps and open questions (neither draft alone fully resolves)

These are areas where neither draft, standing alone, fully captures the constraints and lessons from the broader documentation set; the reconciled plan addresses them explicitly.

1. **Explicit integration of LESSON-OPS-051 (real-device validation)**  
   - Both drafts emphasize Playwright and preflight gates but do not restate the requirement that any dashboard code change affecting network behavior must be validated on real hardware with the dashboard open before merge, as codified in LESSON-OPS-051.[cite:2]
   - The reconciled plan needs to make device-testing checkpoints part of Phase X acceptance criteria, even for "structural-only" steps.

2. **Explicit acknowledgement of aggregator overlay semantics in component design**  
   - LESSON-OPS-074 requires that the aggregator boot path be a superset overlay of the satellite path, not a forked pipeline.[cite:2]
   - Both drafts preserve this implicitly by keeping a single runtime, but neither calls it out when defining Level 3 components (e.g., how gateway panels and settings overlay the base dashboard). The reconciled plan must keep this constraint front-and-center when defining panel/component boundaries.

3. **Tight coupling to POST/body handling constraints (LESSON-OPS-099)**  
   - Phase X is nominally structural, but restructuring the settings panel, management UI, and import/export code touches areas where LESSON-OPS-099 (x-www-form-urlencoded only) is critical.[cite:2]
   - Neither draft explicitly states that POST semantics and content types must remain unchanged through the refactor; the reconciled plan will make this an explicit rule.

4. **Decision on whether generated HTML stays committed**  
   - Draft A asserts that generated outputs, including `dashboard.html`, should remain committed for reviewability, whereas Draft B proposes gitignoring `dashboard.html` and enforcing non-commitment via preflight.[cite:3][cite:5]
   - This is a real tension that the reconciled plan must resolve by choosing one approach and carrying the relevant guardrails from both sides.

5. **Explicit relationship to the existing regeneration pipeline from Phase D and later lessons**  
   - Phase D and LESSON-OPS-091 already define a five-step regeneration pipeline (render → fixtures → minify → header → check).[cite:1][cite:2]
   - Draft B partially integrates the new bundle/build steps into this pipeline; Draft A describes the desired behavior more abstractly. The reconciled plan must restate the canonical pipeline end-to-end for Phase X.

6. **Where and how to add new Phase-X-specific tests**  
   - Draft B sketches a new Group 19 for build-pipeline and component existence tests; Draft A assumes existing tests are sufficient and does not plan for new tests.[cite:3][cite:5]
   - The reconciled plan needs to adopt a concrete testing closure story (from Draft B) while ensuring it fits with the rest of the repo’s testing philosophy in `bugs-and-lessons-learned.md`.

---

## 6. Summary of reconciliation direction

At a high level, the reconciled plan will:

- Use **Draft B’s step decomposition and concrete file-level actions** (version range `v7.6.5.0–v7.6.5.7`, explicit module/component lists, and preflight/CI wiring),
- Enrich it with **Draft A’s deeper current-state and CSS/component mapping**, to define component boundaries that reflect the existing DOM and visual layout,[cite:3][cite:5]
- Preserve **reviewable generated artifacts** (keep `dashboard.html` committed but clearly marked as generated, with preflight enforcing sync), following Draft A’s principle while still using Draft B’s identity and sync checks,[cite:3][cite:5]
- Explicitly integrate **LESSON-OPS-043, -051, -052, -065, -074, and -099** as non-negotiable guardrails for every Phase X step,[cite:2]
- And adopt **Draft B’s closure/test additions** (build-pipeline smoke tests, component existence checks) as the Phase X exit criteria.

These decisions are carried forward into the separate reconciliation plan document and the final unified Phase X implementation plan.
