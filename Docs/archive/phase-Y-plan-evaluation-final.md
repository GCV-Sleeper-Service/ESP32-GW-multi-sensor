# Phase Y Plan Evaluation — Final Expert Assessment

_Date: 2026-04-08_
_Evaluator: Claude (independent evaluation after reviewing all five plans, two prior assessments, v2 inventory, and the actual source file)_

---

## Methodology

I read all five plans, both prior assessments, the v2 inventory, the Phase X context document, and verified every critical line-range claim against the actual `dashboard/sensor_history_multi.h` at HEAD. Where the two prior assessments disagree, I resolved the disagreement by checking the source.

### Verified File Landmarks (HEAD)

| Landmark | Actual line | Plans D/E claim | Verified? |
|---|---|---|---|
| `TAG` definition | 96 | 96 | ✓ |
| `SENSOR_MANIFEST:HEADER_BEGIN` | 375 | 375 | ✓ |
| `SENSOR_MANIFEST:ENTITY_BEGIN` | 381 | 381 | ✓ |
| `SENSOR_MANIFEST:ENTITY_END` | 496 | 496 | ✓ |
| `struct HistoryMeta` | 556 | 556 | ✓ |
| `maybe_yield_nvs_scan_` | 801 | 801 | ✓ |
| `reboot_task_` | 1170 | 1170 | ✓ |
| `#ifdef PING_DEVICE_INDEX` | 1220 | 1220 | ✓ |
| `class PingAdapter` | 1221 | 1220–1221 | ✓ |
| `#if AGGREGATOR_ENABLED` (island 1) | 1388 | 1388 | ✓ |
| `s_cache_mutex` definition | 1479 | 1479 | ✓ |
| `#endif // AGGREGATOR_ENABLED` (island 1) | 2272 | 2272 | ✓ |
| `class HistoryWebHandler` | 2279 | 2279 | ✓ |
| `#if AGGREGATOR_ENABLED` (island 2) | 3697 | 3697/3709 | D says 3709, E says 3697 — **E is correct** |
| `#endif // AGGREGATOR_ENABLED` (island 2) | 4282 | 4282/4283 | ✓ |
| Class `};` | 4283 | 4283/4284 | ✓ |
| `register_history_handler` | 4290 | 4285/4290 | 4285 is the comment block, 4290 is the function — both reasonable |

**Observation:** Plans D and E have the most accurate line ranges. Plan D's aggregator island 2 start at "3709" is slightly off — the `#if AGGREGATOR_ENABLED` guard is at 3697, not 3709. Plan E is exact.

---

## The Decisive Architectural Choice: Option B vs Option A

The single most important differentiator across the five plans is the assembly strategy. This determines cascading impacts on generator changes, YAML changes, preflight impact, and identity gate feasibility.

| Aspect | Option A (direct `#include` chain) | Option B (assembled artifact) |
|---|---|---|
| Plans using it | A (GP), B (GPv2) | D (CO), E (CL) |
| Plan C | Ambiguous — discusses both without resolving |  |
| Generator changes | Required (retarget `render_sensor_config.py`) | Zero |
| YAML `includes:` changes | Required (list all fragment files) | Zero |
| Preflight impact | All 18 content-based checks break | Zero — checks grep the assembled file |
| Identity gate | Preprocessor output comparison (needs toolchain) | SHA-256 of assembled text (portable, trivial) |
| Blast radius per step | YAML + generator + preflight must change together | Fragment extraction + assembly script only |

**Verdict:** Option B is unambiguously safer and more practical. This single decision eliminates Plans A, B, and C from serious contention as base plans.

---

## Plan-by-Plan Evaluation

### Plan A — GP (1,019 lines)

| Criterion | Score | Wt | Wtd | Key Strength | Key Weakness |
|---|---|---|---|---|---|
| Module boundaries | 3 | ×3 | 9 | Good named modules; aggregator two-island correctly identified | No verified line ranges; non-contiguous `aggregator_state.h` extraction not justified |
| Verification gates | 2 | ×2 | 4 | Rejects binary identity | "Normalized preprocessor output" is undefined and unimplementable without toolchain |
| Generator strategy | 3 | ×1.5 | 4.5 | Dedicated generated header concept is sound | Requires modifying `render_sensor_config.py` — breaks all 18 preflight checks during migration |
| Aggregator resolution | 3 | ×2 | 6 | Three-layer split (state/runtime/routes) is architecturally sound | `aggregator_state.h` requires extracting non-contiguous symbols from a contiguous `#if` block |
| Step granularity | 3 | ×1.5 | 4.5 | Logical ordering; gate conditions per level | No checkbox acceptance criteria; steps v7.6.6.4–6 are rated "High, 2–3 sessions" |
| Safety rules | 4 | ×2 | 8 | All 12 rules addressed; deferred-task homes explicit | Mutex visibility depends on non-contiguous extraction succeeding |
| Phase 7 compat | 5 | ×1 | 5 | Best explicit Phase 7 extension-point mapping | — |
| Executability | 2 | ×2 | 4 | Clear intent | Preprocessor gate not implementable; YAML migration at v7.6.6.7 is high-blast |
| **Total** | | | **45/75** | | |

**Veto check:** FAIL — Verification gates (2) and Practical executability (2) both below 3.

### Plan B — GPv2 (1,495 lines)

| Criterion | Score | Wt | Wtd | Key Strength | Key Weakness |
|---|---|---|---|---|---|
| Module boundaries | 4 | ×3 | 12 | Best Architecture Decisions section; `.inc` handler fragments | No verified line ranges; Option A means YAML/preflight changes early |
| Verification gates | 4 | ×2 | 8 | Best explanation of why binary and preprocessor comparison fail | Assembly script named but not specified |
| Generator strategy | 4 | ×1.5 | 6 | Single `sensor_topology.generated.h` is clean | Still requires generator retargeting |
| Aggregator resolution | 5 | ×2 | 10 | Clearest three-layer articulation | `.inc` pattern is "or equivalent" — leaves coding agent to decide |
| Step granularity | 3 | ×1.5 | 4.5 | Logical progression | Lighter per-step acceptance criteria |
| Safety rules | 4 | ×2 | 8 | Deferred-task pairs and mutex explicitly addressed | Doesn't enumerate all 12 rules by number |
| Phase 7 compat | 4 | ×1 | 4 | References both v7.7 docs | Not as mapped as Plan A |
| Executability | 4 | ×2 | 8 | Task-size analysis present; best of non-Option-B plans | Assembly script unspecified; still needs generator migration |
| **Total** | | | **60.5/75** | | |

**Veto check:** PASS — no criterion below 3.

### Plan C — PEv2 (1,033 lines)

| Criterion | Score | Wt | Wtd | Key Strength | Key Weakness |
|---|---|---|---|---|---|
| Module boundaries | 3 | ×3 | 9 | 9-module structure; Phase 7 stubs | PingAdapter at "~1951–2235" is wrong — actual is 1220–1387; suggests v1 inventory data |
| Verification gates | 3 | ×2 | 6 | Discusses both options | Ambiguous about which option to use |
| Generator strategy | 3 | ×1.5 | 4.5 | Generator markers in `data-model.h` | Generator migration path unspecified |
| Aggregator resolution | 3 | ×2 | 6 | Two islands acknowledged | Shared state visibility not explicit |
| Step granularity | 4 | ×1.5 | 6 | 10 steps with level classifications | Later steps lack file-change tables |
| Safety rules | 3 | ×2 | 6 | Rules present | NVS schema protection not explicit |
| Phase 7 compat | 4 | ×1 | 4 | Most detailed Phase 7 struct analysis | Stubs are out-of-scope commentary |
| Executability | 3 | ×2 | 6 | Token tables present | Wrong PingAdapter line range would cause extraction failure |
| **Total** | | | **47.5/75** | | |

**Veto check:** PASS (barely) — three criteria at exactly 3.

### Plan D — CO (1,012 lines)

| Criterion | Score | Wt | Wtd | Key Strength | Key Weakness |
|---|---|---|---|---|---|
| Module boundaries | 5 | ×3 | 15 | 7 fragments with verified line ranges; correct landmarks; single `web-handler.h` preserving class integrity | `web-handler.h` at ~2,005 lines is large but honestly acknowledged |
| Verification gates | 5 | ×2 | 10 | SHA-256 assembly check is trivial, portable, toolchain-free; `--check`/`--write`/`--dry-run` specified | Does not address how `--check` handles post-generator divergence (reverse-sync gap) |
| Generator strategy | 5 | ×1.5 | 7.5 | Zero generator changes under Option B; pipeline ordering explicit | Reverse-sync between fragment stubs and assembled content not addressed |
| Aggregator resolution | 5 | ×2 | 10 | Both islands with exact line ranges; complete shared-state symbol table; assembly-order visibility chain | Plan doesn't explicitly state "Option B makes two-island safe" (the key insight CL has) |
| Step granularity | 5 | ×1.5 | 7.5 | 8 steps; every step has scope + files table + checkbox criteria + gate conditions; pre-step fully specified | v7.6.6.1 assembly script + baseline is one step — could be split |
| Safety rules | 5 | ×2 | 10 | All 4 deferred-task pairs mapped with call chains; mutex + yield visibility verified with line numbers; NVS schema invariants listed; all 18 preflight checks catalogued | Does not enumerate 12 rules by number (covers all content though) |
| Phase 7 compat | 4 | ×1 | 4 | Per-module Phase 7 delta table (+100/+400/+150 lines) | Doesn't reference v7.7 plan docs by name |
| Executability | 5 | ×2 | 10 | Assembly script fully specified; task-size table present; each step independently executable from checkbox criteria; Option B means zero adjacent-system changes per extraction | Reverse-sync gap is an operational hazard the coding agent will encounter |
| **Total** | | | **74/75** | | |

**Veto check:** PASS — no criterion below 4.

### Plan E — CL (998 lines)

| Criterion | Score | Wt | Wtd | Key Strength | Key Weakness |
|---|---|---|---|---|---|
| Module boundaries | 5 | ×3 | 15 | 10 fragments with arithmetic checksum (sums to 4,325 ✓); per-boundary justification; most granular | Three web-handler fragments (07/08/09) create syntactically incomplete C++ files |
| Verification gates | 5 | ×2 | 10 | SHA-256 assembly check; per-step gates; fully specified `--write`/`--check`/`--list` | — |
| Generator strategy | 4 | ×1.5 | 6 | Zero generator changes; explicitly addresses the reverse-sync requirement | Reverse-sync is error-prone and requires operator discipline |
| Aggregator resolution | 5 | ×2 | 10 | Best articulation: "Option B re-joins both islands — two-island is source-organisation, not compilation" | — |
| Step granularity | 4 | ×1.5 | 6 | 9 steps with checkbox criteria; `run_full_pipeline()` written out | v7.6.6.1 bundles all 10 fragments + assembly script in one step |
| Safety rules | 5 | ×2 | 10 | All deferred-task pairs; mutex/yield traced; NVS schema guarded | — |
| Phase 7 compat | 5 | ×1 | 5 | References both Phase 7 docs; per-module delta estimates; extension points named | — |
| Executability | 4 | ×2 | 8 | Checkbox criteria; task-size table; pipeline bash contract written out | Split class fragments break IDE/clangd for anyone editing fragments directly; reverse-sync adds operational complexity |
| **Total** | | | **70/75** | | |

**Veto check:** PASS — no criterion below 4.

---

## Comparative Score Table

| Criterion (weight) | A-GP | B-GPv2 | C-PEv2 | D-CO | E-CL |
|---|---|---|---|---|---|
| Module boundaries (×3) | 9 | 12 | 9 | **15** | **15** |
| Verification gates (×2) | 4 | 8 | 6 | **10** | **10** |
| Generator strategy (×1.5) | 4.5 | 6 | 4.5 | **7.5** | 6 |
| Aggregator resolution (×2) | 6 | 10 | 6 | **10** | **10** |
| Step granularity (×1.5) | 4.5 | 4.5 | 6 | **7.5** | 6 |
| Safety rules (×2) | 8 | 8 | 6 | **10** | **10** |
| Phase 7 compat (×1) | **5** | 4 | 4 | 4 | **5** |
| Executability (×2) | 4 | 8 | 6 | **10** | 8 |
| **Total /75** | **45** | **60.5** | **47.5** | **74** | **70** |
| Veto | FAIL | PASS | PASS | PASS | PASS |

---

## Assessment of the Two Prior Assessments

### Assessment 1

Recommends Plan D (74/75) as-is. Gives Plan E 68/75 with deductions for reverse-sync and split web handler.

**Where I agree:** The split web-handler criticism is valid and material. Three syntactically incomplete class fragments are a real ergonomic problem for coding agents and human editors alike. Plan D's single `web-handler.h` is the better boundary.

**Where I partially disagree:** Assessment 1 gives Plan D a near-perfect score without noting the reverse-sync gap. Assessment 1 claims "Plan D explicitly avoids the reverse-sync requirement by design" — this is incorrect. Both plans have the same issue: the generator writes into the assembled file, which then diverges from pure fragment concatenation. Plan D simply doesn't mention the problem.

### Assessment 2

Initially gives Plan E a perfect 75/75. Then, after reviewing Assessment 1's feedback, revises to "Plan D as base with Plan E amendments."

**Where I agree:** The revised recommendation is correct. Assessment 2's analysis of the reverse-sync issue is the most accurate of both assessments — it correctly identifies that Plan D defers the problem rather than solving it, and that Plan E at least names it.

**Where I partially disagree:** The initial 75/75 for Plan E overweights completeness and underweights the ergonomic cost of syntactically incomplete C++ fragments. The revised score after feedback is more accurate.

---

## Resolving the Assessments' Disagreement

The two assessments converge on the same conclusion after Assessment 2 processes Assessment 1's feedback: **Plan D as the base, with amendments from Plan E.** I agree with this convergence.

The specific points of disagreement and my resolution:

| Disagreement | Assessment 1 | Assessment 2 | My verdict |
|---|---|---|---|
| Web handler split | D's single file is better (valid) | E's 3-fragment is more granular (initially) → agrees D is better after feedback | D is better — incomplete C++ fragments are a real problem |
| Reverse-sync | Claims D avoids it by design | Correctly identifies D defers it | Assessment 2 is correct — D has an undocumented gap |
| Fragment directory | Prefers `firmware/core/` | Notes both are valid; prefers `firmware/core/` in amendments | `firmware/core/` — firmware code doesn't belong under `dashboard/` |
| Overall winner | D as-is (74/75) | D as base + E amendments (revised) | D as base + specific E amendments |

---

## Recommendation

**Use Plan D (CO) as the base, with targeted amendments from Plan E (CL).**

Plan D earns the base-plan role because:

1. Option B (assembled artifact) eliminates generator, YAML, and preflight risk during all extraction steps
2. `firmware/core/` is the semantically correct home for firmware modules
3. Single `web-handler.h` preserves syntactic completeness of all fragments
4. Verified line ranges with correct landmarks
5. SHA-256 identity gate is trivially implementable

### Specific Amendments from Plan E

| Section | Take from | Rationale |
|---|---|---|
| Reverse-sync mechanism | Plan E (§4.2–4.3) | Plan D omits how `assemble --check` stays green after generator writes. The assembled file diverges from pure fragment concatenation after `render_sensor_config.py --write`. Plan E's explicit reverse-sync step must be added to Plan D's pipeline. |
| Separate deferred-management fragment | Plan E (04-deferred-mgmt.h) | Plan D bundles reboot/delete-data tasks into `nvs-persistence.h`. Plan E correctly separates them into a 50-line module. This gives management tasks explicit ownership and cleaner Phase 7 extension. |
| Arithmetic verification sum in pre-implementation gate | Plan E (§2.4) | The explicit check that fragment line counts sum to 4,325 is a valuable pre-implementation sanity check. |
| `run_full_pipeline()` bash contract | Plan E (v7.6.6.0) | Plan E's `run_full_pipeline()` with `require_node()` and `require_npm_deps()` dependency pre-checks is more complete than Plan D's equivalent. |
| "Option B re-joins both islands" articulation | Plan E (Appendix D) | Plan E's insight that "the two-island problem is a source-organisation concern, not a compilation concern" under Option B should be stated explicitly in the plan. |
| Step-level checkbox criteria format | Plan E | Where Plan D's acceptance criteria are lighter, adopt Plan E's checkbox format for consistency. |
| Architecture Decisions section | Plan B (GPv2 §2) | Plan B's 7-decision resolved table is the most complete and should be adapted as a §0 or §2. |

### Amendments NOT taken

| Proposal | Source | Why rejected |
|---|---|---|
| 3-fragment web handler split | Plan E | Syntactically incomplete fragments; IDE/clangd breakage; ergonomic cost outweighs granularity benefit |
| `dashboard/firmware_modules/` directory | Plan E | Firmware modules don't belong under `dashboard/`; `firmware/core/` is semantically correct |
| Phase 7 extension stubs in code | Plan C | Out of scope for structural-only phase; adds noise without value |
| Dedicated `aggregator_state.h` | Plans A/B | Requires non-contiguous extraction from a contiguous `#if` block; not a safe structural-only move |

---

## Unresolved Issues (Operator Decisions Required)

1. **Reverse-sync mechanism design.** The assembly `--check` gate will fail after every `render_sensor_config.py --write` because the generator injects content into the assembled file that doesn't exist in the fragment stubs. Two options:
   - **Option R1:** After generator writes, reverse-extract the affected fragment (`data-model.h`) from the assembled file back to the fragment source. Plan E proposes this explicitly.
   - **Option R2:** The assembly `--check` is "smart" — it knows which region is generator-owned and excludes it from comparison, or compares only the non-generated portions.
   - **Recommendation:** R2 is more robust. The assembly script should know which fragment contains generator markers and compare only the delimiter lines, not the generated content. This avoids the operational risk of forgetting the reverse-sync step.

2. **Assembly script name.** Plan D: `assemble-firmware-modules.sh`. Plan E: `assemble-sensor-history.sh`. Recommendation: `assemble-sensor-history.sh` — it's specific to this file and follows the `bundle-dashboard.sh` naming convention.

3. **`web-handler.h` future split.** At ~2,005 lines, this is the largest fragment. The operator should decide whether to add a future Phase Z step to split it, or accept it as the cost of preserving class integrity. Recommendation: accept for Phase Y; revisit after Phase 7 if the file grows further.

4. **Step numbering for assembly placeholder.** Plan D's `provision.sh` v7.6.6.0 should reserve a slot for `assemble-sensor-history.sh` (even as a no-op) so step numbering is stable across the Phase Y window.

5. **Board profile validation scope at v7.6.6.6–7.** Plan D mentions validating with both CI-safe and aggregator configs but doesn't enumerate which board YAML files exist for the aggregator profile. This should be confirmed before v7.6.6.6 execution.

---

## Final Module Structure (Recommended)

```
firmware/
  core/
    config.h                    ← lines 1–95 (includes, compile-time constants)
    data-model.h                ← lines 96–555 (types + generated marker blocks)
    nvs-persistence.h           ← lines 556–1169 (NVS model, helpers, restore, persist)
    deferred-management.h       ← lines 1170–1219 (reboot/delete-data task pairs)
    ping-adapter.h              ← lines 1220–1387 (PingAdapter class)
    aggregator-runtime.h        ← lines 1388–2278 (aggregator runtime island 1)
    web-handler.h               ← lines 2279–4284 (HistoryWebHandler class, complete)
    registration.h              ← lines 4285–4325 (register_history_handler)

Verification sum: 95 + 460 + 614 + 50 + 168 + 891 + 2006 + 41 = 4,325 ✓
```

This structure has 8 fragments vs Plan D's 7 (adding the separated `deferred-management.h`) while keeping Plan D's single `web-handler.h`.

---

_End of evaluation._
