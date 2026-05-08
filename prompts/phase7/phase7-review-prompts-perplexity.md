# Phase 7 — Review Prompts for Perplexity AI

_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Date: 2026-05-08_
_Optimized for: Perplexity AI (stateless, MCP GitHub tool access, no persistent sub-agents)_
_Scope: Review sessions only. For agent sessions, use the `v7.7.x.x-claude-two-step.md` files._

---

## How these prompts differ from the claude-two-step originals

The `v7.7.x.x-claude-two-step.md` files were written for Claude — an IDE agent with a persistent shell and iterative REPL. Perplexity operates differently:

- **No shell execution.** Every file read is a GitHub MCP API call that consumes context tokens.
- **No persistent sub-agent workers.** The entire session is one context window; there is no "coordinator + workers" hierarchy.
- **Stateless per turn.** Nothing persists between conversations unless committed to the repo.
- **Context is the scarcest resource.** The diff-first approach keeps the review window focused — source files are only opened if a gate cannot be decided from the diff alone.
- **Inline context headers (≤ 400 tokens)** front-load all constraints before any file is opened, so high-attention positions carry the critical rules and blocking gates.
- **Table-first output.** Gate checklist tables (≤ 600 tokens) replace long prose session narratives.

---

## Shared review protocol

All review sessions in this file use the **Shared Perplexity Review Session Protocol** defined in:

`prompts/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md`

Read that file at the start of every review session. It defines the three-turn structure (Turn 1 — Spec extraction, Turn 2 — Diff + evidence audit, Turn 3 — Verdict + output), coordinator constraints, and the standard Turn 3 output format. The sections below provide only the step-specific inline context and gate lists.

---

# v7.7.1.0 — Health-Check Telemetry Task

## Inline review context

```
Step: v7.7.1.0 — Phase 7 Step 0b (first implementation step)
Objective: Add health-check.h fragment, wire into assembly and YAML on_boot, add preflight check.

Allowed diff scope:
  firmware/core/health-check.h           — NEW file only
  scripts/assemble-sensor-history.sh     — health-check.h insertion between nvs-persistence.h and deferred-management.h
  firmware/esp32-c3-multi-sensor.yaml    — xTaskCreate call in on_boot at priority 600
  scripts/preflight.sh                   — health-check.h existence check added
  Docs/changelog.md                      — v7.7.1.0 entry
  CURRENT-STATE.md                       — version, "What Just Shipped", unimplemented recommendations
  prompts/prompt-index-and-workflow.md   — Critical Rules 65–67 added
  version artifact                       — bumped to 7.7.1.0
  session log                            — created per Rule 63

⛔ Out of scope: any existing firmware fragments · dashboard/ · tests · sensor_history_multi.h · HTTP endpoints

Critical rules:
  Rule 24 — use esp_get_free_internal_heap_size() for internal heap, not esp_get_free_heap_size() alone
  Rule 58 — do NOT edit dashboard/sensor_history_multi.h directly
  Rule 63 — session log required with specified sections

Blocking gates:
  — health-check task contains NVS write operations
  — existing firmware fragments were modified
  — HTTP endpoints were created
  — assemble-sensor-history.sh --check fails

Evidence needed:
  — CHECKPOINT A grep outputs (xTaskCreate, nvs_get_stats, esp_get_free_internal_heap_size counts)
  — CHECKPOINT B grep outputs (health-check.h in MODULES, --check PASS)
  — PRE-PR GATE outputs (preflight PASS, Playwright green)
  — Session log (Rule 63)
```

## Review prompt — v7.7.1.0

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` for the three-turn structure, coordinator constraints, and Turn 3 output format. Then proceed.

**Turn 1 — Spec extraction (≤ 300 tokens output)**

Read only:
- The inline review context above.
- `prompts/handoff/phase7/session-handoff-v7.7.1.0.md`
- `prompts/phase7/v7.7.1.0-agent-prompt-gpt-codex.md`

Produce: gate checklist, allowed diff scope, required evidence artifacts, blocking gate verdict criteria. Do **not** open the PR diff yet.

**Turn 2 — Diff + evidence audit**

Fetch PR diff for:
- `firmware/core/health-check.h`
- `scripts/assemble-sensor-history.sh`
- `firmware/esp32-c3-multi-sensor.yaml`
- `scripts/preflight.sh`
- `Docs/changelog.md`
- `CURRENT-STATE.md`
- `prompts/prompt-index-and-workflow.md`
- version artifact, session log

Fetch evidence artifacts from the PR description or comments (agent compliance table, CHECKPOINT A/B outputs, PRE-PR GATE outputs, Playwright results).

For each gate: record PASS / FAIL / UNCLEAR with one-line evidence. Only open source files if a gate cannot be decided from the diff alone.

**Review gates to decide explicitly:**
- `esp_get_free_internal_heap_size()` used (not just `esp_get_free_heap_size()`) — Rule 24
- `heap_caps_get_minimum_free_size(MALLOC_CAP_INTERNAL)` used for min_free
- `uxTaskGetStackHighWaterMark` result multiplied by `sizeof(StackType_t)` for bytes
- `nvs_get_stats` called with `HISTORY_PARTITION_LABEL` (not hardcoded string)
- `xTaskCreate` stack is 4096, priority is 1
- Task name ≤ 16 characters
- 30-second initial delay before first report
- `health-check.h` inserted between `nvs-persistence.h` and `deferred-management.h` in MODULES
- No NVS write operations in the health-check task
- No HTTP endpoints created
- No existing fragments modified
- `assemble-sensor-history.sh --check` passes (CHECKPOINT B evidence)
- `start_health_check_task_()` called in YAML `on_boot` at priority 600
- Preflight check added for health-check.h existence
- `CURRENT-STATE.md` updated (version, "What Just Shipped", unimplemented recommendations)
- Critical Rules 65–67 added to `prompts/prompt-index-and-workflow.md`
- Phase 7 step tracking issue for v7.7.1.0 referenced in PR body
- All Playwright tests pass across all fixture sets
- Session log created with required sections (Rule 63)

**Turn 3 — Verdict + output**

Produce the standard Turn 3 output format from the shared protocol. Post as a PR225 comment. PR branch - `feature/v7.7.1.0-health-check`

If verdict is **NEEDS-FIX or BLOCKED**: produce a targeted fix prompt that addresses ONLY the remaining failing/unclear gates. Do-NOT list must explicitly exclude all already-passing gates. Use `prompts/phase7/v7.7.1.0-agent-prompt-gpt-codex.md` as the style reference for the fix prompt.

Operator device testing:
- Flash C3, wait 90s, check serial logs for `HEALTH:` lines
- Record `heap_free`, `min_free`, `httpd_stack_wm`, `nvs_used` values as v7.7.1.0 baseline
- Verify health-check task does not measurably reduce free_heap (task stack is only 4096 B)

**Deliverables (if MERGE-READY):** -  the the following actions one by one pushing updates and checking if the push was successful:
- Create `prompts/phase7/v7.7.1.0-PR225-consolidated-audit-and-lessons.md` 
- Review and update `prompts/handoff/phase7/session-handoff-v7.7.1.1.md`
- Review and update `prompts/phase7/v7.7.1.1-agent-prompt-gpt-codex.md`
- Apply version tag: `git tag -a v7.7.1.0 -m "Phase 7: Health-check telemetry task" && git push origin v7.7.1.0`
- Ask operator to merge and confirm that next step execution is ready.

---

# v7.7.1.1 — Chunked HTTP Streaming for History Endpoints (BUG-082 Fix)

## Inline review context

```
Step: v7.7.1.1 — Phase 7 Step 1 (CRITICAL production crash fix — HIGH RISK)
Objective: Replace CSV-in-RAM history handlers with httpd_resp_send_chunk() streaming. Fixes BUG-082 / issue #139.

Allowed diff scope:
  firmware/core/web-handler.h     — handle_history_() and handle_api_v2_history_() rewritten; helpers added
  Docs/changelog.md               — v7.7.1.1 entry, BUG-082 resolved
  CURRENT-STATE.md                — BUG-082 moved to resolved
  version artifact                — bumped to 7.7.1.1
  session log                     — created per Rule 63

⛔ Out of scope: nvs-persistence.h · data-model.h · dashboard/ · tests · aggregator proxy handler · any other firmware fragments

Critical rules:
  Rule 58 — do NOT edit dashboard/sensor_history_multi.h directly
  Rule 63 — session log required

Blocking gates:
  — csv.reserve still present in web-handler.h (std::string CSV not removed)
  — SegmentSnapshot allocated but not freed on error paths (memory leak)
  — CSV format changed (breaks dashboard parseCompactHistory)
  — any fragment other than web-handler.h modified
  — any dashboard file modified
  — PR does not reference Fixes #139

Evidence needed:
  — CHECKPOINT A grep outputs (send_snapshot_series_chunk_ ≥2, send_history_buffer_chunk_ ≥2, httpd_resp_send_chunk ≥6)
  — CHECKPOINT B grep outputs (csv.reserve = 0, httpd_resp_send_chunk ≥8, maybe_yield_nvs_scan_ ≥1)
  — PRE-PR GATE outputs (preflight PASS, Playwright green, no dashboard/fragment changes)
  — Session log (Rule 63)
```

## Review prompt — v7.7.1.1

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

Read `prompts/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` for the three-turn structure, coordinator constraints, and Turn 3 output format. Then proceed.

**Turn 1 — Spec extraction (≤ 300 tokens output)**

Read only:
- The inline review context above.
- `prompts/handoff/phase7/session-handoff-v7.7.1.1.md`
- `prompts/phase7/v7.7.1.1-agent-prompt-gpt-codex.md`

Produce: gate checklist, allowed diff scope, required evidence artifacts, blocking gate verdict criteria. Do **not** open the PR diff yet.

**Turn 2 — Diff + evidence audit**

Fetch PR diff for:
- `firmware/core/web-handler.h`
- `Docs/changelog.md`
- `CURRENT-STATE.md`
- version artifact, session log

Fetch evidence artifacts from the PR description or comments (agent compliance table, CHECKPOINT A/B outputs, PRE-PR GATE outputs, Playwright results).

For each gate: record PASS / FAIL / UNCLEAR with one-line evidence. Only open source files if a gate cannot be decided from the diff alone.

**Review gates to decide explicitly:**
- `csv.reserve` is completely gone from `web-handler.h` (`grep -c` returns 0) — blocking
- `httpd_resp_send_chunk` used correctly — Transfer-Encoding set automatically on first call
- `httpd_resp_set_type(raw_req, "text/plain")` called before first chunk
- `httpd_resp_set_hdr(raw_req, "Cache-Control", "no-store")` called
- Final empty chunk `httpd_resp_send_chunk(raw_req, nullptr, 0)` present at end of each handler
- Raw request obtained via `static_cast<httpd_req_t *>(*request)` (not a different cast)
- SegmentSnapshot still allocated via `allocate_snapshot_()` and freed via `delete snapshot` on all paths — blocking
- `maybe_yield_nvs_scan_()` still called between NVS segment reads
- `send_snapshot_series_chunk_` uses stack-local buffer (~512 B), not heap allocation
- `send_history_buffer_chunk_` uses stack-local buffer (~512 B)
- Buffer flush threshold reasonable (`buf_pos > sizeof(buf) - 48`)
- No `beginResponse` or `beginResponseStream` in the rewritten handlers
- No `std::string csv` in the rewritten handlers — blocking
- CSV format unchanged: `epoch,value\n` (dashboard `parseCompactHistory` depends on it) — blocking
- No other firmware fragments modified — blocking
- No dashboard files modified — blocking
- `CURRENT-STATE.md` marks BUG-082 as resolved
- PR description contains `Fixes #139` — blocking
- Phase 7 step tracking issue for v7.7.1.1 referenced in PR body
- Session log created with required sections (Rule 63)

**Turn 3 — Verdict + output**

Produce the standard Turn 3 output format from the shared protocol. Post as a PR comment.

If verdict is **NEEDS-FIX or BLOCKED**: produce a targeted fix prompt that addresses ONLY the remaining failing/unclear gates. Do-NOT list must explicitly exclude all already-passing gates. Use `prompts/phase7/v7.7.1.1-agent-prompt-gpt-codex.md` as the style reference for the fix prompt.

**Post-merge deliverables (if MERGE-READY):**
- Create `prompts/phase7/v7.7.1.1-PR<NN>-consolidated-audit-and-lessons.md`
- Review and update `prompts/handoff/phase7/session-handoff-v7.7.1.2.md` (if produced)
- Review and update `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` (if produced)
- Apply version tag: `git tag -a v7.7.1.1 -m "Phase 7: Chunked HTTP streaming - BUG-082 fix" && git push origin v7.7.1.1`

Operator device testing (post-merge — CRITICAL — results go in consolidated audit):
- Flash WROOM (192.168.120.190) — the board that crashed before this fix
- `curl -v http://192.168.120.190/history/office/temp` — must return chunked CSV, NO crash
- Flash C3 (192.168.120.189) — verify chunked response
- Run `scripts/stress-test-httpd-stack.sh` — verify no regression
- Monitor health-check logs during history serve — peak heap usage should be < 5 KB
- Record all measurements in consolidated audit

---

## Token budget reference

| Step | Inline context | Turn 1 reads | Turn 2 reads | Est. total tokens | Claude original est. | Savings |
|------|---------------|-------------|-------------|-------------------|---------------------|---------|
| v7.7.1.0 | ~280 | ~400 (handoff + agent prompt) | ~600 (diff + evidence) | ~1,280 | ~4,000–6,000 | ~75% |
| v7.7.1.1 | ~340 | ~500 (handoff + agent prompt) | ~800 (diff + evidence) | ~1,640 | ~6,000–8,000 | ~75% |
