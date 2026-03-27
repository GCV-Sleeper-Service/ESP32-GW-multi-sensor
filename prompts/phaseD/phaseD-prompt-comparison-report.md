# Phase D Prompt Set Comparison Report (Base vs CL)

**Date:** 2026-03-27  
**Scope compared:**
- Base prompts (current): `v7.6.0.0` … `v7.6.0.5`
- Alternate prompts (commit `2371dac`): `v7.6.0.0-CL` … `v7.6.0.5-CL`

---

## 1) Executive Verdict

### Are the two PR91-style comments warranted?
Yes. Both were warranted and high-value:
1. **v7.6.0.0 reset ambiguity** (“choose one behavior”) created implementation divergence risk.
2. **v7.6.0.1 add persistence ambiguity** (“single save or full save”) also allowed divergence.

Both issues are now corrected in the base prompts.

### Which prompt family is more likely to deliver the best implementation outcome?
**Overall winner: Base prompts (the non-CL files), after the ambiguity fixes.**

Why:
- They match your required section anatomy and ordering more closely.
- They explicitly reference **35 critical rules** (new index state), not legacy 28.
- They are cleaner for downstream agent execution and less likely to drift from your requested structure.

### What does CL do better?
The CL prompts are often stronger in **low-level implementation specificity** (buffer ownership, pointer aliasing risks, exact helper usage caveats, route-shape examples, and test anti-pattern callouts). These are useful to merge selectively into base prompts.

---

## 2) Comparison Method

Compared every step pair one-by-one:
- `v7.6.0.0` vs `v7.6.0.0-CL`
- `v7.6.0.1` vs `v7.6.0.1-CL`
- `v7.6.0.2` vs `v7.6.0.2-CL`
- `v7.6.0.3` vs `v7.6.0.3-CL`
- `v7.6.0.4` vs `v7.6.0.4-CL`
- `v7.6.0.5` vs `v7.6.0.5-CL`

Evaluation axes:
1. Conformance to your prompt-structure requirement (section names/order)
2. Conformance to fixed design decisions
3. Contract-lock completeness
4. Data lifecycle clarity
5. Operational safety (mutex, compaction, no side effects)
6. Test/mock rigor and CI matrix expectations

---

## 3) High-Level Compliance Findings

### 3.1 Structure compliance vs your “exact section order” requirement
- **Base prompts:** largely aligned to the required section names/order.
- **CL prompts:** good quality, but not aligned to your exact naming/order convention (e.g., “Repository & Setup” section injected; section labels differ from your §3.2/§3.3 style wording).

**Impact:** If strict reviewer checks use your template grammar/order, base prompts are safer.

### 3.2 Critical Rules currency
- **Base:** references all **35** critical rules.
- **CL:** repeatedly references “all 28 critical rules” (older baseline).

**Impact:** CL can under-signal newer rule set (29–35) unless manually updated.

### 3.3 Pre-condition command exactness
- **Base:** includes the exact command block you required (3sensor/mixed/system/aggregator + preflight).
- **CL:** adds extra commands (`firefox`, `render_sensor_config.py --check`). Good in practice, but not “exact block only.”

**Impact:** CL is operationally stronger but less template-conformant.

---

## 4) Step-by-Step Findings and Best Combination

## v7.6.0.0 — NVS Persistence Layer

### Better in Base
- Better conformance to required structure and ordering.
- Now has explicit reset behavior (no longer ambiguous): clear NVS namespace and leave it empty; runtime reloads compile-time defaults for current boot.

### Better in CL
- Stronger technical guardrails around `SatelliteCache` pointer ownership and introducing owned buffers (`id_buf`, `name_buf`, `url_buf`).
- Explicit mention that init currently happens inside `aggregator_poll_task()` in this branch layout.
- More implementation-level details around where loops currently live and what exactly must change.

### Recommended hybrid (best result)
Use **Base as canonical**, and copy in CL’s concrete memory-safety notes:
- owned storage/pointer aliasing warning,
- explicit init-location caveat if code still has inline init in task,
- explicit loop-audit checklist with exact function names.

---

## v7.6.0.1 — Add Satellite Endpoint

### Better in Base
- Cleaner structure and explicit validation branch matrix.
- Ambiguity fixed: requires `save_satellites_to_nvs_()` full rewrite for this endpoint.

### Better in CL
- Better context-specific safety notes for buffers (`s_proxy_tmp` vs polling buffer).
- Stronger guidance about query parsing in ESPHome/IDF context.
- Better “probe helper now for reuse in v7.6.0.3” instruction depth.

### Recommended hybrid
Keep **Base skeleton and contracts**, import CL’s:
- buffer selection safety note,
- explicit helper-reuse guidance,
- additional parameter bounds guidance (`poll` min/max) if desired.

---

## v7.6.0.2 — Delete Satellite Endpoint

### Better in Base
- Directly aligned with required shape and concise invariant language.
- Explicit “full rewrite after compaction” rule.

### Better in CL
- Excellent rationale for avoiding raw struct `memcpy` due to pointer aliasing.
- Stronger compaction snippet detail and lifecycle explanation.

### Recommended hybrid
Base + CL pointer-aliasing warning and safe compaction-copy guidance. This is likely the highest-value technical merge.

---

## v7.6.0.3 — Test Satellite Endpoint

### Better in Base
- Cleanly enforces side-effect-free contract.
- Simpler, less over-prescriptive prompt that reduces accidental divergence.

### Better in CL
- Better explicit extraction guidance for `hardware` and `sensor_count` from manifest payload.
- Better mention of method handling and concrete response examples.

### Recommended hybrid
Base + CL’s concrete success response shape example and parsing caveats.

---

## v7.6.0.4 — Dashboard Add/Remove/Test UI

### Better in Base
- Better direct mapping to your required “Code quality gates must be in prompt.”
- Clear Rule 28 regeneration requirement and no-firmware boundary.

### Better in CL
- Richer UI implementation notes (event-binding anti-pattern examples, explicit inline status flow, dark/light styling reminders, explicit escaping examples).

### Recommended hybrid
Base + CL’s concrete JS anti-pattern examples and UI state transition details.

---

## v7.6.0.5 — Playwright + Closure

### Better in Base
- Strong section anatomy and closure-document checklist directly aligned to your instruction.
- Good contract-lock section covering branches and response-shape requirements.

### Better in CL
- More detailed test-guardrails (group numbering discipline, hardcoded count assertions, skip-guard style).
- Strong stateful-mock implementation guidance and branch table examples.

### Recommended hybrid
Base + CL’s test anti-pattern/guardrail specifics (especially vacuous assertion warnings and fixture-skip discipline).

---

## 5) Gaps Identified (Both Families)

1. **Potential stale references to Critical Rules count in CL (28 vs 35).**
   - Cause: CL prompt set appears derived from an earlier prompt-index baseline.
2. **Some prerequisites in both sets assume prior-step internals exist exactly as described.**
   - Cause: serial step prompts naturally depend on previous merges; risk if real merged code deviates.
3. **No explicit “if merged code differs from prompt assumptions, reconcile before coding” gate.**
   - Cause: both families are execution-oriented rather than reconciliation-oriented.
4. **CL prompts occasionally over-constrain implementation details that may differ by actual branch code layout.**
   - Cause: very concrete snippets tied to one observed file shape.
5. **Base prompts can be too abstract in places where CL gives safer low-level caveats.**
   - Cause: prioritizing template compliance and concision over implementation depth.

---

## 6) Root Causes of Divergence

- Different optimization targets:
  - **Base** optimized for template compliance and process gates.
  - **CL** optimized for technical implementation detail and defensive coding cues.
- Different source baselines:
  - CL still references the older critical-rule total (28), indicating mismatch with updated prompt index.
- Different risk priorities:
  - Base minimizes format drift risk.
  - CL minimizes implementation ambiguity risk.

---

## 7) Final Recommendation — “Best Combined Prompts” Strategy

For each version (`v7.6.0.0`…`v7.6.0.5`):
1. Keep **Base prompt** as canonical document to preserve strict structure/order compliance.
2. Import from CL only the highest-value concrete safeguards:
   - pointer ownership and copy-safety notes,
   - exact buffer safety caveats,
   - explicit anti-pattern warnings in UI/tests,
   - richer branch tables where helpful.
3. Normalize all references to **Critical Rules 1–35**.
4. Keep the exact pre-condition block as required, optionally adding extra checks under an “Optional hardening checks” subsection (not replacing required block).
5. Add a one-line reconciliation gate per prompt:
   - “If source code shape differs from this prompt’s assumptions, document delta and adjust implementation plan before editing.”

This hybrid gives the best chance of successful, reproducible downstream execution while still satisfying your strict prompt authoring contract.

---

## 8) Per-Step Winner Summary

- **v7.6.0.0:** Base (with CL memory-safety details merged)
- **v7.6.0.1:** Base (with CL buffer/probe detail merged)
- **v7.6.0.2:** Base (with CL compaction/pointer-copy warning merged)
- **v7.6.0.3:** Base (with CL response/parsing detail merged)
- **v7.6.0.4:** Base (with CL event-binding/UX anti-pattern detail merged)
- **v7.6.0.5:** Base (with CL test guardrail detail merged)

Overall best delivery path: **Base-first hybridization with selective CL hardening notes**.
