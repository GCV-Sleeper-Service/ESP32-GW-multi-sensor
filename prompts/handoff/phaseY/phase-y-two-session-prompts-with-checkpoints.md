# Phase Y — Two-Session Execution Prompts (with Inline Verification Gates)

_All 9 steps. Each step has two prompts:_
_Step 1 = agent session (does the work). Step 2 = review session (checks it)._
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Date: 2026-04-09_
_Update: Added inline verification gates (⛔ CHECKPOINT blocks) to reduce fix cycles._

---

## Multi-LLM Execution Preamble

_If running on GPT, Codex, or any non-Claude/non-Copilot agent, prepend this before each Step 1 prompt:_

```
═══════════════════════════════════════════════════════════════════
MULTI-LLM EXECUTION PREAMBLE
═══════════════════════════════════════════════════════════════════

You are executing an implementation prompt designed for a coding agent with
file system access and shell command execution. Follow the instructions
literally. Do NOT compress, summarize, or skip any reading steps.

CRITICAL RULES:
1. Read every file in §1 COMPLETELY and IN ORDER before changes.
2. Do NOT reorganize implementation steps. The order is deliberate.
3. When you hit a ⛔ CHECKPOINT, STOP and run every command listed.
   If any fails, fix it before continuing. Do NOT skip checkpoints.
4. "Do NOT" instructions are absolute — from real bugs that caused
   hardware damage or broke CI.
5. All POST: curl -d 'a=1' -X POST [url]. NEVER JSON content type.
6. S3 board: use GENERATED YAML, never committed C3 template.
7. After aggregator testing: run provision.sh satellite before PR.
8. Produce ALL §9 deliverables before closing session.
═══════════════════════════════════════════════════════════════════
```

---
---

# v7.6.6.0 — Pre-Step: `provision.sh` Full Pipeline Automation

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md` — session context.
2. Read `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§1).
   Pay special attention to:
   - `scripts/provision.sh` — understand `run_render()`, `print_workflow()`, and the three
     `activate_*()` functions. You will replace `print_workflow()` with `run_full_pipeline()`.
   - `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §3 v7.6.6.0 for the
     exact `run_full_pipeline()` contract and step array.
   - `prompts/prompt-index-and-workflow.md` — Critical Rules #37 (pipeline) and #49 (provision.sh).

Then implement in this order:

  1. Add `run_full_pipeline()` to `provision.sh` with the exact step array from the plan
  2. Add `require_node()` and `require_npm_deps()` dependency pre-checks
  3. Add Step 0 placeholder for `assemble-sensor-history.sh` (no-op comment until v7.6.6.1)

---
⛔ CHECKPOINT A (after adding run_full_pipeline):
Run:
  grep -c 'eval' scripts/provision.sh — expected: 0 (no eval usage)
  grep -A2 'status)' scripts/provision.sh — verify status case does NOT call run_full_pipeline
  grep 'run_full_pipeline' scripts/provision.sh | wc -l — verify function exists
If ANY check fails: STOP. Fix before continuing.
---

  4. Add `--dry-run` support to all board modes
  5. Replace `print_workflow()` calls with `run_full_pipeline()` calls in activate functions

---
⛔ CHECKPOINT B (after wiring pipeline into board modes):
Run:
  git diff --name-only — must show ONLY scripts/provision.sh (no other files yet)
  bash scripts/provision.sh --dry-run satellite 2>&1 | head -20 — must show [DRY-RUN] prefix, no file changes
If ANY check fails: STOP. Fix before continuing.
---

  6. Verify `status` remains non-mutating
  7. Add LESSON-OPS entry to `Docs/lessons/operations.md`
  8. Version bump: `bash scripts/bump-version.sh 7.6.6.0`
  9. Full pipeline validation for satellite, aggregator, and wroom modes
  10. Changelog entry
  11. Full Playwright suite across all four fixture sets
  12. `bash scripts/preflight.sh`

---
⛔ PRE-PR GATE (before creating PR):
Run:
  git diff --name-only — verify ONLY allowed files: provision.sh, changelog, lessons, version files
  bash scripts/preflight.sh — all checks pass
  FIXTURE_SET=3sensor npx playwright test --project=chromium — green
  FIXTURE_SET=mixed npx playwright test --project=chromium — green
  FIXTURE_SET=system npx playwright test --project=chromium — green
  FIXTURE_SET=aggregator npx playwright test --project=chromium — green
  grep "v7.6.6.0" Docs/changelog.md — entry exists
If ANY check fails: fix before creating PR. Do NOT create a PR with failing checks.
---

  13. Session log + Instruction Compliance Output table

Follow all rules listed under "Critical Rules" in §7 of the implementation instructions.

Do NOT modify `sensor_history_multi.h`, any firmware file, or any test file.
Do NOT use `eval` for pipeline step execution.
Do NOT make `status` mutating.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md` to understand the current stage and deliveries.

After the agent creates its PR, open a second fresh session and ask for a review
specifically checking:

  • Pipeline ordering — does `run_full_pipeline()` match Critical Rule 37 exactly?
  • Assembly placeholder — Step 0 prints skip message, does NOT execute nonexistent script?
  • `--dry-run` — prints all steps with `[DRY-RUN]` prefix, zero filesystem changes?
  • `status` non-mutating — does NOT call `run_full_pipeline()`?
  • No `eval` usage — direct command execution only?
  • Dependency pre-checks — `require_node()` and `require_npm_deps()` called before pipeline?
  • Error handling — failed step exits with clear message identifying which step failed?
  • CI-safe warning preserved for non-satellite modes?
  • All board modes (satellite, aggregator, wroom) run full pipeline?
  • No changes to firmware, tests, or `sensor_history_multi.h`?
  • `esphome config` validates? All Playwright tests pass (all 4 fixture sets)?

IMPORTANT: Once PR is merged, produce deliverables BEFORE closing the session.

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.0-PR<NN>-consolidated-audit-and-lessons.md`
  - Review and update `session-handoff-v7.6.6.1.md` and `v7.6.6.1-implementation-instructions-for-coding-agent.md`

Tag: `git tag -a v7.6.6.0 -m "Phase Y Pre-step: provision.sh full pipeline automation" && git push origin v7.6.6.0`

---
---

# v7.6.6.1 — Establish Assembly Script and Baseline

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md` — session context and fragment manifest.
2. Read `prompts/phaseY/v7.6.6.1-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§1).
   Pay special attention to:
   - `dashboard/sensor_history_multi.h` — the 4,325-line file being split. Verify boundary
     landmarks with `grep -n` (lines 96, 556, 1170, 1220, 1388, 2279, 4290).
   - `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §2.3 (fragment manifest
     with line ranges), §3 v7.6.6.1 (assembly script specification).

Then — before splitting — verify boundaries:

  a. `wc -l dashboard/sensor_history_multi.h` — must be 4325.
  b. Verify all 7 boundary landmarks with `grep -n`.
  c. Record baseline SHA-256.

Only after confirming, implement in this order:

  1. Create `firmware/core/` directory
  2. Extract 8 fragments using `sed -n` with exact line ranges from §5b

---
⛔ CHECKPOINT A (after fragment extraction):
Run:
  wc -l firmware/core/*.h | tail -1 — expected: 4325 total
  diff dashboard/sensor_history_multi.h <(cat firmware/core/*.h) — expected: exit 0 (identical)
If either fails: STOP. The line ranges are wrong. Re-check against §5b and fix before continuing.
---

  3. Verify: `wc -l firmware/core/*.h | tail -1` must show 4325 total
  4. Verify: `diff dashboard/sensor_history_multi.h <(cat firmware/core/*.h)` must exit 0
  5. Create `scripts/assemble-sensor-history.sh` from plan specification (--write/--check/--list/--dry-run)

---
⛔ CHECKPOINT B (after assembly script creation):
Run:
  bash scripts/assemble-sensor-history.sh --check — expected: exit 0
  bash scripts/assemble-sensor-history.sh --list — expected: 8 fragments with correct line counts
  grep 'strip_generated' scripts/assemble-sensor-history.sh — expected: function exists
If ANY fails: STOP. Fix the assembly script before wiring it into the pipeline.
---

  6. Activate assembly step in `provision.sh` (replace placeholder)
  7. Add `firmware_core_fragments_exist` check to `preflight.sh`
  8. Version bump: `bash scripts/bump-version.sh 7.6.6.1`
  9. Full pipeline, identity gate, Playwright suite
  10. Changelog entry + session log

---
⛔ PRE-PR GATE:
Run:
  git diff --name-only — verify ONLY: firmware/core/*.h (new), scripts/assemble-sensor-history.sh (new),
    scripts/provision.sh, scripts/preflight.sh, changelog, version files. NO other files.
  bash scripts/assemble-sensor-history.sh --check — exit 0
  bash scripts/preflight.sh — all pass
  Playwright across all 4 fixture sets — all green
  grep -c 'sensor_history_multi.h' <(git diff) — expected: 0 (monolith NOT modified)
---

Do NOT use `split` command — use `sed -n` with explicit line ranges only.
Do NOT modify `sensor_history_multi.h` — fragments are copies, not moves.
Do NOT add fragments to YAML `includes:`.
Do NOT redirect `render_sensor_config.py` to fragment files.
The `--check` mode MUST use `strip_generated()` to handle generator marker content.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.1.md`.

After the agent creates its PR, review specifically checking:

  • Fragment count — exactly 8 files in `firmware/core/`?
  • Line counts — 95+460+614+50+168+891+2006+41 = 4,325?
  • SHA-256 identity — `assemble-sensor-history.sh --check` exits 0?
  • Direct concatenation identity — `diff` of assembled vs `cat` of fragments exits 0?
  • `--list` correct — 8 fragments with correct line counts?
  • Generator-aware `--check` — `strip_generated()` strips SENSOR_MANIFEST marker content?
  • No code changes — fragments are pure line-range extractions?
  • Boundary landmarks — spot-check `head -1` of data-model.h (TAG), aggregator-runtime.h (#if AGGREGATOR_ENABLED), registration.h (comment)?
  • Assembly step activated in provision.sh?
  • Preflight fragment check added and passing?
  • YAML unchanged — no fragment files in `includes:`?
  • MODULES array order correct?

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.1-PR<NN>-consolidated-audit-and-lessons.md`
  - Review and update `session-handoff-v7.6.6.2.md` and `v7.6.6.2-*`

Tag: `git tag -a v7.6.6.1 -m "Phase Y: Establish assembly script and 8 fragment baseline" && git push origin v7.6.6.1`

---
---

# v7.6.6.2 — Wire Assembly into Pipeline and Fragment-Level Preflight

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md` — session context.
2. Read `prompts/phaseY/v7.6.6.2-implementation-instructions-for-coding-agent.md` in full.
3. Read every file listed in the "Required Reading" section of that document (§1).

Then implement:

  1. Verify assembly step is active in `provision.sh` pipeline
  2. Add `firmware_core_assembly_check` to `preflight.sh` — calls `assemble-sensor-history.sh --check`
  3. Add `firmware_core_fragment_line_sum` to `preflight.sh` — verifies fragment line counts sum to committed file

---
⛔ CHECKPOINT A (after adding both preflight checks):
Run:
  bash scripts/preflight.sh — all checks pass including the two new ones
  git diff --name-only — must show ONLY scripts/preflight.sh (and changelog/version later)
If preflight fails: STOP. Fix the check functions before continuing.
If unexpected files appear in diff: STOP. Revert unauthorized changes.
---

  4. Version bump, changelog, full pipeline, Playwright suite

---
⛔ PRE-PR GATE:
Run:
  git diff --name-only — ONLY: scripts/preflight.sh, changelog, version files
  bash scripts/preflight.sh — all pass
  Playwright across all 4 fixture sets — all green
  Verify: NO changes to firmware/core/, assembly script, or test files
---

Do NOT modify fragments, assembly script, or test files.
Do NOT add `--check` as a pipeline step after the generator (see §4.2 — runs in preflight only).

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.2.md`.

After the agent creates its PR, review specifically checking:

  • Assembly step in pipeline — `provision.sh` runs assembly as Step 0?
  • Two new preflight checks added — `firmware_core_assembly_check` and `firmware_core_fragment_line_sum`?
  • Both new checks pass?
  • No assembly `--check` in pipeline after generator (only in preflight)?
  • No fragment changes, no test changes, no assembly script changes?
  • All Playwright tests pass (all 4 fixture sets)?

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.2-PR<NN>-consolidated-audit-and-lessons.md`
  - Review and update `session-handoff-v7.6.6.3.md` and `v7.6.6.3-*`

Tag: `git tag -a v7.6.6.2 -m "Phase Y: Wire assembly into pipeline and fragment-level preflight" && git push origin v7.6.6.2`

---
---

# v7.6.6.3 — Fragment Editing Workflow Validated

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md` — session context.
2. Read `prompts/phaseY/v7.6.6.3-implementation-instructions-for-coding-agent.md` in full.
3. Read `scripts/assemble-sensor-history.sh` — understand `--write` and `--check` modes.

Then implement the validation cycle:

  1. Record baseline SHA-256 and verify `--check` PASSES

---
⛔ CHECKPOINT A (baseline established):
Run:
  bash scripts/assemble-sensor-history.sh --check — must exit 0 (PASS)
  sha256sum dashboard/sensor_history_multi.h — record this value
If --check fails: STOP. The baseline is broken. Do not proceed.
---

  2. Add trailing blank line to `registration.h`, reassemble, verify line count changes (4326)
  3. Revert the blank line, reassemble, verify SHA-256 matches baseline (IDENTITY RESTORED)

---
⛔ CHECKPOINT B (edit-revert cycle confirmed):
Run:
  sha256sum dashboard/sensor_history_multi.h — must match baseline from CHECKPOINT A
  wc -l firmware/core/*.h | tail -1 — must be 4325 again
If SHA doesn't match: STOP. The revert was incomplete. Fix before the deliberate-break test.
---

  4. Deliberate-break test: add space to config.h line 1, run `--check` WITHOUT reassembling — must FAIL
  5. Revert, run `--check` — must PASS again

---
⛔ CHECKPOINT C (four-stage sequence complete):
Verify all four results documented:
  Stage 1: PASS (baseline)
  Stage 2: CHANGE (line count changed to 4326 after edit+reassemble)
  Stage 3: FAIL (deliberate break detected by --check without reassemble)
  Stage 4: PASS (identity restored after revert)
If any stage produced the wrong result: STOP. The assembly workflow has a defect.
---

  6. Document all four results (PASS → CHANGE → FAIL → PASS)
  7. Full pipeline, version bump, changelog, Playwright suite

---
⛔ PRE-PR GATE:
Run:
  git diff --name-only -- firmware/core/ — must show ZERO changes (all edits reverted)
  bash scripts/assemble-sensor-history.sh --check — exit 0
  wc -l firmware/core/*.h | tail -1 — 4325
  Playwright across all 4 fixture sets — green
---

Do NOT leave any permanent content changes in fragment files.
Do NOT modify the assembly script or preflight script.
Do NOT skip the deliberate-break test.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.3.md`.

After the agent creates its PR, review specifically checking:

  • No permanent fragment changes — `git diff` shows ZERO changes to `firmware/core/`?
  • Four-step gate test documented — PASS, CHANGE, FAIL, PASS sequence with evidence?
  • No assembly/preflight/provision.sh changes?
  • Fragment line counts unchanged — total still 4,325?
  • All Playwright tests pass (all 4 fixture sets)?

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.3-PR<NN>-consolidated-audit-and-lessons.md`
  - Review and update `session-handoff-v7.6.6.4.md` and `v7.6.6.4-*`

Tag: `git tag -a v7.6.6.3 -m "Phase Y: Fragment editing workflow validated" && git push origin v7.6.6.3`

---
---

# v7.6.6.4 — Ping Adapter Fragment Validation

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md` — session context.
2. Read `prompts/phaseY/v7.6.6.4-implementation-instructions-for-coding-agent.md` in full.
3. Read `firmware/core/ping-adapter.h` — the fragment being validated. Verify `#ifdef PING_DEVICE_INDEX` starts the file and the PingAdapter class is complete.

Then implement:

  1. Validate fragment content: `head -1 firmware/core/ping-adapter.h` → `#ifdef PING_DEVICE_INDEX`
  2. Verify PingAdapter class exists: `grep "class PingAdapter"` → exactly 1 match
  3. Verify no cross-fragment symbol leakage in code (no `s_cache_mutex`, no `HistoryMeta` in non-comment lines)
  4. Verify `wc -l` → 168 lines

---
⛔ CHECKPOINT A (fragment integrity verified):
Run:
  head -1 firmware/core/ping-adapter.h — must start with #ifdef PING_DEVICE_INDEX
  grep -c "class PingAdapter" firmware/core/ping-adapter.h — must be exactly 1
  grep -v '^\s*//' firmware/core/ping-adapter.h | grep -c "s_cache_mutex\|HistoryMeta" — must be 0 (comments excluded; boundary comments referencing adjacent-fragment symbols are expected)
  wc -l firmware/core/ping-adapter.h — must be 168
If ANY fails: STOP. Fragment content is incorrect — escalate.
---

  5. Assembly identity gate: `assemble-sensor-history.sh --check` → PASS
  6. Full pipeline, ESPHome config validation, Playwright suite
  7. Version bump, changelog

---
⛔ PRE-PR GATE:
Run:
  git diff --name-only -- firmware/core/ — must show ZERO changes
  git diff --name-only — ONLY changelog, version files
  bash scripts/preflight.sh — all pass
  Playwright across all 4 fixture sets — green
---

Do NOT modify any fragment file content.
Do NOT treat this as a "first real edit" step — no functional changes.
If ping device is configured, optionally run device smoke test.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.4.md`.

After the agent creates its PR, review specifically checking:

  • No fragment changes — `git diff` shows ZERO changes to `firmware/core/`?
  • Compile-guard intact — `#ifdef PING_DEVICE_INDEX` is first line?
  • PingAdapter class complete — exactly 1 `class PingAdapter` match?
  • No cross-fragment symbol leakage?
  • Line count correct — 168 lines?
  • Assembly identity holds?
  • No script/test/YAML changes?
  • All Playwright tests pass (all 4 fixture sets)?

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.4-PR<NN>-consolidated-audit-and-lessons.md`
  - Review and update `session-handoff-v7.6.6.5.md` and `v7.6.6.5-*`

Tag: `git tag -a v7.6.6.4 -m "Phase Y: Ping adapter fragment validation" && git push origin v7.6.6.4`

---
---

# v7.6.6.5 — NVS Persistence Device Test Gate ⚠️ BLOCKING

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

**⚠️ BLOCKING GATE — Phase Y cannot proceed if this step fails.**

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md` — session context.
2. Read `prompts/phaseY/v7.6.6.5-implementation-instructions-for-coding-agent.md` in full.
3. Read `firmware/core/nvs-persistence.h` — understand `HistoryMeta`, `restore_from_nvs()`, `persist_hourly_segment()`, `maybe_yield_nvs_scan_()`.
4. Read `Docs/lessons/firmware.md` — NVS-related bugs and constraints.

Then implement the device test protocol on C3 at `192.168.120.189`:

  1. `bash scripts/provision.sh satellite` — full pipeline

---
⛔ CHECKPOINT A (pipeline clean before flash):
Run:
  bash scripts/assemble-sensor-history.sh --check — exit 0
  bash scripts/preflight.sh — all pass
If either fails: STOP. Do not flash a board with a broken pipeline.
---

  2. Flash C3: `cd firmware && esphome run esp32-c3-multi-sensor.yaml`
  3. Capture boot log — verify NVS restore messages, no crash

---
⛔ CHECKPOINT B (board is alive):
Verify: boot log shows NVS restore messages and no panic/crash/reboot loop.
Run: curl -s http://192.168.120.189/api/status | python3 -m json.tool — must return valid JSON
If board is not responding or boot log shows crash: STOP. Use bug escalation prompt.
---

  4. Test 1: `curl -s http://192.168.120.189/api/storage-stats | python3 -m json.tool`
  5. Test 2: `curl -s http://192.168.120.189/api/manifest | python3 -m json.tool` then history endpoint
  6. Test 3: `curl -s http://192.168.120.189/api/v2/live | python3 -m json.tool`
  7. Test 4: `curl -s http://192.168.120.189/api/status | python3 -m json.tool`
  8. Test 5 (reboot persistence): record storage-stats → `curl -s -u <user>:<pass> -d 'a=1' -X POST http://192.168.120.189/api/reboot` → wait 60s → re-check storage-stats → segments must not decrease
  9. Test 6 (optional): observe hourly persist cycle

---
⛔ CHECKPOINT C (all device tests complete):
Verify: ALL tests 1-5 produced valid JSON evidence.
Verify: Test 5 reboot persistence — segments did NOT decrease.
⚠️ If ANY test failed: STOP. Use `prompts/phaseY/phase-y-bug-escalation-prompt.md`. Do NOT continue.
---

  10. Document ALL evidence in PR
  11. Playwright suite, version bump, changelog

---
⛔ PRE-PR GATE:
Run:
  git diff --name-only — ONLY changelog, version files (NO source code changes)
  bash scripts/preflight.sh — all pass
  Playwright across all 4 fixture sets — green
  Verify: PR description contains ALL device test evidence (Tests 1-5 with JSON output)
---

Do NOT use `Content-Type: application/json` — use `-d 'a=1'` for all POST.
Do NOT use generated YAML for C3 — use committed `esp32-c3-multi-sensor.yaml`.
Do NOT modify any source code.
If any device test fails, STOP and escalate using `prompts/phaseY/phase-y-bug-escalation-prompt.md`.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.5.md`.

After the agent creates its PR, review specifically checking:

  • No source code changes — only changelog and version files?
  • Boot log evidence present — NVS restore messages, no crash?
  • Storage-stats evidence — valid JSON with NVS statistics?
  • History endpoint evidence — populated data?
  • Reboot persistence evidence — pre/post comparison, segments did not decrease?
  • Correct curl usage — `-d 'a=1'` for POST, no JSON content type?
  • Correct board YAML — committed `esp32-c3-multi-sensor.yaml`?
  • Assembly identity holds?
  • All Playwright tests pass (all 4 fixture sets)?

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.5-PR<NN>-consolidated-audit-and-lessons.md`
  - Review and update `session-handoff-v7.6.6.6.md` and `v7.6.6.6-*`

Tag: `git tag -a v7.6.6.5 -m "Phase Y: NVS persistence device test gate PASSED" && git push origin v7.6.6.5`

---
---

# v7.6.6.6 — Aggregator Runtime Device Test Gate ⚠️ BLOCKING

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

**⚠️ BLOCKING GATE — Phase Y cannot proceed if this step fails.**

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md` — session context.
2. Read `prompts/phaseY/v7.6.6.6-implementation-instructions-for-coding-agent.md` in full.
3. Read `firmware/core/aggregator-runtime.h` — understand `SatelliteCache`, `s_cache_mutex`, poll task, deferred satellite tasks.
4. Read `firmware/core/deferred-management.h` — deferred reboot/delete-data pairs.

Then implement the device test protocol on S3 at `192.168.120.191`:

  1. `bash scripts/provision.sh aggregator` — generates S3-specific YAML

---
⛔ CHECKPOINT A (aggregator pipeline clean):
Run:
  ls firmware/esp32-s3-devkitc1-n16r8-gw.yaml — file must exist (generated by provision.sh)
  bash scripts/assemble-sensor-history.sh --check — exit 0
If either fails: STOP. The aggregator provisioning failed.
---

  2. Flash S3: `cd firmware && esphome run esp32-s3-devkitc1-n16r8-gw.yaml`
  3. Capture boot log — verify aggregator poll task start

---
⛔ CHECKPOINT B (aggregator board alive):
Verify: boot log shows aggregator poll task initialization.
Run: curl -s http://192.168.120.191/api/aggregator/gateways | python3 -m json.tool — must return valid JSON
If board is not responding: STOP. Use bug escalation prompt.
---

  4. Test 1: `curl -s http://192.168.120.191/api/aggregator/gateways | python3 -m json.tool`
  5. Test 2: `curl -s http://192.168.120.191/api/aggregator/live | python3 -m json.tool`
  6. Test 3: Proxy history endpoint
  7. Test 4: `curl -s -u <user>:<pass> -d "ip=192.168.120.189" -X POST http://192.168.120.191/api/aggregator/test-satellite`
  8. Test 5: `curl -s -d "ip=192.168.120.189" -X POST http://192.168.120.191/api/aggregator/add-satellite`
  9. Test 6: Check config_generation in gateways response
  10. Test 7: `curl -s -u <user>:<pass> -X DELETE http://192.168.120.191/api/aggregator/satellite/0`
  11. Test 8: Re-add satellite, Test 9: Reboot persistence (pre/post gateways comparison)
  12. Test 10: `curl -s -u <user>:<pass> -d 'a=1' -X POST http://192.168.120.191/api/system/reset-satellites`

---
⛔ CHECKPOINT C (all aggregator tests complete):
Verify: ALL tests 1-10 produced evidence.
Verify: Reboot persistence — satellite config survived reboot.
⚠️ If ANY test failed: STOP. Escalate. Do NOT continue.
---

  13. **MANDATORY: `bash scripts/provision.sh satellite`** — switch back before PR

---
⛔ CHECKPOINT D (satellite mode restored — CRITICAL):
Run:
  bash scripts/provision.sh status — must show satellite mode, NOT aggregator
  bash scripts/preflight.sh — all pass
  git diff --name-only -- firmware/esp32-s3-devkitc1-n16r8-gw.yaml — this file must NOT be in the diff
     (it's generated and gitignored)
If satellite mode NOT restored: STOP. Run provision.sh satellite NOW. Do NOT create PR in aggregator mode.
---

  14. Document ALL evidence, Playwright suite, version bump, changelog

---
⛔ PRE-PR GATE:
Run:
  git diff --name-only — ONLY changelog, version files (NO source code, NO generated YAML)
  bash scripts/preflight.sh — all pass
  Playwright across all 4 fixture sets — green
  Verify: PR description contains ALL device test evidence
---

Do NOT use committed C3 YAML for S3 — use GENERATED `esp32-s3-devkitc1-n16r8-gw.yaml` (Critical Rule 36).
Do NOT forget to switch back to satellite mode.
Do NOT modify any source code.
All POST commands use `-d 'a=1'` — never JSON content type.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.6.md`.

After the agent creates its PR, review specifically checking:

  • No source code changes?
  • Correct board YAML — generated `esp32-s3-devkitc1-n16r8-gw.yaml`?
  • Aggregator poll task started (boot log)?
  • All aggregator endpoints tested (gateways, live, proxy)?
  • Satellite mutation tested (add, delete, test, reset)?
  • Reboot persistence — satellite config survived reboot?
  • Config generation incremented?
  • Correct curl usage — `-d 'a=1'` for POST?
  • Satellite mode restored?
  • Assembly identity holds?
  • All Playwright tests pass?

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.6-PR<NN>-consolidated-audit-and-lessons.md`
  - Review and update `session-handoff-v7.6.6.7.md` and `v7.6.6.7-*`

Tag: `git tag -a v7.6.6.6 -m "Phase Y: Aggregator runtime device test gate PASSED" && git push origin v7.6.6.6`

---
---

# v7.6.6.7 — Full Endpoint Smoke Test

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md` — session context and endpoint list.
2. Read `prompts/phaseY/v7.6.6.7-implementation-instructions-for-coding-agent.md` in full.
3. Read `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` — §5 (all 21 endpoints).

Then implement the comprehensive endpoint test across both boards:

**Phase A — C3 Satellite (21 endpoints at `192.168.120.189`):**
  1. Flash C3: `esphome run esp32-c3-multi-sensor.yaml`

---
⛔ CHECKPOINT A (C3 alive):
Run: curl -s http://192.168.120.189/api/status | python3 -m json.tool — valid JSON
If not responding: STOP. Check flash output for errors.
---

  2. Test all 13 local endpoints (history, manifest, dashboard, status, live, ingest)
  3. Test auth behavior (401 unauthenticated → 200 authenticated)
  4. Test all 8 import/management endpoints (begin, data, finish, reboot, delete-data, reset-satellites)

---
⛔ CHECKPOINT B (Phase A complete):
Count: verify 21 endpoints tested with evidence recorded.
If any endpoint missing: test it now before moving to Phase B.
⚠️ Do NOT run delete-data until AFTER all history endpoint tests.
---

**Phase B — S3 Aggregator (6 endpoints at `192.168.120.191`):**
  5. `bash scripts/provision.sh aggregator`
  6. Flash S3: `esphome run esp32-s3-devkitc1-n16r8-gw.yaml`
  7. Test all 6 aggregator endpoints (gateways, live, proxy, add, test, delete)

**Phase C — Cleanup:**
  8. **MANDATORY: `bash scripts/provision.sh satellite`**

---
⛔ CHECKPOINT C (satellite mode restored — CRITICAL):
Run:
  bash scripts/provision.sh status — must show satellite mode
  bash scripts/preflight.sh — all pass
If satellite mode NOT restored: STOP. Run provision.sh satellite NOW.
---

  9. Playwright suite, version bump, changelog
  10. Fill in the 21-endpoint evidence table in PR description

---
⛔ PRE-PR GATE:
Run:
  git diff --name-only — ONLY changelog, version files
  bash scripts/preflight.sh — all pass
  Playwright across all 4 fixture sets — green
  Verify: 21-endpoint evidence table in PR description is COMPLETE (no blank rows)
---

Validate `esphome config` for BOTH board profiles before flashing.
Do NOT skip any of the 21 endpoints.
Do NOT run delete-data before other history tests.
Do NOT forget to switch back to satellite mode.
All POST commands use `-d 'a=1'` — never JSON content type.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.7.md`.

After the agent creates its PR, review specifically checking:

  • No source code changes?
  • All 21 endpoints tested — evidence table complete with HTTP status codes?
  • Auth behavior verified — both authenticated and unauthenticated?
  • Import cycle tested — begin/data/finish sequence?
  • Both boards tested — C3 satellite AND S3 aggregator?
  • Both ESPHome configs validated?
  • Correct board YAMLs used (C3 committed, S3 generated)?
  • Correct curl usage?
  • Satellite mode restored?
  • Assembly identity holds?
  • All Playwright tests pass?

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.7-PR<NN>-consolidated-audit-and-lessons.md`
  - Review and update `session-handoff-v7.6.6.8.md` and `v7.6.6.8-*`

Tag: `git tag -a v7.6.6.7 -m "Phase Y: Full endpoint smoke test PASSED" && git push origin v7.6.6.7`

---
---

# v7.6.6.8 — Closure: Preflight, Documentation, Critical Rules

## Step 1 — Agent's Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Before making ANY changes, read the following files completely and in order:

1. Read `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md` — session context and closure scope.
2. Read `prompts/phaseY/v7.6.6.8-implementation-instructions-for-coding-agent.md` in full.
3. Read `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — §3 v7.6.6.8 (exact
   preflight checks and Critical Rules wording).
4. Read `scripts/preflight.sh` — count existing checks, understand function pattern.
5. Read `prompts/prompt-index-and-workflow.md` — Critical Rules table.
6. Read `prompts/handoff/phaseD/phaseD-results.md` — format reference for results document.

Then implement:

  1. Add 6 new preflight checks to `preflight.sh`:
     - `sensor_history_monolith_is_assembled` — `assemble-sensor-history.sh --check` passes
     - `firmware_core_fragment_count` — exactly 8 fragments
     - `no_generator_markers_in_fragments` — no SENSOR_MANIFEST content between delimiters
     - `deferred_task_pairs_in_expected_homes` — all 4 pairs in correct fragments
     - `maybe_yield_present_in_nvs_persistence` — function defined in nvs-persistence.h
     - `mutex_single_owner` — `s_cache_mutex` defined only in aggregator-runtime.h

---
⛔ CHECKPOINT A (preflight checks added):
Run:
  bash scripts/preflight.sh — ALL checks pass (including the 6 new ones)
  bash scripts/preflight.sh 2>&1 | grep -c "PASS\|OK" — count total checks, record number
If any new check fails: STOP. Fix the check implementation before continuing.
---

  2. Add Critical Rules 58–62 to `prompts/prompt-index-and-workflow.md` (exact plan wording)

---
⛔ CHECKPOINT B (critical rules added with exact wording):
Run:
  grep -A1 "Rule 58" prompts/prompt-index-and-workflow.md — verify exact wording from plan
  grep -c "Rule 5[89]\|Rule 6[012]" prompts/prompt-index-and-workflow.md — must be 5 (all present)
If wording doesn't match plan exactly: STOP. Fix before continuing. Do NOT paraphrase.
---

  3. Update Phase Y step statuses to ✅ Complete, add completion summary
  4. Update `README.md` — document `firmware/core/` structure with fragment table
  5. Update `Docs/lessons/firmware.md` — fragment architecture lesson
  6. Update `Docs/lessons/build-pipeline.md` — assembly step documentation
  7. Create `prompts/handoff/phaseY-results.md` — Phase Y results document
  8. Version bump, changelog, full pipeline, Playwright suite
  9. Verify ALL preflight checks pass (report total count)

---
⛔ PRE-PR GATE:
Run:
  git diff --name-only — verify ONLY allowed files: preflight.sh, prompt-index, README,
    lessons files, phaseY-results.md, changelog, version files. NO firmware/core/ changes.
    NO test file changes. NO YAML changes.
  bash scripts/preflight.sh — ALL pass (report total count)
  bash scripts/assemble-sensor-history.sh --check — exit 0
  Playwright across all 4 fixture sets — green
  Verify: phaseY-results.md exists and is non-empty
  Verify: All 9 Phase Y steps marked ✅ Complete in prompt-index
---

Do NOT modify fragment content, assembly script, test files, or YAML.
Use EXACT Critical Rule wording from the Phase Y plan.

## Step 2 — Review Prompt

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Read thoughtfully `prompts/handoff/phaseY/session-handoff-v7.6.6.8.md`.

After the agent creates its PR, review specifically checking:

  • 6 new preflight checks — all functions exist and called in main sequence?
  • ALL preflight checks pass — report total count?
  • Critical Rules 58–62 — exact wording from plan? All 5 present?
  • Phase Y step table — all 9 steps ✅ Complete?
  • Phase Y completion summary present?
  • README — `firmware/core/` structure documented?
  • Firmware lessons — fragment architecture lesson added?
  • Build-pipeline lessons — assembly step lesson added?
  • Phase Y results document — `prompts/handoff/phaseY-results.md` exists and complete?
  • No fragment content changes?
  • No test file changes?
  • Assembly identity holds?
  • `esphome config` validates?
  • All Playwright tests pass (all 4 fixture sets)?
  • Final migration safety: all 12 rules verified across entire Phase Y?

Post-merge deliverables:
  - `prompts/phaseY/v7.6.6.8-PR<NN>-consolidated-audit-and-lessons.md` (FINAL Phase Y audit)

Tag: `git tag -a v7.6.6.8 -m "Phase Y: Closure — sensor_history_multi.h architecture refactor complete" && git push origin v7.6.6.8`

---

_End of Phase Y Two-Session Execution Prompts (with Inline Verification Gates)._
