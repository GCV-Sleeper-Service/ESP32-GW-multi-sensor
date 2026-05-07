Let me address your questions systematically, starting with the one that needs verification.Good — the research is back and I need to correct myself. Let me address all your questions, then give the execution plan.

---

## Corrections and Answers

**`.github/copilot-instructions.md` — I was wrong about tier requirements.**

Repository custom instructions via `.github/copilot-instructions.md` are available on all Copilot plans, including Free, Pro, and Pro+. No Business/Enterprise tier needed. The file applies to both Copilot Chat and Copilot code review.

There are two mechanisms:
- **`.github/copilot-instructions.md`** — repository-wide, applies to all Copilot interactions including PR code review. Limited to 4,000 characters for code review, so you must prioritize the most impactful rules.
- **`AGENTS.md`** — an open standard developed by the Linux Foundation / Agentic AI Foundation that works across multiple AI agents. Copilot, Claude, Gemini all recognize their respective files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`).

One caveat: automated PR reviews don't always reliably apply custom instructions — there are reports of inconsistency where chat-based reviews respect the file but automated reviews sometimes ignore it. This is reportedly improving.

**Practical recommendation:** Create both `.github/copilot-instructions.md` (4,000 char, focused on the top 10 review rules) AND `AGENTS.md` (more comprehensive, for agent execution via VSC). You can also create path-specific files like `.github/instructions/firmware.instructions.md` targeting `firmware/core/*.h` files.

---

**CURRENT-STATE.md — "will the prompt/instruction to create it change over time?"**

Yes, but infrequently. The template has two parts:
1. **Static structure** — sections that always exist (version, open issues, measurements, recommendations). This structure changes only when the methodology itself evolves (maybe once every 3-4 phases).
2. **Dynamic content** — values within those sections that change every merge.

The instruction to agents is simple and stable: "Update the sections of `CURRENT-STATE.md` that your changes affect." The post-merge deliverable checklist includes it alongside changelog and session log updates. When the structure itself needs a revision (new section, deprecated section), that's a methodology update — it happens during phase closure, not during step execution.

---

**Reviewers — keeping 5, automating GPT/Codex reviews.**

Understood, I withdraw the "drop to 3" recommendation. The real optimization is automating the review orchestration, not reducing reviewer count. A shell script or GitHub Action that triggers all 5 reviews in parallel and collects results would save the 30-60 minutes of manual coordination. I'll address this in Document 1.

---

**Curl tests as standard procedure in agent prompts.**

Yes. For any step that modifies HTTP endpoints or firmware behavior, the agent prompt should include a "Device Verification" section with specific curl commands and expected outputs. The pattern:

```
## Device Verification (agent-executed)
After upload, wait 30s for boot, then:
curl -s http://192.168.120.189/api/status | jq '.version'
# Expected: "7.7.0.1"
curl -s -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full | jq '.free_heap'
# Expected: > 40000
```

For steps that don't touch firmware (docs-only, test-only), this section is omitted.

---

**Parallelism — concrete Phase 7 scenario.**

Here's how it would work for v7.7.0.0 + v7.7.0.1:

**Session A (you + Codex agent on VSC):** Execute v7.7.0.0 agent prompt — struct definitions, key scheme, hash function. This creates a PR, gets reviewed, gets merged.

**Session B (you + a second Codex/Copilot session, or you during review wait time of Session A):** While Session A's PR is in review, author Playwright test stubs for the new `/api/v2/storage-stats` endpoint. These tests use mock contracts from the Phase 7 plan — they don't need the firmware implementation to exist yet. They go into a separate PR.

**Session C (documentation, can be a Claude or Copilot session):** While Session A executes, update `Docs/v7.7-implementation-plan.md` with the rewritten file paths, produce the CURRENT-STATE.md update, update the decision log. This is a separate PR that doesn't touch code files.

The key constraint: **Session B and C's PRs don't merge until Session A's PR merges** (to avoid merge conflicts). But the *work* happens in parallel, so when A merges, B and C are already ready for their review cycle.

In practice this means: instead of doing A→B→C sequentially over 6 hours, you do A in 2 hours, B and C overlap with A's review period, and the total wall-clock drops to ~3 hours.

---

**ESPHome defaults audit — worth doing?**

Yes, but scoped tightly. The productive version isn't "discover all defaults" (there are thousands) — it's "audit the defaults for the components we actually use." That means:

1. `web_server` — httpd stack size, max connections, timeout (already known)
2. `wifi` — power save mode, listen interval, max retries
3. `ble_tracker` — scan window, scan interval, connection timeout
4. `sensor` — update intervals, filter defaults
5. `nvs` — partition size, page count
6. `esp32` — `CONFIG_LWIP_MAX_SOCKETS`, `CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS`, watchdog timeout

A single investigative session could document these as "Component Defaults Audit" — maybe 30 values total. Then when ESPHome upgrades, a diff against the previous audit catches changes. This is worth 1 session of effort for long-term value. I'd put it as Phase 7 step -1 (before step 0).

---

**v7.6.10.4 checkpoint stumbles — how to improve?**

The v7.6.10.4 session log documented that the agent hit checkpoint failures multiple times. Two root causes:

1. **Checkpoints referenced stale state** — version markers, test counts, file paths were from plan-write-time, not execution-time. Your note about line number decay is exactly this. Fix: checkpoints should use *queries* (grep, jq, curl) rather than *assertions* (line 1431 should contain X). A checkpoint like `grep -c 'authFetch' dashboard/core/history.js` is stable; `line 47 of dashboard/core/history.js should be authFetch(...)` is fragile.

2. **Agent treated checkpoint failure as "fix it" rather than "stop and report."** Some agents, when hitting a checkpoint that says "verify X," will try to make X true rather than reporting that X is false. Fix: checkpoint language needs to be unambiguous: "If this check fails, STOP and post the actual vs expected values as a PR comment. Do NOT modify code to pass the checkpoint."

Both fixes go into the writing guide as checkpoint authoring rules.

---

**Proactive measurement as standard procedure.**

Add to every phase plan's Step 0:

```
## Step 0 — Measurement Baseline
Before any code changes:
1. Record current heap/watermark/NVS stats from all production boards
2. Record current Playwright test count
3. Record current CI build time
4. Check all open postmortem recommendations — are any still unimplemented?
5. Run stress test on at least one board per architecture
6. Commit results to CURRENT-STATE.md
```

This becomes a mandatory gate — no code step starts until Step 0 is merged.

---

**Weekly health-check script tied to CURRENT-STATE.md.**

Yes. A cron job on the LXC container that runs weekly:
```bash
#!/bin/bash
for board in 192.168.120.189 192.168.120.190 192.168.120.191; do
  curl -s -u ESPadmin:ESPpass100 http://$board/api/status/full | \
    jq '{board: .id, version: .version, free_heap, min_free_heap, uptime_s}'
done >> /root/config/ESP32-GW-multi-sensor/Docs/health-check-log.jsonl
```

When CURRENT-STATE.md is updated, it reads the latest entry from this log. If any board shows `min_free_heap` below a threshold (say 15,000), it flags it.

---

**Chunked streaming decoupling — what info do I need?**

To confirm chunked streaming can be done independently of the per-device persistence rewrite, I need to verify one thing: **does the current `/history/{id}/{series}` handler iterate NVS segments using the old `seg_NNN` key scheme directly, or through an abstraction?**

If it uses `seg_NNN` keys directly (which I believe it does based on reading `firmware/core/nvs-persistence.h`), then chunked streaming can be implemented against those keys now and updated later when the key scheme changes. If it goes through a function that Phase 7 plans to replace, the decoupling gets messy.

This is a 5-minute verification — `grep -n 'seg_' firmware/core/nvs-persistence.h | head -20` — that should be done at session start of the planning session, not assumed now.

---

**Task queue depth documentation.**

Yes, this should be a section in the Phase 7 plan. The current deferred tasks (`schedule_reboot_`, `schedule_reset_satellites_`, `schedule_delete_data_`) run one at a time because they're spawned by individual HTTP handlers. Phase 7 adds at least 2 more (per-device persist, per-device delete). The plan should document: max concurrent deferred tasks = 1 (they run sequentially), expected worst-case queue = 2, timeout behavior if a task takes too long.

---

## Updated Action Plan

Based on your feedback, here's the revised plan. Changes from previous version marked with △:

**Immediate deliverables (this session):**

1. ✅ `CURRENT-STATE.md` — create the file with current data
2. ✅ `Docs/decisions/decision-log.md` — create the lightweight index
3. ✅ `.github/copilot-instructions.md` — top 10 review rules (4,000 char limit) △ *confirmed works on all tiers*
4. ✅ `AGENTS.md` — comprehensive agent instructions △ *added based on research*
5. ✅ Document 1: `Docs/development-process-guide.md` — project-specific process acceleration
6. ✅ Document 2: `Docs/llm-assisted-development-guide.md` — practitioner's handbook
7. ✅ Document 3: `prompts/handoff/methodology-audit-findings-for-planning.md` — supplement for planning session
8. ✅ CI path filtering config for `.github/workflows/`

**Process changes (embedded in Documents 1 and 2):**
- Assumption-audit gate for planning sessions
- Recommendation tracking (postmortem → issue, no third option)
- Writing guide update cadence (every phase closure)
- △ Keep 5 reviewers, automate orchestration instead
- Flash/test automation in agent prompts (with curl verification)
- Checkpoint authoring rules (queries not assertions, stop-don't-fix)
- △ Proactive measurement as Step 0 of every phase
- △ Weekly health-check script
- △ Component defaults audit as Phase 7 step -1
- KPI tracking (steps-per-feature, fix cycles, wall-clock)

**What feeds into the multi-phase planning session:**
- Document 3 (methodology findings)
- Updated CURRENT-STATE.md
- Decision log
- The Phase 7 staleness analysis (file paths, struct refs, dashboard structure all stale)
- Phase 7 reordering recommendation (BUG-082 fix first)
- BUG-075-076 health-check as step 0
- Component defaults audit as step -1

**Regarding the "forgotten" feature priority document:** Yes, please share it or tell me its filename/location. It should feed into the multi-phase planning session alongside Document 3, so the phase ordering reflects both technical dependencies and feature priorities.

---

## Execution Order

Here's what I'll do now:

**Round 1** — Create the foundation files:
1. `CURRENT-STATE.md` (by reading current repo state)
2. `Docs/decisions/decision-log.md`
3. `.github/copilot-instructions.md`
4. `AGENTS.md`

**Round 2** — Write the three documents:
5. Document 1 (project-specific process guide)
6. Document 2 (LLM-assisted development practitioner's guide)
7. Document 3 (methodology audit findings for planning)

**Round 3** — CI config + any remaining files

Shall I start with Round 1?