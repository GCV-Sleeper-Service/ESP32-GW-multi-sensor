# Universal Bug / Problem Escalation Prompt

_Self-contained prompt for consulting the architectural advisor (Claude) when a bug, problem, or unclear situation is encountered during any phase._
_No prior conversation context required — paste this prompt into a fresh Claude session within this project._

---

## Instructions for the Advisor

You are the architectural advisor for the **ESP32-GW Multi-Sensor Gateway** project (`https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`). A problem has been encountered. Your job is to:

1. **Understand the current codebase state** — not from memory, but from reading
2. **Diagnose the root cause** — prompt defect, codebase issue, agent error, or unclear documentation
3. **Produce a resolution** — fix, workaround, or updated instructions
4. **Check downstream impact** — does this affect any future step's handoff or prompt?

### ⚠️ CRITICAL: Read Before Responding

Your training data and session memory may be **stale**. The project has a strict phase/version system and the codebase changes frequently. You MUST:

1. **Clone the repo** and read the actual current state:
   ```
   https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
   ```
2. **Read these files in order** (mandatory for every escalation):
   - `VERSION` — confirm current version
   - `Docs/changelog.md` — understand what changed recently (read last 3–5 version entries)
   - The phase plan document (path given by operator below)
   - The relevant session handoff (path given by operator below)
   - The relevant agent prompt (path given by operator below)
   - `scripts/provision.sh` — current pipeline (if build/pipeline related)
   - `scripts/assemble-sensor-history.sh` — module assembly (if firmware related)
   - `firmware/core/` directory listing — current module structure
   - `Docs/lessons/` — accumulated constraints and failure modes

3. **Do NOT rely on your memory of the codebase.** The monolithic `sensor_history_multi.h` was refactored in Phase Y into modules under `firmware/core/`. The pipeline was consolidated into `provision.sh`. File locations, line numbers, function signatures, and even entire subsystems may have changed since your last session.

### Diagnosis Process

1. **Reproduce understanding.** Read the error output and identify which component failed (compiler, preflight, Playwright, device runtime, assembly identity gate, pipeline, serial log, unclear documentation, operator workflow gap).
2. **Trace the root cause.** Use the current codebase (not memory) to trace the failure to a specific file, function, configuration, or documentation gap.
3. **Check common failure modes** (see checklist at the bottom).
4. **Produce a resolution package** (format below).
5. **Check downstream impact.** Does the fix or finding affect any remaining step's handoff, prompt, or plan document? If yes, produce the updates.

---

## Operator: Fill In These Fields

```
Current version:     v7.6.___.___ (from VERSION file)
Current phase:       [ Phase V | Phase Y | Phase 7 | other: ___ ]
Error category:      [ compiler | preflight | playwright | device-runtime |
                       assembly-gate | pipeline | serial-log | documentation-gap |
                       unclear-instructions | agent-deviation | other: ___ ]

Phase plan document: Docs/___
Session handoff:     prompts/handoff/___
Agent prompt:        prompts/___

Error description:
<What happened? What was the expected outcome vs. actual outcome?
 Include: what step you were on, what you were trying to do, and what confused you or went wrong.>

What was attempted before escalating:
<What did the agent or operator try? Include commands run and their output.>

Relevant files:
<List the specific files involved in the failure.
 If agent-produced changes exist: include `git diff --name-only` output.>

Error output / evidence:
<Paste ONE of: serial log snippet, compiler error, curl output with response,
 Playwright failure, git diff excerpt, pipeline output, or screenshot description.
 For device issues: include output of `curl -s http://{ip}/api/status | jq`>

Agent used (if applicable): [ GPT / Codex / Claude / Copilot / N/A (operator action) ]

Hardware involved (if applicable):
<Board, IP, role (satellite/aggregator), firmware version from /api/status>
```

---

## Common Failure Modes (Advisor Checklist)

### Build / Compile

1. **Symbol not found / incomplete type** — Fragment references a symbol defined in a later fragment. Check assembly order in `scripts/assemble-sensor-history.sh` MODULES array.
2. **Duplicate symbol** — A `static` variable accidentally duplicated across fragments. `grep -rn "^static " firmware/core/*.h | sort` — each static must appear in exactly one fragment.
3. **YAML includes order wrong** — YAML must include only `../dashboard/dashboard.h` and `../dashboard/sensor_history_multi.h`, never individual fragments.

### Pipeline / Assembly

4. **Assembly identity gate fails** — Content changed during fragment editing. `bash scripts/assemble-sensor-history.sh --check` must pass. Use `--check` output to identify which region differs.
5. **Pipeline step fails** — Run `bash scripts/provision.sh satellite --dry-run` to see the step sequence, then run without `--dry-run`. Check which specific step fails.
6. **Generator marker block in wrong file** — `SENSOR_MANIFEST:*` markers must be stubs in fragments; generated content lives only in the assembled file after `render_sensor_config.py --write`.

### Device / Runtime

7. **Crash / Guru Meditation / WDT reset** — Check serial log for stack trace. Common causes: stack overflow (httpd task at 16KB is patched via local_components), NVS operation on httpd task (must use deferred task pattern), NULL pointer in device array.
8. **HTTP 404 on expected endpoint** — Endpoint not registered, or URL path mismatch. Check `handleRequest()` dispatch chain in `firmware/core/web-handler.h`.
9. **POST body not received** — Must use `Content-Type: application/x-www-form-urlencoded` with `body: 'a=1'`. JSON content type triggers ESPHome's fallback path.
10. **Heap exhaustion** — Check `/api/status` for `free_heap`. NVS operations on httpd task can spike heap usage. History endpoint NVS scan is blocking (LESSON-OPS-052).
11. **Import crash** — Import must use deferred task pattern (`xTaskCreate` with 8192 B stack). Check that `handle_import_begin_()` spawns the task and doesn't do heavy work on httpd.

### Testing

12. **Playwright tests fail after code change** — Verify assembly: `bash scripts/assemble-sensor-history.sh --check`. Verify fixtures: `node tests/fixtures/generate-fixtures.js`. Verify preflight: `bash scripts/preflight.sh`.
13. **Test passes locally but concept is wrong** — Playwright tests run against mock servers, not real devices. A test passing doesn't guarantee device behaviour.

### Documentation / Workflow Gaps

14. **Plan says "do X" but doesn't explain how** — The plan may assume operator knowledge that isn't documented. Common gaps: physical device workflow, serial setup, logger level interactions, timing dependencies, measurement interpretation.
15. **Handoff references stale line numbers** — Line numbers shift between steps. Always `grep -n` for the target function/variable before editing, never trust hardcoded line numbers.
16. **Logger level suppresses expected output** — The C3 YAML has `logger: level: WARN`. Any `ESP_LOGI` or `ESP_LOGD` output will be silently suppressed. Use `ESP_LOGW` for temporary instrumentation. The WROOM board profile also has `logger: baud_rate: 0` which disables serial output entirely.

---

## Resolution Package Format

Produce ALL of the following that apply:

### 1. Root Cause
Which failure mode (number from checklist, or new), which file, which line or function. If this is a documentation gap rather than a code bug, say so explicitly.

### 2. Fix
Exact changes needed — file paths, code edits, script modifications, or documentation rewrites. For code: provide the edit against the CURRENT codebase (verify by reading the file, not from memory). For documentation gaps: provide the rewritten section.

### 3. Verification
Commands to confirm the fix works. Include expected output.

### 4. Prompt / Handoff / Plan Impact
Does any prompt, handoff, or plan document for current or future steps need updating? If yes, produce the specific edits. If measurements or findings change gate conditions, update the relevant decision tables.

### 5. New Lesson (if applicable)
If this reveals a new pattern, draft a `BUG-xxx` or `LESSON-OPS-xxx` entry for `Docs/lessons/`.

### 6. New Critical Rule (if applicable)
If this is a constraint that agents or operators will hit again, draft the rule text.

---

_End of universal bug escalation prompt._
