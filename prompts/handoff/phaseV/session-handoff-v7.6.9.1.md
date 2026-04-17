# Session Handoff — v7.6.9.1: Satellite Hostname/IP + CSV Export Role Column

_Date: 2026-04-12_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.9.0 COMPLETE. Device card cleanup merged._

---

## Project State Summary

**v7.6.9.0 is complete** (PR #183, merged 2026-04-16). V3-A dashboard device card cleanup complete. Starting V3-B satellite gateway card.

---

## Phase V Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete |
| v7.6.7.3 | Operational telemetry in /api/status | ✅ Complete (PR #179) |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status split | ✅ Complete |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR | ✅ Complete |
| v7.6.8.2 | V2-H/I/J: Gated optimisations | ✅ Complete |
| v7.6.9.0 | V3-A: Device card cleanup | ✅ Complete (PR #183, merged 2026-04-16) |
| **v7.6.9.1** | **V3-B/C: Hostname/IP + CSV role** | **⬅️ Current** |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | Pending |
| v7.6.9.3 | V3-F: Struct audit (conditional) | Pending |

---

## v7.6.9.1 Scope

### What this step does

1. Extract hostname/IP from satellite manifest in gateways JSON response (V3-B)
2. Display hostname/IP in dashboard gateway card (V3-B)
3. Add `role` column at position 3 in CSV export (V3-C — breaking change)
4. Add satellite prefix to column names in aggregator merged export (V3-C)

### What this step does NOT do

- Manifest-driven export columns (V3-D)
- Import changes

### Files modified

- `firmware/core/web-handler.h` — hostname/IP extraction
- `dashboard/components/gateway-panel/index.js` — display
- `dashboard/core/sensor-defs.js` — role column
- `dashboard/core/history.js` — CSV builders

### Acceptance criteria

See `prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md` §6 for the full checklist.

---

## Pre-merge Checklist for v7.6.9.1

- [ ] Read the coding agent prompt (`prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates in §5 verified
- [ ] All acceptance criteria in §6 met
- [ ] ⛔ PRE-PR GATE in §7 passes
- [ ] Session log created
- [ ] Instruction Compliance Output table in PR description

---

## Critical Rules Relevant to v7.6.9.1

| # | Rule | Why Relevant |
|---|------|-------------|
| 47 | No direct dashboard.js/html edits | Edit source modules |
| 58 | Edit fragment, run assembly | web-handler.h |

---

## Risk: LOW-MEDIUM — CSV breaking change documented

---

## Workflow for v7.6.9.1

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt (or use Claude two-step)
3. Agent implements per §5 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Review the PR — verify scope, acceptance criteria, Critical Rules
6. Send universal reviewer prompt + step-specific focus areas to external reviewers (Codex/GPT/Copilot)
   - Universal prompt: `prompts/phaseV/pr-audit-question-template-phaseV.md` (top section)
   - Step supplement: same file, lookup table at bottom for this version
   - Reviewers post findings as PR comments; fix any Blocking/High issues
7. Merge, tag `v7.6.9.1`
8. Execute device testing (if applicable)
9. Produce consolidated audit
10. Inspect and update next step's handoff + agent prompt

---

## Device Testing

| Board | IP | Role |
|-------|-----|------|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite |
| ESP32-S3-DevKitC1-N16R8 | `192.168.120.191` | Aggregator |

- [ ] Gateways JSON includes hostname and ip fields
- [ ] Dashboard shows hostname/IP in gateway card

**If any endpoint crashes the board:** capture serial log, use bug escalation prompt (`prompts/handoff/universal-bug-escalation-prompt.md`).

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.9.1-PR<NN>-consolidated-audit-and-lessons.md`
**Use template:** `prompts/phaseV/pr-audit-question-template-phaseV.md` (stable core + sub-phase supplement)

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseV/session-handoff-v7.6.9.2.md`
- `prompts/phaseV/v7.6.9.2-agent-prompt-gpt-codex.md`
- `prompts/phaseV/v7.6.9.2-claude-two-step.md`

If any actual result from this step invalidates assumptions in the next step's handoff or prompt (e.g., line numbers shifted, function signatures changed differently than planned), update them before starting the next step.

---

## Context That Carries Forward to Next Step

- CSV format now includes `role` column at position 3. Breaking change.
- Gateways JSON includes `hostname` and `ip` fields.
- DEVICE_INFO_MAP entries: di-device-name, di-firmware-version, di-flash, di-sram, di-psram now present in status-snapshot.js
- Flash/SRAM display: static strings in YAML text_sensors with update_interval: 60s (NOT never)
- PSRAM: single di-psram element; board-profile conditional lambda in generator
- Known limitation: loadStatusSnapshot() credentials: 'same-origin' fails over Cloudflare Tunnel — tracked v7.6.9.6
- LESSON-V769-01: text_sensors returning static values must use update_interval: 60s, not never
- LESSON-V769-02: SRAM label must use datasheet static strings, not heap_caps allocator APIs
---

_End of session handoff document._
