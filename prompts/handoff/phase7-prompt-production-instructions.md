> ⛔ **SUPERSEDED — DO NOT USE.**
>
> This document predates the Phase-7 batch-2 audit. It treats §9 as "Post-Merge Deliverables" (the E-1 anatomy bug — see `prompts/handoff/phase7/operator-notes.txt`).
>
> The current authoritative meta-prompt is **`prompts/handoff/phase7-batch-production-prompt-update.md`**.
>
> Phase 8+ will use a phase-agnostic successor (issue #228 item E14).
>
> Do NOT propagate any pattern, structure, or wording from this file into produced prompts.

# Phase 7 Prompt Production — Session Instructions

_Purpose: Produce agent prompt bundles for Phase 7 steps._
_Input: Planning documents committed to repo._
_Output: Agent prompts, two-step Claude prompts, session handoffs, consolidated audit template._

---

## Strategy: Batched Prompt Production

Phase 7 has 12 steps. Producing all prompts in one session risks context saturation and produces stale prompts for later steps (because earlier steps may discover things that change later plans). Instead:

**Batch 1 (this session):** v7.7.0.0, v7.7.1.0, v7.7.1.1
- These are the first three steps — research, health-check, chunked streaming (BUG-082)
- They can be prompted with full confidence because they don't depend on discoveries from earlier steps

**Batch 2 (after v7.7.1.1 merges):** v7.7.1.2, v7.7.1.3, v7.7.1.4
- The per-device engine steps. Prompts benefit from knowing what v7.7.1.1 discovered about chunked streaming implementation details.

**Batch 3 (after v7.7.1.4 merges):** v7.7.2.1, v7.7.2.2, v7.7.2.3
- Integration and migration. Prompts need the actual struct definitions and key schemes from Batch 2.

**Batch 4 (after v7.7.2.3 merges):** v7.7.3.1, v7.7.3.2, v7.7.3.3
- Export/import and closure. Prompts need the final API surface from Batch 3.

Each batch session reads the session handoff from the last completed step of the previous batch, ensuring prompts reflect actual codebase state.

---

## Batch 1 Session Prompt

_Paste this into a fresh Claude Opus session._

```markdown
# Phase 7 Prompt Production — Batch 1 (v7.7.0.0, v7.7.1.0, v7.7.1.1)

You are the prompt producer for the ESP32-GW Multi-Sensor Gateway project.
Read the codebase, then produce agent prompt bundles for the first three
Phase 7 steps.

## Setup

Clone and read:
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor

## Mandatory Reading (in order)

1. `CURRENT-STATE.md` — current version, open issues, board measurements
2. `Docs/phase-7-review-and-rewrite.md` — THE Phase 7 plan (rewritten 2026-05-07)
3. `Docs/development-process-guide.md` — §2-3 (execution workflow, prompt structure)
4. `Docs/writing-guide/methodology.md` — 10-section prompt anatomy
5. `prompts/prompt-index-and-workflow.md` — Critical Rules table (rules 1-67)
6. `AGENTS.md` — what inline reviewers see
7. `firmware/core/config.h` — compile-time constants
8. `firmware/core/data-model.h` — HistoryBuffer, HistEntry, SensorEntity structs
9. `firmware/core/web-handler.h` — HTTP handlers (specifically handle_history_ and
   handle_api_v2_history_ for v7.7.1.1)
10. `firmware/core/nvs-persistence.h` — current NVS implementation (seg_NNN keys)
11. `scripts/assemble-sensor-history.sh` — fragment assembly (for adding health-check.h)
12. `Docs/board-measurement-log-v7.6.10.md` — measured heap/stack values
13. `Docs/lessons/firmware.md` — BUG-082, BUG-083, BUG-084

## Verify Before Producing

Run these checks to confirm codebase state:
- `cat VERSION` — should be 7.6.10.4
- `ls firmware/core/` — should list 8 .h files (no health-check.h yet)
- `grep -c 'authenticate_management_' firmware/core/web-handler.h` — should be ≥14
- `grep -c 'authFetch' dashboard/core/auth.js` — should be ≥1
- `grep -n 'handle_history_' firmware/core/web-handler.h | head -3` — find line numbers

## Deliverables

### For v7.7.0.0 (ESPHome component defaults audit — research):

Produce:
- `prompts/phase7/v7.7.0.0-research-prompt.md`

This is research only (no code changes, no version bump). The agent audits ESPHome 2026.4.1
component source for hardcoded defaults. Output: `Docs/esphome-component-defaults-audit.md`.

Sections: §1 Required reading (ESPHome source paths), §2 Audit targets (web server, WiFi,
BLE, NVS, OTA), §3 Output format (table: component, default, risk, recommendation),
§4 Acceptance criteria (document produced, critical findings → GitHub Issues).

### For v7.7.1.0 (health-check telemetry task):

Produce:
- `prompts/phase7/v7.7.1.0-agent-prompt-gpt-codex.md` — 10-section agent prompt
- `prompts/phase7/v7.7.1.0-claude-two-step.md` — agent section + reviewer checklist
- `prompts/handoff/phase7/session-handoff-v7.7.1.0.md` — handoff for next step

Agent creates `firmware/core/health-check.h` (new fragment). Updates
`assemble-sensor-history.sh`. Adds `xTaskCreate` to boot lambda. Logs: free_heap,
min_free_heap, httpd stack HWM, NVS stats, uptime. Period: 60s. Stack: 4096 B.

Checkpoints must use grep queries (not line numbers):
- `grep -c 'health-check.h' scripts/assemble-sensor-history.sh` → 1
- `grep -c 'xTaskCreate.*health_check' firmware/core/health-check.h` → 1
- `grep -c 'nvs_get_stats' firmware/core/health-check.h` → ≥1

### For v7.7.1.1 (chunked HTTP streaming — BUG-082 fix):

Produce:
- `prompts/phase7/v7.7.1.1-agent-prompt-gpt-codex.md` — 10-section agent prompt
- `prompts/phase7/v7.7.1.1-claude-two-step.md` — agent section + reviewer checklist
- `prompts/handoff/phase7/session-handoff-v7.7.1.1.md` — handoff

This is the highest-risk step. The agent rewrites handle_history_() and
handle_api_v2_history_() to use chunked HTTP streaming. Read these handlers
carefully before writing the prompt — verify the current response building
pattern (csv.reserve + append loop + sendstr).

Key constraint: Must work with ESPHome's AsyncWebHandler framework, or drop
to raw ESP-IDF httpd APIs for these specific handlers. Research which approach
is viable by reading the local component override at
`firmware/local_components/web_server_idf/`.

Scope guard: ONLY the history CSV handlers change. No other endpoints.
No persistence engine changes. No dashboard changes (browsers handle
Transfer-Encoding: chunked transparently).

### Consolidated Audit Template:

Also produce:
- `prompts/phase7/consolidated-audit-template-phase7.md`

Based on the Phase V template (`prompts/phaseV/consolidated-audit-template-phaseV.md`),
adapted for Phase 7. Sections:
§1 PR metadata, §2 Findings by severity, §3 Agent autonomous decisions,
§4 Prompt quality score, §5 Acceptance criteria checklist, §6 Device test results,
§7 Recommendations for next step.

## Prompt Anatomy (10 Sections)

Every implementation agent prompt follows this structure:
1. Required reading (file list with read order)
2. Pre-implementation verification gate (grep checks)
3. Scope boundary (what IS and IS NOT in scope)
4. Critical rules checklist (applicable rules from the table)
5. Do-NOT list (common agent mistakes to prevent)
6. Implementation steps (with session log reference)
7. Acceptance criteria (checkboxes)
8. Pipeline commands (full regeneration + CI commands)
9. Verification gate (post-implementation checks)
10. Post-merge deliverables (CURRENT-STATE.md, changelog, session log)

## Constraints

- All file paths verified against cloned repo (grep, not memory)
- Checkpoints use queries not assertions
- Stop-don't-fix semantics on checkpoint failures
- CURRENT-STATE.md update is mandatory in every implementation step
- Session log is a pre-merge acceptance criterion (Critical Rule 63)
```

---

## Batch 2-4 Production Pattern

After each batch's last step merges, the next batch's prompt production session reads:
1. `CURRENT-STATE.md` (updated by the merged step)
2. `Docs/phase-7-review-and-rewrite.md` (the plan)
3. The session handoff from the last merged step
4. The relevant firmware/core/ files that the new steps will modify

The batch session prompt follows the same structure as Batch 1, substituting the step versions and scopes.

**Batch 2 trigger:** After v7.7.1.1 merges, produce prompts for v7.7.1.2, v7.7.1.3, v7.7.1.4.
**Batch 3 trigger:** After v7.7.1.4 merges, produce prompts for v7.7.2.1, v7.7.2.2, v7.7.2.3.
**Batch 4 trigger:** After v7.7.2.3 merges, produce prompts for v7.7.3.1, v7.7.3.2, v7.7.3.3.

This pattern ensures each batch's prompts reflect the actual codebase state after the previous batch's changes are merged — preventing the staleness problem that made the original Phase 7 prompts unusable.

---

_End of prompt production instructions._
