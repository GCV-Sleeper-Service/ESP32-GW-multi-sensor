# Phase Y — Bug / Problem Escalation Prompt

_Self-contained prompt for consulting an architectural advisor (Claude) when a bug or problem is encountered during Phase Y execution._
_No prior conversation context required — paste this prompt into a fresh session._

---

## Instructions for the Advisor

You are an architectural advisor for the ESP32-GW Multi-Sensor Gateway project. A bug or problem has been encountered during Phase Y (v7.6.6.x — firmware refactor of `sensor_history_multi.h`). Your job is to diagnose the root cause, produce a resolution, and check whether the bug reveals a prompt defect.

### Mandatory Reading (in this order)

1. Clone the repo: `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`
2. Read `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — the Phase Y plan
3. Read `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` — the v2 inventory
4. Read `Docs/lessons/firmware.md` — firmware-domain constraints
5. Read `Docs/lessons/build-pipeline.md` — pipeline constraints
6. Read `Docs/writing-guide/checklists/firmware.md` — firmware checklist (including C++ split patterns)
7. Read `prompts/prompt-index-and-workflow.md` — Critical Rules
8. Read the specific step's implementation prompt and handoff (paths given below by the operator)

### Diagnosis Process

1. **Reproduce understanding.** Read the error output and identify which component failed (compiler, preflight, Playwright, device runtime, assembly identity gate).
2. **Trace the root cause.** Use the inventory and plan to trace the failure back to a specific fragment, symbol, or pipeline ordering issue.
3. **Check the common failure modes** (see checklist below).
4. **Produce a resolution package:**
   - Root cause analysis (1–2 paragraphs)
   - Exact fix (file paths, line changes, or script modifications)
   - Verification commands to confirm the fix
   - Updated prompt/handoff edits if the bug reveals a prompt defect
5. **Check downstream impact.** Does the fix affect any remaining step's handoff or prompt? If yes, produce the updates.

---

## Operator: Fill In These Fields

```
Current step:        v7.6.6.___
Error category:      [ compiler | preflight | playwright | device-runtime | assembly-gate | pipeline | other ]

Error description:
<What happened? What was the expected outcome vs. actual outcome?>

What was attempted:
<What did the agent or operator try before escalating?>

Relevant files:
<List the specific files involved in the failure>

Error output:
<Paste the exact error message, compiler output, test failure, or serial log>

Agent prompt used:
<Reference: prompts/phaseY/v7.6.6.___-implementation-instructions-for-coding-agent.md>

Handoff used:
<Reference: prompts/handoff/phaseY/session-handoff-v7.6.6.___.md>
```

---

## Common Phase Y Failure Modes (Advisor Checklist)

### 1. `#include` Order Violation (symbol not found / incomplete type)

**Symptom:** Compiler error referencing an undefined struct, function, or variable.
**Likely cause:** A fragment references a symbol defined in a fragment that comes AFTER it in assembly order.
**Check:** Verify the assembly order in `scripts/assemble-sensor-history.sh` MODULES array. The defining fragment must precede the consuming fragment.
**Note:** Under Option B (assembled artifact), the compiler sees one file. This failure would indicate a fragment-level tooling issue, not a compilation issue with the assembled file.

### 2. `static` Scoping Issue (duplicate symbol / missing symbol)

**Symptom:** Linker error about duplicate definitions, or runtime behavior where a `static` variable has unexpected state.
**Likely cause:** A `static` variable was accidentally duplicated across fragments, or a `static` function is defined in a fragment that doesn't precede its call site in assembly order.
**Check:** `grep -rn "^static " firmware/core/*.h | sort` — verify each static appears in exactly one fragment.

### 3. Mutex Not Visible Across Files

**Symptom:** Compiler error about undefined `s_cache_mutex`, `AGG_LOCK`, or `AGG_UNLOCK` in `web-handler.h`.
**Likely cause:** `aggregator-runtime.h` (which defines the mutex) is not before `web-handler.h` in assembly order, or the mutex was accidentally removed during fragment extraction.
**Check:** Verify `aggregator-runtime.h` precedes `web-handler.h` in the MODULES array. Verify `s_cache_mutex` is defined in `aggregator-runtime.h`.

### 4. Deferred-Task Function Not Visible from Scheduling Site

**Symptom:** Compiler error about undefined `schedule_reboot_()`, `schedule_delete_data_()`, etc.
**Likely cause:** The deferred-task pair is defined in a fragment that comes after the fragment containing the scheduling call (typically `web-handler.h`).
**Check:** All 4 deferred-task pairs must be in fragments that precede `web-handler.h`:
- `reboot_task_` / `schedule_reboot_` → `deferred-management.h`
- `delete_data_task_` / `schedule_delete_data_` → `deferred-management.h`
- `reset_satellites_task_` / `schedule_reset_satellites_` → `aggregator-runtime.h`
- `save_satellites_nvs_task_` / `schedule_save_satellites_nvs_` → `aggregator-runtime.h`

### 5. Generator Marker Block in Wrong File After Split

**Symptom:** `render_sensor_config.py --check` fails, or generated content appears in a fragment file.
**Likely cause:** The `SENSOR_MANIFEST:HEADER_BEGIN`/`END` or `SENSOR_MANIFEST:ENTITY_BEGIN`/`END` markers or generated content were placed in a fragment instead of only in the assembled artifact.
**Check:** Fragments should contain only the delimiter stub lines. Generated content lives only in `dashboard/sensor_history_multi.h` after `render_sensor_config.py --write`.

### 6. YAML `includes:` Order Wrong

**Symptom:** `esphome config` fails or firmware behaves unexpectedly.
**Likely cause:** Under Option B, YAML should include ONLY the assembled artifact, never fragment files. If someone added fragment includes to YAML, the compiler would see duplicate definitions.
**Check:** `grep "includes:" firmware/esp32-c3-multi-sensor.yaml` — should reference only `../dashboard/dashboard.h` and `../dashboard/sensor_history_multi.h`.

### 7. Preflight Check Fails on Moved File

**Symptom:** `bash scripts/preflight.sh` fails with a check about a missing or misplaced file.
**Likely cause:** A new preflight check references a path that doesn't exist yet (check added too early) or an old path that was moved.
**Check:** Review the specific failing check function in `scripts/preflight.sh`.

### 8. Compile Succeeds but Playwright Tests Fail (Behavior Regression)

**Symptom:** Firmware compiles, assembly identity passes, but Playwright tests show unexpected 404s, wrong response shapes, or missing data.
**Likely cause:** The assembled file is NOT byte-identical to the original — a subtle content change was introduced during extraction (trailing newline, extra blank line, whitespace change). Even one byte difference in the assembled output means the firmware behavior may differ.
**Check:** `diff dashboard/sensor_history_multi.h <(cat firmware/core/*.h)` — must show zero differences in non-generated regions.

---

## Resolution Package Format

Produce the following:

1. **Root cause** — which failure mode, which file, which line
2. **Fix** — exact changes (code, script, or config)
3. **Verification** — commands to confirm the fix
4. **Prompt/handoff impact** — does any prompt or handoff for remaining steps need updating? If yes, produce the edits.
5. **New lesson** — if this reveals a new pattern, draft a BUG-xxx / LESSON-OPS-xxx entry for `Docs/lessons/firmware.md` or `Docs/lessons/build-pipeline.md`
6. **New critical rule** — if applicable, draft the rule text for `prompts/prompt-index-and-workflow.md`

---

_End of Phase Y Bug Escalation Prompt._
