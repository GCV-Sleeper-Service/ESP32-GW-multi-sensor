# Session Handoff — v7.6.10.3: Capacity Study and Board Selection Guide Update

_Date: 2026-04-22_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.10.2 COMPLETE (measurements collected). Ready for documentation update._
_Type: Claude advisory session — NOT an agent prompt. Deliverables are zip archives._

---

## Purpose

Read the measurement log and produce updated versions of two documents:
1. `Docs/phase-V-capacity-study.md` — expanded with all board data
2. `Docs/esp32-board-selection-guide.md` — expanded with measured data and decision matrix

---

## Required Reading

1. `Docs/board-measurement-log-v7.6.10.md` — the measurement dataset (must be populated)
2. `Docs/phase-V-capacity-study.md` — current capacity study
3. `Docs/esp32-board-selection-guide.md` — current board selection guide
4. `prompts/handoff/phaseVX/phaseVX-sprint-assessment.md` — board spec corrections

---

## Capacity Study Updates (`Docs/phase-V-capacity-study.md`)

1. Expand the executive summary table with all 6 boards (3 existing + 3 new)
2. Update the SRAM breakdown section with per-board measured figures
3. Add new subsection: **"§X — Per-Board Stack and Heap Measurements (Phase VX)"** with the full dataset from the measurement log
4. Revise the "Max persistent metrics (safe heap)" column using actual `free_heap` / `min_free_heap` measurements
5. Add PSRAM scaling observations:
   - S3 SuperMini 2 MB PSRAM vs S3 DevKitC 8 MB PSRAM — how much does PSRAM size affect usable heap?
   - C5 WROOM-1U 8 MB PSRAM — similar to S3 or different (RISC-V vs Xtensa)?
6. Note: C5 has 384 KB silicon SRAM (less than C3's 400 KB) but 8 MB PSRAM — describe the trade-off

---

## Board Selection Guide Updates (`Docs/esp32-board-selection-guide.md`)

1. Expand §1 chip family table with C6 and C5 measured data (update ESPHome support status to ✅ for C6 since it compiles)
2. Update §2 satellite/aggregator recommendation tables with new boards
3. Add comprehensive use-case matrix:

| Board class | PSRAM | Flash | Max persistent metrics | Max sensors | Standalone viable | Satellite viable | Aggregator viable | Notes |
|---|---|---|---|---|---|---|---|---|

Populate from measured data with specific guidance:
- What can a C6 (512 KB SRAM, no PSRAM) do vs a C3 (400 KB, no PSRAM)?
- What does 2 MB PSRAM buy (S3 SuperMini) vs 8 MB (S3 DevKitC, C5)?
- Is the C5 a viable aggregator despite being single-core?
- Which boards are the best value for satellite deployment?

4. Update the "Summary Decision Matrix" with all 6 boards
5. Update ESPHome version references from 2026.2.1 to 2026.4.1

---

## Deliverable Format

Produce updated document files as a zip archive. The operator will unzip directly over the working copy.

```
delivery/
  Docs/
    phase-V-capacity-study.md          (updated)
    esp32-board-selection-guide.md     (updated)
```

---

## Version and Changelog

This step does NOT bump VERSION or create a PR — the document updates are folded into the Phase VX closure or the next code PR. If the operator prefers a separate docs PR, bump VERSION to 7.6.10.3 and add a changelog entry.

---

_End of session handoff document._
