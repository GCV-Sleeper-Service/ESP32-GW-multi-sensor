# Session Handoff — v7.6.6.1: Establish Assembly Script and Baseline

_Date: 2026-04-08_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.6.0 COMPLETE. provision.sh full pipeline automation merged. Entering fragment creation._

---

## Project State Summary

**v7.6.6.0 is complete.** `provision.sh` now runs the full 8-step regeneration pipeline automatically on board switch. `--dry-run` support added. Step 0 placeholder for assembly script is present (no-op). `main` is green.

This step creates the Phase Y verification scaffold: 8 fragment source files in `firmware/core/`, the assembly script `scripts/assemble-sensor-history.sh`, and verifies byte-for-byte SHA-256 identity of the reassembled output.

---

## Phase Y Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.6.0 | Pre-step: provision.sh full pipeline automation | ✅ Complete |
| **v7.6.6.1** | **Establish assembly script + 8 fragments + SHA-256 baseline** | **⬅️ Current** |
| v7.6.6.2 | Wire assembly into pipeline + fragment-level preflight | Pending |
| v7.6.6.3 | Validate edit-fragment workflow end-to-end | Pending |
| v7.6.6.4–v7.6.6.8 | Validation, device tests, closure | Pending |

---

## v7.6.6.1 Scope

### What this step does

1. Create `firmware/core/` directory
2. Extract 8 fragment files from `dashboard/sensor_history_multi.h` using exact line ranges
3. Create `scripts/assemble-sensor-history.sh` with `--write`, `--check`, `--list`, `--dry-run` modes
4. Activate the assembly step in `provision.sh` (replace no-op placeholder from v7.6.6.0)
5. Add `firmware_core_fragments_exist` check to `scripts/preflight.sh`
6. Verify SHA-256 identity: assembled output matches committed file

### Fragment manifest

| # | Fragment | Lines | Count |
|---|----------|-------|------:|
| 1 | `config.h` | 1–95 | 95 |
| 2 | `data-model.h` | 96–555 | 460 |
| 3 | `nvs-persistence.h` | 556–1169 | 614 |
| 4 | `deferred-management.h` | 1170–1219 | 50 |
| 5 | `ping-adapter.h` | 1220–1387 | 168 |
| 6 | `aggregator-runtime.h` | 1388–2278 | 891 |
| 7 | `web-handler.h` | 2279–4284 | 2,006 |
| 8 | `registration.h` | 4285–4325 | 41 |

**Total: 4,325 lines** (must match `wc -l dashboard/sensor_history_multi.h`)

### Acceptance criteria

- [ ] All 8 fragment files exist in `firmware/core/`
- [ ] Fragment line counts sum to 4,325
- [ ] `bash scripts/assemble-sensor-history.sh --check` exits 0 (SHA-256 match)
- [ ] `bash scripts/assemble-sensor-history.sh --list` prints all 8 fragments with correct counts
- [ ] Assembly step activated in `provision.sh` (no longer no-op)
- [ ] `bash scripts/preflight.sh` passes (all existing checks + new fragment existence check)
- [ ] `esphome config firmware/esp32-c3-multi-sensor.yaml` validates
- [ ] All Playwright tests pass across all 4 fixture sets
- [ ] No behavior change — `sensor_history_multi.h` content is identical

---

## Pre-merge Checklist for v7.6.6.1

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] Pre-extraction: verify `wc -l dashboard/sensor_history_multi.h` = 4,325
- [ ] Pre-extraction: verify boundary landmarks with `grep -n` (line 96, 556, 1170, 1220, 1388, 2279, 4290)
- [ ] Post-extraction: verify `wc -l firmware/core/*.h | tail -1` = 4,325 total
- [ ] Post-extraction: verify `diff dashboard/sensor_history_multi.h <(cat firmware/core/config.h firmware/core/data-model.h firmware/core/nvs-persistence.h firmware/core/deferred-management.h firmware/core/ping-adapter.h firmware/core/aggregator-runtime.h firmware/core/web-handler.h firmware/core/registration.h)` exits 0
- [ ] Assembly script `--check` passes
- [ ] No dashboard source or build script changes (other than assembly script creation)

---

## Critical Rules Relevant to v7.6.6.1

| # | Rule | Why Relevant |
|---|------|-------------|
| 4 | Preflight must pass | New fragment existence check added |
| 5 | CI-exact `FIXTURE_SET=` runs | Full acceptance gate |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 37 | Full regeneration pipeline | Assembly step now active in pipeline |

---

## Risk: Low

Pure file splitting with no code changes. SHA-256 identity gate catches any content mismatch.

---

## Workflow for v7.6.6.1

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for this step is open. If not, **open a NEW coding agent session** and paste the prompt
3. Agent verifies line count and boundary landmarks
4. Agent extracts fragments using `sed -n` or `head`/`tail`
5. Agent creates assembly script
6. Agent verifies SHA-256 identity
7. Review the PR — verify line counts, identity gate, preflight
8. Merge, tag `v7.6.6.1`
9. Produce consolidated audit (see Post-PR Closure section below)
10. Check and update session handoff for v7.6.6.2 if necessary
11. Check and update agent's prompt for v7.6.6.2 if necessary

---

## Post-PR Closure Deliverables for v7.6.6.1

### 1. Consolidated Audit

**File:** `prompts/phaseY/v7.6.6.1-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseY/pr-audit-question-template-phaseY.md`

Step-specific supplement:
- Do all 8 fragments exist with correct line counts?
- Does SHA-256 identity pass?
- Is the assembly script's MODULES array in the correct order?
- Were any boundary landmarks off from the plan? If so, document the actual ranges.

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`
- `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md`

---

## Device Testing

**Not applicable.** No firmware behavior changes. Assembly identity gate confirms code equivalence.

---

_End of session handoff document._
