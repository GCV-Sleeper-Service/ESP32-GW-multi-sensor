# Session Handoff — v7.6.9.0: Dashboard Device Card Cleanup (#143 + #144 + #136 + #138)

_Date: 2026-04-12_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.8.2 COMPLETE. V2 complete. Gated optimisations applied (or documented as no-change)._

---

## Project State Summary

**v7.6.8.2 is complete.** Security hardening and optimisations complete. Starting dashboard enhancements.

---

## Phase V Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status split | ✅ Complete |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR | ✅ Complete |
| v7.6.8.2 | V2-H/I/J: Gated optimisations | ✅ Complete |
| **v7.6.9.0** | **V3-A: Device card cleanup** | **⬅️ Current** |
| v7.6.9.1 | V3-B/C: Hostname/IP + CSV role | Pending |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | Pending |
| v7.6.9.3 | V3-F: Struct audit (conditional) | Pending |

---

## v7.6.9.0 Scope

### What this step does

1. Replace MAC row with Device Name + Firmware Version rows (#144)
2. Add flash/SRAM runtime text_sensors to YAML; add to DEVICE_INFO_MAP (#136)
3. Add PSRAM sensors for S3; emit 'None' on C3 (#138)

### What this step does NOT do

- Export/import logic
- Satellite gateway card (V3-B)
- Firmware C++ changes

### Files modified

- `dashboard/core/status-snapshot.js` — DEVICE_INFO_MAP
- `dashboard/core/manifest.js` — populate new fields
- `dashboard/dashboard.tmpl.html` — new row IDs
- `firmware/esp32-c3-multi-sensor.yaml` — text_sensors

### Acceptance criteria

See `prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md` §6 for the full checklist.

---

## Pre-merge Checklist for v7.6.9.0

- [ ] Read the coding agent prompt (`prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates in §5 verified
- [ ] All acceptance criteria in §6 met
- [ ] ⛔ PRE-PR GATE in §7 passes
- [ ] Session log created
- [ ] Instruction Compliance Output table in PR description

---

## Critical Rules Relevant to v7.6.9.0

| # | Rule | Why Relevant |
|---|------|-------------|
| 47 | No direct dashboard.js/html edits | Edit source modules |
| 48 | Edit template source | Template is HTML source |

---

## Risk: MEDIUM — three issues combined, dashboard rebuild required

---

## Workflow for v7.6.9.0

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt (or use Claude two-step)
3. Agent implements per §5 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Review the PR — verify scope, acceptance criteria, Critical Rules
6. Send universal reviewer prompt + step-specific focus areas to external reviewers (Codex/GPT/Copilot)
   - Universal prompt: `prompts/phaseV/pr-audit-question-template-phaseV.md` (top section)
   - Step supplement: same file, lookup table at bottom for this version
   - Reviewers post findings as PR comments; fix any Blocking/High issues
7. Merge, tag `v7.6.9.0`
8. Execute device testing (if applicable)
9. Produce consolidated audit
10. Inspect and update next step's handoff + agent prompt

---

## Device Testing

| Board | IP | Role |
|-------|-----|------|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite |
| ESP32-S3-DevKitC1-N16R8 | `192.168.120.191` | Aggregator |

- [ ] Device card shows Device Name, Firmware Version
- [ ] Device card shows Flash/SRAM from runtime sensors
- [ ] S3 shows PSRAM; C3 shows None

**If any endpoint crashes the board:** capture serial log, use bug escalation prompt (`prompts/phaseV/phaseV-bug-escalation-to-claude.md`).

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.9.0-PR<NN>-consolidated-audit-and-lessons.md`
**Use template:** `prompts/phaseV/pr-audit-question-template-phaseV.md` (stable core + sub-phase supplement)

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseV/session-handoff-v7.6.9.1.md`
- `prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md`
- `prompts/phaseV/v7.6.9.1-claude-two-step.md`

If any actual result from this step invalidates assumptions in the next step's handoff or prompt (e.g., line numbers shifted, function signatures changed differently than planned), update them before starting the next step.

---

## Context That Carries Forward to Next Step

- DEVICE_INFO_MAP updated. New text_sensor entities in YAML.

---

_End of session handoff document._
