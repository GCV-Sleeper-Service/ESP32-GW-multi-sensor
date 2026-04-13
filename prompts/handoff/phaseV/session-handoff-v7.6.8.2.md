# Session Handoff — v7.6.8.2: Gated Optimisations — Sockets, Ping Stack, httpd Stack

_Date: 2026-04-12_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.8.1 COMPLETE. Security hardening complete. All auth guards + SEC-ADR in place._

---

## Project State Summary

**v7.6.8.1 is complete.** Complete auth coverage. History endpoints gated. DoS cooldown active. SEC-ADR-001 committed.

---

## Phase V Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status split | ✅ Complete |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR | ✅ Complete |
| **v7.6.8.2** | **V2-H/I/J: Gated optimisations** | **⬅️ Current** |
| v7.6.9.0 | V3-A: Device card cleanup | Pending |
| v7.6.9.1 | V3-B/C: Hostname/IP + CSV role | Pending |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | Pending |
| v7.6.9.3 | V3-F: Struct audit (conditional) | Pending |

---

## v7.6.8.2 Scope

### What this step does

1. V2-H: Reduce `CONFIG_LWIP_MAX_SOCKETS` 18→15 IF gate passes (5-min two-tab test)
2. V2-I: Reduce ping_adapter stack 4096→2048 IF Step 7 watermark shows ≥512 B headroom
3. V2-J: Right-size httpd stack per decision table IF Step 6 watermark allows

### What this step does NOT do

- Any change without gate measurement results
- Dashboard changes
- Reduce LWIP below 13
- Set httpd stack below measured_peak + 2048

### Files modified

- `firmware/esp32-c3-multi-sensor.yaml` — socket count (if gate passes)
- `firmware/core/ping-adapter.h` — ping stack (if gate passes)
- `firmware/local_components/web_server_idf/web_server_idf.cpp` — httpd stack (if gate passes)
- `scripts/patch-esphome-httpd-stack.sh` — update patched value (if httpd stack changed)

### Acceptance criteria

See `prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md` §6 for the full checklist.

---

## Pre-merge Checklist for v7.6.8.2

- [ ] Read the coding agent prompt (`prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates in §5 verified
- [ ] All acceptance criteria in §6 met
- [ ] ⛔ PRE-PR GATE in §7 passes
- [ ] Session log created
- [ ] Instruction Compliance Output table in PR description

---

## Critical Rules Relevant to v7.6.8.2

| # | Rule | Why Relevant |
|---|------|-------------|
| 58 | Edit fragment, run assembly | ping-adapter.h if changed |

---

## Risk: HIGH if gates skipped; LOW if gates pass

---

## Workflow for v7.6.8.2

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt (or use Claude two-step)
3. Agent implements per §5 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Review the PR — verify scope, acceptance criteria, Critical Rules
6. Send universal reviewer prompt + step-specific focus areas to external reviewers (Codex/GPT/Copilot)
   - Universal prompt: `prompts/phaseV/pr-audit-question-template-phaseV.md` (top section)
   - Step supplement: same file, lookup table at bottom for this version
   - Reviewers post findings as PR comments; fix any Blocking/High issues
7. Merge, tag `v7.6.8.2`
8. Execute device testing (if applicable)
9. Produce consolidated audit
10. Inspect and update next step's handoff + agent prompt

---

## Device Testing

| Board | IP | Role |
|-------|-----|------|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite |
| ESP32-S3-DevKitC1-N16R8 | `192.168.120.191` | Aggregator |

- [ ] If V2-H: 5-min two-tab test, zero ENFILE errors
- [ ] If V2-I: ping sensor reports correctly for 30 minutes
- [ ] If V2-J: all dashboard operations work under new stack

**If any endpoint crashes the board:** capture serial log, use bug escalation prompt (`prompts/phaseV/phaseV-bug-escalation-to-claude.md`).

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.8.2-PR<NN>-consolidated-audit-and-lessons.md`
**Use template:** `prompts/phaseV/pr-audit-question-template-phaseV.md` (stable core + sub-phase supplement)

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseV/session-handoff-v7.6.9.0.md`
- `prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md`
- `prompts/phaseV/v7.6.9.0-claude-two-step.md`

If any actual result from this step invalidates assumptions in the next step's handoff or prompt (e.g., line numbers shifted, function signatures changed differently than planned), update them before starting the next step.

---

## Context That Carries Forward to Next Step

- Document which gates passed/failed and actual values.
- V2 is complete. Post-V2 heap baseline for V3-F gate.

---

_End of session handoff document._
