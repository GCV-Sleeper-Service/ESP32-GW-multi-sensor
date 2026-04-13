# Session Handoff — v7.6.7.1: Import Crash Fix — Deferred Task Pattern

_Date: 2026-04-12_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.7.0 COMPLETE. V1-A/B/C merged. Proxy fixed, NAS history disabled, logger level changed._

---

## Project State Summary

**v7.6.7.0 is complete.** Proxy returns diagnostic JSON on 502. NAS metrics are live-only (~2.3 KB saved). Logger at WARN level.

---

## Phase V Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| **v7.6.7.1** | **V1-D: Import crash fix** | **⬅️ Current** |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | Pending |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status split | Pending |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR | Pending |
| v7.6.8.2 | V2-H/I/J: Gated optimisations | Pending |
| v7.6.9.0 | V3-A: Device card cleanup | Pending |
| v7.6.9.1 | V3-B/C: Hostname/IP + CSV role | Pending |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | Pending |
| v7.6.9.3 | V3-F: Struct audit (conditional) | Pending |

---

## v7.6.7.1 Scope

### What this step does

1. Defer `build_import_epoch_map_()` from httpd task to `xTaskCreate` (8192 B stack) — Rule 40 compliance
2. Add `s_import_ready` volatile flag for import readiness gating
3. Add `/api/import/status` endpoint (public, returns ready boolean)
4. Gate `/api/import/d/` and `/api/import/w/` on `s_import_ready`
5. Replace `beginResponseStream` at line ~817 with `beginResponse()` — Rule 8 fix

### What this step does NOT do

- Dashboard JS import polling (V3 concern if needed)
- Auth guards (V2)
- Any other firmware fragment changes
- Test file modifications

### Files modified

- `firmware/core/web-handler.h` — import handlers, `/api/import/status` endpoint, deferred task

### Acceptance criteria

See `prompts/phaseV/v7.6.7.1-agent-prompt-gpt-codex.md` §6 for the full checklist.

---

## Pre-merge Checklist for v7.6.7.1

- [ ] Read the coding agent prompt (`prompts/phaseV/v7.6.7.1-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates in §5 verified
- [ ] All acceptance criteria in §6 met
- [ ] ⛔ PRE-PR GATE in §7 passes
- [ ] Session log created
- [ ] Instruction Compliance Output table in PR description

---

## Critical Rules Relevant to v7.6.7.1

| # | Rule | Why Relevant |
|---|------|-------------|
| 8 | Replace `beginResponseStream` | Line ~817 import begin response |
| 40 | NVS work deferred to xTaskCreate | Import epoch map building |
| 41 | httpd task must not block on NVS | Import begin returns immediately |
| 58 | Edit fragment, run assembly | web-handler.h fragment |

---

## Risk: MEDIUM-HIGH — complex state machine with task + flag + polling. Test on C3 hardware mandatory.

---

## Workflow for v7.6.7.1

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt (or use Claude two-step)
3. Agent implements per §5 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Review the PR — verify scope, acceptance criteria, Critical Rules
6. Merge, tag `v7.6.7.1`
7. Execute device testing (if applicable)
8. Produce consolidated audit
9. Inspect and update next step's handoff + agent prompt

---

## Device Testing

| Board | IP | Role |
|-------|-----|------|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite |
| ESP32-S3-DevKitC1-N16R8 | `192.168.120.191` | Aggregator |

- [ ] `POST /api/import/begin` returns immediately (no crash, no WDT reset)
- [ ] `GET /api/import/status` returns `{ready:false}` then `{ready:true}`
- [ ] Full import sequence completes without watchdog reset
- [ ] Free heap does not drop below 55 KB during import task

**If any endpoint crashes the board:** capture serial log, use bug escalation prompt (`prompts/phaseV/phaseV-bug-escalation-to-claude.md`).

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.7.1-PR<NN>-consolidated-audit-and-lessons.md`
**Use template:** `prompts/phaseV/pr-audit-question-template-phaseV.md` (stable core + sub-phase supplement)

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseV/session-handoff-v7.6.7.2.md`
- `prompts/phaseV/v7.6.7.2-agent-prompt-gpt-codex.md`
- `prompts/phaseV/v7.6.7.2-claude-two-step.md`

If any actual result from this step invalidates assumptions in the next step's handoff or prompt (e.g., line numbers shifted, function signatures changed differently than planned), update them before starting the next step.

---

## Context That Carries Forward to Next Step

- Import now uses deferred task pattern. `/api/import/status` is a new public endpoint.
- `s_import_ready` is `static volatile bool` — data endpoints gate on it.
- The multi-sensor import path may also need deferred task treatment — check if the agent addressed both paths.

---

_End of session handoff document._
