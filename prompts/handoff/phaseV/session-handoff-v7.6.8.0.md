# Session Handoff — v7.6.8.0: Auth Guards on Ingest/Add-Satellite/Aggregator Reads + Status Split

_Date: 2026-04-14 (updated from 2026-04-12 with v7.6.7.2 device test results and V1 operator measurements)_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.7.2 COMPLETE. V1 complete. Operator measurements taken. Merged PR #178, tagged v7.6.7.2._

---

## Project State Summary

**v7.6.7.2 is complete.** All V1 fixes shipped. Heap baseline confirmed on physical hardware. Measurement results available for V2-H/I/J gate decisions.

### v7.6.7.2 Confirmed State (from device tests 2026-04-14)

- Firmware flashed via OTA: 1,464,144 bytes in 5.54 s. ESPHome 2026.2.1, ESP-IDF 5.5.2. ✅
- API handshake: connected in 0.056 s, handshake 0.114 s. ✅
- Version badge (`v7.6.7.2`) visible in dashboard footer before SSE connects. ✅
- Badge visible in both light and dark mode. ✅
- No watchdog reset. No Guru Meditation. No task stack overflow. ✅
- **Runtime RAM:** 16.5% used (54,128 / 327,680 B). Free: ~273,552 B.
- **Flash:** 82.7% used (1,463,744 / 1,769,472 B).
- **Heap floor for all V2 steps: 65 KB** (confirmed by v7.6.7.1 device test: 70,568 bytes free; v7.6.7.2 dead code deletion does not affect runtime heap materially).
- `stream_snapshot_series_()` and `HistoryBuffer::stream_to()` confirmed deleted — zero tracked-source callers.
- Import session lifetime comment present at `handle_import_begin_()`.
- `assemble-sensor-history.sh --check` identity hash confirmed at v7.6.7.2 merge.

---

## Phase V Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete (PR #178, 2026-04-14) |
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
5. Add `basic_auth` parameter to `fetch_to_buffer()`; update aggregator polling to call `/api/status/full` (V2-D)

### What this step does NOT do

- History endpoint auth (V2-E)
- DoS cooldown (V2-F)
- Gated optimisations (V2-H/I/J)
- Dashboard JS changes (handles 401 natively)
- Any modification to import handler logic
- Direct edits to generated dashboard files (Rule 47)

### Files modified

- `firmware/core/web-handler.h` — auth guards + status split + `/api/status/full`
- `firmware/core/aggregator-runtime.h` — `basic_auth` parameter + polling update
- `Docs/lessons/build-pipeline.md` — LESSON-SEC-001 + LESSON-OPS-089 resolved
- `Docs/changelog.md`

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
| 8 | No new `beginResponseStream` | `/api/status/full` response must use pre-reserved string |
| 27 | `lwip_*` prefix for socket calls | Any new socket usage in fetch_to_buffer |
| 58 | Edit fragments, run assembly | Two fragment files modified |
| LESSON-OPS-110 | Auth decision comment in every handler code block | All V2 handlers require explicit auth comment |

---

## Risk: MEDIUM — aggregator polling must be updated simultaneously with status split

The aggregator polling task fetches `/api/status` from satellites to get heap/version data. When `/api/status` is stripped to `{ok, role, id}`, the polling task MUST be updated to call `/api/status/full` with credentials in the same PR. Failing to do so will silently break the aggregator dashboard's satellite heap/version display with no compile-time error.

**Agent must verify:** after Step 4.4, the aggregator dashboard still shows satellite heap and version information on the physical S3 aggregator.

---

## Line Number Notice (v7.6.8.0 agent)

The v7.6.8.0 agent prompt references several functions at approximate line numbers:
- `handle_add_satellite_()` at line ~1657
- `handle_aggregator_proxy_()` at line ~1556

Due to v7.6.7.2 additions (dead code deletion actually *reduces* lines in web-handler.h), actual line numbers may have shifted. **Always grep before editing:**
```bash
grep -n "void handle_add_satellite_" firmware/core/web-handler.h
grep -n "void handle_aggregator_proxy_" firmware/core/web-handler.h
grep -n "void handle_api_ingest_" firmware/core/web-handler.h
```
Use grep results as actual line numbers, not the ~estimates in the prompt.

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

- [ ] Unauthenticated `POST /api/ingest/` returns 401
- [ ] Authenticated `POST /api/ingest/` returns 200
- [ ] Unauthenticated `POST /api/aggregator/add-satellite` returns 401
- [ ] Unauthenticated `GET /api/aggregator/gateways` returns 401
- [ ] Authenticated `GET /api/aggregator/gateways` returns 200 + JSON
- [ ] Public `GET /api/status` returns ONLY `{ok, role, id}` (no `version`, `free_heap`, `uptime_s`)
- [ ] `GET /api/status/full` without auth returns 401
- [ ] `GET /api/status/full` with auth returns full JSON including `free_heap`, `version`, `uptime_s`
- [ ] Aggregator dashboard still shows satellite heap/version (polling uses `/api/status/full` with credentials)

**If any endpoint crashes the board:** capture serial log, use bug escalation prompt (`prompts/phaseV/phaseV-bug-escalation-to-claude.md`).

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.8.0-PR<NN>-consolidated-audit-and-lessons.md`
**Use template:** `prompts/phaseV/consolidated-audit-template-phaseV.md` (stable core + sub-phase supplement)

### 2. Inspect Next Step Artifacts

**Review and update if necessary:**
- `prompts/handoff/phaseV/session-handoff-v7.6.8.1.md`
- `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md`
- `prompts/phaseV/v7.6.8.1-claude-two-step.md`

If any actual result from this step invalidates assumptions in the next step's handoff or prompt (e.g., line numbers shifted, function signatures changed differently than planned), update them before starting the next step.

---

## Context That Carries Forward to Next Step

- `fetch_to_buffer()` will have 7 parameters after v7.6.8.0 (adds `basic_auth` on top of V1-A changes). All callers in `aggregator-runtime.h` must pass the new parameter.
- LESSON-OPS-089 exception is removed — `add-satellite` requires auth.
- Public `/api/status` returns only `{ok, role, id}`. Full status at `/api/status/full` (auth required).
- `/api/manifest` and `/sensors.json` remain public — accepted risk per SEC-ADR-001 RV-06.
- `/api/v2/live` remains public — accepted risk per SEC-ADR-001 RV-07.
- `/api/import/status` remains public — dashboard polls it; returns boolean only.
- Heap floor for all V2 steps: **65 KB**. Flash at 82.7% — monitor growth.
- `stream_snapshot_series_()` and `HistoryBuffer::stream_to()` are gone — do not reference them.
- Multi-sensor import `clear_persisted_history_()` still runs synchronously on httpd — V2 backlog.

### Lessons from v7.6.7.2 relevant to v7.6.8.0 agent

- **LESSON-REVIEW-001:** `grep -rn` against `firmware/` will hit `.esphome/build/` artefacts. Always use `--exclude-dir=.esphome` or note that those hits are generated build output.
- **LESSON-REVIEW-003:** `App.version` already includes the `v` prefix — do not use `'v' + App.version` in badge code.

---

_End of session handoff document._
