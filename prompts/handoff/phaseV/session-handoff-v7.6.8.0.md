# Session Handoff — v7.6.8.0: Auth Guards on Ingest/Add-Satellite/Aggregator Reads + Status Split

_Date: 2026-04-15 (updated with v7.6.7.3 telemetry and V1 measurement results)_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.7.3 COMPLETE. V1 complete. Operator measurements taken. Merged PR #179, tagged v7.6.7.3._

---

## Project State Summary

**v7.6.7.3 is complete.** All V1 fixes shipped. Permanent operational telemetry added to `/api/status`. Heap and stack watermark measurements taken on physical hardware. V2 gate decisions determined.

### v7.6.7.3 Confirmed State (from device tests 2026-04-15)

- Firmware version: `v7.6.7.3` confirmed via `GET /api/status`. ✅
- Three new telemetry fields in `/api/status`: `min_free_heap`, `httpd_stack_watermark_bytes`, `ping_stack_watermark_bytes`. ✅
- No watchdog reset. No Guru Meditation. No task stack overflow. ✅
- **Heap floor for all V2 steps: 65 KB** (v7.6.7.3 fresh boot: 72,324 B internal; min_free_heap under load: 60,420 B = 59 KB; still above 55 KB gate).
- `assemble-sensor-history.sh --check` identity hash confirmed at v7.6.7.3 merge.

### V1 Measurement Results (v7.6.7.3, C3 satellite at 192.168.120.189)

| Measurement | Value | Gate Decision |
|---|---|---|
| Free heap at boot (internal) | 72,324 B (70.6 KB) | > 65 KB ✅ |
| Free heap at boot (total) | 80,080 B (78.2 KB) | > 65 KB ✅ |
| Min free heap (all endpoints exercised) | 60,420 B (59.0 KB) | > 55 KB ✅ |
| httpd stack watermark | **260 B** unused of 16,384 B | V2-J: **BLOCKED** — no reduction possible |
| ping stack watermark | **2,160 B** unused of 4,096 B | V2-I: **BLOCKED** — target 2048 leaves only 112 B headroom |
| V2-H socket test (two-tab, 5 min) | No ENFILE errors | V2-H: **PASSED** — socket reduction 18→15 is safe |

**V2 gate summary:** V2-H is the only surviving gated optimisation. V2-I and V2-J are blocked. v7.6.8.2 scope is significantly reduced.

---

## Phase V Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete (PR #178) |
| v7.6.7.3 | Operational telemetry in /api/status | ✅ Complete (PR #179) |
| **v7.6.8.0** | **V2-A/B/C/D: Auth guards + status split** | **⬅️ Current** |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR | Pending |
| v7.6.8.2 | V2-H: Socket reduction (V2-I/J blocked) | Pending |
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
4. Strip `/api/status` to return only `{ok, role, id}`; add auth-gated `/api/status/full` with all current fields (V2-D)
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

### Current `/api/status` response fields (v7.6.7.3 — exhaustive)

The agent must know every field currently in the response to correctly split them between public and full:

```json
{
  "ok": true,
  "version": "v7.6.7.3",
  "uptime_seconds": 12345,
  "sensor_count": 5,
  "sensors": [ {"id":"office","name":"Office","category":"environmental","last_seen":1776213088,"temp_valid":true,"hum_valid":true}, ... ],
  "ram_history_points_per_series": 96,
  "persist_days": 45,
  "free_heap": 69552,
  "free_heap_internal": 69552,
  "free_heap_total": 77308,
  "min_free_heap": 62220,
  "httpd_stack_watermark_bytes": 260,
  "ping_stack_watermark_bytes": 2160
}
```

**After V2-D:**
- Public `/api/status` → `{"ok":true,"role":"satellite","id":"esp32-c3-multi"}` (3 fields only; `role` and `id` are NEW)
- Auth-gated `/api/status/full` → all fields above PLUS `role` and `id`

### Deriving `role` and `id`

- `role`: compile-time from `AGGREGATOR_ENABLED` — `"aggregator"` if defined and non-zero, `"satellite"` otherwise
- `id`: the ESPHome device name, accessible via `App.get_name().c_str()` (ESPHome global singleton, always available in component code)

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
| 8 | No new `beginResponseStream` | `/api/status/full` response must use pre-reserved string + `beginResponse`, NOT `beginResponseStream` |
| 27 | `lwip_*` prefix for socket calls | Any new socket usage in fetch_to_buffer |
| 58 | Edit fragments, run assembly | Two fragment files modified |
| LESSON-OPS-110 | Auth decision comment in every handler code block | All V2 handlers require explicit auth comment |

---

## Risk: MEDIUM — aggregator polling must be updated simultaneously with status split

The aggregator polling task fetches `/api/status` from satellites to get heap/version data. When `/api/status` is stripped to `{ok, role, id}`, the polling task MUST be updated to call `/api/status/full` with credentials in the same PR. Failing to do so will silently break the aggregator dashboard's satellite heap/version display with no compile-time error.

**Agent must verify:** after Step 4.4, the aggregator dashboard still shows satellite heap and version information on the physical S3 aggregator.

---

## Line Number Notice (v7.6.8.0 agent)

Due to v7.6.7.2 dead code deletions and v7.6.7.3 telemetry additions, line numbers have shifted from earlier estimates. **Always grep before editing:**
```bash
grep -n "void handle_add_satellite_" firmware/core/web-handler.h
grep -n "void handle_aggregator_proxy_" firmware/core/web-handler.h
grep -n "void handle_api_ingest_" firmware/core/web-handler.h
grep -n "void handle_status_" firmware/core/web-handler.h
```
Use grep results as actual line numbers, not any estimates in prompts.

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
- [ ] Public `GET /api/status` returns ONLY `{"ok":true,"role":"...","id":"..."}` — no `version`, `free_heap`, `uptime_seconds`, `sensors`, `min_free_heap`, or any other field
- [ ] `GET /api/status/full` without auth returns 401
- [ ] `GET /api/status/full` with auth returns full JSON including ALL current fields: `version`, `uptime_seconds`, `sensor_count`, `sensors[]`, `free_heap`, `free_heap_internal`, `free_heap_total`, `min_free_heap`, `httpd_stack_watermark_bytes`, `ping_stack_watermark_bytes`, `ram_history_points_per_series`, `persist_days`, plus new `role` and `id`
- [ ] Aggregator dashboard still shows satellite heap/version (polling uses `/api/status/full` with credentials)

**If any endpoint crashes the board:** capture serial log, use bug escalation prompt (`prompts/handoff/universal-bug-escalation-prompt.md`).

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

- v7.6.7.3 added `min_free_heap`, `httpd_stack_watermark_bytes`, `ping_stack_watermark_bytes` to `/api/status`. After V2-D, these live in `/api/status/full` only.
- `fetch_to_buffer()` will have 7 parameters after v7.6.8.0 (adds `basic_auth` on top of V1-A changes). All callers in `aggregator-runtime.h` must pass the new parameter.
- LESSON-OPS-089 exception is removed — `add-satellite` requires auth.
- Public `/api/status` returns only `{ok, role, id}`. Full status at `/api/status/full` (auth required).
- `/api/manifest` and `/sensors.json` remain public — accepted risk per SEC-ADR-001 RV-06.
- `/api/v2/live` remains public — accepted risk per SEC-ADR-001 RV-07.
- `/api/import/status` remains public — dashboard polls it; returns boolean only.
- Heap floor: min_free_heap under load = 60,420 B (59 KB). Above 55 KB gate but with limited margin. Monitor growth.
- V2-I (ping stack) BLOCKED. V2-J (httpd stack) BLOCKED. V2-H (sockets) PASSED.
- `stream_snapshot_series_()` and `HistoryBuffer::stream_to()` are gone — do not reference them.
- Multi-sensor import `clear_persisted_history_()` still runs synchronously on httpd — V2 backlog.

### Lessons from v7.6.7.x relevant to v7.6.8.0 agent

- **LESSON-REVIEW-001:** `grep -rn` against `firmware/` will hit `.esphome/build/` artefacts. Always use `--exclude-dir=.esphome` or note that those hits are generated build output.
- **LESSON-REVIEW-003:** `App.version` already includes the `v` prefix — do not use `'v' + App.version` in badge code.
- **v7.6.7.3 learning:** `uxTaskGetStackHighWaterMark()` on ESP-IDF 5.x returns bytes (StackType_t is uint8_t). Use `* sizeof(StackType_t)` for portability, which is a no-op on current platform.
- **v7.6.7.3 learning:** `bump-version.sh` does NOT run `assemble-sensor-history.sh`. Always run `bash scripts/provision.sh satellite` after version bump to get the full pipeline.

---

_End of session handoff document._
