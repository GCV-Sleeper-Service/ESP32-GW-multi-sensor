# Session Handoff — v7.6.9.5: C3 httpd Stack Watermark Investigation

_Date: 2026-04-19_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.9.4 COMPLETE (PR#193 + PR#194 merged). This is the second of three Phase V mitigation steps; actual Phase V closure is v7.6.9.6._

---

## Project State Summary

**v7.6.9.4 is complete.** The heap-adaptive history cap and boot sequencing shipped in PR#193/PR#194. BUG-082 was discovered during v7.6.9.4 device validation: `csv.reserve()` does not truncate — the NVS scan loop grows the string past the reserved cap, causing WROOM boards with large NVS history to still crash on history fetch. BUG-082 is deferred to Phase 7 (chunked HTTP streaming replaces single-response CSV building entirely). LESSON-OPS-127 documents the `std::string::reserve()` semantics.

**This step (v7.6.9.5) investigates the C3 httpd stack watermark**, which was measured at 636 bytes on v7.6.9.4 firmware — 3.9% of the 16 KB patched stack. The WROOM and S3 (both Xtensa architecture) show 13044 and 13760 bytes respectively, confirming the deficit is architecture-specific: the C3's RISC-V core uses larger stack frames per function call than Xtensa's register-windowed architecture.

---

## Phase V Progress Table

| Version | Scope | Status |
|---|---|---|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete |
| v7.6.7.3 | Operational telemetry in /api/status | ✅ Complete (PR #179) |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status split | ✅ Complete |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR (60 KB fixed cap) | ✅ Complete |
| v7.6.8.2 | V2-H/I/J: Gated optimisations | ✅ Complete |
| v7.6.9.0 | V3-A: Device card cleanup (+ hotfix 1, 2) | ✅ Complete (PR #183) |
| v7.6.9.1 | V3-B/C: Hostname/IP + CSV role | ✅ Complete |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | ✅ Complete |
| v7.6.9.3 | V3-F: Struct audit (conditional) | ✅ Complete (preliminary Phase V closure) |
| v7.6.9.4 | V4: Heap-adaptive history cap + boot sequencing (#139 partial) | ✅ Complete (PR#193 + PR#194) |
| **v7.6.9.5** | **V5: C3 httpd stack watermark investigation** | **⬅️ Current** |
| v7.6.9.6 | V6: Polling telemetry — narrow /api/status un-strip + SEC-ADR amendment (**Phase V actual closure**) | 🔜 Queued |

---

## v7.6.9.5 Scope

### Why this step exists

Post-v7.6.9.4 device telemetry (2026-04-19, all boards on v7.6.9.4 firmware, ~15 hours uptime) shows a dangerous stack margin on the C3:

| Board | Architecture | `httpd_stack_watermark_bytes` | Headroom % | `free_heap` | `min_free_heap` |
|---|---|---|---|---|---|
| ESP32-C3 (189) | RISC-V | **636** | **3.9%** | 69896 | 52592 |
| WROOM-32D (190) | Xtensa LX6 | 13044 | 79.6% | 37032 | 13616 |
| ESP32-S3 (191) | Xtensa LX7 | 13760 | 84.0% | 52460 | 8434304 (PSRAM) |

The 636-byte watermark means the C3's httpd task stack has been within 636 bytes of overflowing during normal operation. Standard embedded practice requires a minimum of 10–15% headroom (1600–2400 bytes on a 16 KB stack). At 3.9%, any slightly deeper call chain (e.g., concurrent handler execution, interrupt coincidence) could overflow the stack and crash the board.

The 20× discrepancy between C3 (636 B) and WROOM/S3 (~13 KB) running identical firmware is explained by the architecture difference: Xtensa register windows keep function arguments and local variables in registers without pushing to the stack, while RISC-V's conventional ABI pushes callee-saved registers at every call boundary. A typical stack frame is 48–96 bytes on RISC-V vs 16–32 bytes on Xtensa for the same function.

### What this step does

1. **Stress test script:** delivers `scripts/stress-test-httpd-stack.sh` — a reproducible concurrent-request protocol targeting the C3 board to find the true stack floor under load.
2. **C3 stack bump:** conditionally increases the httpd task stack from 16384 to 20480 bytes for RISC-V targets (`CONFIG_IDF_TARGET_ARCH_RISCV`). Xtensa targets (WROOM, S3) stay at 16384.
3. **Patch script update:** `scripts/patch-esphome-httpd-stack.sh` updated to apply the conditional stack sizing and verify it on `--check`.
4. **Docs:** changelog entry, LESSON-OPS entry documenting the RISC-V vs Xtensa stack depth difference, BUG entry if the stress test reveals a new finding.
5. **Device testing:** operator runs the stress test on the bumped C3 firmware. Acceptance gate: stress-test watermark ≥ 2000 bytes.

### What this step does NOT do

- No handler refactoring or call-chain flattening — scope is strictly the stack bump
- No changes to `HistoryBuffer`, `SegmentSnapshot`, NVS format, partition tables — Phase 7 scope
- No changes to `handle_status_` or `handle_status_full_` field lists — v7.6.9.6 scope (SEC-ADR RV-03)
- No changes to response framing, chunked/windowed streaming — Phase 7 scope
- No changes to `dashboard/` source files — no dashboard work in this step
- No fragment boundary changes (Rule 62)
- No SEC-ADR changes
- No changes to auth posture on any endpoint

### Files modified

- `firmware/local_components/web_server_idf/web_server_idf.cpp` — conditional stack size (line 124)
- `firmware/local_components/web_server_idf/PATCH_INFO.md` — document the conditional
- `scripts/patch-esphome-httpd-stack.sh` — updated patch insertion and `--check` verification
- `scripts/stress-test-httpd-stack.sh` — new file (stress test protocol)
- `Docs/changelog.md` — v7.6.9.5 entry
- `Docs/lessons/firmware.md` — LESSON-OPS entry on RISC-V vs Xtensa stack depth
- `Docs/lessons/index.md` — update lessons index with new entry
- `Docs/phase-V-capacity-study.md` — update task stack table with architecture-conditional values and measured data
- `VERSION` — bump to `7.6.9.5` via `scripts/bump-version.sh`
- Generated artifacts regenerated via pipeline, never hand-edited

### Acceptance criteria

See `prompts/phaseV/v7.6.9.5-agent-prompt-gpt-codex.md` §6 for the full checklist.

---

## Pre-merge Checklist for v7.6.9.5

- [ ] Read the coding agent prompt (`prompts/phaseV/v7.6.9.5-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Confirm v7.6.9.4 is merged (PR#193 + PR#194) and `VERSION` reads `7.6.9.4`
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates in §5 verified
- [ ] All acceptance criteria in §6 met
- [ ] ⛔ PRE-PR GATE in §7 passes
- [ ] Stress test on C3 with bumped firmware complete — watermark ≥ 2000 bytes (§8)
- [ ] Smoke test on WROOM and S3 complete — no heap regression
- [ ] Session log created with device test results filled in (not placeholders)
- [ ] Instruction Compliance Output table in PR description

---

## Critical Rules Relevant to v7.6.9.5

| # | Rule | Why Relevant |
|---|---|---|
| 40 | httpd stack is hardcoded by HTTPD_DEFAULT_CONFIG() at 4 KB | This step modifies the patch that overrides it |
| 41 | CONFIG_HTTPD_STACK_SIZE has no effect | Do not add to board profiles as a "fix" |
| 42 | httpd stack must be patched via local component override | The bump goes in the same local override |
| 47 | Never edit `dashboard/dashboard.js` / `dashboard/dashboard.html` directly | No dashboard work in this step |
| 58 | Never edit `dashboard/sensor_history_multi.h` directly | No dashboard work in this step |

Additional constraints:
- **SEC-ADR RV-03:** no changes to `/api/status` response body — v7.6.9.6 scope
- **Phase V invariant:** no Phase 7 work in Phase V — storage engine, NVS format, response chunking are off-limits
- **LESSON-OPS-101:** deferred task pattern for NVS-heavy handlers — this step does not add new handlers, but the deferred task pattern must not be disturbed
- **Hard floor:** httpd stack size must never be set below `measured_peak + 2048 B` (per V2-J decision table precedent)

---

## Risk: LOW

- The code change is 5 lines in a single file (`web_server_idf.cpp` line 124) — a conditional replacing a constant.
- Xtensa boards (WROOM, S3) are unchanged — their stack stays at 16384 with 13 KB+ headroom.
- The patch script update is mechanical — same pattern, updated value and check.
- The stress test script is a new file with no impact on firmware or dashboard.
- No functional changes to any handler, no data path changes, no auth changes.
- Regression risk: Playwright cannot validate stack sizing (mock server has no FreeRTOS stack). Validation is device-only via the stress test.

---

## Workflow for v7.6.9.5

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt (or use Claude two-step)
3. Agent implements per §5 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Agent produces changelog + LESSON-OPS entry
6. Review the PR — verify scope, acceptance criteria, Critical Rules
7. Send universal reviewer prompt + v7.6.9.5 supplement to external reviewers
8. **Device testing gate before merge:** flash C3 with bumped firmware, run `scripts/stress-test-httpd-stack.sh`. Record minimum watermark. Gate: ≥ 2000 bytes.
9. Flash WROOM and S3. Smoke test: `free_heap` not regressed (WROOM stays ≥ 33 KB), all endpoints work.
10. Fill in §8 device test table in session log with measured values.
11. Merge, tag `v7.6.9.5`
12. Produce consolidated audit
13. Update #165 on GitHub: post comment with stack investigation findings
14. (Do NOT run Phase V closure analysis — that waits for v7.6.9.6)

---

## Device Testing

| Board | IP | Role |
|---|---|---|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite — **primary investigation target** |
| ESP32-WROOM-32D | `192.168.120.190` | Satellite — smoke test only |
| ESP32-S3-DevKitC1-N16R8 | `192.168.120.191` | Aggregator — smoke test only |

### C3 stress test protocol (primary gate)

1. Flash C3 with v7.6.9.5 firmware (20 KB httpd stack)
2. Wait 2 minutes for boot stabilisation
3. Run `bash scripts/stress-test-httpd-stack.sh` (5 waves × 8 concurrent requests, 30 s between waves)
4. Record minimum watermark observed across all waves
5. **Acceptance gate: minimum watermark ≥ 2000 bytes**

### All-board smoke test

- [ ] C3 `/api/status/full` returns 200 with correct `version`
- [ ] C3 `httpd_stack_watermark_bytes` ≥ 2000 under stress
- [ ] C3 `/history/office/temp` returns 200, no crash
- [ ] WROOM `/api/status/full` returns 200, `free_heap` ≥ 33000
- [ ] WROOM `/history/office/temp` does not crash (BUG-082 known limitation — 503 or truncated CSV acceptable)
- [ ] S3 `/api/status/full` returns 200, all fields present
- [ ] `/api/status` still returns only `{ok, role, id}` on all boards (SEC-ADR RV-03 intact)
- [ ] No watchdog reboots on any board during 5-minute post-test soak

**If C3 stress test watermark < 2000:** do NOT merge. Open a new agent session to bump the stack to 24576 (24 KB) and retest. Document the finding.

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.9.5-PR<NN>-consolidated-audit-and-lessons.md`

Use template: `prompts/phaseV/consolidated-audit-template-phaseV.md`
Use PR audit questions: `prompts/phaseV/pr-audit-question-template-phaseV.md`

### 2. New LESSON-OPS Entry

Topic: RISC-V vs Xtensa httpd stack depth. Key points:
- Xtensa register windows dramatically reduce per-frame stack usage compared to RISC-V
- Same firmware on ESP32-C3 (RISC-V) uses ~4.7× more httpd stack than ESP32/ESP32-S3 (Xtensa)
- httpd stack sizing must be architecture-conditional for multi-target firmware projects
- A single stack size safe for all architectures wastes significant RAM on Xtensa targets

### 3. Issue #165 Update

On GitHub:
- Post comment: "Stack watermark investigation in v7.6.9.5 (PR #NN). Findings: C3 RISC-V peak httpd stack usage ~15748 B (watermark 636 B on 16 KB stack) vs Xtensa ~3340 B (watermark 13044 B). Root cause: RISC-V ABI pushes more state per call frame. Fix: conditional stack bump to 20 KB for RISC-V targets. Stress test confirms watermark ≥ 2000 B post-fix."

### 4. Phase V Closure

- Fill in `prompts/handoff/phaseV-results.md` v7.6.9.5 row
- Do NOT run Phase V closure analysis — that waits for v7.6.9.6 (the actual closure step)
- Do NOT update `phaseV-conclusion-assessment.md` — v7.6.9.6 handles this

---

## Context That Carries Forward

### To v7.6.9.6 (next step — Cloudflare polling telemetry + SEC-ADR amendment)

- v7.6.9.5 stack investigation is complete. C3 httpd stack bumped to 20 KB for RISC-V. Xtensa boards unchanged at 16 KB.
- The C3 watermark under stress was [FILL IN from §8 results] bytes — above the 2000-byte acceptance floor.
- v7.6.9.6 is the actual Phase V closure step. It delivers the narrow SEC-ADR RV-03 amendment to re-expose `free_heap` + `uptime_seconds` on public `/api/status`, fixing the Cloudflare Tunnel polling 500 errors.
- After v7.6.9.6 merges: run the Pre-Closure Readiness Assessment, fix any gaps, then run Phase V closure documents.

### Post-Phase V sequence (planned)

After Phase V formal closure, three work streams follow before Phase 7 starts:

1. **Phase VX (v7.6.10.x) — Board Onboarding Sprint:**
   - Upgrade ESPHome 2026.2.1 → 2026.4.0 (re-run `patch-esphome-httpd-stack.sh`)
   - Create board profiles for S3 SuperMini (2MB PSRAM/4MB flash), C6 SuperMini, C6 DevKitC-1, C5
   - Create partition tables, update `provision.sh`
   - Flash all 7 boards, run `stress-test-httpd-stack.sh` on each, collect telemetry
   - Update capacity study with all-board measurements
   - Update board selection guide with comprehensive chip × memory × use-case chart
   - Prompt: `prompts/handoff/phaseVX-board-onboarding-sprint-prompt.md`

2. **Phase VY (v7.6.11.x) — Multi-Phase Planning Session:**
   - Reads: updated capacity study, expanded board selection guide, Phase V closure docs, all LESSON-OPS
   - Produces: Phase 7 review (adds stress test gate + chunked streaming step), Phase 8/9/10 scoping
   - Prompt: `prompts/handoff/multi-phase-planning-prompt.md` (with supplement from v7.6.9.5)

3. **Phase 7 (v7.7.x) — Per-Device NVS Persistence Engine:**
   - Begins only after VX and VY complete
   - Phase 7 plan must include: httpd stack stress test after adding new handlers, chunked HTTP streaming for history responses (missing from current plan — flagged by v7.6.9.5 investigation)

### To Phase 7 planning (gaps identified by v7.6.9.5)

- Phase 7 plan (`Docs/v7.7-implementation-plan.md`) has NO mention of httpd stack watermark validation. Phase 7 adds 3+ new httpd handlers; each deepens the C3 call chain. The multi-phase planning session must add a stress test gate.
- Phase 7 plan does NOT include chunked HTTP streaming for history responses. BUG-082 says "fix deferred to Phase 7 chunked HTTP streaming" but the plan's 12 steps are all NVS engine work. The multi-phase planning session must add a chunked streaming step.
- BUG-082 (csv.reserve≠truncate) remains the primary Phase 7 driver — WROOM history fetch still crashes with large NVS history.
- Issue #139 stays open until Phase 7 delivers the full fix.

---

_End of session handoff document._
