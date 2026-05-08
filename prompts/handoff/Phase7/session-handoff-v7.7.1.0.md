# Session Handoff — v7.7.1.0: Health-Check Telemetry Task

_Date: 2026-05-07_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.10.4 on `main`. Phase 7 planning complete. v7.7.0.0 research complete (or skipped — no code changes)._

---

## Project State Summary

**v7.6.10.4 is the current release.** Phase VX (board onboarding + auth refactor) complete. Phase 7 planning session produced `Docs/phase-7-review-and-rewrite.md`. This is the first implementation step of Phase 7.

The BUG-075/076 postmortem (6+ weeks ago) recommended periodic health telemetry. That recommendation has been sitting in CURRENT-STATE.md "Unimplemented Recommendations" since Phase D. This step finally implements it.

---

## Phase 7 Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.7.0.0 | ESPHome component defaults audit (research) | Complete (no code changes) |
| **v7.7.1.0** | **Health-check telemetry task** | **⬅️ Current** |
| v7.7.1.1 | Chunked HTTP streaming (BUG-082 fix) | Pending |
| v7.7.1.2 | Per-device structs, key scheme, hash | Pending |
| v7.7.1.3 | Per-device persist engine (write path) | Pending |
| v7.7.1.4 | Per-device restore engine + retention budget | Pending |

---

## v7.7.1.0 Scope

### What this step does

1. Creates `firmware/core/health-check.h` — new firmware fragment with a periodic FreeRTOS task
2. Updates `scripts/assemble-sensor-history.sh` — adds 9th fragment to assembly
3. Adds `xTaskCreate` call in YAML `on_boot` lambda at priority 600
4. Adds preflight check for the new fragment
5. Task logs every 60 seconds: heap (internal + total), min_free_heap (internal + total), httpd stack watermark, NVS stats, uptime

### What this step does NOT do

- No HTTP endpoints — health-check is ESPHome serial log output only
- No NVS writes — read-only telemetry
- No dashboard changes
- No existing fragment modifications
- No persistence engine changes

### Files created or modified

- `firmware/core/health-check.h` — **NEW** fragment
- `scripts/assemble-sensor-history.sh` — insert into MODULES array
- `firmware/esp32-c3-multi-sensor.yaml` — add on_boot entry
- `scripts/preflight.sh` — add existence check
- `Docs/changelog.md` — v7.7.1.0 entry
- `CURRENT-STATE.md` — update version, shipped list, move recommendation

### Acceptance criteria

See `prompts/phase7/v7.7.1.0-agent-prompt-gpt-codex.md` §7 for the full checklist.

---

## Pre-merge Checklist for v7.7.1.0

- [ ] Read the coding agent prompt (`prompts/phase7/v7.7.1.0-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates (A, B) verified
- [ ] All acceptance criteria in §7 met
- [ ] ⛔ PRE-PR GATE in §8 passes
- [ ] CURRENT-STATE.md updated (mandatory — version, What Just Shipped, Unimplemented Recommendations)
- [ ] Critical Rules 65-67 added to `prompts/prompt-index-and-workflow.md`
- [ ] PR body references Phase 7 step tracking issue for v7.7.1.0 and health-check recommendation issues
- [ ] Session log created
- [ ] Instruction Compliance Output table in PR description

---

## Critical Rules Relevant to v7.7.1.0

| # | Rule | Why Relevant |
|---|------|-------------|
| 2 | Use `bump-version.sh` for version bumps | Version 7.7.1.0 |
| 24 | Report internal and total heap separately | Health-check reports both |
| 58 | Edit fragments, not assembled artifact | New fragment created |
| 62 | Assembly order is dependency order | New fragment insertion position |
| 63 | Session log is pre-merge acceptance criterion | Mandatory |

---

## Risk: MEDIUM — new FreeRTOS task competes for heap

The health-check task uses 4096 bytes of stack. On the WROOM (tightest heap at ~38 KB free), this reduces free heap by ~10%. The task is read-only and low-priority (1), so the runtime risk is low. The main risk is the assembly insertion position — if placed wrong, compilation fails.

**Mitigation:** Insert after nvs-persistence.h (provides NVS APIs) and before deferred-management.h (no dependency). ⛔ CHECKPOINT B catches assembly failures.

---

## Workflow for v7.7.1.0

1. Read the coding agent prompt and this handoff completely
2. Open a NEW coding agent session and paste the GPT/Codex prompt
3. Agent implements per §6 with ⛔ CHECKPOINT verification
4. Agent runs pipeline, preflight, Playwright
5. Review the PR — verify scope, acceptance criteria, Critical Rules
6. Send universal reviewer prompt to external reviewers
7. Merge, tag `v7.7.1.0`
8. Execute device testing — flash C3, observe health-check logs
9. Produce consolidated audit — record baseline measurements
10. Inspect and update v7.7.1.1 handoff + agent prompt

---

## Device Testing

| Board | IP | Role |
|-------|-----|------|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite |

After flash and 90-second wait:
- [ ] Serial logs show `HEALTH: heap_free=... min_free=...` every 60s
- [ ] `nvs_used`, `nvs_free` values reported
- [ ] `httpd_stack_wm` value matches board-measurement-log (≈12,924 B for C3)
- [ ] No crash or watchdog timeout during health-check execution
- [ ] Free heap not significantly reduced vs v7.6.10.4 baseline (~58 KB boot → expect ~54 KB with task stack)

---

## Context That Carries Forward to v7.7.1.1

- Health-check task is running and providing runtime telemetry
- Use health-check output to verify that v7.7.1.1 chunked streaming reduces peak heap during history serve to < 5 KB
- The health-check baseline measurements (recorded in the consolidated audit) are the "before" numbers for BUG-082 fix validation
- Assembly script now has 9 fragments — v7.7.1.1 does NOT add new fragments, only modifies `web-handler.h`

---

_End of session handoff document._
