# Session Handoff — v7.6.8.1: History Auth + Heap Cap + DoS Cooldown + SEC-ADR Commit

_Date: 2026-04-12_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.8.0 COMPLETE. Auth guards on ingest, add-satellite, aggregator reads. Status split done._

---

## Project State Summary

**v7.6.8.0 is complete.** All write endpoints and topology-disclosure endpoints auth-gated. `/api/status/full` added. Aggregator polling uses credentials.

---

## Phase V Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete |
| v7.6.7.3 | Operational telemetry in /api/status | ✅ Complete (PR #179) |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status split | ✅ Complete |
| **v7.6.8.1** | **V2-E/F/G: History auth + DoS + SEC-ADR** | **⬅️ Current** |
| v7.6.8.2 | V2-H/I/J: Gated optimisations | Pending |
| v7.6.9.0 | V3-A: Device card cleanup | Pending |
| v7.6.9.1 | V3-B/C: Hostname/IP + CSV role | Pending |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | Pending |
| v7.6.9.3 | V3-F: Struct audit (conditional) | Pending |

---

## v7.6.8.1 Scope

### What this step does

1. Auth guards on `/history/` and `/api/v2/history/` (V2-E)
2. Cap `csv.reserve()` at 60 KB (V2-E)
3. Per-URL DoS cooldown on add-satellite probe (V2-F)
4. Commit SEC-ADR-001 document (V2-G)

### What this step does NOT do

- Gated optimisations (V2-H/I/J — next step)
- Dashboard changes

### Files modified

- `firmware/core/web-handler.h` — history auth + heap cap
- `firmware/core/aggregator-runtime.h` or `web-handler.h` — DoS cooldown
- `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` — commit

### Acceptance criteria

See `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md` §6 for the full checklist.

---

## Pre-merge Checklist for v7.6.8.1

- [ ] Read the coding agent prompt (`prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates in §5 verified
- [ ] All acceptance criteria in §6 met
- [ ] ⛔ PRE-PR GATE in §7 passes
- [ ] Session log created
- [ ] Instruction Compliance Output table in PR description

---

## Critical Rules Relevant to v7.6.8.1

| # | Rule | Why Relevant |
|---|------|-------------|
| 58 | Edit fragments, run assembly | Fragment edits |
| LESSON-OPS-110 | Auth decision comments | History handler |

---

## Risk: LOW

---

## Workflow for v7.6.8.1

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt (or use Claude two-step)
3. Agent implements per §5 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Review the PR — verify scope, acceptance criteria, Critical Rules
6. Send universal reviewer prompt + step-specific focus areas to external reviewers (Codex/GPT/Copilot)
   - Universal prompt: `prompts/phaseV/pr-audit-question-template-phaseV.md` (top section)
   - Step supplement: same file, lookup table at bottom for this version
   - Reviewers post findings as PR comments; fix any Blocking/High issues
7. Merge, tag `v7.6.8.1`
8. Execute device testing (if applicable)
9. Produce consolidated audit
10. Inspect and update next step's handoff + agent prompt

---

## Device Testing

| Board | IP | Role |
|-------|-----|------|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite |
| ESP32-S3-DevKitC1-N16R8 | `192.168.120.191` | Aggregator |

- [ ] History endpoints return 401 without auth
- [ ] DoS cooldown: second rapid add-satellite returns 429

**If any endpoint crashes the board:** capture serial log, use bug escalation prompt (`prompts/handoff/universal-bug-escalation-prompt.md`).

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.8.1-PR<NN>-consolidated-audit-and-lessons.md`
**Use template:** `prompts/phaseV/pr-audit-question-template-phaseV.md` (stable core + sub-phase supplement)

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseV/session-handoff-v7.6.8.2.md`
- `prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md`
- `prompts/phaseV/v7.6.8.2-claude-two-step.md`

If any actual result from this step invalidates assumptions in the next step's handoff or prompt (e.g., line numbers shifted, function signatures changed differently than planned), update them before starting the next step.

---

## Context That Carries Forward to Next Step

- All security hardening is now in place. Auth coverage table in SEC-ADR-001 is the reference.
- History endpoints are auth-gated — affects any script or tool that fetches history.
- DoS cooldown array is static — no heap allocation.

---

_End of session handoff document._
