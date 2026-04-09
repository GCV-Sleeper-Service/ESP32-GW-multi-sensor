# Phase Y Prompt Production — Continuation Session

_This is the second session of Phase Y prompt production. The first session produced deliverables A, F, G, H and step-specific prompts for v7.6.6.0–v7.6.6.3. This session completes the remaining deliverables._

---

## Your Task

Continue producing the Phase Y implementation prompt package. The first session delivered roughly half the package. This session completes the rest.

**Do NOT re-implement anything already delivered.** Read what exists and produce only the remaining items.

---

## What Was Already Delivered (Session 1)

### Deliverable A — Writing Guide Updates ✅
- `Docs/writing-guide/methodology.md` — §4 added (two-prompt pattern, prompt anatomy, handoff insufficiency, chain-inspection)
- `Docs/writing-guide/gap-catalog.md` — Gaps 19–21 added (identity gate self-waiver, contiguous-slice violation, pipeline ordering)
- `Docs/writing-guide/checklists/firmware.md` — C++ file split patterns section added

### Deliverable F — PR Audit Template ✅
- `prompts/phaseY/pr-audit-question-template-phaseY.md`

### Deliverable G — Bug Escalation Prompt ✅
- `prompts/phaseY/phase-y-bug-escalation-prompt.md`

### Deliverable H — Prompt Index Update ✅
- `prompts/prompt-index-and-workflow.md` — Phase Y step table added with all 9 steps, status "Pending", file paths for all prompts and handoffs

### Steps v7.6.6.0–v7.6.6.3 (12 files) ✅
For each step (0, 1, 2, 3):
- `prompts/handoff/phaseY/session-handoff-v7.6.6.{N}.md`
- `prompts/phaseY/v7.6.6.{N}-implementation-instructions-for-coding-agent.md`
- `prompts/phaseY/v7.6.6.{N}-review-prompt.md`

---

## What Remains (This Session)

### B/C/D. Steps v7.6.6.4–v7.6.6.8 (15 files)

For each step (4, 5, 6, 7, 8), produce:
- `prompts/handoff/phaseY/session-handoff-v7.6.6.{N}.md`
- `prompts/phaseY/v7.6.6.{N}-implementation-instructions-for-coding-agent.md`
- `prompts/phaseY/v7.6.6.{N}-review-prompt.md`

### E. Combined Two-Session Prompts File

- `prompts/handoff/phaseY/phase-y-two-session-prompts.md`
- Contains all agent + review prompt pairs organized by step (all 9 steps)
- Format reference: `prompts/handoff/phaseX/phase-x-two-session-prompts.md`

---

## Prerequisites

Before starting, read these files to understand what was already produced:

### Already-delivered Phase Y files (read first)
1. `prompts/phaseY/pr-audit-question-template-phaseY.md` — audit template
2. `prompts/phaseY/phase-y-bug-escalation-prompt.md` — escalation prompt
3. `prompts/handoff/phaseY/session-handoff-v7.6.6.0.md` through `session-handoff-v7.6.6.3.md` — format reference for handoffs
4. `prompts/phaseY/v7.6.6.0-implementation-instructions-for-coding-agent.md` through `v7.6.6.3-*` — format reference for implementation and review prompts

### Primary planning inputs (same as Session 1)
5. `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md` — the Phase Y plan. Steps v7.6.6.4–v7.6.6.8 are defined here.
6. `Docs/phase-Y-current-state-inventory-sensor-history-v2.md` — file-level detail
7. `prompts/handoff/phaseX/phase-x-two-session-prompts.md` — format reference for the combined file

### Firmware reference (needed for device-test steps)
8. `dashboard/sensor_history_multi.h` — the file being split. Needed for exact function names and endpoint references in v7.6.6.5–v7.6.6.7 prompts.
9. `Docs/lessons/firmware.md` — firmware constraints for inline anti-patterns
10. `prompts/prompt-index-and-workflow.md` — Critical Rules

---

## Step-Specific Notes for Remaining Steps

### v7.6.6.4 — Ping Adapter Fragment Validation
- Lightweight validation step: confirms PingAdapter fragment works as authoritative source
- Lines 1220–1387 in `ping-adapter.h`
- Clean `#ifdef PING_DEVICE_INDEX` compile-guard boundary
- Optional device test if ping is configured
- Low risk, 0.5 session effort

### v7.6.6.5 — NVS Persistence Device Test Gate ⚠️ HIGH PRIORITY
- **Requires actual device testing on C3 hardware** (192.168.120.189)
- Flash satellite firmware, verify boot restore, history retention, hourly persist
- Test protocol: boot log check, reboot persistence, hourly segment, storage-stats, history endpoint
- This is a **blocking gate** — Phase Y cannot proceed if this fails
- Prompt must include detailed curl commands and expected outputs
- Reference: `Docs/writing-guide/checklists/firmware.md` NVS testing patterns

### v7.6.6.6 — Aggregator Runtime Device Test Gate ⚠️ HIGH PRIORITY
- **Requires actual device testing on S3 hardware** (192.168.120.191)
- Uses `provision.sh aggregator` → generated `firmware/esp32-s3-devkitc1-n16r8-gw.yaml`
- Test protocol: poll task, gateway endpoints, satellite add/delete, NVS reboot persistence
- Must test all 4 deferred-task pairs and mutex behavior
- Must switch back to satellite mode after testing (`provision.sh satellite`)
- Reference: Critical Rule 36 (use generated YAML for non-C3 boards)

### v7.6.6.7 — Full Endpoint Smoke Test
- **Requires device testing on BOTH C3 and S3 boards**
- Validates all 21 endpoint handlers
- Comprehensive route validation: auth, lockout, import cycle, management endpoints
- Both `esphome config` must validate for both board profiles
- Reference: v2 inventory §5 for full endpoint list

### v7.6.6.8 — Closure
- Add 6 new preflight checks (Phase Y closure checks from plan §3 v7.6.6.8)
- Add Critical Rules 58–62
- Update README, lessons, prompt-index
- Produce `prompts/handoff/phaseY-results.md`
- No device testing needed

---

## Quality Requirements

Match the format and quality of the v7.6.6.0–v7.6.6.3 deliverables already produced:

1. **Imperative, not advisory.** "Read file X" not "You may want to read file X"
2. **Inline anti-patterns at point of risk.** Place each anti-pattern next to the instruction it guards
3. **Explicit post-merge demands.** The agent produces consolidated audit before session close
4. **Chain-inspection requirement.** Each step's closure includes reviewing the next step's handoff
5. **Step-specific review checklists.** Each review prompt targets that step's exact failure modes
6. **Device test steps include exact curl commands.** With IP addresses, credentials, and expected outputs

---

## C++ Split Anti-Patterns (must appear in every prompt)

These are already present in v7.6.6.0–v7.6.6.3. Maintain the same set in v7.6.6.4–v7.6.6.8:

- `#include` order matters: assembly concatenation order is the dependency order
- `static` functions/variables scope: per-translation-unit under inclusion, file-scoped under assembly
- Mutex variables (`s_cache_mutex`) must be defined in exactly one fragment
- Deferred-task functions must be visible (defined before use) in assembly order
- ESPHome YAML `includes:` unchanged — only assembled artifact
- `render_sensor_config.py` marker blocks: delimiter stubs in fragments, content in assembled artifact
- `application/x-www-form-urlencoded` POST body requirement applies to all endpoints
- `maybe_yield_nvs_scan_()` must remain accessible from all NVS-scanning loop sites

---

## Deliverable Checklist (This Session)

Before committing, verify:

- [ ] One handoff per step exists for v7.6.6.4–v7.6.6.8 (5 files)
- [ ] One agent prompt per step exists for v7.6.6.4–v7.6.6.8 (5 files)
- [ ] One review prompt per step exists for v7.6.6.4–v7.6.6.8 (5 files)
- [ ] Combined two-session prompts file exists with ALL 9 steps (v7.6.6.0–v7.6.6.8)
- [ ] Every prompt references exact file paths (post-C1 reorganization paths)
- [ ] Every prompt includes the full regeneration pipeline
- [ ] Every prompt includes C++ split anti-patterns
- [ ] Every handoff includes the chain-inspection requirement
- [ ] Device test steps (v7.6.6.5, v7.6.6.6, v7.6.6.7) include curl commands with IPs and credentials
- [ ] v7.6.6.8 prompt includes all 6 new preflight checks and Critical Rules 58–62

---

## Commit Strategy

Package all deliverables and commit to `main`:

```
docs: produce Phase Y prompts v7.6.6.4–v7.6.6.8 and combined two-session file
```

---

_End of continuation prompt._
