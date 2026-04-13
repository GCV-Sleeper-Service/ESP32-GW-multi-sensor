# Session Handoff — v7.6.8.0: Auth Guards on Ingest/Add-Satellite/Aggregator Reads + Status Split

_Date: 2026-04-12_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.7.2 COMPLETE. V1 complete. Operator measurements taken._

---

## Project State Summary

**v7.6.7.2 is complete.** All V1 fixes shipped. Heap baseline recorded. Measurement results available for V2-H/I/J gates.

---

## Phase V Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete |
| **v7.6.8.0** | **V2-A/B/C/D: Auth guards + status split** | **⬅️ Current** |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR | Pending |
| v7.6.8.2 | V2-H/I/J: Gated optimisations | Pending |
| v7.6.9.0 | V3-A: Device card cleanup | Pending |
| v7.6.9.1 | V3-B/C: Hostname/IP + CSV role | Pending |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | Pending |
| v7.6.9.3 | V3-F: Struct audit (conditional) | Pending |

---

## v7.6.8.0 Scope

### What this step does

1. Auth guard on `/api/ingest/` (V2-A)
2. Auth guard on `/api/aggregator/add-satellite` + remove LESSON-OPS-089 exception (V2-B)
3. Auth guards on `/api/aggregator/gateways`, `/api/aggregator/live`, `/api/aggregator/proxy/` (V2-C)
4. Strip sensitive fields from public `/api/status`; add auth-gated `/api/status/full` (V2-D)
5. Add `basic_auth` parameter to `fetch_to_buffer()`; update aggregator polling (V2-D)

### What this step does NOT do

- History endpoint auth (V2-E)
- DoS cooldown (V2-F)
- Gated optimisations (V2-H/I/J)
- Dashboard JS changes (handles 401 natively)

### Files modified

- `firmware/core/web-handler.h` — auth guards + status split + `/api/status/full`
- `firmware/core/aggregator-runtime.h` — `basic_auth` parameter + polling update
- `Docs/lessons/build-pipeline.md` — LESSON-SEC-001 + LESSON-OPS-089 resolved

### Acceptance criteria

See `prompts/phaseV/v7.6.8.0-agent-prompt-gpt-codex.md` §6 for the full checklist.

---

## Pre-merge Checklist for v7.6.8.0

- [ ] Read the coding agent prompt (`prompts/phaseV/v7.6.8.0-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates in §5 verified
- [ ] All acceptance criteria in §6 met
- [ ] ⛔ PRE-PR GATE in §7 passes
- [ ] Session log created
- [ ] Instruction Compliance Output table in PR description

---

## Critical Rules Relevant to v7.6.8.0

| # | Rule | Why Relevant |
|---|------|-------------|
| 8 | No new `beginResponseStream` | Status/full response |
| 58 | Edit fragments, run assembly | Two fragments modified |
| LESSON-OPS-110 | Auth decision in every handler code block | All V2 handlers |

---

## Risk: MEDIUM — aggregator polling must be updated simultaneously with status split

---

## Workflow for v7.6.8.0

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt (or use Claude two-step)
3. Agent implements per §5 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Review the PR — verify scope, acceptance criteria, Critical Rules
6. Send universal reviewer prompt + step-specific focus areas to external reviewers (Codex/GPT/Copilot)
   - Universal prompt: `prompts/phaseV/pr-audit-question-template-phaseV.md` (top section)
   - Step supplement: same file, lookup table at bottom for this version
   - Reviewers post findings as PR comments; fix any Blocking/High issues
7. Merge, tag `v7.6.8.0`
8. Execute device testing (if applicable)
9. Produce consolidated audit
10. Inspect and update next step's handoff + agent prompt

---

## Device Testing

| Board | IP | Role |
|-------|-----|------|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite |
| ESP32-S3-DevKitC1-N16R8 | `192.168.120.191` | Aggregator |

- [ ] Unauthenticated ingest returns 401
- [ ] Unauthenticated add-satellite returns 401
- [ ] Unauthenticated gateways returns 401
- [ ] Public `/api/status` returns only ok/role/id
- [ ] `/api/status/full` requires auth
- [ ] Aggregator dashboard still shows satellite info

**If any endpoint crashes the board:** capture serial log, use bug escalation prompt (`prompts/phaseV/phaseV-bug-escalation-to-claude.md`).

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.8.0-PR<NN>-consolidated-audit-and-lessons.md`
**Use template:** `prompts/phaseV/pr-audit-question-template-phaseV.md` (stable core + sub-phase supplement)

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseV/session-handoff-v7.6.8.1.md`
- `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md`
- `prompts/phaseV/v7.6.8.1-claude-two-step.md`

If any actual result from this step invalidates assumptions in the next step's handoff or prompt (e.g., line numbers shifted, function signatures changed differently than planned), update them before starting the next step.

---

## Context That Carries Forward to Next Step

- `fetch_to_buffer()` now has 7 parameters (added `basic_auth` on top of V1-A changes).
- LESSON-OPS-089 exception is removed — add-satellite requires auth.
- Public `/api/status` returns only `{ok, role, id}`. Full status at `/api/status/full`.

---

_End of session handoff document._
