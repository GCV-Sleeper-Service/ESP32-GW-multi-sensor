# Multi-Phase Planning Session — Supplement from Phase V Mitigation Steps

_Append this supplement to `prompts/handoff/multi-phase-planning-prompt.md` before running the multi-phase planning session._
_Source: v7.6.9.4–v7.6.9.5 mitigation sequence + Phase VX board onboarding sprint findings._
_Date: 2026-04-20 (revised: BUG-083 corrected RISC-V stack analysis)_

---

## Additional Mandatory Reading

Add these to the **Layer 4 — Constraint Context** reading list:

18. `Docs/phase-V-capacity-study.md` — includes task stack sizing table (corrected v7.6.9.5)
19. `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` — why three extra mitigation steps were needed
20. `Docs/board-measurement-log-v7.6.10.md` — if Phase VX completed: real telemetry from all 7 boards
21. `Docs/esp32-board-selection-guide.md` — if Phase VX completed: expanded use-case matrix
22. `Docs/lessons/firmware.md` — read BUG-082, BUG-083, LESSON-OPS-127, LESSON-OPS-128
23. `scripts/stress-test-httpd-stack.sh` — the httpd stack stress test protocol (must be referenced in Phase 7)

---

## Phase 7 Review — Additional Questions

The original prompt asks 5 questions about Phase 7 readiness. Add these:

**6. Does the Phase 7 plan include httpd stack watermark validation after adding new handlers?**

Phase 7 adds at least 3 new HTTP handlers (`DELETE /api/v2/history/{device_id}`, `POST /api/v2/import/{device_id}`, storage stats v2). Each runs on the httpd task stack. v7.6.9.5 measured peak usage at ~3,400 B across all three production boards — with a 16 KB stack that leaves ~12,600 B headroom. New handlers that increase call chain depth should not approach the stack ceiling, but validation is cheap and should be mandatory.

**Required addition to Phase 7:** After the step that adds the last new handler, add a mandatory device gate:
```
Run `bash scripts/stress-test-httpd-stack.sh` on at least one board per architecture.
Acceptance: minimum watermark ≥ 2000 bytes.
If watermark < 2000: investigate handler call depth before merging.
```

This gate is lightweight — the stress test runs in under 30 seconds. The 2000 B threshold is conservative; current headroom is ~12,600 B. The purpose is detecting unexpected regressions, not tuning.

**7. Does the Phase 7 plan include chunked HTTP streaming for history responses?**

BUG-082 (discovered v7.6.9.4) documents that `csv.reserve(cap)` does not truncate — the NVS scan loop grows the string past the cap through unbounded appending. WROOM boards with large NVS history (500+ segments, ~40 KB CSV vs ~34 KB free heap) crash on `/history/{id}/{series}`. The changelog says "Full fix deferred to Phase 7 chunked HTTP streaming."

But Phase 7's 12 steps (`Docs/v7.7-implementation-plan.md`) are entirely about the per-device NVS persistence engine. There is NO step for chunked HTTP streaming, no step for a paged history loader on the dashboard, and no step that addresses BUG-082 directly.

**Required addition to Phase 7:** A step (probably v7.7.3.0 or a new sub-phase) that:
- Replaces single-response CSV building with chunked `Transfer-Encoding: chunked` streaming
- Streams history rows directly from NVS to the HTTP response without building a full string in RAM
- Updates the dashboard history loader to handle streaming responses
- Closes BUG-082 and fully resolves issue #139

This step depends on v7.7.0.x (per-device persistence engine) being complete, since the streaming implementation needs to iterate over the new per-device NVS key scheme.

**8. Are the memory budget assumptions in the capacity study still valid?**

The capacity study (`Docs/phase-V-capacity-study.md`) was produced at v7.6.6.8. Since then:
- v7.6.9.4 added heap-adaptive history cap (changes runtime memory profile)
- v7.6.9.5 fixed BUG-083: the C3 was running on stock 4 KB httpd stack, not the intended 16 KB. With the fix applied, the C3 now allocates 12 KB more stack — meaning ~12 KB less free heap at boot than the capacity study assumed.
- BUG-082 means the CSV reserve cap is not actually enforced — real peak memory usage during history fetch is higher than the capacity study assumed

If Phase VX completed, the `board-measurement-log-v7.6.10.md` has real measurements from 7 boards. Use those instead of the capacity study's estimates where they differ.

**9. Does the Phase 7 plan account for the httpd stack stress test gate?**

All boards now run with the same 16 KB httpd stack — there is no architecture-conditional sizing. Peak usage is ~3,400 B on both RISC-V (C3) and Xtensa (WROOM, S3). However, Phase 7 adds new FreeRTOS tasks (e.g., `agg_hist_sync` suggested in the capacity study line 467). Each new task needs appropriate stack sizing based on its workload, validated with `uxTaskGetStackHighWaterMark()` during device testing.

The lesson from BUG-083 (LESSON-OPS-128): verify configuration equivalence before theorizing about measurement discrepancies. When a new board shows unexpected watermark values, check that the local component override is actually compiled in (`grep external_components` in the board's YAML) before investigating deeper causes.

---

## Phase 10 Review — Additional Context

The original prompt asks about a "standalone" board role. v7.6.9.5's findings add a dimension:

**Standalone on C3 (RISC-V, 400 KB SRAM, no PSRAM):**
- Free heap at boot: ~57 KB (after BUG-083 fix — 16 KB stack now properly allocated)
- httpd stack: 16 KB (uniform across all boards)
- min_free_heap under load: ~29 KB (from v7.6.9.5 stress test)
- Removing aggregator code (disabled via `AGGREGATOR_ENABLED` guard) saves: measure with Phase VX data
- Key question: does removing aggregator code free enough heap to make the C3 comfortable as a standalone, or is PSRAM still needed for non-trivial sensor counts?

**Standalone on C6 (RISC-V, 512 KB SRAM, no PSRAM):**
- 512 KB SRAM vs C3's 400 KB → ~112 KB more SRAM
- Peak httpd stack usage will be similar to C3 (~3,400 B) since both are RISC-V — no architecture penalty
- Phase VX measurements will show actual free_heap — compare C6 standalone to S3 satellite

The board selection guide's use-case matrix should include a "Standalone" column populated with Phase VX measurements.

---

## Board Selection Guide — Expansion Scope

The multi-phase planning session should produce or commission an expanded board selection guide. The expansion goes beyond adding rows — it needs analytical depth:

**Use-case matrix requirements:**

1. **Per-chip measured data** (from Phase VX `board-measurement-log-v7.6.10.md`):
   - Boot free_heap, min_free_heap under load, httpd stack watermark
   - Derived: available heap for history buffers after subtracting WiFi/BT/ESPHome/stack overhead

2. **Derived capability limits per board:**
   - Max persistent metrics = `(available_heap - safety_floor) / 804` (from capacity study §1)
   - Max sensors = max_persistent_metrics / avg_metrics_per_sensor (typically 2–3)
   - Whether the board can serve as standalone (no aggregator overhead)

3. **PSRAM impact analysis:**
   - S3 SuperMini (2 MB) vs S3 DevKitC (8 MB) — how much does PSRAM size matter?
   - Can 2 MB PSRAM handle aggregator role? How many satellites?
   - PSRAM scaling rule from architecture notes: no PSRAM → satellite only; 2 MB → max 4 satellites; 4 MB+ → max 8

4. **Flash impact analysis:**
   - 4 MB vs 16 MB — what changes? (Larger NVS partition → more history days)
   - C6 SuperMini (4 MB) vs C6 DevKitC (16 MB) — concrete comparison

5. **Forward-looking guidance:**
   - All future Espressif chips are RISC-V — Xtensa is end-of-line
   - C6 is the natural C3 successor for satellites (512 KB SRAM, WiFi 6, Zigbee)
   - When to buy which board for which deployment scenario

---

## Current State Summary Updates

The original prompt asks the advisor to produce a "Current State Summary." Add these items:

- **Uniform httpd stack:** All boards run 16 KB httpd stack via local component override. Peak usage is ~3,400 B on both RISC-V and Xtensa architectures (BUG-083 corrected the false RISC-V vs Xtensa divergence).
- **BUG-082 is open:** csv.reserve≠truncate, WROOM history crash with large NVS, deferred to Phase 7
- **BUG-083 is closed:** C3 template missing external_components, fixed in v7.6.9.5
- **ESPHome version:** 2026.4.0 (if VX completed upgrade) or 2026.2.1 (if not yet upgraded)
- **Board fleet:** 3 production + up to 4 test boards (if VX completed onboarding)
- **Phase V closed with 5 additional mitigation steps** beyond the original plan (v7.6.9.1–v7.6.9.5). v7.6.9.6 was originally planned but dropped after the Cloudflare polling issue self-resolved (BUG-078 fix in v7.6.0.1 eliminated the 401→500 mapping; browser native auth dialog handles credentials).
- **Dashboard auth UX:** Browser shows native Basic Auth dialog when polling auth-gated endpoints. A unified proactive auth flow is planned for Phase VX as a final step before Phase 7.

---

_End of multi-phase planning session supplement._
